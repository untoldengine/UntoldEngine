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
    var name: String = ""
    var meshFileName: URL = .init(fileURLWithPath: "")
    var position: simd_float3 = .zero
    var eulerRotation: simd_float3 = .zero
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
}

func serializeScene() -> SceneData {
    var sceneData = SceneData()

    for entityId in getAllGameEntities() {
        guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entityId) else {
            handleError(.noInEditorComponent, entityId)
            continue
        }

        var entityData = EntityData()

        entityData.name = getEntityName(entityId: entityId)!

        // Rendering properties
        let meshPath: URL = inEditorComponent.meshFilename

        entityData.meshFileName = meshPath

        entityData.hasRenderingComponent = hasComponent(entityId: entityId, componentType: RenderComponent.self)

        // Transform properties
        entityData.position = inEditorComponent.position

        let eulerRotation = inEditorComponent.orientation

        entityData.eulerRotation = simd_float3(eulerRotation.x, eulerRotation.y, eulerRotation.z)

        entityData.hasLocalTransformComponent = hasComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        // Animation properties
        entityData.animations = inEditorComponent.animationsFilenames

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

        sceneData.entities.append(entityData)
    }

    // load environment data
    sceneData.environment = EnvironmentData()

    sceneData.environment?.hdr = hdrURL
    sceneData.environment?.ambientIntensity = ambientIntensity
    sceneData.environment?.applyIBL = applyIBL
    sceneData.environment?.renderEnvironment = renderEnvironment

    return sceneData
}

@available(macOS 13.0, *)
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

@available(macOS 13.0, *)
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

    for sceneDataEntity in sceneData.entities {
        let entity = createEntity()

        registerComponent(entityId: entity, componentType: InEditorComponent.self)

        guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entity) else {
            handleError(.noInEditorComponent)
            continue
        }

        inEditorComponent.meshFilename = sceneDataEntity.meshFileName
        inEditorComponent.animationsFilenames = sceneDataEntity.animations

        setEntityName(entityId: entity, name: sceneDataEntity.name)

        if sceneDataEntity.hasRenderingComponent == true {
            let meshFileName = sceneDataEntity.meshFileName.deletingPathExtension().lastPathComponent
            let meshFileNameExt = sceneDataEntity.meshFileName.pathExtension

            setEntityMesh(entityId: entity, filename: meshFileName, withExtension: meshFileNameExt)
        }

        if sceneDataEntity.hasAnimationComponent == true {
            for animations in sceneDataEntity.animations {
                let animationFilename = animations.deletingPathExtension().lastPathComponent
                let animationFilenameExt = animations.pathExtension

                setEntityAnimations(entityId: entity, filename: animationFilename, withExtension: animationFilenameExt, name: animationFilename)

                changeAnimation(entityId: entity, name: animationFilename)
            }
        }

        if sceneDataEntity.hasKineticComponent == true {
            setEntityKinetics(entityId: entity)

            guard let physicsComponent = scene.get(component: PhysicsComponents.self, for: entity) else {
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

                createLight(entityId: entity, lightType: type)

                guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
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
            inEditorComponent.position = sceneDataEntity.position
            inEditorComponent.orientation = sceneDataEntity.eulerRotation

            translateTo(entityId: entity, position: sceneDataEntity.position)

            let euler = sceneDataEntity.eulerRotation

            rotateTo(entityId: entity, pitch: euler.x, yaw: euler.y, roll: euler.z)
        }

        if sceneDataEntity.hasCameraComponent == true {
            if let camera = sceneDataEntity.cameraData {
                let eye = camera.eye
                let target = camera.target
                let up = camera.up

                createGameCamera(entityId: entity)

                guard let cameraComponent = scene.get(component: CameraComponent.self, for: entity) else {
                    handleError(.noGameCamera)
                    continue
                }

                cameraComponent.eye = eye
                cameraComponent.target = target
                cameraComponent.up = up

                cameraLookAt(entityId: entity, eye: eye, target: target, up: up)
            }
        }
    }
}
