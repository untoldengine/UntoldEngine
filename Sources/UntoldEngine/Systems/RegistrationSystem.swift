
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

private var pendingDestroyCompletions: [() -> Void] = []
private let pendingDestroyCompletionsLock = NSLock()

private func enqueuePendingDestroyCompletion(_ completion: (() -> Void)?) {
    guard let completion else { return }
    pendingDestroyCompletionsLock.lock()
    pendingDestroyCompletions.append(completion)
    pendingDestroyCompletionsLock.unlock()
}

private func runPendingDestroyCompletions() {
    let callbacks: [() -> Void]
    pendingDestroyCompletionsLock.lock()
    guard pendingDestroyCompletions.isEmpty == false else {
        pendingDestroyCompletionsLock.unlock()
        return
    }
    callbacks = pendingDestroyCompletions
    pendingDestroyCompletions.removeAll(keepingCapacity: true)
    pendingDestroyCompletionsLock.unlock()

    for callback in callbacks {
        callback()
    }
}

private let componentCleanupRegistrationLock = NSLock()
private var componentCleanupHandlersRegistered = false

func ensureComponentCleanupHandlersRegistered() {
    componentCleanupRegistrationLock.lock()
    defer { componentCleanupRegistrationLock.unlock() }

    guard componentCleanupHandlersRegistered == false else { return }
    registerComponentCleanupHandlers()
    componentCleanupHandlersRegistered = true
}

private func registerComponentCleanupHandlers() {
    ComponentRegistry.register(componentType: ScenegraphComponent.self, handlerId: "scenegraph", priority: 10) { entityId in
        removeEntityScenegraph(entityId: entityId)
    }

    ComponentRegistry.register(componentType: RenderComponent.self, handlerId: "mesh", priority: 20) { entityId in
        removeEntityMesh(entityId: entityId)
    }
    ComponentRegistry.register(componentType: SkeletonComponent.self, handlerId: "mesh", priority: 20) { entityId in
        removeEntityMesh(entityId: entityId)
    }

    ComponentRegistry.register(componentType: AnimationComponent.self, handlerId: "animation", priority: 30) { entityId in
        removeEntityAnimations(entityId: entityId)
    }

    ComponentRegistry.register(componentType: PhysicsComponents.self, handlerId: "kinetics", priority: 30) { entityId in
        removeEntityKinetics(entityId: entityId)
    }
    ComponentRegistry.register(componentType: KineticComponent.self, handlerId: "kinetics", priority: 30) { entityId in
        removeEntityKinetics(entityId: entityId)
    }

    ComponentRegistry.register(componentType: LightComponent.self, handlerId: "light", priority: 30) { entityId in
        removeEntityLight(entityId: entityId)
    }
    ComponentRegistry.register(componentType: DirectionalLightComponent.self, handlerId: "light", priority: 30) { entityId in
        removeEntityLight(entityId: entityId)
    }
    ComponentRegistry.register(componentType: PointLightComponent.self, handlerId: "light", priority: 30) { entityId in
        removeEntityLight(entityId: entityId)
    }
    ComponentRegistry.register(componentType: SpotLightComponent.self, handlerId: "light", priority: 30) { entityId in
        removeEntityLight(entityId: entityId)
    }
    ComponentRegistry.register(componentType: AreaLightComponent.self, handlerId: "light", priority: 30) { entityId in
        removeEntityLight(entityId: entityId)
    }

    ComponentRegistry.register(componentType: StaticBatchComponent.self, handlerId: "staticBatch", priority: 30) { entityId in
        removeEntityStaticBatch(entityId: entityId)
    }

    ComponentRegistry.register(componentType: LODComponent.self, handlerId: "lod", priority: 30) { entityId in
        removeEntityLOD(entityId: entityId)
    }

    ComponentRegistry.register(componentType: GaussianComponent.self, handlerId: "gaussian", priority: 30) { entityId in
        removeEntityGaussian(entityId: entityId)
    }

    ComponentRegistry.register(componentType: CameraComponent.self, handlerId: "camera", priority: 30) { entityId in
        removeEntityCamera(entityId: entityId)
    }
    ComponentRegistry.register(componentType: SceneCameraComponent.self, handlerId: "camera", priority: 30) { entityId in
        removeEntityCamera(entityId: entityId)
    }

    ComponentRegistry.register(componentType: AssetInstanceComponent.self, handlerId: "assetInstance", priority: 30) { entityId in
        removeEntityAssetInstance(entityId: entityId)
    }
    ComponentRegistry.register(componentType: DerivedAssetNodeComponent.self, handlerId: "assetInstance", priority: 30) { entityId in
        removeEntityAssetInstance(entityId: entityId)
    }

    ComponentRegistry.register(componentType: ScriptComponent.self, handlerId: "script", priority: 30) { entityId in
        removeEntityScript(entityId: entityId)
    }

    ComponentRegistry.register(componentType: StreamingComponent.self, handlerId: "streaming", priority: 30) { entityId in
        removeEntityStreaming(entityId: entityId)
    }

    ComponentRegistry.register(componentType: GizmoComponent.self, handlerId: "gizmo", priority: 30) { entityId in
        removeEntityGizmo(entityId: entityId)
    }

    ComponentRegistry.register(componentType: LocalTransformComponent.self, handlerId: "transforms", priority: 90) { entityId in
        removeEntityTransforms(entityId: entityId)
    }
    ComponentRegistry.register(componentType: WorldTransformComponent.self, handlerId: "transforms", priority: 90) { entityId in
        removeEntityTransforms(entityId: entityId)
    }
}

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
    ensureComponentCleanupHandlersRegistered()
    if !ComponentRegistry.hasCleanupHandler(for: componentType) {
        ComponentRegistry.register(componentType: componentType, priority: 50) { entityId in
            scene.remove(component: componentType, from: entityId)
        }
    }
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

