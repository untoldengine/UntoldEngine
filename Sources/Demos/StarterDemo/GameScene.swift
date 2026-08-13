//
//  GameScene.swift
//  StarterDemo
//

#if os(macOS)
    import DemoUtils
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
            configureDemoEngine(registerKeyboard: true)
            makeDemoCamera(name: "Main Camera", eye: Constants.cameraStart, target: Constants.worldOrigin, orbitOffset: Constants.orbitTargetOffset)
            makeDemoSunLight(name: "Key Light", pitch: -45.0, color: simd_float3(1.0, 0.92, 0.82), intensity: 1.4)
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
