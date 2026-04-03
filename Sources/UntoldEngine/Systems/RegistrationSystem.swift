
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
import ModelIO

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
    var skeletonCache: [URL: MDLSkeleton?] = [:]
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

    ComponentRegistry.register(componentType: TileComponent.self, handlerId: "tile", priority: 30) { entityId in
        removeTileComponent(entityId: entityId)
    }

    ComponentRegistry.register(componentType: TileLODTagComponent.self, handlerId: "tileLODTag", priority: 30) { entityId in
        scene.remove(component: TileLODTagComponent.self, from: entityId)
    }

    ComponentRegistry.register(componentType: GizmoComponent.self, handlerId: "gizmo", priority: 30) { entityId in
        removeEntityGizmo(entityId: entityId)
    }

    ComponentRegistry.register(componentType: PickInteractionComponent.self, handlerId: "pickInteraction", priority: 30) { entityId in
        removeEntityPickInteraction(entityId: entityId)
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

private func detectImportedLODGroups(from meshGroups: [[Mesh]]) -> [ImportedLODGroupCandidate]? {
    var meshesBySourceName: [String: [Mesh]] = [:]

    for meshGroup in meshGroups {
        let groupedBySourceName = splitMeshGroupBySourceName(meshGroup)
        for (sourceName, sourceMeshes) in groupedBySourceName {
            meshesBySourceName[sourceName, default: []].append(contentsOf: sourceMeshes)
        }
    }

    let detectionResult = detectImportedLODGroups(fromSourceNames: Array(meshesBySourceName.keys))
    if !detectionResult.ambiguousBaseNames.isEmpty {
        let baseNames = detectionResult.ambiguousBaseNames.sorted().joined(separator: ", ")
        Logger.logWarning(message: "Ambiguous imported LOD groups skipped: \(baseNames)")
    }

    var detectedGroups: [ImportedLODGroupCandidate] = []
    detectedGroups.reserveCapacity(detectionResult.groups.count)

    for group in detectionResult.groups {
        if group.levels.contains(where: { $0.lodIndex == 0 }) == false {
            Logger.logWarning(message: "Imported LOD group '\(group.baseName)' is missing LOD0.")
        }

        let missingIndices = missingLODIndices(for: group.levels)
        if !missingIndices.isEmpty {
            let indices = missingIndices.map(String.init).joined(separator: ", ")
            Logger.logWarning(message: "Imported LOD group '\(group.baseName)' has sparse levels. Missing: \(indices)")
        }

        var meshLevels: [ImportedLODLevelCandidate] = []
        meshLevels.reserveCapacity(group.levels.count)

        for level in group.levels {
            guard let sourceMeshes = meshesBySourceName[level.sourceName], !sourceMeshes.isEmpty else {
                continue
            }
            meshLevels.append(
                ImportedLODLevelCandidate(
                    lodIndex: level.lodIndex,
                    sourceName: level.sourceName,
                    meshes: sourceMeshes
                )
            )
        }

        guard meshLevels.count >= 2 else {
            continue
        }

        detectedGroups.append(
            ImportedLODGroupCandidate(
                baseName: group.baseName,
                levels: meshLevels.sorted { $0.lodIndex < $1.lodIndex }
            )
        )
    }

    guard !detectedGroups.isEmpty else {
        return nil
    }

    return detectedGroups.sorted { $0.baseName < $1.baseName }
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
    }
}

private func applyImportedTransformFromMeshGroup(_ meshGroup: [Mesh], to entityId: EntityID) {
    guard let firstMesh = meshGroup.first else {
        return
    }
    applyWorldTransform(firstMesh.worldSpace, to: entityId)
}

@discardableResult
private func tryRegisterImportedLODGroup(
    entityId: EntityID,
    url: URL,
    filename: String,
    withExtension: String,
    nonEmptyMeshes: [[Mesh]]
) -> Bool {
    guard let importedLODGroups = detectImportedLODGroups(from: nonEmptyMeshes) else {
        return false
    }

    if importedLODGroups.count == 1, let importedLOD = importedLODGroups.first {
        let lodLevels = buildImportedLODLevels(from: importedLOD, url: url)
        guard let activeLODIndex = lodLevels.firstIndex(where: { !$0.mesh.isEmpty }) else {
            return false
        }

        if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
            registerTransformComponent(entityId: entityId)
        }

        if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
            registerSceneGraphComponent(entityId: entityId)
        }

        let activeLOD = lodLevels[activeLODIndex]
        let activeAssetName = activeLOD.assetName ?? importedLOD.baseName
        associateMeshesToEntity(entityId: entityId, meshes: activeLOD.mesh)
        registerRenderComponent(entityId: entityId, meshes: activeLOD.mesh, url: url, assetName: activeAssetName)
        configureLODComponent(entityId: entityId, lodLevels: lodLevels, activeLODIndex: activeLODIndex)

        setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
        Logger.log(message: "✅ Auto-detected imported LOD group '\(importedLOD.baseName)' with \(importedLOD.levels.count) levels")
        return true
    }

    // Multiple LOD families in one USDZ: create asset root + one child entity per base group.
    let assetInstanceComp = AssetInstanceComponent(
        assetURL: url,
        assetName: filename,
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

    var createdChildren = 0

    for (index, importedLOD) in importedLODGroups.enumerated() {
        let lodLevels = buildImportedLODLevels(from: importedLOD, url: url)
        guard let activeLODIndex = lodLevels.firstIndex(where: { !$0.mesh.isEmpty }) else {
            continue
        }

        let childEntityId = createEntity()
        if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
            registerTransformComponent(entityId: childEntityId)
        }
        if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
            registerSceneGraphComponent(entityId: childEntityId)
        }

        let activeLOD = lodLevels[activeLODIndex]
        applyImportedTransformFromMeshGroup(activeLOD.mesh, to: childEntityId)
        let activeAssetName = activeLOD.assetName ?? importedLOD.baseName
        associateMeshesToEntity(entityId: childEntityId, meshes: activeLOD.mesh)
        registerRenderComponent(entityId: childEntityId, meshes: activeLOD.mesh, url: url, assetName: activeAssetName)
        configureLODComponent(entityId: childEntityId, lodLevels: lodLevels, activeLODIndex: activeLODIndex)

        setEntityName(entityId: childEntityId, name: importedLOD.baseName)
        setParent(childId: childEntityId, parentId: entityId)

        let nodePath = generateStableNodePath(assetName: importedLOD.baseName, index: index)
        let derivedComp = DerivedAssetNodeComponent(assetRootEntityId: entityId, nodePath: nodePath)
        registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
        if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
            derived.assetRootEntityId = derivedComp.assetRootEntityId
            derived.nodePath = derivedComp.nodePath
        }

        setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)
        createdChildren += 1
    }

    guard createdChildren > 0 else {
        return false
    }

    Logger.log(message: "✅ Auto-detected imported LOD groups: \(createdChildren) entities created from \(importedLODGroups.count) LOD families")
    return true
}

