//
//  GameScene.swift
//  ExporterPipelineDemo
//

#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    enum ExportedAssetOption: String, CaseIterable, Identifiable {
        case stadium
        case redplayer
        case ball

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .stadium: "Stadium"
            case .redplayer: "Red Player"
            case .ball: "Ball"
            }
        }

        var supportsAnimation: Bool {
            self == .redplayer
        }

        var defaultScale: simd_float3 {
            switch self {
            case .ball: simd_float3(repeating: 0.8)
            default: simd_float3(repeating: 1.0)
            }
        }
    }

    enum ExportedAnimationOption: String, CaseIterable, Identifiable {
        case idle
        case running

        var id: String {
            rawValue
        }

        var title: String {
            rawValue.capitalized
        }
    }

    struct ValidationSummary {
        var assetName: String = "-"
        var meshCount: Int = 0
        var totalVertices: Int = 0
        var totalIndices: Int = 0
        var found = false
    }

    struct PipelineStatus {
        var loadedEntity = "None"
        var assetPath = "-"
        var assetExists = false
        var validation = ValidationSummary()
        var animationClips = "-"
        var message = "Select an exported asset."
    }

    final class GameScene: @unchecked Sendable {
        private enum Constants {
            static let cameraEye = simd_float3(0.0, 3.5, 8.0)
            static let cameraTarget = simd_float3(0.0, 0.8, 0.0)
            static let orbitOffset: Float = 8.0
        }

        var onStatusChanged: (@Sendable (PipelineStatus) -> Void)?

        private var loadedEntity: EntityID?
        private var loadedAsset: ExportedAssetOption?
        private var status = PipelineStatus()
        private var wasRightMousePressed = false

        init() {
            configureEngine()
            createCamera()
            createLight()
            loadAsset(.redplayer)
        }

        func update(deltaTime _: Float) {
            if gameMode == false { return }
        }

        func handleInput() {
            if gameMode == false { return }
            if isSceneReady() == false { return }

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

        func loadAsset(_ option: ExportedAssetOption) {
            setSceneReady(false)

            if let loadedEntity {
                destroyEntity(entityId: loadedEntity)
                self.loadedEntity = nil
            }

            loadedAsset = option
            status = makeStatus(for: option, message: "Loading \(option.title)...")
            publishStatus()

            let entity = createEntity()
            setEntityName(entityId: entity, name: option.title)
            setEntityMeshAsync(entityId: entity, filename: option.rawValue, withExtension: "untold") { [weak self] success in
                guard let self else { return }

                if success {
                    loadedEntity = entity
                    translateTo(entityId: entity, position: .zero)
                    scaleTo(entityId: entity, scale: option.defaultScale)
                    if option == .stadium {
                        rotateTo(entityId: entity, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
                    }
                    status = makeStatus(for: option, message: "\(option.title) loaded.")
                    refreshAnimationClips()
                } else {
                    status = makeStatus(for: option, message: "Failed to load \(option.title).")
                }

                setSceneReady(success)
                publishStatus()
            }
        }

        func loadAnimation(_ option: ExportedAnimationOption) {
            guard let loadedEntity, loadedAsset?.supportsAnimation == true else {
                status.message = "Selected asset does not support the demo animations."
                publishStatus()
                return
            }

            setEntityAnimations(
                entityId: loadedEntity,
                filename: option.rawValue,
                withExtension: "untold",
                name: option.rawValue
            )
            changeAnimation(entityId: loadedEntity, name: option.rawValue)
            status.message = "Animation \(option.title) applied."
            refreshAnimationClips()
            publishStatus()
        }

        func resetScene() {
            if let loadedAsset {
                loadAsset(loadedAsset)
            } else {
                loadAsset(.redplayer)
            }
        }

        private func configureEngine() {
            gameMode = true
            setSceneReady(false)
            setEngine(.assetBasePath(Self.resourcesURL()))
            setRendering(.postProcessing(.enabled))
            setRendering(.antiAliasing(.fxaa))
            setRendering(.environment(.ibl(true)))
            setRendering(.environment(.visible(false)))
            InputSystem.shared.registerMouseEvents()
        }

        static func resourcesURL() -> URL {
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
            setEntityName(entityId: camera, name: "Pipeline Camera")
            createGameCamera(entityId: camera)
            cameraLookAt(
                entityId: camera,
                eye: Constants.cameraEye,
                target: Constants.cameraTarget,
                up: simd_float3(0.0, 1.0, 0.0)
            )
            setOrbitOffset(entityId: camera, uTargetOffset: Constants.orbitOffset)
            setCamera(.active(camera))
        }

        private func createLight() {
            let sun = createEntity()
            setEntityName(entityId: sun, name: "Pipeline Key Light")
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, angle: -50.0, axis: simd_float3(1.0, 0.0, 0.0))
            setLight(entityId: sun, .color(simd_float3(1.0, 0.94, 0.86)))
            setLight(entityId: sun, .intensity(1.5))
            setLight(entityId: sun, .directional(.active))
        }

        private func makeStatus(for option: ExportedAssetOption, message: String) -> PipelineStatus {
            let assetURL = assetURL(for: option)
            return PipelineStatus(
                loadedEntity: loadedEntity.map { "\($0)" } ?? "None",
                assetPath: assetURL.path,
                assetExists: FileManager.default.fileExists(atPath: assetURL.path),
                validation: validationSummary(for: option),
                animationClips: status.animationClips,
                message: message
            )
        }

        private func assetURL(for option: ExportedAssetOption) -> URL {
            Self.resourcesURL()
                .appendingPathComponent("Models")
                .appendingPathComponent(option.rawValue)
                .appendingPathComponent("\(option.rawValue).untold")
        }

        private func validationURL(for option: ExportedAssetOption) -> URL {
            Self.resourcesURL()
                .appendingPathComponent("Models")
                .appendingPathComponent(option.rawValue)
                .appendingPathComponent("\(option.rawValue).validation.json")
        }

        private func validationSummary(for option: ExportedAssetOption) -> ValidationSummary {
            let url = validationURL(for: option)
            guard FileManager.default.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(ValidationFile.self, from: data)
            else {
                return ValidationSummary(found: false)
            }

            return ValidationSummary(
                assetName: decoded.assetName,
                meshCount: decoded.meshCount,
                totalVertices: decoded.meshes.reduce(0) { $0 + $1.vertexCount },
                totalIndices: decoded.meshes.reduce(0) { $0 + $1.indexCount },
                found: true
            )
        }

        private func refreshAnimationClips() {
            guard let loadedEntity else {
                status.animationClips = "-"
                return
            }

            let clips = getAllAnimationClips(entityId: loadedEntity).sorted()
            status.loadedEntity = "\(loadedEntity)"
            status.animationClips = clips.isEmpty ? "None" : clips.joined(separator: ", ")
        }

        private func publishStatus() {
            onStatusChanged?(status)
        }
    }

    private struct ValidationFile: Decodable {
        let assetName: String
        let meshCount: Int
        let meshes: [ValidationMesh]

        enum CodingKeys: String, CodingKey {
            case assetName = "asset_name"
            case meshCount = "mesh_count"
            case meshes
        }
    }

    private struct ValidationMesh: Decodable {
        let vertexCount: Int
        let indexCount: Int

        enum CodingKeys: String, CodingKey {
            case vertexCount = "vertex_count"
            case indexCount = "index_count"
        }
    }
#endif
