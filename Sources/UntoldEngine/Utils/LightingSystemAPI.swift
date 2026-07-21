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
}

public enum PointLightProperty: Sendable {
    case radius(Float)
    case falloff(Float)
    case attenuation(simd_float3)
    case castsShadow(Bool)
}

public enum SpotLightProperty: Sendable {
    case coneAngle(Float)
    case falloff(Float)
    case radius(Float)
    case attenuation(simd_float3)
    case castsShadow(Bool)
}

public enum AreaLightProperty: Sendable {
    case twoSided(Bool)
}

// MARK: - Top-level light property enum

public enum LightEntityProperty: Sendable {
    case color(simd_float3)
    case intensity(Float)
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
    case let .intensity(value):
        updateLightIntensity(entityId: entityId, intensity: value)
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

private func applyDirectionalLightSetting(entityId: EntityID, _ setting: DirectionalLightSetting) {
    switch setting {
    case .active:
        guard hasComponent(entityId: entityId, componentType: DirectionalLightComponent.self) else {
            Logger.logWarning(message: "[LightingSystem] Cannot set active directional light. Entity \(entityId) has no DirectionalLightComponent.")
            return
        }
        LightingSystem.shared.activeDirectionalLight = entityId
    }
}

private func applyPointLightProperty(entityId: EntityID, _ property: PointLightProperty) {
    switch property {
    case let .radius(value):
        updateLightRadius(entityId: entityId, radius: value)
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
    }
}
