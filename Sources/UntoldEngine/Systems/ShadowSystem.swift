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

let minimumSpotShadowDistance: Float = 10.0
let minimumPointShadowDistance: Float = 10.0
private let localShadowInfluenceThreshold: Float = 0.01

let pointShadowFaceDirections: [simd_float3] = [
    simd_float3(1.0, 0.0, 0.0),
    simd_float3(-1.0, 0.0, 0.0),
    simd_float3(0.0, 1.0, 0.0),
    simd_float3(0.0, -1.0, 0.0),
    simd_float3(0.0, 0.0, 1.0),
    simd_float3(0.0, 0.0, -1.0),
]

let pointShadowFaceUpVectors: [simd_float3] = [
    simd_float3(0.0, -1.0, 0.0),
    simd_float3(0.0, -1.0, 0.0),
    simd_float3(0.0, 0.0, 1.0),
    simd_float3(0.0, 0.0, -1.0),
    simd_float3(0.0, -1.0, 0.0),
    simd_float3(0.0, -1.0, 0.0),
]

/// Runtime tuning for CSM shadow filtering.
public struct ShadowSoftnessSettings: Equatable, Sendable {
    public var enabled: Bool
    public var nearRadiusTexels: Float
    public var farRadiusTexels: Float
    public var depthScale: Float
    public var xrRadiusScale: Float

    public init(
        enabled: Bool = true,
        nearRadiusTexels: Float = 2.0,
        farRadiusTexels: Float = 5.0,
        depthScale: Float = 1.0,
        xrRadiusScale: Float = 1.35
    ) {
        self.enabled = enabled
        self.nearRadiusTexels = nearRadiusTexels
        self.farRadiusTexels = farRadiusTexels
        self.depthScale = depthScale
        self.xrRadiusScale = xrRadiusScale
    }
}

/// Swift mirror of the Metal CSMUniforms struct in ShaderStructs.h.
/// Layout must stay in sync with the Metal struct.
struct CSMUniforms {
    var lightSpaceMatrices: (simd_float4x4, simd_float4x4, simd_float4x4) = (
        matrix_identity_float4x4, matrix_identity_float4x4, matrix_identity_float4x4
    )
    var cameraViewMatrix: simd_float4x4 = matrix_identity_float4x4
    var cascadeSplits: (Float, Float, Float) = (0, 0, 0)
    var cascadeCount: Int32 = .init(csmCascadeCount)
    var cascadeWorldTexelSizes: (Float, Float, Float) = (1, 1, 1)
    var cascadeDepthSpans: (Float, Float, Float) = (1, 1, 1)
    var cascadeBlendStarts: (Float, Float, Float) = (0, 0, 0)
    var shadowSoftnessNear: Float = 1.0
    var shadowSoftnessFar: Float = 2.25
    var shadowSoftnessDepthScale: Float = 1.0
    var shadowSoftnessEnabled: Float = 1.0
}

struct SpotShadowUniforms {
    var lightSpaceMatrix: simd_float4x4 = matrix_identity_float4x4
    var lightIndex: Int32 = -1
    var enabled: Float = 0.0
    var shadowSoftness: Float = 2.0
    var bias: Float = 0.0015
}

struct PointShadowUniforms {
    var lightPosition: simd_float3 = .zero
    var farDistance: Float = 1.0
    var lightIndex: Int32 = -1
    var enabled: Float = 0.0
    var shadowSoftness: Float = 2.0
    var bias: Float = 0.0015
}

struct PointShadowState {
    var light: ShadowCastingPointLight?
    var lightSpaceMatrices: [simd_float4x4] = Array(repeating: matrix_identity_float4x4, count: 6)
    var farDistance: Float = minimumPointShadowDistance
    var isActive: Bool = false

