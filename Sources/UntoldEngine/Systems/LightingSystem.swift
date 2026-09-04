
//
//  LightingSystem.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import simd

public final class LightingSystem: @unchecked Sendable {
    public static let shared: LightingSystem = .init()

    private let activeDirectionalLightLock = NSLock()
    private var _activeDirectionalLight: EntityID?
    private let lightPortalRenderDiagnosticsLock = NSLock()
    private var latestLightPortalRenderDiagnostics = LightPortalRenderDiagnostics.empty
    private let lightPortalAreaLightCacheLock = NSLock()
    private var lightPortalAreaLightCache: LightPortalAreaLightCache?

    private init() {}

    public var activeDirectionalLight: EntityID? {
        get {
            activeDirectionalLightLock.lock()
            defer { activeDirectionalLightLock.unlock() }
            return _activeDirectionalLight
        }
        set {
            activeDirectionalLightLock.lock()
            _activeDirectionalLight = newValue
            activeDirectionalLightLock.unlock()
        }
    }

    fileprivate func setLightPortalRenderDiagnostics(_ diagnostics: LightPortalRenderDiagnostics) {
        lightPortalRenderDiagnosticsLock.lock()
        latestLightPortalRenderDiagnostics = diagnostics
        lightPortalRenderDiagnosticsLock.unlock()
    }

    fileprivate func getLightPortalRenderDiagnostics() -> LightPortalRenderDiagnostics {
        lightPortalRenderDiagnosticsLock.lock()
        let diagnostics = latestLightPortalRenderDiagnostics
        lightPortalRenderDiagnosticsLock.unlock()
        return diagnostics
    }

    fileprivate func cachedLightPortalAreaLights(
        frameIndex: Int,
        authoredAreaLightCount: Int,
        remainingAreaLightCapacity: Int
    ) -> (areaLights: [AreaLight], diagnostics: LightPortalRenderDiagnostics)? {
        lightPortalAreaLightCacheLock.lock()
        let cache = lightPortalAreaLightCache
        lightPortalAreaLightCacheLock.unlock()

        guard cache?.frameIndex == frameIndex,
              cache?.authoredAreaLightCount == authoredAreaLightCount,
              cache?.remainingAreaLightCapacity == remainingAreaLightCapacity,
              let cache
        else {
            return nil
        }

        return (cache.areaLights, cache.diagnostics)
    }

    fileprivate func setCachedLightPortalAreaLights(
        frameIndex: Int,
        authoredAreaLightCount: Int,
        remainingAreaLightCapacity: Int,
        areaLights: [AreaLight],
        diagnostics: LightPortalRenderDiagnostics
    ) {
        lightPortalAreaLightCacheLock.lock()
        lightPortalAreaLightCache = LightPortalAreaLightCache(
            frameIndex: frameIndex,
            authoredAreaLightCount: authoredAreaLightCount,
            remainingAreaLightCapacity: remainingAreaLightCapacity,
            areaLights: areaLights,
            diagnostics: diagnostics
        )
        lightPortalAreaLightCacheLock.unlock()
    }

    fileprivate func resetLightPortalAreaLightCache() {
        lightPortalAreaLightCacheLock.lock()
        lightPortalAreaLightCache = nil
        lightPortalAreaLightCacheLock.unlock()
    }
}

public struct DirectionalLight {
    var direction: simd_float3 = .init(1.0, 1.0, 1.0)
    var color: simd_float3 = .init(1.0, 1.0, 1.0)
    var intensity: Float = 1.0
}

public struct PointLight {
    /// Legacy coefficients in xyz, or x < 0 for radiometric inverse-square.
    /// w is the optional influence range.
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0)
    var position: simd_float3 = .init(0.0, 1.0, 0.0)
    var color: simd_float3 = .init(1.0, 0.0, 0.0)
    var intensity: Float = 1.0
    var radius: Float = 1.0
}

struct ShadowCastingPointLight {
    var entityId: EntityID
    var light: PointLight
    var index: Int32
}

public struct SpotLight {
    /// Legacy coefficients in xyz, or x < 0 for radiometric inverse-square.
    /// w is the optional influence range.
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0)
    var direction: simd_float3 = .init(1.0, 1.0, 1.0)
    var position: simd_float3 = .init(0.0, 1.0, 0.0)
    var color: simd_float3 = .init(1.0, 0.0, 0.0)
    var intensity: Float = 1.0
    var innerCone: Float = 0.0
    var outerCone: Float = 0.0
    var radius: Float = 1.0
}

struct ShadowCastingSpotLight {
    var entityId: EntityID
    var light: SpotLight
    var index: Int32
}