public func destroyAllEntities(completion: (() -> Void)? = nil) {
    enqueuePendingDestroyCompletion(completion)

    let toDestroy = scene.getAllEntities()
    if toDestroy.isEmpty {
        // Deletions are deferred to frame finalization. If there is no pending work,
        // fire completion immediately so callers can continue loading synchronously.
        if hasPendingDestroys == false {
            runPendingDestroyCompletions()
        }
        return
    }

    for entity in toDestroy {
        destroyEntity(entityId: entity)
    }
}

func finalizePendingDestroys() {
    ensureComponentCleanupHandlersRegistered()

    visibleEntityIds.removeAll()

    // Process pending entities iteratively so children marked during cleanup
    // are also cleaned in the same finalize pass.
    var cleanedPendingEntities: Set<EntityID> = []

    while true {
        let pending: [EntityID] = scene.entities.compactMap { entity in
            guard entity.pendingDestroy, !entity.freed, !cleanedPendingEntities.contains(entity.entityId) else {
                return nil
            }
            return entity.entityId
        }

        guard pending.isEmpty == false else {
            break
        }

        for entityId in pending {
            ComponentRegistry.cleanupAll(entityId: entityId)
            removeEntityName(entityId: entityId) // Name data is not an ECS component.
            scene.removeAllComponents(from: entityId) // Failsafe for unregistered component types.
            cleanedPendingEntities.insert(entityId)
        }
    }

    scene.finalizePendingDestroys()
    runPendingDestroyCompletions()
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

    // Cache meshes for streaming system (so reloads don't require disk I/O)
    MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

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

            // Extract full transform (translation, rotation, scale) from mesh's worldSpace
            // BEFORE registerRenderComponent. This ensures the entity holds the complete
            // authored transform from the USDZ, while the mesh itself remains at identity.
            if let firstMesh = mesh.first {
                let transform = firstMesh.worldSpace

                // Extract translation
                let translation = simd_float3(
                    transform.columns.3.x,
                    transform.columns.3.y,
                    transform.columns.3.z
                )

                // Extract scale from the length of each basis vector
                let scaleX = simd_length(simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z))
                let scaleY = simd_length(simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z))
                let scaleZ = simd_length(simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
                let scale = simd_float3(scaleX, scaleY, scaleZ)

                // Extract rotation by normalizing the scaled rotation matrix
                var rotationMatrix = matrix_float3x3(
                    simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z) / scaleX,
                    simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z) / scaleY,
                    simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z) / scaleZ
                )
                let rotation = transformMatrix3nToQuaternion(m: rotationMatrix)

                // Convert quaternion to Euler angles for editor display
                let eulerAngles = transformQuaternionToEulerAngles(q: rotation)

                // Apply to entity's local transform
                if let localTransform = scene.get(component: LocalTransformComponent.self, for: childEntityId) {
                    localTransform.position = translation
                    localTransform.rotation = rotation
                    localTransform.scale = scale
                    // Update Euler angle cache for editor inspector
                    localTransform.rotationX = eulerAngles.pitch
                    localTransform.rotationY = eulerAngles.yaw
                    localTransform.rotationZ = eulerAngles.roll
                }
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
        let progressUpdateStride = 25
        var lastProgressSent = 0
        let meshes = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: coordinateConversion
        ) { current, total in
            guard total > 0 else { return }
            let shouldReport = current == total || (current - lastProgressSent) >= progressUpdateStride
            guard shouldReport else { return }
            lastProgressSent = current

            Task {
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: current, totalMeshes: total)
            }
        }

        // Cache meshes for streaming system (so reloads don't require disk I/O)
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

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

            // Process mesh groups without artificial delays to maximize import throughput.
            for (index, mesh) in nonEmptyMeshes.enumerated() {
                let childEntityId = await MainActor.run { () -> EntityID in
                    let childEntityId = createEntity()

                    if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
                        registerTransformComponent(entityId: childEntityId)
                    }

                    if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
                        registerSceneGraphComponent(entityId: childEntityId)
                    }

                    // Extract full transform (translation, rotation, scale) from mesh's worldSpace
                    // BEFORE registerRenderComponent. This ensures the entity holds the complete
                    // authored transform from the USDZ, while the mesh itself remains at identity.
                    if let firstMesh = mesh.first {
                        let transform = firstMesh.worldSpace

                        // Extract translation
                        let translation = simd_float3(
                            transform.columns.3.x,
                            transform.columns.3.y,
                            transform.columns.3.z
                        )

                        // Extract scale from the length of each basis vector
                        let scaleX = simd_length(simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z))
                        let scaleY = simd_length(simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z))
                        let scaleZ = simd_length(simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z))
                        let scale = simd_float3(scaleX, scaleY, scaleZ)

                        // Extract rotation by normalizing the scaled rotation matrix
                        var rotationMatrix = matrix_float3x3(
                            simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z) / scaleX,
                            simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z) / scaleY,
                            simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z) / scaleZ
                        )
                        let rotation = transformMatrix3nToQuaternion(m: rotationMatrix)

                        // Convert quaternion to Euler angles for editor display
                        let eulerAngles = transformQuaternionToEulerAngles(q: rotation)

                        // Apply to entity's local transform
                        if let localTransform = scene.get(component: LocalTransformComponent.self, for: childEntityId) {
                            localTransform.position = translation
                            localTransform.rotation = rotation
                            localTransform.scale = scale
                            // Update Euler angle cache for editor inspector
                            localTransform.rotationX = eulerAngles.pitch
                            localTransform.rotationY = eulerAngles.yaw
                            localTransform.rotationZ = eulerAngles.roll
                        }
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

    withWorldMutationGate {
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

    // Cache meshes for streaming system (so reloads don't require disk I/O)
    MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

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
        let progressUpdateStride = 25
        var lastProgressSent = 0
        let meshes = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: coordinateConversion
        ) { current, total in
            guard total > 0 else { return }
            let shouldReport = current == total || (current - lastProgressSent) >= progressUpdateStride
            guard shouldReport else { return }
            lastProgressSent = current

            Task {
                await AssetLoadingState.shared.updateProgress(entityId: sceneLoadEntityId, currentMesh: current, totalMeshes: total)
            }
        }

        // Cache meshes for streaming system (so reloads don't require disk I/O)
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

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
    var removedAnyResourceOwner = false

    if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
        renderComponent.cleanUp()
        scene.remove(component: RenderComponent.self, from: entityId)
        removedAnyResourceOwner = true
    }

    // deassocate entity to mesh
    deassociateMeshesToEntity(entityId: entityId)
    MeshResourceManager.shared.release(entityId: entityId)

    if let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) {
        skeletonComponent.cleanUp()
        scene.remove(component: SkeletonComponent.self, from: entityId)
        removedAnyResourceOwner = true
    }

    guard removedAnyResourceOwner else {
        return
    }

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
        withWorldMutationGate {
            addClips(to: animationComponent)
        }

        return
    }

    withWorldMutationGate {
        // register Animation Component
        registerComponent(entityId: entityId, componentType: AnimationComponent.self)

        guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
            handleError(.noAnimationComponent, entityId)
            return
        }

        addClips(to: animationComponent)
    }
}