private func setEntityMeshCommon(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    flip _: Bool,
    meshLoader: (URL) -> [[Mesh]],
    entityName _: String?,
    assetName: String?
) -> Bool {
    guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
        handleError(.filenameNotFound, filename)
        return false
    }

    if url.pathExtension == "dae" {
        handleError(.fileTypeNotSupported, url.pathExtension)
        return false
    }

    let meshes = meshLoader(url)
    let supportsSkeletons = RuntimeAssetSource.infer(from: url).kind != .untold

    // Cache meshes for streaming system (so reloads don't require disk I/O)
    MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

    if meshes.isEmpty {
        handleError(.assetDataMissing, filename)
        return false
    }

    var nonEmptyMeshes = meshes.filter { !$0.isEmpty }

    if let assetNameExist = assetName {
        if let matchedMesh = nonEmptyMeshes.first(where: { $0.first?.assetName == assetNameExist }) {
            nonEmptyMeshes = [matchedMesh]
        } else {
            handleError(.assetDataMissing, "No mesh with asset name \(assetNameExist)")
            return false
        }
    }

    if tryRegisterImportedLODGroup(
        entityId: entityId,
        url: url,
        filename: filename,
        withExtension: withExtension,
        nonEmptyMeshes: nonEmptyMeshes
    ) {
        return true
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
        if supportsSkeletons {
            setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
        }

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

            // Extract full transform (translation, rotation, scale) from mesh world space
            // before RenderComponent registration.
            if let firstMesh = mesh.first {
                applyWorldTransform(firstMesh.worldSpace, to: childEntityId)
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
            if supportsSkeletons {
                setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)
            }
        }
    }

    return true
}

private func loadUntoldMeshGroups(url: URL, device: MTLDevice) -> [[Mesh]] {
    do {
        let runtimeAsset = try UntoldRuntimeAssetLoader().loadAssetSync(from: url)
        return Mesh.makeMeshGroups(from: runtimeAsset, device: device)
    } catch {
        Logger.logError(message: "[Untold] Failed to load runtime asset '\(url.lastPathComponent)': \(error)")
        return []
    }
}

/// Generate a stable node path for a derived mesh node
func generateStableNodePath(assetName: String, index: Int) -> String {
    // Use a deterministic format: "Root/<AssetName>#<Index>"
    // This ensures the same USDZ file produces the same nodePath each time
    "Root/\(assetName)#\(index)"
}

/// Register one MDLMesh leaf as an out-of-core stub entity.
///
/// Creates the full ECS presence (transform, scenegraph, streaming component) with NO GPU
/// allocation. The `StreamingComponent` starts in `.unloaded` state with placeholder
/// radii (`Float.greatestFiniteMagnitude`) so the streaming system ignores the entity
/// until `enableStreaming()` is called and real radii are set.
///
/// **Must be called from within an existing `withWorldMutationGate` block.**
/// The caller (setEntityMeshAsync) wraps the entire stub-registration loop in a single gate
/// acquisition rather than one gate per stub, avoiding N × acquire/release overhead for
/// assets with hundreds of mesh leaves.
///
/// The caller is responsible for storing the MDLMesh in `ProgressiveAssetLoader.cpuMeshRegistry`
/// so `GeometryStreamingSystem.loadMeshAsync` can upload it from CPU when the entity enters range.
///
/// - Returns: The newly created child `EntityID`.
@discardableResult
func registerProgressiveStubEntity(
    mdlObject: MDLObject,
    index: Int,
    uniqueAssetName: String,
    rootEntityId: EntityID,
    url _: URL,
    filename: String,
    withExtension ext: String
) -> EntityID {
    let childEntityId = createEntity()

    if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
        registerTransformComponent(entityId: childEntityId)
    }

    if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
        registerSceneGraphComponent(entityId: childEntityId)
    }

    // Set world position from the MDLObject's composed transform.
    // This is what the octree and distance calculations will use.
    let worldTransform = composedWorldTransform(for: mdlObject)
    applyWorldTransform(worldTransform, to: childEntityId)

    // Seed the bounding box from the MDLMesh so OctreeSystem and calculateDistance
    // compute meaningful spatial extents even before the RenderComponent exists.
    if let mdlMesh = mdlObject as? MDLMesh,
       let local = scene.get(component: LocalTransformComponent.self, for: childEntityId)
    {
        local.boundingBox = (min: mdlMesh.boundingBox.minBounds, max: mdlMesh.boundingBox.maxBounds)
    }

    setEntityName(entityId: childEntityId, name: uniqueAssetName)
    setParent(childId: childEntityId, parentId: rootEntityId)

    // Stable identity for serialisation / scene graph lookup.
    let nodePath = generateStableNodePath(assetName: uniqueAssetName, index: index)
    registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
    if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
        derived.assetRootEntityId = rootEntityId
        derived.nodePath = nodePath
    }

    // StreamingComponent in .unloaded state — GPU resources will be created by
    // GeometryStreamingSystem when the entity enters streamingRadius.
    registerComponent(entityId: childEntityId, componentType: StreamingComponent.self)
    if let sc = scene.get(component: StreamingComponent.self, for: childEntityId) {
        sc.assetFilename = filename
        sc.assetExtension = ext
        sc.assetName = uniqueAssetName
        sc.state = .unloaded
        // Large placeholder radii: enableStreaming() sets the real values.
        // This prevents the streaming system from immediately queueing a disk-based
        // reload before the out-of-core CPU registry entry is in place.
        sc.streamingRadius = Float.greatestFiniteMagnitude
        sc.unloadRadius = Float.greatestFiniteMagnitude
    }

    // Register with the octree so update() spatial queries can find this stub.
    OctreeSystem.shared.registerEntity(childEntityId)

    return childEntityId
}

/// Synchronously load and set an entity mesh on the calling thread.
///
/// This API always uses the **immediate** path: all Metal resources are created in a single
/// pass before the function returns. It does not support out-of-core stub registration or
/// distance-based streaming — the mesh is permanently GPU-resident after this call.
///
/// For large assets or any asset that should benefit from distance-based streaming and
/// eviction, use `setEntityMeshAsync(streamingPolicy:)` instead.
public func setEntityMesh(entityId: EntityID, filename: String, withExtension: String, assetName: String? = nil, flip: Bool = true, coordinateConversion: CoordinateSystemConversion = .autoDetect) {
    _ = setEntityMeshCommon(
        entityId: entityId,
        filename: filename,
        withExtension: withExtension,
        flip: flip,
        meshLoader: { url in
            if RuntimeAssetSource.infer(from: url).kind == .untold {
                return loadUntoldMeshGroups(url: url, device: renderInfo.device)
            }

            return Mesh.loadSceneMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, coordinateConversion: coordinateConversion)
        },
        entityName: nil,
        assetName: assetName
    )
}

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

