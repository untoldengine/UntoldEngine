//
//  GaussianChunkLevelTest.swift
//  UntoldEngine
//
//  Per-chunk coarse levels of .untoldgs v3 (per-chunk-lod-tiers): a section-free file and the
//  fine-only mode draw the frame of before, bit for bit; the coarse-only mode draws the
//  whole-buffer level twin, whole-resident and paged; a far camera draws every chunk coarse at
//  30 dB of the fine image and beats the fine prefix at the same budget; every level tag the
//  quota pass writes is the CPU mirror's over a 40-frame pull-back; the budget bound holds
//  through the transitions; a switch cross-fades the two windows with the coverage-preserving
//  weights for exactly fadeFrames frames and the band holds one tier of hysteresis; under paging
//  the coarse section streams first and a non-resident chunk draws it, a fine head arriving on a
//  coarse chunk fades in over it, chunks in the coarse regime issue no fine reads and their
//  tiers leave as surplus; frames are deterministic once the fades are done; stereo picks one
//  level per chunk from the larger eye; the fit check falls back to the coarsest level, then to
//  none; a corrupt coarse payload disables the levels for the entity while fine paging goes on;
//  the analytic cluster fixture merges to its closed-form centres; the layouts are pinned.
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
final class GaussianChunkLevelTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []
    private var fixtures: [EntityID] = []
    private var savedOptions: (hzb: Bool, chunkCull: Bool, budget: Bool, weighted: Bool, paging: Bool, freeze: Bool, pageFade: Bool, tint: Bool, mode: GaussianLevelMode, levelFade: Bool, levelTint: Bool)?
    private var savedWorkingSetOverride: Int?
    private var savedFloorOverride: Float?

    /// The slab seen from above its centre (the budget suite's camera): every chunk in view,
    /// most in the fine regime at the default density floor.
    private let slabCamera = (eye: simd_float3(0, 6, 3), target: simd_float3.zero)
    private let viewportPixels: Float = 1920 * 1080

    override func setUp() async throws {
        try await super.setUp()
        let options = GaussianDebugOptions.shared
        savedOptions = (options.disableHZBOcclusionCull, options.disableChunkCull, options.disableWorkingSetBudget, options.disableScreenWeightedQuotas, options.disablePaging, options.freezePaging, options.disablePageFade, options.residencyDebugTint, options.gaussianLevelMode, options.disableLevelCrossFade, options.levelDebugTint)
        savedWorkingSetOverride = GaussianRuntimeLimits.workingSetSplatsOverride
        savedFloorOverride = GaussianRuntimeLimits.maxSplatsPerPixelOverride
        options.disableHZBOcclusionCull = true
        options.disableChunkCull = false
        options.disableWorkingSetBudget = false
        options.disableScreenWeightedQuotas = false
        options.disablePaging = false
        options.freezePaging = false
        options.disablePageFade = false
        options.residencyDebugTint = false
        options.gaussianLevelMode = .auto
        options.disableLevelCrossFade = false
        options.levelDebugTint = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianRuntimeLimits.maxSplatsPerPixelOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        GaussianPagingPolicy.resetKnobs()
        GaussianPagingPolicy.minPoolSlots = 4
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
        }
        GaussianTestPageSource.resetCreated()
        GaussianPageSourceFactory.override = nil
        GaussianPagingPolicy.resetKnobs()
        if let saved = savedOptions {
            let options = GaussianDebugOptions.shared
            options.disableHZBOcclusionCull = saved.hzb
            options.disableChunkCull = saved.chunkCull
            options.disableWorkingSetBudget = saved.budget
            options.disableScreenWeightedQuotas = saved.weighted
            options.disablePaging = saved.paging
            options.freezePaging = saved.freeze
            options.disablePageFade = saved.pageFade
            options.residencyDebugTint = saved.tint
            options.gaussianLevelMode = saved.mode
            options.disableLevelCrossFade = saved.levelFade
            options.levelDebugTint = saved.levelTint
        }
        GaussianRuntimeLimits.workingSetSplatsOverride = savedWorkingSetOverride
        GaussianRuntimeLimits.maxSplatsPerPixelOverride = savedFloorOverride
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

    private struct Fixture {
        let url: URL
        let entity: EntityID
        let component: GaussianComponent
        let index: UntoldGSIndex
        let source: GaussianTestPageSource?

        var table: GaussianChunkTable {
            component.chunkTable!
        }

        var coarse: GaussianCoarseTable? {
            component.chunkTable?.coarse
        }

        var pager: GaussianPageManager? {
            component.pager
        }

        var chunkCount: Int {
            index.chunks.count
        }

        var splatCount: Int {
            Int(index.header.splatCount)
        }

        /// The clock the level fades count on: the pager's tick, or the executed frames.
        var frameIndex: UInt32 {
            component.pager?.tick ?? component.chunkTable?.executedFrames ?? 0
        }
    }

    private func levelledSlabURL() throws -> URL {
        try GaussianSyntheticAsset.url(splatCount: 300_000, coarseLevels: .default)
    }

    private func plainSlabURL() throws -> URL {
        try GaussianSyntheticAsset.url(splatCount: 300_000)
    }

    /// Loads `url` whole-resident (the slab is below the paging threshold).
    private func loadWhole(_ url: URL) throws -> Fixture {
        let entity = createEntity()
        fixtures.append(entity)
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        XCTAssertNil(component.pager, "whole-resident")
        return Fixture(url: url, entity: entity, component: component, index: table.index, source: nil)
    }

    /// Loads `url` paged into a pool of `poolSlots` slots with the coarse levels allowed
    /// `coarseFraction` of the residency budget (the pool is small on purpose; the levels are
    /// charged beside it), the event log on.
    private func loadPaged(_ url: URL, poolSlots: Int, coarseFraction: Double = 8, configure: (@Sendable (GaussianTestPageSource) -> Void)? = nil) throws -> Fixture {
        let header = try UntoldGSFormat.readHeaderV3(from: url)
        let slotBytes = GaussianPagingPolicy.ranksPerPage(splatsPerChunk: header.splatsPerChunk) * (UntoldGSFormat.coreRecordSize + header.shBytesPerSplat)
        GaussianPagingPolicy.pagingThresholdBytesOverride = 0
        GaussianPagingPolicy.residencyBudgetBytesOverride = poolSlots * slotBytes
        GaussianPagingPolicy.coarseBudgetFractionOverride = coarseFraction
        let entity = createEntity()
        fixtures.append(entity)
        GaussianPageSourceFactory.override = { fileURL in
            let source = try GaussianTestPageSource(url: fileURL)
            configure?(source)
            GaussianTestPageSource.record(source)
            return source
        }
        setEntityGaussian(entityId: entity, filename: url.deletingPathExtension().path, withExtension: "untoldgs")
        GaussianTestPageSource.install()
        let component = try XCTUnwrap(scene.get(component: GaussianComponent.self, for: entity))
        let table = try XCTUnwrap(component.chunkTable)
        let pager = try XCTUnwrap(component.pager, "the asset pages")
        let source = try XCTUnwrap(GaussianTestPageSource.created.last { $0.url == url })
        pager.eventLogEnabled = true
        XCTAssertEqual(pager.slotCount, poolSlots)
        return Fixture(url: url, entity: entity, component: component, index: table.index, source: source)
    }

    private func unload(_ fixture: Fixture) {
        if scene.exists(fixture.entity) {
            removeEntityGaussian(entityId: fixture.entity)
        }
        fixtures.removeAll { $0 == fixture.entity }
    }

    // MARK: - Frames

    /// Waits until every read the pager issued has landed or is blocked in the source.
    private func settle(_ fixture: Fixture, timeout: TimeInterval = 5) {
        guard let pager = fixture.pager, let source = fixture.source else { return }
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

    /// One manual frame: the cull, the quota pass and the fused pass; for a paged entity the
    /// retire ring emptied first, then a tick of the source's latency and the reads settled.
    private func frame(_ fixture: Fixture) {
        fixture.pager?.noteGPUIdle()
        runGaussianCullAndPreprocess()
        fixture.source?.advance()
        settle(fixture)
    }

    /// One full renderer frame, its splat layer returned, the reads settled.
    private func fullFrame(_ fixture: Fixture) -> [Float16] {
        fixture.pager?.noteGPUIdle()
        let image = renderGaussianSplatLayer()
        fixture.source?.advance()
        settle(fixture)
        return image
    }

    @discardableResult
    private func frames(_ fixture: Fixture, max: Int, until condition: () -> Bool) -> Int {
        var count = 0
        while count < max, !condition() {
            frame(fixture)
            count += 1
        }
        return count
    }

    private func alphaSum(_ image: [Float16]) -> Double {
        var sum = 0.0
        for i in stride(from: 3, to: image.count, by: 4) {
            sum += Double(image[i])
        }
        return sum
    }

    /// The sorted depth keys and the records (sorted by their bytes) of one frame.
    private struct Capture: Equatable {
        let depths: [UInt32]
        let records: [[UInt8]]
        let count: Int
    }

    private func capture() -> Capture {
        let depths = sortedDepthWords()
        let records = sharedGaussianRecords().map { record in withUnsafeBytes(of: record) { Array($0) } }.sorted { $0.lexicographicallyPrecedes($1) }
        return Capture(depths: depths, records: records, count: depths.count)
    }

    // MARK: - Cameras and the mirror

    /// The entity's cull constants for the active camera (mono, no HZB).
    private func cullConstants(_ fixture: Fixture) throws -> GaussianChunkCullConstants {
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
            paged: fixture.pager == nil ? 0 : 1
        )
    }

    /// The chunks the CPU mirror keeps for the active camera, with their areas (view units).
    private func mirrorAreas(_ fixture: Fixture) throws -> [Int: Float] {
        let constants = try cullConstants(fixture)
        var areas: [Int: Float] = [:]
        for (chunk, entry) in fixture.index.chunks.enumerated() {
            let area = GaussianPageManager.seedArea(entry: entry, constants: constants)
            if area > 0 { areas[chunk] = area }
        }
        return areas
    }

    /// A camera above the slab's centre on the line (0, h, 0.6 h), raised or lowered until the
    /// median visible chunk covers about `pixels` pixels of the 1920 × 1080 viewport.
    @discardableResult
    private func placeCameraWithMedianChunkPixels(_ pixels: Float, _ fixture: Fixture) throws -> (camera: EntityID, eye: simd_float3, medianPixels: Float) {
        let camera = placeGaussianTestCamera(eye: simd_float3(0, 5, 3), target: .zero)
        var low: Float = 1
        var high: Float = 450
        var best: (simd_float3, Float) = (.zero, 0)
        for _ in 0 ..< 40 {
            let height = 0.5 * (low + high)
            let eye = simd_float3(0, height, 0.6 * height)
            cameraLookAt(entityId: camera, eye: eye, target: .zero, up: simd_float3(0, 1, 0))
            let areas = try mirrorAreas(fixture).values.sorted()
            guard !areas.isEmpty else { high = height; continue }
            let median = areas[areas.count / 2] * viewportPixels
            best = (eye, median)
            if abs(median - pixels) < 0.02 * pixels { break }
            if median > pixels { low = height } else { high = height }
        }
        return (camera, best.0, best.1)
    }

    private var densityFloor: Float {
        gaussianDensityFloor(viewport: renderInfo.viewPort ?? simd_float2(1920, 1080))
    }

    /// The tier shifts of a coarse table.
    private func tierShifts(_ coarse: GaussianCoarseTable) -> (Int, Int) {
        let constants = gaussianChunkLevelConstants(coarse: coarse, frameIndex: 0, cull: GaussianChunkCullConstants())
        return (Int(constants.tierShift1), Int(constants.tierShift2))
    }

    /// The availability mask of a whole-resident chunk: fine plus every level it has a record at.
    private func availability(_ fixture: Fixture, chunk: Int) -> UInt32 {
        var mask: UInt32 = 1
        if let coarse = fixture.coarse {
            for level in 1 ... coarse.levelCount where fixture.table.coarseEntry(runtimeLevel: level, chunk: chunk) != nil {
                mask |= 1 << UInt32(level)
            }
        }
        return mask
    }

    /// The runtime levels' counts of a chunk (level 2's is level 1's with one level resident).
    private func counts(_ fixture: Fixture, chunk: Int) -> (UInt32, UInt32) {
        guard let coarse = fixture.coarse else { return (0, 0) }
        let m1 = fixture.table.coarseEntry(runtimeLevel: 1, chunk: chunk)?.splatCount ?? 0
        let m2 = coarse.levelCount > 1 ? (fixture.table.coarseEntry(runtimeLevel: 2, chunk: chunk)?.splatCount ?? 0) : m1
        return (m1, m2)
    }

    /// The count a chunk draws whole at `level` (its fine count at 0).
    private func levelCount(_ fixture: Fixture, chunk: Int, level: Int) -> UInt32 {
        let coarse = counts(fixture, chunk: chunk)
        switch level {
        case 0: return fixture.index.chunks[chunk].splatCount
        case 1: return coarse.0
        default: return coarse.1
        }
    }

    /// The mirror's quota of a chunk drawn at `level`.
    private func mirrorQuota(_ fixture: Fixture, chunk: Int, level: Int, cap: Float, area: Float) -> UInt32 {
        GaussianChunkCullMath.levelQuota(level: level, densityCap: cap, splatCount: fixture.index.chunks[chunk].splatCount, screenArea: area, counts: counts(fixture, chunk: chunk))
    }

    /// The mirror's level for a whole-resident chunk at `cap` and the frame's floor, from the
    /// level it drew last frame.
    private func mirrorLevel(_ fixture: Fixture, chunk: Int, area: Float, cap: Float, previous: Int, floor: Float? = nil) -> Int {
        guard let coarse = fixture.coarse else { return 0 }
        return GaussianChunkCullMath.level(
            densityCap: cap,
            densityFloor: floor ?? densityFloor,
            splatCount: fixture.index.chunks[chunk].splatCount,
            screenArea: area,
            previous: previous,
            available: availability(fixture, chunk: chunk),
            tierShifts: tierShifts(coarse)
        )
    }

    /// `maxSplatsPerPixel` that puts the density floor in the middle of `tier`.
    private func floorOverride(tier: Int) -> Float {
        GaussianChunkCullMath.densityTierFloor(tier) * 1.19 / viewportPixels
    }

    // MARK: - Record attribution

    /// Maps every working-set record of a frame back to the asset splat or coarse record it
    /// came from by its decoded centre (fine positions, then level 1, then level 2).
    private struct LevelResolver {
        struct Origin {
            let level: Int
            let chunk: Int
            let rank: Int
            let opacity: Float
        }

        let resolver: GaussianSplatIndexResolver
        let origins: [Origin]

        init(url: URL, index: UntoldGSIndex, levels: [Int]) throws {
            let cpu = try UntoldGSFormat.read(from: url)
            var positions = cpu.encodedSplats.map(\.position)
            var origins: [Origin] = []
            origins.reserveCapacity(positions.count)
            var cursor = 0
            for (chunkIndex, chunk) in index.chunks.enumerated() {
                for rank in 0 ..< Int(chunk.splatCount) {
                    origins.append(Origin(level: 0, chunk: chunkIndex, rank: rank, opacity: Float(cpu.encodedSplats[cursor].colorAndOpacity.w)))
                    cursor += 1
                }
            }
            let file = try UntoldGSFile(url: url)
            for level in levels where level >= 1 && level <= index.coarseLevelCount {
                for chunk in index.chunks.indices {
                    let splats = try file.decodeCoarseLevel(level: level, chunk: chunk)
                    for (rank, splat) in splats.enumerated() {
                        positions.append(splat.position)
                        origins.append(Origin(level: level, chunk: chunk, rank: rank, opacity: splat.opacity))
                    }
                }
            }
            resolver = GaussianSplatIndexResolver(positions: positions)
            self.origins = origins
        }

        /// The origin of every record; fails the test for a record that matches nothing.
        func origins(of records: [GaussianWorkingSetSplat], file: StaticString = #filePath, line: UInt = #line) -> [(record: GaussianWorkingSetSplat, origin: Origin)] {
            var result: [(GaussianWorkingSetSplat, Origin)] = []
            var unmatched = 0
            for record in records {
                if let index = resolver.index(of: record.position) {
                    result.append((record, origins[index]))
                } else {
                    unmatched += 1
                }
            }
            XCTAssertEqual(unmatched, 0, "\(unmatched) records match no splat or coarse record", file: file, line: line)
            return result
        }
    }

    // MARK: - 1: the section-free file and the fine-only mode

    /// A section-free file draws what it drew before (no coarse table, one entry per chunk, no
    /// tag bits, nothing coarse in the budget state), and the levelled file under `.fineOnly`
    /// draws bit-identical keys and records, at the unlimited and at a quarter budget.
    func testFineOnlyModeMatchesSectionFreeFile() throws {
        let plain = try loadWhole(plainSlabURL())
        XCTAssertFalse(plain.table.hasCoarse)
        XCTAssertNil(plain.coarse)
        XCTAssertEqual(plain.table.visibleChunks.first?.length, plain.chunkCount * MemoryLayout<GaussianVisibleChunk>.stride, "one entry per chunk")
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(plain)
        let unlimitedVisible = sharedGaussianVisibleCount()
        XCTAssertGreaterThan(unlimitedVisible, 10000)
        let quarter = unlimitedVisible / 4

        func frames() throws -> (unlimited: Capture, quarter: Capture, histogram: [UInt32]) {
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
            GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
            runGaussianCullAndPreprocess()
            let unlimited = capture()
            let state = try budgetState()
            XCTAssertEqual(state.coarseChunks, 0)
            XCTAssertEqual(state.coarseSplats, 0)
            XCTAssertEqual(state.transitionSplats, 0)
            GaussianRuntimeLimits.workingSetSplatsOverride = quarter
            GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
            runGaussianCullAndPreprocess()
            let truncated = capture()
            XCTAssertLessThan(try budgetState().targetScale, 1, "sanity — truncated")
            let histogram = try densityReadback()
            return (unlimited, truncated, histogram.tierArray.flatMap { [$0.splats, $0.scaledArea, $0.coarse1, $0.coarse2, $0.levelledSplats] })
        }
        let before = try frames()
        for entry in visibleChunkLevels(plain.table) {
            XCTAssertEqual(entry.level, 0)
            XCTAssertFalse(entry.outgoing)
        }
        XCTAssertEqual(before.quarter.count, sharedGaussianVisibleCount())
        unload(plain)

        let levelled = try loadWhole(levelledSlabURL())
        let coarse = try XCTUnwrap(levelled.coarse, "the levelled slab carries its section")
        XCTAssertTrue(levelled.table.hasCoarse)
        XCTAssertEqual(coarse.levelCount, 2)
        XCTAssertEqual(coarse.fileLevels, [1, 2])
        XCTAssertEqual(coarse.ratioLog2, [3, 6])
        XCTAssertEqual(levelled.table.visibleChunks.first?.length, 2 * levelled.chunkCount * MemoryLayout<GaussianVisibleChunk>.stride, "two entries per chunk")
        XCTAssertEqual(levelled.index.header.splatCount, plain.index.header.splatCount)
        XCTAssertEqual(levelled.index.chunks.map(\.crc32), plain.index.chunks.map(\.crc32), "the same fine chunks")
        GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
        let after = try frames()
        XCTAssertEqual(after.unlimited, before.unlimited, "fine only: the section-free frame, bit for bit")
        XCTAssertEqual(after.quarter, before.quarter, "and at a quarter budget")
        XCTAssertEqual(after.histogram, before.histogram, "the same histogram (binned by the drawable count, no level words)")
        for entry in visibleChunkLevels(levelled.table) {
            XCTAssertEqual(entry.level, 0, "no tag bits under fineOnly")
            XCTAssertFalse(entry.outgoing)
        }
        XCTAssertEqual(try budgetState().coarseChunks, 0)
        XCTAssertGreaterThan(before.unlimited.count, 10000)
    }

    // MARK: - 2: the coarse-only mode and the level twin

    /// `.coarseOnly` with the cross-fade off draws every chunk at level 2 — bit-identical keys
    /// and records to the level twin (the same coarse entries as a whole-resident chunk table),
    /// whole-resident and paged with every read delivered; with the cross-fade off no frame
    /// lists an outgoing window.
    func testCoarseOnlyEqualsLevelTwin() throws {
        GaussianDebugOptions.shared.gaussianLevelMode = .coarseOnly
        GaussianDebugOptions.shared.disableLevelCrossFade = true
        GaussianDebugOptions.shared.disableWorkingSetBudget = true
        let url = try levelledSlabURL()
        let whole = try loadWhole(url)
        let coarse = try XCTUnwrap(whole.coarse)
        // Straight above the slab's centre: every chunk inside the frustum, none at its edge (the
        // twin culls by the level's own box, the levelled entity by the fine box).
        placeGaussianTestCamera(eye: simd_float3(0, 14, 0.01), target: .zero)
        var listedOutgoing = 0
        for _ in 0 ..< 4 {
            frame(whole)
            listedOutgoing += visibleChunkLevels(whole.table).filter(\.outgoing).count
        }
        XCTAssertEqual(listedOutgoing, 0, "with the cross-fade off a switch lists no outgoing window")
        let entries = visibleChunkLevels(whole.table)
        XCTAssertEqual(entries.count, whole.chunkCount, "every chunk in view, one entry each")
        for entry in entries {
            XCTAssertEqual(entry.level, 2, "chunk \(entry.chunkIndex) draws the coarsest level")
            XCTAssertEqual(entry.quota, whole.table.coarseEntry(runtimeLevel: 2, chunk: Int(entry.chunkIndex))?.splatCount, "whole")
        }
        let expectedRecords = (0 ..< whole.chunkCount).reduce(0) { $0 + Int(whole.table.coarseEntry(runtimeLevel: 2, chunk: $1)?.splatCount ?? 0) }
        let levelled = capture()
        XCTAssertEqual(levelled.count, expectedRecords, "every level-2 record is drawn")
        let state = try budgetState()
        XCTAssertEqual(Int(state.coarseChunks), whole.chunkCount)
        XCTAssertEqual(Int(state.coarseSplats), expectedRecords)
        for state in levelStates(coarse, chunkCount: whole.chunkCount) {
            XCTAssertEqual(state.level, 2)
            XCTAssertNil(state.pending)
        }

        let loaded = try GaussianChunkLoader.load(url: url, allowPaging: false)
        let twin = try GaussianLevelTwin(loaded: loaded) { _ in 2 }
        XCTAssertEqual(twin.levels, Array(repeating: 2, count: whole.chunkCount))
        XCTAssertFalse(twin.table.hasCoarse)
        let twinFrame = twin.withTwinBuffers(whole.component) { capture() }
        XCTAssertEqual(twinFrame.count, levelled.count)
        XCTAssertEqual(twinFrame.depths, levelled.depths, "the same sorted depth keys as the level twin")
        XCTAssertEqual(twinFrame.records, levelled.records, "and the same records")
        unload(whole)

        // Paged, every read delivered at once, a pool holding the whole asset: the same frame
        // from the coarse records the pager streamed.
        let tiers = whole.index.chunks.reduce(0) { $0 + GaussianPagingPolicy.tiersNeeded(needed: $1.splatCount, ranksPerPage: 256) }
        let paged = try loadPaged(url, poolSlots: tiers, coarseFraction: 1)
        let pager = try XCTUnwrap(paged.pager)
        XCTAssertEqual(paged.coarse?.levelCount, 2)
        paged.source?.deliverAll()
        frames(paged, max: 40) { pager.coarseSectionLanded && pager.stats.pendingReads == 0 }
        XCTAssertTrue(pager.coarseSectionLanded)
        for _ in 0 ..< 4 {
            frame(paged)
        }
        let pagedFrame = capture()
        XCTAssertEqual(pagedFrame.depths, levelled.depths, "paged: the same keys")
        XCTAssertEqual(pagedFrame.records, levelled.records, "paged: the same records")
        for entry in visibleChunkLevels(paged.table) {
            XCTAssertEqual(entry.level, 2)
            XCTAssertFalse(entry.outgoing)
        }
    }

    // MARK: - 3: the far camera

    /// Far enough that a chunk covers a few pixels, `.auto` draws every listed chunk coarse
    /// (the density floor, the frame fits), within 30 dB of the unlimited fine image with the
    /// alpha within 10 %, and at the working-set budget the coarse frame drew, it beats the fine
    /// prefix `.fineOnly` draws at that budget.
    func testFarCameraDrawsCoarseAndBeatsThePrefix() throws {
        let fixture = try loadWhole(levelledSlabURL())
        let coarse = try XCTUnwrap(fixture.coarse)
        // A chunk covers about 17 × 17 pixels (its padded box about 300): the fine splats are
        // still above a pixel, so the fine image is a valid reference; the default floor keeps
        // every chunk fine here, and the floor lowered by six then twelve half-octaves puts them
        // all at level 1, then level 2 — the same levels a farther camera reaches at the default
        // floor, where the synthetic slab's tiny splats have already dropped below a pixel.
        let view = try placeCameraWithMedianChunkPixels(300, fixture)
        XCTAssertEqual(view.medianPixels, 300, accuracy: 30)
        let medianDensity = try mirrorAreas(fixture).values.map { 1024 / $0 }.sorted()[fixture.chunkCount / 2]
        let medianTier = GaussianChunkCullMath.densityTier(density: medianDensity)
        XCTAssertGreaterThanOrEqual(GaussianChunkCullMath.densityTier(density: densityFloor) - medianTier, -4, "sanity — fine at the default floor")

        // The reference: fine, unlimited.
        GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
        _ = fullFrame(fixture)
        let reference = fullFrame(fixture)
        let fineVisible = sharedGaussianVisibleCount()
        XCTAssertGreaterThan(fineVisible, 100_000, "sanity — the view keeps most of the slab")
        let coveredPixels = reference.indices.filter { $0 % 4 == 3 && Float(reference[$0]) > 0.001 }.count
        XCTAssertGreaterThan(coveredPixels, 4000)
        let referenceAlpha = alphaSum(reference)

        struct Outcome {
            var psnr: Float = 0
            var alphaRatio: Double = 0
            var visible = 0
            var budget = 0
        }
        func drawCoarse(level: Int, label: String) throws -> Outcome {
            GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: medianTier - (level == 1 ? 6 : 12))
            GaussianDebugOptions.shared.gaussianLevelMode = .auto
            GaussianRuntimeLimits.workingSetSplatsOverride = nil
            GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
            var image: [Float16] = []
            for _ in 0 ..< 20 {
                image = fullFrame(fixture)
                try assertFrameFits()
            }
            let entries = visibleChunkLevels(fixture.table)
            XCTAssertGreaterThan(entries.count, 200)
            XCTAssertEqual(entries.filter(\.outgoing).count, 0, "\(label): the fades are done")
            let coarseEntries = entries.filter { !$0.outgoing && $0.level != 0 }
            // The oblique view spreads the chunks' densities over a few tiers around the median:
            // the largest fifth may stay fine (or a level finer) where the floor puts the median
            // a level down.
            XCTAssertGreaterThanOrEqual(coarseEntries.count, entries.count * 8 / 10, "\(label): nearly every listed chunk draws a coarse level: \(entries.filter { $0.level == 0 }.count) fine")
            XCTAssertGreaterThanOrEqual(coarseEntries.filter { $0.level == level }.count, entries.count * 6 / 10, "\(label): most at level \(level)")
            let state = try budgetState()
            XCTAssertTrue(state.densityCap.isInfinite, "\(label): the frame fits: the floor alone chooses the levels")
            XCTAssertEqual(Int(state.coarseChunks), coarseEntries.count)
            XCTAssertLessThanOrEqual(state.coarseSplats, state.quotaSplats)
            for entry in coarseEntries {
                let expected = mirrorLevel(fixture, chunk: Int(entry.chunkIndex), area: entry.screenArea, cap: .infinity, previous: entry.level)
                XCTAssertEqual(entry.level, expected, "\(label) chunk \(entry.chunkIndex): the mirror's level at the floor")
                XCTAssertEqual(entry.quota, levelCount(fixture, chunk: Int(entry.chunkIndex), level: entry.level), "whole")
            }
            var outcome = Outcome()
            outcome.visible = sharedGaussianVisibleCount()
            outcome.budget = Int(state.quotaSplats)
            let quality = compareGaussianSplatLayers(image, reference)
            outcome.psnr = quality.psnr
            outcome.alphaRatio = alphaSum(image) / referenceAlpha
            print(String(format: "[GaussianChunkLevelTest] %@ (median chunk %.0f px): fine %d splats, coarse %d splats (%d L1, %d L2); PSNR vs fine %.2f dB over %d px, alpha ratio %.3f", label, view.medianPixels, fineVisible, outcome.visible, coarseEntries.filter { $0.level == 1 }.count, coarseEntries.filter { $0.level == 2 }.count, quality.psnr, quality.covered, outcome.alphaRatio))
            return outcome
        }
        func drawPrefix(budget: Int, label: String) throws -> Float {
            GaussianRuntimeLimits.workingSetSplatsOverride = budget
            GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
            GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
            var prefix: [Float16] = []
            for _ in 0 ..< 4 {
                prefix = fullFrame(fixture)
                try assertFrameFits()
            }
            XCTAssertLessThan(try budgetState().targetScale, 1, "\(label): sanity — the fine frame is truncated at the coarse frame's budget")
            let quality = compareGaussianSplatLayers(prefix, reference)
            print(String(format: "[GaussianChunkLevelTest] %@: fine prefix at budget %d, PSNR vs fine %.2f dB", label, budget, quality.psnr))
            return quality.psnr
        }

        // The slab's splats carry independent random colours, so the fine image at this scale is
        // colour noise a merged record can only average: level 1 measures about 22 dB against
        // it and level 2 about 20 (a capture's coherent colour merges far closer); the bounds
        // below leave two decibels. The claim of the feature is the comparison with the prefix.
        let level1 = try drawCoarse(level: 1, label: "level 1")
        XCTAssertLessThan(level1.visible, fineVisible / 2, "level 1 draws a fraction of the fine frame")
        XCTAssertGreaterThanOrEqual(level1.psnr, 20, "level 1 against the fine image")
        XCTAssertEqual(level1.alphaRatio, 1, accuracy: 0.1, "level 1 keeps the coverage within 10 %")
        let prefix1 = try drawPrefix(budget: level1.budget, label: "level 1's budget")
        XCTAssertGreaterThanOrEqual(level1.psnr, prefix1 + 1, "at the same budget level 1 beats the fine prefix by a decibel")

        let level2 = try drawCoarse(level: 2, label: "level 2")
        XCTAssertLessThan(level2.visible, level1.visible / 4)
        XCTAssertGreaterThanOrEqual(level2.psnr, 17, "level 2 (a sixty-fourth of the splats) against the fine image")
        XCTAssertEqual(level2.alphaRatio, 1, accuracy: 0.1)
        let prefix2 = try drawPrefix(budget: level2.budget, label: "level 2's budget")
        XCTAssertGreaterThanOrEqual(level2.psnr, prefix2 + 3, "at the same budget level 2 beats the fine prefix by three decibels")
        _ = coarse
    }

    // MARK: - 4: the mirror over a pull-back

    /// Over a 40-frame pull-back at a quarter budget every incoming entry's level tag is the
    /// mirror's from the frame's read-back cap, the entry's area and the state the quota pass
    /// held before the frame (the two-phase switch: a detected level is drawn one frame later),
    /// the state after the frame holds the drawn level, and every outgoing entry names the
    /// window the state was fading or about to commit.
    func testLevelChoiceMatchesMirrorForEveryEntry() throws {
        let fixture = try loadWhole(levelledSlabURL())
        let coarse = try XCTUnwrap(fixture.coarse)
        let camera = placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(fixture)
        let quarter = max(1, sharedGaussianVisibleCount() / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = quarter
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        var previousStates = levelStates(coarse, chunkCount: fixture.chunkCount)
        var checked = 0
        var coarseSeen = 0
        var outgoingSeen = 0
        var levelsSeen: Set<Int> = []
        for frameIndex in 0 ..< 40 {
            let t = Float(frameIndex) / 39
            let height = 6 + t * 70
            cameraLookAt(entityId: camera, eye: simd_float3(0, height, 0.5 * height), target: .zero, up: simd_float3(0, 1, 0))
            frame(fixture)
            try assertFrameFits()
            let state = try budgetState()
            let clock = fixture.frameIndex
            let states = levelStates(coarse, chunkCount: fixture.chunkCount)
            for entry in visibleChunkLevels(fixture.table) {
                let chunk = Int(entry.chunkIndex)
                let before = previousStates[chunk]
                if entry.outgoing {
                    outgoingSeen += 1
                    let expectedLevel = before.pending != nil ? before.level : before.outLevel
                    XCTAssertEqual(entry.level, expectedLevel, "frame \(frameIndex) chunk \(chunk): the outgoing entry names the window being replaced or fading")
                    XCTAssertTrue(before.pending != nil || before.isFading(frame: clock, fadeFrames: GaussianPagingPolicy.fadeFrames), "frame \(frameIndex) chunk \(chunk): an outgoing entry only for a pending or fading chunk")
                    continue
                }
                let wanted = mirrorLevel(fixture, chunk: chunk, area: entry.screenArea, cap: state.densityCap, previous: before.level)
                let drawn = before.pending == wanted ? wanted : before.level
                XCTAssertEqual(entry.level, drawn, "frame \(frameIndex) chunk \(chunk): cap \(state.densityCap) area \(entry.screenArea) previous \(before.level) pending \(before.pending.map(String.init) ?? "none") wanted \(wanted)")
                XCTAssertEqual(states[chunk].level, drawn, "frame \(frameIndex) chunk \(chunk): the state holds the drawn level")
                if wanted != drawn {
                    XCTAssertEqual(states[chunk].pending, wanted, "frame \(frameIndex) chunk \(chunk): a detected switch is pending")
                } else {
                    XCTAssertNil(states[chunk].pending)
                }
                // The detection frame of a switch to a coarser level caps the old window at the
                // new level's quota; every other frame draws the level's own quota at the cap.
                var expectedQuota = mirrorQuota(fixture, chunk: chunk, level: drawn, cap: state.densityCap, area: entry.screenArea)
                if wanted > drawn {
                    expectedQuota = min(expectedQuota, mirrorQuota(fixture, chunk: chunk, level: wanted, cap: state.densityCap, area: entry.screenArea))
                }
                XCTAssertEqual(entry.quota, expectedQuota, "frame \(frameIndex) chunk \(chunk): the level's quota at the cap")
                if drawn != 0 { coarseSeen += 1 }
                levelsSeen.insert(drawn)
                checked += 1
            }
            previousStates = states
        }
        XCTAssertGreaterThan(checked, 2000)
        XCTAssertGreaterThan(coarseSeen, 100, "the pull-back reaches the coarse regime")
        XCTAssertGreaterThan(outgoingSeen, 0, "and switches fade")
        XCTAssertEqual(levelsSeen, [0, 1, 2], "every level was drawn")
    }

    // MARK: - 5: the budget bound through transitions

    /// A 60-frame pull-back and push-in at a quarter budget: every frame fits, switching frames
    /// reserve their outgoing windows, and the quota sum (outgoing windows included) never
    /// exceeds the grant.
    func testBudgetBoundHoldsThroughTransitions() throws {
        let fixture = try loadWhole(levelledSlabURL())
        let camera = placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(fixture)
        let quarter = max(1, sharedGaussianVisibleCount() / 4)
        GaussianRuntimeLimits.workingSetSplatsOverride = quarter
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        var transitions = 0
        var coarseFrames = 0
        var maxTransition: UInt32 = 0
        for frameIndex in 0 ..< 60 {
            let t = frameIndex < 30 ? Float(frameIndex) / 29 : Float(59 - frameIndex) / 29
            let height = 6 + t * 60
            cameraLookAt(entityId: camera, eye: simd_float3(0, height, 0.5 * height), target: .zero, up: simd_float3(0, 1, 0))
            frame(fixture)
            try assertFrameFits()
            let state = try budgetState()
            let set = sharedVisibleSet()
            XCTAssertLessThanOrEqual(Int(state.quotaSplats) + Int(state.reservedSplats), Int(state.budget), "frame \(frameIndex): the quotas fit the budget")
            XCTAssertLessThanOrEqual(Int(set.visibleCount), Int(state.quotaSplats), "frame \(frameIndex)")
            let outgoing = visibleChunkLevels(fixture.table).filter(\.outgoing)
            let reserved = outgoing.reduce(0) { $0 + Int($1.splatCount) }
            XCTAssertEqual(Int(state.transitionSplats), reserved, "frame \(frameIndex): the reserved windows are the listed outgoing entries")
            if state.transitionSplats > 0 { transitions += 1 }
            if state.coarseChunks > 0 { coarseFrames += 1 }
            maxTransition = max(maxTransition, state.transitionSplats)
            XCTAssertLessThanOrEqual(Int(state.coarseSplats), Int(state.quotaSplats))
        }
        XCTAssertGreaterThan(transitions, 0, "switches reserved their windows")
        XCTAssertGreaterThan(coarseFrames, 10, "the far end draws coarse")
        print("[GaussianChunkLevelTest] transitions on \(transitions) of 60 frames, coarse on \(coarseFrames), largest reservation \(maxTransition) splats at budget \(quarter)")
    }

    // MARK: - 6: the cross-fade and the hysteresis

    /// Under a static camera the density floor is stepped so that a set of chunks goes from
    /// fine to level 1: the detection frame caps their fine window at the level-1 count, the next
    /// frame commits and both windows are listed for exactly fadeFrames frames — the incoming
    /// records at 1 − (1 − α)^w and the outgoing at 1 − (1 − α)^(1 − w) — then one entry; two
    /// identical frames after the fade are bit-identical; stepping the floor back by one tier does
    /// not re-switch (the band), by two it does.
    func testSwitchIsCoverageFading() throws {
        let fixture = try loadWhole(levelledSlabURL())
        let coarse = try XCTUnwrap(fixture.coarse)
        let shifts = tierShifts(coarse)
        let fadeFrames = GaussianPagingPolicy.fadeFrames
        XCTAssertEqual(fadeFrames, 16)
        try placeCameraWithMedianChunkPixels(600, fixture)
        let areas = try mirrorAreas(fixture)
        XCTAssertGreaterThan(areas.count, 200)
        // The median chunk's density tier; floors that put it at Δ = −1 (fine), −(s1 + 1) (just
        // inside level 1), then one and two tiers back up.
        let medianDensity = areas.values.map { 1024 / $0 }.sorted()[areas.count / 2]
        let medianTier = GaussianChunkCullMath.densityTier(density: medianDensity)
        let fineTier = medianTier - 1
        let coarseTier = medianTier - shifts.0 - 1
        XCTAssertGreaterThan(coarseTier, 2)
        func setFloor(tier: Int) {
            GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: tier)
            XCTAssertEqual(GaussianChunkCullMath.densityTier(density: densityFloor), tier)
        }
        func chunkLevels(at tier: Int, previous: Int) -> [Int: Int] {
            let floor = GaussianChunkCullMath.densityTierFloor(tier) * 1.19
            return areas.mapValues { area in
                GaussianChunkCullMath.level(densityCap: .infinity, densityFloor: floor, splatCount: 1024, screenArea: area, previous: previous, available: 7, tierShifts: shifts)
            }
        }
        // The chunks the rule keeps fine at the fine floor and sends to level 1 at the coarse floor.
        let switching = Set(chunkLevels(at: fineTier, previous: 0).filter { $0.value == 0 }.keys).intersection(chunkLevels(at: coarseTier, previous: 0).filter { $0.value == 1 }.keys)
        XCTAssertGreaterThan(switching.count, 50, "sanity — a good set of chunks switches")
        let resolver = try LevelResolver(url: fixture.url, index: fixture.index, levels: [1])

        setFloor(tier: fineTier)
        for _ in 0 ..< 3 {
            frame(fixture)
        }
        func m1(_ chunk: Int) -> UInt32 {
            counts(fixture, chunk: chunk).0
        }
        func n(_ chunk: Int) -> UInt32 {
            fixture.index.chunks[chunk].splatCount
        }
        let reservedWhileFading = switching.reduce(UInt32(0)) { $0 + m1($1) }
        let fineEntries = Dictionary(uniqueKeysWithValues: visibleChunkLevels(fixture.table).map { ($0.chunkIndex, $0) })
        for chunk in switching {
            let entry = try XCTUnwrap(fineEntries[UInt32(chunk)])
            XCTAssertEqual(entry.level, 0)
            XCTAssertEqual(entry.quota, n(chunk), "unlimited: whole")
        }
        let fineImage = fullFrame(fixture)

        // Step down: the detection frame.
        setFloor(tier: coarseTier)
        frame(fixture)
        var states = levelStates(coarse, chunkCount: fixture.chunkCount)
        var byChunk = Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
        for chunk in switching {
            let entries = try XCTUnwrap(byChunk[UInt32(chunk)])
            XCTAssertEqual(entries.count, 1, "chunk \(chunk): detection lists one entry")
            XCTAssertEqual(entries[0].level, 0, "still drawn fine")
            XCTAssertEqual(entries[0].quota, m1(chunk), "capped at the level-1 count")
            XCTAssertEqual(states[chunk].pending, 1)
            XCTAssertEqual(states[chunk].outCount, m1(chunk))
        }
        XCTAssertEqual(try budgetState().transitionSplats, 0, "nothing reserved yet")
        let detectionImage = fullFrame(fixture)
        // The full frame above committed the switch: from here the fade runs on the frame clock.
        states = levelStates(coarse, chunkCount: fixture.chunkCount)
        let firstSwitching = try XCTUnwrap(switching.first)
        let switchFrame = states[firstSwitching].switchFrame
        for chunk in switching {
            XCTAssertEqual(states[chunk].level, 1, "chunk \(chunk): committed")
            XCTAssertEqual(states[chunk].outLevel, 0)
            XCTAssertEqual(states[chunk].outCount, m1(chunk))
            XCTAssertEqual(states[chunk].switchFrame, switchFrame, "every switching chunk committed on the same frame")
            XCTAssertNil(states[chunk].pending)
        }
        XCTAssertEqual(switchFrame, fixture.frameIndex)

        // The fade: both windows for fadeFrames frames from the commit frame, the records at the
        // coverage weights.
        var alphaTrajectory: [Double] = [alphaSum(detectionImage)]
        var fadeFramesSeen = 0
        var checkedRecords = 0
        for step in 0 ..< Int(fadeFrames) + 2 {
            // The commit frame was the full frame above; every later step renders one more.
            if step > 0 { alphaTrajectory.append(alphaSum(fullFrame(fixture))) }
            let frameCounter = fixture.frameIndex
            let elapsed = frameCounter &- switchFrame
            XCTAssertEqual(elapsed, UInt32(step))
            let fading = elapsed < fadeFrames
            byChunk = Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
            for chunk in switching {
                let entries = try XCTUnwrap(byChunk[UInt32(chunk)])
                if fading {
                    XCTAssertEqual(entries.count, 2, "chunk \(chunk) at \(elapsed) frames past the switch: both windows")
                    let incoming = try XCTUnwrap(entries.first { !$0.outgoing })
                    let outgoing = try XCTUnwrap(entries.first(where: \.outgoing))
                    XCTAssertEqual(incoming.level, 1)
                    XCTAssertEqual(incoming.quota, m1(chunk))
                    XCTAssertEqual(outgoing.level, 0)
                    XCTAssertEqual(outgoing.quota, m1(chunk))
                } else {
                    XCTAssertEqual(entries.count, 1, "chunk \(chunk) at \(elapsed) frames past the switch: the fade is over")
                    XCTAssertEqual(entries[0].level, 1)
                }
            }
            if fading { fadeFramesSeen += 1 }
            let weight = GaussianChunkCullMath.fadeWeight(frame: frameCounter, switchFrame: switchFrame, fadeFrames: fadeFrames)
            XCTAssertEqual(try budgetState().transitionSplats, fading ? reservedWhileFading : 0, "the outgoing windows are reserved while fading")
            // Every sixteenth record: the frame holds some 300 k and the resolver is a hash per record.
            let sampled = sharedGaussianRecords().enumerated().filter { $0.offset % 16 == 0 }.map(\.element)
            for (record, origin) in resolver.origins(of: sampled) where switching.contains(origin.chunk) {
                let expected: Float
                let count = m1(origin.chunk)
                if origin.level == 1 {
                    let full = origin.opacity * GaussianChunkCullMath.opacityBandFactor(rank: UInt32(origin.rank), quota: count, splatCount: count)
                    expected = fading ? GaussianChunkCullMath.coverageWeight(alpha: full, weight: weight) : full
                } else {
                    XCTAssertTrue(fading, "a fine record of chunk \(origin.chunk) after the fade")
                    XCTAssertLessThan(UInt32(origin.rank), count, "the outgoing window is the first m1 ranks")
                    let full = origin.opacity * GaussianChunkCullMath.opacityBandFactor(rank: UInt32(origin.rank), quota: count, splatCount: n(origin.chunk))
                    expected = GaussianChunkCullMath.coverageWeight(alpha: full, weight: 1 - weight)
                }
                XCTAssertEqual(record.conicAndOpacity.w, expected, accuracy: 3e-3, "chunk \(origin.chunk) level \(origin.level) rank \(origin.rank) at weight \(weight)")
                checkedRecords += 1
            }
        }
        XCTAssertEqual(fadeFramesSeen, Int(fadeFrames), "both windows for exactly fadeFrames frames")
        XCTAssertGreaterThan(checkedRecords, 1000)
        // The coverage: the composite transmittance of a surface both windows cover is 1 − α
        // at every weight, so the frame's alpha stays flat across the fade (the detection frame,
        // the fine window cut to the level-1 count, is the fade's own starting point).
        let coarseImage = fullFrame(fixture)
        let endpoints = (min(alphaTrajectory[0], alphaSum(coarseImage)), max(alphaTrajectory[0], alphaSum(coarseImage)))
        for (i, alpha) in alphaTrajectory.enumerated() {
            XCTAssertGreaterThanOrEqual(alpha, endpoints.0 * 0.95, "frame \(i) of the fade: the coverage stays within 5 %")
            XCTAssertLessThanOrEqual(alpha, endpoints.1 * 1.05, "frame \(i) of the fade: the coverage stays within 5 %")
        }
        XCTAssertEqual(alphaSum(coarseImage) / alphaSum(fineImage), 1, accuracy: 0.05, "level 1 keeps the fine frame's coverage")
        print(String(format: "[GaussianChunkLevelTest] fade of %d chunks: alpha fine %.0f, detection %.0f, level 1 %.0f; trajectory %@", switching.count, alphaSum(fineImage), alphaTrajectory[0], alphaSum(coarseImage), alphaTrajectory.map { String(format: "%.0f", $0) }.joined(separator: " ")))

        // Determinism after the fade.
        let first = capture()
        let second = capture()
        XCTAssertEqual(first, second, "two identical frames after the fade are bit-identical")

        // The band: one tier back up keeps level 1 (finer needs one more tier), two switch back.
        setFloor(tier: coarseTier + 1)
        for _ in 0 ..< 3 {
            frame(fixture)
        }
        states = levelStates(coarse, chunkCount: fixture.chunkCount)
        byChunk = Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
        for chunk in switching {
            XCTAssertEqual(states[chunk].level, 1, "chunk \(chunk): one tier inside the band stays at level 1")
            XCTAssertNil(states[chunk].pending)
            XCTAssertEqual(byChunk[UInt32(chunk)]?.count, 1)
        }
        setFloor(tier: coarseTier + 2)
        frame(fixture)
        frame(fixture)
        states = levelStates(coarse, chunkCount: fixture.chunkCount)
        byChunk = Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
        for chunk in switching {
            XCTAssertEqual(states[chunk].level, 0, "chunk \(chunk): two tiers past the band switches back to fine")
            XCTAssertEqual(states[chunk].outLevel, 1)
            XCTAssertEqual(byChunk[UInt32(chunk)]?.count, 2, "fading back")
        }
    }

    /// One listed entry of a frame, for comparing two histories.
    private struct Listed: Hashable, Comparable {
        let chunk: UInt32
        let outgoing: Bool
        let level: Int
        let splatCount: UInt32
        let quota: UInt32

        static func < (a: Listed, b: Listed) -> Bool {
            (a.chunk, a.outgoing ? 1 : 0) < (b.chunk, b.outgoing ? 1 : 0)
        }

        init(_ entry: GaussianVisibleChunkLevelEntry) {
            chunk = entry.chunkIndex
            outgoing = entry.outgoing
            level = entry.level
            splatCount = entry.splatCount
            quota = entry.quota
        }
    }

    /// The outgoing entry's grant is a function of the pre-commit state alone, whatever slots
    /// the cull's atomics handed the two entries of a chunk — the quota pass reads every
    /// outgoing entry before any incoming entry writes the state: a pending the floor moved
    /// past before its commit (fine → level 1 detected, level 2 wanted the next frame) grants
    /// the listed fine window nothing, so the fine ranks are not drawn twice that frame; a fade
    /// cut by a new detection keeps the old window's count for the frame; and the same history
    /// gives the same entries and records, run twice from a fresh load.
    func testOutgoingWindowsAreGrantedFromThePreCommitState() throws {
        struct Outcome: Equatable {
            let replaced: [Listed]
            let replacedRecords: Capture
            let committed: [Listed]
            let cut: [Listed]
            let cutRecords: Capture
        }
        func run() throws -> Outcome {
            GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
            let fixture = try loadWhole(levelledSlabURL())
            defer { unload(fixture) }
            let coarse = try XCTUnwrap(fixture.coarse)
            let shifts = tierShifts(coarse)
            let fadeFrames = GaussianPagingPolicy.fadeFrames
            try placeCameraWithMedianChunkPixels(600, fixture)
            let areas = try mirrorAreas(fixture)
            let medianDensity = areas.values.map { 1024 / $0 }.sorted()[areas.count / 2]
            let medianTier = GaussianChunkCullMath.densityTier(density: medianDensity)
            let fineTier = medianTier - 1
            let level1Tier = medianTier - shifts.0 - 1
            let level2Tier = medianTier - shifts.1 - 1
            XCTAssertGreaterThan(level2Tier, 2)
            func setFloor(tier: Int) {
                GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: tier)
            }
            func chunkLevels(at tier: Int) -> [Int: Int] {
                let floor = GaussianChunkCullMath.densityTierFloor(tier) * 1.19
                return areas.mapValues { area in
                    GaussianChunkCullMath.level(densityCap: .infinity, densityFloor: floor, splatCount: 1024, screenArea: area, previous: 0, available: 7, tierShifts: shifts)
                }
            }
            // The chunks fine at the fine floor, level 1 at the level-1 floor, level 2 at the level-2 floor.
            let switching = Set(chunkLevels(at: fineTier).filter { $0.value == 0 }.keys)
                .intersection(chunkLevels(at: level1Tier).filter { $0.value == 1 }.keys)
                .intersection(chunkLevels(at: level2Tier).filter { $0.value == 2 }.keys)
            XCTAssertGreaterThan(switching.count, 20, "sanity — a good set of chunks steps through both levels")
            func m1(_ chunk: Int) -> UInt32 {
                counts(fixture, chunk: chunk).0
            }
            func m2(_ chunk: Int) -> UInt32 {
                counts(fixture, chunk: chunk).1
            }
            func listed() -> [Listed] {
                visibleChunkLevels(fixture.table).filter { switching.contains(Int($0.chunkIndex)) }.map(Listed.init).sorted()
            }
            func byChunk() -> [UInt32: [GaussianVisibleChunkLevelEntry]] {
                Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
            }

            // A pending replaced before its commit: fine → level 1 detected, then level 2
            // wanted on the frame the cull listed and reserved the fine window.
            setFloor(tier: fineTier)
            for _ in 0 ..< 3 {
                frame(fixture)
            }
            setFloor(tier: level1Tier)
            frame(fixture)
            var states = levelStates(coarse, chunkCount: fixture.chunkCount)
            for chunk in switching {
                XCTAssertEqual(states[chunk].pending, 1, "chunk \(chunk): level 1 detected")
                XCTAssertEqual(states[chunk].outCount, m1(chunk))
            }
            setFloor(tier: level2Tier)
            let replacedRecords = capture() // runs the frame
            states = levelStates(coarse, chunkCount: fixture.chunkCount)
            var entries = byChunk()
            for chunk in switching {
                let pair = try XCTUnwrap(entries[UInt32(chunk)])
                XCTAssertEqual(pair.count, 2, "chunk \(chunk): the reserved fine window is listed beside the incoming entry")
                let incoming = try XCTUnwrap(pair.first { !$0.outgoing })
                let outgoing = try XCTUnwrap(pair.first(where: \.outgoing))
                XCTAssertEqual(incoming.level, 0, "still drawn fine")
                XCTAssertEqual(incoming.quota, m2(chunk), "capped at the level-2 count the solve charged")
                XCTAssertEqual(outgoing.level, 0)
                XCTAssertEqual(outgoing.splatCount, m1(chunk), "the window the cull reserved for the level-1 switch")
                XCTAssertEqual(outgoing.quota, 0, "chunk \(chunk): a pending the floor moved past grants the listed window nothing")
                XCTAssertEqual(states[chunk].level, 0)
                XCTAssertEqual(states[chunk].pending, 2, "the pending is replaced, not committed")
                XCTAssertEqual(states[chunk].outCount, m2(chunk))
            }
            let replaced = listed()
            frame(fixture)
            states = levelStates(coarse, chunkCount: fixture.chunkCount)
            entries = byChunk()
            for chunk in switching {
                let pair = try XCTUnwrap(entries[UInt32(chunk)])
                XCTAssertEqual(pair.count, 2)
                XCTAssertEqual(pair.first { !$0.outgoing }?.level, 2, "chunk \(chunk): committed to level 2")
                XCTAssertEqual(pair.first { !$0.outgoing }?.quota, m2(chunk))
                XCTAssertEqual(pair.first(where: \.outgoing)?.level, 0)
                XCTAssertEqual(pair.first(where: \.outgoing)?.quota, m2(chunk), "the fine window fades out at the level-2 count")
                XCTAssertEqual(states[chunk].level, 2)
                XCTAssertEqual(states[chunk].outLevel, 0)
                XCTAssertNil(states[chunk].pending)
            }
            let committed = listed()

            // Back to fine (a direct level 2 → fine switch, faded), then a fade cut by a new
            // detection: fine → level 1 committed and fading, level 2 wanted two frames later.
            setFloor(tier: fineTier)
            for _ in 0 ..< Int(fadeFrames) + 4 {
                frame(fixture)
            }
            states = levelStates(coarse, chunkCount: fixture.chunkCount)
            for chunk in switching {
                XCTAssertEqual(states[chunk].level, 0, "chunk \(chunk): fine again")
                XCTAssertFalse(states[chunk].isFading(frame: fixture.frameIndex, fadeFrames: fadeFrames))
            }
            setFloor(tier: level1Tier)
            frame(fixture) // detect
            frame(fixture) // commit
            frame(fixture)
            states = levelStates(coarse, chunkCount: fixture.chunkCount)
            for chunk in switching {
                XCTAssertEqual(states[chunk].level, 1)
                XCTAssertEqual(states[chunk].outLevel, 0, "chunk \(chunk): the fine window is fading")
                XCTAssertEqual(states[chunk].outCount, m1(chunk))
            }
            setFloor(tier: level2Tier)
            let cutRecords = capture() // runs the frame
            states = levelStates(coarse, chunkCount: fixture.chunkCount)
            entries = byChunk()
            for chunk in switching {
                let pair = try XCTUnwrap(entries[UInt32(chunk)])
                XCTAssertEqual(pair.count, 2, "chunk \(chunk): the fading fine window is listed beside the level-1 entry")
                let incoming = try XCTUnwrap(pair.first { !$0.outgoing })
                let outgoing = try XCTUnwrap(pair.first(where: \.outgoing))
                XCTAssertEqual(incoming.level, 1)
                XCTAssertEqual(incoming.quota, m2(chunk), "capped at the level-2 count")
                XCTAssertEqual(outgoing.level, 0)
                XCTAssertEqual(outgoing.quota, m1(chunk), "chunk \(chunk): the cut fade keeps the old window's count for the frame")
                XCTAssertEqual(states[chunk].level, 1)
                XCTAssertNil(states[chunk].outLevel, "the running fade is cut by the detection")
                XCTAssertEqual(states[chunk].pending, 2)
                XCTAssertEqual(states[chunk].outCount, m2(chunk))
            }
            let cut = listed()
            frame(fixture)
            entries = byChunk()
            for chunk in switching {
                let pair = try XCTUnwrap(entries[UInt32(chunk)])
                XCTAssertEqual(pair.first { !$0.outgoing }?.level, 2, "chunk \(chunk): committed to level 2")
                XCTAssertEqual(pair.first(where: \.outgoing)?.level, 1, "level 1 is the outgoing window now")
                XCTAssertEqual(pair.first(where: \.outgoing)?.quota, m2(chunk))
            }
            try assertFrameFits()
            return Outcome(replaced: replaced, replacedRecords: replacedRecords, committed: committed, cut: cut, cutRecords: cutRecords)
        }
        let first = try run()
        let second = try run()
        XCTAssertEqual(first.replaced, second.replaced, "the replaced-pending frame lists the same grants")
        XCTAssertEqual(first.replacedRecords, second.replacedRecords, "and draws the same records")
        XCTAssertEqual(first.committed, second.committed)
        XCTAssertEqual(first.cut, second.cut, "the cut-fade frame lists the same grants")
        XCTAssertEqual(first.cutRecords, second.cutRecords, "and draws the same records")
        XCTAssertGreaterThan(first.replacedRecords.count, 1000)
    }

    // MARK: - 7: coarse-first under paging

    /// Every fine read held: frame 1 lists nothing (as before), the coarse section streams
    /// coarsest level first in pieces and every visible chunk is then listed and drawn at its
    /// finest landed level with nothing fine resident; releasing the reads lands the heads,
    /// which fade in over the coarse windows (two entries per chunk), and once the fades are
    /// done the fine-only frame of the resident set is the partial twin's.
    func testCoarseFirstUnderPaging() throws {
        GaussianPagingPolicy.fadeFrames = 16
        GaussianPagingPolicy.maxPageBytesInFlight = 256 << 10
        // Held reads keep their worker: two a tick keeps them under the 64 workers for the run,
        // so the pieces queued behind them still get one.
        GaussianPagingPolicy.maxPageReadsPerTick = 2
        let url = try levelledSlabURL()
        let index = try UntoldGSFile(url: url).index
        let chunkCount = index.chunks.count
        let fixture = try loadPaged(url, poolSlots: 400) { source in
            source.holdChunks = Set(0 ..< chunkCount)
        }
        let pager = try XCTUnwrap(fixture.pager)
        let source = try XCTUnwrap(fixture.source)
        let coarse = try XCTUnwrap(fixture.coarse)
        XCTAssertEqual(coarse.levelCount, 2)
        XCTAssertGreaterThan(pager.coarsePieces.count, 3, "several pieces: \(pager.coarsePieces.count)")
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)

        frame(fixture)
        XCTAssertEqual(visibleChunkEntries(fixture.table).record.threadgroupCount, 0, "frame 1: nothing resident, nothing landed, nothing listed")
        XCTAssertEqual(sharedVisibleSet().visibleCount, 0)
        let used = frames(fixture, max: 30) { pager.coarseSectionLanded }
        XCTAssertTrue(pager.coarseSectionLanded, "the section landed within \(used) more frames")
        XCTAssertEqual(pager.stats.residentChunks, 0, "every fine read is held")
        // The pieces go out in file order, the coarsest level first (the request log is in the
        // workers' order, so the order is read off the pager's events and the pieces themselves).
        let coarseReads = source.requestLog.filter(\.isCoarse)
        XCTAssertEqual(coarseReads.count, pager.coarsePieces.count)
        let issuedPieces = pager.eventLog.filter { $0.kind == .coarseIssued }.map(\.tier)
        XCTAssertEqual(issuedPieces, Array(0 ..< pager.coarsePieces.count), "the pieces are issued in order")
        XCTAssertEqual(pager.coarsePieces.first?.fileOffset, index.coarseLevelRange(level: 2)?.lowerBound, "the first piece starts at level 2")
        XCTAssertEqual(pager.coarsePieces.last?.end, index.coarseLevelRange(level: 1)?.upperBound, "the last ends level 1")
        let level2End = try XCTUnwrap(index.coarseLevelRange(level: 2)).upperBound
        let piecesInLevel2 = pager.coarsePieces.filter { $0.fileOffset < level2End }.count
        XCTAssertEqual(coarseReads.filter { $0.coarseLevel == 2 }.count, piecesInLevel2, "the pieces starting in level 2 were read as level 2")
        XCTAssertEqual(coarseReads.filter { $0.coarseLevel == 1 }.count, pager.coarsePieces.count - piecesInLevel2)
        let issueTicks = pager.eventLog.filter { $0.kind == .coarseIssued }.map(\.tick)
        XCTAssertEqual(issueTicks.filter { $0 == 1 }.count, 2, "two pieces at the first tick fill the in-flight cap, level 2 among them")
        XCTAssertEqual(pager.eventLog.filter { $0.kind == .coarseCommitted }.count, pager.coarsePieces.count)
        XCTAssertEqual(pager.stats.coarseBytesLanded, coarse.recordBytes)
        for chunk in 0 ..< chunkCount where index.coarseEntry(level: 2, chunk: chunk) != nil {
            XCTAssertEqual(pager.coarseAvailable(of: chunk), 3, "chunk \(chunk): both levels available")
        }
        let fineReads = source.requestLog.filter(\.isFine)
        XCTAssertEqual(fineReads.count, source.blockedReads, "every fine read is blocked in the source")

        // Level 2 landed first and was drawn; level 1 then replaced it chunk by chunk with a
        // fade. Once those fades are done every visible chunk draws level 1 whole.
        var sawLevel2 = false
        var sawSwitch = false
        for _ in 0 ..< Int(GaussianPagingPolicy.fadeFrames) + 3 {
            frame(fixture)
            let listed = visibleChunkLevels(fixture.table)
            if listed.contains(where: { !$0.outgoing && $0.level == 2 }) { sawLevel2 = true }
            if listed.contains(where: { $0.outgoing && $0.level == 2 }) { sawSwitch = true }
            XCTAssertEqual(listed.filter { !$0.outgoing && $0.level == 0 }.count, 0, "nothing fine is resident")
            try assertFrameFits()
        }
        XCTAssertTrue(sawSwitch, "chunks drawn at level 2 switched to level 1 with the coarse window outgoing")
        _ = sawLevel2
        XCTAssertEqual(pager.stats.residentChunks, 0, "still nothing fine")
        let entries = visibleChunkLevels(fixture.table)
        XCTAssertGreaterThan(entries.count, 200)
        var expectedRecords = 0
        for entry in entries {
            XCTAssertFalse(entry.outgoing, "chunk \(entry.chunkIndex): the fades are done")
            XCTAssertEqual(entry.level, 1, "chunk \(entry.chunkIndex): the finest landed level with nothing fine resident")
            expectedRecords += Int(entry.quota)
            XCTAssertEqual(entry.quota, index.coarseEntry(level: 1, chunk: Int(entry.chunkIndex))?.splatCount)
        }
        let drawn = sharedGaussianVisibleCount()
        XCTAssertGreaterThan(drawn, expectedRecords / 2)
        XCTAssertLessThanOrEqual(drawn, expectedRecords)
        XCTAssertEqual(try Int(budgetState().coarseChunks), entries.count)
        try assertFrameFits()

        // Release the heads: they land, and fade in over the coarse windows.
        GaussianPagingPolicy.maxPageReadsPerTick = 64
        source.deliverAll()
        var sawTwoEntries = false
        for _ in 0 ..< 6 {
            frame(fixture)
            let byChunk = Dictionary(grouping: visibleChunkLevels(fixture.table), by: \.chunkIndex)
            for (chunk, chunkEntries) in byChunk where chunkEntries.count == 2 {
                sawTwoEntries = true
                let incoming = try XCTUnwrap(chunkEntries.first { !$0.outgoing })
                let outgoing = try XCTUnwrap(chunkEntries.first(where: \.outgoing))
                XCTAssertEqual(incoming.level, 0, "chunk \(chunk): the fine head incoming")
                XCTAssertEqual(outgoing.level, 1, "chunk \(chunk): the coarse window outgoing")
                XCTAssertEqual(outgoing.quota, index.coarseEntry(level: 1, chunk: Int(chunk))?.splatCount)
            }
            try assertFrameFits()
        }
        XCTAssertTrue(sawTwoEntries, "a head arriving over a coarse level lists both windows")
        XCTAssertGreaterThan(pager.stats.residentChunks, 0)
        frames(fixture, max: 30) { pager.stats.pendingReads == 0 && pager.stats.issuedThisTick == 0 }
        for _ in 0 ..< Int(GaussianPagingPolicy.fadeFrames) + 2 {
            frame(fixture)
        }
        XCTAssertEqual(visibleChunkLevels(fixture.table).filter(\.outgoing).count, 0, "the fades are done")

        // The resident set frozen, fine only: the partial twin's frame.
        GaussianDebugOptions.shared.freezePaging = true
        GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
        frame(fixture)
        frame(fixture)
        var residentRanks: [Int: Int] = [:]
        for chunk in 0 ..< chunkCount {
            residentRanks[chunk] = Int(pager.residentRanks(of: chunk))
        }
        XCTAssertGreaterThanOrEqual(residentRanks.values.filter { $0 > 0 }.count, 100)
        let whole = try GaussianChunkLoader.load(url: url, allowPaging: false)
        let twin = try GaussianPartialTwin(loaded: whole, residentRanks: residentRanks)
        let pagedImage = renderGaussianSplatLayer()
        let twinImage = twin.withLegacyBuffers(fixture.component) { renderGaussianSplatLayer() }
        let comparison = compareGaussianSplatLayers(pagedImage, twinImage)
        XCTAssertGreaterThan(comparison.covered, 1000)
        XCTAssertLessThanOrEqual(comparison.differingPixels, comparison.covered / 100)
        XCTAssertGreaterThan(comparison.psnr, 55)
    }

    // MARK: - 8: no fine reads for far chunks, and their tiers leave

    /// At a far camera every chunk draws level 2 once the section lands: from then on no fine
    /// read is issued for a chunk in the coarse regime, and when a nearer view wants fine tiers
    /// for other chunks, the heads the far chunks got at the first tick leave first, as surplus.
    func testFarChunksIssueNoFineReadsAndReleaseTiers() throws {
        GaussianPagingPolicy.fadeFrames = 0
        GaussianPagingPolicy.surplusTicks = 4
        GaussianPagingPolicy.minResidencyTicks = 0
        GaussianPagingPolicy.holdOffTicks = 2
        GaussianPagingPolicy.reloadCooldownTicks = 0
        let url = try levelledSlabURL()
        let fixture = try loadPaged(url, poolSlots: 400)
        let pager = try XCTUnwrap(fixture.pager)
        let source = try XCTUnwrap(fixture.source)
        XCTAssertEqual(fixture.coarse?.levelCount, 2)
        // Near first, straight above the slab so every chunk is in view, under the uniform
        // rule at a budget of about a hundred splats per chunk (levels are off under it): every
        // chunk gets its head into the pool and no more.
        placeGaussianTestCamera(eye: simd_float3(0, 14, 0.01), target: .zero)
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = true
        GaussianRuntimeLimits.workingSetSplatsOverride = 100 * fixture.chunkCount
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        frames(fixture, max: 40) { pager.stats.residentChunks == fixture.chunkCount && pager.stats.pendingReads == 0 }
        XCTAssertEqual(pager.stats.residentChunks, fixture.chunkCount, "every head resident")
        XCTAssertTrue(pager.coarseSectionLanded, "the section landed meanwhile")
        for chunk in 0 ..< fixture.chunkCount {
            XCTAssertLessThanOrEqual(pager.residentRanks(of: chunk), 256, "heads only")
        }
        // Then an oblique view with the whole slab in it, its near edge at 11 m and its far edge
        // at 22 m so the chunks' densities spread over several tiers, the weighted quotas and
        // the budget unlimited, and the floor five tiers under the least dense chunk: every
        // chunk in the coarse regime.
        GaussianDebugOptions.shared.disableScreenWeightedQuotas = false
        GaussianRuntimeLimits.workingSetSplatsOverride = nil
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        placeGaussianTestCamera(eye: simd_float3(0, 8, 14), target: simd_float3(0, 0, -3))
        let densities = try mirrorAreas(fixture).values.map { 1024 / $0 }.sorted()
        XCTAssertEqual(densities.count, fixture.chunkCount, "every chunk in view")
        let spread = GaussianChunkCullMath.densityTier(density: densities[densities.count - 1]) - GaussianChunkCullMath.densityTier(density: densities[0])
        XCTAssertGreaterThanOrEqual(spread, 4, "sanity — the densities spread over four tiers or more")
        GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: GaussianChunkCullMath.densityTier(density: densities[0]) - 5)
        /// The level the wants assume for a chunk at the current floor: the rule from the fine
        /// state (the finer side of the band), as GaussianPageManager.computeWants evaluates it.
        func wantsCoarse(_ chunk: Int) -> Bool {
            guard let coarse = fixture.coarse else { return false }
            let inputs = GaussianCoarseWantInputs(tierShifts: tierShifts(coarse), counts: counts(fixture, chunk: chunk), available: pager.coarseAvailable(of: chunk), densityFloor: densityFloor)
            return GaussianPagingPolicy.coarseLevel(inputs, splatCount: fixture.index.chunks[chunk].splatCount, area: pager.chunkState(chunk).lastArea, cap: .infinity, previous: 0) != 0
        }
        frame(fixture)
        frame(fixture)
        let landedTick = pager.tick
        let headsBefore = pager.stats.residentSlots
        XCTAssertGreaterThanOrEqual(headsBefore, fixture.chunkCount)
        let readsBefore = source.requestLog.filter(\.isFine).count
        for _ in 0 ..< 12 {
            frame(fixture)
            XCTAssertEqual(pager.stats.issuedThisTick, 0, "tick \(pager.tick): nothing issued in the coarse regime")
        }
        XCTAssertEqual(source.requestLog.filter(\.isFine).count, readsBefore, "no fine read in the coarse regime")
        let coarseRegime = Set((0 ..< fixture.chunkCount).filter { pager.chunkState($0).drawnLevel != 0 })
        XCTAssertGreaterThan(coarseRegime.count, fixture.chunkCount * 9 / 10, "nearly every chunk is in the coarse regime at the far camera")
        for entry in visibleChunkLevels(fixture.table) {
            XCTAssertNotEqual(entry.level, 0, "chunk \(entry.chunkIndex) draws coarse")
        }
        XCTAssertEqual(pager.stats.residentSlots, headsBefore, "nothing left yet: no demand competes for the slots")
        let evictedBefore = pager.eventLog.filter { $0.kind == .evicted }.count

        // The floor raised so that the third of the chunks largest on screen flips to fine (Δ =
        // −3 at their density, one past the band from level 1) while the densest stay coarse:
        // the fine chunks want tiers, and the coarse chunks' heads — surplus since the view
        // went coarse — go first.
        let splitDensity = densities[densities.count / 3]
        GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: GaussianChunkCullMath.densityTier(density: splitDensity) - 3)
        // A chunk whose wants say coarse asks for nothing and its head is surplus; a chunk inside
        // the band is drawn coarse but wants fine (the finer assumption of GaussianPagingPolicy
        // .wantedRanks, so it keeps its tiers), and may load like any fine chunk.
        var evicted: [(chunk: Int, tick: UInt32, surplus: Bool)] = []
        var issuedForCoarse = 0
        var issuedInBand = 0
        for _ in 0 ..< 30 {
            frame(fixture)
            let tick = pager.tick
            for event in pager.eventLog where event.tick == tick {
                switch event.kind {
                case .evicted:
                    evicted.append((event.chunk, tick, wantsCoarse(event.chunk)))
                case .issued:
                    if wantsCoarse(event.chunk) { issuedForCoarse += 1 }
                    if pager.chunkState(event.chunk).drawnLevel != 0 { issuedInBand += 1 }
                default:
                    break
                }
            }
        }
        // The surplus class goes before the tail class: the first tick's victims are all heads
        // of chunks that want nothing, and most of those leave before any other tier does.
        let firstTick = try XCTUnwrap(evicted.first?.tick)
        XCTAssertTrue(evicted.filter { $0.tick == firstTick }.allSatisfy(\.surplus), "the first evictions are surplus heads of coarse chunks")
        let surplusEvicted = evicted.filter(\.surplus).count
        XCTAssertGreaterThan(surplusEvicted, 50, "the coarse chunks' heads left")
        if let firstOther = evicted.firstIndex(where: { !$0.surplus }) {
            XCTAssertGreaterThan(evicted[..<firstOther].count, surplusEvicted / 2, "most surplus heads left before any other tier")
        }
        let fineNow = (0 ..< fixture.chunkCount).filter { pager.chunkState($0).drawnLevel == 0 }.count
        XCTAssertGreaterThan(fineNow, fixture.chunkCount / 5, "sanity — a good share of the chunks flipped to fine")
        XCTAssertLessThan(fineNow, fixture.chunkCount * 2 / 3, "sanity — most stay coarse")
        XCTAssertGreaterThan((0 ..< fixture.chunkCount).filter { wantsCoarse($0) }.count, fixture.chunkCount / 5, "sanity — a good share still wants coarse")
        XCTAssertGreaterThan(evicted.count, 0, "surplus tiers of coarse chunks left for the fine chunks' tiers")
        XCTAssertEqual(issuedForCoarse, 0, "no fine read for a chunk whose wants say coarse")
        XCTAssertGreaterThan(pager.eventLog.filter { $0.kind == .issued && $0.tick > landedTick }.count, 0, "the fine chunks did load")
        XCTAssertLessThanOrEqual(pager.stats.residentSlots, pager.slotCount)
        XCTAssertGreaterThan(pager.eventLog.filter { $0.kind == .evicted }.count, evictedBefore)
        print("[GaussianChunkLevelTest] far camera: \(headsBefore) heads resident from the near view, tick \(landedTick), \(coarseRegime.count) of \(fixture.chunkCount) chunks coarse; with the floor raised \(fineNow) chunks drawn fine, \(evicted.count) tiers evicted for their tiers (\(surplusEvicted) surplus heads of coarse chunks; \(issuedInBand) reads for chunks drawn coarse inside the band)")
    }

    // MARK: - 9: a fine head arriving over a coarse level

    /// One chunk's fine reads held while the section lands: the chunk draws level 1; when the
    /// head is released and lands the switch commits at once with the coarse window outgoing on
    /// the arrival's clock — two entries for fadeFrames frames, the fine ranks at the arrival
    /// fade and the coarse records at the complementary coverage weight — then one entry.
    func testHeadArrivalFadesOverCoarse() throws {
        GaussianPagingPolicy.fadeFrames = 16
        let url = try levelledSlabURL()
        let index = try UntoldGSFile(url: url).index
        let chunkCount = index.chunks.count
        // The chunk nearest the slab's centre: in view from the slab camera, held while every
        // other chunk loads.
        let chunk = try XCTUnwrap(index.chunks.indices.min { simd_length(0.5 * (index.chunks[$0].aabbMin + index.chunks[$0].aabbMax)) < simd_length(0.5 * (index.chunks[$1].aabbMin + index.chunks[$1].aabbMax)) })
        let tiers = index.chunks.reduce(0) { $0 + GaussianPagingPolicy.tiersNeeded(needed: $1.splatCount, ranksPerPage: 256) }
        let fixture = try loadPaged(url, poolSlots: tiers, coarseFraction: 1) { source in
            source.holdChunks = [chunk]
        }
        let pager = try XCTUnwrap(fixture.pager)
        let source = try XCTUnwrap(fixture.source)
        let coarse = try XCTUnwrap(fixture.coarse)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frames(fixture, max: 30) { pager.coarseSectionLanded }
        XCTAssertTrue(pager.coarseSectionLanded)
        for _ in 0 ..< Int(GaussianPagingPolicy.fadeFrames) + 3 {
            frame(fixture)
        }
        XCTAssertEqual(pager.residentRanks(of: chunk), 0, "held")
        let listed = visibleChunkLevels(fixture.table)
        let before = listed.filter { $0.chunkIndex == UInt32(chunk) }
        XCTAssertEqual(before.count, 1)
        XCTAssertEqual(before.first?.level, 1, "drawn at level 1 while nothing fine of it is resident")
        let m1 = try XCTUnwrap(index.coarseEntry(level: 1, chunk: chunk)?.splatCount)
        let resolver = try LevelResolver(url: url, index: index, levels: [1])

        let coarseAlpha = alphaSum(fullFrame(fixture))
        source.release(chunk: chunk)
        settle(fixture)
        frame(fixture) // the head maps: arrival this tick, the switch commits at once
        // The set frozen from here: the chunk's later tiers would fade in on their own clocks.
        GaussianDebugOptions.shared.freezePaging = true
        let arrival = pager.chunkState(chunk).arrivalTick
        XCTAssertEqual(arrival, pager.tick)
        let resident = pager.residentRanks(of: chunk)
        XCTAssertGreaterThan(resident, 0)
        XCTAssertEqual(chunkCount, index.chunks.count)
        var states = levelStates(coarse, chunkCount: chunkCount)
        XCTAssertEqual(states[chunk].level, 0)
        XCTAssertEqual(states[chunk].outLevel, 1, "the coarse level is the outgoing window")
        XCTAssertEqual(states[chunk].outCount, m1)
        XCTAssertEqual(states[chunk].switchFrame, arrival, "on the arrival's clock")
        var fadingFrames = 0
        var checked = 0
        var alphaTrajectory: [Double] = []
        while pager.tick &- arrival < 18 {
            let elapsed = pager.tick &- arrival
            let fading = elapsed < 16
            let entries = visibleChunkLevels(fixture.table).filter { $0.chunkIndex == UInt32(chunk) }
            if fading {
                XCTAssertEqual(entries.count, 2, "\(elapsed) frames after the arrival: both windows")
                let incoming = try XCTUnwrap(entries.first { !$0.outgoing })
                let outgoing = try XCTUnwrap(entries.first(where: \.outgoing))
                XCTAssertEqual(incoming.level, 0)
                XCTAssertEqual(incoming.quota, resident)
                XCTAssertEqual(outgoing.level, 1)
                XCTAssertEqual(outgoing.quota, m1)
                fadingFrames += 1
            } else {
                XCTAssertEqual(entries.count, 1, "\(elapsed) frames after the arrival: fine alone")
                XCTAssertEqual(entries.first?.level, 0)
            }
            let weight = GaussianChunkCullMath.fadeWeight(frame: pager.tick, switchFrame: arrival, fadeFrames: 16)
            // The chunk's records alone (the frame holds some 300 k): those inside its fine box,
            // which holds the merged centres too.
            let box = (min: index.chunks[chunk].aabbMin - 1e-3, max: index.chunks[chunk].aabbMax + 1e-3)
            let inBox = sharedGaussianRecords().filter { all($0.position .>= box.min) && all($0.position .<= box.max) }
            for (record, origin) in resolver.origins(of: inBox) where origin.chunk == chunk {
                if origin.level == 0 {
                    // The same power law as the coarse window, on the arrival's ramp: the pair
                    // composes to the surface's own transmittance (a linear ramp would dip).
                    let full = origin.opacity * GaussianChunkCullMath.opacityBandFactor(rank: UInt32(origin.rank), quota: resident, splatCount: index.chunks[chunk].splatCount)
                    XCTAssertEqual(record.conicAndOpacity.w, GaussianChunkCullMath.coverageWeight(alpha: full, weight: weight), accuracy: 3e-3, "fine rank \(origin.rank) at the arrival fade \(weight)")
                } else {
                    XCTAssertTrue(fading)
                    XCTAssertEqual(record.conicAndOpacity.w, GaussianChunkCullMath.coverageWeight(alpha: origin.opacity, weight: 1 - weight), accuracy: 3e-3, "coarse record \(origin.rank) at the complementary weight")
                }
                checked += 1
            }
            alphaTrajectory.append(alphaSum(fullFrame(fixture)))
        }
        XCTAssertEqual(fadingFrames, 16)
        XCTAssertGreaterThan(checked, 500)
        states = levelStates(coarse, chunkCount: chunkCount)
        XCTAssertEqual(states[chunk].level, 0)
        XCTAssertEqual(pager.residentRanks(of: chunk), resident, "frozen")
        // The coverage through the arrival: flat within 5 % between the coarse frame before the
        // head landed and the fine frame after the fade.
        let fineAlpha = alphaSum(fullFrame(fixture))
        let endpoints = (min(coarseAlpha, fineAlpha), max(coarseAlpha, fineAlpha))
        for (i, alpha) in alphaTrajectory.enumerated() {
            XCTAssertGreaterThanOrEqual(alpha, endpoints.0 * 0.95, "frame \(i) of the arrival fade: the coverage stays within 5 %")
            XCTAssertLessThanOrEqual(alpha, endpoints.1 * 1.05, "frame \(i) of the arrival fade: the coverage stays within 5 %")
        }
    }

    // MARK: - 10: determinism

    /// Whole-resident: after 40 frames at a far camera two identical frames are bit-identical.
    /// Paged with the set frozen and the camera static: 30 identical frames.
    func testDeterminism() throws {
        let url = try levelledSlabURL()
        let whole = try loadWhole(url)
        frame(whole)
        GaussianRuntimeLimits.workingSetSplatsOverride = max(1, sharedGaussianVisibleCount() / 3)
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        let camera = placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        for frameIndex in 0 ..< 40 {
            let height = 6 + Float(min(frameIndex, 20)) * 2
            cameraLookAt(entityId: camera, eye: simd_float3(0, height, 0.5 * height), target: .zero, up: simd_float3(0, 1, 0))
            frame(whole)
        }
        // The camera has been still for twenty frames; the cap's climb and the fades it starts
        // settle within the next thirty.
        GaussianSharedWorkingSet.shared.resetBudgetHysteresis()
        for _ in 0 ..< 30 {
            frame(whole)
        }
        XCTAssertGreaterThan(try budgetState().coarseChunks, 0, "levels are drawn")
        XCTAssertEqual(visibleChunkLevels(whole.table).filter(\.outgoing).count, 0, "no fade is running")
        let a = capture()
        let b = capture()
        XCTAssertEqual(a, b)
        XCTAssertGreaterThan(a.count, 1000)
        unload(whole)

        GaussianPagingPolicy.fadeFrames = 16
        let paged = try loadPaged(url, poolSlots: 300)
        let pager = try XCTUnwrap(paged.pager)
        cameraLookAt(entityId: camera, eye: simd_float3(0, 30, 15), target: .zero, up: simd_float3(0, 1, 0))
        frames(paged, max: 40) { pager.coarseSectionLanded && pager.stats.pendingReads == 0 && pager.stats.issuedThisTick == 0 }
        for _ in 0 ..< 20 {
            frame(paged)
        }
        GaussianDebugOptions.shared.freezePaging = true
        frame(paged)
        let first = capture()
        XCTAssertGreaterThan(first.count, 100)
        for i in 0 ..< 30 {
            frame(paged)
            XCTAssertEqual(capture(), first, "frozen frame \(i)")
        }
    }

    // MARK: - 11: stereo

    /// In stereo the level of a chunk comes from the larger eye's area, one entry per chunk for
    /// both eyes: the tags are the mirror's from the entries' areas, and a near second eye makes
    /// some chunks finer than the far eye alone would.
    func testStereoOneLevelPerChunk() throws {
        let fixture = try loadWhole(levelledSlabURL())
        let coarse = try XCTUnwrap(fixture.coarse)
        // The far eye where the median chunk covers about 25 pixels of its padded box (the
        // coarse regime at the default floor); the near eye at half the distance.
        let farEye = try placeCameraWithMedianChunkPixels(25, fixture).eye
        let nearEye = farEye * 0.5
        let farView = try viewProjection(entity: fixture.entity, eye: farEye, target: .zero)
        let nearView = try viewProjection(entity: fixture.entity, eye: nearEye, target: .zero)
        let levelConstants = gaussianChunkLevelConstants(coarse: coarse, frameIndex: 1, cull: GaussianChunkCullConstants(), viewport: renderInfo.viewPort, fadeFrames: 0, levelMode: .auto)
        XCTAssertEqual(levelConstants.hasCoarse, 2)

        func run(eye0: simd_float4x4, eye1: simd_float4x4?, label: String) throws -> [UInt32: GaussianVisibleChunkLevelEntry] {
            // A fresh state: the first pass detects, the second commits.
            coarse.levelStateBuffer.contents().initializeMemory(as: UInt8.self, repeating: 0, count: coarse.levelStateBuffer.length)
            var constants = try stereoConstants(table: fixture.table, entity: fixture.entity, eye0: eye0, eye1: eye1 ?? eye0)
            if eye1 == nil { constants.viewCount = 1 }
            var lvl = levelConstants
            lvl.chunkCount = constants.chunkCount
            lvl.paged = 0
            lvl.uniformQuotas = 0
            var entries: [GaussianVisibleChunk] = []
            for _ in 0 ..< 2 {
                entries = try cullChunks(fixture.table, constants: constants, levels: coarse.levelBuffers, levelConstants: lvl, quotas: true).entries
            }
            var byChunk: [UInt32: GaussianVisibleChunkLevelEntry] = [:]
            for entry in entries {
                let tag = GaussianChunkCullMath.decodeVisibleChunkTag(entry.chunkIndex)
                XCTAssertFalse(tag.outgoing, "\(label): no outgoing window without a fade")
                XCTAssertNil(byChunk[tag.chunkIndex], "\(label): one entry per chunk")
                byChunk[tag.chunkIndex] = GaussianVisibleChunkLevelEntry(chunkIndex: tag.chunkIndex, level: tag.level, outgoing: tag.outgoing, entry: entry)
                let expectedArea = GaussianChunkCullMath.chunkScreenArea(chunk: decodeConstants(fixture.table)[Int(tag.chunkIndex)], constants: constants)
                XCTAssertEqual(entry.screenArea, expectedArea, accuracy: max(1e-5 * expectedArea, 1e-6), "\(label) chunk \(tag.chunkIndex): the larger kept eye's area")
                let expected = mirrorLevel(fixture, chunk: Int(tag.chunkIndex), area: entry.screenArea, cap: .infinity, previous: 0)
                XCTAssertEqual(tag.level, expected, "\(label) chunk \(tag.chunkIndex): the mirror's level from the entry's area")
            }
            return byChunk
        }
        let stereo = try run(eye0: farView, eye1: nearView, label: "stereo")
        let mono = try run(eye0: farView, eye1: nil, label: "mono far")
        let swapped = try run(eye0: nearView, eye1: farView, label: "swapped")
        XCTAssertGreaterThan(stereo.count, 200)
        XCTAssertEqual(stereo.count, mono.count, "the far eye sees every chunk the pair sees")
        XCTAssertGreaterThan(mono.values.filter { $0.level != 0 }.count, 100, "sanity — the far eye alone draws coarse")
        var finer = 0
        for (chunk, entry) in stereo {
            let far = try XCTUnwrap(mono[chunk])
            XCTAssertLessThanOrEqual(entry.level, far.level, "chunk \(chunk): the larger eye never makes a chunk coarser")
            if entry.level < far.level { finer += 1 }
            XCTAssertEqual(swapped[chunk]?.level, entry.level, "chunk \(chunk): swapping the eyes changes nothing")
        }
        XCTAssertGreaterThan(finer, 20, "the near eye makes some chunks finer")
    }

    private func decodeConstants(_ table: GaussianChunkTable) -> [GaussianChunkDecodeConstants] {
        Array(UnsafeBufferPointer(start: table.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: table.chunkCount), count: table.chunkCount))
    }

    // MARK: - 12: the fit check

    /// With a residency budget that holds only the coarsest level the table keeps level 2 alone
    /// as the runtime's level 1 with its own tier shift and the frame draws fine or that level;
    /// smaller still and the entity draws fine only, bit-identical to the section-free file.
    func testFitCheckFallsBackToL2Only() throws {
        GaussianDebugOptions.shared.disablePaging = true
        let url = try levelledSlabURL()
        let index = try UntoldGSFile(url: url).index
        let level1Bytes = try Int(XCTUnwrap(index.coarseLevelRange(level: 1)).count)
        let level2Bytes = try Int(XCTUnwrap(index.coarseLevelRange(level: 2)).count)
        XCTAssertGreaterThan(level1Bytes, 4 * level2Bytes)
        // Both fit when they take at most 20 % of the budget; level 2 alone when it does.
        GaussianPagingPolicy.residencyBudgetBytesOverride = 5 * level2Bytes + 4096
        XCTAssertEqual(GaussianPagePoolRegistry.shared.coarseBytes, 0, "no levelled entity is loaded")
        do {
            let l2Only = try loadWhole(url)
            let coarse = try XCTUnwrap(l2Only.coarse, "the coarsest level fits")
            XCTAssertEqual(coarse.levelCount, 1)
            XCTAssertEqual(coarse.fileLevels, [2])
            XCTAssertEqual(coarse.ratioLog2, [6])
            XCTAssertEqual(coarse.recordBytes, level2Bytes, "level 2's records alone")
            XCTAssertEqual(GaussianPagePoolRegistry.shared.coarseBytes, level2Bytes, "the level's bytes are claimed on the shared coarse ledger")
            XCTAssertEqual(coarse.claim?.bytes, level2Bytes)
            // A second levelled entity fits against what the first holds: the share is one ledger
            // for every entity, not a fifth of the budget for each.
            do {
                let second = try loadWhole(url)
                XCTAssertNil(second.coarse, "the first entity holds the share; the second draws fine only")
                XCTAssertEqual(GaussianPagePoolRegistry.shared.coarseBytes, level2Bytes)
                unload(second)
            }
            let rows = Array(UnsafeBufferPointer(start: coarse.constantsBuffer.contents().bindMemory(to: GaussianChunkDecodeConstants.self, capacity: l2Only.chunkCount), count: l2Only.chunkCount))
            for chunk in 0 ..< l2Only.chunkCount {
                XCTAssertEqual(rows[chunk].splatCount, index.coarseEntry(level: 2, chunk: chunk)?.splatCount ?? 0, "chunk \(chunk): the runtime's level 1 row is the file's level 2")
                XCTAssertEqual(l2Only.table.coarseEntry(runtimeLevel: 1, chunk: chunk), index.coarseEntry(level: 2, chunk: chunk))
                XCTAssertNil(l2Only.table.coarseEntry(runtimeLevel: 2, chunk: chunk))
            }
            let constants = gaussianChunkLevelConstants(coarse: coarse, frameIndex: 1, cull: GaussianChunkCullConstants())
            XCTAssertEqual(constants.hasCoarse, 1)
            XCTAssertEqual(Int(constants.tierShift1), GaussianChunkCullMath.tierShift(ratioLog2: 6))
            XCTAssertEqual(constants.tierShift2, constants.tierShift1)
            try placeCameraWithMedianChunkPixels(20, l2Only)
            for _ in 0 ..< 20 {
                frame(l2Only)
            }
            let entries = visibleChunkLevels(l2Only.table)
            XCTAssertGreaterThan(entries.count, 200)
            XCTAssertGreaterThan(entries.filter { $0.level == 1 }.count, 100, "far chunks draw the coarsest level as level 1")
            for entry in entries where !entry.outgoing {
                XCTAssertLessThanOrEqual(entry.level, 1, "chunk \(entry.chunkIndex): one resident level")
                XCTAssertEqual(entry.level, mirrorLevel(l2Only, chunk: Int(entry.chunkIndex), area: entry.screenArea, cap: .infinity, previous: entry.level), "chunk \(entry.chunkIndex): the rule with the level-2 shift")
            }
            unload(l2Only)
        }
        XCTAssertEqual(GaussianPagePoolRegistry.shared.coarseBytes, 0, "released with the entity's table")
        // Smaller: no level fits; the frame is the section-free file's.
        GaussianPagingPolicy.residencyBudgetBytesOverride = 4 * level2Bytes
        let none = try loadWhole(url)
        XCTAssertNil(none.coarse)
        XCTAssertFalse(none.table.hasCoarse)
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frame(none)
        let levelledFrame = capture()
        XCTAssertEqual(try budgetState().coarseChunks, 0)
        unload(none)
        let plain = try loadWhole(plainSlabURL())
        frame(plain)
        XCTAssertEqual(capture(), levelledFrame, "without a fitting level the levelled file draws the section-free frame")
    }

    // MARK: - 13: a corrupt coarse payload

    /// A coarse piece that fails its CRC faults the entity's levels: the event, the stats, no
    /// active coarse table, no tag bits — and the fine paging goes on.
    func testCorruptCoarsePayloadDisablesLevelsForEntity() throws {
        let url = try levelledSlabURL()
        let fixture = try loadPaged(url, poolSlots: 400) { source in
            source.corruptCoarse = true
        }
        let pager = try XCTUnwrap(fixture.pager)
        XCTAssertNotNil(fixture.coarse)
        XCTAssertNotNil(gaussianActiveCoarseTable(fixture.component))
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)
        frames(fixture, max: 10) { pager.coarseFaulted }
        XCTAssertTrue(pager.coarseFaulted)
        XCTAssertTrue(pager.stats.coarseFaulted)
        XCTAssertEqual(pager.stats.coarseLevels, 0)
        XCTAssertEqual(pager.eventLog.filter { $0.kind == .coarseCorrupt }.count, 1, "reported once")
        XCTAssertNil(gaussianActiveCoarseTable(fixture.component), "the driver binds no levels")
        XCTAssertEqual(pager.stats.state, .active, "the asset itself is fine")
        frames(fixture, max: 30) { pager.stats.residentChunks > 50 && pager.stats.pendingReads == 0 }
        XCTAssertGreaterThan(pager.stats.residentChunks, 50, "fine paging continues")
        frame(fixture)
        let entries = visibleChunkLevels(fixture.table)
        XCTAssertGreaterThan(entries.count, 50)
        for entry in entries {
            XCTAssertEqual(entry.level, 0, "chunk \(entry.chunkIndex): fine")
            XCTAssertFalse(entry.outgoing)
        }
        XCTAssertGreaterThan(sharedGaussianVisibleCount(), 0)
        XCTAssertEqual(try budgetState().coarseChunks, 0)
        XCTAssertEqual(pager.eventLog.filter { $0.kind == .coarseIssued }.count, 1, "no piece after the fault")
        try assertFrameFits()
    }

    /// Piece reads that fail with an I/O error are retried per piece on the tier reads'
    /// schedule (`retryTicks`): every piece of the section failing once costs each one retry
    /// and the section lands (a count across pieces would have faulted the levels at the fourth
    /// failure whichever pieces failed), a piece's retries back off by the schedule, and the
    /// levels fault only when one piece exhausts it.
    func testCoarsePieceReadFailuresRetryPerPiece() throws {
        GaussianPagingPolicy.maxPageBytesInFlight = 128 << 10 // 64 KiB pieces: the slab's section in several
        let url = try levelledSlabURL()
        placeGaussianTestCamera(eye: slabCamera.eye, target: slabCamera.target)

        let once = try loadPaged(url, poolSlots: 400) { source in
            source.coarsePieceFailures = 1
        }
        let pager = try XCTUnwrap(once.pager)
        frames(once, max: 150) { pager.coarseSectionLanded || pager.coarseFaulted }
        XCTAssertTrue(pager.coarseSectionLanded, "every piece failed once and the section still landed")
        XCTAssertFalse(pager.coarseFaulted)
        XCTAssertEqual(pager.stats.coarseLevels, 2)
        let issued = pager.eventLog.filter { $0.kind == .coarseIssued }
        let pieces = Set(issued.map(\.tier))
        XCTAssertGreaterThanOrEqual(pieces.count, 4, "the section streams in several pieces: \(pieces.count)")
        for piece in pieces.sorted() {
            let ticks = issued.filter { $0.tier == piece }.map(\.tick)
            XCTAssertEqual(ticks.count, 2, "piece \(piece): the first read and one retry — \(ticks)")
            if ticks.count == 2 {
                // A failure lands the tick after it is issued; the back-off counts from there.
                XCTAssertEqual(Int(ticks[1]) - Int(ticks[0]), 9, accuracy: 1, "piece \(piece): retried after retryTicks[0]")
            }
        }
        XCTAssertEqual(pager.stats.state, .active)
        unload(once)

        let exhausted = try loadPaged(url, poolSlots: 400) { source in
            source.coarsePieceFailures = GaussianPagingPolicy.retryTicks.count + 1
        }
        let faultingPager = try XCTUnwrap(exhausted.pager)
        frames(exhausted, max: 230) { faultingPager.coarseFaulted }
        XCTAssertTrue(faultingPager.coarseFaulted, "a piece that fails past the schedule faults the levels")
        XCTAssertEqual(faultingPager.stats.coarseLevels, 0)
        XCTAssertEqual(faultingPager.stats.state, .active, "the asset itself is fine")
        let attempts = faultingPager.eventLog.filter { $0.kind == .coarseIssued && $0.tier == 0 }.map(\.tick)
        XCTAssertEqual(attempts.count, 4, "piece 0: the first read and three retries — \(attempts)")
        if attempts.count == 4 {
            XCTAssertEqual(Int(attempts[1]) - Int(attempts[0]), 9, accuracy: 1)
            XCTAssertEqual(Int(attempts[2]) - Int(attempts[1]), 33, accuracy: 1)
            XCTAssertEqual(Int(attempts[3]) - Int(attempts[2]), 129, accuracy: 1)
        }
        XCTAssertEqual(faultingPager.eventLog.filter { $0.kind == .coarseCorrupt }.count, 1, "reported once")
        frame(exhausted)
        XCTAssertNil(gaussianActiveCoarseTable(exhausted.component), "the driver binds no levels")
    }

    // MARK: - 14: the analytic cluster fixture

    /// Eight tight clusters of identical isotropic splats per chunk, baked with one record per
    /// cluster at level 1 and one per chunk at level 2: the level-1 records sit at the clusters'
    /// centres, saturate in opacity and carry the clusters' extent; level 2 sits at the chunk's
    /// mean; drawn coarse only from afar the frame is close to the fine one.
    func testCoarseClustersMergeToTheirCentres() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GaussianChunkLevelTest-clusters-\(UUID().uuidString)")
            .appendingPathExtension("untoldgs")
        temporaryFiles.append(url)
        let clusters = try GaussianSyntheticAsset.coarseClusters(chunkCount: 64, to: url)
        let file = try UntoldGSFile(url: url)
        let index = file.index
        XCTAssertEqual(index.chunks.count, 64)
        XCTAssertEqual(index.coarseLevelCount, 2)
        XCTAssertEqual(index.coarseRatioLog2, [7, 10])
        XCTAssertEqual(clusters.centres.count, 512)
        var matched: Set<Int> = []
        let centres = GaussianSplatIndexResolver(positions: clusters.centres)
        for chunk in 0 ..< 64 {
            XCTAssertEqual(index.chunks[chunk].splatCount, 1024)
            let level1 = try file.decodeCoarseLevel(level: 1, chunk: chunk)
            XCTAssertEqual(level1.count, 8, "chunk \(chunk): one record per cluster")
            var chunkCentres: [simd_float3] = []
            for splat in level1 {
                let nearest = try XCTUnwrap(centres.index(of: splat.position, tolerance: 0.03), "chunk \(chunk): a level-1 record at \(splat.position) sits on a cluster centre")
                XCTAssertTrue(matched.insert(nearest).inserted, "each cluster merged once")
                chunkCentres.append(clusters.centres[nearest])
                XCTAssertGreaterThan(splat.opacity, 0.95, "128 overlapping splats saturate")
                // r² I plus the members' spread over the ball (r_c² / 5 per axis).
                let expectedSigma = (clusters.splatRadius * clusters.splatRadius + clusters.radius * clusters.radius / 5).squareRoot()
                for axis in 0 ..< 3 {
                    XCTAssertEqual(splat.scale[axis], expectedSigma, accuracy: 0.3 * expectedSigma, "chunk \(chunk): the merged extent")
                }
            }
            let level2 = try file.decodeCoarseLevel(level: 2, chunk: chunk)
            XCTAssertEqual(level2.count, 1, "chunk \(chunk): one record per chunk")
            let mean = chunkCentres.reduce(simd_float3.zero, +) / 8
            XCTAssertLessThan(simd_distance(level2[0].position, mean), 0.08, "chunk \(chunk): level 2 at the chunk's mean")
            /// Eight saturated blobs spread over a cell: the merged record's coverage is their
            /// summed area over its own, 1 − exp(−Σ α_i s_i / s_M) — a few percent, not opaque.
            func area(_ s: simd_float3) -> Float {
                (s.x * s.y + s.y * s.z + s.z * s.x) / 3
            }
            let summed = level1.reduce(Float(0)) { $0 + $1.opacity * area($1.scale) }
            let expectedOpacity = 1 - exp(-summed / area(level2[0].scale))
            XCTAssertEqual(level2[0].opacity, expectedOpacity, accuracy: max(0.3 * expectedOpacity, 1 / 255), "chunk \(chunk): level 2's coverage opacity")
            XCTAssertLessThan(level2[0].opacity, 0.2, "sparse: far from saturated")
            let spread = chunkCentres.reduce(Float(0)) { $0 + simd_length_squared($1 - mean) } / 8
            XCTAssertGreaterThan(simd_length_squared(level2[0].scale), 0.5 * spread, "chunk \(chunk): level 2 carries the block's extent")
        }
        XCTAssertEqual(matched.count, 512)

        // Drawn from above the grid's centre at a distance where a fine splat is about a pixel:
        // the fine frame, then the floor lowered so every chunk draws level 1 — one record per
        // cluster against 128 splats.
        let fixture = try loadWhole(url)
        XCTAssertEqual(fixture.coarse?.levelCount, 2)
        placeGaussianTestCamera(eye: simd_float3(3.5, 22, 3.51), target: simd_float3(3.5, 3.5, 3.5))
        GaussianDebugOptions.shared.gaussianLevelMode = .fineOnly
        _ = fullFrame(fixture)
        let fine = fullFrame(fixture)
        XCTAssertEqual(sharedGaussianVisibleCount(), 65536, "every fine splat in view")
        // Ratios 7 and 10 make the tier shifts 12 and 18 (the rule honours the file's ratios):
        // level 1 lies fourteen half-octaves under the median chunk's density.
        let medianDensity = try mirrorAreas(fixture).values.map { 1024 / $0 }.sorted()[32]
        let shifts = try tierShifts(XCTUnwrap(fixture.coarse))
        XCTAssertEqual(shifts.0, 12)
        XCTAssertEqual(shifts.1, 18)
        GaussianRuntimeLimits.maxSplatsPerPixelOverride = floorOverride(tier: GaussianChunkCullMath.densityTier(density: medianDensity) - 16)
        GaussianDebugOptions.shared.gaussianLevelMode = .auto
        GaussianDebugOptions.shared.disableLevelCrossFade = true
        for _ in 0 ..< 3 {
            frame(fixture)
        }
        let level1 = fullFrame(fixture)
        let entries = visibleChunkLevels(fixture.table)
        XCTAssertEqual(entries.count, 64)
        XCTAssertEqual(entries.filter { $0.level == 1 }.count, 64, "every chunk at level 1")
        XCTAssertEqual(sharedGaussianVisibleCount(), 512, "one record per cluster")
        let quality = compareGaussianSplatLayers(level1, fine)
        let alphaRatio = alphaSum(level1) / alphaSum(fine)
        print(String(format: "[GaussianChunkLevelTest] clusters: level 1 vs fine PSNR %.2f dB over %d px, alpha ratio %.3f", quality.psnr, quality.covered, alphaRatio))
        // The 128 splats of a cluster are each about a pixel here and the fused pass draws every
        // one at least a pixel wide, so the fine cluster bleeds past the merged record's footprint
        // (about 10 dB, a third of the alpha); the closed-form moments above are the check of the merge.
        XCTAssertGreaterThan(quality.covered, 1000)
        XCTAssertGreaterThanOrEqual(quality.psnr, 8, "one merged record per cluster against its 128 splats")
        XCTAssertGreaterThan(alphaRatio, 0.2)
        XCTAssertLessThan(alphaRatio, 1.5)
    }

    // MARK: - 15: layouts

    func testLayoutsArePinned() {
        XCTAssertEqual(MemoryLayout<GaussianVisibleChunk>.stride, 16)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.stride, 16)
        XCTAssertEqual(MemoryLayout<GaussianChunkResidency>.offset(of: \.coarseAvailable), 12)
        XCTAssertEqual(MemoryLayout<GaussianChunkPagingConstants>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianChunkCullConstants>.stride, 176)
        XCTAssertEqual(MemoryLayout<GaussianChunkDecodeConstants>.stride, 48)
        XCTAssertEqual(MemoryLayout<GaussianWorkingSetSplat>.stride, 64)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.stride, 48)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.offset(of: \.transitionSplats), 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.offset(of: \.coarseChunks), 36)
        XCTAssertEqual(MemoryLayout<GaussianBudgetState>.offset(of: \.coarseSplats), 40)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.stride, 48)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.offset(of: \.densityFloor), 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.offset(of: \.tierShift1), 36)
        XCTAssertEqual(MemoryLayout<GaussianBudgetScaleConstants>.offset(of: \.tierShift2), 40)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityTier>.stride, 32)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityTier>.offset(of: \.coarse1), 8)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityTier>.offset(of: \.coarse2), 12)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityTier>.offset(of: \.levelledSplats), 16)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.stride, 2064)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.targetDensity), 2048)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.fullDensity), 2052)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.grant), 2056)
        XCTAssertEqual(MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.visibleChunks), 2060)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.stride, 48)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.hasCoarse), 0)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.tierShift1), 4)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.tierShift2), 8)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.frameIndex), 12)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.fadeFrames), 16)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.levelMode), 20)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.debugTint), 24)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.densityFloor), 28)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.chunkCount), 32)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.paged), 36)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelConstants>.offset(of: \.uniformQuotas), 40)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelState>.stride, 8)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelState>.offset(of: \.word0), 0)
        XCTAssertEqual(MemoryLayout<GaussianChunkLevelState>.offset(of: \.switchFrame), 4)
        XCTAssertEqual(kGaussianVisibleChunkIndexMask, 0x00FF_FFFF)
        XCTAssertEqual(kGaussianVisibleChunkLevelShift, 24)
        XCTAssertEqual(kGaussianVisibleChunkLevelMask, 0x0300_0000)
        XCTAssertEqual(kGaussianVisibleChunkOutgoing, 0x0400_0000)
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
        XCTAssertEqual(GaussianLevelMode.auto.rawValue, 0)
        XCTAssertEqual(GaussianLevelMode.fineOnly.rawValue, 1)
        XCTAssertEqual(GaussianLevelMode.coarseOnly.rawValue, 2)
        // The tag round trip at the largest chunk index the bits hold.
        let word = GaussianChunkCullMath.visibleChunkTag(chunkIndex: kGaussianVisibleChunkIndexMask, level: 2, outgoing: true)
        let decoded = GaussianChunkCullMath.decodeVisibleChunkTag(word)
        XCTAssertEqual(decoded.chunkIndex, kGaussianVisibleChunkIndexMask)
        XCTAssertEqual(decoded.level, 2)
        XCTAssertTrue(decoded.outgoing)
    }
}
