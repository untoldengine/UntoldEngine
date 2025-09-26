//
//  SceneSerializer.swift
//
//
//  Created by Harold Serrano on 3/6/25.
//
#if canImport(AppKit)
import AppKit
import Foundation
import simd
import UniformTypeIdentifiers

struct SceneData: Codable {
    var entities: [EntityData] = []
    var environment: EnvironmentData? = nil
    var assetBasePath: URL? = nil
    var toneMapping: ToneMappingData? = nil
    var colorGrading: ColorGradingData? = nil
    var colorCorrection: ColorCorrectionData? = nil
    var bloom: BloomThresholdData? = nil
    var vignette: VignetteData? = nil
    var chromaticAberration: ChromaticAberrationData? = nil
    var depthOfField: DepthOfFieldData? = nil
    var ssao: SSAOData? = nil
}

struct ToneMappingData: Codable {
    var exposure: Float = 1.0
    var toneMapOperator: Int = 0
    var gamma: Float = 1.0
}

struct ColorGradingData: Codable {
    var brightness: Float = 0.0
    var contrast: Float = 1.0
    var saturation: Float = 1.0
    var exposure: Float = 1.0
    var temperature: Float = 0.0
    var tint: Float = 0.0
}

struct ColorCorrectionData: Codable {
    var temperature: Float = 0.0 // -1.0 to 1.0 (-1.0 bluish, 0.0 neutral, +1.0 warm, yellowish/orange)
    var tint: Float = 0.0 // -1.0 to 1.0 Green (-)/Magenta (+)
    var lift: simd_float3 = .zero // RGB adjustment for shadows (0 - 2)
    var gamma: simd_float3 = .one // RGB adjustment for midtones (0.5 - 2.5)
    var gain: simd_float3 = .one // RGB adjustment for highlights (0 - 2)
}

struct BloomThresholdData: Codable {
    var threshold: Float = 1.0 // 0.0 to 5.0
    var intensity: Float = 1.0 // 0.0 to 2.0
    var enabled: Bool? = false
}

struct VignetteData: Codable {
    var intensity: Float = 0.7 // 0.0 to 1.0
    var radius: Float = 0.75 // 0.5 to 1.0
    var softness: Float = 0.45 // 0.0 to 1.0
    var center: simd_float2 = .init(0.5, 0.5) // 0-1
    var enabled: Bool? = false
}

struct ChromaticAberrationData: Codable {
    var intensity: Float = 0.0 // 0.0 to 0.1
    var center: simd_float2 = .init(0.5, 0.5) // 0-1
    var enabled: Bool? = false
}

struct DepthOfFieldData: Codable {
    var focusDistance: Float = 1.0 // 0.0 to 1.0
    var focusRange: Float = 0.1 // 0.01-0.3
    var maxBlur: Float = 0 // 0.005-0.05
    var enabled: Bool? = false
}

struct SSAOData: Codable {
    var radius: Float = 0.5
    var bias: Float = 0.0
    var intensity: Float = 0.0
    var enabled: Bool? = false
}

struct LightData: Codable {
    var color: simd_float3 = .one
    var radius: Float = 1.0
    var intensity: Float = 1.0
    var falloff: Float = 0.5
    var coneAngle: Float = 30.0
    var forward: simd_float3 = .init(0.0, 0.0, -1.0) // Normal vector of the light's surface
    var right: simd_float3 = .init(1.0, 0.0, 0.0) // Right vector defining the surface orientation
    var up: simd_float3 = .init(0.0, 1.0, 0.0) // Up vector defining the surface orientation
    var bounds: simd_float2 = .one
    var twoSided: Bool = false
}

struct CameraData: Codable {
    var eye: simd_float3 = .zero
    var target: simd_float3 = .zero
    var up: simd_float3 = .init(0.0, 1.0, 0.0)
}

struct EnvironmentData: Codable {
    var applyIBL: Bool? = nil
    var renderEnvironment: Bool? = nil
    var hdr: String? = nil
    var ambientIntensity: Float? = nil
}

struct MaterialData: Codable {
    var baseColorValue: simd_float4 = .zero
    var emissiveValue: simd_float3 = .zero
    var roughnessValue: Float = 1.0
    var metallicValue: Float = 0.0
    var baseColorURL: URL? = nil
    var roughnessURL: URL? = nil
    var metallicURL: URL? = nil
    var normalURL: URL? = nil
}

