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

public func pickEntity(rayOrigin: simd_float3, rayDirection: simd_float3, isGizmoActive: Bool = false) -> (EntityID, Float)? {
    let rayLengthSquared = simd_length_squared(rayDirection)
    guard rayLengthSquared.isFinite, rayLengthSquared > Float.ulpOfOne else { return nil }
    let normalizedRayDirection = rayDirection / sqrt(rayLengthSquared)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let renderId = getComponentId(for: RenderComponent.self)

    let candidates: [EntityID]
    if isGizmoActive, !InputSystem.shared.keyState.shiftPressed {
        let gizmoId = getComponentId(for: GizmoComponent.self)
        candidates = queryEntitiesWithComponentIds([transformId, renderId, gizmoId], in: scene)
    } else {
        candidates = visibleEntityIds
    }

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

        if distance < bestDistance {
            bestDistance = distance
            bestEntity = entityId
        }
    }

    guard let bestEntity else { return nil }
    return (bestEntity, bestDistance)
}

private func rayAABBIntersectionDistance(
    rayOrigin: simd_float3,
    rayDirection: simd_float3,
    minBounds: simd_float3,
    maxBounds: simd_float3
) -> Float? {
    guard isFiniteVector3(rayOrigin),
          isFiniteVector3(rayDirection),
          isFiniteVector3(minBounds),
          isFiniteVector3(maxBounds)
    else {
        return nil
    }

    let epsilon: Float = 0.000_001
    var tMin = -Float.greatestFiniteMagnitude
    var tMax = Float.greatestFiniteMagnitude

    for axis in 0 ..< 3 {
        let origin = rayOrigin[axis]
        let direction = rayDirection[axis]
        let minValue = minBounds[axis]
        let maxValue = maxBounds[axis]

        if abs(direction) <= epsilon {
            if origin < minValue || origin > maxValue {
                return nil
            }
            continue
        }

        let invDirection = 1.0 / direction
        var t1 = (minValue - origin) * invDirection
        var t2 = (maxValue - origin) * invDirection

        if t1 > t2 {
            swap(&t1, &t2)
        }

        tMin = max(tMin, t1)
        tMax = min(tMax, t2)

        if tMin > tMax {
            return nil
        }
    }

    if tMax < 0 {
        return nil
    }

    return tMin >= 0 ? tMin : tMax
}

@inline(__always)
private func isFiniteVector3(_ vector: simd_float3) -> Bool {
    vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
}