public struct AreaLight {
    var position: simd_float3 = .init(0.0, 0.0, 0.0) // Center position of the area light
    var color: simd_float3 = .init(1.0, 1.0, 1.0) // Light color
    var forward: simd_float3 = .init(0.0, 0.0, 1.0) // LTC polygon/front normal used by the shader
    var right: simd_float3 = .init(1.0, 0.0, 0.0) // Right vector defining the surface orientation
    var up: simd_float3 = .init(0.0, 1.0, 0.0) // Up vector defining the surface orientation
    var bounds: simd_float2 = .one
    var intensity: Float = 1.0 // Light intensity
    var range: Float = 0.0 // Maximum influence distance; 0 keeps legacy unlimited area-light behavior
    var nearSourceSuppressionRadius: Float = 0.0 // Radius near the light surface that fades contribution; 0 disables
    var twoSided: Bool = false // Whether the light emits from both sides
}

private enum LightPortalLightingTuning {
    static let suppressionFractionOfMinDimension: Float = 0.2
    static let minSuppressionRadius: Float = 0.15
    static let maxSuppressionRadius: Float = 0.5
}

private struct LightPortalAreaLightCache {
    var frameIndex: Int
    var authoredAreaLightCount: Int
    var remainingAreaLightCapacity: Int
    var areaLights: [AreaLight]
    var diagnostics: LightPortalRenderDiagnostics
}

public struct LightPortalRenderDiagnostics: Equatable, Sendable {
    public var authoredAreaLightCount: Int
    public var portalAreaLightCount: Int
    public var remainingAreaLightCapacity: Int
    public var environmentIntensityScale: Float
    public var xrIntensityScale: Float?
    public var environmentTintColor: simd_float3
    public var realWorldLightingContribution: Float
    public var xrLightingValid: Bool
    public var minEffectivePortalIntensity: Float?
    public var maxEffectivePortalIntensity: Float?
    public var averageEffectivePortalIntensity: Float?
    public var totalEffectivePortalIntensity: Float
    public var fallbackReason: String?

    public static let empty = LightPortalRenderDiagnostics(
        authoredAreaLightCount: 0,
        portalAreaLightCount: 0,
        remainingAreaLightCapacity: 0,
        environmentIntensityScale: 1.0,
        xrIntensityScale: nil,
        environmentTintColor: simd_float3(1.0, 1.0, 1.0),
        realWorldLightingContribution: 1.0,
        xrLightingValid: false,
        minEffectivePortalIntensity: nil,
        maxEffectivePortalIntensity: nil,
        averageEffectivePortalIntensity: nil,
        totalEffectivePortalIntensity: 0.0,
        fallbackReason: nil
    )
}

private func setLightPortalRenderDiagnostics(_ diagnostics: LightPortalRenderDiagnostics) {
    LightingSystem.shared.setLightPortalRenderDiagnostics(diagnostics)
}

public func getLightPortalRenderDiagnostics() -> LightPortalRenderDiagnostics {
    LightingSystem.shared.getLightPortalRenderDiagnostics()
}

public func resetLightPortalRenderDiagnostics() {
    setLightPortalRenderDiagnostics(.empty)
}

public func resetLightPortalAreaLightCache() {
    LightingSystem.shared.resetLightPortalAreaLightCache()
}

