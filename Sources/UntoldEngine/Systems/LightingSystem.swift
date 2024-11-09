
//
//  LightingSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import simd

public struct DirectionalLight {
    public var direction: simd_float3 = .init(1.0, 1.0, 1.0)
    public var color: simd_float3 = .init(1.0, 1.0, 1.0)
    public var intensity: Float = 1.0

    public init() {}
}

public struct PointLight {
    public var position: simd_float3 = .init(0.0, 1.0, 0.0)
    public var color: simd_float3 = .init(1.0, 0.0, 0.0)
    public var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // constant, linera, quadratic -> (x, y, z, max range)
    public var intensity: Float = 1.0
    public var radius: Float = 1.0

    public init() {}
}

public struct AreaLight {
    var position: simd_float3 = .init(0.0, 0.0, 0.0) // Center position of the area light
    var color: simd_float3 = .init(1.0, 1.0, 1.0) // Light color
    var intensity: Float = 1.0 // Light intensity
    //    var width: Float = 1.0                                   // Width of the area light
    //    var height: Float = 1.0                                  // Height of the area light
    //    var forward: simd_float3 = simd_float3(0.0, -1.0, 0.0)    // Normal vector of the light's surface
    //    var right: simd_float3 = simd_float3(1.0, 0.0, 0.0)      // Right vector defining the surface orientation
    //    var up: simd_float3 = simd_float3(0.0, 0.0, 1.0)         // Up vector defining the surface orientation
    // var twoSided: Bool = false                               // Whether the light emits from both sides
}

public struct LightingSystem {
    var dirLight: [EntityID: DirectionalLight] = [:]
    var pointLight: [EntityID: PointLight] = [:]
    var areaLight: [EntityID: AreaLight] = [:]

    var activeAreaLightID: EntityID?

    init() {}

    public mutating func addDirectionalLight(entityID: EntityID, light: DirectionalLight) {
        dirLight[entityID] = light
    }

    public mutating func addPointLight(entityID: EntityID, light: PointLight) {
        pointLight[entityID] = light
    }

    mutating func addAreaLight(entityID: EntityID, light: AreaLight) {
        activeAreaLightID = entityID
        areaLight[entityID] = light
    }

    func getDirectionalLight(entityID: EntityID) -> DirectionalLight? {
        return dirLight[entityID]
    }

    func getPointLight(entityID: EntityID) -> PointLight? {
        return pointLight[entityID]
    }

    func getAreaLight(entityID: EntityID) -> AreaLight? {
        return areaLight[entityID]
    }

    mutating func updateDirectionalLight(
        entityID: EntityID, newDirection: simd_float3, newColor: simd_float3, newIntensity: Float
    ) {
        if var light = dirLight[entityID] {
            light.direction = newDirection
            light.color = newColor
            light.intensity = newIntensity
            dirLight[entityID] = light
        }
    }

    mutating func updatePointLight(
        entityID: EntityID, newPosition: simd_float3, newColor: simd_float3, newIntensity: Float,
        newRadius: Float
    ) {
        if var light = pointLight[entityID] {
            light.position = newPosition
            light.color = newColor
            light.intensity = newIntensity
            light.radius = newRadius
            pointLight[entityID] = light
        }
    }

    mutating func removeLight(entityID: EntityID) {
        dirLight.removeValue(forKey: entityID)
        pointLight.removeValue(forKey: entityID)
        // spot light goes here too
    }

    func checkCurrentEntityLightType(entityID: EntityID) {
        guard let l = scene.get(component: LightComponent.self, for: entityID) else { return }

        if case .directional = l.lightType {
//      lightingSystem.activeDirectionalLightID = entityID
        }

        if case .point = l.lightType {
            //     lightingSystem.activePointLightID = entityID
        }

        if case .area = l.lightType {
            lightingSystem.activeAreaLightID = entityID
        }
    }
}
