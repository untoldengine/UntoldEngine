
//
//  RegistrationSystem.swift
//  Untold Engine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import CShaderTypes
import Foundation
import MetalKit

public func createEntity() -> EntityID {
    globalEntityCounter += 1
    let entity = scene.newEntity()
    makeSpatial(entityId: entity) // attach LocalTransform, WorldTransform, Scenegraph
    return entity
}

public func makeSpatial(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
    registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
    registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
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
        removeEntityStaticBatch(entityId: entityId)
        removeEntityLOD(entityId: entityId)
        removeEntityGaussian(entityId: entityId)
        removeEntityCamera(entityId: entityId)
        removeEntityAssetInstance(entityId: entityId)
        removeEntityScript(entityId: entityId)
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
    guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
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
        // Multi-mesh asset: mark root as AssetInstance, children as DerivedAssetNode
        let assetInstanceComp = AssetInstanceComponent(
            assetURL: url,
            assetName: assetName ?? filename,
            importMode: "preserveHierarchy",
            rootPrimPath: nil
        )
        registerComponent(entityId: entityId, componentType: AssetInstanceComponent.self)
        if let instanceComp = scene.get(component: AssetInstanceComponent.self, for: entityId) {
            instanceComp.assetURL = assetInstanceComp.assetURL
            instanceComp.assetName = assetInstanceComp.assetName
            instanceComp.importMode = assetInstanceComp.importMode
            instanceComp.rootPrimPath = assetInstanceComp.rootPrimPath
        }

        for (index, mesh) in nonEmptyMeshes.enumerated() {
            let childEntityId = createEntity()

            if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
                registerTransformComponent(entityId: childEntityId)
            }

            if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
                registerSceneGraphComponent(entityId: childEntityId)
            }

            associateMeshesToEntity(entityId: childEntityId, meshes: mesh)

            registerRenderComponent(entityId: childEntityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)

            let meshAssetName = mesh.first!.assetName
            setEntityName(entityId: childEntityId, name: meshAssetName)

            setParent(childId: childEntityId, parentId: entityId)

            // Tag as derived node with stable nodePath
            let nodePath = generateStableNodePath(assetName: meshAssetName, index: index)
            let derivedComp = DerivedAssetNodeComponent(assetRootEntityId: entityId, nodePath: nodePath)
            registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
            if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
                derived.assetRootEntityId = derivedComp.assetRootEntityId
                derived.nodePath = derivedComp.nodePath
            }

            // look for any skeletons in asset
            setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)
        }
    }
}

/// Generate a stable node path for a derived mesh node
private func generateStableNodePath(assetName: String, index: Int) -> String {
    // Use a deterministic format: "Root/<AssetName>#<Index>"
    // This ensures the same USDZ file produces the same nodePath each time
    "Root/\(assetName)#\(index)"
}

public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String, assetName: String? = nil, flip: Bool = true, coordinateConversion: CoordinateSystemConversion = .autoDetect) {
    setEntityMeshCommon(
        entityId: entityId,
        filename: filename,
        withExtension: withExtension,
        flip: flip,
        meshLoader: { url in
            Mesh.loadSceneMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, coordinateConversion: coordinateConversion)
        },
        entityName: nil,
        assetName: assetName
    )
}

