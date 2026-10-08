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

        // One copy for the whole pass: reading the shared configuration takes a lock,
        // and a scene can hold tens of thousands of LOD entities.
        let config = LODConfig.shared

        if config.enableFadeTransitions {
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
            interval: config.lodUpdateFrameInterval,
            cameraPosition: cameraPosition,
            lastCameraPosition: lastCameraPosition,
            displacementThreshold: config.minimumCameraDisplacementForLODUpdate
        ) else { return }

        hasRunOnce = true
        lastCameraPosition = cameraPosition

        // What a size on screen is worth in distance, for the view being drawn. In
        // stereo the eyes are rendered after this update, so their projections are the
        // last frame's; the field of view of a headset does not change between frames.
        let screenSizeReach = renderInfo.isXRStereoMode
            ? lodScreenSizeReach(eyeProjections: [renderInfo.xrEye0Projection, renderInfo.xrEye1Projection])
            : lodScreenSizeReach(projection: renderInfo.perspectiveSpace)

        // Query entities with LOD components
        let lodId = getComponentId(for: LODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        for entityId in entities {
            updateEntityLOD(entityId: entityId, cameraPosition: cameraPosition, screenSizeReach: screenSizeReach, config: config)
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

    private func updateEntityLOD(entityId: EntityID, cameraPosition: simd_float3, screenSizeReach: Float?, config: LODConfig) {
        guard let lodComponent = scene.get(component: LODComponent.self, for: entityId) else { return }

        // Skip if no LOD levels loaded yet (async loading may still be in progress)
        guard !lodComponent.lodLevels.isEmpty else { return }

        if shouldDeferLODSelectionDuringTransition(
            fadeTransitionsEnabled: config.enableFadeTransitions,
            previousLOD: lodComponent.previousLOD
        ) {
            return
        }

        let desiredLOD: Int
        if lodComponent.selectsByScreenSize, let screenSizeReach {
            // Select by the size of the entity on screen, as it is now
            let (distance, radius) = entityDistanceAndRadius(
                entityId: entityId,
                cameraPosition: cameraPosition,
                localRadius: lodComponent.screenSizeRadius
            )
            desiredLOD = selectLODIndex(
                levels: lodComponent.lodLevels,
                distance: distance,
                reach: radius * screenSizeReach,
                currentLOD: lodComponent.desiredLOD,
                forcedLOD: lodComponent.forcedLOD,
                lodBias: config.lodBias,
                hysteresis: config.hysteresis,
                globalDistances: config.lodDistances
            )
        } else {
            // Calculate distance
            let distance = entityDistanceToCamera(entityId: entityId, cameraPosition: cameraPosition)

            // Select desired LOD level based on distance
            desiredLOD = selectLODLevel(
                distance: distance,
                lodComponent: lodComponent,
                currentLOD: lodComponent.desiredLOD,
                config: config
            )
        }

        lodComponent.desiredLOD = desiredLOD

        // Resolve actual LOD (check residency, find fallback if needed)
        let actualLOD = resolveActualLOD(
            entityId: entityId,
            lodComponent: lodComponent,
            desiredLOD: desiredLOD
        )

        // Apply the LOD (handles transitions, updates render component)
        applyLOD(entityId: entityId, lodComponent: lodComponent, newLOD: actualLOD, config: config)
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

    private func selectLODLevel(distance: Float, lodComponent: LODComponent, currentLOD: Int, config: LODConfig) -> Int {
        selectLODIndex(
            levels: lodComponent.lodLevels,
            distance: distance,
            currentLOD: currentLOD,
            forcedLOD: lodComponent.forcedLOD,
            lodBias: config.lodBias,
            hysteresis: config.hysteresis,
            globalDistances: config.lodDistances
        )
    }

    private func applyLOD(entityId: EntityID, lodComponent: LODComponent, newLOD: Int, config: LODConfig) {
        let previousLODIndex = lodComponent.currentLOD

        // No change needed: the usual case, so it comes before any other lookup.
        if newLOD == previousLODIndex, lodComponent.previousLOD == nil {
            return
        }

        guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else { return }

        withWorldMutationGate {
            // Handle fade transitions
            if config.enableFadeTransitions {
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
                if lodComponent.levelsShareMaterials, !lodComponent.lodLevels[newLOD].mesh.isEmpty {
                    // The materials are the entity's: the level that leaves keeps those it
                    // was drawn with (a fade still draws it) and the one that arrives takes them.
                    let drawnMeshes = renderComponent.mesh
                    if previousLODIndex != newLOD, previousLODIndex >= 0, previousLODIndex < lodComponent.lodLevels.count {
                        carryLODMaterials(from: drawnMeshes, to: &lodComponent.lodLevels[previousLODIndex].mesh)
                    }
                    carryLODMaterials(from: drawnMeshes, to: &lodComponent.lodLevels[newLOD].mesh)
                }
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

/// The distance from the camera to the center of an entity's bounds and the radius, in
/// world space, of the sphere its size on screen is measured by: `localRadius` under the
/// entity's world transform, or the sphere around its bounding box when `localRadius`
/// is 0.
func entityDistanceAndRadius(entityId: EntityID, cameraPosition: simd_float3, localRadius: Float) -> (distance: Float, radius: Float) {
    guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
          let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
    else { return (0.0, 0.0) }

    let boundingBox = localTransform.boundingBox
    let localCenter = (boundingBox.min + boundingBox.max) * 0.5
    let worldCenter = worldTransform.space * simd_float4(localCenter, 1.0)
    let radius = localRadius > 0 ? localRadius : simd_length(boundingBox.max - boundingBox.min) * 0.5
    return (
        simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z)),
        radius * largestAxisScale(of: worldTransform.space)
    )
}

/// The distance, per unit of radius, at which a sphere covers a screen size of 1 (the
/// whole height of the viewport) in the view that `projection` draws: a sphere of radius
/// r covers the screen size s at the distance r * reach / s. Nil when the projection has
/// no perspective, where the size on screen does not depend on the distance.
///
/// A screen size is a share of the viewport height, whatever that height is in pixels:
/// the switches follow the field of view and not the resolution, so a denser display
/// draws the same levels as a coarser one.
func lodScreenSizeReach(projection: simd_float4x4) -> Float? {
    // A perspective projection has no constant term in w; its [1][1] is 1 / tan(fovY / 2).
    let perspectiveScale = projection.columns.1.y
    guard projection.columns.3.w == 0, perspectiveScale > 0, perspectiveScale.isFinite else { return nil }
    return perspectiveScale
}

/// The reach for a stereo frame: the larger of the eyes' reaches, so that an entity is
/// drawn at the level the eye that sees it largest asks for. Nil until an eye has been
/// rendered (the projections are still the identity), when the stored distances serve.
func lodScreenSizeReach(eyeProjections: [simd_float4x4]) -> Float? {
    eyeProjections.compactMap(lodScreenSizeReach(projection:)).max()
}

/// The share of a level's switch distance that `selectLODIndex` lets the hysteresis reach.
let lodHysteresisDistanceShare: Float = 0.1

/// Copies the materials of `source` onto `destination`, mesh for mesh and submesh for
/// submesh. Does nothing unless the two have the same layout.
func carryLODMaterials(from source: [Mesh], to destination: inout [Mesh]) {
    guard source.count == destination.count,
          zip(source, destination).allSatisfy({ $0.submeshes.count == $1.submeshes.count })
    else { return }
    for meshIndex in destination.indices {
        for submeshIndex in destination[meshIndex].submeshes.indices {
            destination[meshIndex].submeshes[submeshIndex].material = source[meshIndex].submeshes[submeshIndex].material
        }
    }
}

/// Shared by `LODSystem.selectLODLevel` and `GaussianLODSystem.selectDesiredLOD` — walks
/// `levels` in distance order and returns the first whose threshold isn't yet exceeded by
/// `distance * lodBias`. Applies `hysteresis` when a candidate level would mean switching to
/// higher detail (lower index) than `currentLOD`, so a distance oscillating right at a
/// threshold doesn't flip the selection every re-evaluation. The hysteresis never takes more
/// than `lodHysteresisDistanceShare` of a threshold: a fixed distance larger than a level's
/// own switch distance would otherwise keep a small object from ever returning to that level.
/// Falls back to `globalDistances[index]` when a level's own `maxDistance` is unset (0).
func selectLODIndex(
    levels: [some LODDistanceLevel],
    distance: Float,
    currentLOD: Int,
    forcedLOD: Int?,
    lodBias: Float,
    hysteresis: Float,
    globalDistances: [Float]
) -> Int {
    selectLODIndex(
        levelCount: levels.count,
        distance: distance,
        currentLOD: currentLOD,
        forcedLOD: forcedLOD,
        lodBias: lodBias,
        hysteresis: hysteresis
    ) { index in
        lodDistanceThreshold(of: levels[index], at: index, globalDistances: globalDistances)
    }
}

/// `selectLODIndex` for an entity whose levels are chosen by its size on screen
/// (`LODComponent.selectsByScreenSize`). A level ends at the distance where the entity
/// covers the screen size of the next one, `reach / screenPercentage`, with `reach` the
/// distance at which the entity covers a screen size of 1: its world radius times
/// `lodScreenSizeReach`. The bias and the hysteresis act on that distance as they do on
/// a `maxDistance`. A level whose successor has no screen size, the last level, and an
/// entity without a size end at their own `maxDistance` instead.
func selectLODIndex(
    levels: [LODLevel],
    distance: Float,
    reach: Float,
    currentLOD: Int,
    forcedLOD: Int?,
    lodBias: Float,
    hysteresis: Float,
    globalDistances: [Float]
) -> Int {
    selectLODIndex(
        levelCount: levels.count,
        distance: distance,
        currentLOD: currentLOD,
        forcedLOD: forcedLOD,
        lodBias: lodBias,
        hysteresis: hysteresis
    ) { index in
        if reach > 0, reach.isFinite, index + 1 < levels.count, levels[index + 1].screenPercentage > 0 {
            return reach / levels[index + 1].screenPercentage
        }
        return lodDistanceThreshold(of: levels[index], at: index, globalDistances: globalDistances)
    }
}

/// Where a level hands over to the next one by distance: its own `maxDistance`, or
/// `globalDistances[index]` when that is unset (0). Nil when neither says.
private func lodDistanceThreshold(of level: some LODDistanceLevel, at index: Int, globalDistances: [Float]) -> Float? {
    if level.maxDistance > 0 {
        return level.maxDistance
    }
    return index < globalDistances.count ? globalDistances[index] : nil
}

/// The walk behind `selectLODIndex`: the first level, finest first, whose
/// `switchDistance` the biased distance has not passed. A level without one is skipped.
private func selectLODIndex(
    levelCount: Int,
    distance: Float,
    currentLOD: Int,
    forcedLOD: Int?,
    lodBias: Float,
    hysteresis: Float,
    switchDistance: (Int) -> Float?
) -> Int {
    if let forced = forcedLOD, forced >= 0 {
        return min(forced, levelCount - 1)
    }

    let adjustedDistance = distance * lodBias

    for index in 0 ..< levelCount {
        guard let baseThreshold = switchDistance(index) else { continue }

        let threshold = index < currentLOD
            ? baseThreshold - min(hysteresis, baseThreshold * lodHysteresisDistanceShare)
            : baseThreshold
        if adjustedDistance <= threshold {
            return index
        }
    }

    return levelCount - 1
}
