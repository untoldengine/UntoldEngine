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
//  to whole, that a sliver in the last density tier does not set the climb's step, that a
//  fitting frame stays whole, that leaving chunks free budget that fades back
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

    // MARK: - GPU fixtures

    /// The far camera of GaussianChunkCullTest: the whole 200-splat fixture in view (13 chunks).
    private let farCamera = (eye: simd_float3(0, 3, 7), target: simd_float3.zero)
    /// Its close view of the +x/+y corner: 8 of the 13 chunks.
    private let cornerCamera = (eye: simd_float3(1.0, 1.0, 0.6), target: simd_float3(1.0, 1.0, 0))
    /// Its close view of the −x side: 12 of the 13 chunks.
    private let sideCamera = (eye: simd_float3(-1.0, 0.2, 1.0), target: simd_float3(-1.0, 0.2, 0))
    /// The budget suite's view of the synthetic slab from above its centre.
    private let slabCamera = (eye: simd_float3(0, 6, 3), target: simd_float3.zero)

    private struct ChunkedFixture {
        let entity: EntityID
        let component: GaussianComponent
        let table: GaussianChunkTable
        let cpu: UntoldGSAsset
        let resolver: GaussianSplatIndexResolver
    }

    private struct SlabFixture {
        let entity: EntityID
        let component: GaussianComponent
        let table: GaussianChunkTable
        var splatCount: Int {
            Int(component.splatCount)
        }
    }

    private func bakeV3(chunkSplats log2: UInt8) throws -> URL {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianScreenWeightedQuotaTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    /// The 200-splat fixture baked at 2^`log2` splats per chunk, placed at `position`.
    private func loadFixture(chunkSplats log2: UInt8 = 4, at position: simd_float3 = .zero) throws -> ChunkedFixture {
        let url = try bakeV3(chunkSplats: log2)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        if position != .zero {
            translateTo(entityId: entity, position: position)
        }
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        let cpu = try UntoldGSFormat.read(from: url)
        return ChunkedFixture(entity: entity, component: component, table: table, cpu: cpu, resolver: GaussianSplatIndexResolver(positions: cpu.encodedSplats.map(\.position)))
    }

    /// The 300,000-splat synthetic slab (GaussianSyntheticAsset), 1024 splats per chunk.
    private func loadSlab() throws -> SlabFixture {
        let url = try GaussianSyntheticAsset.url(splatCount: 300_000)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertEqual(table.splatsPerChunk, 1024)
        return SlabFixture(entity: entity, component: component, table: table)
    }

    private func runFrame() {
        runGaussianCullAndPreprocess()
    }

    /// The chunk table's decode constants, by chunk index.
    private func decodeConstants(_ table: GaussianChunkTable) -> [GaussianChunkDecodeConstants] {
        Array(UnsafeBufferPointer(start: table.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: table.chunkCount), count: table.chunkCount))
    }

    private func entriesByChunk(_ entries: [GaussianVisibleChunk]) -> [UInt32: GaussianVisibleChunk] {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.chunkIndex, $0) })
    }

    /// The visible count of the current view with the budget at the resident total, after a
    /// hysteresis reset — the frame every "a quarter of the visible count" budget is taken from.
    private func unlimitedVisibleCount(residentSplats: Int) -> Int {
        GaussianRuntimeLimits.workingSetSplatsOverride = residentSplats
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        return sharedGaussianVisibleCount()
    }

    /// The largest rise of the cap from `previous` toward `target` in one frame, the climb
    /// density of `histogram` standing in for an infinite target.
    private func densityStep(previous: Float, target: Float, histogram: GaussianBudgetDensityHistogram) -> Float {
        max(previous * gaussianBudgetMaxStepFraction, gaussianBudgetDensityMinStepFraction * (target.isInfinite ? GaussianChunkCullMath.climbDensity(histogram: histogram) : target))
    }

    /// The working set's record of the last completed frame, once the completed handler has
    /// delivered the frame whose grant is `grant` (it runs on the command buffer's completion,
    /// which `waitUntilCompleted` need not order after it).
    private func recordedReadback(grant: UInt32) throws -> (state: GaussianBudgetState, histogram: GaussianBudgetDensityHistogram) {
        let deadline = Date().addingTimeInterval(1)
        while GaussianSharedWorkingSet.shared.lastDensityHistogram.grant != grant, Date() < deadline {
            usleep(1000)
        }
        return (GaussianSharedWorkingSet.shared.lastBudgetState, GaussianSharedWorkingSet.shared.lastDensityHistogram)
    }

    /// Every entry's quota is the mirror's from the GPU's own cap and area; returns the sum.
    @discardableResult
    private func assertQuotasFollowTheCap(_ entries: [GaussianVisibleChunk], densityCap: Float, file: StaticString = #filePath, line: UInt = #line) -> Int {
        var total = 0
        for entry in entries {
            let expected = GaussianChunkCullMath.quota(densityCap: densityCap, splatCount: entry.splatCount, screenArea: entry.screenArea)
            XCTAssertEqual(entry.quota, expected, "chunk \(entry.chunkIndex): quota = min(n, floor(cap × area)) with cap \(densityCap) and area \(entry.screenArea)", file: file, line: line)
            XCTAssertGreaterThanOrEqual(entry.screenArea, gaussianScreenAreaMin, file: file, line: line)
            XCTAssertLessThanOrEqual(entry.screenArea, gaussianScreenAreaGuard, file: file, line: line)
            total += Int(entry.quota)
        }
        return total
    }

    /// The GPU's histogram is the mirror's from the GPU's own areas, allowing a chunk whose
    /// density lies within 1e-5 of a tier bound to land on either side (the GPU's division may
    /// differ from the CPU's by an ulp).
    private func assertHistogramMatchesTheMirror(_ gpu: GaussianBudgetDensityHistogram, entries: [GaussianVisibleChunk], file: StaticString = #filePath, line: UInt = #line) {
        let count = gaussianDensityTierCount
        var certainSplats = [Int](repeating: 0, count: count)
        var certainArea = [Int](repeating: 0, count: count)
        var slackSplats = [Int](repeating: 0, count: count)
        var slackArea = [Int](repeating: 0, count: count)
        for entry in entries {
            let density = Float(entry.splatCount) / entry.screenArea
            let tier = GaussianChunkCullMath.densityTier(density: density)
            let lower = GaussianChunkCullMath.densityTierFloor(tier)
            let upper = GaussianChunkCullMath.densityTierFloor(tier + 1)
            let nearBound = abs(density - lower) <= 1e-5 * density || abs(density - upper) <= 1e-5 * density
            for candidate in nearBound ? [tier - 1, tier, tier + 1] : [tier] where candidate >= 0 && candidate < count {
                let area = Int(ceil(entry.screenArea * GaussianChunkCullMath.densityTierFloor(candidate)))
                if nearBound {
                    slackSplats[candidate] += Int(entry.splatCount)
                    slackArea[candidate] += area
                } else {
                    certainSplats[candidate] += Int(entry.splatCount)
                    certainArea[candidate] += area
                }
            }
        }
        for (tier, gpuTier) in gpu.tierArray.enumerated() {
            XCTAssertGreaterThanOrEqual(Int(gpuTier.splats), certainSplats[tier], "tier \(tier): the GPU holds every chunk the mirror bins there", file: file, line: line)
            XCTAssertLessThanOrEqual(Int(gpuTier.splats), certainSplats[tier] + slackSplats[tier], "tier \(tier): and nothing the mirror bins elsewhere", file: file, line: line)
            XCTAssertGreaterThanOrEqual(Int(gpuTier.scaledArea), certainArea[tier], "tier \(tier): scaled area", file: file, line: line)
            XCTAssertLessThanOrEqual(Int(gpuTier.scaledArea), certainArea[tier] + slackArea[tier], "tier \(tier): scaled area", file: file, line: line)
        }
        XCTAssertEqual(Int(gpu.requestedSplats), entries.reduce(0) { $0 + Int($1.splatCount) }, file: file, line: line)
    }

    /// The head view-projection the frame's mono cull tests `entity`'s chunks against.
    private func headViewProjection(entity: EntityID) throws -> simd_float4x4 {
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: entity))
        return simd_mul(renderInfo.perspectiveSpace, simd_mul(SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace), world.space))
    }

    // MARK: - GPU, mono

    /// One truncated frame over the slab: every visible chunk's quota is exactly the mirror's
    /// from the GPU's cap and area, the sums agree, the histogram is the mirror's from the GPU's
    /// areas, the cap's bounded grant is within the grant (the room), and the quotas fill it to
    /// within the straddling tier and a splat per chunk.
    func testEveryQuotaFollowsTheGPUsDensityCap() throws {
        let slab = try loadSlab()
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        XCTAssertGreaterThan(unlimited, 10000, "sanity — the camera sees a good part of the slab")
        let budget = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()

        let state = try budgetState()
        let histogram = try densityReadback()
        let readback = visibleChunkEntries(slab.table)
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget)
        XCTAssertGreaterThan(Int(state.requestedSplats), budget, "sanity — truncated")
        XCTAssertLessThan(state.targetScale, 1)
        XCTAssertTrue(state.densityCap.isFinite)
        XCTAssertGreaterThan(state.densityCap, 0)
        XCTAssertEqual(state.densityCap, histogram.targetDensity, "the first frame after a reset takes the target")
        XCTAssertLessThan(state.densityCap, histogram.fullDensity)

        let total = assertQuotasFollowTheCap(readback.entries, densityCap: state.densityCap)
        XCTAssertEqual(total, Int(state.quotaSplats), "the quotas sum to the state's grant")
        XCTAssertEqual(Int(readback.record.visibleCount), total, "and to the chunk record's count")
        XCTAssertEqual(Int(readback.record.instanceCount), Int(state.requestedSplats))
        assertHistogramMatchesTheMirror(histogram, entries: readback.entries)
        XCTAssertEqual(Int(histogram.visibleChunks), readback.entries.count)
        XCTAssertEqual(Int(histogram.grant), Int(gaussianBudgetHeadroom * Float(budget)), "the grant is the room: floor(0.98 × budget), no reservation")
        // The GPU chose the cap so that its own G(cap) is within the grant; the CPU's G differs
        // from the kernel's fast-math division by a few ulps, so the re-evaluation gets a
        // relative tolerance — the integer bound below is the exact one.
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.boundedGrant(histogram: histogram, density: state.densityCap), Float(histogram.grant) * (1 + 1e-5), "G(cap) ≤ grant")
        XCTAssertLessThanOrEqual(Int(state.quotaSplats), Int(histogram.grant))
        let straddling = histogram.tier(GaussianChunkCullMath.densityTier(density: state.densityCap)).splats
        XCTAssertGreaterThanOrEqual(Double(state.quotaSplats), Double(histogram.grant) * (1 - 1e-5) - 0.42 * Double(straddling) - 2 * Double(readback.entries.count), "the fill loss is bounded by the straddling tier and the floors")
        XCTAssertGreaterThanOrEqual(Int(state.quotaSplats), Int(0.9 * Double(histogram.grant)) - readback.entries.count, "the quotas fill at least 90 % of the grant less a splat per chunk")
        let mirrorTarget = GaussianChunkCullMath.densityCap(histogram: histogram, grant: histogram.grant)
        XCTAssertEqual(histogram.targetDensity, mirrorTarget, accuracy: 1e-4 * mirrorTarget, "the solve is the mirror's")
        try assertFrameFits()

        // The CPU readback the profile line and the benchmark read: the completed handler copied
        // this slot's state and histogram into the working set.
        let recorded = try recordedReadback(grant: histogram.grant)
        XCTAssertEqual(recorded.histogram.grant, histogram.grant, "lastDensityHistogram carries the slot's grant")
        XCTAssertEqual(recorded.histogram.visibleChunks, histogram.visibleChunks)
        XCTAssertEqual(recorded.histogram.targetDensity.bitPattern, histogram.targetDensity.bitPattern)
        XCTAssertEqual(recorded.histogram.fullDensity.bitPattern, histogram.fullDensity.bitPattern)
        XCTAssertEqual(recorded.histogram.tierArray.map(\.splats), histogram.tierArray.map(\.splats), "and its tiers")
        XCTAssertEqual(recorded.state.densityCap.bitPattern, state.densityCap.bitPattern, "lastBudgetState carries the slot's cap")
        XCTAssertEqual(recorded.state.quotaSplats, state.quotaSplats)
        XCTAssertEqual(recorded.state.requestedSplats, state.requestedSplats)
        print(String(format: "[GaussianScreenWeightedQuotaTest] slab quarter budget %d: %d chunks, grant %u, quota %u (fill %.3f), cap %.4g, full %.4g", budget, readback.entries.count, histogram.grant, state.quotaSplats, Double(state.quotaSplats) / Double(histogram.grant), Double(state.densityCap), Double(histogram.fullDensity)))
    }

    /// At the same budget the chunks large on screen keep more of their splats than the small
    /// ones: quota over count is monotone in the area among equal chunks, the upper half by area
    /// keeps at least twice the fraction of the lower half, the largest tenth at least three
    /// times the smallest tenth's and some of it is whole; with the uniform switch every chunk
    /// keeps the same fraction. And in the two-entity form — the
    /// fixture at 4 and at 16 units along one line of sight, a budget with room for 60 % of the
    /// request — the near copy stays whole while the far one takes what is left.
    func testNearChunksKeepMoreThanFarChunksAtTheSameBudget() throws {
        let slab = try loadSlab()
        // A low view across the slab: its near edge about 2 units away, the far edge 13, so the
        // chunks' screen areas span well over a decade.
        placeGaussianTestCamera(eye: simd_float3(0, 1.6, 7.5), target: simd_float3(0, 0, -3))
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        let budget = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let state = try budgetState()
        XCTAssertLessThan(state.targetScale, 1, "sanity — truncated")
        let entries = visibleChunkEntries(slab.table).entries.filter { $0.splatCount == UInt32(slab.table.splatsPerChunk) }
        XCTAssertGreaterThan(entries.count, 40, "sanity — enough whole chunks in view")
        assertQuotasFollowTheCap(entries, densityCap: state.densityCap)
        let byArea = entries.sorted { $0.screenArea < $1.screenArea }
        XCTAssertGreaterThan(try XCTUnwrap(byArea.last?.screenArea) / byArea.first!.screenArea, 8, "sanity — the areas span nearly a decade")
        for (smaller, larger) in zip(byArea, byArea.dropFirst()) {
            XCTAssertLessThanOrEqual(smaller.quota, larger.quota, "chunk \(smaller.chunkIndex) (area \(smaller.screenArea)) keeps no more than chunk \(larger.chunkIndex) (area \(larger.screenArea))")
        }
        func meanFraction(_ chunks: ArraySlice<GaussianVisibleChunk>) -> Double {
            chunks.reduce(0.0) { $0 + Double($1.quota) / Double($1.splatCount) } / Double(max(1, chunks.count))
        }
        let half = byArea.count / 2
        let lower = meanFraction(byArea[..<half])
        let upper = meanFraction(byArea[half...])
        XCTAssertGreaterThanOrEqual(upper, 2 * lower, "the larger half keeps at least twice the fraction of the smaller half (\(upper) vs \(lower))")
        // Truncated chunks keep a fraction proportional to their area, so the largest tenth
        // keeps at least three times what the smallest tenth keeps, and the chunks nearest the
        // camera — the largest on screen — are whole while the smallest are cut.
        let tenth = max(1, byArea.count / 10)
        let top = meanFraction(byArea[(byArea.count - tenth)...])
        let bottom = meanFraction(byArea[..<tenth])
        XCTAssertGreaterThanOrEqual(top, 3 * bottom, "the largest tenth keeps at least three times the fraction of the smallest tenth (\(top) vs \(bottom))")
        XCTAssertTrue(byArea.suffix(tenth).contains { $0.quota == $0.splatCount }, "some of the largest chunks are whole")
        XCTAssertLessThan(try XCTUnwrap(byArea.first?.quota), try XCTUnwrap(byArea.first?.splatCount), "the smallest chunk is truncated")
        try assertFrameFits()

        // The uniform switch: every chunk's area is its count, every quota the same fraction.
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let uniformState = try budgetState()
        XCTAssertLessThan(uniformState.scale, 1)
        XCTAssertEqual(uniformState.densityCap, uniformState.scale, "under the switch the cap is the scale")
        XCTAssertTrue(try densityReadback().targetDensity.isInfinite, "no solve")
        for entry in visibleChunkEntries(slab.table).entries {
            XCTAssertEqual(entry.screenArea, Float(entry.splatCount), "chunk \(entry.chunkIndex): density 1")
            XCTAssertEqual(entry.quota, GaussianChunkCullMath.quota(scale: uniformState.scale, splatCount: entry.splatCount), "chunk \(entry.chunkIndex): floor(scale × n)")
        }
        try assertFrameFits()
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        destroyAllEntities()

        // Two copies of the fixture on the far camera's line of sight, at 4 and 16 units.
        let direction = simd_normalize(farCamera.target - farCamera.eye)
        let near = try loadFixture(at: farCamera.eye + 4 * direction)
        let far = try loadFixture(at: farCamera.eye + 16 * direction)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        GaussianRuntimeLimits.workingSetSplatsOverride = 400
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        XCTAssertEqual(try Int(budgetState().requestedSplats), 400, "sanity — both copies are wholly in view")
        // Room for 60 % of the request: the near copy (16 × the far one's area) is whole, the
        // far copy takes the rest.
        let twoBudget = 245
        GaussianRuntimeLimits.workingSetSplatsOverride = twoBudget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let twoState = try budgetState()
        XCTAssertEqual(twoState.targetScale, GaussianChunkCullMath.targetScale(requestedSplats: 400, budget: twoBudget), accuracy: 1e-6)
        XCTAssertEqual(twoState.targetScale, 0.6, accuracy: 0.01)
        let nearQuota = visibleChunkEntries(near.table).entries.reduce(0) { $0 + Int($1.quota) }
        let farQuota = visibleChunkEntries(far.table).entries.reduce(0) { $0 + Int($1.quota) }
        XCTAssertGreaterThanOrEqual(Double(nearQuota) / 200, 0.9, "the near copy keeps at least 90 % (\(nearQuota) of 200)")
        XCTAssertLessThan(Double(farQuota) / 200, Double(twoState.targetScale), "the far copy keeps less than the uniform fraction (\(farQuota) of 200)")
        XCTAssertGreaterThan(farQuota, 0)
        XCTAssertEqual(nearQuota + farQuota, Int(twoState.quotaSplats))
        try assertFrameFits()
    }

    /// Over a budget lift that stays truncated, the GPU's cap is the mirror's every frame — the
    /// target from this frame's histogram, smoothed against the previous cap — rising by at most
    /// a step, the grant never falling, every frame fitting.
    func testDensityCapMatchesTheCPUMirrorOverAClimb() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        GaussianRuntimeLimits.workingSetSplatsOverride = 100
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        var state = try budgetState()
        var histogram = try densityReadback()
        XCTAssertEqual(Int(state.requestedSplats), 200)
        XCTAssertEqual(Int(histogram.grant), 98)
        XCTAssertEqual(state.densityCap, histogram.targetDensity, "the first frame takes the target")
        let firstTarget = GaussianChunkCullMath.densityCap(histogram: histogram, grant: histogram.grant)
        XCTAssertEqual(histogram.targetDensity, firstTarget, accuracy: 1e-4 * firstTarget, "the solve is the mirror's")
        XCTAssertEqual(histogram.fullDensity, GaussianChunkCullMath.fullDensity(histogram: histogram))
        assertQuotasFollowTheCap(visibleChunkEntries(fixture.table).entries, densityCap: state.densityCap)
        try assertFrameFits()

        GaussianRuntimeLimits.workingSetSplatsOverride = 160
        var previousCap = state.densityCap
        var previousQuota = Int(state.quotaSplats)
        var caps: [Float] = [previousCap]
        for frame in 0 ..< 12 {
            runFrame()
            state = try budgetState()
            histogram = try densityReadback()
            XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, 160)
            XCTAssertLessThan(state.targetScale, 1, "frame \(frame): still truncated")
            XCTAssertEqual(Int(histogram.grant), Int(gaussianBudgetHeadroom * 160))
            let target = GaussianChunkCullMath.densityCap(histogram: histogram, grant: histogram.grant)
            XCTAssertEqual(histogram.targetDensity, target, accuracy: 1e-4 * target, "frame \(frame): the target is the mirror's")
            let full = GaussianChunkCullMath.fullDensity(histogram: histogram)
            XCTAssertEqual(histogram.fullDensity, full)
            let expected = GaussianChunkCullMath.smoothedDensityCap(target: target, previous: previousCap, climbDensity: GaussianChunkCullMath.climbDensity(histogram: histogram))
            XCTAssertEqual(state.densityCap, expected, accuracy: 1e-4 * expected, "frame \(frame): the cap is the mirror's: \(caps)")
            XCTAssertLessThanOrEqual(state.densityCap, previousCap + densityStep(previous: previousCap, target: target, histogram: histogram) + 1e-4 * previousCap, "frame \(frame): the rise is at most one step")
            XCTAssertGreaterThanOrEqual(state.densityCap, previousCap, "frame \(frame): a lift never lowers the cap")
            XCTAssertGreaterThanOrEqual(Int(state.quotaSplats), previousQuota, "frame \(frame): the grant never falls")
            assertQuotasFollowTheCap(visibleChunkEntries(fixture.table).entries, densityCap: state.densityCap)
            try assertFrameFits()
            caps.append(state.densityCap)
            previousCap = state.densityCap
            previousQuota = Int(state.quotaSplats)
        }
        XCTAssertEqual(state.densityCap, histogram.targetDensity, accuracy: 1e-4 * histogram.targetDensity, "arrived at the target: \(caps)")
        XCTAssertGreaterThan(caps.count(where: { $0 < caps.last! * 0.999 }), 1, "the climb took several frames: \(caps)")
    }

    /// Two frames at the same pose and budget are bit-identical: entries, cap, histogram, sorted
    /// depth keys, shared count.
    func testTwoIdenticalFramesAreBitIdentical() throws {
        let slab = try loadSlab()
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        GaussianRuntimeLimits.workingSetSplatsOverride = max(1, unlimited / 4)
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        struct Frame {
            /// chunkIndex, screenArea bits, quota per entry, by chunk index.
            let entries: [UInt32]
            let cap: UInt32
            /// splats, scaledArea per tier, then the header's four words.
            let histogram: [UInt32]
            let depths: [UInt32]
            let shared: Int
        }
        func capture() throws -> Frame {
            let depths = sortedDepthWords()
            let entries = visibleChunkEntries(slab.table).entries.sorted { $0.chunkIndex < $1.chunkIndex }.flatMap { [$0.chunkIndex, $0.screenArea.bitPattern, $0.quota] }
            let histogram = try densityReadback()
            return try Frame(
                entries: entries,
                cap: budgetState().densityCap.bitPattern,
                histogram: histogram.tierArray.flatMap { [$0.splats, $0.scaledArea] } + [histogram.targetDensity.bitPattern, histogram.fullDensity.bitPattern, histogram.grant, histogram.visibleChunks],
                depths: depths,
                shared: sharedGaussianVisibleCount()
            )
        }
        let first = try capture()
        let second = try capture()
        XCTAssertGreaterThan(first.entries.count, 30)
        XCTAssertEqual(first.entries, second.entries, "the same chunks with the same areas and quotas")
        XCTAssertEqual(first.cap, second.cap, "the same cap bit for bit")
        XCTAssertEqual(first.histogram, second.histogram, "the same histogram")
        XCTAssertEqual(first.depths, second.depths, "the same sorted depth keys")
        XCTAssertEqual(first.depths, first.depths.sorted(), "ascending")
        XCTAssertEqual(first.shared, second.shared)
        XCTAssertEqual(first.shared, first.depths.count)
        try assertFrameFits()
    }

    /// Seeded random poses around, inside and grazing the slab, beside a reserved `.ply`, at
    /// budgets from an eighth to three quarters of each pose's visible count: no frame ever
    /// exceeds its budget, the reservation comes first, and a truncated frame leaves the headroom.
    func testBudgetSweepNeverExceedsTheBudget() throws {
        let slab = try loadSlab()
        let ply = createEntity()
        setEntityGaussian(entityId: ply, filename: "test_gaussians", withExtension: "ply")
        let plyComponent = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: ply))
        translateTo(entityId: ply, position: simd_float3(0.5, 0.6, 0))
        let resident = slab.splatCount + Int(plyComponent.splatCount)
        var generator = GaussianSyntheticAsset.SplitMix64(seed: 0x5EED_5A1E)
        var poses: [(eye: simd_float3, target: simd_float3)] = []
        for _ in 0 ..< 16 {
            poses.append((simd_float3(generator.value(in: -10 ... 10), generator.value(in: 3 ... 10), generator.value(in: -10 ... 10)), simd_float3(generator.value(in: -5 ... 5), 0, generator.value(in: -5 ... 5))))
        }
        for _ in 0 ..< 4 {
            let eye = simd_float3(generator.value(in: -5 ... 5), generator.value(in: -0.2 ... 0.2), generator.value(in: -5 ... 5))
            let heading = generator.value(in: 0 ... 6.283)
            poses.append((eye, eye + simd_float3(cos(heading), 0, sin(heading))))
        }
        for i in 0 ..< 4 {
            poses.append((simd_float3(generator.value(in: -7 ... 7), 0.35, i % 2 == 0 ? 7 : -7), simd_float3(generator.value(in: -3 ... 3), 0.3, 0)))
        }
        var truncatedFrames = 0
        for (poseIndex, pose) in poses.enumerated() {
            let camera = placeGaussianTestCamera(eye: pose.eye, target: pose.target)
            defer { destroyEntity(entityId: camera) }
            let unlimited = unlimitedVisibleCount(residentSplats: resident)
            let plySlot = min(renderInfo.currentInFlightFrameSlot, plyComponent.gaussianVisibleCount.count - 1)
            let plyVisible = try Int(XCTUnwrap(plyComponent.gaussianVisibleCount[plySlot]).contents().load(as: GaussianVisibleSet.self).visibleCount)
            XCTAssertEqual(try Int(budgetState().reservedSplats), plyVisible, "pose \(poseIndex): the .ply is reserved")
            try assertFrameFits()
            for fraction in [0.75, 0.5, 0.25, 0.125, 0.25, 0.5] {
                let budget = max(1, Int(Double(unlimited) * fraction))
                GaussianRuntimeLimits.workingSetSplatsOverride = budget
                runFrame()
                let state = try budgetState()
                let set = sharedVisibleSet()
                XCTAssertEqual(Int(state.reservedSplats), plyVisible, "pose \(poseIndex) budget \(budget): the .ply is reserved first")
                XCTAssertEqual(set.overflowCount, 0, "pose \(poseIndex) budget \(budget)")
                XCTAssertLessThanOrEqual(Int(state.quotaSplats) + Int(state.reservedSplats), Int(state.budget), "pose \(poseIndex) budget \(budget): within the budget")
                if state.targetScale < 1 {
                    truncatedFrames += 1
                    XCTAssertLessThanOrEqual(Int(state.quotaSplats) + Int(state.reservedSplats), max(Int(gaussianBudgetHeadroom * Float(state.budget)), Int(state.reservedSplats)), "pose \(poseIndex) budget \(budget): a truncated frame leaves the headroom")
                }
                try assertFrameFits()
            }
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
        }
        XCTAssertGreaterThan(truncatedFrames, 60, "sanity — most budgets truncate")
    }

    /// A cut is taken at once and a lift climbs to whole: unlimited (whole), a quarter without a
    /// reset (the cap falls to its target that frame and stays), unlimited again (the cap rises
    /// by at most a step per frame and is whole within twenty frames). The scale climbs on its
    /// own schedule beside it.
    func testACutFallsAtOnceAndALiftClimbsToWhole() throws {
        let slab = try loadSlab()
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        var state = try budgetState()
        XCTAssertTrue(state.densityCap.isInfinite, "unlimited: whole")
        XCTAssertEqual(state.scale, 1)
        XCTAssertTrue(visibleChunkEntries(slab.table).entries.allSatisfy { $0.quota == $0.splatCount })
        try assertFrameFits()

        let quarter = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = quarter
        runFrame()
        state = try budgetState()
        var histogram = try densityReadback()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, quarter)
        XCTAssertTrue(state.densityCap.isFinite)
        XCTAssertEqual(state.densityCap, histogram.targetDensity, "the fall is taken at once")
        XCTAssertLessThan(state.densityCap, histogram.fullDensity)
        XCTAssertEqual(state.scale, state.targetScale, "and so is the scale's")
        try assertFrameFits()
        let cutCap = state.densityCap
        for frame in 0 ..< 3 {
            runFrame()
            state = try budgetState()
            XCTAssertEqual(state.densityCap, cutCap, "frame \(frame): stays")
            try assertFrameFits()
        }

        GaussianRuntimeLimits.workingSetSplatsOverride = slab.splatCount
        var previousCap = cutCap
        var previousScale = state.scale
        var climb: [Float] = [cutCap]
        var frames = 0
        for _ in 0 ..< 30 {
            runFrame()
            state = try budgetState()
            histogram = try densityReadback()
            frames += 1
            XCTAssertTrue(histogram.targetDensity.isInfinite, "the lifted frame fits: the target is whole")
            XCTAssertEqual(state.scale, GaussianChunkCullMath.smoothedScale(target: 1, previous: previousScale), accuracy: 1e-5, "the scale climbs as before")
            previousScale = state.scale
            try assertFrameFits()
            climb.append(state.densityCap)
            if state.densityCap.isInfinite { break }
            let step = densityStep(previous: previousCap, target: .infinity, histogram: histogram)
            XCTAssertLessThanOrEqual(state.densityCap, previousCap + step + 1e-4 * previousCap, "the cap rises by at most one step: \(climb)")
            XCTAssertGreaterThan(state.densityCap, previousCap, "and rises every frame: \(climb)")
            XCTAssertLessThan(state.densityCap, histogram.fullDensity, "finite while below the full density")
            previousCap = state.densityCap
        }
        XCTAssertTrue(state.densityCap.isInfinite, "whole again: \(climb)")
        XCTAssertLessThanOrEqual(frames, 20, "within twenty frames: \(climb)")
        XCTAssertGreaterThan(frames, 2, "over several frames: \(climb)")
        XCTAssertTrue(visibleChunkEntries(slab.table).entries.allSatisfy { $0.quota == $0.splatCount }, "every quota whole")
        XCTAssertEqual(sharedGaussianVisibleCount(), unlimited)
    }

    /// A sliver in the frame's last density tier — a second copy of the fixture baked at 64
    /// splats per chunk and scaled to a fraction of a pixel, so its three 64-splat chunks sit at
    /// the minimum area with density 2^30 — sets the full density but not the climb density.
    /// After a cut to a quarter and a lift to a fitting budget, the first climb frame's step is
    /// 5 % of the density below which all but the densest 5 % of the request are whole, not 5 %
    /// of 2^30: no slab chunk truncated before the lift gains more than the step allows, most of
    /// them stay truncated, the climb takes several frames and ends whole with the sliver's
    /// chunks (the tail) becoming whole along with it.
    func testASliverInTheLastTierDoesNotSetTheClimbStep() throws {
        let slab = try loadSlab()
        let sliver = try loadFixture(chunkSplats: 6, at: simd_float3(0, 0.5, 0))
        scaleTo(entityId: sliver.entity, scale: simd_float3(repeating: 1e-4))
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        let resident = slab.splatCount + Int(sliver.component.splatCount)
        let unlimited = unlimitedVisibleCount(residentSplats: resident)
        var state = try budgetState()
        var histogram = try densityReadback()
        XCTAssertTrue(state.densityCap.isInfinite, "unlimited: whole")
        XCTAssertEqual(histogram.fullDensity, pow2(30), "the sliver's 64-splat chunks sit in the last tier and set the full density")
        XCTAssertEqual(Int(histogram.tier(gaussianDensityTierCount - 1).splats), 3 * 64, "the three 64-splat chunks of the sliver, nothing of the slab, are in the last tier")
        let sliverEntries = visibleChunkEntries(sliver.table).entries
        XCTAssertEqual(sliverEntries.count, 4, "the sliver's four chunks (64, 64, 64, 8) are in view")
        for entry in sliverEntries {
            XCTAssertEqual(entry.screenArea, gaussianScreenAreaMin, "sliver chunk \(entry.chunkIndex): at the minimum area")
            if entry.splatCount == 64 {
                XCTAssertGreaterThanOrEqual(Float(entry.splatCount) / entry.screenArea, pow2(30), "sliver chunk \(entry.chunkIndex): density 2^30")
            }
        }
        let climbAtUnlimited = GaussianChunkCullMath.climbDensity(histogram: histogram)
        XCTAssertLessThan(climbAtUnlimited, histogram.fullDensity / pow2(8), "the climb density is the slab population's, orders of magnitude below the sliver's")
        try assertFrameFits()

        let quarter = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = quarter
        for _ in 0 ..< 3 {
            runFrame()
            try assertFrameFits()
        }
        state = try budgetState()
        histogram = try densityReadback()
        let cutCap = state.densityCap
        XCTAssertTrue(cutCap.isFinite)
        XCTAssertEqual(cutCap, histogram.targetDensity, "the cut holds")
        let truncated = entriesByChunk(visibleChunkEntries(slab.table).entries).filter { $0.value.quota < $0.value.splatCount }
        XCTAssertGreaterThan(truncated.count, 100, "sanity — most slab chunks are truncated at a quarter")
        XCTAssertTrue(visibleChunkEntries(sliver.table).entries.allSatisfy { $0.quota == 0 }, "the sliver gets nothing under the cut")

        // The lift: the first climb frame.
        GaussianRuntimeLimits.workingSetSplatsOverride = resident
        runFrame()
        state = try budgetState()
        histogram = try densityReadback()
        try assertFrameFits()
        XCTAssertTrue(histogram.targetDensity.isInfinite, "the lifted frame fits")
        XCTAssertEqual(histogram.fullDensity, pow2(30))
        XCTAssertTrue(state.densityCap.isFinite, "not whole at once")
        let climbDensity = GaussianChunkCullMath.climbDensity(histogram: histogram)
        let step = densityStep(previous: cutCap, target: .infinity, histogram: histogram)
        XCTAssertEqual(step, max(0.1 * cutCap, 0.05 * climbDensity))
        XCTAssertLessThanOrEqual(state.densityCap, cutCap + step * (1 + 1e-4), "the cap rises by at most a step of the climb density")
        XCTAssertGreaterThan(state.densityCap, cutCap)
        XCTAssertLessThan(state.densityCap, histogram.fullDensity / pow2(8), "nowhere near the sliver's density")
        var wholeAtOnce = 0
        var largestGain = 1.0
        let allowedCap = cutCap + step * (1 + 1e-4)
        let capRise = Double(allowedCap / cutCap)
        for entry in visibleChunkEntries(slab.table).entries {
            guard let before = truncated[entry.chunkIndex] else { continue }
            XCTAssertLessThanOrEqual(entry.quota, GaussianChunkCullMath.quota(densityCap: allowedCap, splatCount: entry.splatCount, screenArea: entry.screenArea), "chunk \(entry.chunkIndex): gains no more than the step allows")
            // quota ≤ cap' × area and quota_before + 1 > cap × area, so quota < (cap' / cap) × (quota_before + 1).
            XCTAssertLessThanOrEqual(Double(entry.quota), capRise * Double(before.quota + 1) + 1e-3, "chunk \(entry.chunkIndex): gains no more than the cap's rise (\(before.quota) → \(entry.quota))")
            if entry.quota == entry.splatCount { wholeAtOnce += 1 }
            largestGain = max(largestGain, Double(entry.quota) / Double(max(1, before.quota)))
        }
        // The per-chunk gain on the first climb frame is bounded by the cap's rise, 1 + 5 % of
        // the climb density over the cut cap — the spread between the cap and the population's
        // densest 95 % (about 3× on the slab at a quarter) — where 5 % of the sliver's 2^30
        // would have taken every truncated chunk to whole in this one frame.
        XCTAssertLessThan(capRise, 4, "the cap rises a few times, not to the sliver's density (\(cutCap) → \(state.densityCap), climb density \(climbDensity))")
        XCTAssertLessThan(largestGain, 4, "and so does any quota (\(largestGain)× over \(truncated.count) truncated chunks, \(wholeAtOnce) whole)")
        XCTAssertLessThan(wholeAtOnce, truncated.count / 4, "most truncated chunks are still truncated after the first climb frame")
        print(String(format: "[GaussianScreenWeightedQuotaTest] sliver climb: cut cap %.4g, climb density %.4g (full %.4g), first cap %.4g, largest gain %.2f×, %d of %d truncated chunks whole", Double(cutCap), Double(climbDensity), Double(histogram.fullDensity), Double(state.densityCap), largestGain, wholeAtOnce, truncated.count))

        var previousCap = state.densityCap
        var frames = 1
        for _ in 0 ..< 30 {
            runFrame()
            state = try budgetState()
            histogram = try densityReadback()
            frames += 1
            try assertFrameFits()
            if state.densityCap.isInfinite { break }
            let step = densityStep(previous: previousCap, target: .infinity, histogram: histogram)
            XCTAssertLessThanOrEqual(state.densityCap, previousCap + step * (1 + 1e-4), "frame \(frames): at most a step")
            XCTAssertTrue(visibleChunkEntries(sliver.table).entries.allSatisfy { $0.quota == 0 }, "frame \(frames): the sliver, the tail, waits for the whole")
            previousCap = state.densityCap
        }
        XCTAssertTrue(state.densityCap.isInfinite, "whole again")
        XCTAssertLessThanOrEqual(frames, 20, "within twenty frames")
        XCTAssertGreaterThan(frames, 2, "over several frames")
        XCTAssertTrue(visibleChunkEntries(slab.table).entries.allSatisfy { $0.quota == $0.splatCount }, "every slab quota whole")
        XCTAssertTrue(visibleChunkEntries(sliver.table).entries.allSatisfy { $0.quota == $0.splatCount }, "the sliver became whole with the cap")
        XCTAssertEqual(sharedGaussianVisibleCount(), unlimited)
    }

    /// With the budget at the resident total every pose fits: the cap stays whole across the
    /// three views although the full density — the densest chunk — changes between them.
    func testAFittingFrameStaysWholeWhenADenserChunkEnters() throws {
        let fixture = try loadFixture()
        GaussianRuntimeLimits.workingSetSplatsOverride = 200
        var fullDensities: Set<Float> = []
        for (index, camera) in [farCamera, cornerCamera, sideCamera, farCamera].enumerated() {
            let cameraEntity = placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            defer { destroyEntity(entityId: cameraEntity) }
            runFrame()
            let state = try budgetState()
            let histogram = try densityReadback()
            XCTAssertTrue(state.densityCap.isInfinite, "pose \(index): whole")
            XCTAssertTrue(histogram.targetDensity.isInfinite)
            XCTAssertTrue(histogram.fullDensity.isFinite)
            XCTAssertEqual(state.scale, 1)
            let entries = visibleChunkEntries(fixture.table).entries
            XCTAssertGreaterThan(entries.count, 0)
            XCTAssertTrue(entries.allSatisfy { $0.quota == $0.splatCount }, "pose \(index): every quota whole")
            XCTAssertEqual(Int(state.quotaSplats), Int(state.requestedSplats))
            fullDensities.insert(histogram.fullDensity)
            try assertFrameFits()
        }
        XCTAssertGreaterThanOrEqual(fullDensities.count, 2, "the densest chunk changed between poses: \(fullDensities)")
    }

    /// A budget that truncates the far view but fits the corner view: turning to the corner
    /// frees budget that fades back in — the target is whole at once, the cap climbs by at most
    /// a step per frame and no chunk gains more than the step allows, whole within twenty frames.
    func testLeavingChunksFreeBudgetThatFadesBackIn() throws {
        let fixture = try loadFixture()
        var camera = placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        GaussianRuntimeLimits.workingSetSplatsOverride = 200
        runFrame()
        let cornerRequest = try Int(budgetState().requestedSplats)
        XCTAssertGreaterThan(cornerRequest, 0)
        XCTAssertLessThan(cornerRequest, 200, "sanity — the corner view culls chunks")
        let budget = Int(ceil(Float(cornerRequest) / gaussianBudgetHeadroom)) + 1
        destroyEntity(entityId: camera)

        camera = placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        var state = try budgetState()
        XCTAssertEqual(Int(state.requestedSplats), 200)
        XCTAssertLessThan(state.targetScale, 1, "the far view is truncated")
        XCTAssertTrue(state.densityCap.isFinite)
        try assertFrameFits()
        destroyEntity(entityId: camera)

        camera = placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        var previousCap = state.densityCap
        var climb: [Float] = [previousCap]
        var frames = 0
        for _ in 0 ..< 30 {
            runFrame()
            state = try budgetState()
            let histogram = try densityReadback()
            frames += 1
            climb.append(state.densityCap)
            XCTAssertEqual(Int(state.requestedSplats), cornerRequest)
            XCTAssertEqual(state.targetScale, 1, "the corner view fits")
            XCTAssertTrue(histogram.targetDensity.isInfinite, "the target is whole at once")
            try assertFrameFits()
            if state.densityCap.isInfinite { break }
            let step = densityStep(previous: previousCap, target: .infinity, histogram: histogram)
            XCTAssertLessThanOrEqual(state.densityCap, previousCap + step + 1e-4 * previousCap, "the cap climbs by at most a step: \(climb)")
            for entry in visibleChunkEntries(fixture.table).entries {
                XCTAssertLessThanOrEqual(entry.quota, GaussianChunkCullMath.quota(densityCap: previousCap + step * (1 + 1e-4), splatCount: entry.splatCount, screenArea: entry.screenArea), "chunk \(entry.chunkIndex) gains no more than the step allows")
            }
            previousCap = state.densityCap
        }
        XCTAssertTrue(state.densityCap.isInfinite, "whole: \(climb)")
        XCTAssertLessThanOrEqual(frames, 20, "within twenty frames: \(climb)")
        XCTAssertGreaterThan(frames, 1, "not at once: \(climb)")
        XCTAssertLessThanOrEqual(Int(sharedVisibleSet().visibleCount), Int(state.quotaSplats), "the close view's per-splat test drops part of the quotas")
        destroyEntity(entityId: camera)
    }

    /// A chunk entering the view through the guard band is listed with a small clipped area
    /// that grows as it comes in, its quota following the cap and that area; the request is
    /// always the listed chunks' splats.
    func testAnEnteringChunkGrowsWithItsClippedArea() throws {
        let slab = try loadSlab()
        // From 3 units above the slab, looking down at a wedge of it: the view's footprint covers
        // part of the slab, and panning sweeps its right edge across the chunks.
        let eye = simd_float3(0, 3, 1)
        let camera = placeGaussianTestCamera(eye: eye, target: simd_float3(-4, 0, -5))
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        let budget = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        let chunks = decodeConstants(slab.table)
        // The view pans from x = −4 to x = +2 on the far side in 24 steps: chunks on the +x side
        // enter through the right edge of the guard band.
        let frameCount = 24
        var frames: [(entries: [UInt32: GaussianVisibleChunk], cap: Float, viewProjection: simd_float4x4)] = []
        for frame in 0 ... frameCount {
            let t = Float(frame) / Float(frameCount)
            cameraLookAt(entityId: camera, eye: eye, target: simd_float3(-4 + 6 * t, 0, -5), up: simd_float3(0, 1, 0))
            runFrame()
            let state = try budgetState()
            let entries = visibleChunkEntries(slab.table).entries
            XCTAssertEqual(Int(state.requestedSplats), entries.reduce(0) { $0 + Int($1.splatCount) }, "frame \(frame): the request is the listed chunks' splats")
            assertQuotasFollowTheCap(entries, densityCap: state.densityCap)
            try assertFrameFits()
            try frames.append((entriesByChunk(entries), state.densityCap, headViewProjection(entity: slab.entity)))
        }
        // Chunks absent at first and present to the end from the frame they appear.
        let candidates = try XCTUnwrap(frames.last?.entries.keys.filter { index in
            frames[0].entries[index] == nil && {
                guard let first = frames.firstIndex(where: { $0.entries[index] != nil }) else { return false }
                return frames[first...].allSatisfy { $0.entries[index] != nil } && frames.count - first >= 4
            }()
        })
        XCTAssertGreaterThan(candidates.count, 0, "sanity — some chunk entered during the pan")
        /// The one that came in most gradually.
        func ratio(_ index: UInt32) -> Float {
            let areas = frames.compactMap { $0.entries[index]?.screenArea }
            return areas.first! / areas.max()!
        }
        let entering = try XCTUnwrap(candidates.min { ratio($0) < ratio($1) })
        let areas = frames.compactMap { $0.entries[entering]?.screenArea }
        XCTAssertLessThanOrEqual(ratio(entering), 0.25, "chunk \(entering) is first listed with at most a quarter of its largest area: \(areas)")
        let chunk = chunks[Int(entering)]
        let box = GaussianChunkCullMath.paddedBox(aabbMin: simd_float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ), aabbMax: simd_float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ), logScaleMax: chunk.logScaleMax)
        var previousArea: Float = 0
        var stillEntering = true
        for (frameIndex, frame) in frames.enumerated() {
            guard let entry = frame.entries[entering] else { continue }
            let clipped = GaussianChunkCullMath.screenArea(boxMin: box.min, boxMax: box.max, viewProjection: frame.viewProjection)
            let unclipped = GaussianChunkCullMath.screenArea(boxMin: box.min, boxMax: box.max, viewProjection: frame.viewProjection, clipGuardBand: 1000)
            XCTAssertTrue(clipped.passes)
            XCTAssertEqual(entry.screenArea, clipped.area, accuracy: max(1e-5 * clipped.area, 1e-6), "frame \(frameIndex): the area is the clipped rect's")
            if stillEntering {
                XCTAssertGreaterThanOrEqual(entry.screenArea, previousArea * (1 - 1e-5), "frame \(frameIndex): the clipped area grows while the chunk comes in: \(areas)")
            }
            if clipped.area >= unclipped.area * (1 - 1e-4) {
                stillEntering = false
            }
            XCTAssertLessThanOrEqual(Float(entry.quota), frame.cap * entry.screenArea, "frame \(frameIndex): quota ≤ cap × area")
            previousArea = entry.screenArea
        }
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(areas.max()) / areas.first!, 4, "the chunk grew as it came in: \(areas)")
        destroyEntity(entityId: camera)
    }

    /// The chunk whose padded box contains the eye is charged for the whole guard-banded view:
    /// the sparsest chunk of the frame, so it keeps the largest fraction of any chunk and, with
    /// the rest of the view receding into the distance, is kept whole at a quarter budget while
    /// the far chunks are cut. (Standing inside a slab, dozens of chunks reach behind the eye and
    /// share that first claim; a quarter budget then spreads over all of them.)
    func testTheChunkYouStandInIsKeptWhole() throws {
        let slab = try loadSlab()
        // Standing on a corner of the slab, the eye within the padding of the chunk below,
        // looking across the whole slab: the rest of the view recedes into dense far chunks.
        let eye = simd_float3(5.7, 0.42, 5.7)
        placeGaussianTestCamera(eye: eye, target: .zero)
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        let containing = decodeConstants(slab.table).enumerated().compactMap { index, chunk -> UInt32? in
            let box = GaussianChunkCullMath.paddedBox(aabbMin: simd_float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ), aabbMax: simd_float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ), logScaleMax: chunk.logScaleMax)
            return simd_reduce_min(eye - box.min) > 0 && simd_reduce_min(box.max - eye) > 0 ? UInt32(index) : nil
        }
        XCTAssertGreaterThan(containing.count, 0, "sanity — the eye is inside some chunk's padded box")

        GaussianRuntimeLimits.workingSetSplatsOverride = max(1, unlimited / 4)
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        var state = try budgetState()
        XCTAssertLessThan(state.targetScale, 1, "sanity — truncated")
        var entries = entriesByChunk(visibleChunkEntries(slab.table).entries)
        let largestFraction = try XCTUnwrap(entries.values.map { Double($0.quota) / Double($0.splatCount) }.max())
        for index in containing {
            let entry = try XCTUnwrap(entries[index], "the chunk the camera stands in is listed")
            XCTAssertEqual(entry.screenArea, gaussianScreenAreaGuard, "chunk \(index) reaches behind the eye: the whole guard-banded view")
            XCTAssertEqual(Double(entry.quota) / Double(entry.splatCount), largestFraction, "chunk \(index) keeps the largest fraction of any chunk")
            XCTAssertEqual(entry.quota, entry.splatCount, "chunk \(index) is kept whole")
        }
        let truncated = entries.values.filter { $0.quota < $0.splatCount }
        XCTAssertGreaterThan(truncated.count, entries.count / 2, "sanity — most chunks, the far ones, are truncated")
        XCTAssertTrue(truncated.allSatisfy { $0.screenArea < gaussianScreenAreaGuard }, "no chunk reaching behind the eye is truncated")
        try assertFrameFits()

        // Inside the slab, dozens of chunks reach behind the eye: they all keep the largest
        // fraction, cut alike once the budget cannot hold them all.
        let inside = simd_float3(0.3, 0.05, 0.2)
        placeGaussianTestCamera(eye: inside, target: inside + simd_float3(5, 0, 0.5))
        let insideUnlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        GaussianRuntimeLimits.workingSetSplatsOverride = max(1, insideUnlimited / 4)
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        state = try budgetState()
        entries = entriesByChunk(visibleChunkEntries(slab.table).entries)
        let straddling = entries.values.filter { $0.screenArea == gaussianScreenAreaGuard }
        XCTAssertGreaterThan(straddling.count, 10, "sanity — many chunks reach behind an eye inside the slab")
        let best = try XCTUnwrap(entries.values.map { Double($0.quota) / Double($0.splatCount) }.max())
        XCTAssertTrue(straddling.allSatisfy { Double($0.quota) / Double($0.splatCount) == best }, "every chunk reaching behind the eye keeps the largest fraction")
        XCTAssertEqual(Set(straddling.map(\.quota)).count, 1, "and the same quota")
        try assertFrameFits()
    }

    /// With every chunk forced visible, the chunks no view keeps carry the minimum area and are
    /// cut first: they get nothing, the frustum's chunks share the whole grant.
    func testForceAllVisibleChunksNoViewKeepsAreCutFirst() throws {
        let slab = try loadSlab()
        placeGaussianTestCamera(eye: simd_float3(0, 3, 0.5), target: simd_float3(0, 0, 6))
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        let budget = max(1, unlimited / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let culledState = try budgetState()
        let culledCount = visibleChunkEntries(slab.table).entries.count
        XCTAssertLessThan(culledCount, slab.table.chunkCount, "sanity — the camera faces away from part of the slab")

        GaussianDebugOptions.shared.disableChunkCull = true
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let state = try budgetState()
        let entries = visibleChunkEntries(slab.table).entries
        XCTAssertEqual(entries.count, slab.table.chunkCount, "every chunk is listed")
        XCTAssertEqual(Int(state.requestedSplats), slab.splatCount)
        let unkept = entries.filter { $0.screenArea == gaussianScreenAreaMin }
        let kept = entries.filter { $0.screenArea > gaussianScreenAreaMin }
        XCTAssertGreaterThan(unkept.count, 0, "sanity — chunks no view keeps")
        XCTAssertEqual(kept.count, culledCount, "the chunks with a real area are the frustum's")
        XCTAssertTrue(unkept.allSatisfy { $0.quota == 0 }, "a chunk no view keeps gets nothing")
        XCTAssertEqual(kept.reduce(0) { $0 + Int($1.quota) }, Int(state.quotaSplats), "the frustum's chunks share the whole grant")
        let medianArea = try XCTUnwrap(kept.map(\.screenArea).sorted().dropFirst(kept.count / 2).first)
        XCTAssertTrue(kept.filter { $0.screenArea >= medianArea }.allSatisfy { $0.quota > 0 }, "the larger half of the frustum's chunks all get something")
        XCTAssertEqual(Double(state.quotaSplats), Double(culledState.quotaSplats), accuracy: 0.01 * Double(culledState.quotaSplats), "the grant is what the chunk cull's frame granted")
        assertQuotasFollowTheCap(entries, densityCap: state.densityCap)
        try assertFrameFits()
    }

    /// The uniform switch reproduces the pre-weighting rule byte for byte: the cap is the scale,
    /// every 64-splat chunk gets 31 of 100, every quota is floor(scale × n), the scale climbs as
    /// its mirror predicts, and no solve runs.
    func testUniformSwitchReproducesTheUniformRuleByteForByte() throws {
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
        let fixture = try loadFixture(chunkSplats: 6)
        XCTAssertEqual(fixture.table.index.chunks.map(\.splatCount), [64, 64, 64, 8])
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        GaussianRuntimeLimits.workingSetSplatsOverride = 100
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        var state = try budgetState()
        XCTAssertEqual(state.scale, GaussianChunkCullMath.targetScale(requestedSplats: 200, budget: 100), accuracy: 1e-6)
        XCTAssertEqual(state.densityCap, state.scale, "the cap is the scale")
        XCTAssertTrue(try densityReadback().targetDensity.isInfinite, "no solve")
        for entry in visibleChunkEntries(fixture.table).entries {
            XCTAssertEqual(entry.screenArea, Float(entry.splatCount))
            XCTAssertEqual(entry.quota, GaussianChunkCullMath.quota(scale: state.scale, splatCount: entry.splatCount))
            if entry.splatCount == 64 {
                XCTAssertEqual(entry.quota, 31)
            }
        }
        try assertFrameFits()

        var previousScale = state.scale
        for (frame, budget) in ([Int](repeating: 50, count: 4) + [Int](repeating: 200, count: 16)).enumerated() {
            GaussianRuntimeLimits.workingSetSplatsOverride = budget
            runFrame()
            state = try budgetState()
            let target = GaussianChunkCullMath.targetScale(requestedSplats: 200, budget: budget)
            XCTAssertEqual(state.targetScale, target, accuracy: 1e-6, "frame \(frame)")
            XCTAssertEqual(state.scale, GaussianChunkCullMath.smoothedScale(target: target, previous: previousScale), accuracy: 1e-6, "frame \(frame): the scale is the mirror's")
            if state.scale < 1 {
                XCTAssertEqual(state.densityCap, state.scale, "frame \(frame): the cap is the scale")
            } else {
                XCTAssertTrue(state.densityCap.isInfinite, "frame \(frame): at scale 1 the cap is whole")
            }
            XCTAssertTrue(try densityReadback().targetDensity.isInfinite)
            for entry in visibleChunkEntries(fixture.table).entries {
                XCTAssertEqual(entry.screenArea, Float(entry.splatCount), "frame \(frame)")
                XCTAssertEqual(entry.quota, GaussianChunkCullMath.quota(scale: state.scale, splatCount: entry.splatCount), "frame \(frame) chunk \(entry.chunkIndex)")
            }
            try assertFrameFits()
            previousScale = state.scale
        }
        XCTAssertEqual(state.scale, 1, "climbed back")
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), 200)
    }

    /// With the budget switched off every chunk is whole whatever the override.
    func testDisableWorkingSetBudgetKeepsEveryChunkWhole() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        GaussianRuntimeLimits.workingSetSplatsOverride = 50
        runFrame()
        let state = try budgetState()
        XCTAssertTrue(state.densityCap.isInfinite)
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, 200)
        XCTAssertTrue(visibleChunkEntries(fixture.table).entries.allSatisfy { $0.quota == $0.splatCount })
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), 200)
        XCTAssertEqual(sharedVisibleSet().overflowCount, 0)
    }

    /// The opacity band follows each chunk's own weighted quota: chunks at different depths get
    /// different quotas and fade at different ranks, each as the mirror predicts.
    func testTheOpacityBandFollowsEachChunksWeightedQuota() throws {
        let fixture = try loadFixture(chunkSplats: 6)
        XCTAssertEqual(fixture.table.index.chunks.map(\.splatCount), [64, 64, 64, 8])
        fixture.component.opacityScale = 1
        // An oblique, close view: the four chunks at different depths.
        placeGaussianTestCamera(eye: simd_float3(2.2, 1.6, 2.0), target: simd_float3(0, 0, 0.25))
        GaussianRuntimeLimits.workingSetSplatsOverride = 100
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let state = try budgetState()
        XCTAssertLessThan(state.targetScale, 1, "sanity — truncated")
        let entries = entriesByChunk(visibleChunkEntries(fixture.table).entries)
        let quotas = Set(entries.values.filter { $0.splatCount == 64 }.map(\.quota))
        XCTAssertGreaterThanOrEqual(quotas.count, 2, "the 64-splat chunks get different quotas: \(quotas)")
        assertQuotasFollowTheCap(Array(entries.values), densityCap: state.densityCap)

        var firstSplat: [UInt32] = []
        var next: UInt32 = 0
        for chunk in fixture.table.index.chunks {
            firstSplat.append(next)
            next += chunk.splatCount
        }
        let records = sharedGaussianRecords()
        XCTAssertGreaterThan(records.count, 40)
        let indices = fixture.resolver.indices(of: records)
        var checked = 0
        for (record, index) in zip(records, indices) {
            let chunkIndex = try XCTUnwrap(firstSplat.lastIndex { $0 <= index })
            let rank = index - firstSplat[chunkIndex]
            let entry = try XCTUnwrap(entries[UInt32(chunkIndex)], "a compacted splat's chunk is listed")
            XCTAssertLessThan(rank, entry.quota, "splat \(index) is within chunk \(chunkIndex)'s quota")
            let baseOpacity = Float(fixture.cpu.encodedSplats[Int(index)].colorAndOpacity.w)
            guard baseOpacity > 0 else { continue }
            let expected = GaussianChunkCullMath.opacityBandFactor(rank: rank, quota: entry.quota, splatCount: entry.splatCount)
            XCTAssertEqual(record.conicAndOpacity.w / baseOpacity, expected, accuracy: 2e-3, "splat \(index) (chunk \(chunkIndex) rank \(rank)): the band follows the chunk's quota \(entry.quota)")
            checked += 1
        }
        XCTAssertGreaterThan(checked, 40)
        try assertFrameFits()
    }

    // MARK: - GPU, stereo

    /// In stereo the area is the larger of the two eyes' among those that keep the chunk, a
    /// chunk only one eye keeps weighs by that eye, swapping the eyes changes nothing, and mono
    /// on eye 0 alone gives eye 0's areas.
    func testStereoTakesTheLargerEyeAreaAndSwappingEyesChangesNothing() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let farView = try viewProjection(entity: fixture.entity, eye: farCamera.eye, target: farCamera.target)
        let cornerView = try viewProjection(entity: fixture.entity, eye: cornerCamera.eye, target: cornerCamera.target)
        let chunks = decodeConstants(fixture.table)
        func box(_ chunk: GaussianChunkDecodeConstants) -> (min: simd_float3, max: simd_float3) {
            GaussianChunkCullMath.paddedBox(aabbMin: simd_float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ), aabbMax: simd_float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ), logScaleMax: chunk.logScaleMax)
        }
        func assertAreas(_ entries: [GaussianVisibleChunk], constants: GaussianChunkCullConstants, _ label: String) {
            for entry in entries {
                let expected = GaussianChunkCullMath.chunkScreenArea(chunk: chunks[Int(entry.chunkIndex)], constants: constants)
                XCTAssertEqual(entry.screenArea, expected, accuracy: max(1e-5 * expected, 1e-6), "\(label) chunk \(entry.chunkIndex): the larger kept eye's area")
            }
        }

        let constants = try stereoConstants(table: fixture.table, entity: fixture.entity, eye0: farView, eye1: cornerView)
        let cull = try cullChunks(fixture.table, constants: constants)
        XCTAssertEqual(cull.chunks.count, 13, "the far eye sees every chunk")
        assertAreas(cull.entries, constants: constants, "far / corner")
        let histogram = try densityHistogramBuffer().contents().load(as: GaussianBudgetDensityHistogram.self)
        assertHistogramMatchesTheMirror(histogram, entries: cull.entries)
        XCTAssertEqual(Int(histogram.visibleChunks), 13)

        // The corner eye misses five chunks: those weigh by the far eye alone, the others by
        // the larger of the two.
        var eitherEyeLarger = 0
        for entry in cull.entries {
            let b = box(chunks[Int(entry.chunkIndex)])
            let far = GaussianChunkCullMath.screenArea(boxMin: b.min, boxMax: b.max, viewProjection: farView)
            let corner = GaussianChunkCullMath.screenArea(boxMin: b.min, boxMax: b.max, viewProjection: cornerView)
            XCTAssertTrue(far.passes)
            if !corner.passes {
                XCTAssertEqual(entry.screenArea, min(max(far.area, gaussianScreenAreaMin), gaussianScreenAreaGuard), accuracy: max(1e-5 * far.area, 1e-6), "chunk \(entry.chunkIndex): only eye 0 keeps it, eye 0's area")
            } else if corner.area > far.area {
                eitherEyeLarger += 1
                XCTAssertEqual(entry.screenArea, min(corner.area, gaussianScreenAreaGuard), accuracy: max(1e-5 * corner.area, 1e-6), "chunk \(entry.chunkIndex): the corner eye is closer, its area wins")
            }
        }
        XCTAssertEqual(cull.entries.filter { entry in !GaussianChunkCullMath.screenArea(boxMin: box(chunks[Int(entry.chunkIndex)]).min, boxMax: box(chunks[Int(entry.chunkIndex)]).max, viewProjection: cornerView).passes }.count, 5)
        XCTAssertGreaterThan(eitherEyeLarger, 0, "sanity — the close eye sees some chunk larger")

        // Swapped eyes: the same entries and histogram.
        let swapped = try cullChunks(fixture.table, constants: stereoConstants(table: fixture.table, entity: fixture.entity, eye0: cornerView, eye1: farView))
        let swappedHistogram = try densityHistogramBuffer().contents().load(as: GaussianBudgetDensityHistogram.self)
        let sortedA = cull.entries.sorted { $0.chunkIndex < $1.chunkIndex }.flatMap { [$0.chunkIndex, $0.splatCount, $0.screenArea.bitPattern] }
        let sortedB = swapped.entries.sorted { $0.chunkIndex < $1.chunkIndex }.flatMap { [$0.chunkIndex, $0.splatCount, $0.screenArea.bitPattern] }
        XCTAssertEqual(sortedA, sortedB, "swapping the eyes changes nothing")
        XCTAssertEqual(histogram.tierArray.flatMap { [$0.splats, $0.scaledArea] }, swappedHistogram.tierArray.flatMap { [$0.splats, $0.scaledArea] })
        // Chunks only the far eye keeps, with the far eye as eye 1: eye 1's area.
        for entry in swapped.entries {
            let b = box(chunks[Int(entry.chunkIndex)])
            let corner = GaussianChunkCullMath.screenArea(boxMin: b.min, boxMax: b.max, viewProjection: cornerView)
            if !corner.passes {
                let far = GaussianChunkCullMath.screenArea(boxMin: b.min, boxMax: b.max, viewProjection: farView)
                XCTAssertEqual(entry.screenArea, min(max(far.area, gaussianScreenAreaMin), gaussianScreenAreaGuard), accuracy: max(1e-5 * far.area, 1e-6), "chunk \(entry.chunkIndex): only eye 1 keeps it, eye 1's area")
            }
        }

        // Mono on eye 0 alone: eye 0's areas.
        var mono = constants
        mono.viewCount = 1
        let monoCull = try cullChunks(fixture.table, constants: mono)
        XCTAssertEqual(monoCull.chunks.count, 13)
        assertAreas(monoCull.entries, constants: mono, "mono far")
        for entry in monoCull.entries {
            let b = box(chunks[Int(entry.chunkIndex)])
            let far = GaussianChunkCullMath.screenArea(boxMin: b.min, boxMax: b.max, viewProjection: farView)
            XCTAssertEqual(entry.screenArea, min(max(far.area, gaussianScreenAreaMin), gaussianScreenAreaGuard), accuracy: max(1e-5 * far.area, 1e-6))
        }
    }

    /// A stereo head turn over the slab at a quarter budget: every frame fits, the cap never
    /// rises by more than a step, the request moves gradually, and no chunk present in
    /// consecutive frames gains more than the step allows.
    func testStereoHeadTurnStaysUnderBudgetWithoutPops() throws {
        let savedStereo = renderInfo.isXRStereoMode
        let savedEyes = (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection)
        let savedComposed = (renderInfo.xrEye0ViewProjection, renderInfo.xrEye1ViewProjection)
        defer {
            renderInfo.isXRStereoMode = savedStereo
            (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection) = savedEyes
            (renderInfo.xrEye0ViewProjection, renderInfo.xrEye1ViewProjection) = savedComposed
        }
        let slab = try loadSlab()
        let eye = simd_float3(0, 5, 6)
        let camera = placeGaussianTestCamera(eye: eye, target: .zero)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let forward = simd_float3.zero - eye

        /// Points the head `angle` radians about the up axis from the centre view and installs
        /// the two eyes 6.4 cm apart, as renderXR leaves them.
        func turnHead(_ angle: Float) {
            let rotation = simd_quatf(angle: angle, axis: simd_float3(0, 1, 0))
            cameraLookAt(entityId: camera, eye: eye, target: eye + rotation.act(forward), up: simd_float3(0, 1, 0))
            let head = cameraComponent.viewSpace
            let eye0View = simd_mul(matrix4x4Translation(0.032, 0, 0), head)
            let eye1View = simd_mul(matrix4x4Translation(-0.032, 0, 0), head)
            renderInfo.isXRStereoMode = true
            renderInfo.xrEye0View = eye0View
            renderInfo.xrEye1View = eye1View
            renderInfo.xrEye0Projection = renderInfo.perspectiveSpace
            renderInfo.xrEye1Projection = renderInfo.perspectiveSpace
            renderInfo.xrEye0ViewProjection = simd_mul(renderInfo.perspectiveSpace, eye0View)
            renderInfo.xrEye1ViewProjection = simd_mul(renderInfo.perspectiveSpace, eye1View)
            cameraComponent.viewSpace = eye1View
        }

        turnHead(-Float.pi / 6)
        let unlimited = unlimitedVisibleCount(residentSplats: slab.splatCount)
        GaussianRuntimeLimits.workingSetSplatsOverride = max(1, unlimited / 4)
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        var state = try budgetState()
        var histogram = try densityReadback()
        var previous = entriesByChunk(visibleChunkEntries(slab.table).entries)
        var previousCap = state.densityCap
        var previousRequest = Int(state.requestedSplats)
        XCTAssertLessThan(state.targetScale, 1, "sanity — truncated")
        try assertFrameFits()
        var largestRequestChange = 0.0
        for frame in 1 ... 40 {
            turnHead(-Float.pi / 6 + Float.pi / 3 * Float(frame) / 40)
            runFrame()
            state = try budgetState()
            histogram = try densityReadback()
            let entries = visibleChunkEntries(slab.table).entries
            try assertFrameFits()
            let step = densityStep(previous: previousCap, target: histogram.targetDensity, histogram: histogram)
            if state.densityCap > previousCap {
                XCTAssertLessThanOrEqual(state.densityCap, previousCap + step + 1e-4 * previousCap, "frame \(frame): the cap rises by at most a step")
            }
            let requestChange = abs(Double(Int(state.requestedSplats) - previousRequest)) / Double(previousRequest)
            largestRequestChange = max(largestRequestChange, requestChange)
            XCTAssertLessThanOrEqual(requestChange, 0.15, "frame \(frame): the request moves gradually (\(previousRequest) → \(state.requestedSplats))")
            let allowedCap = min(previousCap + step * (1 + 1e-4), state.densityCap.isInfinite ? .infinity : max(state.densityCap, previousCap))
            for entry in entries {
                guard previous[entry.chunkIndex] != nil else { continue }
                XCTAssertLessThanOrEqual(entry.quota, GaussianChunkCullMath.quota(densityCap: allowedCap, splatCount: entry.splatCount, screenArea: entry.screenArea), "frame \(frame) chunk \(entry.chunkIndex): gains no more than the step allows")
            }
            assertQuotasFollowTheCap(entries, densityCap: state.densityCap)
            previous = entriesByChunk(entries)
            previousCap = state.densityCap
            previousRequest = Int(state.requestedSplats)
        }
        XCTAssertGreaterThan(largestRequestChange, 0, "sanity — the turn changed the request")
    }

    /// An HZB occlusion in eye 1 removes eye 1's area: with a solid pyramid and both eyes at the
    /// asset, every entry carries eye 0's area alone; in mono the solid pyramid lists nothing.
    func testStereoHZBOcclusionInEyeOneOnlyRemovesEyeOnesArea() throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = false
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let farView = try viewProjection(entity: fixture.entity, eye: farCamera.eye, target: farCamera.target)
        // A closer view along the same line of sight: larger areas, no chunk reaching behind
        // the eye (which would be charged the guard area rather than tested against the pyramid).
        let closerView = try viewProjection(entity: fixture.entity, eye: 0.7 * farCamera.eye, target: farCamera.target)
        let chunks = decodeConstants(fixture.table)
        let nearDepth: Float = renderInfo.reverseZEnabled ? 0.95 : 0.05
        try withInjectedHZB(depths: [nearDepth], valid: true) {
            // Eye 0 the far view, eye 1 the closer view (whose areas would win): occluded in
            // eye 1, every chunk weighs by eye 0.
            let constants = try stereoConstants(table: fixture.table, entity: fixture.entity, eye0: farView, eye1: closerView, hzbValid: true)
            let cull = try cullChunks(fixture.table, constants: constants)
            XCTAssertEqual(cull.chunks.count, 13, "eye 0 keeps every chunk by its frustum alone")
            var eyeZero = constants
            eyeZero.viewCount = 1
            var cornerWouldWin = 0
            for entry in cull.entries {
                let expected = GaussianChunkCullMath.chunkScreenArea(chunk: chunks[Int(entry.chunkIndex)], constants: eyeZero)
                XCTAssertEqual(entry.screenArea, expected, accuracy: max(1e-5 * expected, 1e-6), "chunk \(entry.chunkIndex): eye 0's area alone")
                if GaussianChunkCullMath.chunkScreenArea(chunk: chunks[Int(entry.chunkIndex)], constants: constants) > expected * (1 + 1e-4) {
                    cornerWouldWin += 1
                }
            }
            XCTAssertGreaterThan(cornerWouldWin, 0, "sanity — without the occlusion eye 1's area would win for some chunk")

            // Mono: the head view is the pyramid's, and it culls everything.
            let mono = try cullChunks(fixture.table, constants: eyeZero)
            XCTAssertEqual(mono.chunks.count, 0)
            XCTAssertEqual(mono.record.visibleCount, 0)
        }
    }
}
