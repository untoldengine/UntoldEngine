
//
//  RegistrationSystem.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit

@inline(__always)
private func enforceRegistrationMainActor() {
    // Registration and ECS state are synchronized with lock-backed globals.
}

private struct BoolCompletionBox: @unchecked Sendable {
    let callback: (Bool) -> Void

    func call(_ result: Bool) {
        if Thread.isMainThread {
            callback(result)
            return
        }
        Task { @MainActor in
            callback(result)
        }
    }
}

/// Ensures a continuation is resumed exactly once across two racing closures
/// (the work completer and the deadline timer).  NSLock makes it safe to call
/// from any thread/DispatchQueue without data races.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false

    /// Call `block` the first time; subsequent calls are no-ops.
    func callOnce(_ block: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !fired else { return }
        fired = true
        block()
    }
}

private final class RegistrationRuntimeState: @unchecked Sendable {
    let lock = NSLock()
    var pendingDestroyCompletions: [() -> Void] = []
    var componentCleanupHandlersRegistered = false
    var customComponentEncoderMap: [ObjectIdentifier: (EntityID) -> Data?] = [:]
    var customComponentDecoderMap: [String: (EntityID, Data) -> Void] = [:]
    var customComponentTypeNameById: [ObjectIdentifier: String] = [:]
}

private let registrationRuntimeState = RegistrationRuntimeState()

private var pendingDestroyCompletions: [() -> Void] {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.pendingDestroyCompletions
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.pendingDestroyCompletions = newValue
        registrationRuntimeState.lock.unlock()
    }
}

private let pendingDestroyCompletionsLock = NSLock()

private func enqueuePendingDestroyCompletion(_ completion: (() -> Void)?) {
    enforceRegistrationMainActor()
    guard let completion else { return }
    pendingDestroyCompletionsLock.lock()
    pendingDestroyCompletions.append(completion)
    pendingDestroyCompletionsLock.unlock()
}

private func runPendingDestroyCompletions() {
    enforceRegistrationMainActor()
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
private var componentCleanupHandlersRegistered: Bool {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.componentCleanupHandlersRegistered
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.componentCleanupHandlersRegistered = newValue
        registrationRuntimeState.lock.unlock()
    }
}

func ensureComponentCleanupHandlersRegistered() {
    enforceRegistrationMainActor()
    componentCleanupRegistrationLock.lock()
    defer { componentCleanupRegistrationLock.unlock() }

    guard componentCleanupHandlersRegistered == false else { return }
    registerComponentCleanupHandlers()
    componentCleanupHandlersRegistered = true
}

private func registerComponentCleanupHandlers() {
    enforceRegistrationMainActor()
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

    registerPhysicsComponentCleanupHandlers()

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

    ComponentRegistry.register(componentType: GaussianLODComponent.self, handlerId: "gaussianLOD", priority: 30) { entityId in
        removeEntityGaussianLOD(entityId: entityId)
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

    ComponentRegistry.register(componentType: TileComponent.self, handlerId: "tile", priority: 30) { entityId in
        removeTileComponent(entityId: entityId)
    }

    ComponentRegistry.register(componentType: TiledSceneComponent.self, handlerId: "tiledScene", priority: 30) { entityId in
        scene.remove(component: TiledSceneComponent.self, from: entityId)
    }

    ComponentRegistry.register(componentType: TileLODTagComponent.self, handlerId: "tileLODTag", priority: 30) { entityId in
        scene.remove(component: TileLODTagComponent.self, from: entityId)
    }
    ComponentRegistry.register(componentType: TileRepresentationFadeComponent.self, handlerId: "tileRepresentationFade", priority: 30) { entityId in
        scene.remove(component: TileRepresentationFadeComponent.self, from: entityId)
    }

    ComponentRegistry.register(componentType: GizmoComponent.self, handlerId: "gizmo", priority: 30) { entityId in
        removeEntityGizmo(entityId: entityId)
    }

    ComponentRegistry.register(componentType: PickInteractionComponent.self, handlerId: "pickInteraction", priority: 30) { entityId in
        removeEntityPickInteraction(entityId: entityId)
    }

    ComponentRegistry.register(componentType: EntitySceneChannelsComponent.self, handlerId: "sceneChannels", priority: 30) { entityId in
        removeEntitySceneChannels(entityId: entityId)
    }

    ComponentRegistry.register(componentType: LocalTransformComponent.self, handlerId: "transforms", priority: 90) { entityId in
        removeEntityTransforms(entityId: entityId)
    }
    ComponentRegistry.register(componentType: WorldTransformComponent.self, handlerId: "transforms", priority: 90) { entityId in
        removeEntityTransforms(entityId: entityId)
    }
}

public func createEntity() -> EntityID {
    enforceRegistrationMainActor()
    globalEntityCounter += 1
    let entity = scene.newEntity()
    makeSpatial(entityId: entity) // attach LocalTransform, WorldTransform, Scenegraph
    return entity
}

public func makeSpatial(entityId: EntityID) {
    enforceRegistrationMainActor()
    registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
    registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
    registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
}

public func registerComponent(entityId: EntityID, componentType: (some Component).Type) {
    enforceRegistrationMainActor()
    ensureComponentCleanupHandlersRegistered()
    if !ComponentRegistry.hasCleanupHandler(for: componentType) {
        ComponentRegistry.register(componentType: componentType, priority: 50) { entityId in
            scene.remove(component: componentType, from: entityId)
        }
    }
    _ = scene.assign(to: entityId, component: componentType)
}

public func destroyEntity(entityId: EntityID) {
    enforceRegistrationMainActor()
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
    enforceRegistrationMainActor()
    SceneAuthoredSourceStore.shared.clear()
    ColorLUTParams.shared.clear()
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
    enforceRegistrationMainActor()
    ensureComponentCleanupHandlersRegistered()

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

    // Prune destroyed entity IDs from the render-visible lists so the renderer does
    // not attempt to access non-existent entities for the 1–3 frames until the triple
    // buffer naturally rotates past the stale slots.
    //
    // This also covers the loading-gate window: while AssetLoadingGate.isLoadingAny is
    // true, RenderingSystem freezes visibleEntityIds and skips culling.  Concurrent tile
    // unloads during that window would otherwise leave stale IDs resident for the full
    // 1–2 s parse duration, not just a few frames.  Targeted removal (not clearAll) avoids
    // blanking the screen — only the just-destroyed entities are pruned.
    if !cleanedPendingEntities.isEmpty {
        visibleEntityIds.removeAll { cleanedPendingEntities.contains($0) }
        tripleVisibleEntities.remove(ids: cleanedPendingEntities)
        RenderPasses.invalidateShadowEntityCache()
    }
}

private struct ImportedLODLevelCandidate {
    let lodIndex: Int
    let sourceName: String
    let meshes: [Mesh]
}

private struct ImportedLODGroupCandidate {
    let baseName: String
    let levels: [ImportedLODLevelCandidate]
}

private func resolveImportedSourceName(for mesh: Mesh) -> String? {
    let sourceName = mesh.assetName.trimmingCharacters(in: .whitespacesAndNewlines)
    return sourceName.isEmpty ? nil : sourceName
}

private func splitMeshGroupBySourceName(_ meshGroup: [Mesh]) -> [String: [Mesh]] {
    var grouped: [String: [Mesh]] = [:]

    for mesh in meshGroup {
        guard let sourceName = resolveImportedSourceName(for: mesh) else {
            continue
        }
        grouped[sourceName, default: []].append(mesh)
    }

    return grouped
}

private func meshesWithDefaultSkin(_ meshes: [Mesh]) -> [Mesh] {
    var updatedMeshes = meshes
    let defaultSkin = Skin()
    for index in updatedMeshes.indices {
        if updatedMeshes[index].skin == nil {
            updatedMeshes[index].skin = defaultSkin
        }
    }
    return updatedMeshes
}

private func buildImportedLODLevels(from group: ImportedLODGroupCandidate, url: URL) -> [LODLevel] {
    let configuredDistances = LODConfig.shared.lodDistances
    let maxLODIndex = group.levels.map(\.lodIndex).max() ?? 0
    var lodLevels: [LODLevel] = (0 ... maxLODIndex).map { lodIndex in
        LODLevel(
            mesh: [],
            maxDistance: defaultLODMaxDistance(for: lodIndex, configuredDistances: configuredDistances),
            screenPercentage: 0.0,
            url: nil,
            assetName: nil
        )
    }

    for level in group.levels {
        let levelMeshes = meshesWithDefaultSkin(level.meshes)
        lodLevels[level.lodIndex] = LODLevel(
            mesh: levelMeshes,
            maxDistance: defaultLODMaxDistance(for: level.lodIndex, configuredDistances: configuredDistances),
            screenPercentage: 0.0,
            url: url,
            assetName: level.sourceName
        )
    }

    return lodLevels
}

private func configureLODComponent(entityId: EntityID, lodLevels: [LODLevel], activeLODIndex: Int) {
    if hasComponent(entityId: entityId, componentType: LODComponent.self) == false {
        registerComponent(entityId: entityId, componentType: LODComponent.self)
    }

    if let lodComponent = scene.get(component: LODComponent.self, for: entityId) {
        lodComponent.lodLevels = lodLevels
        lodComponent.currentLOD = activeLODIndex
        lodComponent.desiredLOD = activeLODIndex
        lodComponent.previousLOD = nil
        lodComponent.transitionProgress = 0.0
        lodComponent.isUsingFallback = false
    }
}

func applyWorldTransform(_ transform: simd_float4x4, to entityId: EntityID) {
    applyDecomposedTransform(transform, to: entityId)
}

private func applyLocalTransform(_ transform: simd_float4x4, to entityId: EntityID) {
    applyDecomposedTransform(transform, to: entityId)
}

private func applyDecomposedTransform(_ transform: simd_float4x4, to entityId: EntityID) {
    let translation = simd_float3(
        transform.columns.3.x,
        transform.columns.3.y,
        transform.columns.3.z
    )

    let xAxisWorld = simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
    let yAxisWorld = simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
    let zAxisWorld = simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)

    let scaleX = simd_length(xAxisWorld)
    let scaleY = simd_length(yAxisWorld)
    let scaleZ = simd_length(zAxisWorld)
    let scale = simd_float3(scaleX, scaleY, scaleZ)

    let epsilon: Float = 1e-6
    let nearZeroScaleAxis = scaleX < epsilon || scaleY < epsilon || scaleZ < epsilon

    var xAxis = scaleX < epsilon ? simd_float3(1, 0, 0) : (xAxisWorld / scaleX)
    var yAxis = scaleY < epsilon ? simd_float3(0, 1, 0) : (yAxisWorld / scaleY)
    var zAxis = scaleZ < epsilon ? simd_float3(0, 0, 1) : (zAxisWorld / scaleZ)

    xAxis = simd_normalize(xAxis)
    yAxis = simd_normalize(yAxis)
    zAxis = simd_normalize(zAxis)

    let rotationMatrix = matrix_float3x3(xAxis, yAxis, zAxis)
    let rotation = transformMatrix3nToQuaternion(m: rotationMatrix)
    let eulerAngles = transformQuaternionToEulerAngles(q: rotation)

    if nearZeroScaleAxis {
        Logger.logWarning(message: "Near-zero scale axis detected while decomposing imported transform for entity \(entityId). Rotation basis was clamped.")
    }

    if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
        localTransform.position = translation
        localTransform.rotation = rotation
        localTransform.scale = scale
        localTransform.rotationX = eulerAngles.pitch
        localTransform.rotationY = eulerAngles.yaw
        localTransform.rotationZ = eulerAngles.roll
        syncWorldTransformAndMarkOctreeDirty(entityId: entityId)
    }
}

private func applyImportedTransformFromMeshGroup(_ meshGroup: [Mesh], to entityId: EntityID) {
    guard let firstMesh = meshGroup.first else {
        return
    }
    applyWorldTransform(firstMesh.worldSpace, to: entityId)
}

@discardableResult

private func loadUntoldRuntimeAsset(url: URL) -> RuntimeAsset? {
    do {
        return try NativeFormatLoader().loadAssetSync(from: url)
    } catch {
        handleError(.assetLoadFailed, error.localizedDescription, url.lastPathComponent)
        return nil
    }
}

private func registerRuntimeSkeletonIfNeeded(entityId: EntityID, skeleton: RuntimeSkeleton?) {
    guard let skeleton else { return }
    guard let nativeSkeleton = Skeleton(runtimeSkeleton: skeleton) else { return }

    registerComponent(entityId: entityId, componentType: SkeletonComponent.self)
    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        handleError(.noSkeletonComponent, entityId)
        return
    }
    skeletonComponent.skeleton = nativeSkeleton
}

private func resolvedRuntimeSkeleton(
    for node: RuntimeAssetNode,
    nodesByID: [UInt32: RuntimeAssetNode]
) -> RuntimeSkeleton? {
    if let skeleton = node.skeleton {
        return skeleton
    }

    for primitive in node.primitives {
        if let skeletonEntityID = primitive.skin?.skeletonEntityID,
           let referencedSkeleton = nodesByID[skeletonEntityID]?.skeleton
        {
            return referencedSkeleton
        }
    }

    return nil
}

private func assignRuntimeSkins(entityId: EntityID, node: RuntimeAssetNode) {
    guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }
    guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId) else {
        return
    }

    // Match the USDZ skinning path: initialize skin buffers from the skeleton's
    // bind-adjusted rest pose before any animation playback occurs.
    skeletonComponent.skeleton.resetPoseToRest()

    let count = min(renderComponent.mesh.count, node.primitives.count)
    for index in 0 ..< count {
        guard let runtimeSkin = node.primitives[index].skin else { continue }
        var mesh = renderComponent.mesh[index]
        mesh.skin = Skin(runtimeSkin: runtimeSkin)
        mesh.skin?.updateJointMatrices(skeleton: skeletonComponent.skeleton)
        renderComponent.mesh[index] = mesh
    }
    entityMeshMap[entityId] = renderComponent.mesh
}

private func ensureUntoldNodeComponents(entityId: EntityID) {
    if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
        registerTransformComponent(entityId: entityId)
    }

    if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
        registerSceneGraphComponent(entityId: entityId)
    }
}

func makeMeshes(from node: RuntimeAssetNode) -> [Mesh] {
    node.primitives.compactMap { primitive -> Mesh? in
        guard var mesh = Mesh.makeMesh(from: primitive, device: renderInfo.device) else {
            return nil
        }
        mesh.localSpace = matrix_identity_float4x4
        mesh.worldSpace = matrix_identity_float4x4
        return mesh
    }
}

/// Pre-build Metal meshes for all renderable nodes in a runtime asset.
/// Returns a map of nodeID → [Mesh] built via makeMeshes() — pure MTLBuffer allocation,
/// no ECS access. Safe to call outside withWorldMutationGate.
func prebuildNodeMeshes(from nodes: [RuntimeAssetNode]) -> [UInt32: [Mesh]] {
    var result: [UInt32: [Mesh]] = [:]
    for node in nodes where !node.primitives.isEmpty {
        let meshes = makeMeshes(from: node)
        if !meshes.isEmpty {
            result[node.id] = meshes
        }
    }
    return result
}

/// Register one RuntimeAssetNode as a zero-GPU OCC stub entity.
///
/// Creates the ECS presence (transform, scenegraph, streaming component) with no GPU allocation.
/// GeometryStreamingSystem uploads via uploadFromRuntimeEntry when the entity enters streaming range.
///
/// - Parameters:
///   - parentEntityId: The direct scene-graph parent (may be a container node, not always the asset root).
///   - rootEntityId: The asset root entity used for DerivedAssetNodeComponent tracking.
@discardableResult
private func registerUntoldProgressiveStubEntity(
    node: RuntimeAssetNode,
    index: Int,
    uniqueAssetName: String,
    parentEntityId: EntityID,
    rootEntityId: EntityID,
    url _: URL,
    filename: String,
    withExtension ext: String
) -> EntityID {
    let childEntityId = createEntity()

    ensureUntoldNodeComponents(entityId: childEntityId)

    // Compute the local transform that will produce node.worldTransform after parenting.
    // After setParent: childWorld = parentWorld × childLocal
    // We want childWorld = node.worldTransform, so:
    //   childLocal = inverse(parentWorld) × node.worldTransform
    // For tile geometry (parentWorld = identity) this equals node.worldTransform directly.
    // For non-identity parents this prevents double-application of the parent transform.
    let parentWorldTransform = scene.get(component: WorldTransformComponent.self, for: parentEntityId)?.space
        ?? matrix_identity_float4x4
    let localTransform = simd_mul(parentWorldTransform.inverse, node.worldTransform)
    applyLocalTransform(localTransform, to: childEntityId)

    if let local = scene.get(component: LocalTransformComponent.self, for: childEntityId) {
        local.boundingBox = (min: node.localBounds.min, max: node.localBounds.max)
    }

    setEntityName(entityId: childEntityId, name: uniqueAssetName)
    setParent(childId: childEntityId, parentId: parentEntityId)

    // Register with the octree so GeometryStreamingSystem.update() finds this stub
    // via queryNear. Without this, the stub is invisible to the streaming scheduler.
    OctreeSystem.shared.registerEntity(childEntityId)

    let nodePath = generateStableNodePath(assetName: uniqueAssetName, index: index)
    registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
    if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
        derived.assetRootEntityId = rootEntityId
        derived.nodePath = nodePath
    }

    registerComponent(entityId: childEntityId, componentType: StreamingComponent.self)
    if let sc = scene.get(component: StreamingComponent.self, for: childEntityId) {
        sc.assetFilename = filename
        sc.assetExtension = ext
        sc.assetName = uniqueAssetName
        sc.state = .unloaded
        // Placeholder radii — enableStreaming() (called by GeometryStreamingSystem via tile) sets real values.
        sc.streamingRadius = Float.greatestFiniteMagnitude
        sc.unloadRadius = Float.greatestFiniteMagnitude
    }
    setDefaultEntitySceneChannels(entityId: childEntityId, channels: defaultSceneChannels(forName: uniqueAssetName))

    return childEntityId
}

/// Register all renderable nodes in a .untold RuntimeAsset as OCC stub entities.
///
/// Each node with primitives becomes a zero-GPU child stub with StreamingComponent(.unloaded)
/// and a CPURuntimeEntry in ProgressiveAssetLoader. Container nodes (no primitives) become
/// plain hierarchy entities. Renderable nodes are always created as CHILDREN of entityId
/// (never as entityId itself) so countOCCDescendants finds them correctly.
///
/// Hierarchy is preserved: a renderable node whose parentID points to a container node is
/// parented to that container entity, not directly to entityId.
@discardableResult
private func registerUntoldRuntimeAssetOCC(
    entityId: EntityID,
    runtimeAsset: RuntimeAsset,
    url: URL,
    filename: String,
    withExtension ext: String,
    assetName _: String?
) -> Bool {
    guard !runtimeAsset.nodes.isEmpty else {
        handleError(.assetDataMissing, filename)
        return false
    }

    ensureUntoldNodeComponents(entityId: entityId)
    applyLocalTransform(runtimeAsset.rootTransform, to: entityId)

    var entityByNodeID: [UInt32: EntityID] = [:]
    var childIds: [EntityID] = []
    var index = 0

    let residencyPolicy = AssetLoadingPolicy(geometry: .streaming, texture: .eager, source: .auto)

    for node in runtimeAsset.nodes {
        if node.primitives.isEmpty {
            // Container node — hierarchy entity only, no StreamingComponent.
            let containerEntityId = createEntity()
            ensureUntoldNodeComponents(entityId: containerEntityId)
            applyLocalTransform(node.localTransform, to: containerEntityId)
            setEntityName(entityId: containerEntityId, name: node.name)
            let parentEntityId = node.parentID.flatMap { entityByNodeID[$0] } ?? entityId
            setParent(childId: containerEntityId, parentId: parentEntityId)
            entityByNodeID[node.id] = containerEntityId

        } else {
            // Renderable node — always a CHILD OCC stub (never the root entity).
            // This ensures countOCCDescendants finds it correctly even for single-node assets.
            let uniqueName = runtimeAsset.nodes.filter { !$0.primitives.isEmpty }.count == 1
                ? node.name
                : "\(node.name)#\(index)"
            // Parent to the node's actual parent (container) if it has one; otherwise to entityId.
            let parentEntityId = node.parentID.flatMap { entityByNodeID[$0] } ?? entityId
            let childEntityId = registerUntoldProgressiveStubEntity(
                node: node,
                index: index,
                uniqueAssetName: uniqueName,
                parentEntityId: parentEntityId,
                rootEntityId: entityId,
                url: url,
                filename: filename,
                withExtension: ext
            )

            let estimatedBytes = node.primitives.reduce(0) { $0 + $1.estimatedGPUBytes }
            let entry = ProgressiveAssetLoader.CPURuntimeEntry(
                node: node,
                url: url,
                uniqueAssetName: uniqueName,
                estimatedGPUBytes: estimatedBytes,
                residencyPolicy: residencyPolicy
            )
            ProgressiveAssetLoader.shared.storeCPURuntimeEntry(entry, for: childEntityId)
            childIds.append(childEntityId)
            entityByNodeID[node.id] = childEntityId
            index += 1
        }
    }

    ProgressiveAssetLoader.shared.registerChildren(childIds, for: entityId)
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)

    Logger.log(
        message: "[OutOfCore] '\(filename)': .untold → OCC stub registration (\(childIds.count) stubs)",
        category: LogCategory.oocStatus.rawValue
    )
    return true
}

