
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
    if entityId == .invalid {
        return
    }

    hasPendingDestroys = true
    scene.markDestroy(entityId)

    // if entity has children, then mark it to destroy

    let childrenId = getEntityChildren(parentId: entityId)
    for childId in childrenId {
        scene.markDestroy(childId)
    }
}

public func destroyAllEntities() {
    let toDestroy = scene.getAllEntities()

    for entity in toDestroy {
        destroyEntity(entityId: entity)
    }
}

func finalizePendingDestroys() {
    visibleEntityIds.removeAll()
    // clear any other systems from the entities

    // Gather marked entities from scene
    let pending: [EntityID] = scene.entities.enumerated().compactMap { _, e in (e.pendingDestroy && !e.freed) ? e.entityId : nil }

    // Clean up each entity
    for entityId in pending {
        removeEntityMesh(entityId: entityId)
        removeEntityTransforms(entityId: entityId)
        removeEntityAnimations(entityId: entityId)
        removeEntityKinetics(entityId: entityId)
        removeEntityScenegraph(entityId: entityId)
        removeEntityName(entityId: entityId)
        removeEntityLight(entityId: entityId)
    }

    scene.finalizePendingDestroys()
}

private func setEntityMeshCommon(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    flip _: Bool,
    meshLoader: (URL) -> [[Mesh]],
    entityName _: String?,
    assetName: String?
) {
    guard let url = getResourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
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

    var nonEmptyMeshes = meshes.filter { !$0.isEmpty }

    if let assetNameExist = assetName {
        if let matchedMesh = nonEmptyMeshes.first(where: { $0.first?.assetName == assetNameExist }) {
            nonEmptyMeshes = [matchedMesh]
        } else {
            handleError(.assetDataMissing, "No mesh with asset name \(assetNameExist)")
            return
        }
    }

    if nonEmptyMeshes.count == 1 {
        let mesh = nonEmptyMeshes[0]

        if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
            registerTransformComponent(entityId: entityId)
        }

        if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
            registerSceneGraphComponent(entityId: entityId)
        }

        associateMeshesToEntity(entityId: entityId, meshes: mesh)
        registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)
        setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)

    } else if nonEmptyMeshes.count > 1 {
        for mesh in nonEmptyMeshes {
            let childEntityId = createEntity()

            if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
                registerTransformComponent(entityId: childEntityId)
            }

            if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
                registerSceneGraphComponent(entityId: childEntityId)
            }

            associateMeshesToEntity(entityId: childEntityId, meshes: mesh)

            registerRenderComponent(entityId: childEntityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)

            setEntityName(entityId: childEntityId, name: mesh.first!.assetName)

            setParent(childId: childEntityId, parentId: entityId)

            // look for any skeletons in asset
            setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)
        }
    }
}

public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String, assetName: String? = nil, flip: Bool = true) {
    setEntityMeshCommon(
        entityId: entityId,
        filename: filename,
        withExtension: withExtension,
        flip: flip,
        meshLoader: { url in
            Mesh.loadSceneMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)
        },
        entityName: nil,
        assetName: assetName
    )
}

public func loadScene(filename: String, withExtension: String) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
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

            if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
                registerTransformComponent(entityId: entityId)
            }

            if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
                registerSceneGraphComponent(entityId: entityId)
            }

            associateMeshesToEntity(entityId: entityId, meshes: mesh)

            registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)

            setEntityName(entityId: entityId, name: mesh.first!.assetName)

            // look for any skeletons in asset
            setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
        }
    }
}

func removeEntityMesh(entityId: EntityID) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    renderComponent.cleanUp()
    scene.remove(component: RenderComponent.self, from: entityId)

    // deassocate entity to mesh
    deassociateMeshesToEntity(entityId: entityId)

    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        return
    }

    skeletonComponent.cleanUp()
    scene.remove(component: SkeletonComponent.self, from: entityId)
}

public func setEntitySkeleton(entityId: EntityID, filename: String, withExtension: String) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
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
    guard scene.get(component: SkeletonComponent.self, for: entityId) != nil else {
        handleError(.noSkeletonComponent, entityId)
        return
    }

    // Helper function to add animation clips
    func addClips(to animationComponent: AnimationComponent) {
        for assetAnimation in assetAnimations {
            let animationClip = AnimationClip(animation: assetAnimation, animationName: name)
            animationComponent.animationClips[name] = animationClip
        }
    }

    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
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
        return
    }

    kineticComponent.clearForces()
    scene.remove(component: KineticComponent.self, from: entityId)
    scene.remove(component: PhysicsComponents.self, from: entityId)
}

func removeEntityLight(entityId: EntityID) {
    guard scene.get(component: LightComponent.self, for: entityId) != nil else {
        return
    }

    scene.remove(component: LightComponent.self, from: entityId)
}

