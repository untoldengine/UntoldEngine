//
//  DDMPrecompute.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd

/// CPU-side Direct Delta Mush bake: smooths per-vertex skinning influence
/// matrices (homogeneous outer products of the rest positions, weighted by
/// the joint weights) over the mesh surface, so the runtime kernel can fit a
/// rigid transform per vertex instead of linearly blending joint matrices.
///
/// Input snapshot is plain arrays so the bake can run off the render thread.
struct DDMPrecomputeInput {
    let positions: [simd_float4]
    let jointIndices: [simd_ushort4]
    let jointWeights: [simd_float4]
    let triangleIndices: [UInt32]
}

enum DDMPrecompute {
    /// Smoothing schedule: `iterations` explicit Laplacian steps blending
    /// each vertex `blend` of the way toward its one-ring average. More
    /// iterations widen the smoothing radius (the DDM "p" parameter).
    /// The radius is topological — each step reaches one edge ring — so
    /// production-density meshes (tens of thousands of vertices) need far
    /// more steps than a low-poly test mesh for a visible effect.
    static let smoothingIterations = 64
    static let smoothingBlend: Float = 0.85

    /// Diagonal regularizer added to the 3x3 block of each omega, scaled by
    /// the mesh's spread and distributed by joint weight. Locally flat
    /// regions produce a singular position covariance, which breaks the
    /// runtime polar decomposition; the regularizer transforms with the
    /// blended joint matrix, so rigid invariance stays exact while the
    /// decomposition stays well-conditioned.
    static let regularization: Float = 0.05

    /// Ten unique entries of the symmetric 4x4 homogeneous outer product,
    /// row-major upper triangle (matches DDMOmegaEntry.m).
    private typealias Sym10 = (Float, Float, Float, Float, Float, Float, Float, Float, Float, Float)

    private static func outerProduct(_ u: simd_float3, weight: Float) -> [Float] {
        [
            u.x * u.x, u.x * u.y, u.x * u.z, u.x,
            u.y * u.y, u.y * u.z, u.y,
            u.z * u.z, u.z,
            1.0,
        ].map { $0 * weight }
    }

