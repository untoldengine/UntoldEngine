//
//  SceneSerializer.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public struct SceneData: Codable {
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

// MARK: - Asset Instance Data

struct LocalTransformOverrideData: Codable {
    var position: simd_float3?
    var scale: simd_float3?
    var axisOfRotations: simd_float3?
}

struct AssetOverrideData: Codable {
    var nodePath: String
    var transform: LocalTransformOverrideData?
    var material: MaterialData?
    var visibility: Bool?
    var name: String?
}

struct AssetInstanceData: Codable {
    var assetURL: URL
    var assetName: String
    var importMode: String // "preserveHierarchy" | "combineMeshes"
    var rootPrimPath: String?
    var overrides: [AssetOverrideData]
}

// MARK: - LOD Data

struct LODLevelData: Codable {
    var url: URL
    var maxDistance: Float
    var screenPercentage: Float
}

struct LODData: Codable {
    var lodLevels: [LODLevelData]
    var currentLOD: Int
    var fadeTransition: Bool
    var transitionDuration: Float
}

struct EntityData: Codable {
    var uuid: UUID = .init() // Unique identifier for this entity
    var parentUUID: UUID? = nil // UUID of the parent entity, if any
    var name: String = "" // entity name
    var assetName: String = "" // asset name in 3D software (legacy)
    var assetURL: URL = .init(fileURLWithPath: "") // legacy
    var position: simd_float3 = .zero
    var axisOfRotations: simd_float3 = .zero
    var scale: simd_float3 = .one
    var animations: [URL] = []
    var mass: Float = .init(1.0)
    var lightData: LightData? = nil
    var cameraData: CameraData? = nil
    var materialData: MaterialData? = nil
    var hasRenderingComponent: Bool = false // legacy
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
    var hasDirLightComponent: Bool?
    var hasPointLightComponent: Bool?
    var hasSpotLightComponent: Bool?
    var hasAreaLightComponent: Bool?
    var hasCameraComponent: Bool?
    var hasLODComponent: Bool?
    var hasStaticBatchComponent: Bool?

    var customComponents: [String: Data]? = nil

    // New Asset Instance system
    var assetInstance: AssetInstanceData? = nil

    // LOD system
    var lodData: LODData? = nil
}

private func isProceduralAssetURL(_ url: URL) -> Bool {
    let path = url.path
    return path.hasPrefix("/primitive/") || path.hasPrefix("/fallback/")
}

private func createProceduralMeshes(assetName: String) -> [Mesh] {
    let typeName = assetName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if typeName.contains("sphere") {
        return BasicPrimitives.createSphere()
    }
    if typeName.contains("plane") {
        return BasicPrimitives.createPlane()
    }
    if typeName.contains("cylinder") {
        return BasicPrimitives.createCylinder()
    }
    if typeName.contains("cone") {
        return BasicPrimitives.createCone()
    }
    // Default to cube
    return BasicPrimitives.createCube()
}