@discardableResult
private func registerUntoldNodePayload(
    entityId: EntityID,
    node: RuntimeAssetNode,
    nodesByID: [UInt32: RuntimeAssetNode],
    url: URL,
    prebuiltMeshes: [Mesh]? = nil
) -> Bool {
    // Use pre-built meshes when provided (built outside withWorldMutationGate to avoid
    // long gate holds); fall back to makeMeshes() for synchronous call sites.
    let meshes = prebuiltMeshes ?? makeMeshes(from: node)
    guard !meshes.isEmpty else { return false }

    associateMeshesToEntity(entityId: entityId, meshes: meshes)
    registerRenderComponent(entityId: entityId, meshes: meshes, url: url, assetName: node.name)
    registerRuntimeSkeletonIfNeeded(
        entityId: entityId,
        skeleton: resolvedRuntimeSkeleton(for: node, nodesByID: nodesByID)
    )
    assignRuntimeSkins(entityId: entityId, node: node)
    return true
}

private func ensureAnimationComponent(entityId: EntityID, errorEntityId: EntityID) -> AnimationComponent? {
    if let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) {
        return animationComponent
    }

    registerComponent(entityId: entityId, componentType: AnimationComponent.self)
    guard let animationComponent = scene.get(component: AnimationComponent.self, for: entityId) else {
        handleError(.noAnimationComponent, errorEntityId)
        return nil
    }

    return animationComponent
}

private func registerRuntimeAnimationClips(
    _ runtimeClips: [RuntimeAnimationClip],
    preferredName: String,
    to animationComponent: AnimationComponent
) -> [String] {
    var registeredNames: [String] = []

    for runtimeClip in runtimeClips {
        let animationClip = AnimationClip(runtimeClip: runtimeClip)
        animationComponent.animationClips[runtimeClip.name] = animationClip
        registeredNames.append(runtimeClip.name)
    }

    if runtimeClips.count == 1,
       let runtimeClip = runtimeClips.first,
       preferredName.isEmpty == false,
       preferredName != runtimeClip.name
    {
        animationComponent.animationClips[preferredName] = AnimationClip(runtimeClip: runtimeClip)
        registeredNames.append(preferredName)
    }

    return registeredNames
}

private func appendAnimationSourceURLIfNeeded(_ url: URL, to animationComponent: AnimationComponent) {
    if animationComponent.animationsFilenames.contains(url) == false {
        animationComponent.animationsFilenames.append(url)
    }
}

private func buildUntoldNodePath(nodeID: UInt32, nodesByID: [UInt32: RuntimeAssetNode]) -> String {
    guard let node = nodesByID[nodeID] else {
        return "Root/Unknown#\(nodeID)"
    }

    let nodeSegment = "\(node.name)#\(node.id)"
    if let parentID = node.parentID {
        let parentPath = buildUntoldNodePath(nodeID: parentID, nodesByID: nodesByID)
        return "\(parentPath)/\(nodeSegment)"
    }

    return "Root/\(nodeSegment)"
}

private func registerUntoldRuntimeAsset(
    entityId: EntityID,
    runtimeAsset: RuntimeAsset,
    url: URL,
    filename: String,
    withExtension: String,
    assetName: String? = nil,
    prebuiltMeshes: [UInt32: [Mesh]] = [:]
) -> Bool {
    guard !runtimeAsset.nodes.isEmpty else {
        handleError(.assetDataMissing, filename)
        return false
    }

    // Named-node path: caller requested a specific node by name.
    // Find the first matching node, register its primitives directly on entityId,
    // and return — no hierarchy, no child entities.
    if let assetName {
        guard let matchedNode = runtimeAsset.nodes.first(where: { $0.name == assetName }) else {
            handleError(.assetDataMissing, "No node named '\(assetName)' in '\(filename).\(withExtension)'")
            return false
        }
        let nodesByID = Dictionary(uniqueKeysWithValues: runtimeAsset.nodes.map { ($0.id, $0) })

        ensureUntoldNodeComponents(entityId: entityId)
        applyLocalTransform(matchedNode.localTransform, to: entityId)
        setEntityName(entityId: entityId, name: matchedNode.name)

        guard matchedNode.primitives.isEmpty == false else {
            handleError(.assetDataMissing, "Node '\(assetName)' in '\(filename).\(withExtension)' has no renderable primitives")
            return false
        }

        guard registerUntoldNodePayload(
            entityId: entityId,
            node: matchedNode,
            nodesByID: nodesByID,
            url: url,
            prebuiltMeshes: prebuiltMeshes[matchedNode.id]
        ) else {
            handleError(.assetDataMissing, "Node '\(assetName)' in '\(filename).\(withExtension)' has no renderable primitives")
            return false
        }
        return true
    }

    ensureUntoldNodeComponents(entityId: entityId)
    applyLocalTransform(runtimeAsset.rootTransform, to: entityId)

    let hasHierarchy = runtimeAsset.nodes.count > 1 || runtimeAsset.nodes.contains(where: { $0.parentID != nil || $0.primitives.isEmpty })
    if hasHierarchy {
        let assetInstanceComp = AssetInstanceComponent(
            assetURL: url,
            assetName: runtimeAsset.assetName,
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

    let nodesByID = Dictionary(uniqueKeysWithValues: runtimeAsset.nodes.map { ($0.id, $0) })
    var entityByNodeID: [UInt32: EntityID] = [:]

    for node in runtimeAsset.nodes {
        let targetEntityId: EntityID
        if runtimeAsset.nodes.count == 1, node.parentID == nil {
            // Single-node asset: the caller's entity IS the mesh node.
            targetEntityId = entityId
        } else {
            // Multi-node scene: entityId is the parent container (identity transform);
            // every scene node gets its own entity so no node hijacks the root.
            targetEntityId = createEntity()
        }

        entityByNodeID[node.id] = targetEntityId

        ensureUntoldNodeComponents(entityId: targetEntityId)
        applyLocalTransform(node.localTransform, to: targetEntityId)
        setEntityName(entityId: targetEntityId, name: node.name)

        if targetEntityId != entityId {
            let parentEntityId = node.parentID.flatMap { entityByNodeID[$0] } ?? entityId
            setParent(childId: targetEntityId, parentId: parentEntityId)

            let derivedComp = DerivedAssetNodeComponent(
                assetRootEntityId: entityId,
                nodePath: buildUntoldNodePath(nodeID: node.id, nodesByID: nodesByID)
            )
            registerComponent(entityId: targetEntityId, componentType: DerivedAssetNodeComponent.self)
            if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: targetEntityId) {
                derived.assetRootEntityId = derivedComp.assetRootEntityId
                derived.nodePath = derivedComp.nodePath
            }
        }

        guard !node.primitives.isEmpty else {
            registerRuntimeSkeletonIfNeeded(
                entityId: targetEntityId,
                skeleton: resolvedRuntimeSkeleton(for: node, nodesByID: nodesByID)
            )
            continue
        }

        _ = registerUntoldNodePayload(
            entityId: targetEntityId,
            node: node,
            nodesByID: nodesByID,
            url: url,
            prebuiltMeshes: prebuiltMeshes[node.id]
        )
    }

    // Register animation clips embedded in the asset (e.g. redplayer.untold walk/run cycles).
    // Resolve to every skinned descendant so split characters animate all meshes.
    let animClips = runtimeAsset.animationClips
    if !animClips.isEmpty {
        let animTargets = resolveAnimationBindingTargetEntities(entityId: entityId)
        for animTarget in animTargets {
            if let animComp = ensureAnimationComponent(entityId: animTarget, errorEntityId: entityId) {
                let registeredNames = registerRuntimeAnimationClips(animClips, preferredName: animClips.first?.name ?? "", to: animComp)
                appendAnimationSourceURLIfNeeded(url, to: animComp)
                if animComp.currentAnimation == nil, let first = registeredNames.first {
                    animComp.currentAnimation = animComp.animationClips[first]
                }
            }
        }
    }

    // Propagate world transforms for the full hierarchy now that all nodes are
    // registered. setParent() calls syncWorldTransformAndMarkOctreeDirty on each
    // child, but at that point the root entity's worldTransformComponent.space has
    // not yet been updated from its localTransform (e.g. the 90° X rotation baked
    // into the Armature node by the exporter). Re-running the propagation from the
    // root after the loop ensures every descendant inherits the correct world transform.
    syncWorldTransformAndMarkOctreeDirty(entityId: entityId)

    return true
}

/// Generate a stable node path for a derived mesh node
func generateStableNodePath(assetName: String, index: Int) -> String {
    // Use a deterministic format: "Root/<AssetName>#<Index>"
    // This ensures the same USDZ file produces the same nodePath each time
    "Root/\(assetName)#\(index)"
}

// Synchronously load and set an entity mesh on the calling thread.
//
// This API always uses the **immediate** path: all Metal resources are created in a single
// pass before the function returns. It does not support out-of-core stub registration or
// distance-based streaming — the mesh is permanently GPU-resident after this call.
//
// For large assets or any asset that should benefit from distance-based streaming and
// eviction, use `setEntityMeshAsync(streamingPolicy:)` instead.

/// Controls how `setEntityMeshAsync` manages GPU residency for a loaded asset.
public enum MeshStreamingPolicy: Sendable {
    /// Automatic: uses `ProgressiveAssetLoader.fileSizeThresholdBytes` and
    /// `outOfCoreObjectCountThreshold` to decide. Large or many-object assets
    /// go out-of-core; small assets upload directly. Default.
    case auto

    /// Always register leaf meshes as `.unloaded` stub entities. The streaming
    /// system uploads each mesh to the GPU when the camera enters `streamingRadius`
    /// and evicts it when the camera moves beyond `unloadRadius`.
    ///
    /// The completion callback fires immediately after stub registration — no GPU
    /// work happens at load time. **You must call `enableStreaming(entityId:streamingRadius:unloadRadius:)`
    /// inside the completion block** so the streaming system knows the real radii.
    case outOfCore

    /// Always upload directly to the GPU in a single pass. The mesh is permanently
    /// resident and is never evicted by the streaming system. Use for small assets
    /// that must be visible without any streaming delay (e.g. character, weapon, HUD).
    case immediate
}

private let untoldImportedMinimumLightRadius: Float = 0.001
private let untoldImportedMinimumSpotConeAngle: Float = 0.1
private let untoldImportedMaximumSpotConeAngle: Float = 89.0
private let untoldImportedMinimumSpotConeSeparation: Float = 0.05

private func normalizedImportedDirection(_ direction: simd_float3, fallback: simd_float3) -> simd_float3 {
    simd_length_squared(direction) > 1.0e-8 ? simd_normalize(direction) : fallback
}

private func importedTransformAxis(_ transform: simd_float4x4, column: Int, fallback: simd_float3) -> simd_float3 {
    let vector = switch column {
    case 0:
        simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
    case 1:
        simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
    default:
        simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
    }
    return normalizedImportedDirection(vector, fallback: fallback)
}

private func importedTransformPosition(_ transform: simd_float4x4) -> simd_float3 {
    simd_float3(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
}

private func scaleImportedAreaLight(_ areaSize: simd_float2, entityId: EntityID) {
    guard let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let currentScale = localTransform.scale
    let dimensions = getDimension(entityId: entityId)
    let baseWidth = abs(currentScale.x) > 1.0e-6 ? dimensions.width / currentScale.x : dimensions.width
    let baseHeight = abs(currentScale.y) > 1.0e-6 ? dimensions.height / currentScale.y : dimensions.height

    let targetWidth = max(areaSize.x, untoldImportedMinimumLightRadius)
    let targetHeight = max(areaSize.y, untoldImportedMinimumLightRadius)
    let nextScaleX = abs(baseWidth) > 1.0e-6 ? currentScale.x * (targetWidth / baseWidth) : currentScale.x
    let nextScaleY = abs(baseHeight) > 1.0e-6 ? currentScale.y * (targetHeight / baseHeight) : currentScale.y

    scaleTo(entityId: entityId, scale: simd_float3(nextScaleX, nextScaleY, currentScale.z))
}

private func registerUntoldScenePayload(from runtimeAsset: RuntimeAsset) {
    for light in runtimeAsset.lights {
        registerUntoldLight(light)
    }
    for camera in runtimeAsset.cameras {
        registerUntoldCamera(camera)
    }
}

/// Loads the baked color-grading LUT and applies it as global rendering
/// state. Unlike lights/cameras this creates no entity — it's scene-wide.
private func replaceColorManagement(_ colorManagement: RuntimeColorManagement?) {
    // Replacement is transactional from the renderer's perspective: clear the
    // previous scene first, then publish the new texture and all parameters as
    // one locked snapshot only after validation and loading succeed.
    ColorLUTParams.shared.clear()

    guard let colorManagement else {
        return
    }

    guard colorManagement.lutSize >= 2,
          colorManagement.lutSize <= 64,
          colorManagement.shaperMinStops.isFinite,
          colorManagement.shaperMaxStops.isFinite,
          colorManagement.shaperMaxStops > colorManagement.shaperMinStops
    else {
        Logger.log(
            message: "[UntoldColorManagement] Invalid LUT parameters; using the default tonemap",
            category: LogCategory.textureLoading.rawValue
        )
        return
    }

    guard let texture = loadColorLUTTexture(colorManagement.lutTexture) else {
        Logger.log(
            message: "[UntoldColorManagement] LUT texture failed to load; falling back to the default tonemap",
            category: LogCategory.textureLoading.rawValue
        )
        return
    }
    let expectedWidth = colorManagement.lutSize * colorManagement.lutSize
    guard texture.width == expectedWidth, texture.height == colorManagement.lutSize else {
        Logger.log(
            message: "[UntoldColorManagement] LUT dimensions \(texture.width)x\(texture.height) do not match expected \(expectedWidth)x\(colorManagement.lutSize); using the default tonemap",
            category: LogCategory.textureLoading.rawValue
        )
        return
    }

    ColorLUTParams.shared.replace(
        texture: texture,
        shaperMinStops: colorManagement.shaperMinStops,
        shaperMaxStops: colorManagement.shaperMaxStops,
        lutSize: colorManagement.lutSize
    )
}

private func loadColorLUTTexture(_ reference: RuntimeTextureReference?) -> MTLTexture? {
    guard let reference, let url = reference.sourceURL else { return nil }

    // The LUT is always non-color data and must never be mip-filtered —
    // interpolating between mip levels would blend unrelated lookup cells.
    if reference.textureFormat.isNativeContainer {
        return NativeTextureLoader(device: renderInfo.device)?.loadTexture(from: url, label: "color_grade_lut")
    }

    let textureLoader = MTKTextureLoader(device: renderInfo.device)
    let options: [MTKTextureLoader.Option: Any] = [
        .textureUsage: NSNumber(value: MTLTextureUsage([.shaderRead]).rawValue),
        .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
        .SRGB: NSNumber(value: false),
        .generateMipmaps: NSNumber(value: false),
    ]
    do {
        return try textureLoader.newTexture(URL: url, options: options)
    } catch {
        handleError(.textureFailedLoading, "Color grading LUT \(error.localizedDescription)", reference.name ?? "<unnamed>")
        return nil
    }
}

private func registerUntoldLight(_ light: RuntimeLightSource) {
    let lightEntityId = createEntity()

    switch light.kind {
    case .directional:
        createDirLight(entityId: lightEntityId)
    case .point:
        createPointLight(entityId: lightEntityId)
    case .spot:
        createSpotLight(entityId: lightEntityId)
    case .area:
        createAreaLight(entityId: lightEntityId)
    }

    setEntityName(entityId: lightEntityId, name: light.name ?? "Imported Light")
    applyLocalTransform(light.localTransform, to: lightEntityId)

    if let lightComponent = scene.get(component: LightComponent.self, for: lightEntityId) {
        lightComponent.color = light.color
        lightComponent.intensity = light.intensity
        lightComponent.usesRadiometricUnits = light.usesRadiometricUnits
        updateMaterialEmmisive(entityId: lightEntityId, emmissive: light.color)
    }

    switch light.kind {
    case .directional:
        scene.get(component: DirectionalLightComponent.self, for: lightEntityId)?.castsShadow = light.castsShadow
        setDirectionalLight(.active(lightEntityId))

    case .point:
        if let pointLight = scene.get(component: PointLightComponent.self, for: lightEntityId) {
            pointLight.radius = max(light.radius, untoldImportedMinimumLightRadius)
            pointLight.range = max(light.range, 0.0)
            pointLight.falloff = simd_clamp(light.falloff, 0.0, 1.0)
            pointLight.castsShadow = light.castsShadow
        }

    case .spot:
        if let spotLight = scene.get(component: SpotLightComponent.self, for: lightEntityId) {
            spotLight.radius = max(light.radius, untoldImportedMinimumLightRadius)
            spotLight.range = max(light.range, 0.0)
            spotLight.falloff = simd_clamp(light.falloff, 0.0, 1.0)
            spotLight.castsShadow = light.castsShadow
            spotLight.innerCone = simd_clamp(light.innerCone, untoldImportedMinimumSpotConeAngle, untoldImportedMaximumSpotConeAngle)
            spotLight.outerCone = simd_clamp(light.outerCone, untoldImportedMinimumSpotConeAngle, untoldImportedMaximumSpotConeAngle)
            if spotLight.innerCone >= spotLight.outerCone {
                spotLight.innerCone = max(untoldImportedMinimumSpotConeAngle, spotLight.outerCone - untoldImportedMinimumSpotConeSeparation)
            }
            spotLight.coneAngle = spotLight.outerCone
        }

    case .area:
        if let areaLight = scene.get(component: AreaLightComponent.self, for: lightEntityId) {
            scaleImportedAreaLight(light.areaSize, entityId: lightEntityId)
            areaLight.bounds = simd_float2(
                max(light.areaSize.x, untoldImportedMinimumLightRadius),
                max(light.areaSize.y, untoldImportedMinimumLightRadius)
            )
            areaLight.range = max(light.range, 0.0)
            areaLight.castsShadow = light.castsShadow
        }
    }
}

private func registerUntoldCamera(_ camera: RuntimeCameraSource) {
    let gameCamera = createEntity()
    createGameCamera(entityId: gameCamera)
    setCamera(.active(gameCamera))
    setCamera(.defaultFOV(camera.fovYDegrees))
    setCamera(.clipPlanes(near: camera.nearClip, far: camera.farClip))
    setEntityName(entityId: gameCamera, name: camera.name ?? "Imported Camera")

    if hasComponent(entityId: gameCamera, componentType: LocalTransformComponent.self) == false {
        registerTransformComponent(entityId: gameCamera)
    }
    if hasComponent(entityId: gameCamera, componentType: ScenegraphComponent.self) == false {
        registerSceneGraphComponent(entityId: gameCamera)
    }

    let position = importedTransformPosition(camera.localTransform)
    let forward = importedTransformAxis(camera.localTransform, column: 2, fallback: simd_float3(0.0, 0.0, 1.0))
    let up = importedTransformAxis(camera.localTransform, column: 1, fallback: simd_float3(0.0, 1.0, 0.0))
    cameraLookAt(
        entityId: gameCamera,
        eye: position,
        target: position + forward,
        up: up
    )
}

/// Synchronously load a .untold mesh onto an entity.
///
/// Blocks the calling thread until the asset is fully registered and GPU-resident.
/// Use for small, always-resident assets where you need the mesh available on the
/// next line (e.g. scene initialisation, editor tooling, simple demos).
///
/// For large assets or anything loaded at runtime, prefer `setEntityMeshAsync` —
/// it loads off the main thread and avoids frame hitches.
public func setEntityMesh(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    assetName: String? = nil
) {
    guard let url = LoadingSystem.shared.resourceURL(
        forResource: filename,
        withExtension: withExtension,
        subResource: nil
    ) else {
        handleError(.filenameNotFound, filename)
        loadFallbackMesh(entityId: entityId, filename: filename)
        return
    }

    guard RuntimeAssetSource.infer(from: url).kind == .untold else {
        Logger.logWarning(message: "[RegistrationSystem] setEntityMesh only supports .untold assets. Use setEntityMeshAsync for other formats.")
        loadFallbackMesh(entityId: entityId, filename: filename)
        return
    }

    guard let runtimeAsset = loadUntoldRuntimeAsset(url: url) else {
        loadFallbackMesh(entityId: entityId, filename: filename)
        return
    }

    let didLoad = registerUntoldRuntimeAsset(
        entityId: entityId,
        runtimeAsset: runtimeAsset,
        url: url,
        filename: filename,
        withExtension: withExtension,
        assetName: assetName
    )

    if !didLoad {
        loadFallbackMesh(entityId: entityId, filename: filename)
    }

    RenderPasses.invalidateShadowEntityCache()
}

/// Asynchronously load and set entity mesh without blocking the main thread
public func setEntityMeshAsync(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    assetName: String? = nil,
    flip _: Bool = true,
    coordinateConversion _: CoordinateSystemConversion = .autoDetect,
    streamingPolicy: MeshStreamingPolicy = .immediate,
    blockRenderLoop: Bool = true,
    completion: ((Bool) -> Void)? = nil
) {
    let completionBox = completion.map { BoolCompletionBox(callback: $0) }

    Task {
        // Track progress for the whole async load.  Tile streaming passes
        // blockRenderLoop:false so parsing does not freeze culling; only the short
        // withWorldMutationGate registration sections pause render traversal.
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: filename, blockRenderLoop: blockRenderLoop)

        // Get URL
        guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
            handleError(.filenameNotFound, filename)
            withWorldMutationGate {
                loadFallbackMesh(entityId: entityId, filename: filename)
            }
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(false)
            return
        }

        if url.pathExtension == "dae" {
            handleError(.fileTypeNotSupported, url.pathExtension)
            withWorldMutationGate {
                loadFallbackMesh(entityId: entityId, filename: filename)
            }
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(false)
            return
        }

        if RuntimeAssetSource.infer(from: url).kind == .untold {
            guard let runtimeAsset = loadUntoldRuntimeAsset(url: url) else {
                withWorldMutationGate {
                    loadFallbackMesh(entityId: entityId, filename: filename)
                }
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(false)
                return
            }

            // OCC is only valid for whole-asset loads. Named-node loads always full-load.
            let useOCC: Bool
            if assetName != nil {
                useOCC = false
            } else {
                switch streamingPolicy {
                case .immediate:
                    useOCC = false
                case .outOfCore:
                    useOCC = true
                case .auto:
                    let renderableNodes = runtimeAsset.nodes.filter { !$0.primitives.isEmpty }
                    let estimatedGeometryBytes = renderableNodes
                        .flatMap(\.primitives)
                        .reduce(0) { $0 + $1.estimatedGPUBytes }
                    let budget = MemoryBudgetManager.shared.geometryBudget
                    let budgetFraction: Float = budget > 0
                        ? Float(estimatedGeometryBytes) / Float(budget)
                        : 1.0
                    useOCC = renderableNodes.count >= 50 || budgetFraction > 0.30
                }
            }

            // Pre-build Metal buffers for all renderable nodes BEFORE acquiring the gate.
            // makeMeshes() allocates MTLBuffers — pure GPU-resource work with no ECS access.
            // Keeping this inside withWorldMutationGate was the root cause of 30-40ms gate
            // holds during HLOD and LOD tile registration, which blocked the main thread.
            // OCC path builds meshes separately (CPU→GPU upload), so no pre-build needed there.
            let prebuiltMeshes: [UInt32: [Mesh]] = useOCC ? [:] : prebuildNodeMeshes(from: runtimeAsset.nodes)

            let didLoad: Bool = withWorldMutationGate {
                if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
                    registerTransformComponent(entityId: entityId)
                }

                if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
                    registerSceneGraphComponent(entityId: entityId)
                }

                let loaded: Bool
                if useOCC {
                    loaded = registerUntoldRuntimeAssetOCC(
                        entityId: entityId,
                        runtimeAsset: runtimeAsset,
                        url: url,
                        filename: filename,
                        withExtension: withExtension,
                        assetName: assetName
                    )
                } else {
                    loaded = registerUntoldRuntimeAsset(
                        entityId: entityId,
                        runtimeAsset: runtimeAsset,
                        url: url,
                        filename: filename,
                        withExtension: withExtension,
                        assetName: assetName,
                        prebuiltMeshes: prebuiltMeshes
                    )
                }

                if !loaded {
                    loadFallbackMesh(entityId: entityId, filename: filename)
                }

                // Non-streaming entities don't fire residency events, so the shadow
                // entity candidate cache must be explicitly invalidated here.
                // Without this, the entity is never added to shadow candidates after
                // the initial (empty) cache rebuild on the first shadow-pass frame.
                RenderPasses.invalidateShadowEntityCache()

                return loaded
            }

            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(didLoad)
            return
        }

        // Non-.untold assets are not supported. Log and return a fallback.
        Logger.logWarning(message: "[RegistrationSystem] Only .untold format is supported. Ignoring '\(filename).\(withExtension)'.")
        withWorldMutationGate {
            loadFallbackMesh(entityId: entityId, filename: filename)
            RenderPasses.invalidateShadowEntityCache()
        }
        await AssetLoadingState.shared.finishLoading(entityId: entityId)
        completionBox?.call(false)
    }
}