    /// Bakes `DDM_OMEGAS_PER_VERTEX` omega entries per vertex. Returns an
    /// array of `vertexCount * DDM_OMEGAS_PER_VERTEX` entries; unused slots
    /// carry jointIndex == .max.
    static func bakeOmegas(input: DDMPrecomputeInput) -> [DDMOmegaEntry] {
        let vertexCount = input.positions.count
        let slotCount = Int(DDM_OMEGAS_PER_VERTEX)

        // One-ring adjacency from the triangle list. Positions are compared
        // exactly; vertices split at UV/normal seams share a position, so
        // merge them through a position key to keep the surface connected
        // across seams (otherwise smoothing tears at every seam).
        var positionKeyToCanonical: [SIMD3<Float>: Int] = [:]
        var canonicalIndex = [Int](repeating: 0, count: vertexCount)
        for index in 0 ..< vertexCount {
            let key = input.positions[index].xyz
            if let existing = positionKeyToCanonical[key] {
                canonicalIndex[index] = existing
            } else {
                positionKeyToCanonical[key] = index
                canonicalIndex[index] = index
            }
        }

        var adjacency = [Set<Int>](repeating: [], count: vertexCount)
        var triangleIndex = 0
        while triangleIndex + 2 < input.triangleIndices.count {
            let a = canonicalIndex[Int(input.triangleIndices[triangleIndex])]
            let b = canonicalIndex[Int(input.triangleIndices[triangleIndex + 1])]
            let c = canonicalIndex[Int(input.triangleIndices[triangleIndex + 2])]
            if a != b { adjacency[a].insert(b); adjacency[b].insert(a) }
            if b != c { adjacency[b].insert(c); adjacency[c].insert(b) }
            if a != c { adjacency[a].insert(c); adjacency[c].insert(a) }
            triangleIndex += 3
        }

        // Sparse omega field: per canonical vertex, jointIndex -> 10 floats.
        // Initialized from the raw skinning weights, then Laplacian-smoothed.
        var omegas = [[UInt32: [Float]]](repeating: [:], count: vertexCount)
        for index in 0 ..< vertexCount {
            let canonical = canonicalIndex[index]
            guard canonical == index else { continue }
            let joints = input.jointIndices[index]
            let weights = input.jointWeights[index]
            let u = input.positions[index].xyz
            for influence in 0 ..< 4 {
                let weight = weights[influence]
                guard weight > 0 else { continue }
                let joint = UInt32(joints[influence])
                let contribution = outerProduct(u, weight: weight)
                if var existing = omegas[index][joint] {
                    for k in 0 ..< 10 {
                        existing[k] += contribution[k]
                    }
                    omegas[index][joint] = existing
                } else {
                    omegas[index][joint] = contribution
                }
            }
        }

        // Explicit Laplacian smoothing over the one-ring, truncating each
        // vertex to the strongest joints so the sparse maps stay bounded.
        let truncationLimit = slotCount * 2
        for _ in 0 ..< smoothingIterations {
            var next = omegas
            for index in 0 ..< vertexCount where canonicalIndex[index] == index {
                let neighbors = adjacency[index]
                guard !neighbors.isEmpty else { continue }

                var average: [UInt32: [Float]] = [:]
                let neighborScale = 1.0 / Float(neighbors.count)
                for neighbor in neighbors {
                    for (joint, values) in omegas[neighbor] {
                        if var existing = average[joint] {
                            for k in 0 ..< 10 {
                                existing[k] += values[k] * neighborScale
                            }
                            average[joint] = existing
                        } else {
                            average[joint] = values.map { $0 * neighborScale }
                        }
                    }
                }

                var blended: [UInt32: [Float]] = [:]
                let ownScale = 1 - smoothingBlend
                for (joint, values) in omegas[index] {
                    blended[joint] = values.map { $0 * ownScale }
                }
                for (joint, values) in average {
                    if var existing = blended[joint] {
                        for k in 0 ..< 10 {
                            existing[k] += values[k] * smoothingBlend
                        }
                        blended[joint] = existing
                    } else {
                        blended[joint] = values.map { $0 * smoothingBlend }
                    }
                }

                if blended.count > truncationLimit {
                    let kept = blended.sorted { $0.value[9] > $1.value[9] }.prefix(truncationLimit)
                    blended = Dictionary(uniqueKeysWithValues: Array(kept))
                }
                next[index] = blended
            }
            omegas = next
        }

        // Regularizer magnitude follows the covariance units (length²): the
        // mean squared distance of the mesh from its centroid.
        var centroid = simd_float3.zero
        for position in input.positions {
            centroid += position.xyz
        }
        centroid /= Float(max(vertexCount, 1))
        var meanSquaredSpread: Float = 0
        for position in input.positions {
            meanSquaredSpread += simd_length_squared(position.xyz - centroid)
        }
        meanSquaredSpread /= Float(max(vertexCount, 1))
        let epsilon = regularization * max(meanSquaredSpread, 1e-8)

        // Emit the top slots per vertex, renormalized so the homogeneous
        // weight (m[9]) sums to one — required for the rigid fit — and
        // regularized on the 3x3 diagonal proportionally to that weight.
        var entries = [DDMOmegaEntry](
            repeating: DDMOmegaEntry(jointIndex: .max, m: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0)),
            count: vertexCount * slotCount
        )
        for index in 0 ..< vertexCount {
            let map = omegas[canonicalIndex[index]]
            let strongest = map.sorted { $0.value[9] > $1.value[9] }.prefix(slotCount)
            let totalWeight = strongest.reduce(Float(0)) { $0 + $1.value[9] }
            guard totalWeight > 1e-8 else { continue }
            for (slot, item) in strongest.enumerated() {
                let scale = 1 / totalWeight
                let v = item.value
                let weightShare = v[9] * scale
                entries[index * slotCount + slot] = DDMOmegaEntry(
                    jointIndex: item.key,
                    m: (
                        v[0] * scale + epsilon * weightShare,
                        v[1] * scale, v[2] * scale, v[3] * scale,
                        v[4] * scale + epsilon * weightShare,
                        v[5] * scale, v[6] * scale,
                        v[7] * scale + epsilon * weightShare,
                        v[8] * scale, v[9] * scale
                    )
                )
            }
        }
        return entries
    }
}

private extension simd_float4 {
    var xyz: simd_float3 {
        simd_float3(x, y, z)
    }
}
