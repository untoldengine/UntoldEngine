
//
//  UntoldEngine.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import Metal
import MetalKit
import simd

public protocol UntoldRendererDelegate {
    func willDraw(in view: MTKView)
    func didDraw(in view: MTKView)
}

public class UntoldRenderer: NSObject, MTKViewDelegate {
    public let metalView: MTKView

    var gameUpdateCallback: ((_ deltaTime: Float) -> Void)?
    var handleInputCallback: (() -> Void)?

    private var configuration: UntoldRendererConfig
    public var delegate: UntoldRendererDelegate?
    public var pendingResize = false

    init(configuration: UntoldRendererConfig? = nil) {
        self.configuration = configuration ?? .default

        // Set the metal view from configuration or create new one
        metalView = self.configuration.metalView ?? MTKView()

        #if canImport(AppKit)
            Logger.addSink(LogStore.shared)
        #endif

        super.init()
    }

    public static func create(configuration: UntoldRendererConfig? = nil) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        guard let device = MTLCreateSystemDefaultDevice() else {
            Logger.logError(message: "Metal device is not available.")
            return nil
        }
        renderer.metalView.device = device
        renderer.metalView.depthStencilPixelFormat = .depth32Float
        renderer.metalView.colorPixelFormat = .bgra8Unorm_srgb
        renderer.metalView.preferredFramesPerSecond = 60
        (renderer.metalView.layer as? CAMetalLayer)?.contentsScale = 1.0
        renderer.metalView.framebufferOnly = false
        renderer.metalView.delegate = renderer

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }
        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = false
        renderInfo.colorPixelFormat = .rgba16Float
        renderInfo.depthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(renderer.metalView.drawableSize.width), Float(renderer.metalView.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = renderer.metalView.colorPixelFormat
        renderInfo.presentDepthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        renderer.initResources()

        return renderer
    }

    public static func create(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }

        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = false
        renderInfo.colorPixelFormat = .rgba16Float
        renderInfo.depthPixelFormat = view.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(view.drawableSize.width), Float(view.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = view.colorPixelFormat
        renderInfo.presentDepthPixelFormat = view.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        renderer.initResources()

        return renderer
    }

    public func setupCallbacks(
        gameUpdate: @escaping (_ deltaTime: Float) -> Void,
        handleInput: @escaping () -> Void
    ) {
        gameUpdateCallback = gameUpdate
        handleInputCallback = handleInput
    }

    func initResources() {
        initBufferResources()

        PipelineManager.shared.initRenderPipelines(configuration.initRenderPipelineBlocks)

        initSizeableResources() // TODO: Find a better name function

        shadowSystem = ShadowSystem()

        // init ssao kernels
        initSSAOResources()

        initFrustumCulllingCompute()

        initGuassianComputePipelines()
        initScenePickingSystem()

        initScriptingSystem()

        // Create defautls objects.
        let gameCamera = createEntity()
        setEntityName(entityId: gameCamera, name: "Main Camera")
        createGameCamera(entityId: gameCamera)

        let light = createEntity()
        setEntityName(entityId: light, name: "Directional Light")
        createDirLight(entityId: light)

        CameraSystem.shared.activeCamera = gameCamera

        Logger.log(message: "Untold Engine Starting")
    }

    public func initSizeableResources() {
        if renderInfo.viewPort.x == 0 || renderInfo.viewPort.y == 0 { return }

        initRTXAccumulationBuffer()

        initTextureResources()
        initRenderPassDescriptors()
        initIBLResources()

        // Initialize SSAO quality-based textures (must come after initTextureResources)
        reinitSSAOTextures()
    }

    func calculateDeltaTime() {
        if !firstUpdateCall {
            // init the time properties for the update

            timeSinceLastUpdate = 0.0

            timeSinceLastUpdatePreviousTime = CACurrentMediaTime()

            firstUpdateCall = true

            // init fps time properties
            frameCount = 0
            timePassedSinceLastFrame = 0.0

        } else {
            // figure out the time since we last we drew
            let currentTime: TimeInterval = CACurrentMediaTime()

            timeSinceLastUpdate = Float(currentTime - timeSinceLastUpdatePreviousTime)

            // keep track of the time interval between draws
            timeSinceLastUpdatePreviousTime = currentTime

            // get fps
            timePassedSinceLastFrame += Float(timeSinceLastUpdate)

            if timePassedSinceLastFrame > 0.1 {
                // let fps:Float=Float(frameCount)/timePassedSinceLastFrame

                frameCount = 0
                timePassedSinceLastFrame = 0.0
            }
        }
    }

    @discardableResult
    private func runFrame(beforeRender: (() -> Void)? = nil,
                          render: (() -> Void)? = nil,
                          afterRender: (() -> Void)? = nil) -> Bool
    {
        EngineProfiler.shared.beginFrame()

        // finalize destroys once per frame
        if needsFinalizeDestroys {
            needsFinalizeDestroys = false
            if hasPendingDestroys {
                finalizePendingDestroys()
                hasPendingDestroys = false
            }
        }

        MemoryBudgetManager.shared.beginFrame()

        // must have a valid camera
        guard CameraSystem.shared.activeCamera != .invalid else {
            handleError(.noActiveCamera)
            EngineProfiler.shared.endFrame()
            return false
        }

        // Get camera position
        if let camera = CameraSystem.shared.activeCamera,
           let transform = scene.get(component: WorldTransformComponent.self, for: camera)
        {
            let cameraPos = simd_float3(
                transform.space.columns.3.x,
                transform.space.columns.3.y,
                transform.space.columns.3.z
            )

            // === SYSTEM INTEGRATION PIPELINE ===
            // Order matters: Streaming -> LOD -> Batching -> Render

            // 1. Update streaming region manager
            StreamingRegionManager.shared.update(
                cameraPosition: cameraPos,
                deltaTime: fixedStep
            )

            // 2. Update geometry streaming (decides what meshes exist in memory)
            GeometryStreamingSystem.shared.update(
                cameraPosition: cameraPos,
                deltaTime: fixedStep
            )
        }

        frameCount += 1

        // pre-render hook (e.g., editor hot reload)
        beforeRender?()

        // simulation/update pipeline
        EngineProfiler.shared.beginScope(.update)
        calculateDeltaTime()
        traverseSceneGraph()
        handleInputCallback?()

        // 3. LOD selection (decides which representation is active, checks residency)
        LODSystem.shared.update(deltaTime: fixedStep)

        // 4. Flush events (residency and LOD change events are processed)
        SystemEventBus.shared.flushEvents()

        // 5. Batching incremental update (consumes LOD change events)
        BatchingSystem.shared.tick()

        // 6. Integration stats monitoring
        SystemIntegrationMonitor.shared.tick()
        HZBDebugMonitor.shared.tick()

        OctreeSystem.shared.updateDirtyBounds()

        if gameMode == true {
            AnimationSystem.shared.update(timeSinceLastUpdate)

            // USC scripts (runs every frame in Play mode)
            USCSystem.shared.update(timeSinceLastUpdate)

            // fixed‐timestep physics
            physicsAccumulator += timeSinceLastUpdate
            let maxSteps = 5
            var steps = 0
            while physicsAccumulator >= fixedStep, steps < maxSteps {
                updatePhysicsSystem(deltaTime: fixedStep)
                updateCustomSystems(deltaTime: fixedStep)
                physicsAccumulator -= fixedStep
                steps += 1
            }

            // user game update
            gameUpdateCallback?(timeSinceLastUpdate)
        }
        EngineProfiler.shared.endScope(.update)

        // render hook (platform-specific)
        render?()

        // post-render hook (e.g., editor)
        afterRender?()

        EngineProfiler.shared.endFrame()
        return true
    }

    public func draw(in view: MTKView) {
        if pendingResize {
            initSizeableResources()
            pendingResize = false
        }
        _ = runFrame(
            beforeRender: { [weak self] in self?.delegate?.willDraw(in: view) },
            render: { [weak self] in
                guard let self else { return }
                configuration.updateRenderingSystemCallback(view)
            },
            afterRender: { [weak self] in self?.delegate?.didDraw(in: view) }
        )
    }

    public func mtkView(_ mtkView: MTKView, drawableSizeWillChange size: CGSize) {
        let oldSize = mtkView.drawableSize
        if size.width == 0 || size.height == 0 {
            return
        }

        let aspect = Float(size.width) / Float(size.height)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(size.width), Float(size.height))
        renderInfo.viewPort = viewPortSize

        let sizeChanged = abs(oldSize.width - size.width) > 0.1 || abs(oldSize.height - size.height) > 0.1
        if size.width > 0, size.height > 0, sizeChanged {
            // Recreate viewport-sized resources once at the start of the next frame.
            if !pendingResize {
                pendingResize = true
            }
        }
    }

    // MARK: - XR Entry Point (VisionOS)

    public static func createXR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, commandQueue: MTLCommandQueue, colorPixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat, viewPort: simd_float2) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = true
        renderInfo.colorPixelFormat = colorPixelFormat
        renderInfo.depthPixelFormat = depthPixelFormat
        renderInfo.viewPort = viewPort

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = colorPixelFormat
        renderInfo.presentDepthPixelFormat = depthPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        renderer.initResources()

        renderEnvironment = true

        return renderer
    }

    public func updateXR() {
        _ = runFrame()
    }

    public func updateXR(render: @escaping () -> Void) {
        _ = runFrame(render: render)
    }

    public func renderXR(
        commandBuffer: MTLCommandBuffer,
        passDescriptor: MTLRenderPassDescriptor,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        eyeIndex _: Int
    ) {
        renderInfo.perspectiveSpace = projectionMatrix

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        cameraComponent.viewSpace = viewMatrix

        configuration.updateXRRenderingSystemCallback!(.xr(commandBuffer: commandBuffer, passDescriptor: passDescriptor))
    }

    public func getConfiguration() -> UntoldRendererConfig {
        configuration
    }

    public static func createiOS(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView, immersionStyle: UntoldImmersionMode = .none) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }

        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = false
        renderInfo.colorPixelFormat = view.colorPixelFormat
        renderInfo.depthPixelFormat = view.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(Float(view.bounds.size.width), Float(view.bounds.size.height))

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = view.colorPixelFormat
        renderInfo.presentDepthPixelFormat = view.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        renderer.initResources()

        renderInfo.immersionStyle = immersionStyle
        return renderer
    }

    // MARK: - AR Entry Point (iOS)

    public static func createAR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView) -> UntoldRenderer? {
        createiOS(configuration: configuration, device: device, view: view, immersionStyle: .ar)
    }
}