/// Loads scene-authored lights/cameras and replaces the active scene color
/// management from a `.untold` asset, separate from any mesh load.
///
/// Call this alongside `setEntityMeshAsync` when you want to bring scene-authored
/// lights and cameras from an exported asset into the current scene without coupling
/// them to the mesh entity's transform.
public func loadSceneAuthored(
    filename: String,
    withExtension ext: String,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    loadSceneAuthored(filename: filename, withExtension: ext, registerEntities: true, completion: completion)
}

private func loadSceneAuthored(
    filename: String,
    withExtension ext: String,
    registerEntities: Bool,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    Task {
        ColorLUTParams.shared.clear()
        SceneAuthoredSourceStore.shared.clear()
        guard let url = LoadingSystem.shared.resourceURL(
            forResource: filename, withExtension: ext, subResource: nil
        ) else {
            handleError(.filenameNotFound, filename)
            completion?(false)
            return
        }

        guard RuntimeAssetSource.infer(from: url).kind == .untold else {
            Logger.logWarning(message: "[RegistrationSystem] loadSceneAuthored only supports .untold assets.")
            completion?(false)
            return
        }

        let sourceReference = sceneAssetReference(
            kind: .model,
            url: url,
            displayName: url.deletingPathExtension().lastPathComponent
        )
        guard let runtimeAsset = loadUntoldRuntimeAsset(url: url) else {
            completion?(false)
            return
        }

        replaceColorManagement(runtimeAsset.colorManagement)
        SceneAuthoredSourceStore.shared.source = sourceReference
        if registerEntities {
            withWorldMutationGate {
                registerUntoldScenePayload(from: runtimeAsset)
            }
        }
        completion?(true)
    }
}

/// Loads scene-authored lights/cameras and replaces the active scene color
/// management from a `.json` tile manifest, separate from tile residency.
///
/// Call this alongside `setEntityStreamScene` when the manifest contains
/// `scene_lights` / `scene_cameras` you want imported into the current scene.
public func loadSceneAuthored(
    url manifestURL: URL,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    loadSceneAuthored(url: manifestURL, registerEntities: true, completion: completion)
}

private func loadSceneAuthored(
    url manifestURL: URL,
    registerEntities: Bool,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    Task {
        ColorLUTParams.shared.clear()
        SceneAuthoredSourceStore.shared.clear()
        do {
            let localURL: URL
            if manifestURL.scheme?.lowercased() == "https" {
                localURL = try await RemoteAssetDownloader.shared.localURL(for: manifestURL)
            } else if manifestURL.scheme?.lowercased() == "http" {
                throw RemoteAssetDownloader.DownloadError.insecureScheme("http")
            } else {
                localURL = manifestURL
            }

            guard let data = try? Data(contentsOf: localURL),
                  let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
            else {
                handleError(.manifestDecodeFailed, manifestURL.lastPathComponent)
                completion?(false)
                return
            }

            let sourceReference = sceneAssetReference(
                kind: .streamModel,
                url: manifestURL,
                displayName: manifestURL.deletingPathExtension().lastPathComponent
            )
            let colorManagement = try await manifestColorManagement(
                tileManifest.colorLUT,
                manifestURL: manifestURL,
                localManifestURL: localURL
            )
            replaceColorManagement(colorManagement)
            SceneAuthoredSourceStore.shared.source = sourceReference
            if registerEntities {
                withWorldMutationGate {
                    registerManifestScenePayload(tileManifest)
                }
            }
            completion?(true)
        } catch {
            handleError(.manifestNotFound, error.localizedDescription, manifestURL.lastPathComponent)
            completion?(false)
        }
    }
}

func loadSceneAuthoredColorManagement(
    from source: SceneAssetReference,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    switch source.kind {
    case .model:
        guard let url = resolvedSceneAssetURL(source) else {
            ColorLUTParams.shared.clear()
            SceneAuthoredSourceStore.shared.clear()
            completion?(false)
            return
        }
        loadSceneAuthored(
            filename: url.path,
            withExtension: url.pathExtension,
            registerEntities: false,
            completion: completion
        )
    case .streamModel:
        guard let url = resolvedSceneAssetURL(source) else {
            ColorLUTParams.shared.clear()
            SceneAuthoredSourceStore.shared.clear()
            completion?(false)
            return
        }
        loadSceneAuthored(url: url, registerEntities: false, completion: completion)
    case .animation, .procedural:
        ColorLUTParams.shared.clear()
        SceneAuthoredSourceStore.shared.clear()
        completion?(false)
    }
}

/// Load a fallback cube mesh when async loading fails
private func loadFallbackMesh(entityId: EntityID, filename: String) {
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

        RenderPasses.invalidateShadowEntityCache()
    }
}

/// Tears down all scene entities and clears per-frame GPU residency state.
/// Called by registerTiledScene before registering new tile stubs.
private func clearScene() {
    ColorLUTParams.shared.clear()
    SceneAuthoredSourceStore.shared.clear()
    for entity in scene.getAllEntities() {
        destroyEntity(entityId: entity)
    }
    finalizePendingDestroys()
    hasPendingDestroys = false
    // Reset CPU-visible list so stale IDs from the previous scene do not persist
    // while new culling results are warming up.
    visibleEntityIds.removeAll()
    // Clear all triple-buffer slots so the renderer does not read stale entity IDs
    // on the next 1–3 frames.  Not called from finalizePendingDestroys() because
    // that runs during normal streaming teardown (unloadTile, tile failure cleanup)
    // where wiping this buffer would blank the whole scene for 1–3 frames.
    tripleVisibleEntities.clearAll()
}

// MARK: - Tiled Scene Manifest structs (private)

private struct TileSize: Decodable {
    let x: Double
    let y: Double
    let z: Double
}

private struct TileManifest: Decodable {
    let version: Int
    /// "uniform_grid" (v3) or "quadtree_floor" (v4).  Absent in older manifests.
    let partitioningMode: String?
    let streamingDefaults: StreamingDefaults
    let tiles: [TileEntry]
    /// Optional shared-bucket entry written by the Blender tile-export script.
    /// Geometry that spans too many tiles is packed into a single USD file with
    /// a large streaming radius so it is always resident.  The engine registers
    /// it as a TileComponent stub with its own streaming/unload radii.
    let sharedBucket: TileEntry?
    /// Tile footprint in world units, as written by the Blender export script.
    /// Used to calibrate the batch cell size so it aligns with tile boundaries.
    let tileSize: TileSize?
    /// Union AABB of all ExteriorShell tiles.  Present in v4 quadtree manifests.
    /// The streaming system only loads interior tiles when the camera is inside
    /// this volume.  Nil for uniform_grid manifests — interior gate is disabled.
    let interiorZone: TileBounds?
    /// Scene-authored lights/cameras exported alongside a tile manifest.
    /// Decoded only by explicit `loadSceneAuthored(url:)` calls; not tied to tile residency.
    let sceneLights: [ManifestLightEntry]?
    let sceneCameras: [ManifestCameraEntry]?
    let colorLUT: ManifestColorManagementEntry?

    enum CodingKeys: String, CodingKey {
        case version
        case partitioningMode = "partitioning_mode"
        case streamingDefaults = "streaming_defaults"
        case tiles
        case sharedBucket = "shared_bucket"
        case tileSize = "tile_size"
        case interiorZone = "interior_zone"
        case sceneLights = "scene_lights"
        case sceneCameras = "scene_cameras"
        case colorLUT
    }
}

private struct ManifestColorManagementEntry: Decodable {
    let lutUri: String
    let lutSize: Int
    let viewTransform: String?
    let look: String?
    let displayDevice: String?
    let exposure: Float
    let gamma: Float
    let shaperMinStops: Float
    let shaperMaxStops: Float
}

private struct ManifestLightEntry: Decodable {
    let name: String?
    let kind: RuntimeLightSourceKind
    let color: simd_float3
    let intensity: Float
    let position: simd_float3
    let radius: Float
    let range: Float
    let direction: simd_float3
    let falloff: Float
    let right: simd_float3
    let innerCone: Float
    let up: simd_float3
    let outerCone: Float
    let areaSize: simd_float2
    let sourcePower: Float
    let sourceExposure: Float
    let castsShadow: Bool
    let usesRadiometricUnits: Bool
    let localTransform: simd_float4x4

    enum CodingKeys: String, CodingKey {
        case name
        case entityName = "entity_name"
        case kind
        case type
        case lightType = "light_type"
        case color
        case intensity
        case position
        case radius
        case range
        case direction
        case falloff
        case right
        case innerCone = "inner_cone"
        case up
        case outerCone = "outer_cone"
        case areaSize = "area_size"
        case sourcePower = "source_power"
        case sourceExposure = "source_exposure"
        case castsShadow = "casts_shadow"
        case usesRadiometricUnits = "uses_radiometric_units"
        case localTransform = "local_transform"
        case localTransformRows = "local_transform_rows"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .entityName)
        kind = try Self.decodeKind(from: container)
        color = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .color), default: simd_float3(1, 1, 1))
        intensity = try container.decodeIfPresent(Float.self, forKey: .intensity) ?? 1.0
        position = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .position), default: .zero)
        radius = try container.decodeIfPresent(Float.self, forKey: .radius) ?? 1.0
        range = try max(container.decodeIfPresent(Float.self, forKey: .range) ?? 0.0, 0.0)
        direction = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .direction), default: simd_float3(0, -1, 0))
        falloff = try container.decodeIfPresent(Float.self, forKey: .falloff) ?? 0.5
        right = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .right), default: simd_float3(1, 0, 0))
        innerCone = try container.decodeIfPresent(Float.self, forKey: .innerCone) ?? 5.0
        up = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .up), default: simd_float3(0, 1, 0))
        outerCone = try container.decodeIfPresent(Float.self, forKey: .outerCone) ?? 10.0
        areaSize = try decodeFloat2(container.decodeIfPresent([Float].self, forKey: .areaSize), default: simd_float2(1, 1))
        sourcePower = try container.decodeIfPresent(Float.self, forKey: .sourcePower) ?? intensity
        sourceExposure = try container.decodeIfPresent(Float.self, forKey: .sourceExposure) ?? 0.0
        castsShadow = try container.decodeIfPresent(Bool.self, forKey: .castsShadow) ?? (kind == .directional)
        usesRadiometricUnits = try container.decodeIfPresent(Bool.self, forKey: .usesRadiometricUnits) ?? false
        let transformRows = try container.decodeIfPresent([[Float]].self, forKey: .localTransformRows)
            ?? container.decodeIfPresent([[Float]].self, forKey: .localTransform)
        localTransform = decodeMatrix4x4Rows(
            transformRows,
            fallbackPosition: position,
            right: right,
            up: up,
            forward: -normalizedImportedDirection(direction, fallback: simd_float3(0.0, -1.0, 0.0))
        )
    }

    private static func decodeKind(from container: KeyedDecodingContainer<CodingKeys>) throws -> RuntimeLightSourceKind {
        if let rawString = (try? container.decode(String.self, forKey: .kind))
            ?? (try? container.decode(String.self, forKey: .type))
            ?? (try? container.decode(String.self, forKey: .lightType))
        {
            switch rawString.lowercased() {
            case "directional", "sun", "dir":
                return .directional
            case "point":
                return .point
            case "spot":
                return .spot
            case "area":
                return .area
            default:
                return .point
            }
        }

        let rawInt = try? container.decode(Int.self, forKey: .lightType)
        let rawType = (try? container.decode(UInt32.self, forKey: .lightType))
            ?? rawInt.flatMap { UInt32(exactly: $0) }
            ?? UntoldLightType.point.rawValue
        switch rawType {
        case UInt32(UntoldLightType.directional.rawValue):
            return .directional
        case UInt32(UntoldLightType.spot.rawValue):
            return .spot
        case UInt32(UntoldLightType.area.rawValue):
            return .area
        default:
            return .point
        }
    }
}

private struct ManifestCameraEntry: Decodable {
    let name: String?
    let position: simd_float3
    let forward: simd_float3
    let up: simd_float3
    let right: simd_float3
    let fovYDegrees: Float
    let nearClip: Float
    let farClip: Float
    let aspectRatio: Float
    let localTransform: simd_float4x4

    enum CodingKeys: String, CodingKey {
        case name
        case entityName = "entity_name"
        case position
        case forward
        case up
        case right
        case fovYDegrees = "fov_y_degrees"
        case nearClip = "near_clip"
        case farClip = "far_clip"
        case aspectRatio = "aspect_ratio"
        case localTransform = "local_transform"
        case localTransformRows = "local_transform_rows"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .entityName)
        position = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .position), default: .zero)
        forward = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .forward), default: simd_float3(0, 0, 1))
        up = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .up), default: simd_float3(0, 1, 0))
        right = try decodeFloat3(container.decodeIfPresent([Float].self, forKey: .right), default: simd_float3(1, 0, 0))
        fovYDegrees = try container.decodeIfPresent(Float.self, forKey: .fovYDegrees) ?? 50.0
        nearClip = try max(container.decodeIfPresent(Float.self, forKey: .nearClip) ?? 0.1, 0.001)
        farClip = try max(container.decodeIfPresent(Float.self, forKey: .farClip) ?? 1000.0, 0.001)
        aspectRatio = try max(container.decodeIfPresent(Float.self, forKey: .aspectRatio) ?? 1.5, 0.001)
        let transformRows = try container.decodeIfPresent([[Float]].self, forKey: .localTransformRows)
            ?? container.decodeIfPresent([[Float]].self, forKey: .localTransform)
        localTransform = decodeMatrix4x4Rows(
            transformRows,
            fallbackPosition: position,
            right: right,
            up: up,
            forward: forward
        )
    }
}

private struct StreamingDefaults: Decodable {
    let streamingRadius: Float
    let unloadRadius: Float
    let priority: Int
    /// Optional default prefetch radius.  When absent, each tile auto-computes its
    /// prefetch radius as the midpoint between streamingRadius and unloadRadius.
    let prefetchRadius: Float?

    enum CodingKeys: String, CodingKey {
        case streamingRadius = "streaming_radius"
        case unloadRadius = "unload_radius"
        case priority
        case prefetchRadius = "prefetch_radius"
    }
}

private struct TileEntry: Decodable {
    let tileId: String
    let pathRelativeToManifest: String
    let fileSizeBytes: Int
    let bounds: TileBounds
    let center: [Float]
    // Per-tile overrides are optional; engine falls back to streaming_defaults.
    let streamingRadius: Float?
    let unloadRadius: Float?
    let priority: Int?
    /// Per-tile prefetch radius override.  When absent, uses the manifest default
    /// (prefetch_radius in streaming_defaults), or auto-computes from stream/unload midpoint.
    let prefetchRadius: Float?

    /// Optional HLOD levels for this tile.  Only the first entry is used by the engine.
    /// Each entry has a relative path to the HLOD USDC file and a switch distance (the
    /// camera distance beyond which the coarse HLOD mesh is shown instead of full geometry).
    let hlodLevels: [HLODLevel]?

    /// Optional per-tile LOD levels that fill the distance band between the tile's
    /// streaming radius (full geometry) and hlodSwitchDistance (HLOD proxy).
    /// Sorted ascending by switch_distance in the manifest (finest first).
    let lodLevels: [LODLevelEntry]?

    /// ── Quadtree / semantic-tier fields (manifest v4, optional) ──────────────
    /// Floor index within the building.  0 = ground floor.
    /// Present in v4 (quadtree_floor partitioning) manifests only.
    let floorId: Int?
    /// Quadtree node identifier written by the phase-1+2 Blender script,
    /// e.g. "F02Q100".  Used for debug logging; not required for streaming.
    let quadtreeNodeId: String?
    /// Semantic detail tier: "ExteriorShell" | "StructuralInterior" |
    /// "RoomContents" | "FineProps".  The streaming_radius on this entry
    /// already encodes the correct load distance for the tier, so no
    /// additional runtime logic is required beyond reading this for diagnostics.
    let semanticTier: String?
    /// When true this tile contains interior-only geometry.  The streaming
    /// system gates loading on the camera being inside the scene's interiorZone.
    /// Absent in older (v3 uniform_grid) manifests — treated as false.
    let isInterior: Bool?

    /// Partition-cell AABB written by the exporter.  Tighter than `bounds` for
    /// spanning tiles because it reflects the KD/quad-tree cell, not the mesh
    /// content footprint.  Used for the "Tile Bounds" debug overlay.
    let cellBounds: TileBounds?