/// Asynchronously load and set entity mesh without blocking the main thread
public func setEntityMeshAsync(
    entityId: EntityID,
    filename: String,
    withExtension: String,
    assetName: String? = nil,
    flip _: Bool = true,
    coordinateConversion: CoordinateSystemConversion = .autoDetect,
    streamingPolicy: MeshStreamingPolicy = .auto,
    blockRenderLoop: Bool = true,
    completion: ((Bool) -> Void)? = nil
) {
    let completionBox = completion.map { BoolCompletionBox(callback: $0) }

    Task {
        // Mark as loading.  Secondary assets (LOD levels, HLODs) pass blockRenderLoop:false —
        // the gate is opened and immediately closed so the render loop is never stalled
        // waiting for supplementary geometry.  All downstream finishLoading calls are
        // idempotent no-ops once the entity is already removed from the loading set.
        await AssetLoadingState.shared.startLoading(entityId: entityId, filename: filename)
        if !blockRenderLoop {
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
        }

        // Ensure entity has required components while loading gate is active.
        if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
            registerTransformComponent(entityId: entityId)
        }

        if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
            registerSceneGraphComponent(entityId: entityId)
        }

        // Get URL
        guard let url = LoadingSystem.shared.resourceURL(forResource: filename, withExtension: withExtension, subResource: nil) else {
            handleError(.filenameNotFound, filename)
            loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(false)
            return
        }

        if url.pathExtension == "dae" {
            handleError(.fileTypeNotSupported, url.pathExtension)
            loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(false)
            return
        }

        if RuntimeAssetSource.infer(from: url).kind == .untold {
            if streamingPolicy != .immediate {
                Logger.logWarning(message: "[Untold] '.untold' assets currently use the immediate full-load path. Ignoring streaming policy '\(streamingPolicy)'.")
            }

            let didLoad = setEntityMeshCommon(
                entityId: entityId,
                filename: filename,
                withExtension: withExtension,
                flip: true,
                meshLoader: { loadUntoldMeshGroups(url: $0, device: renderInfo.device) },
                entityName: nil,
                assetName: assetName
            )

            if !didLoad {
                loadFallbackMesh(entityId: entityId, filename: filename)
            }

            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(didLoad)
            return
        }

        // MARK: Out-of-core / small-file routing

        // All assets parse with a CPU-only allocator to avoid the GPU memory spike caused
        // by MTKMeshBufferAllocator pre-allocating Metal buffers for the entire scene.
        //
        // Two-stage admission gate (V1):
        //   Stage 1 (pre-parse):  coarse file-size × expansion multiplier check — rejects
        //                         obviously unsafe assets before Model I/O touches the file.
        //   Stage 2 (post-parse): accurate profiler-based check after parse completes —
        //                         the final authority. Note: Stage 2 cannot prevent the
        //                         parse-time RAM spike; it prevents all downstream work
        //                         (stub registration, MDLAsset retention, CPU registry storage).
        //
        // If both gates pass, large assets register every leaf mesh immediately as a stub
        // entity (zero-GPU). CPU-side MDLMesh data is stored in ProgressiveAssetLoader so
        // GeometryStreamingSystem can upload each stub on demand without a disk re-read.
        // Small assets create all Metal resources right here in a single pass.
        if assetName == nil {
            // ── Stage 1: Pre-parse admission gate ─────────────────────────────────────
            // Compute file size before parseAssetAsync so the gate fires before Model I/O
            // allocates CPU heap for all mesh buffers.
            //
            // Expansion factor: 20× — conservative upper bound for USDZ geometry
            //   decompression. Real-world worst case is ~55× (a 159 MB city USDZ
            //   expanding to ~8858 MB of geometry). 20× catches obvious outliers without
            //   rejecting normal-sized files.
            //
            // Three-zone model:
            //   Safe zone     projectedCPU ≤ 50% RAM  — allow, no log
            //   Soft zone     projectedCPU  > 50% AND < 75% RAM
            //                 → log warning, allow parse, delegate to Stage 2
            //                 → expected for texture-heavy USDZs: compressed texture bytes
            //                   in a USDZ do not expand at parse time (MDLMeshBufferData-
            //                   Allocator only decompresses geometry; textures are decoded
            //                   lazily at first-upload time via ensureTexturesLoaded).
            //                   Stage 2 is the accurate authority for these borderline cases.
            //   Hard reject   projectedCPU ≥ 75% RAM  — reject before parse, load fallback
            //                 → geometry expansion of this magnitude would risk an OOM kill
            //                   before Stage 2 can even run.
            //
            // Known gap: the assetName != nil path (Mesh.loadSceneMeshesAsync) is not
            // guarded. That path is only used for named-mesh lookups and is not expected
            // to be called with large assets in normal production use.
            //
            // Future refinement: a lightweight USDZ ZIP central-directory scan could
            // separate texture-entry bytes from scene-entry bytes before parsing and apply
            // the 20× multiplier only to the scene portion, eliminating soft-zone false
            // positives for texture-heavy assets entirely. Validate the soft-zone model
            // on real assets before adding that complexity.
            let fileSizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
            if fileSizeBytes > 0 {
                let physicalMemory = Int(ProcessInfo.processInfo.physicalMemory)
                let softZoneThreshold = Int(Double(physicalMemory) * 0.50) // soft zone starts here
                let hardRejectThreshold = Int(Double(physicalMemory) * 0.75) // hard reject at or above
                let projectedCPUBytes = fileSizeBytes * 20

                let fileMB = String(format: "%.1f", Double(fileSizeBytes) / 1_048_576)
                let projGB = String(format: "%.1f", Double(projectedCPUBytes) / 1_073_741_824)
                let ramGB = String(format: "%.1f", Double(physicalMemory) / 1_073_741_824)

                if projectedCPUBytes >= hardRejectThreshold {
                    let thrGB = String(format: "%.1f", Double(hardRejectThreshold) / 1_073_741_824)
                    Logger.logError(message: "[AdmissionGate] Stage 1 HARD REJECT '\(filename)' — File: \(fileMB) MB | Expansion: 20× | Projected CPU: ~\(projGB) GB | Hard-reject threshold: \(thrGB) GB (75% of \(ramGB) GB RAM). Asset too large to parse safely on this device. Use a lower-polygon asset or split into smaller files.")
                    loadFallbackMesh(entityId: entityId, filename: filename)
                    await AssetLoadingState.shared.finishLoading(entityId: entityId)
                    completionBox?.call(false)
                    return
                } else if projectedCPUBytes > softZoneThreshold {
                    let softGB = String(format: "%.1f", Double(softZoneThreshold) / 1_073_741_824)
                    Logger.logWarning(message: "[AdmissionGate] Stage 1 SOFT ZONE '\(filename)' — File: \(fileMB) MB | Expansion: 20× | Projected CPU: ~\(projGB) GB | Soft threshold: \(softGB) GB (50% of \(ramGB) GB RAM). Parse will proceed; Stage 2 is the authoritative gate. Typical for texture-heavy assets whose compressed texture bytes do not expand at parse time.")
                    // Fall through — parse proceeds. Stage 2 is the accurate authority.
                }
                // else: safe zone (projectedCPU ≤ softZoneThreshold) — allow, no log.
            }

            guard let assetData = await Mesh.parseAssetAsync(
                url: url,
                vertexDescriptor: vertexDescriptor.model,
                device: renderInfo.device,
                coordinateConversion: coordinateConversion
            ) else {
                handleError(.assetDataMissing, filename)
                loadFallbackMesh(entityId: entityId, filename: filename)
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(false)
                return
            }

            // ── Stage 2: Post-parse accurate admission gate ───────────────────────────
            // AssetProfiler measures actual geometry + texture byte estimates from the
            // parsed MDLMesh objects. This is the accurate gate; Stage 1 (pre-parse) is
            // only a coarse early filter.
            //
            // IMPORTANT: by the time this check runs, parseAssetAsync() has already
            // allocated CPU heap for all MDLMesh buffers. This gate cannot prevent the
            // parse-time RAM spike. What it prevents is all downstream work:
            //   - stub registration (no ECS entities created),
            //   - MDLAsset retention in rootAssetRefs (no CPU RAM kept permanently),
            //   - CPU registry storage in ProgressiveAssetLoader.
            // When the gate fires, assetData goes out of scope and ARC releases the
            // parsed MDLMesh buffers, recovering the RAM that the parse consumed.
            //
            // The profile is computed regardless of streamingPolicy so all three policy
            // modes (.auto, .outOfCore, .immediate) are subject to the same gate.
            let assetProfile = AssetProfiler.profile(url: url, assetData: assetData, fileSizeBytes: fileSizeBytes)
            let postParsePhysicalMemory = Int(ProcessInfo.processInfo.physicalMemory)
            let postParseSafetyThreshold = Int(Double(postParsePhysicalMemory) * 0.75)
            if assetProfile.estimatedGeometryBytes > postParseSafetyThreshold {
                let geoGB = String(format: "%.1f", Double(assetProfile.estimatedGeometryBytes) / 1_073_741_824)
                let thrGB = String(format: "%.1f", Double(postParseSafetyThreshold) / 1_073_741_824)
                let ramGB = String(format: "%.1f", Double(postParsePhysicalMemory) / 1_073_741_824)
                let fileMBStr = String(format: "%.1f", Double(fileSizeBytes) / 1_048_576)
                Logger.logError(message: "[AdmissionGate] Stage 2 HARD REJECT '\(filename)' — File: \(fileMBStr) MB | Profiled geometry: ~\(geoGB) GB | Threshold: \(thrGB) GB (75% of \(ramGB) GB RAM). Stub registration and CPU registry storage are skipped; the parsed MDLAsset will be released by ARC. Fallback mesh assigned.")
                // Load fallback so the entity is visually stable — the scene shows a
                // placeholder cube rather than an invisible, mesh-less entity.
                loadFallbackMesh(entityId: entityId, filename: filename)
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(false)
                return
            }

            // Resolve the effective loading policy from the caller's streamingPolicy.
            //
            // For .auto, AssetProfiler classifies the already-computed assetProfile
            // against the live platform memory budget to select independent geometry
            // and texture residency policies.
            //
            // For .outOfCore / .immediate, the caller's intent is mapped directly to the
            // policy types for a clean internal representation.
            let loadingPolicy: AssetLoadingPolicy
            let outOfCoreReason: String?
            switch streamingPolicy {
            case .outOfCore:
                loadingPolicy = .geometryStreaming
                outOfCoreReason = "explicit .outOfCore policy"
            case .immediate:
                loadingPolicy = .fullLoad
                outOfCoreReason = nil
            case .auto:
                let budget = MemoryBudgetManager.shared.meshBudget
                loadingPolicy = AssetProfiler.classifyPolicy(profile: assetProfile, budget: budget)

                let fileMB = String(format: "%.1f", Double(fileSizeBytes) / 1_048_576)
                let geoMB = String(format: "%.1f", Double(assetProfile.estimatedGeometryBytes) / 1_048_576)
                let texMB = String(format: "%.1f", Double(assetProfile.estimatedTextureBytes) / 1_048_576)
                let budgetMB = String(format: "%.0f", Double(budget) / 1_048_576)
                Logger.log(message: "[AssetProfiler] '\(filename)' (\(fileMB) MB) → \(assetProfile.assetCharacter.rawValue) | geo ~\(geoMB) MB, tex ~\(texMB) MB | budget: \(budgetMB) MB | meshes: \(assetProfile.meshCount)")
                Logger.log(message: "[AssetProfiler] Policy → geometry: \(loadingPolicy.geometryPolicy.rawValue), texture: \(loadingPolicy.texturePolicy.rawValue) (source: \(loadingPolicy.source.rawValue))")

                if loadingPolicy.geometryPolicy == .streaming {
                    outOfCoreReason = "\(assetProfile.assetCharacter.rawValue) asset, geo ~\(geoMB) MB on \(budgetMB) MB budget"
                } else {
                    outOfCoreReason = nil
                }
            }

            // Detect LOD groups before choosing the loading path.
            let topLevelNames = assetData.topLevelObjects.map {
                ($0 as? MDLMesh)?.parent?.name ?? $0.name
            }
            let lodNameDetection = detectImportedLODGroups(fromSourceNames: topLevelNames)
            let hasLODGroups = !lodNameDetection.groups.isEmpty
            let useOutOfCore = loadingPolicy.geometryPolicy == .streaming

            if useOutOfCore, hasLODGroups {
                // LOD + OUT-OF-CORE PATH ────────────────────────────────────────────────
                // Each LOD group becomes ONE entity with a LODComponent whose levels are
                // stub LODLevels (empty mesh, .notResident). CPU-side MDLObject data for
                // each level is stored in ProgressiveAssetLoader.cpuLODRegistry so
                // GeometryStreamingSystem can upload only the active LOD level from RAM
                // when the entity enters streaming range — no disk re-read required.
                Logger.log(
                    message: "[OutOfCore] '\(filename)': LOD asset with \(lodNameDetection.groups.count) group(s) — LOD+OOC stub registration (\(assetData.totalObjectCount) objects)",
                    category: LogCategory.oocStatus.rawValue
                )

                // Build name→MDLObject map using the same naming formula as topLevelNames.
                var nameToObject: [String: MDLObject] = [:]
                for obj in assetData.topLevelObjects {
                    let name = (obj as? MDLMesh)?.parent?.name ?? obj.name
                    nameToObject[name] = obj
                }

                let isMultiGroup = lodNameDetection.groups.count > 1

                // Register AssetInstanceComponent on root for multi-group assets.
                if isMultiGroup {
                    withWorldMutationGate {
                        registerComponent(entityId: entityId, componentType: AssetInstanceComponent.self)
                        if let inst = scene.get(component: AssetInstanceComponent.self, for: entityId) {
                            inst.assetURL = url
                            inst.assetName = filename
                            inst.importMode = "preserveHierarchy"
                        }
                    }
                }

                var lodGroupEntityIds: [EntityID] = []
                lodGroupEntityIds.reserveCapacity(lodNameDetection.groups.count)
                var cpuLODEntries: [(groupEntityId: EntityID, lodIndex: Int, entry: ProgressiveAssetLoader.CPUMeshEntry)] = []
                cpuLODEntries.reserveCapacity(assetData.totalObjectCount)

                let configuredDistances = LODConfig.shared.lodDistances

                withWorldMutationGate {
                    for (groupIdx, group) in lodNameDetection.groups.enumerated() {
                        // Single group: the root entity IS the LOD entity.
                        // Multi-group: create a child entity per group.
                        let groupEntityId: EntityID
                        if isMultiGroup {
                            groupEntityId = createEntity()
                            if hasComponent(entityId: groupEntityId, componentType: LocalTransformComponent.self) == false {
                                registerTransformComponent(entityId: groupEntityId)
                            }
                            if hasComponent(entityId: groupEntityId, componentType: ScenegraphComponent.self) == false {
                                registerSceneGraphComponent(entityId: groupEntityId)
                            }
                            setEntityName(entityId: groupEntityId, name: group.baseName)
                            setParent(childId: groupEntityId, parentId: entityId)
                            let nodePath = generateStableNodePath(assetName: group.baseName, index: groupIdx)
                            registerComponent(entityId: groupEntityId, componentType: DerivedAssetNodeComponent.self)
                            if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: groupEntityId) {
                                derived.assetRootEntityId = entityId
                                derived.nodePath = nodePath
                            }
                        } else {
                            groupEntityId = entityId
                            if hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) == false {
                                registerTransformComponent(entityId: entityId)
                            }
                            if hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) == false {
                                registerSceneGraphComponent(entityId: entityId)
                            }
                        }

                        // Seed transform and bounding box from the LOD0 MDLObject.
                        if let lod0Level = group.levels.first(where: { $0.lodIndex == 0 }),
                           let lod0Object = nameToObject[lod0Level.sourceName]
                        {
                            let worldTransform = composedWorldTransform(for: lod0Object)
                            applyWorldTransform(worldTransform, to: groupEntityId)
                            if let mdlMesh = lod0Object as? MDLMesh,
                               let local = scene.get(component: LocalTransformComponent.self, for: groupEntityId)
                            {
                                local.boundingBox = (min: mdlMesh.boundingBox.minBounds, max: mdlMesh.boundingBox.maxBounds)
                            }
                        }

                        // Build stub LODLevels: empty mesh + .notResident for every level.
                        let maxLODIndex = group.levels.map(\.lodIndex).max() ?? 0
                        var stubLODLevels: [LODLevel] = (0 ... maxLODIndex).map { lodIdx in
                            LODLevel(
                                mesh: [],
                                maxDistance: defaultLODMaxDistance(for: lodIdx, configuredDistances: configuredDistances),
                                url: url,
                                assetName: nil
                            )
                        }
                        for level in group.levels {
                            stubLODLevels[level.lodIndex] = LODLevel(
                                mesh: [],
                                maxDistance: defaultLODMaxDistance(for: level.lodIndex, configuredDistances: configuredDistances),
                                url: url,
                                assetName: level.sourceName
                            )
                        }

                        // Configure LODComponent with stubs (nothing resident yet).
                        configureLODComponent(entityId: groupEntityId, lodLevels: stubLODLevels, activeLODIndex: 0)

                        // StreamingComponent (.unloaded) so GeometryStreamingSystem picks this up.
                        registerComponent(entityId: groupEntityId, componentType: StreamingComponent.self)
                        if let sc = scene.get(component: StreamingComponent.self, for: groupEntityId) {
                            sc.assetFilename = filename
                            sc.assetExtension = withExtension
                            sc.assetName = group.baseName
                            sc.state = .unloaded
                            // Placeholder radii — enableStreaming() sets the real values.
                            sc.streamingRadius = Float.greatestFiniteMagnitude
                            sc.unloadRadius = Float.greatestFiniteMagnitude
                        }

                        OctreeSystem.shared.registerEntity(groupEntityId)
                        lodGroupEntityIds.append(groupEntityId)

                        // Collect CPU entries (stored outside the gate below).
                        for level in group.levels {
                            guard let obj = nameToObject[level.sourceName] else { continue }
                            let estimatedGPUBytes: Int = {
                                guard let mdlMesh = obj as? MDLMesh else { return 0 }
                                let stride = Int((mdlMesh.vertexDescriptor.layouts.firstObject as? MDLVertexBufferLayout)?.stride ?? 48)
                                return mdlMesh.vertexCount * stride + mdlMesh.vertexCount * 3 * 4
                            }()
                            let entry = ProgressiveAssetLoader.CPUMeshEntry(
                                object: obj,
                                vertexDescriptor: vertexDescriptor.model,
                                textureLoader: assetData.textureLoader,
                                device: renderInfo.device,
                                url: url,
                                filename: filename,
                                withExtension: withExtension,
                                uniqueAssetName: level.sourceName,
                                estimatedGPUBytes: estimatedGPUBytes,
                                residencyPolicy: loadingPolicy
                            )
                            cpuLODEntries.append((groupEntityId, level.lodIndex, entry))
                        }
                    }
                }

                // Store CPU LOD entries outside the gate (lock-based, no ECS mutation).
                for (groupEntityId, lodIdx, entry) in cpuLODEntries {
                    ProgressiveAssetLoader.shared.storeCPULODMesh(entry, for: groupEntityId, lodIndex: lodIdx)
                }

                // Keep MDLAsset alive so MDLMeshBufferDataAllocator is not prematurely released.
                ProgressiveAssetLoader.shared.storeAsset(assetData.asset, for: entityId)
                ProgressiveAssetLoader.shared.registerChildren(lodGroupEntityIds, for: entityId)
                ProgressiveAssetLoader.shared.storeRootRehydrationContext(url: url, policy: loadingPolicy, for: entityId)

                Logger.log(
                    message: "[OutOfCore] '\(filename)': \(lodGroupEntityIds.count) LOD group entities registered — GeometryStreamingSystem will upload active LOD on demand",
                    category: LogCategory.oocStatus.rawValue
                )

                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(true)
                return
            }

            if useOutOfCore {
                // OUT-OF-CORE PATH ──────────────────────────────────────────────────────
                // Register ALL leaf meshes immediately as .unloaded stub entities (ECS-only,
                // no GPU allocation). Each stub's MDLMesh data is stored in the CPU registry
                // so GeometryStreamingSystem can upload it from RAM when the entity enters
                // streaming range — no disk re-read required.
                //
                // This replaces the old ProgressiveLoadJob / tick() approach:
                //   Old: upload nearest N → skip rest → skipped entities permanently absent
                //   New: all entities present from the start, streaming drives GPU residency
                Logger.log(
                    message: "[OutOfCore] '\(filename)': \(outOfCoreReason ?? "policy") → out-of-core stub registration (\(assetData.totalObjectCount) stubs)",
                    category: LogCategory.oocStatus.rawValue
                )

                // Register AssetInstanceComponent on the root entity so scene-graph
                // serialisation can identify this as a multi-mesh asset instance.
                withWorldMutationGate {
                    let assetInstanceComp = AssetInstanceComponent(
                        assetURL: url,
                        assetName: filename,
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

                // Register ALL stub entities inside a single withWorldMutationGate.
                // Batching N stubs into one gate acquisition avoids N × acquire/release
                // overhead on assets with hundreds of mesh leaves (e.g. 500 buildings).
                var childEntityIds: [EntityID] = []
                childEntityIds.reserveCapacity(assetData.totalObjectCount)
                var cpuEntries: [(EntityID, ProgressiveAssetLoader.CPUMeshEntry)] = []
                cpuEntries.reserveCapacity(assetData.totalObjectCount)

                withWorldMutationGate {
                    for (i, obj) in assetData.topLevelObjects.enumerated() {
                        let baseName = (obj as? MDLMesh)?.parent?.name ?? obj.name
                        let uniqueAssetName = "\(baseName)#\(i)"

                        let childId = registerProgressiveStubEntity(
                            mdlObject: obj,
                            index: i,
                            uniqueAssetName: uniqueAssetName,
                            rootEntityId: entityId,
                            url: url,
                            filename: filename,
                            withExtension: withExtension
                        )

                        // Estimate GPU bytes from MDLMesh vertex/index counts.
                        // Used by GeometryStreamingSystem for pre-emptive budget reservation
                        // before starting a CPU→Metal upload, so the budget gate fires before
                        // a load rather than reacting after allocation.
                        let estimatedGPUBytes: Int = {
                            guard let mdlMesh = obj as? MDLMesh else { return 0 }
                            let stride = Int((mdlMesh.vertexDescriptor.layouts.firstObject as? MDLVertexBufferLayout)?.stride ?? 48)
                            let vertexBytes = mdlMesh.vertexCount * stride
                            // Approximate: ~3 indices per vertex (conservative, no sharing assumed)
                            let indexBytes = mdlMesh.vertexCount * 3 * 4
                            return vertexBytes + indexBytes
                        }()

                        let entry = ProgressiveAssetLoader.CPUMeshEntry(
                            object: obj,
                            vertexDescriptor: vertexDescriptor.model,
                            textureLoader: assetData.textureLoader,
                            device: renderInfo.device,
                            url: url,
                            filename: filename,
                            withExtension: withExtension,
                            uniqueAssetName: uniqueAssetName,
                            estimatedGPUBytes: estimatedGPUBytes,
                            residencyPolicy: loadingPolicy
                        )
                        cpuEntries.append((childId, entry))
                        childEntityIds.append(childId)
                    }
                }

                // Store CPU entries outside the gate (lock-based, no ECS mutation).
                for (childId, entry) in cpuEntries {
                    ProgressiveAssetLoader.shared.storeCPUMesh(entry, for: childId)
                }

                // Keep MDLAsset alive so the MDLMeshBufferDataAllocator backing all
                // child CPU buffers is not released prematurely.
                ProgressiveAssetLoader.shared.storeAsset(assetData.asset, for: entityId)
                ProgressiveAssetLoader.shared.registerChildren(childEntityIds, for: entityId)

                // Store URL + policy so GeometryStreamingSystem can re-parse from disk if
                // releaseWarmAsset() transitions this asset to CPU-cold in a future frame.
                ProgressiveAssetLoader.shared.storeRootRehydrationContext(
                    url: url,
                    policy: loadingPolicy,
                    for: entityId
                )

                Logger.log(
                    message: "[OutOfCore] '\(filename)': \(assetData.totalObjectCount) stubs registered — GeometryStreamingSystem will upload on demand",
                    category: LogCategory.oocStatus.rawValue
                )

                // Release the loading gate immediately — no GPU work happens here.
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(true)
                return
            }

            // SMALL-FILE FAST PATH (CPU-parsed) ────────────────────────────────────────
            // File is below the size threshold: create all mesh groups from the
            // CPU-parsed data right now, then continue with the normal registration code below.
            // Must use makeMeshesFromCPUBuffers (not makeMeshes) because parseAssetAsync
            // uses MDLMeshBufferDataAllocator — CPU-heap buffers that MTKMesh(mesh:device:)
            // cannot accept directly (MTKModelErrorNoMTLBuffer). makeMeshesFromCPUBuffers
            // copies each buffer to a fresh MTKMeshBufferAllocator-backed buffer first.
            //
            // parseAssetAsync intentionally skips loadTextures() to defer the decompression
            // cost. The OOC path calls ensureTexturesLoaded() in uploadFromCPUEntry before
            // makeMeshesFromCPUBuffers. This fast path bypasses that route, so we must call
            // loadTextures() here to ensure USDZ-embedded textures are decoded — otherwise
            // MTKTextureLoader cannot read the pixel data and all textures silently fail.
            //
            // loadTextures() is a blocking C/ObjC call that can hang indefinitely when
            // ModelIO encounters an unsupported image format inside the USDZ archive.
            // Running it on a DispatchQueue (not the Swift cooperative pool) isolates the
            // hang from other async work.  A 15-second deadline resumes the continuation
            // with false so the load proceeds without textures rather than freezing
            // the render loop via AssetLoadingGate.  ResumeOnce guarantees the
            // continuation fires exactly once regardless of which side wins the race.
            Logger.log(message: "[Streaming] '\(filename)': loadTextures() start")
            let textureLoadOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                let once = ResumeOnce()
                let assetRef = assetData.asset
                let nameForLog = filename
                DispatchQueue.global(qos: .userInitiated).async {
                    assetRef.loadTextures()
                    once.callOnce { cont.resume(returning: true) }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + 15.0) {
                    once.callOnce {
                        Logger.logWarning(message: "[Streaming] '\(nameForLog)': loadTextures() timed out after 15s — proceeding without textures")
                        cont.resume(returning: false)
                    }
                }
            }
            Logger.log(message: "[Streaming] '\(filename)': loadTextures() \(textureLoadOK ? "complete" : "timed out")")
            let smallAssetMeshes: [[Mesh]] = assetData.topLevelObjects.map { obj in
                Mesh.makeMeshesFromCPUBuffers(
                    object: obj,
                    vertexDescriptor: vertexDescriptor.model,
                    textureLoader: assetData.textureLoader,
                    device: renderInfo.device,
                    flip: true
                )
            }
            MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: smallAssetMeshes)

            // Continue to the validation + registration block below using these meshes.
            // ─── SMALL-ASSET CONTINUATION ──────────────────────────────────────────────
            let meshes = smallAssetMeshes

            if meshes.isEmpty {
                handleError(.assetDataMissing, filename)
                loadFallbackMesh(entityId: entityId, filename: filename)
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(false)
                return
            }

            let nonEmptyMeshes = meshes.filter { !$0.isEmpty }

            // assetName is nil here (progressive path requires nil assetName).

            await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 0, totalMeshes: nonEmptyMeshes.count, phase: .registering)

            var loadingEntityIds: [EntityID] = [entityId]

            let handledImportedLOD = tryRegisterImportedLODGroup(
                entityId: entityId,
                url: url,
                filename: filename,
                withExtension: withExtension,
                nonEmptyMeshes: nonEmptyMeshes
            )

            if handledImportedLOD {
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: nonEmptyMeshes.count, totalMeshes: nonEmptyMeshes.count)
            } else if nonEmptyMeshes.count == 1 {
                let mesh = nonEmptyMeshes[0]
                associateMeshesToEntity(entityId: entityId, meshes: mesh)
                registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)
                setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)
                if let renderComp = scene.get(component: RenderComponent.self, for: entityId) {
                    renderComp.isVisible = false
                }
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 1, totalMeshes: 1)
            } else if nonEmptyMeshes.count > 1 {
                let assetInstanceComp = AssetInstanceComponent(
                    assetURL: url,
                    assetName: filename,
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
                    if let firstMesh = mesh.first {
                        applyWorldTransform(firstMesh.worldSpace, to: childEntityId)
                    }
                    associateMeshesToEntity(entityId: childEntityId, meshes: mesh)
                    registerRenderComponent(entityId: childEntityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)
                    let meshAssetName = mesh.first!.assetName
                    setEntityName(entityId: childEntityId, name: meshAssetName)
                    setParent(childId: childEntityId, parentId: entityId)
                    let nodePath = generateStableNodePath(assetName: meshAssetName, index: index)
                    let derivedComp = DerivedAssetNodeComponent(assetRootEntityId: entityId, nodePath: nodePath)
                    registerComponent(entityId: childEntityId, componentType: DerivedAssetNodeComponent.self)
                    if let derived = scene.get(component: DerivedAssetNodeComponent.self, for: childEntityId) {
                        derived.assetRootEntityId = derivedComp.assetRootEntityId
                        derived.nodePath = derivedComp.nodePath
                    }
                    setEntitySkeleton(entityId: childEntityId, filename: filename, withExtension: withExtension)
                    if let renderComp = scene.get(component: RenderComponent.self, for: childEntityId) {
                        renderComp.isVisible = false
                    }
                    loadingEntityIds.append(childEntityId)
                    await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: index + 1, totalMeshes: nonEmptyMeshes.count)
                }
            }

            for id in loadingEntityIds {
                if let renderComp = scene.get(component: RenderComponent.self, for: id) {
                    renderComp.isVisible = true
                }
            }

            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(true)
            return
        }

        // ORIGINAL PATH (assetName specified, or progressive loading disabled) ──────────
        // Uses MTKMeshBufferAllocator: all Metal buffers allocated at parse time.
        // Kept for named-mesh lookups and fallback when progressive loading is off.
        let meshes = await Mesh.loadSceneMeshesAsync(
            url: url,
            vertexDescriptor: vertexDescriptor.model,
            device: renderInfo.device,
            coordinateConversion: coordinateConversion
        ) { current, total in
            guard total > 0 else { return }

            Task {
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: current, totalMeshes: total)
            }
        }

        // Cache meshes for streaming system (so reloads don't require disk I/O)
        MeshResourceManager.shared.cacheLoadedMeshes(url: url, meshArrays: meshes)

        // Process on main thread - validate meshes first
        if meshes.isEmpty {
            handleError(.assetDataMissing, filename)
            loadFallbackMesh(entityId: entityId, filename: filename)
            await AssetLoadingState.shared.finishLoading(entityId: entityId)
            completionBox?.call(false)
            return
        }

        var nonEmptyMeshes = meshes.filter { !$0.isEmpty }

        if let assetNameExist = assetName {
            if let matchedMesh = nonEmptyMeshes.first(where: { $0.first?.assetName == assetNameExist }) {
                nonEmptyMeshes = [matchedMesh]
            } else {
                handleError(.assetDataMissing, "No mesh with asset name \(assetNameExist)")
                loadFallbackMesh(entityId: entityId, filename: filename)
                await AssetLoadingState.shared.finishLoading(entityId: entityId)
                completionBox?.call(false)
                return
            }
        }

        // Register components in batches to avoid blocking
        // Update progress to show registration phase
        await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 0, totalMeshes: nonEmptyMeshes.count, phase: .registering)

        // Track entities being loaded to hide them during registration
        var loadingEntityIds: [EntityID] = [entityId]

        let handledImportedLOD = tryRegisterImportedLODGroup(
            entityId: entityId,
            url: url,
            filename: filename,
            withExtension: withExtension,
            nonEmptyMeshes: nonEmptyMeshes
        )

        if handledImportedLOD {
            await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: nonEmptyMeshes.count, totalMeshes: nonEmptyMeshes.count)
        } else if nonEmptyMeshes.count == 1 {
            let mesh = nonEmptyMeshes[0]
            associateMeshesToEntity(entityId: entityId, meshes: mesh)
            registerRenderComponent(entityId: entityId, meshes: mesh, url: url, assetName: mesh.first!.assetName)
            setEntitySkeleton(entityId: entityId, filename: filename, withExtension: withExtension)

            // Hide during registration
            if let renderComp = scene.get(component: RenderComponent.self, for: entityId) {
                renderComp.isVisible = false
            }
            await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: 1, totalMeshes: 1)
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

            // Process mesh groups without artificial delays to maximize import throughput.
            for (index, mesh) in nonEmptyMeshes.enumerated() {
                let childEntityId = createEntity()

                if hasComponent(entityId: childEntityId, componentType: LocalTransformComponent.self) == false {
                    registerTransformComponent(entityId: childEntityId)
                }

                if hasComponent(entityId: childEntityId, componentType: ScenegraphComponent.self) == false {
                    registerSceneGraphComponent(entityId: childEntityId)
                }

                // Extract full transform (translation, rotation, scale) from mesh world space
                // before RenderComponent registration.
                if let firstMesh = mesh.first {
                    applyWorldTransform(firstMesh.worldSpace, to: childEntityId)
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

                // Add child to loading set
                loadingEntityIds.append(childEntityId)

                // Update registration progress
                await AssetLoadingState.shared.updateProgress(entityId: entityId, currentMesh: index + 1, totalMeshes: nonEmptyMeshes.count)
            }
        }

        // Mark all entities as visible now that registration is complete
        for id in loadingEntityIds {
            if let renderComp = scene.get(component: RenderComponent.self, for: id) {
                renderComp.isVisible = true
            }
        }

        await AssetLoadingState.shared.finishLoading(entityId: entityId)
        completionBox?.call(true)
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
    }
}

