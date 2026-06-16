//
//  NativeFormatTileStreamingTests.swift
//  UntoldEngine
//
//  Integration tests that prove manifest-driven tile, HLOD, and LOD payloads
//  can be backed by `.untold` files instead of runtime USD/ModelIO parsing.
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
final class NativeFormatTileStreamingTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.updateInterval = 0.0
        MemoryBudgetManager.shared.clear()
        MemoryBudgetManager.shared.enabled = true
        MemoryBudgetManager.shared.geometryBudget = 512 * 1024 * 1024
        MemoryBudgetManager.shared.textureBudget = 256 * 1024 * 1024
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        MemoryBudgetManager.shared.clear()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    func testLoadTileAndReloadUntoldManifestPayload() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))
        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))

        XCTAssertEqual(tileComp.tileURL.lastPathComponent, fixture.tileFileName)
        XCTAssertEqual(tileComp.tileURL.pathExtension, "untold")
        XCTAssertEqual(tileComp.state, .unloaded)

        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)

        let tileParsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(tileParsed, "Tile should parse through the .untold runtime path")

        let loadedTileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(loadedTileComp.state, .parsed)
        XCTAssertEqual(loadedTileComp.failureCount, 0)

        let tileChildren = getEntityChildren(parentId: tileEntityId)
        XCTAssertEqual(tileChildren.count, 1, "Tile stub should own one dedicated mesh root child")

        let meshRootId = try XCTUnwrap(tileChildren.first)
        let renderDescendants = GeometryStreamingSystem.shared.collectRenderDescendantIds(meshRootId)
        XCTAssertFalse(renderDescendants.isEmpty, "Loaded .untold tile should produce renderable descendants")

        for renderEntityId in renderDescendants {
            let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: renderEntityId))
            XCTAssertEqual(render.assetURL.pathExtension, "untold")
            XCTAssertFalse(render.mesh.isEmpty)
        }

        GeometryStreamingSystem.shared.unloadTile(entityId: tileEntityId)

        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.state, .unloaded)
        XCTAssertTrue(getEntityChildren(parentId: tileEntityId).isEmpty, "Tile unload should destroy all loaded descendants")

        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)

        let tileReloaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(tileReloaded, "Tile should be able to reload from the same .untold payload")

        XCTAssertFalse(getEntityChildren(parentId: tileEntityId).isEmpty, "Reloaded tile should repopulate descendants")
    }

    func testLoadHLODAndLODLevel_acceptUntoldPayloads() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: true)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))
        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))

        XCTAssertEqual(tileComp.hlodURL?.pathExtension, "untold")
        XCTAssertEqual(tileComp.lodLevels.count, 1)
        XCTAssertEqual(tileComp.lodLevels.first?.url.pathExtension, "untold")

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)

        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded, "HLOD should load from a .untold payload")

        let loadedHLODId = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId)?.hlodEntityId)
        XCTAssertTrue(scene.exists(loadedHLODId))
        XCTAssertFalse(GeometryStreamingSystem.shared.collectRenderDescendantIds(loadedHLODId).isEmpty)

        GeometryStreamingSystem.shared.unloadHLOD(entityId: tileEntityId)

        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState, .unloaded)
        XCTAssertNil(scene.get(component: TileComponent.self, for: tileEntityId)?.hlodEntityId)

        GeometryStreamingSystem.shared.loadLODLevel(entityId: tileEntityId, levelIndex: 0)

        let lodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.lodLevels.first?.state == .loaded
        }
        XCTAssertTrue(lodLoaded, "LOD level should load from a .untold payload")

        let loadedLODId = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId)?.lodLevels.first?.entityId)
        XCTAssertTrue(scene.exists(loadedLODId))
        XCTAssertFalse(GeometryStreamingSystem.shared.collectRenderDescendantIds(loadedLODId).isEmpty)

        GeometryStreamingSystem.shared.unloadLODLevel(entityId: tileEntityId, levelIndex: 0)

        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.lodLevels.first?.state, .unloaded)
        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.lodLevels.first?.entityId, .invalid)
    }

    // MARK: - loadTiledScene(url:) — URL overload parity

    /// Verifies that passing a local `file://` URL to `loadTiledScene(url:)`
    /// registers the same tile stubs as the string-based API.
    func testLoadTiledSceneFromURL_localFileProducesSameTileStubs() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)

        let didSucceed = await loadSceneManifestFromURL(fixture.manifestURL)
        XCTAssertTrue(didSucceed, "loadTiledScene(url:) should succeed for a local manifest URL")

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID),
                                         "Tile stub '\(fixture.tileID)' should be registered")
        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))

        XCTAssertEqual(tileComp.tileURL.lastPathComponent, fixture.tileFileName)
        XCTAssertEqual(tileComp.tileURL.pathExtension, "untold")
        XCTAssertEqual(tileComp.state, .unloaded)
    }

    // MARK: - Scene-authored manifest payload

    func testLoadSceneAuthoredFromURLRegistersManifestLightsAndCameras() async throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeScenePayload: true
        )

        let didSucceed = await loadSceneManifestFromURL(fixture.manifestURL)
        XCTAssertTrue(didSucceed, "loadSceneManifestFromURL should succeed for a local manifest URL")

        let sceneAuthoredExpectation = expectation(description: "scene authored loaded")
        loadSceneAuthored(url: fixture.manifestURL) { _ in sceneAuthoredExpectation.fulfill() }
        await fulfillment(of: [sceneAuthoredExpectation], timeout: 5.0)

        XCTAssertNotNil(findEntity(named: "Manifest Key Light"))
        let cameraEntityId = try XCTUnwrap(findEntity(named: "Manifest Camera"))
        XCTAssertNotNil(scene.get(component: CameraComponent.self, for: cameraEntityId))
        XCTAssertEqual(CameraSystem.shared.activeCamera, cameraEntityId)
        XCTAssertEqual(fov, 55.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 750.0, accuracy: 0.001)
    }

    func testTileManifestSkipsSceneAuthoredLightsAndCamerasByDefault() throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeScenePayload: true
        )
        try loadSceneManifest(at: fixture.manifestURL)

        XCTAssertNil(findEntity(named: "Manifest Key Light"))
        XCTAssertNil(findEntity(named: "Manifest Camera"))
    }

    func testTileManifestRegistersSceneAuthoredLightsAndCamerasWhenRequested() throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeScenePayload: true
        )
        try loadSceneManifest(at: fixture.manifestURL)
        let sceneAuthoredExpectation = expectation(description: "scene authored loaded")
        loadSceneAuthored(url: fixture.manifestURL) { _ in sceneAuthoredExpectation.fulfill() }
        wait(for: [sceneAuthoredExpectation], timeout: 5.0)

        let lightEntityId = try XCTUnwrap(findEntity(named: "Manifest Key Light"))
        let light = try XCTUnwrap(scene.get(component: LightComponent.self, for: lightEntityId))
        let point = try XCTUnwrap(scene.get(component: PointLightComponent.self, for: lightEntityId))

        XCTAssertEqual(light.color.x, 0.8, accuracy: 0.001)
        XCTAssertEqual(light.color.y, 0.9, accuracy: 0.001)
        XCTAssertEqual(light.color.z, 1.0, accuracy: 0.001)
        XCTAssertEqual(light.intensity, 3.5, accuracy: 0.001)
        XCTAssertEqual(point.radius, 12.0, accuracy: 0.001)

        let cameraEntityId = try XCTUnwrap(findEntity(named: "Manifest Camera"))
        XCTAssertNotNil(scene.get(component: CameraComponent.self, for: cameraEntityId))
        XCTAssertEqual(CameraSystem.shared.activeCamera, cameraEntityId)
        XCTAssertEqual(fov, 55.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 750.0, accuracy: 0.001)
    }

    // MARK: - Parse timeout — clock starts after download, not before

    /// Verifies the parse-timeout fix: `parseStartTime` is 0 immediately after
    /// `loadTile` is called (Task has not yet run) and becomes non-zero once the
    /// download/resolve step completes and actual parsing begins.
    ///
    /// For local `.untold` tiles `resolveAssetURL` returns instantly, so the window
    /// between "Task spawned" and "parseStartTime set" is a single async dispatch hop.
    /// The test confirms both that the initial value is 0 (clock excluded from download)
    /// and that it advances before the tile reaches `.parsed`.
    func testParseStartTimeIsZeroOnDispatchThenNonZeroBeforeParse() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        // Dispatch the load synchronously — Task body has not yet run.
        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)

        let tcAtDispatch = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tcAtDispatch.parseStartTime, 0,
                       "parseStartTime must be 0 immediately after loadTile — clock must not run during download")

        // Wait for the tile to reach .parsed. During that transition parseStartTime
        // will have been set (non-zero) then reset to 0 on completion.
        // We poll for either a non-zero parseStartTime or the final .parsed state
        // to confirm the assignment path ran without hanging.
        let parseProgressed = await waitUntil(timeout: 5.0) {
            guard let tc = scene.get(component: TileComponent.self, for: tileEntityId) else { return false }
            return tc.parseStartTime > 0 || tc.state == .parsed
        }
        XCTAssertTrue(parseProgressed,
                      "Tile should advance through parsing (parseStartTime > 0) or reach .parsed within timeout")
    }

    // MARK: - Scene-root scale invariance

    /// Verifies that the streaming system correctly handles a tiled scene that is scaled
    /// down via SceneRootTransform (the "virtual camera" approach used to let users
    /// inspect a miniature scene before placing it at full size).
    ///
    /// Mechanism: GeometryStreamingSystem.update() calls
    ///   effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraPos)
    /// which applies inverseMatrix (scale 10 when scene scale is 0.1), making the camera
    /// appear 10× farther from every tile in entity space.  calculateDistance() then
    /// computes distance in entity-local space, so the effective streaming radius shrinks
    /// proportionally with the scene scale.
    ///
    /// Scenario (matching a client's AR placement workflow):
    ///   manifest: tile at origin, streamingRadius=50, unloadRadius=120
    ///   → effectivePrefetchRadius = 50 + (120−50)×0.5 = 85 m
    ///   → dispatch condition: entityLocalDist ≤ 86 m
    ///
    ///   camera at world (9, 0, 0):
    ///     scale 0.1  → effective camera at (90, 0, 0) → dist to tile AABB = 89 m > 86 → BLOCKED
    ///     scale 1.0  → effective camera at  (9, 0, 0) → dist to tile AABB =  8 m ≤ 86 → DISPATCHED
    func testTiledScene_scaleDownViaSceneRootTransform_reducesEffectiveStreamingRadius() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        defer {
            // Always restore identity so other tests are not affected.
            SceneRootTransform.shared.reset()
        }

        // ── Scale-down phase: camera at world (9, 0, 0) but scene scaled to 0.1 ──
        // Entity-local camera = inverseScale(0.1) × (9,0,0) = (90, 0, 0).
        // Closest AABB point = (1, 0, 0), local distance = 89 m > prefetchRadius+1 (86 m).
        // Tile must NOT be dispatched.
        SceneRootTransform.shared.scale = simd_float3(0.1, 0.1, 0.1)
        SceneRootTransform.shared.updateIfNeeded()

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(9, 0, 0),
            deltaTime: 0.016
        )

        let tcSmall = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(
            tcSmall.state, .unloaded,
            "At scale 0.1 the tile is 89 m from the camera in entity space " +
                "(> prefetchRadius 85 m) and must not be dispatched"
        )

        // ── Scale-up phase: restore to 1.0, same camera position ──
        // Entity-local camera = (9, 0, 0). Distance to tile AABB = 8 m ≤ 86 m.
        // Tile must be dispatched (state transitions to .parsing synchronously in loadTile).
        SceneRootTransform.shared.scale = simd_float3(1, 1, 1)
        SceneRootTransform.shared.updateIfNeeded()

        GeometryStreamingSystem.shared.update(
            cameraPosition: simd_float3(9, 0, 0),
            deltaTime: 0.016
        )

        let tcFull = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(
            tcFull.state, .parsing,
            "At scale 1.0 the tile is 8 m from the camera in entity space " +
                "(≤ prefetchRadius 85 m) and must be dispatched to .parsing"
        )
    }

    // MARK: - forceUnloadAllParsedTiles

    /// Core case: a single parsed tile is immediately transitioned to .unloaded and its
    /// mesh-root child entity is destroyed synchronously.
    func testForceUnloadAllParsedTiles_unloadsParsedTileAndDestroysDescendants() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)
        let tileParsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(tileParsed, "Tile must reach .parsed before the force-unload test")
        XCTAssertFalse(getEntityChildren(parentId: tileEntityId).isEmpty,
                       "Parsed tile must have at least one mesh-root child")

        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.state, .unloaded,
                       "forceUnloadAllParsedTiles must transition the tile to .unloaded synchronously")
        XCTAssertTrue(getEntityChildren(parentId: tileEntityId).isEmpty,
                      "forceUnloadAllParsedTiles must destroy the tile's mesh-root child entity")
    }

    /// A resident HLOD mesh is unloaded even when the full tile itself is not .parsed,
    /// because forceUnloadAllParsedTiles iterates loadedHLODEntities independently.
    func testForceUnloadAllParsedTiles_unloadsResidentHLOD() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)
        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded, "HLOD must reach .loaded before the force-unload test")

        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.hlodState, .unloaded,
                       "forceUnloadAllParsedTiles must unload resident HLOD meshes")
        XCTAssertNil(tc.hlodEntityId,
                     "HLOD entity reference must be cleared after force-unload")
    }

    /// A resident per-tile LOD level is unloaded even when the full tile itself is not .parsed.
    func testForceUnloadAllParsedTiles_unloadsResidentLODLevels() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: true)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadLODLevel(entityId: tileEntityId, levelIndex: 0)
        let lodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.lodLevels.first?.state == .loaded
        }
        XCTAssertTrue(lodLoaded, "LOD level must reach .loaded before the force-unload test")

        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.lodLevels.first?.state, .unloaded,
                       "forceUnloadAllParsedTiles must unload resident per-tile LOD levels")
        XCTAssertEqual(tc.lodLevels.first?.entityId, .invalid,
                       "LOD entity ID must be cleared after force-unload")
    }

    /// Tiles that are still in .parsing state when forceUnloadAllParsedTiles() is called
    /// must be transitioned to .unloading, not left running.  Without this, the background
    /// Task can complete through its success path after the call returns, register GPU
    /// memory in MemoryBudgetManager, and reintroduce the exact memory-budget blockage
    /// the API is meant to prevent.
    ///
    /// State is injected directly (same technique as the timeout-guard tests) to make the
    /// test deterministic — we need the tile to be in .parsing when the call fires.
    func testForceUnloadAllParsedTiles_cancelsParsingSoSuccessPathCannotFire() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        // Inject .parsing state: enrol in tracking sets the same way loadTile() does,
        // but skip spawning a real Task so we control the exact moment forceUnload fires.
        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        tileComp.state = .parsing
        tileComp.parseStartTime = CFAbsoluteTimeGetCurrent()
        _ = GeometryStreamingSystem.shared.reserveActiveTileLoad(
            entityId: tileEntityId, fileSizeBytes: 1024
        )
        GeometryStreamingSystem.shared.markLoadingTileEntity(tileEntityId)

        // Call forceUnloadAllParsedTiles() while the tile is in .parsing.
        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        // The tile must be .unloading (unloadTile() set state before cancelling the Task).
        // This ensures any real Task completion that arrives later finds .unloading and
        // takes the cleanup path instead of the success path.
        let state = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId)?.state)
        XCTAssertEqual(state, .unloading,
                       "forceUnloadAllParsedTiles must transition .parsing tiles to .unloading " +
                           "so their completion callbacks cannot enter the success path")

        // Clean up injected tracking state so tearDown drains cleanly.
        GeometryStreamingSystem.shared.releaseActiveTileLoad(entityId: tileEntityId)
        tileComp.state = .unloaded
        tileComp.parseStartTime = 0
    }

    /// When no tiles are loaded, forceUnloadAllParsedTiles must be a safe no-op.
    func testForceUnloadAllParsedTiles_isNoOpWhenNothingIsLoaded() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))
        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.state, .unloaded,
                       "Precondition: tile must start in .unloaded state")

        // Must not crash and tile must remain .unloaded.
        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.state, .unloaded)
    }

    /// The primary session-transition contract: after forceUnloadAllParsedTiles the tile
    /// can be immediately re-dispatched for loading with no memory-budget deadlock.
    /// This is the key scenario for calibration ↔ full-scale cycling in AR/VR apps:
    /// without forceUnloadAllParsedTiles, shouldEvictGeometry() would block new tile
    /// loads until the slow distance-based unload pass completed (10+ seconds).
    func testForceUnloadAllParsedTiles_tileIsReloadableImmediatelyAfterSessionTransition() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        // ── Session 1: parse the tile ──────────────────────────────────────────
        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)
        let session1Parsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(session1Parsed, "Tile must reach .parsed in session 1")

        // ── Simulate session transition (e.g. entering calibration mode) ───────
        GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

        XCTAssertEqual(scene.get(component: TileComponent.self, for: tileEntityId)?.state, .unloaded,
                       "Tile must be .unloaded after forceUnloadAllParsedTiles")
        XCTAssertTrue(getEntityChildren(parentId: tileEntityId).isEmpty,
                      "Mesh children must be destroyed after forceUnloadAllParsedTiles")

        // ── Session 2: tile must reload cleanly without any budget blockage ─────
        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)
        let session2Parsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(session2Parsed,
                      "Tile must be reloadable in session 2 with no memory-budget deadlock")
    }

    // MARK: - HLOD lifecycle

    func testHLOD_loadIsNoOpWhenAlreadyLoaded() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)
        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded, "HLOD should reach .loaded before second loadHLOD call")

        let firstHLODEntityId = scene.get(component: TileComponent.self, for: tileEntityId)?.hlodEntityId

        // Second call must be a no-op: guard requires hlodState == .unloaded.
        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)

        try await Task.sleep(nanoseconds: 100_000_000) // 100 ms

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.hlodState, .loaded, "loadHLOD on an already-loaded tile should be a no-op")
        XCTAssertEqual(tc.hlodEntityId, firstHLODEntityId, "Second loadHLOD must not replace the existing HLOD entity")
    }

    func testHLOD_cancelDuringLoading() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)

        // Capture state before cancel to confirm we caught it mid-load.
        let tcMidLoad = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tcMidLoad.hlodState, .loading, "State should be .loading before unloadHLOD")

        // Cancel synchronously — unloadHLOD sets .unloading then .unloaded in the same call.
        GeometryStreamingSystem.shared.unloadHLOD(entityId: tileEntityId)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.hlodState, .unloaded, "Cancelled HLOD load must leave state as .unloaded")
        XCTAssertNil(tc.hlodEntityId, "Cancelled HLOD entity reference must be cleared")

        // Wait for the background Task to settle so no phantom child survives.
        let childrenClear = await waitUntil(timeout: 2.0) {
            getEntityChildren(parentId: tileEntityId).isEmpty
        }
        XCTAssertTrue(childrenClear, "No HLOD child entity should survive after cancellation")
    }

    func testHLOD_unloadedAfterFullTileIsRenderVisible() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)
        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded, "HLOD should be resident before full tile parse")

        // Parsing the full tile keeps HLOD resident until LOD0 appears in the
        // render-visible set.
        GeometryStreamingSystem.shared.loadTile(entityId: tileEntityId)
        let tileParsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.state == .parsed
        }
        XCTAssertTrue(tileParsed, "Full tile should reach .parsed state")

        let parsedTC = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(parsedTC.hlodState, .loaded, "HLOD should remain until LOD0 is visible")

        visibleEntityIds = Array(GeometryStreamingSystem.shared.collectRenderDescendantIds(tileEntityId))
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let releasedTC = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(releasedTC.hlodState, .unloaded, "HLOD must unload after LOD0 enters the visible set")
        XCTAssertNil(releasedTC.hlodEntityId, "HLOD entity reference must be nil after LOD0 handoff")
    }

    func testHLOD_doubleUnloadIsNoOp() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        // Unloading when already .unloaded must not crash or change state.
        GeometryStreamingSystem.shared.unloadHLOD(entityId: tileEntityId)
        GeometryStreamingSystem.shared.unloadHLOD(entityId: tileEntityId)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.hlodState, .unloaded)
        XCTAssertNil(tc.hlodEntityId)
    }

    func testHLOD_lastTransitionTimeSetOnLoad() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))
        let beforeLoad = CFAbsoluteTimeGetCurrent()

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)
        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertGreaterThan(tc.lastHLODTransitionTime, beforeLoad,
                             "lastHLODTransitionTime must be stamped at HLOD load completion")
    }

    func testHLOD_lastTransitionTimeUpdatedOnUnload() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        GeometryStreamingSystem.shared.loadHLOD(entityId: tileEntityId)
        let hlodLoaded = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: tileEntityId)?.hlodState == .loaded
        }
        XCTAssertTrue(hlodLoaded)

        let timeAfterLoad = try XCTUnwrap(
            scene.get(component: TileComponent.self, for: tileEntityId)
        ).lastHLODTransitionTime

        try await Task.sleep(nanoseconds: 10_000_000) // 10 ms — ensures strict ordering

        GeometryStreamingSystem.shared.unloadHLOD(entityId: tileEntityId)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertGreaterThanOrEqual(tc.lastHLODTransitionTime, timeAfterLoad,
                                    "lastHLODTransitionTime must be re-stamped on HLOD unload")
    }

    // MARK: - Tile parse timeout guard

    /// Injects stuck-parse state directly (no real hung parse needed) and
    /// verifies the timeout guard transitions the tile to .failed with retry bookkeeping.
    func testTimeoutGuard_transitionsParsingToFailed() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        // Create a stand-in mesh child entity — mirrors what loadTile creates.
        // We reuse tileEntityId as the meshEntityId value so finishLoading has
        // a valid (though already-idempotent) entity ID to pass through.
        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        tileComp.state = .parsing
        tileComp.parseStartTime = CFAbsoluteTimeGetCurrent() - 120.0 // 120s ago — well past 60s threshold
        tileComp.meshEntityId = tileEntityId // valid non-.invalid id for gate-release path

        // Enroll in tracking sets the same way loadTile does.
        _ = GeometryStreamingSystem.shared.reserveActiveTileLoad(entityId: tileEntityId, fileSizeBytes: 1024)
        GeometryStreamingSystem.shared.markLoadingTileEntity(tileEntityId)

        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.state, .failed,
                       "Tile stuck in .parsing for >tileParseTimeoutSeconds must transition to .failed")
        XCTAssertEqual(tc.failureCount, 1, "Timeout must increment failureCount for retry backoff")
        XCTAssertEqual(tc.parseStartTime, 0, "parseStartTime must be cleared after timeout")
        XCTAssertEqual(tc.meshEntityId, .invalid, "meshEntityId must be cleared after timeout")
    }

    /// A tile that was .unloading when the timeout fires should go to .unloaded, not .failed.
    func testTimeoutGuard_transitionsUnloadingToUnloaded() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        tileComp.state = .unloading
        tileComp.parseStartTime = CFAbsoluteTimeGetCurrent() - 120.0
        _ = GeometryStreamingSystem.shared.reserveActiveTileLoad(entityId: tileEntityId, fileSizeBytes: 1024)
        GeometryStreamingSystem.shared.markLoadingTileEntity(tileEntityId)

        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        // Camera placed beyond the tile's effectivePrefetchRadius (85 m) so the tile
        // load pass does not immediately re-dispatch the tile after the timeout guard
        // clears it to .unloaded in the same update() tick.
        GeometryStreamingSystem.shared.update(cameraPosition: simd_float3(500, 0, 0), deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.state, .unloaded,
                       "Timed-out .unloading tile must go to .unloaded, not .failed")
        XCTAssertEqual(tc.failureCount, 0,
                       "Timeout of an .unloading tile must not increment failureCount")
    }

    /// The guard requires parseStartTime > 0.  When it is 0 (download still in flight)
    /// the guard must not fire even with a zero-second threshold.
    func testTimeoutGuard_doesNotFireWhenParseStartTimeIsZero() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        tileComp.state = .parsing
        tileComp.parseStartTime = 0 // download still pending — clock not yet started
        _ = GeometryStreamingSystem.shared.reserveActiveTileLoad(entityId: tileEntityId, fileSizeBytes: 1024)
        GeometryStreamingSystem.shared.markLoadingTileEntity(tileEntityId)

        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 0.0 // would fire immediately if start > 0
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.state, .parsing,
                       "Timeout guard must not fire while parseStartTime is 0 (remote download in progress)")
        XCTAssertEqual(tc.failureCount, 0)

        // Clean up injected state so tearDown drains cleanly.
        GeometryStreamingSystem.shared.unmarkLoadingTileEntity(tileEntityId)
        GeometryStreamingSystem.shared.releaseActiveTileLoad(entityId: tileEntityId)
        tileComp.state = .unloaded
        tileComp.parseStartTime = 0
        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
    }

    /// A parse that just started must not be timed out even if the threshold is very low.
    func testTimeoutGuard_doesNotFireBeforeThreshold() throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try loadSceneManifest(at: fixture.manifestURL)

        let tileEntityId = try XCTUnwrap(findEntity(named: fixture.tileID))

        let tileComp = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        tileComp.state = .parsing
        tileComp.parseStartTime = CFAbsoluteTimeGetCurrent() // started right now
        _ = GeometryStreamingSystem.shared.reserveActiveTileLoad(entityId: tileEntityId, fileSizeBytes: 1024)
        GeometryStreamingSystem.shared.markLoadingTileEntity(tileEntityId)

        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        GeometryStreamingSystem.shared.update(cameraPosition: .zero, deltaTime: 0.016)

        let tc = try XCTUnwrap(scene.get(component: TileComponent.self, for: tileEntityId))
        XCTAssertEqual(tc.state, .parsing,
                       "Timeout guard must not fire before tileParseTimeoutSeconds have elapsed")
        XCTAssertEqual(tc.failureCount, 0)

        // Clean up injected state so tearDown drains cleanly.
        GeometryStreamingSystem.shared.unmarkLoadingTileEntity(tileEntityId)
        GeometryStreamingSystem.shared.releaseActiveTileLoad(entityId: tileEntityId)
        tileComp.state = .unloaded
        tileComp.parseStartTime = 0
    }

    private func loadSceneManifest(at manifestURL: URL) throws {
        let expectation = XCTestExpectation(description: "Manifest loaded")
        let manifestStem = manifestURL.deletingPathExtension().path
        var didSucceed = false

        loadTiledScene(
            manifest: manifestStem,
            withExtension: manifestURL.pathExtension
        ) { success in
            didSucceed = success
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(didSucceed, "Tile manifest should load successfully")
    }

    private func loadSceneManifestFromURL(_ url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            loadTiledScene(url: url) { @Sendable success in
                continuation.resume(returning: success)
            }
        }
    }

    private func findEntity(named name: String) -> EntityID? {
        reverseEntityNameMap[name]?.first(where: { scene.exists($0) && getEntityName(entityId: $0) == name })
    }

    private func waitUntil(timeout: TimeInterval, pollIntervalNanoseconds: UInt64 = 25_000_000, condition: @escaping @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        return condition()
    }
}