func removeEntityAnimations(entityId: EntityID) {
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        return
    }

    animationComponent.cleanUp()
    scene.remove(component: AnimationComponent.self, from: entityId)
}

public func setEntityKinetics(entityId: EntityID) {
    withWorldMutationGate {
        if let _ = scene.get(component: PhysicsComponents.self, for: entityId) {
            registerComponent(entityId: entityId, componentType: KineticComponent.self)
        } else {
            // Components doesn't exist, create and register it
            registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
            registerComponent(entityId: entityId, componentType: KineticComponent.self)
        }
    }
}

func removeEntityKinetics(entityId: EntityID) {
    if let kineticComponent = scene.get(component: KineticComponent.self, for: entityId) {
        kineticComponent.clearForces()
        scene.remove(component: KineticComponent.self, from: entityId)
    }

    if scene.get(component: PhysicsComponents.self, for: entityId) != nil {
        scene.remove(component: PhysicsComponents.self, from: entityId)
    }
}

func removeEntityLight(entityId: EntityID) {
    if let lightComponent = scene.get(component: LightComponent.self, for: entityId) {
        lightComponent.lightType = nil
        lightComponent.texture.directional = nil
        lightComponent.texture.point = nil
        lightComponent.texture.spot = nil
        lightComponent.texture.area = nil
        scene.remove(component: LightComponent.self, from: entityId)
    }

    if scene.get(component: DirectionalLightComponent.self, for: entityId) != nil {
        scene.remove(component: DirectionalLightComponent.self, from: entityId)
    }

    if scene.get(component: PointLightComponent.self, for: entityId) != nil {
        scene.remove(component: PointLightComponent.self, from: entityId)
    }

    if scene.get(component: SpotLightComponent.self, for: entityId) != nil {
        scene.remove(component: SpotLightComponent.self, from: entityId)
    }

    if scene.get(component: AreaLightComponent.self, for: entityId) != nil {
        scene.remove(component: AreaLightComponent.self, from: entityId)
    }
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
    if scene.get(component: LocalTransformComponent.self, for: entityId) != nil {
        scene.remove(component: LocalTransformComponent.self, from: entityId)
    }

    if scene.get(component: WorldTransformComponent.self, for: entityId) != nil {
        scene.remove(component: WorldTransformComponent.self, from: entityId)
    }
}

