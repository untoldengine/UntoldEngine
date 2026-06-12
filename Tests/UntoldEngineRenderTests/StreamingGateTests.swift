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
        destroyAllEntities()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.updateInterval = 0.0
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 2
        GeometryStreamingSystem.shared.maxConcurrentLODLoads = 4
        GeometryStreamingSystem.shared.maxConcurrentHLODLoads = 4
        GeometryStreamingSystem.shared.tileParseMemoryBudgetMB = 200.0
        GeometryStreamingSystem.shared.velocitySmoothing = 0.85
        GeometryStreamingSystem.shared.velocityLookAheadTime = 0.5
        GeometryStreamingSystem.shared.velocityLookAheadMinSpeed = 1.5
        GeometryStreamingSystem.shared.floorProximityGateY = 5.0
        GeometryStreamingSystem.shared.enableImportanceSort = true
        GeometryStreamingSystem.shared.enableFrustumGate = false // disabled by default; re-enabled per test
        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        LODConfig.shared = LODConfig()
        OctreeSystem.shared.clear()
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.highWaterMark = 0.85
        MemoryBudgetManager.shared.lowWaterMark = 0.70
        MemoryBudgetManager.shared.geometryBudget = 512 * 1024 * 1024
        MemoryBudgetManager.shared.textureBudget = 256 * 1024 * 1024
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 2
        GeometryStreamingSystem.shared.maxConcurrentLODLoads = 4
        GeometryStreamingSystem.shared.maxConcurrentHLODLoads = 4
        GeometryStreamingSystem.shared.tileParseMemoryBudgetMB = 200.0
        GeometryStreamingSystem.shared.velocitySmoothing = 0.85
        GeometryStreamingSystem.shared.velocityLookAheadTime = 0.5
        GeometryStreamingSystem.shared.velocityLookAheadMinSpeed = 1.5
        GeometryStreamingSystem.shared.floorProximityGateY = 5.0
        GeometryStreamingSystem.shared.enableImportanceSort = true
        GeometryStreamingSystem.shared.enableFrustumGate = true // restore default
        GeometryStreamingSystem.shared.interiorZone = nil
        LODConfig.shared = LODConfig()
        CameraSystem.shared.activeCamera = nil
        OctreeSystem.shared.clear()
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.highWaterMark = 0.85
        MemoryBudgetManager.shared.lowWaterMark = 0.70
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

    // MARK: - Importance sort

    // These tests verify that tileImportanceComponents drives the tile load order.
    // maxConcurrentTileLoads is forced to 1 so only the top-ranked candidate is
    // dispatched per tick — the second tile remaining .unloaded is the observable
    // signal that ordering worked correctly.
    //
    // Geometry notes (camera at origin, cameraForward = (0, 0, -1)):
    //   Surface distance = simd_distance(camera, closestAABBPoint)
    //   Solid angle      = projectedSilhouetteArea / distance²
    //   ViewAlignment    = viewAlignmentMinWeight + (1 − minWeight) × dot(forward, dirToTile)

    func testImportanceSort_largeAabbLoadsBeforeSmallAtEqualDistance() throws {
        setUpCameraLookingNegativeZ()
        let oldMax = GeometryStreamingSystem.shared.maxConcurrentTileLoads
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1
        defer { GeometryStreamingSystem.shared.maxConcurrentTileLoads = oldMax }

        // Both tiles have AABB surface-distance 50 m so raw distance cannot break the
        // tie.  The large tile (hx=hy=hz=5) subtends a 25× greater solid angle
        // (projectedArea = 50 vs 2) and must be dispatched first.
        let largeTile = makeTileStub(
            center: simd_float3(0, 0, -55),
            halfExtent: simd_float3(5, 5, 5), // AABB max-z = -50 → surface dist = 50 m
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )
        let smallTile = makeTileStub(
            center: simd_float3(0, 0, -51),
            halfExtent: simd_float3(1, 1, 1), // AABB max-z = -50 → surface dist = 50 m
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcLarge = try XCTUnwrap(scene.get(component: TileComponent.self, for: largeTile))
        let tcSmall = try XCTUnwrap(scene.get(component: TileComponent.self, for: smallTile))
        XCTAssertEqual(tcLarge.state, .parsing,
                       "Large tile (solid angle 25× greater) must be dispatched first at equal surface distance")
        XCTAssertEqual(tcSmall.state, .unloaded,
                       "Small tile must wait when the single load slot is held by the larger-solid-angle tile")
    }

    func testImportanceSort_onAxisTileLoadsBeforePeripheralAtEqualAabbAndDistance() throws {
        setUpCameraLookingNegativeZ()
        // Frustum gate is already disabled in setUp; the 90°-off-axis tile must reach
        // the importance sort, not be filtered before it.
        let oldMax = GeometryStreamingSystem.shared.maxConcurrentTileLoads
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1
        defer { GeometryStreamingSystem.shared.maxConcurrentTileLoads = oldMax }

        // Both cubes: halfExtent (1,1,1), surface distance 50 m.
        // Equal solid angles — view alignment is the only differentiator.
        // On-axis: dot((0,0,-1),(0,0,-1)) = 1.0  → viewAlignment = 1.0
        // Off-axis: dot((0,0,-1),(1,0,0)) = 0.0  → viewAlignment = 0.2 (minWeight)
        let onAxisTile = makeTileStub(
            center: simd_float3(0, 0, -51), // directly ahead; surface at z = -50
            halfExtent: simd_float3(1, 1, 1),
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )
        let offAxisTile = makeTileStub(
            center: simd_float3(51, 0, 0), // 90° off-axis; surface at x = 50
            halfExtent: simd_float3(1, 1, 1),
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcOn = try XCTUnwrap(scene.get(component: TileComponent.self, for: onAxisTile))
        let tcOff = try XCTUnwrap(scene.get(component: TileComponent.self, for: offAxisTile))
        XCTAssertEqual(tcOn.state, .parsing,
                       "On-axis tile (viewAlignment 1.0) must load before peripheral tile (viewAlignment 0.2)")
        XCTAssertEqual(tcOff.state, .unloaded,
                       "Peripheral tile must wait when the load slot is held by the on-axis tile")
    }

    func testImportanceSort_disabledRevertsToPureDistanceOrdering() throws {
        setUpCameraLookingNegativeZ()
        let oldMax = GeometryStreamingSystem.shared.maxConcurrentTileLoads
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1
        GeometryStreamingSystem.shared.enableImportanceSort = false
        defer {
            GeometryStreamingSystem.shared.maxConcurrentTileLoads = oldMax
            GeometryStreamingSystem.shared.enableImportanceSort = true
        }

        // Close small tile at 30 m; far large tile at 60 m.
        // With importance sort OFF the streaming system falls back to raw distance:
        // the close tile wins despite having a ~400× smaller solid angle.
        let closeSmallTile = makeTileStub(
            center: simd_float3(0, 0, -31),
            halfExtent: simd_float3(1, 1, 1), // surface at z = -30 → distance 30 m
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )
        let farLargeTile = makeTileStub(
            center: simd_float3(0, 0, -100),
            halfExtent: simd_float3(40, 40, 40), // surface at z = -60 → distance 60 m
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcClose = try XCTUnwrap(scene.get(component: TileComponent.self, for: closeSmallTile))
        let tcFar = try XCTUnwrap(scene.get(component: TileComponent.self, for: farLargeTile))
        XCTAssertEqual(tcClose.state, .parsing,
                       "Closer tile must load first when importance sort is disabled")
        XCTAssertEqual(tcFar.state, .unloaded,
                       "Far tile must wait when sort is disabled, regardless of its solid angle advantage")
    }

    func testImportanceSort_enabledPrefersHighSolidAngleOverRawDistance() throws {
        setUpCameraLookingNegativeZ()
        let oldMax = GeometryStreamingSystem.shared.maxConcurrentTileLoads
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1
        defer { GeometryStreamingSystem.shared.maxConcurrentTileLoads = oldMax }

        // Same geometry as the disabled test; importance sort is on (default).
        // The far large tile's solid angle (≈0.89) dominates the close small tile's
        // (≈0.002) by ~400×.  It must load first despite being 2× farther away.
        let closeSmallTile = makeTileStub(
            center: simd_float3(0, 0, -31),
            halfExtent: simd_float3(1, 1, 1), // distance 30 m, solidAngle ≈ 0.002
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )
        let farLargeTile = makeTileStub(
            center: simd_float3(0, 0, -100),
            halfExtent: simd_float3(40, 40, 40), // distance 60 m, solidAngle ≈ 0.89
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )

        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcClose = try XCTUnwrap(scene.get(component: TileComponent.self, for: closeSmallTile))
        let tcFar = try XCTUnwrap(scene.get(component: TileComponent.self, for: farLargeTile))
        XCTAssertEqual(tcFar.state, .parsing,
                       "Far large tile (solid angle ≈ 0.89) must load first — importance beats raw distance")
        XCTAssertEqual(tcClose.state, .unloaded,
                       "Close small tile (solid angle ≈ 0.002) must wait when outranked by solid angle")
    }

    // MARK: - Occlusion sort camera guard

    func testOcclusionSort_disabledWhenNoCameraAvailable() throws {
        // No active camera — viewProjMatrixValid must be false this tick, so the
        // occluder build is skipped and both tiles get occlusionScore = 1.0.
        // Phase 1 importance sort still applies: the larger tile loads first.
        CameraSystem.shared.activeCamera = nil
        let oldMax = GeometryStreamingSystem.shared.maxConcurrentTileLoads
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 1
        defer { GeometryStreamingSystem.shared.maxConcurrentTileLoads = oldMax }

        // Large tile and small tile at equal distance — large wins on solid angle alone.
        let largeTile = makeTileStub(
            center: simd_float3(0, 0, -55),
            halfExtent: simd_float3(5, 5, 5),
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )
        let smallTile = makeTileStub(
            center: simd_float3(0, 0, -51),
            halfExtent: simd_float3(1, 1, 1),
            streamingRadius: 200.0,
            unloadRadius: 400.0
        )

        // Should not crash or stall — occlusion is simply skipped this tick.
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tcLarge = try XCTUnwrap(scene.get(component: TileComponent.self, for: largeTile))
        let tcSmall = try XCTUnwrap(scene.get(component: TileComponent.self, for: smallTile))
        XCTAssertEqual(tcLarge.state, .parsing,
                       "Large tile must still load first via solid-angle sort even when occlusion is skipped (no camera)")
        XCTAssertEqual(tcSmall.state, .unloaded,
                       "Small tile must wait — importance sort still applies without occlusion")
    }

    // MARK: - View alignment closest-point fix

    func testViewAlignment_closestAABBPointUsedForLargeTile() {
        // A large wall tile whose AABB center is far off to the right, but whose
        // AABB surface is directly in front of the camera.
        //
        // center = (150, 0, -10), halfExtent = (200, 10, 5)
        // AABB: x ∈ [-50, 350],  y ∈ [-10, 10],  z ∈ [-15, -5]
        // Camera at origin, forward = (0, 0, -1).
        //
        // Center direction ≈ normalize(150, 0, -10) → dot ≈ 0.07  (nearly perpendicular)
        // Closest AABB point = clamp((0,0,0), min, max) = (0, 0, -5)
        // Closest direction  = (0, 0, -1)              → dot = 1.0  (directly ahead)
        //
        // With center-based alignment the tile would score ≈ viewAlignmentMinWeight + tiny.
        // With closest-point alignment it must score close to 1.0.
        GeometryStreamingSystem.shared.lastCameraForward = simd_float3(0, 0, -1)

        let tile = makeTileStub(
            center: simd_float3(150, 0, -10),
            halfExtent: simd_float3(200, 10, 5),
            streamingRadius: 1000.0,
            unloadRadius: 2000.0
        )

        let sys = GeometryStreamingSystem.shared
        let (_, va) = sys.tileImportanceComponents(
            entityId: tile,
            distance: 5.0, // distance from camera to closest AABB point (z = -5)
            cameraPosition: .zero,
            cameraForward: simd_float3(0, 0, -1)
        )

        XCTAssertGreaterThan(va, 0.9,
                             "Large wall tile with AABB surface directly ahead must score high view alignment even when its center is far off-axis")
    }

    func testViewAlignment_centerBasedWouldUnderrankThisTile() {
        // Complementary to the above: verify that the center direction alone would
        // produce a near-minimum alignment score for the same tile, confirming that
        // the fix is actually doing something.
        // center direction ≈ (0.998, 0, -0.067) → dot with (0,0,-1) ≈ 0.067
        // → center-based alignment ≈ 0.2 + 0.8 × 0.067 ≈ 0.253
        let center = simd_float3(150, 0, -10)
        let cameraForward = simd_float3(0, 0, -1)
        let dirToCenter = simd_normalize(center - .zero)
        let centerDot = max(0, simd_dot(cameraForward, dirToCenter))
        let minW = GeometryStreamingSystem.shared.viewAlignmentMinWeight
        let centerBasedAlignment = minW + (1.0 - minW) * centerDot

        XCTAssertLessThan(centerBasedAlignment, 0.35,
                          "Center-based alignment for a far-off-axis center must be low, confirming the fix improves the score")
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