/// Asynchronously load and set entity mesh without blocking the main thread
public func setEntityMeshAsync(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    assetName: String? = nil,
    flip _: Bool = true,
    coordinateConversion: CoordinateSystemConversion = .autoDetect,
    completion: ((Bool) -> Void)? = nil
) {
    // Ensure entity has required components
    if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
        registerTransformComponent(entityId: entityId)
    }

    if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
        registerSceneGraphComponent(entityId: entityId)
    }

    Task {
        // Mark as loading
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: filename)

        // Get URL
        guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
            handleError(.filenameNotFound, filename)
            await loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            await MainActor.run {
                completion?(false)
            }
            return
        }

        if url.pathExtension == "dae" {
            handleError(.fileTypeNotSupported, url.pathExtension)
            await loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Load meshes asynchronously
        let meshes = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: coordinateConversion
        ) { current, total in
            Task {
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: current, totalMeshes: total)
            }
        }

        // Process on main thread - validate meshes first
        if meshes.isEmpty {
            handleError(.assetDataMissing, filename)
            await loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            await MainActor.run {
                completion?(false)
            }
            return
        }

        var nonEmptyMeshes = meshes.filter { !$0.isEmpty }

        if let assetNameExist = assetName {
            if let matchedMesh = nonEmptyMeshes.first(where: { $0.first?.assetName == assetNameExist }) {
                nonEmptyMeshes = [matchedMesh]
            } else {
                handleError(.assetDataMissing, "No mesh with asset name \(assetNameExist)")
                await loadFallbackMesh(entityId: entityId, filename: filename)
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                await MainActor.run {
                    completion?(false)
                }
                return
            }
        }

        // Register components in batches to avoid blocking
        // Update progress to show registration phase
        await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 0, totalMeshes: nonEmptyMeshes.count, phase: .registering)

        // Track entities being loaded to hide them during registration
        var loadingEntityIds: [EntityID] = [entityId]

        if nonEmptyMeshes.count == 1 {
            await MainActor.run {
                let mesh = nonEmptyMeshes[0]
                associateMeshesToEntity(entityId: entityId, meshes: mesh)
                registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)
                setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)

                // Hide during registration
                if let renderComp = scene.get(component: RenderComponent.self, for: entityId) {
                    renderComp.isVisible = false
                }
            }
            await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 1, totalMeshes: 1)
        } else if nonEmptyMeshes.count > 1 {
            // Multi-mesh asset: mark root as AssetInstance, children as DerivedAssetNode
            await MainActor.run {
                let assetInstanceComp = AssetInstanceComponent(
                    assetURL: url,
                    assetName: assetName ?? filename,
                    importMode: "preserveHierarchy",
                    rootPrimPath: nil
                )
                registerComponent(entityId: entityId, componentType: AssetInstanceComponent.self)
                if let instanceComp = scene.get(component: AssetInstanceComponent.self, for: entityId) {
                    instanceComp.assetURL = assetInstanceComp.assetURL
                    instanceComp.assetName = assetInstanceComp.assetName
                    instanceComp.importMode = assetInstanceComp.importMode
                    instanceComp.rootPrimPath = assetInstanceComp.rootPrimPath
                }
            }

            // Process mesh groups in batches to keep UI responsive
            let batchSize = 10 // Larger batches for registration (faster than mesh loading)
            for (index, mesh) in nonEmptyMeshes.enumerated() {
                let childEntityId = await MainActor.run { () -> EntityID in
                    let childEntityId = createEntity()

                    if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
                        registerTransformComponent(entityId: childEntityId)
                    }

                    if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
                        registerSceneGraphComponent(entityId: childEntityId)
                    }

                    associateMeshesToEntity(entityId: childEntityId, meshes: mesh)
                    registerRenderComponent(entityId: childEntityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)

                    let meshAssetName = mesh.first!.assetName
                    setEntityName(entityId: childEntityId, name: meshAssetName)
                    setParent(childId: childEntityId, parentId: entityId)

                    // Tag as derived node with stable nodePath
                    let nodePath = generateStableNodePath(assetName: meshAssetName, index: index)
                    let derivedComp = DerivedAssetNodeComponent(assetRootEntityId: entityId, nodePath: nodePath)
                    registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
                    if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
                        derived.assetRootEntityId = derivedComp.assetRootEntityId
                        derived.nodePath = derivedComp.nodePath
                    }

                    setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)

                    // Hide during registration
                    if let renderComp = scene.get(component: RenderComponent.self, for: childEntityId) {
                        renderComp.isVisible = false
                    }

                    return childEntityId
                }

                // Add child to loading set
                loadingEntityIds.append(childEntityId)

                // Update registration progress
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: index + 1, totalMeshes: nonEmptyMeshes.count)

                // Yield after each batch
                if (index + 1) % batchSize == 0 {
                    try? await Task.sleep(nanoseconds: 8_000_000) // 8ms (faster than mesh loading)
                }
            }
        }

        // Mark all entities as visible now that registration is complete
        await MainActor.run {
            for id in loadingEntityIds {
                if let renderComp = scene.get(component: RenderComponent.self, for: id) {
                    renderComp.isVisible = true
                }
            }
        }

        await AssetLoadingState.shared.finishLoading(entityId: entityId)
        await MainActor.run {
            completion?(true)
        }
    }
}

