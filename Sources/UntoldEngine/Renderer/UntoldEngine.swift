
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
        setEntityName(entityId: gameCamera, name: "Main Camera")
        createGameCamera(entityId: gameCamera)

        let light = createEntity()
        setEntityName(entityId: light, name: "Directional Light")
        createDirLight(entityId: light)
        // initialize ray vs model pipeline
        initRayPickerCompute()

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
            updateShadersAndPipeline()

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

        let input = (w: inputSystem.keyState.wPressed, a: inputSystem.keyState.aPressed, s: inputSystem.keyState.sPressed, d: inputSystem.keyState.dPressed, q: inputSystem.keyState.qPressed, e: inputSystem.keyState.ePressed)

        moveCameraWithInput(entityId: findSceneCamera(), input: input, speed: 1, deltaTime: 0.1)

        guard let editorController else {
            return
        }

        if activeEntity == .invalid {
            return
        }

        if inputSystem.keyState.shiftPressed || gizmoActive {
            guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
                handleError(.noActiveCamera)
                return
            }
            
            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: activeEntity) else {
                handleError(.noLocalTransformComponent)
                return
            }

            switch (editorController.activeMode, editorController.activeAxis) {
            // Translate
            case (.translate, .x) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(1.0, 0.0, 0.0)

                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                let translation = simd_float3(1.0, 0.0, 0.0) * projectedAmount
                translateBy(entityId: activeEntity, position: translation)
                translateBy(entityId: parentEntityIdGizmo, position: translation)
                editorController.refreshInspector()

            case (.translate, .y) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(0.0, 1.0, 0.0)

                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                let translation = simd_float3(0.0, 1.0, 0.0) * projectedAmount

                translateBy(entityId: activeEntity, position: translation)
                translateBy(entityId: parentEntityIdGizmo, position: translation)
                editorController.refreshInspector()

            case (.translate, .z) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(0.0, 0.0, 1.0)

                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                let translation = simd_float3(0.0, 0.0, 1.0) * projectedAmount

                translateBy(entityId: activeEntity, position: translation)
                translateBy(entityId: parentEntityIdGizmo, position: translation)
                editorController.refreshInspector()

            // Orientation
            case (.rotate, .x) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(1.0, 0.0, 0.0)

                let angleDelta = computeRotationAngleFromGizmo(
                    axis: axisWorldDir, // simd_float3, e.g., (0,1,0)
                    gizmoWorldPosition: getLocalPosition(entityId: activeEntity), // simd_float3
                    lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY), // simd_float2 in screen coords
                    currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY), // simd_float2 in screen coords
                    viewMatrix: cameraComponent.viewSpace,
                    projectionMatrix: renderInfo.perspectiveSpace,
                    viewportSize: renderInfo.viewPort,
                    sensitivity: 100.0
                )

                var axisOfRotation = getAxisRotations(entityId: activeEntity)
                axisOfRotation.x -= angleDelta * 10

                applyAxisRotations(entityId: activeEntity, axis: axisOfRotation)
                editorController.refreshInspector()

            case (.rotate, .y) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(0.0, 1.0, 0.0)

                let angleDelta = computeRotationAngleFromGizmo(
                    axis: axisWorldDir,
                    gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                    lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY),
                    currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY),
                    viewMatrix: cameraComponent.viewSpace,
                    projectionMatrix: renderInfo.perspectiveSpace,
                    viewportSize: renderInfo.viewPort,
                    sensitivity: 100.0
                )

                var axisOfRotation = getAxisRotations(entityId: activeEntity)
                axisOfRotation.y += angleDelta * 10

                applyAxisRotations(entityId: activeEntity, axis: axisOfRotation)

                editorController.refreshInspector()

            case (.rotate, .z) where inputSystem.mouseActive:

                let axisWorldDir = simd_float3(0.0, 0.0, 1.0)

                let angleDelta = computeRotationAngleFromGizmo(
                    axis: axisWorldDir,
                    gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                    lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY),
                    currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY),
                    viewMatrix: cameraComponent.viewSpace,
                    projectionMatrix: renderInfo.perspectiveSpace,
                    viewportSize: renderInfo.viewPort,
                    sensitivity: 100.0
                )

                var axisOfRotation = getAxisRotations(entityId: activeEntity)
                axisOfRotation.z += angleDelta * 10

                applyAxisRotations(entityId: activeEntity, axis: axisOfRotation)
                editorController.refreshInspector()

            // scale
            case (.scale, .x) where inputSystem.mouseActive:
                let axisWorldDir = simd_float3(1.0, 0.0, 0.0)
                
                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                    handleLightScaleInput(projectedAmount: projectedAmount, axis: axisWorldDir)
                } else {
                    
                    applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axisWorldDir, projectedAmount: projectedAmount)
                    
                }
                editorController.refreshInspector()

            case (.scale, .y) where inputSystem.mouseActive:
                let axisWorldDir = simd_float3(0.0, 1.0, 0.0)
                
                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                    handleLightScaleInput(projectedAmount: projectedAmount, axis: axisWorldDir)
                } else {

                    applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axisWorldDir, projectedAmount: projectedAmount)

                }
                editorController.refreshInspector()

            case (.scale, .z) where inputSystem.mouseActive:
                let axisWorldDir = simd_float3(0.0, 0.0, 1.0)
                
                let projectedAmount = computeAxisTranslationGizmo(axisWorldDir: axisWorldDir, gizmoWorldPosition: getLocalPosition(entityId: activeEntity), mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY), viewMatrix: cameraComponent.viewSpace, projectionMatrix: renderInfo.perspectiveSpace, viewportSize: renderInfo.viewPort)

                if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                    handleLightScaleInput(projectedAmount: projectedAmount, axis: axisWorldDir)
                } else {
                    
                    applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axisWorldDir, projectedAmount: projectedAmount)

                }
                editorController.refreshInspector()
            
            // light direction
            case (.lightRotate, .none) where inputSystem.mouseActive:
                let lightDirEntity = findEntity(name: "directionHandle")
              
                // compute the view-aligned plane translation
                let cameraForward = -cameraComponent.zAxis // Assuming forward is -Z

                let absForward = simd_abs(cameraForward)

                var axis1 = simd_float3.zero
                var axis2 = simd_float3.zero

                // Determine the plane perpendicular to the dominant axis
                if absForward.x > absForward.y && absForward.x > absForward.z {
                    // Looking down X → move in YZ plane
                    axis1 = simd_float3(0, 1, 0) // Y
                    axis2 = simd_float3(0, 0, 1) // Z
                } else if absForward.y > absForward.x && absForward.y > absForward.z {
                    // Looking down Y → move in XZ plane
                    axis1 = simd_float3(1, 0, 0) // X
                    axis2 = simd_float3(0, 0, 1) // Z
                } else {
                    // Looking down Z → move in XY plane
                    axis1 = simd_float3(1, 0, 0) // X
                    axis2 = simd_float3(0, 1, 0) // Y
                }

                
                let projected1 = computeAxisTranslationGizmo(
                    axisWorldDir: axis1,
                    gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                    mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                    viewMatrix: cameraComponent.viewSpace,
                    projectionMatrix: renderInfo.perspectiveSpace,
                    viewportSize: renderInfo.viewPort)

                let projected2 = computeAxisTranslationGizmo(
                    axisWorldDir: axis2,
                    gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                    mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                    viewMatrix: cameraComponent.viewSpace,
                    projectionMatrix: renderInfo.perspectiveSpace,
                    viewportSize: renderInfo.viewPort)

                let translation = axis1 * projected1 + axis2 * projected2
                translateBy(entityId: lightDirEntity!, position: translation)

                let lightPos = getPosition(entityId: parentEntityIdGizmo)
                let gizmoPos = getPosition(entityId: lightDirEntity!)
                
                // z axis
                let zAxis = simd_normalize(gizmoPos - lightPos) * -1.0
                
                let worldUp = simd_float3(0.0,1.0,0.0)
                let xAxis = simd_normalize(simd_cross(worldUp, zAxis))
                
                // if zAxis is too aligned with worldUp, swicth to a different up vector
                var finalXAxis = xAxis
                if simd_length(xAxis) < 0.001{
                    finalXAxis = simd_normalize(simd_cross(simd_float3(1.0,0.0,0.0), zAxis))
                }
                
                // Recompute yAxis to ensure orthogonality
                let yAxis = simd_normalize(simd_cross(zAxis, finalXAxis))
                
                // construct rotation matrix
                let rotationMatrix = simd_float3x3(columns: (finalXAxis, yAxis, zAxis))
                
                let q = transformMatrix3nToQuaternion(m: rotationMatrix)
                
                localTransformComponent.rotation = q
                
                
            // default
            default:
                break
            }
        }
    }
}