private func applyDefaultLightOrientation(entityId: EntityID) {
    // Engine light emission is defined as local -Z transformed into world space.
    // Rotate identity lights so the default emission direction points along -Y.
    rotateTo(entityId: entityId, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
}

private func assignDefaultProceduralLightMesh(entityId: EntityID) {
    let meshes = BasicPrimitives.createCube(extent: 0.5)
    setEntityMeshDirect(entityId: entityId, meshes: meshes, assetName: "default_cube")
}

private let minimumLightRadius: Float = 0.001
private let minimumSpotConeAngle: Float = 0.1
private let maximumSpotConeAngle: Float = 89.0
private let minimumSpotConeSeparation: Float = 0.05

private func sanitizedLightRadius(_ radius: Float) -> Float {
    max(radius, minimumLightRadius)
}

private func sanitizedLightFalloff(_ falloff: Float) -> Float {
    simd_clamp(falloff, 0.0, 1.0)
}

private func lightAttenuationUniform(
    usesRadiometricUnits: Bool,
    falloff: Float,
    sourceRadius: Float,
    range: Float
) -> simd_float4 {
    if usesRadiometricUnits {
        return simd_float4(-1.0, 0.0, 0.0, max(range, 0.0))
    }

    let sanitizedFalloff = sanitizedLightFalloff(falloff)
    let legacyRadius = sanitizedLightRadius(sourceRadius)
    let linear: Float = simd_mix(0.1, 0.0, sanitizedFalloff)
    let quadratic: Float = simd_mix(0.0, 1.0 / (legacyRadius * legacyRadius), sanitizedFalloff)
    return simd_float4(1.0, linear, quadratic, legacyRadius)
}

private func sanitizedSpotConeAngle(_ coneAngle: Float) -> Float {
    simd_clamp(coneAngle, minimumSpotConeAngle, maximumSpotConeAngle)
}

private func derivedSpotConeAngles(coneAngle: Float, falloff: Float) -> (inner: Float, outer: Float) {
    let outerCone = sanitizedSpotConeAngle(coneAngle)
    let edgeSoftness = min(
        simd_mix(1.0, 10.0, sanitizedLightFalloff(falloff)),
        max(minimumSpotConeSeparation, outerCone - minimumSpotConeSeparation)
    )
    return (max(minimumSpotConeAngle, outerCone - edgeSoftness), outerCone)
}

private func syncDerivedSpotConeAngles(_ spotLightComponent: SpotLightComponent) {
    let cones = derivedSpotConeAngles(
        coneAngle: spotLightComponent.coneAngle,
        falloff: spotLightComponent.falloff
    )
    spotLightComponent.innerCone = cones.inner
    spotLightComponent.outerCone = cones.outer
}

private func normalizedLightDirection(_ direction: simd_float3, fallback: simd_float3) -> simd_float3 {
    let lengthSquared = simd_length_squared(direction)
    guard lengthSquared.isFinite, lengthSquared > 1.0e-8 else {
        return fallback
    }
    return direction / sqrt(lengthSquared)
}

/// Returns the entity transform's local +Z axis in world space.
///
/// This is a pure transform concept. Use `getLightEmissionDirection(entityId:)`
/// when asking where a non-point light emits.
public func getLightTransformForwardAxis(entityId: EntityID) -> simd_float3 {
    if scene.get(component: WorldTransformComponent.self, for: entityId) != nil {
        let orientation = getOrientation(entityId: entityId)
        return normalizedLightDirection(
            simd_float3(
                orientation.columns.2.x,
                orientation.columns.2.y,
                orientation.columns.2.z
            ),
            fallback: simd_float3(0.0, 0.0, 1.0)
        )
    }

    return normalizedLightDirection(
        getForwardAxisVector(entityId: entityId),
        fallback: simd_float3(0.0, 0.0, 1.0)
    )
}

/// Returns the semantic light emission/travel direction.
///
/// Untold lights emit along local -Z transformed into world space. Point lights do
/// not have a physical emission axis, but returning the transform-derived value
/// keeps editor/debug handles deterministic if they request one.
public func getLightEmissionDirection(entityId: EntityID) -> simd_float3 {
    normalizedLightDirection(
        -getLightTransformForwardAxis(entityId: entityId),
        fallback: simd_float3(0.0, -1.0, 0.0)
    )
}

/// Directional lighting shaders currently consume the BRDF light vector from the
/// shaded point toward the light source, which is opposite the light's emission.
public func getDirectionalLightShaderDirection(entityId: EntityID) -> simd_float3 {
    normalizedLightDirection(
        -getLightEmissionDirection(entityId: entityId),
        fallback: simd_float3(0.0, 1.0, 0.0)
    )
}

/// Returns the sun elevation/azimuth (degrees) implied by the entity's current orientation, using
/// the same forward-axis convention as `getDirectionalLightShaderDirection(entityId:)`.
///
/// This is a pure re-parameterization of the existing transform orientation (pitch/yaw) -- no
/// additional state is stored, so it can never drift from the transform. `elevation` is the angle
/// above the horizon (-90 straight down ... 0 horizon ... 90 straight up); `azimuth` is the
/// compass angle around the horizon measured from +Z toward +X, in [0, 360). Roll has no effect
/// on light direction and is not represented here.
public func getSunElevationAzimuth(entityId: EntityID) -> (elevation: Float, azimuth: Float) {
    let direction = getDirectionalLightShaderDirection(entityId: entityId)

    let elevation = radiansToDegrees(radians: asin(clampFloat(direction.y, min: -1.0, max: 1.0)))
    let azimuth = radiansToDegrees(radians: atan2(direction.x, direction.z))

    return (elevation, azimuth < 0.0 ? azimuth + 360.0 : azimuth)
}

/// Orients the entity so its light direction points at the given sun elevation/azimuth (degrees),
/// using the same convention as `getSunElevationAzimuth(entityId:)`. Rebuilds the full orientation
/// from the target direction, so any existing roll is discarded -- consistent with roll having no
/// effect on light direction.
public func setSunElevationAzimuth(entityId: EntityID, elevation: Float, azimuth: Float) {
    guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    let elevationRad = degreesToRadians(degrees: elevation)
    let azimuthRad = degreesToRadians(degrees: azimuth)

    let horizontalRadius = cos(elevationRad)
    let direction = simd_float3(
        horizontalRadius * sin(azimuthRad),
        sin(elevationRad),
        horizontalRadius * cos(azimuthRad)
    )

    // quaternion_lookAt maps local +Z (the light's forward/shader-direction axis) to
    // (eye - target); passing the target direction as `eye` with `target` at the origin makes
    // local +Z equal `direction`, matching getDirectionalLightShaderDirection's convention.
    let up: simd_float3 = abs(direction.y) > 0.999 ? simd_float3(0.0, 0.0, 1.0) : simd_float3(0.0, 1.0, 0.0)
    let rotation = quaternion_lookAt(eye: direction, target: simd_float3(0.0, 0.0, 0.0), up: up)

    rotateTo(entityId: entityId, rotation: rotation)
}

public func createDirLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: DirectionalLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    assignDefaultProceduralLightMesh(entityId: entityId)
    // Default sun position/brightness for newly-created directional lights, tuned for the
    // procedural sky background (see getSunElevationAzimuth/setSunElevationAzimuth).
    setSunElevationAzimuth(entityId: entityId, elevation: 90.0, azimuth: 0.0)

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .directional
    lightComponent.intensity = 5.0
    if LightingSystem.shared.activeDirectionalLight == nil {
        LightingSystem.shared.activeDirectionalLight = entityId
    }

    do {
        let texture = try loadTexture(device: renderInfo.device, textureName: "directional_light_icon_256x256", withExtension: "png")

        lightComponent.texture.directional = texture

    } catch {
        handleError(.textureMissing)
    }
}

