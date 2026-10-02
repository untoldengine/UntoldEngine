//
//  MuscleGeometryBuilder.swift
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

/// One muscle of a baked rig: resolved joints, bind-space attachment points
/// and the ranges of its particles/tets in the shared arrays.
struct MuscleBakedMuscle {
    let definition: MuscleDefinition
    let originJoint: Int
    let insertionJoint: Int
    let driverJoint: Int?
    let originRest: simd_float3
    let insertionRest: simd_float3
    let restAxis: simd_float3
    let restLength: Float
    let originBone: (start: simd_float3, end: simd_float3)
    let insertionBone: (start: simd_float3, end: simd_float3)
    let particleRange: Range<Int>
    let tetRange: Range<Int>
    /// Rest volume of the closed cage (tube + caps).
    let restVolume: Float

    /// Cross-section radius at axial parameter `t`.
    func radius(at t: Float) -> Float {
        MuscleGeometryBuilder.fusiformRadius(t: t, belly: definition.bellyRadius, tendon: definition.tendonRadius)
    }
}

/// CPU-side result of baking a `MuscleRig` against a skeleton: flat particle,
/// constraint and adjacency arrays ready for upload, plus per-muscle metadata
/// used to drive attachments and activation every frame.
struct MuscleBakedGeometry {
    var particleInfos: [MuscleParticleInfo] = []
    /// xyz bind-pose position, w inverse mass (0 = attachment).
    var initialPositions: [simd_float4] = []
    var edges: [MuscleEdge] = []
    /// Skin-wrap interpolation cells (ring centre + ring pair wedges).
    var tets: [MuscleTet] = []
    /// Outward-oriented closed surface per muscle (volume constraint).
    var triangles: [MuscleSurfaceTriangle] = []
    var edgeOffsets: [UInt32] = []
    var edgeList: [UInt32] = []
    var triOffsets: [UInt32] = []
    var triList: [UInt32] = []
    var muscles: [MuscleBakedMuscle] = []
    var frame = MuscleCharacterFrame(lateral: simd_float3(1, 0, 0), up: simd_float3(0, 1, 0), forward: simd_float3(0, 0, 1))

    var particleCount: Int {
        particleInfos.count
    }

    func tetCentroid(_ index: Int) -> simd_float3 {
        let tet = tets[index]
        let p0 = initialPositions[Int(tet.vertices.x)]
        let p1 = initialPositions[Int(tet.vertices.y)]
        let p2 = initialPositions[Int(tet.vertices.z)]
        let p3 = initialPositions[Int(tet.vertices.w)]
        let sum = p0 + p1 + p2 + p3
        return simd_float3(sum.x, sum.y, sum.z) * 0.25
    }
}

enum MuscleGeometryBuilder {
    /// Fusiform profile: tendon radius at both ends, belly radius mid-way.
    static func fusiformRadius(t: Float, belly: Float, tendon: Float) -> Float {
        tendon + (belly - tendon) * sin(Float.pi * min(max(t, 0), 1))
    }

    /// Signed volume of a closed, outward-oriented triangle surface.
    static func surfaceVolume(_ triangles: ArraySlice<MuscleSurfaceTriangle>, positions: [simd_float4]) -> Float {
        triangles.reduce(Float(0)) { sum, tri in
            func p(_ id: UInt32) -> simd_float3 {
                let v = positions[Int(id)]
                return simd_float3(v.x, v.y, v.z)
            }
            return sum + simd_dot(p(tri.a), simd_cross(p(tri.b), p(tri.c))) / 6
        }
    }

    /// Bakes every muscle whose joints resolve on `skeleton`; unresolved
    /// muscles are skipped with a warning. Returns nil when nothing resolved.
    static func bake(rig: MuscleRig, skeleton: Skeleton) -> MuscleBakedGeometry? {
        var geometry = MuscleBakedGeometry()
        geometry.frame = skeleton.muscleCharacterFrame(forwardReference: rig.forwardReference)

        for definition in rig.muscles {
            guard let origin = skeleton.muscleAttachmentPoint(definition.origin, frame: geometry.frame),
                  let insertion = skeleton.muscleAttachmentPoint(definition.insertion, frame: geometry.frame)
            else {
                Logger.logWarning(message: "Muscle \(definition.name): attachment joint not found, skipped")
                continue
            }
            let axis = insertion.point - origin.point
            let length = simd_length(axis)
            guard length > 1e-5, definition.rings >= 2, definition.segments >= 3,
                  definition.bellyRadius > 0, definition.tendonRadius > 0
            else {
                Logger.logWarning(message: "Muscle \(definition.name): degenerate definition, skipped")
                continue
            }
            let driverJoint = definition.driver.flatMap { skeleton.muscleJointIndex(named: $0.jointName) }
            appendFusiform(
                definition: definition,
                origin: origin.point,
                insertion: insertion.point,
                originJoint: origin.joint,
                insertionJoint: insertion.joint,
                driverJoint: driverJoint,
                originBone: skeleton.muscleBoneSegment(of: origin.joint),
                insertionBone: skeleton.muscleBoneSegment(of: insertion.joint),
                into: &geometry
            )
        }

        guard !geometry.muscles.isEmpty else { return nil }
        buildAdjacency(&geometry)
        return geometry
    }