    mutating func update() {
        isActive = false
        light = nil
        lightSpaceMatrices = Array(repeating: matrix_identity_float4x4, count: 6)
        farDistance = minimumPointShadowDistance

        guard let shadowLight = getShadowCastingPointLight() else { return }

        let position = shadowLight.light.position
        guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { return }

        farDistance = pointShadowDistance(for: shadowLight.light)
        let nearZ: Float = 0.05
        let projection = matrixPerspectiveRightHand(
            fovyRadians: degreesToRadians(degrees: 90.0),
            aspectRatio: 1.0,
            nearZ: nearZ,
            farZ: farDistance
        )

        for face in 0 ..< 6 {
            let view = matrix_look_at_right_hand(
                position,
                position + pointShadowFaceDirections[face],
                pointShadowFaceUpVectors[face]
            )
            lightSpaceMatrices[face] = simd_mul(projection, view)
        }

        light = shadowLight
        isActive = true
    }

    func makeUniforms() -> PointShadowUniforms {
        guard isActive, let light else {
            return PointShadowUniforms()
        }

        let softnessScale: Float = renderInfo.isXRStereoMode ? 1.35 : 1.0
        return PointShadowUniforms(
            lightPosition: light.light.position,
            farDistance: farDistance,
            lightIndex: light.index,
            enabled: 1.0,
            shadowSoftness: (light.light.attenuation.x < 0.0
                ? max(light.light.radius, 0.001)
                : 2.0) * softnessScale,
            bias: 0.0015
        )
    }
}

struct SpotShadowState {
    var light: ShadowCastingSpotLight?
    var lightSpaceMatrix: simd_float4x4 = matrix_identity_float4x4
    var frustum: Frustum?
    var isActive: Bool = false

    mutating func update() {
        isActive = false
        light = nil
        lightSpaceMatrix = matrix_identity_float4x4
        frustum = nil

        guard let shadowLight = getShadowCastingSpotLight() else { return }

        let direction = simd_normalize(shadowLight.light.direction)
        guard direction.x.isFinite, direction.y.isFinite, direction.z.isFinite else { return }

        let position = shadowLight.light.position
        let outerCone = max(shadowLight.light.outerCone, degreesToRadians(degrees: 1.0))
        let fov = min(max(outerCone * 2.0, degreesToRadians(degrees: 1.0)), degreesToRadians(degrees: 175.0))
        let nearZ: Float = 0.05
        let farZ = max(spotShadowDistance(for: shadowLight.light), nearZ + 0.01)
        let up = stableSpotShadowUp(for: direction)
        let view = matrix_look_at_right_hand(position, position + direction, up)
        let projection = matrixPerspectiveRightHand(fovyRadians: fov, aspectRatio: 1.0, nearZ: nearZ, farZ: farZ)
        let matrix = simd_mul(projection, view)

        light = shadowLight
        lightSpaceMatrix = matrix
        frustum = buildFrustum(from: matrix)
        isActive = true
    }

    func makeUniforms() -> SpotShadowUniforms {
        guard isActive, let light else {
            return SpotShadowUniforms()
        }

        let softnessScale: Float = renderInfo.isXRStereoMode ? 1.35 : 1.0
        return SpotShadowUniforms(
            lightSpaceMatrix: SceneRootTransform.shared.effectiveLightMatrix(lightSpaceMatrix),
            lightIndex: light.index,
            enabled: 1.0,
            shadowSoftness: (light.light.attenuation.x < 0.0
                ? max(light.light.radius, 0.001)
                : 2.0) * softnessScale,
            bias: 0.0015
        )
    }
}

private func pointShadowDistance(for light: PointLight) -> Float {
    if light.attenuation.w > 0.0 {
        return max(light.attenuation.w, minimumPointShadowDistance)
    }
    guard light.attenuation.x < 0.0 else {
        return max(light.radius, minimumPointShadowDistance)
    }

    let radiantIntensity = max(light.intensity, 0.0) / (4.0 * Float.pi)
    let automaticDistance = sqrt(radiantIntensity / localShadowInfluenceThreshold)
    return simd_clamp(
        automaticDistance,
        minimumPointShadowDistance,
        max(RenderPasses.maxShadowCastingDistance, minimumPointShadowDistance)
    )
}