/// Load a fallback cube mesh when async loading fails
private func loadFallbackMesh(entityId: EntityID, filename: String) async {
    await MainActor.run {
        Logger.logWarning(message: "Failed to load mesh '\(filename)'. Rendering fallback cube instead.")
        let fallbackMeshes = BasicPrimitives.createCube()
        let dummyURL = URL(fileURLWithPath: "/fallback/\(filename)")
        let fallbackName = "Fallback_\(filename)"

        if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
            registerTransformComponent(entityId: entityId)
        }

        if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
            registerSceneGraphComponent(entityId: entityId)
        }

        associateMeshesToEntity(entityId: entityId, meshes: fallbackMeshes)
        registerRenderComponent(entityId: entityId, meshes: fallbackMeshes, url: dummyURL, assetName: fallbackName)
        setEntityName(entityId: entityId, name: fallbackName)

        // Assign default skin to prevent shader validation errors
        // Fallback primitives don't have skeletons, so create an empty skin
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }

        let skin = Skin()

        for index in renderComponent.mesh.indices {
            renderComponent.mesh[index].skin = skin
        }
    }
}

/// Sets entity mesh directly from pre-generated meshes (e.g., procedural primitives)
/// Follows the same pattern as setEntityMeshCommon
public func setEntityMeshDirect(entityId: EntityID, meshes: [Mesh], assetName: String) {
    if meshes.isEmpty {
        handleError(.assetDataMissing, assetName)
        return
    }

    // Single mesh case
    if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
        registerTransformComponent(entityId: entityId)
    }

    if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
        registerSceneGraphComponent(entityId: entityId)
    }

    associateMeshesToEntity(entityId: entityId, meshes: meshes)
    let dummyURL = URL(fileURLWithPath: "/primitive/\(assetName)")
    registerRenderComponent(entityId: entityId, meshes: meshes, url: dummyURL, assetName: assetName)
    // Primitives don't have skeletons, so we skip setEntitySkeleton

    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    let skin = Skin()

    for index in renderComponent.mesh.indices {
        renderComponent.mesh[index].skin = skin
    }
}

public func loadScene(filename: String, withExtension: String, coordinateConversion: CoordinateSystemConversion = .autoDetect) {
    guard let url: URL = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return
    }

    var meshes = [[Mesh]]()

    meshes = Mesh.loadSceneMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, coordinateConversion: coordinateConversion)

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

/// Asynchronously load a scene without blocking the main thread
public func loadSceneAsync(
    filename: String,
    withExtension: String,
    coordinateConversion: CoordinateSystemConversion = .autoDetect,
    completion: ((Bool) -> Void)? = nil
) {
    Task {
        // Create a temporary entity ID for tracking the scene load
        let sceneLoadEntityId = EntityID.max - 1 // Use a special ID for scene loading

        // Mark as loading
        await AssetLoadingState.shared.startLoading(entityId: sceneLoadEntityId, filename: filename)

        // Get URL
        guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
            handleError(.filenameNotFound, filename)
            await AssetLoadingState.shared.finishLoading(entityId: sceneLoadEntityId)
            await MainActor.run {
                completion?(false)
            }
            return
        }

        if url.pathExtension == "dae" {
            handleError(.fileTypeNotSupported, url.pathExtension)
            await AssetLoadingState.shared.finishLoading(entityId: sceneLoadEntityId)
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Load scene meshes asynchronously
        let meshes = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: coordinateConversion
        ) { current, total in
            Task {
                await AssetLoadingState.shared.updateProgress(entityId: sceneLoadEntityId, currentMesh: current, totalMeshes: total)
            }
        }

        // Process on main thread
        let didLoadMeshes: Bool = await MainActor.run {
            if meshes.isEmpty {
                handleError(.assetDataMissing, filename)
                return false
            }

            for mesh in meshes where mesh.count > 0 {
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
                setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
            }
            return true
        }

        await AssetLoadingState.shared.finishLoading(entityId: sceneLoadEntityId)

        await MainActor.run {
            completion?(didLoadMeshes)
        }
    }
}

