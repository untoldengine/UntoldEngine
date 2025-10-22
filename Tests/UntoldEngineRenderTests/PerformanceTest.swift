//
//  PerformanceTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class PerformanceTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!
    let saveToDisk: Bool = true // set to true to save ref, rendered and diff images to the download folder: Download/UntoldEngineRenderingTest
    let timeoutFactor: Float = 5.0
    let windowWidth = 800
    let windowHeight = 600

    // Set up a headless renderer.
    override func setUp() {
        super.setUp()
        ambientIntensity = 0.4

        let bundleURL = Bundle.module.resourceURL
        assetBasePath = bundleURL

        // Create the renderer as usual
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }
        self.renderer = renderer

        // Pick a canonical test size (1× pixels, same references/CI)
        let size = CGSize(width: windowWidth, height: windowHeight)

        // DO NOT create/attach a window (no Retina/backingScale involved)
        // Just configure the MTKView directly.
        renderer.metalView.autoResizeDrawable = false
        renderer.metalView.drawableSize = size // pixels (locks 1×)
        (renderer.metalView.layer as? CAMetalLayer)?.contentsScale = 1.0 // belt-and-suspenders
        renderer.metalView.frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight) // bounds in points

        renderer.mtkView(renderer.metalView, drawableSizeWillChange: size)

        let aspect = Float(windowWidth) / Float(windowHeight)
        renderInfo.perspectiveSpace = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov),
            aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.viewPort = simd_float2(Float(windowWidth), Float(windowHeight))

        initializeAssets()

        setVisibleEntities()
    }

    override func tearDown() {
        super.tearDown()
    }

    // Temp solution until I figure out how to get culling working inside this test routine
    func setVisibleEntities() {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, renderId], in: scene)

        for entity in entities {
            visibleEntityIds.append(entity)
        }
    }

    private func initializeAssets() {
        cameraLookAt(entityId: findGameCamera(), eye: simd_float3(0.0, 3.0, 7.0), target: simd_float3(0.0, 0.0, 0.0), up: simd_float3(0.0, 1.0, 0.0))

        // Stadium (static mesh)
        let stadium = createEntity()
        setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdz")
        translateBy(entityId: stadium, position: simd_float3(0.0, 0.0, 0.0))

        // Player (animated, named for lookup)
        let player = createEntity()
        setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdz", flip: false)
        setEntityAnimations(entityId: player, filename: "running", withExtension: "usdz", name: "running")
        setEntityName(entityId: player, name: "player")
        rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))

        changeAnimation(entityId: player, name: "running")

        // Ball (named for lookup)
        let ball = createEntity()
        setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdz")
        setEntityName(entityId: ball, name: "ball")
        translateBy(entityId: ball, position: simd_float3(0.0, 0.6, 3.0))

        ambientIntensity = 0.4

        let sunEntity: EntityID = createEntity()

        createDirLight(entityId: sunEntity)

        let pointLight = createEntity()
        createPointLight(entityId: pointLight)

        translateTo(entityId: pointLight, position: simd_float3(3.0, 0.5, 0.0))

        let spotLight = createEntity()
        createSpotLight(entityId: spotLight)

        translateTo(entityId: spotLight, position: simd_float3(-3.0, 1.0, 0.0))

        renderEnvironment = true
    }

    func test_AverageFrameTime_UnderBudget() throws {
        // Tune per target device
        let frameBudgetMs = 16.67 // ~60 FPS
        let warmupFrames = 120
        let measuredFrames = 300

        // Safety
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }

        // Warmup: compile pipelines, fill caches
        for _ in 0 ..< warmupFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Measure N frames
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< measuredFrames {
            renderer.draw(in: renderer.metalView)
        }
        let end = CFAbsoluteTimeGetCurrent()

        let avgMs = ((end - start) / Double(measuredFrames)) * 1000.0
        let fps = 1000.0 / avgMs
        print(String(format: "Perf (wall-clock): avg %.2f ms (%.1f FPS) over %d frames",
                     avgMs, fps, measuredFrames))

        XCTAssertLessThanOrEqual(
            avgMs,
            frameBudgetMs,
            String(format: "Average frame time %.2f ms exceeded budget %.2f ms (%.1f FPS).",
                   avgMs, frameBudgetMs, fps)
        )
    }
}
