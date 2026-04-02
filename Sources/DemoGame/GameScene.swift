//
//  GameScene.swift
//

#if os(macOS)
    import simd
    import UntoldEngine

    // MARK: - GameScene

    /// Demo-facing bridge over the core engine API.
    ///
    /// Core Engine API map used by this demo:
    /// - Entity lifecycle: `createEntity`, `setEntityName`, `destroyAllEntities`
    /// - Camera/input: `createGameCamera`, `findGameCamera`, `moveCameraWithInput`, `orbitCameraAround`
    /// - Asset loading: `setEntityMeshAsync` (always-resident), `loadTiledScene` (streamable scene)
    /// - Performance features: `setEntityStaticBatchComponent`, `enableBatching`, `generateBatches`, `enableStreaming`
    /// - Debug overlays: `setLODLevelDebug`, `setTextureStreamingTierDebug`, `setOctreeLeafBoundsDebug`
    final class GameScene {
        private enum Constants {
            static let orbitTargetOffset: Float = 25.0
            static let cameraMoveSpeed: Float = 1.0
            static let cameraInputDeltaTime: Float = 0.1
            static let streamingPriority: Int = 10
            static let usdzExtension = "usdz"
        }

        private(set) var loadedEntity: EntityID?
        private var wasRightMousePressed: Bool = false

        init() {
            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
            bypassPostProcessing = true
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
        }
    }

    // MARK: - Asset Loading

    extension GameScene {
        /// Loads a USDZ file as an always-resident asset, replacing whatever was previously loaded.
        /// The previously loaded entity is destroyed; the scene camera and light are preserved.
        func loadFile(path: String, completion: @escaping (Bool) -> Void) {
            clearSceneBatches()

            if let prev = loadedEntity {
                destroyEntity(entityId: prev)
            }
            loadedEntity = nil

            let entity = createEntity()
            setEntityName(entityId: entity, name: path)

            setEntityMeshAsync(entityId: entity, filename: path, withExtension: Constants.usdzExtension) { [weak self] success in
                guard let self else { return }
                loadedEntity = success ? entity : nil
                let camera = findGameCamera()
                setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
                completion(success)
            }
        }

        /// Loads a tiled scene from a manifest JSON.
        /// `manifestPath` is an absolute path (without extension) — LoadingSystem
        /// resolves it directly so no bundle search is needed when using the file picker.
        func loadTileScene(manifestPath: String, completion: @escaping (Bool) -> Void) {
            clearSceneBatches()
            loadedEntity = nil
            GeometryStreamingSystem.shared.enabled = true

            loadTiledScene(manifest: manifestPath, withExtension: "json") { success in
                completion(success)
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

            if input.keyState.rightMousePressed {
                if !wasRightMousePressed {
                    setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
                }
                var dx = input.mouseDeltaX
                var dy = input.mouseDeltaY
                if abs(dx) < abs(dy) { dx = 0 } else { dy = 0 }
                orbitCameraAround(entityId: camera, uDelta: simd_float2(dx, dy))
            }
            wasRightMousePressed = input.keyState.rightMousePressed
        }
    }
#endif
