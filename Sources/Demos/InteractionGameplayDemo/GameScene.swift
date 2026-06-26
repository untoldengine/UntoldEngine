//
//  GameScene.swift
//  InteractionGameplayDemo
//

#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    final class GameScene: @unchecked Sendable {
        private enum Constants {
            static let cameraEye = simd_float3(0.0, 7.0, 15.0)
            static let cameraTarget = simd_float3(0.0, 0.0, 0.0)
            static let playerStart = simd_float3(0.0, 0.0, 0.0)
            static let ballLocalOffset = simd_float3(0.0, 0.6, 1.0)
            static let maxPlayerSpeed: Float = 2.0
            static let turnSpeed: Float = 5.0
            static let ballRollDegreesPerSecond: Float = 240.0
        }

        private var stadium: EntityID?
        private var redPlayer: EntityID?
        private var ball: EntityID?
        private var startMoving = false
        private var currentAnimation = "idle"
        private var ballAttached = false

        init() {
            configureEngine()
            createCamera()
            createLight()
            loadScene()
        }

        func update(deltaTime: Float) {
            if gameMode == false { return }
            if isSceneReady() == false { return }
            guard let redPlayer else { return }

            if startMoving {
                playAnimationIfNeeded("running")
                pausePhysicsComponent(entityId: redPlayer, isPaused: false)
            } else {
                playAnimationIfNeeded("idle")
                pausePhysicsComponent(entityId: redPlayer, isPaused: true)
                return
            }

            let targetPosition = movementTarget(from: getPosition(entityId: redPlayer))
            steerSeek(
                entityId: redPlayer,
                targetPosition: targetPosition,
                maxSpeed: Constants.maxPlayerSpeed,
                deltaTime: deltaTime,
                turnSpeed: Constants.turnSpeed
            )

            if let ball {
                rotateBy(
                    entityId: ball,
                    angle: Constants.ballRollDegreesPerSecond * deltaTime,
                    axis: getRightAxisVector(entityId: ball)
                )
            }
        }

        func handleInput() {
            if gameMode == false { return }
            if isSceneReady() == false { return }

            let input = InputSystem.shared.keyState
            startMoving = input.wPressed || input.aPressed || input.sPressed || input.dPressed
        }

        private func configureEngine() {
            gameMode = true
            setSceneReady(false)
            setEngine(.assetBasePath(Self.resourcesURL()))
            setRendering(.postProcessing(.enabled))
            setRendering(.antiAliasing(.fxaa))
            setRendering(.environment(.ibl(true)))
            setRendering(.environment(.visible(false)))
            InputSystem.shared.registerKeyboardEvents()
        }

        private static func resourcesURL() -> URL {
            let sourceURL = URL(fileURLWithPath: #filePath)
            let repoRoot = sourceURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return repoRoot
                .appendingPathComponent("Tests")
                .appendingPathComponent("UntoldEngineRenderTests")
                .appendingPathComponent("Resources")
        }

        private func createCamera() {
            let camera = createEntity()
            setEntityName(entityId: camera, name: "Gameplay Camera")
            createGameCamera(entityId: camera)
            cameraLookAt(
                entityId: camera,
                eye: Constants.cameraEye,
                target: Constants.cameraTarget,
                up: simd_float3(0.0, 1.0, 0.0)
            )
            setCamera(.active(camera))
        }

        private func createLight() {
            let sun = createEntity()
            setEntityName(entityId: sun, name: "Sun")
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, angle: -55.0, axis: simd_float3(1.0, 0.0, 0.0))
            setLight(entityId: sun, .color(simd_float3(1.0, 0.94, 0.86)))
            setLight(entityId: sun, .intensity(1.6))
            setLight(entityId: sun, .directional(.active))
        }

        private func loadScene() {
            loadStadium { [weak self] entity, success in
                self?.stadium = entity
                if success == false {
                    Logger.log(message: "Failed to load stadium")
                }
            }

            loadPlayer { [weak self] entity, success in
                self?.redPlayer = entity
                self?.attachBallToPlayerIfReady()
                setSceneReady(success)
            }

            loadBall { [weak self] entity, success in
                self?.ball = entity
                self?.attachBallToPlayerIfReady()
                if success == false {
                    Logger.log(message: "Failed to load ball")
                }
            }
        }

        private func loadStadium(completion: @escaping @Sendable (EntityID?, Bool) -> Void) {
            let entity = createEntity()
            setEntityName(entityId: entity, name: "Stadium")
            setEntityMeshAsync(entityId: entity, filename: "stadium", withExtension: "untold") { success in
                guard success else {
                    completion(nil, false)
                    return
                }

                rotateTo(entityId: entity, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
                completion(entity, true)
            }
        }

        private func loadPlayer(completion: @escaping @Sendable (EntityID?, Bool) -> Void) {
            let entity = createEntity()
            setEntityName(entityId: entity, name: "Red Player")
            setEntityMeshAsync(entityId: entity, filename: "redplayer", withExtension: "untold") { success in
                guard success else {
                    completion(nil, false)
                    return
                }

                translateTo(entityId: entity, position: Constants.playerStart)
                setEntityAnimations(entityId: entity, filename: "running", withExtension: "untold", name: "running")
                setEntityAnimations(entityId: entity, filename: "idle", withExtension: "untold", name: "idle")
                changeAnimation(entityId: entity, name: "idle")
                setEntityKinetics(entityId: entity)
                setGravityScale(entityId: entity, gravityScale: 0.0)
                setLinearDragCoefficient(entityId: entity, coefficients: simd_float2(1.5, 0.2))
                pausePhysicsComponent(entityId: entity, isPaused: true)
                completion(entity, true)
            }
        }

        private func loadBall(completion: @escaping @Sendable (EntityID?, Bool) -> Void) {
            let entity = createEntity()
            setEntityName(entityId: entity, name: "Ball")
            setEntityMeshAsync(entityId: entity, filename: "ball", withExtension: "untold") { success in
                guard success else {
                    completion(nil, false)
                    return
                }

                translateTo(entityId: entity, position: Constants.ballLocalOffset)
                completion(entity, true)
            }
        }

        private func attachBallToPlayerIfReady() {
            guard ballAttached == false, let ball, let redPlayer else { return }
            setParent(childId: ball, parentId: redPlayer)
            ballAttached = true
        }

        private func movementTarget(from currentPosition: simd_float3) -> simd_float3 {
            let input = InputSystem.shared.keyState
            var targetPosition = currentPosition

            if input.wPressed { targetPosition.z += 1.0 }
            if input.sPressed { targetPosition.z -= 1.0 }
            if input.aPressed { targetPosition.x -= 1.0 }
            if input.dPressed { targetPosition.x += 1.0 }

            return targetPosition
        }

        private func playAnimationIfNeeded(_ name: String) {
            guard let redPlayer, currentAnimation != name else { return }
            currentAnimation = name
            changeAnimation(entityId: redPlayer, name: name)
        }
    }
#endif
