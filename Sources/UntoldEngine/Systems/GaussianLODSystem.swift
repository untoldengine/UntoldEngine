//
//  GaussianLODSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Distance-driven tier selection for progressively streamed Gaussian splats.
public class GaussianLODSystem: @unchecked Sendable {
    public static let shared = GaussianLODSystem()
    private init() {}

    private var frameCounter = 0
    private var lastCameraPosition: simd_float3 = .zero
    private var hasRunOnce = false

    public func reset() {
        frameCounter = 0
        lastCameraPosition = .zero
        hasRunOnce = false
    }

    public func update(deltaTime _: Float) {
        frameCounter &+= 1

        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else { return }

        let cameraPosition = SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition)

        // This global check only catches camera movement — it decides whether to force *every*
        // entity to re-evaluate this frame (the frame-interval throttle still applies per-entity
        // below either way). An entity that itself moved (e.g. a splat prop being dragged while
        // the camera stays put) is caught by updateEntityLOD's own per-entity displacement check,
        // not by this one.
        let forceFullReevaluation = lodShouldRunThisFrame(
            frameCounter: frameCounter,
            hasRunOnce: hasRunOnce,
            interval: LODConfig.shared.lodUpdateFrameInterval,
            cameraPosition: cameraPosition,
            lastCameraPosition: lastCameraPosition,
            displacementThreshold: LODConfig.shared.minimumCameraDisplacementForLODUpdate
        )

        // Only advance on a qualifying frame — lodShouldRunThisFrame's cumulative-displacement
        // fast path needs lastCameraPosition to still reflect the last qualifying frame, not
        // every frame, or slow continuous camera motion below the per-frame threshold could
        // never accumulate enough to trip it. Mirrors the mesh LODSystem.update()'s guarded form.
        if forceFullReevaluation {
            hasRunOnce = true
            lastCameraPosition = cameraPosition
        }

        let lodId = getComponentId(for: GaussianLODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        for entityId in entities {
            updateEntityLOD(entityId: entityId, cameraPosition: cameraPosition, forceFullReevaluation: forceFullReevaluation)
        }
    }

    private func updateEntityLOD(entityId: EntityID, cameraPosition: simd_float3, forceFullReevaluation: Bool) {
        guard let lodComponent = scene.get(component: GaussianLODComponent.self, for: entityId),
              !lodComponent.lodLevels.isEmpty
        else { return }

        let distance = entityDistanceToCamera(entityId: entityId, cameraPosition: cameraPosition)

        // Cheap per-entity fast path: even when the global camera-driven throttle above says
        // "skip this frame," still refresh if this specific entity's distance to the camera has
        // moved enough to plausibly cross a LOD threshold — otherwise dragging a prop while the
        // camera stays still could go unnoticed for up to lodUpdateFrameInterval frames, or
        // (if the drag ends before a throttled frame lands) not be picked up at all until
        // something else nudges the throttle.
        let entityMoved: Bool
        if let lastEvaluatedDistance = lodComponent.lastEvaluatedDistance {
            entityMoved = abs(distance - lastEvaluatedDistance) > LODConfig.shared.minimumEntityDisplacementForLODUpdate
        } else {
            entityMoved = true
        }

        guard forceFullReevaluation || entityMoved else { return }
        lodComponent.lastEvaluatedDistance = distance

        let distanceSelectedLOD = selectDesiredLOD(distance: distance, lodComponent: lodComponent)
        lodComponent.distanceSelectedLOD = distanceSelectedLOD

        var desiredLOD = distanceSelectedLOD

        if let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) {
            let halfExtent = (localTransform.boundingBox.max - localTransform.boundingBox.min) * 0.5
            let boundingRadius = simd_length(halfExtent)
            let tanHalfFovY = renderInfo.perspectiveSpace[1][1] > 0 ? 1.0 / renderInfo.perspectiveSpace[1][1] : 0
            let fovY = 2 * atan(tanHalfFovY)
            let viewportHeight = renderInfo.viewPort?.y ?? 0

            desiredLOD = clampGaussianLODForOverdraw(
                desiredLOD: desiredLOD,
                lodComponent: lodComponent,
                distance: distance,
                fovY: fovY,
                viewportHeight: viewportHeight,
                boundingRadius: boundingRadius,
                budget: LODConfig.shared.gaussianOverdrawBudget
            )
        }

        lodComponent.desiredLOD = desiredLOD

        if !lodComponent.isLODResident(desiredLOD) {
            GeometryStreamingSystem.shared.requestGaussianLODLevelLoad(entityId: entityId, lodIndex: desiredLOD)
        }

        let actualLOD: Int
        if lodComponent.isLODResident(desiredLOD) {
            lodComponent.isUsingFallback = false
            actualLOD = desiredLOD
        } else if let fallback = lodComponent.findFallbackLOD(from: desiredLOD) {
            lodComponent.isUsingFallback = true
            actualLOD = fallback
        } else {
            return
        }

