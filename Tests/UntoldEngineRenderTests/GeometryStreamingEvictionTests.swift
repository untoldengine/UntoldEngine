//
//  GeometryStreamingEvictionTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ModelIO
import simd
@testable import UntoldEngine
import XCTest

/// Tests for the eviction and concurrency fixes introduced alongside the
/// distance-aware visibility guard (`visibleEvictionProtectionRadius`).
///
/// These tests do NOT require actual GPU uploads. They verify the control-flow
/// decisions made by `GeometryStreamingSystem.evictLRU` and the near-band
/// concurrency limiter — both of which are purely CPU-side.
@MainActor
final class GeometryStreamingEvictionTests: BaseRenderSetup {
    // MARK: - Setup / Teardown

    override func setUp() async throws {
        try await super.setUp()

        // Reset both systems to a known, isolated state before each test.
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0 // no throttle
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.nearBandFraction = 0.33
        GeometryStreamingSystem.shared.nearBandMaxConcurrentLoads = 1
        GeometryStreamingSystem.shared.visibleEvictionProtectionRadius = 30.0
        GeometryStreamingSystem.shared.evictionDistanceWeight = 0.6
        GeometryStreamingSystem.shared.evictionSizeWeight = 0.4
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0

        // Clear budget so base-setup entity registrations don't interfere.
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        // GeometryStreamingSystem eviction uses the geometry pool only. Setting the
        // combined meshBudget would split 100 MB into 60 MB geometry / 40 MB texture,
        // which breaks the documented arithmetic in the value-score eviction tests.
        MemoryBudgetManager.shared.geometryBudget = 100 * 1024 * 1024 // 100 MB
        MemoryBudgetManager.shared.textureBudget = 0
        MemoryBudgetManager.shared.highWaterMark = 0.85
        MemoryBudgetManager.shared.lowWaterMark = 0.70

        // Clear the global visible-entity list so tests control it explicitly.
        visibleEntityIds = []
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.updateInterval = 0.1
        MemoryBudgetManager.shared.clear()
        visibleEntityIds = []
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Create an entity that is already loaded (state = .loaded) and tracked by
    /// the streaming system, placed at `(distance, 0, 0)` from the origin.
    ///
    /// `evictLRU` discovers it via `loadedStreamingEntitiesSnapshot()`.
    @discardableResult
    private func makeLoadedEntity(
        distance: Float,
        memoryBytes: Int,
        streamingRadius: Float = 100.0,
        unloadRadius: Float = 200.0
    ) -> EntityID {
        let entityId = createEntity()

        // Place the bounding-box center at (distance, 0, 0) with an identity
        // WorldTransform. calculateDistance() uses (bb.min + bb.max) / 2
        // multiplied by WorldTransform.space.
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
            streaming.streamingRadius = streamingRadius
            streaming.unloadRadius = unloadRadius
            streaming.assetFilename = "dummy"
            streaming.assetExtension = "usdz"
            streaming.lastVisibleFrame = 1
        }

        // Register in streaming system tracking set (same path as a real load).
        GeometryStreamingSystem.shared.registerLoadedEntity(entityId)

        // Register memory so shouldEvict() / canAccept() see it.
        MemoryBudgetManager.shared.registerMesh(
            entityId: entityId,
            meshSizeBytes: memoryBytes,
            textureSizeBytes: 0
        )

        return entityId
    }

    /// Create an entity that is unloaded (state = .unloaded) and registered
    /// in the octree so `update()` discovers it as a load candidate.
    @discardableResult
    private func makeUnloadedEntity(
        distance: Float,
        streamingRadius: Float = 100.0,
        unloadRadius: Float = 200.0
    ) -> EntityID {
        // StreamingComponent loads are now restricted to tile-owned entities.
        // Create a minimal tile parent so this fixture exercises the scheduler
        // rather than the non-tile ownership guard.
        let tileRoot = createEntity()
        _ = scene.assign(to: tileRoot, component: TileComponent.self)

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
            streaming.streamingRadius = streamingRadius
            streaming.unloadRadius = unloadRadius
            // Intentionally nonexistent asset so loadMeshAsync returns false quickly.
            streaming.assetFilename = "nonexistent_test_asset"
            streaming.assetExtension = "usdz"
        }

        // Must be in octree so the spatial query in update() finds it as a candidate.
        OctreeSystem.shared.registerEntity(entityId)

