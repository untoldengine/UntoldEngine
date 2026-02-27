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
    case automatic
    case cpuOnly
    case octreePreferred
    case gpuOnly
    // Deprecated alias for backward compatibility
    @available(*, deprecated, renamed: "octreePreferred")
    static let gpuPreferred = octreePreferred
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

public func pickEntity(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    options: ScenePickOptions = ScenePickOptions()
) -> ScenePickHit? {
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    if options.backend == .gpuOnly, !scenePickingCanUseGPU() {
        return nil
    }

    switch resolveScenePickingBackend(options.backend) {
    case .octree:
        return pickEntityOctreeRay(
            rayOrigin: rayOrigin,
            normalizedRayDirection: normalizedRayDirection,
            options: options
        )
    case .cpu:
        return pickEntityCPU(
            rayOrigin: rayOrigin,
            normalizedRayDirection: normalizedRayDirection,
            options: options
        )
    case .gpu:
        switch pickEntityGPU(
            rayOrigin: rayOrigin,
            normalizedRayDirection: normalizedRayDirection,
            options: options,
            allowNonBlockingRebuild: options.backend != .gpuOnly,
            allowNonBlockingRayQuery: options.backend != .gpuOnly
        ) {
        case let .hit(hit):
            return hit
        case .miss:
            return nil
        case .pending:
            break
        case .error:
            break
        }

        if options.backend == .gpuOnly {
            return nil
        }

        return pickEntityCPU(
            rayOrigin: rayOrigin,
            normalizedRayDirection: normalizedRayDirection,
            options: options
        )
    }
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

private func pickEntityOctreeRay(
    rayOrigin: simd_float3,
    normalizedRayDirection: simd_float3,
    options: ScenePickOptions
) -> ScenePickHit? {
    guard OctreeSystem.shared.enabled else { return nil }
    
    // Use a sphere that encompasses reasonable hit distance for ray queries
    // Start with a large radius to find candidates
    let searchRadius: Float = 500.0
    let sphere = BoundingSphere(center: rayOrigin, radius: searchRadius)
    let candidateEntities = OctreeSystem.shared.query(sphere: sphere)
    
    var bestEntity: EntityID?
    var bestDistance = Float.greatestFiniteMagnitude
    
    for entityId in candidateEntities {
        guard scene.mask(for: entityId) != nil else { continue }
        if hasComponent(entityId: entityId, componentType: CameraComponent.self) { continue }
        if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) { continue }
        
        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            continue
        }
        
        if !renderComponent.isVisible { continue }
        
        // Test ray vs AABB intersection
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
        if hasComponent(entityId: entityId, componentType: CameraComponent.self) { continue }
        if hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) { continue }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else {
            continue
        }

        if !renderComponent.isVisible { continue }

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
    }

    if options.isGizmoActive, !InputSystem.shared.keyState.shiftPressed {
        let gizmoId = getComponentId(for: GizmoComponent.self)
        return queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)
    }

    return visibleEntityIds
}

@inline(__always)
private func resolveScenePickingBackend(_ preference: ScenePickingBackendPreference) -> ScenePickingResolvedBackend {
    switch preference {
    case .cpuOnly:
        return .cpu
    case .gpuOnly:
        return scenePickingCanUseGPU() ? .gpu : .cpu
    case .octreePreferred:
        // Prefer Octree (fast, no build overhead) -> GPU (precise) -> CPU (fallback)
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
