
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

public func destroyEntity(entityId: EntityID) {

    scene.destroyEntity(entityId)
}

public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String, flip: Bool = true) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        handleError(.filenameNotFound, filename)
        return
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return
    }

    var meshes = [Mesh]()

    meshes = Mesh.loadMeshes(
        url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, flip: flip
    )

    if meshes.isEmpty {
        handleError(.assetDataMissing, filename)
        return
    }

    meshDictionary[meshes.first!.name] = meshes.first

    if meshes.count > 1 {
        print("several models found in file \(filename). Only the first model will be linked to entity")
    }

    registerDefaultComponents(entityId: entityId, name: meshes.first!.name)

    // look for any skeletons in asset
    setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
}

public func setEntitySkeleton(entityId: EntityID, filename: String, withExtension: String) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        handleError(.filenameNotFound, filename)
        return
    }

    let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

    let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor.model, bufferAllocator: bufferAllocator)

    let skeletons =
        asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton] ?? []

    if skeletons.first == nil {
        
        let skin = Skin()
        
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }
        
        renderComponent.mesh.skin = skin
        
        return
    }

    let skeleton = Skeleton(mdlSkeleton: skeletons.first)!

    // register Skeleton Component
    registerComponent(entityId: entityId, componentType: SkeletonComponent.self)

    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        handleError(.noSkeletonComponent, entityId)
        return
    }

    skeletonComponent.skeleton = skeleton

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    setEntitySkin(entityId: entityId, mdlMesh: renderComponent.mesh.modelMDLMesh)
}

public func setEntitySkin(entityId: EntityID, mdlMesh: MDLMesh) {
    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        handleError(.noSkeletonComponent, entityId)
        return
    }

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    let animationBindComponent = mdlMesh.componentConforming(to: MDLComponent.self) as? MDLAnimationBindComponent

    let skin = Skin(animationBindComponent: animationBindComponent, skeleton: skeletonComponent.skeleton)

    // update the buffer with rest pose
    skeletonComponent.skeleton.resetPoseToRest()

    skin?.updateJointMatrices(skeleton: skeletonComponent.skeleton)

    renderComponent.mesh.skin = skin
}

public func setEntityAnimations(entityId: EntityID, filename: String, withExtension: String, name: String) {
    // Helper function to add animation clips
    func addClips(to animationComponent: AnimationComponent) {
        for assetAnimation in assetAnimations {
            let animationClip = AnimationClip(animation: assetAnimation, animationName: name)
            animationComponent.animationClips[name] = animationClip
        }
    }

    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        handleError(.filenameNotFound, filename)
        return
    }

    let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

    let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor.model, bufferAllocator: bufferAllocator)

    let assetAnimations = asset.animations.objects.compactMap {
        $0 as? MDLPackedJointAnimation
    }

    if assetAnimations.isEmpty {
        handleError(.assetHasNoAnimation, filename)
        return
    }

    if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
        addClips(to: animationComponent)

        return
    }

    // register Skeleton Component
    registerComponent(entityId: entityId, componentType: AnimationComponent.self)

    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    addClips(to: animationComponent)
}

public func setEntityKinetics(entityId: EntityID) {
    if let _ = scene.get(component: PhysicsComponents.self, for: entityId) {
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
    } else {
        // Components doesn't exist, create and register it
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
    }
}

// register Render and Transform components

func registerDefaultComponents(entityId: EntityID, name: String) {
    if let meshValue = meshDictionary[name] {
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: TransformComponent.self)

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }

        guard let transformComponent = scene.get(component: TransformComponent.self, for: entityId) else {
            handleError(.noTransformComponent, entityId)
            return
        }

        renderComponent.mesh = meshValue

        transformComponent.localSpace = meshValue.localSpace
        transformComponent.maxBox = meshValue.maxBox
        transformComponent.minBox = meshValue.minBox
        transformComponent.flipCoord = meshValue.flipCoord
        entityDictionary[entityId] = name

    } else {
        print("asset not found in list")
    }
}
