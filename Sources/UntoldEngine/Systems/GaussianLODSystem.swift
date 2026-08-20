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
            distance: calculateDistance(entityId: entityId, cameraPosition: cameraPosition),
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

    private func calculateDistance(entityId: EntityID, cameraPosition: simd_float3) -> Float {
        guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
              let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
        else { return 0 }

        let localCenter = (localTransform.boundingBox.min + localTransform.boundingBox.max) * 0.5
        let worldCenter = worldTransform.space * simd_float4(localCenter, 1)
        return simd_distance(cameraPosition, simd_float3(worldCenter.x, worldCenter.y, worldCenter.z))
    }

    private func selectDesiredLOD(distance: Float, lodComponent: GaussianLODComponent) -> Int {
        if let forced = lodComponent.forcedLOD, forced >= 0 {
            return min(forced, lodComponent.lodLevels.count - 1)
        }

        let adjustedDistance = distance * LODConfig.shared.lodBias
        for (index, level) in lodComponent.lodLevels.enumerated() {
            guard level.maxDistance > 0 else { continue }
            if adjustedDistance <= level.maxDistance {
                return index
            }
        }
        return lodComponent.lodLevels.count - 1
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
            guard let destination = scene.assign(to: entityId, component: GaussianComponent.self) else {
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