private func spotShadowDistance(for light: SpotLight) -> Float {
    if light.attenuation.w > 0.0 {
        return max(light.attenuation.w, minimumSpotShadowDistance)
    }
    guard light.attenuation.x < 0.0 else {
        return max(light.attenuation.w, minimumSpotShadowDistance)
    }

    let solidAngle = max(2.0 * Float.pi * (1.0 - cos(light.outerCone)), 1.0e-4)
    let radiantIntensity = max(light.intensity, 0.0) / solidAngle
    let automaticDistance = sqrt(radiantIntensity / localShadowInfluenceThreshold)
    return simd_clamp(
        automaticDistance,
        minimumSpotShadowDistance,
        max(RenderPasses.maxShadowCastingDistance, minimumSpotShadowDistance)
    )
}

private func stableSpotShadowUp(for direction: simd_float3) -> simd_float3 {
    let worldUp = simd_float3(0.0, 1.0, 0.0)
    if abs(simd_dot(direction, worldUp)) < 0.95 {
        return worldUp
    }
    return simd_float3(1.0, 0.0, 0.0)
}

struct ShadowSystem {
    private struct ShadowCasterBounds {
        var min: simd_float3
        var max: simd_float3
    }

    private struct LightSpaceBounds {
        var min: simd_float3
        var max: simd_float3
    }

    // Per-frame cascade outputs
    var cascadeLightSpaceMatrices: [simd_float4x4] = Array(repeating: matrix_identity_float4x4, count: csmCascadeCount)
    var cascadeSplitDistances: [Float] = Array(repeating: 0, count: csmCascadeCount)
    var cascadeWorldTexelSizes: [Float] = Array(repeating: 1, count: csmCascadeCount)
    var cascadeDepthSpans: [Float] = Array(repeating: 1, count: csmCascadeCount)
    /// World-space centroid and bounding-sphere radius of each cascade's camera-frustum
    /// slice. Used by the renderer to reject shadow casters that are farther than the
    /// engine's own shadow-distance horizon from anything this cascade could possibly
    /// receive — a cull that stays correct for any light direction, unlike a camera-depth
    /// cutoff (see RenderPasses.shadowCasterEntityIds).
    var cascadeWorldCenters: [simd_float3] = Array(repeating: .zero, count: csmCascadeCount)
    var cascadeWorldRadii: [Float] = Array(repeating: 0, count: csmCascadeCount)
    /// Camera-depth distance at which each cascade begins cross-fading into the next.
    /// Computed once per frame by `cascadeBlendStart` and uploaded to the shader — see
    /// that function's doc comment for why this is the single source of truth for the
    /// blend boundary shared by the CPU frustum widening and the GPU cross-fade.
    var cascadeBlendStarts: [Float] = Array(repeating: 0, count: csmCascadeCount)
    var softnessSettings: ShadowSoftnessSettings = .init()
    var isActive: Bool = false

    /// Legacy accessor used by callers that only need to know "is there a shadow?"
    var dirLightSpaceMatrix: simd_float4x4? {
        isActive ? cascadeLightSpaceMatrices[0] : nil
    }

    /// Camera-depth distance at which cascade `cascadeIdx` begins cross-fading its
    /// visibility into the next cascade. This is the single source of truth for the
    /// blend boundary: it is computed once per frame here on the CPU, used directly to
    /// widen the *next* cascade's frustum-fitting near plane (`cascadeNearDistance`
    /// below), and uploaded via `makeUniforms()` so the shader reads the same value
    /// instead of re-deriving it from `cascadeSplits` — eliminating the CPU/GPU-duplicated
    /// formula that previously had to be kept in sync by hand.
    /// Internal — exposed for testing via @testable import.
    static func cascadeBlendStart(
        cascadeIdx: Int,
        splits: [Float],
        blendFraction: Float
    ) -> Float {
        guard cascadeIdx >= 0, cascadeIdx < splits.count else { return 0 }
        // Match the shader's first interval, which begins at camera depth zero.
        let intervalNear: Float = cascadeIdx > 0 ? splits[cascadeIdx - 1] : 0
        let intervalLength = max(splits[cascadeIdx] - intervalNear, 0.001)
        let blendWidth = intervalLength * simd_clamp(blendFraction, 0.0, 0.5)
        return splits[cascadeIdx] - blendWidth
    }