func removeEntityScenegraph(entityId: EntityID) {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        return
    }

    let childrenId = scenegraphComponent.children

    for childId in childrenId {
        destroyEntity(entityId: childId)
    }

    // we need to unlink parent from main entity
    if scenegraphComponent.parent != .invalid {
        // get the parent for the entity
        guard let parentScenegraphComponent = scene.get(component: ScenegraphComponent.self, for: scenegraphComponent.parent) else {
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
    guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
        return
    }

    scene.remove(component: LocalTransformComponent.self, from: entityId)

    guard scene.get(component: WorldTransformComponent.self, for: entityId) != nil else {
        return
    }

    scene.remove(component: WorldTransformComponent.self, from: entityId)
}

func registerRenderComponent(entityId: EntityID, meshes: [Mesh], url: URL, assetName: String) {
    // check if a render component already exist. If so, remove it and clean up its mesh
    removeEntityMesh(entityId: entityId)

    registerComponent(entityId: entityId, componentType: RenderComponent.self)

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    renderComponent.mesh = meshes
    renderComponent.assetName = assetName
    renderComponent.assetURL = url
    entityMeshMap[entityId] = meshes

    let boundingBox = Mesh.computeMeshBoundingBox(for: meshes)

    localTransformComponent.position = simd_float3(meshes[0].worldSpace.columns.3.x, meshes[0].worldSpace.columns.3.y, meshes[0].worldSpace.columns.3.z)

    localTransformComponent.scale = .one

    localTransformComponent.rotation = transformMatrix3nToQuaternion(m: matrix3x3_upper_left(meshes[0].worldSpace))

    let euler = transformQuaternionToEulerAngles(q: localTransformComponent.rotation)

    localTransformComponent.rotationX = euler.pitch
    localTransformComponent.rotationY = euler.yaw
    localTransformComponent.rotationZ = euler.roll

    localTransformComponent.boundingBox = boundingBox
    localTransformComponent.flipCoord = meshes[0].flipCoord
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

public func getEntityName(entityId: EntityID) -> String {
    if let name = entityNameMap[entityId] {
        return name
    }
    return "Entity-\(entityId)"
}


func removeEntityName(entityId: EntityID) {
    if let stored = entityNameMap[entityId],
       stored.isEmpty == false {
        reverseEntityNameMap.removeValue(forKey: stored)
    }
    entityNameMap.removeValue(forKey: entityId)
}


public func findEntity(name: String) -> EntityID? {
    reverseEntityNameMap[name]
}

/*
 var customComponentEncoderMap: [ObjectIdentifier: (EntityID) -> Data?] = [:]
 var customComponentDecoderMap: [String: (EntityID, Data) -> Void] = [:]

 public func encodeCustomComponent<T: Component & Codable>(
     type: T.Type,
     merge: ((inout T, T) -> Void)? = nil
 ) {
     let encKey = ObjectIdentifier(type)
     let decKey = String(describing: type)

     customComponentEncoderMap[encKey] = { entityId in
         guard let c = scene.get(component: T.self, for: entityId) else { return nil }
         return try? JSONEncoder().encode(c)
     }

     customComponentDecoderMap[decKey] = { entityId, data in
         guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { return }

         if var existing = scene.assign(to: entityId, component: T.self) {
             if let merge = merge {
                 merge(&existing, decoded)  // partial update
             } else {
                 existing = decoded         // full replace
             }
         }
     }
 }
 */

var customComponentEncoderMap: [ObjectIdentifier: (EntityID) -> Data?] = [:]
var customComponentDecoderMap: [String: (EntityID, Data) -> Void] = [:]
var customComponentTypeNameById: [ObjectIdentifier: String] = [:]

public func encodeCustomComponent<T: Component & Codable>(
    type: T.Type,
    merge: ((inout T, T) -> Void)? = nil
) {
    let encKey = ObjectIdentifier(type)
    let decKey = String(describing: type)

    customComponentTypeNameById[encKey] = decKey

    customComponentEncoderMap[encKey] = { entityId in
        guard let c = scene.get(component: T.self, for: entityId) else { return nil }
        return try? JSONEncoder().encode(c)
    }

    customComponentDecoderMap[decKey] = { entityId, data in
        guard let decoded = try? JSONDecoder().decode(T.self, from: data) else { return }
        if var existing = scene.assign(to: entityId, component: T.self) {
            if let merge { merge(&existing, decoded) } else { existing = decoded }
        }
        // (Optional) If you still want editor visibility auto-restored:
        // EditorComponentsState.shared.components[entityId, default: [:]][encKey] = <your editor metadata>
    }
}

func loadRawMesh(
    name: String,
    filename: String,
    withExtension: String
) -> [Mesh] {
    guard let url = getResourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return []
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return []
    }

    let meshes = Mesh.loadMeshWithName(name: name, url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

    if meshes.isEmpty {
        handleError(.assetDataMissing, filename)
        return []
    }

    return meshes
}