public func serializeScene() -> SceneData {
    var sceneData = SceneData()
    var entityIdToUUID: [EntityID: UUID] = [:]

    var authoredEntityCount = 0
    var derivedEntityCount = 0

    // assign UUIDs only to authored entities (skip derived nodes)
    for entityId in getAllGameEntities() {
        // Skip derived asset nodes - they will be recreated on import
        if hasComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self) {
            derivedEntityCount += 1
            continue
        }

        let uuid = UUID()
        entityIdToUUID[entityId] = uuid
        authoredEntityCount += 1
    }

    Logger.log(message: "[SceneSerializer] Serializing \(authoredEntityCount) authored entities, skipping \(derivedEntityCount) derived nodes")

    for entityId in getAllGameEntities() {
        // Skip derived asset nodes
        if hasComponent(entityId: entityId, componentType: DerivedAssetNodeComponent.self) {
            continue
        }

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

        // LOD properties
        let hasLOD: Bool = hasComponent(entityId: entityId, componentType: LODComponent.self)

        if hasLOD {
            entityData.hasLODComponent = hasLOD

            if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
                var lodLevelsData: [LODLevelData] = []

                for lodLevel in lodComponent.lodLevels {
                    // Only serialize if URL is available
                    if let url = lodLevel.url {
                        let lodLevelData = LODLevelData(
                            url: url,
                            maxDistance: lodLevel.maxDistance,
                            screenPercentage: lodLevel.screenPercentage
                        )
                        lodLevelsData.append(lodLevelData)
                    }
                }

                if !lodLevelsData.isEmpty {
                    entityData.lodData = LODData(
                        lodLevels: lodLevelsData,
                        currentLOD: lodComponent.currentLOD,
                        fadeTransition: lodComponent.fadeTransition,
                        transitionDuration: lodComponent.transitionDuration
                    )
                }
            }
        }

        // Static Batch properties
        // Check if entity or any of its children have StaticBatchComponent
        func hasStaticBatchInHierarchy(entityId: EntityID) -> Bool {
            // Check self
            if hasComponent(entityId: entityId, componentType: StaticBatchComponent.self) {
                return true
            }
            // Check children recursively
            let children = getEntityChildren(parentId: entityId)
            for child in children {
                if hasStaticBatchInHierarchy(entityId: child) {
                    return true
                }
            }
            return false
        }

        // Only set the flag if true (leave as nil otherwise)
        if hasStaticBatchInHierarchy(entityId: entityId) {
            entityData.hasStaticBatchComponent = true
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

        // Check if this is an Asset Instance root
        if let assetInstanceComp = scene.get(component: AssetInstanceComponent.self, for: entityId) {
            // Collect overrides from derived descendants
            var overrides: [AssetOverrideData] = []
            let children = getEntityChildren(parentId: entityId)

            for childId in children {
                if let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) {
                    // Only collect overrides if the derived node belongs to this asset instance
                    if derivedComp.assetRootEntityId == entityId {
                        // MVP: always serialize derived node state (we don't track "initial" values yet)
                        let transformOverride = LocalTransformOverrideData(
                            position: getLocalPosition(entityId: childId),
                            scale: getScale(entityId: childId),
                            axisOfRotations: getAxisRotations(entityId: childId)
                        )

                        var materialOverride: MaterialData? = nil
                        if hasComponent(entityId: childId, componentType: RenderComponent.self) {
                            let baseColor = getMaterialBaseColor(entityId: childId)
                            let roughness = getMaterialRoughness(entityId: childId)
                            let metallic = getMaterialMetallic(entityId: childId)
                            let emissive = getMaterialEmmissive(entityId: childId)
                            materialOverride = MaterialData(
                                baseColorValue: baseColor,
                                emissiveValue: emissive,
                                roughnessValue: roughness,
                                metallicValue: metallic
                            )
                        }

                        let visibilityOverride: Bool? = nil // TODO: track visibility if needed

                        let entityName = getEntityName(entityId: childId)

                        let override = AssetOverrideData(
                            nodePath: derivedComp.nodePath,
                            transform: transformOverride,
                            material: materialOverride,
                            visibility: visibilityOverride,
                            name: entityName
                        )
                        overrides.append(override)
                    }
                }
            }

            entityData.assetInstance = AssetInstanceData(
                assetURL: assetInstanceComp.assetURL,
                assetName: assetInstanceComp.assetName,
                importMode: assetInstanceComp.importMode,
                rootPrimPath: assetInstanceComp.rootPrimPath,
                overrides: overrides
            )

            Logger.log(message: "[SceneSerializer] Asset instance '\(entityData.name)' serialized with \(overrides.count) overrides")
        }

        sceneData.entities.append(entityData)
    }

    // Only serialize environment data if IBL is actually being used
    if applyIBL || renderEnvironment {
        // Validate that HDR file actually exists if IBL is enabled
        var validatedHDR: String? = hdrURL
        var shouldApplyIBL = applyIBL

        if applyIBL, !hdrURL.isEmpty {
            var hdrExists = false

            // Check in user's asset base path (HDR folder)
            if let basePath = assetBasePath {
                let hdrPath = basePath.appendingPathComponent("HDR").appendingPathComponent(hdrURL)
                hdrExists = FileManager.default.fileExists(atPath: hdrPath.path)

                if !hdrExists {
                    Logger.logWarning(message: "[SceneSerializer] HDR file not found in assets: \(hdrURL), disabling IBL")
                    validatedHDR = nil
                    shouldApplyIBL = false
                }
            } else {
                // No asset base path set, can't validate
                Logger.logWarning(message: "[SceneSerializer] No asset base path set, cannot validate HDR")
                validatedHDR = nil
                shouldApplyIBL = false
            }
        }

        // Only serialize if we still have a valid configuration
        if shouldApplyIBL, renderEnvironment {
            sceneData.environment = EnvironmentData(
                applyIBL: shouldApplyIBL,
                renderEnvironment: renderEnvironment,
                hdr: validatedHDR,
                ambientIntensity: ambientIntensity
            )
        }
    }

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

