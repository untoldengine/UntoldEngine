//
//  PoseDriverEvaluation.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Pose-space deformation driver evaluation: a morph target authored with a
/// driver reaches full weight when its joint's rest-relative local rotation
/// matches the authored pose, falling off with quaternion geodesic distance.
///
/// The driver pose is authored in Blender as the pose bone's basis rotation
/// (`pose_bone.rotation_quaternion`), and the engine's clip-sampled local
/// rotation composes as `rest ∘ basis`, so the rest-relative delta compared
/// here is `rest⁻¹ ∘ current` — parent-space, unaffected by the exporter's
/// root orientation conversion.
enum PoseDriverEvaluation {
    /// Gaussian falloff weight in [0, 1]; exactly 1 at the authored pose.
    /// Weights below `activationFloor` clamp to zero so inactive targets
    /// skip their accumulation dispatch entirely.
    static let activationFloor: Float = 0.02

    static func weight(
        currentLocalRotation: simd_quatf,
        restLocalRotation: simd_quatf,
        driverPose: simd_quatf,
        radius: Float
    ) -> Float {
        let delta = restLocalRotation.inverse * currentLocalRotation
        let alignment = min(abs(simd_dot(delta.vector, driverPose.vector)), 1.0)
        let distance = 2.0 * acos(alignment)

        let safeRadius = max(radius, 1e-3)
        let falloff = exp(-2.0 * (distance / safeRadius) * (distance / safeRadius))
        return falloff < activationFloor ? 0 : falloff
    }

    /// Rotation of a local rest matrix with scale factored out (uniform or
    /// mildly non-uniform rest scales both normalize cleanly per column).
    static func restRotation(from localRestTransform: simd_float4x4) -> simd_quatf {
        let c0 = simd_normalize(simd_float3(
            localRestTransform.columns.0.x, localRestTransform.columns.0.y, localRestTransform.columns.0.z
        ))
        let c1 = simd_normalize(simd_float3(
            localRestTransform.columns.1.x, localRestTransform.columns.1.y, localRestTransform.columns.1.z
        ))
        let c2 = simd_normalize(simd_float3(
            localRestTransform.columns.2.x, localRestTransform.columns.2.y, localRestTransform.columns.2.z
        ))
        return simd_quatf(simd_float3x3(c0, c1, c2))
    }
}

extension DeformationSystem {
    /// Refreshes `component.drivenMorphWeights` from the entity's current
    /// local pose. Driven weights participate in morph accumulation whenever
    /// pose drivers are enabled; manually set weights still apply to targets
    /// without a driver.
    func evaluatePoseDrivers(
        component: DeformationComponent,
        mesh: Mesh,
        entityId: EntityID
    ) {
        guard component.poseDriversEnabled,
              let morphTargets = mesh.morphTargets,
              morphTargets.targets.contains(where: { $0.driver != nil })
        else {
            if !component.drivenMorphWeights.isEmpty {
                component.drivenMorphWeights.removeAll()
            }
            return
        }
        guard let skeletonComponent = scene.get(component: SkeletonComponent.self, for: entityId),
              let skeleton = skeletonComponent.skeleton,
              let animationComponent = scene.get(component: AnimationComponent.self, for: entityId),
              animationComponent.hasSampledPose,
              animationComponent.localPose.rotations.count == skeleton.jointPaths.count
        else { return }

        for target in morphTargets.targets {
            guard let driver = target.driver else { continue }
            guard let jointIndex = skeleton.jointPaths.firstIndex(of: driver.jointPath) else {
                continue
            }
            let restRotation = PoseDriverEvaluation.restRotation(
                from: skeleton.restTransform[jointIndex]
            )
            let weight = PoseDriverEvaluation.weight(
                currentLocalRotation: animationComponent.localPose.rotations[jointIndex],
                restLocalRotation: restRotation,
                driverPose: simd_quatf(vector: driver.poseRotation),
                radius: driver.radius
            )
            if weight > 0 {
                component.drivenMorphWeights[target.name] = weight
            } else {
                component.drivenMorphWeights.removeValue(forKey: target.name)
            }
        }
    }
}

/// Enables or disables automatic pose-driven morph weights on `entityId`
/// (resolved through the hierarchy like `setEntityDeformation`). Manual
/// weights set via `setEntityMorphTargetWeight` keep applying to targets
/// without a driver.
public func setEntityPoseDrivers(entityId: EntityID, enabled: Bool) {
    guard scene.exists(entityId) else { return }
    for targetEntityId in resolveAnimationBindingTargetEntities(entityId: entityId) {
        guard let component = scene.get(component: DeformationComponent.self, for: targetEntityId) else {
            continue
        }
        component.poseDriversEnabled = enabled
        if !enabled {
            component.drivenMorphWeights.removeAll()
        }
    }
}
