
//
//  RenderPasses.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import MetalKit

public enum RenderPasses {
    /// Count of unbatched shadow-caster entities from the most recent frame.
    /// Updated by shadowCasterEntityIds (main thread); read by the streaming heartbeat (main thread).
    public nonisolated(unsafe) static var lastShadowCasterCount: Int = 0
    public typealias RenderPassExecution = @Sendable (MTLCommandBuffer) -> Void

    /// Maximum distance from the camera at which an entity is considered for shadow casting.
    /// Entities whose closest AABB point exceeds this distance are skipped across all cascade passes.
    /// Set to 0 to disable distance culling. Default: 40 world units.
    public nonisolated(unsafe) static var maxShadowCastingDistance: Float = 40.0

    private static let runtimeState = RuntimeState()
    private static let lodDebugPalette: [simd_float3] = [
        simd_float3(1.0, 0.0, 0.0), // LOD0 = red
        simd_float3(0.0, 1.0, 0.0), // LOD1 = green
        simd_float3(0.0, 0.0, 1.0), // LOD2 = blue
        simd_float3(1.0, 1.0, 0.0), // LOD3 = yellow
        simd_float3(1.0, 0.0, 1.0), // LOD4 = magenta
        simd_float3(0.0, 1.0, 1.0), // LOD5+ = cyan (palette wraps)
    ]

    /// Streaming tier debug colors.
    /// Blue = full resolution, Orange = medium (capped), Red = minimum, Yellow = in-flight.
    private static let streamingTierDebugColors: [simd_float3] = [
        simd_float3(0.1, 0.4, 1.0), // [0] full     = blue
        simd_float3(1.0, 0.55, 0.0), // [1] capped    = orange
        simd_float3(1.0, 0.2, 0.1), // [2] minimum   = red
        simd_float3(1.0, 0.85, 0.0), // [3] in-flight = yellow
    ]
    private static let defaultWireframeColor = simd_float4(0.2, 0.85, 1.0, 1.0)
    private struct SpatialDebugColorKey: Hashable {
        let r: UInt32
        let g: UInt32
        let b: UInt32
        let a: UInt32
    }

    private struct SpatialDebugLineBatch {
        let color: simd_float4
        let vertexStart: Int
        let vertexCount: Int
    }

    private struct LODDitherDraw {
        let meshes: [Mesh]
        let threshold: Float
        let mode: Float
    }

    private final class RuntimeState: @unchecked Sendable {
        let lock = NSLock()
        var transparencyXRDepthWriteState: MTLDepthStencilState?
        var wireframeXRDepthWriteState: MTLDepthStencilState?
        var alwaysDepthState: MTLDepthStencilState?
        var spatialDebugLineBuffer: MTLBuffer?
        var spatialDebugLineBufferCapacityVertices: Int = 0
        var spatialDebugLastLogTime: TimeInterval = 0
        var spatialDebugLastLogSignature: String = ""
        var visibleBatchIdsFrame: Int = -1
        var visibleBatchIdsCache: Set<UUID> = []
        /// Cache for cluster-level frustum-culled batch groups (replaces entity-derived path).
        var visibleBatchGroupsFrame: Int = -1
        var visibleBatchGroupsCache: [BatchGroup] = []
        /// Cached Set<EntityID> built from visibleEntityIds — avoids O(n) rebuild on each use.
        var visibleEntitySetFrame: Int = -1
        var visibleEntitySetCache: Set<EntityID> = []
        /// Pre-screened shadow-caster candidates. Excludes cameras, lights, gizmos, and
        /// batch-eligible entities. Rebuilt only when dirty (residency/LOD events),
        /// not on every cascade call.
        var shadowEntityCandidates: [EntityID] = []
        var shadowCacheDirty: Bool = true
    }

    @inline(__always)
    private static func updateSpatialDebugLogState(now: TimeInterval, signature: String) -> Bool {
        runtimeState.lock.lock()
        let shouldLog =
            (now - runtimeState.spatialDebugLastLogTime) >= 1.0
                || signature != runtimeState.spatialDebugLastLogSignature
        if shouldLog {
            runtimeState.spatialDebugLastLogTime = now
            runtimeState.spatialDebugLastLogSignature = signature
        }
        runtimeState.lock.unlock()
        return shouldLog
    }