// Cache to avoid reloading USDZ files multiple times for skeleton checks
private var skeletonCache: [URL: MDLSkeleton?] = [:]

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

    OctreeSystem.shared.unregisterEntity(entityId)

    MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)
}

public func setEntitySkeleton(entityId: EntityID, filename: String, withExtension: String) {
    guard let url: URL = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return
    }

    // Check cache first to avoid reloading USDZ
    let cachedSkeleton: MDLSkeleton?
    if let cached = skeletonCache[url] {
        cachedSkeleton = cached
    } else {
        // Not in cache - load USDZ once and cache result
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor.model, bufferAllocator: bufferAllocator)
        let skeletons = asset.childObjects(of: MDLSkeleton.self) as? [MDLSkeleton] ?? []
        cachedSkeleton = skeletons.first
        skeletonCache[url] = cachedSkeleton // Cache for future calls
    }

    if cachedSkeleton == nil {
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

    let skeleton = Skeleton(mdlSkeleton: cachedSkeleton!)!

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

    let resourceURL = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension)
    guard let url = resourceURL else {
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

public func registerTransformComponent(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
    registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
}

public func registerSceneGraphComponent(entityId: EntityID) {
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

    // Use localSpace transform instead of worldSpace
    // This ensures child entities get their transform relative to their parent
    let transformMatrix = meshes[0].localSpace

    localTransformComponent.position = simd_float3(transformMatrix.columns.3.x, transformMatrix.columns.3.y, transformMatrix.columns.3.z)

    localTransformComponent.scale = .one

    localTransformComponent.rotation = transformMatrix3nToQuaternion(m: matrix3x3_upper_left(transformMatrix))

    let euler = transformQuaternionToEulerAngles(q: localTransformComponent.rotation)

    localTransformComponent.rotationX = euler.pitch
    localTransformComponent.rotationY = euler.yaw
    localTransformComponent.rotationZ = euler.roll

    localTransformComponent.boundingBox = boundingBox

    OctreeSystem.shared.registerEntity(entityId)

    MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshes: meshes)
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
    if let previousName = entityNameMap[entityId], !previousName.isEmpty {
        if var list = reverseEntityNameMap[previousName] {
            list.removeAll { $0 == entityId }
            if list.isEmpty {
                reverseEntityNameMap.removeValue(forKey: previousName)
            } else {
                reverseEntityNameMap[previousName] = list
            }
        }
    }

    if name.isEmpty {
        entityNameMap.removeValue(forKey: entityId)
        return
    }

    entityNameMap[entityId] = name
    var list = reverseEntityNameMap[name] ?? []
    if list.contains(entityId) == false {
        list.append(entityId)
    }
    reverseEntityNameMap[name] = list
}

public func getEntityName(entityId: EntityID) -> String {
    if let name = entityNameMap[entityId] {
        return name
    }
    return "Entity-\(entityId)"
}

func removeEntityName(entityId: EntityID) {
    if let stored = entityNameMap[entityId],
       stored.isEmpty == false
    {
        if var list = reverseEntityNameMap[stored] {
            list.removeAll { $0 == entityId }
            if list.isEmpty {
                reverseEntityNameMap.removeValue(forKey: stored)
            } else {
                reverseEntityNameMap[stored] = list
            }
        }
    }
    entityNameMap.removeValue(forKey: entityId)
}

