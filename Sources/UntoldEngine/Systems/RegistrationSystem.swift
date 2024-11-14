
//
//  RegistrationSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 2/19/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import MetalKit

public func createEntity() -> EntityID {
    return scene.newEntity()
}

public func registerComponent<T: Component>(entityId: EntityID, componentType: T.Type) {
    _ = scene.assign(to: entityId, component: componentType)
}

public func destroyEntity(entityID: EntityID) {
    selectedModel = false

    var renderComponent = scene.get(component: RenderComponent.self, for: entityID)
    var transformComponent = scene.get(component: TransformComponent.self, for: entityID)
    renderComponent?.mesh = nil

    scene.remove(component: RenderComponent.self, from: entityID)
    scene.remove(component: TransformComponent.self, from: entityID)

    renderComponent = nil
    transformComponent = nil

    if scene.get(component: LightComponent.self, for: entityID) != nil {
        lightingSystem.removeLight(entityID: entityID)
        scene.remove(component: LightComponent.self, from: entityID)
    }

    scene.destroyEntity(entityID)
}

public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String){
    
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        print("Unable to find file \(filename)")
        return
    }
    
    var meshes = [Mesh]()

    meshes = Mesh.loadMeshes(
        url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device
    )

    meshDictionary[meshes.first!.name] = meshes.first
    
    if meshes.count > 1 {
        print("several models found in file \(filename). Only the first model will be linked to entity")
    }
    
    registerDefaultComponents(entityId: entityId, name: meshes.first!.name)
    
    // look for any skeletons in asset
    setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
    
}

public func setEntitySkeleton(entityId: EntityID, filename: String, withExtension: String){
 
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        print("Unable to find file \(filename)")
        return
    }
    
    let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
    
    let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor.model, bufferAllocator: bufferAllocator)
    
    let skeletons =
      asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton] ?? []
    
    if skeletons.first == nil{
        
        print("no skeleton found in asset")
        
        return
        
    }
    
    let skeleton:Skeleton = Skeleton(mdlSkeleton: skeletons.first)!
    
    // register Skeleton Component
    registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
    
    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        print("Entity does not have a Skeleton Component. Please add one if required")
        return
    }
    
    skeletonComponent.skeleton=skeleton
    
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        print("Entity does not have a Render Component.")
        return
    }
    
    setEntitySkin(entityId: entityId, mdlMesh: renderComponent.mesh.modelMDLMesh)
}

public func setEntitySkin(entityId: EntityID, mdlMesh: MDLMesh){
    
    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        print("Entity does not have a Skeleton Component. Please add one")
        return
    }
    
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        print("Entity does not have a Render Component. Please add one")
        return
    }
    
    //for index in 0..<mdlMeshes.count{
    let animationBindComponent=mdlMesh.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent

    let skin=Skin(bindComponent: animationBindComponent, skeleton: skeletonComponent.skeleton)

    renderComponent.mesh.skin = skin

    //}
    
}

// register Render and Transform components

func registerDefaultComponents(entityId: EntityID, name: String) {
    if let meshValue = meshDictionary[name] {
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: TransformComponent.self)

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            print("Entity does not have a Render Component. Please add one")
            return
        }

        guard let transformComponent = scene.get(component: TransformComponent.self, for: entityId) else {
            print("Entity does not have a Transform Component. Please add one")
            return
        }

        renderComponent.mesh = meshValue

        transformComponent.localSpace = meshValue.localSpace
        transformComponent.maxBox = meshValue.maxBox
        transformComponent.minBox = meshValue.minBox

    } else {
        print("asset not found in list")
    }
}