public func createPointLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: PointLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    assignDefaultProceduralLightMesh(entityId: entityId)
    applyDefaultLightOrientation(entityId: entityId)

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .point

    do {
        let texture = try loadTexture(device: renderInfo.device, textureName: "point_light_icon_256x256", withExtension: "png")

        lightComponent.texture.point = texture

    } catch {
        handleError(.textureMissing)
    }
}

public func createSpotLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: SpotLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    assignDefaultProceduralLightMesh(entityId: entityId)
    applyDefaultLightOrientation(entityId: entityId)

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .spotlight
    if let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) {
        syncDerivedSpotConeAngles(spotLightComponent)
    }
    updateMaterialEmmisive(entityId: entityId, emmissive: simd_float3(1.0, 1.0, 1.0))

    do {
        let texture = try loadTexture(device: renderInfo.device, textureName: "spot_light_icon_256x256", withExtension: "png")

        lightComponent.texture.spot = texture

    } catch {
        handleError(.textureMissing)
    }
}

public func createAreaLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: AreaLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    assignDefaultProceduralLightMesh(entityId: entityId)
    applyDefaultLightOrientation(entityId: entityId)

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .area
    updateMaterialEmmisive(entityId: entityId, emmissive: simd_float3(1.0, 1.0, 1.0))

    do {
        let texture = try loadTexture(device: renderInfo.device, textureName: "area_light_icon_256x256", withExtension: "png")

        lightComponent.texture.area = texture

    } catch {
        handleError(.textureMissing)
    }
}

func getDirectionalLightParameters() -> LightParameters {
    var lightDirection = simd_float3(0.0, 1.0, 0.0)
    var lightIntensity: Float = 0.0
    var lightColor = simd_float3(0.0, 0.0, 0.0)

    guard let entity = LightingSystem.shared.activeDirectionalLight else {
        var lightParameter = LightParameters()
        lightParameter.direction = lightDirection
        lightParameter.intensity = lightIntensity
        lightParameter.color = lightColor
        return lightParameter
    }

    guard let lightComponent = scene.get(component: LightComponent.self, for: entity),
          scene.get(component: DirectionalLightComponent.self, for: entity) != nil,
          scene.get(component: LocalTransformComponent.self, for: entity) != nil
    else {
        LightingSystem.shared.activeDirectionalLight = nil
        var lightParameter = LightParameters()
        lightParameter.direction = lightDirection
        lightParameter.intensity = lightIntensity
        lightParameter.color = lightColor
        return lightParameter
    }

    lightDirection = getDirectionalLightShaderDirection(entityId: entity)
    lightIntensity = lightComponent.intensity
    lightColor = lightComponent.color

    var lightParameter = LightParameters()
    lightParameter.direction = lightDirection
    lightParameter.intensity = lightIntensity
    lightParameter.color = lightColor

    return lightParameter
}

public func updateLightColor(entityId: EntityID, color: simd_float3) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.color = color
}

public func getLightColor(entityId: EntityID) -> simd_float3 {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return .zero
    }

    return lightComponent.color
}

public func updateLightAttenuation(entityId: EntityID, attenuation: simd_float3) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }

        pointLightComponent.attenuation = simd_float4(attenuation.x, attenuation.y, attenuation.z, 0.0)

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }

        spotLightComponent.attenuation = simd_float4(attenuation.x, attenuation.y, attenuation.z, 0.0)
    }
}

public func getLightAttenuation(entityId: EntityID) -> simd_float3 {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return .zero
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return .zero
        }

        return simd_float3(pointLightComponent.attenuation.x, pointLightComponent.attenuation.y, pointLightComponent.attenuation.z)

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return .zero
        }

        return simd_float3(spotLightComponent.attenuation.x, spotLightComponent.attenuation.y, spotLightComponent.attenuation.z)
    }

    return .zero
}

public func updateLightIntensity(entityId: EntityID, intensity: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.intensity = intensity
}

public func getLightIntensity(entityId: EntityID) -> Float {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return 0.0
    }

    return lightComponent.intensity
}

