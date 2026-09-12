//
//  UntoldGSCoarsener.swift
//  UntoldEngine
//
//  Builds the merged coarse levels of one `.untoldgs` chunk: a weighted Lloyd
//  clustering over the chunk's Morton order with a linear-colour term, a
//  moment-matched Gaussian per cluster (mixture mean and covariance, coverage
//  opacity, linear-space colour), a deterministic Jacobi eigensolve back to a
//  rotation and a scale, and a second level built hierarchically over the first.
//  Pure functions in a fixed evaluation order, so a bake is bit-reproducible run
//  to run and independent of how the writer schedules chunks across threads.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// How the writer bakes the per-chunk coarse levels (`UntoldGSWriteOptions.coarseLevels`).
public struct UntoldGSCoarseLevelOptions: Sendable, Equatable {
    /// Levels to bake, 1 or 2.
    public var levelCount: Int = 2
    /// Level L holds `max(1, n >> ratioLog2[L − 1])` merged splats of a chunk of `n` fine splats.
    /// Strictly increasing; at least `levelCount` entries, each 1…`log2ChunkSplats`.
    public var ratioLog2: [UInt8] = [3, 6]
    /// Chunks with fewer fine splats get no coarse level.
    public var minimumChunkSplats: Int = 16
    /// Weighted Lloyd refinement passes over the Morton seeds (0 keeps the seeds).
    public var refinementPasses: Int = 6
    /// Colour term of the clustering metric, in world units per unit of linear-colour distance,
    /// as a fraction of the chunk's mean fine major axis (0 = spatial only).
    public var colourWeightScale: Float = 0.25

    public init() {}

    public static let `default` = UntoldGSCoarseLevelOptions()

    /// The ratio of level `level` (1-based).
    public func ratio(level: Int) -> UInt8 {
        ratioLog2[level - 1]
    }

    /// Checks the options against a chunk size; `UntoldGSError.invalidInput` names the fault.
    public func validate(log2ChunkSplats: UInt8) throws {
        guard levelCount >= 1, levelCount <= UntoldGSFormat.maxCoarseLevels else {
            throw UntoldGSError.invalidInput("coarse level count \(levelCount) is not 1…\(UntoldGSFormat.maxCoarseLevels)")
        }
        guard ratioLog2.count >= levelCount else {
            throw UntoldGSError.invalidInput("coarse ratios \(ratioLog2) do not cover \(levelCount) levels")
        }
        var previous: UInt8 = 0
        for level in 0 ..< levelCount {
            let ratio = ratioLog2[level]
            guard ratio > previous, ratio <= log2ChunkSplats else {
                throw UntoldGSError.invalidInput("coarse ratios \(ratioLog2) must increase strictly within 1…\(log2ChunkSplats)")
            }
            previous = ratio
        }
        guard refinementPasses >= 0, minimumChunkSplats >= 1, colourWeightScale >= 0, colourWeightScale.isFinite else {
            throw UntoldGSError.invalidInput("coarse level options out of range")
        }
    }

    /// These options with the ratios clamped to a chunk size, collapsing to fewer levels where
    /// two would coincide — what `coarseLevelsAutomatic` bakes for a tier whose chunks are smaller
    /// than the ratios assume (a 16-splat chunk cannot hold a 1 : 64 level).
    public func clamped(toLog2ChunkSplats log2ChunkSplats: UInt8) -> UntoldGSCoarseLevelOptions {
        var options = self
        var kept: [UInt8] = []
        for ratio in ratioLog2.prefix(levelCount).map({ min($0, log2ChunkSplats) }) where ratio > (kept.last ?? 0) {
            kept.append(ratio)
        }
        options.levelCount = kept.count
        options.ratioLog2 = kept
        return options
    }
}

/// The merged levels of one chunk, each ordered by importance descending (rank 0 first).
public struct UntoldGSCoarseLevels: Sendable, Equatable {
    public var l1: [UntoldGSSplat]
    public var l2: [UntoldGSSplat]

    public init(l1: [UntoldGSSplat] = [], l2: [UntoldGSSplat] = []) {
        self.l1 = l1
        self.l2 = l2
    }