struct EntityData: Codable {
    var uuid: UUID = .init() // Unique identifier for this entity
    var parentUUID: UUID? = nil // UUID of the parent entity, if any
    var name: String = "" // entity name
    var assetName: String = "" // asset name in 3D software
    var assetURL: URL = .init(fileURLWithPath: "")
    var position: simd_float3 = .zero
    var axisOfRotations: simd_float3 = .zero
    var scale: simd_float3 = .one
    var animations: [URL] = []
    var mass: Float = .init(1.0)
    var lightData: LightData? = nil
    var cameraData: CameraData? = nil
    var materialData: MaterialData? = nil
    var hasRenderingComponent: Bool = false
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
    var hasDirLightComponent: Bool?
    var hasPointLightComponent: Bool?
    var hasSpotLightComponent: Bool?
    var hasAreaLightComponent: Bool?
    var hasCameraComponent: Bool?

    var customComponents: [String: Data]? = nil
}

func serializeScene() -> SceneData {
    var sceneData = SceneData()
    var entityIdToUUID: [EntityID: UUID] = [:]

    // assign UUIDs
    for entityId in getAllGameEntities() {
        let uuid = UUID()
        entityIdToUUID[entityId] = uuid
    }

    for entityId in getAllGameEntities() {
        var entityData = EntityData()

        // assign uuid
        entityData.uuid = entityIdToUUID[entityId]!

        // parent uuid (if any)
        if let parentId = getEntityParent(entityId: entityId) {
            entityData.parentUUID = entityIdToUUID[parentId]
        }

        entityData.name = getEntityName(entityId: entityId)

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            entityData.assetName = renderComponent.assetName

            entityData.assetURL = renderComponent.assetURL

            // material data
            let baseColor: simd_float4 = getMaterialBaseColor(entityId: entityId)
            let roughnessValue: Float = getMaterialRoughness(entityId: entityId)
            let metallicValue: Float = getMaterialMetallic(entityId: entityId)
            let emissiveValue: simd_float3 = getMaterialEmmissive(entityId: entityId)

            var baseColorURL: URL?
            var roughnessURL: URL?
            var metallicURL: URL?
            var normalURL: URL?

            if let baseColorTexture: URL = getMaterialTextureURL(entityId: entityId, type: .baseColor) {
                baseColorURL = baseColorTexture
            }

            if let roughnessTexture: URL = getMaterialTextureURL(entityId: entityId, type: .roughness) {
                roughnessURL = roughnessTexture
            }

            if let metallicTexture: URL = getMaterialTextureURL(entityId: entityId, type: .metallic) {
                metallicURL = metallicTexture
            }

            if let normalTexture: URL = getMaterialTextureURL(entityId: entityId, type: .normal) {
                normalURL = normalTexture
            }

            entityData.materialData = MaterialData(baseColorValue: baseColor, emissiveValue: emissiveValue, roughnessValue: roughnessValue, metallicValue: metallicValue, baseColorURL: baseColorURL, roughnessURL: roughnessURL, metallicURL: metallicURL, normalURL: normalURL)
        }

        // Rendering properties
        entityData.hasRenderingComponent = hasComponent(entityId: entityId, componentType: RenderComponent.self)

        // Transform properties
        if scene.get(component: LocalTransformComponent.self, for: entityId) != nil {
            entityData.position = getLocalPosition(entityId: entityId)
            entityData.scale = getScale(entityId: entityId)
            let axisOfRotations = getAxisRotations(entityId: entityId)

            entityData.axisOfRotations = axisOfRotations
        }

        entityData.hasLocalTransformComponent = hasComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        // Animation properties
        if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
            entityData.animations = animationComponent.animationsFilenames
        }

        entityData.hasAnimationComponent = hasComponent(entityId: entityId, componentType: AnimationComponent.self)

        // Kinetic properties
        entityData.mass = getMass(entityId: entityId)

        entityData.hasKineticComponent = hasComponent(entityId: entityId, componentType: KineticComponent.self)

        // Dir Light properties
        let hasDirLight: Bool = hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self)

        if hasDirLight {
            entityData.hasDirLightComponent = hasDirLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)
        }

        // Point Light properties
        let hasPointLight: Bool = hasComponent(entityId: entityId, componentType: PointLightComponent.self)

        if hasPointLight {
            entityData.hasPointLightComponent = hasPointLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.radius = getLightRadius(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)

            entityData.lightData?.falloff = getLightFalloff(entityId: entityId)
        }

        // Spot light properties
        let hasSpotLight: Bool = hasComponent(entityId: entityId, componentType: SpotLightComponent.self)

        if hasSpotLight {
            entityData.hasSpotLightComponent = hasSpotLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.radius = getLightRadius(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)

            entityData.lightData?.falloff = getLightFalloff(entityId: entityId)

            entityData.lightData?.coneAngle = getLightConeAngle(entityId: entityId)
        }

        // Area light properties
        let hasAreaLight: Bool = hasComponent(entityId: entityId, componentType: AreaLightComponent.self)

        if hasAreaLight {
            entityData.hasAreaLightComponent = hasAreaLight

            entityData.lightData = LightData()

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)

            entityData.lightData?.forward = getForwardAxisVector(entityId: entityId)

            entityData.lightData?.right = getRightAxisVector(entityId: entityId)

            entityData.lightData?.up = getUpAxisVector(entityId: entityId)

            let (width, height, _) = getDimension(entityId: entityId)

            entityData.lightData?.bounds = simd_float2(width, height)

            if let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) {
                entityData.lightData?.twoSided = areaLightComponent.twoSided
            }
        }

        // Camera properties
        let hasCamera: Bool = hasComponent(entityId: entityId, componentType: CameraComponent.self)

        if hasCamera {
            entityData.hasCameraComponent = hasCamera

            entityData.cameraData = CameraData()

            entityData.cameraData?.eye = getCameraEye(entityId: entityId)
            entityData.cameraData?.target = getCameraTarget(entityId: entityId)
            entityData.cameraData?.up = getCameraUp(entityId: entityId)
        }

        // custom component
        var customComponents: [String: Data] = [:]

        // Serialize every registered custom component; the closure returns nil if the entity doesn’t have it
        for (encKey, serialize) in customComponentEncoderMap {
            if let data = serialize(entityId),
               let typeName = customComponentTypeNameById[encKey]
            {
                customComponents[typeName] = data
            }
        }

        entityData.customComponents = customComponents

        sceneData.entities.append(entityData)
    }

    // load environment data
    sceneData.environment = EnvironmentData(applyIBL: applyIBL, renderEnvironment: renderEnvironment, hdr: hdrURL, ambientIntensity: ambientIntensity)

    // Load post-process data
    sceneData.toneMapping = ToneMappingData(
        toneMapOperator: ToneMappingParams.shared.toneMapOperator,
        gamma: ToneMappingParams.shared.gamma
    )

    sceneData.colorCorrection = ColorCorrectionData(
        lift: ColorCorrectionParams.shared.lift,
        gamma: ColorCorrectionParams.shared.gamma,
        gain: ColorCorrectionParams.shared.gain
    )

    sceneData.colorGrading = ColorGradingData(
        brightness: ColorGradingParams.shared.brightness,
        contrast: ColorGradingParams.shared.contrast,
        saturation: ColorGradingParams.shared.saturation,
        exposure: ColorGradingParams.shared.exposure,
        temperature: ColorGradingParams.shared.temperature,
        tint: ColorGradingParams.shared.tint
    )

    sceneData.bloom = BloomThresholdData(threshold: BloomThresholdParams.shared.threshold, intensity: BloomThresholdParams.shared.intensity, enabled: BloomThresholdParams.shared.enabled)

    sceneData.vignette = VignetteData(intensity: VignetteParams.shared.intensity, radius: VignetteParams.shared.radius, softness: VignetteParams.shared.softness, center: VignetteParams.shared.center, enabled: VignetteParams.shared.enabled)

    sceneData.chromaticAberration = ChromaticAberrationData(intensity: ChromaticAberrationParams.shared.intensity, center: ChromaticAberrationParams.shared.center, enabled: ChromaticAberrationParams.shared.enabled)

    sceneData.depthOfField = DepthOfFieldData(focusDistance: DepthOfFieldParams.shared.focusDistance, focusRange: DepthOfFieldParams.shared.focusRange, maxBlur: DepthOfFieldParams.shared.maxBlur, enabled: DepthOfFieldParams.shared.enabled)

    sceneData.ssao = SSAOData(radius: SSAOParams.shared.radius, bias: SSAOParams.shared.bias, intensity: SSAOParams.shared.intensity, enabled: SSAOParams.shared.enabled)

    // save asset base path
    sceneData.assetBasePath = assetBasePath

    return sceneData
}

