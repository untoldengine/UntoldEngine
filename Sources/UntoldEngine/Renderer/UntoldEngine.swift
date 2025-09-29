
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

public  protocol UntoldRendererDelegate
{
    func willDraw(in view: MTKView) -> Void
    func didDraw(in view: MTKView) -> Void
}


public class UntoldRenderer: NSObject, MTKViewDelegate {
    public let metalView: MTKView

    var gameUpdateCallback: ((_ deltaTime: Float) -> Void)?
    var handleInputCallback: (() -> Void)?
    
    private var configuration: UntoldRendererConfig
    public var delegate: UntoldRendererDelegate? = nil
        
    public init( configuration: UntoldRendererConfig? = nil ) {
        self.configuration = configuration ?? .default

        // Set the metal view from configuration or create new one
        metalView = self.configuration.metalView ?? MTKView()
        
        #if canImport(AppKit)
        Logger.addSink(LogStore.shared)
        #endif
        
        super.init()
    }

    public static func create( configuration: UntoldRendererConfig? = nil ) -> UntoldRenderer? {
        let renderer = UntoldRenderer( configuration: configuration )

        guard let device = MTLCreateSystemDefaultDevice() else {
            assertionFailure("Metal device is not available.")
            return nil
        }
        renderer.metalView.device = device
        renderer.metalView.depthStencilPixelFormat = .depth32Float
        renderer.metalView.colorPixelFormat = .bgra8Unorm_srgb
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

        return renderer
    }

    public func setupCallbacks(
        gameUpdate: @escaping (_ deltaTime: Float) -> Void,
        handleInput: @escaping () -> Void
    ) {
        gameUpdateCallback = gameUpdate
        handleInputCallback = handleInput
    }

    @MainActor
    public func initResources() {
        initBufferResources()
        
        PipelineManager.shared.initRenderPipelines( configuration.initRenderPipelineBlocks )
               
        initSizeableResources() //TODO: Find a better name function

        shadowSystem = ShadowSystem()
        
        // init ssao kernels
        initSSAOResources()

        initFrustumCulllingCompute()

        Logger.log(message: "Untold Engine Starting")
    }
    
    func initSizeableResources() {
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

    public func draw(in view: MTKView) {
        if needsFinalizeDestroys {
            needsFinalizeDestroys = false

            if hasPendingDestroys {
                finalizePendingDestroys()
                hasPendingDestroys = false
            }
        }

        if getMainCamera() == .invalid {
            handleError(.noGameCamera)
            return
        }

        // call the update call before the render
        frameCount += 1

        // Call delegate, for example the editor to support hotreload system
        delegate?.willDraw(in: view)
        
        // calculate delta time for frame
        calculateDeltaTime()
        traverseSceneGraph()
        
        // process Input - Handle user input before updating game states
        handleInputCallback?()

        AnimationSystem.shared.update(timeSinceLastUpdate)

        // TODO: Should be this moving to Physics system?
        // Fixed‐timestep physics
        physicsAccumulator += timeSinceLastUpdate
        let maxSteps = 5
        var steps = 0
        while physicsAccumulator >= fixedStep, steps < maxSteps {
            updatePhysicsSystem(deltaTime: fixedStep)
            updateCustomSystems(deltaTime: fixedStep)
            physicsAccumulator -= fixedStep
            steps += 1
        }


        // update game states and logic
        gameUpdateCallback?(timeSinceLastUpdate)

        // render
        configuration.updateRenderingSystemCallback(view)
                 
        delegate?.didDraw(in: view)
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
        }
        else if (abs(oldSize.width - size.height) < 0.1 &&
                 abs(oldSize.height - size.width) < 0.1) {
            // Init the resources again becasue the rotation of the screen
            initResources()
        }
        // TODO: We should init the resources again if they change the view size?
    }
   
}
