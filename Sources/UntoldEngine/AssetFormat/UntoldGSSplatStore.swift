//
//  UntoldGSSplatStore.swift
//  UntoldEngine
//
//  The cooked splats of a bake as one compact structure of arrays: the
//  writer's floats (position, scale, rotation, colour, opacity) and the
//  higher-order spherical harmonics already reduced to the target degree and
//  quantised to the file's bytes. About 56 bytes per splat plus the SH bytes,
//  where the importer's structs plus the writer's per-splat arrays cost several
//  hundred — the reason a 10 M-splat capture cooks in about a gigabyte.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Cooked splats in structure-of-arrays form. Floats are kept as floats — the writer quantises
/// them against each chunk's own ranges — and only the spherical harmonics, whose byte is a pure
/// per-value function (`quantizeGaussianSHCoefficient`), are stored in their final form.
struct UntoldGSSplatStore {
    private(set) var count = 0
    /// 3 per splat.
    private(set) var positions: [Float] = []
    /// 3 per splat, linear and strictly positive.
    private(set) var scales: [Float] = []
    /// 4 per splat in `simd_quatf.vector` order `(ix, iy, iz, r)`.
    private(set) var rotations: [Float] = []
    /// 3 per splat, display-referred 0…1.
    private(set) var colors: [Float] = []
    private(set) var opacities: [Float] = []
    /// Higher-order SH degree stored, 0…3.
    let shDegree: UInt8
    /// `UntoldGSFormat.shCoefficientCount(degree: shDegree)` bytes per splat.
    let shBytesPerSplat: Int
    /// `shBytesPerSplat` quantised coefficients per splat, channel-major.
    private(set) var sh: [UInt8] = []

    init(shDegree: UInt8) {
        self.shDegree = shDegree
        shBytesPerSplat = UntoldGSFormat.shCoefficientCount(degree: shDegree)
    }

    mutating func reserveCapacity(_ splats: Int) {
        positions.reserveCapacity(splats * 3)
        scales.reserveCapacity(splats * 3)
        rotations.reserveCapacity(splats * 4)
        colors.reserveCapacity(splats * 3)
        opacities.reserveCapacity(splats)
        sh.reserveCapacity(splats * shBytesPerSplat)
    }

    // MARK: - Access

    @inline(__always)
    func position(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(positions[3 * index], positions[3 * index + 1], positions[3 * index + 2])
    }

    @inline(__always)
    func scale(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(scales[3 * index], scales[3 * index + 1], scales[3 * index + 2])
    }

    @inline(__always)
    func rotation(_ index: Int) -> simd_quatf {
        simd_quatf(vector: SIMD4<Float>(rotations[4 * index], rotations[4 * index + 1], rotations[4 * index + 2], rotations[4 * index + 3]))
    }

    @inline(__always)
    func color(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(colors[3 * index], colors[3 * index + 1], colors[3 * index + 2])
    }

    @inline(__always)
    func opacity(_ index: Int) -> Float {
        opacities[index]
    }

    /// The writer's splat without its harmonics (the coarsener and the coarse levels never use them).
    @inline(__always)
    func splat(_ index: Int) -> UntoldGSSplat {
        UntoldGSSplat(position: position(index), scale: scale(index), rotation: rotation(index), color: color(index), opacity: opacity(index))
    }

    /// Largest scale magnitude: `gaussianMajorAxis` of the importer's splat.
    @inline(__always)
    func majorAxis(_ index: Int) -> Float {
        max(abs(scales[3 * index]), max(abs(scales[3 * index + 1]), abs(scales[3 * index + 2])))
    }

    /// The writer's importance, `opacity × (σxσy + σyσz + σzσx)` — `UntoldGSFormat.importance`.
    @inline(__always)
    func writerImportance(_ index: Int) -> Float {
        let sx = scales[3 * index], sy = scales[3 * index + 1], sz = scales[3 * index + 2]
        return opacities[index] * (sx * sy + sy * sz + sz * sx)
    }

    /// The cooker's budget importance, `opacity × ∛volume` — `UntoldGSCooker.importance(of:)`.
    @inline(__always)
    func budgetImportance(_ index: Int) -> Float {
        let volume = max(scales[3 * index] * scales[3 * index + 1] * scales[3 * index + 2], 0)
        return opacities[index] * cbrt(volume)
    }

