//
//  ScenePickingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public enum ScenePickingBackendPreference {
    /// Automatic: octree broad-phase + GPU narrow-phase if available, otherwise GPU-only, else CPU.
    case automatic
    /// CPU-only ray-AABB intersection (no GPU acceleration structures).
    case cpuOnly
    /// Octree broad-phase (ray vs octree node AABBs) followed by GPU ray-triangle on the narrow
    /// candidate set. Falls back to ray-AABB results when GPU is unavailable.
    case octreeGPUPreferred
    /// GPU ray-triangle for all visible entities (builds full acceleration structure).
    case gpuOnly
    // Deprecated aliases for backward compatibility
    @available(*, deprecated, renamed: "octreeGPUPreferred")
    static let gpuPreferred = octreeGPUPreferred
    @available(*, deprecated, renamed: "octreeGPUPreferred")
    static let octreePreferred = octreeGPUPreferred
}

public struct ScenePickOptions {
    public var isGizmoActive: Bool
    public var gizmoOnly: Bool
    public var maxDistance: Float
    public var backend: ScenePickingBackendPreference

    public init(
        isGizmoActive: Bool = false,
        gizmoOnly: Bool = false,
        maxDistance: Float = .greatestFiniteMagnitude,
        backend: ScenePickingBackendPreference = .automatic
    ) {
        self.isGizmoActive = isGizmoActive
        self.gizmoOnly = gizmoOnly
        self.maxDistance = maxDistance
        self.backend = backend
    }
}

public struct ScenePickHit {
    public let entityId: EntityID
    public let distance: Float
    public let worldPosition: simd_float3
    public let worldNormal: simd_float3?
    public let triangleIndex: UInt32?

    public init(
        entityId: EntityID,
        distance: Float,
        worldPosition: simd_float3,
        worldNormal: simd_float3? = nil,
        triangleIndex: UInt32? = nil
    ) {
        self.entityId = entityId
        self.distance = distance
        self.worldPosition = worldPosition
        self.worldNormal = worldNormal
        self.triangleIndex = triangleIndex
    }
}

private enum ScenePickingResolvedBackend {
    case cpu
    case gpu
    case octree
}

public func initScenePickingSystem() {
    scenePickingSystemInitialized = true
    scenePickingDirtyEntities.removeAll()
    initScenePickingGPUResources()
}

public func shutdownScenePickingSystem() {
    shutdownScenePickingGPUResources()
    scenePickingSystemInitialized = false
    scenePickingDirtyEntities.removeAll()
}

public func setIgnoreRayIntersectionWithTransparents(_ enabled: Bool) {
    scenePickingIgnoreRayIntersectionWithTransparents = enabled
}

public func isIgnoringRayIntersectionWithTransparents() -> Bool {
    scenePickingIgnoreRayIntersectionWithTransparents
}

public func pickEntity(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    options: ScenePickOptions = ScenePickOptions()
) -> ScenePickHit? {
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    // Transform the ray into entity-local space by applying the inverse scene root.
    // Entities live in un-shifted world space; the scene root only shifts the camera.
    let srt = SceneRootTransform.shared
    let localOrigin: simd_float3
    let localDirection: simd_float3
    if srt.isIdentity {
        localOrigin = rayOrigin
        localDirection = normalizedRayDirection
    } else {
        let invM = srt.inverseMatrix
        let o = simd_mul(invM, simd_float4(rayOrigin, 1.0))
        localOrigin = simd_float3(o.x, o.y, o.z)
        let d = simd_mul(invM, simd_float4(normalizedRayDirection, 0.0))
        localDirection = simd_normalize(simd_float3(d.x, d.y, d.z))
    }

    if options.backend == .gpuOnly, !scenePickingCanUseGPU() {
        return nil
    }

    var hit: ScenePickHit?
    switch resolveScenePickingBackend(options.backend) {
    case .octree:
        hit = pickEntityOctreeGPU(
            rayOrigin: localOrigin,
            normalizedRayDirection: localDirection,
            options: options
        )
    case .cpu:
        hit = pickEntityCPU(
            rayOrigin: localOrigin,
            normalizedRayDirection: localDirection,
            options: options
        )
    case .gpu:
        switch pickEntityGPU(
            rayOrigin: localOrigin,
            normalizedRayDirection: localDirection,
            options: options,
            allowNonBlockingRebuild: options.backend != .gpuOnly,
            allowNonBlockingRayQuery: options.backend != .gpuOnly
        ) {
        case let .hit(h):
            hit = h
        case .miss:
            hit = nil
        case .pending:
            break
        case .error:
            break
        }

        if hit == nil, options.backend == .gpuOnly {
            return nil
        }

        if hit == nil {
            hit = pickEntityCPU(
                rayOrigin: localOrigin,
                normalizedRayDirection: localDirection,
                options: options
            )
        }
    }

    // Back-transform hit position into the caller's (scene-root-shifted) world space.
    guard let h = hit, !srt.isIdentity else { return hit }
    let wp = simd_mul(srt.matrix, simd_float4(h.worldPosition, 1.0))
    return ScenePickHit(
        entityId: h.entityId,
        distance: h.distance,
        worldPosition: simd_float3(wp.x, wp.y, wp.z),
        worldNormal: h.worldNormal,
        triangleIndex: h.triangleIndex
    )
}