    // MARK: - Fusiform cage

    private static func appendFusiform(
        definition: MuscleDefinition,
        origin: simd_float3,
        insertion: simd_float3,
        originJoint: Int,
        insertionJoint: Int,
        driverJoint: Int?,
        originBone: (start: simd_float3, end: simd_float3),
        insertionBone: (start: simd_float3, end: simd_float3),
        into geometry: inout MuscleBakedGeometry
    ) {
        let muscleIndex = UInt32(geometry.muscles.count)
        let rings = definition.rings
        let segments = definition.segments
        let axis = insertion - origin
        let length = simd_length(axis)
        let direction = axis / length
        let helper = abs(direction.y) < 0.9 ? simd_float3(0, 1, 0) : simd_float3(1, 0, 0)
        let u = simd_normalize(simd_cross(direction, helper))
        let v = simd_cross(direction, u)

        let particleBase = geometry.particleInfos.count
        let tetBase = geometry.tets.count
        let perRing = segments + 1

        func particleIndex(ring: Int, slot: Int) -> UInt32 {
            UInt32(particleBase + ring * perRing + slot)
        }

        // Ring centres are not simulated: they follow their ring's mean and
        // exist only as skin-wrap tet corners. End rings are pinned to the
        // joints; every other ring particle is free.
        for ring in 0 ..< rings {
            let t = Float(ring) / Float(rings - 1)
            let center = origin + axis * t
            let radius = fusiformRadius(t: t, belly: definition.bellyRadius, tendon: definition.tendonRadius)
            let attachment: UInt32 = ring == 0
                ? UInt32(MUSCLE_ATTACHMENT_ORIGIN)
                : (ring == rings - 1 ? UInt32(MUSCLE_ATTACHMENT_INSERTION) : UInt32(MUSCLE_ATTACHMENT_FREE))
            let inverseMass: Float = attachment == UInt32(MUSCLE_ATTACHMENT_FREE) ? 1 : 0

            geometry.particleInfos.append(MuscleParticleInfo(
                restPosition: simd_float4(center, t),
                restRadial: simd_float4(0, 0, 0, 0),
                muscleIndex: muscleIndex,
                attachment: UInt32(MUSCLE_ATTACHMENT_CENTER),
                ringSegments: UInt32(segments),
                pad0: 0
            ))
            geometry.initialPositions.append(simd_float4(center, 0))

            for segment in 0 ..< segments {
                let angle = 2 * Float.pi * Float(segment) / Float(segments)
                let radial = (u * cos(angle) + v * sin(angle)) * radius
                geometry.particleInfos.append(MuscleParticleInfo(
                    restPosition: simd_float4(center + radial, t),
                    restRadial: simd_float4(radial, 0),
                    muscleIndex: muscleIndex,
                    attachment: attachment,
                    ringSegments: 0,
                    pad0: 0
                ))
                geometry.initialPositions.append(simd_float4(center + radial, inverseMass))
            }
        }

        func position(_ id: UInt32) -> simd_float3 {
            let p = geometry.initialPositions[Int(id)]
            return simd_float3(p.x, p.y, p.z)
        }
        func appendEdge(_ a: UInt32, _ b: UInt32, fiber: Float) {
            geometry.edges.append(MuscleEdge(
                a: min(a, b), b: max(a, b),
                restLength: simd_length(position(a) - position(b)),
                fiber: fiber
            ))
        }
        /// Outward orientation: the triangle normal must point along `outward`.
        func appendTriangle(_ a: UInt32, _ b: UInt32, _ c: UInt32, outward: simd_float3) {
            let normal = simd_cross(position(b) - position(a), position(c) - position(a))
            let ordered: (UInt32, UInt32, UInt32) = simd_dot(normal, outward) >= 0 ? (a, b, c) : (a, c, b)
            geometry.triangles.append(MuscleSurfaceTriangle(a: ordered.0, b: ordered.1, c: ordered.2, muscleIndex: muscleIndex))
        }

        let triangleBase = geometry.triangles.count
        for ring in 0 ..< rings - 1 {
            for segment in 0 ..< segments {
                let next = (segment + 1) % segments
                let a0 = particleIndex(ring: ring, slot: 0)
                let a1 = particleIndex(ring: ring, slot: 1 + segment)
                let a2 = particleIndex(ring: ring, slot: 1 + next)
                let b0 = particleIndex(ring: ring + 1, slot: 0)
                let b1 = particleIndex(ring: ring + 1, slot: 1 + segment)
                let b2 = particleIndex(ring: ring + 1, slot: 1 + next)

                // Membrane constraints: fibers along the axis, hoops around
                // it, one shear diagonal per quad (half fiber). The end slabs
                // are tendons: they never contract and stretch instead, so an
                // isometric flex still shortens and thickens the belly.
                let contractile: Float = (ring == 0 || ring == rings - 2) ? 0 : 1
                appendEdge(a1, b1, fiber: contractile)
                appendEdge(a1, a2, fiber: 0)
                appendEdge(a1, b2, fiber: 0.5 * contractile)
                if ring == rings - 2 {
                    appendEdge(b1, b2, fiber: 0)
                }

                // Tube surface, oriented away from the axis.
                let outward = position(a1) - position(a0)
                appendTriangle(a1, a2, b2, outward: outward)
                appendTriangle(a1, b2, b1, outward: outward)

                // Skin-wrap wedge between the rings, split into three tets.
                appendTet([a0, a1, a2, b0], muscleIndex: muscleIndex, into: &geometry)
                appendTet([a1, a2, b0, b1], muscleIndex: muscleIndex, into: &geometry)
                appendTet([a2, b0, b1, b2], muscleIndex: muscleIndex, into: &geometry)
            }
        }
        // End caps close the surface (fans around the pinned ring centres).
        for segment in 0 ..< segments {
            let next = (segment + 1) % segments
            appendTriangle(
                particleIndex(ring: 0, slot: 0),
                particleIndex(ring: 0, slot: 1 + segment),
                particleIndex(ring: 0, slot: 1 + next),
                outward: -direction
            )
            appendTriangle(
                particleIndex(ring: rings - 1, slot: 0),
                particleIndex(ring: rings - 1, slot: 1 + segment),
                particleIndex(ring: rings - 1, slot: 1 + next),
                outward: direction
            )
        }
        let restVolume = surfaceVolume(geometry.triangles[triangleBase...], positions: geometry.initialPositions)

        geometry.muscles.append(MuscleBakedMuscle(
            definition: definition,
            originJoint: originJoint,
            insertionJoint: insertionJoint,
            driverJoint: driverJoint,
            originRest: origin,
            insertionRest: insertion,
            restAxis: direction,
            restLength: length,
            originBone: originBone,
            insertionBone: insertionBone,
            particleRange: particleBase ..< geometry.particleInfos.count,
            tetRange: tetBase ..< geometry.tets.count,
            restVolume: restVolume
        ))
    }