    /// The splat's SH bytes.
    @inline(__always)
    func shRange(_ index: Int) -> Range<Int> {
        (index * shBytesPerSplat) ..< ((index + 1) * shBytesPerSplat)
    }

    // MARK: - Building

    /// Appends one splat; `shBytes` must hold `shBytesPerSplat` values.
    mutating func append(_ splat: UntoldGSSplat, shBytes: some Collection<UInt8>) {
        positions.append(splat.position.x)
        positions.append(splat.position.y)
        positions.append(splat.position.z)
        scales.append(splat.scale.x)
        scales.append(splat.scale.y)
        scales.append(splat.scale.z)
        let q = splat.rotation.vector
        rotations.append(q.x)
        rotations.append(q.y)
        rotations.append(q.z)
        rotations.append(q.w)
        colors.append(splat.color.x)
        colors.append(splat.color.y)
        colors.append(splat.color.z)
        opacities.append(splat.opacity)
        sh.append(contentsOf: shBytes)
        count += 1
    }

    /// Appends every splat of `other` (the same degree), in order.
    mutating func append(contentsOf other: UntoldGSSplatStore) {
        precondition(other.shDegree == shDegree)
        positions.append(contentsOf: other.positions)
        scales.append(contentsOf: other.scales)
        rotations.append(contentsOf: other.rotations)
        colors.append(contentsOf: other.colors)
        opacities.append(contentsOf: other.opacities)
        sh.append(contentsOf: other.sh)
        count += other.count
    }

    /// Keeps the splats at `indices` (ascending) and drops the rest, in place.
    mutating func compact(keeping indices: [Int]) {
        guard indices.count < count else { return }
        var target = 0
        for source in indices {
            if source != target {
                for k in 0 ..< 3 {
                    positions[3 * target + k] = positions[3 * source + k]
                    scales[3 * target + k] = scales[3 * source + k]
                    colors[3 * target + k] = colors[3 * source + k]
                }
                for k in 0 ..< 4 {
                    rotations[4 * target + k] = rotations[4 * source + k]
                }
                opacities[target] = opacities[source]
                for k in 0 ..< shBytesPerSplat {
                    sh[target * shBytesPerSplat + k] = sh[source * shBytesPerSplat + k]
                }
            }
            target += 1
        }
        count = target
        positions.removeLast(positions.count - 3 * count)
        scales.removeLast(scales.count - 3 * count)
        rotations.removeLast(rotations.count - 4 * count)
        colors.removeLast(colors.count - 3 * count)
        opacities.removeLast(opacities.count - count)
        sh.removeLast(sh.count - shBytesPerSplat * count)
    }

    // MARK: - Whole-store facts

    /// Bounds of the centres, or the empty (inverted) box.
    func centerBounds() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        var minimum = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maximum = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for index in 0 ..< count {
            let p = position(index)
            minimum = simd_min(minimum, p)
            maximum = simd_max(maximum, p)
        }
        return (minimum, maximum)
    }

    /// `computeGaussianSplatBoundingBox` of the importer's splats: centres grown by their major axis.
    func expandedBoundingBox() -> (min: SIMD3<Float>, max: SIMD3<Float>) {
        guard count > 0 else { return (min: .zero, max: .zero) }
        return UntoldGSFormat.expandedBoundingBox(count: count, position: { position($0) }, radius: { majorAxis($0) })
    }

    /// `meanSquaredSplatExtent` over `indices` in that order: a sequential `Float` sum, as the
    /// header word has always been computed (the sum is not associative).
    func meanSquaredSplatExtent(over indices: some Sequence<Int>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        let sumOfSquares = indices.reduce(Float(0)) { partial, index in
            let majorAxis = majorAxis(index)
            return partial + majorAxis * majorAxis
        }
        return sumOfSquares / Float(count)
    }
}

/// A tier of a store: every splat (`indices == nil`) or a subset in a given order, the way the
/// progressive bake hands each `_lodN` tier its ranked prefix. Positions in the view are the
/// writer's splat indices; the store index behind each is `storeIndex(_:)`.
struct UntoldGSStoreView {
    let store: UntoldGSSplatStore
    let indices: [Int]?