public func updatePointLightCastsShadow(entityId: EntityID, castsShadow: Bool) {
    guard scene.get(component: LightComponent.self, for: entityId) != nil else {
        handleError(.noLightComponent)
        return
    }

    guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
        handleError(.noPointLightComponent)
        return
    }

    pointLightComponent.castsShadow = castsShadow
}

public func getPointLightCastsShadow(entityId: EntityID) -> Bool {
    guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
        handleError(.noPointLightComponent)
        return false
    }

    return pointLightComponent.castsShadow
}

public func updateSpotLightCastsShadow(entityId: EntityID, castsShadow: Bool) {
    guard scene.get(component: LightComponent.self, for: entityId) != nil else {
        handleError(.noLightComponent)
        return
    }

    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return
    }

    spotLightComponent.castsShadow = castsShadow
}

public func getSpotLightCastsShadow(entityId: EntityID) -> Bool {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return false
    }

    return spotLightComponent.castsShadow
}

public func updateLightRadius(entityId: EntityID, radius: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }

        pointLightComponent.radius = sanitizedLightRadius(radius)

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }

        spotLightComponent.radius = sanitizedLightRadius(radius)
    }
}

public func getLightRadius(entityId: EntityID) -> Float {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return 0.0
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return 0.0
        }

        return pointLightComponent.radius

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return 0.0
        }

        return spotLightComponent.radius
    }

    return 0.0
}

public func getLightFalloff(entityId: EntityID) -> Float {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return 0.0
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return 0.0
        }

        return pointLightComponent.falloff

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return 0.0
        }

        return spotLightComponent.falloff
    }

    return 0.0
}

public func updateLightFalloff(entityId: EntityID, falloff: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }

        pointLightComponent.falloff = sanitizedLightFalloff(falloff)

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }

        spotLightComponent.falloff = sanitizedLightFalloff(falloff)
        syncDerivedSpotConeAngles(spotLightComponent)
    }
}

public func getPointLightCount() -> Int {
    let lightComponentID = getComponentId(for: PointLightComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID], in: scene)

    var pointCount = 0

    for entity in lightEntities {
        guard scene.get(component: PointLightComponent.self, for: entity) != nil else {
            handleError(.noLightComponent)
            continue
        }

        pointCount += 1
    }

    return pointCount
}

public func getSpotLightCount() -> Int {
    let lightComponentID = getComponentId(for: SpotLightComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID], in: scene)

    var spotPointCount = 0

    for entity in lightEntities {
        guard scene.get(component: SpotLightComponent.self, for: entity) != nil else {
            handleError(.noSpotLightComponent)
            continue
        }

        spotPointCount += 1
    }

    return spotPointCount
}

func getPointLights() -> [PointLight] {
    var pointLights: [PointLight] = []

    let lightComponentID = getComponentId(for: LightComponent.self)
    let pointLightComponentID = getComponentId(for: PointLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID, pointLightComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entity) else {
            handleError(.noPointLightComponent)
            continue
        }

        guard scene.get(component: LocalTransformComponent.self, for: entity) != nil else {
            handleError(.noLocalTransformComponent)
            continue
        }

        var pointLight = PointLight()
        pointLight.position = getPosition(entityId: entity)
        pointLight.color = lightComponent.color

        let radius = sanitizedLightRadius(pointLightComponent.radius)
        pointLight.attenuation = lightAttenuationUniform(
            usesRadiometricUnits: lightComponent.usesRadiometricUnits,
            falloff: pointLightComponent.falloff,
            sourceRadius: radius,
            range: pointLightComponent.range
        )
        pointLight.intensity = lightComponent.intensity
        pointLight.radius = radius

        pointLights.append(pointLight)
    }

    return pointLights
}

func getShadowCastingPointLight() -> ShadowCastingPointLight? {
    let lightComponentID = getComponentId(for: LightComponent.self)
    let pointLightComponentID = getComponentId(for: PointLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID, pointLightComponentID], in: scene)

    var pointIndex: Int32 = 0
    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity),
              let pointLightComponent = scene.get(component: PointLightComponent.self, for: entity),
              scene.get(component: LocalTransformComponent.self, for: entity) != nil
        else {
            continue
        }

        defer { pointIndex += 1 }
        guard pointLightComponent.castsShadow else { continue }

        var pointLight = PointLight()
        pointLight.position = getPosition(entityId: entity)
        pointLight.color = lightComponent.color

        let radius = sanitizedLightRadius(pointLightComponent.radius)
        pointLight.attenuation = lightAttenuationUniform(
            usesRadiometricUnits: lightComponent.usesRadiometricUnits,
            falloff: pointLightComponent.falloff,
            sourceRadius: radius,
            range: pointLightComponent.range
        )
        pointLight.intensity = lightComponent.intensity
        pointLight.radius = radius

        return ShadowCastingPointLight(entityId: entity, light: pointLight, index: pointIndex)
    }

    return nil
}

func getLightType(entityId: EntityID) -> String {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return "none"
    }

    if lightComponent.lightType == .directional {
        return "directional"
    } else if lightComponent.lightType == .point {
        return "point"
    }

    return "none"
}