@available(*, deprecated, message: "Use pickEntity(rayOrigin:rayDirection:options:) to receive ScenePickHit.")
public func pickEntity(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    isGizmoActive: Bool = false
) -> (EntityID, Float)? {
    guard let hit = pickEntity(
        rayOrigin: rayOrigin,
        rayDirection: rayDirection,
        options: ScenePickOptions(isGizmoActive: isGizmoActive)
    ) else {
        return nil
    }

    return (hit.entityId, hit.distance)
}

private func pickEntityOctreeGPU(
    rayOrigin: simd_float3,
    normalizedRayDirection: simd_float3,
    options: ScenePickOptions
) -> ScenePickHit? {
    guard OctreeSystem.shared.enabled else { return nil }

    // --- Stage 1: Ray-traverse octree to find narrow candidate set ---
    let octreeHits = OctreeSystem.shared.query(
        rayOrigin: rayOrigin,
        rayDirection: normalizedRayDirection,
        maxDistance: options.maxDistance
    )

    guard !octreeHits.isEmpty else { return nil }

    // Filter candidates (cameras, invisible, transparency, gizmo mode).
    let gizmoOnly = options.gizmoOnly
        || (options.isGizmoActive && !InputSystem.shared.keyState.shiftPressed)

    var filteredCandidates: [EntityID] = []
    var bestAABBEntity: EntityID?
    var bestAABBDistance = Float.greatestFiniteMagnitude

    for (entityId, distance) in octreeHits {
        guard scene.mask(for: entityId) != nil else { continue }
        if scenePickingShouldIgnoreEntityForRayPicking(entityId) { continue }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { continue }
        if !renderComponent.isVisible { continue }
        if scenePickingShouldIgnoreEntityDueToTransparency(renderComponent) { continue }

        if gizmoOnly {
            guard hasComponent(entityId: entityId, componentType: GizmoComponent.self) else { continue }
        }

        filteredCandidates.append(entityId)

        // Track best AABB hit as fallback when GPU is unavailable.
        if distance < bestAABBDistance {
            bestAABBDistance = distance
            bestAABBEntity = entityId
        }
    }

    guard !filteredCandidates.isEmpty else { return nil }

    // --- Stage 2: GPU ray-triangle intersection on narrow candidates ---
    if let gpuHit = pickEntityGPUWithCandidates(
        candidates: filteredCandidates,
        rayOrigin: rayOrigin,
        normalizedRayDirection: normalizedRayDirection,
        options: options
    ) {
        return gpuHit
    }

    // Fallback: return best ray-AABB hit when GPU is unavailable.
    guard let bestAABBEntity else { return nil }
    let worldPosition = rayOrigin + normalizedRayDirection * bestAABBDistance
    return ScenePickHit(entityId: bestAABBEntity, distance: bestAABBDistance, worldPosition: worldPosition)
}