    init(store: UntoldGSSplatStore, indices: [Int]? = nil) {
        self.store = store
        self.indices = indices
    }

    var count: Int {
        indices?.count ?? store.count
    }

    @inline(__always)
    func storeIndex(_ position: Int) -> Int {
        indices?[position] ?? position
    }

    @inline(__always)
    func position(_ index: Int) -> SIMD3<Float> {
        store.position(storeIndex(index))
    }

    @inline(__always)
    func splat(_ index: Int) -> UntoldGSSplat {
        store.splat(storeIndex(index))
    }

    /// Runs `body` with raw pointers into the view's arrays — what a hot loop that several
    /// threads run at once must use: an array subscript in an unoptimised build retains and
    /// releases the shared buffer, and sixteen cores contending on one reference count turn a
    /// two-second cook into minutes. The pointers are valid inside `body` only.
    func withUnsafePointers<Result>(_ body: (UntoldGSStorePointers) throws -> Result) rethrows -> Result {
        try store.positions.withUnsafeBufferPointer { positions in
            try store.scales.withUnsafeBufferPointer { scales in
                try store.rotations.withUnsafeBufferPointer { rotations in
                    try store.colors.withUnsafeBufferPointer { colors in
                        try store.opacities.withUnsafeBufferPointer { opacities in
                            try store.sh.withUnsafeBufferPointer { sh in
                                try withOptionalIndices { indices in
                                    try body(UntoldGSStorePointers(
                                        positions: positions, scales: scales, rotations: rotations, colors: colors,
                                        opacities: opacities, sh: sh, shBytesPerSplat: store.shBytesPerSplat, indices: indices
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func withOptionalIndices<Result>(_ body: (UnsafeBufferPointer<Int>?) throws -> Result) rethrows -> Result {
        if let indices {
            return try indices.withUnsafeBufferPointer { try body($0) }
        }
        return try body(nil)
    }
}

/// Raw pointers into a `UntoldGSStoreView`, from `withUnsafePointers`. `storeIndex(_:)` maps a
/// view position to the store; the accessors take store indices.
struct UntoldGSStorePointers {
    let positions: UnsafeBufferPointer<Float>
    let scales: UnsafeBufferPointer<Float>
    let rotations: UnsafeBufferPointer<Float>
    let colors: UnsafeBufferPointer<Float>
    let opacities: UnsafeBufferPointer<Float>
    let sh: UnsafeBufferPointer<UInt8>
    let shBytesPerSplat: Int
    let indices: UnsafeBufferPointer<Int>?

    @inline(__always)
    func storeIndex(_ position: Int) -> Int {
        if let indices {
            return indices[position]
        }
        return position
    }

    @inline(__always)
    func position(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(positions[3 * index], positions[3 * index + 1], positions[3 * index + 2])
    }

    @inline(__always)
    func scale(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(scales[3 * index], scales[3 * index + 1], scales[3 * index + 2])
    }

    @inline(__always)
    func rotation(_ index: Int) -> simd_quatf {
        simd_quatf(vector: SIMD4<Float>(rotations[4 * index], rotations[4 * index + 1], rotations[4 * index + 2], rotations[4 * index + 3]))
    }

    @inline(__always)
    func color(_ index: Int) -> SIMD3<Float> {
        SIMD3<Float>(colors[3 * index], colors[3 * index + 1], colors[3 * index + 2])
    }

    @inline(__always)
    func opacity(_ index: Int) -> Float {
        opacities[index]
    }

    /// `UntoldGSSplatStore.splat(_:)`.
    @inline(__always)
    func splat(_ index: Int) -> UntoldGSSplat {
        UntoldGSSplat(position: position(index), scale: scale(index), rotation: rotation(index), color: color(index), opacity: opacity(index))
    }

    /// `UntoldGSSplatStore.writerImportance(_:)`.
    @inline(__always)
    func writerImportance(_ index: Int) -> Float {
        let sx = scales[3 * index], sy = scales[3 * index + 1], sz = scales[3 * index + 2]
        return opacities[index] * (sx * sy + sy * sz + sz * sx)
    }
}