/// Tears down all scene entities and clears per-frame GPU residency state.
/// Called by registerTiledScene before registering new tile stubs.
private func clearScene() {
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

    enum CodingKeys: String, CodingKey {
        case version
        case streamingDefaults = "streaming_defaults"
        case tiles
        case sharedBucket = "shared_bucket"
        case tileSize = "tile_size"
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

// MARK: - loadTiledScene

/// Load a large scene described by a tile manifest instead of a single USDZ.
///
/// The manifest (JSON) lists spatial tiles — each pointing to a small USDC/USDZ file
/// with pre-computed world-space bounds.  This function reads the manifest, clears the
/// current scene, creates a default camera and light, then registers one lightweight
/// stub entity per tile.  No geometry is parsed or uploaded at this stage.
///
/// The streaming bootstrap (Issue 3 / GeometryStreamingSystem) will call
/// setEntityMeshAsync on each tile stub when the camera enters its streaming radius,
/// parsing and uploading that tile's geometry on demand.
///
/// - Parameters:
///   - manifest: Filename of the manifest (without extension) searched via LoadingSystem.
///   - withExtension: File extension of the manifest (default "json").
///   - completion: Called on the main thread with `true` when stubs are registered,
///                 `false` if the manifest cannot be found or decoded.
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
        Logger.logError(message: "[loadTiledScene] Manifest '\(manifest).\(ext)' not found in any search path.")
        completion?(false)
        return
    }

    guard let data = try? Data(contentsOf: manifestURL),
          let tileManifest = try? JSONDecoder().decode(TileManifest.self, from: data)
    else {
        Logger.logError(message: "[loadTiledScene] Failed to decode manifest '\(manifest).\(ext)'. Check JSON format.")
        completion?(false)
        return
    }

    Logger.log(message: "[loadTiledScene] Manifest v\(tileManifest.version) decoded — \(tileManifest.tiles.count) tile(s).")

    registerTiledScene(
        manifest: tileManifest,
        baseURL: manifestURL.deletingLastPathComponent(),
        label: "\(manifest).\(ext)",
        completion: completion
    )
}