public func loadGameScene(from url: URL) -> SceneData? {
    // Ensure it's a file URL
    guard url.isFileURL else {
        Logger.log(message: "Invalid URL: must be a file URL")
        return nil
    }

    // Check if file exists and is readable
    guard FileManager.default.isReadableFile(atPath: url.path) else {
        Logger.log(message: "File not accesible or doesn't exist: \(url.path)")
        return nil
    }

    do {
        let data = try Data(contentsOf: url)
        let scene = try JSONDecoder().decode(SceneData.self, from: data)
        Logger.log(message: "Scene loaded from \(url.path)")
        return scene
    } catch {
        Logger.log(message: "Failed to load scene: \(error)")
        return nil
    }
}

public enum MeshLoadingMode {
    case asyncDefault
    case sync
}

public func deserializeScene(sceneData: SceneData, meshLoadingMode: MeshLoadingMode = .asyncDefault) {
    var uuidToEntityMap: [UUID: EntityID] = [:]

    if let env = sceneData.environment {
        applyIBL = env.applyIBL ?? false
        renderEnvironment = env.renderEnvironment ?? false
        ambientIntensity = env.ambientIntensity ?? 0.44

        // Only generate HDR if IBL is explicitly enabled and HDR is specified
        if applyIBL, let hdr = env.hdr, !hdr.isEmpty {
            hdrURL = hdr
            generateHDR(hdrURL)
        }
    }

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
        let applyLocalTransform = {
            if sceneDataEntity.hasLocalTransformComponent == true {
                translateTo(entityId: entityId, position: sceneDataEntity.position)
                scaleTo(entityId: entityId, scale: sceneDataEntity.scale)
                let axisOfRotation = sceneDataEntity.axisOfRotations

                applyAxisRotations(entityId: entityId, axis: axisOfRotation)
            }
        }

        uuidToEntityMap[sceneDataEntity.uuid] = entityId

        setEntityName(entityId: entityId, name: sceneDataEntity.name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)

        // Check for new Asset Instance system
        if let assetInstance = sceneDataEntity.assetInstance {
            // New asset instance workflow
            let filename = assetInstance.assetURL.deletingPathExtension().lastPathComponent
            let withExtension = assetInstance.assetURL.pathExtension

            // Apply parent entity's transform
            applyLocalTransform()

            switch meshLoadingMode {
            case .sync:
                setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension, assetName: nil)
                // Apply overrides synchronously after import
                applyAssetInstanceOverrides(entityId: entityId, overrides: assetInstance.overrides)

                // Restore Static Batch Component (sync mode - mesh already loaded)
                if sceneDataEntity.hasStaticBatchComponent == true {
                    setEntityStaticBatchComponent(entityId: entityId)
                }

                // Setup animations (skeleton is now available)
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
            case .asyncDefault:
                setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: nil) { success in
                    Task {
                        await MainActor.run {
                            if success {
                                Logger.log(message: "✅ Asset instance '\(sceneDataEntity.name)' loaded")
                                // Apply overrides after async import completes
                                applyAssetInstanceOverrides(entityId: entityId, overrides: assetInstance.overrides)

                                // Restore Static Batch Component (meshes now loaded)
                                if sceneDataEntity.hasStaticBatchComponent == true {
                                    setEntityStaticBatchComponent(entityId: entityId)
                                }

                                // Setup animations (skeleton is now available)
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
                            } else {
                                Logger.logWarning(message: "❌ Asset instance '\(sceneDataEntity.name)' failed to load")
                            }
                        }
                    }
                }
            }
        } else if sceneDataEntity.hasRenderingComponent == true {
            // Legacy rendering component workflow (backward compatibility)
            let filename = sceneDataEntity.assetURL.deletingPathExtension().lastPathComponent
            let withExtension = sceneDataEntity.assetURL.pathExtension
            let isProcedural = isProceduralAssetURL(sceneDataEntity.assetURL)
            switch meshLoadingMode {
            case .sync:
                if isProcedural {
                    let meshes = createProceduralMeshes(assetName: sceneDataEntity.assetName)
                    setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: sceneDataEntity.assetName)
                    applyLocalTransform()

                    // Restore Static Batch Component (procedural mesh already loaded)
                    if sceneDataEntity.hasStaticBatchComponent == true {
                        setEntityStaticBatchComponent(entityId: entityId)
                    }
                } else {
                    setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension, assetName: sceneDataEntity.assetName)
                    applyLocalTransform()

                    // Restore Static Batch Component (sync mode - mesh already loaded)
                    if sceneDataEntity.hasStaticBatchComponent == true {
                        setEntityStaticBatchComponent(entityId: entityId)
                    }
                }

                // Setup animations (skeleton is now available)
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
            case .asyncDefault:
                if isProcedural {
                    let meshes = createProceduralMeshes(assetName: sceneDataEntity.assetName)
                    setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: sceneDataEntity.assetName)
                    applyLocalTransform()

                    // Restore Static Batch Component (procedural mesh already loaded)
                    if sceneDataEntity.hasStaticBatchComponent == true {
                        setEntityStaticBatchComponent(entityId: entityId)
                    }
                } else {
                    let fallbackLabel = withExtension.isEmpty ? filename : "\(filename).\(withExtension)"
                    let meshLabel = sceneDataEntity.name.isEmpty ? fallbackLabel : sceneDataEntity.name
                    setEntityMeshAsync(entityId: entityId, filename: filename, withExtension: withExtension, assetName: sceneDataEntity.assetName) { success in
                        Task {
                            await MainActor.run {
                                applyLocalTransform()
                                if success {
                                    Logger.log(message: "✅ Mesh loaded for \(meshLabel)")

                                    // Restore Static Batch Component (mesh now loaded)
                                    if sceneDataEntity.hasStaticBatchComponent == true {
                                        setEntityStaticBatchComponent(entityId: entityId)
                                    }

                                    // Setup animations (skeleton is now available)
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
                                } else {
                                    Logger.logWarning(message: "❌ Mesh failed for \(meshLabel)")
                                }
                            }
                        }
                    }
                }
            }

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

        // Animation setup is now handled inside mesh loading completion handlers
        // (for asset instances and rendering components) to ensure skeleton component is available.
        // For entities without meshes (cameras, lights, empty parents), animations wouldn't apply anyway
        // since they require a skeleton, which comes from mesh loading.
        //
        // Note: For multi-mesh assets, the skeleton is on child entities, not the parent.
        // If sceneDataEntity has hasAnimationComponent but is a multi-mesh parent, the animations
        // should actually be applied to the specific child entity that has the skeleton.

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

        if sceneDataEntity.assetInstance == nil, sceneDataEntity.hasRenderingComponent != true {
            applyLocalTransform()
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

        // LOD Component
        if sceneDataEntity.hasLODComponent == true {
            if let lodData = sceneDataEntity.lodData {
                switch meshLoadingMode {
                case .sync:
                    // Synchronous LOD loading not yet implemented
                    Logger.logWarning(message: "[SceneSerializer] Synchronous LOD loading not supported, skipping LOD for '\(sceneDataEntity.name)'")
                case .asyncDefault:
                    // Register LOD component first
                    setEntityLodComponent(entityId: entityId)

                    // Track completion
                    var loadedCount = 0
                    let totalLevels = lodData.lodLevels.count

                    // Load each LOD level using the granular API
                    for (index, lodLevelData) in lodData.lodLevels.enumerated() {
                        let url = lodLevelData.url
                        let filename = url.deletingPathExtension().lastPathComponent
                        let ext = url.pathExtension
                        let maxDistance = lodLevelData.maxDistance

                        addLODLevel(
                            entityId: entityId,
                            lodIndex: index,
                            fileName: filename,
                            withExtension: ext,
                            maxDistance: maxDistance
                        ) { success in
                            if success {
                                loadedCount += 1
                                // When all levels are loaded, restore LOD settings
                                if loadedCount == totalLevels {
                                    Logger.log(message: "✅ LOD loaded for '\(sceneDataEntity.name)' with \(totalLevels) levels")
                                    Task {
                                        await MainActor.run {
                                            if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
                                                lodComponent.currentLOD = lodData.currentLOD
                                                lodComponent.fadeTransition = lodData.fadeTransition
                                                lodComponent.transitionDuration = lodData.transitionDuration
                                            }
                                        }
                                    }
                                }
                            } else {
                                Logger.logWarning(message: "⚠️ Failed to load LOD level \(index) for '\(sceneDataEntity.name)'")
                            }
                        }
                    }
                }
            }
        }

        // Static Batch Component is now restored inside mesh loading completion handlers
        // (moved there to ensure RenderComponent exists before adding StaticBatchComponent)

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