public func findEntity(name: String) -> EntityID? {
    guard var list = reverseEntityNameMap[name], !list.isEmpty else {
        return nil
    }

    list = list.filter { id in
        scene.exists(id) && entityNameMap[id] == name
    }

    if list.isEmpty {
        reverseEntityNameMap.removeValue(forKey: name)
        return nil
    }

    reverseEntityNameMap[name] = list
    return list.first
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

public func loadRawMesh(
    name: String,
    filename: String,
    withExtension: String
) -> [Mesh] {
    guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return []
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return []
    }

    let meshes = Mesh.loadMeshWithName(name: name, url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

    if !meshes.isEmpty {
        return meshes
    }

    // ---- Fallback path: fabricate a safe default mesh ----
    handleError(.assetDataMissing, filename)
    return Mesh.makeDefaultMesh()
}

public func setEntityGaussian(entityId: EntityID, filename: String, withExtension: String) {
    guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return
    }

    // Attempt to read Gaussian splats, handling errors internally
    let splats: [GaussianSplat]
    do {
        splats = try PLYReader.readGaussianSplats(from: url)
    } catch {
        handleError(.assetDataMissing, "Failed to read Gaussian splats from \(filename): \(error.localizedDescription)")
        return
    }

    // Check if we exceed the buffer capacity
    guard splats.count <= Int(maxNumOfGaussians) else {
        handleError(.bufferAllocationFailed, "Too many Gaussian splats: \(splats.count) exceeds maximum \(maxNumOfGaussians)")
        return
    }

    registerComponent(entityId: entityId, componentType: GaussianComponent.self)

    guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    gaussianComponent.splatCount = UInt(splats.count)
    var temSplatCount = UInt(splats.count)
    let tempPowerOfTwoSplatCount: UInt = nextPowerOf2(x: &temSplatCount)

    gaussianComponent.gaussianSortedIndices = renderInfo.device.makeBuffer(length: MemoryLayout<UInt64>.stride * Int(tempPowerOfTwoSplatCount), options: .storageModeShared)

    gaussianComponent.splatData = renderInfo.device.makeBuffer(length: MemoryLayout<GaussianSplat>.stride * Int(gaussianComponent.splatCount), options: .storageModeShared)

    // Copy to GPU buffer
    guard let splatBuffer = gaussianComponent.splatData else {
        handleError(.bufferAllocationFailed, "Gaussian splat buffer is nil")
        return
    }

    let pointer = splatBuffer.contents().bindMemory(
        to: GaussianSplat.self,
        capacity: splats.count
    )

    for (index, splat) in splats.enumerated() {
        pointer[index] = splat
    }

    gaussianComponent.spaceUniform = (0 ..< 2).compactMap { _ in
        renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                     options: [MTLResourceOptions.storageModeShared])
    }
}

// MARK: Static Batching

public func setEntityStaticBatchComponent(entityId: EntityID) {
    // Only process entities with RenderComponent (skip empty parent entities)
    if let _ = scene.get(component: RenderComponent.self, for: entityId) {
        if !hasComponent(entityId: entityId, componentType: StaticBatchComponent.self) {
            registerComponent(entityId: entityId, componentType: StaticBatchComponent.self)
            Logger.log(message: "✅ StaticBatchComponent registered for entity \(entityId)")
        } else {
            Logger.logWarning(message: "StaticBatchComponent already exists on entity \(entityId)")
        }
    }

    // Recursively mark all children as static
    let children = getEntityChildren(parentId: entityId)
    for childId in children {
        setEntityStaticBatchComponent(entityId: childId)
    }
}

public func removeEntityStaticBatchComponent(entityId: EntityID) {
    // Remove from this entity if it has the component
    if let _ = scene.get(component: StaticBatchComponent.self, for: entityId) {
        scene.remove(component: StaticBatchComponent.self, from: entityId)
        Logger.log(message: "✅ StaticBatchComponent removed from entity \(entityId)")
    }

    // Recursively remove from all children
    let children = getEntityChildren(parentId: entityId)
    for childId in children {
        removeEntityStaticBatchComponent(entityId: childId)
    }
}

// Internal cleanup function for entity destruction (non-recursive, called per entity)
func removeEntityStaticBatch(entityId: EntityID) {
    if scene.get(component: StaticBatchComponent.self, for: entityId) != nil {
        scene.remove(component: StaticBatchComponent.self, from: entityId)
    }
}

