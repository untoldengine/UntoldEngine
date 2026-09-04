//
//  LightingSystemAPI.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// MARK: - Light sub-domain enums

public enum DirectionalLightSetting: Sendable {
    case active
    case castsShadow(Bool)
}

public enum PointLightProperty: Sendable {
    /// Physical emitter radius; independent from influence range.
    case radius(Float)
    /// Optional smooth influence cutoff. Zero disables the authored cutoff.
    case range(Float)
    case falloff(Float)
    case attenuation(simd_float3)
    case castsShadow(Bool)
}

public enum SpotLightProperty: Sendable {
    case coneAngle(Float)
    case falloff(Float)
    case radius(Float)
    case range(Float)
    case attenuation(simd_float3)
    case castsShadow(Bool)
}

public enum AreaLightProperty: Sendable {
    case twoSided(Bool)
    case range(Float)
    case castsShadow(Bool)
}

public enum LightIntensityUnits: Sendable, Equatable {
    case legacy
    /// Point, spot, and area intensity is radiant power in watts; sun
    /// intensity is irradiance in W/m².
    case radiometric
}

// MARK: - Top-level light property enum

public enum LightEntityProperty: Sendable {
    case color(simd_float3)
    /// Convenience alias for radiometric local-light power in watts.
    /// Equivalent to `.intensity(value)` plus `.intensityUnits(.radiometric)`.
    /// For directional/sun lights, use `.strength(value)` instead.
    case power(Float)
    /// Convenience alias for radiometric directional/sun-light strength in
    /// watts per square meter (irradiance), matching Blender's Sun "Strength".
    /// Equivalent to `.intensity(value)` plus `.intensityUnits(.radiometric)`.
    case strength(Float)
    case intensity(Float)
    case intensityUnits(LightIntensityUnits)
    case directional(DirectionalLightSetting)
    case point(PointLightProperty)
    case spot(SpotLightProperty)
    case area(AreaLightProperty)
}

// MARK: - Facade

public func setLight(entityId: EntityID, _ property: LightEntityProperty) {
    switch property {
    case let .color(value):
        updateLightColor(entityId: entityId, color: value)
    case let .power(value):
        setRadiometricIntensity(entityId: entityId, value: value)
    case let .strength(value):
        setRadiometricIntensity(entityId: entityId, value: value)
    case let .intensity(value):
        updateLightIntensity(entityId: entityId, intensity: value)
    case let .intensityUnits(units):
        guard let light = scene.get(component: LightComponent.self, for: entityId) else {
            handleError(.noLightComponent)
            return
        }
        light.usesRadiometricUnits = units == .radiometric
    case let .directional(setting):
        applyDirectionalLightSetting(entityId: entityId, setting)
    case let .point(pointProperty):
        applyPointLightProperty(entityId: entityId, pointProperty)
    case let .spot(spotProperty):
        applySpotLightProperty(entityId: entityId, spotProperty)
    case let .area(areaProperty):
        applyAreaLightProperty(entityId: entityId, areaProperty)
    }
}

// MARK: - Private applicators

private func setRadiometricIntensity(entityId: EntityID, value: Float) {
    updateLightIntensity(entityId: entityId, intensity: value)
    guard let light = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }
    light.usesRadiometricUnits = true
}

private func applyDirectionalLightSetting(entityId: EntityID, _ setting: DirectionalLightSetting) {
    switch setting {
    case .active:
        guard hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self) else {
            Logger.logWarning(message: "[LightingSystem] Cannot set active directional light. Entity \(entityId) has no DirectionalLightComponent.")
            return
        }
        LightingSystem.shared.activeDirectionalLight = entityId
    case let .castsShadow(value):
        guard let light = scene.get(component: DirectionalLightComponent.self, for: entityId) else {
            handleError(.noDirLightComponent)
            return
        }
        light.castsShadow = value
    }
}

private func applyPointLightProperty(entityId: EntityID, _ property: PointLightProperty) {
    switch property {
    case let .radius(value):
        updateLightRadius(entityId: entityId, radius: value)
    case let .range(value):
        guard let light = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }
        light.range = max(value, 0.0)
    case let .falloff(value):
        updateLightFalloff(entityId: entityId, falloff: value)
    case let .attenuation(value):
        updateLightAttenuation(entityId: entityId, attenuation: value)
    case let .castsShadow(value):
        updatePointLightCastsShadow(entityId: entityId, castsShadow: value)
    }
}

private func applySpotLightProperty(entityId: EntityID, _ property: SpotLightProperty) {
    switch property {
    case let .coneAngle(value):
        updateLightConeAngle(entityId: entityId, coneAngle: value)
    case let .falloff(value):
        updateLightFalloff(entityId: entityId, falloff: value)
    case let .radius(value):
        updateLightRadius(entityId: entityId, radius: value)
    case let .range(value):
        guard let light = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }
        light.range = max(value, 0.0)
    case let .attenuation(value):
        updateLightAttenuation(entityId: entityId, attenuation: value)
    case let .castsShadow(value):
        updateSpotLightCastsShadow(entityId: entityId, castsShadow: value)
    }
}

private func applyAreaLightProperty(entityId: EntityID, _ property: AreaLightProperty) {
    switch property {
    case let .twoSided(value):
        guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
            handleError(.noAreaLightComponent)
            return
        }
        areaLightComponent.twoSided = value
    case let .range(value):
        guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
            handleError(.noAreaLightComponent)
            return
        }
        areaLightComponent.range = max(value, 0.0)
    case let .castsShadow(value):
        guard let areaLightComponent = scene.get(component: AreaLightComponent.self, for: entityId) else {
            handleError(.noAreaLightComponent)
            return
        }
        areaLightComponent.castsShadow = value
    }
}