func updateLightType(entityId: EntityID, type: LightType) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = type
}

func getSpotLights() -> [SpotLight] {
    var spotLights: [SpotLight] = []

    let lightComponentID = getComponentId(for: LightComponent.self)
    let spotLightComponentID = getComponentId(for: SpotLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID, spotLightComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entity) else {
            handleError(.noSpotLightComponent)
            continue
        }

        guard scene.get(component: LocalTransformComponent.self, for: entity) != nil else {
            handleError(.noLocalTransformComponent)
            continue
        }

        var spotLight = SpotLight()
        spotLight.direction = getLightEmissionDirection(entityId: entity)
        spotLight.position = getPosition(entityId: entity)
        spotLight.color = lightComponent.color

        let falloff = sanitizedLightFalloff(spotLightComponent.falloff)
        let radius = sanitizedLightRadius(spotLightComponent.radius)
        spotLight.attenuation = lightAttenuationUniform(
            usesRadiometricUnits: lightComponent.usesRadiometricUnits,
            falloff: falloff,
            sourceRadius: radius,
            range: spotLightComponent.range
        )
        spotLight.intensity = lightComponent.intensity
        spotLight.radius = radius

        let innerCone = simd_clamp(
            spotLightComponent.innerCone,
            minimumSpotConeAngle,
            maximumSpotConeAngle
        )
        let outerCone = simd_clamp(
            spotLightComponent.outerCone,
            minimumSpotConeAngle,
            maximumSpotConeAngle
        )
        if innerCone < outerCone {
            spotLight.innerCone = degreesToRadians(degrees: innerCone)
            spotLight.outerCone = degreesToRadians(degrees: outerCone)
        } else {
            let cones = derivedSpotConeAngles(
                coneAngle: spotLightComponent.coneAngle,
                falloff: falloff
            )
            spotLight.innerCone = degreesToRadians(degrees: cones.inner)
            spotLight.outerCone = degreesToRadians(degrees: cones.outer)
        }

        spotLights.append(spotLight)
    }

    return spotLights
}

func getShadowCastingSpotLight() -> ShadowCastingSpotLight? {
    let lightComponentID = getComponentId(for: LightComponent.self)
    let spotLightComponentID = getComponentId(for: SpotLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID, spotLightComponentID], in: scene)

    var spotIndex: Int32 = 0
    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity),
              let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entity),
              scene.get(component: LocalTransformComponent.self, for: entity) != nil
        else {
            continue
        }

        defer { spotIndex += 1 }
        guard spotLightComponent.castsShadow else { continue }

        var spotLight = SpotLight()
        spotLight.direction = getLightEmissionDirection(entityId: entity)
        spotLight.position = getPosition(entityId: entity)
        spotLight.color = lightComponent.color

        let falloff = sanitizedLightFalloff(spotLightComponent.falloff)
        let radius = sanitizedLightRadius(spotLightComponent.radius)
        spotLight.attenuation = lightAttenuationUniform(
            usesRadiometricUnits: lightComponent.usesRadiometricUnits,
            falloff: falloff,
            sourceRadius: radius,
            range: spotLightComponent.range
        )
        spotLight.intensity = lightComponent.intensity
        spotLight.radius = radius

        let innerCone = simd_clamp(spotLightComponent.innerCone, minimumSpotConeAngle, maximumSpotConeAngle)
        let outerCone = simd_clamp(spotLightComponent.outerCone, minimumSpotConeAngle, maximumSpotConeAngle)
        if innerCone < outerCone {
            spotLight.innerCone = degreesToRadians(degrees: innerCone)
            spotLight.outerCone = degreesToRadians(degrees: outerCone)
        } else {
            let cones = derivedSpotConeAngles(coneAngle: spotLightComponent.coneAngle, falloff: falloff)
            spotLight.innerCone = degreesToRadians(degrees: cones.inner)
            spotLight.outerCone = degreesToRadians(degrees: cones.outer)
        }

        return ShadowCastingSpotLight(entityId: entity, light: spotLight, index: spotIndex)
    }

    return nil
}

func getLightInnerCone(entityId: EntityID) -> Float {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return 0.0
    }

    return spotLightComponent.innerCone
}

func getLightOuterCone(entityId: EntityID) -> Float {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return 0.0
    }

    return spotLightComponent.outerCone
}

func updateLightInnerCone(entityId: EntityID, innerCone: Float) {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return
    }

    spotLightComponent.innerCone = innerCone
}

func updateLightOuterCone(entityId: EntityID, outerCone: Float) {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return
    }

    spotLightComponent.outerCone = outerCone
}

public func getLightConeAngle(entityId: EntityID) -> Float {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return 0.0
    }

    return spotLightComponent.coneAngle
}

public func updateLightConeAngle(entityId: EntityID, coneAngle: Float) {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return
    }

    spotLightComponent.coneAngle = sanitizedSpotConeAngle(coneAngle)
    syncDerivedSpotConeAngles(spotLightComponent)
}