    static func signedVolume(_ p0: simd_float3, _ p1: simd_float3, _ p2: simd_float3, _ p3: simd_float3) -> Float {
        simd_dot(simd_cross(p1 - p0, p2 - p0), p3 - p0) / 6
    }

    private static func appendTet(_ ids: [UInt32], muscleIndex: UInt32, into geometry: inout MuscleBakedGeometry) {
        func position(_ id: UInt32) -> simd_float3 {
            let p = geometry.initialPositions[Int(id)]
            return simd_float3(p.x, p.y, p.z)
        }
        var ordered = ids
        var volume = signedVolume(position(ordered[0]), position(ordered[1]), position(ordered[2]), position(ordered[3]))
        if volume < 0 {
            ordered.swapAt(1, 2)
            volume = -volume
        }
        guard volume > 1e-12 else { return }
        geometry.tets.append(MuscleTet(
            vertices: simd_uint4(ordered[0], ordered[1], ordered[2], ordered[3]),
            restVolume: volume,
            muscleIndex: muscleIndex,
            pad0: 0, pad1: 0
        ))
    }

    // MARK: - Adjacency (CSR)

    private static func buildAdjacency(_ geometry: inout MuscleBakedGeometry) {
        let particleCount = geometry.particleCount
        var edgeCounts = [UInt32](repeating: 0, count: particleCount)
        for edge in geometry.edges {
            edgeCounts[Int(edge.a)] += 1
            edgeCounts[Int(edge.b)] += 1
        }
        var triCounts = [UInt32](repeating: 0, count: particleCount)
        for tri in geometry.triangles {
            for id in [tri.a, tri.b, tri.c] {
                triCounts[Int(id)] += 1
            }
        }

        geometry.edgeOffsets = prefixSum(edgeCounts)
        geometry.triOffsets = prefixSum(triCounts)
        var edgeCursor = Array(geometry.edgeOffsets.dropLast())
        var triCursor = Array(geometry.triOffsets.dropLast())
        geometry.edgeList = [UInt32](repeating: 0, count: Int(geometry.edgeOffsets.last ?? 0))
        geometry.triList = [UInt32](repeating: 0, count: Int(geometry.triOffsets.last ?? 0))

        for (index, edge) in geometry.edges.enumerated() {
            for id in [edge.a, edge.b] {
                geometry.edgeList[Int(edgeCursor[Int(id)])] = UInt32(index)
                edgeCursor[Int(id)] += 1
            }
        }
        for (index, tri) in geometry.triangles.enumerated() {
            for id in [tri.a, tri.b, tri.c] {
                geometry.triList[Int(triCursor[Int(id)])] = UInt32(index)
                triCursor[Int(id)] += 1
            }
        }
    }

