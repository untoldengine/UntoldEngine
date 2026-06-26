//
//  GameScene.swift
//  StarterDemo
//

#if os(macOS)
    import Foundation
    import simd
    import SwiftUI
    import UntoldEngine

    final class GameScene {
        private enum Constants {
            static let cameraMoveSpeed: Float = 4.0
            static let orbitTargetOffset: Float = 5.0
            static let cameraStart = simd_float3(0.0, 2.0, 6.0)
            static let worldOrigin = simd_float3(0.0, 0.0, 0.0)
        }

        private var cube: EntityID?
        private var wasRightMousePressed = false

        init() {
            configureEngine()
            createCamera()
            createLight()
            createStarterObject()
            setSceneReady(false)
        }

        func update(deltaTime: Float) {
            guard let cube, gameMode else { return }

            rotateBy(
                entityId: cube,
                angle: 25.0 * deltaTime,
                axis: simd_float3(0.0, 1.0, 0.0)
            )
            
            setSceneReady(true)
        }

        func handleInput() {
            guard gameMode, isSceneReady() else { return }
            guard let camera = CameraSystem.shared.activeCamera else { return }

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
                deltaTime: 1.0 / 60.0
            )

            if input.keyState.rightMousePressed {
                if !wasRightMousePressed {
                    setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
                }
                orbitCameraAround(
                    entityId: camera,
                    uDelta: simd_float2(input.mouseDeltaX, input.mouseDeltaY)
                )
            }

            wasRightMousePressed = input.keyState.rightMousePressed
        }

        private func configureEngine() {
            gameMode = true
            setSceneReady(false)
            setRendering(.postProcessing(.enabled))
            setRendering(.antiAliasing(.fxaa))
            setRendering(.environment(.ibl(true)))
            setRendering(.environment(.visible(false)))

            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
        }

        private func createCamera() {
            let camera = createEntity()
            setEntityName(entityId: camera, name: "Main Camera")
            createGameCamera(entityId: camera)
            cameraLookAt(
                entityId: camera,
                eye: Constants.cameraStart,
                target: Constants.worldOrigin,
                up: simd_float3(0.0, 1.0, 0.0)
            )
            setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
            setCamera(.active(camera))
        }

        private func createLight() {
            let sun = createEntity()
            setEntityName(entityId: sun, name: "Key Light")
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, angle: -45.0, axis: simd_float3(1.0, 0.0, 0.0))
            setLight(entityId: sun, .color(simd_float3(1.0, 0.92, 0.82)))
            setLight(entityId: sun, .intensity(1.4))
            setLight(entityId: sun, .directional(.active))
        }

        private func createStarterObject() {
            let entity = createEntity()
            setEntityName(entityId: entity, name: "Starter Cube")
            setEntityMeshDirect(
                entityId: entity,
                meshes: BasicPrimitives.createCube(extent: 1.25),
                assetName: "starter_cube"
            )
            translateTo(entityId: entity, position: Constants.worldOrigin)
            updateMaterialColor(entityId: entity, color: Color(red: 0.95, green: 0.42, blue: 0.18))
            cube = entity
            setSceneReady(true)
        }

        // Use this instead of createStarterObject() when you add your own exported asset:
        //
        // private func loadUntoldAsset() {
        //     let entity = createEntity()
        //     setEntityName(entityId: entity, name: "My Model")
        //     setEntityMeshAsync(entityId: entity, filename: "my_model", withExtension: "untold") { success in
        //         guard success else {
        //             setSceneReady(false)
        //             return
        //         }
        //         translateTo(entityId: entity, position: .zero)
        //         setSceneReady(true)
        //     }
        // }
    }
#endif