func getAreaLights() -> [AreaLight] {
    var areaLights: [AreaLight] = []

    let lightComponentID = getComponentId(for: LightComponent.self)
    let areaLightComponentID = getComponentId(for: AreaLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID, areaLightComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entity) else {
            handleError(.noAreaLightComponent)
            continue
        }

        guard scene.get(component: LocalTransformComponent.self, for: entity) != nil else {
            handleError(.noLocalTransformComponent)
            continue
        }

        var areaLight = AreaLight()
        areaLight.position = getLocalPosition(entityId: entity)
        areaLight.color = lightComponent.color
        areaLight.intensity = lightComponent.intensity
        areaLight.forward = getLightTransformForwardAxis(entityId: entity)
        areaLight.right = getRightAxisVector(entityId: entity)
        areaLight.up = getUpAxisVector(entityId: entity)
        let (width, height, _) = getDimension(entityId: entity)
        areaLight.bounds = simd_float2(width, height)
        areaLight.twoSided = areaLightComponent.twoSided
        areaLight.range = areaLightComponent.range
        if lightComponent.usesRadiometricUnits {
            let emittingArea = max(abs(width * height), 1.0e-6)
            let emittingSides: Float = areaLight.twoSided ? 2.0 : 1.0
            areaLight.intensity = lightComponent.intensity / (Float.pi * emittingArea * emittingSides)
        }
        areaLights.append(areaLight)
    }

    appendLightPortalAreaLights(to: &areaLights)
    return areaLights
}

private func appendLightPortalAreaLights(to areaLights: inout [AreaLight]) {
    let authoredAreaLightCount = areaLights.count
    let remainingCapacity = max(maxAreaLights - areaLights.count, 0)
    let frameIndex = cullFrameIndex
    guard remainingCapacity > 0 else {
        let diagnostics = inactiveLightPortalRenderDiagnostics(
            authoredAreaLightCount: authoredAreaLightCount,
            remainingAreaLightCapacity: 0,
            fallbackReason: "No remaining area-light capacity"
        )
        setLightPortalRenderDiagnostics(diagnostics)
        return
    }
    guard hasSceneChannelLightPortalsEnabled() else {
        setLightPortalRenderDiagnostics(.empty)
        return
    }

    if let cached = LightingSystem.shared.cachedLightPortalAreaLights(
        frameIndex: frameIndex,
        authoredAreaLightCount: authoredAreaLightCount,
        remainingAreaLightCapacity: remainingCapacity
    ) {
        areaLights.append(contentsOf: cached.areaLights)
        setLightPortalRenderDiagnostics(cached.diagnostics)
        return
    }

    let proxyLights = resolveSceneLightPortalProxyLightsForActiveCamera()
    guard proxyLights.isEmpty == false else {
        let diagnostics = inactiveLightPortalRenderDiagnostics(
            authoredAreaLightCount: authoredAreaLightCount,
            remainingAreaLightCapacity: remainingCapacity,
            fallbackReason: "No active portal proxy lights"
        )
        LightingSystem.shared.setCachedLightPortalAreaLights(
            frameIndex: frameIndex,
            authoredAreaLightCount: authoredAreaLightCount,
            remainingAreaLightCapacity: remainingCapacity,
            areaLights: [],
            diagnostics: diagnostics
        )
        setLightPortalRenderDiagnostics(diagnostics)
        return
    }

    let environment = lightPortalEnvironmentIntensityScale()
    var effectiveIntensities: [Float] = []
    var portalAreaLights: [AreaLight] = []
    for proxyLight in proxyLights.prefix(remainingCapacity) {
        let effectiveIntensity = proxyLight.intensity * (proxyLight.useRealWorldTint ? environment.scale : 1.0)
        var areaLight = AreaLight()
        areaLight.position = proxyLight.position
        areaLight.color = proxyLight.useRealWorldTint ? environment.tintColor : proxyLight.color
        areaLight.intensity = effectiveIntensity
        areaLight.range = proxyLight.range
        areaLight.forward = proxyLight.forward
        areaLight.right = proxyLight.right
        areaLight.up = proxyLight.up
        areaLight.bounds = proxyLight.bounds
        areaLight.twoSided = true
        areaLight.nearSourceSuppressionRadius = lightPortalNearSourceSuppressionRadius(for: proxyLight)
        portalAreaLights.append(areaLight)
        effectiveIntensities.append(effectiveIntensity)
    }

    let totalEffectiveIntensity = effectiveIntensities.reduce(0.0, +)
    let diagnostics = LightPortalRenderDiagnostics(
        authoredAreaLightCount: authoredAreaLightCount,
        portalAreaLightCount: effectiveIntensities.count,
        remainingAreaLightCapacity: remainingCapacity,
        environmentIntensityScale: environment.scale,
        xrIntensityScale: environment.xrIntensityScale,
        environmentTintColor: environment.tintColor,
        realWorldLightingContribution: environment.realWorldLightingContribution,
        xrLightingValid: environment.xrLightingValid,
        minEffectivePortalIntensity: effectiveIntensities.min(),
        maxEffectivePortalIntensity: effectiveIntensities.max(),
        averageEffectivePortalIntensity: effectiveIntensities.isEmpty ? nil : totalEffectiveIntensity / Float(effectiveIntensities.count),
        totalEffectivePortalIntensity: totalEffectiveIntensity,
        fallbackReason: environment.fallbackReason
    )
    LightingSystem.shared.setCachedLightPortalAreaLights(
        frameIndex: frameIndex,
        authoredAreaLightCount: authoredAreaLightCount,
        remainingAreaLightCapacity: remainingCapacity,
        areaLights: portalAreaLights,
        diagnostics: diagnostics
    )
    areaLights.append(contentsOf: portalAreaLights)
    setLightPortalRenderDiagnostics(diagnostics)
}

