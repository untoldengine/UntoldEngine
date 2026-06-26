//
//  GameScene.swift
//  LargeSceneStreamingDemo
//

#if os(macOS)
    import Foundation
    import simd
    import SwiftUI
    import UntoldEngine

    final class GameScene: @unchecked Sendable {
        enum RemoteScenePreset: String, CaseIterable {
            case dungeon = "Dungeon"
            case city = "City"

            var manifestURL: URL {
                switch self {
                case .dungeon:
                    URL(string: "https://d8pyi1c08k1w.cloudfront.net/dungeon3/dungeon3.json")!
                case .city:
                    URL(string: "https://d8pyi1c08k1w.cloudfront.net/city/city.json")!
                }
            }

            var cameraEye: simd_float3 {
                switch self {
                case .dungeon: simd_float3(0.0, 4.0, 18.0)
                case .city: simd_float3(0.0, 18.35, 73.56)
                }
            }
        }

        private enum Constants {
            static let cameraMoveSpeed: Float = 9.0
            static let cameraInputDeltaTime: Float = 1.0 / 60.0
            static let orbitTargetOffset: Float = 25.0
            static let fallbackGridSize = 28
            static let fallbackSpacing: Float = 4.0
            static let worldOrigin = simd_float3(0.0, 0.0, 0.0)
        }

        var onStatusChanged: (@Sendable (String, Bool) -> Void)?

        private var streamedSceneRoot: EntityID?
        private var fallbackEntities: [EntityID] = []
        private var wasRightMousePressed = false

        init() {
            configureEngine()
            createCamera()
            createLight()
            setSceneReady(true)
        }

        func loadPreset(_ preset: RemoteScenePreset) {
            placeCamera(eye: preset.cameraEye)
            loadManifest(url: preset.manifestURL, label: preset.rawValue)
        }

        func loadManifest(url: URL, label: String) {
            clearLoadedContent()
            setSceneReady(false)
            setGeometryStreaming(.enabled(true))
            setStatus("Loading \(label)...", isLoading: true)

            let root = createEntity()
            setEntityName(entityId: root, name: "\(label) Stream Root")
            streamedSceneRoot = root

            setEntityStreamScene(entityId: root, url: url) { [weak self] success in
                guard let self else { return }
                if success {
                    setSceneReady(true)
                    setStatus("\(label) manifest registered. Move the camera to stream tiles.", isLoading: false)
                } else {
                    setSceneReady(true)
                    setStatus("Could not load \(label). Use Field for offline fallback.", isLoading: false)
                    if streamedSceneRoot == root {
                        streamedSceneRoot = nil
                    }
                }
            }
        }

        func loadFallbackField() {
            clearLoadedContent()
            setGeometryStreaming(.enabled(false))
            setSceneReady(false)
            setStatus("Building procedural reference field...", isLoading: true)

            let cubeMesh = BasicPrimitives.createCube(extent: 0.9)
            let half = Constants.fallbackGridSize / 2

            for z in -half ..< half {
                for x in -half ..< half {
                    let entity = createEntity()
                    setEntityName(entityId: entity, name: "Fallback_\(x)_\(z)")
                    setEntityMeshDirect(entityId: entity, meshes: cubeMesh, assetName: "fallback_cube")
                    translateTo(
                        entityId: entity,
                        position: simd_float3(
                            Float(x) * Constants.fallbackSpacing,
                            0.0,
                            Float(z) * Constants.fallbackSpacing
                        )
                    )
                    let hue = Double((x + half) % 8) / 8.0
                    updateMaterialColor(
                        entityId: entity,
                        color: Color(hue: hue, saturation: 0.62, brightness: 0.86)
                    )
                    setEntityStaticBatchComponent(entityId: entity)
                    fallbackEntities.append(entity)
                }
            }

            setBatching(.enabled(true))
            generateBatches()
            placeCamera(eye: simd_float3(0.0, 24.0, 72.0))
            setSceneReady(true)
            setStatus("Offline field loaded. Use remote/custom manifest for true tile streaming.", isLoading: false)
        }

        func update(deltaTime _: Float) {
            guard gameMode else { return }
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
                deltaTime: Constants.cameraInputDeltaTime
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

        func setTileBoundsDebug(_ enabled: Bool) {
            setSpatialDebug(.tileBounds(enabled: enabled))
        }

        func setLodDebug(_ enabled: Bool) {
            setSpatialDebug(.lodLevels(enabled))
        }

        func setTextureTierDebug(_ enabled: Bool) {
            setSpatialDebug(.textureStreamingTiers(enabled))
        }

        private func configureEngine() {
            gameMode = true
            setRendering(.postProcessing(.enabled))
            setRendering(.antiAliasing(.fxaa))
            setRendering(.environment(.ibl(true)))
            setRendering(.environment(.visible(false)))

            setGeometryStreaming(.enabled(true))
            setGeometryStreaming(.tileConcurrency(2))
            setGeometryStreaming(.meshConcurrency(3))
            setGeometryStreaming(.lodConcurrency(4))
            setGeometryStreaming(.hlodConcurrency(4))
            setGeometryStreaming(.queryRadius(650.0))
            setGeometryStreaming(.frustumGate(.enabled(meshPadding: 6.0, tilePadding: 30.0)))
            setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
            setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))

            setBatching(.enabled(true))
            setSpatialDebug(.tileBounds(enabled: true))

            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
        }

        private func createCamera() {
            let camera = createEntity()
            setEntityName(entityId: camera, name: "Streaming Camera")
            createGameCamera(entityId: camera)
            setCamera(.active(camera))
            placeCamera(eye: RemoteScenePreset.dungeon.cameraEye)
        }

        private func createLight() {
            let sun = createEntity()
            setEntityName(entityId: sun, name: "Key Light")
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, angle: -45.0, axis: simd_float3(1.0, 0.0, 0.0))
            setLight(entityId: sun, .color(simd_float3(1.0, 0.94, 0.86)))
            setLight(entityId: sun, .intensity(1.4))
            setLight(entityId: sun, .directional(.active))
        }

        private func placeCamera(eye: simd_float3) {
            guard let camera = CameraSystem.shared.activeCamera else { return }
            cameraLookAt(
                entityId: camera,
                eye: eye,
                target: Constants.worldOrigin,
                up: simd_float3(0.0, 1.0, 0.0)
            )
            setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitTargetOffset)
        }

        private func clearLoadedContent() {
            GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()

            if let streamedSceneRoot {
                destroyEntity(entityId: streamedSceneRoot)
                self.streamedSceneRoot = nil
            }

            for entity in fallbackEntities {
                destroyEntity(entityId: entity)
            }
            fallbackEntities.removeAll()
            clearSceneBatches()
        }

        private func setStatus(_ message: String, isLoading: Bool) {
            onStatusChanged?(message, isLoading)
        }
    }
#endif
