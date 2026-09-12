//
//  GaussianPagingPolicyTests.swift
//  UntoldEngine
//
//  The chunk pager's rules on the CPU, without Metal (GaussianPagingPolicy): the wanted ranks
//  under the density cap with headroom, the fill density when the frame fits, the uniform and
//  budget-off modes, the fixed point the headroom gives the density solve, the load priority,
//  the eviction classes and their hysteresis (margin, pin, cooldown, hold-off), the retire ring,
//  the coalescing of a chunk's tiers into one read, the pool sizing and the resident estimate,
//  and the per-chunk coarse levels' share (per-chunk-lod-tiers): the wants a chunk drawn coarse
//  gives up, the finer assumption inside the hysteresis band, the fit check, the pieces of the
//  coarse section, the eviction exclusion of a chunk mid-fade and the residency rewrite that
//  carries the availability bits.
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

final class GaussianPagingPolicyTests: XCTestCase {
    override func tearDown() {
        GaussianPagingPolicy.resetKnobs()
        super.tearDown()
    }

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
    }

    // MARK: - Wanted ranks

    func testWantedRanksFollowTheDensityCapWithHeadroom() {
        let n: UInt32 = 1024
        let area: Float = 0.05
        let cap: Float = 4000
        let want = GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false)
        XCTAssertEqual(want, GaussianChunkCullMath.quota(densityCap: cap, splatCount: n, screenArea: area))
        XCTAssertEqual(want, 200)
        let needed = GaussianPagingPolicy.neededRanks(want: want, splatCount: n)
        XCTAssertEqual(needed, 250, "ceil(1.25 × 200)")
        XCTAssertEqual(GaussianPagingPolicy.tiersNeeded(needed: needed, ranksPerPage: 256), 1)
        XCTAssertEqual(GaussianPagingPolicy.tiersNeeded(needed: 257, ranksPerPage: 256), 2)
        XCTAssertEqual(GaussianPagingPolicy.tiersNeeded(needed: 0, ranksPerPage: 256), 0, "want 0 ⇒ no tier")
        // The headroom never exceeds the count.
        XCTAssertEqual(GaussianPagingPolicy.neededRanks(want: 900, splatCount: n), n)
        XCTAssertEqual(GaussianPagingPolicy.neededRanks(want: 0, splatCount: n), 0)
        // A cap that grants nothing wants nothing.
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: 0, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false), 0)
        // The resident prefix of k tiers.
        XCTAssertEqual(GaussianPagingPolicy.residentRanks(tiers: 2, ranksPerPage: 256, splatCount: 1000), 512)
        XCTAssertEqual(GaussianPagingPolicy.residentRanks(tiers: 4, ranksPerPage: 256, splatCount: 1000), 1000)
    }

    func testWantedRanksUseTheFillDensityWhenTheCapIsInfinite() {
        let budget = 1_000_000
        var generator = SplitMix64(seed: 7)
        let chunks: [(n: UInt32, area: Float)] = (0 ..< 5000).map { _ in (1024, 0.0005 + 0.05 * generator.unit()) }
        let totalArea = chunks.reduce(Float(0)) { $0 + $1.area }
        let fill = GaussianPagingPolicy.fillDensity(budget: budget, reservedSplats: 0, demandedArea: totalArea)
        XCTAssertEqual(fill, 0.98 * Float(budget) / totalArea, accuracy: 1e-3)
        var wanted = 0
        var whole = 0
        for chunk in chunks {
            let want = GaussianPagingPolicy.wantedRanks(splatCount: chunk.n, area: chunk.area, densityCap: .infinity, fillDensity: fill, uniformQuotas: false, disableWorkingSetBudget: false)
            wanted += Int(want)
            if want == chunk.n { whole += 1 }
        }
        XCTAssertLessThanOrEqual(Float(wanted), 1.25 * 0.98 * Float(budget), "Σ want stays within the headroom's share of the budget")
        XCTAssertLessThan(whole, chunks.count, "a starved pool never wants the whole asset")
        XCTAssertGreaterThan(wanted, 0)
        // Nothing demanded: an infinite fill density (no chunk to apply it to).
        XCTAssertEqual(GaussianPagingPolicy.fillDensity(budget: budget, reservedSplats: 0, demandedArea: 0), .infinity)
        // A reservation above the headroom's share: nothing left.
        XCTAssertEqual(GaussianPagingPolicy.fillDensity(budget: 100, reservedSplats: 100, demandedArea: 1), 0)
    }

    /// The fill density cap: the terms added chunk by chunk are the levelled histogram of the
    /// same chunks resident whole with their levels landed (and removals undo them); the cap
    /// keeps the bounded request within the room and is the largest such density on the
    /// bisection's grid; it is at least the plain fill density, which ignores the chunks the
    /// count caps; it is +inf when everything fits whole and 0 when nothing does.
    func testFillDensityCapSolvesOverTheDemandedSetAsIfResident() {
        var generator = SplitMix64(seed: 11)
        struct Chunk {
            var n: UInt32
            var area: Float
            var m1: UInt32
            var m2: UInt32
        }
        let chunks: [Chunk] = (0 ..< 3000).map { index in
            let n = UInt32(64 + Int(generator.unit() * 960))
            let levelled = index % 3 != 0
            return Chunk(n: n, area: 0.00002 + 0.01 * generator.unit(), m1: levelled ? n / 3 : 0, m2: levelled ? n / 6 : 0)
        }
        var histogram = GaussianBudgetDensityHistogram()
        for chunk in chunks {
            GaussianPagingPolicy.addFillTerm(to: &histogram, splatCount: chunk.n, area: chunk.area, coarseCounts: (chunk.m1, chunk.m2))
        }
        let mirror = GaussianChunkCullMath.densityHistogram(levelledChunks: chunks.map {
            GaussianChunkCullMath.LevelledChunk(splatCount: $0.n, residentRanks: $0.n, screenArea: $0.area, coarse1: $0.m1, coarse2: $0.m2, availableLevels: ($0.m1 > 0 ? 1 : 0) | ($0.m2 > 0 ? 2 : 0))
        })
        for (tier, entry) in histogram.tierArray.enumerated() {
            let expected = mirror.tier(tier)
            XCTAssertEqual(entry.splats, expected.splats, "tier \(tier)")
            XCTAssertEqual(entry.scaledArea, expected.scaledArea, "tier \(tier)")
            XCTAssertEqual(entry.coarse1, expected.coarse1, "tier \(tier)")
            XCTAssertEqual(entry.coarse2, expected.coarse2, "tier \(tier)")
            XCTAssertEqual(entry.levelledSplats, expected.levelledSplats, "tier \(tier)")
            XCTAssertEqual(entry.levelledScaledArea, expected.levelledScaledArea, "tier \(tier)")
        }
        // A removal undoes the term.
        var reduced = histogram
        for chunk in chunks.prefix(100) {
            GaussianPagingPolicy.addFillTerm(to: &reduced, splatCount: chunk.n, area: chunk.area, coarseCounts: (chunk.m1, chunk.m2), sign: -1)
        }
        let rest = GaussianChunkCullMath.densityHistogram(levelledChunks: chunks.dropFirst(100).map {
            GaussianChunkCullMath.LevelledChunk(splatCount: $0.n, residentRanks: $0.n, screenArea: $0.area, coarse1: $0.m1, coarse2: $0.m2, availableLevels: ($0.m1 > 0 ? 1 : 0) | ($0.m2 > 0 ? 2 : 0))
        })
        XCTAssertEqual(reduced.tierArray.map(\.splats), rest.tierArray.map(\.splats))
        XCTAssertEqual(reduced.tierArray.map(\.levelledScaledArea), rest.tierArray.map(\.levelledScaledArea))

        let total = chunks.reduce(0) { $0 + Int($1.n) }
        let levels = (densityFloor: Float.infinity, tierShifts: (2, 6))
        // Without levels: the budget solve's own mirror, the grant being the room.
        let room = Float(total) / 4
        let plainCap = GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: room, levels: nil)
        XCTAssertEqual(plainCap, GaussianChunkCullMath.densityCap(histogram: histogram, grant: UInt32(room)), "the fill cap is the budget solve over the fill histogram")
        XCTAssertTrue(plainCap.isFinite && plainCap > 0)
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.boundedGrant(histogram: histogram, density: plainCap), room)
        XCTAssertGreaterThan(GaussianChunkCullMath.boundedGrant(histogram: histogram, density: plainCap * 1.01), room, "the largest such density on the grid")
        // With levels: the levelled request, which draws the coarse chunks at their counts.
        let levelledCap = GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: room, levels: levels)
        XCTAssertTrue(levelledCap.isFinite && levelledCap > 0)
        XCTAssertLessThanOrEqual(GaussianChunkCullMath.boundedRequest(histogram: histogram, density: levelledCap, tierShifts: levels.tierShifts), room)
        XCTAssertGreaterThan(GaussianChunkCullMath.boundedRequest(histogram: histogram, density: levelledCap * 1.01, tierShifts: levels.tierShifts), room)
        XCTAssertNotEqual(levelledCap, plainCap, "the levels change the solve")
        // A room below what the coarsest levels alone draw: nothing fits.
        let coarseFloor = GaussianChunkCullMath.boundedRequest(histogram: histogram, density: 0, tierShifts: levels.tierShifts)
        XCTAssertGreaterThan(coarseFloor, 0)
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: coarseFloor * 0.9, levels: levels), 0)
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: Float(total) * 2, levels: nil), .infinity, "everything fits whole")
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: 0, levels: nil), 0, "nothing fits")
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: GaussianBudgetDensityHistogram(), room: 100, levels: nil), .infinity, "nothing demanded")
        XCTAssertEqual(GaussianPagingPolicy.fillRoom(budget: 1000, reservedSplats: 100), 0.98 * 1000 - 100)
        // A room beyond what a whole number of 32-bit splats can hold is taken as that number,
        // never converted as is (`Float(UInt32.max)` rounds up to 2^32, which `UInt32(_:)`
        // rejects): an "unlimited" working set override reaches this on the render thread.
        XCTAssertEqual(GaussianPagingPolicy.fillRoomMax, 4_294_967_040)
        XCTAssertNotNil(UInt32(exactly: GaussianPagingPolicy.fillRoomMax))
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: 5e9, levels: nil), .infinity, "a room of 5e9 splats fits everything")
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: Float(UInt32.max), levels: levels), .infinity)
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: .infinity, levels: nil), .infinity)
        XCTAssertEqual(GaussianPagingPolicy.fillDensityCap(histogram: histogram, room: GaussianPagingPolicy.fillRoom(budget: Int.max, reservedSplats: 0), levels: levels), .infinity, "an unlimited budget")
    }

    func testUniformModeWantsTheScaledCount() {
        let n: UInt32 = 1000
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 0.001, densityCap: 0.25, fillDensity: 1, fillScale: 0.5, uniformQuotas: true, disableWorkingSetBudget: false), 500, "the fill scale over the full counts, never the read-back cap: that cap scales the resident ranks the kernel listed and has no fixed point over the full count")
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 0.001, densityCap: .infinity, fillDensity: 1, uniformQuotas: true, disableWorkingSetBudget: false), n, "scale 1 when nothing bounds the fill")
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 0.001, densityCap: .infinity, fillDensity: 1, fillScale: 0.5, uniformQuotas: true, disableWorkingSetBudget: false), 500, "the fill scale")
        // The fixed point: with every demanded chunk resident at the needed ranks the request
        // is 1.25 × the room, the kernel's cap 0.8, and the quota over the resident ranks is the
        // fill scale times the count — and the wants do not move.
        let budget = 300_000
        let chunks = 200
        let scale = GaussianPagingPolicy.fillScale(budget: budget, reservedSplats: 0, demandedSplats: chunks * 4096)
        let want = GaussianPagingPolicy.wantedRanks(splatCount: 4096, area: 1, densityCap: .infinity, fillDensity: 1, fillScale: scale, uniformQuotas: true, disableWorkingSetBudget: false)
        let needed = GaussianPagingPolicy.neededRanks(want: want, splatCount: 4096)
        let room = gaussianBudgetHeadroom * Float(budget)
        let cap = room / Float(chunks * Int(needed))
        XCTAssertEqual(cap, 0.8, accuracy: 0.01)
        XCTAssertEqual(GaussianChunkCullMath.quota(scale: cap, splatCount: needed), want, "the kernel grants the wanted ranks of the resident ones")
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: 4096, area: 1, densityCap: cap, fillDensity: 1, fillScale: scale, uniformQuotas: true, disableWorkingSetBudget: false), want, "the read-back cap leaves the wants where they are")
        XCTAssertEqual(GaussianPagingPolicy.fillScale(budget: 1000, reservedSplats: 0, demandedSplats: 4900), 0.2, accuracy: 1e-6)
        XCTAssertEqual(GaussianPagingPolicy.fillScale(budget: 1000, reservedSplats: 0, demandedSplats: 100), 1)
        XCTAssertEqual(GaussianPagingPolicy.fillScale(budget: 1000, reservedSplats: 0, demandedSplats: 0), 1)
    }

    func testDisableWorkingSetBudgetWantsEverything() {
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: 777, area: 0, densityCap: 0, fillDensity: 0, uniformQuotas: false, disableWorkingSetBudget: true), 777)
    }

    /// With every demanded chunk resident at r_i = min(n_i, ceil(1.25 × d × A_i)), the grant
    /// over the resident counts equals the grant over the full counts at d: the resident
    /// extents never bind, so the density does not chase residency.
    func testHeadroomGivesTheDensityCapAFixedPoint() {
        var generator = SplitMix64(seed: 0xF15ED)
        for _ in 0 ..< 100 {
            let count = 50 + Int(generator.next() % 400)
            let chunks: [(n: UInt32, area: Float)] = (0 ..< count).map { _ in
                (UInt32(16 + generator.next() % 1009), 0.0001 + 0.2 * generator.unit())
            }
            let cap = Float(exp2(-4 + 20 * generator.unit()))
            var full: Float = 0
            var resident: Float = 0
            for chunk in chunks {
                let want = GaussianChunkCullMath.quota(densityCap: cap, splatCount: chunk.n, screenArea: chunk.area)
                // The bound as stated: r = min(n, ceil(1.25 × d × A)) is never below d × A.
                let r = min(Float(chunk.n), ceil(GaussianPagingPolicy.wantedHeadroom * cap * chunk.area))
                full += min(Float(chunk.n), cap * chunk.area)
                resident += min(r, cap * chunk.area)
                // And what the pager keeps, min(n, ceil(1.25 × want)), grants the same quota.
                let kept = GaussianPagingPolicy.neededRanks(want: want, splatCount: chunk.n)
                XCTAssertEqual(GaussianChunkCullMath.quota(densityCap: cap, splatCount: kept, screenArea: chunk.area), want, "the quota of the resident prefix is the quota of the whole chunk")
            }
            XCTAssertEqual(resident, full, accuracy: max(1e-5 * full, 1e-4))
        }
    }

    // MARK: - Priority

    func testPriorityOrdersNearLargeAndEmptyChunksFirst() {
        let R = 256
        let large = GaussianPagingPolicy.loadPriority(area: 0.5, residentRanks: 0, neededRanks: 512, ranksPerPage: R)
        let small = GaussianPagingPolicy.loadPriority(area: 0.05, residentRanks: 0, neededRanks: 512, ranksPerPage: R)
        XCTAssertGreaterThan(large, small, "larger area first")
        let empty = GaussianPagingPolicy.loadPriority(area: 0.1, residentRanks: 0, neededRanks: 512, ranksPerPage: R)
        let topUp = GaussianPagingPolicy.loadPriority(area: 0.1, residentRanks: 256, neededRanks: 512, ranksPerPage: R)
        XCTAssertGreaterThan(empty, topUp, "an empty chunk before a top-up at equal area")
        XCTAssertEqual(empty, 0.1, accuracy: 1e-6, "deficit 1 over tier 0 + 1")
        XCTAssertEqual(topUp, 0.1 * 0.5 / 2, accuracy: 1e-6)
        let guardChunk = GaussianPagingPolicy.loadPriority(area: gaussianScreenAreaGuard, residentRanks: 0, neededRanks: 256, ranksPerPage: R)
        XCTAssertGreaterThan(guardChunk, GaussianPagingPolicy.loadPriority(area: 1, residentRanks: 0, neededRanks: 256, ranksPerPage: R), "the chunk the camera stands in first")
        XCTAssertEqual(GaussianPagingPolicy.loadPriority(area: 1, residentRanks: 512, neededRanks: 512, ranksPerPage: R), 0, "nothing missing")
        XCTAssertEqual(GaussianPagingPolicy.keepScore(area: 0.4, tier: 3), 0.1)
    }

    /// The pager evaluates the wants over its columns with the level rule's cap side computed
    /// once per pass (`GaussianChunkCullMath.levelCap`, `levelDeltaTier`, `level(mode:…)`) and
    /// the want through `fineWant`: over random inputs that path is `wantedRanks` /
    /// `coarseLevel` / `GaussianChunkCullMath.level(densityCap:…)` exactly.
    func testTheColumnRulesThePagerRunsAreTheDocumentedRules() {
        var rng = SplitMix64(seed: 0x5EED_C0DE)
        let modes: [GaussianLevelMode] = [.auto, .fineOnly, .coarseOnly]
        var coarseWants = 0
        var fineWants = 0
        for _ in 0 ..< 4000 {
            let n = UInt32(1 + rng.next() % 1024)
            let area = exp2(rng.unit() * 24 - 12)
            let cap: Float = rng.unit() < 0.15 ? .infinity : rng.unit() < 0.1 ? 0 : exp2(rng.unit() * 30 - 8)
            let fill: Float = rng.unit() < 0.3 ? .infinity : exp2(rng.unit() * 30 - 8)
            let floor: Float = rng.unit() < 0.5 ? .infinity : exp2(rng.unit() * 30 - 8)
            let mask = UInt32(rng.next() % 8)
            let previous = Int(rng.next() % 3)
            let shifts = (Int(rng.next() % 6), Int(rng.next() % 6) + 6)
            let mode = modes[Int(rng.next() % 3)]
            let counts = (UInt32(rng.next() % 300), UInt32(rng.next() % 100))
            let effective = cap.isFinite ? cap : fill
            let levelCap = GaussianChunkCullMath.levelCap(densityCap: effective, densityFloor: floor)
            let deltaTier = GaussianChunkCullMath.levelDeltaTier(cap: levelCap, splatCount: n, screenArea: area)
            let columnLevel = GaussianChunkCullMath.level(mode: mode, deltaTier: deltaTier, previous: previous, available: mask, tierShifts: shifts)
            XCTAssertEqual(columnLevel, GaussianChunkCullMath.level(densityCap: effective, densityFloor: floor, splatCount: n, screenArea: area, previous: previous, available: mask, tierShifts: shifts, levelMode: mode))
            // The wants: fine assumed drawn, the availability from the coarse inputs.
            let coarse = GaussianCoarseWantInputs(tierShifts: shifts, counts: counts, available: mask >> 1, densityFloor: floor, levelMode: mode)
            let wantMask = coarse.availabilityMask
            let wantLevel = GaussianChunkCullMath.level(mode: mode, deltaTier: deltaTier, previous: 0, available: wantMask, tierShifts: shifts)
            XCTAssertEqual(wantLevel, GaussianPagingPolicy.coarseLevel(coarse, splatCount: n, area: area, cap: effective, previous: 0))
            let columnWant = GaussianPagingPolicy.fineWant(level: wantLevel, cap: effective, splatCount: n, area: area)
            XCTAssertEqual(columnWant, GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: fill, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarse))
            XCTAssertEqual(GaussianPagingPolicy.fineWant(level: 0, cap: effective, splatCount: n, area: area), GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: fill, uniformQuotas: false, disableWorkingSetBudget: false), "without levels")
            if wantLevel != 0 { coarseWants += 1 } else { fineWants += 1 }
        }
        XCTAssertGreaterThan(coarseWants, 200, "the draw covered coarse wants")
        XCTAssertGreaterThan(fineWants, 200, "and fine ones")
    }

    // MARK: - Eviction

    private func resident(_ ranks: UInt16, area: Float, lastDemand: UInt32, needed: UInt16, mappedAt: UInt32 = 0, surplusSince: UInt32 = 0) -> GaussianChunkPageState {
        var state = GaussianChunkPageState()
        state.residentRanks = ranks
        state.lastArea = area
        state.lastDemandTick = lastDemand
        state.neededRanks = needed
        state.mappedAtTick = mappedAt
        state.surplusSinceTick = surplusSince
        return state
    }

    func testEvictionPrefersStaleThenSurplusThenDisplacementWithMargin() {
        let R = 256
        let tick: UInt32 = 200
        var inputs = GaussianEvictionInputs(tick: tick, ranksPerPage: R)
        inputs.holdOffTicks = 30
        inputs.surplusTicks = 45
        inputs.minResidencyTicks = 30

        // Chunk 0: stale (not seen for 100 ticks), two tiers. Chunk 1: demanded, three tiers
        // resident but one wanted, surplus for 50 ticks. Chunk 2: demanded, one tier, wanted.
        let states = [
            resident(512, area: 0.9, lastDemand: 100, needed: 512),
            resident(768, area: 0.3, lastDemand: tick, needed: 200, mappedAt: 100, surplusSince: 150),
            resident(256, area: 0.2, lastDemand: tick, needed: 256, mappedAt: 100),
        ]
        inputs.candidatePriority = 1.4 * GaussianPagingPolicy.keepScore(area: 0.2, tier: 0)
        var victims = GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2], count: 10, inputs: inputs)
        XCTAssertEqual(Array(victims.prefix(2)), [
            GaussianEvictionVictim(chunk: 0, tier: 1, kind: .stale),
            GaussianEvictionVictim(chunk: 0, tier: 0, kind: .stale),
        ], "the stale chunk first, from the top down")
        XCTAssertEqual(Array(victims[2 ..< 4]), [
            GaussianEvictionVictim(chunk: 1, tier: 2, kind: .surplus),
            GaussianEvictionVictim(chunk: 1, tier: 1, kind: .surplus),
        ], "then the surplus tiers above the wanted one")
        XCTAssertEqual(victims.count, 4, "at 1.4× the keep score nothing is displaced")

        inputs.candidatePriority = 1.5 * GaussianPagingPolicy.keepScore(area: 0.2, tier: 0)
        victims = GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2], count: 10, inputs: inputs)
        XCTAssertEqual(victims.count, 5)
        XCTAssertEqual(victims[4], GaussianEvictionVictim(chunk: 2, tier: 0, kind: .displacement), "the smallest keep score is displaced at 1.5×")
        // Chunk 1's remaining tail (tier 0, keep score 0.3) is not beaten by 1.5 × 0.2.
        inputs.candidatePriority = 1.5 * GaussianPagingPolicy.keepScore(area: 0.3, tier: 0)
        victims = GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2], count: 10, inputs: inputs)
        XCTAssertEqual(victims.count, 6)
        XCTAssertEqual(victims[5], GaussianEvictionVictim(chunk: 1, tier: 0, kind: .displacement), "the surplus tiers taken above do not count again")

        // Only as many as asked for.
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2], count: 1, inputs: inputs).count, 1)
        // A loading chunk is never a victim.
        var loading = states
        loading[0].flags.insert(.loading)
        XCTAssertFalse(GaussianPagingPolicy.selectVictims(states: loading, resident: [0, 1, 2], count: 10, inputs: inputs).contains { $0.chunk == 0 })
    }

    /// A chunk flagged `.demanded` is never stale, whatever its stamp: the pager stamps the
    /// chunks an ingest sees through the flag (not one by one), so a demanded chunk's own
    /// `lastDemandTick` predates the hold-off after a still camera.
    func testADemandedChunkIsNeverStaleWhateverItsStamp() {
        let R = 256
        var inputs = GaussianEvictionInputs(tick: 30 + 100, ranksPerPage: R)
        inputs.holdOffTicks = 30
        inputs.surplusTicks = 0
        inputs.minResidencyTicks = 0
        inputs.candidatePriority = .infinity
        // Two tiers resident, one wanted, surplus since tick 1: stamp 0 either way.
        var unflagged = resident(512, area: 0.5, lastDemand: 0, needed: 256, surplusSince: 1)
        var demanded = unflagged
        demanded.flags.insert(.demanded)
        let stale = GaussianPagingPolicy.selectVictims(states: [unflagged], resident: [0], count: 10, inputs: inputs)
        XCTAssertEqual(stale.map(\.kind), [.stale, .stale], "without the flag the stamp makes it stale, and it goes whole")
        let kept = GaussianPagingPolicy.selectVictims(states: [demanded], resident: [0], count: 10, inputs: inputs)
        XCTAssertFalse(kept.contains { $0.kind == .stale }, "with the flag it is never stale")
        XCTAssertEqual(kept, [
            GaussianEvictionVictim(chunk: 0, tier: 1, kind: .surplus),
            GaussianEvictionVictim(chunk: 0, tier: 0, kind: .displacement),
        ], "only its surplus tier and, for a candidate worth it, its tail")
        // Under pressure the same: the flag keeps it out of the stale class.
        inputs.pressure = true
        XCTAssertFalse(GaussianPagingPolicy.selectVictims(states: [demanded], resident: [0], count: 10, inputs: inputs).contains { $0.kind == .stale })
        // A stamp inside the hold-off keeps an unflagged chunk out of the stale class too.
        unflagged.lastDemandTick = inputs.tick - inputs.holdOffTicks
        XCTAssertFalse(GaussianPagingPolicy.selectVictims(states: [unflagged], resident: [0], count: 10, inputs: inputs).contains { $0.kind == .stale })
    }

    func testDisplacementMarginIsAppliedPerCandidateSlot() {
        let R = 256
        let tick: UInt32 = 500
        var inputs = GaussianEvictionInputs(tick: tick, ranksPerPage: R)
        inputs.holdOffTicks = 30
        inputs.surplusTicks = 45
        inputs.minResidencyTicks = 30
        // Eleven demanded chunks, one head each, equal worth K, mapped long ago.
        let K: Float = 0.2
        let states = (0 ..< 11).map { _ in resident(256, area: K, lastDemand: tick, needed: 256, mappedAt: 100) }
        let residentChunks = Array(0 ..< 11)
        // One strong candidate (1.6 K, one tier) riding with ten weak ones (K each): only the
        // strong one's slot may displace, the weak ones wait — the pool is saturated for them.
        let strong = GaussianPagingPolicy.loadPriority(area: 1.6 * K, residentRanks: 0, neededRanks: 256, ranksPerPage: R)
        let weak = GaussianPagingPolicy.loadPriority(area: K, residentRanks: 0, neededRanks: 256, ranksPerPage: R)
        inputs.candidatePriority = strong
        inputs.slotPriorities = [strong] + Array(repeating: weak, count: 10)
        var victims = GaussianPagingPolicy.selectVictims(states: states, resident: residentChunks, count: 11, inputs: inputs)
        XCTAssertEqual(victims.count, 1, "the weak candidates do not beat an equal tail by the margin")
        XCTAssertEqual(victims.first?.kind, .displacement)
        // The best candidate's priority alone (the single-candidate form) would have taken all eleven.
        inputs.slotPriorities = nil
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: residentChunks, count: 11, inputs: inputs).count, 11)
        // Two strong requests of two tiers each followed by weak ones: four tails go.
        inputs.slotPriorities = [strong, strong, strong, strong] + Array(repeating: weak, count: 7)
        victims = GaussianPagingPolicy.selectVictims(states: states, resident: residentChunks, count: 11, inputs: inputs)
        XCTAssertEqual(victims.count, 4)
        // Past the end of the list the last entry holds.
        inputs.slotPriorities = [strong]
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: residentChunks, count: 3, inputs: inputs).count, 3)
        // Stale and surplus victims need no margin and come first, before the per-slot test.
        var withStale = states
        withStale[4] = resident(256, area: K, lastDemand: 100, needed: 256, mappedAt: 100)
        inputs.slotPriorities = [weak, weak]
        inputs.candidatePriority = weak
        victims = GaussianPagingPolicy.selectVictims(states: withStale, resident: residentChunks, count: 2, inputs: inputs)
        XCTAssertEqual(victims, [GaussianEvictionVictim(chunk: 4, tier: 0, kind: .stale)], "the stale chunk goes, nothing is displaced for a weak candidate")
    }

    func testVictimSelectionDoesNotDependOnTheResidentOrder() {
        let R = 256
        let tick: UInt32 = 300
        var inputs = GaussianEvictionInputs(tick: tick, ranksPerPage: R)
        inputs.holdOffTicks = 30
        inputs.surplusTicks = 45
        inputs.minResidencyTicks = 30
        // Ties everywhere: three stale chunks last seen at the same tick, two demanded chunks of
        // equal area, one surplus tier each.
        var states = Array(repeating: GaussianChunkPageState(), count: 8)
        for chunk in [1, 4, 6] {
            states[chunk] = resident(512, area: 0.5, lastDemand: 200, needed: 512, mappedAt: 100)
        }
        for chunk in [2, 7] {
            states[chunk] = resident(512, area: 0.25, lastDemand: tick, needed: 256, mappedAt: 100, surplusSince: 200)
        }
        for chunk in [3, 5] {
            states[chunk] = resident(256, area: 0.25, lastDemand: tick, needed: 256, mappedAt: 100)
        }
        inputs.candidatePriority = 1.0
        let residentChunks = [1, 2, 3, 4, 5, 6, 7]
        let reference = GaussianPagingPolicy.selectVictims(states: states, resident: residentChunks, count: 20, inputs: inputs)
        XCTAssertEqual(reference.count, 12, "six stale tiers, two surplus tiers, four tails")
        XCTAssertEqual(reference.prefix(2).map(\.chunk), [1, 1], "the stale tie is broken on the chunk index")
        XCTAssertEqual(reference[6], GaussianEvictionVictim(chunk: 2, tier: 1, kind: .surplus))
        XCTAssertEqual(reference[8], GaussianEvictionVictim(chunk: 2, tier: 0, kind: .displacement))
        XCTAssertEqual(reference[9], GaussianEvictionVictim(chunk: 3, tier: 0, kind: .displacement))
        for permutation in [[7, 6, 5, 4, 3, 2, 1], [3, 7, 1, 5, 2, 6, 4], [5, 3, 7, 2, 6, 1, 4]] {
            XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: permutation, count: 20, inputs: inputs), reference, "resident order \(permutation)")
            XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: permutation, count: 1, inputs: inputs), Array(reference.prefix(1)))
            XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: permutation, count: 9, inputs: inputs), Array(reference.prefix(9)))
        }
    }

    func testMinimumResidencyPinsFreshPages() {
        let tick: UInt32 = 100
        var inputs = GaussianEvictionInputs(tick: tick, ranksPerPage: 256)
        inputs.minResidencyTicks = 30
        inputs.candidatePriority = 100
        let fresh = [resident(256, area: 0.1, lastDemand: tick, needed: 256, mappedAt: 90)]
        XCTAssertTrue(GaussianPagingPolicy.selectVictims(states: fresh, resident: [0], count: 1, inputs: inputs).isEmpty, "mapped 10 ticks ago: pinned")
        let aged = [resident(256, area: 0.1, lastDemand: tick, needed: 256, mappedAt: 70)]
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: aged, resident: [0], count: 1, inputs: inputs).count, 1, "mapped 30 ticks ago: displaceable")
        inputs.pressure = true
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: fresh, resident: [0], count: 1, inputs: inputs).count, 1, "under pressure the pin does not hold")
    }

    func testReloadCooldownHoldsAnEvictedTier() {
        var state = GaussianChunkPageState()
        state.neededRanks = 256
        state.retryAfterTick = 115
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 100))
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 114))
        XCTAssertTrue(GaussianPagingPolicy.isLoadCandidate(state, tick: 115))
        state.flags.insert(.loading)
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 200))
        state.flags = [.faulted]
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 200))
        state.flags = [.fadeActive]
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 200), "a fading chunk is not topped up")
        state.flags = []
        state.residentRanks = 256
        XCTAssertFalse(GaussianPagingPolicy.isLoadCandidate(state, tick: 200), "nothing missing")
    }

    func testHoldOffKeepsAGlancedAwayPage() {
        var inputs = GaussianEvictionInputs(tick: 100, ranksPerPage: 256)
        inputs.holdOffTicks = 30
        // Last seen 20 ticks ago: neither stale nor (wanted) surplus nor displaceable without a candidate.
        let glanced = [resident(256, area: 0.1, lastDemand: 80, needed: 256)]
        XCTAssertTrue(GaussianPagingPolicy.selectVictims(states: glanced, resident: [0], count: 1, inputs: inputs).isEmpty)
        // 31 ticks ago: stale.
        let stale = [resident(256, area: 0.1, lastDemand: 69, needed: 256)]
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: stale, resident: [0], count: 1, inputs: inputs), [GaussianEvictionVictim(chunk: 0, tier: 0, kind: .stale)])
        // Exactly the hold-off: kept.
        let edge = [resident(256, area: 0.1, lastDemand: 70, needed: 256)]
        XCTAssertTrue(GaussianPagingPolicy.selectVictims(states: edge, resident: [0], count: 1, inputs: inputs).isEmpty)
    }

    // MARK: - The retire ring

    func testRetireRingFreesSlotsThreeTicksLater() {
        var ring = GaussianPageRetireRing()
        var freeSlots = Set<UInt32>()
        var generation: [UInt32: Int] = [7: 0]
        let retiredAt: UInt32 = 10
        for tick in retiredAt ... retiredAt + 4 {
            let recycled = ring.recycle(atTick: tick)
            for slot in recycled {
                generation[slot, default: 0] += 1
                freeSlots.insert(slot)
            }
            if tick == retiredAt {
                ring.retire(7, atTick: tick)
            }
            switch tick {
            case retiredAt, retiredAt + 1, retiredAt + 2:
                XCTAssertFalse(freeSlots.contains(7), "tick \(tick): still retiring")
                XCTAssertEqual(ring.total, 1)
            default:
                XCTAssertTrue(freeSlots.contains(7), "tick \(tick): free")
                XCTAssertEqual(ring.total, 0)
            }
        }
        XCTAssertEqual(generation[7], 1, "the generation is bumped once")
        // Draining takes everything at once.
        ring.retire(1, atTick: 20)
        ring.retire(2, atTick: 21)
        XCTAssertEqual(Set(ring.drainAll()), [1, 2])
        XCTAssertEqual(ring.total, 0)
        XCTAssertEqual(GaussianPageRetireRing.depth, maxInFlightCommandBuffers)
    }

    // MARK: - Coalescing

    private func entry(payloadOffset: UInt64, splatCount: UInt32, shBytesPerSplat: Int) -> UntoldGSChunkEntry {
        UntoldGSChunkEntry(
            payloadOffset: payloadOffset,
            payloadBytes: UInt32(UntoldGSFormat.alignedToPage(Int(splatCount) * (16 + shBytesPerSplat))),
            coreBytes: 16 * splatCount,
            splatCount: splatCount,
            aabbMin: .zero,
            aabbMax: .one,
            logScaleMin: -3,
            logScaleMax: -1,
            crc32: 0
        )
    }

    func testCoalescerMergesContiguousTiersOfOneChunkOnly() {
        let chunk = entry(payloadOffset: 65536, splatCount: 1024, shBytesPerSplat: 9)
        // Ranks [256, 1024) into slots 10, 11, 12: one core range and one SH range.
        let merged = GaussianPagingPolicy.coalesceRequest(chunk: chunk, firstRank: 256, rankCount: 768, slots: [10, 11, 12], ranksPerPage: 256, shBytesPerSplat: 9)
        XCTAssertEqual(merged.core, [GaussianPageReadRange(fileOffset: 65536 + 4096, byteCount: 16384 - 4096, poolOffset: 10 * 4096)])
        XCTAssertEqual(merged.sh, [GaussianPageReadRange(fileOffset: 65536 + 16384 + 256 * 9, byteCount: 768 * 9, poolOffset: 10 * 256 * 9)])
        // Non-adjacent slots split at the slot boundary.
        let split = GaussianPagingPolicy.coalesceRequest(chunk: chunk, firstRank: 256, rankCount: 768, slots: [10, 12, 13], ranksPerPage: 256, shBytesPerSplat: 9)
        XCTAssertEqual(split.core, [
            GaussianPageReadRange(fileOffset: 65536 + 4096, byteCount: 4096, poolOffset: 10 * 4096),
            GaussianPageReadRange(fileOffset: 65536 + 8192, byteCount: 8192, poolOffset: 12 * 4096),
        ])
        XCTAssertEqual(split.sh.count, 2)
        // A short last tier reads only its ranks; no harmonics, no SH ranges.
        let short = entry(payloadOffset: 0, splatCount: 700, shBytesPerSplat: 0)
        let tail = GaussianPagingPolicy.coalesceRequest(chunk: short, firstRank: 512, rankCount: 188, slots: [3], ranksPerPage: 256, shBytesPerSplat: 0)
        XCTAssertEqual(tail.core, [GaussianPageReadRange(fileOffset: 512 * 16, byteCount: 188 * 16, poolOffset: 3 * 4096)])
        XCTAssertTrue(tail.sh.isEmpty)
        // Two chunks never merge: each request is one chunk by construction; the whole-chunk
        // request of a 16-splat chunk is one range of 256 bytes.
        let tiny = entry(payloadOffset: 16384, splatCount: 16, shBytesPerSplat: 0)
        XCTAssertEqual(GaussianPagingPolicy.coalesceRequest(chunk: tiny, firstRank: 0, rankCount: 16, slots: [5], ranksPerPage: 16, shBytesPerSplat: 0).core, [GaussianPageReadRange(fileOffset: 16384, byteCount: 256, poolOffset: 5 * 256)])
    }

    // MARK: - Coarse levels (per-chunk-lod-tiers)

    /// Level 1 at ratio 3 (tier shift 4), level 2 at ratio 6 (shift 10), both landed, on a
    /// 1024-splat chunk.
    private func coarseInputs(available: UInt32 = 3, densityFloor: Float = .infinity, levelMode: GaussianLevelMode = .auto) -> GaussianCoarseWantInputs {
        GaussianCoarseWantInputs(tierShifts: (4, 10), counts: (128, 16), available: available, densityFloor: densityFloor, levelMode: levelMode)
    }

    func testWantedRanksZeroInCoarseRegime() {
        let n: UInt32 = 1024
        // Density n / A six octaves (twelve tiers) above the cap: level 2 by the rule (fine holds
        // down to four tiers under, level 1 down to ten), no fine rank wanted.
        let area: Float = 1024 / (1024 * 64)
        let cap: Float = 1024
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: area, cap: cap, previous: 0), 2)
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), 0, "a chunk drawn coarse wants no fine rank")
        // Three octaves above the cap: level 1, still nothing.
        let areaL1: Float = 1024 / (1024 * 8)
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: areaL1, cap: cap, previous: 0), 1)
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: areaL1, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), 0)
        // The same chunk with nothing landed yet wants the fine quota: there is no level to draw instead.
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs(available: 0)), GaussianChunkCullMath.quota(densityCap: cap, splatCount: n, screenArea: area))
        // A near chunk (its density at the cap) wants the fine quota as without levels.
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 1, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), GaussianChunkCullMath.quota(densityCap: cap, splatCount: n, screenArea: 1))
        // The fill density stands in for an infinite cap, the floor lowers the effective cap (the
        // level only: the want of a fine chunk is still on the fill density).
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: .infinity, fillDensity: cap, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), 0)
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: .infinity, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs(densityFloor: cap)), 0, "the density floor draws the far chunk coarse on a fitting frame")
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 1, densityCap: .infinity, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs(densityFloor: cap)), n)
        // Levels off: the fine-only mode, the uniform rule and the budget switch want as before.
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs(levelMode: .fineOnly)), GaussianChunkCullMath.quota(densityCap: cap, splatCount: n, screenArea: area))
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, fillScale: 0.5, uniformQuotas: true, disableWorkingSetBudget: false, coarse: coarseInputs()), 512)
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: true, coarse: coarseInputs()), n)
        // The coarse-only mode draws the coarsest landed level whatever the cap.
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: 1, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs(levelMode: .coarseOnly)), 0)
        // The mask: fine, plus each landed level with a count.
        XCTAssertEqual(coarseInputs().availabilityMask, 7)
        XCTAssertEqual(coarseInputs(available: 2).availabilityMask, 5)
        XCTAssertEqual(GaussianCoarseWantInputs(tierShifts: (4, 10), counts: (0, 16), available: 3).availabilityMask, 5, "a level the chunk is too small for is not available")
    }

    func testWantedRanksFinerInsideBand() {
        let n: UInt32 = 1024
        // Δ = tier(cap) − tier(n / A) = −4 exactly: the band between the level-1 threshold and the
        // one-tier hysteresis the GPU applies when the chunk drew level 1 last frame.
        let cap: Float = 1024
        let area: Float = 1024 / 4096
        XCTAssertEqual(GaussianChunkCullMath.densityTier(density: cap) - GaussianChunkCullMath.densityTier(density: Float(n) / area), -4)
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: area, cap: cap, previous: 0), 0, "from fine: fine")
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: area, cap: cap, previous: 1), 1, "from level 1: level 1, the band")
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: area, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), GaussianChunkCullMath.quota(densityCap: cap, splatCount: n, screenArea: area), "the wants take the finer assumption: the fine tiers stay while the GPU still draws level 1")
        // One octave further: level 1 from either side, nothing wanted.
        let areaBelow: Float = area / 2
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: areaBelow, cap: cap, previous: 0), 1)
        XCTAssertEqual(GaussianPagingPolicy.wantedRanks(splatCount: n, area: areaBelow, densityCap: cap, fillDensity: .infinity, uniformQuotas: false, disableWorkingSetBudget: false, coarse: coarseInputs()), 0)
        // The mirror with nothing resident steps to the next coarser available level.
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(), splatCount: n, area: 1, cap: cap, previous: 0, fineAvailable: false), 1, "fine wanted but not resident: level 1")
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(available: 2), splatCount: n, area: 1, cap: cap, previous: 0, fineAvailable: false), 2, "only level 2 landed")
        XCTAssertEqual(GaussianPagingPolicy.coarseLevel(coarseInputs(available: 0), splatCount: n, area: 1, cap: cap, previous: 0, fineAvailable: false), 0, "nothing available: the wanted level (the cull lists no such chunk)")
    }

    func testCoarseResidentLevelsFitCheck() {
        // The Vision Pro figures of the 20 M asset at ratios 3, 6: 40 MB of level 1, 5 MB of
        // level 2, a 75 MiB residency budget (300 MiB geometry budget) → level 2 only.
        let l1 = 40_000_000
        let l2 = 5_000_000
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 75 << 20, fraction: 0.2), 1)
        // A 900 MiB geometry budget (225 MiB residency): both.
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 225 << 20, fraction: 0.2), 2)
        // Ratios 4, 7 halve the bytes: still level 2 only at 75 MiB.
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1 / 2, l2 / 2], residencyBudgetBytes: 75 << 20, fraction: 0.2), 1)
        // A budget too small for the coarsest: none.
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 16 << 20, fraction: 0.2), 0)
        // One level in the file: it, or nothing.
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l2], residencyBudgetBytes: 75 << 20, fraction: 0.2), 1)
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l2], residencyBudgetBytes: 16 << 20, fraction: 0.2), 0)
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [], residencyBudgetBytes: 75 << 20), 0)
        // Bytes other entities hold come off the bound; the override replaces the fraction.
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 225 << 20, allocatedBytes: 10 << 20, fraction: 0.2), 1)
        XCTAssertEqual(GaussianPagingPolicy.coarseBudgetFractionInEffect, GaussianPagingPolicy.coarseBudgetFraction)
        GaussianPagingPolicy.coarseBudgetFractionOverride = 0.6
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 75 << 20), 2, "60 % of 75 MiB holds both")
        GaussianPagingPolicy.resetKnobs()
        XCTAssertEqual(GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: 75 << 20), 1)
    }

    func testCoarsePiecesAreSequentialFromTheStart() {
        let pieceBytes = GaussianPagingPolicy.coarsePieceBytes(maxPageBytesInFlight: 4 << 20)
        XCTAssertEqual(pieceBytes, 2 << 20, "half the in-flight cap")
        XCTAssertEqual(GaussianPagingPolicy.coarsePieceBytes(maxPageBytesInFlight: 1000), UntoldGSFormat.pageAlignment, "at least a page")
        let start: UInt64 = 16384 * 7
        let end = start + UInt64(5 * pieceBytes + 100)
        let pieces = GaussianPagingPolicy.coarsePieces(rangeStart: start, rangeEnd: end, pieceBytes: pieceBytes)
        XCTAssertEqual(pieces.count, 6)
        var cursor = start
        for (index, piece) in pieces.enumerated() {
            XCTAssertEqual(piece.fileOffset, cursor, "piece \(index) follows the previous")
            XCTAssertEqual(piece.bufferOffset, Int(piece.fileOffset - start))
            XCTAssertEqual(piece.byteCount, index < 5 ? pieceBytes : 100)
            cursor = piece.end
        }
        XCTAssertEqual(cursor, end)
        XCTAssertTrue(GaussianPagingPolicy.coarsePieces(rangeStart: 10, rangeEnd: 10, pieceBytes: pieceBytes).isEmpty)
    }

    func testVictimsExcludeLevelFade() {
        let R = 256
        let tick: UInt32 = 200
        var inputs = GaussianEvictionInputs(tick: tick, ranksPerPage: R)
        inputs.holdOffTicks = 30
        inputs.surplusTicks = 45
        inputs.minResidencyTicks = 30
        inputs.candidatePriority = 100
        // Chunk 0 stale, chunk 1 surplus, chunk 2 a displaceable tail — every class — each with
        // a level fade running; chunk 3 the same tail without one.
        var states = [
            resident(512, area: 0.9, lastDemand: 100, needed: 512),
            resident(768, area: 0.3, lastDemand: tick, needed: 200, mappedAt: 100, surplusSince: 150),
            resident(256, area: 0.2, lastDemand: tick, needed: 256, mappedAt: 100),
            resident(256, area: 0.25, lastDemand: tick, needed: 256, mappedAt: 100),
        ]
        for chunk in 0 ..< 3 {
            states[chunk].flags.insert(.levelFade)
        }
        let victims = GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2, 3], count: 10, inputs: inputs)
        XCTAssertEqual(victims, [GaussianEvictionVictim(chunk: 3, tier: 0, kind: .displacement)], "a chunk mid-fade is no victim in any class")
        inputs.pressure = true
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2, 3], count: 10, inputs: inputs).map(\.chunk), [3], "under pressure too")
        // The flag lifted: the classes as before.
        for chunk in 0 ..< 3 {
            states[chunk].flags.remove(.levelFade)
        }
        inputs.pressure = false
        XCTAssertEqual(GaussianPagingPolicy.selectVictims(states: states, resident: [0, 1, 2, 3], count: 10, inputs: inputs).count, 7, "two stale tiers, two surplus tiers, three tails")
        // A fading chunk is still no load candidate for the arrival fade, and a level fade alone
        // does not stop a top-up.
        var state = GaussianChunkPageState()
        state.neededRanks = 512
        state.residentRanks = 256
        state.flags = [.levelFade]
        XCTAssertTrue(GaussianPagingPolicy.isLoadCandidate(state, tick: tick))
    }

    func testMapPreservesCoarseAvailable() {
        let previous = GaussianChunkResidency(residentRanks: 256, fadeFromRank: 0, arrivalFrame: 3, coarseAvailable: 3)
        let mapped = GaussianPagingPolicy.mappedResidency(previous: previous, firstRank: 256, rankCount: 256, now: 9)
        XCTAssertEqual(mapped.residentRanks, 512)
        XCTAssertEqual(mapped.fadeFromRank, 256)
        XCTAssertEqual(mapped.arrivalFrame, 9)
        XCTAssertEqual(mapped.coarseAvailable, 3, "the availability bits ride in the struct and survive the rewrite")
        let fresh = GaussianPagingPolicy.mappedResidency(previous: GaussianChunkResidency(residentRanks: 0, fadeFromRank: 0, arrivalFrame: 0, coarseAvailable: 2), firstRank: 0, rankCount: 256, now: 1)
        XCTAssertEqual(fresh.residentRanks, 256)
        XCTAssertEqual(fresh.coarseAvailable, 2)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.coarseAvailable), 12)
    }

    // MARK: - Sizing

    func testResidentEstimateBytes() {
        GaussianPagingPolicy.pagingThresholdBytesOverride = nil
        let budget = 200 << 20
        let threshold = GaussianPagingPolicy.pagingThresholdBytes(residencyBudgetBytes: budget)
        XCTAssertEqual(threshold, min(GaussianPagingPolicy.pagingThresholdBytesDefault, budget))
        XCTAssertEqual(GaussianPagingPolicy.residentEstimateBytes(assetBytes: threshold, residencyBudgetBytes: budget), threshold, "at the threshold: whole")
        XCTAssertEqual(GaussianPagingPolicy.residentEstimateBytes(assetBytes: threshold + 1, residencyBudgetBytes: budget, poolMaxBytes: 64 << 20), 64 << 20, "above it: the pool cap")
        XCTAssertEqual(GaussianPagingPolicy.residentEstimateBytes(assetBytes: 2 << 30, residencyBudgetBytes: 100 << 20, poolMaxBytes: 1 << 30), 100 << 20, "never above the budget")
        GaussianPagingPolicy.pagingThresholdBytesOverride = 0
        XCTAssertEqual(GaussianPagingPolicy.residentEstimateBytes(assetBytes: 1000, residencyBudgetBytes: budget), 1000, "a small asset pages whole into its pool")
        GaussianPagingPolicy.residencyBudgetBytesOverride = 12345
        XCTAssertEqual(GaussianPagingPolicy.residencyBudgetBytes(geometryBudget: 1 << 30), 12345)
        GaussianPagingPolicy.residencyBudgetBytesOverride = nil
        XCTAssertEqual(GaussianPagingPolicy.residencyBudgetBytes(geometryBudget: 1 << 30), 1 << 28)
    }

    func testPoolSlotCountFollowsTheBudgetTheCapAndTheMinimum() {
        let slotBytes = 4096
        // 1 MiB budget against a large asset: 256 slots.
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 320 << 20, slotBytes: slotBytes, residencyBudgetBytes: 1 << 20, allocatedBytes: 0, poolMaxBytes: 256 << 20, minPoolSlots: 4), 256)
        // The asset bounds the pool.
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 40960, slotBytes: slotBytes, residencyBudgetBytes: 1 << 30, allocatedBytes: 0, poolMaxBytes: 256 << 20, minPoolSlots: 4), 10)
        // The platform cap bounds it.
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 1 << 30, slotBytes: slotBytes, residencyBudgetBytes: 1 << 30, allocatedBytes: 0, poolMaxBytes: 256 << 20, minPoolSlots: 4), 65536)
        // What other pools left.
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 1 << 30, slotBytes: slotBytes, residencyBudgetBytes: 1 << 20, allocatedBytes: 1 << 19, poolMaxBytes: 256 << 20, minPoolSlots: 4), 128)
        // Never below the minimum.
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 1 << 30, slotBytes: slotBytes, residencyBudgetBytes: 0, allocatedBytes: 0, poolMaxBytes: 256 << 20, minPoolSlots: 64), 64)
        XCTAssertEqual(GaussianPagingPolicy.poolSlotCount(assetBytes: 256, slotBytes: 256, residencyBudgetBytes: 1 << 30, allocatedBytes: 0, poolMaxBytes: 256 << 20, minPoolSlots: 4), 4)
        XCTAssertEqual(GaussianPagingPolicy.ranksPerPage(splatsPerChunk: 1024), 256)
        XCTAssertEqual(GaussianPagingPolicy.ranksPerPage(splatsPerChunk: 16), 16)
        XCTAssertEqual(GaussianPagingPolicy.pagesPerChunk(splatsPerChunk: 1024), 4)
        XCTAssertEqual(GaussianPagingPolicy.pagesPerChunk(splatsPerChunk: 16384), 64)
        XCTAssertEqual(GaussianPagingPolicy.pagesPerChunk(splatsPerChunk: 16), 1)
        XCTAssertEqual(GaussianPagingPolicy.assetBytes(splatCount: 20_000_000, shBytesPerSplat: 0), 320_000_000)
        XCTAssertTrue(GaussianPagingPolicy.shouldPage(assetBytes: 1, thresholdBytes: 0, allowPaging: true, disablePaging: false))
        XCTAssertFalse(GaussianPagingPolicy.shouldPage(assetBytes: 1, thresholdBytes: 0, allowPaging: false, disablePaging: false), "no chunk kernels: whole")
        XCTAssertFalse(GaussianPagingPolicy.shouldPage(assetBytes: 1, thresholdBytes: 0, allowPaging: true, disablePaging: true))
        XCTAssertFalse(GaussianPagingPolicy.shouldPage(assetBytes: 100, thresholdBytes: 100, allowPaging: true, disablePaging: false), "at the threshold: whole")
    }

    func testPoolReservationsAreClaimedUnderTheRegistryLock() {
        let registry = GaussianPagePoolRegistry.shared
        let baseline = registry.allocatedBytes
        let slotBytes = 4096
        let budget = 8 * slotBytes
        let assetBytes = 100 * slotBytes
        let claim: @Sendable () -> (GaussianPagePoolReservation, Int) = {
            var slots = 0
            let reservation = registry.reserve { allocated in
                slots = GaussianPagingPolicy.poolSlotCount(assetBytes: assetBytes, slotBytes: slotBytes, residencyBudgetBytes: budget, allocatedBytes: allocated - baseline, minPoolSlots: 4)
                return slots * slotBytes
            }
            return (reservation, slots)
        }
        // In sequence: the first takes the budget, the second the floor.
        let (first, firstSlots) = claim()
        XCTAssertEqual(firstSlots, 8)
        XCTAssertEqual(registry.allocatedBytes - baseline, 8 * slotBytes, "a claim counts before any pool exists")
        let (second, secondSlots) = claim()
        XCTAssertEqual(secondSlots, 4)
        XCTAssertEqual(registry.reservedBytes(second), 4 * slotBytes)
        registry.resize(first, bytes: 4 * slotBytes)
        XCTAssertEqual(registry.allocatedBytes - baseline, 8 * slotBytes, "a shrunk claim is settled at once")
        registry.release(first)
        registry.release(second)
        XCTAssertNil(registry.reservedBytes(first))
        XCTAssertEqual(registry.allocatedBytes, baseline)

        // At once from eight threads: exactly one sees the whole budget, the claims sum as if
        // sequential, and every one is released.
        final class Claims: @unchecked Sendable {
            let lock = NSLock()
            var all: [(GaussianPagePoolReservation, Int)] = []
        }
        let claims = Claims()
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            let claimed = claim()
            claims.lock.lock()
            claims.all.append(claimed)
            claims.lock.unlock()
        }
        XCTAssertEqual(claims.all.filter { $0.1 == 8 }.count, 1, "one load gets the budget")
        XCTAssertEqual(claims.all.filter { $0.1 == 4 }.count, 7, "the others the floor")
        XCTAssertEqual(registry.allocatedBytes - baseline, claims.all.reduce(0) { $0 + $1.1 * slotBytes })
        for (reservation, _) in claims.all {
            registry.release(reservation)
        }
        XCTAssertEqual(registry.allocatedBytes, baseline)
    }

    /// The coarse levels' share of the residency budget is one ledger for every levelled
    /// entity (per-chunk-lod-tiers): a claim is sized against the bytes the others hold under
    /// the registry's lock, counts in `coarseBytes` — beside the pools, not in `allocatedBytes`
    /// — until it is released, and a `GaussianCoarseClaim` releases it when dropped.
    func testCoarseClaimsShareTheCoarseBudget() {
        let registry = GaussianPagePoolRegistry.shared
        let baselineCoarse = registry.coarseBytes
        let baselinePools = registry.allocatedBytes
        let l1 = 40 << 20
        let l2 = 5 << 20
        let budget = 300 << 20 // 20 % = 60 MiB: both levels once, the coarsest for the next, then nothing
        let claim: () -> (GaussianCoarseReservation, Int) = {
            var levels = 0
            let reservation = registry.reserveCoarse { held in
                levels = GaussianPagingPolicy.coarseResidentLevels(coarseBytesPerLevel: [l1, l2], residencyBudgetBytes: budget, allocatedBytes: held - baselineCoarse, fraction: 0.2)
                return levels == 2 ? l1 + l2 : (levels == 1 ? l2 : 0)
            }
            return (reservation, levels)
        }
        let (first, firstLevels) = claim()
        XCTAssertEqual(firstLevels, 2, "the first entity keeps both levels")
        XCTAssertEqual(registry.coarseBytes - baselineCoarse, l1 + l2)
        XCTAssertEqual(registry.allocatedBytes, baselinePools, "the coarse share is beside the pools")
        let (second, secondLevels) = claim()
        XCTAssertEqual(secondLevels, 1, "the second sees 45 MiB held and keeps the coarsest alone")
        let (third, thirdLevels) = claim()
        XCTAssertEqual(thirdLevels, 1, "50 MiB held: the coarsest still fits")
        let (fourth, fourthLevels) = claim()
        XCTAssertEqual(fourthLevels, 1, "55 MiB held")
        let (fifth, fifthLevels) = claim()
        XCTAssertEqual(fifthLevels, 0, "60 MiB held: nothing left of the share")
        XCTAssertEqual(registry.coarseBytes - baselineCoarse, l1 + 4 * l2)
        registry.releaseCoarse(fifth)
        registry.releaseCoarse(first)
        XCTAssertEqual(registry.coarseBytes - baselineCoarse, 3 * l2, "released bytes come back to the share")
        let (sixth, sixthLevels) = claim()
        XCTAssertEqual(sixthLevels, 2, "15 MiB held: both fit again")
        for reservation in [second, third, fourth, sixth] {
            registry.releaseCoarse(reservation)
        }
        registry.releaseCoarse(sixth)
        XCTAssertEqual(registry.coarseBytes, baselineCoarse, "a second release is a no-op")

        // A claim object gives the bytes back when it is dropped.
        var token: GaussianCoarseClaim? = GaussianCoarseClaim(reservation: registry.reserveCoarse { _ in l2 }, bytes: l2)
        XCTAssertEqual(token?.bytes, l2)
        XCTAssertEqual(registry.coarseBytes - baselineCoarse, l2)
        token = nil
        XCTAssertEqual(registry.coarseBytes, baselineCoarse)
    }
}