func removeEntityLOD(entityId: EntityID) {
    if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
        // Clear LOD levels (meshes will be cleaned up by RenderComponent cleanup)
        lodComponent.lodLevels.removeAll()
        scene.remove(component: LODComponent.self, from: entityId)
    }
}

func removeEntityGaussian(entityId: EntityID) {
    if let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) {
        // Release Metal buffers
        gaussianComponent.splatData = nil
        gaussianComponent.gaussianSortedIndices = nil
        gaussianComponent.spaceUniform.removeAll()
        scene.remove(component: GaussianComponent.self, from: entityId)
    }
}

func removeEntityCamera(entityId: EntityID) {
    if scene.get(component: CameraComponent.self, for: entityId) != nil {
        scene.remove(component: CameraComponent.self, from: entityId)
    }
    if scene.get(component: SceneCameraComponent.self, for: entityId) != nil {
        scene.remove(component: SceneCameraComponent.self, from: entityId)
    }
}

func removeEntityAssetInstance(entityId: EntityID) {
    if scene.get(component: AssetInstanceComponent.self, for: entityId) != nil {
        scene.remove(component: AssetInstanceComponent.self, from: entityId)
    }
    if scene.get(component: DerivedAssetNodeComponent.self, for: entityId) != nil {
        scene.remove(component: DerivedAssetNodeComponent.self, from: entityId)
    }
}

func removeEntityScript(entityId: EntityID) {
    if let scriptComponent = scene.get(component: ScriptComponent.self, for: entityId) {
        // Clean up scripts
        scriptComponent.scripts.removeAll()
        scriptComponent.scriptFilePaths = nil
        scene.remove(component: ScriptComponent.self, from: entityId)
    }
}

// MARK: - Granular LOD Management Functions

/// Set up LOD component for an entity
/// Call this before adding LOD levels
public func setEntityLodComponent(entityId: EntityID) {
    if !hasComponent(entityId: entityId, componentType: LODComponent.self) {
        registerComponent(entityId: entityId, componentType: LODComponent.self)
        Logger.log(message: "✅ LODComponent registered for entity")
    } else {
        Logger.logWarning(message: "LODComponent already exists on entity")
    }
}

/// Add a single LOD level to an entity
/// Entity must have LODComponent set via setEntityLodComponent() first
public func addLODLevel(
    entityId: EntityID,
    lodIndex: Int,
    fileName: String,
    withExtension: String,
    maxDistance: Float,
    screenPercentage: Float = 0.0,
    completion: ((Bool) -> Void)? = nil
) {
    Task {
        // Check if LODComponent exists
        guard hasComponent(entityId: entityId, componentType: LODComponent.self) else {
            Logger.logError(message: "Entity does not have LODComponent. Call setEntityLodComponent() first.")
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Get file URL using standard resource loading
        guard let url = LoadingSystem.shared.resourceURL(forResource: fileName, withExtension: withExtension) else {
            Logger.logError(message: "Failed to find LOD file: \(fileName).\(withExtension)")
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Load meshes for this LOD
        var meshes = await Mesh.loadMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        // Assign empty skin to all meshes (required by shaders)
        let skin = Skin()
        for index in meshes.indices {
            meshes[index].skin = skin
        }

        // Create LOD level
        let lodLevel = LODLevel(
            mesh: meshes,
            maxDistance: maxDistance,
            screenPercentage: screenPercentage,
            url: url
        )

        await MainActor.run {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
                handleError(.componentNotFound, "LODComponent")
                completion?(false)
                return
            }

            // Add LOD level at the specified index
            if lodIndex < 0 {
                Logger.logWarning(message: "Invalid LOD index \(lodIndex), appending to end")
                lodComponent.lodLevels.append(lodLevel)
            } else if lodIndex >= lodComponent.lodLevels.count {
                // Ensure array is large enough by padding with empty slots if needed
                // This handles out-of-order additions (e.g., adding LOD2 before LOD1)
                while lodComponent.lodLevels.count < lodIndex {
                    // Pad with placeholder (will be replaced when proper LOD is added)
                    let placeholder = LODLevel(mesh: [], maxDistance: 0, screenPercentage: 0, url: URL(fileURLWithPath: ""))
                    lodComponent.lodLevels.append(placeholder)
                }
                // Now append the actual LOD at the correct index
                lodComponent.lodLevels.append(lodLevel)
            } else {
                // Replace existing LOD at this index
                lodComponent.lodLevels[lodIndex] = lodLevel
            }

            // If this is LOD0, create or update RenderComponent
            if lodIndex == 0 {
                if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
                    // Update existing RenderComponent
                    renderComponent.mesh = meshes
                    renderComponent.assetURL = url
                    renderComponent.assetName = meshes.first?.assetName ?? url.deletingPathExtension().lastPathComponent
                } else {
                    // Create new RenderComponent
                    let assetName = meshes.first?.assetName ?? url.deletingPathExtension().lastPathComponent
                    registerRenderComponent(entityId: entityId, meshes: meshes, url: url, assetName: assetName)
                    associateMeshesToEntity(entityId: entityId, meshes: meshes)
                }
            }

            Logger.log(message: "✅ Added LOD level \(lodIndex) to entity")
            completion?(true)
        }
    }
}

