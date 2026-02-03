//
//  LODSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

public class LODSystem {
    public static let shared = LODSystem()
    private init() {}

    public func update(deltaTime: Float) {
        // Get active camer
        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else { return }

        let cameraPosition = cameraComponent.localPosition

        // Query entities with LOD components
        let lodId = getComponentId(for: LODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        for entityId in entities {
            updateEntityLOD(entityId: entityId, cameraPosition: cameraPosition, deltaTime: deltaTime)
        }
    }

    private func updateEntityLOD(entityId: EntityID, cameraPosition: simd_float3, deltaTime: Float) {
        // Calculate distance
        let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)

        // Get current LOD Component
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else { return }

        // Select new LOD level
        let newLOD = selectLODLevel(distance: distance, lodComponent: lodComponent, currentLOD: lodComponent.currentLOD)

        // Apply the LOD (handles transitions, updates render component)
        applyLOD(entityId: entityId, newLOD: newLOD, deltaTime: deltaTime)
    }

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId), let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) else { return 0.0 }

        // Get entity center from AABB
        let boundingBox = localTransform.boundingBox
        let localCenter = (boundingBox.min + boundingBox.max) * 0.5

        // Tranform to world space
        let worldCenter = worldTransform.space * simd_float4(localCenter, 1.0)

        // Calculate distance from camera to entity center
        let distance = simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))

        // Optional: Adjust by object size (larger objects can have more lods)
        // Uncomment below to enable size-aware LOD
        // let objectSize = simd_length(boundingBox.max - boundingBox.min)
        // return distance / max(objectSize * 0.5, 1.0)

        return distance
    }

    private func selectLODLevel(distance: Float, lodComponent: LODComponent, currentLOD: Int) -> Int {
        // Check for forced LOD override
        if let forced = lodComponent.forcedLOD, forced >= 0 {
            return min(forced, lodComponent.lodLevels.count - 1)
        }

        // Apply LOD bias
        let adjustedDistance = distance * LODConfig.shared.lodBias

        // Find appropriate LOD level
        for (index, lodLevel) in lodComponent.lodLevels.enumerated() {
            var threshold = lodLevel.maxDistance

            // Apply hysteresis when switching to higher detail (prevents flickering)
            if index < currentLOD {
                threshold -= LODConfig.shared.hysteresis
            }

            if adjustedDistance <= threshold {
                return index
            }
        }

        // Beyond all thresholds, use lowest LOD
        return lodComponent.lodLevels.count - 1
    }

    private func applyLOD(entityId: EntityID, newLOD: Int, deltaTime: Float) {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId), let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
            return
        }

        let currentLOD = lodComponent.currentLOD

        // No change needed
        if newLOD == currentLOD, lodComponent.previousLOD == nil {
            return
        }

        // Handle fade transitions
        if LODConfig.shared.enableFadeTransitions {
            if newLOD != currentLOD {
                // Start transition
                lodComponent.previousLOD = currentLOD
                lodComponent.currentLOD = newLOD
                lodComponent.transitionProgress = 0.0
            }

            // Update transition
            if lodComponent.previousLOD != nil {
                lodComponent.transitionProgress += deltaTime / LODConfig.shared.fadeTransitionTime

                if lodComponent.transitionProgress >= 1.0 {
                    // Transition complete
                    lodComponent.previousLOD = nil
                    lodComponent.transitionProgress = 0.0
                }
            }
        } else {
            // Instant switch
            lodComponent.currentLOD = newLOD
            lodComponent.previousLOD = nil
        }

        // Update render component with new LOD meshes
        // Safety check: ensure LOD level exists and has valid mesh data
        if newLOD >= 0, newLOD < lodComponent.lodLevels.count {
            let lodLevel = lodComponent.lodLevels[newLOD]
            // Skip placeholder LODs (empty mesh arrays)
            if !lodLevel.mesh.isEmpty {
                renderComponent.mesh = lodLevel.mesh
            }
        }
    }
}
