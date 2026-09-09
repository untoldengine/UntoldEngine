//
//  GaussianBudgetedWorkingSetTest.swift
//  UntoldEngine
//
//  The budget-sized shared working set and the per-chunk quotas that fit .untoldgs entities to
//  it (GaussianWorkingSetBudget.metal, GaussianChunkPreprocess.metal): under a budget below the
//  visible count the frame compacts exactly the quota sum, the kept records of every chunk are
//  its first quota ranks, two identical frames compact the same set in the same depth order and
//  the overflow counter stays at zero; a budget step converges through the hysteresis over
//  several frames by at most 10 % of the scale per frame; the last fifth of a truncated chunk
//  fades its opacity by rank as the CPU mirror predicts; the memory accounting charges a chunked
//  entity 16 bytes per splat plus harmonics and chunk table, the shared set its budget rather
//  than the resident total, and a two-million-splat asset loads and renders under the raised cap.
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
final class GaussianBudgetedWorkingSetTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var savedDisableHZBOcclusionCull = false
    private var savedDisableChunkCull = false
    private var savedDisableWorkingSetBudget = false
    private var savedWorkingSetOverride: Int?

    /// The far camera of GaussianChunkCullTest: the whole 200-splat fixture in view.
    private let farCamera = (eye: simd_float3(0, 3, 7), target: simd_float3.zero)

    override func setUp() async throws {
        try await super.setUp()
        savedDisableHZBOcclusionCull = GaussianDebugOptions.shared.disableHZBOcclusionCull
        savedDisableChunkCull = GaussianDebugOptions.shared.disableChunkCull
        savedDisableWorkingSetBudget = GaussianDebugOptions.shared.disableWorkingSetBudget
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        GaussianDebugOptions.shared.disableHZBOcclusionCull = true
        GaussianDebugOptions.shared.disableChunkCull = false
        GaussianDebugOptions.shared.disableWorkingSetBudget = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
    }

    override func tearDown() async throws {
        GaussianDebugOptions.shared.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        GaussianDebugOptions.shared.disableChunkCull = savedDisableChunkCull
        GaussianDebugOptions.shared.disableWorkingSetBudget = savedDisableWorkingSetBudget
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

    // MARK: - Helpers

    private func bakeV3(chunkSplats log2: UInt8) throws -> URL {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianBudgetedWorkingSetTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    private struct ChunkedFixture {
        let entity: EntityID
        let component: GaussianComponent
        let table: GaussianChunkTable
        let cpu: UntoldGSAsset
        let resolver: GaussianSplatIndexResolver
        let legacy: GaussianLegacyTwin
    }

    private func loadFixture(chunkSplats log2: UInt8 = 4) throws -> ChunkedFixture {
        let url = try bakeV3(chunkSplats: log2)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        let cpu = try UntoldGSFormat.read(from: url)
        let legacy = try GaussianLegacyTwin(loaded: GaussianChunkLoader.load(url: url))
        return ChunkedFixture(
            entity: entity,
            component: component,
            table: table,
            cpu: cpu,
            resolver: GaussianSplatIndexResolver(positions: cpu.encodedSplats.map(\.position)),
            legacy: legacy
        )
    }

    private func runFrame() {
        runGaussianCullAndPreprocess()
    }

    /// The published budget state of the slot the manual frames run in.
    private func budgetState() throws -> GaussianBudgetState {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        return try XCTUnwrap(GaussianSharedWorkingSet.shared.budgetReadback(slot: slot)).contents().load(as: GaussianBudgetState.self)
    }

    private func sharedVisibleSet() -> GaussianVisibleSet {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        return GaussianSharedWorkingSet.shared.visibleSet(slot: slot)!.contents().load(as: GaussianVisibleSet.self)
    }

    private func visibleChunkEntries(_ table: GaussianChunkTable) -> (record: GaussianVisibleSet, entries: [GaussianVisibleChunk]) {
        let slot = min(renderInfo.currentInFlightFrameSlot, table.visibleChunkSets.count - 1)
        let record = table.visibleChunkSets[slot].contents().load(as: GaussianVisibleSet.self)
        let count = Int(record.threadgroupCount)
        let entries = Array(UnsafeBufferPointer(start: table.visibleChunks[slot].contents().bindMemory(to: GaussianVisibleChunk.self, capacity: count), count: count))
        return (record, entries)
    }

    /// Runs the frame's cull and sort as the renderer does, and returns the sorted keys' depth
    /// words (the low word is the append slot, which no two frames need share).
    private func sortedDepthWords() -> [UInt32] {
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected to allocate a command buffer")
            return []
        }
        executeGaussianFrustumCulling(commandBuffer)
        executeGaussianPreprocess(commandBuffer)
        executeRadixSort(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return sharedGaussianSortedKeys().map { UInt32(truncatingIfNeeded: $0 >> 32) }
    }

    // MARK: - (b) The budget: quotas, first ranks, determinism, no overflow

    func testBudgetBelowTheVisibleCountKeepsEachChunksFirstQuotaRanks() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)
        XCTAssertEqual(splatCount, 200)

        // Unlimited: the whole asset is in view for this camera (the test needs every splat to
        // pass the per-splat test, so the quota alone decides what is kept).
        runFrame()
        let unlimited = fixture.resolver.indices(of: sharedGaussianRecords())
        XCTAssertEqual(unlimited.count, splatCount, "sanity — the far camera sees every splat")
        XCTAssertEqual(try budgetState().scale, 1)

        // Half the visible count. The first budgeted frame after a reset takes the target as is.
        let budget = 100
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()

        let state = try budgetState()
        XCTAssertEqual(Int(state.budget), budget, "the shared set is exactly the budget when the resident total exceeds it")
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget)
        XCTAssertEqual(Int(state.requestedSplats), splatCount, "every chunk asked for its whole count")
        let expectedScale = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: budget)
        XCTAssertEqual(state.targetScale, expectedScale, accuracy: 1e-6)
        XCTAssertEqual(state.scale, expectedScale, accuracy: 1e-6, "the first frame after a reset takes the target")

        let chunks = visibleChunkEntries(fixture.table)
        XCTAssertEqual(chunks.entries.count, fixture.table.chunkCount, "every chunk is visible")
        var expectedQuotaTotal = 0
        for entry in chunks.entries {
            let expected = GaussianChunkCullMath.quota(scale: state.scale, splatCount: entry.splatCount)
            XCTAssertEqual(entry.quota, expected, "chunk \(entry.chunkIndex): quota = floor(scale × splats)")
            XCTAssertLessThan(entry.quota, entry.splatCount, "chunk \(entry.chunkIndex) is truncated")
            XCTAssertGreaterThan(entry.quota, 0)
            expectedQuotaTotal += Int(expected)
        }
        XCTAssertEqual(Int(chunks.record.visibleCount), expectedQuotaTotal, "the chunk record sums the quotas")
        XCTAssertEqual(Int(chunks.record.instanceCount), splatCount, "and keeps the request")
        XCTAssertEqual(Int(state.quotaSplats), expectedQuotaTotal)
        XCTAssertLessThanOrEqual(expectedQuotaTotal, budget)

        let set = sharedVisibleSet()
        XCTAssertEqual(Int(set.visibleCount), expectedQuotaTotal, "the frame compacts exactly the quota sum")
        XCTAssertEqual(set.overflowCount, 0)

        // The kept records of every chunk are its first quota ranks — the most important
        // splats, as the bake ordered them.
        let kept = Set(fixture.resolver.indices(of: sharedGaussianRecords()))
        XCTAssertEqual(kept.count, expectedQuotaTotal, "each kept splat once")
        for (chunkIndex, chunk) in fixture.table.index.chunks.enumerated() {
            let entry = try XCTUnwrap(chunks.entries.first { Int($0.chunkIndex) == chunkIndex })
            let firstSplat = fixture.table.index.chunks[..<chunkIndex].reduce(0) { $0 + Int($1.splatCount) }
            let expectedRanks = Set((firstSplat ..< firstSplat + Int(entry.quota)).map { UInt32($0) })
            let chunkSplats = Set((firstSplat ..< firstSplat + Int(chunk.splatCount)).map { UInt32($0) })
            XCTAssertEqual(kept.intersection(chunkSplats), expectedRanks, "chunk \(chunkIndex) keeps exactly its first \(entry.quota) ranks")
        }

        // Determinism: two identical frames compact the same set in the same depth order.
        let firstDepths = sortedDepthWords()
        let firstSet = Set(fixture.resolver.indices(of: sharedGaussianRecords()))
        let secondDepths = sortedDepthWords()
        let secondSet = Set(fixture.resolver.indices(of: sharedGaussianRecords()))
        XCTAssertEqual(firstDepths.count, expectedQuotaTotal)
        XCTAssertEqual(firstDepths, secondDepths, "the sorted depth keys are identical frame to frame")
        XCTAssertEqual(firstSet, secondSet, "and so is the set of splats")
        XCTAssertEqual(sharedVisibleSet().overflowCount, 0)
        XCTAssertEqual(firstDepths, firstDepths.sorted(), "and ascending")
    }

    // MARK: - (c) Hysteresis

    func testBudgetStepConvergesOverSeveralFramesByAtMostTenPercentPerFrame() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)

        runFrame()
        XCTAssertEqual(try budgetState().scale, 1, "unlimited: the scale is 1")

        // A quarter of the visible count, without resetting the hysteresis.
        let budget = splatCount / 4
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        let target = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: budget)
        var scales: [Float] = [1]
        var previous: Float = 1
        for _ in 0 ..< 40 {
            runFrame()
            let state = try budgetState()
            XCTAssertEqual(state.targetScale, target, accuracy: 1e-6)
            XCTAssertGreaterThanOrEqual(state.scale, previous * (1 - gaussianBudgetMaxStepFraction) - 1e-5, "the scale falls by at most 10 % per frame")
            XCTAssertLessThanOrEqual(state.scale, previous + 1e-6, "and never rises while above the target")
            XCTAssertEqual(state.scale, GaussianChunkCullMath.smoothedScale(target: target, previous: previous), accuracy: 1e-5, "the CPU mirror predicts each step")
            scales.append(state.scale)
            previous = state.scale
            if abs(state.scale - target) < 1e-6 { break }
        }
        XCTAssertEqual(previous, target, accuracy: 1e-6, "the scale converged: \(scales)")
        XCTAssertGreaterThanOrEqual(scales.count - 1, 5, "a step to a quarter takes several frames: \(scales)")

        // Converged: the quotas fit the budget and nothing overflows.
        XCTAssertLessThanOrEqual(Int(sharedVisibleSet().visibleCount), budget)
        XCTAssertEqual(sharedVisibleSet().overflowCount, 0)

        // Back to unlimited: the scale climbs by at most 10 % of itself per frame.
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        var climbed: [Float] = [previous]
        for _ in 0 ..< 60 {
            runFrame()
            let state = try budgetState()
            XCTAssertEqual(state.targetScale, 1)
            XCTAssertLessThanOrEqual(state.scale, previous * (1 + gaussianBudgetMaxStepFraction) + 1e-5, "the scale rises by at most 10 % per frame")
            XCTAssertGreaterThanOrEqual(state.scale, previous - 1e-6)
            climbed.append(state.scale)
            previous = state.scale
            if state.scale >= 1 { break }
        }
        XCTAssertEqual(previous, 1, "the scale is back at 1: \(climbed)")
        XCTAssertGreaterThanOrEqual(climbed.count - 1, 5)

        // The debug switch: every chunk keeps its whole count and the set holds the resident total.
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        runFrame()
        XCTAssertEqual(try budgetState().scale, 1)
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, splatCount)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)
    }

    // MARK: - (d) The opacity band

    /// One chunk of 200 splats (256-splat chunks) under a budget of 100: quota 98, the band over
    /// ranks 78 ..< 98. Each kept record's opacity divided by the splat's own opacity is the band
    /// factor — 1 before the band, then falling by one step per rank to 1/20 at the last rank.
    func testLastFifthOfATruncatedChunkFadesOpacityByRank() throws {
        let fixture = try loadFixture(chunkSplats: 8)
        XCTAssertEqual(fixture.table.chunkCount, 1)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        fixture.component.opacityScale = 1

        let budget = 100
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()

        let chunks = visibleChunkEntries(fixture.table)
        let entry = try XCTUnwrap(chunks.entries.first)
        let quota = entry.quota
        let scale = try budgetState().scale
        XCTAssertEqual(quota, GaussianChunkCullMath.quota(scale: scale, splatCount: 200))
        XCTAssertGreaterThan(quota, 50)
        XCTAssertLessThan(quota, 200)
        let bandStart = UInt32(gaussianOpacityBandFraction * Float(quota))
        XCTAssertGreaterThanOrEqual(quota - bandStart, 15, "the band spans enough ranks to see the ramp")

        let records = sharedGaussianRecords()
        XCTAssertEqual(records.count, Int(quota))
        let indices = fixture.resolver.indices(of: records)
        var factorByRank: [UInt32: Float] = [:]
        for (record, index) in zip(records, indices) {
            let baseOpacity = Float(fixture.cpu.encodedSplats[Int(index)].colorAndOpacity.w)
            guard baseOpacity > 0 else { continue }
            factorByRank[index] = record.conicAndOpacity.w / baseOpacity
        }
        XCTAssertEqual(Set(factorByRank.keys), Set(0 ..< quota), "the first quota ranks are kept")

        var previousFactor: Float = 1
        for rank in 0 ..< quota {
            let factor = try XCTUnwrap(factorByRank[rank])
            let expected = GaussianChunkCullMath.opacityBandFactor(rank: rank, quota: quota, splatCount: 200)
            XCTAssertEqual(factor, expected, accuracy: 2e-3, "rank \(rank): the record's opacity is the splat's times the band factor")
            if rank < bandStart {
                XCTAssertEqual(factor, 1, accuracy: 2e-3, "rank \(rank) is before the band")
            } else {
                XCTAssertLessThanOrEqual(factor, previousFactor + 2e-3, "rank \(rank): the band never rises")
                if rank > bandStart {
                    XCTAssertLessThan(factor, previousFactor - 1e-3, "rank \(rank): the band falls every rank")
                }
            }
            previousFactor = factor
        }
        XCTAssertLessThan(try XCTUnwrap(factorByRank[quota - 1]), 0.1, "the last kept rank is nearly transparent")

        // A chunk kept whole has no band.
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let whole = sharedGaussianRecords()
        XCTAssertEqual(whole.count, 200)
        for (record, index) in zip(whole, fixture.resolver.indices(of: whole)) {
            let baseOpacity = Float(fixture.cpu.encodedSplats[Int(index)].colorAndOpacity.w)
            XCTAssertEqual(record.conicAndOpacity.w, baseOpacity, accuracy: 2e-3)
        }
    }

    // MARK: - (f) Memory accounting

    func testChunkedEntityCostsItsPackedRecordsAndTheSharedSetItsBudget() throws {
        let fixture = try loadFixture()
        let splatCount = Int(fixture.component.splatCount)
        let packed = try XCTUnwrap(fixture.component.packedSplatData)
        XCTAssertEqual(packed.length, splatCount * UntoldGSFormat.coreRecordSize)
        XCTAssertEqual(
            fixture.component.estimatedGPUBytes,
            packed.length + (fixture.component.sphericalHarmonicsData?.length ?? 0) + fixture.table.gpuBytes,
            "16 bytes per splat, the harmonics and the chunk table — no encoded buffer, no index buffers, no share of the shared set"
        )
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: fixture.entity), fixture.component.estimatedGPUBytes)
        // The legacy twin of the same file pays the 48-byte record and 4 bytes per frame in flight instead.
        XCTAssertEqual(
            fixture.legacy.result.estimatedGPUBytes,
            splatCount * (MemoryLayout<EncodedGaussianSplat>.stride + maxInFlightCommandBuffers * MemoryLayout<UInt32>.stride)
                + maxInFlightCommandBuffers * MemoryLayout<GaussianVisibleSet>.stride
                + (fixture.legacy.result.sphericalHarmonicsBuffer?.length ?? 0)
        )

        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let workingSet = GaussianSharedWorkingSet.shared
        let perSplat = GaussianSharedWorkingSet.bytesPerSplatPerSlot * maxInFlightCommandBuffers
        XCTAssertEqual(perSplat, 216)

        // Below the budget the set holds the resident total, not the budget.
        GaussianRuntimeLimits.workingSetSplatsOverride = 1000
        runFrame()
        XCTAssertEqual(workingSet.capacity, splatCount, "no frame can compact more than is loaded")

        // A budget below the resident total sizes the set exactly to the budget.
        GaussianRuntimeLimits.workingSetSplatsOverride = 120
        runFrame()
        XCTAssertEqual(workingSet.capacity, 120)
        let recordBytes = maxInFlightCommandBuffers * (MemoryLayout<GaussianWorkingSetSplat>.stride + MemoryLayout<UInt64>.stride) * 120
        XCTAssertEqual(workingSet.residentBytes - fixedWorkingSetBytes(), recordBytes, "records and keys are 3 × 72 B × budget")
        XCTAssertEqual(MemoryBudgetManager.shared.gaussianWorkingSetBytesTracked, workingSet.residentBytes, "the ledger carries the shared set as one entry")

        // The default budget is clamped by the memory budget.
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: 216 * 4 * 50000), 50000, "a quarter of the geometry budget, in 216-byte records")
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: .max / 2), GaussianRuntimeLimits.workingSetSplats, "never above the platform default")
        GaussianRuntimeLimits.workingSetSplatsOverride = 7
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: 216), 7, "the override wins over both")
    }

    private func fixtureChunkCount(_ table: GaussianChunkTable) -> Int {
        table.chunkCount
    }

    /// The shared set's bytes that do not scale with the budget: visible sets, entity constants
    /// and budget state.
    private func fixedWorkingSetBytes() -> Int {
        maxInFlightCommandBuffers * (MemoryLayout<GaussianVisibleSet>.stride + MemoryLayout<GaussianBudgetState>.stride)
            + MemoryLayout<GaussianBudgetState>.stride
            + totalPerMeshUniformBuffers() * MemoryLayout<GaussianEntityDrawConstants>.stride * Int(gaussianMaxEntitiesPerFrame)
    }

    /// Two million splats, above the old mobile cap, load as 32 MB of packed records (no encoded
    /// buffer, no index buffers) and render under a one-million budget with no overflow, the set
    /// sized to the budget rather than to the asset.
    func testTwoMillionSplatAssetLoadsAndRendersUnderTheBudget() throws {
        let splatCount = 2_000_000
        XCTAssertGreaterThan(GaussianRuntimeLimits.maxSplatsPerEntityMobile, splatCount)
        XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntityMobile, 20_000_000)
        XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntityMac, 40_000_000)
        let url = try GaussianSyntheticAsset.url(splatCount: splatCount)
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertEqual(Int(component.splatCount), splatCount)
        XCTAssertEqual(table.splatsPerChunk, 1024)
        XCTAssertEqual(component.packedSplatData?.length, splatCount * 16)
        XCTAssertNil(component.encodedSplatData)
        XCTAssertEqual(component.estimatedGPUBytes, splatCount * 16 + table.gpuBytes, "no harmonics: 16 bytes per splat plus the chunk table")
        XCTAssertLessThan(component.estimatedGPUBytes, 40 * 1024 * 1024)

        let budget = 1_000_000
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        // From above the slab's centre the camera sees most of it: far more than the budget.
        placeGaussianTestCamera(eye: simd_float3(0, 6, 3), target: .zero)
        _ = renderGaussianSplatLayer()
        let image = renderGaussianSplatLayer()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget, "the set is the budget, not the two million resident splats")
        let set = sharedVisibleSet()
        let state = try budgetState()
        XCTAssertGreaterThan(Int(state.requestedSplats), budget, "sanity — the view asks for more than the budget")
        XCTAssertLessThan(state.scale, 1)
        XCTAssertLessThanOrEqual(Int(set.visibleCount), budget)
        XCTAssertGreaterThan(Int(set.visibleCount), budget / 2, "the budget is used")
        XCTAssertEqual(set.overflowCount, 0)
        XCTAssertLessThanOrEqual(Int(set.visibleCount), Int(state.quotaSplats), "the quotas bound what the fused pass appends; chunks straddling the frustum lose splats to the per-splat test")
        XCTAssertLessThanOrEqual(Int(state.quotaSplats), Int(Float(budget) * gaussianBudgetHeadroom) + fixtureChunkCount(table), "the quota sum fits the budget with the headroom")
        let covered = image.indices.filter { $0 % 4 == 3 && Float(image[$0]) > 0.001 }.count
        XCTAssertGreaterThan(covered, 10000, "the slab is drawn")
    }
}
