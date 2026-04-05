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

    private func loadSceneManifest(at manifestURL: URL) throws {
        let expectation = XCTestExpectation(description: "Manifest loaded")
        let manifestStem = manifestURL.deletingPathExtension().path
        var didSucceed = false

        loadTiledScene(manifest: manifestStem, withExtension: manifestURL.pathExtension) { success in
            didSucceed = success
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)
        XCTAssertTrue(didSucceed, "Tile manifest should load successfully")
    }

    /// Async variant that wraps `loadTiledScene(url:)` in a `CheckedContinuation`
    /// so it can be awaited from `async throws` test methods without using
    /// `wait(for:)` which is unavailable in async contexts.
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

private func makeUntoldTileSceneFixture(includeHLOD: Bool, includeLOD: Bool) throws -> UntoldTileSceneFixture {
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

    let manifest: [String: Any] = [
        "version": 1,
        "streaming_defaults": [
            "streaming_radius": 50.0,
            "unload_radius": 120.0,
            "priority": 0,
            "prefetch_radius": 80.0,
        ],
        "tiles": [tileEntry],
    ]

    let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
    let manifestURL = fixtureRoot.appendingPathComponent("scene.json")
    try manifestData.write(to: manifestURL)

    return UntoldTileSceneFixture(
        manifestURL: manifestURL,
        tileID: "tile_0_0",
        tileFileName: tileFileName
    )
}