private func transformsApproximatelyEqual(_ lhs: simd_float4x4, _ rhs: simd_float4x4, epsilon: Float = 0.0001) -> Bool {
    let delta0 = simd_length(lhs.columns.0 - rhs.columns.0)
    let delta1 = simd_length(lhs.columns.1 - rhs.columns.1)
    let delta2 = simd_length(lhs.columns.2 - rhs.columns.2)
    let delta3 = simd_length(lhs.columns.3 - rhs.columns.3)
    return delta0 < epsilon && delta1 < epsilon && delta2 < epsilon && delta3 < epsilon
}

private func resolveMeshTransformsForRender(_ meshes: [Mesh]) -> [Mesh] {
    let hasAncestorTransforms = meshes.contains { mesh in
        transformsApproximatelyEqual(mesh.localSpace, mesh.worldSpace) == false
    }

    guard hasAncestorTransforms else {
        return meshes
    }

    var resolvedMeshes = meshes
    for index in resolvedMeshes.indices {
        // For multi-mesh USDZ files, the full transform is extracted to the entity.
        // Set mesh localSpace to identity so the mesh renders at the entity's transform.
        // This aligns with Unity/Unreal behavior where imported transforms go to the GameObject/Actor.
        resolvedMeshes[index].localSpace = matrix_identity_float4x4
    }

    return resolvedMeshes
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

    let resolvedMeshes = resolveMeshTransformsForRender(meshes)

    renderComponent.mesh = resolvedMeshes
    renderComponent.assetName = assetName
    renderComponent.assetURL = url
    entityMeshMap[entityId] = resolvedMeshes

    let boundingBox = Mesh.computeMeshBoundingBox(for: resolvedMeshes)

    localTransformComponent.boundingBox = boundingBox

    OctreeSystem.shared.registerEntity(entityId)

    MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshes: resolvedMeshes)
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

    let splatCount = UInt(splats.count)
    var temSplatCount = splatCount
    let tempPowerOfTwoSplatCount: UInt = nextPowerOf2(x: &temSplatCount)

    let gaussianSortedIndices = renderInfo.device.makeBuffer(length: MemoryLayout<UInt64>.stride * Int(tempPowerOfTwoSplatCount), options: .storageModeShared)

    guard let splatBuffer = renderInfo.device.makeBuffer(length: MemoryLayout<GaussianSplat>.stride * Int(splatCount), options: .storageModeShared) else {
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

    let spaceUniform = (0 ..< totalPerMeshUniformBuffers()).compactMap { _ in
        renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                     options: [MTLResourceOptions.storageModeShared])
    }

    withWorldMutationGate {
        registerComponent(entityId: entityId, componentType: GaussianComponent.self)

        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noRenderComponent, entityId)
            return
        }

        gaussianComponent.splatCount = splatCount
        gaussianComponent.gaussianSortedIndices = gaussianSortedIndices
        gaussianComponent.splatData = splatBuffer
        gaussianComponent.spaceUniform = spaceUniform
    }
}

