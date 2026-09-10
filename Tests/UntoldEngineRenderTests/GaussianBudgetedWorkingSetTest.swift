//
//  GaussianBudgetedWorkingSetTest.swift
//  UntoldEngine
//
//  The budget-sized shared working set and the per-chunk quotas that fit .untoldgs entities to
//  it (GaussianWorkingSetBudget.metal, GaussianChunkPreprocess.metal): under a budget below the
//  visible count the frame compacts exactly the quota sum, the kept records of every chunk are
//  its first quota ranks, two identical frames compact the same set in the same depth order and
//  the overflow counter stays at zero; a fall of the budget scale (a budget step, a turn into a
//  denser view) is taken at once and a rise climbs back exactly as the CPU mirror predicts, the
//  set never overflowing on the way; a frame without splat entities resets the hysteresis; a
//  whole-buffer (.ply) entity beside a chunked one is reserved out of the budget first and the
//  set never drops below its resident total; a capacity change forgets the stale in-flight
//  slots; the last fifth of a truncated chunk fades its opacity by rank within every chunk as
//  the CPU mirror predicts; the memory accounting charges a chunked entity 16 bytes per splat
//  plus harmonics and chunk table, the shared set its budget rather than the resident total
//  (re-published after a ledger clear), and a large synthetic asset (two million splats when
//  UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1, else 300,000) loads and renders under a budget below its
//  request. The suite runs with GaussianDebugOptions.disableScreenWeightedQuotas on — its
//  assertions are the uniform rule's — except where noted; the budget-step and reservation
//  sequences are replayed once with the weighted quotas, asserting only that every frame fits.
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
    private var savedDisableScreenWeightedQuotas = false
    private var savedWorkingSetOverride: Int?

    /// The far camera of GaussianChunkCullTest: the whole 200-splat fixture in view.
    private let farCamera = (eye: simd_float3(0, 3, 7), target: simd_float3.zero)
    /// Its close view of the +x/+y corner: 8 of the 13 chunks.
    private let cornerCamera = (eye: simd_float3(1.0, 1.0, 0.6), target: simd_float3(1.0, 1.0, 0))

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
        // This suite asserts the uniform rule — the same fraction of every chunk, the scale's
        // climb — which is the mode the switch selects; the weighted rule has its own suite
        // (GaussianScreenWeightedQuotaTest).
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
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

    /// The asset indices of the records the chunked `entity` compacted this frame.
    private func chunkedIndices(_ fixture: ChunkedFixture) -> [UInt32] {
        let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        guard let entityIndex = GaussianSharedWorkingSet.shared.entityOrder(slot: slot).firstIndex(of: fixture.entity) else {
            XCTFail("the chunked entity is not in this slot's entity order")
            return []
        }
        return fixture.resolver.indices(of: sharedGaussianRecords().filter { Int($0.entityIndex) == entityIndex })
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

    /// A budget step down is taken at once — the set is already at its new capacity, so a scale
    /// lagging above its target would grant more than the set holds and drop splats by arrival
    /// order — and the climb back is by max(10 % of the scale, 0.05) per frame, exactly as the
    /// CPU mirror predicts, over the number of frames it predicts. No frame on either way
    /// overflows the set.
    func testBudgetStepFallsAtOnceAndClimbsBackOverSeveralFrames() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)

        runFrame()
        XCTAssertEqual(try budgetState().scale, 1, "unlimited: the scale is 1")

        // A quarter of the visible count, without resetting the hysteresis.
        let budget = splatCount / 4
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        let target = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: budget)
        XCTAssertLessThan(target, 0.3)
        runFrame()
        var state = try budgetState()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget, "the set shrank to the budget this frame")
        XCTAssertEqual(state.targetScale, target, accuracy: 1e-6)
        XCTAssertEqual(state.scale, target, accuracy: 1e-6, "the fall is taken at once")
        XCTAssertEqual(state.scale, GaussianChunkCullMath.smoothedScale(target: target, previous: 1), accuracy: 1e-6, "as the CPU mirror predicts")
        try assertFrameFits()
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), Int(state.quotaSplats), "the far camera sees every splat, so the frame compacts exactly the quota sum")
        for _ in 0 ..< 3 {
            runFrame()
            XCTAssertEqual(try budgetState().scale, target, accuracy: 1e-6, "and stays there")
            try assertFrameFits()
        }

        // Back to unlimited: the scale climbs by at most max(10 % of itself, 0.05) per frame,
        // each step the mirror's, reaching 1 in exactly the frames the mirror predicts.
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        let predictedFrames = GaussianChunkCullMath.framesToReach(target: 1, from: target)
        XCTAssertGreaterThanOrEqual(predictedFrames, 5, "a climb from a quarter takes several frames")
        var previous = target
        var climbed: [Float] = [previous]
        for _ in 0 ..< 60 {
            runFrame()
            state = try budgetState()
            XCTAssertEqual(state.targetScale, 1)
            XCTAssertEqual(state.scale, GaussianChunkCullMath.smoothedScale(target: 1, previous: previous), accuracy: 1e-5, "the CPU mirror predicts each step: \(climbed)")
            XCTAssertLessThanOrEqual(state.scale, previous + max(previous * gaussianBudgetMaxStepFraction, gaussianBudgetMinStep) + 1e-5, "the scale rises by at most one step per frame")
            XCTAssertGreaterThan(state.scale, previous, "and rises every frame until it arrives")
            try assertFrameFits()
            climbed.append(state.scale)
            previous = state.scale
            if state.scale >= 1 { break }
        }
        XCTAssertEqual(previous, 1, "the scale is back at 1: \(climbed)")
        XCTAssertEqual(climbed.count - 1, predictedFrames, "the climb takes the frames the mirror predicts: \(climbed)")
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)

        // A turn from a sparse view into a dense one at a fixed budget: the request outgrows the
        // budget and the scale falls at once, so the first dense frame already fits.
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        runFrame()
        let sparseRequest = try Int(budgetState().requestedSplats)
        XCTAssertGreaterThan(sparseRequest, 0)
        XCTAssertLessThan(sparseRequest, splatCount, "sanity — the corner view culls chunks")
        let fixedBudget = Int(ceil(Float(sparseRequest) / gaussianBudgetHeadroom)) + 1
        XCTAssertLessThan(fixedBudget, splatCount)
        GaussianRuntimeLimits.workingSetSplatsOverride = fixedBudget
        runFrame()
        XCTAssertEqual(try budgetState().scale, 1, "the sparse view fits the budget")
        try assertFrameFits()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        runFrame()
        state = try budgetState()
        let denseTarget = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: fixedBudget)
        XCTAssertEqual(Int(state.requestedSplats), splatCount)
        XCTAssertLessThan(denseTarget, 1)
        XCTAssertEqual(state.targetScale, denseTarget, accuracy: 1e-6)
        XCTAssertEqual(state.scale, denseTarget, accuracy: 1e-6, "the first dense frame takes the target")
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, fixedBudget)
        try assertFrameFits()

        // The debug switch: every chunk keeps its whole count and the set holds the resident total.
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        runFrame()
        XCTAssertEqual(try budgetState().scale, 1)
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, splatCount)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)
    }

    /// A frame with no splat entity — the scene was unloaded — makes the next frame with some
    /// take its target directly: the scale the previous scene settled at does not fade the new
    /// one in. The reset lasts one frame.
    func testAFrameWithoutSplatEntitiesResetsTheHysteresis() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)
        let budget = splatCount / 4
        let low = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: budget)
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        runFrame()
        runFrame()
        XCTAssertEqual(try budgetState().scale, low, accuracy: 1e-6, "settled at the low scale")

        destroyEntity(entityId: fixture.entity)
        runFrame()

        let reloaded = try loadFixture()
        XCTAssertEqual(Int(reloaded.component.splatCount), splatCount)
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        runFrame()
        XCTAssertEqual(try budgetState().scale, 1, "the new scene takes its target instead of climbing from \(low)")
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)

        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        runFrame()
        XCTAssertEqual(try budgetState().scale, low, accuracy: 1e-6)
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        runFrame()
        let climbing = try budgetState().scale
        XCTAssertEqual(climbing, GaussianChunkCullMath.smoothedScale(target: 1, previous: low), accuracy: 1e-5, "the reset lasted one frame: the climb is smoothed again")
        XCTAssertLessThan(climbing, 1)
    }

    // MARK: - (e) Whole-buffer entities beside chunked ones

    /// A `.ply` is not budgeted: its visible count is reserved out of the budget before the
    /// chunked entities are fitted to the rest, and the set is never smaller than the
    /// whole-buffer entities' resident total, so neither entity ever loses a splat by arrival
    /// order and the chunked entity still keeps its first quota ranks.
    func testWholeBufferEntitiesAreReservedBeforeTheChunkedOnesAreFitted() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)
        let ply = createEntity()
        setEntityGaussian(entityId: ply, filename: "test_gaussians", withExtension: "ply")
        let plyComponent = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: ply))
        XCTAssertFalse(plyComponent.isChunked)
        XCTAssertEqual(Int(plyComponent.splatCount), splatCount)
        translateTo(entityId: ply, position: simd_float3(0.5, 0, 0))

        // Unlimited: both entities compact every splat.
        runFrame()
        var state = try budgetState()
        let plySlot = min(renderInfo.currentInFlightFrameSlot, plyComponent.gaussianVisibleCount.count - 1)
        let plyVisible = try Int(XCTUnwrap(plyComponent.gaussianVisibleCount[plySlot]).contents().load(as: GaussianVisibleSet.self).visibleCount)
        XCTAssertEqual(plyVisible, splatCount, "sanity — the far camera sees the whole .ply")
        XCTAssertEqual(Int(state.reservedSplats), plyVisible, "the .ply's visible count is reserved")
        XCTAssertEqual(Int(state.requestedSplats), splatCount, "the chunked entity asks for its whole count")
        XCTAssertEqual(state.scale, 1)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), 2 * splatCount)
        try assertFrameFits()

        // A budget below the two together but above the .ply: the .ply keeps everything, the
        // chunked entity is fitted to what is left.
        let budget = splatCount + splatCount / 4
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        state = try budgetState()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget)
        XCTAssertEqual(Int(state.reservedSplats), plyVisible)
        let expectedScale = GaussianChunkCullMath.targetScale(requestedSplats: splatCount, budget: budget, reservedSplats: plyVisible)
        XCTAssertGreaterThan(expectedScale, 0)
        XCTAssertLessThan(expectedScale, 0.5)
        XCTAssertEqual(state.targetScale, expectedScale, accuracy: 1e-6, "the chunked request is fitted to the budget less the reservation")
        XCTAssertEqual(state.scale, expectedScale, accuracy: 1e-6)
        let chunks = visibleChunkEntries(fixture.table)
        var expectedQuotaTotal = 0
        for entry in chunks.entries {
            XCTAssertEqual(entry.quota, GaussianChunkCullMath.quota(scale: state.scale, splatCount: entry.splatCount))
            expectedQuotaTotal += Int(entry.quota)
        }
        XCTAssertGreaterThan(expectedQuotaTotal, 0)
        XCTAssertEqual(Int(state.quotaSplats), expectedQuotaTotal)
        XCTAssertLessThanOrEqual(plyVisible + expectedQuotaTotal, Int(Float(budget) * gaussianBudgetHeadroom))
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), plyVisible + expectedQuotaTotal, "the .ply's splats and the quotas, nothing dropped")
        try assertFrameFits()
        let kept = Set(chunkedIndices(fixture))
        XCTAssertEqual(kept.count, expectedQuotaTotal)
        for (chunkIndex, chunk) in fixture.table.index.chunks.enumerated() {
            let entry = try XCTUnwrap(chunks.entries.first { Int($0.chunkIndex) == chunkIndex })
            let firstSplat = fixture.table.index.chunks[..<chunkIndex].reduce(0) { $0 + Int($1.splatCount) }
            let expectedRanks = Set((firstSplat ..< firstSplat + Int(entry.quota)).map { UInt32($0) })
            let chunkSplats = Set((firstSplat ..< firstSplat + Int(chunk.splatCount)).map { UInt32($0) })
            XCTAssertEqual(kept.intersection(chunkSplats), expectedRanks, "chunk \(chunkIndex) keeps exactly its first \(entry.quota) ranks beside the .ply")
        }
        runFrame()
        XCTAssertEqual(Set(chunkedIndices(fixture)), kept, "and the same ranks the next frame")
        try assertFrameFits()

        // A budget below the .ply alone: the set stays at the .ply's resident total, the .ply
        // keeps everything and the chunked entity gets nothing.
        GaussianRuntimeLimits.workingSetSplatsOverride = splatCount / 2
        runFrame()
        state = try budgetState()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, splatCount, "the set never drops below the whole-buffer resident total")
        XCTAssertEqual(Int(state.reservedSplats), plyVisible)
        XCTAssertEqual(state.targetScale, 0, "nothing is left for the chunked entity")
        XCTAssertEqual(state.scale, 0)
        XCTAssertEqual(state.quotaSplats, 0)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), plyVisible)
        try assertFrameFits()

        // A .ply alone above the budget: no overflow, as before the budget existed.
        destroyEntity(entityId: fixture.entity)
        GaussianRuntimeLimits.workingSetSplatsOverride = splatCount / 4
        runFrame()
        state = try budgetState()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, splatCount)
        XCTAssertEqual(state.requestedSplats, 0)
        XCTAssertEqual(state.scale, 1, "with no chunked request the scale takes its target: nothing is drawn under it")
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), plyVisible)
        XCTAssertEqual(sharedVisibleSet().overflowCount, 0)
    }

    /// A chunked entity and a `.ply` in one frame render like the same two entities with the
    /// chunked one swapped onto the whole-buffer path (its legacy twin): the entity index each
    /// path stamps beside the other resolves to the right matrices, records of both entities
    /// reach the set and the shared count is the sum of the two.
    func testChunkedAndWholeBufferEntitiesRenderLikeTwoWholeBufferEntities() throws {
        let fixture = try loadFixture()
        let cameraEntity = placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let ply = createEntity()
        setEntityGaussian(entityId: ply, filename: "test_gaussians", withExtension: "ply")
        translateTo(entityId: ply, position: simd_float3(0.8, 0.2, 0))

        _ = renderGaussianSplatLayer()
        let mixed = renderGaussianSplatLayer()
        let mixedVisible = sharedGaussianVisibleCount()
        XCTAssertEqual(mixedVisible, 2 * Int(fixture.component.splatCount), "the far camera sees both whole assets")
        XCTAssertEqual(Set(sharedGaussianRecords().map(\.entityIndex)), [0, 1], "records of both entities, each stamped with its own index")

        let (twoWholeBuffer, twoWholeBufferVisible) = fixture.legacy.withLegacyBuffers(fixture.component) {
            _ = renderGaussianSplatLayer()
            let image = renderGaussianSplatLayer()
            return (image, sharedGaussianVisibleCount())
        }
        XCTAssertEqual(twoWholeBufferVisible, mixedVisible)

        let quality = compareGaussianSplatLayers(mixed, twoWholeBuffer)
        XCTAssertGreaterThan(quality.covered, 500, "sanity — the assets cover part of the frame")
        XCTAssertLessThanOrEqual(quality.differingPixels, 50, "\(quality.differingPixels) of \(quality.covered) covered pixels differ by more than one 8-bit step between the mixed frame and the two whole-buffer entities")
        XCTAssertGreaterThan(quality.psnr, 55, "\(quality.psnr) dB over covered pixels")
        destroyEntity(entityId: cameraEntity)
    }

    // MARK: - The same sequences under the weighted quotas

    /// The budget-step sequence and the reservation sequence again with the screen-weighted
    /// quotas (the switch off): the per-chunk quotas differ, but every frame still fits — no
    /// overflow, the grant within the capacity and, when truncated, within the headroom — and
    /// the reservation still comes first.
    func testTheBudgetSequencesFitUnderTheWeightedQuotasToo() throws {
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        try replayBudgetStepSequence()
        destroyAllEntities()
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        try replayReservationSequence()
    }

    /// The frames of testBudgetStepFallsAtOnceAndClimbsBackOverSeveralFrames, asserting only
    /// the fit and what the two rules share.
    private func replayBudgetStepSequence() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)
        runFrame()
        try assertFrameFits()
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)

        GaussianRuntimeLimits.workingSetSplatsOverride = splatCount / 4
        for _ in 0 ..< 4 {
            runFrame()
            try assertFrameFits()
            XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, splatCount / 4)
            XCTAssertLessThan(try budgetState().targetScale, 1)
        }
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        var previousQuota = 0
        var frames = 0
        for _ in 0 ..< 60 {
            runFrame()
            try assertFrameFits()
            let state = try budgetState()
            XCTAssertGreaterThanOrEqual(Int(state.quotaSplats), previousQuota, "the grant never falls while the budget lifts")
            previousQuota = Int(state.quotaSplats)
            frames += 1
            if state.densityCap.isInfinite { break }
        }
        XCTAssertLessThanOrEqual(frames, 20, "the climb to whole takes at most twenty frames")
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)

        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        runFrame()
        let sparseRequest = try Int(budgetState().requestedSplats)
        let fixedBudget = Int(ceil(Float(sparseRequest) / gaussianBudgetHeadroom)) + 1
        GaussianRuntimeLimits.workingSetSplatsOverride = fixedBudget
        runFrame()
        try assertFrameFits()
        XCTAssertTrue(try budgetState().densityCap.isInfinite, "the sparse view fits the budget")
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        runFrame()
        try assertFrameFits()
        XCTAssertLessThan(try budgetState().targetScale, 1, "the dense view is truncated")
        XCTAssertFalse(try budgetState().densityCap.isInfinite, "and the cap falls at once")

        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        runFrame()
        XCTAssertTrue(try budgetState().densityCap.isInfinite)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), splatCount)
        GaussianDebugOptions.shared.disableWorkingSetBudget = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
    }

    /// The frames of testWholeBufferEntitiesAreReservedBeforeTheChunkedOnesAreFitted, asserting
    /// the fit and the reservation.
    private func replayReservationSequence() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let splatCount = Int(fixture.component.splatCount)
        let ply = createEntity()
        setEntityGaussian(entityId: ply, filename: "test_gaussians", withExtension: "ply")
        let plyComponent = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: ply))
        translateTo(entityId: ply, position: simd_float3(0.5, 0, 0))
        runFrame()
        try assertFrameFits()
        let plySlot = min(renderInfo.currentInFlightFrameSlot, plyComponent.gaussianVisibleCount.count - 1)
        let plyVisible = try Int(XCTUnwrap(plyComponent.gaussianVisibleCount[plySlot]).contents().load(as: GaussianVisibleSet.self).visibleCount)
        XCTAssertEqual(try Int(budgetState().reservedSplats), plyVisible)
        XCTAssertEqual(Int(sharedVisibleSet().visibleCount), 2 * splatCount)

        // Three frames per budget; a budget above the .ply that follows one below it runs on
        // until the chunked entity has a quota again — the cap climbs from zero by the step, as
        // the scale does, so the entity fades back in over a few frames rather than popping.
        for budget in [splatCount + splatCount / 4, splatCount / 2, splatCount + splatCount / 2, splatCount / 4] {
            GaussianRuntimeLimits.workingSetSplatsOverride = budget
            var previousQuota = 0
            var previousCap: Float = 0
            for frame in 0 ..< 20 {
                runFrame()
                try assertFrameFits()
                let state = try budgetState()
                XCTAssertEqual(Int(state.reservedSplats), plyVisible, "the .ply is reserved first")
                XCTAssertGreaterThanOrEqual(Int(sharedVisibleSet().visibleCount), plyVisible, "the .ply always fits")
                if budget <= splatCount {
                    XCTAssertEqual(state.quotaSplats, 0, "nothing is left for the chunked entity below the .ply")
                    XCTAssertEqual(state.densityCap, 0)
                    if frame >= 2 { break }
                } else {
                    XCTAssertGreaterThanOrEqual(Int(state.quotaSplats), previousQuota, "budget \(budget) frame \(frame): the grant never falls while the budget holds")
                    XCTAssertGreaterThanOrEqual(state.densityCap, previousCap, "budget \(budget) frame \(frame): the cap climbs")
                    previousQuota = Int(state.quotaSplats)
                    previousCap = state.densityCap
                    if frame >= 2, state.quotaSplats > 0 { break }
                }
            }
            if budget > splatCount {
                XCTAssertGreaterThan(previousQuota, 0, "budget \(budget): the chunked entity gets part of what the .ply leaves within the climb's frames")
            }
        }
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
    }

    // MARK: - A capacity change forgets the stale slots

    /// The other in-flight slots' records and visible sets were written for the old buffers; a
    /// frame that reuses one without re-running the preprocess (the asset-loading gate) must not
    /// draw the old count over the new buffers, so the draw's entity order is cleared for every
    /// slot and the frame that changed the capacity re-sets only its own.
    func testACapacityChangeForgetsEveryInFlightSlotsEntityOrder() throws {
        let fixture = try loadFixture()
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let workingSet = GaussianSharedWorkingSet.shared
        // A budget above the resident total: the set holds the resident total (shrunk to it if
        // an earlier test left a larger one).
        GaussianRuntimeLimits.workingSetSplatsOverride = 1000
        runFrame()
        XCTAssertEqual(workingSet.capacity, Int(fixture.component.splatCount))

        for slot in 0 ..< maxInFlightCommandBuffers {
            workingSet.setEntityOrder([fixture.entity], slot: slot)
        }
        GaussianRuntimeLimits.workingSetSplatsOverride = 120
        runFrame()
        XCTAssertEqual(workingSet.capacity, 120, "the set shrank")
        let current = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
        for slot in 0 ..< maxInFlightCommandBuffers where slot != current {
            XCTAssertTrue(workingSet.entityOrder(slot: slot).isEmpty, "slot \(slot) was written for the old capacity and is not drawn")
        }
        XCTAssertEqual(workingSet.entityOrder(slot: current), [fixture.entity], "the frame that shrank the set re-set its own slot")

        // An unchanged capacity keeps every slot's order.
        for slot in 0 ..< maxInFlightCommandBuffers {
            workingSet.setEntityOrder([fixture.entity], slot: slot)
        }
        runFrame()
        for slot in 0 ..< maxInFlightCommandBuffers {
            XCTAssertEqual(workingSet.entityOrder(slot: slot), [fixture.entity], "slot \(slot) keeps its order while the capacity holds")
        }

        // Growing forgets them too.
        GaussianRuntimeLimits.workingSetSplatsOverride = 1000
        runFrame()
        XCTAssertEqual(workingSet.capacity, Int(fixture.component.splatCount))
        for slot in 0 ..< maxInFlightCommandBuffers where slot != min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1) {
            XCTAssertTrue(workingSet.entityOrder(slot: slot).isEmpty)
        }
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

    /// The band follows the rank within each chunk, not the splat index: with four chunks
    /// (64, 64, 64 and 8 splats) under a budget of 100 every 64-splat chunk is granted 31 and
    /// fades ranks 24 ..< 31, and the chunks whose first splat is 64 and 128 fade exactly as
    /// the first one does.
    func testTheOpacityBandFollowsTheRankWithinEveryChunk() throws {
        let fixture = try loadFixture(chunkSplats: 6)
        XCTAssertEqual(fixture.table.chunkCount, 4)
        XCTAssertEqual(fixture.table.index.chunks.map(\.splatCount), [64, 64, 64, 8])
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        fixture.component.opacityScale = 1

        let budget = 100
        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        runFrame()
        let scale = try budgetState().scale
        XCTAssertEqual(scale, GaussianChunkCullMath.targetScale(requestedSplats: 200, budget: budget), accuracy: 1e-6)
        let chunks = visibleChunkEntries(fixture.table)
        XCTAssertEqual(chunks.entries.count, 4)

        let records = sharedGaussianRecords()
        let indices = fixture.resolver.indices(of: records)
        var factorByIndex: [UInt32: Float] = [:]
        for (record, index) in zip(records, indices) {
            let baseOpacity = Float(fixture.cpu.encodedSplats[Int(index)].colorAndOpacity.w)
            guard baseOpacity > 0 else { continue }
            factorByIndex[index] = record.conicAndOpacity.w / baseOpacity
        }

        var firstSplat: UInt32 = 0
        for (chunkIndex, chunk) in fixture.table.index.chunks.enumerated() {
            defer { firstSplat += chunk.splatCount }
            let entry = try XCTUnwrap(chunks.entries.first { Int($0.chunkIndex) == chunkIndex })
            let quota = entry.quota
            XCTAssertEqual(quota, GaussianChunkCullMath.quota(scale: scale, splatCount: chunk.splatCount))
            if chunk.splatCount == 64 {
                XCTAssertEqual(quota, 31)
            }
            let bandStart = UInt32(gaussianOpacityBandFraction * Float(quota))
            let keptRanks = Set(factorByIndex.keys.filter { $0 >= firstSplat && $0 < firstSplat + chunk.splatCount }.map { $0 - firstSplat })
            XCTAssertEqual(keptRanks, Set(0 ..< quota), "chunk \(chunkIndex) (first splat \(firstSplat)) keeps its first \(quota) ranks")
            for rank in 0 ..< quota {
                let factor = try XCTUnwrap(factorByIndex[firstSplat + rank])
                let expected = GaussianChunkCullMath.opacityBandFactor(rank: rank, quota: quota, splatCount: chunk.splatCount)
                XCTAssertEqual(factor, expected, accuracy: 2e-3, "chunk \(chunkIndex) rank \(rank) (splat \(firstSplat + rank)): the band is by rank within the chunk")
                if rank < bandStart {
                    XCTAssertEqual(factor, 1, accuracy: 2e-3, "chunk \(chunkIndex) rank \(rank) is before the band")
                } else if quota < chunk.splatCount, rank > bandStart {
                    XCTAssertLessThan(factor, 1 - 1e-3, "chunk \(chunkIndex) rank \(rank) is inside the band")
                }
            }
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

        // Below the budget the set holds the resident total, not the budget (shrunk first, so a
        // larger set an earlier test left behind does not stand in).
        GaussianRuntimeLimits.workingSetSplatsOverride = 1
        runFrame()
        XCTAssertEqual(workingSet.capacity, 1)
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

        // A scene unload clears the ledger; the set is not scene-owned and lives on, so the next
        // frame re-publishes its bytes.
        MemoryBudgetManager.shared.clear()
        XCTAssertEqual(MemoryBudgetManager.shared.gaussianWorkingSetBytesTracked, 0)
        runFrame()
        XCTAssertEqual(workingSet.capacity, 120, "the capacity did not change")
        XCTAssertEqual(MemoryBudgetManager.shared.gaussianWorkingSetBytesTracked, workingSet.residentBytes, "the ledger carries the set again although no buffer was reallocated")

        // The default budget is clamped by the memory budget.
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: 216 * 4 * 50000), 50000, "a quarter of the geometry budget, in 216-byte records")
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: .max / 2), GaussianRuntimeLimits.workingSetSplats, "never above the platform default")
        GaussianRuntimeLimits.workingSetSplatsOverride = 7
        XCTAssertEqual(GaussianSharedWorkingSet.budgetSplats(geometryBudgetBytes: 216), 7, "the override wins over both")
    }

    /// The shared set's bytes that do not scale with the budget: visible sets, entity constants,
    /// budget state and density histogram (each with its per-slot readbacks).
    private func fixedWorkingSetBytes() -> Int {
        maxInFlightCommandBuffers * (MemoryLayout<GaussianVisibleSet>.stride + MemoryLayout<GaussianBudgetState>.stride + MemoryLayout<GaussianBudgetDensityHistogram>.stride)
            + MemoryLayout<GaussianBudgetState>.stride
            + MemoryLayout<GaussianBudgetDensityHistogram>.stride
            + totalPerMeshUniformBuffers() * MemoryLayout<GaussianEntityDrawConstants>.stride * Int(gaussianMaxEntitiesPerFrame)
    }

    /// A large synthetic slab — two million splats, above the old mobile cap, when
    /// UNTOLD_PERF_GAUSSIAN_CHUNK_CULL=1 (a bake of ten seconds or more, shared with the
    /// benchmark), else 300,000 — loads as 16 bytes per splat of packed records (no encoded
    /// buffer, no index buffers) and renders, with the weighted quotas, under a budget below its
    /// request with no overflow, the set sized to the budget rather than to the asset and the
    /// quota sum within the headroom exactly. A partial view then checks how much of the grant
    /// the quotas fill when chunks straddle the frustum — the clipped area charges an edge chunk
    /// for its on-screen part only, so what the per-splat test still drops is the off-screen
    /// share of its kept ranks (the importance order is not spatial) — and that the weighted
    /// quotas put at least as many splats into the set as the uniform rule does, and at least
    /// the share of the request the view keeps unlimited.
    func testLargeSyntheticAssetLoadsAndRendersUnderTheBudget() throws {
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        let full = ProcessInfo.processInfo.environment["UNTOLD_PERF_GAUSSIAN_CHUNK_CULL"] == "1"
        let splatCount = full ? 2_000_000 : 300_000
        let budget = full ? 1_000_000 : 100_000
        XCTAssertGreaterThan(GaussianRuntimeLimits.maxSplatsPerEntityMobile, 2_000_000)
        XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntityMobile, 20_000_000)
        XCTAssertEqual(GaussianRuntimeLimits.maxSplatsPerEntityMac, 40_000_000)
        XCTAssertEqual(GaussianRuntimeLimits.maxWholeBufferSplatsPerEntityMobile, 5_242_880, "the whole-buffer path keeps the old cap")
        XCTAssertEqual(GaussianRuntimeLimits.maxWholeBufferSplatsPerEntityMac, 16_777_216)
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

        GaussianRuntimeLimits.workingSetSplatsOverride = budget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        // From above the slab's centre the camera sees most of it: far more than the budget.
        let cameraEntity = placeGaussianTestCamera(eye: simd_float3(0, 6, 3), target: .zero)
        _ = renderGaussianSplatLayer()
        let image = renderGaussianSplatLayer()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, budget, "the set is the budget, not the resident splats")
        let set = sharedVisibleSet()
        let state = try budgetState()
        XCTAssertGreaterThan(Int(state.requestedSplats), budget, "sanity — the view asks for more than the budget")
        XCTAssertLessThan(state.scale, 1)
        XCTAssertEqual(state.scale, state.targetScale, "settled: a fall is taken at once")
        let density = try densityReadback()
        XCTAssertEqual(state.densityCap, density.targetDensity, "the cap too")
        XCTAssertFalse(state.densityCap.isInfinite)
        XCTAssertEqual(Int(density.grant), Int(gaussianBudgetHeadroom * Float(budget)), "the grant is the room")
        XCTAssertGreaterThanOrEqual(Int(state.quotaSplats), Int(0.9 * Double(density.grant)) - Int(density.visibleChunks), "the weighted quotas fill the grant to within the straddling tier and a splat per chunk")
        XCTAssertLessThanOrEqual(Int(set.visibleCount), budget)
        XCTAssertGreaterThan(Int(set.visibleCount), budget / 2, "the budget is used")
        XCTAssertEqual(set.overflowCount, 0)
        XCTAssertLessThanOrEqual(Int(set.visibleCount), Int(state.quotaSplats), "the quotas bound what the fused pass appends; chunks straddling the frustum lose splats to the per-splat test")
        XCTAssertLessThanOrEqual(Int(state.quotaSplats), Int(Float(budget) * gaussianBudgetHeadroom), "floor quotas sum to at most the headroom's share of the budget, with no slack for \(table.chunkCount) chunks")
        let covered = image.indices.filter { $0 % 4 == 3 && Float(image[$0]) > 0.001 }.count
        XCTAssertGreaterThan(covered, 10000, "the slab is drawn")

        // A partial view, the benchmark's camera: the budget at a quarter of what the view
        // keeps unlimited (the override at the resident total, so the default budget's memory
        // clamp does not stand in), no overflow, and the fill the by-count quotas reach.
        destroyEntity(entityId: cameraEntity)
        GaussianRuntimeLimits.workingSetSplatsOverride = splatCount
        let view = placeGaussianCameraSeeing(target: 0.3, index: table.index)
        XCTAssertGreaterThan(view.fraction, 0.15)
        XCTAssertLessThan(view.fraction, 0.5)
        // The scale the first part settled at would climb back over a dozen frames; start afresh.
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = renderGaussianSplatLayer()
        _ = renderGaussianSplatLayer()
        let partialRequest = try Int(budgetState().requestedSplats)
        let unlimitedVisible = sharedGaussianVisibleCount()
        XCTAssertEqual(try budgetState().scale, 1, "the partial view fits the resident total")
        XCTAssertGreaterThan(partialRequest, 0)
        XCTAssertLessThan(partialRequest, splatCount, "sanity — the partial view culls chunks")
        XCTAssertGreaterThan(unlimitedVisible, splatCount / 100, "sanity — the view keeps part of the slab")
        let quarter = max(1, unlimitedVisible / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = quarter
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = renderGaussianSplatLayer()
        _ = renderGaussianSplatLayer()
        let partialSet = sharedVisibleSet()
        let partialState = try budgetState()
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, quarter)
        XCTAssertEqual(partialSet.overflowCount, 0)
        XCTAssertLessThanOrEqual(Int(partialSet.visibleCount), Int(partialState.quotaSplats))
        XCTAssertLessThanOrEqual(Int(partialState.quotaSplats), Int(Float(quarter) * gaussianBudgetHeadroom))
        XCTAssertGreaterThan(Int(partialSet.visibleCount), 0)
        let partialDensity = try densityReadback()
        XCTAssertGreaterThanOrEqual(Int(partialState.quotaSplats), Int(0.9 * Double(partialDensity.grant)) - Int(partialDensity.visibleChunks), "the quotas fill the grant")
        let quotaFill = Double(partialState.quotaSplats) / Double(max(1, partialDensity.grant))
        let fill = Double(partialSet.visibleCount) / Double(quarter)
        XCTAssertGreaterThanOrEqual(fill, Double(unlimitedVisible) / Double(partialRequest), "the weighted quotas reach the set at least as well as the view's unlimited share of its request")

        // The same frame under the uniform rule: the weighting spends the grant on the chunks
        // that are on screen, so more of it survives the per-splat test.
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        _ = renderGaussianSplatLayer()
        _ = renderGaussianSplatLayer()
        let uniformSet = sharedVisibleSet()
        let uniformState = try budgetState()
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        XCTAssertEqual(uniformSet.overflowCount, 0)
        XCTAssertLessThanOrEqual(Int(uniformState.quotaSplats), Int(Float(quarter) * gaussianBudgetHeadroom))
        XCTAssertGreaterThanOrEqual(partialSet.visibleCount, uniformSet.visibleCount, "the weighted quotas put at least as many splats into the set as the uniform rule")
        print(String(format: "[GaussianBudgetedWorkingSetTest] %d splats, partial view sees %.1f %% by chunk box: request %u, budget %d, grant %u, quota %u (fill %.1f %% of the grant), compacted %u — fill %.1f %% of the budget (uniform rule: quota %u, compacted %u, fill %.1f %%), density=%.4g over %u chunks",
                     splatCount, view.fraction * 100, partialState.requestedSplats, quarter, partialDensity.grant, partialState.quotaSplats, quotaFill * 100, partialSet.visibleCount, fill * 100, uniformState.quotaSplats, uniformSet.visibleCount, Double(uniformSet.visibleCount) / Double(quarter) * 100, Double(partialState.densityCap), partialDensity.visibleChunks))
    }
}
