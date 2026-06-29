#if os(macOS)
    import DemoUtils
    import Foundation
    import simd
    import SwiftUI
    import UntoldEngine

    final class GameScene: @unchecked Sendable {
        private enum Constants {
            static let cameraEye = simd_float3(0.0, 4.5, 11.0)
            static let cameraTarget = simd_float3(0.0, 1.0, 0.0)
            static let orbitOffset: Float = 10.0
        }

        private var dirLight: EntityID?
        private var pointLight: EntityID?
        private var spotLight: EntityID?
        private var areaLight: EntityID?
        private var wasRightMousePressed = false

        init() {
            configureDemoEngine(registerMouse: true)
            makeDemoCamera(
                name: "Lighting Camera",
                eye: Constants.cameraEye,
                target: Constants.cameraTarget,
                orbitOffset: Constants.orbitOffset
            )
            buildScene()
            buildLights()
            setSceneReady(true)
        }

        func update(deltaTime _: Float) {
            if gameMode == false { return }
        }

        func handleInput() {
            if gameMode == false { return }
            guard let camera = CameraSystem.shared.activeCamera else { return }
            let input = InputSystem.shared
            if input.keyState.rightMousePressed {
                if !wasRightMousePressed {
                    setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitOffset)
                }
                orbitCameraAround(entityId: camera, uDelta: simd_float2(input.mouseDeltaX, input.mouseDeltaY))
            }
            wasRightMousePressed = input.keyState.rightMousePressed
        }

        // MARK: - Scene

        private func buildScene() {
            let floor = createEntity()
            setEntityName(entityId: floor, name: "Floor")
            setEntityMeshDirect(
                entityId: floor,
                meshes: BasicPrimitives.createPlane(width: 14.0, depth: 12.0),
                assetName: "floor"
            )
            updateMaterialColor(entityId: floor, color: Color(red: 0.55, green: 0.55, blue: 0.57))

            let wall = createEntity()
            setEntityName(entityId: wall, name: "Back Wall")
            setEntityMeshDirect(entityId: wall, meshes: BasicPrimitives.createCube(extent: 1.0), assetName: "wall")
            scaleTo(entityId: wall, scale: simd_float3(14, 8, 0.2))
            translateTo(entityId: wall, position: simd_float3(0, 4, -6))
            updateMaterialColor(entityId: wall, color: Color(red: 0.70, green: 0.70, blue: 0.72))

            spawnSphere(
                name: "Sphere Left",
                assetName: "sphere_left",
                position: simd_float3(-3.0, 0.5, -1.0),
                color: Color(red: 0.85, green: 0.22, blue: 0.16)
            )
            spawnSphere(
                name: "Sphere Center",
                assetName: "sphere_center",
                position: simd_float3(0.0, 0.5, 0.5),
                color: Color(red: 0.92, green: 0.82, blue: 0.18)
            )
            spawnSphere(
                name: "Sphere Right",
                assetName: "sphere_right",
                position: simd_float3(3.0, 0.5, -1.0),
                color: Color(red: 0.18, green: 0.52, blue: 0.90)
            )
        }

        private func spawnSphere(name: String, assetName: String, position: simd_float3, color: Color) {
            let entity = createEntity()
            setEntityName(entityId: entity, name: name)
            setEntityMeshDirect(entityId: entity, meshes: BasicPrimitives.createSphere(extent: 0.5), assetName: assetName)
            translateTo(entityId: entity, position: position)
            updateMaterialColor(entityId: entity, color: color)
        }

        // MARK: - Lights

        private func buildLights() {
            // Directional — warm sun, active by default as the scene's primary shadow caster.
            let dir = createEntity()
            setEntityName(entityId: dir, name: "Directional Light")
            createDirLight(entityId: dir)
            rotateTo(entityId: dir, angle: -50.0, axis: simd_float3(1, 0, 0))
            setLight(entityId: dir, .color(simd_float3(1.0, 0.95, 0.85)))
            setLight(entityId: dir, .intensity(1.2))
            setLight(entityId: dir, .directional(.active))
            dirLight = dir

            // Point — warm orange, right side of scene.
            let pt = createEntity()
            setEntityName(entityId: pt, name: "Point Light")
            createPointLight(entityId: pt)
            translateTo(entityId: pt, position: simd_float3(3.5, 3.5, 2.0))
            setLight(entityId: pt, .color(simd_float3(1.0, 0.55, 0.1)))
            setLight(entityId: pt, .intensity(3.0))
            setLight(entityId: pt, .point(.radius(9.0)))
            pointLight = pt

            // Spot — cool blue, angled from upper-left.
            let sp = createEntity()
            setEntityName(entityId: sp, name: "Spot Light")
            createSpotLight(entityId: sp)
            translateTo(entityId: sp, position: simd_float3(-3.5, 6.0, 1.5))
            rotateTo(entityId: sp, angle: -65.0, axis: simd_float3(1, 0, 0))
            setLight(entityId: sp, .color(simd_float3(0.3, 0.65, 1.0)))
            setLight(entityId: sp, .intensity(4.0))
            setLight(entityId: sp, .spot(.coneAngle(20.0)))
            setLight(entityId: sp, .spot(.falloff(0.8)))
            spotLight = sp

            // Area — soft purple, overhead panel.
            let ar = createEntity()
            setEntityName(entityId: ar, name: "Area Light")
            createAreaLight(entityId: ar)
            translateTo(entityId: ar, position: simd_float3(0.0, 5.5, -1.5))
            rotateTo(entityId: ar, angle: -90.0, axis: simd_float3(1, 0, 0))
            scaleTo(entityId: ar, scale: simd_float3(5, 5, 1))
            setLight(entityId: ar, .color(simd_float3(0.75, 0.5, 1.0)))
            setLight(entityId: ar, .intensity(2.0))
            setLight(entityId: ar, .area(.twoSided(false)))
            areaLight = ar
        }

        // MARK: - Light Control API

        func setDirLight(enabled: Bool, intensity: Float) {
            guard let dirLight else { return }
            setLight(entityId: dirLight, .intensity(enabled ? intensity : 0))
        }

        func setPointLight(enabled: Bool, intensity: Float) {
            guard let pointLight else { return }
            setLight(entityId: pointLight, .intensity(enabled ? intensity : 0))
        }

        func setSpotLight(enabled: Bool, intensity: Float, coneAngle: Float) {
            guard let spotLight else { return }
            setLight(entityId: spotLight, .intensity(enabled ? intensity : 0))
            if enabled {
                setLight(entityId: spotLight, .spot(.coneAngle(coneAngle)))
            }
        }

        func setAreaLight(enabled: Bool, intensity: Float) {
            guard let areaLight else { return }
            setLight(entityId: areaLight, .intensity(enabled ? intensity : 0))
        }
    }
#endif
