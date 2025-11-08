
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
            assertionFailure("Metal device is not available.")
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
        renderInfo.colorPixelFormat = .rgba16Float
        renderInfo.depthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(renderer.metalView.drawableSize.width), Float(renderer.metalView.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

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
        // finalize destroys once per frame
        if needsFinalizeDestroys {
            needsFinalizeDestroys = false
            if hasPendingDestroys {
                finalizePendingDestroys()
                hasPendingDestroys = false
            }
        }

        // must have a valid camera
        guard CameraSystem.shared.activeCamera != .invalid else {
            handleError(.noActiveCamera)
            return false
        }

        frameCount += 1

        // pre-render hook (e.g., editor hot reload)
        beforeRender?()

        // simulation/update pipeline
        calculateDeltaTime()
        traverseSceneGraph()
        handleInputCallback?()
        AnimationSystem.shared.update(timeSinceLastUpdate)

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

        // render hook (platform-specific)
        render?()

        // post-render hook (e.g., editor)
        afterRender?()

        return true
    }

    public func draw(in view: MTKView) {
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

        let aspect = Float(size.width) / Float(size.height)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(size.width), Float(size.height))
        renderInfo.viewPort = viewPortSize

        if oldSize.width == 0 || oldSize.height == 0 {
            // Init sizeable resources
            initSizeableResources()
        } else if abs(oldSize.width - size.height) < 0.1,
                  abs(oldSize.height - size.width) < 0.1
        {
            // Init the resources again becasue the rotation of the screen
            initResources()
        }
        // TODO: We should init the resources again if they change the view size?
    }

    // MARK: - XR Entry Point (VisionOS)

    public static func createXR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, commandQueue: MTLCommandQueue, colorPixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat, viewPort: simd_float2) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.colorPixelFormat = colorPixelFormat
        renderInfo.depthPixelFormat = depthPixelFormat
        renderInfo.viewPort = viewPort

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

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

    public static func createAR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }

        renderInfo.commandQueue = commandQueue
        renderInfo.colorPixelFormat = view.colorPixelFormat
        renderInfo.depthPixelFormat = view.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(Float(view.bounds.size.width), Float(view.bounds.size.height))

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        renderer.initResources()

        renderInfo.immersionStyle = .ar

        return renderer
    }
}
