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

struct EntityData: Codable {
    var name: String = ""
    var meshFileName: URL = .init(fileURLWithPath: "")
    var position: simd_float3 = .zero
    var eulerRotation: simd_float3 = .zero
    var scale: simd_float3 = .one
    var animations: [URL] = []
    var mass: Float = .init(1.0)
    var hasRenderingComponent: Bool = false
    var hasAnimationComponent: Bool = false
    var hasLocalTransformComponent: Bool = false
    var hasKineticComponent: Bool = false
}

func serializeScene() -> SceneData {
    var sceneData = SceneData()

    for entity in scene.getAllEntities() {
        guard let inEditorComponent = scene.get(component: InEditorComponent.self, for: entity) else {
            continue
        }

        var entityData = EntityData()

        entityData.name = getEntityName(entityId: entity)!

        entityData.position = getLocalPosition(entityId: entity)
        let eulerRotation = getLocalOrientationEuler(entityId: entity)
        entityData.eulerRotation = simd_float3(eulerRotation.pitch, eulerRotation.yaw, eulerRotation.roll)

        entityData.mass = getMass(entityId: entity)

        let meshPath: URL = inEditorComponent.meshFilename

        entityData.meshFileName = meshPath

        entityData.animations = inEditorComponent.animationsFilenames

        entityData.hasRenderingComponent = hasComponent(entityId: entity, componentType: RenderComponent.self)

        entityData.hasLocalTransformComponent = hasComponent(entityId: entity, componentType: LocalTransformComponent.self)

        entityData.hasAnimationComponent = hasComponent(entityId: entity, componentType: AnimationComponent.self)

        entityData.hasKineticComponent = hasComponent(entityId: entity, componentType: KineticComponent.self)

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

        if sceneDataEntity.hasRenderingComponent == true {
            setEntityName(entityId: entity, name: sceneDataEntity.name)

            let meshFileName = sceneDataEntity.meshFileName.deletingPathExtension().lastPathComponent
            let meshFileNameExt = sceneDataEntity.meshFileName.pathExtension

            setEntityMesh(entityId: entity, filename: meshFileName, withExtension: meshFileNameExt)

            translateTo(entityId: entity, position: sceneDataEntity.position)

            let euler = sceneDataEntity.eulerRotation

            rotateTo(entityId: entity, pitch: euler.x, yaw: euler.y, roll: euler.z)
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
    }
}