/// Canonical scene-loading runtime.
///
/// Clears the world, resets streaming systems, registers one TileComponent stub per
/// manifest entry, and enables cell-based static batching.  No geometry is parsed or
/// uploaded here — that happens incrementally as the camera moves.
///
/// Called by loadTiledScene() after JSON decoding.  The manifest is the only public
/// scene contract; USD/USDZ files are internal tile payloads.
///
/// - Parameters:
///   - manifest:    Decoded TileManifest to register.
///   - baseURL:     Directory used to resolve pathRelativeToManifest entries.
///   - label:       Human-readable identifier used in log messages.
///   - completion:  Called synchronously after all stubs are registered.
private func registerTiledScene(
    manifest tileManifest: TileManifest,
    baseURL manifestDir: URL,
    label: String,
    completion: ((Bool) -> Void)?
) {
    // ── 1. Clear previous scene ────────────────────────────────────────────
    clearScene()
    // Reset streaming system state so tile/mesh tracking sets from the previous
    // scene do not persist into this scene's streaming passes.  Camera velocity
    // is also cleared so stale look-ahead does not immediately prefetch wrong tiles.
    GeometryStreamingSystem.shared.reset()
    // Align texture streaming distance tiers to this manifest's actual radii so
    // texture quality bands scale with the scene rather than using fixed values.
    TextureStreamingSystem.shared.alignToManifest(
        streamingRadius: tileManifest.streamingDefaults.streamingRadius,
        unloadRadius: tileManifest.streamingDefaults.unloadRadius
    )

    // ── 2. Default camera + light ──────────────────────────────────────────
    let camera = createEntity()
    setEntityName(entityId: camera, name: "Main Camera")
    createGameCamera(entityId: camera)
    CameraSystem.shared.activeCamera = camera

    let light = createEntity()
    setEntityName(entityId: light, name: "Directional Light")
    createDirLight(entityId: light)

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
    BatchingSystem.shared.setBatchCellSize(manifestTileSize * 2.0)
    enableBatching(true)

    // ── 4. Register tile stub entities ────────────────────────────────────
    // All stubs are registered inside a single withWorldMutationGate to avoid
    // repeated acquire/release overhead on large manifests.
    let defaults = tileManifest.streamingDefaults
    var registeredCount = 0
    var skippedCount = 0

    withWorldMutationGate {
        for tile in tileManifest.tiles {
            // Build the tile URL from the path relative to the manifest.
            // This keeps manifests portable — absolute paths in the JSON are ignored.
            let tileURL = manifestDir.appendingPathComponent(tile.pathRelativeToManifest)

            guard FileManager.default.fileExists(atPath: tileURL.path) else {
                Logger.logWarning(message: "[loadTiledScene] Tile file missing: '\(tile.pathRelativeToManifest)' — skipping '\(tile.tileId)'.")
                skippedCount += 1
                continue
            }

            guard tile.bounds.min.count >= 3, tile.bounds.max.count >= 3,
                  tile.center.count >= 3
            else {
                Logger.logWarning(message: "[loadTiledScene] Tile '\(tile.tileId)' has malformed bounds or center — skipping.")
                skippedCount += 1
                continue
            }

            let entityId = createEntity()
            setEntityName(entityId: entityId, name: tile.tileId)

            // Transform + bounds.
            // The entity's world transform is identity (tile geometry is already in
            // world space in the exported USDC).  The local bounding box is set to
            // the tile's world-space AABB — valid because identity world transform
            // means local space == world space.
            //
            // OctreeSystem.calculateWorldBounds multiplies localBounds by the world
            // matrix (identity here) → correct world-space AABB in the octree.
            //
            // GeometryStreamingSystem.calculateDistance transforms the camera into
            // entity-local space using inv(identity) = identity, then measures to
            // the local AABB → correct world-space distance to the tile surface.
            registerTransformComponent(entityId: entityId)
            if let local = scene.get(component: LocalTransformComponent.self, for: entityId) {
                local.boundingBox = (
                    min: simd_float3(tile.bounds.min[0], tile.bounds.min[1], tile.bounds.min[2]),
                    max: simd_float3(tile.bounds.max[0], tile.bounds.max[1], tile.bounds.max[2])
                )
            }

            registerSceneGraphComponent(entityId: entityId)

            // TileComponent carries everything the streaming bootstrap needs:
            // the tile file URL, the file size for the pre-parse admission gate,
            // and the streaming radii that control when the tile loads/unloads.
            registerComponent(entityId: entityId, componentType: TileComponent.self)
            if let tileComp = scene.get(component: TileComponent.self, for: entityId) {
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
                // prefetchRadius = 0 means auto (midpoint of stream/unload gap).
                // Resolved from: per-tile override → manifest default → auto (0).
                tileComp.prefetchRadius = normalizedBands.prefetchRadius
                tileComp.tileId = tile.tileId
                tileComp.state = .unloaded

                // HLOD: use the first level if present and the file exists on disk.
                if let hlodLevels = tile.hlodLevels, let first = hlodLevels.first {
                    let hlodURL = manifestDir.appendingPathComponent(first.path)
                    if FileManager.default.fileExists(atPath: hlodURL.path),
                       let normalizedHLOD = normalizedBands.hlodSwitchDistance
                    {
                        tileComp.hlodURL = hlodURL
                        tileComp.hlodSwitchDistance = normalizedHLOD
                    }
                }

                // LOD levels: sort ascending by switchDistance (finest first) so the
                // streaming pass can binary-search for the active level by distance.
                if let lodEntries = tile.lodLevels {
                    let sorted = lodEntries.sorted { $0.switchDistance < $1.switchDistance }
                    for (index, entry) in sorted.enumerated() {
                        guard index < normalizedBands.lodSwitchDistances.count else { break }
                        let lodURL = manifestDir.appendingPathComponent(entry.path)
                        guard FileManager.default.fileExists(atPath: lodURL.path) else {
                            Logger.logWarning(message: "[loadTiledScene] LOD file missing for tile '\(tile.tileId)': '\(entry.path)' — skipping level.")
                            continue
                        }
                        tileComp.lodLevels.append(TileLODLevel(url: lodURL, switchDistance: normalizedBands.lodSwitchDistances[index]))
                    }
                }
            }

            // Register with the octree so the streaming system can find this tile
            // via spatial queries.  The octree uses the world bounds computed above.
            OctreeSystem.shared.registerEntity(entityId)
            registeredCount += 1
        }
    }

    // ── 5. Register shared-bucket stub (if present) ───────────────────────
    // The shared bucket is a single USD file containing geometry that spans too
    // many tiles to clip efficiently.  It is registered as a TileComponent stub
    // with the large streaming/unload radii written by the export script so that
    // GeometryStreamingSystem loads it as soon as the camera enters the scene.
    var hasSharedBucket = false
    if let shared = tileManifest.sharedBucket {
        let sharedURL = manifestDir.appendingPathComponent(shared.pathRelativeToManifest)

        if !FileManager.default.fileExists(atPath: sharedURL.path) {
            Logger.logWarning(message: "[loadTiledScene] Shared bucket file missing: '\(shared.pathRelativeToManifest)' — skipping.")
        } else if shared.bounds.min.count < 3 || shared.bounds.max.count < 3 || shared.center.count < 3 {
            Logger.logWarning(message: "[loadTiledScene] Shared bucket has malformed bounds — skipping.")
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
                    // Shared bucket always carries explicit radii from the export script.
                    // Fall back to Float.greatestFiniteMagnitude so the asset is always
                    // loaded if the script somehow omits them.
                    tileComp.streamingRadius = shared.streamingRadius ?? Float.greatestFiniteMagnitude
                    tileComp.unloadRadius = shared.unloadRadius ?? Float.greatestFiniteMagnitude
                    tileComp.priority = shared.priority ?? defaults.priority
                    // Shared bucket: prefetchRadius mirrors streamingRadius (no prefetch
                    // gap needed — it loads immediately when the scene starts).
                    tileComp.prefetchRadius = shared.prefetchRadius ?? defaults.prefetchRadius ?? 0
                    tileComp.tileId = shared.tileId
                    tileComp.state = .unloaded
                }

                OctreeSystem.shared.registerEntity(entityId)
            }
            hasSharedBucket = true
            Logger.log(message: "[loadTiledScene] Shared bucket stub registered: '\(shared.tileId)'.")
        }
    }

    let skipMsg = skippedCount > 0 ? " (\(skippedCount) skipped)" : ""
    let bucketMsg = hasSharedBucket ? " + shared bucket" : ""
    Logger.log(message: "[loadTiledScene] '\(label)': \(registeredCount) tile stubs registered\(skipMsg)\(bucketMsg).")
    completion?(true)
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
            message: "[loadTiledScene] Normalized streaming bands for tile '\(tileId)' — prefetch=\(String(format: "%.2f", normalizedPrefetch)) hlod=\(normalizedHLOD.map { String(format: "%.2f", $0) } ?? "nil") lods=\(normalizedLODs.map { String(format: "%.2f", $0) })"
        )
    }

    return (normalizedPrefetch, normalizedHLOD, normalizedLODs)
}

