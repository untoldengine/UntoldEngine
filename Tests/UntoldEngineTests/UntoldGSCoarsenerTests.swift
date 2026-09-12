//
//  UntoldGSCoarsenerTests.swift
//  UntoldEngineTests
//
//  Oracles for the per-chunk coarse levels of `.untoldgs` v3: the merge of
//  identical splats, the analytic moments of tight clusters, the colour term
//  of the clustering, the coverage opacity, the Jacobi eigensolve, the rank
//  order of a level, the chunk-size floor and the bit-identical bake.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class UntoldGSCoarsenerTests: XCTestCase {
    private let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)

    private func isotropic(_ position: SIMD3<Float>, radius: Float, color: SIMD3<Float> = [0.5, 0.5, 0.5], opacity: Float = 1) -> UntoldGSSplat {
        UntoldGSSplat(position: position, scale: SIMD3<Float>(repeating: radius), rotation: identity, color: color, opacity: opacity)
    }

    private func covariance(_ splat: UntoldGSSplat) -> simd_float3x3 {
        UntoldGSSplat.covariance(rotation: splat.rotation, scale: splat.scale)
    }

    private func assertEqual(_ a: simd_float3x3, _ b: simd_float3x3, relative: Float, file: StaticString = #filePath, line: UInt = #line) {
        var norm: Float = 0
        for column in 0 ..< 3 {
            norm = max(norm, simd_length(b[column]))
        }
        for column in 0 ..< 3 {
            for row in 0 ..< 3 {
                XCTAssertEqual(a[column, row], b[column, row], accuracy: relative * norm + 1e-7, "[\(column), \(row)]", file: file, line: line)
            }
        }
    }

    // MARK: - Merge

    func testIdenticalSplatsMergeToOneSaturating() throws {
        let r: Float = 0.1
        let members = (0 ..< 8).map { _ in isotropic([1, 2, 3], radius: r, color: [0.2, 0.4, 0.8], opacity: 1) }
        var options = UntoldGSCoarseLevelOptions()
        options.levelCount = 1
        options.ratioLog2 = [3]
        options.minimumChunkSplats = 8
        let levels = try UntoldGSCoarsener.coarsen(members, options: options)
        XCTAssertEqual(levels.l1.count, 1)
        XCTAssertEqual(levels.l2, [])
        let merged = levels.l1[0]
        XCTAssertEqual(merged.position, [1, 2, 3])
        for axis in 0 ..< 3 {
            XCTAssertEqual(merged.scale[axis], r, accuracy: 1e-5, "no spread between identical centres: σ is the members'")
        }
        XCTAssertEqual(merged.opacity, 1 - exp(-8), accuracy: 1e-4, "eight opaque members over one footprint saturate")
        for channel in 0 ..< 3 {
            XCTAssertEqual(merged.color[channel], members[0].color[channel], accuracy: 1e-5)
        }
        // The same through `merge` alone.
        let stats = UntoldGSCoarsener.ChunkStatistics(members)
        let direct = UntoldGSCoarsener.merge(members, weights: members.map(UntoldGSCoarsener.weight), stats: stats)
        XCTAssertEqual(direct.position, merged.position)
        XCTAssertEqual(direct.opacity, merged.opacity, accuracy: 1e-6)
    }

    /// k tight clusters of N identical isotropic splats whose merged Gaussian is closed-form: the
    /// mean is the cluster mean, the covariance `r² I + S` (S the members' centre covariance), the
    /// opacity `1 − exp(−N α r² / s_M)`, and the colour the linear-space mean of a two-colour cluster.
    func testClustersRecoverAnalyticMoments() throws {
        let k = 8
        let n = 128
        let r: Float = 0.02
        let alpha: Float = 0.6
        let red = SIMD3<Float>(0.9, 0.1, 0.1)
        let white = SIMD3<Float>(0.95, 0.95, 0.95)
        var rng = SplitMix64(seed: 77)
        var members: [UntoldGSSplat] = []
        var offsets: [[SIMD3<Float>]] = []
        for cluster in 0 ..< k {
            let centre = SIMD3<Float>(Float(cluster) * 1.0, 0.3 * Float(cluster % 2), 0)
            var clusterOffsets: [SIMD3<Float>] = []
            for member in 0 ..< n {
                let offset = SIMD3<Float>(rng.nextFloat(in: -0.05 ... 0.05), rng.nextFloat(in: -0.02 ... 0.02), rng.nextFloat(in: -0.08 ... 0.08))
                clusterOffsets.append(offset)
                members.append(isotropic(centre + offset, radius: r, color: member % 2 == 0 ? red : white, opacity: alpha))
            }
            offsets.append(clusterOffsets)
        }
        var options = UntoldGSCoarseLevelOptions()
        options.levelCount = 2
        options.ratioLog2 = [7, 10] // 1024 → 8 and 1
        let levels = try UntoldGSCoarsener.coarsen(members, options: options)
        XCTAssertEqual(levels.l1.count, 8)
        XCTAssertEqual(levels.l2.count, 1)

        let expectedColour = UntoldGSColor.display(fromLinear: (UntoldGSColor.linear(fromDisplay: red) + UntoldGSColor.linear(fromDisplay: white)) / 2)
        for cluster in 0 ..< k {
            let centre = SIMD3<Float>(Float(cluster) * 1.0, 0.3 * Float(cluster % 2), 0)
            var mean = SIMD3<Float>(repeating: 0)
            for offset in offsets[cluster] {
                mean += offset
            }
            mean /= Float(n)
            var spread = simd_float3x3(0)
            for offset in offsets[cluster] {
                let d = offset - mean
                spread += simd_float3x3(columns: (d * d.x, d * d.y, d * d.z))
            }
            spread = spread * (1 / Float(n))
            let expected = spread + simd_float3x3(diagonal: SIMD3<Float>(repeating: r * r))

            // Levels are ordered by importance; find the record nearest the cluster mean.
            let merged = try XCTUnwrap(levels.l1.min { simd_distance($0.position, centre + mean) < simd_distance($1.position, centre + mean) })
            XCTAssertLessThan(simd_distance(merged.position, centre + mean), 1e-4)
            assertEqual(covariance(merged), expected, relative: 0.05)
            let mergedArea = UntoldGSCoarsener.projectedArea(merged.scale)
            let expectedOpacity = 1 - exp(-Float(n) * alpha * r * r / mergedArea)
            XCTAssertEqual(merged.opacity, expectedOpacity, accuracy: 0.02 * expectedOpacity)
            for channel in 0 ..< 3 {
                XCTAssertEqual(merged.color[channel], expectedColour[channel], accuracy: 2e-3, "linear-space mean of the two colours")
            }
            XCTAssertGreaterThanOrEqual(merged.rotation.real, 0)
            XCTAssertEqual(simd_length(merged.rotation.vector), 1, accuracy: 1e-5)
        }

        // L2 is the same formula over the eight L1 records.
        let stats = UntoldGSCoarsener.ChunkStatistics(members)
        let l2 = UntoldGSCoarsener.merge(levels.l1, weights: levels.l1.map(UntoldGSCoarsener.weight), stats: stats)
        XCTAssertLessThan(simd_distance(levels.l2[0].position, l2.position), 1e-4)
        assertEqual(covariance(levels.l2[0]), covariance(l2), relative: 1e-3)
        XCTAssertEqual(levels.l2[0].opacity, l2.opacity, accuracy: 1e-4)
        for channel in 0 ..< 3 {
            XCTAssertEqual(levels.l2[0].color[channel], l2.color[channel], accuracy: 1e-4)
        }
    }

    // MARK: - Clustering

    /// A run of Morton neighbours, red and white splats at the same positions ± ε: the colour
    /// term puts each colour in its own cluster; without it the clusters split by position.
    func testColourTermSeparatesStraddlingRun() throws {
        let red = UntoldGSColor.linear(fromDisplay: [1, 0, 0])
        let white = UntoldGSColor.linear(fromDisplay: [1, 1, 1])
        var positions: [SIMD3<Float>] = []
        var colours: [SIMD3<Float>] = []
        // 32 along x, 0.0005 apart; the first half mostly red, the second mostly white.
        for index in 0 ..< 32 {
            let isRed = index < 16 ? index % 4 != 3 : index % 4 == 3
            positions.append(SIMD3<Float>(Float(index) * 0.0005 + (isRed ? -0.0001 : 0.0001), 0, 0))
            colours.append(isRed ? red : white)
        }
        let weights = [Float](repeating: 1, count: 32)
        let meanMajorAxis: Float = 0.1

        let separated = UntoldGSCoarsener.cluster(positions: positions, colours: colours, weights: weights, clusterCount: 2, passes: 6, colourWeight: 0.25 * meanMajorAxis)
        for cluster in 0 ..< 2 {
            let memberColours = Set((0 ..< 32).filter { separated[$0] == cluster }.map { colours[$0] == red ? "red" : "white" })
            XCTAssertEqual(memberColours.count, 1, "cluster \(cluster) holds one colour")
        }
        XCTAssertEqual(separated.filter { $0 == 0 }.count, 16)

        let mixed = UntoldGSCoarsener.cluster(positions: positions, colours: colours, weights: weights, clusterCount: 2, passes: 6, colourWeight: 0)
        for cluster in 0 ..< 2 {
            let memberColours = Set((0 ..< 32).filter { mixed[$0] == cluster }.map { colours[$0] == red ? "red" : "white" })
            XCTAssertEqual(memberColours.count, 2, "cluster \(cluster) mixes the colours")
        }
        XCTAssertEqual(mixed, (0 ..< 32).map { $0 < 16 ? 0 : 1 }, "spatial only: the two halves of the run")

        // The whole merge: two records, one pure red and one pure white.
        let splats = (0 ..< 32).map { isotropic(positions[$0], radius: meanMajorAxis, color: colours[$0] == red ? [1, 0, 0] : [1, 1, 1]) }
        var options = UntoldGSCoarseLevelOptions()
        options.levelCount = 1
        options.ratioLog2 = [4]
        let levels = try UntoldGSCoarsener.coarsen(splats, options: options)
        XCTAssertEqual(levels.l1.count, 2)
        let sorted = levels.l1.sorted { $0.color.y < $1.color.y }
        XCTAssertEqual(sorted[0].color.y, 0, accuracy: 1e-5)
        XCTAssertEqual(sorted[1].color.y, 1, accuracy: 1e-5)
    }

    func testSeedsAreEqualSubrangesAndEmptyClustersAreReseeded() {
        let positions = (0 ..< 10).map { SIMD3<Float>(Float($0), 0, 0) }
        let colours = [SIMD3<Float>](repeating: .zero, count: 10)
        let weights = [Float](repeating: 1, count: 10)
        XCTAssertEqual(UntoldGSCoarsener.cluster(positions: positions, colours: colours, weights: weights, clusterCount: 4, passes: 0, colourWeight: 0), [0, 0, 0, 1, 1, 2, 2, 2, 3, 3])
        XCTAssertEqual(UntoldGSCoarsener.cluster(positions: positions, colours: colours, weights: weights, clusterCount: 1, passes: 6, colourWeight: 0), [Int](repeating: 0, count: 10))
        // Two coincident groups and three clusters: one cluster empties after the first pass and
        // is re-seeded from the largest, so every cluster keeps a member.
        let coincident = (0 ..< 12).map { SIMD3<Float>($0 < 6 ? 0 : 5, 0, 0) }
        let assignment = UntoldGSCoarsener.cluster(positions: coincident, colours: [SIMD3<Float>](repeating: .zero, count: 12), weights: [Float](repeating: 1, count: 12), clusterCount: 3, passes: 4, colourWeight: 0)
        XCTAssertEqual(Set(assignment).count, 3)
    }

    // MARK: - Opacity and eigensolve

    func testCoverageOpacityIsBoundedAndMonotone() {
        XCTAssertEqual(UntoldGSCoarsener.coverageOpacity(summedCoverage: 0, mergedArea: 1), 0)
        XCTAssertEqual(UntoldGSCoarsener.coverageOpacity(summedCoverage: 1, mergedArea: 0), 0)
        var previous: Float = 0
        for step in 1 ... 40 {
            let summed = Float(step) * 0.25
            let opacity = UntoldGSCoarsener.coverageOpacity(summedCoverage: summed, mergedArea: 1)
            XCTAssertGreaterThan(opacity, previous)
            XCTAssertLessThanOrEqual(opacity, 1)
            XCTAssertLessThanOrEqual(opacity, summed, "never above the linear sum")
            previous = opacity
        }
        XCTAssertEqual(UntoldGSCoarsener.coverageOpacity(summedCoverage: 0.01, mergedArea: 1), 0.01, accuracy: 1e-4, "sparse: linear")
        XCTAssertEqual(UntoldGSCoarsener.coverageOpacity(summedCoverage: 20, mergedArea: 1), 1, accuracy: 1e-6, "dense: saturated")
        XCTAssertGreaterThan(
            UntoldGSCoarsener.coverageOpacity(summedCoverage: 1, mergedArea: 1),
            UntoldGSCoarsener.coverageOpacity(summedCoverage: 1, mergedArea: 2),
            "a larger merged footprint spreads the same coverage thinner"
        )
        let members = (0 ..< 4).map { _ in isotropic(.zero, radius: 0.5, opacity: 0.5) }
        XCTAssertEqual(UntoldGSCoarsener.coverageOpacity(members: members, mergedArea: 0.25), 1 - exp(-2), accuracy: 1e-6)
    }

    func testJacobiIsDeterministicAndOrthonormal() {
        var rng = SplitMix64(seed: 99)
        for _ in 0 ..< 200 {
            var m = simd_float3x3(0)
            for column in 0 ..< 3 {
                for row in 0 ... column {
                    let value = rng.nextFloat(in: -2 ... 2) * (row == column ? 4 : 1)
                    m[column, row] = value
                    m[row, column] = value
                }
            }
            let first = UntoldGSCoarsener.jacobiEigen3(m)
            let second = UntoldGSCoarsener.jacobiEigen3(m)
            XCTAssertEqual(first.values, second.values, "bit-identical across runs")
            XCTAssertEqual(first.vectors, second.vectors)
            let v = first.vectors
            let reconstructed = v * simd_float3x3(diagonal: first.values) * v.transpose
            assertEqual(reconstructed, m, relative: 1e-5)
            assertEqual(v.transpose * v, matrix_identity_float3x3, relative: 1e-5)
            XCTAssertEqual(simd_determinant(v), 1, accuracy: 1e-5, "right-handed")
        }
        // The trivial cases.
        let diagonal = UntoldGSCoarsener.jacobiEigen3(simd_float3x3(diagonal: [3, 1, 2]))
        XCTAssertEqual(diagonal.values, [3, 1, 2])
        XCTAssertEqual(diagonal.vectors, matrix_identity_float3x3)
        let zero = UntoldGSCoarsener.jacobiEigen3(simd_float3x3(0))
        XCTAssertEqual(zero.values, .zero)
        XCTAssertEqual(zero.vectors, matrix_identity_float3x3)
    }

    // MARK: - Levels

    func testLevelOrderIsImportanceDescending() throws {
        var rng = SplitMix64(seed: 5)
        let splats = (0 ..< 256).map { _ in rng.nextSplat() }
        let levels = try UntoldGSCoarsener.coarsen(splats, options: .default)
        XCTAssertEqual(levels.l1.count, 32)
        XCTAssertEqual(levels.l2.count, 4)
        for level in [levels.l1, levels.l2] {
            let importance = level.map(UntoldGSFormat.importance)
            XCTAssertEqual(importance, importance.sorted(by: >))
            for splat in level {
                XCTAssertTrue(splat.isFinite)
                XCTAssertGreaterThan(splat.opacity, 0)
                XCTAssertLessThanOrEqual(splat.opacity, 1)
            }
        }
        // Every merged σ lies within the chunk's [smallest fine σ, extent + largest fine σ].
        let stats = UntoldGSCoarsener.ChunkStatistics(splats)
        for splat in levels.l1 + levels.l2 {
            XCTAssertGreaterThanOrEqual(splat.scale.min(), stats.minimumScale * 0.999)
            XCTAssertLessThanOrEqual(splat.scale.max(), stats.maximumScale * 1.001)
        }
    }

    func testSmallChunksGetNoLevels() throws {
        var rng = SplitMix64(seed: 6)
        XCTAssertEqual(try UntoldGSCoarsener.coarsen((0 ..< 15).map { _ in rng.nextSplat() }, options: .default), .none)
        XCTAssertEqual(try UntoldGSCoarsener.coarsen([], options: .default), .none)
        let sixteen = try UntoldGSCoarsener.coarsen((0 ..< 16).map { _ in rng.nextSplat() }, options: .default)
        XCTAssertEqual(sixteen.l1.count, 2, "16 >> 3")
        XCTAssertEqual(sixteen.l2.count, 1, "max(1, 16 >> 6)")
        var options = UntoldGSCoarseLevelOptions.default
        options.minimumChunkSplats = 100
        XCTAssertEqual(try UntoldGSCoarsener.coarsen((0 ..< 64).map { _ in rng.nextSplat() }, options: options), .none)
    }

    func testOptionsValidateAndResolveAutomatically() {
        XCTAssertNoThrow(try UntoldGSCoarseLevelOptions.default.validate(log2ChunkSplats: 10))
        XCTAssertNoThrow(try UntoldGSCoarseLevelOptions.default.validate(log2ChunkSplats: 6))
        XCTAssertThrowsError(try UntoldGSCoarseLevelOptions.default.validate(log2ChunkSplats: 5))
        var options = UntoldGSCoarseLevelOptions.default
        options.ratioLog2 = [6, 3]
        XCTAssertThrowsError(try options.validate(log2ChunkSplats: 10))
        options.ratioLog2 = [3]
        XCTAssertThrowsError(try options.validate(log2ChunkSplats: 10), "two levels need two ratios")
        options.levelCount = 1
        XCTAssertNoThrow(try options.validate(log2ChunkSplats: 10))
        options.levelCount = 3
        XCTAssertThrowsError(try options.validate(log2ChunkSplats: 10))
        options.levelCount = 0
        XCTAssertThrowsError(try options.validate(log2ChunkSplats: 10))

        XCTAssertEqual(UntoldGSCoarseLevelOptions.default.clamped(toLog2ChunkSplats: 10), .default)
        let clamped = UntoldGSCoarseLevelOptions.default.clamped(toLog2ChunkSplats: 4)
        XCTAssertEqual(clamped.levelCount, 2)
        XCTAssertEqual(clamped.ratioLog2, [3, 4])
        let collapsed = UntoldGSCoarseLevelOptions.default.clamped(toLog2ChunkSplats: 3)
        XCTAssertEqual(collapsed.levelCount, 1)
        XCTAssertEqual(collapsed.ratioLog2, [3])
        let two = UntoldGSCoarseLevelOptions.default.clamped(toLog2ChunkSplats: 2)
        XCTAssertEqual(two.levelCount, 1)
        XCTAssertEqual(two.ratioLog2, [2])
        var wide = UntoldGSCoarseLevelOptions.default
        wide.ratioLog2 = [4, 7]
        XCTAssertEqual(wide.clamped(toLog2ChunkSplats: 10), wide)
        XCTAssertEqual(wide.clamped(toLog2ChunkSplats: 5).ratioLog2, [4, 5])
    }

    func testBakeIsBitIdenticalAcrossRuns() throws {
        var rng = SplitMix64(seed: 8)
        let splats = (0 ..< 3000).map { _ in rng.nextSplat() }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 5 // 94 chunks: automatic levels
        let parallel = try UntoldGSFormat.writeReporting(splats: splats, options: options, serialCoarsening: false)
        let serial = try UntoldGSFormat.writeReporting(splats: splats, options: options, serialCoarsening: true)
        let again = try UntoldGSFormat.writeReporting(splats: splats, options: options, serialCoarsening: false)
        XCTAssertEqual(parallel.report, serial.report)
        XCTAssertEqual(parallel.data, serial.data, "the thread count never changes a byte")
        XCTAssertEqual(parallel.data, again.data, "run to run")
        XCTAssertEqual(parallel.report.chunkCount, 94)
        XCTAssertEqual(parallel.report.coarse?.levelCount, 2)
        XCTAssertEqual(parallel.report.coarse?.ratioLog2, [3, 5])
        XCTAssertEqual(parallel.report.coarse?.recordsPerLevel, [93 * 4 + 3, 94]) // 3000 = 93 × 32 + 24; 24 >> 3 = 3, 24 >> 5 → 1
        XCTAssertEqual(parallel.report.coarse?.chunksWithoutLevels, 0)
    }
}

/// Deterministic generator so failures reproduce.
private struct SplitMix64 {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextUnitFloat() -> Float {
        Float(next() >> 40) / Float(1 << 24)
    }

    mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
        range.lowerBound + nextUnitFloat() * (range.upperBound - range.lowerBound)
    }

    mutating func nextSplat() -> UntoldGSSplat {
        let v = SIMD4<Float>(nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1), nextFloat(in: -1 ... 1))
        return UntoldGSSplat(
            position: SIMD3<Float>(nextFloat(in: -1 ... 1), nextFloat(in: -0.2 ... 0.2), nextFloat(in: -1 ... 1)),
            scale: SIMD3<Float>(exp(nextFloat(in: -6 ... -2)), exp(nextFloat(in: -6 ... -2)), exp(nextFloat(in: -6 ... -2))),
            rotation: simd_quatf(vector: simd_normalize(v)),
            color: SIMD3<Float>(nextUnitFloat(), nextUnitFloat(), nextUnitFloat()),
            opacity: nextFloat(in: 0.1 ... 1)
        )
    }
}