    enum CodingKeys: String, CodingKey {
        case tileId = "tile_id"
        case pathRelativeToManifest = "path_relative_to_manifest"
        case fileSizeBytes = "file_size_bytes"
        case bounds
        case center
        case streamingRadius = "streaming_radius"
        case unloadRadius = "unload_radius"
        case priority
        case prefetchRadius = "prefetch_radius"
        case hlodLevels = "hlod_levels"
        case lodLevels = "lod_levels"
        case floorId = "floor_id"
        case quadtreeNodeId = "quadtree_node_id"
        case semanticTier = "semantic_tier"
        case isInterior = "interior"
        case cellBounds = "cell_bounds"
    }
}

private struct HLODLevel: Decodable {
    let path: String
    let switchDistance: Float

    enum CodingKeys: String, CodingKey {
        case path
        case switchDistance = "switch_distance"
    }
}

/// One entry in a tile's lod_levels manifest array.
/// switch_distance is the camera distance beyond which this LOD is preferred
/// over the next finer level (or the full tile if this is the finest).
/// Entries should be sorted ascending by switch_distance in the manifest.
private struct LODLevelEntry: Decodable {
    let path: String
    let switchDistance: Float

    enum CodingKeys: String, CodingKey {
        case path
        case switchDistance = "switch_distance"
    }
}

private struct TileBounds: Decodable {
    let min: [Float]
    let max: [Float]
}

private func decodeFloat2(_ values: [Float]?, default defaultValue: simd_float2) -> simd_float2 {
    guard let values, values.count >= 2 else { return defaultValue }
    return simd_float2(values[0], values[1])
}

private func decodeFloat3(_ values: [Float]?, default defaultValue: simd_float3) -> simd_float3 {
    guard let values, values.count >= 3 else { return defaultValue }
    return simd_float3(values[0], values[1], values[2])
}

private func decodeMatrix4x4Rows(
    _ rows: [[Float]]?,
    fallbackPosition: simd_float3 = .zero,
    right: simd_float3 = simd_float3(1, 0, 0),
    up: simd_float3 = simd_float3(0, 1, 0),
    forward: simd_float3 = simd_float3(0, 0, 1)
) -> simd_float4x4 {
    guard let rows, rows.count >= 4, rows[0].count >= 4, rows[1].count >= 4,
          rows[2].count >= 4, rows[3].count >= 4
    else {
        return simd_float4x4(
            simd_float4(right, 0),
            simd_float4(up, 0),
            simd_float4(forward, 0),
            simd_float4(fallbackPosition, 1)
        )
    }

    return simd_float4x4(
        simd_float4(rows[0][0], rows[1][0], rows[2][0], rows[3][0]),
        simd_float4(rows[0][1], rows[1][1], rows[2][1], rows[3][1]),
        simd_float4(rows[0][2], rows[1][2], rows[2][2], rows[3][2]),
        simd_float4(rows[0][3], rows[1][3], rows[2][3], rows[3][3])
    )
}

private func registerManifestScenePayload(_ manifest: TileManifest) {
    for light in manifest.sceneLights ?? [] {
        registerUntoldLight(
            RuntimeLightSource(
                name: light.name,
                kind: light.kind,
                color: light.color,
                intensity: light.intensity,
                position: light.position,
                radius: light.radius,
                range: light.range,
                direction: light.direction,
                falloff: light.falloff,
                right: light.right,
                innerCone: light.innerCone,
                up: light.up,
                outerCone: light.outerCone,
                areaSize: light.areaSize,
                sourcePower: light.sourcePower,
                sourceExposure: light.sourceExposure,
                castsShadow: light.castsShadow,
                usesRadiometricUnits: light.usesRadiometricUnits,
                localTransform: light.localTransform
            )
        )
    }
    for camera in manifest.sceneCameras ?? [] {
        registerUntoldCamera(
            RuntimeCameraSource(
                name: camera.name,
                position: camera.position,
                forward: camera.forward,
                up: camera.up,
                right: camera.right,
                fovYDegrees: camera.fovYDegrees,
                nearClip: camera.nearClip,
                farClip: camera.farClip,
                aspectRatio: camera.aspectRatio,
                localTransform: camera.localTransform
            )
        )
    }
}

private func manifestColorManagement(
    _ entry: ManifestColorManagementEntry?,
    manifestURL: URL,
    localManifestURL: URL
) async throws -> RuntimeColorManagement? {
    guard let entry else { return nil }
    guard entry.displayDevice == nil || entry.displayDevice == "sRGB",
          (2 ... 64).contains(entry.lutSize),
          entry.exposure.isFinite,
          entry.gamma.isFinite,
          entry.gamma > 0,
          entry.shaperMinStops.isFinite,
          entry.shaperMaxStops.isFinite,
          entry.shaperMaxStops > entry.shaperMinStops
    else {
        throw UntoldValidationError.invalidColorManagementRecord
    }

    let baseURL = manifestURL.scheme?.lowercased() == "https"
        ? manifestURL.deletingLastPathComponent()
        : localManifestURL.deletingLastPathComponent()
    let resolvedURL: URL
    if let absolute = URL(string: entry.lutUri), absolute.scheme != nil {
        resolvedURL = absolute
    } else if baseURL.isFileURL {
        resolvedURL = baseURL.appendingPathComponent(entry.lutUri)
    } else {
        guard let remoteURL = URL(string: entry.lutUri, relativeTo: baseURL)?.absoluteURL else {
            throw URLError(.badURL)
        }
        resolvedURL = remoteURL
    }

    let localLUTURL: URL
    if resolvedURL.scheme?.lowercased() == "https" {
        localLUTURL = try await RemoteAssetDownloader.shared.localURL(for: resolvedURL)
    } else if resolvedURL.scheme?.lowercased() == "http" {
        throw RemoteAssetDownloader.DownloadError.insecureScheme("http")
    } else {
        localLUTURL = resolvedURL
    }

    return RuntimeColorManagement(
        lutTexture: RuntimeTextureReference(
            name: "ColorGradeLUT",
            sourceURL: localLUTURL,
            isSRGB: false,
            flags: UntoldTextureFlags.lut,
            width: entry.lutSize * entry.lutSize,
            height: entry.lutSize,
            mipCount: 1,
            textureFormat: .rgba16Float
        ),
        exposure: entry.exposure,
        gamma: entry.gamma,
        shaperMinStops: entry.shaperMinStops,
        shaperMaxStops: entry.shaperMaxStops,
        lutSize: entry.lutSize
    )
}

// MARK: - setEntityStreamScene / loadTiledScene

/// Attaches a distance-streamed tile scene to `rootEntityId`.
///
/// Mirrors `setEntityMeshAsync(entityId:filename:withExtension:)` at the scene level.
/// The manifest (JSON) lists spatial tiles — each pointing to a small runtime payload
/// with pre-computed world-space bounds.  One lightweight stub entity is registered per
/// tile, all parented under `rootEntityId`.  No geometry is parsed or uploaded here;
/// `GeometryStreamingSystem` loads each tile on demand as the camera approaches.
///
/// The caller is responsible for creating `rootEntityId` via `createEntity()` before
/// calling this function, and for managing its lifetime.  To replace a streamed scene,
/// destroy the old root (cascades to all tile stubs), then call this with a new root.
/// A manifest `colorLUT` is installed automatically because it is scene-wide.
/// Scene-authored lights/cameras remain opt-in; call `loadSceneAuthored(url:)`
/// explicitly when you want those entities in the current scene.
///
/// - Parameters:
///   - rootEntityId:  Entity that becomes the parent of all tile stubs.
///   - manifest:      Name of the JSON manifest file (without extension).
///   - ext:           File extension; defaults to `"json"`.
///   - completion:    Called with `true` when all stubs are registered.
public func setEntityStreamScene(
    entityId rootEntityId: EntityID,
    manifest: String,
    withExtension ext: String = "json",
    completion: ((Bool) -> Void)? = nil
) {
    guard let manifestURL = LoadingSystem.shared.resourceURL(
        forResource: manifest,
        withExtension: ext,
        subResource: nil
    ) else {
        handleError(.manifestNotFound, "\(manifest).\(ext)")
        completion?(false)
        return
    }

    guard let data = try? Data(contentsOf: manifestURL),
          let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
    else {
        handleError(.manifestDecodeFailed, "\(manifest).\(ext)")
        completion?(false)
        return
    }

    Logger.log(
        message: "[setEntityStreamScene] Manifest v\(tileManifest.version) decoded — \(tileManifest.tiles.count) tile(s).",
        category: LogCategory.tileStreaming.rawValue
    )

    let completionBox = completion.map { BoolCompletionBox(callback: $0) }
    ColorLUTParams.shared.clear()
    Task {
        do {
            let colorManagement = try await manifestColorManagement(
                tileManifest.colorLUT,
                manifestURL: manifestURL,
                localManifestURL: manifestURL
            )
            replaceColorManagement(colorManagement)
            registerTiledScene(
                rootEntityId: rootEntityId,
                manifest: tileManifest,
                baseURL: manifestURL.deletingLastPathComponent(),
                label: "\(manifest).\(ext)",
                manifestURL: manifestURL,
                completion: { result in completionBox?.call(result) }
            )
        } catch {
            handleError(.manifestDecodeFailed, "Color LUT: \(error.localizedDescription)", "\(manifest).\(ext)")
            completionBox?.call(false)
        }
    }
}

/// Loads a tiled scene from a named manifest, creating an internal root entity.
///
/// Backwards-compatible overload.  Prefer `setEntityStreamScene(entityId:manifest:)`
/// when you need a stable handle to the loaded scene.
///
/// A manifest `colorLUT` is installed automatically. Scene-authored
/// lights/cameras remain opt-in through `loadSceneAuthored(url:)`.
public func loadTiledScene(
    manifest: String,
    withExtension ext: String = "json",
    completion: ((Bool) -> Void)? = nil
) {
    guard let manifestURL = LoadingSystem.shared.resourceURL(
        forResource: manifest,
        withExtension: ext,
        subResource: nil
    ) else {
        handleError(.manifestNotFound, "\(manifest).\(ext)")
        completion?(false)
        return
    }

    guard let data = try? Data(contentsOf: manifestURL),
          let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
    else {
        handleError(.manifestDecodeFailed, "\(manifest).\(ext)")
        completion?(false)
        return
    }

    Logger.log(
        message: "[loadTiledScene] Manifest v\(tileManifest.version) decoded — \(tileManifest.tiles.count) tile(s).",
        category: LogCategory.tileStreaming.rawValue
    )

    let completionBox = completion.map { BoolCompletionBox(callback: $0) }
    ColorLUTParams.shared.clear()
    Task {
        do {
            let colorManagement = try await manifestColorManagement(
                tileManifest.colorLUT,
                manifestURL: manifestURL,
                localManifestURL: manifestURL
            )
            replaceColorManagement(colorManagement)
            let rootEntityId = createEntity()
            setEntityName(entityId: rootEntityId, name: "\(manifest).root")
            registerTiledScene(
                rootEntityId: rootEntityId,
                manifest: tileManifest,
                baseURL: manifestURL.deletingLastPathComponent(),
                label: "\(manifest).\(ext)",
                manifestURL: manifestURL,
                completion: { result in completionBox?.call(result) }
            )
        } catch {
            handleError(.manifestDecodeFailed, "Color LUT: \(error.localizedDescription)", "\(manifest).\(ext)")
            completionBox?.call(false)
        }
    }
}

/// Attaches a distance-streamed tile scene to `rootEntityId` from a URL.
///
/// URL variant of `setEntityStreamScene(entityId:manifest:)`.  Accepts a local
/// `file://` URL or a remote `https://` URL; for remote manifests, tile paths are
/// resolved relative to the manifest directory and downloaded on demand by the
/// streaming system as the camera approaches each tile.
///
/// The caller is responsible for creating `rootEntityId` via `createEntity()` before
/// calling this function, and for managing its lifetime. A manifest `colorLUT`
/// is installed automatically. Scene-authored lights/cameras remain opt-in
/// through `loadSceneAuthored(url:)`.
///
/// - Parameters:
///   - rootEntityId: Entity that becomes the parent of all tile stubs.
///   - url:          Full URL to the manifest JSON (local or remote).
///   - completion:   Called with `true` when all stubs are registered.
public func setEntityStreamScene(
    entityId rootEntityId: EntityID,
    url manifestURL: URL,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    ColorLUTParams.shared.clear()
    Task {
        do {
            let localURL: URL
            if manifestURL.scheme?.lowercased() == "https" {
                localURL = try await RemoteAssetDownloader.shared.localURL(for: manifestURL)
            } else if manifestURL.scheme?.lowercased() == "http" {
                throw RemoteAssetDownloader.DownloadError.insecureScheme("http")
            } else {
                localURL = manifestURL
            }

            guard let data = try? Data(contentsOf: localURL),
                  let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
            else {
                handleError(.manifestDecodeFailed, manifestURL.lastPathComponent)
                completion?(false)
                return
            }

            Logger.log(
                message: "[setEntityStreamScene] Manifest v\(tileManifest.version) decoded — \(tileManifest.tiles.count) tile(s).",
                category: LogCategory.tileStreaming.rawValue
            )

            let colorManagement = try await manifestColorManagement(
                tileManifest.colorLUT,
                manifestURL: manifestURL,
                localManifestURL: localURL
            )
            replaceColorManagement(colorManagement)
            registerTiledScene(
                rootEntityId: rootEntityId,
                manifest: tileManifest,
                baseURL: manifestURL.deletingLastPathComponent(),
                label: manifestURL.lastPathComponent,
                manifestURL: manifestURL,
                completion: completion
            )
        } catch {
            handleError(.manifestNotFound, error.localizedDescription, manifestURL.lastPathComponent)
            completion?(false)
        }
    }
}

/// Loads a tiled scene from a URL (local `file://` or remote `http(s)://`),
/// creating an internal root entity.
///
/// Backwards-compatible overload.  Prefer `setEntityStreamScene(entityId:url:)`
/// when you need a stable handle to the loaded scene.
///
/// A manifest `colorLUT` is installed automatically. Scene-authored
/// lights/cameras remain opt-in through `loadSceneAuthored(url:)`.
///
/// - Parameters:
///   - url:        Full URL to the manifest JSON (local or remote).
///   - completion: Called on the calling thread with `true` on success.
public func loadTiledScene(
    url manifestURL: URL,
    completion: (@Sendable (Bool) -> Void)? = nil
) {
    ColorLUTParams.shared.clear()
    Task {
        do {
            let localURL: URL
            if manifestURL.scheme?.lowercased() == "https" {
                localURL = try await RemoteAssetDownloader.shared.localURL(for: manifestURL)
            } else if manifestURL.scheme?.lowercased() == "http" {
                throw RemoteAssetDownloader.DownloadError.insecureScheme("http")
            } else {
                localURL = manifestURL
            }

            guard let data = try? Data(contentsOf: localURL),
                  let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
            else {
                handleError(.manifestDecodeFailed, manifestURL.lastPathComponent)
                completion?(false)
                return
            }

            Logger.log(
                message: "[loadTiledScene] Manifest v\(tileManifest.version) decoded — \(tileManifest.tiles.count) tile(s).",
                category: LogCategory.tileStreaming.rawValue
            )

            let colorManagement = try await manifestColorManagement(
                tileManifest.colorLUT,
                manifestURL: manifestURL,
                localManifestURL: localURL
            )
            replaceColorManagement(colorManagement)
            let rootEntityId = createEntity()
            setEntityName(entityId: rootEntityId, name: "\(manifestURL.deletingPathExtension().lastPathComponent).root")

            registerTiledScene(
                rootEntityId: rootEntityId,
                manifest: tileManifest,
                baseURL: manifestURL.deletingLastPathComponent(),
                label: manifestURL.lastPathComponent,
                manifestURL: manifestURL,
                completion: completion
            )
        } catch {
            handleError(.manifestNotFound, error.localizedDescription, manifestURL.lastPathComponent)
            completion?(false)
        }
    }
}