    /// Near-plane distance for cascade `cascadeIdx`'s frustum-fitting sub-frustum.
    /// Cascades after the first begin at the preceding cascade's blend-start distance,
    /// so both cascades' fitted frustums cover the receiver positions the shader
    /// cross-fades over.
    /// Internal — exposed for testing via @testable import.
    static func cascadeNearDistance(
        cascadeIdx: Int,
        splits: [Float],
        cameraNear: Float,
        blendFraction: Float
    ) -> Float {
        guard cascadeIdx > 0 else { return cameraNear }
        return max(cameraNear, cascadeBlendStart(cascadeIdx: cascadeIdx - 1, splits: splits, blendFraction: blendFraction))
    }

    /// Fills the 3 fixed GPU slots from a per-cascade array, padding unused slots
    /// (beyond csmCascadeCount) with `fallback` so the shader's cascadeCount field
    /// controls which slots are actually read.
    private static func pack3<T>(_ values: [T], fallback: T) -> (T, T, T) {
        (
            values[0],
            csmCascadeCount > 1 ? values[1] : fallback,
            csmCascadeCount > 2 ? values[2] : fallback
        )
    }

    /// Pack into the GPU-ready uniform struct.
    /// CSMUniforms always carries 3 slots (GPU layout is fixed); unused slots are
    /// left as identity/zero so the shader's cascadeCount field controls which are read.
    func makeUniforms() -> CSMUniforms {
        var u = CSMUniforms()
        u.lightSpaceMatrices = Self.pack3(cascadeLightSpaceMatrices, fallback: matrix_identity_float4x4)
        u.cascadeSplits = Self.pack3(cascadeSplitDistances, fallback: 0)
        u.cascadeCount = Int32(csmCascadeCount)
        u.cascadeWorldTexelSizes = Self.pack3(cascadeWorldTexelSizes, fallback: cascadeWorldTexelSizes[0])
        u.cascadeDepthSpans = Self.pack3(cascadeDepthSpans, fallback: cascadeDepthSpans[0])
        u.cascadeBlendStarts = Self.pack3(cascadeBlendStarts, fallback: cascadeBlendStarts[0])
        let softness = Self.sanitizedSoftnessSettings(softnessSettings)
        let xrScale = renderInfo.isXRStereoMode ? softness.xrRadiusScale : 1.0
        u.shadowSoftnessNear = softness.nearRadiusTexels * xrScale
        u.shadowSoftnessFar = softness.farRadiusTexels * xrScale
        u.shadowSoftnessDepthScale = softness.depthScale
        u.shadowSoftnessEnabled = softness.enabled ? 1.0 : 0.0
        return u
    }

    mutating func setSoftness(_ settings: ShadowSoftnessSettings) {
        softnessSettings = Self.sanitizedSoftnessSettings(settings)
    }