        if Logger.isEnabled(category: .gaussian),
           desiredLOD != lodComponent.lastLoggedDesiredLOD || actualLOD != lodComponent.lastLoggedActualLOD
        {
            lodComponent.lastLoggedDesiredLOD = desiredLOD
            lodComponent.lastLoggedActualLOD = actualLOD
            Logger.log(
                message: String(
                    format: "[Gaussian][LOD] entity=%llu distance=%.2f desiredLOD=%d actualLOD=%d currentLOD=%d fallback=%@ residency=%@",
                    entityId,
                    distance,
                    desiredLOD,
                    actualLOD,
                    lodComponent.currentLOD,
                    lodComponent.isUsingFallback ? "true" : "false",
                    lodComponent.lodLevels.map { "\($0.residencyState)" }.joined(separator: ",")
                ),
                category: LogCategory.gaussian.rawValue
            )
        }

        applyLOD(entityId: entityId, newLOD: actualLOD)
    }

    private func selectDesiredLOD(distance: Float, lodComponent: GaussianLODComponent) -> Int {
        // lodComponent.distanceSelectedLOD still holds the previous frame's pure distance-based
        // decision here — the caller overwrites it with this call's result right after — so
        // passing it as currentLOD gives selectLODIndex the hysteresis reference point it
        // needs, same as the mesh LODSystem.updateEntityLOD -> selectLODLevel call. Deliberately
        // NOT lodComponent.desiredLOD: that field can hold an overdraw-forced-coarser value the
        // hysteresis math was never designed to anchor on — see distanceSelectedLOD's doc comment.
        selectLODIndex(
            levels: lodComponent.lodLevels,
            distance: distance,
            currentLOD: lodComponent.distanceSelectedLOD,
            forcedLOD: lodComponent.forcedLOD,
            lodBias: LODConfig.shared.lodBias,
            hysteresis: LODConfig.shared.hysteresis,
            globalDistances: LODConfig.shared.lodDistances
        )
    }

    private func applyLOD(entityId: EntityID, newLOD: Int) {
        guard let lodComponent = scene.get(component: GaussianLODComponent.self, for: entityId),
              newLOD >= 0,
              newLOD < lodComponent.lodLevels.count,
              let source = lodComponent.lodLevels[newLOD].buffers
        else { return }

        // Only the current tier and the one being switched to hold a pool: a paged tier the
        // selection targeted earlier and left before it warmed in (the hysteresis picked the
        // current one again, the overdraw clamp held it back, the camera stopped) is released
        // here, the moment it stops being the target — its pager shuts down and its buffers go,
        // as at a switch (below). Left alone it would neither draw nor warm (no frame culls
        // its demand or ticks its pager) and its pool, a fixed tens to hundreds of MiB, would
        // stay alive until some later switch commits, one per tier abandoned this way. The
        // normal request path loads it again, into a fresh pool, if the selection returns.
        let currentLOD = lodComponent.currentLOD
        releasePagedTiers(entityId: entityId, lodComponent: lodComponent) { $0 != newLOD && $0 != currentLOD }

        if newLOD == lodComponent.currentLOD, scene.get(component: GaussianComponent.self, for: entityId) != nil {
            return
        }

        // A paged tier switches in only once its pool holds most of what the frame wants:
        // until then it warms — the frame culls its demand beside the current tier's and the
        // pager fills it — while the current tier keeps drawing. Re-evaluated every update.
        if let pager = source.pager, !pager.isWarm {
            pager.warming = true
            return
        }
        source.pager?.warming = false

        withWorldMutationGate {
            // Reuse the entity's existing GaussianComponent if it already has one — scene.assign
            // unconditionally re-initializes the component slot, which would drop the previous
            // instance (and every Metal buffer it retained) without releasing it.
            guard let destination = scene.get(component: GaussianComponent.self, for: entityId)
                ?? scene.assign(to: entityId, component: GaussianComponent.self)
            else {
                return
            }

            copyGaussianComponentBuffers(from: source, to: destination)
            lodComponent.currentLOD = newLOD
            SystemIntegrationMonitor.shared.recordLODSwitch()

            // The paged tier the selection just left goes with the switch: it holds a fixed
            // pool (tens to hundreds of MiB) that nothing else would release before the
            // entity's teardown, and a dolly across a threshold or two would leave one pool per
            // tier visited alive. The pager shuts down (its pool leaves the registry at once,
            // the reads in flight are dropped when they land — the generation guard) and the
            // buffers are let go; the in-flight frames' command buffers retain the pool until
            // they complete. The live component now references the new tier alone. A
            // whole-resident tier stays cached for the instant switch back — see
            // `GaussianLODLevel.buffers`. The tier reads `.notResident` after this, so
            // updateEntityLOD requests it again, and the warmth gate above fills its fresh pool
            // before the switch, when the selection returns to it.
            releasePagedTiers(entityId: entityId, lodComponent: lodComponent) { $0 != newLOD }
        }
    }

    /// Releases every paged tier of `lodComponent` whose index `isSuperseded` accepts
    /// (`GaussianLODComponent.releaseLevelResources(at:)`) and, when any went, rewrites the
    /// entity's ledger entry from the tiers still resident — under the world mutation gate,
    /// taken only when there is something to release. A whole-resident tier is never released
    /// here — it holds no pool and stays cached for the instant switch back.
    private func releasePagedTiers(entityId: EntityID, lodComponent: GaussianLODComponent, where isSuperseded: (Int) -> Bool) {
        let superseded = lodComponent.lodLevels.indices.filter {
            isSuperseded($0) && lodComponent.lodLevels[$0].buffers?.pager != nil
        }
        guard !superseded.isEmpty else { return }
        withWorldMutationGate {
            for index in superseded {
                lodComponent.releaseLevelResources(at: index)
            }
            GeometryStreamingSystem.shared.registerGaussianLODLevelBytes(entityId: entityId, lod: lodComponent)
        }
    }
}

