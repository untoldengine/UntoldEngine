//
//  SceneSerializer.swift
//
//
//  Created by Harold Serrano on 3/6/25.
//

import AppKit
import Foundation
import simd
import UniformTypeIdentifiers

struct SceneData: Codable {
    var entities: [EntityData] = []
    var environment: EnvironmentData? = nil
    var assetBasePath: URL? = nil
}

struct LightData: Codable {
    var color: simd_float3 = .one
    var radius: Float = 1.0
    var intensity: Float = 1.0
    var falloff: Float = 0.5
    var coneAngle: Float = 30.0
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
    var hasRenderingComponent: Bool = false
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
    var hasDirLightComponent: Bool?
    var hasPointLightComponent: Bool?
    var hasSpotLightComponent: Bool?
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

        entityData.name = getEntityName(entityId: entityId)!

        if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
            entityData.assetName = renderComponent.assetName

            entityData.assetURL = renderComponent.assetURL
        }

        // Rendering properties
        entityData.hasRenderingComponent = hasComponent(entityId: entityId, componentType: RenderComponent.self)

        // Transform properties
        if scene.get(component: LocalTransformComponent.self, for: entityId) != nil {
            entityData.position = getLocalPosition(entityId: entityId)

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
        for (key, editorComponent) in EditorComponentsState.shared.components[entityId] ?? [:] {
            if key == ObjectIdentifier(RenderComponent.self) ||
                key == ObjectIdentifier(LocalTransformComponent.self) ||
                key == ObjectIdentifier(AnimationComponent.self) ||
                key == ObjectIdentifier(LightComponent.self) ||
                key == ObjectIdentifier(CameraComponent.self) ||
                key == ObjectIdentifier(KineticComponent.self)
            {
                continue
            }

            if let serializeFunc = customComponentEncoderMap[key] {
                if let jsonData = serializeFunc(entityId) {
                    let typeName = String(describing: editorComponent.type)
                    customComponents[typeName] = jsonData
                }
            }
        }

        entityData.customComponents = customComponents

        sceneData.entities.append(entityData)
    }

    // load environment data
    sceneData.environment = EnvironmentData()

    sceneData.environment?.hdr = hdrURL
    sceneData.environment?.ambientIntensity = ambientIntensity
    sceneData.environment?.applyIBL = applyIBL
    sceneData.environment?.renderEnvironment = renderEnvironment

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

func loadScene() -> SceneData? {
    let openPanel = NSOpenPanel()
    openPanel.title = "Open Scene"
    openPanel.allowedContentTypes = [UTType.json]
    openPanel.allowsMultipleSelection = false

    if openPanel.runModal() == .OK, let url = openPanel.url {
        let decoder = JSONDecoder()

        do {
            let jsonData = try Data(contentsOf: url)
            let sceneData = try decoder.decode(SceneData.self, from: jsonData)
            print("Scene loaded from \(url.path)")
            return sceneData
        } catch {
            print("Failed to load scene: \(error)")
        }
    }

    return nil
}

func deserializeScene(sceneData: SceneData) {
    var uuidToEntityMap: [UUID: EntityID] = [:]

    if let env = sceneData.environment {
        applyIBL = env.applyIBL ?? false
        renderEnvironment = env.renderEnvironment ?? false
        ambientIntensity = env.ambientIntensity ?? 0.44

        hdrURL = env.hdr ?? "photostudio.hdr"
        generateHDR(hdrURL)
    }

    assetBasePath = sceneData.assetBasePath
    EditorAssetBasePath.shared.basePath = assetBasePath

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
            }
        }

        if sceneDataEntity.hasLocalTransformComponent == true {
            translateTo(entityId: entityId, position: sceneDataEntity.position)

            // TODO: Uncomment this section once the rotation is correct
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
