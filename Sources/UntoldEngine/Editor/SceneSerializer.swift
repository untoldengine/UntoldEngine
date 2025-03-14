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
}

struct LightData: Codable {
    var type: String = "directional"
    var color: simd_float3 = .one
    var attenuation: simd_float3 = .zero
    var radius: Float = 1.0
    var intensity: Float = 1.0
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
    var hasRenderingComponent: Bool = false
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
    var hasLightComponent: Bool = false
}

func serializeScene() -> SceneData {
    var sceneData = SceneData()

    for entityId in scene.getAllEntities() {
        guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entityId) else {
            continue
        }

        var entityData = EntityData()

        entityData.name = getEntityName(entityId: entityId)!

        // Rendering properties
        let meshPath: URL = inEditorComponent.meshFilename

        entityData.meshFileName = meshPath

        entityData.hasRenderingComponent = hasComponent(entityId: entityId, componentType: RenderComponent.self)

        // Transform properties
        entityData.position = getLocalPosition(entityId: entityId)

        let eulerRotation = getLocalOrientationEuler(entityId: entityId)
        entityData.eulerRotation = simd_float3(eulerRotation.pitch, eulerRotation.yaw, eulerRotation.roll)

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

        sceneData.entities.append(entityData)
    }

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
            translateTo(entityId: entity, position: sceneDataEntity.position)

            let euler = sceneDataEntity.eulerRotation

            rotateTo(entityId: entity, pitch: euler.x, yaw: euler.y, roll: euler.z)
        }
    }
}