    @inline(__always)
    private static func getOrCreateTransparencyXRDepthWriteState(device: MTLDevice) -> MTLDepthStencilState? {
        runtimeState.lock.lock()
        if let cached = runtimeState.transparencyXRDepthWriteState {
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = sceneDepthCompareFunction(.lessEqual)
        depthStateDescriptor.isDepthWriteEnabled = true
        let created = device.makeDepthStencilState(descriptor: depthStateDescriptor)

        runtimeState.lock.lock()
        if runtimeState.transparencyXRDepthWriteState == nil {
            runtimeState.transparencyXRDepthWriteState = created
        }
        let result = runtimeState.transparencyXRDepthWriteState
        runtimeState.lock.unlock()
        return result
    }

    @inline(__always)
    private static func getOrCreateWireframeXRDepthWriteState(device: MTLDevice) -> MTLDepthStencilState? {
        runtimeState.lock.lock()
        if let cached = runtimeState.wireframeXRDepthWriteState {
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = sceneDepthCompareFunction(.lessEqual)
        depthStateDescriptor.isDepthWriteEnabled = true
        let created = device.makeDepthStencilState(descriptor: depthStateDescriptor)

        runtimeState.lock.lock()
        if runtimeState.wireframeXRDepthWriteState == nil {
            runtimeState.wireframeXRDepthWriteState = created
        }
        let result = runtimeState.wireframeXRDepthWriteState
        runtimeState.lock.unlock()
        return result
    }

    @inline(__always)
    private static func getOrCreateAlwaysDepthState(device: MTLDevice) -> MTLDepthStencilState? {
        runtimeState.lock.lock()
        if let cached = runtimeState.alwaysDepthState {
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        let created = device.makeDepthStencilState(descriptor: descriptor)

        runtimeState.lock.lock()
        if runtimeState.alwaysDepthState == nil {
            runtimeState.alwaysDepthState = created
        }
        let result = runtimeState.alwaysDepthState
        runtimeState.lock.unlock()
        return result
    }

    @inline(__always)
    private static func ensureSpatialDebugLineBuffer(
        device: MTLDevice,
        requiredVertexCount: Int,
        vertexStride: Int
    ) -> MTLBuffer? {
        runtimeState.lock.lock()
        if runtimeState.spatialDebugLineBuffer == nil
            || runtimeState.spatialDebugLineBufferCapacityVertices < requiredVertexCount
        {
            let grownCapacity = max(
                requiredVertexCount,
                max(runtimeState.spatialDebugLineBufferCapacityVertices * 2, 1024)
            )
            runtimeState.spatialDebugLineBuffer = device.makeBuffer(
                length: grownCapacity * vertexStride,
                options: .storageModeShared
            )
            runtimeState.spatialDebugLineBuffer?.label = "Spatial Debug Leaf Bounds Buffer"
            runtimeState.spatialDebugLineBufferCapacityVertices = grownCapacity
        }
        let buffer = runtimeState.spatialDebugLineBuffer
        runtimeState.lock.unlock()
        return buffer
    }

    @inline(__always)
    private static func appendAABBLineVertices(_ bounds: AABB, to vertices: inout [SIMD4<Float>]) {
        let min = bounds.min
        let max = bounds.max

        vertices.append(contentsOf: [
            // Bottom face
            SIMD4(min.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, min.z, 1.0),
            SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, max.z, 1.0),
            SIMD4(max.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, max.z, 1.0),
            SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, min.z, 1.0),

            // Top face
            SIMD4(min.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
            SIMD4(max.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
            SIMD4(max.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
            SIMD4(min.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),

            // Vertical edges
            SIMD4(min.x, min.y, min.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),
            SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
            SIMD4(max.x, min.y, max.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
            SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
        ])
    }

    @inline(__always)
    private static func shouldCullWireframeByDistanceFade(
        bounds: AABB,
        cameraPosition: simd_float3,
        settings: WireframeRenderState
    ) -> Bool {
        guard settings.distanceFadeEnabled else { return false }

        let fadeEnd = max(settings.fadeEndDistance, settings.fadeStartDistance + 0.001)
        // Closest-point AABB distance: camera inside the AABB gives distance 0
        // (always renders), so a room the user is standing in is never culled.
        let closest = simd_clamp(cameraPosition, bounds.min, bounds.max)
        return simd_length(cameraPosition - closest) > fadeEnd
    }

    @inline(__always)
    private static func spatialDebugColorKey(_ color: simd_float4) -> SpatialDebugColorKey {
        SpatialDebugColorKey(
            r: color.x.bitPattern,
            g: color.y.bitPattern,
            b: color.z.bitPattern,
            a: color.w.bitPattern
        )
    }

    @inline(__always)
    private static func logSpatialDebugStatus(totalLeaves: Int, drawnLeaves: Int, cap: Int) {
        let now = Date().timeIntervalSince1970
        let signature = "\(totalLeaves)|\(drawnLeaves)|\(cap)"
        let shouldLog = updateSpatialDebugLogState(now: now, signature: signature)
        guard shouldLog else { return }
//        Logger.log(
//            message: "[SpatialDebug] enabled=true leaves=\(totalLeaves) drawn=\(drawnLeaves) cap=\(cap)",
//            category: "SpatialDebug"
//        )
    }

    @inline(__always)
    private static func lodDebugColor(for lodIndex: Int) -> simd_float3 {
        let clamped = max(0, lodIndex)
        return lodDebugPalette[clamped % lodDebugPalette.count]
    }

    @inline(__always)
    private static func passthroughGhostAlpha(for entityId: EntityID) -> Float {
        guard renderInfo.immersionStyle == .mixed,
              let opacity = passthroughGhostOpacity(for: getEntitySceneChannels(entityId: entityId))
        else {
            return 1.0
        }
        return opacity
    }

    @inline(__always)
    private static func passthroughGhostAlpha(for batchGroup: BatchGroup) -> Float {
        guard renderInfo.immersionStyle == .mixed,
              let opacity = passthroughGhostOpacity(for: batchGroup.sceneChannels)
        else {
            return 1.0
        }
        return opacity
    }

    @inline(__always)
    private static func isEntityInActiveLODFade(_ entityId: EntityID) -> Bool {
        guard LODConfig.shared.enableFadeTransitions,
              let lod = scene.get(component: LODComponent.self, for: entityId)
        else { return false }
        return lod.previousLOD != nil
    }

    @inline(__always)
    private static func isEntityInActiveTileRepresentationFade(_ entityId: EntityID) -> Bool {
        scene.get(component: TileRepresentationFadeComponent.self, for: entityId) != nil
    }

    private static func opaqueLODDraws(entityId: EntityID, renderComponent: RenderComponent) -> [LODDitherDraw] {
        guard LODConfig.shared.enableFadeTransitions,
              let lod = scene.get(component: LODComponent.self, for: entityId),
              let previousLOD = lod.previousLOD,
              previousLOD >= 0,
              previousLOD < lod.lodLevels.count
        else {
            return [LODDitherDraw(meshes: renderComponent.mesh, threshold: 1.0, mode: 0.0)]
        }

        let previousMeshes = lod.lodLevels[previousLOD].mesh
        guard !previousMeshes.isEmpty else {
            return [LODDitherDraw(meshes: renderComponent.mesh, threshold: 1.0, mode: 0.0)]
        }

        let threshold = simd_clamp(lod.transitionProgress, 0.0, 1.0)
        return [
            LODDitherDraw(meshes: previousMeshes, threshold: threshold, mode: 2.0),
            LODDitherDraw(meshes: renderComponent.mesh, threshold: threshold, mode: 1.0),
        ]
    }

    @inline(__always)
    private static func applyLODDither(
        draw: LODDitherDraw,
        materialParameters: inout MaterialParametersUniform
    ) {
        materialParameters.lodDither = simd_float4(draw.threshold, draw.mode, 0.0, 0.0)
    }

    @inline(__always)
    private static func applyTileRepresentationDither(
        entityId: EntityID,
        materialParameters: inout MaterialParametersUniform
    ) {
        guard let fade = scene.get(component: TileRepresentationFadeComponent.self, for: entityId) else { return }
        materialParameters.lodDither = simd_float4(
            simd_clamp(fade.progress, 0.0, 1.0),
            fade.mode,
            0.0,
            0.0
        )
    }

    @inline(__always)
    private static func extractLODIndex(from batchKey: String) -> Int? {
        guard let markerRange = batchKey.range(of: "_LOD", options: .backwards) else {
            return nil
        }

        let suffix = batchKey[markerRange.upperBound...]
        let digits = suffix.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return Int(digits)
    }

    static func collectVisibleBatchIds(from entityIds: [EntityID]) -> Set<UUID> {
        var visibleBatchIds: Set<UUID> = []
        visibleBatchIds.reserveCapacity(entityIds.count)

        for entityId in entityIds {
            guard let batchInfo = BatchingSystem.shared.getBatchInfo(for: entityId) else { continue }
            visibleBatchIds.insert(batchInfo.batchId)
        }

        return visibleBatchIds
    }

    /// Per-frame cached Set<EntityID> built from visibleEntityIds.
    /// Avoids O(n) allocation + hashing on every caller within the same frame.
    static func visibleEntitySetSnapshot() -> Set<EntityID> {
        let frame = cullFrameIndex

        runtimeState.lock.lock()
        if runtimeState.visibleEntitySetFrame == frame {
            let cached = runtimeState.visibleEntitySetCache
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let ids = visibleEntityIds
        var computed = Set<EntityID>()
        computed.reserveCapacity(ids.count)
        for id in ids {
            computed.insert(id)
        }

        runtimeState.lock.lock()
        runtimeState.visibleEntitySetFrame = frame
        runtimeState.visibleEntitySetCache = computed
        runtimeState.lock.unlock()
        return computed
    }

    private static func visibleBatchIdsSnapshot() -> Set<UUID> {
        let frame = cullFrameIndex

        runtimeState.lock.lock()
        if runtimeState.visibleBatchIdsFrame == frame {
            let cached = runtimeState.visibleBatchIdsCache
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let computed = collectVisibleBatchIds(from: visibleEntityIds)

        runtimeState.lock.lock()
        runtimeState.visibleBatchIdsFrame = frame
        runtimeState.visibleBatchIdsCache = computed
        runtimeState.lock.unlock()
        return computed
    }

    /// Tests each live BatchGroup's world-space AABB against the current-frame frustum.
    /// This is the cluster-level culling path: one AABB test per batch group rather than
    /// one test per entity, then a lookup to derive which groups are visible.
    ///
    /// Falls back to the entity-derived path when `currentFrameFrustum` is nil (no
    /// camera yet, or called before the first culling pass).
    private static func collectVisibleBatchGroupsDirect() -> [BatchGroup] {
        let groups = BatchingSystem.shared.batchGroups
        guard !groups.isEmpty else { return [] }
        let channelVisibleGroups = groups.filter { shouldRenderSceneChannelsOpaque($0.sceneChannels) }
        guard !channelVisibleGroups.isEmpty else { return [] }

        guard let frustum = currentFrameFrustum else {
            // Frustum not yet available — derive from visible entities (safe fallback).
            let ids = collectVisibleBatchIds(from: visibleEntityIds)
            return channelVisibleGroups.filter { ids.contains($0.id) }
        }

        // Phase 1: frustum cull — drop groups whose AABB is outside the view frustum.
        let frustumPassed = channelVisibleGroups.filter {
            isAABBInFrustum(frustum, min: $0.boundingBox.min, max: $0.boundingBox.max)
        }

        guard !frustumPassed.isEmpty else { return [] }

        // Phase 2: HZB occlusion cull — reuse the entity-level GPU HZB result.
        // Batched entities go through the same GPU frustum+HZB pipeline and appear
        // in visibleEntityIds when not occluded.  A batch group whose every member
        // entity was occluded by the HZB is itself fully occluded and can be skipped.
        // One-frame latency matches the entity-level rendering path.
        guard renderInfo.hzbIsValid else {
            return frustumPassed
        }

        let visibleSet = visibleEntitySetSnapshot()
        return frustumPassed.filter { group in
            group.entityIds.contains { visibleSet.contains($0) }
        }
    }

    @inline(__always)
    private static func shouldSkipShadowEntity(_ entityId: EntityID) -> Bool {
        if scene.mask(for: entityId) == nil { return true }
        if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { return true }
        if scene.get(component: CameraComponent.self, for: entityId) != nil { return true }
        if scene.get(component: LightComponent.self, for: entityId) != nil { return true }
        if scene.get(component: GizmoComponent.self, for: entityId) != nil { return true }
        return false
    }

    private static func shadowFrustum(for cascadeIdx: Int) -> Frustum? {
        guard cascadeIdx >= 0, cascadeIdx < shadowSystem.cascadeLightSpaceMatrices.count else {
            return nil
        }
        let effectiveLightMatrix = SceneRootTransform.shared.effectiveLightMatrix(
            shadowSystem.cascadeLightSpaceMatrices[cascadeIdx]
        )
        return buildFrustum(from: effectiveLightMatrix)
    }

    public static let copyOpaqueDepthForHZBExecution: RenderPassExecution = { commandBuffer in
        guard let sourceDepth = textureResources.depthMap,
              let hzbSourceDepth = textureResources.hzbSourceDepthMap
        else { return }

        let width = min(sourceDepth.width, hzbSourceDepth.width)
        let height = min(sourceDepth.height, hzbSourceDepth.height)
        guard width > 0, height > 0 else { return }

        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }
        blitEncoder.label = "Copy Opaque Depth for HZB"
        blitEncoder.copy(
            from: sourceDepth,
            sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: hzbSourceDepth,
            destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()
    }

    // MARK: - Shadow entity cache

    /// Guards one-time subscription setup for the shadow entity cache.
    private nonisolated(unsafe) static var shadowCacheConfigured = false

    /// Registers residency and LOD event subscribers that mark the shadow entity cache dirty.
    /// Called once, lazily, on the first shadow pass invocation.
    private static func ensureShadowCacheConfigured() {
        guard !shadowCacheConfigured else { return }
        shadowCacheConfigured = true
        SystemEventBus.shared.subscribeToResidencyChanges { _ in
            runtimeState.lock.lock()
            runtimeState.shadowCacheDirty = true
            runtimeState.lock.unlock()
        }
        SystemEventBus.shared.subscribeToLODChanges { _ in
            runtimeState.lock.lock()
            runtimeState.shadowCacheDirty = true
            runtimeState.lock.unlock()
        }
    }

    /// Rebuilds the shadow entity candidate list from the current ECS state.
    ///
    /// Only filters by stable properties (component presence). Per-frame culls — isVisible,
    /// scene-channel visibility, distance, cascade frustum — are applied per-cascade in
    /// shadowCasterEntityIds so this scan runs at most once per dirty event, not every frame.
    private static func rebuildShadowEntityCache() {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let localTransformId = getComponentId(for: LocalTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, localTransformId, renderId], in: scene)

        var candidates: [EntityID] = []
        candidates.reserveCapacity(entities.count / 4)

        let batchingEnabled = BatchingSystem.shared.isEnabled()
        for entityId in entities {
            if shouldSkipShadowEntity(entityId) { continue }
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.castsShadow
            else { continue }
            // Batch-eligible entities always cast shadows via shadowCasterBatchGroups.
            // Excluding them here prevents O(n_loaded_tiles) individual shadow draw calls.
            if batchingEnabled, scene.get(component: StaticBatchComponent.self, for: entityId) != nil { continue }
            candidates.append(entityId)
        }

        runtimeState.lock.lock()
        runtimeState.shadowEntityCandidates = candidates
        runtimeState.shadowCacheDirty = false
        runtimeState.lock.unlock()
    }

    /// Marks the shadow entity candidate cache dirty so it is rebuilt on the next shadow pass.
    /// Call this after creating or destroying non-streamed renderable entities; streamed entities
    /// are handled automatically via residency events.
    public static func invalidateShadowEntityCache() {
        runtimeState.lock.lock()
        runtimeState.shadowCacheDirty = true
        runtimeState.lock.unlock()
    }

    /// Returns the current shadow entity candidate cache, rebuilding first if dirty.
    /// Internal — exposed for testing via @testable import. Lets tests pin the exact
    /// staleness bug this cache has had before: a non-streaming load that skips
    /// invalidateShadowEntityCache() is silently absent from shadow candidates.
    static func shadowEntityCandidatesForTesting() -> [EntityID] {
        runtimeState.lock.lock()
        let dirty = runtimeState.shadowCacheDirty
        runtimeState.lock.unlock()
        if dirty {
            rebuildShadowEntityCache()
        }
        runtimeState.lock.lock()
        defer { runtimeState.lock.unlock() }
        return runtimeState.shadowEntityCandidates
    }

    private static func shadowCasterEntityIds(for cascadeIdx: Int) -> [EntityID] {
        ensureShadowCacheConfigured()
        guard let frustum = shadowFrustum(for: cascadeIdx) else { return [] }

        let cameraPosition: simd_float3
        if let cam = CameraSystem.shared.activeCamera,
           let camComp = scene.get(component: CameraComponent.self, for: cam)
        {
            cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(camComp.localPosition)
        } else {
            cameraPosition = .zero
        }

        // Rebuild candidate list if dirty. At most one rebuild per dirty event, shared
        // across all cascade invocations in the same frame.
        runtimeState.lock.lock()
        let dirty = runtimeState.shadowCacheDirty
        runtimeState.lock.unlock()
        if dirty {
            rebuildShadowEntityCache()
        }

        runtimeState.lock.lock()
        let candidates = runtimeState.shadowEntityCandidates
        runtimeState.lock.unlock()

        var result: [EntityID] = []
        result.reserveCapacity(candidates.count / 4)

        for entityId in candidates {
            guard scene.mask(for: entityId) != nil else { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }
            if BatchingSystem.shared.isEnabled() {
                // Batch-eligible entities (StaticBatchComponent present) are always drawn
                // via shadowCasterBatchGroups — whether or not the batch rebuild has landed
                // yet.  Skipping them here prevents O(n_loaded_tiles) shadow draw calls that
                // scale with the scene and eventually overflow the GPU command buffer budget.
                // During the brief batch-rebuild window their shadow is absent; this is
                // preferable to the alternative of the app freezing at ~300+ loaded tiles.
                if scene.get(component: StaticBatchComponent.self, for: entityId) != nil { continue }
                if BatchingSystem.shared.isBatched(entityId: entityId) { continue }
            }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.isVisible,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            // Per-cascade distance limit: cap at the cascade's own split distance so
            // objects beyond this cascade's far plane are not rendered into it.
            // This prevents the near cascade from receiving shadow casters that are
            // only relevant to farther cascades, cutting draw calls significantly for
            // the near (most expensive) cascade.
            let cascadeMaxDistance = shadowCascadeMaxDistance(
                cascadeIdx: cascadeIdx,
                splitDistances: shadowSystem.cascadeSplitDistances,
                globalMax: RenderPasses.maxShadowCastingDistance
            )
            if shadowEntityBeyondMaxDistance(
                worldMin: worldMin, worldMax: worldMax,
                cameraPosition: cameraPosition,
                maxDistance: cascadeMaxDistance
            ) { continue }
            if isAABBInFrustum(frustum, min: worldMin, max: worldMax) {
                result.append(entityId)
            }
        }

        lastShadowCasterCount = result.count
        return result
    }

    private static func shadowCasterBatchGroups(for cascadeIdx: Int) -> [BatchGroup] {
        let groups = BatchingSystem.shared.batchGroups.filter { shouldRenderSceneChannelsOpaque($0.sceneChannels) }
        guard !groups.isEmpty, let frustum = shadowFrustum(for: cascadeIdx) else { return [] }

        return groups.filter {
            isAABBInFrustum(frustum, min: $0.boundingBox.min, max: $0.boundingBox.max)
        }
    }

    private static func spotShadowCasterEntityIds() -> [EntityID] {
        ensureShadowCacheConfigured()
        guard spotShadowState.isActive,
              let shadowLight = spotShadowState.light,
              let frustum = spotShadowState.frustum
        else { return [] }

        runtimeState.lock.lock()
        let dirty = runtimeState.shadowCacheDirty
        runtimeState.lock.unlock()
        if dirty {
            rebuildShadowEntityCache()
        }

        runtimeState.lock.lock()
        let candidates = runtimeState.shadowEntityCandidates
        runtimeState.lock.unlock()

        let lightPosition = shadowLight.light.position
        let maxDistance = max(shadowLight.light.attenuation.w, minimumSpotShadowDistance)
        var result: [EntityID] = []
        result.reserveCapacity(candidates.count / 4)

        for entityId in candidates {
            guard scene.mask(for: entityId) != nil else { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }
            if BatchingSystem.shared.isEnabled() {
                if scene.get(component: StaticBatchComponent.self, for: entityId) != nil { continue }
                if BatchingSystem.shared.isBatched(entityId: entityId) { continue }
            }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.isVisible,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            if shadowEntityBeyondMaxDistance(
                worldMin: worldMin,
                worldMax: worldMax,
                cameraPosition: lightPosition,
                maxDistance: maxDistance
            ) { continue }
            if isAABBInFrustum(frustum, min: worldMin, max: worldMax) {
                result.append(entityId)
            }
        }

        return result
    }

    private static func pointShadowCasterEntityIds() -> [EntityID] {
        ensureShadowCacheConfigured()
        guard pointShadowState.isActive,
              let shadowLight = pointShadowState.light
        else { return [] }

        runtimeState.lock.lock()
        let dirty = runtimeState.shadowCacheDirty
        runtimeState.lock.unlock()
        if dirty {
            rebuildShadowEntityCache()
        }

        runtimeState.lock.lock()
        let candidates = runtimeState.shadowEntityCandidates
        runtimeState.lock.unlock()

        let lightPosition = shadowLight.light.position
        let maxDistance = max(shadowLight.light.radius, minimumPointShadowDistance)
        var result: [EntityID] = []
        result.reserveCapacity(candidates.count / 4)

        for entityId in candidates {
            if entityId == shadowLight.entityId { continue }
            guard scene.mask(for: entityId) != nil else { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }
            if BatchingSystem.shared.isEnabled() {
                if scene.get(component: StaticBatchComponent.self, for: entityId) != nil { continue }
                if BatchingSystem.shared.isBatched(entityId: entityId) { continue }
            }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.isVisible,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            if shadowEntityBeyondMaxDistance(
                worldMin: worldMin,
                worldMax: worldMax,
                cameraPosition: lightPosition,
                maxDistance: maxDistance
            ) { continue }

            result.append(entityId)
        }

        return result
    }

    private static func pointShadowCasterBatchGroups() -> [BatchGroup] {
        let groups = BatchingSystem.shared.batchGroups.filter { shouldRenderSceneChannelsOpaque($0.sceneChannels) }
        guard !groups.isEmpty,
              pointShadowState.isActive
        else { return [] }

        let maxDistance = max(pointShadowState.farDistance, minimumPointShadowDistance)
        let lightPosition = pointShadowState.light?.light.position ?? .zero
        return groups.filter {
            !shadowEntityBeyondMaxDistance(
                worldMin: $0.boundingBox.min,
                worldMax: $0.boundingBox.max,
                cameraPosition: lightPosition,
                maxDistance: maxDistance
            )
        }
    }

    private static func spotShadowCasterBatchGroups() -> [BatchGroup] {
        let groups = BatchingSystem.shared.batchGroups.filter { shouldRenderSceneChannelsOpaque($0.sceneChannels) }
        guard !groups.isEmpty,
              spotShadowState.isActive,
              let frustum = spotShadowState.frustum
        else { return [] }

        return groups.filter {
            isAABBInFrustum(frustum, min: $0.boundingBox.min, max: $0.boundingBox.max)
        }
    }

    /// Per-frame cached cluster-level visibility.  Both batch render passes (shadow +
    /// model) call this; the result is computed once and reused for the same frame index.
    private static func visibleBatchGroupsSnapshot() -> [BatchGroup] {
        let frame = cullFrameIndex

        runtimeState.lock.lock()
        if runtimeState.visibleBatchGroupsFrame == frame {
            let cached = runtimeState.visibleBatchGroupsCache
            runtimeState.lock.unlock()
            return cached
        }
        runtimeState.lock.unlock()

        let computed = collectVisibleBatchGroupsDirect()

        runtimeState.lock.lock()
        runtimeState.visibleBatchGroupsFrame = frame
        runtimeState.visibleBatchGroupsCache = computed
        runtimeState.lock.unlock()
        return computed
    }

    @inline(__always)
    private static func applyMaterialTextureState(
        material: Material,
        materialParameters: inout MaterialParametersUniform
    ) {
        materialParameters.hasTexture = simd_int4(
            Int32(material.hasBaseMap ? 1 : 0),
            Int32(material.hasRoughMap ? 1 : 0),
            Int32(material.hasMetalMap ? 1 : 0),
            0
        )
        materialParameters.textureChannels = simd_int4(
            Int32(material.roughnessChannel.rawValue),
            Int32(material.metallicChannel.rawValue),
            0,
            0
        )
    }

    @inline(__always)
    private static func applyLODDebugColorOverride(
        entityId: EntityID? = nil,
        batchGroup: BatchGroup? = nil,
        materialParameters: inout MaterialParametersUniform
    ) {
        guard SpatialDebugVisualization.shared.colorRenderablesByLOD else { return }

        let lodIndex: Int?
        if let entityId,
           let lod = scene.get(component: LODComponent.self, for: entityId)
        {
            // Non-batched path: entity-level LOD — read live currentLOD.
            lodIndex = lod.currentLOD
        } else if let entityId,
                  let tag = scene.get(component: TileLODTagComponent.self, for: entityId)
        {
            // Non-batched path: per-tile LOD / HLOD child mesh.
            lodIndex = tag.levelIndex
        } else if let batchGroup, batchGroup.isLODBatch {
            // Batched path: only color batches that actually contain LOD entities.
            // Non-LOD batches also have _LOD0 in their key but should not be tinted.
            lodIndex = extractLODIndex(from: batchGroup.batchKey)
        } else {
            lodIndex = nil
        }

        guard let lodIndex else { return }

        let color = lodDebugColor(for: lodIndex)
        materialParameters.baseColor = simd_float4(color.x, color.y, color.z, materialParameters.baseColor.w)
        materialParameters.hasTexture.x = 0
    }

    @inline(__always)
    private static func applyStreamingTierDebugColorOverride(
        entityId: EntityID? = nil,
        batchMaterial: Material? = nil,
        materialParameters: inout MaterialParametersUniform
    ) {
        guard SpatialDebugVisualization.shared.colorRenderablesByStreamingTier else { return }

        let streamingLevel: TextureStreamingLevel
        let inFlight: Bool

        if let entityId {
            guard let render = scene.get(component: RenderComponent.self, for: entityId),
                  let material = render.mesh.first?.submeshes.first?.material
            else { return }
            streamingLevel = material.baseColorStreamingLevel
            inFlight = TextureStreamingSystem.shared.isStreaming(entityId: entityId)
        } else if let batchMaterial {
            streamingLevel = batchMaterial.baseColorStreamingLevel
            inFlight = false
        } else {
            return
        }

        let color: simd_float3
        if inFlight {
            color = streamingTierDebugColors[3]
        } else {
            switch streamingLevel {
            case .full: color = streamingTierDebugColors[0]
            case .capped: color = streamingTierDebugColors[1]
            case .minimum: color = streamingTierDebugColors[2]
            }
        }

        materialParameters.baseColor = simd_float4(color.x, color.y, color.z, materialParameters.baseColor.w)
        materialParameters.hasTexture.x = 0
    }

    public static let gridExecution: RenderPassExecution = { commandBuffer in
        guard let gridPipeline = PipelineManager.shared.renderPipelinesByType[.grid] else {
            handleError(.pipelineStateNulled, "gridPipeline is nil")
            return
        }

        if gridPipeline.success == false {
            handleError(.pipelineStateNulled, gridPipeline.name!)
            return
        }

        // update uniforms
        var gridUniforms = Uniforms()

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        // viewMatrix (inverted) and projectionMatrix (inverted) are used by the vertex shader
        // to unproject NDC corners into world-space rays for the infinite grid.
        let invView = cameraComponent.viewSpace.inverse
        gridUniforms.viewMatrix = invView
        gridUniforms.projectionMatrix = renderInfo.perspectiveSpace.inverse

        // modelViewMatrix repurposed: stores the forward P*V matrix so the fragment shader
        // can compute correct clip-space depth regardless of Z convention.
        gridUniforms.modelViewMatrix = simd_mul(renderInfo.perspectiveSpace, cameraComponent.viewSpace)

        if let gridUniformBuffer = bufferResources.gridUniforms {
            gridUniformBuffer.contents().copyMemory(
                from: &gridUniforms, byteCount: MemoryLayout<Uniforms>.stride
            )
        } else {
            handleError(.bufferAllocationFailed, bufferResources.gridUniforms!.label!)
            return
        }

        // create the encoder

        guard let encoderDescriptor = renderInfo.environmentRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Environment render pass descriptor not initialized")
            return
        }
        encoderDescriptor.colorAttachments[0].clearColor = mtkBackgroundColor
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Grid Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Grid Pass"

        renderEncoder.pushDebugGroup("Grid Pass")

        renderEncoder.setRenderPipelineState(gridPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(gridPipeline.depthState)

        // send the uniforms
        renderEncoder.setVertexBuffer(
            bufferResources.gridVertexBuffer, offset: 0, index: Int(gridPassPositionIndex.rawValue)
        )

        renderEncoder.setVertexBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue)
        )

        renderEncoder.setFragmentBuffer(
            bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue)
        )

        // send buffer data

        renderEncoder.drawPrimitivesTracked(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let executeEnvironmentPass: RenderPassExecution = { commandBuffer in
        guard let environmentPipeline = PipelineManager.shared.renderPipelinesByType[.environment] else {
            handleError(.pipelineStateNulled, "environmentPipeline is nil")
            return
        }

        if environmentPipeline.success == false {
            handleError(.pipelineStateNulled, environmentPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.environmentRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Environment render pass descriptor not initialized")
            return
        }

        encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
        encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
        encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Environment Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Environment Pass"

        renderEncoder.pushDebugGroup("Environment Pass")

        renderEncoder.setCullMode(.back)

        renderEncoder.setFrontFacing(.clockwise)

        renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)

        var environmentConstants = EnvironmentConstants()
        environmentConstants.modelMatrix = matrix4x4Identity()
        environmentConstants.environmentRotation = matrix4x4Identity()
        environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
        environmentConstants.viewMatrix = cameraComponent.viewSpace

        // remove the translational part of the view matrix to make the environment stay "infinitely" far away
        environmentConstants.viewMatrix.columns.3 = simd_float4(0.0, 0.0, 0.0, 1.0)

        //    let viewports = drawable.views.map { $0.textureMap.viewport }
        //
        //    renderEncoder.setViewports(viewports)
        //
        //    if drawable.views.count > 1 {
        //        var viewMappings = (0..<drawable.views.count).map {
        //            MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
        //                                              renderTargetArrayIndexOffset: UInt32($0))
        //        }
        //        renderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
        //    }
        //
        for (index, element) in environmentMesh.vertexDescriptor.layouts.enumerated() {
            guard let layout = element as? MDLVertexBufferLayout else {
                return
            }

            if layout.stride != 0 {
                let buffer = environmentMesh.vertexBuffers[index]
                renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
            }
        }

        renderEncoder.setVertexBytes(
            &environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride,
            index: Int(envPassConstantIndex.rawValue)
        )

        var environmentRotationAngle = envRotationAngle
        renderEncoder.setVertexBytes(
            &environmentRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(envPassRotationAngleIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(textureResources.environmentTexture, index: 0)

        for submesh in environmentMesh.submeshes {
            renderEncoder.drawIndexedPrimitivesTracked(
                type: submesh.primitiveType,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset
            )
        }
    }

    public static let shadowExecution: RenderPassExecution = { commandBuffer in
        // XR: shadow map is shared; only render cascades on eye 0.
        if renderInfo.isXRStereoMode, renderInfo.currentEye > 0 { return }

        guard let shadowPipeline = PipelineManager.shared.renderPipelinesByType[.shadow] else {
            handleError(.pipelineStateNulled, "shadowPipeline is nil")
            return
        }
        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        shadowSystem.updateCascades()
        guard shadowSystem.isActive else { return }
        guard !renderInfo.csmRenderPassDescriptors.isEmpty else { return }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)

        // Render each cascade into its own depth array slice.
        for cascadeIdx in 0 ..< csmCascadeCount {
            guard cascadeIdx < renderInfo.csmRenderPassDescriptors.count else { break }
            let descriptor = renderInfo.csmRenderPassDescriptors[cascadeIdx]
            descriptor.depthAttachment.loadAction = .clear
            descriptor.depthAttachment.storeAction = .store
            descriptor.depthAttachment.clearDepth = 1.0

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                handleError(.renderPassCreationFailed, "Shadow Cascade \(cascadeIdx)")
                continue
            }

            renderEncoder.label = "Shadow Cascade \(cascadeIdx)"
            renderEncoder.pushDebugGroup("Shadow Cascade \(cascadeIdx)")
            renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
            renderEncoder.setDepthStencilState(shadowPipeline.depthState!)
            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
            renderEncoder.setDepthBias(0.0015, slopeScale: 0.75, clamp: 0.02)
            renderEncoder.setViewport(
                MTLViewport(originX: 0, originY: 0,
                            width: Double(shadowResolution.x), height: Double(shadowResolution.y),
                            znear: 0, zfar: 1)
            )

            var effectiveLightMatrix = SceneRootTransform.shared.effectiveLightMatrix(
                shadowSystem.cascadeLightSpaceMatrices[cascadeIdx]
            )
            renderEncoder.setVertexBytes(
                &effectiveLightMatrix, length: MemoryLayout<simd_float4x4>.stride,
                index: Int(shadowPassLightMatrixUniform.rawValue)
            )

            let shadowCasterIds = shadowCasterEntityIds(for: cascadeIdx)
            for entityId in shadowCasterIds {
                guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { continue }
                guard let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else { continue }
                guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else { continue }

                for mesh in renderComponent.mesh {
                    var modelUniforms = Uniforms()
                    var modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)
                    let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                    let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
                    let normalMatrix = upperModelMatrix.inverse.transpose

                    modelUniforms.modelViewMatrix = modelViewMatrix
                    modelUniforms.normalMatrix = normalMatrix
                    modelUniforms.viewMatrix = viewMatrix
                    modelUniforms.modelMatrix = modelMatrix
                    modelUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                    modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                    renderEncoder.setVertexBytes(
                        &modelUniforms, length: MemoryLayout<Uniforms>.stride,
                        index: Int(shadowPassModelUniform.rawValue)
                    )
                    renderEncoder.bindShadowVertexStreams(mesh: mesh, entityId: entityId)

                    for subMesh in mesh.submeshes {
                        renderEncoder.drawIndexedPrimitivesTracked(
                            type: subMesh.metalKitSubmesh.primitiveType,
                            indexCount: subMesh.metalKitSubmesh.indexCount,
                            indexType: subMesh.metalKitSubmesh.indexType,
                            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                            category: .shadow
                        )
                    }
                }
            }

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
    }

    public static let batchedShadowExecution: RenderPassExecution = { commandBuffer in
        guard BatchingSystem.shared.isEnabled() else { return }

        // XR: shadow map shared; skip on eye 1.
        if renderInfo.isXRStereoMode, renderInfo.currentEye > 0 { return }

        guard let shadowPipeline = PipelineManager.shared.renderPipelinesByType[.shadow] else {
            handleError(.pipelineStateNulled, "shadowPipeline is nil")
            return
        }
        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        // Cascades were already computed by shadowExecution.
        guard shadowSystem.isActive else { return }
        guard !renderInfo.csmRenderPassDescriptors.isEmpty else { return }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        var batchUniforms = Uniforms()
        batchUniforms.modelMatrix = matrix_identity_float4x4
        batchUniforms.viewMatrix = viewMatrix
        batchUniforms.modelViewMatrix = viewMatrix
        batchUniforms.normalMatrix = matrix_identity_float3x3
        batchUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

        for cascadeIdx in 0 ..< csmCascadeCount {
            guard cascadeIdx < renderInfo.csmRenderPassDescriptors.count else { break }

            // Batched geometry adds into the existing cascade depth slice (already written by shadowExecution).
            let descriptor = renderInfo.csmRenderPassDescriptors[cascadeIdx]
            descriptor.depthAttachment.loadAction = .load

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                handleError(.renderPassCreationFailed, "Batched Shadow Cascade \(cascadeIdx)")
                continue
            }

            renderEncoder.label = "Batched Shadow Cascade \(cascadeIdx)"
            renderEncoder.pushDebugGroup("Batched Shadow Cascade \(cascadeIdx)")
            renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
            renderEncoder.setDepthStencilState(shadowPipeline.depthState!)
            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
            renderEncoder.setDepthBias(0.0015, slopeScale: 0.75, clamp: 0.02)
            renderEncoder.setViewport(
                MTLViewport(originX: 0, originY: 0,
                            width: Double(shadowResolution.x), height: Double(shadowResolution.y),
                            znear: 0, zfar: 1)
            )

            var effectiveLightMatrix = SceneRootTransform.shared.effectiveLightMatrix(
                shadowSystem.cascadeLightSpaceMatrices[cascadeIdx]
            )
            renderEncoder.setVertexBytes(
                &effectiveLightMatrix, length: MemoryLayout<simd_float4x4>.stride,
                index: Int(shadowPassLightMatrixUniform.rawValue)
            )

            let shadowBatchGroups = shadowCasterBatchGroups(for: cascadeIdx)
            for batchGroup in shadowBatchGroups {
                guard let positionBuffer = batchGroup.positionBuffer,
                      let indexBuffer = batchGroup.indexBuffer
                else { continue }

                renderEncoder.setVertexBytes(&batchUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(shadowPassModelUniform.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassModelPositionIndex.rawValue))

                var hasArmature = false
                renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(shadowPassHasArmature.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointIdIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointWeightsIndex.rawValue))
                var identity = matrix_identity_float4x4
                renderEncoder.setVertexBytes(&identity, length: MemoryLayout<simd_float4x4>.stride, index: Int(shadowPassJointTransformIndex.rawValue))

                renderEncoder.drawIndexedPrimitivesTracked(
                    type: .triangle,
                    indexCount: batchGroup.indexCount,
                    indexType: .uint32,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0,
                    category: .shadow,
                    batched: true
                )
            }

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
    }

    public static let spotShadowExecution: RenderPassExecution = { commandBuffer in
        if renderInfo.isXRStereoMode, renderInfo.currentEye > 0 { return }

        spotShadowState.update()
        guard spotShadowState.isActive else { return }

        guard let shadowPipeline = PipelineManager.shared.renderPipelinesByType[.shadow] else {
            handleError(.pipelineStateNulled, "shadowPipeline is nil")
            return
        }
        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        guard let descriptor = renderInfo.spotShadowRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Spot Shadow descriptor not initialized")
            return
        }
        descriptor.depthAttachment.loadAction = .clear
        descriptor.depthAttachment.storeAction = .store
        descriptor.depthAttachment.clearDepth = 1.0

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            handleError(.renderPassCreationFailed, "Spot Shadow")
            return
        }

        renderEncoder.label = "Spot Shadow"
        renderEncoder.pushDebugGroup("Spot Shadow")
        renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(shadowPipeline.depthState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        renderEncoder.setDepthBias(0.0015, slopeScale: 0.75, clamp: 0.02)
        renderEncoder.setViewport(
            MTLViewport(originX: 0, originY: 0,
                        width: Double(shadowResolution.x), height: Double(shadowResolution.y),
                        znear: 0, zfar: 1)
        )

        var effectiveLightMatrix = SceneRootTransform.shared.effectiveLightMatrix(spotShadowState.lightSpaceMatrix)
        renderEncoder.setVertexBytes(
            &effectiveLightMatrix,
            length: MemoryLayout<simd_float4x4>.stride,
            index: Int(shadowPassLightMatrixUniform.rawValue)
        )

        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        for entityId in spotShadowCasterEntityIds() {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  scene.get(component: LocalTransformComponent.self, for: entityId) != nil
            else { continue }

            for mesh in renderComponent.mesh {
                var modelUniforms = Uniforms()
                let modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)
                modelUniforms.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                modelUniforms.normalMatrix = matrix3x3_upper_left(modelMatrix).inverse.transpose
                modelUniforms.viewMatrix = viewMatrix
                modelUniforms.modelMatrix = modelMatrix
                modelUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                renderEncoder.setVertexBytes(&modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(shadowPassModelUniform.rawValue))
                renderEncoder.bindShadowVertexStreams(mesh: mesh, entityId: entityId)

                for subMesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                        category: .shadow
                    )
                }
            }
        }

        if BatchingSystem.shared.isEnabled() {
            var batchUniforms = Uniforms()
            batchUniforms.modelMatrix = matrix_identity_float4x4
            batchUniforms.viewMatrix = viewMatrix
            batchUniforms.modelViewMatrix = viewMatrix
            batchUniforms.normalMatrix = matrix_identity_float3x3
            batchUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
            batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

            for batchGroup in spotShadowCasterBatchGroups() {
                guard let positionBuffer = batchGroup.positionBuffer,
                      let indexBuffer = batchGroup.indexBuffer
                else { continue }

                renderEncoder.setVertexBytes(&batchUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(shadowPassModelUniform.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassModelPositionIndex.rawValue))

                var hasArmature = false
                renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(shadowPassHasArmature.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointIdIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointWeightsIndex.rawValue))
                var identity = matrix_identity_float4x4
                renderEncoder.setVertexBytes(&identity, length: MemoryLayout<simd_float4x4>.stride, index: Int(shadowPassJointTransformIndex.rawValue))

                renderEncoder.drawIndexedPrimitivesTracked(
                    type: .triangle,
                    indexCount: batchGroup.indexCount,
                    indexType: .uint32,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0,
                    category: .shadow,
                    batched: true
                )
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
    }

    public static let pointShadowExecution: RenderPassExecution = { commandBuffer in
        if renderInfo.isXRStereoMode, renderInfo.currentEye > 0 { return }

        pointShadowState.update()
        guard pointShadowState.isActive else { return }

        guard let shadowPipeline = PipelineManager.shared.renderPipelinesByType[.shadow] else {
            handleError(.pipelineStateNulled, "shadowPipeline is nil")
            return
        }
        if shadowPipeline.success == false {
            handleError(.pipelineStateNulled, shadowPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let casterEntityIds = pointShadowCasterEntityIds()
        let batchGroups = BatchingSystem.shared.isEnabled() ? pointShadowCasterBatchGroups() : []

        for face in 0 ..< min(renderInfo.pointShadowRenderPassDescriptors.count, pointShadowState.lightSpaceMatrices.count) {
            let descriptor = renderInfo.pointShadowRenderPassDescriptors[face]
            descriptor.depthAttachment.loadAction = .clear
            descriptor.depthAttachment.storeAction = .store
            descriptor.depthAttachment.clearDepth = 1.0
            descriptor.depthAttachment.slice = face

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                handleError(.renderPassCreationFailed, "Point Shadow")
                return
            }

            renderEncoder.label = "Point Shadow Face \(face)"
            renderEncoder.pushDebugGroup("Point Shadow Face \(face)")
            renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
            renderEncoder.setDepthStencilState(shadowPipeline.depthState!)
            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
            renderEncoder.setDepthBias(0.002, slopeScale: 0.9, clamp: 0.03)
            renderEncoder.setViewport(
                MTLViewport(originX: 0, originY: 0,
                            width: Double(shadowResolution.x), height: Double(shadowResolution.y),
                            znear: 0, zfar: 1)
            )

            var effectiveLightMatrix = SceneRootTransform.shared.effectiveLightMatrix(pointShadowState.lightSpaceMatrices[face])
            renderEncoder.setVertexBytes(
                &effectiveLightMatrix,
                length: MemoryLayout<simd_float4x4>.stride,
                index: Int(shadowPassLightMatrixUniform.rawValue)
            )

            for entityId in casterEntityIds {
                guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                      let transformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                      scene.get(component: LocalTransformComponent.self, for: entityId) != nil
                else { continue }

                for mesh in renderComponent.mesh {
                    var modelUniforms = Uniforms()
                    let modelMatrix = simd_mul(transformComponent.space, mesh.localSpace)
                    modelUniforms.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                    modelUniforms.normalMatrix = matrix3x3_upper_left(modelMatrix).inverse.transpose
                    modelUniforms.viewMatrix = viewMatrix
                    modelUniforms.modelMatrix = modelMatrix
                    modelUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                    modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                    renderEncoder.setVertexBytes(&modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(shadowPassModelUniform.rawValue))
                    renderEncoder.bindShadowVertexStreams(mesh: mesh, entityId: entityId)

                    for subMesh in mesh.submeshes {
                        renderEncoder.drawIndexedPrimitivesTracked(
                            type: subMesh.metalKitSubmesh.primitiveType,
                            indexCount: subMesh.metalKitSubmesh.indexCount,
                            indexType: subMesh.metalKitSubmesh.indexType,
                            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                            category: .shadow
                        )
                    }
                }
            }

            if BatchingSystem.shared.isEnabled() {
                var batchUniforms = Uniforms()
                batchUniforms.modelMatrix = matrix_identity_float4x4
                batchUniforms.viewMatrix = viewMatrix
                batchUniforms.modelViewMatrix = viewMatrix
                batchUniforms.normalMatrix = matrix_identity_float3x3
                batchUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

                for batchGroup in batchGroups {
                    guard let positionBuffer = batchGroup.positionBuffer,
                          let indexBuffer = batchGroup.indexBuffer
                    else { continue }

                    renderEncoder.setVertexBytes(&batchUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(shadowPassModelUniform.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassModelPositionIndex.rawValue))

                    var hasArmature = false
                    renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(shadowPassHasArmature.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointIdIndex.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(shadowPassJointWeightsIndex.rawValue))
                    var identity = matrix_identity_float4x4
                    renderEncoder.setVertexBytes(&identity, length: MemoryLayout<simd_float4x4>.stride, index: Int(shadowPassJointTransformIndex.rawValue))

                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: .triangle,
                        indexCount: batchGroup.indexCount,
                        indexType: .uint32,
                        indexBuffer: indexBuffer,
                        indexBufferOffset: 0,
                        category: .shadow,
                        batched: true
                    )
                }
            }

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }
    }

    public static let modelExecution: RenderPassExecution = { commandBuffer in
        guard let modelPipeline = PipelineManager.shared.renderPipelinesByType[.model] else {
            handleError(.pipelineStateNulled, "modelPipeline is nil")
            return
        }

        if modelPipeline.success == false {
            handleError(.pipelineStateNulled, modelPipeline.name!)
            return
        }
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Offscreen render pass descriptor not initialized")
            return
        }

        encoderDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .loadAction = .clear
        encoderDescriptor.colorAttachments[Int(materialTarget.rawValue)].loadAction = .clear
        encoderDescriptor.colorAttachments[Int(emissiveTarget.rawValue)].loadAction = .clear

        encoderDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .storeAction = .store

        encoderDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(materialTarget.rawValue)]
            .storeAction = .store
        encoderDescriptor.colorAttachments[Int(emissiveTarget.rawValue)]
            .storeAction = .store