    private static func sanitizedSoftnessSettings(_ settings: ShadowSoftnessSettings) -> ShadowSoftnessSettings {
        let nearRadius = simd_clamp(settings.nearRadiusTexels, 0.25, 8.0)
        let farRadius = simd_clamp(settings.farRadiusTexels, nearRadius, 12.0)
        let depthScale = simd_clamp(settings.depthScale, 0.0, 2.0)
        let xrRadiusScale = simd_clamp(settings.xrRadiusScale, 1.0, 2.0)
        return ShadowSoftnessSettings(
            enabled: settings.enabled,
            nearRadiusTexels: nearRadius,
            farRadiusTexels: farRadius,
            depthScale: depthScale,
            xrRadiusScale: xrRadiusScale
        )
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

        guard let lightEntity = LightingSystem.shared.activeDirectionalLight,
              let directionalLight = scene.get(component: DirectionalLightComponent.self, for: lightEntity),
              scene.get(component: LocalTransformComponent.self, for: lightEntity) != nil
        else {
            LightingSystem.shared.activeDirectionalLight = nil
            return
        }
        guard directionalLight.castsShadow else { return }

        let lightForward = getLightEmissionDirection(entityId: lightEntity)

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

        // Keep cascades within the same effective distance used to cull shadow casters.
        // This gives small/editor scenes more texel density in the near cascade.
        let shadowFar = min(far, RenderPasses.maxShadowCastingDistance)
        let cameraFar: Float = renderInfo.isXRStereoMode ? min(50.0, shadowFar) : shadowFar

        // Practical split scheme (blend of log and uniform, λ=0.5).
        let splits = computeCascadeSplits(cameraNear: near, cameraFar: cameraFar)
        cascadeSplitDistances = splits
        for i in 0 ..< csmCascadeCount {
            cascadeBlendStarts[i] = Self.cascadeBlendStart(
                cascadeIdx: i, splits: splits, blendFraction: csmCascadeBlendFraction
            )
        }

        // Light view: look along lightForward using a stable up vector.
        let lightUp: simd_float3 = abs(lightForward.y) < 0.99
            ? simd_float3(0, 1, 0)
            : simd_float3(0, 0, 1)
        let lightView = matrix_look_at_right_hand(-lightForward * 150.0, simd_float3(0, 0, 0), lightUp)
        let casterLightSpaceBounds = collectShadowCasterBounds().map {
            lightSpaceBounds(for: $0, lightView: lightView)
        }

        for i in 0 ..< csmCascadeCount {
            let cascadeFar = splits[i]
            let cascadeNear = Self.cascadeNearDistance(
                cascadeIdx: i,
                splits: splits,
                cameraNear: near,
                blendFraction: csmCascadeBlendFraction
            )

            // 8 corners of the cascade sub-frustum in world space.
            // Farther cascades begin inside the preceding cascade so both maps
            // cover the receiver positions used by the transition blend.
            let corners = cascadeFrustumCornersWorldSpace(
                invViewMatrix: invView,
                tanHalfFovX: tanHalfFovX,
                tanHalfFovY: tanHalfFovY,
                nearDist: cascadeNear,
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
            var radius: Float = 0
            for corner in corners {
                radius = max(radius, simd_length(corner - center))
            }

            let diameter = max(ceil(radius * 2.0), 0.001)
            let texelSize = diameter / Float(shadowResolution.x)
            cascadeWorldTexelSizes[i] = texelSize
            cascadeWorldCenters[i] = center
            cascadeWorldRadii[i] = radius

            var centerLS = lightView * simd_float4(center, 1.0)
            centerLS.x = floor(centerLS.x / texelSize) * texelSize
            centerLS.y = floor(centerLS.y / texelSize) * texelSize

            let halfDiameter = diameter * 0.5
            let minX = centerLS.x - halfDiameter
            let maxX = centerLS.x + halfDiameter
            let minY = centerLS.y - halfDiameter
            let maxY = centerLS.y + halfDiameter

            // Start from the receiver cascade corners, then expand light-space Z
            // using caster AABBs whose light-space XY overlaps this cascade. Indoor
            // occluders such as ceilings can sit outside the receiver slice depth
            // while still blocking light from visible floors/walls.
            var minZ = Float.infinity, maxZ = -Float.infinity

            for corner in corners {
                let lc = lightView * simd_float4(corner, 1.0)
                minZ = min(minZ, lc.z); maxZ = max(maxZ, lc.z)
            }

            let casterXYMargin = max(texelSize * 4.0, diameter * 0.03)
            for boundsLS in casterLightSpaceBounds {
                guard lightSpaceXYIntersects(
                    boundsLS,
                    minX: minX - casterXYMargin,
                    maxX: maxX + casterXYMargin,
                    minY: minY - casterXYMargin,
                    maxY: maxY + casterXYMargin
                ) else {
                    continue
                }

                minZ = min(minZ, boundsLS.min.z)
                maxZ = max(maxZ, boundsLS.max.z)
            }

            let depthMargin: Float = max(0.5, min(8.0, diameter * 0.1))
            minZ -= depthMargin
            maxZ += depthMargin

            // Convert light-space Z extents to positive near/far distances for the ortho matrix.
            // In right-hand view space, scene geometry is at negative Z; nearest geometry has
            // the largest (least-negative) Z, which becomes nearZ; farthest becomes farZ.
            let orthoNearZ = -maxZ
            let orthoFarZ = -minZ
            cascadeDepthSpans[i] = max(orthoFarZ - orthoNearZ, 0.001)

            let ortho = matrix_ortho_right_hand(minX, maxX, minY, maxY, orthoNearZ, farZ: orthoFarZ)
            cascadeLightSpaceMatrices[i] = simd_mul(ortho, lightView)
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

    private func collectShadowCasterBounds() -> [ShadowCasterBounds] {
        let transformId = getComponentId(for: WorldTransformComponent.self)
        let localTransformId = getComponentId(for: LocalTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, localTransformId, renderId], in: scene)
        let batchingEnabled = BatchingSystem.shared.isEnabled()

        var bounds: [ShadowCasterBounds] = []
        bounds.reserveCapacity(entities.count)

        for entityId in entities {
            guard scene.mask(for: entityId) != nil else { continue }
            if scene.get(component: SceneCameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: CameraComponent.self, for: entityId) != nil { continue }
            if scene.get(component: LightComponent.self, for: entityId) != nil { continue }
            if scene.get(component: GizmoComponent.self, for: entityId) != nil { continue }
            if shouldHideSceneEntity(entityId: entityId) { continue }
            if shouldRenderSceneEntityAsWireframe(entityId: entityId) { continue }
            if batchingEnabled, scene.get(component: StaticBatchComponent.self, for: entityId) != nil { continue }
            if batchingEnabled, BatchingSystem.shared.isBatched(entityId: entityId) { continue }

            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  renderComponent.isVisible,
                  let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)
            else {
                continue
            }

            let (worldMin, worldMax) = worldAABB_MinMax(
                localMin: localTransformComponent.boundingBox.min,
                localMax: localTransformComponent.boundingBox.max,
                worldMatrix: worldTransformComponent.space
            )
            bounds.append(ShadowCasterBounds(min: worldMin, max: worldMax))
        }

        if batchingEnabled {
            for group in BatchingSystem.shared.batchGroups where shouldRenderSceneChannelsOpaque(group.sceneChannels) {
                bounds.append(ShadowCasterBounds(min: group.boundingBox.min, max: group.boundingBox.max))
            }
        }

        return bounds
    }

    private func lightSpaceBounds(
        for caster: ShadowCasterBounds,
        lightView: simd_float4x4
    ) -> LightSpaceBounds {
        var minPoint = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var maxPoint = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        for corner in aabbCorners(min: caster.min, max: caster.max) {
            let p = lightView * simd_float4(corner, 1.0)
            let point = simd_float3(p.x, p.y, p.z)
            minPoint = simd_min(minPoint, point)
            maxPoint = simd_max(maxPoint, point)
        }

        return LightSpaceBounds(min: minPoint, max: maxPoint)
    }

    private func lightSpaceXYIntersects(
        _ bounds: LightSpaceBounds,
        minX: Float,
        maxX: Float,
        minY: Float,
        maxY: Float
    ) -> Bool {
        bounds.max.x >= minX &&
            bounds.min.x <= maxX &&
            bounds.max.y >= minY &&
            bounds.min.y <= maxY
    }

    private func aabbCorners(min: simd_float3, max: simd_float3) -> [simd_float3] {
        [
            simd_float3(min.x, min.y, min.z),
            simd_float3(max.x, min.y, min.z),
            simd_float3(min.x, max.y, min.z),
            simd_float3(max.x, max.y, min.z),
            simd_float3(min.x, min.y, max.z),
            simd_float3(max.x, min.y, max.z),
            simd_float3(min.x, max.y, max.z),
            simd_float3(max.x, max.y, max.z),
        ]
    }
}

public func setShadowSoftness(_ settings: ShadowSoftnessSettings) {
    shadowSystem.setSoftness(settings)
}

public func getShadowSoftness() -> ShadowSoftnessSettings {
    shadowSystem.softnessSettings
}
