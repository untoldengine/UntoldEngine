
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
        #if canImport(AppKit)
        Logger.addSink(LogStore.shared)
        #endif
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

        // init ssao kernels
        initSSAOResources()

        loadLightDebugMeshes()

        initFrustumCulllingCompute()

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

            updateAnimationSystem(deltaTime: timeSinceLastUpdate)

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

        } else {
            handleSceneInput() // if scene mode
        }

        // update game states and logic
        gameUpdateCallback?(timeSinceLastUpdate)

        // render
        updateRenderingSystem(in: view)
    }

    public func mtkView(_ mtkView: MTKView, drawableSizeWillChange _: CGSize) {
        let mtkViewSize = mtkView.bounds.size
        let aspect = Float(mtkViewSize.width) / Float(mtkViewSize.height)
        let projectionMatrix = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far
        )

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(mtkViewSize.width), Float(mtkViewSize.height))
        renderInfo.viewPort = viewPortSize
    }

    func handleSceneInput() {
        #if os(macOS)
        // Game mode blocks editor + camera input entirely
        if gameMode { return }

        // Always allow camera WASDQE input, regardless of editor state
        let input = (
            w: inputSystem.keyState.wPressed,
            a: inputSystem.keyState.aPressed,
            s: inputSystem.keyState.sPressed,
            d: inputSystem.keyState.dPressed,
            q: inputSystem.keyState.qPressed,
            e: inputSystem.keyState.ePressed
        )
        moveCameraWithInput(entityId: findSceneCamera(), input: input, speed: 1, deltaTime: 0.1)

        // Editor is optional; only gate editor logic with this flag
        let isEditorEnabled = editorController?.isEnabled ?? (editorController != nil)

        // Only proceed into gizmo/editor handling if:
        //  - editor exists/enabled
        //  - there is an active entity
        //  - user intent suggests editing (Shift or gizmo is active)
        guard isEditorEnabled,
              activeEntity != .invalid,
              (inputSystem.keyState.shiftPressed || gizmoActive)
        else {
            return
        }

        // From here on, we can safely touch editor-only parts
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: findSceneCamera()) else {
            handleError(.noActiveCamera)
            return
        }
        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: activeEntity) else {
            handleError(.noLocalTransformComponent)
            return
        }

        // Convenience to avoid repeating the optional chaining
        @inline(__always)
        func refreshInspector() { editorController?.refreshInspector() }

        switch (editorController!.activeMode, editorController!.activeAxis) {
        // MARK: - Translate
        case (.translate, .x) where inputSystem.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let amt = computeAxisTranslationGizmo(
                axisWorldDir: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort
            )
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        case (.translate, .y) where inputSystem.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        case (.translate, .z) where inputSystem.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            let t = axis * amt
            translateBy(entityId: activeEntity, position: t)
            translateBy(entityId: parentEntityIdGizmo, position: t)
            refreshInspector()

        // MARK: - Rotate
        case (.rotate, .x) where inputSystem.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY),
                currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.x -= angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        case (.rotate, .y) where inputSystem.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY),
                currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.y += angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        case (.rotate, .z) where inputSystem.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let angle = computeRotationAngleFromGizmo(
                axis: axis,
                gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                lastMousePos: simd_float2(inputSystem.lastMouseX, inputSystem.lastMouseY),
                currentMousePos: simd_float2(inputSystem.mouseX, inputSystem.mouseY),
                viewMatrix: cameraComponent.viewSpace,
                projectionMatrix: renderInfo.perspectiveSpace,
                viewportSize: renderInfo.viewPort,
                sensitivity: 100.0
            )
            var r = getAxisRotations(entityId: activeEntity)
            r.z += angle * 10
            applyAxisRotations(entityId: activeEntity, axis: r)
            refreshInspector()

        // MARK: - Scale
        case (.scale, .x) where inputSystem.mouseActive:
            let axis = simd_float3(1, 0, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        case (.scale, .y) where inputSystem.mouseActive:
            let axis = simd_float3(0, 1, 0)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        case (.scale, .z) where inputSystem.mouseActive:
            let axis = simd_float3(0, 0, 1)
            let amt = computeAxisTranslationGizmo(axisWorldDir: axis,
                                                  gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                  mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                  viewMatrix: cameraComponent.viewSpace,
                                                  projectionMatrix: renderInfo.perspectiveSpace,
                                                  viewportSize: renderInfo.viewPort)
            if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
                handleLightScaleInput(projectedAmount: amt, axis: axis)
            } else {
                applyWorldSpaceScaleDelta(entityId: activeEntity, worldAxis: axis, projectedAmount: amt)
            }
            refreshInspector()

        // MARK: - Light direction (view-plane drag)
        case (.lightRotate, .none) where inputSystem.mouseActive:
            let lightDirEntity = findEntity(name: "directionHandle")

            // Choose 2D plane aligned to camera forward
            let cameraForward = -cameraComponent.zAxis
            let absF = simd_abs(cameraForward)
            let (axis1, axis2): (simd_float3, simd_float3) = {
                if absF.x > absF.y && absF.x > absF.z { return (simd_float3(0,1,0), simd_float3(0,0,1)) } // YZ
                if absF.y > absF.x && absF.y > absF.z { return (simd_float3(1,0,0), simd_float3(0,0,1)) } // XZ
                return (simd_float3(1,0,0), simd_float3(0,1,0))                                          // XY
            }()

            let p1 = computeAxisTranslationGizmo(axisWorldDir: axis1,
                                                 gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                 mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                 viewMatrix: cameraComponent.viewSpace,
                                                 projectionMatrix: renderInfo.perspectiveSpace,
                                                 viewportSize: renderInfo.viewPort)

            let p2 = computeAxisTranslationGizmo(axisWorldDir: axis2,
                                                 gizmoWorldPosition: getLocalPosition(entityId: activeEntity),
                                                 mouseDelta: simd_float2(inputSystem.mouseDeltaX, inputSystem.mouseDeltaY),
                                                 viewMatrix: cameraComponent.viewSpace,
                                                 projectionMatrix: renderInfo.perspectiveSpace,
                                                 viewportSize: renderInfo.viewPort)

            let t = axis1 * p1 + axis2 * p2
            translateBy(entityId: lightDirEntity!, position: t)

            let lightPos = getPosition(entityId: parentEntityIdGizmo)
            let gizmoPos = getPosition(entityId: lightDirEntity!)
            let zAxis = simd_normalize(gizmoPos - lightPos) * -1.0

            let worldUp = simd_float3(0, 1, 0)
            var xAxis = simd_normalize(simd_cross(worldUp, zAxis))
            if simd_length(xAxis) < 0.001 {
                xAxis = simd_normalize(simd_cross(simd_float3(1, 0, 0), zAxis))
            }
            let yAxis = simd_normalize(simd_cross(zAxis, xAxis))
            let rotM = simd_float3x3(columns: (xAxis, yAxis, zAxis))
            localTransformComponent.rotation = transformMatrix3nToQuaternion(m: rotM)

        default:
            break
        }
#endif
    }

   
}
