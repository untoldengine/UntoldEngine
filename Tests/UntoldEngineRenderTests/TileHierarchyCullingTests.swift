//
//  TileHierarchyCullingTests.swift
//  UntoldEngine
//
//  Tests for hierarchy-aware tile culling.
//  Coverage areas:
//    1. buildTileHierarchyIndex — correctness of parent-prefix grouping and AABB union.
//    2. Hierarchy gate — integration tests verifying that candidate tiles whose parent
//       region is fully occluded by loaded geometry are skipped by the streaming system.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

// MARK: - buildTileHierarchyIndex unit tests

/// Tests the index-building logic: given tile entities registered in the ECS with
/// quadtreeNodeId set, buildTileHierarchyIndex must produce the correct parent-prefix
/// entries and union AABBs.  No camera or rendering is required.
@MainActor
final class TileHierarchyIndexTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        GeometryStreamingSystem.shared.reset()
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: Helpers

    private func makeTileEntity(
        nodeId: String?,
        bbMin: simd_float3,
        bbMax: simd_float3
    ) -> EntityID {
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        if let lt = scene.get(component: LocalTransformComponent.self, for: entityId) {
            lt.boundingBox.min = bbMin
            lt.boundingBox.max = bbMax
        }
        registerComponent(entityId: entityId, componentType: TileComponent.self)
        if let tc = scene.get(component: TileComponent.self, for: entityId) {
            tc.tileId = nodeId ?? "v3_tile"
            tc.quadtreeNodeId = nodeId
            tc.state = .unloaded
        }
        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    // MARK: Tests

    func testBuildIndex_emptyForV3Tiles() {
        // Tiles with nil quadtreeNodeId (v3 uniform-grid) must not produce any entries.
        _ = makeTileEntity(nodeId: nil, bbMin: .zero, bbMax: simd_float3(1, 1, 1))
        _ = makeTileEntity(nodeId: nil, bbMin: simd_float3(2, 0, 0), bbMax: simd_float3(3, 1, 1))

        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        XCTAssertTrue(
            GeometryStreamingSystem.shared.tileHierarchyIndex.isEmpty,
            "v3 tiles without quadtreeNodeId must not populate the hierarchy index"
        )
    }

    func testBuildIndex_singleTileCreatesParentEntry() throws {
        // "F01_Q_0_0" → parent prefix "F01_Q_0"
        _ = makeTileEntity(
            nodeId: "F01_Q_0_0",
            bbMin: simd_float3(0, 0, 0),
            bbMax: simd_float3(10, 5, 10)
        )

        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        let index = GeometryStreamingSystem.shared.tileHierarchyIndex
        XCTAssertEqual(index.count, 1)
        let entry = try XCTUnwrap(index["F01_Q_0"])
        XCTAssertTrue(simd_length(entry.min - simd_float3(0, 0, 0)) < 1e-4, "min mismatch: \(entry.min)")
        XCTAssertTrue(simd_length(entry.max - simd_float3(10, 5, 10)) < 1e-4, "max mismatch: \(entry.max)")
    }

    func testBuildIndex_twoTilesWithSamePrefixUnionAABBs() throws {
        // "F01_Q_0_0" and "F01_Q_0_1" share parent prefix "F01_Q_0"; union AABB must span both.
        _ = makeTileEntity(
            nodeId: "F01_Q_0_0",
            bbMin: simd_float3(0, 0, 0),
            bbMax: simd_float3(5, 5, 5)
        )
        _ = makeTileEntity(
            nodeId: "F01_Q_0_1",
            bbMin: simd_float3(3, 3, 3),
            bbMax: simd_float3(10, 10, 10)
        )

        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        let index = GeometryStreamingSystem.shared.tileHierarchyIndex
        XCTAssertEqual(index.count, 1, "Two tiles with the same prefix must produce one parent entry")
        let entry = try XCTUnwrap(index["F01_Q_0"])
        XCTAssertTrue(simd_length(entry.min - simd_float3(0, 0, 0)) < 1e-4, "Union min must be the global minimum, got: \(entry.min)")
        XCTAssertTrue(simd_length(entry.max - simd_float3(10, 10, 10)) < 1e-4, "Union max must be the global maximum, got: \(entry.max)")
    }

    func testBuildIndex_twoTilesWithDifferentPrefixesAreSeparate() {
        // "F01_Q_0_0" → prefix "F01_Q_0"; "F02_Q_0_0" → prefix "F02_Q_0" — two distinct entries.
        _ = makeTileEntity(
            nodeId: "F01_Q_0_0",
            bbMin: simd_float3(0, 0, 0),
            bbMax: simd_float3(5, 5, 5)
        )
        _ = makeTileEntity(
            nodeId: "F02_Q_0_0",
            bbMin: simd_float3(10, 0, 0),
            bbMax: simd_float3(15, 5, 5)
        )

        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        let index = GeometryStreamingSystem.shared.tileHierarchyIndex
        XCTAssertEqual(index.count, 2, "Tiles with different prefixes must produce separate entries")
        XCTAssertNotNil(index["F01_Q_0"])
        XCTAssertNotNil(index["F02_Q_0"])
    }

    func testBuildIndex_nodeIdWithNoUnderscoreIsSkipped() {
        // A nodeId with no underscore has no derivable parent prefix — must be skipped.
        _ = makeTileEntity(
            nodeId: "ROOTONLY",
            bbMin: simd_float3(0, 0, 0),
            bbMax: simd_float3(5, 5, 5)
        )

        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        XCTAssertTrue(
            GeometryStreamingSystem.shared.tileHierarchyIndex.isEmpty,
            "A nodeId with no underscore has no parent prefix and must not produce an index entry"
        )
    }

    func testBuildIndex_clearedOnReset() {
        _ = makeTileEntity(
            nodeId: "F01_Q_0_0",
            bbMin: simd_float3(0, 0, 0),
            bbMax: simd_float3(5, 5, 5)
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()
        XCTAssertFalse(GeometryStreamingSystem.shared.tileHierarchyIndex.isEmpty, "Pre-condition: index must be populated")

        GeometryStreamingSystem.shared.reset()

        XCTAssertTrue(
            GeometryStreamingSystem.shared.tileHierarchyIndex.isEmpty,
            "reset() must clear the tile hierarchy index"
        )
    }
}

// MARK: - Hierarchy gate integration tests

/// Verifies that the hierarchy gate in the streaming candidate loop correctly skips
/// tiles whose parent region is fully occluded by loaded geometry, and leaves tiles
/// unaffected when the gate conditions are not met.
@MainActor
final class TileHierarchyGateTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0
        GeometryStreamingSystem.shared.enableFrustumGate = false
        GeometryStreamingSystem.shared.enableOcclusionSort = true
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 10
        GeometryStreamingSystem.shared.occlusionFullThreshold = 0.85
        GeometryStreamingSystem.shared.occlusionMinWeight = 0.05
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.geometryBudget = 512 * 1024 * 1024
        MemoryBudgetManager.shared.textureBudget = 256 * 1024 * 1024
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.enableFrustumGate = true
        GeometryStreamingSystem.shared.enableOcclusionSort = true
        CameraSystem.shared.activeCamera = nil
        MemoryBudgetManager.shared.clear()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: Helpers

    private func setUpCameraLookingNegativeZ() {
        let camera = findGameCamera()
        CameraSystem.shared.activeCamera = camera
        cameraLookAt(
            entityId: camera,
            eye: .zero,
            target: simd_float3(0, 0, -1),
            up: simd_float3(0, 1, 0)
        )
    }

    /// Creates an unloaded tile stub with an optional quadtreeNodeId.
    private func makeCandidateTile(
        center: simd_float3,
        halfExtent: simd_float3 = simd_float3(5, 5, 5),
        nodeId: String?
    ) -> EntityID {
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        if let lt = scene.get(component: LocalTransformComponent.self, for: entityId) {
            lt.position = center
            lt.boundingBox.min = center - halfExtent
            lt.boundingBox.max = center + halfExtent
        }
        registerComponent(entityId: entityId, componentType: TileComponent.self)
        if let tc = scene.get(component: TileComponent.self, for: entityId) {
            tc.tileId = nodeId ?? "v3_candidate"
            tc.quadtreeNodeId = nodeId
            tc.tileURL = URL(fileURLWithPath: "/dev/null")
            tc.streamingRadius = 1000.0
            tc.unloadRadius = 2000.0
            tc.state = .unloaded
        }
        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    /// Creates a fully loaded tile that acts as an occluder for the streaming system.
    /// The tile's AABB is sized to cover the entire visible screen area from the camera.
    private func makeFullScreenOccluder(distance: Float = 5.0) -> EntityID {
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        // Very large AABB close to camera — projects to cover the full NDC screen.
        let center = simd_float3(0, 0, -distance)
        let halfExtent = simd_float3(200, 200, 1)
        if let lt = scene.get(component: LocalTransformComponent.self, for: entityId) {
            lt.position = center
            lt.boundingBox.min = center - halfExtent
            lt.boundingBox.max = center + halfExtent
        }
        registerComponent(entityId: entityId, componentType: TileComponent.self)
        if let tc = scene.get(component: TileComponent.self, for: entityId) {
            tc.tileId = "occluder_tile"
            tc.state = .parsed
            tc.streamingRadius = 1000.0
            tc.unloadRadius = 2000.0
        }
        OctreeSystem.shared.registerEntity(entityId)
        GeometryStreamingSystem.shared.markLoadedTileEntity(entityId)
        return entityId
    }

    // MARK: Tests

    func testHierarchyGate_inactiveWhenOcclusionSortDisabled() throws {
        // Even with a full-screen occluder, disabling occlusion sort must let
        // the candidate through — the hierarchy gate depends on the occluder list.
        setUpCameraLookingNegativeZ()
        GeometryStreamingSystem.shared.enableOcclusionSort = false

        _ = makeFullScreenOccluder()
        let candidate = makeCandidateTile(
            center: simd_float3(0, 0, -50),
            nodeId: "F01_Q_0_0"
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: candidate))
        XCTAssertEqual(tc.state, .parsing,
                       "Hierarchy gate must be inactive when enableOcclusionSort is false")
    }

    func testHierarchyGate_doesNotApplyToV3Tiles() throws {
        // Tiles without quadtreeNodeId (v3) must ignore the hierarchy index entirely
        // and load normally regardless of what is in tileHierarchyIndex.
        setUpCameraLookingNegativeZ()

        _ = makeFullScreenOccluder()
        let candidate = makeCandidateTile(
            center: simd_float3(0, 0, -50),
            nodeId: nil // v3 — no hierarchy ID
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: candidate))
        XCTAssertEqual(tc.state, .parsing,
                       "v3 tiles without quadtreeNodeId must not be blocked by the hierarchy gate")
    }

    func testHierarchyGate_allowsChildWhenNoOccluders() throws {
        // With no loaded tiles the occluder list is empty, so occludedParentRegions
        // is never populated and every candidate tile must pass through.
        setUpCameraLookingNegativeZ()

        let candidate = makeCandidateTile(
            center: simd_float3(0, 0, -50),
            nodeId: "F01_Q_0_0"
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: candidate))
        XCTAssertEqual(tc.state, .parsing,
                       "Tile must load when there are no occluders to populate occludedParentRegions")
    }

    func testHierarchyGate_blocksChildWhenParentRegionIsOccluded() throws {
        // A full-screen occluder close to the camera covers 100% of the parent region's
        // screen footprint.  The hierarchy gate must block the candidate tile.
        setUpCameraLookingNegativeZ()

        _ = makeFullScreenOccluder(distance: 5.0)
        // Candidate is behind the occluder on the same view axis.
        let candidate = makeCandidateTile(
            center: simd_float3(0, 0, -50),
            nodeId: "F01_Q_0_0"
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: candidate))
        XCTAssertEqual(tc.state, .unloaded,
                       "Tile must not be dispatched when its parent region is fully occluded")
    }
}