        encoderDescriptor.depthAttachment.storeAction = .store
        encoderDescriptor.depthAttachment.loadAction = .clear
        encoderDescriptor.depthAttachment.clearDepth = sceneDepthClearValue()

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Model Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Model Pass"

        renderEncoder.pushDebugGroup("Model Pass")

        renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(modelPipeline.depthState)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        // Create a component query for entities with both Transform and Render components

        // Iterate over the entities found by the component query
        for entityId in visibleEntityIds {
            // Skip entities that are pending destroy
            if scene.mask(for: entityId) == nil { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }

            // Skip batched entities if batching is enabled
            if BatchingSystem.shared.isEnabled(),
               BatchingSystem.shared.isBatched(entityId: entityId),
               !isEntityInActiveLODFade(entityId),
               !isEntityInActiveTileRepresentationFade(entityId)
            {
                continue
            }

            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                handleError(.noRenderComponent, entityId)
                continue
            }

            guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                handleError(.noWorldTransformComponent, entityId)
                continue
            }

            guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                handleError(.noLocalTransformComponent, entityId)
                continue
            }

            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) {
                continue
            }

            if hasComponent(entityId: entityId, componentType: LightComponent.self) {
                continue
            }

            for lodDraw in opaqueLODDraws(entityId: entityId, renderComponent: renderComponent) {
                for mesh in lodDraw.meshes {
                    // update uniforms
                    var modelUniforms = Uniforms()

                    let rootMatrix = worldTransformComponent.space
                    var modelMatrix = simd_mul(rootMatrix, mesh.localSpace)

                    let viewMatrix: simd_float4x4 = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)

                    let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

                    let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

                    let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

                    let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

                    modelUniforms.modelViewMatrix = modelViewMatrix

                    modelUniforms.normalMatrix = normalMatrix

                    modelUniforms.viewMatrix = viewMatrix

                    modelUniforms.modelMatrix = modelMatrix

                    modelUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

                    modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                    renderEncoder.setVertexBytes(
                        &modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassUniformIndex.rawValue)
                    )

                    renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

                    renderEncoder.setFragmentBytes(
                        &modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassFragmentUniformIndex.rawValue)
                    )

                    for subMesh in mesh.submeshes {
                        guard let material = subMesh.material else { continue }

                        // Blend-mode submeshes are rendered in the transparency pass.
                        if material.alphaMode == .blend {
                            continue
                        }

                        var stScale: Float = material.stScale

                        renderEncoder.setFragmentBytes(&stScale, length: MemoryLayout<Float>.stride, index: Int(modelPassFragmentSTScaleIndex.rawValue))

                        // set base texture
                        renderEncoder.setFragmentTexture(
                            material.baseColor.texture, index: Int(modelPassBaseTextureIndex.rawValue)
                        )

                        renderEncoder.setFragmentSamplerState(material.baseColor.sampler, index: Int(modelPassBaseSamplerIndex.rawValue))

                        // set roughness
                        renderEncoder.setFragmentTexture(
                            material.roughness.texture, index: Int(modelPassRoughnessTextureIndex.rawValue)
                        )

                        renderEncoder.setFragmentSamplerState(material.roughness.sampler, index: Int(modelPassMaterialSamplerIndex.rawValue))

                        // set metallic
                        renderEncoder.setFragmentTexture(
                            material.metallic.texture, index: Int(modelPassMetallicTextureIndex.rawValue)
                        )

                        // set normal
                        // set normal
                        var hasNormal: Bool = (material.normal.texture != nil)
                        renderEncoder.setFragmentBytes(
                            &hasNormal, length: MemoryLayout<Bool>.stride,
                            index: Int(modelPassFragmentHasNormalTextureIndex.rawValue)
                        )

                        var materialParameters = MaterialParametersUniform()
                        materialParameters.specular = material.specular
                        materialParameters.specularTint = material.specularTint
                        materialParameters.subsurface = material.subsurface
                        materialParameters.anisotropic = material.anisotropic
                        materialParameters.sheen = material.sheen
                        materialParameters.sheenTint = material.sheenTint
                        materialParameters.clearCoat = material.clearCoat
                        materialParameters.clearCoatGloss = material.clearCoatGloss
                        materialParameters.baseColor = material.baseColorValue
                        materialParameters.roughness = material.roughnessValue
                        materialParameters.metallic = material.metallicValue
                        materialParameters.ior = material.ior
                        materialParameters.edgeTint = material.edgeTint
                        materialParameters.alphaCutoff = material.alphaCutoff
                        materialParameters.passthroughAlpha = passthroughGhostAlpha(for: entityId)
                        materialParameters.alphaMode = Int32(material.alphaMode.rawValue)
                        materialParameters.interactWithLight = material.interactWithLight
                        materialParameters.emmissive = material.emissiveValue

                        applyMaterialTextureState(material: material, materialParameters: &materialParameters)
                        applyLODDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)
                        applyStreamingTierDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)
                        applyLODDither(draw: lodDraw, materialParameters: &materialParameters)
                        applyTileRepresentationDither(entityId: entityId, materialParameters: &materialParameters)

                        renderEncoder.setFragmentBytes(
                            &materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride,
                            index: Int(modelPassFragmentMaterialParameterIndex.rawValue)
                        )

                        renderEncoder.setFragmentTexture(
                            material.normal.texture, index: Int(modelPassNormalTextureIndex.rawValue)
                        )

                        renderEncoder.setFragmentSamplerState(material.normal.sampler, index: Int(modelPassNormalSamplerIndex.rawValue))

                        renderEncoder.drawIndexedPrimitivesTracked(
                            type: subMesh.metalKitSubmesh.primitiveType,
                            indexCount: subMesh.metalKitSubmesh.indexCount,
                            indexType: subMesh.metalKitSubmesh.indexType,
                            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                            category: .opaque
                        )
                    }
                }
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let batchedModelExecution: RenderPassExecution = { commandBuffer in
        // Skip if batching is disabled
        guard BatchingSystem.shared.isEnabled() else { return }

        // The standalone batched pass reopens the G-buffer with .load. MSAA G-buffer
        // attachments are memoryless, so batched geometry must be drawn in the
        // combined TBDR model/light pass when multisampling is active.
        guard renderInfo.opaqueSampleCount == 1 else { return }

        // Cluster-level frustum cull: test each batch group's precomputed world-space
        // AABB against the current-frame frustum.  One AABB test per batch group instead
        // of one per entity — avoids the entity→batchId lookup entirely.
        let visibleBatchGroups = visibleBatchGroupsSnapshot()
        guard !visibleBatchGroups.isEmpty else { return }

        guard let modelPipeline = PipelineManager.shared.renderPipelinesByType[.model] else {
            handleError(.pipelineStateNulled, "modelPipeline is nil")
            return
        }

        if modelPipeline.success == false {
            handleError(.pipelineStateNulled, modelPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Offscreen render pass descriptor not initialized")
            return
        }

        // Reuse existing offscreen descriptor (already configured by modelExecution)
        encoderDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = .load
        encoderDescriptor.colorAttachments[Int(normalTarget.rawValue)].loadAction = .load
        encoderDescriptor.colorAttachments[Int(positionTarget.rawValue)].loadAction = .load
        encoderDescriptor.colorAttachments[Int(materialTarget.rawValue)].loadAction = .load
        encoderDescriptor.colorAttachments[Int(emissiveTarget.rawValue)].loadAction = .load
        encoderDescriptor.depthAttachment.loadAction = .load

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Batched Model Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Batched Model Pass"
        renderEncoder.pushDebugGroup("Batched Model Pass")

        renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(modelPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        // Create identity uniform (batched vertices are already in world space)
        var batchUniforms = Uniforms()
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let modelMatrix = matrix_identity_float4x4
        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix) // Same calculation as modelExecution
        let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

        let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

        let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose
        /*
         // update uniforms
         var modelUniforms = Uniforms()

         var modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)

         let viewMatrix: simd_float4x4 = cameraComponent.viewSpace

         let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

         let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

         let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

         let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose
         */

        batchUniforms.modelMatrix = modelMatrix
        batchUniforms.viewMatrix = viewMatrix
        batchUniforms.modelViewMatrix = modelViewMatrix
        batchUniforms.normalMatrix = normalMatrix
        batchUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

        // Render only batch groups that contain at least one visible entity.
        for batchGroup in visibleBatchGroups {
            guard let positionBuffer = batchGroup.positionBuffer,
                  let normalBuffer = batchGroup.normalBuffer,
                  let uvBuffer = batchGroup.uvBuffer,
                  let tangentBuffer = batchGroup.tangentBuffer,
                  let indexBuffer = batchGroup.indexBuffer
            else { continue }

            // Use the material captured when this batch was built.
            // This guarantees batched shading matches the grouped submesh material.
            let material = batchGroup.material

            if shouldRenderSceneChannelsAsWireframe(batchGroup.sceneChannels) {
                continue
            }

            // Blend-mode materials are rendered in the transparency pass.
            if material.hasTransparency {
                continue
            }

            // Set uniforms
            renderEncoder.setVertexBytes(
                &batchUniforms,
                length: MemoryLayout<Uniforms>.stride,
                index: Int(modelPassUniformIndex.rawValue)
            )

            // Set vertex buffers - now using separate buffers for each attribute
            renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassVerticesIndex.rawValue))
            renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: Int(modelPassNormalIndex.rawValue))
            renderEncoder.setVertexBuffer(uvBuffer, offset: 0, index: Int(modelPassUVIndex.rawValue))
            renderEncoder.setVertexBuffer(tangentBuffer, offset: 0, index: Int(modelPassTangentIndex.rawValue))

            // Static batched objects don't have armature, but shader expects these buffers
            // Set dummy buffers for joint data to avoid validation errors
            renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointIdIndex.rawValue)) // Dummy buffer
            renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointWeightsIndex.rawValue)) // Dummy buffer

            // Create a minimal dummy joint transform buffer (single identity matrix)
            // This is required because Metal validation doesn't allow nil buffers
            var identityMatrix = matrix_identity_float4x4
            renderEncoder.setVertexBytes(&identityMatrix, length: MemoryLayout<simd_float4x4>.stride, index: Int(modelPassJointTransformIndex.rawValue))

            // No armature for static batched objects
            var hasArmature = false
            renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(modelPassHasArmature.rawValue))

            // Set fragment uniforms
            renderEncoder.setFragmentBytes(
                &batchUniforms,
                length: MemoryLayout<Uniforms>.stride,
                index: Int(modelPassFragmentUniformIndex.rawValue)
            )

            // Set material properties (same as normal rendering)
            var stScale: Float = material.stScale
            renderEncoder.setFragmentBytes(&stScale, length: MemoryLayout<Float>.stride, index: Int(modelPassFragmentSTScaleIndex.rawValue))

            renderEncoder.setFragmentTexture(material.baseColor.texture, index: Int(modelPassBaseTextureIndex.rawValue))
            renderEncoder.setFragmentSamplerState(material.baseColor.sampler, index: Int(modelPassBaseSamplerIndex.rawValue))

            renderEncoder.setFragmentTexture(material.roughness.texture, index: Int(modelPassRoughnessTextureIndex.rawValue))
            renderEncoder.setFragmentSamplerState(material.roughness.sampler, index: Int(modelPassMaterialSamplerIndex.rawValue))

            // Set metallic texture
            renderEncoder.setFragmentTexture(material.metallic.texture, index: Int(modelPassMetallicTextureIndex.rawValue))

            var hasNormal: Bool = (material.normal.texture != nil)
            renderEncoder.setFragmentBytes(&hasNormal, length: MemoryLayout<Bool>.stride, index: Int(modelPassFragmentHasNormalTextureIndex.rawValue))
            // Logger.log(message: "  🎨 Material baseColor: \(material.baseColorValue)")
            var materialParameters = MaterialParametersUniform()
            materialParameters.specular = material.specular
            materialParameters.specularTint = material.specularTint
            materialParameters.subsurface = material.subsurface
            materialParameters.anisotropic = material.anisotropic
            materialParameters.sheen = material.sheen
            materialParameters.sheenTint = material.sheenTint
            materialParameters.clearCoat = material.clearCoat
            materialParameters.clearCoatGloss = material.clearCoatGloss
            materialParameters.baseColor = material.baseColorValue
            materialParameters.roughness = material.roughnessValue
            materialParameters.metallic = material.metallicValue
            materialParameters.ior = material.ior
            materialParameters.edgeTint = material.edgeTint
            materialParameters.alphaCutoff = material.alphaCutoff
            materialParameters.passthroughAlpha = passthroughGhostAlpha(for: batchGroup)
            materialParameters.alphaMode = Int32(material.alphaMode.rawValue)
            materialParameters.interactWithLight = material.interactWithLight
            materialParameters.emmissive = material.emissiveValue

            applyMaterialTextureState(material: material, materialParameters: &materialParameters)
            applyLODDebugColorOverride(
                batchGroup: batchGroup,
                materialParameters: &materialParameters
            )
            applyStreamingTierDebugColorOverride(batchMaterial: material, materialParameters: &materialParameters)

            renderEncoder.setFragmentBytes(
                &materialParameters,
                length: MemoryLayout<MaterialParametersUniform>.stride,
                index: Int(modelPassFragmentMaterialParameterIndex.rawValue)
            )

            renderEncoder.setFragmentTexture(material.normal.texture, index: Int(modelPassNormalTextureIndex.rawValue))
            renderEncoder.setFragmentSamplerState(material.normal.sampler, index: Int(modelPassNormalSamplerIndex.rawValue))

            // SINGLE DRAW CALL FOR ENTIRE BATCH
            // Logger.log(message: "✅ Drawing batch \(batchGroup.id): \(batchGroup.indexCount) indices, \(batchGroup.vertexCount) vertices")
            renderEncoder.drawIndexedPrimitivesTracked(
                type: .triangle,
                indexCount: batchGroup.indexCount,
                indexType: .uint32,
                indexBuffer: indexBuffer,
                indexBufferOffset: 0,
                category: .opaque,
                batched: true
            )
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Combined G-buffer + lighting pass (TBDR)

    ///
    /// Merges model geometry, batched geometry, and the lighting quad into a single
    /// MTLRenderCommandEncoder. Because all three sub-passes share one encoder, the
    /// five G-buffer attachments (albedo, normal, position, material, emissive)
    /// normally live only in GPU tile memory and never hit main memory. G-buffer
    /// debug views temporarily store them so a later fullscreen pass can sample
    /// the selected channel. The lit result is written to attachment 5
    /// (deferredColorMap), which is always stored for downstream passes.
    public static let combinedModelLightExecution: RenderPassExecution = { commandBuffer in
        guard let modelPipeline = PipelineManager.shared.renderPipelinesByType[.model],
              modelPipeline.success,
              let lightPipeline = PipelineManager.shared.renderPipelinesByType[.light],
              lightPipeline.success
        else { return }

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Combined G-buffer + Light Pass descriptor not initialized")
            return
        }

        // G-buffer slots (0-4): cleared at start, normally discarded at end.
        // Lit output (5): cleared at start, stored for downstream passes.
        // The simulator always stores the G-buffer: its light pass samples it as
        // textures because framebuffer fetch is unsupported there.
        #if targetEnvironment(simulator)
            let gBufferStoreAction: MTLStoreAction = .store
        #else
            let gBufferStoreAction: MTLStoreAction = renderInfo.gBufferDebugStorageEnabled ? .store : .dontCare
        #endif
        for i in 0 ..< 5 {
            encoderDescriptor.colorAttachments[i].loadAction = .clear
            encoderDescriptor.colorAttachments[i].storeAction = gBufferStoreAction
        }
        encoderDescriptor.colorAttachments[5].loadAction = .clear
        encoderDescriptor.colorAttachments[5].storeAction = renderInfo.opaqueSampleCount > 1 ? .multisampleResolve : .store
        encoderDescriptor.depthAttachment.loadAction = .clear
        encoderDescriptor.depthAttachment.storeAction = renderInfo.opaqueSampleCount > 1 ? .multisampleResolve : .store
        encoderDescriptor.depthAttachment.clearDepth = sceneDepthClearValue()

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor) else {
            handleError(.renderPassCreationFailed, "Combined G-buffer + Light Pass")
            return
        }

        // Both paths end this encoder explicitly (the simulator path ends it
        // mid-function and continues in a second one), so the defer is a
        // safety net only: it fires solely if a future early return leaves
        // the encoder open. Note the device path's final close is this same
        // encoder via lightQuadEncoder, so the flag must be set there too.
        var combinedEncoderClosed = false
        defer {
            if !combinedEncoderClosed {
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
            }
        }

        renderEncoder.label = "G-Buffer + Light Pass (TBDR)"
        renderEncoder.pushDebugGroup("G-Buffer + Light Pass (TBDR)")

        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)

        // ── Sub-pass 1: Unbatched geometry ──────────────────────────────────────
        renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
        renderEncoder.setDepthStencilState(modelPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        for entityId in visibleEntityIds {
            if scene.mask(for: entityId) == nil { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }
            if BatchingSystem.shared.isEnabled(),
               BatchingSystem.shared.isBatched(entityId: entityId),
               !isEntityInActiveLODFade(entityId),
               !isEntityInActiveTileRepresentationFade(entityId)
            { continue }
            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }
            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { continue }
            if hasComponent(entityId: entityId, componentType: LightComponent.self) { continue }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { continue }
            guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else { continue }
            guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else { continue }

            for lodDraw in opaqueLODDraws(entityId: entityId, renderComponent: renderComponent) {
                for mesh in lodDraw.meshes {
                    var modelUniforms = Uniforms()
                    let modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)
                    let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                    let normalMatrix = matrix3x3_upper_left(modelMatrix).inverse.transpose

                    modelUniforms.modelViewMatrix = modelViewMatrix
                    modelUniforms.normalMatrix = normalMatrix
                    modelUniforms.viewMatrix = viewMatrix
                    modelUniforms.modelMatrix = modelMatrix
                    modelUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                    modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                    renderEncoder.setVertexBytes(&modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassUniformIndex.rawValue))

                    renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

                    renderEncoder.setFragmentBytes(&modelUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassFragmentUniformIndex.rawValue))

                    for subMesh in mesh.submeshes {
                        guard let material = subMesh.material else { continue }
                        if material.alphaMode == .blend { continue }

                        var stScale: Float = material.stScale
                        renderEncoder.setFragmentBytes(&stScale, length: MemoryLayout<Float>.stride, index: Int(modelPassFragmentSTScaleIndex.rawValue))
                        renderEncoder.setFragmentTexture(material.baseColor.texture, index: Int(modelPassBaseTextureIndex.rawValue))
                        renderEncoder.setFragmentSamplerState(material.baseColor.sampler, index: Int(modelPassBaseSamplerIndex.rawValue))
                        renderEncoder.setFragmentTexture(material.roughness.texture, index: Int(modelPassRoughnessTextureIndex.rawValue))
                        renderEncoder.setFragmentSamplerState(material.roughness.sampler, index: Int(modelPassMaterialSamplerIndex.rawValue))
                        renderEncoder.setFragmentTexture(material.metallic.texture, index: Int(modelPassMetallicTextureIndex.rawValue))

                        var hasNormal = (material.normal.texture != nil)
                        renderEncoder.setFragmentBytes(&hasNormal, length: MemoryLayout<Bool>.stride, index: Int(modelPassFragmentHasNormalTextureIndex.rawValue))

                        var materialParameters = MaterialParametersUniform()
                        materialParameters.specular = material.specular
                        materialParameters.specularTint = material.specularTint
                        materialParameters.subsurface = material.subsurface
                        materialParameters.anisotropic = material.anisotropic
                        materialParameters.sheen = material.sheen
                        materialParameters.sheenTint = material.sheenTint
                        materialParameters.clearCoat = material.clearCoat
                        materialParameters.clearCoatGloss = material.clearCoatGloss
                        materialParameters.baseColor = material.baseColorValue
                        materialParameters.roughness = material.roughnessValue
                        materialParameters.metallic = material.metallicValue
                        materialParameters.ior = material.ior
                        materialParameters.edgeTint = material.edgeTint
                        materialParameters.alphaCutoff = material.alphaCutoff
                        materialParameters.passthroughAlpha = passthroughGhostAlpha(for: entityId)
                        materialParameters.alphaMode = Int32(material.alphaMode.rawValue)
                        materialParameters.interactWithLight = material.interactWithLight
                        materialParameters.emmissive = material.emissiveValue
                        applyMaterialTextureState(material: material, materialParameters: &materialParameters)
                        applyLODDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)
                        applyStreamingTierDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)
                        applyLODDither(draw: lodDraw, materialParameters: &materialParameters)
                        applyTileRepresentationDither(entityId: entityId, materialParameters: &materialParameters)

                        renderEncoder.setFragmentBytes(&materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride, index: Int(modelPassFragmentMaterialParameterIndex.rawValue))
                        renderEncoder.setFragmentTexture(material.normal.texture, index: Int(modelPassNormalTextureIndex.rawValue))
                        renderEncoder.setFragmentSamplerState(material.normal.sampler, index: Int(modelPassNormalSamplerIndex.rawValue))

                        renderEncoder.drawIndexedPrimitivesTracked(
                            type: subMesh.metalKitSubmesh.primitiveType,
                            indexCount: subMesh.metalKitSubmesh.indexCount,
                            indexType: subMesh.metalKitSubmesh.indexType,
                            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                            category: .opaque
                        )
                    }
                }
            }
        }

        // ── Sub-pass 1b: Batched geometry ───────────────────────────────────────
        if BatchingSystem.shared.isEnabled() {
            let visibleBatchGroups = visibleBatchGroupsSnapshot()
            if !visibleBatchGroups.isEmpty {
                var batchUniforms = Uniforms()
                let modelMatrix = matrix_identity_float4x4
                batchUniforms.modelMatrix = modelMatrix
                batchUniforms.viewMatrix = viewMatrix
                batchUniforms.modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                batchUniforms.normalMatrix = matrix3x3_upper_left(modelMatrix).inverse.transpose
                batchUniforms.cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
                batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

                for batchGroup in visibleBatchGroups {
                    guard let positionBuffer = batchGroup.positionBuffer,
                          let normalBuffer = batchGroup.normalBuffer,
                          let uvBuffer = batchGroup.uvBuffer,
                          let tangentBuffer = batchGroup.tangentBuffer,
                          let indexBuffer = batchGroup.indexBuffer
                    else { continue }

                    if shouldRenderSceneChannelsAsWireframe(batchGroup.sceneChannels) { continue }
                    let material = batchGroup.material
                    if material.hasTransparency { continue }

                    renderEncoder.setVertexBytes(&batchUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassUniformIndex.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassVerticesIndex.rawValue))
                    renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: Int(modelPassNormalIndex.rawValue))
                    renderEncoder.setVertexBuffer(uvBuffer, offset: 0, index: Int(modelPassUVIndex.rawValue))
                    renderEncoder.setVertexBuffer(tangentBuffer, offset: 0, index: Int(modelPassTangentIndex.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointIdIndex.rawValue))
                    renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointWeightsIndex.rawValue))

                    var hasArmature = false
                    renderEncoder.setVertexBytes(&hasArmature, length: MemoryLayout<Bool>.stride, index: Int(modelPassHasArmature.rawValue))
                    var identity = matrix_identity_float4x4
                    renderEncoder.setVertexBytes(&identity, length: MemoryLayout<simd_float4x4>.stride, index: Int(modelPassJointTransformIndex.rawValue))

                    renderEncoder.setFragmentBytes(&batchUniforms, length: MemoryLayout<Uniforms>.stride, index: Int(modelPassFragmentUniformIndex.rawValue))

                    var stScale: Float = material.stScale
                    renderEncoder.setFragmentBytes(&stScale, length: MemoryLayout<Float>.stride, index: Int(modelPassFragmentSTScaleIndex.rawValue))
                    renderEncoder.setFragmentTexture(material.baseColor.texture, index: Int(modelPassBaseTextureIndex.rawValue))
                    renderEncoder.setFragmentSamplerState(material.baseColor.sampler, index: Int(modelPassBaseSamplerIndex.rawValue))
                    renderEncoder.setFragmentTexture(material.roughness.texture, index: Int(modelPassRoughnessTextureIndex.rawValue))
                    renderEncoder.setFragmentSamplerState(material.roughness.sampler, index: Int(modelPassMaterialSamplerIndex.rawValue))
                    renderEncoder.setFragmentTexture(material.metallic.texture, index: Int(modelPassMetallicTextureIndex.rawValue))

                    var hasNormal = (material.normal.texture != nil)
                    renderEncoder.setFragmentBytes(&hasNormal, length: MemoryLayout<Bool>.stride, index: Int(modelPassFragmentHasNormalTextureIndex.rawValue))

                    var materialParameters = MaterialParametersUniform()
                    materialParameters.specular = material.specular
                    materialParameters.specularTint = material.specularTint
                    materialParameters.subsurface = material.subsurface
                    materialParameters.anisotropic = material.anisotropic
                    materialParameters.sheen = material.sheen
                    materialParameters.sheenTint = material.sheenTint
                    materialParameters.clearCoat = material.clearCoat
                    materialParameters.clearCoatGloss = material.clearCoatGloss
                    materialParameters.baseColor = material.baseColorValue
                    materialParameters.roughness = material.roughnessValue
                    materialParameters.metallic = material.metallicValue
                    materialParameters.ior = material.ior
                    materialParameters.edgeTint = material.edgeTint
                    materialParameters.alphaCutoff = material.alphaCutoff
                    materialParameters.passthroughAlpha = passthroughGhostAlpha(for: batchGroup)
                    materialParameters.alphaMode = Int32(material.alphaMode.rawValue)
                    materialParameters.interactWithLight = material.interactWithLight
                    materialParameters.emmissive = material.emissiveValue
                    applyMaterialTextureState(material: material, materialParameters: &materialParameters)
                    applyLODDebugColorOverride(batchGroup: batchGroup, materialParameters: &materialParameters)
                    applyStreamingTierDebugColorOverride(batchMaterial: material, materialParameters: &materialParameters)

                    renderEncoder.setFragmentBytes(&materialParameters, length: MemoryLayout<MaterialParametersUniform>.stride, index: Int(modelPassFragmentMaterialParameterIndex.rawValue))
                    renderEncoder.setFragmentTexture(material.normal.texture, index: Int(modelPassNormalTextureIndex.rawValue))
                    renderEncoder.setFragmentSamplerState(material.normal.sampler, index: Int(modelPassNormalSamplerIndex.rawValue))

                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: .triangle,
                        indexCount: batchGroup.indexCount,
                        indexType: .uint32,
                        indexBuffer: indexBuffer,
                        indexBufferOffset: 0,
                        category: .opaque,
                        batched: true
                    )
                }
            }
        }

        // ── Sub-pass 2: Lighting quad ────────────────────────────────────────────
        // Device: reads G-buffer from tile memory via [[color(N)]] framebuffer fetch
        // in the same encoder — no G-buffer textures are bound.
        // Simulator: framebuffer fetch is unsupported, so end the G-buffer encoder
        // (attachments were stored) and light in a second encoder that samples the
        // G-buffer textures with the texture-based fragmentLightShader.
        #if targetEnvironment(simulator)
            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
            combinedEncoderClosed = true

            guard let lightPassDescriptor = renderInfo.deferredRenderPassDescriptor else {
                handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
                return
            }
            // deferredColorMap was cleared by the G-buffer pass (attachment 5); the
            // fullscreen quad overwrites every pixel. Preserve opaque depth for
            // transparency and post-process consumers.
            lightPassDescriptor.colorAttachments[0].loadAction = .load
            lightPassDescriptor.colorAttachments[0].storeAction = .store
            lightPassDescriptor.depthAttachment.loadAction = .load
            lightPassDescriptor.depthAttachment.storeAction = .store

            guard let lightEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: lightPassDescriptor) else {
                handleError(.renderPassCreationFailed, "Light Pass (Simulator)")
                return
            }
            lightEncoder.label = "Light Pass (Simulator)"
            lightEncoder.pushDebugGroup("Light Pass (Simulator)")
            lightEncoder.waitForFence(renderInfo.fence, before: .fragment)

            // G-buffer textures (stored by the previous encoder).
            lightEncoder.setFragmentTexture(textureResources.colorMap, index: Int(lightPassAlbedoTextureIndex.rawValue))
            lightEncoder.setFragmentTexture(textureResources.normalMap, index: Int(lightPassNormalTextureIndex.rawValue))
            lightEncoder.setFragmentTexture(textureResources.positionMap, index: Int(lightPassPositionTextureIndex.rawValue))
            lightEncoder.setFragmentTexture(textureResources.materialMap, index: Int(lightPassMaterialTextureIndex.rawValue))

            // SSAO runs after this pass in the graph (same as the TBDR path, where
            // ambient occlusion is fixed at 1.0), so disable it here too.
            lightEncoder.setFragmentTexture(textureResources.ssaoBlurTexture, index: Int(lightPassSSAOTextureIndex.rawValue))
            var ssaoEnabledForLightPass = false
            lightEncoder.setFragmentBytes(&ssaoEnabledForLightPass, length: MemoryLayout<Bool>.size, index: Int(lightPassSSAOEnabledIndex.rawValue))

            let lightQuadEncoder: MTLRenderCommandEncoder = lightEncoder
        #else
            let lightQuadEncoder: MTLRenderCommandEncoder = renderEncoder
        #endif

        lightQuadEncoder.setRenderPipelineState(lightPipeline.pipelineState!)
        if let depthState = lightPipeline.depthState {
            lightQuadEncoder.setDepthStencilState(depthState)
        }

        lightQuadEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        lightQuadEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        var effectiveCamPos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        lightQuadEncoder.setFragmentBytes(&effectiveCamPos, length: MemoryLayout<simd_float3>.stride, index: Int(lightPassCameraPositionIndex.rawValue))

        var csmUniforms = shadowSystem.makeUniforms()
        csmUniforms.cameraViewMatrix = viewMatrix
        csmUniforms.lightSpaceMatrices.0 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.0)
        csmUniforms.lightSpaceMatrices.1 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.1)
        csmUniforms.lightSpaceMatrices.2 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.2)
        lightQuadEncoder.setFragmentBytes(&csmUniforms, length: MemoryLayout<CSMUniforms>.stride, index: Int(lightPassLightOrthoViewMatrixIndex.rawValue))

        lightQuadEncoder.setFragmentTexture(textureResources.csmShadowMap, index: Int(lightPassShadowTextureIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(textureResources.pointShadowCubeMap, index: Int(lightPassPointShadowTextureIndex.rawValue))
        var pointShadowUniforms = pointShadowState.makeUniforms()
        lightQuadEncoder.setFragmentBytes(&pointShadowUniforms, length: MemoryLayout<PointShadowUniforms>.stride, index: Int(lightPassPointShadowUniformIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(textureResources.spotShadowMap, index: Int(lightPassSpotShadowTextureIndex.rawValue))
        var spotShadowUniforms = spotShadowState.makeUniforms()
        lightQuadEncoder.setFragmentBytes(&spotShadowUniforms, length: MemoryLayout<SpotShadowUniforms>.stride, index: Int(lightPassSpotShadowUniformIndex.rawValue))
        let environmentLighting = resolveCurrentEnvironmentLighting()
        lightQuadEncoder.setFragmentTexture(environmentLighting.irradianceMap, index: Int(lightPassIBLIrradianceTextureIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(environmentLighting.specularMap, index: Int(lightPassIBLSpecularTextureIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(environmentLighting.brdfMap, index: Int(lightPassIBLBRDFMapTextureIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(textureResources.areaTextureLTCMag, index: Int(lightPassAreaLTCMagTextureIndex.rawValue))
        lightQuadEncoder.setFragmentTexture(textureResources.areaTextureLTCMat, index: Int(lightPassAreaLTCMatTextureIndex.rawValue))

        var lightParams = getDirectionalLightParameters()
        lightQuadEncoder.setFragmentBytes(&lightParams, length: MemoryLayout<LightParameters>.stride, index: Int(lightPassLightParamsIndex.rawValue))

        let headerSize = 16
        _ = uploadAndBindLights(
            buffer: bufferResources.pointLightBuffer,
            lights: getPointLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: lightQuadEncoder,
            bufferIndex: Int(lightPassPointLightsIndex.rawValue),
            labelForErrors: "Point Lights"
        )
        _ = uploadAndBindLights(
            buffer: bufferResources.spotLightBuffer,
            lights: getSpotLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: lightQuadEncoder,
            bufferIndex: Int(lightPassSpotLightsIndex.rawValue),
            labelForErrors: "Spot Lights"
        )
        _ = uploadAndBindLights(
            buffer: bufferResources.areaLightBuffer,
            lights: getAreaLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: lightQuadEncoder,
            bufferIndex: Int(lightPassAreaLightsIndex.rawValue),
            labelForErrors: "Area Lights"
        )

        var brdfParameters = IBLParamsUniform()
        brdfParameters.applyIBL = environmentLighting.applyIBL
        brdfParameters.ambientIntensity = environmentLighting.ambientIntensity
        lightQuadEncoder.setFragmentBytes(&brdfParameters, length: MemoryLayout<IBLParamsUniform>.stride, index: Int(lightPassIBLParamIndex.rawValue))

        var lightPassRotationAngle = envRotationAngle
        lightQuadEncoder.setFragmentBytes(&lightPassRotationAngle, length: MemoryLayout<Float>.stride, index: Int(lightPassIBLRotationAngleIndex.rawValue))

        var isGameMode = gameMode
        lightQuadEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.size, index: Int(lightPassGameModeIndex.rawValue))

        lightQuadEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        lightQuadEncoder.updateFence(renderInfo.fence, after: .fragment)
        // Ends the shared TBDR encoder on device, the standalone light encoder
        // in the simulator (its G-buffer encoder was ended above).
        lightQuadEncoder.popDebugGroup()
        lightQuadEncoder.endEncoding()
        // On device lightQuadEncoder is renderEncoder itself — this close is
        // the one the safety-net defer is watching.
        combinedEncoderClosed = true
    }

    static let ssaoExecution: RenderPassExecution = { commandBuffer in
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let ssaoPipeline = PipelineManager.shared.renderPipelinesByType[.ssao] else {
            handleError(.pipelineStateNulled, "ssaoPipeline is nil")
            return
        }

        if !ssaoPipeline.success {
            handleError(.pipelineStateNulled, ssaoPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO render pass descriptor not initialized")
            return
        }

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "SSAO Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Pass"

        renderEncoder.pushDebugGroup("SSAO Pass")

        renderEncoder.setRenderPipelineState(ssaoPipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(ssaoPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(textureResources.depthMap, index: Int(ssaoDepthTextureIndex.rawValue))

        // ssao properties
        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.radius,
            length: MemoryLayout<Float>.stride,
            index: Int(ssaoPassRadiusIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.bias,
            length: MemoryLayout<Float>.stride,
            index: Int(ssaoPassBiasIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.intensity,
            length: MemoryLayout<Float>.stride,
            index: Int(ssaoPassIntensityIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.enabled,
            length: MemoryLayout<Bool>.stride,
            index: Int(ssaoPassEnabledIndex.rawValue)
        )

        renderEncoder.setFragmentBytes(&renderInfo.viewPort, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassViewPortIndex.rawValue))

        var frustumPlanes = simd_float2(near, far)
        renderEncoder.setFragmentBytes(&frustumPlanes, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassFrustumIndex.rawValue))

        var reverseZ = renderInfo.reverseZEnabled
        renderEncoder.setFragmentBytes(&reverseZ, length: MemoryLayout<Bool>.stride, index: Int(ssaoPassReverseZIndex.rawValue))
        // set the draw command

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    static let ssaoBlurExecution: RenderPassExecution = { commandBuffer in
        guard let ssaoBlurPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBlur] else {
            handleError(.pipelineStateNulled, "ssaoBlurPipeline is nil")
            return
        }

        if !ssaoBlurPipeline.success {
            handleError(.pipelineStateNulled, ssaoBlurPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoBlurRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Blur render pass descriptor not initialized")
            return
        }

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // clear it so that it doesn't have any effect on the final output
        renderInfo.ssaoBlurRenderPassDescriptor.depthAttachment.loadAction = .clear
        renderInfo.ssaoRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = .load

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "SSAO Blur Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Blur Pass"

        renderEncoder.pushDebugGroup("SSAO Blur Pass")

        renderEncoder.setRenderPipelineState(ssaoBlurPipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(ssaoBlurPipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // pass ssao resources
        renderEncoder.setFragmentTexture(textureResources.ssaoTexture, index: 0)

        renderEncoder.setFragmentBytes(
            &SSAOParams.shared.enabled,
            length: MemoryLayout<Bool>.stride,
            index: 0
        )
        // set the draw command

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Optimized SSAO Execution with Quality Tiers

    public static let ssaoOptimizedExecution: RenderPassExecution = { commandBuffer in
        // Skip SSAO entirely if disabled
        if !SSAOParams.shared.enabled {
            return
        }

        let quality = SSAOParams.shared.quality
        let startTime = CACurrentMediaTime()

        // Execute based on quality tier
        if quality.resolutionScale < 1.0 {
            // Low-res path: SSAO -> Blur (bilateral or simple) -> Upsample
            ssaoLowResExecution(commandBuffer)

            if quality.useBilateralBlur {
                ssaoBilateralBlurExecution(commandBuffer)
            } else {
                ssaoSimpleBlurExecution(commandBuffer)
            }

            ssaoUpsampleExecution(commandBuffer)
        } else {
            // Full-res path: SSAO -> Blur
            ssaoExecution(commandBuffer)

            if quality.useBilateralBlur {
                ssaoBilateralBlurFullResExecution(commandBuffer)
            } else {
                ssaoBlurExecution(commandBuffer)
            }
        }

        // Record timing
        commandBuffer.addCompletedHandler { _ in
            /*
             let endTime = CACurrentMediaTime()
             let elapsed = (endTime - startTime) * 1000.0 // ms

             SSAOParams.shared.lastSSAOTime = elapsed
             SSAOParams.shared.frameCount += 1

             // Rolling average over 60 frames
             let alpha = 1.0 / min(Double(SSAOParams.shared.frameCount), 60.0)
             SSAOParams.shared.avgSSAOTime = SSAOParams.shared.avgSSAOTime * (1.0 - alpha) + elapsed * alpha

             // Log periodically
             if SSAOParams.shared.frameCount % 60 == 0 {
                 print("🔍 SSAO Performance:")
                 print("   Quality: \(quality)")
                 print("   Resolution: \(quality.resolutionScale)x")
                 print("   Samples: \(quality.sampleCount)")
                 print("   Avg Time: \(String(format: "%.2f", SSAOParams.shared.avgSSAOTime)) ms")
             }
              */
        }
    }

    // MARK: - Low-Resolution SSAO Pass

    private static let ssaoLowResExecution: RenderPassExecution = { commandBuffer in
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let ssaoPipeline = PipelineManager.shared.renderPipelinesByType[.ssao] else {
            handleError(.pipelineStateNulled, "ssaoPipeline is nil")
            return
        }

        if !ssaoPipeline.success {
            handleError(.pipelineStateNulled, ssaoPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoLowResRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO low-res render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Low-Res Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Low-Res Pass"
        renderEncoder.pushDebugGroup("SSAO Low-Res Pass")

        renderEncoder.setRenderPipelineState(ssaoPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(textureResources.depthMap, index: Int(ssaoDepthTextureIndex.rawValue))

        // Use low-res viewport for sampling calculations
        let quality = SSAOParams.shared.quality
        var lowResViewPort = renderInfo.viewPort * quality.resolutionScale
        renderEncoder.setFragmentBytes(&lowResViewPort, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassViewPortIndex.rawValue))

        var frustumPlanes = simd_float2(near, far)
        renderEncoder.setFragmentBytes(&frustumPlanes, length: MemoryLayout<simd_float2>.stride, index: Int(ssaoPassFrustumIndex.rawValue))

        var reverseZ = renderInfo.reverseZEnabled
        renderEncoder.setFragmentBytes(&reverseZ, length: MemoryLayout<Bool>.stride, index: Int(ssaoPassReverseZIndex.rawValue))

        // SSAO properties
        renderEncoder.setFragmentBytes(&SSAOParams.shared.radius, length: MemoryLayout<Float>.stride, index: Int(ssaoPassRadiusIndex.rawValue))
        renderEncoder.setFragmentBytes(&SSAOParams.shared.bias, length: MemoryLayout<Float>.stride, index: Int(ssaoPassBiasIndex.rawValue))
        renderEncoder.setFragmentBytes(&SSAOParams.shared.intensity, length: MemoryLayout<Float>.stride, index: Int(ssaoPassIntensityIndex.rawValue))
        renderEncoder.setFragmentBytes(&SSAOParams.shared.enabled, length: MemoryLayout<Bool>.stride, index: Int(ssaoPassEnabledIndex.rawValue))

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Bilateral Blur (Separable, Two-Pass)

    private static let ssaoBilateralBlurExecution: RenderPassExecution = { commandBuffer in
        guard let bilateralPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBilateralBlur] else {
            handleError(.pipelineStateNulled, "ssaoBilateralBlur is nil")
            return
        }

        if !bilateralPipeline.success {
            handleError(.pipelineStateNulled, bilateralPipeline.name!)
            return
        }

        // Horizontal pass
        ssaoBilateralBlurPass(
            commandBuffer: commandBuffer,
            pipeline: bilateralPipeline,
            sourceTexture: textureResources.ssaoTextureLowRes!,
            destinationDescriptor: renderInfo.ssaoBlurHorizontalRenderPassDescriptor!,
            direction: simd_float2(1.0, 0.0),
            label: "SSAO Bilateral Blur Horizontal"
        )

        // Vertical pass
        ssaoBilateralBlurPass(
            commandBuffer: commandBuffer,
            pipeline: bilateralPipeline,
            sourceTexture: textureResources.ssaoBlurHorizontal!,
            destinationDescriptor: renderInfo.ssaoBlurVerticalRenderPassDescriptor!,
            direction: simd_float2(0.0, 1.0),
            label: "SSAO Bilateral Blur Vertical"
        )
    }

    private static func ssaoBilateralBlurPass(
        commandBuffer: MTLCommandBuffer,
        pipeline: RenderPipeline,
        sourceTexture: MTLTexture,
        destinationDescriptor: MTLRenderPassDescriptor,
        direction: simd_float2,
        label: String
    ) {
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: destinationDescriptor) else {
            handleError(.renderPassCreationFailed, label)
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = label
        renderEncoder.pushDebugGroup(label)

        renderEncoder.setRenderPipelineState(pipeline.pipelineState!)
        // renderEncoder.setDepthStencilState(pipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // Bind source SSAO texture and depth
        renderEncoder.setFragmentTexture(sourceTexture, index: 0)
        renderEncoder.setFragmentTexture(textureResources.depthMap, index: 1)

        var blurDirection = direction
        renderEncoder.setFragmentBytes(&blurDirection, length: MemoryLayout<simd_float2>.stride, index: 0)

        var enabled = SSAOParams.shared.enabled
        renderEncoder.setFragmentBytes(&enabled, length: MemoryLayout<Bool>.stride, index: 1)

        var frustumPlanes = simd_float2(near, far)
        renderEncoder.setFragmentBytes(&frustumPlanes, length: MemoryLayout<simd_float2>.stride, index: 2)

        var reverseZ = renderInfo.reverseZEnabled
        renderEncoder.setFragmentBytes(&reverseZ, length: MemoryLayout<Bool>.stride, index: 3)

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Simple Blur (Fast Path)

    private static let ssaoSimpleBlurExecution: RenderPassExecution = { commandBuffer in
        guard let ssaoBlurPipeline = PipelineManager.shared.renderPipelinesByType[.ssaoBlur] else {
            handleError(.pipelineStateNulled, "ssaoBlurPipeline is nil")
            return
        }

        if !ssaoBlurPipeline.success {
            handleError(.pipelineStateNulled, ssaoBlurPipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoBlurVerticalRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Blur render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Blur Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Simple Blur Pass"
        renderEncoder.pushDebugGroup("SSAO Simple Blur Pass")

        renderEncoder.setRenderPipelineState(ssaoBlurPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(textureResources.ssaoTextureLowRes, index: 0)
        renderEncoder.setFragmentBytes(&SSAOParams.shared.enabled, length: MemoryLayout<Bool>.stride, index: 0)

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Upsample Pass

    private static let ssaoUpsampleExecution: RenderPassExecution = { commandBuffer in
        guard let upsamplePipeline = PipelineManager.shared.renderPipelinesByType[.ssaoUpsample] else {
            handleError(.pipelineStateNulled, "ssaoUpsample is nil")
            return
        }

        if !upsamplePipeline.success {
            handleError(.pipelineStateNulled, upsamplePipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.ssaoUpsampleRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "SSAO Upsample render pass descriptor not initialized")
            return
        }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            handleError(.renderPassCreationFailed, "SSAO Upsample Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "SSAO Upsample Pass"
        renderEncoder.pushDebugGroup("SSAO Upsample Pass")

        renderEncoder.setRenderPipelineState(upsamplePipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        // Source: low-res blurred SSAO
        renderEncoder.setFragmentTexture(textureResources.ssaoBlurTextureLowRes, index: 0)

        // Reference: full-res depth for edge-aware upsampling
        renderEncoder.setFragmentTexture(textureResources.depthMap, index: 1)

        var useDepthAware = SSAOParams.shared.quality.useDepthAwareUpsample
        renderEncoder.setFragmentBytes(&useDepthAware, length: MemoryLayout<Bool>.stride, index: 0)

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    // MARK: - Full-Res Bilateral Blur

    private static let ssaoBilateralBlurFullResExecution: RenderPassExecution = { commandBuffer in
        // For now, use existing box blur for full-res
        // TODO: Implement dedicated full-res bilateral blur if needed
        ssaoBlurExecution(commandBuffer)
    }

    // lightExecution has been removed. Lighting now runs inside combinedModelLightExecution
    // as the third sub-pass of the TBDR G-buffer + lighting encoder. The .light pipeline
    // is the 6-attachment TBDR pipeline; using it with the old single-attachment
    // deferredRenderPassDescriptor would fail Metal validation immediately.

    @available(*, unavailable, renamed: "combinedModelLightExecution")
    public static var lightExecution: RenderPassExecution {
        fatalError()
    }

    /// Kept below for reference during SSAO tile-kernel restructure — remove after.
    private static let _legacyLightExecution_DEAD: RenderPassExecution = { commandBuffer in
        guard let lightPipeline = PipelineManager.shared.renderPipelinesByType[.light] else {
            handleError(.pipelineStateNulled, "lightPipeline is nil")
            return
        }

        if !lightPipeline.success {
            handleError(.pipelineStateNulled, lightPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let renderPassDescriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
            return
        }
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        // Preserve opaque depth for transparency and post-process depth consumers.
        renderPassDescriptor.depthAttachment.loadAction = .load
        renderPassDescriptor.depthAttachment.storeAction = .store

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Light Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Light Pass"

        renderEncoder.pushDebugGroup("Light Pass")

        renderEncoder.setRenderPipelineState(lightPipeline.pipelineState!)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        var effectiveCamPos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        renderEncoder.setFragmentBytes(&effectiveCamPos, length: MemoryLayout<simd_float3>.stride, index: Int(lightPassCameraPositionIndex.rawValue))

        // CSM uniforms: pack all cascade matrices + split distances into one struct.
        var csmUniforms = shadowSystem.makeUniforms()
        csmUniforms.cameraViewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        // Apply SceneRootTransform to each cascade matrix.
        csmUniforms.lightSpaceMatrices.0 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.0)
        csmUniforms.lightSpaceMatrices.1 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.1)
        csmUniforms.lightSpaceMatrices.2 = SceneRootTransform.shared.effectiveLightMatrix(csmUniforms.lightSpaceMatrices.2)
        renderEncoder.setFragmentBytes(
            &csmUniforms, length: MemoryLayout<CSMUniforms>.stride,
            index: Int(lightPassLightOrthoViewMatrixIndex.rawValue)
        )

        // G-Buffer data
        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture, index: Int(lightPassAlbedoTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture, index: Int(lightPassNormalTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture, index: Int(lightPassPositionTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(materialTarget.rawValue)].texture, index: Int(lightPassMaterialTextureIndex.rawValue)
        )

        // SSAO Blur texture
        renderEncoder.setFragmentTexture(textureResources.ssaoBlurTexture, index: Int(lightPassSSAOTextureIndex.rawValue))

        // Compute Lighting
        var lightParams = getDirectionalLightParameters()

        renderEncoder.setFragmentBytes(&lightParams, length: MemoryLayout<LightParameters>.stride, index: Int(lightPassLightParamsIndex.rawValue))

        // CSM shadow array texture
        renderEncoder.setFragmentTexture(
            textureResources.csmShadowMap, index: Int(lightPassShadowTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.pointShadowCubeMap, index: Int(lightPassPointShadowTextureIndex.rawValue)
        )
        var pointShadowUniforms = pointShadowState.makeUniforms()
        renderEncoder.setFragmentBytes(
            &pointShadowUniforms,
            length: MemoryLayout<PointShadowUniforms>.stride,
            index: Int(lightPassPointShadowUniformIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.spotShadowMap, index: Int(lightPassSpotShadowTextureIndex.rawValue)
        )
        var spotShadowUniforms = spotShadowState.makeUniforms()
        renderEncoder.setFragmentBytes(
            &spotShadowUniforms,
            length: MemoryLayout<SpotShadowUniforms>.stride,
            index: Int(lightPassSpotShadowUniformIndex.rawValue)
        )

        let MAX_POINT_LIGHTS = 1024
        let headerSize = 16
        // Point
        _ = uploadAndBindLights(
            buffer: bufferResources.pointLightBuffer,
            lights: getPointLights(), // [PointLight]
            maxCount: MAX_POINT_LIGHTS,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassPointLightsIndex.rawValue),
            labelForErrors: "Point Lights"
        )

        // Spot
        _ = uploadAndBindLights(
            buffer: bufferResources.spotLightBuffer,
            lights: getSpotLights(), // [SpotLightUniform] or [SpotLight]
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassSpotLightsIndex.rawValue),
            labelForErrors: "Spot Lights"
        )

        // Area
        _ = uploadAndBindLights(
            buffer: bufferResources.areaLightBuffer,
            lights: getAreaLights(), // [AreaLightUniform] or [AreaLight]
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(lightPassAreaLightsIndex.rawValue),
            labelForErrors: "Area Lights"
        )

        // LTC Maps for Area Lights
        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMat, index: Int(lightPassAreaLTCMatTextureIndex.rawValue))

        renderEncoder.setFragmentTexture(textureResources.areaTextureLTCMag, index: Int(lightPassAreaLTCMagTextureIndex.rawValue))

        let environmentLighting = resolveCurrentEnvironmentLighting()

        // ibl
        renderEncoder.setFragmentTexture(
            environmentLighting.irradianceMap, index: Int(lightPassIBLIrradianceTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            environmentLighting.specularMap, index: Int(lightPassIBLSpecularTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            environmentLighting.brdfMap, index: Int(lightPassIBLBRDFMapTextureIndex.rawValue)
        )

        var brdfParameters = IBLParamsUniform()
        brdfParameters.applyIBL = environmentLighting.applyIBL
        brdfParameters.ambientIntensity = environmentLighting.ambientIntensity

        renderEncoder.setFragmentBytes(
            &brdfParameters, length: MemoryLayout<IBLParamsUniform>.stride,
            index: Int(lightPassIBLParamIndex.rawValue)
        )

        var lightPassRotationAngle = envRotationAngle
        renderEncoder.setFragmentBytes(
            &lightPassRotationAngle, length: MemoryLayout<Float>.stride,
            index: Int(lightPassIBLRotationAngleIndex.rawValue)
        )

        var isGameMode = gameMode
        renderEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.size, index: Int(lightPassGameModeIndex.rawValue))

        var ssaoEnabled = SSAOParams.shared.enabled
        renderEncoder.setFragmentBytes(&ssaoEnabled, length: MemoryLayout<Bool>.size, index: Int(lightPassSSAOEnabledIndex.rawValue))

        // set the draw command

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    } // end _legacyLightExecution_DEAD

    public static let preCompositeExecution: RenderPassExecution = { commandBuffer in
        guard let preCompositePipeline = PipelineManager.shared.renderPipelinesByType[.preComposite] else {
            handleError(.pipelineStateNulled, "preCompositePipeline is nil")
            return
        }

        if !preCompositePipeline.success {
            handleError(.pipelineStateNulled, preCompositePipeline.name!)
            return
        }

        guard let renderPassDescriptor = renderInfo.sceneCompositeRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Main render pass descriptor not initialized")
            return
        }

        // set the states for the pipeline
        renderPassDescriptor.colorAttachments[0].texture = textureResources.sceneCompositeTexture
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

        if renderInfo.immersionStyle == .none || renderInfo.immersionStyle == .ar {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
        } else {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, Double(getAlphaForImmersionMode()))
        }

        // clear it so that it doesn't have any effect on the final output
        if gameMode == false {
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.clearDepth = sceneDepthClearValue()
            renderInfo.deferredRenderPassDescriptor?.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].loadAction = .load
        } else {
            renderInfo.postProcessRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.postProcessRenderPassDescriptor?.depthAttachment.clearDepth = sceneDepthClearValue()
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.loadAction = .clear
            renderInfo.offscreenRenderPassDescriptor?.depthAttachment.clearDepth = sceneDepthClearValue()
            renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0]
                .loadAction = .load

            renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].loadAction = .clear
        }

        // Load Gaussian texture so it isn't cleared
        renderInfo.gaussianRenderPassDescriptor?.colorAttachments[0].loadAction = .load

        // set your encoder here
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Pre Composite Pass")
            return
        }

        defer {
            // Make sure no matter what we end the encoding at the end of the function
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Pre Composite Pass"

        renderEncoder.pushDebugGroup("Pre Composite Pass")

        renderEncoder.setRenderPipelineState(preCompositePipeline.pipelineState!)

        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

        renderEncoder.setFragmentTexture(
            renderInfo.environmentRenderPassDescriptor?.colorAttachments[0].texture, index: Int(prePassEnvTextureIndex.rawValue)
        )

        if gameMode == false {
            renderEncoder.setFragmentTexture(
                renderInfo.deferredRenderPassDescriptor?.colorAttachments[0].texture,
                index: Int(prePassFinalTextureIndex.rawValue)
            )

            renderEncoder.setFragmentTexture(
                textureResources.depthMap ?? renderInfo.offscreenRenderPassDescriptor?.depthAttachment.texture,
                index: Int(prePassDepthTextureIndex.rawValue)
            )
        } else {
            let postProcessColorTexture = renderInfo.postProcessRenderPassDescriptor?.colorAttachments[0].texture
            let finalColorTexture = bypassPostProcessing
                ? (renderInfo.deferredRenderPassDescriptor?.colorAttachments[0].texture ?? postProcessColorTexture)
                : postProcessColorTexture

            renderEncoder.setFragmentTexture(
                finalColorTexture,
                index: Int(prePassFinalTextureIndex.rawValue)
            )

            renderEncoder.setFragmentTexture(
                renderInfo.postProcessRenderPassDescriptor?.depthAttachment.texture, index: Int(prePassDepthTextureIndex.rawValue)
            )
        }

        renderEncoder.setFragmentTexture(renderInfo.gizmoRenderPassDescriptor?.colorAttachments[0].texture, index: Int(prePassGizmoTextureIndex.rawValue))

        // Pass the Gaussian texture
        renderEncoder.setFragmentTexture(
            renderInfo.gaussianRenderPassDescriptor?.colorAttachments[0].texture,
            index: Int(prePassGaussianTextureIndex.rawValue)
        )

        renderEncoder.setFragmentTexture(
            textureResources.ssaoBlurTexture,
            index: Int(prePassSSAOTextureIndex.rawValue)
        )

        var isGameMode = gameMode
        renderEncoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.stride, index: Int(prePassGizmoBufferIndex.rawValue))

        var isPassthrough = (renderInfo.immersionStyle == UntoldImmersionMode.mixed) ? true : false

        renderEncoder.setFragmentBytes(&isPassthrough, length: MemoryLayout<Bool>.stride, index: Int(prePassPassthroughBufferIndex.rawValue))

        var ssaoEnabled = SSAOParams.shared.enabled
        renderEncoder.setFragmentBytes(&ssaoEnabled, length: MemoryLayout<Bool>.stride, index: Int(prePassSSAOEnabledIndex.rawValue))

        // set the draw command

        renderEncoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let transparencyExecution: RenderPassExecution = { commandBuffer in
        guard let transparencyPipeline = PipelineManager.shared.renderPipelinesByType[.transparency] else {
            handleError(.pipelineStateNulled, "transparencyPipeline is nil")
            return
        }

        if transparencyPipeline.success == false {
            handleError(.pipelineStateNulled, transparencyPipeline.name!)
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
            return
        }

        // Load the lit opaque scene and blend transparent surfaces on top.
        encoderDescriptor.colorAttachments[0].loadAction = .load
        encoderDescriptor.colorAttachments[0].storeAction = .store

        // Preserve depth for transparency depth-testing and downstream post-process consumers.
        encoderDescriptor.depthAttachment.loadAction = .load
        encoderDescriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Transparency Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Transparency Pass"
        renderEncoder.pushDebugGroup("Transparency Pass")

        renderEncoder.setRenderPipelineState(transparencyPipeline.pipelineState!)

        // XR passthrough: write transparent depth so compositor occlusion/depth edges
        // match transparent silhouettes against camera passthrough.
        if renderInfo.immersionStyle == .mixed {
            if let xrDepthWriteState = getOrCreateTransparencyXRDepthWriteState(device: renderInfo.device) {
                renderEncoder.setDepthStencilState(xrDepthWriteState)
            } else {
                renderEncoder.setDepthStencilState(transparencyPipeline.depthState)
            }
        } else {
            renderEncoder.setDepthStencilState(transparencyPipeline.depthState)
        }
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

        var transpCSM = shadowSystem.makeUniforms()
        transpCSM.cameraViewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        transpCSM.lightSpaceMatrices.0 = SceneRootTransform.shared.effectiveLightMatrix(transpCSM.lightSpaceMatrices.0)
        transpCSM.lightSpaceMatrices.1 = SceneRootTransform.shared.effectiveLightMatrix(transpCSM.lightSpaceMatrices.1)
        transpCSM.lightSpaceMatrices.2 = SceneRootTransform.shared.effectiveLightMatrix(transpCSM.lightSpaceMatrices.2)
        renderEncoder.setFragmentBytes(
            &transpCSM,
            length: MemoryLayout<CSMUniforms>.stride,
            index: Int(transparencyPassLightOrthoViewMatrixIndex.rawValue)
        )

        var effectiveCamPos = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        renderEncoder.setFragmentBytes(
            &effectiveCamPos,
            length: MemoryLayout<simd_float3>.stride,
            index: Int(transparencyPassCameraPositionIndex.rawValue)
        )

        var lightParams = getDirectionalLightParameters()
        renderEncoder.setFragmentBytes(
            &lightParams,
            length: MemoryLayout<LightParameters>.stride,
            index: Int(transparencyPassLightParamsIndex.rawValue)
        )

        let headerSize = 16
        _ = uploadAndBindLights(
            buffer: bufferResources.pointLightBuffer,
            lights: getPointLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(transparencyPassPointLightsIndex.rawValue),
            labelForErrors: "Transparency Point Lights"
        )

        _ = uploadAndBindLights(
            buffer: bufferResources.spotLightBuffer,
            lights: getSpotLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(transparencyPassSpotLightsIndex.rawValue),
            labelForErrors: "Transparency Spot Lights"
        )

        _ = uploadAndBindLights(
            buffer: bufferResources.areaLightBuffer,
            lights: getAreaLights(),
            maxCount: 1024,
            headerSize: headerSize,
            encoder: renderEncoder,
            bufferIndex: Int(transparencyPassAreaLightsIndex.rawValue),
            labelForErrors: "Transparency Area Lights"
        )

        renderEncoder.setFragmentTexture(
            textureResources.areaTextureLTCMat,
            index: Int(transparencyPassAreaLTCMatTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.areaTextureLTCMag,
            index: Int(transparencyPassAreaLTCMagTextureIndex.rawValue)
        )
        let environmentLighting = resolveCurrentEnvironmentLighting()
        renderEncoder.setFragmentTexture(
            environmentLighting.irradianceMap,
            index: Int(transparencyPassIBLIrradianceTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            environmentLighting.specularMap,
            index: Int(transparencyPassIBLSpecularTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            environmentLighting.brdfMap,
            index: Int(transparencyPassIBLBRDFMapTextureIndex.rawValue)
        )
        renderEncoder.setFragmentTexture(
            textureResources.csmShadowMap,
            index: Int(transparencyPassShadowTextureIndex.rawValue)
        )

        var iblParameters = IBLParamsUniform()
        iblParameters.applyIBL = environmentLighting.applyIBL
        iblParameters.ambientIntensity = environmentLighting.ambientIntensity
        renderEncoder.setFragmentBytes(
            &iblParameters,
            length: MemoryLayout<IBLParamsUniform>.stride,
            index: Int(transparencyPassIBLParamIndex.rawValue)
        )

        var transparencyPassRotationAngle = envRotationAngle
        renderEncoder.setFragmentBytes(
            &transparencyPassRotationAngle,
            length: MemoryLayout<Float>.stride,
            index: Int(transparencyPassIBLRotationAngleIndex.rawValue)
        )

        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        // Build and sort transparent draw items back-to-front for correct alpha blending.
        var transparentEntities: [(entityId: EntityID, render: RenderComponent, world: WorldTransformComponent, distanceSq: Float)] = []

        for entityId in visibleEntityIds {
            if scene.mask(for: entityId) == nil { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }

            if BatchingSystem.shared.isEnabled(), BatchingSystem.shared.isBatched(entityId: entityId) {
                continue
            }

            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }
            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { continue }
            if hasComponent(entityId: entityId, componentType: LightComponent.self) { continue }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                continue
            }
            guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                continue
            }

            let hasTransparentSubmesh = renderComponent.mesh.contains { mesh in
                mesh.submeshes.contains { submesh in
                    submesh.material?.alphaMode == .blend
                }
            }

            if !hasTransparentSubmesh {
                continue
            }

            let worldPosition = simd_float3(
                worldTransformComponent.space.columns.3.x,
                worldTransformComponent.space.columns.3.y,
                worldTransformComponent.space.columns.3.z
            )
            let distanceSq = simd_length_squared(effectiveCameraPosition - worldPosition)
            transparentEntities.append((
                entityId: entityId,
                render: renderComponent,
                world: worldTransformComponent,
                distanceSq: distanceSq
            ))
        }

        transparentEntities.sort { $0.distanceSq > $1.distanceSq }

        for entry in transparentEntities {
            let entityId = entry.entityId
            let renderComponent = entry.render
            let worldTransformComponent = entry.world

            for mesh in renderComponent.mesh {
                var modelUniforms = Uniforms()
                let rootMatrix = worldTransformComponent.space
                let modelMatrix = simd_mul(rootMatrix, mesh.localSpace)
                let viewMatrix: simd_float4x4 = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)
                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse
                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

                modelUniforms.modelViewMatrix = modelViewMatrix
                modelUniforms.normalMatrix = normalMatrix
                modelUniforms.viewMatrix = viewMatrix
                modelUniforms.modelMatrix = modelMatrix
                modelUniforms.cameraPosition = effectiveCameraPosition
                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                renderEncoder.setVertexBytes(
                    &modelUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

                renderEncoder.setFragmentBytes(
                    &modelUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(transparencyPassFragmentUniformIndex.rawValue)
                )

                for subMesh in mesh.submeshes {
                    guard let material = subMesh.material else { continue }
                    if material.alphaMode != .blend { continue }

                    var stScale: Float = material.stScale
                    renderEncoder.setFragmentBytes(
                        &stScale,
                        length: MemoryLayout<Float>.stride,
                        index: Int(transparencyPassFragmentSTScaleIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        material.baseColor.texture,
                        index: Int(transparencyPassBaseTextureIndex.rawValue)
                    )
                    renderEncoder.setFragmentSamplerState(
                        material.baseColor.sampler,
                        index: Int(transparencyPassBaseSamplerIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        material.roughness.texture,
                        index: Int(transparencyPassRoughnessTextureIndex.rawValue)
                    )
                    renderEncoder.setFragmentSamplerState(
                        material.roughness.sampler,
                        index: Int(transparencyPassMaterialSamplerIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        material.metallic.texture,
                        index: Int(transparencyPassMetallicTextureIndex.rawValue)
                    )

                    var hasNormal: Bool = (material.normal.texture != nil)
                    renderEncoder.setFragmentBytes(
                        &hasNormal,
                        length: MemoryLayout<Bool>.stride,
                        index: Int(transparencyPassFragmentHasNormalTextureIndex.rawValue)
                    )

                    var materialParameters = MaterialParametersUniform()
                    materialParameters.specular = material.specular
                    materialParameters.specularTint = material.specularTint
                    materialParameters.subsurface = material.subsurface
                    materialParameters.anisotropic = material.anisotropic
                    materialParameters.sheen = material.sheen
                    materialParameters.sheenTint = material.sheenTint
                    materialParameters.clearCoat = material.clearCoat
                    materialParameters.clearCoatGloss = material.clearCoatGloss
                    materialParameters.baseColor = material.baseColorValue
                    materialParameters.roughness = material.roughnessValue
                    materialParameters.metallic = material.metallicValue
                    materialParameters.ior = material.ior
                    materialParameters.edgeTint = material.edgeTint
                    materialParameters.alphaCutoff = material.alphaCutoff
                    materialParameters.passthroughAlpha = 1.0
                    materialParameters.alphaMode = Int32(material.alphaMode.rawValue)
                    materialParameters.interactWithLight = material.interactWithLight
                    materialParameters.emmissive = material.emissiveValue
                    applyMaterialTextureState(material: material, materialParameters: &materialParameters)
                    applyLODDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)
                    applyStreamingTierDebugColorOverride(entityId: entityId, materialParameters: &materialParameters)

                    renderEncoder.setFragmentBytes(
                        &materialParameters,
                        length: MemoryLayout<MaterialParametersUniform>.stride,
                        index: Int(transparencyPassFragmentMaterialParameterIndex.rawValue)
                    )

                    renderEncoder.setFragmentTexture(
                        material.normal.texture,
                        index: Int(transparencyPassNormalTextureIndex.rawValue)
                    )
                    renderEncoder.setFragmentSamplerState(
                        material.normal.sampler,
                        index: Int(transparencyPassNormalSamplerIndex.rawValue)
                    )

                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                        category: .transparent
                    )
                }
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let wireframeOcclusionDepthExecution: RenderPassExecution = { commandBuffer in
        guard let depthTexture = textureResources.hzbSourceDepthMap else { return }
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.wireframeOcclusionDepth] else {
            handleError(.pipelineStateNulled, "wireframeOcclusionDepthPipeline is nil")
            return
        }
        guard pipeline.success, let pipelineState = pipeline.pipelineState else {
            handleError(.pipelineStateNulled, pipeline.name ?? "Wireframe Occlusion Depth Pipeline")
            return
        }
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.noActiveCamera)
            return
        }
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)
        wireframeRenderStateLock.lock()
        let wireframeSettings = wireframeRenderState
        wireframeRenderStateLock.unlock()

        let renderId = getComponentId(for: RenderComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let localTransformId = getComponentId(for: LocalTransformComponent.self)
        let wireframeEntityIds = queryEntitiesWithComponentIds([renderId, transformId, localTransformId], in: scene).filter { entityId in
            if scene.mask(for: entityId) == nil { return false }
            if shouldHideSceneEntity(entityId: entityId) { return false }
            if !shouldRenderSceneEntityAsWireframe(entityId: entityId) { return false }
            if BatchingSystem.shared.isEnabled(), BatchingSystem.shared.isBatched(entityId: entityId) { return false }
            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { return false }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { return false }
            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { return false }
            if hasComponent(entityId: entityId, componentType: LightComponent.self) { return false }
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.isVisible,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { return false }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            if shouldCullWireframeByDistanceFade(
                bounds: AABB(min: worldMin, max: worldMax),
                cameraPosition: effectiveCameraPosition,
                settings: wireframeSettings
            ) { return false }
            guard let frustum = currentFrameFrustum else { return true }
            return isAABBInFrustum(frustum, min: worldMin, max: worldMax)
        }
        let wireframeBatchGroups = BatchingSystem.shared.isEnabled()
            ? BatchingSystem.shared.batchGroups.filter { batchGroup in
                guard shouldRenderSceneChannelsAsWireframe(batchGroup.sceneChannels) else { return false }
                if shouldCullWireframeByDistanceFade(
                    bounds: AABB(min: batchGroup.boundingBox.min, max: batchGroup.boundingBox.max),
                    cameraPosition: effectiveCameraPosition,
                    settings: wireframeSettings
                ) { return false }
                guard let frustum = currentFrameFrustum else { return true }
                return isAABBInFrustum(frustum, min: batchGroup.boundingBox.min, max: batchGroup.boundingBox.max)
            }
            : []
        guard !wireframeEntityIds.isEmpty || !wireframeBatchGroups.isEmpty else { return }

        let descriptor = MTLRenderPassDescriptor()
        descriptor.renderTargetWidth = depthTexture.width
        descriptor.renderTargetHeight = depthTexture.height
        descriptor.depthAttachment.texture = depthTexture
        descriptor.depthAttachment.loadAction = .load
        descriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            handleError(.renderPassCreationFailed, "Wireframe Occlusion Depth Pass")
            return
        }

        defer {
            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Wireframe Occlusion Depth Pass"
        renderEncoder.pushDebugGroup("Wireframe Occlusion Depth Pass")
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(pipeline.depthState)
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        renderEncoder.setCullMode(.none)
        renderEncoder.setTriangleFillMode(.fill)

        for entityId in wireframeEntityIds {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId)
            else { continue }

            for mesh in renderComponent.mesh {
                var modelUniforms = Uniforms()
                let modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)
                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
                let normalMatrix = upperModelMatrix.inverse.transpose

                modelUniforms.modelViewMatrix = modelViewMatrix
                modelUniforms.normalMatrix = normalMatrix
                modelUniforms.viewMatrix = viewMatrix
                modelUniforms.modelMatrix = modelMatrix
                modelUniforms.cameraPosition = effectiveCameraPosition
                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                renderEncoder.setVertexBytes(
                    &modelUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

                for subMesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(
                        type: subMesh.metalKitSubmesh.primitiveType,
                        indexCount: subMesh.metalKitSubmesh.indexCount,
                        indexType: subMesh.metalKitSubmesh.indexType,
                        indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                        indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset
                    )
                }
            }
        }

        if BatchingSystem.shared.isEnabled() {
            var batchUniforms = Uniforms()
            let modelMatrix = matrix_identity_float4x4
            let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
            let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
            let normalMatrix = upperModelMatrix.inverse.transpose

            batchUniforms.modelMatrix = modelMatrix
            batchUniforms.viewMatrix = viewMatrix
            batchUniforms.modelViewMatrix = modelViewMatrix
            batchUniforms.normalMatrix = normalMatrix
            batchUniforms.cameraPosition = effectiveCameraPosition
            batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

            for batchGroup in wireframeBatchGroups {
                guard let positionBuffer = batchGroup.positionBuffer,
                      let normalBuffer = batchGroup.normalBuffer,
                      let uvBuffer = batchGroup.uvBuffer,
                      let tangentBuffer = batchGroup.tangentBuffer,
                      let indexBuffer = batchGroup.indexBuffer
                else { continue }

                renderEncoder.setVertexBytes(
                    &batchUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(modelPassUniformIndex.rawValue)
                )
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassVerticesIndex.rawValue))
                renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: Int(modelPassNormalIndex.rawValue))
                renderEncoder.setVertexBuffer(uvBuffer, offset: 0, index: Int(modelPassUVIndex.rawValue))
                renderEncoder.setVertexBuffer(tangentBuffer, offset: 0, index: Int(modelPassTangentIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointIdIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointWeightsIndex.rawValue))

                var identityMatrix = matrix_identity_float4x4
                renderEncoder.setVertexBytes(
                    &identityMatrix,
                    length: MemoryLayout<simd_float4x4>.stride,
                    index: Int(modelPassJointTransformIndex.rawValue)
                )
                var hasArmature = false
                renderEncoder.setVertexBytes(
                    &hasArmature,
                    length: MemoryLayout<Bool>.stride,
                    index: Int(modelPassHasArmature.rawValue)
                )

                renderEncoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: batchGroup.indexCount,
                    indexType: .uint32,
                    indexBuffer: indexBuffer,
                    indexBufferOffset: 0
                )
            }
        }
    }

    public static let wireframeExecution: RenderPassExecution = { commandBuffer in
        guard let wireframePipeline = PipelineManager.shared.renderPipelinesByType[.wireframe] else {
            handleError(.pipelineStateNulled, "wireframePipeline is nil")
            return
        }

        guard wireframePipeline.success, let wireframePipelineState = wireframePipeline.pipelineState else {
            handleError(.pipelineStateNulled, wireframePipeline.name ?? "Wireframe Pipeline")
            return
        }
        wireframeRenderStateLock.lock()
        let wireframeSettings = wireframeRenderState
        wireframeRenderStateLock.unlock()

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }
        let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        let wireframeEntityIds = visibleEntityIds.filter { entityId in
            if scene.mask(for: entityId) == nil { return false }
            if shouldHideSceneEntity(entityId: entityId) { return false }
            if !shouldRenderSceneEntityAsWireframe(entityId: entityId) { return false }
            if BatchingSystem.shared.isEnabled(), BatchingSystem.shared.isBatched(entityId: entityId) { return false }
            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { return false }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { return false }
            if hasComponent(entityId: entityId, componentType: GizmoComponent.self) { return false }
            if hasComponent(entityId: entityId, componentType: LightComponent.self) { return false }
            guard scene.get(component: RenderComponent.self, for: entityId) != nil,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { return false }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            return !shouldCullWireframeByDistanceFade(
                bounds: AABB(min: worldMin, max: worldMax),
                cameraPosition: effectiveCameraPosition,
                settings: wireframeSettings
            )
        }
        let wireframeBatchGroups = BatchingSystem.shared.isEnabled()
            ? visibleBatchGroupsSnapshot().filter { batchGroup in
                guard shouldRenderSceneChannelsAsWireframe(batchGroup.sceneChannels) else { return false }
                return !shouldCullWireframeByDistanceFade(
                    bounds: AABB(min: batchGroup.boundingBox.min, max: batchGroup.boundingBox.max),
                    cameraPosition: effectiveCameraPosition,
                    settings: wireframeSettings
                )
            }
            : []
        guard !wireframeEntityIds.isEmpty || !wireframeBatchGroups.isEmpty else {
            return
        }

        guard let encoderDescriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
            return
        }

        encoderDescriptor.colorAttachments[0].loadAction = .load
        encoderDescriptor.colorAttachments[0].storeAction = .store
        encoderDescriptor.depthAttachment.loadAction = .load
        encoderDescriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            handleError(.renderPassCreationFailed, "Wireframe Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Wireframe Pass"
        renderEncoder.pushDebugGroup("Wireframe Pass")

        renderEncoder.setRenderPipelineState(wireframePipelineState)
        // In visionOS mixed mode the compositor consumes the drawable depth written
        // by the output transform pass. Wireframe-only context geometry skips the
        // opaque pass, so it must contribute scene depth here or the final drawable
        // depth remains at the cleared far value for line pixels.
        if renderInfo.immersionStyle == .mixed {
            if let xrDepthWriteState = getOrCreateWireframeXRDepthWriteState(device: renderInfo.device) {
                renderEncoder.setDepthStencilState(xrDepthWriteState)
            } else {
                renderEncoder.setDepthStencilState(wireframePipeline.depthState)
            }
        } else {
            renderEncoder.setDepthStencilState(wireframePipeline.depthState)
        }
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        renderEncoder.setCullMode(.none)

        var wireframeColor = wireframeSettings.color
        var fadeParams = simd_float4(
            wireframeSettings.fadeStartDistance,
            wireframeSettings.fadeEndDistance,
            wireframeSettings.minimumAlpha,
            wireframeSettings.distanceFadeEnabled ? 1.0 : 0.0
        )
        renderEncoder.setFragmentBytes(
            &wireframeColor,
            length: MemoryLayout<simd_float4>.stride,
            index: 0
        )
        renderEncoder.setFragmentBytes(
            &fadeParams,
            length: MemoryLayout<simd_float4>.stride,
            index: 1
        )

        for entityId in wireframeEntityIds {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId)
            else { continue }

            for mesh in renderComponent.mesh {
                var modelUniforms = Uniforms()
                let modelMatrix = simd_mul(worldTransformComponent.space, mesh.localSpace)
                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
                let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
                let normalMatrix = upperModelMatrix.inverse.transpose

                modelUniforms.modelViewMatrix = modelViewMatrix
                modelUniforms.normalMatrix = normalMatrix
                modelUniforms.viewMatrix = viewMatrix
                modelUniforms.modelMatrix = modelMatrix
                modelUniforms.cameraPosition = effectiveCameraPosition
                modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

                renderEncoder.setVertexBytes(
                    &modelUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(modelPassUniformIndex.rawValue)
                )

                renderEncoder.bindModelVertexStreams(mesh: mesh, entityId: entityId)

                if let edgeIndexBuffer = mesh.featureEdgeIndexBuffer, mesh.featureEdgeIndexCount > 0 {
                    renderEncoder.setTriangleFillMode(.fill)
                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: .line,
                        indexCount: mesh.featureEdgeIndexCount,
                        indexType: mesh.featureEdgeIndexType,
                        indexBuffer: edgeIndexBuffer,
                        indexBufferOffset: 0,
                        category: .other
                    )
                } else {
                    renderEncoder.setTriangleFillMode(.lines)
                    for subMesh in mesh.submeshes {
                        renderEncoder.drawIndexedPrimitivesTracked(
                            type: subMesh.metalKitSubmesh.primitiveType,
                            indexCount: subMesh.metalKitSubmesh.indexCount,
                            indexType: subMesh.metalKitSubmesh.indexType,
                            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
                            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset,
                            category: .other
                        )
                    }
                }
            }
        }

        if BatchingSystem.shared.isEnabled() {
            var batchUniforms = Uniforms()
            let modelMatrix = matrix_identity_float4x4
            let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
            let upperModelMatrix = matrix3x3_upper_left(modelMatrix)
            let normalMatrix = upperModelMatrix.inverse.transpose

            batchUniforms.modelMatrix = modelMatrix
            batchUniforms.viewMatrix = viewMatrix
            batchUniforms.modelViewMatrix = modelViewMatrix
            batchUniforms.normalMatrix = normalMatrix
            batchUniforms.cameraPosition = effectiveCameraPosition
            batchUniforms.projectionMatrix = renderInfo.perspectiveSpace

            for batchGroup in wireframeBatchGroups {
                guard let positionBuffer = batchGroup.positionBuffer,
                      let normalBuffer = batchGroup.normalBuffer,
                      let uvBuffer = batchGroup.uvBuffer,
                      let tangentBuffer = batchGroup.tangentBuffer
                else { continue }

                renderEncoder.setVertexBytes(
                    &batchUniforms,
                    length: MemoryLayout<Uniforms>.stride,
                    index: Int(modelPassUniformIndex.rawValue)
                )
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassVerticesIndex.rawValue))
                renderEncoder.setVertexBuffer(normalBuffer, offset: 0, index: Int(modelPassNormalIndex.rawValue))
                renderEncoder.setVertexBuffer(uvBuffer, offset: 0, index: Int(modelPassUVIndex.rawValue))
                renderEncoder.setVertexBuffer(tangentBuffer, offset: 0, index: Int(modelPassTangentIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointIdIndex.rawValue))
                renderEncoder.setVertexBuffer(positionBuffer, offset: 0, index: Int(modelPassJointWeightsIndex.rawValue))

                var identityMatrix = matrix_identity_float4x4
                renderEncoder.setVertexBytes(
                    &identityMatrix,
                    length: MemoryLayout<simd_float4x4>.stride,
                    index: Int(modelPassJointTransformIndex.rawValue)
                )
                var hasArmature = false
                renderEncoder.setVertexBytes(
                    &hasArmature,
                    length: MemoryLayout<Bool>.stride,
                    index: Int(modelPassHasArmature.rawValue)
                )

                if let edgeIndexBuffer = batchGroup.featureEdgeIndexBuffer,
                   batchGroup.featureEdgeIndexCount > 0
                {
                    renderEncoder.setTriangleFillMode(.fill)
                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: .line,
                        indexCount: batchGroup.featureEdgeIndexCount,
                        indexType: .uint32,
                        indexBuffer: edgeIndexBuffer,
                        indexBufferOffset: 0,
                        category: .other,
                        batched: true
                    )
                } else if let indexBuffer = batchGroup.indexBuffer {
                    renderEncoder.setTriangleFillMode(.lines)
                    renderEncoder.drawIndexedPrimitivesTracked(
                        type: .triangle,
                        indexCount: batchGroup.indexCount,
                        indexType: .uint32,
                        indexBuffer: indexBuffer,
                        indexBufferOffset: 0,
                        category: .other,
                        batched: true
                    )
                }
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let spatialDebugBoundsExecution: RenderPassExecution = { commandBuffer in
        let settings = SpatialDebugVisualization.shared
        let isOcclusionDebugMode = renderDebugViewMode == .occlusionDebug
        let shouldDrawOctreeBounds = settings.showOctreeLeafBounds
        let shouldDrawStaticBatchCells = settings.showStaticBatchCellBounds
        let shouldDrawTileBounds = settings.showTileBounds
        let shouldDrawOccludedBounds = isOcclusionDebugMode
        guard settings.enabled || isOcclusionDebugMode,
              shouldDrawOctreeBounds || shouldDrawStaticBatchCells || shouldDrawTileBounds || shouldDrawOccludedBounds
        else {
            return
        }

        guard let spatialDebugPipeline = PipelineManager.shared.renderPipelinesByType[.spatialDebug] else {
            handleError(.pipelineStateNulled, "spatialDebugPipeline is nil")
            return
        }

        if !spatialDebugPipeline.success {
            handleError(.pipelineStateNulled, spatialDebugPipeline.name ?? "Spatial Debug Pipeline")
            return
        }

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        guard let encoderDescriptor = renderInfo.deferredRenderPassDescriptor else {
            handleError(.renderPassCreationFailed, "Deferred render pass descriptor not initialized")
            return
        }

        let snapshot = SpatialDebugBoundsCollector.shared.collectSnapshot()
        let leafBounds = shouldDrawOctreeBounds ? snapshot.octreeLeafBounds : []
        let staticBatchCellBounds = shouldDrawStaticBatchCells ? snapshot.staticBatchCellBounds : []
        let tileBounds = shouldDrawTileBounds ? snapshot.tileBounds : []
        let occludedBounds = shouldDrawOccludedBounds ? snapshot.occludedEntityBounds : []

        let maxLeafNodeCount = settings.maxLeafNodeCount
        let drawLeafCount = maxLeafNodeCount > 0 ? min(maxLeafNodeCount, leafBounds.count) : leafBounds.count
        if shouldDrawOctreeBounds {
            logSpatialDebugStatus(totalLeaves: leafBounds.count, drawnLeaves: drawLeafCount, cap: maxLeafNodeCount)
        }

        let maxStaticBatchCellCount = settings.maxStaticBatchCellCount
        let drawStaticBatchCellCount = maxStaticBatchCellCount > 0
            ? min(maxStaticBatchCellCount, staticBatchCellBounds.count)
            : staticBatchCellBounds.count
        let maxTileNodeCount = settings.maxTileNodeCount
        let drawTileCount = maxTileNodeCount > 0 ? min(maxTileNodeCount, tileBounds.count) : tileBounds.count
        let drawOccludedCount = occludedBounds.count

        guard drawLeafCount > 0 || drawStaticBatchCellCount > 0 || drawTileCount > 0 || drawOccludedCount > 0 else {
            return
        }

        var groupedBounds: [SpatialDebugColorKey: (color: simd_float4, bounds: [AABB])] = [:]
        var groupOrder: [SpatialDebugColorKey] = []
        groupOrder.reserveCapacity(4)

        for i in 0 ..< drawLeafCount {
            let item = leafBounds[i]
            let key = spatialDebugColorKey(item.color)
            if groupedBounds[key] == nil {
                groupedBounds[key] = (color: item.color, bounds: [])
                groupOrder.append(key)
            }
            groupedBounds[key]?.bounds.append(item.bounds)
        }

        for i in 0 ..< drawStaticBatchCellCount {
            let item = staticBatchCellBounds[i]
            let key = spatialDebugColorKey(item.color)
            if groupedBounds[key] == nil {
                groupedBounds[key] = (color: item.color, bounds: [])
                groupOrder.append(key)
            }
            groupedBounds[key]?.bounds.append(item.bounds)
        }

        for i in 0 ..< drawTileCount {
            let item = tileBounds[i]
            let key = spatialDebugColorKey(item.color)
            if groupedBounds[key] == nil {
                groupedBounds[key] = (color: item.color, bounds: [])
                groupOrder.append(key)
            }
            groupedBounds[key]?.bounds.append(item.bounds)
        }

        // Occluded entity bounds are kept separate — they need an always-pass depth
        // state so the lines are visible even though the mesh is behind an occluder.
        var occludedGroupedBounds: [SpatialDebugColorKey: (color: simd_float4, bounds: [AABB])] = [:]
        var occludedGroupOrder: [SpatialDebugColorKey] = []
        for i in 0 ..< drawOccludedCount {
            let item = occludedBounds[i]
            let key = spatialDebugColorKey(item.color)
            if occludedGroupedBounds[key] == nil {
                occludedGroupedBounds[key] = (color: item.color, bounds: [])
                occludedGroupOrder.append(key)
            }
            occludedGroupedBounds[key]?.bounds.append(item.bounds)
        }

        var lineVertices: [SIMD4<Float>] = []
        let drawBoundsCount = drawLeafCount + drawStaticBatchCellCount + drawTileCount + drawOccludedCount
        lineVertices.reserveCapacity(drawBoundsCount * 24)
        var batches: [SpatialDebugLineBatch] = []
        batches.reserveCapacity(groupOrder.count)

        for key in groupOrder {
            guard let group = groupedBounds[key] else { continue }
            let vertexStart = lineVertices.count

            for bounds in group.bounds {
                appendAABBLineVertices(bounds, to: &lineVertices)
            }

            let vertexCount = lineVertices.count - vertexStart
            if vertexCount > 0 {
                batches.append(
                    SpatialDebugLineBatch(
                        color: group.color,
                        vertexStart: vertexStart,
                        vertexCount: vertexCount
                    )
                )
            }
        }

        var occludedBatches: [SpatialDebugLineBatch] = []
        occludedBatches.reserveCapacity(occludedGroupOrder.count)
        for key in occludedGroupOrder {
            guard let group = occludedGroupedBounds[key] else { continue }
            let vertexStart = lineVertices.count

            for bounds in group.bounds {
                appendAABBLineVertices(bounds, to: &lineVertices)
            }

            let vertexCount = lineVertices.count - vertexStart
            if vertexCount > 0 {
                occludedBatches.append(
                    SpatialDebugLineBatch(
                        color: group.color,
                        vertexStart: vertexStart,
                        vertexCount: vertexCount
                    )
                )
            }
        }

        let requiredVertexCount = lineVertices.count
        guard requiredVertexCount > 0 else {
            return
        }

        let vertexStride = MemoryLayout<SIMD4<Float>>.stride
        let requiredLength = requiredVertexCount * vertexStride

        guard let lineBuffer = ensureSpatialDebugLineBuffer(
            device: renderInfo.device,
            requiredVertexCount: requiredVertexCount,
            vertexStride: vertexStride
        ) else {
            handleError(.bufferAllocationFailed, "Spatial Debug Leaf Bounds Buffer")
            return
        }

        lineVertices.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.baseAddress else { return }
            lineBuffer.contents().copyMemory(from: src, byteCount: requiredLength)
        }

        // Render as overlay on top of lit scene while preserving depth testing.
        encoderDescriptor.colorAttachments[0].loadAction = .load
        encoderDescriptor.colorAttachments[0].storeAction = .store
        encoderDescriptor.depthAttachment.loadAction = .load
        encoderDescriptor.depthAttachment.storeAction = .store

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor) else {
            handleError(.renderPassCreationFailed, "Spatial Debug Bounds Pass")
            return
        }

        defer {
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
        }

        renderEncoder.label = "Spatial Debug Bounds Pass"
        renderEncoder.pushDebugGroup("Spatial Debug Bounds Pass")

        renderEncoder.setRenderPipelineState(spatialDebugPipeline.pipelineState!)
        if let depthState = spatialDebugPipeline.depthState {
            renderEncoder.setDepthStencilState(depthState)
        }
        renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
        renderEncoder.setCullMode(.none)

        var viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        var projectionMatrix = renderInfo.perspectiveSpace
        var modelMatrix = matrix_identity_float4x4
        var scale = simd_float3(repeating: 1.0)

        renderEncoder.setVertexBuffer(lineBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&viewMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 1)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 2)
        renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout<simd_float4x4>.stride, index: 3)
        renderEncoder.setVertexBytes(&scale, length: MemoryLayout<simd_float3>.stride, index: 4)

        for batch in batches {
            var debugColor = batch.color
            renderEncoder.setFragmentBytes(
                &debugColor,
                length: MemoryLayout<simd_float4>.stride,
                index: 0
            )
            renderEncoder.drawPrimitivesTracked(
                type: .line,
                vertexStart: batch.vertexStart,
                vertexCount: batch.vertexCount,
                category: .other
            )
        }

        // Occluded entity bounds must draw on top of occluding geometry, so switch to
        // an always-pass depth state before drawing them.
        if !occludedBatches.isEmpty {
            let alwaysState = getOrCreateAlwaysDepthState(device: renderInfo.device)
            if let alwaysState {
                renderEncoder.setDepthStencilState(alwaysState)
            }
            for batch in occludedBatches {
                var debugColor = batch.color
                renderEncoder.setFragmentBytes(
                    &debugColor,
                    length: MemoryLayout<simd_float4>.stride,
                    index: 0
                )
                renderEncoder.drawPrimitivesTracked(
                    type: .line,
                    vertexStart: batch.vertexStart,
                    vertexCount: batch.vertexCount,
                    category: .other
                )
            }
        }

        renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    }

    public static let gaussianExecution: RenderPassExecution = { commandBuffer in
        #if targetEnvironment(simulator)
            // Gaussian splatting needs tile shaders, which the simulator doesn't
            // support — the pipelines were never created, so skip quietly.
            _ = commandBuffer
            return
        #else
            EngineProfiler.shared.beginScope(.gaussianDraw)
            defer { EngineProfiler.shared.endScope(.gaussianDraw) }

            let profileStart = gaussianProfilingStartTime()
            var profileTotals = GaussianProfileTotals()
            var activeSplatTotal = 0

            let pipelines = PipelineManager.shared.renderPipelinesByType
            guard let initializePipeline = pipelines[.gaussianTBDRInitialize],
                  let drawPipeline = pipelines[.gaussianTBDRDraw],
                  let postprocessPipeline = pipelines[.gaussianTBDRPostprocess]
            else {
                handleError(.pipelineStateNulled, "Gaussian TBDR pipelines are nil")
                return
            }

            if !initializePipeline.success || !drawPipeline.success || !postprocessPipeline.success {
                handleError(.pipelineStateNulled, "Gaussian TBDR pipeline creation failed")
                return
            }

            guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
                handleError(.noActiveCamera)
                return
            }

            guard let renderPassDescriptor = renderInfo.gaussianRenderPassDescriptor else {
                handleError(.renderPassCreationFailed, "Gaussian render pass descriptor not initialized")
                return
            }

            guard let initializePipelineState = initializePipeline.pipelineState,
                  let drawPipelineState = drawPipeline.pipelineState,
                  let postprocessPipelineState = postprocessPipeline.pipelineState
            else {
                handleError(.pipelineStateNulled, "Gaussian TBDR pipeline state is nil")
                return
            }

            renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
            renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
            renderPassDescriptor.depthAttachment.loadAction = MTLLoadAction.load
            renderPassDescriptor.depthAttachment.storeAction = MTLStoreAction.store
            renderPassDescriptor.tileWidth = 32
            renderPassDescriptor.tileHeight = 32
            renderPassDescriptor.imageblockSampleLength = initializePipelineState.imageblockSampleLength

            // Snapshot the opaque depth before the pass so splats can be occluded by it.
            // depthMap is also this pass's own .load'ed depth attachment below, and this
            // engine never binds the same texture as both an attachment and a
            // separately-sampled argument in one encoder (see copyOpaqueDepthForHZBExecution
            // for the same precaution) — so the draw stage reads this copy instead.
            if let sourceDepth = textureResources.depthMap,
               let opaqueDepthSnapshot = textureResources.gaussianOpaqueDepthSnapshot
            {
                let width = min(sourceDepth.width, opaqueDepthSnapshot.width)
                let height = min(sourceDepth.height, opaqueDepthSnapshot.height)
                if width > 0, height > 0, let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                    blitEncoder.label = "Copy Opaque Depth for Gaussian Occlusion"
                    blitEncoder.copy(
                        from: sourceDepth,
                        sourceSlice: 0, sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: width, height: height, depth: 1),
                        to: opaqueDepthSnapshot,
                        destinationSlice: 0, destinationLevel: 0,
                        destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
                    )
                    blitEncoder.endEncoding()
                }
            }

            guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                handleError(.renderPassCreationFailed, "Gaussian Pass")
                return
            }

            renderEncoder.label = "Gaussian Pass"

            renderEncoder.pushDebugGroup("Gaussian Pass")

            renderEncoder.pushDebugGroup("Initialize")
            renderEncoder.setRenderPipelineState(initializePipelineState)
            renderEncoder.dispatchThreadsPerTile(MTLSize(width: 32, height: 32, depth: 1))
            profileTotals.dispatchCount += 1
            renderEncoder.popDebugGroup()

            renderEncoder.pushDebugGroup("Draw Splats")
            renderEncoder.setRenderPipelineState(drawPipelineState)
            renderEncoder.setDepthStencilState(drawPipeline.depthState)

            renderEncoder.setFragmentTexture(
                textureResources.gaussianOpaqueDepthSnapshot,
                index: Int(gaussianTBDRDrawOpaqueDepthTextureIndex.rawValue)
            )
            var gaussianDrawReverseZ = renderInfo.reverseZEnabled
            renderEncoder.setFragmentBytes(
                &gaussianDrawReverseZ,
                length: MemoryLayout<Bool>.stride,
                index: Int(gaussianTBDRRenderReverseZIndex.rawValue)
            )

            let transformId = getComponentId(for: WorldTransformComponent.self)
            let gaussianId = getComponentId(for: GaussianComponent.self)
            let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)
            let effectiveViewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
            let effectiveCameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

            for entityId in entities {
                guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
                    handleError(.noGaussianComponent, entityId)
                    continue
                }
                profileTotals.include(component: gaussianComponent)

                let activeSplatCount = min(Int(gaussianComponent.visibleSplatCountForRendering), Int(gaussianComponent.splatCount))
                guard activeSplatCount > 0 else { continue }
                activeSplatTotal += activeSplatCount

                guard gaussianComponent.encodedSplatData != nil else {
                    handleError(.bufferAllocationFailed, "Encoded Gaussian splat buffer")
                    continue
                }

                guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
                    handleError(.noWorldTransformComponent, entityId)
                    continue
                }

                guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
                    handleError(.noLocalTransformComponent, entityId)
                    continue
                }

                // update uniforms
                var gaussianUniform = Uniforms()

                let rootMatrix = worldTransformComponent.space
                var modelMatrix = simd_mul(rootMatrix, .identity)

                let viewMatrix: simd_float4x4 = effectiveViewMatrix

                let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

                let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

                let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

                let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

                gaussianUniform.modelViewMatrix = modelViewMatrix

                gaussianUniform.normalMatrix = normalMatrix

                gaussianUniform.viewMatrix = viewMatrix

                gaussianUniform.modelMatrix = modelMatrix

                gaussianUniform.cameraPosition = effectiveCameraPosition

                gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

                guard !gaussianComponent.spaceUniform.isEmpty else {
                    handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
                    return
                }
                let uniformBufferIndex = min(currentUniformBufferIndex(), gaussianComponent.spaceUniform.count - 1)

                if let gaussianUniformBuffer = gaussianComponent.spaceUniform[uniformBufferIndex] {
                    gaussianUniformBuffer.contents().copyMemory(
                        from: &gaussianUniform, byteCount: MemoryLayout<Uniforms>.stride
                    )
                } else {
                    handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
                    return
                }

                // bind data here
                // Same frame-slot indexing as executeGaussianFrustumCulling/executeGaussianDepth/
                // executeRadixSort — renderInfo.currentInFlightFrameSlot is set once per frame
                // and stays constant across both eyes, so this correctly reads back whichever
                // slot this frame's cull/sort pipeline wrote into.
                let gaussianFrameSlot = min(renderInfo.currentInFlightFrameSlot, gaussianComponent.gaussianSortedIndices.count - 1)
                renderEncoder.setVertexBuffer(
                    gaussianComponent.gaussianSortedIndices[gaussianFrameSlot],
                    offset: 0,
                    index: Int(gaussianTBDRRenderIndicesIndex.rawValue)
                )

                renderEncoder.setVertexBuffer(gaussianComponent.encodedSplatData, offset: 0, index: Int(gaussianTBDRRenderSplatIndex.rawValue))
                renderEncoder.setVertexBuffer(
                    gaussianComponent.spaceUniform[uniformBufferIndex], offset: 0, index: Int(gaussianTBDRRenderUniformIndex.rawValue)
                )
                renderEncoder.setVertexBytes(&renderInfo.viewPort, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianTBDRRenderViewPortIndex.rawValue))

                // Conic/radius/color are precomputed once per splat per frame by
                // executeGaussianPreprocess (see GaussianSystem.swift) instead of being
                // recomputed here 4x per splat (once per instanced quad vertex).
                renderEncoder.setVertexBuffer(
                    gaussianComponent.gaussianPrecomputedData[gaussianFrameSlot],
                    offset: 0,
                    index: Int(gaussianTBDRRenderPrecomputedIndex.rawValue)
                )

                renderEncoder.drawPrimitivesTracked(type: .triangleStrip,
                                                    vertexStart: 0,
                                                    vertexCount: 4,
                                                    instanceCount: activeSplatCount)
                profileTotals.drawCallCount += 1
            }

            renderEncoder.popDebugGroup()

            renderEncoder.pushDebugGroup("Postprocess")
            renderEncoder.setRenderPipelineState(postprocessPipelineState)
            renderEncoder.setDepthStencilState(postprocessPipeline.depthState)
            var reverseZ = renderInfo.reverseZEnabled
            renderEncoder.setFragmentBytes(&reverseZ, length: MemoryLayout<Bool>.stride, index: Int(gaussianTBDRRenderReverseZIndex.rawValue))
            renderEncoder.drawPrimitivesTracked(type: .triangle, vertexStart: 0, vertexCount: 3)
            profileTotals.drawCallCount += 1
            renderEncoder.popDebugGroup()

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
            logGaussianProfile(
                stage: "Render",
                startTime: profileStart,
                totals: profileTotals,
                extra: String(format: "activeSplats=%d viewport=%.0fx%.0f tile=32x32", activeSplatTotal, renderInfo.viewPort.x, renderInfo.viewPort.y)
            )
        #endif
    }

    static func executePostProcess(
        _ pipeline: RenderPipeline,
        source: MTLTexture,
        destination: MTLTexture,
        customization: @escaping (_ encoder: MTLRenderCommandEncoder) -> Void
    ) -> (MTLCommandBuffer) -> Void {
        { commandBuffer in
            if !pipeline.success {
                handleError(.pipelineStateNulled, "Post Process Pipeline")
                return
            }

            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].texture = destination

            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].loadAction = .clear
            renderInfo.postProcessRenderPassDescriptor.colorAttachments[0].storeAction = .store
            renderInfo.postProcessRenderPassDescriptor.depthAttachment.loadAction = .load

            guard let renderPassDescriptor = renderInfo.postProcessRenderPassDescriptor else {
                handleError(.renderPassCreationFailed, "Post-process render pass descriptor not initialized")
                return
            }

            // set your encoder here
            guard
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else {
                handleError(.renderPassCreationFailed, "Post Process \(pipeline.name!) Pass")
                return
            }

            defer {
                // Make sure no matter what we end the encoding at the end of the function
                renderEncoder.popDebugGroup()
                renderEncoder.endEncoding()
            }

            renderEncoder.label = "Post-Processing Pass"

            renderEncoder.pushDebugGroup("Post-Processing")

            renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setFragmentTexture(source, index: 0)

            // Pass in individual post-process values
            customization(renderEncoder)
            // set the draw command
            renderEncoder.drawIndexedPrimitivesTracked(
                type: .triangle,
                indexCount: 6,
                indexType: .uint16,
                indexBuffer: bufferResources.quadIndexBuffer!,
                indexBufferOffset: 0
            )

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
        }
    }
}