    private static func prefixSum(_ counts: [UInt32]) -> [UInt32] {
        var offsets = [UInt32](repeating: 0, count: counts.count + 1)
        for (index, count) in counts.enumerated() {
            offsets[index + 1] = offsets[index] + count
        }
        return offsets
    }

    // MARK: - Skin binding

    /// Binds each skin vertex (bind-pose model space) to the nearest tet of
    /// the muscle whose influence is strongest there. The weight is 1 inside
    /// the muscle, falls off over `skinInfluence` outside it and fades toward
    /// the tendons so attachments never tug the skin.
    static func bindSkin(positions: [simd_float4], geometry: MuscleBakedGeometry) -> [MuscleSkinBinding] {
        let centroids = (0 ..< geometry.tets.count).map(geometry.tetCentroid)
        let unbound = MuscleSkinBinding(
            barycentric: simd_float4(0, 0, 0, 0),
            tetIndex: MUSCLE_SKIN_UNBOUND,
            weight: 0,
            pad0: 0, pad1: 0
        )
        var bindings = [MuscleSkinBinding](repeating: unbound, count: positions.count)

        for (vertexIndex, position4) in positions.enumerated() {
            let point = simd_float3(position4.x, position4.y, position4.z)
            var bestWeight: Float = 0
            var bestMuscle: Int?

            for (muscleIndex, muscle) in geometry.muscles.enumerated() {
                let relative = point - muscle.originRest
                let t = min(max(simd_dot(relative, muscle.restAxis) / muscle.restLength, 0), 1)
                let onAxis = muscle.originRest + muscle.restAxis * (t * muscle.restLength)
                let axialDistance = simd_length(point - onAxis)
                let surface = muscle.radius(at: t)
                let influence = max(muscle.definition.skinInfluence, 1e-6)
                guard axialDistance <= surface + influence else { continue }
                let radial: Float = axialDistance <= surface
                    ? 1
                    : smoothstep(1 - (axialDistance - surface) / influence)
                // Zero within 5% of either tendon, full weight from 30% in.
                let fade = smoothstep((t - 0.05) / 0.25) * smoothstep((1 - t - 0.05) / 0.25)
                let weight = radial * fade
                if weight > bestWeight {
                    bestWeight = weight
                    bestMuscle = muscleIndex
                }
            }

            guard let bestMuscle, bestWeight > 1e-3 else { continue }
            let muscle = geometry.muscles[bestMuscle]
            var nearestTet = muscle.tetRange.lowerBound
            var nearestDistance = Float.greatestFiniteMagnitude
            for tetIndex in muscle.tetRange {
                let distance = simd_length_squared(centroids[tetIndex] - point)
                if distance < nearestDistance {
                    nearestDistance = distance
                    nearestTet = tetIndex
                }
            }
            guard let barycentric = barycentricCoordinates(of: point, in: geometry.tets[nearestTet], geometry: geometry) else {
                continue
            }
            bindings[vertexIndex] = MuscleSkinBinding(
                barycentric: barycentric,
                tetIndex: UInt32(nearestTet),
                weight: bestWeight,
                pad0: 0, pad1: 0
            )
        }
        return bindings
    }

    private static func smoothstep(_ x: Float) -> Float {
        let t = min(max(x, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Barycentric coordinates of `point` in `tet` (components clamped to
    /// [-1, 2] to bound extrapolation for points outside the tet).
    static func barycentricCoordinates(of point: simd_float3, in tet: MuscleTet, geometry: MuscleBakedGeometry) -> simd_float4? {
        func position(_ id: UInt32) -> simd_float3 {
            let p = geometry.initialPositions[Int(id)]
            return simd_float3(p.x, p.y, p.z)
        }
        let p0 = position(tet.vertices.x)
        let basis = simd_float3x3(
            position(tet.vertices.y) - p0,
            position(tet.vertices.z) - p0,
            position(tet.vertices.w) - p0
        )
        guard abs(simd_determinant(basis)) > 1e-14 else { return nil }
        let local = simd_inverse(basis) * (point - p0)
        let b1 = min(max(local.x, -1), 2)
        let b2 = min(max(local.y, -1), 2)
        let b3 = min(max(local.z, -1), 2)
        return simd_float4(1 - b1 - b2 - b3, b1, b2, b3)
    }
}