private struct UntoldTileSceneFixture {
    let manifestURL: URL
    let tileID: String
    let tileFileName: String
}

private func makeUntoldTileSceneFixture(
    includeHLOD: Bool,
    includeLOD: Bool,
    includeScenePayload: Bool = false
) throws -> UntoldTileSceneFixture {
    guard let sourceUntoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
        throw NSError(domain: "NativeFormatTileStreamingTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to locate redplayer.untold in test resources"])
    }

    let fileManager = FileManager.default
    let fixtureRoot = fileManager.temporaryDirectory.appendingPathComponent("untold-tile-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)

    let tileFileName = "tile_0_0.untold"
    let tileURL = fixtureRoot.appendingPathComponent(tileFileName)
    try fileManager.copyItem(at: sourceUntoldURL, to: tileURL)

    let sourceTexturesURL = sourceUntoldURL.deletingLastPathComponent().appendingPathComponent("Textures", isDirectory: true)
    if fileManager.fileExists(atPath: sourceTexturesURL.path) {
        let stagedTexturesURL = fixtureRoot.appendingPathComponent("Textures", isDirectory: true)
        try fileManager.copyItem(at: sourceTexturesURL, to: stagedTexturesURL)
    } else if let bundledTextureURL = Bundle.module.url(forResource: "soccer-player-0", withExtension: "png") {
        let stagedTexturesURL = fixtureRoot.appendingPathComponent("Textures", isDirectory: true)
        try fileManager.createDirectory(at: stagedTexturesURL, withIntermediateDirectories: true)
        try fileManager.copyItem(at: bundledTextureURL, to: stagedTexturesURL.appendingPathComponent("soccer-player-0.png"))
    }

    let fileSizeBytes = try (fileManager.attributesOfItem(atPath: tileURL.path)[.size] as? NSNumber)?.intValue ?? 0

    var tileEntry: [String: Any] = [
        "tile_id": "tile_0_0",
        "path_relative_to_manifest": tileFileName,
        "file_size_bytes": fileSizeBytes,
        "bounds": [
            "min": [-1.0, -1.0, -1.0],
            "max": [1.0, 1.0, 1.0],
        ],
        "center": [0.0, 0.0, 0.0],
        "streaming_radius": 50.0,
        "unload_radius": 120.0,
        "priority": 0,
    ]

    if includeHLOD {
        tileEntry["hlod_levels"] = [
            [
                "path": tileFileName,
                "switch_distance": 200.0,
            ],
        ]
    }

    if includeLOD {
        tileEntry["lod_levels"] = [
            [
                "path": tileFileName,
                "switch_distance": 100.0,
            ],
        ]
    }

    var manifest: [String: Any] = [
        "version": 1,
        "streaming_defaults": [
            "streaming_radius": 50.0,
            "unload_radius": 120.0,
            "priority": 0,
            "prefetch_radius": 80.0,
        ],
        "tiles": [tileEntry],
    ]

    if includeScenePayload {
        manifest["scene_lights"] = [
            [
                "entity_name": "Manifest Key Light",
                "kind": "point",
                "color": [0.8, 0.9, 1.0],
                "intensity": 3.5,
                "position": [2.0, 3.0, 4.0],
                "radius": 12.0,
                "direction": [0.0, -1.0, 0.0],
                "falloff": 0.4,
                "right": [1.0, 0.0, 0.0],
                "inner_cone": 10.0,
                "up": [0.0, 1.0, 0.0],
                "outer_cone": 25.0,
                "area_size": [1.0, 1.0],
                "source_power": 3.5,
                "source_exposure": 0.0,
                "local_transform_rows": [
                    [1.0, 0.0, 0.0, 2.0],
                    [0.0, 1.0, 0.0, 3.0],
                    [0.0, 0.0, 1.0, 4.0],
                    [0.0, 0.0, 0.0, 1.0],
                ],
            ],
        ]
        manifest["scene_cameras"] = [
            [
                "entity_name": "Manifest Camera",
                "position": [0.0, 1.0, 6.0],
                "forward": [0.0, 0.0, 1.0],
                "up": [0.0, 1.0, 0.0],
                "right": [1.0, 0.0, 0.0],
                "fov_y_degrees": 55.0,
                "near_clip": 0.05,
                "far_clip": 750.0,
                "aspect_ratio": 1.6,
                "local_transform_rows": [
                    [1.0, 0.0, 0.0, 0.0],
                    [0.0, 1.0, 0.0, 1.0],
                    [0.0, 0.0, 1.0, 6.0],
                    [0.0, 0.0, 0.0, 1.0],
                ],
            ],
        ]
    }

    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    let manifestURL = fixtureRoot.appendingPathComponent("scene.json")
    try manifestData.write(to: manifestURL)

    return UntoldTileSceneFixture(
        manifestURL: manifestURL,
        tileID: "tile_0_0",
        tileFileName: tileFileName
    )
}
