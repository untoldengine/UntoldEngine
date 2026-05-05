//
//  ShadowSystem.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// Swift mirror of the Metal CSMUniforms struct in ShaderStructs.h.
/// Layout must stay in sync: 3xfloat4x4, camera view matrix, 3xfloat, then int + 3xfloat padding.
struct CSMUniforms {
    var lightSpaceMatrices: (simd_float4x4, simd_float4x4, simd_float4x4) = (
        matrix_identity_float4x4, matrix_identity_float4x4, matrix_identity_float4x4
    )
    var cameraViewMatrix: simd_float4x4 = matrix_identity_float4x4
    var cascadeSplits: (Float, Float, Float) = (0, 0, 0)
    var cascadeCount: Int32 = .init(csmCascadeCount)
    var _pad0: Float = 0
    var _pad1: Float = 0
    var _pad2: Float = 0
}

struct ShadowSystem {
    // Per-frame cascade outputs
    var cascadeLightSpaceMatrices: [simd_float4x4] = Array(repeating: matrix_identity_float4x4, count: csmCascadeCount)
    var cascadeSplitDistances: [Float] = Array(repeating: 0, count: csmCascadeCount)
    var isActive: Bool = false

    /// Legacy accessor used by callers that only need to know "is there a shadow?"
    var dirLightSpaceMatrix: simd_float4x4? {
        isActive ? cascadeLightSpaceMatrices[0] : nil
    }

    /// Pack into the GPU-ready uniform struct.
    func makeUniforms() -> CSMUniforms {
        var u = CSMUniforms()
        u.lightSpaceMatrices = (
            cascadeLightSpaceMatrices[0],
            cascadeLightSpaceMatrices[1],
            cascadeLightSpaceMatrices[2]
        )
        u.cascadeSplits = (
            cascadeSplitDistances[0],
            cascadeSplitDistances[1],
            cascadeSplitDistances[2]
        )
        u.cascadeCount = Int32(csmCascadeCount)
        return u
    }