func saveScene(sceneData: SceneData) {
    let savePanel = NSSavePanel()
    savePanel.title = "Save Scene"
    savePanel.allowedContentTypes = [UTType.json]
    savePanel.nameFieldStringValue = "untitled.json"
    savePanel.canCreateDirectories = true
    savePanel.isExtensionHidden = false

    savePanel.begin { result in
        if result == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder()

                encoder.outputFormatting = .prettyPrinted

                let jsonData = try encoder.encode(sceneData)
                try jsonData.write(to: url)
                print("Scene saved to \(url.path)")
            } catch {
                print("Failed to save scene: \(error)")
            }
        }
    }
}

func loadGameScene() -> SceneData? {
    let openPanel = NSOpenPanel()
    openPanel.title = "Open Scene"
    openPanel.allowedContentTypes = [UTType.json]
    openPanel.allowsMultipleSelection = false

    if openPanel.runModal() == .OK, let url = openPanel.url {
        let decoder = JSONDecoder()

        do {
            let jsonData = try Data(contentsOf: url)
            let sceneData = try decoder.decode(SceneData.self, from: jsonData)
            Logger.log(message: "Scene loaded from \(url.path)")
            return sceneData
        } catch {
            Logger.log(message: "Failed to load scene: \(error)")
        }
    }

    return nil
}