/// Canonical scene-loading runtime.
///
/// Registers one TileComponent stub per manifest entry, parents all stubs under
/// `rootEntityId`, and enables cell-based static batching.  No geometry is parsed
/// or uploaded here — that happens incrementally as the camera moves.
///
/// Called by setEntityStreamScene() / loadTiledScene() after JSON decoding.  The manifest is the only public
/// scene contract; tile payloads are runtime implementation details (for example
/// `.untold`, with legacy USD/USDZ support still present during migration).
///
/// Scene-authored manifest lights/cameras are registered once under `rootEntityId`;
/// otherwise camera/light ownership remains with the caller.
///
/// - Parameters:
///   - rootEntityId: Entity that becomes the parent of all tile stubs.
///   - manifest:     Decoded TileManifest to register.
///   - baseURL:      Directory used to resolve pathRelativeToManifest entries.
///   - label:        Human-readable identifier used in log messages.
///   - completion:   Called synchronously after all stubs are registered.
private func registerTiledScene(
    rootEntityId: EntityID,
    manifest tileManifest: TileManifest,
    baseURL manifestDir: URL,
    label: String,
    manifestURL: URL? = nil,
    completion: ((Bool) -> Void)?
) {
    // ── 1. Align streaming systems to this manifest ────────────────────────
    // Align texture streaming distance tiers to this manifest's actual radii so
    // texture quality bands scale with the scene rather than using fixed values.
    TextureStreamingSystem.shared.alignToManifest(
        streamingRadius: tileManifest.streamingDefaults.streamingRadius,
        unloadRadius: tileManifest.streamingDefaults.unloadRadius
    )
    // Clear scene-level streaming state that is not valid across scene boundaries.
    // interiorZone comes from the manifest; stale zone from a previous scene would
    // incorrectly gate interior tile loads in the new scene.
    // firstRangeTimestamps are keyed by EntityID; old entries become incorrect once
    // those entities are destroyed and their IDs are recycled by new tile stubs.
    GeometryStreamingSystem.shared.interiorZone = nil
    GeometryStreamingSystem.shared.firstRangeTimestamps.removeAll()

    // ── 2. Set up root entity ──────────────────────────────────────────────
    // The root receives a transform (identity) and a scenegraph node so tile
    // stubs can be parented under it.  TiledSceneComponent marks it as a tiled
    // scene root for inspection and future editor workflows.
    //
    // Root transforms are NOT propagated to streaming/culling bounds in this
    // release.  The manifest tile bounds are world-space values; keep the root
    // at identity transform to avoid incorrect streaming/culling decisions.
    registerTransformComponent(entityId: rootEntityId)
    registerSceneGraphComponent(entityId: rootEntityId)
    registerComponent(entityId: rootEntityId, componentType: TiledSceneComponent.self)
    if let sceneComp = scene.get(component: TiledSceneComponent.self, for: rootEntityId) {
        sceneComp.manifestLabel = label
        sceneComp.manifestURL = manifestURL
    }

    // ── 3. Cell-based static batching ─────────────────────────────────────
    // Tile entities are tagged with StaticBatchComponent after each tile parse
    // succeeds.  BatchingSystem.handleResidencyChange fires for each OCC stub as
    // its GPU upload completes, so batches self-assemble incrementally.
    // Cell size = 2× tile footprint puts ~4 tiles per cell — enough merge depth
    // without oversized GPU buffers.
    let manifestTileSize: Float
    if let ts = tileManifest.tileSize {
        manifestTileSize = Float(max(ts.x, ts.z))
    } else {
        manifestTileSize = tileManifest.streamingDefaults.streamingRadius
    }
    // Cell size = 1× tile footprint (was 2×).  At 2× (50 m cells) each cell contains
    // ~46 tiles × ~3 entities × ~2500 vertices ≈ 350 K vertices — more than 2× the
    // 160 K complexity-guard limit, so 6 of 9 cells are permanently blocked from batching
    // and render individually (opaque 300 draw calls → GPU overload → freeze).
    // At 1× (25 m cells) each cell contains ~15 tiles × ~3 entities × ~2500 vertices
    // ≈ 115 K vertices, within the limit — all cells form batch groups.
    BatchingSystem.shared.setBatchCellSize(manifestTileSize * 1.0)
    enableBatching(true)

    // ── 4. Register tile stub entities in per-frame batches ──────────────
    // Registering all stubs in one synchronous gate caused a multi-hundred ms
    // main-thread stall on large manifests.  Instead, we drain batchSize stubs
    // per main-thread turn so the render loop gets a window between each batch.
    // The streaming system starts finding candidates as soon as the first batch
    // lands; later batches fill in the rest of the scene without blocking frames.
    let tiles = tileManifest.tiles
    let defaults = tileManifest.streamingDefaults

    // Holds mutable state shared across async batch closures.
    // @unchecked Sendable is safe here: all accesses happen on the main queue.
    final class RegistrationState: @unchecked Sendable {
        var nextIndex = 0
        var registeredCount = 0
        var skippedCount = 0
        var completion: ((Bool) -> Void)?
    }
    let regState = RegistrationState()
    regState.completion = completion

    /// ── 5 + finish: shared bucket, interior zone, completion ─────────────
    /// Runs after the last tile batch completes.
    func finishRegistration() {
        var hasSharedBucket = false
        if let shared = tileManifest.sharedBucket {
            let sharedURL = manifestDir.appendingPathComponent(shared.pathRelativeToManifest)
            if !FileManager.default.fileExists(atPath: sharedURL.path) {
                Logger.logWarning(
                    message: "[loadTiledScene] Shared bucket file missing: '\(shared.pathRelativeToManifest)' — skipping.",
                    category: LogCategory.tileStreaming.rawValue
                )
            } else if shared.bounds.min.count < 3 || shared.bounds.max.count < 3 || shared.center.count < 3 {
                Logger.logWarning(
                    message: "[loadTiledScene] Shared bucket has malformed bounds — skipping.",
                    category: LogCategory.tileStreaming.rawValue
                )
            } else {
                withWorldMutationGate {
                    let entityId = createEntity()
                    setEntityName(entityId: entityId, name: shared.tileId)
                    registerTransformComponent(entityId: entityId)
                    if let local = scene.get(component: LocalTransformComponent.self, for: entityId) {
                        local.boundingBox = (
                            min: simd_float3(shared.bounds.min[0], shared.bounds.min[1], shared.bounds.min[2]),
                            max: simd_float3(shared.bounds.max[0], shared.bounds.max[1], shared.bounds.max[2])
                        )
                    }
                    registerSceneGraphComponent(entityId: entityId)
                    registerComponent(entityId: entityId, componentType: TileComponent.self)
                    if let tileComp = scene.get(component: TileComponent.self, for: entityId) {
                        tileComp.tileURL = sharedURL
                        tileComp.fileSizeBytes = shared.fileSizeBytes
                        tileComp.streamingRadius = shared.streamingRadius ?? Float.greatestFiniteMagnitude
                        tileComp.unloadRadius = shared.unloadRadius ?? Float.greatestFiniteMagnitude
                        tileComp.priority = shared.priority ?? defaults.priority
                        tileComp.prefetchRadius = shared.prefetchRadius ?? defaults.prefetchRadius ?? 0
                        tileComp.tileId = shared.tileId
                        tileComp.isSharedBucket = true
                        tileComp.state = .unloaded
                    }
                    setParent(childId: entityId, parentId: rootEntityId)
                    OctreeSystem.shared.registerEntity(entityId)
                }
                hasSharedBucket = true
                Logger.log(
                    message: "[loadTiledScene] Shared bucket stub registered: '\(shared.tileId)'.",
                    category: LogCategory.tileStreaming.rawValue
                )
            }
        }

        if let iz = tileManifest.interiorZone, iz.min.count >= 3, iz.max.count >= 3 {
            let zone = AABB(
                min: simd_float3(iz.min[0], iz.min[1], iz.min[2]),
                max: simd_float3(iz.max[0], iz.max[1], iz.max[2])
            )
            GeometryStreamingSystem.shared.interiorZone = zone
            Logger.log(
                message: "[loadTiledScene] Interior zone set: \(zone.min) → \(zone.max)",
                category: LogCategory.tileStreaming.rawValue
            )
        }

        let skipMsg = regState.skippedCount > 0 ? " (\(regState.skippedCount) skipped)" : ""
        let bucketMsg = hasSharedBucket ? " + shared bucket" : ""
        Logger.log(
            message: "[loadTiledScene] '\(label)': \(regState.registeredCount) tile stubs registered\(skipMsg)\(bucketMsg).",
            category: LogCategory.tileStreaming.rawValue
        )
        GeometryStreamingSystem.shared.buildTileHierarchyIndex()
        regState.completion?(true)
    }

    /// Registers one batch of tile stubs, then schedules the next batch or
    /// calls finishRegistration when all tiles have been processed.
    func drainBatch() {
        let startIdx = regState.nextIndex
        let endIdx = min(startIdx + 50, tiles.count)
        withWorldMutationGate {
            for i in startIdx ..< endIdx {
                let tile = tiles[i]
                let tileURL = manifestDir.appendingPathComponent(tile.pathRelativeToManifest)
                guard tile.bounds.min.count >= 3, tile.bounds.max.count >= 3,
                      tile.center.count >= 3
                else {
                    Logger.logWarning(
                        message: "[loadTiledScene] Tile '\(tile.tileId)' has malformed bounds or center — skipping.",
                        category: LogCategory.tileStreaming.rawValue
                    )
                    regState.skippedCount += 1
                    continue
                }
                let entityId = createEntity()
                setEntityName(entityId: entityId, name: tile.tileId)
                // Transform + bounds.
                // The entity's world transform is identity (tile geometry is already in
                // world space in the exported USDC).  The local bounding box is set to
                // the tile's world-space AABB — valid because identity world transform
                // means local space == world space.
                registerTransformComponent(entityId: entityId)
                if let local = scene.get(component: LocalTransformComponent.self, for: entityId) {
                    local.boundingBox = (
                        min: simd_float3(tile.bounds.min[0], tile.bounds.min[1], tile.bounds.min[2]),
                        max: simd_float3(tile.bounds.max[0], tile.bounds.max[1], tile.bounds.max[2])
                    )
                }
                registerSceneGraphComponent(entityId: entityId)
                registerComponent(entityId: entityId, componentType: TileComponent.self)
                if let tileComp = scene.get(component: TileComponent.self, for: entityId) {
                    if let cb = tile.cellBounds, cb.min.count >= 3, cb.max.count >= 3 {
                        tileComp.cellBounds = AABB(
                            min: simd_float3(cb.min[0], cb.min[1], cb.min[2]),
                            max: simd_float3(cb.max[0], cb.max[1], cb.max[2])
                        )
                    }
                    let configuredStreamingRadius = tile.streamingRadius ?? defaults.streamingRadius
                    let configuredUnloadRadius = tile.unloadRadius ?? defaults.unloadRadius
                    let configuredPrefetch = tile.prefetchRadius ?? defaults.prefetchRadius ?? 0
                    let configuredHLOD = tile.hlodLevels?.first?.switchDistance
                    let configuredLODs = (tile.lodLevels ?? []).map(\.switchDistance)
                    let normalizedBands = normalizeTileStreamingBands(
                        tileId: tile.tileId,
                        streamingRadius: configuredStreamingRadius,
                        unloadRadius: configuredUnloadRadius,
                        prefetchRadius: configuredPrefetch,
                        hlodSwitchDistance: configuredHLOD,
                        lodSwitchDistances: configuredLODs
                    )
                    tileComp.tileURL = tileURL
                    tileComp.fileSizeBytes = tile.fileSizeBytes
                    tileComp.streamingRadius = configuredStreamingRadius
                    tileComp.unloadRadius = max(configuredUnloadRadius, configuredStreamingRadius + 4.0)
                    tileComp.priority = tile.priority ?? defaults.priority
                    tileComp.prefetchRadius = normalizedBands.prefetchRadius
                    tileComp.tileId = tile.tileId
                    tileComp.quadtreeNodeId = tile.quadtreeNodeId
                    tileComp.isInterior = tile.isInterior ?? false
                    let isFloorPartitioned = tileManifest.partitioningMode == "quadtree_floor"
                        || tileManifest.partitioningMode == "kdtree_floor"
                    tileComp.hasFloorMetadata = isFloorPartitioned && tile.floorId != nil
                    tileComp.floorId = tile.floorId ?? 0
                    tileComp.worldYCenter = tile.center.count >= 2 ? Float(tile.center[1]) : 0
                    tileComp.state = .unloaded
                    if let tier = tile.semanticTier {
                        let floorTag = tile.floorId.map { "floor=\($0) " } ?? ""
                        Logger.log(
                            message: "[loadTiledScene] \(tile.tileId): \(floorTag)tier=\(tier) stream=\(String(format: "%.1f", configuredStreamingRadius))m",
                            category: LogCategory.tileStreaming.rawValue
                        )
                    }
                    if let hlodLevels = tile.hlodLevels, let first = hlodLevels.first,
                       let normalizedHLOD = normalizedBands.hlodSwitchDistance
                    {
                        tileComp.hlodURL = manifestDir.appendingPathComponent(first.path)
                        tileComp.hlodSwitchDistance = normalizedHLOD
                    }
                    if let lodEntries = tile.lodLevels {
                        let sorted = lodEntries.sorted { $0.switchDistance < $1.switchDistance }
                        for (index, entry) in sorted.enumerated() {
                            guard index < normalizedBands.lodSwitchDistances.count else { break }
                            let lodURL = manifestDir.appendingPathComponent(entry.path)
                            tileComp.lodLevels.append(TileLODLevel(url: lodURL, switchDistance: normalizedBands.lodSwitchDistances[index]))
                        }
                    }
                }
                setParent(childId: entityId, parentId: rootEntityId)
                OctreeSystem.shared.registerEntity(entityId)
                regState.registeredCount += 1
            }
        }
        regState.nextIndex = endIdx
        if regState.nextIndex < tiles.count {
            DispatchQueue.main.async { drainBatch() }
        } else {
            finishRegistration()
        }
    }

    drainBatch()
}

private func normalizeTileStreamingBands(
    tileId: String,
    streamingRadius: Float,
    unloadRadius: Float,
    prefetchRadius: Float,
    hlodSwitchDistance: Float?,
    lodSwitchDistances: [Float]
) -> (prefetchRadius: Float, hlodSwitchDistance: Float?, lodSwitchDistances: [Float]) {
    let minBandGap: Float = 4.0
    let clampedUnload = max(unloadRadius, streamingRadius + minBandGap)
    let maxHLOD = max(streamingRadius + minBandGap, clampedUnload - 1.0)
    let minHLOD = streamingRadius + minBandGap

    var normalizedHLOD: Float?
    if let hlod = hlodSwitchDistance, hlod > 0 {
        normalizedHLOD = min(max(hlod, minHLOD), maxHLOD)
    }

    var normalizedLODs = lodSwitchDistances.sorted()
    if !normalizedLODs.isEmpty {
        let upperBound = (normalizedHLOD ?? clampedUnload) - minBandGap
        var previous = max(1.0, streamingRadius * 0.35)
        for i in normalizedLODs.indices {
            let remaining = Float(normalizedLODs.count - i - 1)
            let dynamicUpper = max(previous, upperBound - remaining * minBandGap)
            normalizedLODs[i] = min(max(normalizedLODs[i], previous), dynamicUpper)
            previous = normalizedLODs[i] + minBandGap
        }
        normalizedLODs = normalizedLODs.filter { $0 < upperBound + 0.001 }
    }

    let normalizedPrefetch: Float = {
        guard prefetchRadius > 0 else { return 0 }
        return min(max(prefetchRadius, streamingRadius), clampedUnload)
    }()

    if normalizedHLOD != hlodSwitchDistance || normalizedLODs != lodSwitchDistances || normalizedPrefetch != prefetchRadius {
        Logger.logWarning(
            message: "[loadTiledScene] Normalized streaming bands for tile '\(tileId)' — prefetch=\(String(format: "%.2f", normalizedPrefetch)) hlod=\(normalizedHLOD.map { String(format: "%.2f", $0) } ?? "nil") lods=\(normalizedLODs.map { String(format: "%.2f", $0) })",
            category: LogCategory.tileStreaming.rawValue
        )
    }

    return (normalizedPrefetch, normalizedHLOD, normalizedLODs)
}

func removeEntityMesh(entityId: EntityID) {
    var removedAnyResourceOwner = false

    if let renderComponent = scene.get(component: RenderComponent.self, for: entityId) {
        renderComponent.cleanUp()
        scene.remove(component: RenderComponent.self, from: entityId)
        removedAnyResourceOwner = true
        resetLightPortalAreaLightCache()
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

public func setEntityAnimations(entityId: EntityID, filename: String, withExtension: String, name: String) {
    let targetEntityIds = resolveAnimationBindingTargetEntities(entityId: entityId)
    guard targetEntityIds.contains(where: { scene.get(component: SkeletonComponent.self, for: $0) != nil }) else {
        handleError(.noSkeletonComponent, entityId)
        return
    }

    let resourceURL = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension)
    guard let url = resourceURL else {
        handleError(.filenameNotFound, filename)
        return
    }

    if RuntimeAssetSource.infer(from: url).kind == .untold {
        guard let runtimeAsset = loadUntoldRuntimeAsset(url: url) else {
            handleError(.assetHasNoAnimation, filename)
            return
        }
        let runtimeClips = runtimeAsset.animationClips
        if runtimeClips.isEmpty {
            handleError(.assetHasNoAnimation, filename)
            return
        }

        withWorldMutationGate {
            for targetEntityId in targetEntityIds {
                guard scene.get(component: SkeletonComponent.self, for: targetEntityId) != nil else {
                    continue
                }

                guard let animationComponent = ensureAnimationComponent(entityId: targetEntityId, errorEntityId: entityId) else {
                    continue
                }

                let registeredNames = registerRuntimeAnimationClips(runtimeClips, preferredName: name, to: animationComponent)
                appendAnimationSourceURLIfNeeded(url, to: animationComponent)

                if animationComponent.currentAnimation == nil,
                   let selectedName = registeredNames.first(where: { $0 == name }) ?? registeredNames.first
                {
                    animationComponent.currentAnimation = animationComponent.animationClips[selectedName]
                }
            }
        }
        return
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
        if LightingSystem.shared.activeDirectionalLight == entityId {
            LightingSystem.shared.activeDirectionalLight = nil
        }
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
    anyTransformDirty = true
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
    resetLightPortalAreaLightCache()
    let entityName = getEntityName(entityId: entityId)
    let channelSourceName = entityName.isEmpty ? assetName : entityName
    setDefaultEntitySceneChannels(entityId: entityId, channels: defaultSceneChannels(forName: channelSourceName))

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

    let hasRenderableSceneComponent = scene.get(component: RenderComponent.self, for: entityId) != nil ||
        scene.get(component: StreamingComponent.self, for: entityId) != nil
    if let component = scene.get(component: EntitySceneChannelsComponent.self, for: entityId),
       component.usesDefaultChannels,
       hasRenderableSceneComponent
    {
        component.channels = defaultSceneChannels(forName: name)
    }
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

var customComponentEncoderMap: [ObjectIdentifier: (EntityID) -> Data?] {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.customComponentEncoderMap
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.customComponentEncoderMap = newValue
        registrationRuntimeState.lock.unlock()
    }
}

var customComponentDecoderMap: [String: (EntityID, Data) -> Void] {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.customComponentDecoderMap
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.customComponentDecoderMap = newValue
        registrationRuntimeState.lock.unlock()
    }
}

var customComponentTypeNameById: [ObjectIdentifier: String] {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.customComponentTypeNameById
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.customComponentTypeNameById = newValue
        registrationRuntimeState.lock.unlock()
    }
}

public func encodeCustomComponent<T: Component & Codable>(
    type: T.Type,
    merge: ((inout T, T) -> Void)? = nil
) {
    enforceRegistrationMainActor()
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

    // Load named node from .untold asset.
    if let runtimeAsset = loadUntoldRuntimeAsset(url: url),
       let node = runtimeAsset.nodes.first(where: { $0.name == name }),
       !node.primitives.isEmpty
    {
        let meshes = makeMeshes(from: node)
        if !meshes.isEmpty { return meshes }
    }

    // ---- Fallback path: fabricate a safe default mesh ----
    handleError(.assetDataMissing, filename)
    return Mesh.makeDefaultMesh()
}

/// Built Metal resources for a parsed Gaussian splat asset, ready to attach to an entity.
/// Shared by `setEntityGaussian` (synchronous) and `setEntityGaussianAsync` (off-thread) so
/// there is a single implementation of the PLY-parse/buffer-build/SH-pack pipeline.
struct GaussianLoadResult {
    let splatCount: UInt
    // One buffer per in-flight frame slot (see the comment on GaussianComponent's matching
    // fields) — written fresh every frame by the cull/depth-key/radix-sort passes, so a
    // single shared buffer would let an overlapping newer frame's writes clobber data an
    // older in-flight frame's draw is still reading.
    let gaussianSortedIndices: [MTLBuffer]
    let gaussianVisibleIndices: [MTLBuffer]
    let gaussianVisibleCount: [MTLBuffer]
    let encodedSplatBuffer: MTLBuffer
    // Same per-in-flight-frame slotting as the buffers above — written by
    // executeGaussianPreprocess every frame, read by that same frame's draw pass.
    let gaussianPrecomputedData: [MTLBuffer]
    let sphericalHarmonicsBuffer: MTLBuffer?
    let sphericalHarmonicsMetadata: GaussianSHMetadata?
    let spaceUniform: [MTLBuffer?]
    /// Sum of all GPU buffer bytes above, for `MemoryBudgetManager` registration.
    let estimatedGPUBytes: Int
    /// Local-space bounding box computed from the actual loaded splat positions, for
    /// `LocalTransformComponent.boundingBox` — see `computeGaussianSplatBoundingBox`.
    let boundingBox: (min: simd_float3, max: simd_float3)
}

public enum UntoldGSError: Error, CustomStringConvertible {
    case badMagic
    case unsupportedVersion(UInt32)
    case truncated
    case sizeMismatch(String)

    public var description: String {
        switch self {
        case .badMagic: "Not an Untold Gaussian splat file"
        case let .unsupportedVersion(version): "Unsupported Untold Gaussian splat version \(version)"
        case .truncated: "Untold Gaussian splat file is truncated"
        case let .sizeMismatch(reason): "Untold Gaussian splat size mismatch: \(reason)"
        }
    }
}

public struct UntoldGSAsset {
    public let encodedSplats: [EncodedGaussianSplat]
    public let shCoefficients: [UInt8]
    public let shMetadata: GaussianSHMetadata?
    /// Mean of this tier's splats' squared major-axis extent, baked in by
    /// `bakeGaussianSplatProgressiveTiers` — see `estimatedGaussianOverdraw`. 0 for files
    /// baked before this field existed (indistinguishable from a real 0, but a real 0 can only
    /// happen for a tier with no splats, which never gets written).
    public let meanSquaredSplatExtent: Float
    /// Asset-level local-space bounding box (shared by every tier of the same bake, not
    /// per-tier — see `bakeGaussianSplatProgressiveTiers`), baked in at version 2. Lets any
    /// registration path — including streaming, which needs a real box before it can decide
    /// whether to load anything — read a real box via `UntoldGSFormat.readHeader` without a
    /// caller-supplied value.
    public let boundingBoxMin: simd_float3
    public let boundingBoxMax: simd_float3

    public var splatCount: Int {
        encodedSplats.count
    }
}

public enum UntoldGSFormat {
    private static let magic: UInt32 = 0x5347_5455 // "UTGS"
    // v2 appended boundingBoxMin/boundingBoxMax (24 bytes) after the v1 header — every v1 field
    // offset is unchanged. No dual-version reader: .untoldgs is a regeneratable cache of the
    // source .ply, not hand-authored data, so a version bump just means "re-bake," the same way
    // an EncodedGaussianSplat layout change already does.
    private static let version: UInt32 = 2
    private static let headerByteCount = 72

    public static func write(
        encodedSplats: [EncodedGaussianSplat],
        sphericalHarmonics: PackedGaussianSphericalHarmonics?,
        meanSquaredSplatExtent: Float = 0,
        boundingBoxMin: simd_float3,
        boundingBoxMax: simd_float3,
        to url: URL
    ) throws {
        var data = Data()
        appendUInt32(magic, to: &data)
        appendUInt32(version, to: &data)
        appendUInt64(UInt64(encodedSplats.count), to: &data)
        appendUInt32(sphericalHarmonics?.metadata.degree ?? 0, to: &data)
        appendUInt32(sphericalHarmonics?.metadata.coefficientsPerChannel ?? 0, to: &data)
        appendUInt32(sphericalHarmonics?.metadata.higherOrderCoefficientsPerSplat ?? 0, to: &data)
        appendFloat(meanSquaredSplatExtent, to: &data)
        appendUInt64(UInt64(encodedSplats.count * MemoryLayout<EncodedGaussianSplat>.stride), to: &data)
        appendUInt64(UInt64(sphericalHarmonics?.coefficients.count ?? 0), to: &data)
        appendFloat(boundingBoxMin.x, to: &data)
        appendFloat(boundingBoxMin.y, to: &data)
        appendFloat(boundingBoxMin.z, to: &data)
        appendFloat(boundingBoxMax.x, to: &data)
        appendFloat(boundingBoxMax.y, to: &data)
        appendFloat(boundingBoxMax.z, to: &data)

        encodedSplats.withUnsafeBytes { data.append(contentsOf: $0) }
        if let sphericalHarmonics {
            data.append(contentsOf: sphericalHarmonics.coefficients)
        }

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    /// Check just enough to identify the version before checking the full v2 header length — an
    /// old, valid-but-shorter v1 file (48 bytes) must report .unsupportedVersion (a clear
    /// "re-bake me" signal), not .truncated, which would otherwise fire first purely because
    /// it's shorter than the current header size. Shared by read() and readHeader() so both
    /// report the same error for the same malformed input.
    private static func validateMagicAndVersion(_ data: Data) throws {
        guard data.count >= 8 else { throw UntoldGSError.truncated }
        let magicValue = readUInt32(data, at: 0)
        guard magicValue == magic else { throw UntoldGSError.badMagic }
        let versionValue = readUInt32(data, at: 4)
        guard versionValue == version else { throw UntoldGSError.unsupportedVersion(versionValue) }
    }

    /// Reads only `boundingBoxMin`/`boundingBoxMax` from the fixed-size header via a bounded
    /// `FileHandle` read — not `Data(contentsOf:)`, which would pull the entire (potentially
    /// multi-megabyte) splat/SH payload into memory just to look at 24 header bytes. Lets
    /// registration paths (including streaming, which needs a real box before it can decide
    /// whether to load anything) get one synchronously without a caller-supplied value.
    public static func readHeader(from url: URL) throws -> (boundingBoxMin: simd_float3, boundingBoxMax: simd_float3) {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            throw UntoldGSError.truncated
        }
        defer { try? fileHandle.close() }

        let data = try (fileHandle.read(upToCount: headerByteCount)) ?? Data()
        try validateMagicAndVersion(data)
        guard data.count >= headerByteCount else { throw UntoldGSError.truncated }

        let boundingBoxMin = simd_float3(readFloat(data, at: 48), readFloat(data, at: 52), readFloat(data, at: 56))
        let boundingBoxMax = simd_float3(readFloat(data, at: 60), readFloat(data, at: 64), readFloat(data, at: 68))
        return (boundingBoxMin, boundingBoxMax)
    }