extension float4x4 {
    init(scale s: SIMD3<Float>) {
        self.init(SIMD4<Float>(s.x, 0, 0, 0),
                  SIMD4<Float>(0, s.y, 0, 0),
                  SIMD4<Float>(0, 0, s.z, 0),
                  SIMD4<Float>(0, 0, 0, 1))
    }
}

@inline(__always)
private func uploadAndBindLights<T>(
    buffer: MTLBuffer?,
    lights: [T],
    maxCount: Int,
    headerSize: Int = 16, // uint4 header
    encoder: MTLRenderCommandEncoder,
    bufferIndex: Int,
    labelForErrors: String
) -> Bool {
    guard let buf = buffer else {
        print("Missing buffer for \(labelForErrors)")
        return false
    }

    // Cap to buffer capacity
    let capped = min(lights.count, maxCount)

    // Write count (UInt32) at offset 0; rest of uint4 padding can remain garbage
    buf.contents().storeBytes(of: UInt32(capped), toByteOffset: 0, as: UInt32.self)

    // Copy array right after header
    let dst = buf.contents().advanced(by: headerSize)
    let nBytes = capped * MemoryLayout<T>.stride

    lights.withUnsafeBytes { raw in
        dst.copyMemory(from: raw.baseAddress!, byteCount: nBytes)
    }

    // Bind
    encoder.setFragmentBuffer(buf, offset: 0, index: bufferIndex)
    return true
}

