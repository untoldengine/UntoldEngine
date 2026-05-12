//
//  GameScene.swift
//

#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    // MARK: - GameScene

    /// Demo-facing bridge over the core engine API.
    ///
    /// Core Engine API map used by this demo:
    /// - Entity lifecycle: `createEntity`, `setEntityName`, `destroyAllEntities`
    /// - Camera/input: `createGameCamera`, `findGameCamera`, `moveCameraWithInput`, `orbitCameraAround`
    /// - Asset loading: `setEntityMeshAsync` (always-resident), `setEntityStreamScene` (streamable scene)
    /// - Performance features: `setEntityStaticBatchComponent`, `enableBatching`, `generateBatches`, `enableStreaming`
    /// - Debug overlays: `setLODLevelDebug`, `setTextureStreamingTierDebug`, `setOctreeLeafBoundsDebug`
    final class GameScene: @unchecked Sendable {
        private enum LoadedContent {
            case none
            case mesh(EntityID)
            case tiledScene(EntityID)
        }

        private enum CameraBehavior {
            case flyOrbit
            case originOrbit
        }

        private enum Constants {
            static let orbitTargetOffset: Float = 25.0
            static let cameraMoveSpeed: Float = 1.0
            static let cameraInputDeltaTime: Float = 0.1
            static let streamingPriority: Int = 10
            static let citySceneID = "city"
            static let f1CarSceneID = "f1car"
            static let airplaneSceneID = "airplane"
            static let porsche964SceneID = "porsche964"
            static let cityCameraEye = simd_float3(0.00, 18.35, 73.56)
            static let f1CarCameraEye = simd_float3(0.0, 2.0, 6.0)
            static let airplaneCameraEye = simd_float3(0.0, 2.0, 3.0)
            static let porsche964CameraEye = simd_float3(0.0, 7.0, 15.0)
            static let worldOrigin = simd_float3(0.0, 0.0, 0.0)
        }

        private(set) var loadedEntity: EntityID?
        private var loadedContent: LoadedContent = .none
        private var cameraBehavior: CameraBehavior = .flyOrbit
        private var wasRightMousePressed: Bool = false
        private var wasScrolling: Bool = false
        var suppressCameraInput: Bool = false

        init() {
            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
            bypassPostProcessing = false
            setupDefaultSceneObjects()
        }
    }

    // MARK: - Scene Setup

    fileprivate extension GameScene {
        func setupDefaultSceneObjects() {
            let gameCamera = createEntity()
            setEntityName(entityId: gameCamera, name: "Main Camera")
            createGameCamera(entityId: gameCamera)

            let light = createEntity()
            setEntityName(entityId: light, name: "Directional Light")
            createDirLight(entityId: light)

            CameraSystem.shared.activeCamera = gameCamera

            applyIBL = true
            renderEnvironment = false
        }
    }

    // MARK: - Asset Loading

    extension GameScene {
        /// Loads a USDZ file as an always-resident asset, replacing whatever was previously loaded.
        /// The previously loaded entity is destroyed; the scene camera and light are preserved.
        func loadFile(path: String, completion: @escaping @Sendable (Bool) -> Void) {
            prepareForMeshLoad { [weak self] in
                guard let self else { return }

                let entity = createEntity()
                setEntityName(entityId: entity, name: path)

                setEntityMeshAsync(entityId: entity, filename: path, withExtension: "untold") { [weak self] success in
                    guard let self else { return }
                    loadedEntity = success ? entity : nil
                    loadedContent = success ? .mesh(entity) : .none
                    let camera = findGameCamera()
                    CameraSystem.shared.activeCamera = camera
                    cameraBehavior = .flyOrbit
                    setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
                    renderEnvironment = false
                    completion(success)
                }
            }
        }

        /// Loads a tiled scene from a local or remote manifest URL.
        func loadTileScene(sceneID: String, url: URL, completion: @escaping @Sendable (Bool) -> Void) {
            // Destroy any previously loaded tiled scene before registering a new one.
            if case let .tiledScene(oldRoot) = loadedContent {
                destroyEntity(entityId: oldRoot)
                loadedContent = .none
            }

            clearSceneBatches()
            GeometryStreamingSystem.shared.enabled = true

            let sceneRoot = createEntity()
            setEntityName(entityId: sceneRoot, name: sceneID)

            setEntityStreamScene(entityId: sceneRoot, url: url) { [weak self] success in
                guard let self else { return }
                if success {
                    loadedEntity = nil
                    loadedContent = .tiledScene(sceneRoot)
                    cameraBehavior = Self.cameraBehavior(for: sceneID)
                    Self.applyCameraEye(for: sceneID)
                    renderEnvironment = Self.shouldRenderEnvironment(for: sceneID)
                }
                completion(success)
            }
        }

        private func prepareForMeshLoad(completion: @escaping () -> Void) {
            clearSceneBatches()
            GeometryStreamingSystem.shared.enabled = false

            switch loadedContent {
            case let .mesh(entity):
                destroyEntity(entityId: entity)
                loadedEntity = nil
                loadedContent = .none
                completion()
            case let .tiledScene(rootEntity):
                destroyEntity(entityId: rootEntity)
                loadedEntity = nil
                loadedContent = .none
                completion()
            case .none:
                loadedEntity = nil
                completion()
            }
        }

        private static func applyCameraEye(for sceneID: String) {
            let camera = findGameCamera()
            let eye: simd_float3
            let target: simd_float3

            switch cameraBehavior(for: sceneID) {
            case .originOrbit:
                eye = cameraEye(for: sceneID)
                target = Constants.worldOrigin
            case .flyOrbit:
                eye = sceneID == Constants.citySceneID ? Constants.cityCameraEye : cameraDefaultEye
                target = cameraTargetDefault
            }

            cameraLookAt(entityId: camera, eye: eye, target: target, up: cameraUpDefault)
            CameraSystem.shared.activeCamera = camera
            if cameraBehavior(for: sceneID) == .originOrbit {
                setOriginOrbitTarget(entityId: camera)
            } else {
                setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
            }
        }

        private static func shouldRenderEnvironment(for sceneID: String) -> Bool {
            switch sceneID {
            case Constants.f1CarSceneID, Constants.airplaneSceneID, Constants.porsche964SceneID:
                true
            default:
                false
            }
        }

        private static func cameraBehavior(for sceneID: String) -> CameraBehavior {
            switch sceneID {
            case Constants.f1CarSceneID, Constants.airplaneSceneID, Constants.porsche964SceneID:
                .originOrbit
            default:
                .flyOrbit
            }
        }

        private static func cameraEye(for sceneID: String) -> simd_float3 {
            switch sceneID {
            case Constants.f1CarSceneID:
                Constants.f1CarCameraEye
            case Constants.airplaneSceneID:
                Constants.airplaneCameraEye
            case Constants.porsche964SceneID:
                Constants.porsche964CameraEye
            case Constants.citySceneID:
                Constants.cityCameraEye
            default:
                cameraDefaultEye
            }
        }
    }

    // MARK: - Performance Features

    extension GameScene {
        /// Marks the loaded entity as a static batch and generates batches,
        /// or disables the batching system when turned off.
        func setBatching(_ enabled: Bool) {
            guard let entity = loadedEntity else { return }
            if enabled {
                setEntityStaticBatchComponent(entityId: entity)
                enableBatching(true)
                generateBatches()
            } else {
                enableBatching(false)
            }
        }

        /// Enables or disables the geometry streaming system.
        /// Streaming radii are declared in the scene manifest; this is a runtime on/off toggle only.
        func setStreaming(_ enabled: Bool, streamingRadius _: Float, unloadRadius _: Float) {
            GeometryStreamingSystem.shared.enabled = enabled
        }
    }

    // MARK: - Debug Views

    extension GameScene {
        func setColorGrading(enabled: Bool, exposure: Float, brightness: Float, contrast: Float, saturation: Float) {
            PostFX.enableColorGrading(enabled)
            ColorGradingParams.shared.exposure = exposure
            ColorGradingParams.shared.brightness = brightness
            ColorGradingParams.shared.contrast = contrast
            ColorGradingParams.shared.saturation = saturation
        }

        func setSSAO(enabled: Bool, radius: Float, bias: Float, intensity: Float) {
            SSAO.setEnabled(enabled)
            SSAO.setRadius(radius)
            SSAO.setBias(bias)
            SSAO.setIntensity(intensity)
        }

        /// Toggles the per-entity LOD level colour overlay.
        func setLodDebug(_ enabled: Bool) {
            setLODLevelDebug(enabled: enabled)
        }

        /// Toggles the texture streaming tier colour overlay.
        func setStreamingTierDebug(_ enabled: Bool) {
            setTextureStreamingTierDebug(enabled: enabled)
        }

        /// Selects the renderer debug output.
        func setRenderDebugView(_ mode: RenderDebugViewMode) {
            if mode == .ssaoBlurred, SSAO.isEnabled() == false {
                SSAO.setEnabled(true)
            }
            renderDebugViewMode = mode
        }

        /// Draws (or hides) the octree leaf-node bounds debug overlay.
        func setSpatialDebug(
            enabled: Bool,
            occupiedOnly: Bool,
            colorMode: SpatialDebugLeafColorMode
        ) {
            if enabled {
                setOctreeLeafBoundsDebug(
                    enabled: true,
                    maxLeafNodeCount: 0,
                    occupiedOnly: occupiedOnly,
                    colorMode: colorMode
                )
            } else {
                disableSpatialDebugVisualization()
            }
        }
    }

    // MARK: - Frame Loop

    extension GameScene {
        func update(deltaTime _: Float) {
            if gameMode == false { return }
        }

        func handleInput() {
            if gameMode == false { return }
            let input = InputSystem.shared
            let camera = findGameCamera()

            // if cameraBehavior == .flyOrbit {
            moveCameraWithInput(
                entityId: camera,
                input: (
                    w: input.keyState.wPressed,
                    a: input.keyState.aPressed,
                    s: input.keyState.sPressed,
                    d: input.keyState.dPressed,
                    q: input.keyState.qPressed,
                    e: input.keyState.ePressed
                ),
                speed: Constants.cameraMoveSpeed,
                deltaTime: Constants.cameraInputDeltaTime
            )
            // }

            if input.keyState.rightMousePressed, !suppressCameraInput {
                if !wasRightMousePressed {
                    resetOrbitTarget(entityId: camera)
                }
                if input.keyState.shiftPressed {
                    rotateCamera(
                        entityId: camera,
                        pitch: 0,
                        yaw: input.mouseDeltaX,
                        sensitivity: -0.01
                    )
                } else {
                    var dx = input.mouseDeltaX
                    var dy = input.mouseDeltaY
                    if abs(dx) < abs(dy) { dx = 0 } else { dy = 0 }
                    orbitCameraAround(entityId: camera, uDelta: simd_float2(dx, dy))
                }
            }
            wasRightMousePressed = input.keyState.rightMousePressed

            // Two-finger trackpad drag fires scrollWheel events — support it as an
            // alternative orbit (and shift+scroll for yaw) so users don't need
            // right-click drag. resetOrbitTarget fires only on the first scroll
            // frame, matching the right-mouse-press behaviour above.
            let scroll = input.scrollDelta
            let isScrolling = (scroll.x != 0 || scroll.y != 0) && !input.keyState.rightMousePressed && !suppressCameraInput
            if isScrolling {
                if !wasScrolling {
                    resetOrbitTarget(entityId: camera)
                }
                if input.keyState.shiftPressed {
                    rotateCamera(entityId: camera, pitch: 0, yaw: scroll.x, sensitivity: -0.01)
                } else {
                    orbitCameraAround(entityId: camera, uDelta: scroll)
                }
            }
            wasScrolling = isScrolling
            input.scrollDelta = .zero
        }

        private func resetOrbitTarget(entityId: EntityID) {
            switch cameraBehavior {
            case .flyOrbit:
                setOrbitOffset(entityId: entityId, uTargetOffset: Constants.orbitTargetOffset)
            case .originOrbit:
                Self.setTranslatedOriginOrbitTarget(entityId: entityId)
            }
        }

        private static func setOriginOrbitTarget(entityId: EntityID) {
            let eye = getCameraPosition(entityId: entityId)
            let radius = simd_length(eye - Constants.worldOrigin)
            guard radius > 0.001 else { return }

            cameraLookAt(entityId: entityId, eye: eye, target: Constants.worldOrigin, up: cameraUpDefault)
            setOrbitOffset(entityId: entityId, uTargetOffset: radius)
        }

        private static func setTranslatedOriginOrbitTarget(entityId: EntityID) {
            let eye = getCameraPosition(entityId: entityId)
            let radius = simd_length(eye - Constants.worldOrigin)
            guard radius > 0.001 else { return }

            setOrbitOffset(entityId: entityId, uTargetOffset: radius)
        }
    }
#endif
