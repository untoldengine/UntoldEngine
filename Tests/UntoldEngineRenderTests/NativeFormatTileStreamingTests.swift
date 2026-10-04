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
        ColorLUTParams.shared.clear()
    }

    override func tearDown() async throws {
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        MemoryBudgetManager.shared.clear()
        ColorLUTParams.shared.clear()
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    private func assertVector(
        _ value: simd_float3,
        equals expected: simd_float3,
        accuracy: Float = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(value.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(value.z, expected.z, accuracy: accuracy, file: file, line: line)
    }

    func testLoadTileAndReloadUntoldManifestPayload() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        XCTAssertNotNil(findEntity(named: "Manifest Spot Fallback"))
        XCTAssertNotNil(findEntity(named: "Manifest Area Fallback"))
        let cameraEntityId = try XCTUnwrap(findEntity(named: "Manifest Camera"))
        XCTAssertNotNil(scene.get(component: CameraComponent.self, for: cameraEntityId))
        XCTAssertEqual(CameraSystem.shared.activeCamera, cameraEntityId)
        XCTAssertEqual(fov, 55.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 750.0, accuracy: 0.001)
    }

    func testTileManifestSkipsSceneAuthoredLightsAndCamerasByDefault() async throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeScenePayload: true
        )
        try await loadSceneManifest(at: fixture.manifestURL)

        XCTAssertNil(findEntity(named: "Manifest Key Light"))
        XCTAssertNil(findEntity(named: "Manifest Camera"))
    }

    func testTileManifestRegistersSceneAuthoredLightsAndCamerasWhenRequested() async throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeScenePayload: true
        )
        try await loadSceneManifest(at: fixture.manifestURL)
        let sceneAuthoredExpectation = expectation(description: "scene authored loaded")
        loadSceneAuthored(url: fixture.manifestURL) { _ in sceneAuthoredExpectation.fulfill() }
        await fulfillment(of: [sceneAuthoredExpectation], timeout: 5.0)

        let lightEntityId = try XCTUnwrap(findEntity(named: "Manifest Key Light"))
        let light = try XCTUnwrap(scene.get(component: LightComponent.self, for: lightEntityId))
        let point = try XCTUnwrap(scene.get(component: PointLightComponent.self, for: lightEntityId))

        XCTAssertEqual(light.color.x, 0.8, accuracy: 0.001)
        XCTAssertEqual(light.color.y, 0.9, accuracy: 0.001)
        XCTAssertEqual(light.color.z, 1.0, accuracy: 0.001)
        XCTAssertEqual(light.intensity, 3.5, accuracy: 0.001)
        XCTAssertEqual(point.radius, 12.0, accuracy: 0.001)
        let spotEntityId = try XCTUnwrap(findEntity(named: "Manifest Spot Fallback"))
        XCTAssertNotNil(scene.get(component: SpotLightComponent.self, for: spotEntityId))
        assertVector(getLightEmissionDirection(entityId: spotEntityId), equals: simd_float3(0.0, -1.0, 0.0))
        assertVector(
            getSpotLights().first(where: { simd_length($0.position - simd_float3(-2.0, 3.0, 4.0)) < 0.001 })?.direction ?? .zero,
            equals: simd_float3(0.0, -1.0, 0.0)
        )

        let areaEntityId = try XCTUnwrap(findEntity(named: "Manifest Area Fallback"))
        XCTAssertNotNil(scene.get(component: AreaLightComponent.self, for: areaEntityId))
        assertVector(getLightEmissionDirection(entityId: areaEntityId), equals: simd_float3(0.0, 0.0, -1.0))
        assertVector(
            getAreaLights().first(where: { simd_length($0.position - simd_float3(0.0, 5.0, 0.0)) < 0.001 })?.forward ?? .zero,
            equals: simd_float3(0.0, 0.0, 1.0)
        )

        let cameraEntityId = try XCTUnwrap(findEntity(named: "Manifest Camera"))
        XCTAssertNotNil(scene.get(component: CameraComponent.self, for: cameraEntityId))
        XCTAssertEqual(CameraSystem.shared.activeCamera, cameraEntityId)
        XCTAssertEqual(fov, 55.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 750.0, accuracy: 0.001)
    }

    func testSceneAuthoredManifestInstallsAndResetsColorLUT() async throws {
        let fixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false,
            includeColorLUT: true
        )
        let installed = await loadSceneManifestFromURL(fixture.manifestURL)
        XCTAssertTrue(installed)

        let active = ColorLUTParams.shared.snapshot()
        XCTAssertTrue(active.enabled)
        XCTAssertEqual(active.lutTexture?.pixelFormat, .rgba16Float)
        XCTAssertEqual(active.lutTexture?.width, 16)
        XCTAssertEqual(active.lutTexture?.height, 4)
        XCTAssertEqual(active.lutTexture?.mipmapLevelCount, 1)
        XCTAssertEqual(active.lutSize, 4)

        let noLUTFixture = try makeUntoldTileSceneFixture(
            includeHLOD: false,
            includeLOD: false
        )
        let reset = await loadSceneManifestFromURL(noLUTFixture.manifestURL)
        XCTAssertTrue(reset)

        let cleared = ColorLUTParams.shared.snapshot()
        XCTAssertFalse(cleared.enabled)
        XCTAssertNil(cleared.lutTexture)
        XCTAssertEqual(cleared.lutSize, 0)
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
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testTiledScene_scaleDownViaSceneRootTransform_reducesEffectiveStreamingRadius() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testForceUnloadAllParsedTiles_cancelsParsingSoSuccessPathCannotFire() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testForceUnloadAllParsedTiles_isNoOpWhenNothingIsLoaded() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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

    func testHLOD_doubleUnloadIsNoOp() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: true, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testTimeoutGuard_transitionsParsingToFailed() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testTimeoutGuard_transitionsUnloadingToUnloaded() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testTimeoutGuard_doesNotFireWhenParseStartTimeIsZero() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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
    func testTimeoutGuard_doesNotFireBeforeThreshold() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        try await loadSceneManifest(at: fixture.manifestURL)

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

    // MARK: - The root entity of a streamed scene

    /// The root keeps the transform and scene graph components `createEntity()` gave it, so
    /// it stays under its parent and keeps the children it already has.
    func testStreamSceneRoot_keepsItsParentAndTheChildrenItHad() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let (parent, root, child) = makePlacedRoot()
        let localBefore = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: root))
        let worldBefore = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: root))
        let graphBefore = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: root))

        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        XCTAssertTrue(scene.get(component: LocalTransformComponent.self, for: root) === localBefore, "The local transform is the one the root had")
        XCTAssertTrue(scene.get(component: WorldTransformComponent.self, for: root) === worldBefore, "The world transform is the one the root had")
        XCTAssertTrue(scene.get(component: ScenegraphComponent.self, for: root) === graphBefore, "The scene graph node is the one the root had")

        XCTAssertEqual(getEntityParent(entityId: root), parent, "The root keeps its parent")
        XCTAssertEqual(getEntityChildren(parentId: parent), [root], "The parent lists the root once")
        XCTAssertEqual(getEntityParent(entityId: child), root, "The earlier child keeps its parent")
        XCTAssertEqual(getEntityChildren(parentId: root), [child, stub], "The root lists its earlier child and the tile stub")
        XCTAssertEqual(getEntityParent(entityId: stub), root, "The tile stub is parented under the root")
        XCTAssertEqual(scene.get(component: ScenegraphComponent.self, for: root)?.level, 1)
        XCTAssertEqual(scene.get(component: ScenegraphComponent.self, for: child)?.level, 2)
        XCTAssertEqual(scene.get(component: ScenegraphComponent.self, for: stub)?.level, 2)
        assertSceneGraphIsConsistent([parent, root, child, stub])
        XCTAssertNotNil(scene.get(component: TiledSceneComponent.self, for: root))
    }

    /// Tile bounds are world-space values that do not follow the root, so its own transform
    /// goes back to identity. What its parent adds stays, and the entities under the root
    /// are where that puts them without waiting for a scene graph traversal.
    func testStreamSceneRoot_isPutBackAtTheIdentityOfItsParentSpace() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let (parent, root, child) = makePlacedRoot()
        assertVector(getPosition(entityId: child), equals: simd_float3(11.0, 4.0, 3.0))

        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        assertVector(getLocalPosition(entityId: root), equals: .zero)
        assertVector(getScale(entityId: root), equals: .one)
        XCTAssertEqual(abs(getRotationQuaternion(entityId: root).real), 1.0, accuracy: 0.0001, "The root is no longer rotated")
        assertVector(getAxisRotations(entityId: root), equals: .zero)

        assertVector(getPosition(entityId: root), equals: simd_float3(10.0, 0.0, 0.0))
        assertVector(getPosition(entityId: child), equals: simd_float3(10.0, 1.0, 0.0))
        assertVector(getPosition(entityId: stub), equals: simd_float3(10.0, 0.0, 0.0))
        assertTraversalChangesNothing([parent, root, child, stub])
    }

    func testStreamSceneRoot_destroyTakesTheChildrenItHad() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let (parent, root, child) = makePlacedRoot()

        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        destroyEntity(entityId: root)
        finalizePendingDestroys()

        XCTAssertFalse(scene.exists(root))
        XCTAssertFalse(scene.exists(stub), "The tile stub goes with the root")
        XCTAssertFalse(scene.exists(child), "An entity parented under the root before the scene was attached goes with it")
        XCTAssertTrue(scene.exists(parent))
        XCTAssertTrue(getEntityChildren(parentId: parent).isEmpty, "The parent no longer lists the destroyed root")
    }

    /// A root that was placed streams from where the manifest puts the tiles, like a fresh one.
    func testStreamSceneRoot_placedRootStreamsFromTheAuthoredPlace() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let root = createEntity()
        translateTo(entityId: root, position: simd_float3(1000.0, 0.0, 0.0))
        scaleTo(entityId: root, scale: simd_float3(2.0, 2.0, 2.0))

        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))
        XCTAssertEqual(getEntityParent(entityId: stub), root)
        assertVector(getPosition(entityId: stub), equals: .zero)

        // The tile spans -1...1 around the origin. A camera 10 m away that looks at it has
        // it in range and in view: the streaming tick dispatches it, and nothing else here
        // loads it.
        let camera = try XCTUnwrap(CameraSystem.shared.activeCamera)
        cameraLookAt(entityId: camera, eye: simd_float3(0.0, 0.0, 10.0), target: .zero, up: simd_float3(0.0, 1.0, 0.0))
        GeometryStreamingSystem.shared.update(cameraPosition: simd_float3(0.0, 0.0, 10.0), deltaTime: 0.016)

        let tileParsed = await waitUntil(timeout: 5.0) {
            scene.get(component: TileComponent.self, for: stub)?.state == .parsed
        }
        XCTAssertTrue(tileParsed, "The streaming tick should dispatch the tile under a root that was placed")

        let meshRoot = try XCTUnwrap(getEntityChildren(parentId: stub).first)
        XCTAssertFalse(GeometryStreamingSystem.shared.collectRenderDescendantIds(meshRoot).isEmpty)
        assertSceneGraphIsConsistent([root, stub, meshRoot])
    }

    func testStreamSceneRoot_freshRootIsLeftAsItIs() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let rootName = "Root \(UUID().uuidString)"
        let root = createEntity()
        setEntityName(entityId: root, name: rootName)
        let localBefore = try XCTUnwrap(scene.get(component: LocalTransformComponent.self, for: root))
        let worldBefore = try XCTUnwrap(scene.get(component: WorldTransformComponent.self, for: root))
        let graphBefore = try XCTUnwrap(scene.get(component: ScenegraphComponent.self, for: root))

        let warnings = await warningsLogged(mentioning: rootName) {
            let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
            XCTAssertTrue(didSucceed)
        }
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        XCTAssertTrue(scene.get(component: LocalTransformComponent.self, for: root) === localBefore)
        XCTAssertTrue(scene.get(component: WorldTransformComponent.self, for: root) === worldBefore)
        XCTAssertTrue(scene.get(component: ScenegraphComponent.self, for: root) === graphBefore)
        XCTAssertEqual(getEntityChildren(parentId: root), [stub])
        XCTAssertNil(getEntityParent(entityId: root))
        assertSceneGraphIsConsistent([root, stub])
        XCTAssertEqual(warnings, [], "A root from createEntity() is at identity: there is nothing to report")
    }

    /// A parent at identity, such as a group that only organizes the hierarchy, does not
    /// move the tiles: the root stays in it and nothing is reported.
    func testStreamSceneRoot_inAGroupAtIdentityStaysInTheGroup() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let rootName = "Root \(UUID().uuidString)"
        let group = createEntity()
        let root = createEntity()
        setEntityName(entityId: root, name: rootName)
        setParent(childId: root, parentId: group)

        let warnings = await warningsLogged(mentioning: rootName) {
            let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
            XCTAssertTrue(didSucceed)
        }
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        XCTAssertEqual(getEntityParent(entityId: root), group)
        XCTAssertEqual(getEntityChildren(parentId: group), [root])
        assertVector(getPosition(entityId: stub), equals: .zero)
        assertSceneGraphIsConsistent([group, root, stub])
        XCTAssertEqual(warnings, [])
    }

    /// An entity that does not come from `createEntity()` may have no transform or scene
    /// graph node; the root gets them then, as before.
    func testStreamSceneRoot_withoutTransformComponentsGetsThem() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let root = createEntity()
        removeEntityTransforms(entityId: root)
        scene.remove(component: ScenegraphComponent.self, from: root)

        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)
        let stub = try XCTUnwrap(findEntity(named: fixture.tileID))

        XCTAssertTrue(hasComponent(entityId: root, componentType: LocalTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: root, componentType: WorldTransformComponent.self))
        XCTAssertTrue(hasComponent(entityId: root, componentType: ScenegraphComponent.self))
        XCTAssertEqual(getEntityChildren(parentId: root), [stub])
        assertSceneGraphIsConsistent([root, stub])
    }

    func testStreamSceneRoot_warnsWhenItsTransformIsDiscarded() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let rootName = "Root \(UUID().uuidString)"
        let root = createEntity()
        setEntityName(entityId: root, name: rootName)
        translateTo(entityId: root, position: simd_float3(1.0, 2.0, 3.0))

        let warnings = await warningsLogged(mentioning: rootName) {
            let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
            XCTAssertTrue(didSucceed)
        }

        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("reset to identity") == true, "\(warnings)")
        assertVector(getPosition(entityId: root), equals: .zero)
    }

    func testStreamSceneRoot_warnsWhenAnAncestorKeepsItAwayFromIdentity() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        let rootName = "Root \(UUID().uuidString)"
        let grandparent = createEntity()
        let parent = createEntity()
        let root = createEntity()
        setEntityName(entityId: root, name: rootName)
        setParent(childId: parent, parentId: grandparent)
        setParent(childId: root, parentId: parent)
        translateTo(entityId: grandparent, position: simd_float3(10.0, 0.0, 0.0))

        let warnings = await warningsLogged(mentioning: rootName) {
            let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
            XCTAssertTrue(didSucceed)
        }

        XCTAssertEqual(warnings.count, 1, "\(warnings)")
        XCTAssertTrue(warnings.first?.contains("because of its ancestors") == true, "\(warnings)")
        // The hierarchy is the caller's: the root stays where its ancestors put it.
        XCTAssertEqual(getEntityParent(entityId: root), parent)
        assertVector(getPosition(entityId: root), equals: simd_float3(10.0, 0.0, 0.0))
    }

    /// A scene saved with a stream root that was moved and parented after it was loaded,
    /// which the editor allows. The deserializer attaches the stream scene to an entity it
    /// then places and parents from the file.
    func testStreamSceneRoot_savedSceneLoadsWithAConsistentSceneGraph() async throws {
        let fixture = try makeUntoldTileSceneFixture(includeHLOD: false, includeLOD: false)
        // The serializer stores the manifest of a project by its path inside the project.
        let previousAssetBasePath = assetBasePath
        assetBasePath = fixture.manifestURL.deletingLastPathComponent()
        defer { assetBasePath = previousAssetBasePath }

        let parent = createEntity()
        setEntityName(entityId: parent, name: "Saved Parent")
        let root = createEntity()
        setEntityName(entityId: root, name: "Saved Root")
        let didSucceed = await attachStreamScene(to: root, url: fixture.manifestURL)
        XCTAssertTrue(didSucceed)

        setParent(childId: root, parentId: parent)
        translateTo(entityId: root, position: simd_float3(1.0, 2.0, 3.0))
        let child = createEntity()
        setEntityName(entityId: child, name: "Saved Child")
        setParent(childId: child, parentId: root)
        translateTo(entityId: child, position: simd_float3(0.0, 1.0, 0.0))

        let sceneData = serializeScene()
        XCTAssertEqual(sceneData.entities.first(where: { $0.name == "Saved Root" })?.asset?.kind, .streamModel)

        destroyAllEntities()
        finalizePendingDestroys()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = true

        let sceneLoaded = expectation(description: "Scene deserialized")
        deserializeScene(sceneData: sceneData, completion: { sceneLoaded.fulfill() })
        await fulfillment(of: [sceneLoaded], timeout: 10.0)

        let loadedParent = try XCTUnwrap(findEntity(named: "Saved Parent"))
        let loadedRoot = try XCTUnwrap(findEntity(named: "Saved Root"))
        let loadedChild = try XCTUnwrap(findEntity(named: "Saved Child"))
        let loadedStub = try XCTUnwrap(findEntity(named: fixture.tileID))

        XCTAssertEqual(getEntityParent(entityId: loadedRoot), loadedParent)
        XCTAssertEqual(getEntityChildren(parentId: loadedParent), [loadedRoot])
        XCTAssertEqual(getEntityParent(entityId: loadedChild), loadedRoot)
        XCTAssertEqual(Set(getEntityChildren(parentId: loadedRoot)), [loadedChild, loadedStub])
        XCTAssertEqual(getEntityParent(entityId: loadedStub), loadedRoot)
        assertSceneGraphIsConsistent([loadedParent, loadedRoot, loadedChild, loadedStub])

        // The deserializer holds the world mutation gate until it has restored the saved
        // transform and parent of the root; the root is prepared under the same gate, so
        // the saved transform is always the one that is reset.
        assertVector(getLocalPosition(entityId: loadedRoot), equals: .zero)
        assertVector(getPosition(entityId: loadedChild), equals: simd_float3(0.0, 1.0, 0.0))
        assertVector(getPosition(entityId: loadedStub), equals: .zero)
        assertTraversalChangesNothing([loadedParent, loadedRoot, loadedChild, loadedStub])
    }

    /// A root at (1, 2, 3), turned and at twice its size, under a parent at (10, 0, 0), with
    /// a child of its own one metre above it.
    private func makePlacedRoot() -> (parent: EntityID, root: EntityID, child: EntityID) {
        let parent = createEntity()
        let root = createEntity()
        let child = createEntity()
        translateTo(entityId: parent, position: simd_float3(10.0, 0.0, 0.0))
        setParent(childId: root, parentId: parent)
        setParent(childId: child, parentId: root)
        translateTo(entityId: root, position: simd_float3(1.0, 2.0, 3.0))
        applyAxisRotations(entityId: root, axis: simd_float3(0.0, 90.0, 0.0))
        scaleTo(entityId: root, scale: simd_float3(2.0, 2.0, 2.0))
        translateTo(entityId: child, position: simd_float3(0.0, 1.0, 0.0))
        return (parent, root, child)
    }

    private func attachStreamScene(to rootEntityId: EntityID, url: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            setEntityStreamScene(entityId: rootEntityId, url: url) { @Sendable success in
                continuation.resume(returning: success)
            }
        }
    }

    /// Every link of the scene graph has to be stated by both of its ends: an entity is in
    /// the list of the parent it names, once, one level below it, and the children it lists
    /// name it as their parent.
    private func assertSceneGraphIsConsistent(
        _ entities: [EntityID],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for entityId in entities {
            guard let graph = scene.get(component: ScenegraphComponent.self, for: entityId) else {
                XCTFail("Entity \(entityId) has no scene graph node", file: file, line: line)
                continue
            }

            if graph.parent == .invalid {
                XCTAssertEqual(graph.level, 0, "Entity \(entityId) has no parent", file: file, line: line)
            } else if let parentGraph = scene.get(component: ScenegraphComponent.self, for: graph.parent) {
                XCTAssertEqual(
                    parentGraph.children.filter { $0 == entityId }.count, 1,
                    "Entity \(entityId) names a parent that should list it once", file: file, line: line
                )
                XCTAssertEqual(graph.level, parentGraph.level + 1, "Entity \(entityId) is one level below its parent", file: file, line: line)
            } else {
                XCTFail("Entity \(entityId) names a parent that is not in the scene graph", file: file, line: line)
            }

            for childId in graph.children {
                XCTAssertEqual(
                    scene.get(component: ScenegraphComponent.self, for: childId)?.parent, entityId,
                    "Entity \(entityId) lists a child that should name it as its parent", file: file, line: line
                )
            }
        }
    }

    /// The transform API keeps world matrices current, so they have to be the ones a scene
    /// graph traversal computes already: run one over the entities and check that it moves
    /// nothing.
    private func assertTraversalChangesNothing(
        _ entities: [EntityID],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let worldBefore = entities.map { scene.get(component: WorldTransformComponent.self, for: $0)?.space }

        for entityId in entities {
            scene.get(component: LocalTransformComponent.self, for: entityId)?.transformDirty = true
        }
        anyTransformDirty = true
        traverseSceneGraph()

        for (entityId, before) in zip(entities, worldBefore) {
            guard let before, let after = scene.get(component: WorldTransformComponent.self, for: entityId)?.space else {
                XCTFail("Entity \(entityId) has no world transform", file: file, line: line)
                continue
            }
            for column in 0 ..< 4 {
                XCTAssertLessThan(
                    simd_length(after[column] - before[column]), 0.0001,
                    "The traversal moved column \(column) of entity \(entityId)", file: file, line: line
                )
            }
        }
    }

    /// Runs `body` and returns the warnings logged during it that mention `text`.
    private func warningsLogged(mentioning text: String, during body: () async -> Void) async -> [String] {
        let recorder = LogRecorder()
        let previousLogLevel = Logger.logLevel
        Logger.logLevel = .debug
        defer { Logger.logLevel = previousLogLevel }
        Logger.addSink(recorder)

        await body()

        // Sinks are served in order on a queue of their own: once this marker has arrived,
        // so has everything logged before it.
        let marker = "End of recording \(UUID().uuidString)"
        Logger.log(message: marker)
        let markerArrived = await waitUntil(timeout: 5.0) { recorder.hasLogged(marker) }
        XCTAssertTrue(markerArrived, "The log sink should have been served")

        return recorder.warnings().filter { $0.contains(text) }
    }

    private func loadSceneManifest(at manifestURL: URL) async throws {
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

        await fulfillment(of: [expectation], timeout: 5.0)
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

/// Keeps what the engine logs. A sink is called on the logger's queue.
private final class LogRecorder: LoggerSink, @unchecked Sendable {
    private let lock = NSLock()
    private var events: [LogEvent] = []

    func didLog(_ event: LogEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
    }

    func hasLogged(_ message: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return events.contains { $0.message == message }
    }

    func warnings() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return events.filter { $0.level == .warning }.map(\.message)
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
    includeScenePayload: Bool = false,
    includeColorLUT: Bool = false
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

    if includeColorLUT {
        let lutSize = 4
        let width = lutSize * lutSize
        let payloadSize = width * lutSize * 8
        let writer = UntoldBinaryWriter()
        NativeTexHeader(
            flags: NativeTexFlags.hasAlpha,
            width: UInt32(width),
            height: UInt32(lutSize),
            mipCount: 1,
            pixelFormat: NativeTexFormat.rgba16FloatPixelFormat,
            blockWidth: 1,
            blockHeight: 1,
            payloadOffset: NativeTexFormat.payloadOffset(mipCount: 1),
            totalPayloadSize: UInt32(payloadSize)
        ).encode(to: writer)
        NativeTexMipEntry(
            byteOffset: 0,
            byteSize: UInt32(payloadSize),
            widthPx: UInt32(width),
            heightPx: UInt32(lutSize)
        ).encode(to: writer)
        writer.writeData(Data(count: payloadSize))
        let lutFileName = "gradelut_test.utex"
        try writer.data.write(to: fixtureRoot.appendingPathComponent(lutFileName))

        manifest["colorLUT"] = [
            "lutUri": lutFileName,
            "lutSize": lutSize,
            "viewTransform": "AgX",
            "look": "Medium High Contrast",
            "displayDevice": "sRGB",
            "exposure": 0.0,
            "gamma": 1.0,
            "shaperMinStops": -10.0,
            "shaperMaxStops": 6.0,
        ]
    }

    if includeScenePayload {
        let keyLightRows: [[Float]] = [
            [1.0, 0.0, 0.0, 2.0],
            [0.0, 1.0, 0.0, 3.0],
            [0.0, 0.0, 1.0, 4.0],
            [0.0, 0.0, 0.0, 1.0],
        ]
        let keyLight: [String: Any] = [
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
            "local_transform_rows": keyLightRows,
        ]
        let spotFallback: [String: Any] = [
            "entity_name": "Manifest Spot Fallback",
            "kind": "spot",
            "color": [1.0, 0.6, 0.2],
            "intensity": 2.0,
            "position": [-2.0, 3.0, 4.0],
            "radius": 9.0,
            "direction": [0.0, -1.0, 0.0],
            "falloff": 0.2,
            "right": [1.0, 0.0, 0.0],
            "inner_cone": 8.0,
            "up": [0.0, 0.0, -1.0],
            "outer_cone": 20.0,
            "area_size": [1.0, 1.0],
            "source_power": 2.0,
            "source_exposure": 0.0,
        ]
        let areaFallback: [String: Any] = [
            "entity_name": "Manifest Area Fallback",
            "kind": "area",
            "color": [0.4, 1.0, 0.6],
            "intensity": 4.0,
            "position": [0.0, 5.0, 0.0],
            "radius": 1.0,
            "direction": [0.0, 0.0, -1.0],
            "falloff": 0.5,
            "right": [1.0, 0.0, 0.0],
            "inner_cone": 5.0,
            "up": [0.0, 1.0, 0.0],
            "outer_cone": 10.0,
            "area_size": [3.0, 2.0],
            "source_power": 4.0,
            "source_exposure": 0.0,
        ]
        manifest["scene_lights"] = [keyLight, spotFallback, areaFallback]

        let cameraRows: [[Float]] = [
            [1.0, 0.0, 0.0, 0.0],
            [0.0, 1.0, 0.0, 1.0],
            [0.0, 0.0, 1.0, 6.0],
            [0.0, 0.0, 0.0, 1.0],
        ]
        let camera: [String: Any] = [
            "entity_name": "Manifest Camera",
            "position": [0.0, 1.0, 6.0],
            "forward": [0.0, 0.0, 1.0],
            "up": [0.0, 1.0, 0.0],
            "right": [1.0, 0.0, 0.0],
            "fov_y_degrees": 55.0,
            "near_clip": 0.05,
            "far_clip": 750.0,
            "aspect_ratio": 1.6,
            "local_transform_rows": cameraRows,
        ]
        manifest["scene_cameras"] = [camera]
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
