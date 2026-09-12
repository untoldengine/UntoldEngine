//
//  GaussianChunkCullMathTests.swift
//  UntoldEngine
//
//  The CPU mirrors of the per-chunk level rule of the coarse levels (per-chunk-lod-tiers), without
//  Metal: the tier shifts, the level rule's table with its hysteresis band and availability
//  fallbacks, the density floor, the bounded request R(d) — monotone in the cap and at least the
//  sum of the per-chunk quotas at the levels the rule picks, and the bounded grant byte for
//  byte without levels — the coverage-preserving cross-fade identity, the visible-chunk tag
//  and the level-state word.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class GaussianChunkCullMathTests: XCTestCase {
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

        mutating func unit() -> Float {
            Float(next() >> 40) / Float(1 << 24)
        }

        mutating func below(_ n: Int) -> Int {
            Int(next() % UInt64(max(1, n)))
        }
    }

    /// The default ratios 3, 6 → shifts 4, 10.
    private let shifts = (GaussianChunkCullMath.tierShift(ratioLog2: 3), GaussianChunkCullMath.tierShift(ratioLog2: 6))
    private let allAvailable: UInt32 = 0b111

    // MARK: - Tier shifts

    func testTierShifts() {
        XCTAssertEqual(GaussianChunkCullMath.tierShift(ratioLog2: 3), 4)
        XCTAssertEqual(GaussianChunkCullMath.tierShift(ratioLog2: 6), 10)
        XCTAssertEqual(GaussianChunkCullMath.tierShift(ratioLog2: 4), 6)
        XCTAssertEqual(GaussianChunkCullMath.tierShift(ratioLog2: 1), 0, "a level of half the chunk switches at the chunk's own density")
        XCTAssertEqual(shifts.0, 4)
        XCTAssertEqual(shifts.1, 10)
    }

    // MARK: - The rule

    /// For n = 1024 the cap sweeps the chunk's own density through twelve octaves: fine from
    /// four tiers under, level 1 down to ten under, level 2 below; from level 1 fine needs one
    /// more tier; a wanted level that is unavailable steps to the next coarser, else finer.
    func testLevelRuleTable() {
        let n: UInt32 = 1024
        let area: Float = 0.01
        let own = Float(n) / area
        let ownTier = GaussianChunkCullMath.densityTier(density: own)
        for octaves in stride(from: -12.0, through: 2.0, by: 0.25) {
            let cap = own * Float(pow(2.0, octaves))
            let delta = GaussianChunkCullMath.densityTier(density: cap) - ownTier
            let expected = delta >= -4 ? 0 : (delta >= -10 ? 1 : 2)
            let level = GaussianChunkCullMath.level(densityCap: cap, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts)
            XCTAssertEqual(level, expected, "delta \(delta)")
            XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: delta, previous: 0, available: allAvailable, tierShifts: shifts), level)
        }
        // Hysteresis: from level 1, fine only at delta ≥ −3; from level 2, level 1 only at ≥ −9.
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -4, previous: 0, available: allAvailable, tierShifts: shifts), 0)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -4, previous: 1, available: allAvailable, tierShifts: shifts), 1, "inside the band the level holds")
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -3, previous: 1, available: allAvailable, tierShifts: shifts), 0)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -10, previous: 2, available: allAvailable, tierShifts: shifts), 2)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -9, previous: 2, available: allAvailable, tierShifts: shifts), 1)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -4, previous: 2, available: allAvailable, tierShifts: shifts), 1, "from level 2 the band of the fine threshold lands on level 1")
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -3, previous: 2, available: allAvailable, tierShifts: shifts), 0)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -5, previous: 0, available: allAvailable, tierShifts: shifts), 1, "coarser is taken at once")
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -11, previous: 0, available: allAvailable, tierShifts: shifts), 2)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: GaussianChunkCullMath.levelRuleMinusInfinity, previous: 0, available: allAvailable, tierShifts: shifts), 2, "a zero cap")
        // Availability: fine unavailable → level 1; level 1 unavailable → level 2; nothing coarser → finer.
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: 0, previous: 0, available: 0b110, tierShifts: shifts), 1)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: 0, previous: 0, available: 0b100, tierShifts: shifts), 2)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -6, previous: 0, available: 0b101, tierShifts: shifts), 2)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -12, previous: 0, available: 0b011, tierShifts: shifts), 1)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -12, previous: 0, available: 0b001, tierShifts: shifts), 0)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: 0, previous: 0, available: 0, tierShifts: shifts), 0, "nothing available: the wanted level (the cull lists no such chunk)")
        // An entity with one resident level (the file's coarsest as the runtime's level 1): both
        // shifts equal, so level 1's own range is empty and level 2, wanted below the threshold,
        // steps to the finer available level 1.
        let one = (shifts.1, shifts.1)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -10, previous: 0, available: 0b011, tierShifts: one), 0)
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -11, previous: 0, available: 0b011, tierShifts: one), 1, "level 2 wanted, unavailable, the finer level 1")
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -10, previous: 1, available: 0b011, tierShifts: one), 1, "the band holds")
        XCTAssertEqual(GaussianChunkCullMath.levelRule(deltaTier: -9, previous: 1, available: 0b011, tierShifts: one), 0)
        // The debug modes.
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: 1, splatCount: n, screenArea: area, previous: 2, available: allAvailable, tierShifts: shifts, levelMode: .fineOnly), 0)
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts, levelMode: .coarseOnly), 2)
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, splatCount: n, screenArea: area, previous: 0, available: 0b011, tierShifts: shifts, levelMode: .coarseOnly), 1)
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts), 0, "a fitting frame draws fine")
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: 0, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts), 2, "a zero cap is minus infinity")
    }

    /// With the cap infinite (a fitting frame) a finite floor still sends a far chunk coarse; the
    /// quota mirror is unchanged by it.
    func testDensityFloorLowersEffectiveCap() {
        let n: UInt32 = 1024
        let area: Float = 3.1e-5 // ≈ 64 px at 1080p: density 33 M
        let floor = gaussianDensityFloor(viewport: simd_float2(1920, 1080), maxSplatsPerPixel: 1)
        XCTAssertEqual(floor, 1920 * 1080, accuracy: 1)
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts), 0)
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, densityFloor: floor, splatCount: n, screenArea: area, previous: 0, available: allAvailable, tierShifts: shifts), 1, "four octaves above the floor: level 1")
        XCTAssertEqual(GaussianChunkCullMath.level(densityCap: .infinity, densityFloor: floor, splatCount: n, screenArea: area * 64, previous: 0, available: allAvailable, tierShifts: shifts), 0, "a chunk of 4096 px stays fine")
        XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: .infinity, splatCount: n, screenArea: area), n, "the quota stays on the cap")
        XCTAssertEqual(GaussianChunkCullMath.levelQuota(level: 1, densityCap: .infinity, splatCount: n, screenArea: area, counts: (128, 16)), 128)
        XCTAssertEqual(GaussianChunkCullMath.levelQuota(level: 0, densityCap: .infinity, splatCount: n, residentRanks: 256, screenArea: area, counts: (128, 16)), 256)
        XCTAssertEqual(GaussianChunkCullMath.levelQuota(level: 2, densityCap: 1000, splatCount: n, screenArea: 0.01, counts: (128, 16)), 10, "a coarse window cut by a fallen cap")
        XCTAssertTrue(gaussianDensityFloor(viewport: simd_float2(1920, 1080), maxSplatsPerPixel: 0).isInfinite, "0 switches the floor off")
        XCTAssertTrue(gaussianDensityFloor(viewport: simd_float2(1920, 1080), maxSplatsPerPixel: .infinity).isInfinite)
        XCTAssertEqual(gaussianDensityFloor(viewport: simd_float2(100, 100), maxSplatsPerPixel: 2), 20000)
    }

    // MARK: - The bounded request

    private func randomChunks(_ rng: inout SplitMix64, count: Int) -> [GaussianChunkCullMath.LevelledChunk] {
        (0 ..< count).map { _ in
            let log2n = 4 + rng.below(11) // 16 … 16384 splats
            let n = UInt32(1 << log2n)
            let m1 = max(1, n >> 3)
            let m2 = max(1, n >> 6)
            // Resident ranks: whole, none, or a prefix of 256-rank tiers (a head below the level-1 count included).
            let residentChoice = rng.below(4)
            let resident: UInt32 = residentChoice == 0 ? 0 : (residentChoice == 1 ? n : min(n, UInt32(256 * (1 + rng.below(4)))))
            let available = UInt32(rng.below(4)) // none, level 1, level 2, both
            let area = Float(pow(2.0, Double(-24 + rng.below(24)))) * (0.5 + rng.unit())
            return GaussianChunkCullMath.LevelledChunk(splatCount: n, residentRanks: resident, screenArea: min(area, 1.5), coarse1: m1, coarse2: m2, availableLevels: available)
        }
    }

    private func exactRequest(chunks: [GaussianChunkCullMath.LevelledChunk], density: Float, floor: Float, previous: [Int], shifts perChunk: [(Int, Int)]? = nil) -> Float {
        var total: Float = 0
        for (index, chunk) in chunks.enumerated() where chunk.isListed {
            let level = GaussianChunkCullMath.level(densityCap: density, densityFloor: floor, splatCount: chunk.splatCount, screenArea: chunk.screenArea, previous: previous[index], available: chunk.availability, tierShifts: perChunk?[index] ?? shifts)
            total += Float(GaussianChunkCullMath.levelQuota(level: level, densityCap: density, splatCount: chunk.splatCount, residentRanks: chunk.residentRanks, screenArea: chunk.screenArea, counts: (chunk.coarse1, chunk.coarse2)))
        }
        return total
    }

    /// Over random histograms (random counts, areas, residency, availability) and 64 caps the
    /// bounded request never decreases with the cap and is at least the sum of the per-chunk
    /// quotas at the levels the rule picks, whatever level each chunk drew last frame.
    func testBoundedRequestIsMonotoneAndOneSided() {
        var rng = SplitMix64(seed: 0x51AB_C0DE)
        for round in 0 ..< 1000 {
            let chunks = randomChunks(&rng, count: 1 + rng.below(40))
            let histogram = GaussianChunkCullMath.densityHistogram(levelledChunks: chunks)
            let floor: Float = round % 3 == 0 ? Float(pow(2.0, Double(rng.below(30)))) : .infinity
            let previous = chunks.map { _ in rng.below(3) }
            let finest = chunks.map { _ in 0 }
            var last: Float = -1
            for step in 0 ..< 64 {
                let density = Float(pow(2.0, -16 + Double(step) * 0.75))
                let request = GaussianChunkCullMath.boundedRequest(histogram: histogram, density: density, densityFloor: floor, tierShifts: shifts)
                XCTAssertGreaterThanOrEqual(request, last, "round \(round) step \(step): R(d) fell")
                last = request
                let exactPrevious = exactRequest(chunks: chunks, density: density, floor: floor, previous: previous)
                let exactFinest = exactRequest(chunks: chunks, density: density, floor: floor, previous: finest)
                XCTAssertGreaterThanOrEqual(request, exactPrevious, "round \(round) step \(step): R(d) under the per-chunk sum")
                XCTAssertGreaterThanOrEqual(request, exactFinest, "round \(round) step \(step): R(d) under the per-chunk sum from fine")
            }
            XCTAssertGreaterThanOrEqual(
                GaussianChunkCullMath.boundedRequest(histogram: histogram, density: .infinity, densityFloor: floor, tierShifts: shifts),
                exactRequest(chunks: chunks, density: .infinity, floor: floor, previous: finest),
                "round \(round): the whole request"
            )
        }
    }

    /// A frame whose entities carry different tier shifts — ratios 3, 6 (shifts 4, 10), a
    /// fit-check fallback to level 2 alone (10, 10), ratios 6, 9 (10, 16) — is solved with the
    /// **maximum** shifts over them: a larger shift keeps a chunk fine further under its own
    /// density, so with the maximum the fine term is charged wherever any entity still draws
    /// fine, and R(d) stays at least the per-chunk sum with each chunk's own shifts (the
    /// minimum would charge an entity with larger shifts its coarse count where its own rule
    /// still draws the fine quota). R(d) stays monotone at the maximum.
    func testBoundedRequestIsOneSidedAtTheMaximumShiftsOverMixedEntities() {
        let choices = [(4, 10), (10, 10), (10, 16)]
        var rng = SplitMix64(seed: 0xD1FF_5A1F)
        var undercharged = 0
        for round in 0 ..< 1000 {
            let chunks = randomChunks(&rng, count: 1 + rng.below(40))
            let perChunk = chunks.map { _ in choices[rng.below(3)] }
            let maximum = perChunk.reduce((0, 0)) { (max($0.0, $1.0), max($0.1, $1.1)) }
            let minimum = perChunk.reduce((Int.max, Int.max)) { (min($0.0, $1.0), min($0.1, $1.1)) }
            let histogram = GaussianChunkCullMath.densityHistogram(levelledChunks: chunks)
            let floor: Float = round % 3 == 0 ? Float(pow(2.0, Double(rng.below(30)))) : .infinity
            let previous = chunks.map { _ in rng.below(3) }
            let finest = chunks.map { _ in 0 }
            var last: Float = -1
            for step in 0 ..< 64 {
                let density = Float(pow(2.0, -16 + Double(step) * 0.75))
                let request = GaussianChunkCullMath.boundedRequest(histogram: histogram, density: density, densityFloor: floor, tierShifts: maximum)
                XCTAssertGreaterThanOrEqual(request, last, "round \(round) step \(step): R(d) fell at the maximum shifts")
                last = request
                let exactPrevious = exactRequest(chunks: chunks, density: density, floor: floor, previous: previous, shifts: perChunk)
                let exactFinest = exactRequest(chunks: chunks, density: density, floor: floor, previous: finest, shifts: perChunk)
                XCTAssertGreaterThanOrEqual(request, exactPrevious, "round \(round) step \(step): R(d) at the maximum shifts under the per-chunk sum")
                XCTAssertGreaterThanOrEqual(request, exactFinest, "round \(round) step \(step): R(d) at the maximum shifts under the per-chunk sum from fine")
                if GaussianChunkCullMath.boundedRequest(histogram: histogram, density: density, densityFloor: floor, tierShifts: minimum) < exactFinest {
                    undercharged += 1
                }
            }
        }
        XCTAssertGreaterThan(undercharged, 0, "sanity — the minimum shifts do undercharge some mixed frames, which is why the driver folds the maximum")
    }

    /// Without levelled chunks the request is the bounded grant, bit for bit, and the extended
    /// histogram mirror equals the plain one.
    func testBoundedRequestWithoutLevelsIsTheBoundedGrant() {
        var rng = SplitMix64(seed: 0x0B0B_CAFE)
        for _ in 0 ..< 200 {
            let plain: [(splatCount: UInt32, screenArea: Float)] = (0 ..< 1 + rng.below(30)).map { _ in
                (UInt32(1 + rng.below(1024)), Float(pow(2.0, Double(-24 + rng.below(24)))) * (0.5 + rng.unit()))
            }
            let histogram = GaussianChunkCullMath.densityHistogram(chunks: plain)
            let levelled = GaussianChunkCullMath.densityHistogram(levelledChunks: plain.map { GaussianChunkCullMath.LevelledChunk(splatCount: $0.splatCount, screenArea: $0.screenArea) })
            XCTAssertEqual(histogram.tierArray.map(\.splats), levelled.tierArray.map(\.splats))
            XCTAssertEqual(histogram.tierArray.map(\.scaledArea), levelled.tierArray.map(\.scaledArea))
            XCTAssertTrue(levelled.tierArray.allSatisfy { $0.coarse1 == 0 && $0.coarse2 == 0 && $0.levelledSplats == 0 && $0.levelledScaledArea == 0 })
            for step in 0 ..< 32 {
                let density = Float(pow(2.0, -16 + Double(step) * 1.5))
                XCTAssertEqual(
                    GaussianChunkCullMath.boundedRequest(histogram: histogram, density: density, tierShifts: shifts).bitPattern,
                    GaussianChunkCullMath.boundedGrant(histogram: histogram, density: density).bitPattern
                )
            }
        }
    }

    /// The histogram of an entity with levels: a chunk with a level is binned by its full density,
    /// a non-resident chunk is listed for its finest available level, a chunk with neither is unlisted.
    func testLevelledHistogramBinsByFullDensityAndListsCoarseChunks() {
        let area: Float = 0.001
        let resident = GaussianChunkCullMath.LevelledChunk(splatCount: 1024, residentRanks: 256, screenArea: area, coarse1: 128, coarse2: 16, availableLevels: 3)
        let unlisted = GaussianChunkCullMath.LevelledChunk(splatCount: 1024, residentRanks: 0, screenArea: area, coarse1: 128, coarse2: 16, availableLevels: 0)
        let coarseOnly = GaussianChunkCullMath.LevelledChunk(splatCount: 1024, residentRanks: 0, screenArea: area, coarse1: 128, coarse2: 16, availableLevels: 2)
        let both = GaussianChunkCullMath.LevelledChunk(splatCount: 1024, residentRanks: 0, screenArea: area, coarse1: 128, coarse2: 16, availableLevels: 3)
        let plain = GaussianChunkCullMath.LevelledChunk(splatCount: 512, residentRanks: 512, screenArea: area)
        let headOnly = GaussianChunkCullMath.LevelledChunk(splatCount: 4096, residentRanks: 256, screenArea: area * 4, coarse1: 512, coarse2: 64, availableLevels: 3)
        XCTAssertFalse(unlisted.isListed)
        XCTAssertEqual(coarseOnly.listedSplats, 16)
        XCTAssertEqual(both.listedSplats, 128)
        XCTAssertEqual(resident.listedSplats, 256)
        XCTAssertEqual(headOnly.listedSplats, 512, "a head below the level-1 count lists that count")
        let histogram = GaussianChunkCullMath.densityHistogram(levelledChunks: [resident, unlisted, coarseOnly, both, plain, headOnly])
        XCTAssertEqual(histogram.visibleChunks, 5)
        let full = GaussianChunkCullMath.densityTier(density: 1024 / area)
        let tier = histogram.tier(full)
        let scaled = UInt32(ceil(area * GaussianChunkCullMath.densityTierFloor(full)))
        XCTAssertEqual(tier.splats, 256 + 16 + 128 + 512)
        XCTAssertEqual(tier.levelledSplats, 256 + 16 + 128 + 512)
        XCTAssertEqual(tier.coarse1, 128 + 16 + 128 + 512, "the finest available level's count")
        XCTAssertEqual(tier.coarse2, 16 + 16 + 16 + 64)
        XCTAssertEqual(tier.scaledArea, 3 * scaled + UInt32(ceil(area * 4 * GaussianChunkCullMath.densityTierFloor(full))))
        XCTAssertEqual(tier.levelledScaledArea, tier.scaledArea)
        let plainTier = histogram.tier(GaussianChunkCullMath.densityTier(density: 512 / area))
        XCTAssertEqual(plainTier.splats, 512)
        XCTAssertEqual(plainTier.levelledSplats, 0)
        XCTAssertEqual(plainTier.levelledScaledArea, 0)
        XCTAssertEqual(histogram.requestedSplats, 256 + 16 + 128 + 512 + 512)
    }

    // MARK: - The cross-fade

    /// (1 − α_in)(1 − α_out) = 1 − α for every α and w: the two windows compose to the surface's
    /// transmittance in either draw order.
    func testFadeIdentity() {
        for alpha in stride(from: Float(0.05), through: 0.999, by: 0.0473) {
            for w in stride(from: Float(0), through: 1, by: 1.0 / 16) {
                let incoming = GaussianChunkCullMath.coverageWeight(alpha: alpha, weight: w)
                let outgoing = GaussianChunkCullMath.coverageWeight(alpha: alpha, weight: 1 - w)
                XCTAssertEqual((1 - incoming) * (1 - outgoing), 1 - alpha, accuracy: 1e-6, "alpha \(alpha) w \(w)")
                XCTAssertGreaterThanOrEqual(incoming, 0)
                XCTAssertLessThanOrEqual(incoming, alpha + 1e-6)
            }
            XCTAssertEqual(GaussianChunkCullMath.coverageWeight(alpha: alpha, weight: 1), alpha, accuracy: 1e-6)
            XCTAssertEqual(GaussianChunkCullMath.coverageWeight(alpha: alpha, weight: 0), 0, accuracy: 1e-6)
        }
        XCTAssertEqual(GaussianChunkCullMath.fadeWeight(frame: 10, switchFrame: 10, fadeFrames: 16), 1.0 / 16)
        XCTAssertEqual(GaussianChunkCullMath.fadeWeight(frame: 25, switchFrame: 10, fadeFrames: 16), 1)
        XCTAssertEqual(GaussianChunkCullMath.fadeWeight(frame: 40, switchFrame: 10, fadeFrames: 16), 1)
        XCTAssertEqual(GaussianChunkCullMath.fadeWeight(frame: 10, switchFrame: 10, fadeFrames: 0), 1, "fades off")
    }

    // MARK: - Tags and state

    func testVisibleChunkTagRoundTrip() {
        for level in 0 ... 2 {
            for outgoing in [false, true] {
                for chunk: UInt32 in [0, 1, 12345, (1 << 24) - 1] {
                    let word = GaussianChunkCullMath.visibleChunkTag(chunkIndex: chunk, level: level, outgoing: outgoing)
                    let decoded = GaussianChunkCullMath.decodeVisibleChunkTag(word)
                    XCTAssertEqual(decoded.chunkIndex, chunk)
                    XCTAssertEqual(decoded.level, level)
                    XCTAssertEqual(decoded.outgoing, outgoing)
                    XCTAssertEqual(word & kGaussianVisibleChunkIndexMask, chunk)
                }
            }
        }
        XCTAssertEqual(GaussianChunkCullMath.visibleChunkTag(chunkIndex: 7, level: 0), 7, "a fine entry carries no tag bits")
        XCTAssertEqual(GaussianChunkCullMath.visibleChunkTag(chunkIndex: 7, level: 2, outgoing: true), 7 | 0x0200_0000 | 0x0400_0000)
    }

    func testLevelStateRoundTrip() {
        let initial = GaussianChunkLevelState.initial
        XCTAssertEqual(initial.word0, 0)
        XCTAssertEqual(initial.level, 0)
        XCTAssertNil(initial.outLevel)
        XCTAssertNil(initial.pending)
        XCTAssertEqual(initial.outCount, 0)
        XCTAssertFalse(initial.isFading(frame: 3, fadeFrames: 16), "the zero state fades nothing")
        for level in 0 ... 2 {
            for outLevel in [nil, 0, 1, 2] {
                for pending in [nil, 0, 1, 2] {
                    for count: UInt32 in [0, 1, 128, 16384, 0x00FF_FFFF] {
                        let state = GaussianChunkLevelState(level: level, outLevel: outLevel, outCount: count, pending: pending, switchFrame: 77)
                        XCTAssertEqual(state.level, level)
                        XCTAssertEqual(state.outLevel, outLevel)
                        XCTAssertEqual(state.pending, pending)
                        XCTAssertEqual(state.outCount, count)
                        XCTAssertEqual(state.switchFrame, 77)
                        XCTAssertEqual(state.isFading(frame: 80, fadeFrames: 16), outLevel != nil)
                        XCTAssertFalse(state.isFading(frame: 93, fadeFrames: 16))
                        XCTAssertFalse(state.isFading(frame: 80, fadeFrames: 0))
                    }
                }
            }
        }
    }

    // MARK: - Constants

    func testLevelConstantsFollowTheTableAndTheSwitches() {
        var cull = GaussianChunkCullConstants()
        cull.chunkCount = 293
        cull.paged = 1
        cull.uniformQuotas = 0
        cull.viewport = simd_float2(1920, 1080)
        let two = gaussianChunkLevelConstants(levelCount: 2, ratioLog2: [3, 6], frameIndex: 42, cull: cull, fadeFrames: 16, levelMode: .auto, debugTint: false, maxSplatsPerPixel: 1)
        XCTAssertEqual(two.hasCoarse, 2)
        XCTAssertEqual(two.tierShift1, 4)
        XCTAssertEqual(two.tierShift2, 10)
        XCTAssertEqual(two.frameIndex, 42)
        XCTAssertEqual(two.fadeFrames, 16)
        XCTAssertEqual(two.levelMode, GaussianLevelMode.auto.rawValue)
        XCTAssertEqual(two.debugTint, 0)
        XCTAssertEqual(two.densityFloor, 1920 * 1080)
        XCTAssertEqual(two.chunkCount, 293)
        XCTAssertEqual(two.paged, 1)
        XCTAssertEqual(two.uniformQuotas, 0)
        // One resident level (the file's coarsest): both shifts its own.
        let one = gaussianChunkLevelConstants(levelCount: 1, ratioLog2: [6], frameIndex: 0, cull: cull, fadeFrames: 0, levelMode: .coarseOnly, debugTint: true, maxSplatsPerPixel: 0)
        XCTAssertEqual(one.hasCoarse, 1)
        XCTAssertEqual(one.tierShift1, 10)
        XCTAssertEqual(one.tierShift2, 10)
        XCTAssertEqual(one.fadeFrames, 0)
        XCTAssertEqual(one.levelMode, GaussianLevelMode.coarseOnly.rawValue)
        XCTAssertEqual(one.debugTint, 1)
        XCTAssertTrue(one.densityFloor.isInfinite)
        let none = gaussianChunkLevelConstants(levelCount: 0, ratioLog2: [], frameIndex: 5, cull: cull)
        XCTAssertEqual(none.hasCoarse, 0)
        XCTAssertEqual(GaussianChunkLevelConstants().hasCoarse, 0, "the stand-in keeps every kernel on the old paths")
        // The scale constants carry the floor and the shifts.
        let scale = gaussianBudgetScaleConstants(budget: 1000, uniformQuotas: false, densityFloor: 2_000_000, tierShifts: (4, 10))
        XCTAssertEqual(scale.densityFloor, 2_000_000)
        XCTAssertEqual(scale.tierShift1, 4)
        XCTAssertEqual(scale.tierShift2, 10)
        XCTAssertTrue(gaussianBudgetScaleConstants(budget: 1000, uniformQuotas: false).densityFloor.isInfinite)
        XCTAssertEqual(GaussianLevelMode(rawValue: gaussianChunkLevelModeFineOnly.rawValue), .fineOnly)
        XCTAssertEqual(GaussianLevelMode(rawValue: gaussianChunkLevelModeCoarseOnly.rawValue), .coarseOnly)
    }

    /// The spelled-out availability fallbacks of the level rule agree with the loops they
    /// replaced over every tier distance, previous level, mask and pair of shifts.
    func testLevelRuleFallbacksMatchTheLoops() {
        func reference(deltaTier: Int, previous: Int, available: UInt32, tierShifts: (Int, Int)) -> Int {
            func wanted(margin: Int) -> Int {
                if deltaTier >= -tierShifts.0 + margin { return 0 }
                if deltaTier >= -tierShifts.1 + margin { return 1 }
                return 2
            }
            var want = wanted(margin: 0)
            if want < previous {
                want = min(previous, wanted(margin: 1))
            }
            for level in want ... 2 where (available & (1 << UInt32(level))) != 0 {
                return level
            }
            for level in stride(from: want - 1, through: 0, by: -1) where (available & (1 << UInt32(level))) != 0 {
                return level
            }
            return want
        }
        for shifts in [(0, 0), (2, 2), (2, 6), (4, 10), (0, 4)] {
            for deltaTier in -14 ... 6 {
                for previous in 0 ... 2 {
                    for available in UInt32(0) ... 7 {
                        XCTAssertEqual(
                            GaussianChunkCullMath.levelRule(deltaTier: deltaTier, previous: previous, available: available, tierShifts: shifts),
                            reference(deltaTier: deltaTier, previous: previous, available: available, tierShifts: shifts),
                            "delta \(deltaTier) previous \(previous) available \(available) shifts \(shifts)"
                        )
                    }
                }
            }
        }
    }
}