/// Estimated mean overdraw (blended fragments per pixel) across a Gaussian entity's screen
/// footprint, for one candidate LOD tier. Mirrors the perspective size-at-distance factor
/// `computeCov2D` (`Gaussians.metal`) derives from the projection matrix
/// (`focalY = viewport.y * projectionMatrix[1][1] * 0.5`), reused here CPU-side to turn a
/// tier's bake-time `meanSquaredSplatExtent` (see `GaussianLODTier`) into an estimate of how
/// many splats overlap per pixel — the actual GPU cost driver behind the engine's serial
/// per-pixel TBDR blend (`kGaussianMaxBlendedSplatsPerPixel`), which pure distance-based LOD
/// selection has no visibility into.
func estimatedGaussianOverdraw(
    splatCount: Int,
    meanSquaredSplatExtent: Float,
    distance: Float,
    fovY: Float,
    viewportHeight: Float,
    boundingRadius: Float
) -> Float {
    guard splatCount > 0, distance > 0, boundingRadius > 0, viewportHeight > 0 else { return 0 }
    let tanHalfFovY = tan(fovY * 0.5)
    guard tanHalfFovY > 0 else { return 0 }

    let projectionScaleFactor = viewportHeight / (2 * tanHalfFovY * distance)
    let projectedAreaPerSplat = projectionScaleFactor * projectionScaleFactor * meanSquaredSplatExtent
    let footprintRadius = boundingRadius * projectionScaleFactor
    let objectScreenFootprintArea = Float.pi * footprintRadius * footprintRadius

    guard objectScreenFootprintArea > 0 else { return 0 }
    return (Float(splatCount) * projectedAreaPerSplat) / objectScreenFootprintArea
}

/// Walks from `desiredLOD` (the distance/hysteresis-based choice from `selectDesiredLOD`)
/// toward coarser tiers (higher index, never finer) while `estimatedGaussianOverdraw` for the
/// candidate exceeds `budget`, using each candidate's bake-time `meanSquaredSplatExtent` and
/// `splatCount` — both kept on the `GaussianLODLevel` from the tier's first load on, so a
/// paged tier `applyLOD` has since released still takes part in the walk. Bails out and
/// returns `desiredLOD` unchanged the moment a candidate is missing either value — an
/// un-baked `meanSquaredSplatExtent` or a tier that has never loaded (unknown splat count) —
/// so entities without bake-time stats, or a tier this walk reaches before it has ever
/// loaded, fall back to pure distance-based selection exactly as before this feature existed.
func clampGaussianLODForOverdraw(
    desiredLOD: Int,
    lodComponent: GaussianLODComponent,
    distance: Float,
    fovY: Float,
    viewportHeight: Float,
    boundingRadius: Float,
    budget: Float
) -> Int {
    guard desiredLOD >= 0, desiredLOD < lodComponent.lodLevels.count else { return desiredLOD }

    var candidate = desiredLOD
    while candidate < lodComponent.lodLevels.count {
        let level = lodComponent.lodLevels[candidate]
        guard let meanSquaredSplatExtent = level.meanSquaredSplatExtent,
              let splatCount = level.splatCount
        else {
            return desiredLOD
        }

        let overdraw = estimatedGaussianOverdraw(
            splatCount: splatCount,
            meanSquaredSplatExtent: meanSquaredSplatExtent,
            distance: distance,
            fovY: fovY,
            viewportHeight: viewportHeight,
            boundingRadius: boundingRadius
        )
        if overdraw <= budget {
            return candidate
        }
        candidate += 1
    }
    return lodComponent.lodLevels.count - 1
}

func copyGaussianComponentBuffers(from source: GaussianComponent, to destination: GaussianComponent) {
    destination.splatCount = source.splatCount
    destination.visibleSplatCountForRendering = source.splatCount
    destination.gaussianVisibleIndices = source.gaussianVisibleIndices
    destination.gaussianVisibleCount = source.gaussianVisibleCount
    destination.chunkTable = source.chunkTable
    destination.pager = source.pager
    destination.encodedSplatData = source.encodedSplatData
    destination.packedSplatData = source.packedSplatData
    destination.sphericalHarmonicsData = source.sphericalHarmonicsData
    destination.sphericalHarmonicsMetadata = source.sphericalHarmonicsMetadata
    destination.captureExposureEV = source.captureExposureEV
    destination.captureWhiteBalance = source.captureWhiteBalance
    destination.estimatedGPUBytes = source.estimatedGPUBytes
    destination.localBoundingBox = source.localBoundingBox
}