func loadGameScene(from url: URL) -> SceneData? {
    // Normalize to a file URL if needed
    let fileURL = url.isFileURL ? url : URL(fileURLWithPath: url.path)

    do {
        let data = try Data(contentsOf: fileURL)
        let scene = try JSONDecoder().decode(SceneData.self, from: data)
        Logger.log(message: "Scene loaded from \(fileURL.path)")
        return scene
    } catch {
        Logger.log(message: "Failed to load scene: \(error)")
        return nil
    }
}

func deserializeScene(sceneData: SceneData) {
    var uuidToEntityMap: [UUID: EntityID] = [:]

    if let env = sceneData.environment {
        applyIBL = env.applyIBL ?? false
        renderEnvironment = env.renderEnvironment ?? false
        ambientIntensity = env.ambientIntensity ?? 0.44

        hdrURL = env.hdr ?? "teatro_massimo_2k.hdr"
        generateHDR(hdrURL)
    }

    EditorAssetBasePath.shared.basePath = assetBasePath

    if let colorGrading = sceneData.colorGrading {
        ColorGradingParams.shared.brightness = colorGrading.brightness
        ColorGradingParams.shared.contrast = colorGrading.contrast
        ColorGradingParams.shared.saturation = colorGrading.saturation
        ColorGradingParams.shared.exposure = colorGrading.exposure
        ColorGradingParams.shared.temperature = colorGrading.temperature
        ColorGradingParams.shared.tint = colorGrading.tint
    }

    if let bloomThreshold = sceneData.bloom {
        BloomThresholdParams.shared.intensity = bloomThreshold.intensity
        BloomThresholdParams.shared.threshold = bloomThreshold.threshold
        if let enabled = bloomThreshold.enabled {
            BloomThresholdParams.shared.enabled = enabled
        }
    }

    if let vignette = sceneData.vignette {
        VignetteParams.shared.intensity = vignette.intensity
        VignetteParams.shared.radius = vignette.radius
        VignetteParams.shared.softness = vignette.softness
        VignetteParams.shared.center = vignette.center
        if let enabled = vignette.enabled {
            VignetteParams.shared.enabled = enabled
        }
    }

    if let chromaticAberration = sceneData.chromaticAberration {
        ChromaticAberrationParams.shared.intensity = chromaticAberration.intensity
        ChromaticAberrationParams.shared.center = chromaticAberration.center
        if let enabled = chromaticAberration.enabled {
            ChromaticAberrationParams.shared.enabled = enabled
        }
    }

    if let depthOfField = sceneData.depthOfField {
        DepthOfFieldParams.shared.focusDistance = depthOfField.focusDistance
        DepthOfFieldParams.shared.focusRange = depthOfField.focusRange
        DepthOfFieldParams.shared.maxBlur = depthOfField.maxBlur
        if let enabled = depthOfField.enabled {
            DepthOfFieldParams.shared.enabled = enabled
        }
    }

    if let ssao = sceneData.ssao {
        SSAOParams.shared.radius = ssao.radius
        SSAOParams.shared.intensity = ssao.intensity
        SSAOParams.shared.bias = ssao.bias
        if let enabled = ssao.enabled {
            SSAOParams.shared.enabled = enabled
        }
    }

    for sceneDataEntity in sceneData.entities {
        let entityId = createEntity()

        uuidToEntityMap[sceneDataEntity.uuid] = entityId

        setEntityName(entityId: entityId, name: sceneDataEntity.name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        if sceneDataEntity.hasRenderingComponent == true {
            let filename = sceneDataEntity.assetURL.deletingPathExtension().lastPathComponent
            let withExtension = sceneDataEntity.assetURL.pathExtension
            setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension, assetName: sceneDataEntity.assetName)

            if let materialData = sceneDataEntity.materialData {
                let baseColorValue: simd_float4 = materialData.baseColorValue
                let roughnessValue: Float = materialData.roughnessValue
                let metallicValue: Float = materialData.metallicValue
                let emissiveValue: simd_float3 = materialData.emissiveValue

                updateMaterialColor(entityId: entityId, color: colorFromSimd(baseColorValue))
                updateMaterialRoughness(entityId: entityId, roughness: roughnessValue)
                updateMaterialMetallic(entityId: entityId, metallic: metallicValue)
                updateMaterialEmmisive(entityId: entityId, emmissive: emissiveValue)

                if let baseColorURL = materialData.baseColorURL {
                    updateMaterialTexture(entityId: entityId, textureType: .baseColor, path: baseColorURL)
                }

                if let roughnessURL = materialData.roughnessURL {
                    updateMaterialTexture(entityId: entityId, textureType: .roughness, path: roughnessURL)
                }

                if let metallicURL = materialData.metallicURL {
                    updateMaterialTexture(entityId: entityId, textureType: .metallic, path: metallicURL)
                }

                if let normalURL = materialData.normalURL {
                    updateMaterialTexture(entityId: entityId, textureType: .normal, path: normalURL)
                }
            }
        }

        if sceneDataEntity.hasAnimationComponent == true {
            for animations in sceneDataEntity.animations {
                let animationFilename = animations.deletingPathExtension().lastPathComponent
                let animationFilenameExt = animations.pathExtension

                setEntityAnimations(entityId: entityId, filename: animationFilename, withExtension: animationFilenameExt, name: animationFilename)

                changeAnimation(entityId: entityId, name: animationFilename)
            }

            if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
                animationComponent.animationsFilenames = sceneDataEntity.animations
            }
        }

        if sceneDataEntity.hasKineticComponent == true {
            setEntityKinetics(entityId: entityId)

            guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId) else {
                handleError(.noPhysicsComponent)
                continue
            }

            physicsComponent.mass = sceneDataEntity.mass
        }

        if sceneDataEntity.hasDirLightComponent == true {
            if let light = sceneDataEntity.lightData {
                let color: simd_float3 = light.color
                let intensity: Float = light.intensity

                createDirLight(entityId: entityId)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                    handleError(.noLightComponent)
                    continue
                }

                lightComponent.color = color
                lightComponent.intensity = intensity

                guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                    handleError(.noRenderComponent)
                    continue
                }

                if let materialData = sceneDataEntity.materialData {
                    let emmissiveValue: simd_float3 = materialData.emissiveValue
                    updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                }
            }
        }

        if sceneDataEntity.hasPointLightComponent == true {
            if let light = sceneDataEntity.lightData {
                let color: simd_float3 = light.color
                let radius: Float = light.radius
                let intensity: Float = light.intensity
                let falloff: Float = light.falloff

                createPointLight(entityId: entityId)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                    handleError(.noLightComponent)
                    continue
                }

                guard let pointlightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
                    handleError(.noPointLightComponent)
                    continue
                }

                lightComponent.color = color
                lightComponent.intensity = intensity
                pointlightComponent.radius = radius
                pointlightComponent.falloff = falloff

                guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                    handleError(.noRenderComponent)
                    continue
                }

                if let materialData = sceneDataEntity.materialData {
                    let emmissiveValue: simd_float3 = materialData.emissiveValue
                    updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                }
            }
        }

        if sceneDataEntity.hasSpotLightComponent == true {
            if let light = sceneDataEntity.lightData {
                let color: simd_float3 = light.color
                let radius: Float = light.radius
                let intensity: Float = light.intensity
                let falloff: Float = light.falloff
                let coneAngle: Float = light.coneAngle

                createSpotLight(entityId: entityId)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                    handleError(.noLightComponent)
                    continue
                }

                guard let spotlightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
                    handleError(.noSpotLightComponent)
                    continue
                }

                lightComponent.color = color
                lightComponent.intensity = intensity
                spotlightComponent.radius = radius
                spotlightComponent.falloff = falloff
                spotlightComponent.coneAngle = coneAngle

                guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                    handleError(.noRenderComponent)
                    continue
                }

                if let materialData = sceneDataEntity.materialData {
                    let emmissiveValue: simd_float3 = materialData.emissiveValue
                    updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                }
            }
        }

        if sceneDataEntity.hasAreaLightComponent == true {
            if let light = sceneDataEntity.lightData {
                let color: simd_float3 = light.color
                let intensity: Float = light.intensity
                let forward = light.forward
                let right = light.right
                let up = light.up
                let bounds = light.bounds
                let twoSided = light.twoSided

                createAreaLight(entityId: entityId)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                    handleError(.noLightComponent)
                    continue
                }

                guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
                    handleError(.noAreaLightComponent)
                    continue
                }

                lightComponent.color = color
                lightComponent.intensity = intensity
                areaLightComponent.forward = forward
                areaLightComponent.right = right
                areaLightComponent.up = up
                areaLightComponent.bounds = bounds
                areaLightComponent.twoSided = twoSided

                guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
                    handleError(.noRenderComponent)
                    continue
                }

                if let materialData = sceneDataEntity.materialData {
                    let emmissiveValue: simd_float3 = materialData.emissiveValue
                    updateMaterialEmmisive(entityId: entityId, emmissive: emmissiveValue)
                }
            }
        }

        if sceneDataEntity.hasLocalTransformComponent == true {
            translateTo(entityId: entityId, position: sceneDataEntity.position)
            scaleTo(entityId: entityId, scale: sceneDataEntity.scale)
            let axisOfRotation = sceneDataEntity.axisOfRotations

            applyAxisRotations(entityId: entityId, axis: axisOfRotation)
        }

        if sceneDataEntity.hasCameraComponent == true {
            if let camera = sceneDataEntity.cameraData {
                let eye = camera.eye
                let target = camera.target
                let up = camera.up

                createGameCamera(entityId: entityId)

                guard let cameraComponent = scene.get(component: CameraComponent.self, for: entityId) else {
                    handleError(.noGameCamera)
                    continue
                }

                cameraComponent.eye = eye
                cameraComponent.target = target
                cameraComponent.up = up

                cameraLookAt(entityId: entityId, eye: eye, target: target, up: up)
            }
        }

        // custom components
        if let customComponents = sceneDataEntity.customComponents {
            for (typeName, jsonData) in customComponents {
                if let deserializeFunc = customComponentDecoderMap[typeName] {
                    deserializeFunc(entityId, jsonData)
                }
            }
        }
    }

    // secon pass: rebuild hierarchy
    for sceneDataEntity in sceneData.entities {
        guard let childId = uuidToEntityMap[sceneDataEntity.uuid],
              let parentUUID = sceneDataEntity.parentUUID,
              let parentId = uuidToEntityMap[parentUUID]
        else {
            continue
        }

        setParent(childId: childId, parentId: parentId)
    }
}
#endif
