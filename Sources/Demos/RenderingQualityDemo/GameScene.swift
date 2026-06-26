//
//  GameScene.swift
//  RenderingQualityDemo
//

#if os(macOS)
    import Foundation
    import simd
    import UntoldEngine

    final class GameScene: @unchecked Sendable {
        private enum Constants {
            static let cameraEye = simd_float3(0.0, 5.5, 12.0)
            static let cameraTarget = simd_float3(0.0, 0.7, 0.0)
            static let orbitOffset: Float = 12.0
        }

        private var stadium: EntityID?
        private var player: EntityID?
        private var ball: EntityID?
        private var wasRightMousePressed = false

        init() {
            configureEngine()
            createCamera()
            createLights()
            loadScene()
            applyNeutralLook()
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

        func setAntiAliasing(_ mode: AntiAliasingMode) {
            setRendering(.antiAliasing(mode))
        }

        func setDebugView(_ mode: RenderDebugViewMode) {
            if mode == .ssaoBlurred {
                setPostFX(.ssao(.enabled(true)))
            }
            setRendering(.debugView(mode))
        }

        func applyNeutralLook() {
            setRendering(.postProcessing(.enabled))
            setRendering(.debugView(.lit))
            setRendering(.antiAliasing(.fxaa))
            setPostFX(.preset(.neutral))
            setPostFX(.bloomThreshold(.enabled(false)))
            setPostFX(.bloomComposite(.enabled(false)))
            setPostFX(.vignette(.enabled(false)))
            setPostFX(.chromaticAberration(.enabled(false)))
            setPostFX(.depthOfField(.enabled(false)))
        }

        func applyCinematicLook() {
            setRendering(.postProcessing(.enabled))
            setRendering(.debugView(.lit))
            setRendering(.antiAliasing(.smaa))
            setPostFX(.preset(.cinematic))
            setPostFX(.bloomThreshold(.enabled(true)))
            setPostFX(.bloomThreshold(.threshold(0.62)))
            setPostFX(.bloomThreshold(.intensity(0.45)))
            setPostFX(.bloomComposite(.enabled(true)))
            setPostFX(.bloomComposite(.intensity(0.55)))
            setPostFX(.vignette(.enabled(true)))
            setPostFX(.vignette(.intensity(0.28)))
            setPostFX(.vignette(.radius(0.82)))
            setPostFX(.vignette(.softness(0.42)))
            setPostFX(.chromaticAberration(.enabled(false)))
            setPostFX(.depthOfField(.enabled(false)))
        }

        func applyInspectionLook() {
            setRendering(.postProcessing(.enabled))
            setRendering(.debugView(.lit))
            setRendering(.antiAliasing(.smaa))
            setPostFX(.preset(.archviz))
            setPostFX(.ssao(.enabled(true)))
            setPostFX(.ssao(.quality(.high)))
            setPostFX(.ssao(.radius(0.85)))
            setPostFX(.ssao(.bias(0.02)))
            setPostFX(.ssao(.intensity(0.7)))
            setPostFX(.bloomThreshold(.enabled(false)))
            setPostFX(.bloomComposite(.enabled(false)))
            setPostFX(.vignette(.enabled(false)))
            setPostFX(.chromaticAberration(.enabled(false)))
            setPostFX(.depthOfField(.enabled(false)))
        }

        func setColorGrading(
            enabled: Bool,
            exposure: Float,
            brightness: Float,
            contrast: Float,
            saturation: Float,
            temperature: Float,
            tint: Float
        ) {
            setPostFX(.colorGrading(.enabled(enabled)))
            setPostFX(.colorGrading(.exposure(exposure)))
            setPostFX(.colorGrading(.brightness(brightness)))
            setPostFX(.colorGrading(.contrast(contrast)))
            setPostFX(.colorGrading(.saturation(saturation)))
            setPostFX(.colorGrading(.temperature(temperature)))
            setPostFX(.colorGrading(.tint(tint)))
        }

        func setSSAO(enabled: Bool, radius: Float, bias: Float, intensity: Float, quality: SSAOQuality) {
            setPostFX(.ssao(.enabled(enabled)))
            setPostFX(.ssao(.quality(quality)))
            setPostFX(.ssao(.radius(radius)))
            setPostFX(.ssao(.bias(bias)))
            setPostFX(.ssao(.intensity(intensity)))
        }

        func setBloom(enabled: Bool, threshold: Float, thresholdIntensity: Float, compositeIntensity: Float) {
            setPostFX(.bloomThreshold(.enabled(enabled)))
            setPostFX(.bloomThreshold(.threshold(threshold)))
            setPostFX(.bloomThreshold(.intensity(thresholdIntensity)))
            setPostFX(.bloomComposite(.enabled(enabled)))
            setPostFX(.bloomComposite(.intensity(compositeIntensity)))
        }

        func setVignette(enabled: Bool, intensity: Float, radius: Float, softness: Float) {
            setPostFX(.vignette(.enabled(enabled)))
            setPostFX(.vignette(.intensity(intensity)))
            setPostFX(.vignette(.radius(radius)))
            setPostFX(.vignette(.softness(softness)))
        }

        func setDepthOfField(enabled: Bool, focusDistance: Float, focusRange: Float, maxBlur: Float) {
            setPostFX(.depthOfField(.enabled(enabled)))
            setPostFX(.depthOfField(.focusDistance(focusDistance)))
            setPostFX(.depthOfField(.focusRange(focusRange)))
            setPostFX(.depthOfField(.maxBlur(maxBlur)))
        }

        func setChromaticAberration(enabled: Bool, intensity: Float) {
            setPostFX(.chromaticAberration(.enabled(enabled)))
            setPostFX(.chromaticAberration(.intensity(intensity)))
            setPostFX(.chromaticAberration(.center(simd_float2(0.5, 0.5))))
        }

        private func configureEngine() {
            gameMode = true
            setSceneReady(false)
            setEngine(.assetBasePath(Self.resourcesURL()))
            setRendering(.environment(.ibl(true)))
            setRendering(.environment(.visible(false)))
            InputSystem.shared.registerMouseEvents()
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
            setEntityName(entityId: camera, name: "Quality Camera")
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

        private func createLights() {
            let sun = createEntity()
            setEntityName(entityId: sun, name: "Key Light")
            createDirLight(entityId: sun)
            rotateTo(entityId: sun, angle: -50.0, axis: simd_float3(1.0, 0.0, 0.0))
            setLight(entityId: sun, .color(simd_float3(1.0, 0.94, 0.86)))
            setLight(entityId: sun, .intensity(1.55))
            setLight(entityId: sun, .directional(.active))

            let fill = createEntity()
            setEntityName(entityId: fill, name: "Fill Light")
            createPointLight(entityId: fill)
            translateTo(entityId: fill, position: simd_float3(-3.0, 2.0, 3.0))
            setLight(entityId: fill, .color(simd_float3(0.58, 0.70, 1.0)))
            setLight(entityId: fill, .intensity(0.55))
            setLight(entityId: fill, .point(.radius(5.0)))
        }

        private func loadScene() {
            loadAsset("stadium") { [weak self] entity, success in
                self?.stadium = entity
                if success, let entity {
                    rotateTo(entityId: entity, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
                }
                setSceneReady(success)
            }

            loadAsset("redplayer") { [weak self] entity, success in
                self?.player = entity
                if success, let entity {
                    translateTo(entityId: entity, position: simd_float3(-1.1, 0.0, 0.4))
                }
            }

            loadAsset("ball") { [weak self] entity, success in
                self?.ball = entity
                if success, let entity {
                    translateTo(entityId: entity, position: simd_float3(1.2, 0.45, -0.7))
                    scaleTo(entityId: entity, scale: simd_float3(repeating: 0.75))
                }
            }
        }

        private func loadAsset(
            _ name: String,
            completion: @escaping @Sendable (EntityID?, Bool) -> Void
        ) {
            let entity = createEntity()
            setEntityName(entityId: entity, name: name)
            setEntityMeshAsync(entityId: entity, filename: name, withExtension: "untold") { success in
                completion(success ? entity : nil, success)
            }
        }
    }
#endif