    public static func read(from url: URL) throws -> UntoldGSAsset {
        let data = try Data(contentsOf: url)
        try validateMagicAndVersion(data)
        guard data.count >= headerByteCount else { throw UntoldGSError.truncated }

        let splatCountRaw = readUInt64(data, at: 8)
        let shDegree = readUInt32(data, at: 16)
        let shCoefficientsPerChannel = readUInt32(data, at: 20)
        let shHigherOrderPerSplat = readUInt32(data, at: 24)
        let meanSquaredSplatExtent = readFloat(data, at: 28)
        let encodedByteCountRaw = readUInt64(data, at: 32)
        let shByteCountRaw = readUInt64(data, at: 40)
        let boundingBoxMin = simd_float3(readFloat(data, at: 48), readFloat(data, at: 52), readFloat(data, at: 56))
        let boundingBoxMax = simd_float3(readFloat(data, at: 60), readFloat(data, at: 64), readFloat(data, at: 68))

        // Validate every header-declared count against the actual file size using
        // overflow-checked UInt64 arithmetic before converting anything to Int — a corrupt or
        // malicious header can declare values that overflow a plain multiply/add or don't fit
        // Int, and an unchecked Int(...) conversion would trap the process instead of throwing
        // a catchable UntoldGSError.
        let stride = UInt64(MemoryLayout<EncodedGaussianSplat>.stride)
        let (expectedEncodedBytes, splatByteOverflow) = splatCountRaw.multipliedReportingOverflow(by: stride)
        guard !splatByteOverflow, encodedByteCountRaw == expectedEncodedBytes else {
            throw UntoldGSError.sizeMismatch("encoded splat bytes \(encodedByteCountRaw), expected \(expectedEncodedBytes)")
        }

        let (headerPlusEncoded, headerOverflow) = UInt64(headerByteCount).addingReportingOverflow(encodedByteCountRaw)
        let (totalExpectedBytes, totalOverflow) = headerPlusEncoded.addingReportingOverflow(shByteCountRaw)
        guard !headerOverflow, !totalOverflow, UInt64(data.count) == totalExpectedBytes else {
            throw UntoldGSError.sizeMismatch("file has \(data.count) bytes, expected \(totalExpectedBytes)")
        }

        // Both counts are now provably <= data.count (a valid Int), so these conversions
        // cannot trap.
        guard let encodedByteCount = Int(exactly: encodedByteCountRaw),
              let shByteCount = Int(exactly: shByteCountRaw)
        else {
            throw UntoldGSError.sizeMismatch("header-declared byte counts do not fit in memory")
        }

        let encodedStart = headerByteCount
        let encodedEnd = encodedStart + encodedByteCount
        let encodedSplats = data[encodedStart ..< encodedEnd].withUnsafeBytes { rawBuffer in
            Array(rawBuffer.bindMemory(to: EncodedGaussianSplat.self))
        }

        let shStart = encodedEnd
        let shCoefficients = shByteCount > 0 ? Array(data[shStart ..< shStart + shByteCount]) : []
        let shMetadata: GaussianSHMetadata? = shByteCount > 0
            ? GaussianSHMetadata(
                degree: shDegree,
                coefficientsPerChannel: shCoefficientsPerChannel,
                higherOrderCoefficientsPerSplat: shHigherOrderPerSplat,
                _pad0: 0
            )
            : nil

        return UntoldGSAsset(
            encodedSplats: encodedSplats,
            shCoefficients: shCoefficients,
            shMetadata: shMetadata,
            meanSquaredSplatExtent: meanSquaredSplatExtent,
            boundingBoxMin: boundingBoxMin,
            boundingBoxMax: boundingBoxMax
        )
    }

    private static func appendUInt32(_ value: UInt32, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func appendFloat(_ value: Float, to data: inout Data) {
        appendUInt32(value.bitPattern, to: &data)
    }

    private static func readFloat(_ data: Data, at offset: Int) -> Float {
        Float(bitPattern: readUInt32(data, at: offset))
    }

    private static func appendUInt64(_ value: UInt64, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { rawBuffer in
            UInt32(littleEndian: rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }

    private static func readUInt64(_ data: Data, at offset: Int) -> UInt64 {
        data.withUnsafeBytes { rawBuffer in
            UInt64(littleEndian: rawBuffer.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
        }
    }
}

/// Builds GPU buffers from already-encoded Gaussian splat data.
/// Returns `nil` on any failure, calling `handleError` internally — callers just guard-return.
func buildGaussianLoadResult(
    encodedSplats: [EncodedGaussianSplat],
    packedSphericalHarmonics: PackedGaussianSphericalHarmonics?,
    meanSquaredSplatExtent: Float = 0,
    sourceDescription: String
) -> GaussianLoadResult? {
    guard encodedSplats.count <= Int(maxNumOfGaussians) else {
        handleError(.bufferAllocationFailed, "Too many Gaussian splats: \(encodedSplats.count) exceeds maximum \(maxNumOfGaussians)")
        return nil
    }

    let splatCount = UInt(encodedSplats.count)
    guard splatCount > 0 else {
        handleError(.assetDataMissing, "Gaussian splat file contains no vertices: \(sourceDescription)")
        return nil
    }

    var gaussianSortedIndices: [MTLBuffer] = []
    var gaussianVisibleIndices: [MTLBuffer] = []
    var gaussianVisibleCount: [MTLBuffer] = []
    for _ in 0 ..< maxInFlightCommandBuffers {
        guard let sortedIndicesSlot = renderInfo.device.makeBuffer(
            length: MemoryLayout<UInt64>.stride * Int(splatCount),
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "Gaussian sorted-index buffer is nil")
            return nil
        }
        gaussianSortedIndices.append(sortedIndicesSlot)

        guard let visibleIndicesSlot = renderInfo.device.makeBuffer(
            length: MemoryLayout<UInt32>.stride * Int(splatCount),
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "Gaussian visible-index buffer is nil")
            return nil
        }
        gaussianVisibleIndices.append(visibleIndicesSlot)

        guard let visibleCountSlot = renderInfo.device.makeBuffer(
            length: MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "Gaussian visible-count buffer is nil")
            return nil
        }
        visibleCountSlot.contents().storeBytes(of: UInt32(splatCount), as: UInt32.self)
        gaussianVisibleCount.append(visibleCountSlot)
    }

    guard let encodedSplatBuffer = renderInfo.device.makeBuffer(length: MemoryLayout<EncodedGaussianSplat>.stride * Int(splatCount), options: .storageModeShared) else {
        handleError(.bufferAllocationFailed, "Encoded Gaussian splat buffer is nil")
        return nil
    }

    encodedSplats.withUnsafeBytes { bytes in
        encodedSplatBuffer.contents().copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
    }

    var gaussianPrecomputedData: [MTLBuffer] = []
    for _ in 0 ..< maxInFlightCommandBuffers {
        guard let precomputedSlot = renderInfo.device.makeBuffer(
            length: MemoryLayout<GaussianPrecomputedSplat>.stride * Int(splatCount),
            options: .storageModeShared
        ) else {
            handleError(.bufferAllocationFailed, "Gaussian precomputed-splat buffer is nil")
            return nil
        }
        gaussianPrecomputedData.append(precomputedSlot)
    }

    let sphericalHarmonicsBuffer: MTLBuffer?
    if let packedSphericalHarmonics, !packedSphericalHarmonics.coefficients.isEmpty {
        sphericalHarmonicsBuffer = renderInfo.device.makeBuffer(
            bytes: packedSphericalHarmonics.coefficients,
            length: packedSphericalHarmonics.coefficients.count * MemoryLayout<UInt8>.stride,
            options: .storageModeShared
        )
        guard sphericalHarmonicsBuffer != nil else {
            handleError(.bufferAllocationFailed, "Gaussian spherical-harmonics buffer is nil")
            return nil
        }
        sphericalHarmonicsBuffer?.label = "Gaussian Spherical Harmonics"
    } else {
        sphericalHarmonicsBuffer = nil
    }

    let spaceUniform = (0 ..< totalPerMeshUniformBuffers()).compactMap { _ in
        renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                     options: [MTLResourceOptions.storageModeShared])
    }

    var estimatedGPUBytes = 0
    for buffer in gaussianSortedIndices {
        estimatedGPUBytes += buffer.length
    }
    for buffer in gaussianVisibleIndices {
        estimatedGPUBytes += buffer.length
    }
    for buffer in gaussianVisibleCount {
        estimatedGPUBytes += buffer.length
    }
    estimatedGPUBytes += encodedSplatBuffer.length
    for buffer in gaussianPrecomputedData {
        estimatedGPUBytes += buffer.length
    }
    estimatedGPUBytes += sphericalHarmonicsBuffer?.length ?? 0
    for buffer in spaceUniform {
        estimatedGPUBytes += buffer.length
    }

    return GaussianLoadResult(
        splatCount: splatCount,
        gaussianSortedIndices: gaussianSortedIndices,
        gaussianVisibleIndices: gaussianVisibleIndices,
        gaussianVisibleCount: gaussianVisibleCount,
        encodedSplatBuffer: encodedSplatBuffer,
        gaussianPrecomputedData: gaussianPrecomputedData,
        sphericalHarmonicsBuffer: sphericalHarmonicsBuffer,
        sphericalHarmonicsMetadata: packedSphericalHarmonics?.metadata,
        spaceUniform: spaceUniform,
        estimatedGPUBytes: estimatedGPUBytes,
        // Splat centers alone under-size the true silhouette wherever a large-scale splat sits
        // near the edge — pad uniformly by an approximate per-splat radius derived from the
        // tier's mean squared extent (sqrt of the mean of major-axis², i.e. an RMS radius),
        // since only splat centers/positions (not per-splat scale) are available post-encode.
        boundingBox: computeGaussianSplatPositionBoundingBox(
            encodedSplats.map(\.position),
            padding: meanSquaredSplatExtent > 0 ? sqrt(meanSquaredSplatExtent) : 0
        )
    )
}

/// Min/max bounding box over a set of local-space splat positions, expanded by `padding` in
/// every direction (see call site doc for why: splat centers alone under-size the true
/// silhouette). Mirrors `Mesh.computeMeshBoundingBox`'s shape/purpose for the mesh path.
func computeGaussianSplatPositionBoundingBox(_ positions: [simd_float3], padding: Float = 0) -> (min: simd_float3, max: simd_float3) {
    guard !positions.isEmpty else { return (min: .zero, max: .zero) }
    var boundsMin = simd_float3(repeating: .infinity)
    var boundsMax = simd_float3(repeating: -.infinity)
    for position in positions {
        boundsMin = simd_min(boundsMin, position)
        boundsMax = simd_max(boundsMax, position)
    }
    let paddingVector = simd_float3(repeating: padding)
    return (min: boundsMin - paddingVector, max: boundsMax + paddingVector)
}

/// Min/max bounding box over a set of source `GaussianSplat`s (bake-time, pre-encode form),
/// expanded per-splat by its own major-axis extent (`gaussianMajorAxis`) rather than just its
/// center — a splat whose center sits near the silhouette boundary but has a large individual
/// scale visually extends past a centers-only box. Used for the asset-level box in
/// `bakeGaussianSplatProgressiveTiers`, where the position hasn't been encoded into
/// `EncodedGaussianSplat` yet and real per-splat scale is still available.
func computeGaussianSplatBoundingBox(_ splats: [GaussianSplat]) -> (min: simd_float3, max: simd_float3) {
    guard !splats.isEmpty else { return (min: .zero, max: .zero) }
    var boundsMin = simd_float3(repeating: .infinity)
    var boundsMax = simd_float3(repeating: -.infinity)
    for splat in splats {
        let center = simd_float3(splat.center.x, splat.center.y, splat.center.z)
        let radius = simd_float3(repeating: gaussianMajorAxis(splat))
        boundsMin = simd_min(boundsMin, center - radius)
        boundsMax = simd_max(boundsMax, center + radius)
    }
    return (min: boundsMin, max: boundsMax)
}

/// Reads a `.ply` Gaussian splat asset from disk and builds its GPU buffers.
/// Returns `nil` on any failure, calling `handleError` internally — callers just guard-return.
private func buildGaussianLoadResult(filename: String, withExtension: String) -> GaussianLoadResult? {
    guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return nil
    }

    do {
        return try buildGaussianLoadResultFromPLY(url: url, sourceDescription: filename)
    } catch {
        handleError(.assetDataMissing, "Failed to read Gaussian splats from \(filename): \(error.localizedDescription)")
        return nil
    }
}

func buildGaussianLoadResultFromPLY(url: URL, sourceDescription: String) throws -> GaussianLoadResult? {
    let asset = try PLYReader.readGaussianAsset(from: url)
    let encodedSplats = asset.splats.map(encodeGaussianSplatForTBDR)

    // Reported here, distinctly from a raw PLY-parse failure (which propagates to the
    // caller's catch instead), so a debugger sees "failed to pack SH" rather than a generic
    // "failed to read" message when the file parses fine but has bad SH data (e.g. NaN).
    let packedSphericalHarmonics: PackedGaussianSphericalHarmonics?
    do {
        packedSphericalHarmonics = try asset.sphericalHarmonics.map {
            try packGaussianSphericalHarmonics($0, splatCount: asset.splats.count)
        }
    } catch {
        handleError(.assetDataMissing, "Failed to pack spherical harmonics from \(sourceDescription): \(error.localizedDescription)")
        return nil
    }

    return buildGaussianLoadResult(
        encodedSplats: encodedSplats,
        packedSphericalHarmonics: packedSphericalHarmonics,
        meanSquaredSplatExtent: meanSquaredSplatExtent(asset.splats, keeping: Array(asset.splats.indices)),
        sourceDescription: sourceDescription
    )
}

func buildGaussianComponentFromUntoldGS(url: URL) -> (
    component: GaussianComponent,
    estimatedGPUBytes: Int,
    meanSquaredSplatExtent: Float,
    boundingBox: (min: simd_float3, max: simd_float3)
)? {
    let asset: UntoldGSAsset
    do {
        asset = try UntoldGSFormat.read(from: url)
    } catch {
        handleError(.assetDataMissing, "Failed to read .untoldgs Gaussian tier from \(url.lastPathComponent): \(error)")
        return nil
    }

    let packedSphericalHarmonics = asset.shMetadata.map {
        PackedGaussianSphericalHarmonics(coefficients: asset.shCoefficients, metadata: $0)
    }

    guard let result = buildGaussianLoadResult(
        encodedSplats: asset.encodedSplats,
        packedSphericalHarmonics: packedSphericalHarmonics,
        meanSquaredSplatExtent: asset.meanSquaredSplatExtent,
        sourceDescription: url.lastPathComponent
    ) else {
        return nil
    }

    let component = GaussianComponent()
    copyGaussianLoadResult(result, to: component)
    return (component, result.estimatedGPUBytes, asset.meanSquaredSplatExtent, result.boundingBox)
}

/// Registers `GaussianComponent` on `entityId` from a built `GaussianLoadResult` and records
/// its GPU footprint with `MemoryBudgetManager`. Must be called from within a world-mutation
/// gate (`withWorldMutationGate`).
private func applyGaussianLoadResult(_ result: GaussianLoadResult, to entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: GaussianComponent.self)

    guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
        handleError(.noRenderComponent, entityId)
        return
    }

    copyGaussianLoadResult(result, to: gaussianComponent)
    MemoryBudgetManager.shared.registerMesh(entityId: entityId, meshSizeBytes: result.estimatedGPUBytes)

    if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
        localTransform.boundingBox = result.boundingBox
    }
}

func copyGaussianLoadResult(_ result: GaussianLoadResult, to gaussianComponent: GaussianComponent) {
    gaussianComponent.splatCount = result.splatCount
    gaussianComponent.visibleSplatCountForRendering = result.splatCount
    gaussianComponent.gaussianSortedIndices = result.gaussianSortedIndices.map { $0 as MTLBuffer? }
    gaussianComponent.gaussianVisibleIndices = result.gaussianVisibleIndices.map { $0 as MTLBuffer? }
    gaussianComponent.gaussianVisibleCount = result.gaussianVisibleCount.map { $0 as MTLBuffer? }
    gaussianComponent.encodedSplatData = result.encodedSplatBuffer
    gaussianComponent.gaussianPrecomputedData = result.gaussianPrecomputedData.map { $0 as MTLBuffer? }
    gaussianComponent.sphericalHarmonicsData = result.sphericalHarmonicsBuffer
    gaussianComponent.sphericalHarmonicsMetadata = result.sphericalHarmonicsMetadata
    gaussianComponent.spaceUniform = result.spaceUniform
}

public enum GaussianSource {
    case single(filename: String, withExtension: String)
    /// No `boundingBoxHalfExtent` here: both `setEntityGaussian(source:)` and
    /// `setEntityGaussianStreaming(source:options:)` can read a real box baked into the
    /// `.untoldgs` header itself (see `UntoldGSFormat.readHeader`) — an explicit override, when
    /// one is genuinely needed, is a parameter on the underlying registration path instead
    /// (`GaussianStreamingOptions.boundingBoxHalfExtent` for streaming). Overdraw-aware LOD
    /// stats (`meanSquaredSplatExtent`) are baked directly into each `.untoldgs` tier by
    /// `bakeGaussianSplatProgressiveTiers` and read automatically when a tier loads — nothing to
    /// pass here either.
    case progressive(
        baseFilename: String,
        withExtension: String = "untoldgs",
        levelCount: Int,
        maxDistances: [Float]
    )
}

public typealias GaussianStreamingSource = GaussianSource

public func setEntityGaussian(entityId: EntityID, filename: String, withExtension: String) {
    guard let result = buildGaussianLoadResult(filename: filename, withExtension: withExtension) else {
        return
    }

    withWorldMutationGate {
        applyGaussianLoadResult(result, to: entityId)
    }
}

/// Registers a Gaussian splat entity that is always present, either as one whole asset or
/// as a progressive multi-tier `.untoldgs` asset. Progressive entities do not require a
/// streamed tile scene: the coarsest tier is loaded immediately, then `GaussianLODSystem`
/// requests finer tiers based on camera distance.
public func setEntityGaussian(entityId: EntityID, source: GaussianSource) {
    switch source {
    case let .single(filename, ext):
        setEntityGaussian(entityId: entityId, filename: filename, withExtension: ext)
    case let .progressive(baseFilename, ext, levelCount, maxDistances):
        setEntityGaussianProgressive(
            entityId: entityId,
            baseFilename: baseFilename,
            withExtension: ext,
            levelCount: levelCount,
            maxDistances: maxDistances
        )
    }
}

/// Asynchronously reads and encodes a `.ply` Gaussian splat asset and attaches it to
/// `entityId` without blocking the main thread. Parsing, per-splat encoding, and spherical-
/// harmonics packing all run before the world-mutation gate is acquired; only the final
/// component registration runs under `withWorldMutationGate`, mirroring `setEntityMeshAsync`'s
/// pattern of keeping GPU resource work outside the gate.
///
/// `async -> Bool` (rather than `setEntityMeshAsync`'s fire-and-forget/completion shape) so
/// `GeometryStreamingSystem.loadMesh` can `await` it directly from its own dispatch `Task`,
/// the same way it awaits the mesh path. Used both by direct callers that want a non-blocking
/// one-off load, and internally by the streaming system for distance-streamed splat props —
/// gaussians have no cache/OCC layer analogous to `MeshResourceManager`, so unlike mesh
/// streaming there is no separate streaming-only loader.
@discardableResult
public func setEntityGaussianAsync(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    completion: (@Sendable (Bool) -> Void)? = nil
) async -> Bool {
    guard let result = buildGaussianLoadResult(filename: filename, withExtension: withExtension) else {
        completion?(false)
        return false
    }

    withWorldMutationGate {
        applyGaussianLoadResult(result, to: entityId)
    }

    completion?(true)
    return true
}

