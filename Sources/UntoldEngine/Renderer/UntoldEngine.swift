
//
//  UntoldEngine.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/24.
//

import Foundation
import Metal
import MetalKit
import simd
import Spatial

public class UntoldRenderer: NSObject, MTKViewDelegate {
    public let metalView: MTKView
    public var gameUpdateCallback: ((_ deltaTime: Float) -> Void)?
    public var handleInputCallback: (() -> Void)?

    override public init() {
        // Initialize the metal view
        metalView = MTKView()

        super.init()
    }

    public static func create() -> UntoldRenderer? {
        let renderer = UntoldRenderer()

        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Metal device is not available.")
            return nil
        }
        renderer.metalView.device = device
        renderer.metalView.depthStencilPixelFormat = .depth32Float
        renderer.metalView.colorPixelFormat = .rgba16Float
        renderer.metalView.preferredFramesPerSecond = 60
        renderer.metalView.framebufferOnly = false
        renderer.metalView.delegate = renderer

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }
        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.colorPixelFormat = renderer.metalView.colorPixelFormat
        renderInfo.depthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(renderer.metalView.drawableSize.width), Float(renderer.metalView.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        #if os(iOS)
            let libraryURL = Bundle.module.url(forResource: "UntoldEngineKernels-ios", withExtension: "metallib")!
        #elseif os(macOS)
            let libraryURL = Bundle.module.url(forResource: "UntoldEngineKernels", withExtension: "metallib")!
            // elseif os(xrOS)
            // let libraryURL=Bundle.main.url(forResource: "UntoldEngineKernels-xros", withExtension: "metallib")
            // elseif os(xrOS)
        #endif

        do {
            let mainLibrary = try renderInfo.device.makeLibrary(URL: libraryURL)
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            Logger.logError(message: "Failed to load metallib: \(error)")
        }

        return renderer
    }

    public func setupCallbacks(
        gameUpdate: @escaping (_ deltaTime: Float) -> Void,
        handleInput: @escaping () -> Void
    ) {
        gameUpdateCallback = gameUpdate
        handleInputCallback = handleInput
    }

    public func initResources() {
        initBufferResources()

        initTextureResources()
        initRenderPipelines()

        initRenderPassDescriptors()
        initIBLResources()

        shadowSystem = ShadowSystem()

        inputSystem.setupGestureRecognizers(view: metalView)
        inputSystem.setupEventMonitors()

        let sceneCamera = createEntity()
        createSceneCamera(entityId: sceneCamera)

        let gameCamera = createEntity()
        setEntityName(entityId: gameCamera, name: "Game Camera")
        createGameCamera(entityId: gameCamera)

        let light = createEntity()
        setEntityName(entityId: light, name: "Main Light")
        createLight(entityId: light, lightType: .directional)

        Logger.log(message: "Untold Engine Starting")
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

    public func draw(in view: MTKView) {
        if getMainCamera() == .invalid {
            handleError(.noGameCamera)
            return
        }

        // call the update call before the render
        frameCount += 1

        if hotReload {
            // updateRayKernelPipeline()
            // updateShadersAndPipeline()

            hotReload = false
        }

        // calculate delta time for frame
        calculateDeltaTime()
        traverseSceneGraph()
        // process Input - Handle user input before updating game states
        if gameMode == true {
            handleInputCallback?() // if game mode
            updatePhysicsSystem(deltaTime: timeSinceLastUpdate)
            updateAnimationSystem(deltaTime: timeSinceLastUpdate)
            updateCustomSystems(deltaTime: timePassedSinceLastFrame)
        } else {
            handleSceneInput() // if scene mode
        }

        // update game states and logic
        gameUpdateCallback?(timeSinceLastUpdate)

        // render
        updateRenderingSystem(in: view)
    }

    public func mtkView(_: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(size.width) / Float(size.height)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(size.width), Float(size.height))
        renderInfo.viewPort = viewPortSize
    }

    func handleSceneInput() {
        if gameMode == true {
            return
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }

        if inputSystem.keyState.leftMousePressed {
            setOrbitOffset(entityId: findSceneCamera(), uTargetOffset: length(cameraComponent.localPosition))
        }

        if inputSystem.mouseActive {
            orbitAround(entityId: findSceneCamera(), uPosition: inputSystem.panDelta * 0.005)
        }

        let input = (w: inputSystem.keyState.wPressed, a: inputSystem.keyState.aPressed, s: inputSystem.keyState.sPressed, d: inputSystem.keyState.dPressed, q: inputSystem.keyState.qPressed, e: inputSystem.keyState.ePressed)

        moveCameraWithInput(entityId: findSceneCamera(), input: input, speed: 1, deltaTime: 0.1)
    }
}