    /// Main per-frame update — computes one tight ortho matrix per cascade.
    mutating func updateCascades() {
        // In XR stereo mode the shadow map is shared between both eyes.
        // Only compute (and overwrite) on eye 0; eye 1 reuses the matrices.
        if renderInfo.isXRStereoMode && renderInfo.currentEye > 0 {
            // isActive stays unchanged from eye-0 computation.
            return
        }

        isActive = false

        // Find directional light entity
        let lightComponentID = getComponentId(for: DirectionalLightComponent.self)
        let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)
        let entities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID], in: scene)

        var lightForward = simd_float3(0, -1, 0)
        var foundLight = false
        for entity in entities {
            guard scene.get(component: DirectionalLightComponent.self, for: entity) != nil else { continue }
            let fwd = getForwardAxisVector(entityId: entity)
            lightForward = -normalize(simd_float3(fwd.x, fwd.y, fwd.z))
            foundLight = true
        }
        guard foundLight else { return }

        // Get camera
        guard let camEntity = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camEntity)
        else { return }

        let effectiveView = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let invView = effectiveView.inverse

        // Extract tangent-of-half-FOV from the current perspective projection matrix.
        // proj[0][0] = f/aspect  → tanHalfFovX = 1/proj[0][0]
        // proj[1][1] = f         → tanHalfFovY = 1/proj[1][1]
        let proj = renderInfo.perspectiveSpace
        let tanHalfFovY: Float = 1.0 / proj[1][1]
        let tanHalfFovX: Float = 1.0 / proj[0][0]

        // Vision Pro IPD expansion: widen the cascade sub-frustum horizontally by half the
        // typical max IPD so the cascade AABB envelopes both eye frustums.
        let xrExpansion: Float = renderInfo.isXRStereoMode ? 0.04 : 0.0

        // Use a tighter far for XR — room-scale scenes rarely exceed 50 m.
        let cameraFar: Float = renderInfo.isXRStereoMode ? 50.0 : far

        // Practical split scheme (blend of log and uniform, λ=0.5).
        let splits = computeCascadeSplits(cameraNear: near, cameraFar: cameraFar)
        cascadeSplitDistances = splits

        // Light view: look along lightForward using a stable up vector.
        let lightUp: simd_float3 = abs(lightForward.y) < 0.99
            ? simd_float3(0, 1, 0)
            : simd_float3(0, 0, 1)

        var prevNear: Float = near
        for i in 0 ..< csmCascadeCount {
            let cascadeFar = splits[i]

            // 8 corners of the cascade sub-frustum in world space.
            let corners = cascadeFrustumCornersWorldSpace(
                invViewMatrix: invView,
                tanHalfFovX: tanHalfFovX,
                tanHalfFovY: tanHalfFovY,
                nearDist: prevNear,
                farDist: cascadeFar,
                xrIPDExpansion: xrExpansion
            )

            // Centroid of the frustum slice.
            var center = simd_float3(0, 0, 0)
            for c in corners {
                center += c
            }
            center /= Float(corners.count)

            // Stable CSM: use a light view with fixed orientation, then snap the cascade
            // center to the shadow texel grid in light space. Re-centering the light view
            // directly on the frustum every frame causes sub-texel shadow-map movement
            // during camera rotation.
            let lightView = matrix_look_at_right_hand(-lightForward * 150.0, simd_float3(0, 0, 0), lightUp)

            var radius: Float = 0
            for corner in corners {
                radius = max(radius, simd_length(corner - center))
            }

            let diameter = max(ceil(radius * 2.0), 0.001)
            let texelSize = diameter / Float(shadowResolution.x)

            var centerLS = lightView * simd_float4(center, 1.0)
            centerLS.x = floor(centerLS.x / texelSize) * texelSize
            centerLS.y = floor(centerLS.y / texelSize) * texelSize

            let halfDiameter = diameter * 0.5
            let minX = centerLS.x - halfDiameter
            let maxX = centerLS.x + halfDiameter
            let minY = centerLS.y - halfDiameter
            let maxY = centerLS.y + halfDiameter

            // Keep Z fit to the cascade corners for precision, with a conservative margin
            // for off-camera casters that still project into the cascade.
            var minZ = Float.infinity, maxZ = -Float.infinity

            for corner in corners {
                let lc = lightView * simd_float4(corner, 1.0)
                minZ = min(minZ, lc.z); maxZ = max(maxZ, lc.z)
            }

            // Extend the near (minZ) so objects behind the camera can still cast shadows.
            let depthMargin: Float = 50.0
            minZ -= depthMargin

            // Convert light-space Z extents to positive near/far distances for the ortho matrix.
            // In right-hand view space, scene geometry is at negative Z; nearest geometry has
            // the largest (least-negative) Z, which becomes nearZ; farthest becomes farZ.
            let orthoNearZ = -maxZ
            let orthoFarZ = -minZ

            let ortho = matrix_ortho_right_hand(minX, maxX, minY, maxY, orthoNearZ, farZ: orthoFarZ)
            cascadeLightSpaceMatrices[i] = simd_mul(ortho, lightView)

            prevNear = cascadeFar
        }

        isActive = true
    }

    /// Practical split scheme: λ-blend of logarithmic and uniform partitions.
    private func computeCascadeSplits(cameraNear: Float, cameraFar: Float) -> [Float] {
        let lambda: Float = 0.5
        var splits: [Float] = []
        for i in 1 ... csmCascadeCount {
            let fi = Float(i) / Float(csmCascadeCount)
            let logSplit = cameraNear * pow(cameraFar / cameraNear, fi)
            let uniformSplit = cameraNear + (cameraFar - cameraNear) * fi
            splits.append(lambda * logSplit + (1.0 - lambda) * uniformSplit)
        }
        return splits
    }

    /// Returns the 8 world-space corners of the camera frustum slice [nearDist, farDist].
    /// xrIPDExpansion widens each half-extent in X to envelope the second eye frustum.
    private func cascadeFrustumCornersWorldSpace(
        invViewMatrix: simd_float4x4,
        tanHalfFovX: Float,
        tanHalfFovY: Float,
        nearDist: Float,
        farDist: Float,
        xrIPDExpansion: Float
    ) -> [simd_float3] {
        var corners: [simd_float3] = []
        for dist in [nearDist, farDist] {
            let halfX = tanHalfFovX * dist + xrIPDExpansion
            let halfY = tanHalfFovY * dist
            // Camera looks along -Z in right-hand view space.
            let viewCorners: [simd_float4] = [
                simd_float4(-halfX, -halfY, -dist, 1),
                simd_float4(halfX, -halfY, -dist, 1),
                simd_float4(-halfX, halfY, -dist, 1),
                simd_float4(halfX, halfY, -dist, 1),
            ]
            for vc in viewCorners {
                let w = invViewMatrix * vc
                corners.append(simd_float3(w.x, w.y, w.z))
            }
        }
        return corners
    }
}
