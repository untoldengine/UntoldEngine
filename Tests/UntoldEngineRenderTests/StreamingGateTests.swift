//
//  StreamingGateTests.swift
//  UntoldEngine
//
//  Unit tests for three streaming gate behaviors:
//    1. Interior zone gate  — mesh streaming pass, TileComponent.isInterior flag
//    2. Frustum gate        — tile streaming pass, camera frustum culling
//    3. Velocity predictor  — tile streaming pass, look-ahead distance
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@preconcurrency @testable import UntoldEngine
import XCTest

@MainActor
final class StreamingGateTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0
        GeometryStreamingSystem.shared.enableFrustumGate = false // disabled by default; re-enabled per test
        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.geometryBudget = 512 * 1024 * 1024
        MemoryBudgetManager.shared.textureBudget = 256 * 1024 * 1024
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.enableFrustumGate = true // restore default
        GeometryStreamingSystem.shared.interiorZone = nil
        CameraSystem.shared.activeCamera = nil
        MemoryBudgetManager.shared.clear()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    // MARK: - Entity builders

    /// Creates an entity that the mesh streaming pass will evaluate for loading.
    /// Both StreamingComponent (state=.unloaded) and TileComponent (state=.parsed,
    /// isInterior=true) are attached to the same entity so the interior gate condition
    /// `scene.get(TileComponent, for: entityId)?.isInterior` can fire.
    /// TileComponent.state is forced to .parsed so the tile streaming pass skips it,
    /// leaving only the mesh streaming pass to exercise the interior gate.
    private func makeInteriorEntity(
        at worldPos: simd_float3,
        streamingRadius: Float,
        isInterior: Bool = true
    ) -> EntityID {
        let entityId = createEntity()
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        if let lt = scene.get(component: LocalTransformComponent.self, for: entityId) {
            lt.position = worldPos
            lt.boundingBox.min = worldPos - simd_float3(1, 1, 1)
            lt.boundingBox.max = worldPos + simd_float3(1, 1, 1)
        }
        // World transform stays at .identity — entity is at worldPos in world space.

        registerComponent(entityId: entityId, componentType: StreamingComponent.self)
        if let s = scene.get(component: StreamingComponent.self, for: entityId) {
            s.assetFilename = "interior_gate_stub"
            s.assetExtension = "untold"
            s.streamingRadius = streamingRadius
            s.unloadRadius = streamingRadius * 2.0
            s.state = .unloaded
        }

        // TileComponent in .parsed state prevents the tile streaming pass from calling
        // loadTile on this entity — only the mesh streaming pass sees it.
        // isTileOwned() walks up the parent chain; finding TileComponent on the entity
        // itself satisfies the rule, so loadMesh proceeds when the gate passes.
        registerComponent(entityId: entityId, componentType: TileComponent.self)
        if let tc = scene.get(component: TileComponent.self, for: entityId) {
            tc.isInterior = isInterior
            tc.tileId = "interior_gate_test"
            tc.state = .parsed
            tc.streamingRadius = streamingRadius
            tc.unloadRadius = streamingRadius * 2.0
        }

        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    /// Creates a bare tile stub (TileComponent only, no StreamingComponent) for the
    /// tile streaming pass frustum-gate and velocity-predictor tests.
    /// A fake file path is used; the tile enters .parsing synchronously in loadTile,
    /// which is all the tests need to observe.
    private func makeTileStub(
        center: simd_float3,
        halfExtent: simd_float3 = simd_float3(1, 1, 1),
        streamingRadius: Float,
        unloadRadius: Float,
        hasFloorMetadata: Bool = false,
        worldYCenter: Float? = nil,
        isInterior: Bool = true
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
            tc.tileId = "gate_test_tile_\(entityId)"
            tc.tileURL = URL(fileURLWithPath: "/dev/null") // parse fails fast; .parsing is set synchronously
            tc.streamingRadius = streamingRadius
            tc.unloadRadius = unloadRadius
            tc.hasFloorMetadata = hasFloorMetadata
            tc.worldYCenter = worldYCenter ?? center.y
            tc.isInterior = isInterior
            tc.state = .unloaded
        }

        OctreeSystem.shared.registerEntity(entityId)
        return entityId
    }

    // MARK: - Interior zone gate

    func testInteriorZoneGate_blocksEntityWhenCameraIsOutside() throws {
        // Zone far from origin; camera at origin is outside it.
        GeometryStreamingSystem.shared.interiorZone = AABB(
            min: simd_float3(40, -5, -5),
            max: simd_float3(60, 5, 5)
        )

        let entity = makeInteriorEntity(at: .zero, streamingRadius: 50.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let s = try XCTUnwrap(scene.get(component: StreamingComponent.self, for: entity))
        XCTAssertEqual(s.state, .unloaded,
                       "Interior gate must block loading when camera is outside interiorZone")
    }

    func testInteriorZoneGate_allowsEntityWhenCameraIsInside() throws {
        // Zone encompasses the origin; camera at origin is inside it.
        GeometryStreamingSystem.shared.interiorZone = AABB(
            min: simd_float3(-5, -5, -5),
            max: simd_float3(5, 5, 5)
        )

        let entity = makeInteriorEntity(at: .zero, streamingRadius: 50.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let s = try XCTUnwrap(scene.get(component: StreamingComponent.self, for: entity))
        XCTAssertNotEqual(s.state, .unloaded,
                          "Interior gate must allow loading when camera is inside interiorZone")
    }

    func testInteriorZoneGate_doesNotApplyWhenZoneIsNil() throws {
        // No zone configured — gate is inactive; entity loads regardless of position.
        GeometryStreamingSystem.shared.interiorZone = nil

        let entity = makeInteriorEntity(at: .zero, streamingRadius: 50.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let s = try XCTUnwrap(scene.get(component: StreamingComponent.self, for: entity))
        XCTAssertNotEqual(s.state, .unloaded,
                          "Interior gate must be inactive when interiorZone is nil")
    }

    func testInteriorZoneGate_doesNotApplyToNonInteriorEntities() throws {
        // Zone does not contain origin, but this entity is NOT tagged isInterior.
        GeometryStreamingSystem.shared.interiorZone = AABB(
            min: simd_float3(40, -5, -5),
            max: simd_float3(60, 5, 5)
        )

        // isInterior = false — gate condition short-circuits before zone check.
        let entity = makeInteriorEntity(at: .zero, streamingRadius: 50.0, isInterior: false)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let s = try XCTUnwrap(scene.get(component: StreamingComponent.self, for: entity))
        XCTAssertNotEqual(s.state, .unloaded,
                          "Non-interior entities must not be blocked by the interior zone gate")
    }

    // MARK: - Frustum gate

    /// Sets up the active camera looking toward -Z from the origin, which is the
    /// orientation expected by all frustum gate tests.
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

    func testFrustumGate_tileInFrustumGetsDispatched() throws {
        setUpCameraLookingNegativeZ()
        GeometryStreamingSystem.shared.enableFrustumGate = true

        // Tile directly in front of camera — well inside the frustum.
        let tile = makeTileStub(
            center: simd_float3(0, 0, -30),
            streamingRadius: 1000.0,
            unloadRadius: 2000.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .parsing,
                       "Tile inside the camera frustum must be dispatched to .parsing")
    }

    func testFrustumGate_tileOutOfFrustumIsSkipped() throws {
        setUpCameraLookingNegativeZ()
        GeometryStreamingSystem.shared.enableFrustumGate = true

        // Tile 500 m to the right — beyond the frustum side plane (fov=65°, tilePad=20 m).
        let tile = makeTileStub(
            center: simd_float3(500, 0, 0),
            streamingRadius: 1000.0,
            unloadRadius: 2000.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .unloaded,
                       "Tile entirely outside the camera frustum must not be dispatched")
    }

    func testFrustumGate_disabledFlagAllowsAllTiles() throws {
        setUpCameraLookingNegativeZ()
        GeometryStreamingSystem.shared.enableFrustumGate = false // override default

        let inFrustum = makeTileStub(center: simd_float3(0, 0, -30), streamingRadius: 1000.0, unloadRadius: 2000.0)
        let outOfFrustum = makeTileStub(center: simd_float3(500, 0, 0), streamingRadius: 1000.0, unloadRadius: 2000.0)

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcIn = try XCTUnwrap(scene.get(component: TileComponent.self, for: inFrustum))
        let tcOut = try XCTUnwrap(scene.get(component: TileComponent.self, for: outOfFrustum))

        // Both should be dispatched — frustum gate is off.
        // maxConcurrentTileLoads defaults to 2, so both can be in-flight simultaneously.
        XCTAssertEqual(tcIn.state, .parsing, "In-frustum tile must dispatch when gate is disabled")
        XCTAssertEqual(tcOut.state, .parsing, "Out-of-frustum tile must also dispatch when gate is disabled")
    }

    // MARK: - Floor proximity gate

    func testFloorProximityGate_ignoresLargeYCenterWithoutFloorMetadata() throws {
        let tile = makeTileStub(
            center: .zero,
            streamingRadius: 1000.0,
            unloadRadius: 2000.0,
            hasFloorMetadata: false,
            worldYCenter: 5000.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .parsing,
                       "Uniform-grid tiles must not be floor-gated just because their manifest Y center is nonzero")
    }

    func testFloorProximityGate_blocksVerticallyDistantFloorTile() throws {
        let tile = makeTileStub(
            center: .zero,
            streamingRadius: 1000.0,
            unloadRadius: 2000.0,
            hasFloorMetadata: true,
            worldYCenter: 5000.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .unloaded,
                       "Floor-aware tiles outside floorProximityGateY must remain unloaded")
    }

    func testFloorProximityGate_doesNotBlockExteriorShellTile() throws {
        let tile = makeTileStub(
            center: .zero,
            streamingRadius: 1000.0,
            unloadRadius: 2000.0,
            hasFloorMetadata: true,
            worldYCenter: 5000.0,
            isInterior: false
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .parsing,
                       "Exterior shell tiles must not be floor-gated; upper facade floors need to stream from outside")
    }

    // MARK: - Velocity predictor

    // Tile position and radii used for all velocity predictor tests.
    // Camera at origin; tile's closest AABB point is at x=129 m.
    // effectivePrefetchRadius = (100 + 150) / 2 = 125 m.
    // Actual distance 129 > 126 → NOT in range without the predictor.
    private let velocityTileCenter = simd_float3(130, 0, 0)
    private let velocityTileRadius: Float = 100.0
    private let velocityTileUnloadRadius: Float = 150.0

    func testVelocityPredictor_speedBelowThresholdDoesNotActivateLookAhead() throws {
        // Pre-seed a speed just under the activation threshold (1.5 m/s).
        // The smoothed velocity after one update will be 0.85 × 1.4 = 1.19 < 1.5.
        GeometryStreamingSystem.shared.lastCameraPosition = .zero
        GeometryStreamingSystem.shared.cameraVelocity = simd_float3(1.4, 0, 0)

        let tile = makeTileStub(
            center: velocityTileCenter,
            streamingRadius: velocityTileRadius,
            unloadRadius: velocityTileUnloadRadius
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .unloaded,
                       "Tile just outside prefetchRadius must not load when speed is below velocityLookAheadMinSpeed")
    }

    func testVelocityPredictor_speedAboveThresholdBringsJustOutOfRangeTileIntoRange() throws {
        // Pre-seed a high speed along +X (toward the tile).
        // After smoothing: 0.85 × 100 = 85 m/s. Predicted pos = (0+85×0.5, 0, 0) = (42.5, 0, 0).
        // Predicted distance from (42.5, 0, 0) to tile at (130, 0, 0) = 86.5 m ≤ 126 → in range.
        GeometryStreamingSystem.shared.lastCameraPosition = .zero
        GeometryStreamingSystem.shared.cameraVelocity = simd_float3(100, 0, 0)

        let tile = makeTileStub(
            center: velocityTileCenter,
            streamingRadius: velocityTileRadius,
            unloadRadius: velocityTileUnloadRadius
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .parsing,
                       "Tile just outside prefetchRadius must be dispatched when velocity look-ahead brings it into range")
    }

    func testVelocityPredictor_velocityPointingAwayDoesNotHelpDistantTile() throws {
        // Pre-seed a high speed along -X (away from the tile at +X).
        // After smoothing: 0.85 × 100 = 85 m/s along -X.
        // Predicted pos = (0 - 85×0.5, 0, 0) = (-42.5, 0, 0).
        // Predicted distance from (-42.5, 0, 0) to tile at (130, 0, 0) = 172.5 m > 126 → out of range.
        // effectiveDist = min(actual=129, predicted=172.5) = 129 > 126 → NOT dispatched.
        GeometryStreamingSystem.shared.lastCameraPosition = .zero
        GeometryStreamingSystem.shared.cameraVelocity = simd_float3(-100, 0, 0)

        let tile = makeTileStub(
            center: velocityTileCenter,
            streamingRadius: velocityTileRadius,
            unloadRadius: velocityTileUnloadRadius
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tile))
        XCTAssertEqual(tc.state, .unloaded,
                       "Velocity pointing away from a tile must not reduce its effective distance")
    }
}