/// Remove a specific LOD level by index
public func removeLODLevel(
    entityId: EntityID,
    lodIndex: Int
) {
    guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
        Logger.logWarning(message: "Entity does not have LODComponent")
        return
    }

    // Validate index
    guard lodIndex >= 0, lodIndex < lodComponent.lodLevels.count else {
        Logger.logWarning(message: "Invalid LOD index: \(lodIndex)")
        return
    }

    // Remove the LOD level
    lodComponent.lodLevels.remove(at: lodIndex)

    // If we removed the current LOD, reset to LOD0
    if lodComponent.currentLOD == lodIndex {
        lodComponent.currentLOD = 0

        // Update render component to show LOD0 if available
        if !lodComponent.lodLevels.isEmpty,
           let renderComponent = scene.get(component: RenderComponent.self, for: entityId)
        {
            renderComponent.mesh = lodComponent.lodLevels[0].mesh
        }
    } else if lodComponent.currentLOD > lodIndex {
        // Adjust current LOD index if we removed something before it
        lodComponent.currentLOD -= 1
    }

    Logger.log(message: "✅ Removed LOD level \(lodIndex)")
}

/// Replace an existing LOD level with a new mesh file
public func replaceLODLevel(
    entityId: EntityID,
    lodIndex: Int,
    fileName: String,
    withExtension: String,
    maxDistance: Float,
    screenPercentage: Float = 0.0,
    completion: ((Bool) -> Void)? = nil
) {
    Task {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            Logger.logWarning(message: "Entity does not have LODComponent")
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Validate index
        guard lodIndex >= 0, lodIndex < lodComponent.lodLevels.count else {
            Logger.logWarning(message: "Invalid LOD index: \(lodIndex)")
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Get file URL using standard resource loading
        guard let newURL = LoadingSystem.shared.resourceURL(forResource: fileName, withExtension: withExtension) else {
            Logger.logError(message: "Failed to find LOD file: \(fileName).\(withExtension)")
            await MainActor.run {
                completion?(false)
            }
            return
        }

        // Load new meshes
        var meshes = await Mesh.loadMeshesAsync(
            url: newURL,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            flip: true
        )

        // Assign empty skin to all meshes
        let skin = Skin()
        for index in meshes.indices {
            meshes[index].skin = skin
        }

        // Create new LOD level
        let newLodLevel = LODLevel(
            mesh: meshes,
            maxDistance: maxDistance,
            screenPercentage: screenPercentage,
            url: newURL
        )

        await MainActor.run {
            // Replace the LOD level
            lodComponent.lodLevels[lodIndex] = newLodLevel

            // If this is the current LOD or LOD0, update render component
            if lodComponent.currentLOD == lodIndex,
               let renderComponent = scene.get(component: RenderComponent.self, for: entityId)
            {
                renderComponent.mesh = meshes
                renderComponent.assetURL = newURL
                renderComponent.assetName = meshes.first?.assetName ?? newURL.deletingPathExtension().lastPathComponent
            }

            Logger.log(message: "✅ Replaced LOD level \(lodIndex)")
            completion?(true)
        }
    }
}

/// Get the number of LOD levels for an entity
public func getLODLevelCount(entityId: EntityID) -> Int {
    guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
        return 0
    }
    return lodComponent.lodLevels.count
}