// Lightweight second MDLAsset pass that extracts cameras and lights only.
// Uses a bare MDLAsset (no vertex descriptor, no allocator) so no geometry
// buffers are allocated — this is cheap even for large scenes.

/// Cache to avoid reloading USDZ files multiple times for skeleton checks
private var skeletonCache: [URL: MDLSkeleton?] {
    get {
        registrationRuntimeState.lock.lock()
        defer { registrationRuntimeState.lock.unlock() }
        return registrationRuntimeState.skeletonCache
    }
    set {
        registrationRuntimeState.lock.lock()
        registrationRuntimeState.skeletonCache = newValue
        registrationRuntimeState.lock.unlock()
    }
}

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
    enforceRegistrationMainActor()
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

    /// Helper function to add animation clips
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

public func setEntityStaticBatchComponent(entityId: EntityID) {
    // XR can render from a dedicated thread while scene data is being mutated here.
    // Gate rendering while we recursively tag the hierarchy as static-batchable.
    withWorldMutationGate {
        setEntityStaticBatchComponentRecursive(entityId: entityId)
    }
}

/// Same behavior as `setEntityStaticBatchComponent(entityId:)`, but assumes the caller is
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
    if hasRender || hasStreaming {
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
            Logger.logError(message: "Entity does not have LODComponent. Call setEntityLodComponent() first.")
            completionBox?.call(false)
            return
        }

        // Get file URL using standard resource loading
        guard let url = LoadingSystem.shared.resourceURL(forResource: fileName, withExtension: withExtension) else {
            Logger.logError(message: "Failed to find LOD file: \(fileName).\(withExtension)")
            completionBox?.call(false)
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
            Logger.logError(message: "Failed to find LOD file: \(fileName).\(withExtension)")
            completionBox?.call(false)
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
