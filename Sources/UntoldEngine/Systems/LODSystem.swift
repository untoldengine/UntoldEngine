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

    private var frameCounter: Int = 0
    private var lastCameraPosition: simd_float3 = .zero
    private var hasRunOnce: Bool = false

    /// Resets throttle state. Call between tests to ensure a clean baseline.
    public func reset() {
        frameCounter = 0
        lastCameraPosition = .zero
        hasRunOnce = false
    }

    public func update(deltaTime: Float) {
        frameCounter &+= 1

        if LODConfig.shared.enableFadeTransitions {
            advanceActiveTransitions(deltaTime: deltaTime)
        }

        // Get active camera
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return }

        let cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        guard lodShouldRunThisFrame(
            frameCounter: frameCounter,
            hasRunOnce: hasRunOnce,
            interval: LODConfig.shared.lodUpdateFrameInterval,
            cameraPosition: cameraPosition,
            lastCameraPosition: lastCameraPosition,
            displacementThreshold: LODConfig.shared.minimumCameraDisplacementForLODUpdate
        ) else { return }

        hasRunOnce = true
        lastCameraPosition = cameraPosition

        // Query entities with LOD components
        let lodId = getComponentId(for: LODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        for entityId in entities {
            updateEntityLOD(entityId: entityId, cameraPosition: cameraPosition, deltaTime: deltaTime)
        }
    }

    private func advanceActiveTransitions(deltaTime: Float) {
        let lodId = getComponentId(for: LODComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId], in: scene)
        let transitionDuration = max(LODConfig.shared.fadeTransitionTime, 0.001)

        for entityId in entities {
            guard let lodComponent = scene.get(component: LODComponent.self, for: entityId),
                  lodComponent.previousLOD != nil
            else { continue }

            withWorldMutationGate {
                lodComponent.transitionProgress += deltaTime / transitionDuration

                if lodComponent.transitionProgress >= 1.0 {
                    lodComponent.previousLOD = nil
                    lodComponent.transitionProgress = 0.0

                    let meshAssetID: String
                    if lodComponent.currentLOD >= 0, lodComponent.currentLOD < lodComponent.lodLevels.count {
                        meshAssetID = generateMeshAssetID(
                            lodLevel: lodComponent.lodLevels[lodComponent.currentLOD],
                            lodIndex: lodComponent.currentLOD
                        )
                    } else {
                        meshAssetID = lodComponent.activeMeshAssetID
                    }

                    let event = EntityLODChangedEvent(
                        entityId: entityId,
                        previousLODIndex: lodComponent.currentLOD,
                        newLODIndex: lodComponent.currentLOD,
                        meshAssetID: meshAssetID
                    )
                    SystemEventBus.shared.queueLODChange(event)
                }
            }
        }
    }

    private func updateEntityLOD(entityId: EntityID, cameraPosition: simd_float3, deltaTime: Float) {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else { return }

        // Skip if no LOD levels loaded yet (async loading may still be in progress)
        guard !lodComponent.lodLevels.isEmpty else { return }

        if shouldDeferLODSelectionDuringTransition(
            fadeTransitionsEnabled: LODConfig.shared.enableFadeTransitions,
            previousLOD: lodComponent.previousLOD
        ) {
            return
        }

        // Calculate distance
        let distance = entityDistanceToCamera(entityId: entityId, cameraPosition: cameraPosition)

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

    private func selectLODLevel(distance: Float, lodComponent: LODComponent, currentLOD: Int) -> Int {
        selectLODIndex(
            levels: lodComponent.lodLevels,
            distance: distance,
            currentLOD: currentLOD,
            forcedLOD: lodComponent.forcedLOD,
            lodBias: LODConfig.shared.lodBias,
            hysteresis: LODConfig.shared.hysteresis,
            globalDistances: LODConfig.shared.lodDistances
        )
    }

    private func applyLOD(entityId: EntityID, newLOD: Int, deltaTime _: Float) {
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

// MARK: - Internal helpers (exposed for testing via @testable import)

/// Pure decision function: returns true when the LOD system should run a full entity
/// update this frame. Extracted from LODSystem.update() for deterministic unit testing.
func lodShouldRunThisFrame(
    frameCounter: Int,
    hasRunOnce: Bool,
    interval: Int,
    cameraPosition: simd_float3,
    lastCameraPosition: simd_float3,
    displacementThreshold: Float
) -> Bool {
    // Always run on the very first call so entities get an initial LOD assignment.
    guard hasRunOnce else { return true }
    // Periodic throttle: run once every `interval` frames.
    if frameCounter % max(1, interval) == 0 { return true }
    // Fast-path: camera jumped far enough since last update — run immediately.
    return simd_distance(cameraPosition, lastCameraPosition) > displacementThreshold
}

func shouldDeferLODSelectionDuringTransition(
    fadeTransitionsEnabled: Bool,
    previousLOD: Int?
) -> Bool {
    fadeTransitionsEnabled && previousLOD != nil
}

/// Shared by `LODComponent` and `GaussianLODComponent` — see `LODResidencyLevel`.
func isLODLevelResident(_ levels: [some LODResidencyLevel], _ index: Int) -> Bool {
    guard index >= 0, index < levels.count else { return false }
    let level = levels[index]
    return level.residencyState == .resident && level.isPopulated
}

/// Shared by `LODComponent` and `GaussianLODComponent` — see `LODResidencyLevel`. Prefers a
/// coarser resident level (higher index, lower detail) over a finer one, since showing
/// something-but-coarser while the desired level streams in beats swapping to a different
/// detail level entirely.
func findFallbackLODLevel(_ levels: [some LODResidencyLevel], from desiredIndex: Int) -> Int? {
    for i in (desiredIndex + 1) ..< levels.count where isLODLevelResident(levels, i) {
        return i
    }
    for i in (0 ..< desiredIndex).reversed() where isLODLevelResident(levels, i) {
        return i
    }
    return nil
}

/// Shared by `LODSystem` and `GaussianLODSystem` — distance from the camera to an entity's
/// local-space bounding-box center, in world space.
func entityDistanceToCamera(entityId: EntityID, cameraPosition: simd_float3) -> Float {
    guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
          let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
    else { return 0.0 }

    let boundingBox = localTransform.boundingBox
    let localCenter = (boundingBox.min + boundingBox.max) * 0.5
    let worldCenter = worldTransform.space * simd_float4(localCenter, 1.0)
    return simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
}

/// Shared by `LODSystem.selectLODLevel` and `GaussianLODSystem.selectDesiredLOD` — walks
/// `levels` in distance order and returns the first whose threshold isn't yet exceeded by
/// `distance * lodBias`. Applies `hysteresis` when a candidate level would mean switching to
/// higher detail (lower index) than `currentLOD`, so a distance oscillating right at a
/// threshold doesn't flip the selection every re-evaluation. Falls back to
/// `globalDistances[index]` when a level's own `maxDistance` is unset (0).
func selectLODIndex(
    levels: [some LODDistanceLevel],
    distance: Float,
    currentLOD: Int,
    forcedLOD: Int?,
    lodBias: Float,
    hysteresis: Float,
    globalDistances: [Float]
) -> Int {
    if let forced = forcedLOD, forced >= 0 {
        return min(forced, levels.count - 1)
    }

    let adjustedDistance = distance * lodBias

    for (index, level) in levels.enumerated() {
        let baseThreshold: Float
        if level.maxDistance > 0 {
            baseThreshold = level.maxDistance
        } else if index < globalDistances.count {
            baseThreshold = globalDistances[index]
        } else {
            continue
        }

        let threshold = index < currentLOD ? baseThreshold - hysteresis : baseThreshold
        if adjustedDistance <= threshold {
            return index
        }
    }

    return levels.count - 1
}
