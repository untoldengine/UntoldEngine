//
//  GaussianPagingTest.swift
//  UntoldEngine
//
//  Disk paging of .untoldgs chunks (GaussianPageManager, GaussianPagingPolicy, the paged paths
//  of gaussianChunkCull and gaussianChunkDecodePreprocess): below the threshold nothing
//  changes; a fully resident paged frame is the legacy twin's; non-resident chunks are not
//  listed and ask nothing; a partially resident chunk lists its resident ranks and draws like
//  a truncated one; the demand words match the CPU mirror, in stereo the larger eye's; the
//  reads go out in priority order; a retired slot is not reused for three ticks, by hand and
//  over full frames; eviction has hysteresis and a hold-off; the fade-in is frame-counted;
//  the per-tick caps hold; a failed read backs off and faults the chunk; a corrupt chunk is
//  dropped; a changed file faults the asset and a reopen restores it; freezing holds the set
//  and the image; the ledger carries the pool; an unload with reads in flight drops them; a
//  paged tier waits for warmth; disableChunkCull lists only resident chunks; pressure evicts to
//  a soft target; residentSplatCount sizes the working set; the demand-only cull appends
//  nothing; the layouts are pinned; disablePaging loads whole; an unload with landed reads
//  frees the pager; waiting reads hold no thread; a tier the selection leaves stops warming;
//  and a 300 k asset pages within a 1 MiB pool over 120 real frames from the file itself (4 M
//  and 20 M against a 64 MiB budget on opt-in); with its per-chunk coarse levels it stops
//  wanting fine tiers from afar once they have landed.
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
final class GaussianPagingTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var fixtures: [EntityID] = []
    private var savedDisableHZBOcclusionCull = false
    private var savedDisableChunkCull = false
    private var savedDisableWorkingSetBudget = false
    private var savedDisableScreenWeightedQuotas = false
    private var savedDisablePaging = false
    private var savedFreezePaging = false
    private var savedDisablePageFade = false
    private var savedResidencyDebugTint = false
    private var savedWorkingSetOverride: Int?
    private var savedLODInterval = 1
    private var savedOverdrawBudget: Float = 12

    /// The 200-splat fixture's cameras (GaussianChunkCullTest): far sees 13/13 chunks, corner
    /// 8/13, side 12/13, away none.
    private let farCamera = (eye: simd_float3(0, 3, 7), target: simd_float3.zero)
    private let cornerCamera = (eye: simd_float3(1.0, 1.0, 0.6), target: simd_float3(1.0, 1.0, 0))
    private let sideCamera = (eye: simd_float3(-1.0, 0.2, 1.0), target: simd_float3(-1.0, 0.2, 0))
    private let awayCamera = (eye: simd_float3(0, 3, 7), target: simd_float3(0, 3, 14))
    private let slabCamera = (eye: simd_float3(0, 6, 3), target: simd_float3.zero)

    override func setUp() async throws {
        try await super.setUp()
        let options = GaussianDebugOptions.shared
        savedDisableHZBOcclusionCull = options.disableHZBOcclusionCull
        savedDisableChunkCull = options.disableChunkCull
        savedDisableWorkingSetBudget = options.disableWorkingSetBudget
        savedDisableScreenWeightedQuotas = options.disableScreenWeightedQuotas
        savedDisablePaging = options.disablePaging
        savedFreezePaging = options.freezePaging
        savedDisablePageFade = options.disablePageFade
        savedResidencyDebugTint = options.residencyDebugTint
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        savedLODInterval = LODConfig.shared.lodUpdateFrameInterval
        savedOverdrawBudget = LODConfig.shared.gaussianOverdrawBudget
        options.disableHZBOcclusionCull = true
        options.disableChunkCull = false
        options.disableWorkingSetBudget = false
        options.disableScreenWeightedQuotas = false
        options.disablePaging = false
        options.freezePaging = false
        options.disablePageFade = false
        options.residencyDebugTint = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        GaussianPagingPolicy.resetKnobs()
        GaussianPagingPolicy.pagingThresholdBytesOverride = 0
        GaussianPagingPolicy.minPoolSlots = 4
        GaussianPagingPolicy.fadeFrames = 0
        GaussianPagingPolicy.maxConcurrentReads = 64
        // Count-bounded commits: the tiers a tick maps are a function of the arrivals alone.
        GaussianPagingPolicy.commitBudget = .infinity
        GaussianTestPageSource.resetCreated()
        GaussianTestPageSource.install()
        GaussianLODSystem.shared.reset()
    }

    override func tearDown() async throws {
        for entity in fixtures where scene.exists(entity) {
            removeEntityGaussian(entityId: entity)
        }
        fixtures.removeAll()
        destroyAllEntities()
        for source in GaussianTestPageSource.created {
            source.deliverAll()
            let deadline = Date().addingTimeInterval(2)
            while !source.closed, Date() < deadline {
                usleep(500)
            }
            XCTAssertTrue(source.closed, "the injected source \(source.url.lastPathComponent) is closed with its entity")
        }
        GaussianTestPageSource.resetCreated()
        GaussianPageSourceFactory.override = nil
        GaussianPagingPolicy.resetKnobs()
        let options = GaussianDebugOptions.shared
        options.disableHZBOcclusionCull = savedDisableHZBOcclusionCull
        options.disableChunkCull = savedDisableChunkCull
        options.disableWorkingSetBudget = savedDisableWorkingSetBudget
        options.disableScreenWeightedQuotas = savedDisableScreenWeightedQuotas
        options.disablePaging = savedDisablePaging
        options.freezePaging = savedFreezePaging
        options.disablePageFade = savedDisablePageFade
        options.residencyDebugTint = savedResidencyDebugTint
        GaussianRuntimeLimits.workingSetSplatsOverride = savedWorkingSetOverride
        LODConfig.shared.lodUpdateFrameInterval = savedLODInterval
        LODConfig.shared.gaussianOverdrawBudget = savedOverdrawBudget
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        GaussianLODSystem.shared.reset()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Fixtures

    private struct PagedFixture {
        let url: URL
        let entity: EntityID
        let component: GaussianComponent
        let table: GaussianChunkTable
        let pager: GaussianPageManager
        let source: GaussianTestPageSource
        let index: UntoldGSIndex
        var chunkCount: Int {
            index.chunks.count
        }

        var splatCount: Int {
            Int(index.header.splatCount)
        }
    }

    private func bakeV3(chunkSplats log2: UInt8 = 4) throws -> URL {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianPagingTest-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = log2
        let result = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: output, lodFractions: [1.0], cookOptions: options)
        let url = try XCTUnwrap(result.tiers.first?.url)
        temporaryFiles.append(url)
        return url
    }

    /// Bytes of one pool slot of the asset at `url`.
    private func slotBytes(of url: URL) throws -> Int {
        let header = try UntoldGSFormat.readHeaderV3(from: url)
        return GaussianPagingPolicy.ranksPerPage(splatsPerChunk: header.splatsPerChunk) * (UntoldGSFormat.coreRecordSize + header.shBytesPerSplat)
    }

    /// Loads `url` paged with a pool of `poolSlots` slots and the event log on.
    private func loadPaged(url: URL, poolSlots: Int, configure: (@Sendable (GaussianTestPageSource) -> Void)? = nil) throws -> PagedFixture {
        GaussianPagingPolicy.residencyBudgetBytesOverride = try poolSlots * slotBytes(of: url)
        let entity = createEntity()
        fixtures.append(entity)
        if let configure {
            // The source is created inside the load: the configuration is applied by the
            // factory before the first read.
            GaussianPageSourceFactory.override = { fileURL in
                let source = try GaussianTestPageSource(url: fileURL)
                configure(source)
                GaussianTestPageSource.record(source)
                return source
            }
        }
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        if configure != nil { GaussianTestPageSource.install() }
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        let pager = try XCTUnwrap(component.pager, "the asset pages")
        let source = try XCTUnwrap(GaussianTestPageSource.created.last { $0.url == url })
        pager.eventLogEnabled = true
        XCTAssertEqual(pager.slotCount, poolSlots)
        return PagedFixture(url: url, entity: entity, component: component, table: table, pager: pager, source: source, index: table.index)
    }

    private func loadFixture(poolSlots: Int, configure: (@Sendable (GaussianTestPageSource) -> Void)? = nil) throws -> PagedFixture {
        try loadPaged(url: bakeV3(), poolSlots: poolSlots, configure: configure)
    }

    private func loadSlab(poolSlots: Int, configure: (@Sendable (GaussianTestPageSource) -> Void)? = nil) throws -> PagedFixture {
        try loadPaged(url: GaussianSyntheticAsset.url(splatCount: 300_000), poolSlots: poolSlots, configure: configure)
    }

    /// Waits until every read the pager issued has landed or is blocked in the source (the
    /// condition has to hold over a few polls: a woken read is briefly neither).
    private func settle(_ fixture: PagedFixture, timeout: TimeInterval = 5) {
        settle(pager: fixture.pager, source: fixture.source, timeout: timeout)
    }

    private func settle(pager: GaussianPageManager, source: GaussianTestPageSource, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        var stable = 0
        while Date() < deadline {
            let pending = pager.stats.pendingReads
            if pending == 0 || pending == source.blockedReads {
                stable += 1
                if stable >= 6 { return }
            } else {
                stable = 0
            }
            usleep(300)
        }
        XCTFail("reads did not settle: \(pager.stats.pendingReads) pending, \(source.blockedReads) blocked")
    }

    /// One manual frame: the retire ring emptied (the GPU is idle), the cull and preprocess,
    /// a tick of the source's latency, and the reads settled.
    private func frame(_ fixture: PagedFixture, gpuIdle: Bool = true) {
        if gpuIdle { fixture.pager.noteGPUIdle() }
        runGaussianCullAndPreprocess()
        fixture.source.advance()
        settle(fixture)
    }

    @discardableResult
    private func frames(_ fixture: PagedFixture, max: Int, until condition: () -> Bool) -> Int {
        var count = 0
        while count < max, !condition() {
            frame(fixture)
            count += 1
        }
        return count
    }

    /// One full renderer frame, waited for, the reads settled.
    private func fullFrame(_ fixture: PagedFixture) {
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()
        XCTAssertEqual(renderInfo.lastCommandBuffer?.status, .completed)
        fixture.source.advance()
        settle(fixture)
    }

    private func residentChunks(_ fixture: PagedFixture) -> Set<UInt32> {
        Set((0 ..< fixture.chunkCount).filter { fixture.pager.residentRanks(of: $0) > 0 }.map { UInt32($0) })
    }

    /// The entity's cull constants for the active camera (the frame's, without the HZB).
    private func cullConstants(_ fixture: PagedFixture, paged: UInt32 = 1) throws -> GaussianChunkCullConstants {
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let cameraComponent = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera))
        let world = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: fixture.entity))
        return gaussianChunkCullConstants(
            chunkTable: fixture.table,
            modelMatrix: simd_mul(world.space, fixture.component.splatToEntity),
            viewMatrix: SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace),
            hzbValid: false,
            forceAllVisible: false,
            uniformQuotas: false,
            paged: paged
        )
    }

    /// The chunks the CPU mirror keeps under `constants`, with their areas.
    private func mirrorAreas(_ fixture: PagedFixture, constants: GaussianChunkCullConstants) -> [Int: Float] {
        var areas: [Int: Float] = [:]
        for (chunk, entry) in fixture.index.chunks.enumerated() {
            let area = GaussianPageManager.seedArea(entry: entry, constants: constants)
            if area > 0 { areas[chunk] = area }
        }
        return areas
    }

    private func demandWords(_ fixture: PagedFixture, slot: Int? = nil) -> [UInt32] {
        let table = fixture.table.demandTables[slot ?? gaussianFrameSlot]
        return Array(UnsafeBufferPointer(start: table.contents().bindMemory(to: UInt32.self, capacity: fixture.chunkCount), count: fixture.chunkCount))
    }

    private func residencyEntries(_ fixture: PagedFixture, slot: Int) -> [GaussianChunkResidency] {
        let table = fixture.table.residencyTables[slot]
        return Array(UnsafeBufferPointer(start: table.contents().bindMemory(to: GaussianChunkResidency.self, capacity: fixture.chunkCount), count: fixture.chunkCount))
    }

    /// Every issue of a pool slot comes at least three ticks after its last eviction, and its
    /// generation grows with every issue.
    private func assertSlotReuseInvariant(_ events: [GaussianPagingEvent], file: StaticString = #filePath, line: UInt = #line) {
        var lastEviction: [UInt32: UInt32] = [:]
        var lastIssueGeneration: [UInt32: UInt32] = [:]
        var issues = 0
        for event in events {
            switch event.kind {
            case .evicted:
                lastEviction[event.slot] = event.tick
            case .issued:
                issues += 1
                if let evicted = lastEviction[event.slot] {
                    XCTAssertGreaterThanOrEqual(event.tick, evicted &+ 3, "slot \(event.slot) reissued at tick \(event.tick) after an eviction at \(evicted)", file: file, line: line)
                    XCTAssertGreaterThan(event.generation, lastIssueGeneration[event.slot] ?? 0, "slot \(event.slot): a fresh generation after its eviction", file: file, line: line)
                }
                lastIssueGeneration[event.slot] = event.generation
            default:
                break
            }
        }
        XCTAssertGreaterThan(issues, 0, file: file, line: line)
    }

    /// Runs `body` with the component on the whole-resident chunked path over `loaded`'s
    /// records (no pager), then puts the pool and the pager back.
    private func withWholeResidentBuffers<T>(_ fixture: PagedFixture, loaded: GaussianChunkLoadResult, _ body: () throws -> T) throws -> T {
        let result = try XCTUnwrap(buildGaussianLoadResult(
            packedSplatBuffer: loaded.packedSplatBuffer,
            splatCount: UInt(loaded.splatCount),
            sphericalHarmonicsBuffer: loaded.sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: loaded.sphericalHarmonicsMetadata,
            boundingBox: loaded.boundingBox,
            chunkTable: loaded.chunkTable
        ))
        let component = fixture.component
        let saved = (component.packedSplatData, component.sphericalHarmonicsData, component.chunkTable, component.pager)
        component.packedSplatData = result.packedSplatBuffer
        component.sphericalHarmonicsData = result.sphericalHarmonicsBuffer
        component.chunkTable = result.chunkTable
        component.pager = nil
        defer {
            (component.packedSplatData, component.sphericalHarmonicsData, component.chunkTable, component.pager) = saved
        }
        return try body()
    }

    private func assetBytes(_ fixture: PagedFixture) -> Int {
        GaussianPagingPolicy.assetBytes(splatCount: fixture.splatCount, shBytesPerSplat: fixture.index.header.shBytesPerSplat)
    }

    // MARK: - 1, 25: the threshold and the switch

    func testBelowTheThresholdNothingChanges() throws {
        GaussianPagingPolicy.pagingThresholdBytesOverride = nil
        let url = try bakeV3()
        let entity = createEntity()
        fixtures.append(entity)
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertNil(component.pager, "a 200-splat asset is far below the platform threshold")
        XCTAssertFalse(component.isPaged)
        XCTAssertTrue(table.residencyTables.isEmpty)
        XCTAssertTrue(table.pageTables.isEmpty)
        XCTAssertTrue(table.demandTables.isEmpty)
        XCTAssertEqual(table.pagesPerChunk, 1)
        XCTAssertEqual(component.residentSplatCount, 200)
        XCTAssertEqual(component.estimatedGPUBytes, (component.packedSplatData?.length ?? 0) + (component.sphericalHarmonicsData?.length ?? 0) + table.gpuBytes)
        XCTAssertEqual(component.packedSplatData?.length, 200 * UntoldGSFormat.coreRecordSize)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let depths = sortedDepthWords()
        XCTAssertGreaterThan(depths.count, 100)

        // The same frame with paging switched off outright.
        removeEntityGaussian(entityId: entity)
        GaussianDebugOptions.shared.disablePaging = true
        let second = createEntity()
        fixtures.append(second)
        setEntityGaussian(entityId: second, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: second)?.pager)
        XCTAssertEqual(sortedDepthWords(), depths, "the same sorted depth keys")
    }

    func testDisablePagingLoadsWholeResident() throws {
        GaussianDebugOptions.shared.disablePaging = true
        GaussianPagingPolicy.pagingThresholdBytesOverride = 0
        let url = try bakeV3()
        let entity = createEntity()
        fixtures.append(entity)
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        XCTAssertNil(component.pager)
        XCTAssertEqual(component.packedSplatData?.length, 200 * UntoldGSFormat.coreRecordSize)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0)
    }

    // MARK: - 2: full residency

    func testFullyResidentPagedFrameMatchesTheLegacyTwin() throws {
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        XCTAssertTrue(fixture.component.isPaged)
        XCTAssertGreaterThanOrEqual(fixture.pager.slotCount * fixture.pager.ranksPerPage, fixture.splatCount, "the pool holds the asset")
        fixture.source.deliverAll()
        let used = frames(fixture, max: 10) { fixture.pager.stats.residentChunks == fixture.chunkCount }
        XCTAssertLessThanOrEqual(used, 3, "issued at tick 1, mapped at tick 2")
        XCTAssertEqual(fixture.pager.stats.wholeChunks, fixture.chunkCount)
        XCTAssertEqual(fixture.pager.stats.pendingReads, 0)

        let paged = sortedDepthWords()
        XCTAssertEqual(paged.count, 200, "every splat of the asset is drawn")
        let whole = try GaussianChunkLoader.load(url: fixture.url, allowPaging: false)
        XCTAssertNil(whole.pager)
        // The same kernel over the same records resident whole: bit-identical keys.
        let wholeChunked = try withWholeResidentBuffers(fixture, loaded: whole) { sortedDepthWords() }
        XCTAssertEqual(paged, wholeChunked, "the same sorted depth keys as the whole-resident chunked load")
        let twin = try GaussianLegacyTwin(loaded: whole)
        let legacy = twin.withLegacyBuffers(fixture.component) { sortedDepthWords() }
        XCTAssertEqual(paged.count, legacy.count, "the same set as the whole-buffer twin")

        let pagedImage = renderGaussianSplatLayer()
        let legacyImage = twin.withLegacyBuffers(fixture.component) { renderGaussianSplatLayer() }
        let comparison = compareGaussianSplatLayers(pagedImage, legacyImage)
        XCTAssertGreaterThan(comparison.covered, 1000)
        XCTAssertLessThanOrEqual(comparison.differingPixels, 50)
        XCTAssertGreaterThan(comparison.psnr, 55)
    }

    // MARK: - 3, 4: residency and the list

    func testNonResidentChunksAreNotListedAndAskNothing() throws {
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.holdChunks = Set(0 ..< 13)
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        for _ in 0 ..< 3 {
            frame(fixture)
            let readback = visibleChunkEntries(fixture.table)
            XCTAssertEqual(readback.record.threadgroupCount, 0, "nothing resident: nothing listed")
            XCTAssertEqual(readback.record.instanceCount, 0)
            XCTAssertEqual(try budgetState().requestedSplats, 0)
            XCTAssertEqual(sharedVisibleSet().visibleCount, 0)
        }
        XCTAssertEqual(fixture.pager.stats.pendingReads, 13, "every chunk was asked for at the first tick")
        XCTAssertEqual(fixture.pager.stats.residentChunks, 0)

        let released: Set = [0, 3, 5, 8, 12]
        for chunk in released {
            fixture.source.release(chunk: chunk)
        }
        settle(fixture)
        frame(fixture)
        let resident = residentChunks(fixture)
        XCTAssertEqual(resident, Set(released.map { UInt32($0) }))
        let readback = visibleChunkEntries(fixture.table)
        XCTAssertEqual(Set(readback.entries.map(\.chunkIndex)), resident, "the listed set is the resident set")
        let expectedSplats = released.reduce(UInt32(0)) { $0 + fixture.index.chunks[$1].splatCount }
        XCTAssertEqual(readback.record.instanceCount, expectedSplats)
        XCTAssertEqual(try budgetState().requestedSplats, expectedSplats, "the request is the resident ranks")
        for entry in readback.entries {
            XCTAssertEqual(entry.splatCount, fixture.index.chunks[Int(entry.chunkIndex)].splatCount)
            XCTAssertEqual(entry.quota, entry.splatCount)
        }
    }

    func testPartiallyResidentChunkListsItsResidentRanks() throws {
        // A small budget: the density cap wants at most a couple of hundred ranks of the
        // largest visible chunk, so every request is a head.
        GaussianRuntimeLimits.workingSetSplatsOverride = 1500
        let fixture = try loadSlab(poolSlots: 400)
        XCTAssertEqual(fixture.pager.ranksPerPage, 256)
        XCTAssertEqual(fixture.pager.pagesPerChunk, 4)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frames(fixture, max: 30) { fixture.pager.stats.pendingReads == 0 && fixture.pager.stats.residentChunks > 20 && fixture.pager.stats.issuedThisTick == 0 }
        XCTAssertGreaterThan(fixture.pager.stats.residentChunks, 20)
        for chunk in 0 ..< fixture.chunkCount {
            XCTAssertLessThanOrEqual(fixture.pager.residentRanks(of: chunk), 256, "heads only")
        }
        // Freeze the set and lift the budget: the head is granted whole.
        GaussianDebugOptions.shared.freezePaging = true
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        frame(fixture)
        frame(fixture)
        let readback = visibleChunkEntries(fixture.table)
        XCTAssertGreaterThan(readback.entries.count, 20)
        var residentRanks: [Int: Int] = [:]
        for chunk in 0 ..< fixture.chunkCount {
            residentRanks[chunk] = Int(fixture.pager.residentRanks(of: chunk))
        }
        let constants = try cullConstants(fixture)
        let areas = mirrorAreas(fixture, constants: constants)
        let chunkX = try XCTUnwrap(readback.entries.max { areas[Int($0.chunkIndex)] ?? 0 < areas[Int($1.chunkIndex)] ?? 0 }).chunkIndex
        for entry in readback.entries {
            XCTAssertEqual(entry.splatCount, UInt32(residentRanks[Int(entry.chunkIndex)] ?? 0), "chunk \(entry.chunkIndex) lists its resident ranks")
            XCTAssertEqual(entry.quota, entry.splatCount, "unlimited budget: the resident ranks whole")
        }
        let entryX = try XCTUnwrap(readback.entries.first { $0.chunkIndex == chunkX })
        XCTAssertEqual(entryX.splatCount, 256)
        XCTAssertEqual(entryX.quota, 256)

        // The records of chunk X are its first 256 ranks.
        let cpu = try UntoldGSFormat.read(from: fixture.url)
        let resolver = GaussianSplatIndexResolver(positions: cpu.encodedSplats.map(\.position))
        let firstSplat = fixture.index.chunks[..<Int(chunkX)].reduce(0) { $0 + Int($1.splatCount) }
        let origins = resolver.indices(of: sharedGaussianRecords())
        let ranksOfX = origins.compactMap { origin -> Int? in
            let rank = Int(origin) - firstSplat
            return rank >= 0 && rank < 1024 ? rank : nil
        }
        XCTAssertGreaterThan(ranksOfX.count, 50)
        XCTAssertTrue(ranksOfX.allSatisfy { $0 < 256 }, "only the head is drawn")

        // The image of the partial residency is the partial twin's.
        let whole = try GaussianChunkLoader.load(url: fixture.url, allowPaging: false)
        let twin = try GaussianPartialTwin(loaded: whole, residentRanks: residentRanks)
        let pagedImage = renderGaussianSplatLayer()
        let twinImage = twin.withLegacyBuffers(fixture.component) { renderGaussianSplatLayer() }
        let comparison = compareGaussianSplatLayers(pagedImage, twinImage)
        XCTAssertGreaterThan(comparison.covered, 1000)
        // The twin stores the banded opacities in half precision; over the slab's deep overdraw
        // that rounding moves a few pixels past one 8-bit step.
        XCTAssertLessThanOrEqual(comparison.differingPixels, comparison.covered / 100)
        XCTAssertGreaterThan(comparison.psnr, 55)
    }

    // MARK: - 5, 19, 23: the demand words

    func testDemandWordsMatchTheCPUMirrorArea() throws {
        let fixture = try loadFixture(poolSlots: 13)
        for camera in [farCamera, cornerCamera, sideCamera] {
            placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            frame(fixture)
            let words = demandWords(fixture)
            let areas = try mirrorAreas(fixture, constants: cullConstants(fixture))
            XCTAssertGreaterThan(areas.count, 0)
            for chunk in 0 ..< fixture.chunkCount {
                if let area = areas[chunk] {
                    // The same tolerance as the quota suite's area mirrors: CI's paravirtual Metal
                    // device projects the corners with a different rounding than an Apple GPU, and
                    // a chunk a few pixels wide lands about 2e-3 relative from the CPU mirror.
                    XCTAssertEqual(Float(bitPattern: words[chunk]), area, accuracy: max(1e-5 * area, 1e-6), "chunk \(chunk): the kept chunk's clipped area")
                } else {
                    XCTAssertEqual(words[chunk], 0, "chunk \(chunk): culled, no demand")
                }
            }
        }
    }

    func testStereoDemandTakesTheLargerEye() throws {
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let lookingAt = try viewProjection(entity: fixture.entity, eye: farCamera.eye, target: farCamera.target)
        let lookingAway = try viewProjection(entity: fixture.entity, eye: awayCamera.eye, target: awayCamera.target)
        let constants = try stereoConstants(table: fixture.table, entity: fixture.entity, eye0: lookingAway, eye1: lookingAt)
        var paged = constants
        paged.paged = 1
        let words = try cullByHand(fixture, constants: paged)
        let expected = mirrorAreas(fixture, constants: constants)
        var eye1Only = constants
        eye1Only.viewProjection0 = lookingAt
        eye1Only.viewCount = 1
        let eye1Areas = mirrorAreas(fixture, constants: eye1Only)
        XCTAssertEqual(expected.count, 13, "eye 1 sees everything, eye 0 nothing")
        for chunk in 0 ..< fixture.chunkCount {
            XCTAssertEqual(Float(bitPattern: words[chunk]), expected[chunk] ?? 0, accuracy: 1e-6 * (expected[chunk] ?? 1), "chunk \(chunk): the larger eye's area")
            XCTAssertEqual(expected[chunk], eye1Areas[chunk], "the larger eye is eye 1")
        }
        // Two partial eyes: the larger of the two.
        let corner = try viewProjection(entity: fixture.entity, eye: cornerCamera.eye, target: cornerCamera.target)
        let side = try viewProjection(entity: fixture.entity, eye: sideCamera.eye, target: sideCamera.target)
        var partial = try stereoConstants(table: fixture.table, entity: fixture.entity, eye0: corner, eye1: side)
        partial.paged = 1
        let partialWords = try cullByHand(fixture, constants: partial)
        var cornerOnly = partial
        cornerOnly.viewCount = 1
        var sideOnly = partial
        sideOnly.viewProjection0 = side
        sideOnly.viewCount = 1
        let cornerAreas = mirrorAreas(fixture, constants: cornerOnly)
        let sideAreas = mirrorAreas(fixture, constants: sideOnly)
        for chunk in 0 ..< fixture.chunkCount {
            let larger = max(cornerAreas[chunk] ?? 0, sideAreas[chunk] ?? 0)
            XCTAssertEqual(Float(bitPattern: partialWords[chunk]), larger, accuracy: 1e-6 * max(larger, 1e-3), "chunk \(chunk)")
        }

        // A stereo frame ticks the pager once.
        let savedStereo = renderInfo.isXRStereoMode
        let savedEyes = (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection)
        defer {
            renderInfo.isXRStereoMode = savedStereo
            (renderInfo.xrEye0View, renderInfo.xrEye0Projection, renderInfo.xrEye1View, renderInfo.xrEye1Projection) = savedEyes
        }
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        let headView = try XCTUnwrap(scene.get(component: CameraComponent.self, for: camera)).viewSpace
        renderInfo.isXRStereoMode = true
        renderInfo.xrEye0View = simd_mul(matrix4x4Translation(0.032, 0, 0), headView)
        renderInfo.xrEye1View = simd_mul(matrix4x4Translation(-0.032, 0, 0), headView)
        var eye0Projection = renderInfo.perspectiveSpace
        eye0Projection.columns.2.x = 0.05
        var eye1Projection = renderInfo.perspectiveSpace
        eye1Projection.columns.2.x = -0.05
        renderInfo.xrEye0Projection = eye0Projection
        renderInfo.xrEye1Projection = eye1Projection
        let before = fixture.pager.tick
        frame(fixture)
        XCTAssertEqual(fixture.pager.tick, before + 1, "one tick per stereo frame")
        XCTAssertEqual(fixture.pager.stats.issuedThisTick, 13, "both eyes' demand in one tick")
    }

    /// One paged cull of the fixture into slot 0 by hand; returns the demand words.
    private func cullByHand(_ fixture: PagedFixture, constants: GaussianChunkCullConstants) throws -> [UInt32] {
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        let budgetState = try budgetStateBuffer()
        let densityHistogram = try densityHistogramBuffer()
        densityHistogram.contents().storeBytes(of: GaussianBudgetDensityHistogram(), as: GaussianBudgetDensityHistogram.self)
        memset(fixture.table.demandTables[0].contents(), 0, fixture.table.demandTables[0].length)
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            _ = encodeGaussianChunkCull(
                encoder,
                pipelines: pipelines,
                chunkTable: fixture.table,
                visibleChunks: fixture.table.visibleChunks[0],
                chunkSet: fixture.table.visibleChunkSets[0],
                budgetState: budgetState,
                densityHistogram: densityHistogram,
                constants: constants,
                hzbTexture: textureResources.hzbDepthPyramid ?? textureResources.depthMap,
                residency: fixture.table.residencyTables[0],
                demand: fixture.table.demandTables[0]
            )
            encoder.endEncoding()
        }
        return demandWords(fixture, slot: 0)
    }

    func testDemandOnlyCullWritesDemandAndAppendsNothing() throws {
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let pipelines = try XCTUnwrap(GaussianChunkCullPipelineStates.current())
        let densityHistogram = try densityHistogramBuffer()
        densityHistogram.contents().storeBytes(of: GaussianBudgetDensityHistogram(), as: GaussianBudgetDensityHistogram.self)
        fixture.table.visibleChunkSets[0].contents().storeBytes(of: GaussianVisibleSet(), as: GaussianVisibleSet.self)
        memset(fixture.table.demandTables[0].contents(), 0, fixture.table.demandTables[0].length)
        let constants = try cullConstants(fixture, paged: 2)
        runSynchronously { commandBuffer in
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            _ = encodeGaussianChunkDemand(
                encoder,
                pipelines: pipelines,
                chunkTable: fixture.table,
                visibleChunks: fixture.table.visibleChunks[0],
                chunkSet: fixture.table.visibleChunkSets[0],
                densityHistogram: densityHistogram,
                demand: fixture.table.demandTables[0],
                constants: constants,
                hzbTexture: textureResources.hzbDepthPyramid ?? textureResources.depthMap
            )
            encoder.endEncoding()
        }
        let words = demandWords(fixture, slot: 0)
        let areas = mirrorAreas(fixture, constants: constants)
        XCTAssertEqual(areas.count, 13)
        for chunk in 0 ..< fixture.chunkCount {
            XCTAssertEqual(Float(bitPattern: words[chunk]), areas[chunk] ?? 0, accuracy: 1e-6 * (areas[chunk] ?? 1))
        }
        let record = fixture.table.visibleChunkSets[0].contents().load(as: GaussianVisibleSet.self)
        XCTAssertEqual(record.visibleCount, 0, "nothing appended")
        XCTAssertEqual(record.threadgroupCount, 0)
        let histogram = densityHistogram.contents().load(as: GaussianBudgetDensityHistogram.self)
        XCTAssertEqual(histogram.requestedSplats, 0, "the histogram is untouched")
        XCTAssertEqual(histogram.visibleChunks, 0)
    }

    // MARK: - 6: the order of the reads

    func testWantedRanksAndPriorityOrderTheReads() throws {
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        let areas = try mirrorAreas(fixture, constants: cullConstants(fixture))
        frame(fixture)
        let issued = fixture.pager.eventLog.filter { $0.kind == .issued && $0.tick == 1 }
        XCTAssertEqual(issued.count, areas.count, "every seen chunk's head at the first tick")
        let priorities = issued.map(\.priority)
        XCTAssertEqual(priorities, priorities.sorted(by: >), "by priority, descending")
        let first = try XCTUnwrap(issued.first)
        XCTAssertEqual(areas[first.chunk], areas.values.max(), "the nearest chunk's head first (the chunks the camera stands in tie at the guard area)")
        for event in issued {
            XCTAssertEqual(event.priority, areas[event.chunk] ?? -1, accuracy: 1e-6, "an empty chunk's priority is its area")
        }
        removeEntityGaussian(entityId: fixture.entity)

        // The slab: heads under a small budget, then top-ups when it lifts, each tick in order.
        GaussianRuntimeLimits.workingSetSplatsOverride = 1500
        let slab = try loadSlab(poolSlots: 600)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frames(slab, max: 30) { slab.pager.stats.residentChunks > 20 && slab.pager.stats.issuedThisTick == 0 && slab.pager.stats.pendingReads == 0 }
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        frames(slab, max: 20) { slab.pager.eventLog.contains { $0.kind == .issued && $0.tier > 0 } }
        let events = slab.pager.eventLog.filter { $0.kind == .issued }
        XCTAssertTrue(events.contains { $0.tier > 0 }, "top-ups follow the heads once the budget allows")
        var byTick: [UInt32: [GaussianPagingEvent]] = [:]
        for event in events {
            byTick[event.tick, default: []].append(event)
        }
        for (tick, tickEvents) in byTick {
            let priorities = tickEvents.map(\.priority)
            XCTAssertEqual(priorities, priorities.sorted(by: >), "tick \(tick): issued in priority order")
            // A head (deficit 1 over tier 0) outranks a top-up of the same area.
            for head in tickEvents where head.tier == 0 {
                for topUp in tickEvents where topUp.tier > 0 && abs((slab.pager.chunkState(topUp.chunk).lastArea) - slab.pager.chunkState(head.chunk).lastArea) < 1e-6 {
                    XCTAssertGreaterThanOrEqual(head.priority, topUp.priority)
                }
            }
        }
    }

    // MARK: - 7: slot reuse

    func testRetiredSlotsAreNotReusedForThreeTicks() throws {
        GaussianPagingPolicy.minResidencyTicks = 0
        GaussianPagingPolicy.holdOffTicks = 2
        GaussianPagingPolicy.reloadCooldownTicks = 0
        GaussianPagingPolicy.surplusTicks = 1
        let fixture = try loadFixture(poolSlots: 6)
        // By hand, without noteGPUIdle: the ring alone frees the slots.
        for i in 0 ..< 60 {
            let camera = i % 2 == 0 ? cornerCamera : sideCamera
            placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            frame(fixture, gpuIdle: false)
        }
        let manual = fixture.pager.eventLog
        XCTAssertGreaterThan(manual.filter { $0.kind == .evicted }.count, 5, "the churn evicts")
        assertSlotReuseInvariant(manual)
        XCTAssertEqual(fixture.pager.stats.state, .active)

        // Full frames rotate the in-flight slots for real.
        for i in 0 ..< 60 {
            let camera = i % 2 == 0 ? cornerCamera : sideCamera
            placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            fullFrame(fixture)
            let slot = min(renderInfo.currentInFlightFrameSlot, maxInFlightCommandBuffers - 1)
            XCTAssertEqual(sharedVisibleSet().overflowCount, 0)
            let readback = visibleChunkReadback(fixture.table, slot: slot)
            let residency = residencyEntries(fixture, slot: slot)
            for entry in readback.entries {
                let resident = min(residency[Int(entry.chunkIndex)].residentRanks, fixture.index.chunks[Int(entry.chunkIndex)].splatCount)
                XCTAssertEqual(entry.splatCount, resident, "frame \(i) slot \(slot) chunk \(entry.chunkIndex): the listed count is the slot's resident ranks")
            }
        }
        assertSlotReuseInvariant(Array(fixture.pager.eventLog.dropFirst(manual.count)))
        XCTAssertLessThanOrEqual(fixture.pager.stats.residentSlots, 6)
    }

    // MARK: - 8, 9: eviction hysteresis

    /// The area of every chunk from a camera at `eye` looking at `target`.
    private func areas(_ fixture: PagedFixture, eye: simd_float3, target: simd_float3) throws -> [Int: Float] {
        let viewProjection = try viewProjection(entity: fixture.entity, eye: eye, target: target)
        var constants = GaussianChunkCullConstants()
        constants.viewProjection0 = viewProjection
        constants.viewProjection1 = viewProjection
        constants.viewCount = 1
        constants.clipGuardBand = gaussianCullClipGuardBand
        constants.chunkCount = UInt32(fixture.chunkCount)
        return mirrorAreas(fixture, constants: constants)
    }

    /// Four tight clusters of sixteen splats at x = −6, −1, 1, 6, all at y = z = 0 so the
    /// Morton order is the order along x and each cluster is one chunk; the two near clusters
    /// mirror each other, so a camera on the axis sees them with the same area.
    private func bakeClusters() throws -> URL {
        var splats: [UntoldGSSplat] = []
        var generator = GaussianSyntheticAsset.SplitMix64(seed: 0xC10575)
        let nearOffsets = (0 ..< 16).map { _ in generator.value(in: -0.05 ... 0.05) }
        for x: Float in [-6, -1, 1, 6] {
            for index in 0 ..< 16 {
                let jitter = abs(x) == 1 ? nearOffsets[index] * (x < 0 ? -1 : 1) : generator.value(in: -0.05 ... 0.05)
                let offset = simd_float3(jitter, 0, 0)
                splats.append(UntoldGSSplat(
                    position: simd_float3(x, 0, 0) + offset,
                    scale: simd_float3(repeating: 0.02),
                    rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)),
                    color: simd_float3(0.6, 0.5, 0.4),
                    opacity: 0.9,
                    sphericalHarmonics: []
                ))
            }
        }
        var options = UntoldGSWriteOptions()
        options.log2ChunkSplats = 4
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianPagingTest-clusters-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        try UntoldGSFormat.write(splats: splats, options: options, to: url)
        temporaryFiles.append(url)
        return url
    }

    func testEvictionHasHysteresis() throws {
        GaussianPagingPolicy.minPoolSlots = 1
        GaussianPagingPolicy.minResidencyTicks = 0
        GaussianPagingPolicy.holdOffTicks = 1000
        GaussianPagingPolicy.surplusTicks = 1000
        GaussianPagingPolicy.reloadCooldownTicks = 0
        let fixture = try loadPaged(url: bakeClusters(), poolSlots: 1)
        XCTAssertEqual(fixture.chunkCount, 4)
        let centers = fixture.index.chunks.map { 0.5 * ($0.aabbMin + $0.aabbMax) }
        for chunk in fixture.index.chunks {
            XCTAssertLessThan(chunk.aabbMax.x - chunk.aabbMin.x, 0.2, "one cluster per chunk")
        }
        let left = try XCTUnwrap(centers.indices.min { abs(centers[$0].x + 1) < abs(centers[$1].x + 1) })
        let right = try XCTUnwrap(centers.indices.min { abs(centers[$0].x - 1) < abs(centers[$1].x - 1) })
        let farLeft = try XCTUnwrap(centers.indices.min { abs(centers[$0].x + 6) < abs(centers[$1].x + 6) })
        XCTAssertNotEqual(left, right)

        // On the axis between the two near clusters: equal areas, one slot.
        let axis = (eye: simd_float3(0, 0, 4), target: simd_float3.zero)
        placeGaussianTestCamera(eye: axis.eye, target: axis.target)
        let axisAreas = try areas(fixture, eye: axis.eye, target: axis.target)
        let leftArea = try XCTUnwrap(axisAreas[left])
        let rightArea = try XCTUnwrap(axisAreas[right])
        XCTAssertEqual(leftArea, rightArea, accuracy: 1e-3 * leftArea, "symmetric: the same area")
        XCTAssertLessThan(axisAreas[farLeft] ?? 0, 0.1 * leftArea, "the far clusters are small or out of view")
        frames(fixture, max: 6) { fixture.pager.stats.residentChunks == 1 && fixture.pager.stats.pendingReads == 0 }
        let resident = try XCTUnwrap(residentChunks(fixture).first)
        XCTAssertTrue(resident == UInt32(left) || resident == UInt32(right), "one of the two equal chunks has the slot")
        XCTAssertGreaterThan(fixture.pager.stats.saturatedCandidates, 0, "the other found no slot")
        for _ in 0 ..< 60 {
            frame(fixture)
            XCTAssertEqual(fixture.pager.stats.evictedThisTick, 0, "an equal chunk is not worth 1.5× the resident one: no ping-pong")
        }
        XCTAssertEqual(residentChunks(fixture), [resident])
        XCTAssertTrue(fixture.pager.eventLog.filter { $0.kind == .evicted }.isEmpty)

        // Over the other cluster: it is worth more than 1.5× the resident one and displaces it.
        let other = resident == UInt32(left) ? right : left
        let above = (eye: centers[other] + simd_float3(0, 0.6, 1.2), target: centers[other])
        let aboveAreas = try areas(fixture, eye: above.eye, target: above.target)
        let otherArea = try XCTUnwrap(aboveAreas[other])
        XCTAssertGreaterThanOrEqual(otherArea, 1.5 * max(aboveAreas[Int(resident)] ?? 0, fixture.pager.chunkState(Int(resident)).lastArea), "the pose makes it 1.5× the resident one's worth")
        placeGaussianTestCamera(eye: above.eye, target: above.target)
        frames(fixture, max: 8) { fixture.pager.residentRanks(of: other) > 0 && fixture.pager.stats.pendingReads == 0 }
        XCTAssertGreaterThan(fixture.pager.residentRanks(of: other), 0, "the larger chunk displaced the resident one")
        XCTAssertEqual(fixture.pager.residentRanks(of: Int(resident)), 0)
        XCTAssertEqual(fixture.pager.eventLog.filter { $0.kind == .evicted }.map(\.chunk), [Int(resident)])
    }

    func testStalePagesAreEvictedAfterTheHoldOff() throws {
        GaussianPagingPolicy.holdOffTicks = 30
        GaussianPagingPolicy.minResidencyTicks = 1000
        GaussianPagingPolicy.surplusTicks = 1000
        let fixture = try loadFixture(poolSlots: 8)
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        let cornerSet = try Set(mirrorAreas(fixture, constants: cullConstants(fixture)).keys.map { UInt32($0) })
        XCTAssertEqual(cornerSet.count, 8)
        frames(fixture, max: 6) { residentChunks(fixture) == cornerSet }
        XCTAssertEqual(residentChunks(fixture), cornerSet)
        // A demanded chunk's stamp is the last ingest's tick (the flag stands for it).
        let seenTick = fixture.pager.tick
        for chunk in cornerSet {
            let state = fixture.pager.chunkState(Int(chunk))
            XCTAssertTrue(state.flags.contains(.demanded), "chunk \(chunk) is demanded")
            XCTAssertEqual(state.lastDemandTick, seenTick, "chunk \(chunk) is stamped with the last ingest")
        }

        // Looking away: nothing is demanded, nothing needs a slot, nothing goes.
        placeGaussianTestCamera(eye: awayCamera.eye, target: awayCamera.target)
        let requestsBefore = fixture.source.requestLog.count
        // The tick each chunk was last flagged (the ingest sees the previous frame's cull).
        var lastSeen: [UInt32: UInt32] = [:]
        for _ in 0 ..< 40 {
            frame(fixture)
            for chunk in cornerSet where fixture.pager.chunkState(Int(chunk)).flags.contains(.demanded) {
                lastSeen[chunk] = fixture.pager.tick
            }
            XCTAssertEqual(residentChunks(fixture), cornerSet, "a page seen 40 ticks ago is kept while nothing needs its slot")
        }
        XCTAssertEqual(fixture.source.requestLog.count, requestsBefore)
        // A chunk that dropped out keeps the tick of the last ingest that saw it.
        for chunk in cornerSet {
            let state = fixture.pager.chunkState(Int(chunk))
            XCTAssertFalse(state.flags.contains(.demanded), "chunk \(chunk) left the demand")
            XCTAssertEqual(state.lastDemandTick, lastSeen[chunk] ?? seenTick, "chunk \(chunk) keeps the tick it was last seen")
            XCTAssertGreaterThan(fixture.pager.tick &- state.lastDemandTick, GaussianPagingPolicy.holdOffTicks, "chunk \(chunk) is past the hold-off")
        }

        // The side view demands chunks the pool has no room for: the stale ones make room.
        placeGaussianTestCamera(eye: sideCamera.eye, target: sideCamera.target)
        let sideSet = try Set(mirrorAreas(fixture, constants: cullConstants(fixture)).keys.map { UInt32($0) })
        XCTAssertEqual(sideSet.count, 12)
        let stale = cornerSet.subtracting(sideSet)
        XCTAssertFalse(stale.isEmpty, "some corner chunks are out of the side view")
        frames(fixture, max: 8) { residentChunks(fixture).isDisjoint(with: stale) && fixture.pager.stats.residentChunks == 8 }
        let evicted = Set(fixture.pager.eventLog.filter { $0.kind == .evicted }.map { UInt32($0.chunk) })
        XCTAssertFalse(evicted.isEmpty)
        XCTAssertTrue(evicted.isSubset(of: stale), "only chunks the view left were evicted: \(evicted) vs stale \(stale)")
        XCTAssertTrue(residentChunks(fixture).isSubset(of: sideSet))
    }

    // MARK: - 10: the fade

    func testFadeInIsFrameCountedAndDeterministic() throws {
        GaussianPagingPolicy.fadeFrames = 16
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        let cpu = try UntoldGSFormat.read(from: fixture.url)
        let resolver = GaussianSplatIndexResolver(positions: cpu.encodedSplats.map(\.position))
        frame(fixture) // tick 1: every head issued and landed
        XCTAssertEqual(fixture.pager.stats.pendingReads, 0)
        frame(fixture) // tick 2: mapped, arrival 2, drawn at 1/16
        XCTAssertEqual(fixture.pager.stats.residentChunks, 13)
        XCTAssertEqual(fixture.pager.chunkState(0).arrivalTick, 2)

        func assertOpacity(fraction: Float, file: StaticString = #filePath, line: UInt = #line) {
            let records = sharedGaussianRecords()
            XCTAssertEqual(records.count, 200, file: file, line: line)
            let origins = resolver.indices(of: records)
            var checked = 0
            for (record, origin) in zip(records, origins) {
                let reference = Float(cpu.encodedSplats[Int(origin)].colorAndOpacity.w)
                XCTAssertEqual(record.conicAndOpacity.w, reference * fraction, accuracy: 2e-3, "splat \(origin) at fade \(fraction)", file: file, line: line)
                checked += 1
            }
            XCTAssertEqual(checked, 200, file: file, line: line)
        }
        assertOpacity(fraction: 1 / 16)
        for _ in 0 ..< 7 {
            frame(fixture)
        } // tick 9: +7
        assertOpacity(fraction: 8 / 16)
        for _ in 0 ..< 8 {
            frame(fixture)
        } // tick 17: +15
        assertOpacity(fraction: 1)
        XCTAssertFalse(fixture.pager.chunkState(0).flags.contains(.fadeActive))
        // Two frames past the fade: bit-identical keys.
        frame(fixture)
        frame(fixture)
        let first = sortedDepthWords()
        let second = sortedDepthWords()
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.count, 200)

        // The switch: at once.
        GaussianDebugOptions.shared.disablePageFade = true
        removeEntityGaussian(entityId: fixture.entity)
        let instant = try loadFixture(poolSlots: 13)
        frame(instant)
        frame(instant)
        XCTAssertEqual(instant.pager.stats.residentChunks, 13)
        let records = sharedGaussianRecords()
        let origins = resolver.indices(of: records)
        for (record, origin) in zip(records, origins) {
            XCTAssertEqual(record.conicAndOpacity.w, Float(cpu.encodedSplats[Int(origin)].colorAndOpacity.w), accuracy: 2e-3)
        }
    }

    // MARK: - 11: the caps

    func testPerTickCapsBoundTheIssuedBytes() throws {
        GaussianPagingPolicy.maxPageBytesInFlight = 64 << 10
        GaussianPagingPolicy.maxPageReadsPerTick = 4
        GaussianRuntimeLimits.workingSetSplatsOverride = 20000
        let fixture = try loadSlab(poolSlots: 300)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        var bytesBefore = fixture.source.bytesRequested
        for _ in 0 ..< 12 {
            frame(fixture)
            let issuedBytes = fixture.source.bytesRequested - bytesBefore
            bytesBefore = fixture.source.bytesRequested
            XCTAssertLessThanOrEqual(issuedBytes, 64 << 10, "a tick's reads stay within the in-flight cap")
            let tick = fixture.pager.tick
            let requests = Set(fixture.pager.eventLog.filter { $0.kind == .issued && $0.tick == tick }.map(\.chunk))
            XCTAssertLessThanOrEqual(requests.count, 4)
        }
        XCTAssertGreaterThan(fixture.pager.stats.residentChunks, 10)

        // Two tiers mapped per tick at most: the rest of the landed reads wait in the inbox.
        GaussianPagingPolicy.maxCommitsPerTick = 2
        var sawTwo = false
        for _ in 0 ..< 12 {
            frame(fixture)
            let tick = fixture.pager.tick
            let committed = fixture.pager.eventLog.filter { $0.kind == .committed && $0.tick == tick }.count
            XCTAssertLessThanOrEqual(committed, 2)
            if committed == 2 { sawTwo = true }
        }
        XCTAssertTrue(sawTwo, "the cap was reached")
    }

    /// The commit budget: a tick over it defers the landed tiers past the first clock stride to
    /// the next tick, still in priority order, and counts them (`deferredTiers`); under
    /// `freezePaging` the deferred ones keep mapping (they are landed, not reads).
    func testTheCommitBudgetDefersLandedTiersInOrder() throws {
        GaussianRuntimeLimits.workingSetSplatsOverride = 20000
        let fixture = try loadSlab(poolSlots: 300)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(fixture) // tick 1: the first reads issued and landed
        let issued = fixture.pager.eventLog.filter { $0.kind == .issued && $0.tick == 1 }
        XCTAssertGreaterThan(issued.count, 32, "enough tiers landed to cross the clock stride")
        XCTAssertEqual(fixture.pager.stats.pendingReads, 0)
        // The commit order: priority descending, then the chunk, then the tier.
        let expected = issued.sorted { $0.priority != $1.priority ? $0.priority > $1.priority : $0.chunk != $1.chunk ? $0.chunk < $1.chunk : $0.tier < $1.tier }
            .map { (chunk: $0.chunk, tier: $0.tier) }

        // A budget of 0: the first completion, then one clock stride of 16 tiers, per tick. No
        // new reads (frozen), so the ticks map exactly the tiers that landed at tick 1.
        GaussianPagingPolicy.commitBudget = 0
        GaussianDebugOptions.shared.freezePaging = true
        var committed: [(chunk: Int, tier: Int)] = []
        var perTick: [Int] = []
        var deferredAfter: [Int] = []
        for _ in 0 ..< 64 {
            frame(fixture)
            let tick = fixture.pager.tick
            let events = fixture.pager.eventLog.filter { $0.kind == .committed && $0.tick == tick }
            committed.append(contentsOf: events.map { (chunk: $0.chunk, tier: $0.tier) })
            perTick.append(events.count)
            deferredAfter.append(fixture.pager.stats.deferredTiers)
            XCTAssertEqual(fixture.pager.stats.pendingReads, 0, "a deferred tier is landed, not pending")
            XCTAssertEqual(fixture.pager.stats.issuedThisTick, 0, "frozen: nothing issued")
            if fixture.pager.stats.deferredTiers == 0 { break }
        }
        XCTAssertGreaterThan(perTick.count, 1, "the budget deferred some tiers")
        XCTAssertEqual(deferredAfter.last, 0, "everything landed was mapped in the end")
        for (index, count) in perTick.enumerated() {
            XCTAssertGreaterThanOrEqual(count, min(16, expected.count - perTick[..<index].reduce(0, +)), "tick \(index + 2) mapped at least a clock stride")
            XCTAssertLessThan(count, expected.count, "tick \(index + 2) mapped less than all of it")
        }
        for (index, count) in perTick.dropLast().enumerated() {
            XCTAssertEqual(deferredAfter[index], expected.count - perTick[...index].reduce(0, +), "tick \(index + 2) counted the tiers it left: \(count) mapped")
        }
        XCTAssertEqual(committed.map(\.chunk), expected.map(\.chunk), "mapped across the ticks in the commit order")
        XCTAssertEqual(committed.map(\.tier), expected.map(\.tier))
        GaussianDebugOptions.shared.freezePaging = false
    }

    // MARK: - 12, 13, 14: failures

    func testAReadFailureBacksOffThenFaultsTheChunk() throws {
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.failChunks = [3: .ioFailure(errno: EIO)]
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        for _ in 0 ..< 190 {
            frame(fixture)
        }
        let attempts = fixture.pager.eventLog.filter { $0.kind == .issued && $0.chunk == 3 }.map(\.tick)
        XCTAssertEqual(attempts.count, 4, "the first read and three retries: \(attempts)")
        if attempts.count == 4 {
            // A failure lands the tick after it is issued; the backoff counts from there.
            XCTAssertEqual(attempts[1] - attempts[0], 9, accuracy: 1)
            XCTAssertEqual(attempts[2] - attempts[1], 33, accuracy: 1)
            XCTAssertEqual(attempts[3] - attempts[2], 129, accuracy: 1)
        }
        XCTAssertEqual(fixture.pager.stats.faultedChunks, 1)
        XCTAssertTrue(fixture.pager.chunkState(3).flags.contains(.faulted))
        XCTAssertEqual(fixture.pager.residentRanks(of: 3), 0)
        XCTAssertEqual(fixture.pager.errorReports, 1, "reported once")
        XCTAssertEqual(fixture.pager.stats.residentChunks, 12, "the other chunks are unaffected")
        XCTAssertEqual(fixture.pager.stats.state, .active)
        XCTAssertEqual(fixture.pager.freeSlotCount, 1, "the failed reads' slot went back to the free list at once")
    }

    func testACorruptChunkIsEvictedAndFaulted() throws {
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.corruptChunks = [2]
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        frames(fixture, max: 6) { fixture.pager.stats.residentChunks == 12 && fixture.pager.stats.pendingReads == 0 }
        XCTAssertEqual(fixture.pager.residentRanks(of: 2), 0)
        XCTAssertTrue(fixture.pager.chunkState(2).flags.contains(.faulted))
        XCTAssertEqual(fixture.pager.stats.corruptChunks, 1)
        XCTAssertEqual(fixture.pager.stats.faultedChunks, 1)
        XCTAssertEqual(fixture.pager.errorReports, 1)
        XCTAssertEqual(fixture.pager.stats.residentChunks, 12)
        frame(fixture)
        XCTAssertEqual(fixture.pager.eventLog.filter { $0.kind == .issued && $0.chunk == 2 }.count, 1, "never requested again")

        let whole = try GaussianChunkLoader.load(url: fixture.url, allowPaging: false)
        let twin = try GaussianPartialTwin(loaded: whole, residentRanks: [2: 0])
        let pagedImage = renderGaussianSplatLayer()
        let twinImage = twin.withLegacyBuffers(fixture.component) { renderGaussianSplatLayer() }
        let comparison = compareGaussianSplatLayers(pagedImage, twinImage)
        XCTAssertGreaterThan(comparison.covered, 1000)
        XCTAssertLessThanOrEqual(comparison.differingPixels, 50)
        XCTAssertGreaterThan(comparison.psnr, 55)
    }

    func testAChangedFileFaultsTheAssetAndReopenRestoresIt() throws {
        GaussianPagingPolicy.faultReopenTicks = 20
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.identityChangesAfterRead = 5
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        frames(fixture, max: 5) { fixture.pager.stats.state == .faulted }
        XCTAssertEqual(fixture.pager.stats.state, .faulted)
        XCTAssertEqual(fixture.pager.errorReports, 1)
        let resident = fixture.pager.stats.residentChunks
        XCTAssertGreaterThan(resident, 0, "the reads that landed before the change stay")
        XCTAssertLessThan(resident, 13)
        frame(fixture)
        let visible = sharedVisibleSet().visibleCount
        let requests = fixture.source.requestLog.count
        let reopens = fixture.source.reopenCount
        for _ in 0 ..< 45 {
            frame(fixture)
            XCTAssertEqual(fixture.pager.stats.state, .faulted)
            XCTAssertEqual(fixture.source.requestLog.count, requests, "no new read while faulted")
            XCTAssertEqual(sharedVisibleSet().visibleCount, visible, "the resident set keeps drawing")
        }
        XCTAssertGreaterThan(fixture.source.reopenCount, reopens, "reopen tried every 20 ticks")
        XCTAssertEqual(fixture.pager.stats.residentChunks, resident)

        fixture.source.restoreIdentity()
        frames(fixture, max: 25) { fixture.pager.stats.state == .active }
        XCTAssertEqual(fixture.pager.stats.state, .active, "the reopen found the file back")
        frames(fixture, max: 10) { fixture.pager.stats.residentChunks == 13 }
        XCTAssertEqual(fixture.pager.stats.residentChunks, 13, "reads resumed")
        XCTAssertGreaterThan(fixture.source.requestLog.count, requests)
    }

    // MARK: - 15: freeze

    func testFreezePagingHoldsTheResidentSetAndTheImage() throws {
        GaussianPagingPolicy.minResidencyTicks = 0
        GaussianPagingPolicy.holdOffTicks = 2
        GaussianPagingPolicy.reloadCooldownTicks = 0
        let fixture = try loadFixture(poolSlots: 6)
        for i in 0 ..< 10 {
            let camera = i % 2 == 0 ? cornerCamera : sideCamera
            placeGaussianTestCamera(eye: camera.eye, target: camera.target)
            frame(fixture)
        }
        placeGaussianTestCamera(eye: sideCamera.eye, target: sideCamera.target)
        GaussianDebugOptions.shared.freezePaging = true
        frame(fixture) // the reads already in flight land and map
        let requests = fixture.source.requestLog.count
        let resident = residentChunks(fixture)
        XCTAssertFalse(resident.isEmpty)
        var keys: [[UInt32]] = []
        for _ in 0 ..< 10 {
            fixture.pager.noteGPUIdle()
            keys.append(sortedDepthWords())
            XCTAssertEqual(fixture.source.requestLog.count, requests, "frozen: no read")
            XCTAssertEqual(residentChunks(fixture), resident, "frozen: the resident set")
            XCTAssertEqual(fixture.pager.stats.evictedThisTick, 0)
        }
        for frameKeys in keys {
            XCTAssertEqual(frameKeys, keys[0], "frozen: bit-identical keys")
        }
        GaussianDebugOptions.shared.freezePaging = false
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        frames(fixture, max: 5) { fixture.source.requestLog.count > requests }
        XCTAssertGreaterThan(fixture.source.requestLog.count, requests, "reads resume")
    }

    // MARK: - 16, 17: the ledger and teardown

    func testTheLedgerCarriesThePoolNotTheFile() throws {
        let fixture = try loadFixture(poolSlots: 4)
        let corePool = try XCTUnwrap(fixture.component.packedSplatData)
        let shPool = fixture.component.sphericalHarmonicsData
        XCTAssertEqual(corePool.label, "Gaussian Page Pool Core")
        XCTAssertEqual(corePool.length, 4 * fixture.pager.ranksPerPage * UntoldGSFormat.coreRecordSize)
        XCTAssertEqual(fixture.component.estimatedGPUBytes, corePool.length + (shPool?.length ?? 0) + fixture.table.gpuBytes)
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: fixture.entity), fixture.component.estimatedGPUBytes)
        XCTAssertLessThan(corePool.length + (shPool?.length ?? 0), assetBytes(fixture), "the pool, not the file")
        XCTAssertEqual(fixture.table.residencyTables.count, maxInFlightCommandBuffers)
        XCTAssertEqual(fixture.table.pageTables.count, maxInFlightCommandBuffers)
        XCTAssertEqual(fixture.table.demandTables.count, maxInFlightCommandBuffers)
        XCTAssertEqual(fixture.table.residencyTables[0].length, 13 * MemoryLayout<GaussianChunkResidency>.stride)
        XCTAssertEqual(fixture.table.pageTables[0].length, 13 * MemoryLayout<UInt32>.stride, "one tier per 16-splat chunk")
        XCTAssertEqual(fixture.table.demandTables[0].length, 13 * MemoryLayout<UInt32>.stride)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, fixture.pager.poolBytes)
        XCTAssertEqual(fixture.component.residentSplatCount, 4 * fixture.pager.ranksPerPage)

        removeEntityGaussian(entityId: fixture.entity)
        XCTAssertNil(MemoryBudgetManager.shared.getMemorySize(for: fixture.entity))
        XCTAssertEqual(fixture.pager.state, .closed)
        XCTAssertTrue(fixture.source.closed)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0)
    }

    func testUnloadDuringInFlightReadsDropsTheCompletions() throws {
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.latencyTicks = 5
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        fixture.pager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        settle(fixture)
        XCTAssertEqual(fixture.pager.stats.pendingReads, 13)
        XCTAssertEqual(fixture.source.blockedReads, 13)
        fixture.pager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        XCTAssertEqual(fixture.pager.stats.residentChunks, 0)

        removeEntityGaussian(entityId: fixture.entity)
        XCTAssertEqual(fixture.pager.state, .closed)
        XCTAssertFalse(fixture.source.closed, "the source waits for the reads in flight")
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0, "the pool left the registry at shutdown")
        fixture.source.deliverAll()
        let deadline = Date().addingTimeInterval(5)
        while fixture.pager.stats.pendingReads > 0, Date() < deadline {
            usleep(200)
        }
        XCTAssertEqual(fixture.pager.stats.pendingReads, 0)
        XCTAssertEqual(fixture.pager.eventLog.filter { $0.kind == .dropped }.count, 13, "every completion was dropped")
        XCTAssertEqual(fixture.pager.eventLog.filter { $0.kind == .committed }.count, 0)
        XCTAssertTrue(fixture.source.closed, "closed by the last read")
        XCTAssertEqual(fixture.pager.stats.residentChunks, 0)
    }

    func testRemovingTheEntityWithLandedReadsFreesThePager() throws {
        weak var weakPager: GaussianPageManager?
        let source: GaussianTestPageSource
        do {
            let fixture = try loadFixture(poolSlots: 13) { source in
                source.latencyTicks = 5
            }
            weakPager = fixture.pager
            source = fixture.source
            placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
            fixture.pager.noteGPUIdle()
            runGaussianCullAndPreprocess()
            settle(fixture)
            XCTAssertEqual(fixture.pager.stats.pendingReads, 13)

            // The reads land into the inbox, where they wait for a tick that never comes.
            fixture.source.deliverAll()
            let deadline = Date().addingTimeInterval(5)
            while fixture.pager.stats.pendingReads > 0, Date() < deadline {
                usleep(200)
            }
            XCTAssertEqual(fixture.pager.stats.pendingReads, 0)
            XCTAssertEqual(fixture.pager.stats.residentChunks, 0, "nothing drained: the completions sit in the inbox")

            removeEntityGaussian(entityId: fixture.entity)
            XCTAssertEqual(fixture.pager.state, .closed)
            XCTAssertTrue(fixture.source.closed)
            XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0)
            XCTAssertEqual(fixture.pager.eventLog.filter { $0.kind == .dropped }.count, 13, "the landed completions were dropped at shutdown")
            XCTAssertEqual(fixture.pager.stats.residentChunks, 0)
        }
        XCTAssertNil(weakPager, "no completion holds the manager: the pools and the source go with the entity")
        XCTAssertTrue(source.closed)
    }

    func testWaitingReadsHoldNoThreadBeyondTheConcurrentReads() throws {
        GaussianPagingPolicy.maxConcurrentReads = 2
        let fixture = try loadFixture(poolSlots: 13) { source in
            source.holdChunks = Set(0 ..< 13)
        }
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        fixture.pager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        // Thirteen requests: two run and block in the source, eleven wait in the pager's list.
        let deadline = Date().addingTimeInterval(5)
        while fixture.source.blockedReads < 2, Date() < deadline {
            usleep(200)
        }
        usleep(20000)
        XCTAssertEqual(fixture.pager.stats.pendingReads, 13)
        XCTAssertEqual(fixture.source.blockedReads, 2, "only maxConcurrentReads reads reached the source; the rest hold no thread")
        XCTAssertEqual(Set(fixture.source.requestLog.map(\.chunk)).count, 2)

        // Released, they drain through the two running slots in issue order.
        fixture.source.deliverAll()
        while fixture.pager.stats.pendingReads > 0, Date() < deadline {
            usleep(200)
        }
        XCTAssertEqual(fixture.pager.stats.pendingReads, 0)
        XCTAssertEqual(Set(fixture.source.requestLog.map(\.chunk)).count, 13)
        // The list is drained in issue order; two run at once, so a chunk reaches the source
        // at most one place away from where it was issued.
        let issued = fixture.pager.eventLog.filter { $0.kind == .issued }.map(\.chunk)
        let served = fixture.source.requestLog.map(\.chunk).reduce(into: [Int]()) { if $0.last != $1 { $0.append($1) } }
        XCTAssertEqual(served.count, issued.count)
        for (position, chunk) in served.enumerated() {
            let issuedAt = try XCTUnwrap(issued.firstIndex(of: chunk))
            XCTAssertLessThanOrEqual(abs(position - issuedAt), 1, "chunk \(chunk) served at \(position), issued at \(issuedAt): the waiting reads start in issue order")
        }
        fixture.pager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        XCTAssertEqual(fixture.pager.stats.residentChunks, 13)
    }

    // MARK: - 18: the warmth gate

    func testAPagedTierWaitsForWarmthBeforeTheSwitch() async throws {
        try await runWarmthGate(holdEverything: false)
    }

    func testAPagedTierSwitchesAtTheWarmTimeoutWhenNothingLands() async throws {
        try await runWarmthGate(holdEverything: true)
    }

    private struct TwoTierFixture {
        let entity: EntityID
        let lod: GaussianLODComponent
        let fineURL: URL
        let coarseURL: URL
        let coarseHeader: UntoldGSHeaderV3

        func url(of lodIndex: Int) -> URL {
            lodIndex == 0 ? fineURL : coarseURL
        }
    }

    /// Bakes two progressive tiers of the fixture — the coarse one whole (below a per-run
    /// threshold) unless `coarsePaged`, the fine one paged with a 13-slot pool — and loads the
    /// entity on the coarse tier, the fine one not yet requested.
    private func loadTwoTiers(holdEverything: Bool, coarsePaged: Bool = false) async throws -> TwoTierFixture {
        let ply = try XCTUnwrap(LoadingSystem.shared.resourceURL(forResource: "test_gaussians", withExtension: "ply", subResource: nil))
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("GaussianPagingTest-tiers-\(UUID().uuidString)")
        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = 4
        let bake = try bakeGaussianSplatProgressiveTiers(plyURL: ply, outputBaseURL: base.appendingPathExtension("untoldgs"), levelCount: 2, cookOptions: options)
        temporaryFiles.append(contentsOf: bake.tiers.map(\.url))
        let fineURL = try XCTUnwrap(bake.tiers.first { $0.url.lastPathComponent.contains("_lod0") }?.url)
        let coarseURL = try XCTUnwrap(bake.tiers.first { $0.url.lastPathComponent.contains("_lod1") }?.url)
        let fineHeader = try UntoldGSFormat.readHeaderV3(from: fineURL)
        let coarseHeader = try UntoldGSFormat.readHeaderV3(from: coarseURL)
        let bytesPerSplat = UntoldGSFormat.coreRecordSize + fineHeader.shBytesPerSplat
        // The coarse tier whole, the fine one paged — or both paged.
        GaussianPagingPolicy.pagingThresholdBytesOverride = coarsePaged ? 0 : (Int(coarseHeader.splatCount) + Int(fineHeader.splatCount)) / 2 * bytesPerSplat
        GaussianPagingPolicy.residencyBudgetBytesOverride = 13 * GaussianPagingPolicy.ranksPerPage(splatsPerChunk: fineHeader.splatsPerChunk) * bytesPerSplat
        GaussianPagingPolicy.warmTimeoutTicks = 10
        if holdEverything {
            GaussianPageSourceFactory.override = { url in
                let source = try GaussianTestPageSource(url: url)
                source.holdChunks = Set(0 ..< 64)
                GaussianTestPageSource.record(source)
                return source
            }
        }
        LODConfig.shared.lodUpdateFrameInterval = 1
        LODConfig.shared.gaussianOverdrawBudget = .greatestFiniteMagnitude

        let entity = createEntity()
        fixtures.append(entity)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        setEntityGaussianProgressive(entityId: entity, baseFilename: base.path, withExtension: "untoldgs", levelCount: 2, maxDistances: [20, .greatestFiniteMagnitude])
        let lod = try XCTUnwrap(scene.get(component: GaussianLODComponent.self, for: entity))
        await lod.lodLevels[1].loadTask?.value
        XCTAssertEqual(lod.currentLOD, 1, "the coarse tier first")
        let coarse = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        if coarsePaged {
            XCTAssertNotNil(coarse.pager, "the coarse tier pages")
        } else {
            XCTAssertNil(coarse.pager, "the coarse tier is below the threshold")
        }
        return TwoTierFixture(entity: entity, lod: lod, fineURL: fineURL, coarseURL: coarseURL, coarseHeader: coarseHeader)
    }

    private func runWarmthGate(holdEverything: Bool) async throws {
        let tiers = try await loadTwoTiers(holdEverything: holdEverything)
        let entity = tiers.entity
        let lod = tiers.lod
        let fineURL = tiers.fineURL
        runGaussianCullAndPreprocess()
        let coarseRequest = try budgetState().requestedSplats
        XCTAssertEqual(coarseRequest, tiers.coarseHeader.splatCount)

        lod.forcedLOD = 0
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        XCTAssertEqual(lod.lodLevels[0].residencyState, .resident)
        let fine = try XCTUnwrap(lod.lodLevels[0].buffers)
        let pager = try XCTUnwrap(fine.pager, "the fine tier pages")
        pager.eventLogEnabled = true
        let source = try XCTUnwrap(GaussianTestPageSource.created.last { $0.url == fineURL })
        XCTAssertFalse(pager.isWarm)

        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.currentLOD, 1, "not warm: the coarse tier keeps drawing")
        XCTAssertTrue(pager.warming)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity)?.pager)

        // Frames warm the tier (its demand-only cull, its reads) while the coarse tier draws;
        // the LOD system switches at the first update that finds it warm.
        var ticksToWarm = 0
        var warmAtSwitch = false
        while lod.currentLOD != 0, ticksToWarm < 40 {
            pager.noteGPUIdle()
            runGaussianCullAndPreprocess()
            XCTAssertEqual(try budgetState().requestedSplats, coarseRequest, "the demand-only cull adds nothing to the request")
            settle(pager: pager, source: source)
            ticksToWarm += 1
            warmAtSwitch = pager.isWarm
            GaussianLODSystem.shared.update(deltaTime: 0.1)
            if !warmAtSwitch {
                XCTAssertEqual(lod.currentLOD, 1, "not warm: the coarse tier keeps drawing")
            }
        }
        XCTAssertEqual(lod.currentLOD, 0, "warm: switched")
        XCTAssertTrue(warmAtSwitch, "the switch came with the warmth")
        XCTAssertFalse(pager.warming)
        if holdEverything {
            XCTAssertEqual(pager.stats.residentChunks, 0)
            XCTAssertGreaterThanOrEqual(ticksToWarm, 10, "warm by the timeout alone")
        } else {
            XCTAssertGreaterThan(pager.stats.residentChunks, 8)
            XCTAssertLessThan(ticksToWarm, 10, "warm once the wanted ranks landed")
        }
        XCTAssertTrue(scene.get(component: GaussianComponent.self, for: entity)?.pager === pager)
        if holdEverything {
            source.deliverAll()
        }
    }

    func testATierTheSelectionLeavesStopsWarming() async throws {
        let tiers = try await loadTwoTiers(holdEverything: true)
        let lod = tiers.lod
        GaussianPagingPolicy.warmTimeoutTicks = 1000

        // The fine tier is targeted: it warms (nothing lands, so it does not switch).
        lod.forcedLOD = 0
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        let pager = try XCTUnwrap(lod.lodLevels[0].buffers?.pager, "the fine tier pages")
        let source = try XCTUnwrap(GaussianTestPageSource.created.last { $0.url == tiers.fineURL })
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertTrue(pager.warming)
        XCTAssertEqual(lod.currentLOD, 1)
        let tickBefore = pager.tick
        pager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        XCTAssertEqual(pager.tick, tickBefore + 1, "a warming tier ticks with the frame")

        // The selection goes back to the coarse tier (the hysteresis, the overdraw clamp, a
        // forced LOD): the fine tier is no longer the target, so it stops warming and — a paged
        // tier that neither draws nor warms — is released at once: its pager closes, its pool
        // leaves the registry, its buffers go, and no frame culls its demand or ticks it again.
        lod.forcedLOD = 1
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.currentLOD, 1)
        XCTAssertEqual(pager.state, .closed, "an abandoned paged tier is released, not parked")
        XCTAssertNil(lod.lodLevels[0].buffers)
        XCTAssertEqual(lod.lodLevels[0].residencyState, .notResident)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0, "the coarse tier is whole: no pool left")
        let tickAfter = pager.tick
        for _ in 0 ..< 5 {
            runGaussianCullAndPreprocess()
        }
        XCTAssertEqual(pager.tick, tickAfter, "an abandoned tier is neither culled nor ticked")
        source.deliverAll()

        // Targeted again, it is requested through the normal path and warms into a fresh pool.
        lod.forcedLOD = 0
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.lodLevels[0].residencyState, .loading, "requested again")
        await lod.lodLevels[0].loadTask?.value
        let freshPager = try XCTUnwrap(lod.lodLevels[0].buffers?.pager)
        XCTAssertFalse(freshPager === pager)
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertTrue(freshPager.warming)
        XCTAssertEqual(lod.currentLOD, 1)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, freshPager.poolBytes)
        (GaussianTestPageSource.created.last { $0.url == tiers.fineURL })?.deliverAll()
    }

    func testAnAbandonedPagedTierReleasesItsPoolBeforeAnySwitch() async throws {
        // Both tiers paged, nothing lands: no switch can commit before the warm timeout.
        let tiers = try await loadTwoTiers(holdEverything: true, coarsePaged: true)
        let lod = tiers.lod
        GaussianPagingPolicy.warmTimeoutTicks = 1000
        let coarsePager = try XCTUnwrap(lod.lodLevels[1].buffers?.pager)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes, "one pool: the coarse tier's")
        let coarseLedger = try XCTUnwrap(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity))

        // The camera crosses in: the fine tier loads and warms beside the coarse one.
        lod.forcedLOD = 0
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        let finePager = try XCTUnwrap(lod.lodLevels[0].buffers?.pager, "the fine tier pages")
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertTrue(finePager.warming)
        XCTAssertEqual(lod.currentLOD, 1)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes + finePager.poolBytes, "two pools while the fine tier warms")
        XCTAssertGreaterThan(try XCTUnwrap(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity)), coarseLedger)

        // ...and back out before it warmed: the fine tier's pool goes at once, with no switch
        // committing, and the ledger follows.
        lod.forcedLOD = 1
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.currentLOD, 1, "no switch committed")
        XCTAssertEqual(finePager.state, .closed)
        XCTAssertNil(lod.lodLevels[0].buffers)
        XCTAssertEqual(lod.lodLevels[0].residencyState, .notResident)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes, "one pool: the coarse tier's")
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity), coarseLedger, "the ledger dropped the abandoned tier")
        XCTAssertEqual(coarsePager.state, .active, "the current tier is untouched")
        XCTAssertTrue(scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager === coarsePager)
        (GaussianTestPageSource.created.last { $0.url == tiers.fineURL })?.deliverAll()

        // Frames with the coarse tier drawing alone keep it that way.
        for _ in 0 ..< 5 {
            coarsePager.noteGPUIdle()
            runGaussianCullAndPreprocess()
            GaussianLODSystem.shared.update(deltaTime: 0.1)
        }
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes)

        // Crossing in and out twice more never holds more than the two pools at once and
        // leaves one: each visit gets a fresh pool and gives it back on the retreat.
        var abandoned: [GaussianPageManager] = [finePager]
        for _ in 0 ..< 2 {
            lod.forcedLOD = 0
            GaussianLODSystem.shared.update(deltaTime: 0.1)
            await lod.lodLevels[0].loadTask?.value
            let fresh = try XCTUnwrap(lod.lodLevels[0].buffers?.pager)
            XCTAssertFalse(abandoned.contains { $0 === fresh }, "a fresh pager per visit")
            GaussianLODSystem.shared.update(deltaTime: 0.1)
            XCTAssertTrue(fresh.warming)
            XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes + fresh.poolBytes)
            lod.forcedLOD = 1
            GaussianLODSystem.shared.update(deltaTime: 0.1)
            XCTAssertEqual(fresh.state, .closed)
            XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes)
            abandoned.append(fresh)
            (GaussianTestPageSource.created.last { $0.url == tiers.fineURL })?.deliverAll()
        }
        XCTAssertEqual(lod.currentLOD, 1)
        XCTAssertEqual(abandoned.filter { $0.state == .closed }.count, 3)
    }

    // MARK: - 19: a superseded paged tier releases its pool

    /// Forces `lodIndex`, lets its load land if the tier is not resident, and drives frames
    /// (the live pager and the warming one both idle between frames) until the LOD system
    /// switches to it. Returns the tier's pager once it is current.
    @discardableResult
    private func forceAndSwitch(_ tiers: TwoTierFixture, to lodIndex: Int, maxFrames: Int = 40) async throws -> GaussianPageManager? {
        let lod = tiers.lod
        lod.forcedLOD = lodIndex
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[lodIndex].loadTask?.value
        XCTAssertEqual(lod.lodLevels[lodIndex].residencyState, .resident, "tier \(lodIndex) loaded")
        let pager = lod.lodLevels[lodIndex].buffers?.pager
        let source = GaussianTestPageSource.created.last { $0.url == tiers.url(of: lodIndex) }
        var frames = 0
        while lod.currentLOD != lodIndex, frames < maxFrames {
            scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager?.noteGPUIdle()
            pager?.noteGPUIdle()
            runGaussianCullAndPreprocess()
            if let pager, let source { settle(pager: pager, source: source) }
            frames += 1
            GaussianLODSystem.shared.update(deltaTime: 0.1)
        }
        XCTAssertEqual(lod.currentLOD, lodIndex, "switched to tier \(lodIndex) within \(maxFrames) frames")
        return pager
    }

    func testSwitchingAwayFromAPagedTierReleasesItsPool() async throws {
        let tiers = try await loadTwoTiers(holdEverything: false, coarsePaged: true)
        let lod = tiers.lod
        let coarsePager = try XCTUnwrap(lod.lodLevels[1].buffers?.pager)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes, "one pool: the coarse tier's")
        let coarseLedger = try XCTUnwrap(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity))

        // The fine tier loads and warms beside the coarse one: two pools while it does.
        lod.forcedLOD = 0
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        await lod.lodLevels[0].loadTask?.value
        let finePager = try XCTUnwrap(lod.lodLevels[0].buffers?.pager, "the fine tier pages")
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, coarsePager.poolBytes + finePager.poolBytes, "two pools while the fine tier warms")
        let bothLedger = try XCTUnwrap(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity))
        XCTAssertGreaterThan(bothLedger, coarseLedger, "the ledger carries both tiers")
        XCTAssertEqual(coarsePager.state, .active, "the coarse tier draws until the switch")

        try await forceAndSwitch(tiers, to: 0)

        // The switch released the coarse tier: its pager closed, its buffers gone, its pool
        // out of the registry and the ledger at once.
        XCTAssertEqual(coarsePager.state, .closed)
        XCTAssertNil(lod.lodLevels[1].buffers)
        XCTAssertEqual(lod.lodLevels[1].residencyState, .notResident)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, finePager.poolBytes, "one pool: the fine tier's")
        XCTAssertEqual(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity), bothLedger - coarseLedger, "the ledger dropped the released tier")

        // The live component received the fine tier's buffers and holds them untouched.
        let live = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: tiers.entity))
        XCTAssertTrue(live.pager === finePager)
        XCTAssertEqual(finePager.state, .active)
        XCTAssertNotNil(live.packedSplatData)
        XCTAssertNotNil(live.chunkTable)
        XCTAssertEqual(live.splatCount, lod.lodLevels[0].buffers?.splatCount)
        finePager.noteGPUIdle()
        runGaussianCullAndPreprocess()
        XCTAssertGreaterThan(finePager.stats.residentChunks, 0, "the fine tier keeps paging")
    }

    func testReturningToAReleasedTierLoadsAndWarmsItAgain() async throws {
        let tiers = try await loadTwoTiers(holdEverything: false, coarsePaged: true)
        let lod = tiers.lod
        let coarsePager = try XCTUnwrap(lod.lodLevels[1].buffers?.pager)
        let switched = try await forceAndSwitch(tiers, to: 0)
        let finePager = try XCTUnwrap(switched)
        XCTAssertEqual(coarsePager.state, .closed)
        XCTAssertNil(lod.lodLevels[1].buffers)

        // Wanted again, the coarse tier is requested through the normal path...
        lod.forcedLOD = 1
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.lodLevels[1].residencyState, .loading, "the released tier is requested again")
        XCTAssertEqual(lod.currentLOD, 0, "the fine tier draws meanwhile")
        await lod.lodLevels[1].loadTask?.value
        XCTAssertEqual(lod.lodLevels[1].residencyState, .resident)
        let freshPager = try XCTUnwrap(lod.lodLevels[1].buffers?.pager, "the reloaded tier pages")
        XCTAssertFalse(freshPager === coarsePager, "a fresh pager and pool, not the closed one")
        XCTAssertEqual(freshPager.state, .active)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, finePager.poolBytes + freshPager.poolBytes, "two pools while it warms")

        // ...warms before the switch, as the first time...
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.currentLOD, 0, "not warm: the fine tier keeps drawing")
        XCTAssertTrue(freshPager.warming)
        XCTAssertFalse(freshPager.isWarm)
        XCTAssertTrue(scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager === finePager)

        // ...and switches in with its own pool, releasing the fine tier's.
        try await forceAndSwitch(tiers, to: 1)
        XCTAssertTrue(freshPager.isWarm)
        XCTAssertFalse(freshPager.warming)
        XCTAssertGreaterThan(freshPager.stats.residentChunks, 0, "the fresh pool filled while warming")
        XCTAssertTrue(scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager === freshPager)
        XCTAssertEqual(finePager.state, .closed)
        XCTAssertNil(lod.lodLevels[0].buffers)
        XCTAssertEqual(lod.lodLevels[0].residencyState, .notResident)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, freshPager.poolBytes, "one pool: the reloaded coarse tier's")
    }

    func testDollyingAcrossTheThresholdHoldsOnePool() async throws {
        let tiers = try await loadTwoTiers(holdEverything: false, coarsePaged: true)
        let lod = tiers.lod
        var pagers: [GaussianPageManager] = []
        if let pager = lod.lodLevels[1].buffers?.pager { pagers.append(pager) }

        for _ in 0 ..< 3 {
            if let pager = try await forceAndSwitch(tiers, to: 0) { pagers.append(pager) }
            if let pager = try await forceAndSwitch(tiers, to: 1) { pagers.append(pager) }
        }
        XCTAssertEqual(pagers.count, 7, "the first coarse pager and one per visit")
        let live = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager)
        XCTAssertTrue(live === pagers.last)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, live.poolBytes, "exactly one pool after three round trips")
        XCTAssertEqual(pagers.filter { $0.state == .closed }.count, 6, "every superseded pager closed")
        XCTAssertNil(lod.lodLevels[0].buffers)
        XCTAssertNotNil(lod.lodLevels[1].buffers)

        // The entity's teardown: the last pool goes, and the released tiers are nil-safe.
        removeEntityGaussian(entityId: tiers.entity)
        XCTAssertEqual(live.state, .closed)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0)
        XCTAssertNil(MemoryBudgetManager.shared.getMemorySize(for: tiers.entity))
    }

    func testAWholeResidentTierStaysCachedAcrossTheSwitch() async throws {
        // The coarse tier whole, the fine one paged.
        let tiers = try await loadTwoTiers(holdEverything: false)
        let lod = tiers.lod
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0, "no pool below the threshold")
        let coarse = try XCTUnwrap(lod.lodLevels[1].buffers)

        let switched = try await forceAndSwitch(tiers, to: 0)
        let finePager = try XCTUnwrap(switched)
        XCTAssertTrue(lod.lodLevels[1].buffers === coarse, "a whole-resident tier stays cached for the switch back")
        XCTAssertEqual(lod.lodLevels[1].residencyState, .resident)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, finePager.poolBytes)

        // Back to the cached tier: no load, an instant switch, and the paged tier goes.
        lod.forcedLOD = 1
        GaussianLODSystem.shared.update(deltaTime: 0.1)
        XCTAssertEqual(lod.currentLOD, 1, "instant: nothing to load or warm")
        XCTAssertNil(lod.lodLevels[1].loadTask)
        XCTAssertTrue(lod.lodLevels[1].buffers === coarse)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: tiers.entity)?.pager)
        XCTAssertEqual(finePager.state, .closed)
        XCTAssertNil(lod.lodLevels[0].buffers)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0, "the released tier's pool went with the switch")
    }

    // MARK: - 20: disableChunkCull

    func testDisableChunkCullListsOnlyResidentChunks() throws {
        GaussianDebugOptions.shared.disableChunkCull = true
        let fixture = try loadFixture(poolSlots: 6)
        placeGaussianTestCamera(eye: cornerCamera.eye, target: cornerCamera.target)
        let seen = try Set(mirrorAreas(fixture, constants: cullConstants(fixture)).keys)
        XCTAssertEqual(seen.count, 8)
        frames(fixture, max: 8) { fixture.pager.stats.residentSlots == 6 && fixture.pager.stats.pendingReads == 0 }
        frame(fixture)
        let resident = residentChunks(fixture)
        XCTAssertEqual(resident.count, 6)
        let readback = visibleChunkEntries(fixture.table)
        XCTAssertEqual(Set(readback.entries.map(\.chunkIndex)), resident, "forced visible lists only the resident chunks")
        let requested = Set(fixture.source.requestLog.map(\.chunk))
        XCTAssertTrue(requested.isSubset(of: seen), "a forced-only chunk is never demanded, so never read: \(requested.subtracting(seen))")
    }

    // MARK: - 21, 22: pressure and the working set

    func testPressureWarningEvictsToTheSoftTargetAndStopsIssuing() throws {
        GaussianPagingPolicy.pressureTicks = 20
        GaussianPagingPolicy.holdOffTicks = 1000
        let fixture = try loadFixture(poolSlots: 13)
        placeGaussianTestCamera(eye: farCamera.eye, target: farCamera.target)
        frames(fixture, max: 5) { fixture.pager.stats.residentChunks == 13 }
        XCTAssertEqual(fixture.pager.stats.residentSlots, 13)

        GaussianPagePoolRegistry.shared.noteMemoryPressure(.warning)
        frame(fixture)
        XCTAssertLessThanOrEqual(fixture.pager.stats.residentSlots, 6, "half the slots within one tick")
        let requests = fixture.source.requestLog.count
        for _ in 0 ..< 17 {
            frame(fixture)
            XCTAssertLessThanOrEqual(fixture.pager.stats.residentSlots, 6)
            XCTAssertEqual(fixture.source.requestLog.count, requests, "nothing issued under pressure")
        }
        frames(fixture, max: 10) { fixture.pager.stats.residentChunks == 13 }
        XCTAssertEqual(fixture.pager.stats.residentChunks, 13, "the pressure passed: refilled")

        GaussianPagePoolRegistry.shared.noteMemoryPressure(.critical)
        frame(fixture)
        XCTAssertLessThanOrEqual(fixture.pager.stats.residentSlots, 3, "a quarter on critical")
    }

    func testResidentSplatCountSizesTheWorkingSetUnderDisableWorkingSetBudget() throws {
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        let fixture = try loadSlab(poolSlots: 256)
        XCTAssertEqual(fixture.component.residentSplatCount, 256 * 256)
        XCTAssertEqual(fixture.pager.poolBytes, 1 << 20)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(fixture)
        XCTAssertEqual(GaussianSharedWorkingSet.shared.capacity, 256 * 256, "the set is sized to the pool, not to the 300 000-splat file")
        XCTAssertEqual(try budgetState().budget, 256 * 256)
    }

    // MARK: - 24: layouts

    func testLayoutsArePinned() {
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.stride, 16)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.residentRanks), 0)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.fadeFromRank), 4)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.arrivalFrame), 8)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.coarseAvailable), 12)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.offset(of: \.pagesPerChunk), 0)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.offset(of: \.ranksPerPageLog2), 4)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.offset(of: \.frameIndex), 8)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.offset(of: \.fadeFrames), 12)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.offset(of: \.debugMode), 16)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.stride, 176)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.offset(of: \.paged), 172)
        XCTAssertEqual(gaussianChunkCullResidencyIndex.rawValue, 8)
        XCTAssertEqual(gaussianChunkCullDemandIndex.rawValue, 9)
        XCTAssertEqual(gaussianChunkPreprocessResidencyIndex.rawValue, 13)
        XCTAssertEqual(gaussianChunkPreprocessPageTableIndex.rawValue, 14)
        XCTAssertEqual(gaussianChunkPreprocessPagingConstantsIndex.rawValue, 15)
        XCTAssertEqual(kGaussianPageSlotInvalid, 0xFFFF_FFFF)
        XCTAssertEqual(GaussianPagingPolicy.maxRanksPerPage, 256)
        // The per-chunk level bindings (per-chunk-lod-tiers).
        XCTAssertEqual(gaussianChunkCullCoarseTableIndex.rawValue, 10)
        XCTAssertEqual(gaussianChunkCullLevelStateIndex.rawValue, 11)
        XCTAssertEqual(gaussianChunkCullLevelConstantsIndex.rawValue, 12)
        XCTAssertEqual(gaussianBudgetLevelStateIndex.rawValue, 9)
        XCTAssertEqual(gaussianBudgetResidencyIndex.rawValue, 10)
        XCTAssertEqual(gaussianBudgetCoarseTableIndex.rawValue, 11)
        XCTAssertEqual(gaussianBudgetLevelConstantsIndex.rawValue, 12)
        XCTAssertEqual(gaussianBudgetChunkTableIndex.rawValue, 13)
        XCTAssertEqual(gaussianBudgetLevelTotalsIndex.rawValue, 14)
        XCTAssertEqual(gaussianChunkPreprocessCoarseRecordsIndex.rawValue, 16)
        XCTAssertEqual(gaussianChunkPreprocessCoarseTableIndex.rawValue, 17)
        XCTAssertEqual(gaussianChunkPreprocessLevelStateIndex.rawValue, 18)
        XCTAssertEqual(gaussianChunkPreprocessLevelConstantsIndex.rawValue, 19)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.stride, 48)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelState>.stride, 8)
    }

    // MARK: - 26: the file itself

    /// The 300 k slab from the file itself against a 1 MiB pool. `UNTOLD_PERF_GAUSSIAN_PAGING=1`
    /// adds 4 M and 20 M splats (`GaussianSyntheticAsset.url(splatCount:)`: minutes to bake the
    /// first time, about 3 GB of memory for the 20 M bake, cached in the temporary directory)
    /// against a 64 MiB residency budget; `UNTOLD_PERF_GAUSSIAN_PAGING_SPLAT_COUNT=<n>` keeps
    /// only the sizes up to `n` (4000000 for the 4 M run alone), as `UNTOLD_PERF_SPLAT_COUNT`
    /// does for GaussianChunkCullBenchmark. The pool is what the policy sizes it — the budget,
    /// or the whole asset when that is smaller: a 4 M asset without harmonics is 64,000,000 B,
    /// under 64 MiB, so its pool holds every tier — and the assertions follow the policy.
    func testLargeSyntheticAssetPagesWithinItsPool() throws {
        GaussianPageSourceFactory.override = nil
        try runLargeAsset(splatCount: 300_000, residencyBudgetBytes: 1 << 20, frames: 120)
        if ProcessInfo.processInfo.environment["UNTOLD_PERF_GAUSSIAN_PAGING"] == "1" {
            let cap = ProcessInfo.processInfo.environment["UNTOLD_PERF_GAUSSIAN_PAGING_SPLAT_COUNT"].flatMap { Int($0) } ?? Int.max
            for splatCount in [4_000_000, 20_000_000] where splatCount <= cap {
                try runLargeAsset(splatCount: splatCount, residencyBudgetBytes: 64 << 20, frames: 120)
            }
        }
    }

    /// The same slab with its per-chunk coarse levels (per-chunk-lod-tiers) from the file
    /// itself, against a 2 MiB budget (a pool of half the asset; the levels allowed the whole
    /// budget beside it, so both stay resident), at an orbit far enough that a chunk is a few
    /// pixels. The first tick wants every chunk it sees, so both runs saturate the pool before
    /// the section has landed (one 660 KiB piece, CRC-checked in a debug build over a few
    /// frames); from then on the section-free run keeps wanting fine tiers it cannot fit on every
    /// frame of the orbit, while the levelled run draws the chunks coarse and wants nothing more
    /// — the pool's saturation stops growing.
    func testLargeSyntheticAssetWithLevelsStopsWantingFineTiersFromAfar() throws {
        GaussianPageSourceFactory.override = nil
        GaussianPagingPolicy.fadeFrames = 16
        GaussianPagingPolicy.coarseBudgetFractionOverride = 1
        let plain = try runLargeAsset(splatCount: 300_000, residencyBudgetBytes: 2 << 20, frames: 60, orbitRadius: 200, orbitHeight: 132)
        XCTAssertNil(plain.coarseLevels)
        XCTAssertGreaterThanOrEqual(plain.residentSlots, plain.slotCount - 4, "the section-free run fills its pool")
        let levelled = try runLargeAsset(splatCount: 300_000, residencyBudgetBytes: 2 << 20, frames: 60, orbitRadius: 200, orbitHeight: 132, coarseLevels: .default)
        XCTAssertEqual(levelled.coarseLevels, 2, "both levels resident beside the pool")
        XCTAssertTrue(levelled.coarseLanded, "the section landed from the file source")
        XCTAssertGreaterThan(levelled.coarseChunksDrawn, levelled.chunkCount / 2, "most chunks draw a coarse level")
        let landed = levelled.landedFrame
        XCTAssertLessThan(landed, 40, "the section landed well inside the run")
        let plainGrowth = plain.saturatedByFrame[59] - plain.saturatedByFrame[landed]
        let levelledGrowth = levelled.saturatedByFrame[59] - levelled.saturatedByFrame[landed]
        XCTAssertGreaterThan(plainGrowth, 10 * (59 - landed), "the section-free run keeps wanting tiers it cannot fit")
        XCTAssertLessThan(levelledGrowth, plainGrowth / 4, "once the levels landed the levelled run wants little more")
        print("[GaussianPagingTest] far orbit at 2 MiB: section-free \(plain.fineReads) fine reads, saturation +\(plainGrowth) after frame \(landed); levelled \(levelled.fineReads) fine reads, saturation +\(levelledGrowth) after the section landed at frame \(landed) (tick \(levelled.landedTick)), \(levelled.coarseChunksDrawn) of \(levelled.chunkCount) chunks coarse on the last frame")
    }

    private struct LargeAssetRun {
        var chunkCount = 0
        var slotCount = 0
        var residentSlots = 0
        var coarseLevels: Int?
        var coarseLanded = false
        var landedTick: UInt32 = 0
        var landedFrame = 0
        var fineReads = 0
        var coarseChunksDrawn = 0
        /// `saturatedCandidates` after each frame.
        var saturatedByFrame: [Int] = []
    }

    /// Unloads the previous run's entity before the next load: `destroyAllEntities` alone
    /// defers the component cleanup to a frame's finalize, and a pool still in the registry
    /// leaves the next one only what the budget has left (64 MiB less a 4 M asset's
    /// 64,000,000 B is a 759-slot pool). `removeEntityGaussian` shuts the pager down and
    /// unregisters its pool at once.
    private func releaseLargeAssets() {
        for entity in fixtures where scene.exists(entity) {
            removeEntityGaussian(entityId: entity)
        }
        fixtures.removeAll()
        destroyAllEntities()
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, 0, "every pool left the registry before the next load sizes against the budget")
    }

    @discardableResult
    private func runLargeAsset(splatCount: Int, residencyBudgetBytes: Int, frames frameCount: Int, orbitRadius: Float = 6, orbitHeight: Float = 4, coarseLevels: UntoldGSCoarseLevelOptions? = nil) throws -> LargeAssetRun {
        releaseLargeAssets()
        GaussianPagingPolicy.residencyBudgetBytesOverride = residencyBudgetBytes
        GaussianPagingPolicy.minPoolSlots = 4
        let bakeStart = CFAbsoluteTimeGetCurrent()
        let url = try GaussianSyntheticAsset.url(splatCount: splatCount, coarseLevels: coarseLevels)
        // The pool the policy gives this asset: what the budget leaves (nothing is allocated),
        // capped at the asset in whole slots and at the platform maximum.
        let header = try UntoldGSFormat.readHeaderV3(from: url)
        let slotBytes = try slotBytes(of: url)
        let assetBytes = GaussianPagingPolicy.assetBytes(splatCount: Int(header.splatCount), shBytesPerSplat: header.shBytesPerSplat)
        let expectedSlots = GaussianPagingPolicy.poolSlotCount(assetBytes: assetBytes, slotBytes: slotBytes, residencyBudgetBytes: residencyBudgetBytes, allocatedBytes: 0)
        let poolHoldsTheAsset = expectedSlots * slotBytes >= assetBytes
        let entity = createEntity()
        fixtures.append(entity)
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let pager = try XCTUnwrap(component.pager)
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertTrue(pager.source is UntoldGSFilePageSource, "the file source")
        XCTAssertEqual(pager.slotCount, expectedSlots, "the pool is the budget, or the whole asset when that is smaller")
        XCTAssertEqual(pager.poolBytes, expectedSlots * slotBytes)
        XCTAssertEqual(GaussianPagePoolRegistry.shared.allocatedBytes, pager.poolBytes, "the pool is in the registry")
        pager.eventLogEnabled = true
        var run = LargeAssetRun()
        run.chunkCount = table.chunkCount
        run.coarseLevels = table.coarse?.levelCount
        XCTAssertEqual(table.coarse != nil, coarseLevels != nil, "the levelled bake carries a section that fits at least its coarsest level")
        let camera = placeGaussianTestCamera(eye: simd_float3(orbitRadius, orbitHeight, 0), target: .zero)

        var worstTickMs: Double = 0
        // The time in `renderer.draw` over the run: the wall time also holds each frame's GPU
        // wait, which grows with the resident set (a faster fill makes the wall time longer).
        var drawSeconds: Double = 0
        var sawVisible = false
        var fillFrame: Int?
        var committedSoFar = 0
        let start = CFAbsoluteTimeGetCurrent()
        for frameIndex in 0 ..< frameCount {
            let angle = Float(frameIndex) * 0.05
            cameraLookAt(entityId: camera, eye: simd_float3(orbitRadius * cos(angle), orbitHeight, orbitRadius * sin(angle)), target: .zero, up: simd_float3(0, 1, 0))
            let tickStart = CFAbsoluteTimeGetCurrent()
            renderer.draw(in: renderer.metalView)
            let tickSeconds = CFAbsoluteTimeGetCurrent() - tickStart
            drawSeconds += tickSeconds
            worstTickMs = max(worstTickMs, tickSeconds * 1000)
            renderInfo.lastCommandBuffer?.waitUntilCompleted()
            XCTAssertEqual(renderInfo.lastCommandBuffer?.status, .completed, "frame \(frameIndex)")
            XCTAssertEqual(sharedVisibleSet().overflowCount, 0, "frame \(frameIndex)")
            try assertFrameFits()
            let stats = pager.stats
            XCTAssertLessThanOrEqual(stats.residentSlots, stats.slotCount)
            XCTAssertEqual(stats.state, .active)
            XCTAssertEqual(stats.faultedChunks, 0)
            XCTAssertFalse(stats.coarseFaulted)
            if frameIndex >= 10 {
                if sharedVisibleSet().visibleCount > 0 { sawVisible = true }
            }
            committedSoFar += stats.committedThisTick
            if fillFrame == nil, committedSoFar >= Int(0.8 * Double(stats.slotCount)) { fillFrame = frameIndex }
            run.saturatedByFrame.append(stats.saturatedCandidates)
            // The levels (per-chunk-lod-tiers): the tick the section landed.
            if run.landedTick == 0, pager.coarseSectionLanded {
                run.landedTick = pager.tick
                run.landedFrame = frameIndex
                run.coarseLanded = true
            }
        }
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        let stats = pager.stats
        run.residentSlots = stats.residentSlots
        run.slotCount = stats.slotCount
        run.coarseChunksDrawn = try Int(budgetState().coarseChunks)
        run.fineReads = pager.eventLog.filter { $0.kind == .issued }.count
        let committedTiers = pager.eventLog.filter { $0.kind == .committed }.count
        let evictedTiers = pager.eventLog.filter { $0.kind == .evicted }.count
        XCTAssertEqual(committedSoFar, committedTiers, "the per-tick commit counts sum to the journal's")
        XCTAssertEqual(stats.deferredTiers, 0, "nothing landed is left unmapped at the end")
        XCTAssertTrue(sawVisible, "something drawn after the fill-in")
        XCTAssertNotNil(fillFrame, "the pool fills: 80 % of its slots were committed within the run")
        if poolHoldsTheAsset {
            // Every tier has a slot of its own: the evict-ahead never runs short, so no
            // candidate is left without a slot and nothing is ever displaced.
            XCTAssertEqual(stats.saturatedCandidates, 0, "a pool that holds the whole asset never saturates")
            XCTAssertEqual(evictedTiers, 0, "a pool that holds the whole asset never evicts")
        } else {
            XCTAssertGreaterThan(stats.saturatedCandidates, 0, "the pool is too small on purpose")
        }
        XCTAssertGreaterThan(stats.residentSlots, 0)
        assertSlotReuseInvariant(pager.eventLog)
        print(String(format: "[GaussianPagingTest] %d splats in %d chunks (%@), budget %@, pool %@ (%d slots%@): %d frames in %.2f s (%.2f s in draw), resident %@, 80 %% fill at frame %d, worst frame %.2f ms, saturated %d, committed %d tiers, evicted %d (bake+load %.1f s)%@",
                     splatCount, table.chunkCount, gaussianFormatBytes(assetBytes), gaussianFormatBytes(residencyBudgetBytes), gaussianFormatBytes(pager.poolBytes), stats.slotCount,
                     poolHoldsTheAsset ? ", the whole asset" : "", frameCount, elapsed, drawSeconds,
                     gaussianFormatBytes(stats.residentSlots * slotBytes), fillFrame ?? -1, worstTickMs, stats.saturatedCandidates,
                     committedTiers, evictedTiers, start - bakeStart,
                     table.coarse == nil ? "" : String(format: ", coarse levels %d (%@ landed %@, %d pieces, faulted %d)", stats.coarseLevels, gaussianFormatBytes(stats.coarseBytesLanded), gaussianFormatBytes(stats.coarseBytes), stats.coarseReadsIssued, stats.coarseFaulted ? 1 : 0)))
        return run
    }
}
