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
            setSceneReady(false)

            // Make sure to convert your usdz files to .untold format as explained in docs/API/UsingTheExporter

            // Uncomment to render a simple mesh.
            /*
             let entity = createEntity()
             setEntityMeshAsync(entityId: entity, filename: "/path/to/file", withExtension: "untold") { success in
                 setEntityName(entityId: entity, name: "redplayer")
                 if success {
                     loadSceneAuthored(filename: "/path/to/file", withExtension: "untold")
                 }
                 setSceneReady(success)
             }
             */

            // Uncomment to render a streamed scene
        }

        private func configureEngineSystems() {
            gameMode = true
            AnimationSystem.shared.isEnabled = true
            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
            bypassPostProcessing = false
            setSpatialDebug(.lodLevels(false))
        }

        private func setupDefaultSceneObjects() {
            let camera = createEntity()
            setEntityName(entityId: camera, name: "Main Camera")
            createGameCamera(entityId: camera)
            setCamera(.active(camera))
            setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)

//            let light = createEntity()
//            setEntityName(entityId: light, name: "Directional Light")
            // createDirLight(entityId: light)
        }

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