private func pickEntityCPU(
    rayOrigin: simd_float3,
    normalizedRayDirection: simd_float3,
    options: ScenePickOptions
) -> ScenePickHit? {
    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)

    let candidates = scenePickingCandidates(
        options: options,
        transformId: transformId,
        renderId: renderId
    )

    var bestEntity: EntityID?
    var bestDistance = Float.greatestFiniteMagnitude

    for entityId in candidates {
        guard scene.mask(for: entityId) != nil else { continue }
        if scenePickingShouldIgnoreEntityForRayPicking(entityId) { continue }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            continue
        }

        if !renderComponent.isVisible { continue }
        if scenePickingShouldIgnoreEntityDueToTransparency(renderComponent) { continue }

        let localMin = simd_min(localTransform.boundingBox.min, localTransform.boundingBox.max)
        let localMax = simd_max(localTransform.boundingBox.min, localTransform.boundingBox.max)

        let (worldMinRaw, worldMaxRaw) = worldAABB_MinMax(
            localMin: localMin,
            localMax: localMax,
            worldMatrix: worldTransform.space
        )

        let worldMin = simd_min(worldMinRaw, worldMaxRaw)
        let worldMax = simd_max(worldMinRaw, worldMaxRaw)
        guard isFiniteVector3(worldMin), isFiniteVector3(worldMax) else { continue }

        guard let distance = rayAABBIntersectionDistance(
            rayOrigin: rayOrigin,
            rayDirection: normalizedRayDirection,
            minBounds: worldMin,
            maxBounds: worldMax
        ) else {
            continue
        }

        if distance > options.maxDistance { continue }

        if distance < bestDistance {
            bestDistance = distance
            bestEntity = entityId
        }
    }

    guard let bestEntity else { return nil }
    let worldPosition = rayOrigin + normalizedRayDirection * bestDistance
    return ScenePickHit(entityId: bestEntity, distance: bestDistance, worldPosition: worldPosition)
}

private func scenePickingCandidates(
    options: ScenePickOptions,
    transformId: Int,
    renderId: Int
) -> [EntityID] {
    if options.gizmoOnly {
        let gizmoId = getComponentId(for: GizmoComponent.self)
        return queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)
            .filter { !scenePickingShouldIgnoreEntityForRayPicking($0) }
    }

    if options.isGizmoActive, !InputSystem.shared.keyState.shiftPressed {
        let gizmoId = getComponentId(for: GizmoComponent.self)
        return queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)
            .filter { !scenePickingShouldIgnoreEntityForRayPicking($0) }
    }

    return visibleEntityIds.filter { !scenePickingShouldIgnoreEntityForRayPicking($0) }
}

@inline(__always)
func scenePickingShouldIgnoreEntityForRayPicking(_ entityId: EntityID) -> Bool {
    let shouldIgnoreLightInGameMode =
        gameMode && hasComponent(entityId: entityId, componentType: LightComponent.self)

    return hasComponent(entityId: entityId, componentType: CameraComponent.self)
        || hasComponent(entityId: entityId, componentType: SceneCameraComponent.self)
        || shouldIgnoreLightInGameMode
}

@inline(__always)
func scenePickingHasTransparentSubmesh(_ renderComponent: RenderComponent) -> Bool {
    renderComponent.mesh.contains { mesh in
        mesh.submeshes.contains { submesh in
            submesh.material?.hasTransparency ?? false
        }
    }
}

@inline(__always)
func scenePickingShouldIgnoreEntityDueToTransparency(_ renderComponent: RenderComponent) -> Bool {
    scenePickingIgnoreRayIntersectionWithTransparents
        && scenePickingHasTransparentSubmesh(renderComponent)
}

@inline(__always)
private func resolveScenePickingBackend(_ preference: ScenePickingBackendPreference) -> ScenePickingResolvedBackend {
    switch preference {
    case .cpuOnly:
        return .cpu
    case .gpuOnly:
        return scenePickingCanUseGPU() ? .gpu : .cpu
    case .octreeGPUPreferred:
        // Prefer Octree broad-phase + GPU narrow-phase -> GPU (precise) -> CPU (fallback)
        if OctreeSystem.shared.enabled {
            return .octree
        }
        return scenePickingCanUseGPU() ? .gpu : .cpu
    case .automatic:
        // Automatic: use Octree if available, otherwise GPU if available, else CPU
        if OctreeSystem.shared.enabled {
            return .octree
        }
        return scenePickingCanUseGPU() ? .gpu : .cpu
    }
}
