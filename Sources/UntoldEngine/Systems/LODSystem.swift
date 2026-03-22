//
//  LODSystem.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public class LODSystem: @unchecked Sendable {
    public static let shared = LODSystem()
    private init() {}

    public func update(deltaTime: Float) {
        // Get active camera
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return }

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
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else { return }

        // Skip if no LOD levels loaded yet (async loading may still be in progress)
        guard !lodComponent.lodLevels.isEmpty else { return }

        // Calculate distance
        let distance = calculateDistance(entityId: entityId, cameraPosition: cameraPosition)

        // Select desired LOD level based on distance
        let desiredLOD = selectLODLevel(
            distance: distance,
            lodComponent: lodComponent,
            currentLOD: lodComponent.desiredLOD
        )

        lodComponent.desiredLOD = desiredLOD

        // Resolve actual LOD (check residency, find fallback if needed)
        let actualLOD = resolveActualLOD(
            entityId: entityId,
            lodComponent: lodComponent,
            desiredLOD: desiredLOD
        )

        // Apply the LOD (handles transitions, updates render component)
        applyLOD(entityId: entityId, newLOD: actualLOD, deltaTime: deltaTime)
    }

    /// Resolve desired LOD to actual LOD, falling back if mesh not resident
    private func resolveActualLOD(
        entityId _: EntityID,
        lodComponent: LODComponent,
        desiredLOD: Int
    ) -> Int {
        // Check if desired LOD mesh is resident
        if lodComponent.isLODResident(desiredLOD) {
            lodComponent.isUsingFallback = false
            return desiredLOD
        }

        // Desired LOD not resident - find fallback
        if let fallbackLOD = lodComponent.findFallbackLOD(from: desiredLOD) {
            lodComponent.isUsingFallback = true
            SystemIntegrationMonitor.shared.recordLODFallback()
            return fallbackLOD
        }

        // No fallback available - stay at current LOD
        lodComponent.isUsingFallback = true
        return lodComponent.currentLOD
    }

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return 0.0 }

        // Get entity center from AABB
        let boundingBox = localTransform.boundingBox
        let localCenter = (boundingBox.min + boundingBox.max) * 0.5

        // Transform to world space
        let worldCenter = worldTransform.space * simd_float4(localCenter, 1.0)

        // Calculate distance from camera to entity center
        return simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
    }

    private func selectLODLevel(distance: Float, lodComponent: LODComponent, currentLOD: Int) -> Int {
        // Check for forced LOD override
        if let forced = lodComponent.forcedLOD, forced >= 0 {
            return min(forced, lodComponent.lodLevels.count - 1)
        }

        // Apply LOD bias
        let adjustedDistance = distance * LODConfig.shared.lodBias
        let globalDistances = LODConfig.shared.lodDistances

        // Find appropriate LOD level.
        // Per-level maxDistance takes priority; fall back to LODConfig.lodDistances[index]
        // when maxDistance is 0 (unset). This lets users configure distances either
        // per-level at registration time OR globally via LODConfig.
        for (index, lodLevel) in lodComponent.lodLevels.enumerated() {
            let baseThreshold: Float
            if lodLevel.maxDistance > 0 {
                baseThreshold = lodLevel.maxDistance
            } else if index < globalDistances.count {
                baseThreshold = globalDistances[index]
            } else {
                continue // No threshold available for this level — skip
            }

            // Apply hysteresis when switching to higher detail (prevents flickering)
            let threshold = index < currentLOD
                ? baseThreshold - LODConfig.shared.hysteresis
                : baseThreshold

            if adjustedDistance <= threshold {
                return index
            }
        }

        // Beyond all thresholds, use lowest LOD
        return lodComponent.lodLevels.count - 1
    }

    private func applyLOD(entityId: EntityID, newLOD: Int, deltaTime: Float) {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId),
              let renderComponent = scene.get(component: RenderComponent.self, for: entityId)
        else { return }

        let previousLODIndex = lodComponent.currentLOD

        // No change needed
        if newLOD == previousLODIndex, lodComponent.previousLOD == nil {
            return
        }

        withWorldMutationGate {
            // Handle fade transitions
            if LODConfig.shared.enableFadeTransitions {
                if newLOD != previousLODIndex {
                    // Start transition
                    lodComponent.previousLOD = previousLODIndex
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
            if newLOD >= 0, newLOD < lodComponent.lodLevels.count {
                let lodLevel = lodComponent.lodLevels[newLOD]
                // Skip placeholder LODs (empty mesh arrays)
                if !lodLevel.mesh.isEmpty {
                    renderComponent.mesh = lodLevel.mesh

                    // Generate mesh asset ID for batching
                    let meshAssetID = generateMeshAssetID(lodLevel: lodLevel, lodIndex: newLOD)
                    lodComponent.activeMeshAssetID = meshAssetID

                    // Emit LOD change event if LOD actually changed
                    if newLOD != previousLODIndex {
                        SystemIntegrationMonitor.shared.recordLODSwitch()

                        let event = EntityLODChangedEvent(
                            entityId: entityId,
                            previousLODIndex: previousLODIndex,
                            newLODIndex: newLOD,
                            meshAssetID: meshAssetID
                        )
                        SystemEventBus.shared.queueLODChange(event)
                    }
                }
            }
        }
    }

    /// Generate a unique ID for the mesh at a given LOD level
    private func generateMeshAssetID(lodLevel: LODLevel, lodIndex: Int) -> String {
        let urlString = lodLevel.url?.absoluteString ?? "unknown"
        return "\(urlString)_LOD\(lodIndex)"
    }
}