public struct GaussianStreamingOptions {
    public var streamingRadius: Float
    public var unloadRadius: Float
    /// Explicit override for the entity's local-space bounding box. Optional: `.untoldgs`
    /// sources (single-file or progressive) can read a real box baked into the file itself —
    /// see `UntoldGSFormat.readHeader` — so this is only required for a raw `.ply` `.single`
    /// source, which has no baked box to fall back to.
    public var boundingBoxHalfExtent: simd_float3?
    public var priority: Int

    public init(
        streamingRadius: Float = 100.0,
        unloadRadius: Float = 150.0,
        boundingBoxHalfExtent: simd_float3? = nil,
        priority: Int = 0
    ) {
        self.streamingRadius = streamingRadius
        self.unloadRadius = unloadRadius
        self.boundingBoxHalfExtent = boundingBoxHalfExtent
        self.priority = priority
    }
}

/// Registers a distance-streamed Gaussian splat entity, either as one whole asset or as a
/// progressive multi-tier asset. Prefer this API for new call sites.
public func setEntityGaussianStreaming(
    entityId: EntityID,
    source: GaussianSource,
    options: GaussianStreamingOptions
) {
    switch source {
    case let .single(filename, ext):
        setEntityGaussianStreamable(
            entityId: entityId,
            filename: filename,
            withExtension: ext,
            streamingRadius: options.streamingRadius,
            unloadRadius: options.unloadRadius,
            boundingBoxHalfExtent: options.boundingBoxHalfExtent,
            priority: options.priority
        )
    case let .progressive(baseFilename, ext, levelCount, maxDistances):
        setEntityGaussianProgressiveStreamable(
            entityId: entityId,
            baseFilename: baseFilename,
            withExtension: ext,
            levelCount: levelCount,
            maxDistances: maxDistances,
            streamingRadius: options.streamingRadius,
            unloadRadius: options.unloadRadius,
            boundingBoxHalfExtent: options.boundingBoxHalfExtent,
            priority: options.priority
        )
    }
}

/// Registers a tile-independent progressive Gaussian splat entity. Not part of the public API
/// — reached only through `setEntityGaussian(entityId:source:)`'s `.progressive` case, which is
/// the entry point callers should use.
///
/// The expected files are `<baseFilename>_lod0.untoldgs`, `<baseFilename>_lod1.untoldgs`,
/// etc. LOD0 is full detail; the highest index is the coarsest tier and is loaded
/// immediately so the entity can become visible before finer tiers finish loading.
func setEntityGaussianProgressive(
    entityId: EntityID,
    baseFilename: String,
    withExtension ext: String = "untoldgs",
    levelCount: Int,
    maxDistances: [Float]
) {
    guard configureEntityGaussianProgressiveLOD(
        entityId: entityId,
        baseFilename: baseFilename,
        withExtension: ext,
        levelCount: levelCount,
        maxDistances: maxDistances,
        errorPrefix: "setEntityGaussianProgressive"
    ) else { return }

    // Read the box baked into the coarsest tier's header (cheap, synchronous) so the entity has
    // a real box from frame 1 instead of waiting on the async coarsest-tier load below to
    // populate one via GeometryStreamingSystem+GaussianStreaming.swift's hasExplicitBoundingBox
    // fallback. If unavailable (e.g. a pre-v2 .untoldgs file), that fallback still applies
    // unchanged. No caller-supplied override here — GaussianSource.progressive has no
    // boundingBoxHalfExtent of its own to forward (see its doc comment).
    let coarsestTierURL = gaussianProgressiveTierURL(baseFilename: baseFilename, withExtension: ext, levelCount: levelCount, tierIndex: levelCount - 1)
    if let box = resolveGaussianBoundingBox(override: nil, untoldgsURL: coarsestTierURL),
       let local = scene.get(component: LocalTransformComponent.self, for: entityId)
    {
        local.boundingBox = box
        scene.get(component: GaussianLODComponent.self, for: entityId)?.hasExplicitBoundingBox = true
    }

    // Store the load on the coarsest tier's loadTask, mirroring requestGaussianLODLevelLoad's
    // pattern, so removeEntityGaussianLOD can cancel it if entityId is destroyed while this is
    // still in flight. The assignment happens inside the same gate that spawns the Task: since
    // the Task's own body needs this same lock to touch scene state, it can't run ahead and
    // clear loadTask before this closure finishes assigning it.
    withWorldMutationGate {
        guard let lod = scene.get(component: GaussianLODComponent.self, for: entityId),
              !lod.lodLevels.isEmpty
        else { return }

        let coarsestIndex = lod.lodLevels.count - 1
        let task = Task {
            _ = await GeometryStreamingSystem.shared.loadInitialGaussianProgressiveTier(entityId: entityId)
        }
        lod.lodLevels[coarsestIndex].loadTask = task
    }
}

/// Registers `entityId` as a distance-streamed Gaussian-splat prop, so
/// `GeometryStreamingSystem` loads/unloads it based on camera distance the same way it
/// does the surrounding tile geometry — rather than loading it immediately the way
/// `setEntityGaussian`/`setEntityGaussianAsync` do.
///
/// `entityId` should already be positioned (e.g. via `translateTo`/`rotateTo`) before
/// calling this — the entity's current `LocalTransformComponent.position` is used to find
/// which tile it belongs to, via `findTileEntity(containing:)`. If no tile is found there,
/// this logs a warning and leaves `entityId` as a plain, non-streaming entity.
///
/// `boundingBoxHalfExtent` is optional: a `.untoldgs` source has a real box baked into its
/// header (see `UntoldGSFormat.readHeader`), read synchronously here since
/// `GeometryStreamingSystem`'s frustum gate needs a real local-space volume on the entity
/// before it ever loads. A raw `.ply` source has no baked box, so an explicit value is still
/// required there — omitting it leaves the entity non-streaming rather than registering a
/// zero-size placeholder, which would collapse the gate to a single exact point and make
/// re-streaming unreliable once the camera moves away and back.
///
/// Not part of the public API — reached only through
/// `setEntityGaussianStreaming(entityId:source:options:)`'s `.single` case, which forwards
/// `GaussianStreamingOptions.boundingBoxHalfExtent` here; that's the entry point callers should
/// use.
func setEntityGaussianStreamable(
    entityId: EntityID,
    filename: String,
    withExtension ext: String,
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    boundingBoxHalfExtent: simd_float3? = nil,
    priority: Int = 0
) {
    guard let local = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard let tileEntity = findTileEntity(containing: local.position) else {
        Logger.logWarning(message: "[RegistrationSystem] setEntityGaussianStreamable: no tile found containing position \(local.position) for entity \(entityId) — entity left non-streaming.")
        return
    }

    let untoldgsURL = ext.lowercased() == "untoldgs"
        ? LoadingSystem.shared.resourceURL(forResource: filename, withExtension: ext, subResource: nil)
        : nil
    guard let box = resolveGaussianBoundingBox(override: boundingBoxHalfExtent, untoldgsURL: untoldgsURL) else {
        Logger.logWarning(message: "[RegistrationSystem] setEntityGaussianStreamable: no boundingBoxHalfExtent supplied and no baked box available for '\(filename).\(ext)' — entity left non-streaming. A raw .ply source requires an explicit boundingBoxHalfExtent.")
        return
    }
    local.boundingBox = box

    setParent(childId: entityId, parentId: tileEntity)
    OctreeSystem.shared.registerEntity(entityId)

    if let streaming = scene.assign(to: entityId, component: StreamingComponent.self) {
        streaming.assetKind = .gaussianSplat
        streaming.assetFilename = filename
        streaming.assetExtension = ext
        streaming.streamingRadius = streamingRadius
        streaming.unloadRadius = unloadRadius
        streaming.priority = priority
    }
}

/// Registers `entityId` as a distance-streamed progressive Gaussian splat prop.
///
/// The expected files are `<baseFilename>_lod0.untoldgs`, `<baseFilename>_lod1.untoldgs`,
/// etc. LOD0 is full detail; the highest index is the coarsest tier and is loaded first
/// when the prop enters streaming range. Finer tiers are requested later by
/// `GaussianLODSystem` based on camera distance.
///
/// Not part of the public API — reached only through
/// `setEntityGaussianStreaming(entityId:source:options:)`'s `.progressive` case, which forwards
/// `GaussianStreamingOptions.boundingBoxHalfExtent` here; that's the entry point callers should
/// use.
func setEntityGaussianProgressiveStreamable(
    entityId: EntityID,
    baseFilename: String,
    withExtension ext: String = "untoldgs",
    levelCount: Int,
    maxDistances: [Float],
    streamingRadius: Float = 100.0,
    unloadRadius: Float = 150.0,
    boundingBoxHalfExtent: simd_float3? = nil,
    priority: Int = 0
) {
    guard let local = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }
    guard let tileEntity = findTileEntity(containing: local.position) else {
        Logger.logWarning(message: "[RegistrationSystem] setEntityGaussianProgressiveStreamable: no tile found containing position \(local.position) for entity \(entityId) — entity left non-streaming.")
        return
    }

    // Resolve LOD levels (and validate levelCount/maxDistances/tier files) before touching
    // parent/octree/box state, so a validation failure here leaves the entity exactly as it
    // was before this call — no half-registered state to clean up.
    guard configureEntityGaussianProgressiveLOD(
        entityId: entityId,
        baseFilename: baseFilename,
        withExtension: ext,
        levelCount: levelCount,
        maxDistances: maxDistances,
        errorPrefix: "setEntityGaussianProgressiveStreamable"
    ) else { return }

    // configureEntityGaussianProgressiveLOD already confirmed every tier's file exists (it
    // resolves and validates each URL, including the coarsest), so this is a header-parse
    // concern only, not a file-lookup one.
    let coarsestTierURL = scene.get(component: GaussianLODComponent.self, for: entityId)?.lodLevels.last?.url
    guard let box = resolveGaussianBoundingBox(override: boundingBoxHalfExtent, untoldgsURL: coarsestTierURL) else {
        Logger.logWarning(message: "[RegistrationSystem] setEntityGaussianProgressiveStreamable: no boundingBoxHalfExtent supplied and no baked box available for '\(baseFilename)' — entity left non-streaming.")
        removeEntityGaussianLOD(entityId: entityId)
        return
    }
    local.boundingBox = box
    // boundingBoxHalfExtent may come from either an explicit override or the baked header —
    // mark it explicit either way so loadGaussianLODLevel never overwrites it with a redundant
    // auto-computed one once the first tier actually loads.
    scene.get(component: GaussianLODComponent.self, for: entityId)?.hasExplicitBoundingBox = true

    setParent(childId: entityId, parentId: tileEntity)
    OctreeSystem.shared.registerEntity(entityId)

    if let streaming = scene.assign(to: entityId, component: StreamingComponent.self) {
        streaming.assetKind = .gaussianSplat
        streaming.assetFilename = baseFilename
        streaming.assetExtension = ext
        streaming.streamingRadius = streamingRadius
        streaming.unloadRadius = unloadRadius
        streaming.priority = priority
    }
}

/// Resolves the on-disk URL for one progressive tier, given the same `<baseFilename>_lod<N>`
/// naming `configureEntityGaussianProgressiveLOD` uses (or just `baseFilename` when
/// `levelCount == 1`, matching `bakeGaussianSplatProgressiveTiers`'s single-tier output).
/// Factored out so callers can resolve a specific tier's URL (typically the coarsest, for a
/// bounding-box header read) without going through full LOD-component setup first.
private func gaussianProgressiveTierURL(
    baseFilename: String,
    withExtension ext: String,
    levelCount: Int,
    tierIndex: Int
) -> URL? {
    let filename = levelCount == 1 ? baseFilename : "\(baseFilename)_lod\(tierIndex)"
    return LoadingSystem.shared.resourceURL(forResource: filename, withExtension: ext, subResource: nil)
}

/// Resolves a local-space bounding box for Gaussian entity registration: an explicit
/// caller-supplied `override` always wins; otherwise, if `untoldgsURL` points at a real,
/// header-readable `.untoldgs` file, reads its baked box (see `UntoldGSFormat.readHeader`) —
/// cheap enough to call synchronously at registration time. Returns `nil` when neither is
/// available (e.g. a raw `.ply` source with no override) — callers decide how to handle that.
private func resolveGaussianBoundingBox(
    override: simd_float3?,
    untoldgsURL: URL?
) -> (min: simd_float3, max: simd_float3)? {
    if let override {
        return (min: -override, max: override)
    }
    guard let untoldgsURL, let header = try? UntoldGSFormat.readHeader(from: untoldgsURL) else {
        return nil
    }
    return (min: header.boundingBoxMin, max: header.boundingBoxMax)
}

@discardableResult
private func configureEntityGaussianProgressiveLOD(
    entityId: EntityID,
    baseFilename: String,
    withExtension ext: String,
    levelCount: Int,
    maxDistances: [Float],
    errorPrefix: String
) -> Bool {
    guard levelCount > 0 else {
        handleError(.assetDataMissing, "\(errorPrefix): levelCount must be at least 1, got \(levelCount)")
        return false
    }
    guard maxDistances.count == levelCount else {
        handleError(.assetDataMissing, "\(errorPrefix): maxDistances must have \(levelCount) entries, got \(maxDistances.count)")
        return false
    }

    var levels: [GaussianLODLevel] = []
    for index in 0 ..< levelCount {
        guard let url = gaussianProgressiveTierURL(baseFilename: baseFilename, withExtension: ext, levelCount: levelCount, tierIndex: index) else {
            let filename = levelCount == 1 ? baseFilename : "\(baseFilename)_lod\(index)"
            handleError(.filenameNotFound, filename)
            return false
        }
        // meanSquaredSplatExtent is populated automatically by loadGaussianLODLevel when this
        // tier's .untoldgs file is actually read — it's baked into the file, not caller-supplied.
        levels.append(GaussianLODLevel(maxDistance: maxDistances[index], url: url))
    }

    guard let lodComponent = scene.assign(to: entityId, component: GaussianLODComponent.self) else {
        return false
    }
    lodComponent.lodLevels = levels
    lodComponent.currentLOD = -1
    lodComponent.desiredLOD = levelCount - 1
    lodComponent.isUsingFallback = false
    return true
}

/// Largest per-axis scale magnitude of a splat, used both as the size term in
/// `gaussianImportanceScore` and, aggregated across a tier, as
/// `GaussianLODTier.meanSquaredSplatExtent` for overdraw estimation.
func gaussianMajorAxis(_ splat: GaussianSplat) -> Float {
    max(abs(splat.scale.x), max(abs(splat.scale.y), abs(splat.scale.z)))
}

private func gaussianImportanceScore(_ splat: GaussianSplat) -> Float {
    let majorAxis = gaussianMajorAxis(splat)
    return splat.opacity * majorAxis * majorAxis
}

private struct GaussianSpatialBucketKey: Hashable {
    let x: Int
    let y: Int
    let z: Int
}

private func spatiallyInterleavedGaussianRanking(_ splats: [GaussianSplat]) -> [Int] {
    guard splats.count > 1 else { return Array(splats.indices) }

    var minBounds = simd_float3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
    var maxBounds = simd_float3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
    for splat in splats {
        let center = simd_float3(splat.center.x, splat.center.y, splat.center.z)
        minBounds = simd_min(minBounds, center)
        maxBounds = simd_max(maxBounds, center)
    }

    let extent = maxBounds - minBounds
    let occupiedAxisCount = [extent.x, extent.y, extent.z].filter { $0 > 0.0001 }.count
    guard occupiedAxisCount > 0 else {
        return splats.indices.sorted {
            gaussianImportanceScore(splats[$0]) > gaussianImportanceScore(splats[$1])
        }
    }

    let targetCellCount = max(8, min(512, splats.count / 24))
    let cellsPerAxis = max(1, Int(ceil(pow(Double(targetCellCount), 1.0 / Double(occupiedAxisCount)))))
    let safeExtent = simd_float3(
        max(extent.x, 0.0001),
        max(extent.y, 0.0001),
        max(extent.z, 0.0001)
    )

    var buckets: [GaussianSpatialBucketKey: [Int]] = [:]
    for index in splats.indices {
        let center = simd_float3(splats[index].center.x, splats[index].center.y, splats[index].center.z)
        let normalized = (center - minBounds) / safeExtent
        let maxCellIndex = cellsPerAxis - 1
        let cellX = min(maxCellIndex, max(0, Int(normalized.x * Float(cellsPerAxis))))
        let cellY = min(maxCellIndex, max(0, Int(normalized.y * Float(cellsPerAxis))))
        let cellZ = min(maxCellIndex, max(0, Int(normalized.z * Float(cellsPerAxis))))
        let key = GaussianSpatialBucketKey(x: cellX, y: cellY, z: cellZ)
        buckets[key, default: []].append(index)
    }

    let sortedBuckets = buckets.mapValues { indices in
        indices.sorted {
            gaussianImportanceScore(splats[$0]) > gaussianImportanceScore(splats[$1])
        }
    }

    let bucketCenters = sortedBuckets.mapValues { indices in
        var center = simd_float3.zero
        for index in indices {
            center += simd_float3(splats[index].center.x, splats[index].center.y, splats[index].center.z)
        }
        return center / Float(max(1, indices.count))
    }

    var remainingBuckets = Array(sortedBuckets.keys)
    var bucketOrder: [GaussianSpatialBucketKey] = []
    if let first = remainingBuckets.max(by: { lhs, rhs in
        guard let lhsIndex = sortedBuckets[lhs]?.first,
              let rhsIndex = sortedBuckets[rhs]?.first
        else { return false }
        return gaussianImportanceScore(splats[lhsIndex]) < gaussianImportanceScore(splats[rhsIndex])
    }) {
        bucketOrder.append(first)
        remainingBuckets.removeAll { $0 == first }
    }

    while !remainingBuckets.isEmpty {
        let next = remainingBuckets.max { lhs, rhs in
            let lhsDistance = nearestSelectedBucketDistanceSquared(lhs, centers: bucketCenters, selected: bucketOrder)
            let rhsDistance = nearestSelectedBucketDistanceSquared(rhs, centers: bucketCenters, selected: bucketOrder)
            if lhsDistance == rhsDistance {
                let lhsIndex = sortedBuckets[lhs]?.first ?? 0
                let rhsIndex = sortedBuckets[rhs]?.first ?? 0
                return gaussianImportanceScore(splats[lhsIndex]) < gaussianImportanceScore(splats[rhsIndex])
            }
            return lhsDistance < rhsDistance
        }!
        bucketOrder.append(next)
        remainingBuckets.removeAll { $0 == next }
    }

    var ranking: [Int] = []
    ranking.reserveCapacity(splats.count)
    var depth = 0
    while ranking.count < splats.count {
        var appendedThisRound = false
        for key in bucketOrder {
            guard let indices = sortedBuckets[key], depth < indices.count else { continue }
            ranking.append(indices[depth])
            appendedThisRound = true
        }
        guard appendedThisRound else { break }
        depth += 1
    }

    return ranking
}

private func nearestSelectedBucketDistanceSquared(
    _ key: GaussianSpatialBucketKey,
    centers: [GaussianSpatialBucketKey: simd_float3],
    selected: [GaussianSpatialBucketKey]
) -> Float {
    guard let center = centers[key], !selected.isEmpty else { return Float.greatestFiniteMagnitude }
    var best = Float.greatestFiniteMagnitude
    for selectedKey in selected {
        guard let selectedCenter = centers[selectedKey] else { continue }
        best = min(best, simd_distance_squared(center, selectedCenter))
    }
    return best
}

private func subsetSphericalHarmonics(
    _ sh: GaussianSphericalHarmonics,
    keeping indices: [Int]
) -> GaussianSphericalHarmonics {
    let perSplat = sh.coefficientsPerSplat
    var subset: [Float] = []
    subset.reserveCapacity(indices.count * perSplat)
    for index in indices {
        let base = index * perSplat
        subset.append(contentsOf: sh.coefficients[base ..< base + perSplat])
    }
    return GaussianSphericalHarmonics(
        degree: sh.degree,
        coefficientsPerChannel: sh.coefficientsPerChannel,
        coefficients: subset
    )
}

/// One baked `.untoldgs` tier plus the bake-time statistic needed for overdraw estimation —
/// see `estimatedGaussianOverdraw`.
public struct GaussianLODTier {
    public let url: URL
    public let meanSquaredSplatExtent: Float
}

/// Result of `bakeGaussianSplatProgressiveTiers`: the baked tiers plus a single asset-level
/// bounding box (from the full, unsubsetted source splats) shared by all tiers so it stays
/// stable across LOD switches.
public struct GaussianProgressiveBakeResult {
    public let tiers: [GaussianLODTier]
    public let boundingBoxMin: simd_float3
    public let boundingBoxMax: simd_float3
}

