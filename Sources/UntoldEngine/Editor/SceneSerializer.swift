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
    var type: String = "directional"
    var color: simd_float3 = .one
    var attenuation: simd_float3 = .zero
    var radius: Float = 1.0
    var intensity: Float = 1.0
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
    var hasLightComponent: Bool?
    var hasCameraComponent: Bool?

    var customComponents: [String: Data]? = nil
}

func serializeScene() -> SceneData {
    var sceneData = SceneData()

    for entityId in getAllGameEntities() {
        var entityData = EntityData()

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

        // Light properties
        let hasLight: Bool = hasComponent(entityId: entityId, componentType: LightComponent.self)

        if hasLight {
            entityData.hasLightComponent = hasLight

            entityData.lightData = LightData()

            entityData.lightData?.type = getLightType(entityId: entityId)

            entityData.lightData?.color = getLightColor(entityId: entityId)

            entityData.lightData?.radius = getLightRadius(entityId: entityId)

            entityData.lightData?.intensity = getLightIntensity(entityId: entityId)

            entityData.lightData?.attenuation = getLightAttenuation(entityId: entityId)
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

        setEntityName(entityId: entityId, name: sceneDataEntity.name)
        registerTransformComponent(entityId: entityId)
        registerSceneGraphComponent(entityId: entityId)
        if sceneDataEntity.hasRenderingComponent == true {
            let filename = sceneDataEntity.assetURL.deletingPathExtension().lastPathComponent
            let withExtension = sceneDataEntity.assetURL.pathExtension
            setEntityMesh(entityId: entityId, filename: filename, withExtension: withExtension)
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

        if sceneDataEntity.hasLightComponent == true {
            if let light = sceneDataEntity.lightData {
                let type: String = light.type
                let color: simd_float3 = light.color
                let attenuation: simd_float3 = light.attenuation
                let radius: Float = light.radius
                let intensity: Float = light.intensity

                createLight(entityId: entityId, lightType: type)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
                    handleError(.noLightComponent)
                    continue
                }

                lightComponent.color = color
                lightComponent.radius = radius
                lightComponent.intensity = intensity
                lightComponent.attenuation = simd_float4(attenuation.x, attenuation.y, attenuation.z, 1.0)
            }
        }
        if sceneDataEntity.hasLocalTransformComponent == true {
            translateTo(entityId: entityId, position: sceneDataEntity.position)

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
}