/// Register LOD component for an existing entity with pre-loaded LOD levels
/// Useful for testing or when you've manually created LOD levels
public func registerLODComponent(
    entityId: EntityID,
    lodLevels: [LODLevel]
) {
    guard !lodLevels.isEmpty else {
        Logger.logWarning(message: "Cannot register LODComponent with empty lodLevels")
        return
    }

    registerComponent(entityId: entityId, componentType: LODComponent.self)

    guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
        handleError(.componentNotFound, "LODComponent")
        return
    }

    lodComponent.lodLevels = lodLevels
    lodComponent.currentLOD = 0

    // Update render component with LOD0 if it exists
    if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
        renderComponent.mesh = lodLevels[0].mesh
    }
}

// Geometry Streaming
/// Enable streaming for an entity that already has a mesh
/// Call this AFTER setEntityMesh() or setEntityMeshAsync()
/// For multi-mesh assets, this enables streaming on all child entities with RenderComponents
public func enableStreaming(
    entityId: EntityID,
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    priority: Int = 0
) {
    // Try direct RenderComponent first (single-mesh entity)
    if scene.get(component: RenderComponent.self, for: entityId) != nil {
        enableStreamingForSingleEntity(
            entityId: entityId,
            streamingRadius: streamingRadius,
            unloadRadius: unloadRadius,
            priority: priority
        )
        return
    }

    // No direct RenderComponent - check children (multi-mesh asset)
    if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: entityId),
       !sceneGraph.children.isEmpty
    {
        var enabledCount = 0
        for childId in sceneGraph.children {
            if scene.get(component: RenderComponent.self, for: childId) != nil {
                enableStreamingForSingleEntity(
                    entityId: childId,
                    streamingRadius: streamingRadius,
                    unloadRadius: unloadRadius,
                    priority: priority
                )
                enabledCount += 1
            }
        }
        if enabledCount > 0 {
            Logger.log(message: "✅ Enabled streaming for \(enabledCount) child entities")
        } else {
            Logger.logWarning(message: "Cannot enable streaming: entity \(entityId) has no children with RenderComponents")
        }
        return
    }

    Logger.logWarning(message: "Cannot enable streaming: entity \(entityId) has no RenderComponent")
}

/// Internal helper to enable streaming on a single entity with a RenderComponent
private func enableStreamingForSingleEntity(
    entityId: EntityID,
    streamingRadius: Float,
    unloadRadius: Float,
    priority: Int
) {
    guard let render = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    // Register streaming component
    registerComponent(entityId: entityId, componentType: StreamingComponent.self)

    guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
        return
    }

    // Extract filename info from the render component's URL
    let url = render.assetURL
    streaming.assetFilename = url.deletingPathExtension().lastPathComponent
    streaming.assetExtension = url.pathExtension

    streaming.streamingRadius = streamingRadius
    streaming.unloadRadius = unloadRadius
    streaming.priority = priority
    streaming.state = .loaded // Already has mesh

    // Register with streaming system for tracking
    GeometryStreamingSystem.shared.registerLoadedEntity(entityId)
}

/// Create a streaming entity that loads mesh on demand (deferred loading)
public func createStreamingEntity(
    filename: String,
    withExtension ext: String,
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    priority: Int = 0
) -> EntityID {
    let entityId = createEntity()

    // Register required components
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)
    registerComponent(entityId: entityId, componentType: StreamingComponent.self)

    guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
        return entityId
    }

    streaming.assetFilename = filename
    streaming.assetExtension = ext
    streaming.streamingRadius = streamingRadius
    streaming.unloadRadius = unloadRadius
    streaming.priority = priority
    streaming.state = .unloaded // Will load when camera is near

    return entityId
}