private func meanSquaredSplatExtent(_ splats: [GaussianSplat], keeping indices: [Int]) -> Float {
    guard !indices.isEmpty else { return 0 }
    let sumOfSquares = indices.reduce(Float(0)) { partial, index in
        let majorAxis = gaussianMajorAxis(splats[index])
        return partial + majorAxis * majorAxis
    }
    return sumOfSquares / Float(indices.count)
}

/// Bakes progressive `.untoldgs` Gaussian tiers from a source `.ply`.
///
/// `lodFractions` are ordered finest to coarsest. With `[1.0, 0.5, 0.25]`, output files are
/// `<base>_lod0.untoldgs`, `<base>_lod1.untoldgs`, and `<base>_lod2.untoldgs`.
///
/// Throws `UntoldGSError.sizeMismatch` if `plyURL` contains no splats, regardless of
/// `lodFractions` — including the single-tier (`[1.0]`) case, which needs the same guard since
/// it now also computes an asset-level bounding box that's meaningless for zero splats.
public func bakeGaussianSplatProgressiveTiers(
    plyURL: URL,
    outputBaseURL: URL,
    lodFractions: [Float]
) throws -> GaussianProgressiveBakeResult {
    guard !lodFractions.isEmpty else {
        throw UntoldGSError.sizeMismatch("lodFractions must contain at least one entry")
    }

    let asset = try PLYReader.readGaussianAsset(from: plyURL)
    guard !asset.splats.isEmpty else {
        throw UntoldGSError.sizeMismatch("source .ply contains no splats")
    }
    let assetBoundingBox = computeGaussianSplatBoundingBox(asset.splats)

    if lodFractions == [1.0] {
        let resultURL = outputBaseURL
        let allIndices = Array(asset.splats.indices)
        let encodedSplats = asset.splats.map(encodeGaussianSplatForTBDR)
        let packedSphericalHarmonics = try asset.sphericalHarmonics.map {
            try packGaussianSphericalHarmonics($0, splatCount: asset.splats.count)
        }
        let tierExtent = meanSquaredSplatExtent(asset.splats, keeping: allIndices)
        try UntoldGSFormat.write(
            encodedSplats: encodedSplats,
            sphericalHarmonics: packedSphericalHarmonics,
            meanSquaredSplatExtent: tierExtent,
            boundingBoxMin: assetBoundingBox.min,
            boundingBoxMax: assetBoundingBox.max,
            to: resultURL
        )
        return GaussianProgressiveBakeResult(
            tiers: [GaussianLODTier(url: resultURL, meanSquaredSplatExtent: tierExtent)],
            boundingBoxMin: assetBoundingBox.min,
            boundingBoxMax: assetBoundingBox.max
        )
    }

    let rankedIndices = spatiallyInterleavedGaussianRanking(asset.splats)

    let baseWithoutExtension = outputBaseURL.deletingPathExtension()
    let baseName = baseWithoutExtension.lastPathComponent
    let baseDirectory = baseWithoutExtension.deletingLastPathComponent()

    var tiers: [GaussianLODTier] = []
    for (tierIndex, fraction) in lodFractions.enumerated() {
        let clampedFraction = min(max(fraction, 0), 1)
        let keepCount = max(1, Int((Float(asset.splats.count) * clampedFraction).rounded(.up)))
        let keptIndices = Array(rankedIndices.prefix(keepCount))
        let encodedSplats = keptIndices.map { encodeGaussianSplatForTBDR(asset.splats[$0]) }
        let packedSphericalHarmonics = try asset.sphericalHarmonics.map { sh in
            try packGaussianSphericalHarmonics(
                subsetSphericalHarmonics(sh, keeping: keptIndices),
                splatCount: keptIndices.count
            )
        }
        let tierURL = baseDirectory
            .appendingPathComponent("\(baseName)_lod\(tierIndex)")
            .appendingPathExtension("untoldgs")
        let tierExtent = meanSquaredSplatExtent(asset.splats, keeping: keptIndices)
        try UntoldGSFormat.write(
            encodedSplats: encodedSplats,
            sphericalHarmonics: packedSphericalHarmonics,
            meanSquaredSplatExtent: tierExtent,
            boundingBoxMin: assetBoundingBox.min,
            boundingBoxMax: assetBoundingBox.max,
            to: tierURL
        )
        tiers.append(GaussianLODTier(url: tierURL, meanSquaredSplatExtent: tierExtent))
    }
    return GaussianProgressiveBakeResult(
        tiers: tiers,
        boundingBoxMin: assetBoundingBox.min,
        boundingBoxMax: assetBoundingBox.max
    )
}

public func bakeGaussianSplatProgressiveTiers(
    plyURL: URL,
    outputBaseURL: URL,
    levelCount: Int
) throws -> GaussianProgressiveBakeResult {
    guard levelCount > 0 else {
        throw UntoldGSError.sizeMismatch("levelCount must be at least 1, got \(levelCount)")
    }
    let fractions = (0 ..< levelCount).map { Float(1.0) / Float(1 << $0) }
    return try bakeGaussianSplatProgressiveTiers(
        plyURL: plyURL,
        outputBaseURL: outputBaseURL,
        lodFractions: fractions
    )
}

public struct PackedGaussianSphericalHarmonics {
    public let coefficients: [UInt8]
    public let metadata: GaussianSHMetadata
}

/// Quantizes a higher-order SH coefficient into the GPU's fixed [-1, 1] byte
/// contract. Mirrors `loadGaussianSHCoefficient`'s dequantization in
/// Gaussians.metal: `(byte - 128) / 128`. Values outside [-1, 1] are clamped
/// rather than rejected — real trained assets occasionally have rare
/// higher-order outliers (e.g. strong specular splats), and clamping only
/// caps the affected highlight rather than discarding the whole asset.
func quantizeGaussianSHCoefficient(_ value: Float) -> UInt8 {
    let clamped = min(max(value, -1), 1)
    return UInt8(clamping: Int(clamped * 127) + 128)
}

/// Packs higher-order SH coefficients to the GPU contract while leaving DC
/// color in `EncodedGaussianSplat`. Input and output are both channel-major.
/// Higher-order coefficients are quantized to one byte each; see
/// `quantizeGaussianSHCoefficient`.
func packGaussianSphericalHarmonics(
    _ sphericalHarmonics: GaussianSphericalHarmonics,
    splatCount: Int
) throws -> PackedGaussianSphericalHarmonics {
    let coefficientsPerChannel = sphericalHarmonics.coefficientsPerChannel
    let higherOrderPerChannel = coefficientsPerChannel - 1
    let inputPerSplat = sphericalHarmonics.coefficientsPerSplat
    let expectedInputCount = splatCount * inputPerSplat

    guard (0 ... 3).contains(sphericalHarmonics.degree),
          coefficientsPerChannel == (sphericalHarmonics.degree + 1) * (sphericalHarmonics.degree + 1),
          sphericalHarmonics.coefficients.count == expectedInputCount
    else {
        throw PLYError.invalidData("Spherical-harmonic data does not match its degree or splat count")
    }

    let outputPerSplat = higherOrderPerChannel * 3
    var packed: [UInt8] = []
    packed.reserveCapacity(splatCount * outputPerSplat)

    for splatIndex in 0 ..< splatCount {
        let splatBase = splatIndex * inputPerSplat
        for channel in 0 ..< 3 {
            let channelBase = splatBase + channel * coefficientsPerChannel
            for coefficient in 1 ..< coefficientsPerChannel {
                let value = sphericalHarmonics.coefficients[channelBase + coefficient]
                guard value.isFinite else {
                    throw PLYError.invalidData("Spherical-harmonic coefficient is not finite")
                }
                packed.append(quantizeGaussianSHCoefficient(value))
            }
        }
    }

    return PackedGaussianSphericalHarmonics(
        coefficients: packed,
        metadata: GaussianSHMetadata(
            degree: UInt32(sphericalHarmonics.degree),
            coefficientsPerChannel: UInt32(coefficientsPerChannel),
            higherOrderCoefficientsPerSplat: UInt32(outputPerSplat),
            _pad0: 0
        )
    )
}

private func encodeGaussianSplatForTBDR(_ splat: GaussianSplat) -> EncodedGaussianSplat {
    let scale = simd_float3(splat.scale.x, splat.scale.y, splat.scale.z)
    let rotation = simd_quatf(
        ix: splat.quat.y,
        iy: splat.quat.z,
        iz: splat.quat.w,
        r: splat.quat.x
    ).normalized
    let transform = simd_float3x3(rotation) * simd_float3x3(diagonal: scale)
    let covariance = transform * transform.transpose

    return EncodedGaussianSplat(
        position: simd_float3(splat.center.x, splat.center.y, splat.center.z),
        covA: simd_half3(Float16(covariance[0, 0]), Float16(covariance[0, 1]), Float16(covariance[0, 2])),
        covB: simd_half3(Float16(covariance[1, 1]), Float16(covariance[1, 2]), Float16(covariance[2, 2])),
        colorAndOpacity: simd_half4(
            Float16(splat.color.x), Float16(splat.color.y), Float16(splat.color.z), Float16(splat.opacity)
        )
    )
}

// MARK: Static Batching

public func setEntityPickParticipation(entityId: EntityID, enabled: Bool) {
    withWorldMutationGate {
        if scene.get(component: PickInteractionComponent.self, for: entityId) == nil {
            registerComponent(entityId: entityId, componentType: PickInteractionComponent.self)
        }

        guard let pickInteractionComponent = scene.get(component: PickInteractionComponent.self, for: entityId) else {
            return
        }

        pickInteractionComponent.participatesInPicking = enabled
        scenePickingMarkEntityDirty(entityId)
    }
}

public func getEntityPickParticipation(entityId: EntityID) -> Bool {
    scene.get(component: PickInteractionComponent.self, for: entityId)?.participatesInPicking ?? true
}

public func setEntityPickHitRepresentationMode(entityId: EntityID, mode: PickHitRepresentationMode) {
    withWorldMutationGate {
        if scene.get(component: PickInteractionComponent.self, for: entityId) == nil {
            registerComponent(entityId: entityId, componentType: PickInteractionComponent.self)
        }

        guard let pickInteractionComponent = scene.get(component: PickInteractionComponent.self, for: entityId) else {
            return
        }

        pickInteractionComponent.hitRepresentationMode = mode
        scenePickingMarkEntityDirty(entityId)
    }
}

public func getEntityPickHitRepresentationMode(entityId: EntityID) -> PickHitRepresentationMode {
    scene.get(component: PickInteractionComponent.self, for: entityId)?.hitRepresentationMode ?? .mesh
}

/// Marks every eligible renderable in an entity hierarchy as static-batchable.
///
/// Use this for imported models whose root entity may not render geometry directly.
public func setEntityStaticBatchHierarchy(entityId: EntityID) {
    // XR can render from a dedicated thread while scene data is being mutated here.
    // Gate rendering while we recursively tag the hierarchy as static-batchable.
    withWorldMutationGate {
        setEntityStaticBatchComponentRecursive(entityId: entityId)
    }
}

/// Backward-compatible name for `setEntityStaticBatchHierarchy(entityId:)`.
public func setEntityStaticBatchComponent(entityId: EntityID) {
    setEntityStaticBatchHierarchy(entityId: entityId)
}

/// Same behavior as `setEntityStaticBatchHierarchy(entityId:)`, but assumes the caller is
/// already inside a world-mutation critical section and must not re-open the render gate.
public func setEntityStaticBatchComponentUngated(entityId: EntityID) {
    setEntityStaticBatchComponentRecursive(entityId: entityId)
}

private func setEntityStaticBatchComponentRecursive(entityId: EntityID) {
    // Apply to entities with RenderComponent (fully loaded) OR StreamingComponent
    // (out-of-core stubs that have no RenderComponent yet).  The batching residency
    // handler (handleResidencyChange) checks for StaticBatchComponent when a stub
    // becomes GPU-resident, so it must be tagged before the RenderComponent arrives.
    let hasRender = scene.get(component: RenderComponent.self, for: entityId) != nil
    let hasStreaming = scene.get(component: StreamingComponent.self, for: entityId) != nil
    if hasRender || hasStreaming, !shouldPreserveSceneEntityIdentity(entityId: entityId) {
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

/// Internal cleanup function for entity destruction (non-recursive, called per entity)
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

func removeEntityGaussianLOD(entityId: EntityID) {
    if let lodComponent = scene.get(component: GaussianLODComponent.self, for: entityId) {
        lodComponent.releaseAllLevelResources()
        lodComponent.lodLevels.removeAll()
        scene.remove(component: GaussianLODComponent.self, from: entityId)
    }
}

func removeEntityGaussian(entityId: EntityID) {
    if let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) {
        // Release Metal buffers
        gaussianComponent.encodedSplatData = nil
        gaussianComponent.sphericalHarmonicsData = nil
        gaussianComponent.sphericalHarmonicsMetadata = nil
        gaussianComponent.gaussianSortedIndices.removeAll()
        gaussianComponent.gaussianVisibleIndices.removeAll()
        gaussianComponent.gaussianVisibleCount.removeAll()
        gaussianComponent.gaussianPrecomputedData.removeAll()
        gaussianComponent.visibleSplatCountForRendering = 0
        gaussianComponent.spaceUniform.removeAll()
        scene.remove(component: GaussianComponent.self, from: entityId)
        // Idempotent — safe to call again if `unloadGaussian` already unregistered this
        // entity as part of a streaming unload. Keeps MemoryBudgetManager's ledger accurate
        // for entities destroyed directly (e.g. a non-streamed setEntityGaussian caller).
        MemoryBudgetManager.shared.unregisterMesh(entityId: entityId)
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

func removeTileComponent(entityId: EntityID) {
    if let tileComp = scene.get(component: TileComponent.self, for: entityId) {
        // Cancel any in-flight parse task so it does not complete into a destroyed entity.
        tileComp.loadTask?.cancel()
        tileComp.loadTask = nil
        scene.remove(component: TileComponent.self, from: entityId)
    }
    // Remove stale IDs from all tile tracking sets so the streaming system
    // does not act on entity IDs that no longer exist in the scene.
    GeometryStreamingSystem.shared.unregisterTileEntity(entityId)
}

func removeEntityGizmo(entityId: EntityID) {
    if scene.get(component: GizmoComponent.self, for: entityId) != nil {
        scene.remove(component: GizmoComponent.self, from: entityId)
    }
}

func removeEntityPickInteraction(entityId: EntityID) {
    if scene.get(component: PickInteractionComponent.self, for: entityId) != nil {
        scene.remove(component: PickInteractionComponent.self, from: entityId)
        scenePickingMarkEntityDirty(entityId)
    }
}

func removeEntitySceneChannels(entityId: EntityID) {
    if scene.get(component: EntitySceneChannelsComponent.self, for: entityId) != nil {
        scene.remove(component: EntitySceneChannelsComponent.self, from: entityId)
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
    let completionBox = completion.map { BoolCompletionBox(callback: $0) }

    Task {
        // Check if LODComponent exists
        guard hasComponent(entityId: entityId, componentType: LODComponent.self) else {
            handleError(.componentNotFound, "LODComponent", entityId)
            completionBox?.call(false)
            return
        }

        // Get file URL using standard resource loading
        guard let url = LoadingSystem.shared.resourceURL(forResource: fileName, withExtension: withExtension) else {
            handleError(.filenameNotFound, "\(fileName).\(withExtension)")
            completionBox?.call(false)
            return
        }

        // Load meshes for this LOD
        guard let runtimeAsset = try? NativeFormatLoader().loadAssetSync(from: url) else {
            completionBox?.call(false)
            return
        }
        var meshes: [Mesh] = runtimeAsset.nodes
            .filter { !$0.primitives.isEmpty }
            .flatMap { makeMeshes(from: $0) }

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

        let didAddLOD: Bool = withWorldMutationGate {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
                handleError(.componentNotFound, "LODComponent")
                return false
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
            return true
        }
        completionBox?.call(didAddLOD)
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
    let completionBox = completion.map { BoolCompletionBox(callback: $0) }

    Task {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else {
            Logger.logWarning(message: "Entity does not have LODComponent")
            completionBox?.call(false)
            return
        }

        // Validate index
        guard lodIndex >= 0, lodIndex < lodComponent.lodLevels.count else {
            Logger.logWarning(message: "Invalid LOD index: \(lodIndex)")
            completionBox?.call(false)
            return
        }

        // Get file URL using standard resource loading
        guard let newURL = LoadingSystem.shared.resourceURL(forResource: fileName, withExtension: withExtension) else {
            handleError(.filenameNotFound, "\(fileName).\(withExtension)")
            completionBox?.call(false)
            return
        }

        // Load new meshes
        guard let runtimeAsset2 = try? NativeFormatLoader().loadAssetSync(from: newURL) else {
            completionBox?.call(false)
            return
        }
        var meshes: [Mesh] = runtimeAsset2.nodes
            .filter { !$0.primitives.isEmpty }
            .flatMap { makeMeshes(from: $0) }

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

        let didReplaceLOD: Bool = withWorldMutationGate {
            guard let currentLODComponent = scene.get(component: LODComponent.self, for: entityId) else {
                Logger.logWarning(message: "Entity does not have LODComponent")
                return false
            }

            guard lodIndex >= 0, lodIndex < currentLODComponent.lodLevels.count else {
                Logger.logWarning(message: "Invalid LOD index: \(lodIndex)")
                return false
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
            return true
        }
        completionBox?.call(didReplaceLOD)
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

/// Geometry Streaming
/// Internal — sets StreamingComponent radii on tile-owned child entities after a tile loads.
/// Not part of the public API: streaming radii are declared in the scene manifest.
/// Kept internal so the tile streaming system and tests can call it; external callers should
/// declare radii in the manifest instead.
func enableStreaming(
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

        // No direct RenderComponent — check children.
        // Handles both loaded multi-mesh assets (children have RenderComponent) and
        // out-of-core stub assets (children have StreamingComponent but no RenderComponent yet).
        if let sceneGraph = scene.get(component: ScenegraphComponent.self, for: entityId),
           !sceneGraph.children.isEmpty
        {
            var enabledCount = 0
            for childId in sceneGraph.children {
                let hasRender = scene.get(component: RenderComponent.self, for: childId) != nil
                let hasStreaming = scene.get(component: StreamingComponent.self, for: childId) != nil
                if hasRender || hasStreaming {
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
                Logger.logWarning(message: "Cannot enable streaming: entity \(entityId) has no children with RenderComponent or StreamingComponent")
            }
            return
        }

        Logger.logWarning(message: "Cannot enable streaming: entity \(entityId) has no RenderComponent")
    }
}

/// Internal helper to enable streaming on a single entity.
/// Handles two cases:
///   - Loaded entity (has RenderComponent): state stays `.loaded`, registered as loaded.
///   - Out-of-core stub (StreamingComponent only, no RenderComponent): state stays `.unloaded`,
///     only the radii are updated so GeometryStreamingSystem can start distance checks.
private func enableStreamingForSingleEntity(
    entityId: EntityID,
    streamingRadius: Float,
    unloadRadius: Float,
    priority: Int
) {
    // Out-of-core stub path: entity has a StreamingComponent from stub registration
    // but no RenderComponent yet. Just update the radii — the streaming system will
    // upload the mesh from the CPU registry when the entity enters streamingRadius.
    if let streaming = scene.get(component: StreamingComponent.self, for: entityId),
       scene.get(component: RenderComponent.self, for: entityId) == nil
    {
        streaming.streamingRadius = streamingRadius
        streaming.unloadRadius = unloadRadius
        streaming.priority = priority
        // State remains .unloaded — GeometryStreamingSystem drives the first upload.
        return
    }

    guard let render = scene.get(component: RenderComponent.self, for: entityId) else {
        return
    }

    // Register streaming component only if not already present.
    // scene.assign() always calls typedPointer.initialize(to: T()), which resets an
    // existing StreamingComponent to its default .unloaded state. If a progressive-load
    // child entity already has a .loaded StreamingComponent (added by
    // registerProgressiveChildEntity), calling registerComponent again would briefly
    // set it to .unloaded — creating a race with GeometryStreamingSystem.update() on
    // the compositor render thread, which would see the .unloaded state and immediately
    // queue a full reload of the USDZ file.
    if scene.get(component: StreamingComponent.self, for: entityId) == nil {
        registerComponent(entityId: entityId, componentType: StreamingComponent.self)
    }

    guard let streaming = scene.get(component: StreamingComponent.self, for: entityId) else {
        return
    }

    // Extract filename info from the render component's URL
    let url = render.assetURL
    streaming.assetFilename = url.deletingPathExtension().lastPathComponent
    streaming.assetExtension = url.pathExtension
    streaming.assetName = render.assetName

    streaming.streamingRadius = streamingRadius
    streaming.unloadRadius = unloadRadius
    streaming.priority = priority
    streaming.state = .loaded // Already has mesh

    // Register with streaming system for eviction tracking
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