        return entityId
    }

    // MARK: - Test 1: CPUMeshEntry estimatedGPUBytes round-trip

    /// `estimatedGPUBytes` is computed at stub-registration time and stored in
    /// `CPUMeshEntry`. Verify the value survives `storeCPUMesh` / `retrieveCPUMesh`
    /// and is cleared by `removeCPUMesh`.
    func testCPUMeshEntryEstimatedGPUBytesStoredAndRetrieved() {
        let entityId: EntityID = 99001
        let expectedBytes = 1_234_567

        let entry = ProgressiveAssetLoader.CPUMeshEntry(
            object: MDLObject(),
            vertexDescriptor: MDLVertexDescriptor(),
            textureLoader: TextureLoader(device: renderInfo.device),
            device: renderInfo.device,
            url: URL(fileURLWithPath: "/dev/null"),
            filename: "test",
            withExtension: "usdz",
            uniqueAssetName: "TestMesh#0",
            estimatedGPUBytes: expectedBytes,
            residencyPolicy: .fullLoad
        )

        ProgressiveAssetLoader.shared.storeCPUMesh(entry, for: entityId)

        let retrieved = ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId)
        XCTAssertEqual(
            retrieved?.estimatedGPUBytes, expectedBytes,
            "estimatedGPUBytes should survive storeCPUMesh / retrieveCPUMesh round-trip"
        )

        ProgressiveAssetLoader.shared.removeCPUMesh(for: entityId)
        XCTAssertNil(
            ProgressiveAssetLoader.shared.retrieveCPUMesh(for: entityId),
            "Entry should be absent after removeCPUMesh"
        )
    }

    // MARK: - Test 2: Far visible entity is evicted under budget pressure

    /// Regression test for the zoom-out → zoom-in eviction deadlock.
    ///
    /// Before the fix, `evictLRU` would skip every entity that appeared in
    /// `visibleEntityIds` regardless of distance, making eviction a complete
    /// no-op whenever all loaded meshes were in the frustum. Far visible meshes
    /// would permanently occupy the budget, blocking nearby meshes from loading.
    ///
    /// After the fix, entities beyond `visibleEvictionProtectionRadius` (30 m)
    /// may be evicted even while visible.
    func testFarVisibleEntityIsEvictedUnderBudgetPressure() {
        // Close entity (10 m) — inside protection radius, must NOT be evicted.
        let closeEntity = makeLoadedEntity(distance: 10.0, memoryBytes: 50 * 1024 * 1024)
        // Far entity (200 m) — outside protection radius, MUST be evicted.
        let farEntity = makeLoadedEntity(distance: 200.0, memoryBytes: 50 * 1024 * 1024)

        // Both are visible (in-frustum). Total = 100 MB → exactly at budget.
        // Adding 1 byte pushes shouldEvict() over 85 % high-water mark.
        // Instead of a third entity, tip the budget by adjusting the far entity's size.
        // Re-register far entity with 51 MB to push total to 101 MB (> 85 % of 100 MB).
        MemoryBudgetManager.shared.unregisterMesh(entityId: farEntity)
        MemoryBudgetManager.shared.registerMesh(
            entityId: farEntity,
            meshSizeBytes: 51 * 1024 * 1024,
            textureSizeBytes: 0
        )

        // Both entities are visible.
        visibleEntityIds = [closeEntity, farEntity]

        XCTAssertTrue(MemoryBudgetManager.shared.shouldEvict(), "Pre-condition: budget should be over threshold")

        // Camera at origin (distance to closeEntity ≈ 10 m, farEntity ≈ 200 m).
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 1.0)

        let closeState = scene.get(component: StreamingComponent.self, for: closeEntity)?.state
        let farState = scene.get(component: StreamingComponent.self, for: farEntity)?.state

        XCTAssertEqual(closeState, .loaded,
                       "Close visible entity (10 m < 30 m protection radius) must NOT be evicted")
        XCTAssertEqual(farState, .unloaded,
                       "Far visible entity (200 m > 30 m protection radius) MUST be evicted to free budget")
    }

    // MARK: - Test 3: Close visible entity is protected from eviction

    /// Entities within `visibleEvictionProtectionRadius` must never be evicted
    /// while visible, even under severe budget pressure.
    func testCloseVisibleEntityIsProtectedFromEviction() {
        // One entity very close to camera (5 m), well inside 30 m protection radius.
        let closeEntity = makeLoadedEntity(distance: 5.0, memoryBytes: 90 * 1024 * 1024)

        // Visible and budget over threshold.
        visibleEntityIds = [closeEntity]

        XCTAssertTrue(MemoryBudgetManager.shared.shouldEvict(), "Pre-condition: budget should be over threshold")

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 1.0)

        let state = scene.get(component: StreamingComponent.self, for: closeEntity)?.state
        XCTAssertEqual(state, .loaded,
                       "Visible entity within visibleEvictionProtectionRadius (5 m < 30 m) must remain loaded")
    }

    // MARK: - Test 4: Value-score sorts eviction candidates correctly

    /// Far + large entities must be evicted before far + small, which must be
    /// evicted before near + large.
    ///
    /// Scores (evictionDistanceWeight=0.6, evictionSizeWeight=0.4, budget=100 MB,
    /// maxQueryRadius=500 m):
    ///   A  200 m, 50 MB  →  0.6·(200/500) + 0.4·(50/100) = 0.44  (highest)
    ///   B  200 m,  5 MB  →  0.6·(200/500) + 0.4·( 5/100) = 0.26
    ///   C   10 m, 50 MB  →  0.6·( 10/500) + 0.4·(50/100) = 0.21  (lowest)
    ///
    /// Eviction stops once shouldEvict() returns false. With a 100 MB budget at
    /// 85 % high-water mark, evicting A (50 MB) drops utilisation to ~55 MB and
    /// shouldEvict() turns false — B and C remain loaded.
    func testValueScoreEvictsHighScoreEntityFirst() {
        let entityA = makeLoadedEntity(distance: 200.0, memoryBytes: 50 * 1024 * 1024) // far + large
        let entityB = makeLoadedEntity(distance: 200.0, memoryBytes: 5 * 1024 * 1024) // far + small
        let entityC = makeLoadedEntity(distance: 10.0, memoryBytes: 50 * 1024 * 1024) // near + large
        // Total: 105 MB → shouldEvict() fires.

        // None are visible — visibility guard should not interfere.
        visibleEntityIds = []

        XCTAssertTrue(MemoryBudgetManager.shared.shouldEvict(), "Pre-condition: budget should be over threshold")

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 1.0)

        let stateA = scene.get(component: StreamingComponent.self, for: entityA)?.state
        let stateB = scene.get(component: StreamingComponent.self, for: entityB)?.state
        let stateC = scene.get(component: StreamingComponent.self, for: entityC)?.state

        // A has the highest score and must be evicted first. Evicting A brings
        // utilisation below the threshold, so B and C are left intact.
        XCTAssertEqual(stateA, .unloaded, "Entity A (far + large, highest score) must be evicted first")
        XCTAssertEqual(stateB, .loaded, "Entity B (far + small) must remain loaded after one eviction")
        XCTAssertEqual(stateC, .loaded, "Entity C (near + large) must remain loaded after one eviction")
    }

    // MARK: - Test 5: Near-band concurrency limit is enforced

    /// When `nearBandMaxConcurrentLoads = 1`, at most one near-band entity
    /// should transition to `.loading` per `update()` call, regardless of how
    /// many near-band candidates are available.
    ///
    /// The async load Tasks are not awaited here — the test checks state
    /// immediately after `update()` returns, before any Task completes.
    func testNearBandConcurrencyLimitIsEnforced() {
        // 5 unloaded entities all within nearBand distance.
        // streamingRadius=100, nearBandFraction=0.33 → near band ≤ 33 m.
        let nearBandEntities = (0 ..< 5).map { i in
            makeUnloadedEntity(
                distance: Float(i + 1) * 5.0, // 5, 10, 15, 20, 25 m
                streamingRadius: 100.0,
                unloadRadius: 200.0
            )
        }

        // Budget has plenty of headroom — only the concurrency cap should limit starts.
        XCTAssertFalse(MemoryBudgetManager.shared.shouldEvict(), "Pre-condition: budget must be under threshold")

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 1.0)

        // Count entities that entered .loading state synchronously.
        let loadingCount = nearBandEntities.filter {
            scene.get(component: StreamingComponent.self, for: $0)?.state == .loading
        }.count

        XCTAssertLessThanOrEqual(
            loadingCount,
            GeometryStreamingSystem.shared.nearBandMaxConcurrentLoads,
            "At most nearBandMaxConcurrentLoads (\(GeometryStreamingSystem.shared.nearBandMaxConcurrentLoads)) near-band loads should start per update()"
        )
        XCTAssertGreaterThan(loadingCount, 0,
                             "At least one near-band load should have been started")
    }
}