    public static let none = UntoldGSCoarseLevels()

    /// The splats of level `level` (1-based); empty for an absent level.
    public func level(_ level: Int) -> [UntoldGSSplat] {
        switch level {
        case 1: l1
        case 2: l2
        default: []
        }
    }
}

public enum UntoldGSCoarsener {
    /// Merges one chunk's fine splats (in Morton order) into its coarse levels. Every merged splat
    /// is finite; a non-finite result is a cooker bug and throws `UntoldGSError.invalidInput`.
    public static func coarsen(_ splats: [UntoldGSSplat], options: UntoldGSCoarseLevelOptions) throws -> UntoldGSCoarseLevels {
        let n = splats.count
        guard n >= options.minimumChunkSplats, options.levelCount >= 1, !splats.isEmpty else { return .none }
        let stats = ChunkStatistics(splats)
        let colourWeight = options.colourWeightScale * stats.meanMajorAxis

        let m1 = max(1, n >> Int(options.ratio(level: 1)))
        let l1 = try mergeLevel(splats, clusterCount: m1, options: options, colourWeight: colourWeight, stats: stats)
        guard options.levelCount >= 2 else {
            return UntoldGSCoarseLevels(l1: orderedByImportance(l1))
        }
        let m2 = max(1, n >> Int(options.ratio(level: 2)))
        // Hierarchical: the second level merges the first (in cluster order, which follows the
        // Morton order), so the two levels agree on coverage and colour.
        let l2 = try mergeLevel(l1, clusterCount: m2, options: options, colourWeight: colourWeight, stats: stats)
        return UntoldGSCoarseLevels(l1: orderedByImportance(l1), l2: orderedByImportance(l2))
    }

    /// The writer's importance, `opacity × (σxσy + σyσz + σzσx)`: the clustering weight.
    static func weight(_ splat: UntoldGSSplat) -> Float {
        UntoldGSFormat.importance(splat)
    }

    /// Indices sorted by importance descending, ties by index — the rank order of a level.
    static func orderedByImportance(_ splats: [UntoldGSSplat]) -> [UntoldGSSplat] {
        let importance = splats.map(weight)
        return splats.indices.sorted { a, b in
            importance[a] != importance[b] ? importance[a] > importance[b] : a < b
        }.map { splats[$0] }
    }

    // MARK: - Per-chunk facts

    /// The fine chunk's figures every level is clamped against.
    struct ChunkStatistics {
        /// Mean of the splats' largest scale: the colour term's unit.
        var meanMajorAxis: Float
        /// The smallest fine σ: a merged σ never falls below it.
        var minimumScale: Float
        /// The centre AABB diagonal plus the largest fine σ: a merged σ never exceeds it.
        var maximumScale: Float

        init(_ splats: [UntoldGSSplat]) {
            var majorSum: Float = 0
            var minimum = Float.greatestFiniteMagnitude
            var maximum: Float = 0
            var aabbMin = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var aabbMax = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for splat in splats {
                majorSum += splat.scale.max()
                minimum = min(minimum, splat.scale.min())
                maximum = max(maximum, splat.scale.max())
                aabbMin = simd_min(aabbMin, splat.position)
                aabbMax = simd_max(aabbMax, splat.position)
            }
            meanMajorAxis = splats.isEmpty ? 0 : majorSum / Float(splats.count)
            minimumScale = splats.isEmpty ? 0 : minimum
            maximumScale = splats.isEmpty ? 0 : simd_length(aabbMax - aabbMin) + maximum
        }
    }

    // MARK: - Level

