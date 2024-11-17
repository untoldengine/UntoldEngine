
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
    public var gameUpdateCallback: ((_ deltaTime: Float) -> Void)?
    public var handleInputCallback: (() -> Void)?

    public init?(_ metalView: MTKView) {
        super.init()

        renderInfo.device = metalView.device
        renderInfo.colorPixelFormat = metalView.colorPixelFormat
        renderInfo.depthPixelFormat = metalView.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(metalView.drawableSize.width), Float(metalView.drawableSize.height)
        )

        // create a command queue
        guard let queue = renderInfo.device.makeCommandQueue() else { return nil }
        renderInfo.commandQueue = queue

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
            print("Found Untold Engine metallib")
        } catch {
            print("Failed to load metallib: \(error)")
        }

        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        initBufferResources()

        initTextureResources()
        initRenderPipelines()

        initRenderPassDescriptors()
        initIBLResources()
        renderInfo.fence = renderInfo.device.makeFence()

        camera = Camera()

        //        camera.lookAt(eye: simd_float3(0.0,2.0,4.0), target: simd_float3(0.0,0.0,0.0), up: simd_float3(0.0,1.0,0.0))
        camera.lookAt(
            eye: simd_float3(0.0, 6.0, 15.0), target: simd_float3(0.0, 2.0, 0.0),
            up: simd_float3(0.0, 1.0, 0.0)
        )

        lightingSystem = LightingSystem()
        shadowSystem = ShadowSystem()

        // initRayTracingCompute()

        inputSystem.setupGestureRecognizers(view: metalView)
        inputSystem.setupEventMonitors()

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
        // call the update call before the render
        frameCount += 1

        if hotReload {
            // updateRayKernelPipeline()
            // updateShadersAndPipeline()

            hotReload = false
        }

        // calculate delta time for frame
        calculateDeltaTime()

        // process Input - Handle user input before updating game states
        if gameMode == true {
            handleInputCallback?() // if game mode
            updatePhysicsSystem(deltaTime: timeSinceLastUpdate)
            updateAnimationSystem(deltaTime: timeSinceLastUpdate)
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
        // pinch gestures
        if inputSystem.currentPinchGestureState == .changed {
            // camera.moveCameraAlongAxis(uDelta: inputSystem.pinchDelta)
        }

        // pan gestures

        if inputSystem.currentPanGestureState == .began {
            // camera.setOrbitOffset(uTargetOffset: length(camera.localPosition))
        }

        if inputSystem.currentPanGestureState == .changed {
            // camera.orbitAround(inputSystem.panDelta * 0.005)
        }

        if inputSystem.currentPanGestureState == .ended {}

        camera.rotateCamera(yaw: inputSystem.mouseDeltaX * 0.1, pitch: inputSystem.mouseDeltaY * 0.1, sensitivity: 0.1)

        let input = (w: inputSystem.keyState.wPressed, a: inputSystem.keyState.aPressed, s: inputSystem.keyState.sPressed, d: inputSystem.keyState.dPressed)

        camera.moveCameraWithInput(input: input, speed: 5, deltaTime: 0.1)
    }
}