private func inactiveLightPortalRenderDiagnostics(
    authoredAreaLightCount: Int,
    remainingAreaLightCapacity: Int,
    fallbackReason: String
) -> LightPortalRenderDiagnostics {
    LightPortalRenderDiagnostics(
        authoredAreaLightCount: authoredAreaLightCount,
        portalAreaLightCount: 0,
        remainingAreaLightCapacity: remainingAreaLightCapacity,
        environmentIntensityScale: 1.0,
        xrIntensityScale: nil,
        environmentTintColor: simd_float3(1.0, 1.0, 1.0),
        realWorldLightingContribution: RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution,
        xrLightingValid: false,
        minEffectivePortalIntensity: nil,
        maxEffectivePortalIntensity: nil,
        averageEffectivePortalIntensity: nil,
        totalEffectivePortalIntensity: 0.0,
        fallbackReason: fallbackReason
    )
}

private func lightPortalNearSourceSuppressionRadius(for proxyLight: LightPortalProxyLight) -> Float {
    let minDimension = max(min(proxyLight.bounds.x, proxyLight.bounds.y), 0.001)
    return min(
        max(
            minDimension * LightPortalLightingTuning.suppressionFractionOfMinDimension,
            LightPortalLightingTuning.minSuppressionRadius
        ),
        LightPortalLightingTuning.maxSuppressionRadius
    )
}

private func lightPortalEnvironmentIntensityScale() -> (
    scale: Float,
    xrIntensityScale: Float?,
    tintColor: simd_float3,
    realWorldLightingContribution: Float,
    xrLightingValid: Bool,
    fallbackReason: String?
) {
    let realWorldLightingContribution = RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution
    switch RuntimeEnvironmentLightingStore.shared.mode {
    case .realWorldEstimate:
        guard let xrLighting = RuntimeEnvironmentLightingStore.shared.latestXRLighting(),
              xrLighting.isValid
        else {
            return (
                scale: 0.0,
                xrIntensityScale: nil,
                tintColor: simd_float3(1.0, 1.0, 1.0),
                realWorldLightingContribution: realWorldLightingContribution,
                xrLightingValid: false,
                fallbackReason: "XR lighting unavailable for real-world portal tint"
            )
        }
        return (
            scale: xrLighting.intensityScale * realWorldLightingContribution,
            xrIntensityScale: xrLighting.intensityScale,
            tintColor: xrLighting.tintColor,
            realWorldLightingContribution: realWorldLightingContribution,
            xrLightingValid: true,
            fallbackReason: nil
        )
    case .authoredOnly, .staticIBL:
        return (
            scale: 1.0,
            xrIntensityScale: nil,
            tintColor: simd_float3(1.0, 1.0, 1.0),
            realWorldLightingContribution: realWorldLightingContribution,
            xrLightingValid: false,
            fallbackReason: "Runtime environment mode is not XR real-world lighting"
        )
    }
}

func getAreaLightCount() -> Int {
    let lightComponentID = getComponentId(for: AreaLightComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID], in: scene)

    var areaLightCount = 0

    for entity in lightEntities {
        guard scene.get(component: AreaLightComponent.self, for: entity) != nil else {
            handleError(.noAreaLightComponent)
            continue
        }

        areaLightCount += 1
    }

    return areaLightCount
}

public func handleLightScaleInput(projectedAmount: Float, axis: simd_float3) {
    if let pointLightComponent = scene.get(component: PointLightComponent.self, for: activeEntity) {
        pointLightComponent.radius = sanitizedLightRadius(pointLightComponent.radius + projectedAmount)
    }

    if let spotLightComponent = scene.get(component: SpotLightComponent.self, for: activeEntity) {
        spotLightComponent.coneAngle = sanitizedSpotConeAngle(spotLightComponent.coneAngle + projectedAmount * 10.0)
    }

    if scene.get(component: AreaLightComponent.self, for: activeEntity) != nil {
        let scale: simd_float3 = getScale(entityId: activeEntity)
        let newScale: simd_float3 = axis * projectedAmount + scale

        scaleTo(entityId: activeEntity, scale: newScale)
    }
}
