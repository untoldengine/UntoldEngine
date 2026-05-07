//
//  RemoteStreamFlyThroughTests.swift
//  UntoldEngine
//
//  Integration test: loads a remote tiled scene, flies the camera through
//  a sequence of waypoints, and PSNR-compares a screenshot at each stop.
//
//  ## Workflow
//
//  STEP 1 — Generate reference images (first run only):
//    1. Set your real manifest URL in `manifestURLString` below
//       (or pass it via UNTOLD_STREAM_MANIFEST_URL env var).
//    2. Adjust `waypoints` to positions that give meaningful views of your scene.
//    3. Uncomment `testGenerateFlythroughReferenceImages` and run it once.
//    4. Copy the PNGs from ~/Downloads/UntoldEngineRenderingTest/ into
//       Tests/UntoldEngineRenderTests/Resources/ and add them to the
//       test bundle target.
//    5. Re-comment the generator test.
//
//  STEP 2 — Run the PSNR regression test:
//    Run `testRemoteStreamFlythrough_psnr` normally.  It skips automatically
//    when UNTOLD_STREAM_MANIFEST_URL is unset and manifestURLString is still
//    the placeholder value.
//
//  ## Environment variables
//
//  UNTOLD_STREAM_MANIFEST_URL   — override the CDN manifest URL at runtime
//  UNTOLD_PSNR_THRESHOLD        — PSNR pass threshold in dB (default 11.0)
//  UNTOLD_PYTHON                — path to python3 (default "python3")
//

import CShaderTypes
import Foundation
import simd
import UniformTypeIdentifiers
@preconcurrency @testable import UntoldEngine
import XCTest

@MainActor
final class RemoteStreamFlyThroughTests: BaseRenderSetup {
    // -------------------------------------------------------------------------
    // MARK: - Configuration — edit these for your scene

    // -------------------------------------------------------------------------

    /// Remote (or local file://) URL of your tile manifest.
    /// Override at runtime with the UNTOLD_STREAM_MANIFEST_URL env var.
    private let manifestURLString = "https://d8pyi1c08k1w.cloudfront.net/city/city.json"

    /// Waypoints the camera visits.  At each stop a screenshot is taken.
    /// Adjust positions and look-at targets to match your dungeon layout.
    private let waypoints: [CameraWaypoint] = [
        CameraWaypoint(
            position: simd_float3(0.0, 13.034016, 1.9943304),
            lookAt: simd_float3(0.0, 11.390026, -7.869609),
            up: simd_float3(0.0, 1.0, 0.0),
            segmentDuration: 6.0 // simulated travel time to NEXT waypoint
        ),
        CameraWaypoint(
            position: simd_float3(41.899933, 17.116201, -9.373858),
            lookAt: simd_float3(41.899933, 12.013494, -17.973995),
            up: simd_float3(0.0, 1.0, 0.0),
            segmentDuration: 6.0
        ),
        CameraWaypoint(
            position: simd_float3(50.16962, 14.7179165, -5.8297567),
            lookAt: simd_float3(42.4472, 9.615206, -2.044711),
            up: simd_float3(0.0, 1.0, 0.0),
            segmentDuration: 0.0 // terminal waypoint — duration unused
        ),
    ]

    /// Names used for reference and test PNG filenames.
    /// Must match the Resources/*.png names you add to the test bundle.
    private let keyframeNames = [
        "FlythroughWaypoint1",
        "FlythroughWaypoint2",
        "FlythroughWaypoint3",
    ]

    // -------------------------------------------------------------------------
    // MARK: - XCTest lifecycle

