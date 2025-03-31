
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
    globalEntityCounter += 1
    return scene.newEntity()
}

public func registerComponent(entityId: EntityID, componentType: (some Component).Type) {
    _ = scene.assign(to: entityId, component: componentType)
}

public func destroyEntity(entityId: EntityID) {
    // Remove any resources linked to entity
    removeEntityMesh(entityId: entityId)
    removeEntityTransforms(entityId: entityId)
    removeEntityAnimations(entityId: entityId)
    removeEntityKinetics(entityId: entityId)
    removeEntityScenegraph(entityId: entityId)
    removeEntityName(entityId: entityId)
    removeEntityLight(entityId: entityId)
    scene.destroyEntity(entityId)
}

public func destroyAllEntities() {
    for entity in scene.getAllEntities() {
        // scene camera should not be destroyed
        if hasComponent(entityId: entity, componentType: SceneCameraComponent.self) {
            continue
        }

        destroyEntity(entityId: entity)
        globalEntityCounter = 0
    }
}

private func setEntityMeshCommon(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    flip _: Bool,
    meshLoader: (URL) -> [Mesh],
    entityName _: String?
) {
    guard let url = getResourceURL(forResource: filename, withExtension: withExtension) else {
        handleError(.filenameNotFound, filename)
        return
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return
    }

    let meshes = meshLoader(url)

    if meshes.isEmpty {
        handleError(.assetDataMissing, filename)
        return
    }

    associateMeshesToEntity(entityId: entityId, meshes: meshes)
    registerRenderComponent(entityId: entityId, meshes: meshes, url: url, assetName: meshes.first!.assetName)
    setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
}

public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String, flip: Bool = true) {
    setEntityMeshCommon(
        entityId: entityId,
        filename: filename,
        withExtension: withExtension,
        flip: flip,
        meshLoader: { url in
            Mesh.loadMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, flip: flip)
        },
        entityName: nil
    )
}

public func setEntityMesh(entityId: EntityID, fromAssetNamed: String, filename: String, withExtension: String, flip: Bool = true) {
    setEntityMeshCommon(
        entityId: entityId,
        filename: filename,
        withExtension: withExtension,
        flip: flip,
        meshLoader: { url in
            Mesh.loadMeshWithName(name: fromAssetNamed, url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)
        },
        entityName: fromAssetNamed
    )
}

public func loadScene(filename: String, withExtension: String) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        handleError(.filenameNotFound, filename)
        return
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return
    }

    var meshes = [[Mesh]]()

    meshes = Mesh.loadSceneMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

    if meshes.isEmpty {
        handleError(.assetDataMissing, filename)
        return
    }

    for mesh in meshes {
        if mesh.count > 0 {
            let entityId = createEntity()

            associateMeshesToEntity(entityId: entityId, meshes: mesh)

            registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)

            if let assetName = getAssetName(entityId: entityId) {
                setEntityName(entityId: entityId, name: assetName)
            }

            // look for any skeletons in asset
            setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
        }
    }
}

func removeEntityMesh(entityId: EntityID) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent)
        return
    }

    renderComponent.cleanUp()
    scene.remove(component: RenderComponent.self, from: entityId)

    // deassocate entity to mesh
    deassociateMeshesToEntity(entityId: entityId)

    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        handleError(.noSkeletonComponent)
        return
    }

    skeletonComponent.cleanUp()
    scene.remove(component: SkeletonComponent.self, from: entityId)
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
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }

        let skin = Skin()

        for index in renderComponent.mesh.indices {
            renderComponent.mesh[index].skin = skin
        }

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

    for mesh in renderComponent.mesh {
        setEntitySkin(entityId: entityId, mdlMesh: mesh.modelMDLMesh)
    }
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

    // Assign skin to mesh
    for index in renderComponent.mesh.indices where renderComponent.mesh[index].modelMDLMesh == mdlMesh {
        renderComponent.mesh[index].skin = skin
    }
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

func removeEntityAnimations(entityId: EntityID) {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, entityId)
        return
    }

    animationComponent.cleanUp()
    scene.remove(component: AnimationComponent.self, from: entityId)
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

func removeEntityKinetics(entityId: EntityID) {
    guard let kineticComponent = scene.get(component: KineticComponent.self, for: entityId) else {
        handleError(.noKineticComponent, entityId)
        return
    }

    kineticComponent.clearForces()
    scene.remove(component: KineticComponent.self, from: entityId)
    scene.remove(component: PhysicsComponents.self, from: entityId)
}

func removeEntityLight(entityId: EntityID) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent, entityId)
        return
    }

    scene.remove(component: LightComponent.self, from: entityId)
}

func removeEntityScenegraph(entityId: EntityID) {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        handleError(.noScenegraphComponent)
        return
    }

    let childrenId = scenegraphComponent.children

    for childId in childrenId {
        removeEntityScenegraph(entityId: childId)
    }

    // we need to unlink parent from main entity
    if scenegraphComponent.parent != .invalid {
        // get the parent for the entity
        guard let parentScenegraphComponent = scene.get(component: ScenegraphComponent.self, for: scenegraphComponent.parent) else {
            handleError(.noScenegraphComponent)
            return
        }

        // remove entity from parent's list
        parentScenegraphComponent.children.removeAll { $0 == entityId }
    }

    scenegraphComponent.children.removeAll()
    scenegraphComponent.parent = .invalid
    scenegraphComponent.level = 0
    scene.remove(component: ScenegraphComponent.self, from: entityId)
}

func registerTransformComponent(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
    registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
}

func registerSceneGraphComponent(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
}

func removeEntityTransforms(entityId: EntityID) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    scene.remove(component: LocalTransformComponent.self, from: entityId)

    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return
    }

    scene.remove(component: WorldTransformComponent.self, from: entityId)
}

func registerRenderComponent(entityId: EntityID, meshes: [Mesh], url: URL, assetName: String) {
    registerComponent(entityId: entityId, componentType: RenderComponent.self)

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    guard let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    renderComponent.mesh = meshes
    renderComponent.assetName = assetName
    renderComponent.assetURL = url
    entityMeshMap[entityId] = meshes

    let boundingBox = Mesh.computeMeshBoundingBox(for: meshes)

    transformComponent.space = meshes[0].worldSpace
    transformComponent.boundingBox = boundingBox
    transformComponent.flipCoord = meshes[0].flipCoord

    transformComponent.tempPosition = getLocalPosition(entityId: entityId)
    let euler = getLocalOrientationEuler(entityId: entityId)
    transformComponent.tempOrientation = simd_float3(euler.pitch, euler.yaw, euler.roll)
}

func associateMeshesToEntity(entityId: EntityID, meshes: [Mesh]) {
    entityMeshMap[entityId] = meshes
}

func deassociateMeshesToEntity(entityId: EntityID) {
    entityMeshMap.removeValue(forKey: entityId)
}

func getMeshesForEntity(entityId: EntityID) -> [Mesh]? {
    entityMeshMap[entityId]
}

public func setEntityName(entityId: EntityID, name: String) {
    entityNameMap[entityId] = name
    reverseEntityNameMap[name] = entityId
}

public func getEntityName(entityId: EntityID) -> String? {
    entityNameMap[entityId]
}

func removeEntityName(entityId: EntityID) {
    if let name: String = getEntityName(entityId: entityId) {
        reverseEntityNameMap.removeValue(forKey: name)
    }

    entityNameMap.removeValue(forKey: entityId)
}

public func findEntity(name: String) -> EntityID? {
    reverseEntityNameMap[name]
}
