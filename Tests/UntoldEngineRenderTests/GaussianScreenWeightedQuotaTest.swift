//
//  GaussianScreenWeightedQuotaTest.swift
//  UntoldEngine
//
//  The screen-weighted per-chunk quotas of the working-set budget (GaussianChunkCull.metal,
//  GaussianWorkingSetBudget.metal): the density tiers, the bounded grant and its solve, the
//  density hysteresis and the quota rule against their CPU mirrors, the pinned layouts, and on
//  the GPU that every quota follows the frame's density cap and the chunk's clipped screen
//  area exactly, that near chunks keep more than far ones at the same budget, that the cap
//  matches the mirror over a climb, that two identical frames are bit-identical, that a sweep
//  of poses and budgets never exceeds the budget, that a cut falls at once and a lift climbs
//  to whole, that a fitting frame stays whole, that leaving chunks free budget that fades back
//  in, that an entering chunk grows with its clipped area, that the chunk the camera stands in
//  is kept whole, that chunks no view keeps are cut first, that the uniform switch reproduces
//  the uniform rule byte for byte, that the opacity band follows each chunk's weighted quota,
//  and in stereo that the area is the larger eye's, that a head turn stays under budget
//  without pops, and that an HZB occlusion in eye 1 removes eye 1's area.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class GaussianScreenWeightedQuotaTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var savedDisableHZBOcclusionCull = false
    private var savedDisableChunkCull = false
    private var savedDisableWorkingSetBudget = false
    private var savedDisableScreenWeightedQuotas = false
    private var savedWorkingSetOverride: Int?

    override func setUp() async throws {
        try await super.setUp()
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableWorkingSetBudget = GaussianDebugOptions.shared.disableWorkingSetBudget
        savedDisableScreenWeightedQuotas = GaussianDebugOptions.shared.disableScreenWeightedQuotas
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        GaussianDebugOptions.shared.disableChunkCull = false
        GaussianDebugOptions.shared.disableWorkingSetBudget = false
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableWorkingSetBudget = savedDisableWorkingSetBudget
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = savedDisableScreenWeightedQuotas
        GaussianRuntimeLimits.workingSetSplatsOverride = savedWorkingSetOverride
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - CPU: tiers, the bounded grant, the hysteresis, the quota rule, the layouts

    private let sqrt2 = gaussianBudgetDensityTierRatio

    /// A power of two times `mantissa`, exactly.
    private func pow2(_ k: Int, times mantissa: Float = 1) -> Float {
        Float(sign: .plus, exponent: k, significand: mantissa)
    }

    /// The tier is read off the float's exponent and significand: 2(k + 2) for 2^k, one more
    /// from 2^k × √2 on, one less one ulp below that, clamped into the 64 tiers; the tier floors
    /// are the exact powers of two and √2 times them.
    func testDensityTierMatchesTheFloatExponent() {
        for k in -2 ... 29 {
            XCTAssertEqual(GaussianChunkCullMath.densityTier(density: pow2(k)), 2 * (k + 2), "2^\(k)")
            XCTAssertEqual(GaussianChunkCullMath.densityTier(density: pow2(k, times: sqrt2)), 2 * (k + 2) + 1, "2^\(k) × √2")
            let justBelow = pow2(k, times: sqrt2 * (1 - Float(sign: .plus, exponent: -23, significand: 1)))
            XCTAssertLessThan(justBelow, pow2(k, times: sqrt2))
            XCTAssertEqual(GaussianChunkCullMath.densityTier(density: justBelow), 2 * (k + 2), "one ulp below 2^\(k) × √2 stays in the lower half-octave")
        }
        for tier in 0 ..< gaussianDensityTierCount {
            let floor = GaussianChunkCullMath.densityTierFloor(tier)
            if tier % 2 == 0 {
                XCTAssertEqual(floor, pow2(-2 + tier / 2), "tier \(tier) starts at 2^\(-2 + tier / 2)")
            } else {
                XCTAssertEqual(floor, pow2((tier - 1) / 2 - 2, times: sqrt2), "tier \(tier) starts at 2^\((tier - 1) / 2 - 2) × √2")
            }
            XCTAssertEqual(GaussianChunkCullMath.densityTier(density: floor), tier, "the floor of tier \(tier) is in tier \(tier)")
            if tier > 0 {
                XCTAssertEqual(GaussianChunkCullMath.densityTier(density: floor.nextDown), tier - 1, "one ulp below the floor of tier \(tier) is in tier \(tier - 1)")
            }
        }
        XCTAssertEqual(GaussianChunkCullMath.densityTierFloor(gaussianDensityTierCount), pow2(30), "the floor past the last tier: every chunk of tier 63 is whole there")
        XCTAssertEqual(GaussianChunkCullMath.densityTier(density: pow2(-3)), 0, "below the first tier clamps into it")
        XCTAssertEqual(GaussianChunkCullMath.densityTier(density: pow2(30)), 63, "2^30 is above the last tier and clamps into it")
        XCTAssertEqual(GaussianChunkCullMath.densityTier(density: pow2(40)), 63)
        XCTAssertEqual(GaussianChunkCullMath.densityTier(density: 0), 0)
        XCTAssertEqual(gaussianDensityTierCount, 64)
        XCTAssertEqual(gaussianDensityTiersPerOctave, 2)
        XCTAssertEqual(gaussianDensityTierLog2Floor, -2)
    }

    private struct SeededChunk {
        let splatCount: UInt32
        let screenArea: Float
    }

    /// A random population: `count` chunks, splat counts uniform over `splatRange`, areas
    /// log-uniform over `areaLog2Range` view units.
    private func seededPopulation(seed: UInt64, count: Int, splatRange: ClosedRange<Int> = 1 ... 16384, areaLog2Range: ClosedRange<Float> = -24 ... log2(gaussianScreenAreaGuard)) -> [SeededChunk] {
        var generator = GaussianSyntheticAsset.SplitMix64(seed: seed)
        return (0 ..< count).map { _ in
            let splatCount = UInt32(splatRange.lowerBound + Int(generator.next() % UInt64(splatRange.count)))
            let area = min(max(exp2(generator.value(in: areaLog2Range)), gaussianScreenAreaMin), gaussianScreenAreaGuard)
            return SeededChunk(splatCount: splatCount, screenArea: area)
        }
    }

    private func trueGrant(_ chunks: [SeededChunk], density: Float) -> Double {
        chunks.reduce(0.0) { $0 + min(Double($1.splatCount), Double(density) * Double($1.screenArea)) }
    }

    private func quotaSum(_ chunks: [SeededChunk], density: Float) -> Int {
        chunks.reduce(0) { $0 + Int(GaussianChunkCullMath.quota(densityCap: density, splatCount: $1.splatCount, screenArea: $1.screenArea)) }
    }

    /// Over seeded random populations: the bounded grant is at least the true grant (the sum
    /// over chunks of min(n, d × A)) and non-decreasing in the cap; the solved cap grants at
    /// most the grant asked for (bounded and per-chunk), is non-decreasing in the grant, is the
    /// largest such cap up to the bisection's resolution, and fills the grant to within the
    /// straddling tier's share plus the floors — 90 % less a splat per chunk on a population
    /// whose tiers each hold several chunks. Chunks denser than the last tier (more than 2^30
    /// splats per view: a few pixels holding thousands of splats) clamp into it and are never
    /// whole under any cap; the fill is measured against what the full density can grant.
    func testBoundedGrantBoundsTheTrueGrantAndIsMonotone() {
        var fillChecks = 0
        for population in 0 ..< 200 {
            var generator = GaussianSyntheticAsset.SplitMix64(seed: 0xC0FFEE &+ UInt64(population))
            let count = 1 + Int(generator.next() % 2000)
            // Every fourth population is squeezed into an octave of count and two of area, so
            // every one of its tiers holds several chunks and the round fill figure applies.
            let chunks = population % 4 == 3
                ? seededPopulation(seed: generator.next(), count: max(count, 1000), splatRange: 8192 ... 16384, areaLog2Range: -8 ... -6)
                : seededPopulation(seed: generator.next(), count: count)
            let histogram = GaussianChunkCullMath.densityHistogram(chunks: chunks.map { ($0.splatCount, $0.screenArea) })
            let requested = chunks.reduce(0) { $0 + Int($1.splatCount) }
            XCTAssertEqual(Int(histogram.requestedSplats), requested)
            XCTAssertEqual(Int(histogram.visibleChunks), chunks.count)
            let tiers = histogram.tierArray
            var chunksPerTier = [Int](repeating: 0, count: gaussianDensityTierCount)
            for chunk in chunks {
                chunksPerTier[GaussianChunkCullMath.densityTier(density: Float(chunk.splatCount) / chunk.screenArea)] += 1
            }
            for (tier, entry) in tiers.enumerated() where entry.splats > 0 {
                XCTAssertLessThanOrEqual(Int(entry.scaledArea), Int(entry.splats) + chunksPerTier[tier], "population \(population) tier \(tier): the scaled area is at most the splats plus one per chunk")
            }
            let fullDensity = GaussianChunkCullMath.fullDensity(histogram: histogram)
            XCTAssertTrue(fullDensity.isFinite)
            XCTAssertLessThanOrEqual(fullDensity, pow2(30))
            for chunk in chunks where Float(chunk.splatCount) / chunk.screenArea <= 0.9 * fullDensity {
                XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: fullDensity, splatCount: chunk.splatCount, screenArea: chunk.screenArea), chunk.splatCount, "population \(population): a chunk below the full density is whole there")
            }
            // What any cap can grant: the clamped chunks never reach their count.
            let achievable = quotaSum(chunks, density: fullDensity)
            XCTAssertLessThanOrEqual(achievable, requested)
            if tiers[gaussianDensityTierCount - 1].splats == 0 {
                XCTAssertEqual(achievable, requested, "population \(population): without clamped chunks the full density grants everything")
            }

            var previousGrant: Float = -1
            for step in 0 ..< 32 {
                let density = exp2(-16 + Float(step) * (31 + 16) / 31)
                let bounded = GaussianChunkCullMath.boundedGrant(histogram: histogram, density: density)
                XCTAssertGreaterThanOrEqual(Double(bounded) * (1 + 1e-6) + 1e-3, trueGrant(chunks, density: density), "population \(population) d=\(density): the bounded grant is at least the true grant")
                XCTAssertGreaterThanOrEqual(bounded, previousGrant, "population \(population): non-decreasing in d")
                XCTAssertLessThanOrEqual(Double(bounded), Double(requested) * (1 + 1e-6), "population \(population): never above the request")
                previousGrant = bounded
            }

            // Grants strictly below the request: a frame granted its whole request fits and
            // is whole without a solve.
            var previousCap: Float = -1
            for step in 1 ... 16 {
                let grant = UInt32(max(1, Int(Double(requested) * Double(step) / 17)))
                let cap = GaussianChunkCullMath.densityCap(histogram: histogram, grant: grant)
                XCTAssertTrue(cap.isFinite)
                XCTAssertGreaterThanOrEqual(cap, previousCap, "population \(population): the cap is non-decreasing in the grant")
                previousCap = cap
                let bounded = GaussianChunkCullMath.boundedGrant(histogram: histogram, density: cap)
                XCTAssertLessThanOrEqual(bounded, Float(grant), "population \(population) grant \(grant): the bounded grant at the cap is within the grant")
                let granted = quotaSum(chunks, density: cap)
                XCTAssertLessThanOrEqual(granted, Int(grant), "population \(population) grant \(grant): the quotas sum within the grant")
                // Maximal: a cap 2^-16 octaves above — past the bisection's resolution, which
                // the float spacing of log2 near 30 widens to a few 10^-6 octaves — grants at
                // least the grant in the same float arithmetic, and one 1/64 octave above
                // grants more.
                let above = cap * exp2(Float(sign: .plus, exponent: -16, significand: 1))
                if above < fullDensity {
                    XCTAssertGreaterThanOrEqual(GaussianChunkCullMath.boundedGrant(histogram: histogram, density: above), Float(grant), "population \(population) grant \(grant): a cap just above the bisection's resolution reaches the grant")
                }
                let wellAbove = cap * exp2(Float(sign: .plus, exponent: -6, significand: 1))
                if wellAbove < fullDensity {
                    XCTAssertGreaterThan(GaussianChunkCullMath.boundedGrant(histogram: histogram, density: wellAbove), Float(grant), "population \(population) grant \(grant): a cap 1/64 octave above over-grants")
                }
                // The fill: what the straddling tier's bound, the floors and the bisection can
                // leave ungranted, from the proof; and the spec's round figure on a population
                // whose non-empty tiers hold several chunks each.
                let reachable = min(Double(grant), Double(achievable))
                let straddling = tiers[GaussianChunkCullMath.densityTier(density: cap)].splats
                XCTAssertGreaterThanOrEqual(Double(granted), reachable * (1 - 1e-5) - 0.42 * Double(straddling) - 2 * Double(chunks.count), "population \(population) grant \(grant): the fill loss is bounded by the straddling tier and the floors")
                if zip(chunksPerTier, tiers).allSatisfy({ $1.splats == 0 || $0 >= 8 }) {
                    fillChecks += 1
                    XCTAssertGreaterThanOrEqual(Double(granted), 0.9 * reachable - Double(chunks.count), "population \(population) grant \(grant): at least 90 % of the grant less a splat per chunk")
                }
            }
            XCTAssertTrue(GaussianChunkCullMath.densityCap(histogram: histogram, grant: UInt32(requested), fits: true).isInfinite, "a fitting frame is whole")
            XCTAssertEqual(GaussianChunkCullMath.densityCap(histogram: histogram, grant: 0), 0, "nothing granted: cap 0")
        }
        XCTAssertGreaterThan(fillChecks, 100, "the fill bound was exercised")
        let empty = GaussianChunkCullMath.densityHistogram(chunks: [])
        XCTAssertTrue(GaussianChunkCullMath.fullDensity(histogram: empty).isInfinite)
        XCTAssertTrue(GaussianChunkCullMath.densityCap(histogram: empty, grant: 5).isInfinite, "no request: whole")
    }

    /// The density hysteresis: a fall is taken at once, a rise is capped at max(10 % of the
    /// previous cap, 5 % of the target), a previous cap of zero climbs by the step like any
    /// other (a chunked entity starved by a whole-buffer one fades in when room appears), a
    /// climb toward a fitting frame becomes whole (+inf) once it reaches the climb density,
    /// "whole" falls to a finite target at once, and a climb over ten octaves takes at most
    /// twenty frames.
    func testSmoothedDensityCapFallsAtOnceAndRisesByAStep() {
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 100, previous: 1000, climbDensity: 5000), 100, "a fall is taken at once")
        for (target, previous) in [(Float(1000), Float(100)), (2000, 1900), (1e6, 1), (3, 2)] {
            let expected = min(target, previous + max(0.1 * previous, 0.05 * target))
            XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: target, previous: previous, climbDensity: target * 4), expected, accuracy: expected * 1e-6, "a rise from \(previous) toward \(target) is one step")
        }
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: 0, climbDensity: 5000), 50, "from zero the cap climbs by 5 % of the target, as the scale climbs from zero")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: .infinity, previous: 0, climbDensity: 5000), 250, "from zero toward whole: 5 % of the climb density")
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.framesToReachDensity(target: 1000, from: 0), 20, "from zero to the target within twenty frames")
        XCTAssertGreaterThan(GaussianChunkCullMath.framesToReachDensity(target: 1000, from: 0), 10)
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: 0, climbDensity: 5000, takeTarget: true), 1000, "a reset takes the target")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: 500, climbDensity: 5000, takeTarget: true), 1000, "a reset takes the target")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: -1, climbDensity: 5000), 1000, "a previous cap below zero (never produced) takes the target")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: .nan, climbDensity: 5000), 1000, "so does a NaN")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 1000, previous: 500, climbDensity: 5000), 550)
        let towardWhole = GaussianChunkCullMath.smoothedDensityCap(target: .infinity, previous: 1000, climbDensity: 5000)
        XCTAssertEqual(towardWhole, 1250, "toward a fitting frame the step is 5 % of the climb density (or 10 % of the cap)")
        XCTAssertTrue(GaussianChunkCullMath.smoothedDensityCap(target: .infinity, previous: 4800, climbDensity: 5000).isInfinite, "a climb that reaches the climb density becomes whole")
        XCTAssertTrue(GaussianChunkCullMath.smoothedDensityCap(target: .infinity, previous: .infinity, climbDensity: 5000).isInfinite, "whole stays whole")
        XCTAssertEqual(GaussianChunkCullMath.smoothedDensityCap(target: 700, previous: .infinity, climbDensity: 5000), 700, "whole falls to a finite target at once")
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.framesToReachDensity(target: pow2(20), from: pow2(10)), 20)
        XCTAssertGreaterThan(GaussianChunkCullMath.framesToReachDensity(target: pow2(20), from: pow2(10)), 5)
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.framesToReachDensity(target: .infinity, from: 0.3, climbDensity: pow2(19)), 20, "from the uniform scale to whole in at most twenty frames")
    }

    /// The climb density: the floor of the tier above the densest tiers that together hold at
    /// most 5 % of the request — a sliver of a chunk in tier 63 leaves it where the population
    /// is, and without a tail to spare it is the full density.
    func testClimbDensityLeavesTheDensestTailToTheWhole() {
        // 100 chunks of 1024 in tiers 20 … 29 (ten per tier), one sliver of 1024 in tier 63.
        var chunks: [(splatCount: UInt32, screenArea: Float)] = []
        for tier in 20 ..< 30 {
            let density = GaussianChunkCullMath.densityTierFloor(tier) * 1.1
            chunks += Array(repeating: (splatCount: UInt32(1024), screenArea: 1024 / density), count: 10)
        }
        let population = GaussianChunkCullMath.densityHistogram(chunks: chunks)
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: population), GaussianChunkCullMath.densityTierFloor(30), "5 % of 100 chunks is five: no whole tier of ten fits the tail, the climb density is the full density")
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: population, tailFraction: 0.1), GaussianChunkCullMath.densityTierFloor(29), "a 10 % tail spares the top tier")
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: population, tailFraction: 0.2), GaussianChunkCullMath.densityTierFloor(28))
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: population, tailFraction: 0), GaussianChunkCullMath.fullDensity(histogram: population), "no tail: the full density")

        chunks.append((splatCount: 1024, screenArea: gaussianScreenAreaMin))
        let withSliver = GaussianChunkCullMath.densityHistogram(chunks: chunks)
        XCTAssertEqual(GaussianChunkCullMath.fullDensity(histogram: withSliver), pow2(30), "the sliver sets the full density")
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: withSliver), GaussianChunkCullMath.densityTierFloor(30), "but not the climb density: it is the tail")
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: withSliver, tailFraction: 0.1), GaussianChunkCullMath.densityTierFloor(30), "a 10 % tail (10,342 splats) holds the sliver but not the top tier with it (11,264)")
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: withSliver, tailFraction: 0.12), GaussianChunkCullMath.densityTierFloor(29), "a 12 % tail holds both")

        XCTAssertTrue(GaussianChunkCullMath.climbDensity(histogram: GaussianChunkCullMath.densityHistogram(chunks: [])).isInfinite, "no chunk: whole")
        let one = GaussianChunkCullMath.densityHistogram(chunks: [(splatCount: 16, screenArea: 0.5)])
        XCTAssertEqual(GaussianChunkCullMath.climbDensity(histogram: one), GaussianChunkCullMath.fullDensity(histogram: one), "one chunk is never its own tail")
    }

    /// The quota rule: non-decreasing in the cap, zero exactly while the cap grants less than
    /// one splat, the whole count exactly from the cap that grants it, the whole count under
    /// +inf; and the opacity band of a one- or two-splat quota is degenerate (factor 1).
    func testQuotaIsMonotoneInTheCapAndZeroBelowOneSplat() {
        let area: Float = 0.0125
        let splatCount: UInt32 = 1024
        var previous: UInt32 = 0
        for step in 0 ... 400 {
            let cap = Float(step) * 0.25 / area
            let quota = GaussianChunkCullMath.quota(densityCap: cap, splatCount: splatCount, screenArea: area)
            XCTAssertGreaterThanOrEqual(quota, previous, "cap \(cap): non-decreasing")
            XCTAssertEqual(quota == 0, cap * area < 1, "cap \(cap): zero iff less than one splat")
            XCTAssertEqual(quota == splatCount, cap * area >= Float(splatCount), "cap \(cap): whole iff the product reaches the count")
            XCTAssertLessThanOrEqual(quota, splatCount)
            previous = quota
        }
        XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: .infinity, splatCount: splatCount, screenArea: gaussianScreenAreaMin), splatCount)
        XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: 0, splatCount: splatCount, screenArea: gaussianScreenAreaGuard), 0)
        XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: 3600, splatCount: 80, screenArea: 0.005), 18, "the worked example's far chunk")
        XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: 3600, splatCount: 80, screenArea: 0.5), 80, "and its near chunk")
        XCTAssertEqual(GaussianChunkCullMath.opacityBandFactor(rank: 0, quota: 1, splatCount: 16), 1)
        XCTAssertEqual(GaussianChunkCullMath.opacityBandFactor(rank: 0, quota: 2, splatCount: 16), 1)
        XCTAssertEqual(GaussianChunkCullMath.opacityBandFactor(rank: 1, quota: 2, splatCount: 16), 1, "a two-splat quota has a degenerate band")
    }

    /// The shared layouts the kernels and the readbacks depend on.
    func testLayoutsArePinned() {
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.stride, 176)
        XCTAssertEqual(MemoryLayout<GaussianVisibleChunk>.stride, 16)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityTier>.stride, 8)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.stride, 528)
        XCTAssertEqual(MemoryLayout<GaussianVisibleChunk>.offset(of: \.screenArea), 12)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.offset(of: \.densityCap), 28)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.offset(of: \.uniformQuotas), 24)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.offset(of: \.densityMinStepFraction), 28)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.offset(of: \.uniformQuotas), 168)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.targetDensity), 512)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.fullDensity), 516)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.grant), 520)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.visibleChunks), 524)
        XCTAssertEqual(gaussianChunkCullDensityHistogramIndex.rawValue, 7)
        XCTAssertEqual(gaussianBudgetDensityHistogramIndex.rawValue, 7)
        XCTAssertEqual(gaussianBudgetDensityReadbackIndex.rawValue, 8)
        XCTAssertEqual(gaussianScreenAreaGuard, 1.5625)
        XCTAssertEqual(gaussianScreenAreaMin, pow2(-24))
        var histogram = GaussianBudgetDensityHistogram()
        var tiers = histogram.tierArray
        XCTAssertEqual(tiers.count, gaussianDensityTierCount)
        tiers[5] = GaussianBudgetDensityTier(splats: 7, scaledArea: 9)
        histogram.setTiers(tiers)
        XCTAssertEqual(histogram.tier(5).splats, 7)
        XCTAssertEqual(histogram.tier(5).scaledArea, 9)
        XCTAssertEqual(histogram.requestedSplats, 7)
        withUnsafeBytes(of: histogram) { bytes in
            XCTAssertEqual(bytes.load(fromByteOffset: 40, as: UInt32.self), 7, "tier t's splats sit at word 2t")
            XCTAssertEqual(bytes.load(fromByteOffset: 44, as: UInt32.self), 9, "and its scaled area at word 2t + 1")
        }
    }
}
