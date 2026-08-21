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

        let lodId = getComponentId(for: GaussianLODComponent.self)
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lodId, transformId], in: scene)

        for entityId in entities {
            updateEntityLOD(entityId: entityId, cameraPosition: cameraPosition)
        }
    }

    private func updateEntityLOD(entityId: EntityID, cameraPosition: simd_float3) {
        guard let lodComponent = scene.get(component: GaussianLODComponent.self, for: entityId),
              !lodComponent.lodLevels.isEmpty
        else { return }

        let desiredLOD = selectDesiredLOD(
            distance: entityDistanceToCamera(entityId: entityId, cameraPosition: cameraPosition),
            lodComponent: lodComponent
        )
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

        applyLOD(entityId: entityId, newLOD: actualLOD)
    }

    private func selectDesiredLOD(distance: Float, lodComponent: GaussianLODComponent) -> Int {
        // lodComponent.desiredLOD still holds the previous frame's decision here — the caller
        // overwrites it with this call's result right after — so passing it as currentLOD
        // gives selectLODIndex the hysteresis reference point it needs, same as the mesh
        // LODSystem.updateEntityLOD -> selectLODLevel call.
        selectLODIndex(
            levels: lodComponent.lodLevels,
            distance: distance,
            currentLOD: lodComponent.desiredLOD,
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

        if newLOD == lodComponent.currentLOD, scene.get(component: GaussianComponent.self, for: entityId) != nil {
            return
        }

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
        }
    }
}

func copyGaussianComponentBuffers(from source: GaussianComponent, to destination: GaussianComponent) {
    destination.splatCount = source.splatCount
    destination.visibleSplatCountForRendering = source.splatCount
    destination.gaussianSortedIndices = source.gaussianSortedIndices
    destination.gaussianVisibleIndices = source.gaussianVisibleIndices
    destination.gaussianVisibleCount = source.gaussianVisibleCount
    destination.encodedSplatData = source.encodedSplatData
    destination.gaussianPrecomputedData = source.gaussianPrecomputedData
    destination.sphericalHarmonicsData = source.sphericalHarmonicsData
    destination.sphericalHarmonicsMetadata = source.sphericalHarmonicsMetadata
    destination.spaceUniform = source.spaceUniform
}