// MARK: Static Batching

public func setEntityStaticBatchComponent(entityId: EntityID) {
    // XR can render from a dedicated thread while scene data is being mutated here.
    // Gate rendering while we recursively tag the hierarchy as static-batchable.
    withWorldMutationGate {
        setEntityStaticBatchComponentRecursive(entityId: entityId)
    }
}

private func setEntityStaticBatchComponentRecursive(entityId: EntityID) {
    // Only process entities with RenderComponent (skip empty parent entities)
    if let _ = scene.get(component: RenderComponent.self, for: entityId) {
        if !hasComponent(entityId: entityId, componentType: StaticBatchComponent.self) {
            registerComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        } else {
            Logger.logWarning(message: "StaticBatchComponent already exists on entity \(entityId)")
        }
    }

    // Recursively mark all children as static
    let children = getEntityChildren(parentId: entityId)
    for childId in children {
        setEntityStaticBatchComponentRecursive(entityId: childId)
    }
}

/// Marks only this entity as static-batchable (non-recursive).
/// Used by per-node override application where recursion would repeatedly
/// revisit descendants and generate duplicate "already exists" warnings.
public func setEntityStaticBatch(entityId: EntityID) {
    withWorldMutationGate {
        guard scene.get(component: RenderComponent.self, for: entityId) != nil else {
            return
        }
        if !hasComponent(entityId: entityId, componentType: StaticBatchComponent.self) {
            registerComponent(entityId: entityId, componentType: StaticBatchComponent.self)
        }
    }
}

public func removeEntityStaticBatchComponent(entityId: EntityID) {
    // XR can render from a dedicated thread while scene data is being mutated here.
    // Gate rendering while we recursively untag the hierarchy from static batching.
    withWorldMutationGate {
        removeEntityStaticBatchComponentRecursive(entityId: entityId)
    }
}

