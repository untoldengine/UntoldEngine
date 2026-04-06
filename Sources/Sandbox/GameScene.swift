//
//  GameScene.swift
//

#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    final class GameScene {
        private enum Constants {
            static let orbitTargetOffset: Float = 8.0
            static let cameraMoveSpeed: Float = 1.0
            static let cameraInputDeltaTime: Float = 0.1
        }

        private(set) var loadedEntity: EntityID?
        private var wasRightMousePressed: Bool = false

        init() {
            configureEngineSystems()
            setupDefaultSceneObjects()
            setSceneReady(true)

            // Add ad-hoc sandbox loads here when testing engine APIs.
            // Example:
            // loadMesh(named: "/YourAsset", withExtension: "untold") { success in
            //    setSceneReady(success)
            // }

            // loadScene(from: URL(string: "https://d8pyi1c08k1w.cloudfront.net/dungeon3/dungeon3.json")!) { success in
            //     setSceneReady(success)
            // }
        }

        private func configureEngineSystems() {
            gameMode = true
            AnimationSystem.shared.isEnabled = true
            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
            bypassPostProcessing = false
        }

        private func setupDefaultSceneObjects() {
            let camera = createEntity()
            setEntityName(entityId: camera, name: "Main Camera")
            createGameCamera(entityId: camera)
            CameraSystem.shared.activeCamera = camera
            setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)

            let light = createEntity()
            setEntityName(entityId: light, name: "Directional Light")
            createDirLight(entityId: light)
        }
    }

    extension GameScene {
        func loadMesh(
            named filename: String,
            withExtension pathExtension: String = "untold",
            completion: @escaping @Sendable (Bool) -> Void
        ) {
            setSceneReady(false)

            if let loadedEntity {
                destroyEntity(entityId: loadedEntity)
                self.loadedEntity = nil
            }

            let entity = createEntity()
            setEntityName(entityId: entity, name: filename)

            setEntityMeshAsync(entityId: entity, filename: filename, withExtension: pathExtension) { [weak self] success in
                guard let self else { return }
                loadedEntity = success ? entity : nil
                setSceneReady(success)
                completion(success)
            }
        }

        func loadScene(from url: URL, completion: @escaping @Sendable (Bool) -> Void) {
            setSceneReady(false)

            if let loadedEntity {
                destroyEntity(entityId: loadedEntity)
                self.loadedEntity = nil
            }

            GeometryStreamingSystem.shared.enabled = true
            loadTiledScene(url: url) { success in
                setSceneReady(success)
                completion(success)
            }
        }
    }

    extension GameScene {
        func update(deltaTime _: Float) {
            if gameMode == false { return }
        }

        func handleInput() {
            if gameMode == false { return }
            if isSceneReady() == false { return }

            guard let camera = CameraSystem.shared.activeCamera else {
                Logger.log(message: "No main camera found")
                return
            }

            let input = InputSystem.shared

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