// MARK: - Shadow cascade distance helpers (internal — exposed for testing via @testable import)

/// Returns the effective maximum shadow-casting distance for a single CSM cascade.
///
/// Each cascade only needs shadow casters within its own split range.  Capping at the
/// cascade's split distance prevents the near cascade from receiving distant casters
/// that are only relevant to farther cascades, reducing shadow draw calls on cascade 0.
///
/// - Parameters:
///   - cascadeIdx:    Index of the cascade (0 = nearest).
///   - splitDistances: Per-cascade far-plane distances from the camera, as computed by ShadowSystem.
///   - globalMax:     The scene-wide shadow distance cap (RenderPasses.maxShadowCastingDistance).
/// - Returns: The tighter of globalMax and the cascade's own split distance.
func shadowCascadeMaxDistance(
    cascadeIdx: Int,
    splitDistances: [Float],
    globalMax: Float
) -> Float {
    guard cascadeIdx < splitDistances.count else { return globalMax }
    return min(globalMax, splitDistances[cascadeIdx])
}

/// Returns true when the entity's AABB is farther than maxDistance from the camera.
/// Uses closest-point-on-AABB distance so large meshes near the camera are never wrongly excluded.
/// maxDistance == 0 disables culling (always returns false).
func shadowEntityBeyondMaxDistance(
    worldMin: simd_float3,
    worldMax: simd_float3,
    cameraPosition: simd_float3,
    maxDistance: Float
) -> Bool {
    guard maxDistance > 0 else { return false }
    let closest = simd_clamp(cameraPosition, worldMin, worldMax)
    return simd_distance(cameraPosition, closest) > maxDistance
}