    // -------------------------------------------------------------------------

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
        stopCameraPath()
        GeometryStreamingSystem.shared.reset()
        GeometryStreamingSystem.shared.enabled = false
        MemoryBudgetManager.shared.clear()
        destroyAllEntities()
        try await super.tearDown()
    }

    /// Skip the default stadium/player scene — this test streams its own scene.
    override func initializeAssets() {
        let camera = findGameCamera()
        CameraSystem.shared.activeCamera = camera

        cameraLookAt(
            entityId: camera,
            eye: waypoints[0].position,
            target: simd_float3(0.0, 1.0, 0.0),
            up: simd_float3(0.0, 1.0, 0.0)
        )

        let sun = createEntity()
        createDirLight(entityId: sun)
        ambientIntensity = 0.4
        renderEnvironment = true
        SSAOParams.shared.enabled = false
    }

    // -------------------------------------------------------------------------
    // MARK: - Reference image generator  (uncomment for first run only)

    // -------------------------------------------------------------------------

    /*
     func testGenerateFlythroughReferenceImages() async throws {
         let sceneRoot = try await loadRemoteScene()

         for (index, waypoint) in waypoints.enumerated() {
             let name = keyframeNames[index]
             snapCamera(to: waypoint)
             await driveStreamingUntilReady(sceneRoot: sceneRoot)
             setVisibleEntities()
             for _ in 0 ..< 5 { renderer.draw(in: renderer.metalView) }

             if let tex = renderInfo.deferredRenderPassDescriptor.colorAttachments[0].texture {
                 testGenerateRenderTarget(targetName: name, texture: tex)
                 print("📸 \(name): saved to ~/Downloads/UntoldEngineRenderingTest/")
             }

             if index + 1 < waypoints.count {
                 await animateCameraPath(from: waypoint, to: waypoints[index + 1], sceneRoot: sceneRoot)
             }
         }
     }
     */

    // -------------------------------------------------------------------------
    // MARK: - PSNR regression test

    // -------------------------------------------------------------------------

    func testRemoteStreamFlythrough_psnr() async throws {
        let sceneRoot = try await loadRemoteScene()

        for (index, waypoint) in waypoints.enumerated() {
            let name = keyframeNames[index]

            // Snap to waypoint, wait for nearby tiles to finish loading
            snapCamera(to: waypoint)
            let ready = await driveStreamingUntilReady(sceneRoot: sceneRoot)
            if !ready {
                print("⚠️ \(name): tiles did not fully settle within timeout; capturing partial frame.")
            }

            // Refresh the visible-entity list (new tile geometry may have appeared)
            setVisibleEntities()

            // Render a few frames to let the GPU pipeline warm up at this position
            for _ in 0 ..< 5 {
                renderer.draw(in: renderer.metalView)
            }

            // Capture the deferred-lighting composite and PSNR-compare
            guard let compositeTexture = renderInfo.deferredRenderPassDescriptor
                .colorAttachments[0].texture
            else {
                XCTFail("\(name): deferredRenderPassDescriptor composite texture is nil")
                continue
            }
            psnrTest(targetName: name, texture: compositeTexture)

            // Animate to the next waypoint (skip on last stop)
            if index + 1 < waypoints.count {
                await animateCameraPath(from: waypoint, to: waypoints[index + 1], sceneRoot: sceneRoot)
            }
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Shared helpers

    // -------------------------------------------------------------------------

    /// Resolves the manifest URL, loads the remote tiled scene, and returns the
    /// root entity.  Skips the test if no real URL is configured.
    private func loadRemoteScene() async throws -> EntityID {
        let urlString = ProcessInfo.processInfo.environment["UNTOLD_STREAM_MANIFEST_URL"]
            ?? manifestURLString

        guard urlString != "https://cdn.example.com/dungeon/dungeon.json",
              let manifestURL = URL(string: urlString)
        else {
            throw XCTSkip(
                "No manifest URL configured. " +
                    "Set UNTOLD_STREAM_MANIFEST_URL or edit manifestURLString in RemoteStreamFlyThroughTests.swift."
            )
        }

        let sceneRoot = createEntity()
        let loaded = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            setEntityStreamScene(entityId: sceneRoot, url: manifestURL) { @Sendable success in
                continuation.resume(returning: success)
            }
        }
        XCTAssertTrue(loaded, "Remote manifest \(urlString) should load successfully")
        return sceneRoot
    }

    /// Snaps the camera to `waypoint` using a single-waypoint path (instant).
    private func snapCamera(to waypoint: CameraWaypoint) {
        startCameraPath(
            waypoints: [waypoint],
            mode: .once,
            settings: CameraPathSettings(startImmediately: true)
        )
    }

    /// Calls GeometryStreamingSystem.update() in a 25 ms polling loop until all
    /// tiles that started loading have finished parsing, then returns.
    /// Returns true if the condition was met within the timeout, false otherwise.
    @discardableResult
    private func driveStreamingUntilReady(sceneRoot: EntityID, timeout: TimeInterval = 30.0) async -> Bool {
        let camera = findGameCamera()
        return await waitUntil(timeout: timeout) {
            let camPos = getCameraPosition(entityId: camera)
            GeometryStreamingSystem.shared.update(cameraPosition: camPos, deltaTime: 0.016)
            return self.tilesAreReady(sceneRoot: sceneRoot)
        }
    }

    /// True when at least one tile has parsed and no tile is still mid-parse.
    private func tilesAreReady(sceneRoot: EntityID) -> Bool {
        let tileIds = getEntityChildren(parentId: sceneRoot)
        guard !tileIds.isEmpty else { return false }
        let hasParsed = tileIds.contains {
            scene.get(component: TileComponent.self, for: $0)?.state == .parsed
        }
        let stillParsing = tileIds.contains {
            scene.get(component: TileComponent.self, for: $0)?.state == .parsing
        }
        return hasParsed && !stillParsing
    }

    /// Simulates the camera flying from `origin` to `destination` at 60 fps
    /// while streaming tiles along the path, then waits for tiles to settle.
    private func animateCameraPath(
        from origin: CameraWaypoint,
        to destination: CameraWaypoint,
        sceneRoot: EntityID
    ) async {
        let camera = findGameCamera()
        final class Flag: @unchecked Sendable { var value = false }
        let pathFinished = Flag()

        startCameraPath(
            waypoints: [origin, destination],
            mode: .once,
            settings: CameraPathSettings(startImmediately: true) { pathFinished.value = true }
        )

        let dt: Float = 0.016
        let steps = Int(ceil(origin.segmentDuration / dt)) + 5
        for _ in 0 ..< steps {
            updateCameraPath(deltaTime: dt)
            let pos = getCameraPosition(entityId: camera)
            GeometryStreamingSystem.shared.update(cameraPosition: pos, deltaTime: dt)
        }

        XCTAssertTrue(pathFinished.value, "Camera path to destination should complete within simulated time")

        // Give any newly in-range tiles a chance to parse before the next capture
        await driveStreamingUntilReady(sceneRoot: sceneRoot, timeout: 15.0)
    }

    private func waitUntil(
        timeout: TimeInterval,
        pollIntervalNanoseconds: UInt64 = 25_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        return condition()
    }
}
