//
//  GaussianStreamingTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

/// Verifies that Gaussian-splat props (`StreamingComponent.assetKind == .gaussianSplat`)
/// participate correctly in `GeometryStreamingSystem`'s distance-based load/unload lifecycle,
/// share `MemoryBudgetManager`'s geometry budget and LRU eviction pool with streamed meshes,
/// and are kept `markUsed` while visible so they aren't evicted ahead of genuinely stale
/// entities. Mirrors the CPU-side control-flow style of `GeometryStreamingEvictionTests`.
@MainActor
final class GaussianStreamingTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()

        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0 // no throttle
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.enableFrustumGate = false // deterministic candidate detection
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0
        GeometryStreamingSystem.shared.visibleEvictionProtectionRadius = 30.0

        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.geometryBudget = 100 * 1024 * 1024 // 100 MB
        MemoryBudgetManager.shared.textureBudget = 0
        MemoryBudgetManager.shared.highWaterMark = 0.85
        MemoryBudgetManager.shared.lowWaterMark = 0.70

        visibleEntityIds = []
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.updateInterval = 0.1
        GeometryStreamingSystem.shared.enableFrustumGate = true
        MemoryBudgetManager.shared.clear()
        visibleEntityIds = []
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Create a tile-owned, `.unloaded` streaming entity configured for the gaussian path,
    /// registered in the octree so `update()`'s spatial query can discover it. Mirrors
    /// `GeometryStreamingEvictionTests.makeUnloadedEntity`.
    @discardableResult
    private func makeUnloadedGaussianEntity(
        distance: Float,
        streamingRadius: Float = 10.0,
        unloadRadius: Float = 20.0,
        filename: String = "test_gaussians",
        withExtension ext: String = "ply"
    ) -> EntityID {
        let tileRoot = createEntity()
        if let tileComp = scene.assign(to: tileRoot, component: TileComponent.self) {
            // Keep this stub out of the tile-parse candidate loop entirely — it exists
            // only to satisfy loadMesh's isTileOwned ownership guard.
            tileComp.state = .parsed
        }

        let entityId = createEntity()

        if let local = scene.assign(to: entityId, component: LocalTransformComponent.self) {
            local.boundingBox = (
                min: simd_float3(distance - 0.5, -0.5, -0.5),
                max: simd_float3(distance + 0.5, 0.5, 0.5)
            )
        }
        if let world = scene.assign(to: entityId, component: WorldTransformComponent.self) {
            world.space = simd_float4x4(1.0)
        }
        if let scenegraph = scene.assign(to: entityId, component: ScenegraphComponent.self) {
            scenegraph.parent = tileRoot
            scenegraph.level = 1
        }
        if let streaming = scene.assign(to: entityId, component: StreamingComponent.self) {
            streaming.state = .unloaded
            streaming.assetKind = .gaussianSplat
            streaming.assetFilename = filename
            streaming.assetExtension = ext
            streaming.streamingRadius = streamingRadius
            streaming.unloadRadius = unloadRadius
        }

        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    /// Create an entity that already looks loaded via the gaussian streaming path — state
    /// `.loaded`, tracked in the streaming system's loaded set, carrying a `GaussianComponent`,
    /// and registered with `MemoryBudgetManager` — without going through a real async PLY
    /// load. Mirrors `GeometryStreamingEvictionTests.makeLoadedEntity`.
    @discardableResult
    private func makeLoadedGaussianEntity(
        distance: Float,
        memoryBytes: Int,
        streamingRadius: Float = 10.0,
        unloadRadius: Float = 20.0
    ) -> EntityID {
        let entityId = createEntity()

        if let local = scene.assign(to: entityId, component: LocalTransformComponent.self) {
            local.boundingBox = (
                min: simd_float3(distance - 0.5, -0.5, -0.5),
                max: simd_float3(distance + 0.5, 0.5, 0.5)
            )
        }
        if let world = scene.assign(to: entityId, component: WorldTransformComponent.self) {
            world.space = simd_float4x4(1.0)
        }
        if let streaming = scene.assign(to: entityId, component: StreamingComponent.self) {
            streaming.state = .loaded
            streaming.assetKind = .gaussianSplat
            streaming.assetFilename = "dummy_splat"
            streaming.assetExtension = "ply"
            streaming.streamingRadius = streamingRadius
            streaming.unloadRadius = unloadRadius
            streaming.lastVisibleFrame = 1
        }
        _ = scene.assign(to: entityId, component: GaussianComponent.self)

        GeometryStreamingSystem.shared.registerLoadedEntity(entityId)
        MemoryBudgetManager.shared.registerMesh(
            entityId: entityId,
            meshSizeBytes: memoryBytes,
            textureSizeBytes: 0
        )

        return entityId
    }

    // MARK: - StreamingAssetKind default

    func testStreamingComponentDefaultsToMeshAssetKind() {
        let component = StreamingComponent()
        XCTAssertEqual(component.assetKind, .mesh, "❌ Default assetKind should be .mesh so existing mesh streaming call sites are unaffected")
    }

    // MARK: - setEntityGaussianStreaming / findTileEntity

    /// End-to-end check of the consolidated API: given a positioned entity and a tile
    /// whose bounds contain that position, `setEntityGaussianStreaming` should parent it
    /// under that tile, register it with the octree, and configure it as a real gaussian
    /// streaming candidate — equivalent to `makeUnloadedGaussianEntity`'s manual assembly,
    /// but via the one public call callers are meant to use.
    func testSetEntityGaussianStreamable_attachesToContainingTileAndStreamsCorrectly() async {
        let tileRoot = createEntity()
        if let tileComp = scene.assign(to: tileRoot, component: TileComponent.self) {
            tileComp.state = .parsed
        }
        if let tileLocal = scene.get(component: LocalTransformComponent.self, for: tileRoot) {
            tileLocal.boundingBox = (min: simd_float3(-10, -10, -10), max: simd_float3(10, 10, 10))
        }
        OctreeSystem.shared.registerEntity(tileRoot)

        let entity = createEntity()
        translateTo(entityId: entity, position: .zero)

        setEntityGaussianStreaming(
            entityId: entity,
            source: .single(filename: "test_gaussians", withExtension: "ply"),
            options: GaussianStreamingOptions(
                streamingRadius: 10.0,
                unloadRadius: 20.0,
                boundingBoxHalfExtent: simd_float3(1, 1, 1)
            )
        )

        XCTAssertEqual(
            scene.get(component: ScenegraphComponent.self, for: entity)?.parent, tileRoot,
            "❌ Entity should be parented under the tile whose bounds contain its position"
        )

        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.assetKind, .gaussianSplat, "❌ assetKind should be set to .gaussianSplat")
        XCTAssertEqual(streaming?.assetFilename, "test_gaussians")
        XCTAssertEqual(streaming?.assetExtension, "ply")
        XCTAssertEqual(streaming?.streamingRadius, 10.0)
        XCTAssertEqual(streaming?.unloadRadius, 20.0)
        XCTAssertEqual(streaming?.state, .unloaded, "❌ Entity should start unloaded, same as any other streaming candidate")

        // Drive a real update() tick and confirm it streams in exactly like a manually
        // assembled gaussian streaming entity would.
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)
        await scene.get(component: StreamingComponent.self, for: entity)?.loadTask?.value

        XCTAssertEqual(scene.get(component: StreamingComponent.self, for: entity)?.state, .loaded, "❌ Entity should load once registered and in range")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: entity), "❌ GaussianComponent should be attached after load")
    }

    /// If no tile contains the entity's position, the entity should be left as a plain,
    /// non-streaming entity rather than crashing or silently half-configuring it.
    func testSetEntityGaussianStreaming_noContainingTileLeavesEntityNonStreaming() {
        let entity = createEntity()
        translateTo(entityId: entity, position: simd_float3(1000, 1000, 1000)) // no tile out here

        setEntityGaussianStreaming(
            entityId: entity,
            source: .single(filename: "test_gaussians", withExtension: "ply"),
            options: GaussianStreamingOptions(
                boundingBoxHalfExtent: simd_float3(1, 1, 1)
            )
        )

        XCTAssertNil(
            scene.get(component: StreamingComponent.self, for: entity),
            "❌ Entity should not get a StreamingComponent when no containing tile is found"
        )
    }

    /// `findTileEntity` should return the tile whose bounds contain the query point, and
    /// `nil` when nothing does.
    func testFindTileEntity_returnsContainingTileOrNil() {
        let tileRoot = createEntity()
        _ = scene.assign(to: tileRoot, component: TileComponent.self)
        if let tileLocal = scene.get(component: LocalTransformComponent.self, for: tileRoot) {
            tileLocal.boundingBox = (min: simd_float3(-5, -5, -5), max: simd_float3(5, 5, 5))
        }
        OctreeSystem.shared.registerEntity(tileRoot)

        XCTAssertEqual(findTileEntity(containing: .zero), tileRoot, "❌ Should find the tile containing the origin")
        XCTAssertNil(findTileEntity(containing: simd_float3(1000, 1000, 1000)), "❌ Should return nil when no tile contains the point")
    }

    // MARK: - Load lifecycle

    func testGaussianEntityOutsideStreamingRadiusStaysUnloaded() {
        let entity = makeUnloadedGaussianEntity(distance: 500.0, streamingRadius: 10.0, unloadRadius: 20.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)

        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.state, .unloaded, "❌ Entity far outside its streaming radius must stay unloaded")
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity), "❌ No GaussianComponent should be attached before the entity streams in")
    }

    func testGaussianEntityLoadsWhenCameraApproaches() async {
        let entity = makeUnloadedGaussianEntity(distance: 0.0, streamingRadius: 10.0, unloadRadius: 20.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)

        // loadMesh dispatched an async Task onto StreamingComponent.loadTask — await it
        // directly rather than polling, since Task<Void, Never> exposes `.value`.
        let task = scene.get(component: StreamingComponent.self, for: entity)?.loadTask
        await task?.value

        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.state, .loaded, "❌ Entity within streaming radius should finish loading")

        let gaussian = scene.get(component: GaussianComponent.self, for: entity)
        XCTAssertNotNil(gaussian, "❌ GaussianComponent should be attached after a successful streamed load")
        XCTAssertGreaterThan(gaussian?.splatCount ?? 0, 0, "❌ Loaded splat count should be nonzero")

        XCTAssertTrue(
            MemoryBudgetManager.shared.isTracked(entityId: entity),
            "❌ Streamed gaussian entity should be registered with MemoryBudgetManager, same as a streamed mesh"
        )
    }

    func testGaussianEntityUnloadsWhenCameraLeaves() {
        let entity = makeLoadedGaussianEntity(distance: 0.0, memoryBytes: 1024, streamingRadius: 10.0, unloadRadius: 20.0)
        visibleEntityIds = []

        let farCameraPosition = simd_float3(1000, 0, 0)
        for _ in 0 ..< 3 {
            GeometryStreamingSystem.shared.update(cameraPosition: farCameraPosition, deltaTime: 0.1)
        }

        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.state, .unloaded, "❌ Entity beyond unloadRadius should unload")
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity), "❌ GaussianComponent should be removed on unload")
        XCTAssertFalse(
            MemoryBudgetManager.shared.isTracked(entityId: entity),
            "❌ MemoryBudgetManager entry should be removed on unload so budget/eviction accounting stays accurate"
        )
    }

    func testGaussianEntityReloadsAfterCameraReturns() async {
        let entity = makeUnloadedGaussianEntity(distance: 0.0, streamingRadius: 10.0, unloadRadius: 20.0)

        // First approach: load.
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)
        await scene.get(component: StreamingComponent.self, for: entity)?.loadTask?.value

        XCTAssertEqual(scene.get(component: StreamingComponent.self, for: entity)?.state, .loaded, "Pre-condition: first load should succeed")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: entity), "Pre-condition: GaussianComponent should be attached after first load")

        // Retreat: unload.
        visibleEntityIds = []
        let farCameraPosition = simd_float3(1000, 0, 0)
        for _ in 0 ..< 3 {
            GeometryStreamingSystem.shared.update(cameraPosition: farCameraPosition, deltaTime: 0.1)
        }
        XCTAssertEqual(scene.get(component: StreamingComponent.self, for: entity)?.state, .unloaded, "Pre-condition: entity should unload when far")
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity), "Pre-condition: GaussianComponent should be removed on unload")

        // Re-approach: should load again.
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.1)
        let secondTask = scene.get(component: StreamingComponent.self, for: entity)?.loadTask
        await secondTask?.value

        let streaming = scene.get(component: StreamingComponent.self, for: entity)
        XCTAssertEqual(streaming?.state, .loaded, "❌ Entity should reload after camera re-enters streaming radius")

        let gaussian = scene.get(component: GaussianComponent.self, for: entity)
        XCTAssertNotNil(gaussian, "❌ GaussianComponent should be re-attached after reload")
        XCTAssertGreaterThan(gaussian?.splatCount ?? 0, 0, "❌ Reloaded splat count should be nonzero")
    }

    // MARK: - Tile ownership / tile unload interaction

    /// Regression test: `GeometryStreamingSystem.unloadTile` tears down every scenegraph
    /// descendant of a parsed tile via `collectTileDescendants` — necessary for the tile's
    /// own regenerable mesh content, but a gaussian-splat prop parented under the tile
    /// (the pattern `GameScene.addPoolTableSplat` uses to satisfy `isTileOwned`) must
    /// survive that sweep rather than being destroyed, since it is never regenerated by
    /// the tile's own parse pipeline. Without the assetKind == .gaussianSplat guard in
    /// collectTileDescendants, this destroys the splat entity outright the first time the
    /// surrounding tile unloads — after that, nothing recreates it, so it never streams
    /// back in no matter how many times the camera re-approaches.
    func testGaussianSplatSurvivesParentTileUnload() {
        let tileEntity = createEntity()
        guard let tileComp = scene.assign(to: tileEntity, component: TileComponent.self) else {
            XCTFail("Failed to assign TileComponent")
            return
        }
        tileComp.state = .parsed
        tileComp.tileId = "test_tile"

        // A regular mesh-kind child, representing tile-owned regenerable content —
        // this one SHOULD still be destroyed on tile unload. Uses setParent (not manual
        // ScenegraphComponent.parent assignment) since getEntityChildren reads the
        // parent's `children` array, which only setParent populates.
        let meshChild = createEntity()
        setParent(childId: meshChild, parentId: tileEntity)
        if let streaming = scene.assign(to: meshChild, component: StreamingComponent.self) {
            streaming.assetKind = .mesh
            streaming.state = .loaded
        }

        // A gaussian-splat prop attached the same way GameScene.addPoolTableSplat does —
        // this one must survive.
        let splatChild = createEntity()
        setParent(childId: splatChild, parentId: tileEntity)
        if let streaming = scene.assign(to: splatChild, component: StreamingComponent.self) {
            streaming.assetKind = .gaussianSplat
            streaming.state = .loaded
        }
        _ = scene.assign(to: splatChild, component: GaussianComponent.self)

        GeometryStreamingSystem.shared.unloadTile(entityId: tileEntity)

        XCTAssertFalse(scene.exists(meshChild), "❌ Regular mesh-kind tile child should still be destroyed on tile unload")
        XCTAssertTrue(scene.exists(splatChild), "❌ Gaussian-splat child must survive tile unload — it is not tile-owned regenerable content")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: splatChild), "❌ Splat's GaussianComponent should be untouched by tile unload")
        XCTAssertEqual(
            scene.get(component: StreamingComponent.self, for: splatChild)?.state, .loaded,
            "❌ Splat's own streaming state should be unaffected by tile unload — it's governed independently by its own radii"
        )
    }

    // MARK: - Shared eviction pool

    func testFarGaussianEntityIsEvictedUnderMemoryPressureAheadOfCloseOne() {
        let closeEntity = makeLoadedGaussianEntity(distance: 5.0, memoryBytes: 50 * 1024 * 1024, streamingRadius: 500, unloadRadius: 500)
        let farEntity = makeLoadedGaussianEntity(distance: 200.0, memoryBytes: 51 * 1024 * 1024, streamingRadius: 500, unloadRadius: 500)

        // Both visible; total 101 MB > 85 MB high-water mark on a 100 MB budget.
        visibleEntityIds = [closeEntity, farEntity]

        XCTAssertTrue(MemoryBudgetManager.shared.shouldEvict(), "Pre-condition: budget should be over threshold")

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 1.0)

        let closeState = scene.get(component: StreamingComponent.self, for: closeEntity)?.state
        let farState = scene.get(component: StreamingComponent.self, for: farEntity)?.state

        XCTAssertEqual(closeState, .loaded, "❌ Close visible splat (within visibleEvictionProtectionRadius) must not be evicted")
        XCTAssertEqual(farState, .unloaded, "❌ Far visible splat must be evicted through the same evictLRU pool meshes use")
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: farEntity), "❌ Evicted splat's GaussianComponent should be torn down")
    }

    // MARK: - markUsed correctness

    /// `executeGaussianFrustumCulling` must call `MemoryBudgetManager.markUsed` for entities
    /// that survive its per-splat frustum test, since gaussian-only entities are structurally
    /// excluded from the RenderComponent-keyed query that normally feeds `markUsed`
    /// (see CullingSystem.swift). Without this, a loaded, on-screen splat would look
    /// permanently stale to `evictLRU`.
    func testVisibleGaussianEntityIsMarkedUsedByFrustumCulling() {
        let entity = createEntity()
        setEntityGaussian(entityId: entity, filename: "test_gaussians", withExtension: "ply")
        XCTAssertNotNil(scene.get(component: GaussianComponent.self, for: entity), "Pre-condition: gaussian asset should load synchronously")

        // setEntityGaussian already registers with MemoryBudgetManager at the current frame;
        // capture that baseline so we can detect markUsed advancing it once rendering runs.
        let beforeFrame = MemoryBudgetManager.shared.getLastUsedFrame(for: entity)

        let expectation = XCTestExpectation(description: "Gaussian render pass completes")
        renderer.draw(in: renderer.metalView)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: TimeInterval(timeoutFactor))

        let afterFrame = MemoryBudgetManager.shared.getLastUsedFrame(for: entity)
        XCTAssertNotNil(afterFrame, "❌ Entity should still be tracked by MemoryBudgetManager after rendering")
        XCTAssertNotEqual(
            afterFrame, beforeFrame,
            "❌ markUsed should have advanced lastUsedFrame for a splat entity that survived frustum culling this frame"
        )
    }
}