    private static func mergeLevel(
        _ members: [UntoldGSSplat],
        clusterCount: Int,
        options: UntoldGSCoarseLevelOptions,
        colourWeight: Float,
        stats: ChunkStatistics
    ) throws -> [UntoldGSSplat] {
        let k = min(clusterCount, members.count)
        let weights = members.map(weight)
        let linear = members.map { UntoldGSColor.linear(fromDisplay: $0.color) }
        let assignment = cluster(
            positions: members.map(\.position), colours: linear, weights: weights,
            clusterCount: k, passes: options.refinementPasses, colourWeight: colourWeight
        )
        var clusters = [[Int]](repeating: [], count: k)
        for (index, c) in assignment.enumerated() {
            clusters[c].append(index)
        }
        var level: [UntoldGSSplat] = []
        level.reserveCapacity(k)
        for cluster in clusters {
            let merged = merge(cluster.map { members[$0] }, weights: cluster.map { weights[$0] }, linearColours: cluster.map { linear[$0] }, stats: stats)
            guard merged.isFinite else {
                throw UntoldGSError.invalidInput("coarsening produced a non-finite splat")
            }
            level.append(merged)
        }
        return level
    }

    // MARK: - Clustering

    /// Weighted Lloyd over `clusterCount` seeds cut from the input order as equal sub-ranges.
    /// Distance is `|μ_i − μ_k|² + colourWeight² |c_i − c_k|²`; assignment goes to the nearest
    /// centre, ties to the lower index; an emptied cluster is re-seeded with the member of the
    /// largest cluster farthest from its centre. Fixed iteration order, `Float` accumulation in
    /// member order: bit-reproducible. The inner loops run on scalar arrays through unsafe
    /// buffers and count with `while` — this is the bake's hot spot (`n × k × passes` distances
    /// per chunk), and a debug build pays for every bounds check, every generic `Range`
    /// iterator and every retain of a shared array otherwise.
    static func cluster(
        positions: [SIMD3<Float>],
        colours: [SIMD3<Float>],
        weights: [Float],
        clusterCount: Int,
        passes: Int,
        colourWeight: Float
    ) -> [Int] {
        let n = positions.count
        let k = max(1, min(clusterCount, n))
        var assignment = [Int](repeating: 0, count: n)
        var seed = 0
        while seed < n {
            assignment[seed] = min(k - 1, seed * k / n)
            seed += 1
        }
        guard k > 1, passes > 0 else { return assignment }

        let colourWeightSquared = colourWeight * colourWeight
        // Structure of arrays: member coordinates and colours, then the centres.
        var member = [Float](repeating: 0, count: 6 * n)
        var fill = 0
        while fill < n {
            let position = positions[fill]
            let colour = colours[fill]
            member[6 * fill] = position.x
            member[6 * fill + 1] = position.y
            member[6 * fill + 2] = position.z
            member[6 * fill + 3] = colour.x
            member[6 * fill + 4] = colour.y
            member[6 * fill + 5] = colour.z
            fill += 1
        }
        var centre = [Float](repeating: 0, count: 6 * k)
        var counts = [Int](repeating: 0, count: k)
        var weightSums = [Float](repeating: 0, count: k)
        var plainSums = [Float](repeating: 0, count: 6 * k)

        member.withUnsafeBufferPointer { memberBuffer in
            weights.withUnsafeBufferPointer { weightBuffer in
                centre.withUnsafeMutableBufferPointer { centreBuffer in
                    assignment.withUnsafeMutableBufferPointer { assignmentBuffer in
                        counts.withUnsafeMutableBufferPointer { countBuffer in
                            weightSums.withUnsafeMutableBufferPointer { weightSumBuffer in
                                plainSums.withUnsafeMutableBufferPointer { plainSumBuffer in
                                    guard let m = memberBuffer.baseAddress, let weights = weightBuffer.baseAddress,
                                          let c = centreBuffer.baseAddress, let a = assignmentBuffer.baseAddress,
                                          let count = countBuffer.baseAddress, let weightSums = weightSumBuffer.baseAddress,
                                          let plainSums = plainSumBuffer.baseAddress
                                    else { return }
                                    refine(
                                        n: n, k: k, passes: passes, colourWeightSquared: colourWeightSquared,
                                        m: m, weights: weights, c: c, a: a, count: count, weightSums: weightSums, plainSums: plainSums
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        return assignment
    }

    /// The Lloyd passes of `cluster` over raw buffers: `m` the 6-wide members, `c` the 6-wide
    /// centres, `a` the assignment, `count`, `weightSums` (k) and `plainSums` (6 k) scratch.
    private static func refine(
        n: Int, k: Int, passes: Int, colourWeightSquared: Float,
        m: UnsafePointer<Float>, weights: UnsafePointer<Float>,
        c: UnsafeMutablePointer<Float>, a: UnsafeMutablePointer<Int>, count: UnsafeMutablePointer<Int>,
        weightSums: UnsafeMutablePointer<Float>, plainSums: UnsafeMutablePointer<Float>
    ) {
        @inline(__always) func distance(_ index: Int, _ cluster: Int) -> Float {
            let mi = m + 6 * index
            let ci = c + 6 * cluster
            let dx = mi[0] - ci[0]
            let dy = mi[1] - ci[1]
            let dz = mi[2] - ci[2]
            let dr = mi[3] - ci[3]
            let dg = mi[4] - ci[4]
            let db = mi[5] - ci[5]
            return dx * dx + dy * dy + dz * dz + colourWeightSquared * (dr * dr + dg * dg + db * db)
        }

        var pass = 0
        while pass < passes {
            pass += 1
            // Centres: weighted means in member order (plain means where the weights vanish).
            var value = 0
            while value < 6 * k {
                c[value] = 0
                plainSums[value] = 0
                value += 1
            }
            var cluster = 0
            while cluster < k {
                weightSums[cluster] = 0
                count[cluster] = 0
                cluster += 1
            }
            var index = 0
            while index < n {
                let cluster = a[index]
                let w = weights[index]
                let mi = 6 * index
                let ci = 6 * cluster
                var component = 0
                while component < 6 {
                    c[ci + component] += w * m[mi + component]
                    plainSums[ci + component] += m[mi + component]
                    component += 1
                }
                weightSums[cluster] += w
                count[cluster] += 1
                index += 1
            }
            cluster = 0
            while cluster < k {
                if count[cluster] > 0 {
                    let ci = 6 * cluster
                    if weightSums[cluster] > 0 {
                        var component = 0
                        while component < 6 {
                            c[ci + component] /= weightSums[cluster]
                            component += 1
                        }
                    } else {
                        var component = 0
                        while component < 6 {
                            c[ci + component] = plainSums[ci + component] / Float(count[cluster])
                            component += 1
                        }
                    }
                }
                cluster += 1
            }

            // Assignment: the nearest centre, ties to the lower index.
            index = 0
            while index < n {
                var best = 0
                var bestDistance = distance(index, 0)
                var candidate = 1
                while candidate < k {
                    let d = distance(index, candidate)
                    if d < bestDistance {
                        bestDistance = d
                        best = candidate
                    }
                    candidate += 1
                }
                a[index] = best
                index += 1
            }

            // Re-seed emptied clusters from the largest one (ties to the lower index)
            // with its member farthest from the centre (ties to the lower member index).
            cluster = 0
            while cluster < k {
                count[cluster] = 0
                cluster += 1
            }
            index = 0
            while index < n {
                count[a[index]] += 1
                index += 1
            }
            var empty = 0
            while empty < k {
                if count[empty] == 0 {
                    var largest = 0
                    var candidate = 1
                    while candidate < k {
                        if count[candidate] > count[largest] {
                            largest = candidate
                        }
                        candidate += 1
                    }
                    if count[largest] > 1 {
                        var farthest = -1
                        var farthestDistance: Float = -1
                        var member = 0
                        while member < n {
                            if a[member] == largest {
                                let d = distance(member, largest)
                                if d > farthestDistance {
                                    farthestDistance = d
                                    farthest = member
                                }
                            }
                            member += 1
                        }
                        if farthest >= 0 {
                            a[farthest] = empty
                            count[largest] -= 1
                            count[empty] += 1
                            var component = 0
                            while component < 6 {
                                c[6 * empty + component] = m[6 * farthest + component]
                                component += 1
                            }
                        }
                    }
                }
                empty += 1
            }
        }
    }

    // MARK: - Merge

    /// The moment-matched Gaussian of `members` with `weights`: weighted mean, the mixture's
    /// second moment (within plus between) as covariance, opacity from the members' summed
    /// coverage against the merged area, colour averaged in linear space weighted by
    /// `weight × opacity`. Rotation and scale come from `jacobiEigen3`; σ is clamped to the
    /// chunk's `[minimumScale, maximumScale]`.
    static func merge(_ members: [UntoldGSSplat], weights: [Float], linearColours: [SIMD3<Float>]? = nil, stats: ChunkStatistics) -> UntoldGSSplat {
        precondition(!members.isEmpty && members.count == weights.count)
        let linear = linearColours ?? members.map { UntoldGSColor.linear(fromDisplay: $0.color) }

        var totalWeight: Double = 0
        var weightedPosition = SIMD3<Double>(repeating: 0)
        var plainPosition = SIMD3<Double>(repeating: 0)
        for (index, splat) in members.enumerated() {
            let w = Double(weights[index])
            totalWeight += w
            weightedPosition += w * SIMD3<Double>(splat.position)
            plainPosition += SIMD3<Double>(splat.position)
        }
        let uniform = totalWeight <= 0
        let count = Double(members.count)
        let mean = uniform ? plainPosition / count : weightedPosition / totalWeight

        var covariance = simd_double3x3()
        var colourSum = SIMD3<Double>(repeating: 0)
        var colourWeight: Double = 0
        var plainColour = SIMD3<Double>(repeating: 0)
        var coverage: Double = 0
        for (index, splat) in members.enumerated() {
            let w = uniform ? 1 / count : Double(weights[index]) / totalWeight
            let d = SIMD3<Double>(splat.position) - mean
            let fine = UntoldGSSplat.covariance(rotation: splat.rotation, scale: splat.scale)
            let within = simd_double3x3(columns: (SIMD3<Double>(fine.columns.0), SIMD3<Double>(fine.columns.1), SIMD3<Double>(fine.columns.2)))
            let between = simd_double3x3(columns: (d * d.x, d * d.y, d * d.z))
            covariance += w * (within + between)
            let cw = (uniform ? 1 : Double(weights[index])) * Double(splat.opacity)
            colourSum += cw * SIMD3<Double>(linear[index])
            colourWeight += cw
            plainColour += SIMD3<Double>(linear[index])
            coverage += Double(splat.opacity) * Double(projectedArea(splat.scale))
        }
        let symmetric = simd_float3x3(columns: (
            SIMD3<Float>(Float(covariance[0, 0]), Float((covariance[0, 1] + covariance[1, 0]) / 2), Float((covariance[0, 2] + covariance[2, 0]) / 2)),
            SIMD3<Float>(Float((covariance[0, 1] + covariance[1, 0]) / 2), Float(covariance[1, 1]), Float((covariance[1, 2] + covariance[2, 1]) / 2)),
            SIMD3<Float>(Float((covariance[0, 2] + covariance[2, 0]) / 2), Float((covariance[1, 2] + covariance[2, 1]) / 2), Float(covariance[2, 2]))
        ))
        let eigen = jacobiEigen3(symmetric)
        var scale = SIMD3<Float>(repeating: 0)
        for axis in 0 ..< 3 {
            let variance = max(eigen.values[axis], stats.minimumScale * stats.minimumScale)
            scale[axis] = min(max(variance.squareRoot(), stats.minimumScale), max(stats.maximumScale, stats.minimumScale))
        }
        var rotation = simd_quatf(eigen.vectors)
        if simd_length_squared(rotation.vector) > 0 {
            rotation = simd_normalize(rotation)
        } else {
            rotation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
        }
        if rotation.real < 0 {
            rotation = simd_quatf(vector: -rotation.vector)
        }

        // Members of zero opacity contribute no light: fall back to the plain mean.
        let colour = colourWeight > 0 ? SIMD3<Float>(colourSum / colourWeight) : SIMD3<Float>(plainColour / count)
        let opacity = coverageOpacity(summedCoverage: Float(coverage), mergedArea: projectedArea(scale))
        return UntoldGSSplat(
            position: SIMD3<Float>(mean),
            scale: scale,
            rotation: rotation,
            color: simd_clamp(UntoldGSColor.display(fromLinear: colour), SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1)),
            opacity: opacity
        )
    }

    /// `(σxσy + σyσz + σzσx) / 3`: the rotationally averaged projected area of a Gaussian.
    static func projectedArea(_ scale: SIMD3<Float>) -> Float {
        (scale.x * scale.y + scale.y * scale.z + scale.z * scale.x) / 3
    }

    /// `1 − exp(−Σ α_i s_i / s_M)`: the coverage of overlapping members composited over the merged
    /// footprint — an opaque wall saturates to 1, a sparse cluster stays near linear. In 0…1.
    static func coverageOpacity(summedCoverage: Float, mergedArea: Float) -> Float {
        guard mergedArea > 0, summedCoverage > 0 else { return 0 }
        return min(max(1 - exp(-summedCoverage / mergedArea), 0), 1)
    }

    /// `coverageOpacity` over members: `Σ α_i s_i` against the merged area.
    static func coverageOpacity(members: [UntoldGSSplat], mergedArea: Float) -> Float {
        var summed: Float = 0
        for splat in members {
            summed += splat.opacity * projectedArea(splat.scale)
        }
        return coverageOpacity(summedCoverage: summed, mergedArea: mergedArea)
    }

    // MARK: - Eigensolve

    /// Cyclic Jacobi on a symmetric 3×3 matrix: sweeps over (0,1), (0,2), (1,2) in that order, at
    /// most 12 sweeps, stopping when the off-diagonal norm falls below 1e-12 × trace. Returns the
    /// eigenvalues and a right-handed (det +1) orthonormal matrix whose columns are the
    /// eigenvectors, so `vectors × diag(values) × vectorsᵀ` reproduces the input. Deterministic.
    static func jacobiEigen3(_ input: simd_float3x3) -> (values: SIMD3<Float>, vectors: simd_float3x3) {
        var a = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for row in 0 ..< 3 {
            for column in 0 ..< 3 {
                a[row][column] = Double((input[column, row] + input[row, column]) / 2)
            }
        }
        var v = [[Double]](repeating: [Double](repeating: 0, count: 3), count: 3)
        for i in 0 ..< 3 {
            v[i][i] = 1
        }
        let trace = abs(a[0][0]) + abs(a[1][1]) + abs(a[2][2])
        let pairs = [(0, 1), (0, 2), (1, 2)]
        for _ in 0 ..< 12 {
            let off = (a[0][1] * a[0][1] + a[0][2] * a[0][2] + a[1][2] * a[1][2]).squareRoot()
            if off <= 1e-12 * trace || off == 0 {
                break
            }
            for (p, q) in pairs where a[p][q] != 0 {
                let theta = (a[q][q] - a[p][p]) / (2 * a[p][q])
                let t = (theta >= 0 ? 1.0 : -1.0) / (abs(theta) + (theta * theta + 1).squareRoot())
                let c = 1 / (t * t + 1).squareRoot()
                let s = t * c
                for k in 0 ..< 3 {
                    let akp = a[k][p]
                    let akq = a[k][q]
                    a[k][p] = c * akp - s * akq
                    a[k][q] = s * akp + c * akq
                }
                for k in 0 ..< 3 {
                    let apk = a[p][k]
                    let aqk = a[q][k]
                    a[p][k] = c * apk - s * aqk
                    a[q][k] = s * apk + c * aqk
                }
                for k in 0 ..< 3 {
                    let vkp = v[k][p]
                    let vkq = v[k][q]
                    v[k][p] = c * vkp - s * vkq
                    v[k][q] = s * vkp + c * vkq
                }
            }
        }
        var columns = (0 ..< 3).map { column in SIMD3<Float>(Float(v[0][column]), Float(v[1][column]), Float(v[2][column])) }
        let determinant = simd_dot(columns[0], simd_cross(columns[1], columns[2]))
        if determinant < 0 {
            columns[2] = -columns[2]
        }
        return (
            SIMD3<Float>(Float(a[0][0]), Float(a[1][1]), Float(a[2][2])),
            simd_float3x3(columns: (columns[0], columns[1], columns[2]))
        )
    }
}