private func removeEntityStaticBatchComponentRecursive(entityId: EntityID) {
    // Remove from this entity if it has the component
    if let _ = scene.get(component: StaticBatchComponent.self, for: entityId) {
        scene.remove(component: StaticBatchComponent.self, from: entityId)
        Logger.log(message: "✅ StaticBatchComponent removed from entity \(entityId)")
    }

    // Recursively remove from all children
    let children = getEntityChildren(parentId: entityId)
    for childId in children {
        removeEntityStaticBatchComponentRecursive(entityId: childId)
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

func removeEntityStreaming(entityId: EntityID) {
    if let streamingComponent = scene.get(component: StreamingComponent.self, for: entityId) {
        streamingComponent.loadTask?.cancel()
        streamingComponent.loadTask = nil
        scene.remove(component: StreamingComponent.self, from: entityId)
    }

    GeometryStreamingSystem.shared.unregisterEntity(entityId)
    MeshResourceManager.shared.release(entityId: entityId)
}

func removeEntityGizmo(entityId: EntityID) {
    if scene.get(component: GizmoComponent.self, for: entityId) != nil {
        scene.remove(component: GizmoComponent.self, from: entityId)
    }
}

// MARK: - Granular LOD Management Functions

/// Set up LOD component for an entity
/// Call this before adding LOD levels
public func setEntityLodComponent(entityId: EntityID) {
    withWorldMutationGate {
        if !hasComponent(entityId: entityId, componentType: LODComponent.self) {
            registerComponent(entityId: entityId, componentType: LODComponent.self)
            Logger.log(message: "✅ LODComponent registered for entity")
        } else {
            Logger.logWarning(message: "LODComponent already exists on entity")
        }
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

        // Cache meshes for streaming reload support
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: [meshes])

        // Create LOD level
        let lodLevel = LODLevel(
            mesh: meshes,
            maxDistance: maxDistance,
            screenPercentage: screenPercentage,
            url: url
        )

        await MainActor.run {
            withWorldMutationGate {
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
}

/// Add multiple LOD levels to an entity with a single completion handler.
/// This is useful when you need to wait for all LOD levels to load before performing
/// additional setup (e.g., enabling static batching).
///
/// - Parameters:
///   - entityId: The entity to add LOD levels to
///   - levels: Array of tuples containing (lodIndex, fileName, withExtension, maxDistance, screenPercentage)
///   - completion: Called when all LOD levels have finished loading. Returns true only if ALL levels loaded successfully.
///
/// Example:
/// ```swift
/// addLODLevels(entityId: tree, levels: [
///     (0, "tree_LOD0", "usdz", 50.0, 0.0),
///     (1, "tree_LOD1", "usdz", 100.0, 0.0),
///     (2, "tree_LOD2", "usdz", 200.0, 0.0)
/// ]) { success in
///     if success {
///         setEntityStaticBatchComponent(entityId: tree)
///         generateBatches()
///     }
/// }
/// ```
public func addLODLevels(
    entityId: EntityID,
    levels: [(lodIndex: Int, fileName: String, withExtension: String, maxDistance: Float, screenPercentage: Float)],
    completion: @escaping (Bool) -> Void
) {
    let group = DispatchGroup()
    var allSuccess = true

    for level in levels {
        group.enter()
        addLODLevel(
            entityId: entityId,
            lodIndex: level.lodIndex,
            fileName: level.fileName,
            withExtension: level.withExtension,
            maxDistance: level.maxDistance,
            screenPercentage: level.screenPercentage
        ) { success in
            if !success { allSuccess = false }
            group.leave()
        }
    }

    group.notify(queue: .main) {
        withWorldMutationGate {
            completion(allSuccess)
        }
    }
}

/// Remove a specific LOD level by index
public func removeLODLevel(
    entityId: EntityID,
    lodIndex: Int
) {
    withWorldMutationGate {
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
            withWorldMutationGate {
                guard let currentLODComponent = scene.get(component: LODComponent.self, for: entityId) else {
                    Logger.logWarning(message: "Entity does not have LODComponent")
                    completion?(false)
                    return
                }

                guard lodIndex >= 0, lodIndex < currentLODComponent.lodLevels.count else {
                    Logger.logWarning(message: "Invalid LOD index: \(lodIndex)")
                    completion?(false)
                    return
                }

                // Replace the LOD level
                currentLODComponent.lodLevels[lodIndex] = newLodLevel

                // If this is the current LOD or LOD0, update render component
                if currentLODComponent.currentLOD == lodIndex,
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

    withWorldMutationGate {
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
    // Enabling streaming mutates ECS/component state and streaming tracking sets.
    // Pause XR scene traversal while this registration pass runs.
    withWorldMutationGate {
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
    streaming.assetName = render.assetName // The specific mesh name within the USDZ

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
    withWorldMutationGate {
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
}