// Notification posted when asset instance has finished loading and overrides have been applied
public extension Notification.Name {
    static let assetInstanceDidLoad = Notification.Name("assetInstanceDidLoad")
}

/// Apply overrides to derived asset nodes after import completes
private func applyAssetInstanceOverrides(entityId: EntityID, overrides: [AssetOverrideData]) {
    // Build nodePath -> derived entity map
    var nodePathMap: [String: EntityID] = [:]
    let children = getEntityChildren(parentId: entityId)

    for childId in children {
        if let derivedComp = scene.get(component: DerivedAssetNodeComponent.self, for: childId) {
            nodePathMap[derivedComp.nodePath] = childId
        }
    }

    Logger.log(message: "[SceneSerializer] Applying \(overrides.count) overrides to asset instance (found \(nodePathMap.count) derived nodes)")

    var appliedCount = 0
    var failedCount = 0

    for override in overrides {
        guard let derivedEntityId = nodePathMap[override.nodePath] else {
            Logger.logWarning(message: "[SceneSerializer] Override nodePath '\(override.nodePath)' not found in asset instance")
            failedCount += 1
            continue
        }

        // Apply transform override
        if let transform = override.transform {
            if let position = transform.position {
                translateTo(entityId: derivedEntityId, position: position)
            }
            if let scale = transform.scale {
                scaleTo(entityId: derivedEntityId, scale: scale)
            }
            if let axisRotations = transform.axisOfRotations {
                applyAxisRotations(entityId: derivedEntityId, axis: axisRotations)
            }
        }

        // Apply material override
        if let material = override.material {
            if hasComponent(entityId: derivedEntityId, componentType: RenderComponent.self) {
                updateMaterialColor(entityId: derivedEntityId, color: colorFromSimd(material.baseColorValue))
                updateMaterialRoughness(entityId: derivedEntityId, roughness: material.roughnessValue)
                updateMaterialMetallic(entityId: derivedEntityId, metallic: material.metallicValue)
                updateMaterialEmmisive(entityId: derivedEntityId, emmissive: material.emissiveValue)

                if let baseColorURL = material.baseColorURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .baseColor, path: baseColorURL)
                }
                if let roughnessURL = material.roughnessURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .roughness, path: roughnessURL)
                }
                if let metallicURL = material.metallicURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .metallic, path: metallicURL)
                }
                if let normalURL = material.normalURL {
                    updateMaterialTexture(entityId: derivedEntityId, textureType: .normal, path: normalURL)
                }
            }
        }

        // Apply visibility override (if supported in the future)
        if let visibility = override.visibility {
            if let renderComp = scene.get(component: RenderComponent.self, for: derivedEntityId) {
                renderComp.isVisible = visibility
            }
        }

        // apply entity name override
        if let entityName = override.name {
            setEntityName(entityId: derivedEntityId, name: entityName)
        }

        appliedCount += 1
    }

    if failedCount > 0 {
        Logger.logWarning(message: "[SceneSerializer] Failed to apply \(failedCount) overrides (nodePath not found)")
    }
    if appliedCount > 0 {
        Logger.log(message: "[SceneSerializer] Successfully applied \(appliedCount) overrides")
    }

    // Post notification to inform UI that asset instance is fully loaded
    NotificationCenter.default.post(name: .assetInstanceDidLoad, object: entityId)
}
