
//
//  LightingSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 5/29/23.
//

import CShaderTypes
import Foundation
import simd

public struct DirectionalLight {
    var direction: simd_float3 = .init(1.0, 1.0, 1.0)
    var color: simd_float3 = .init(1.0, 1.0, 1.0)
    var intensity: Float = 1.0
}

public struct PointLight {
    var position: simd_float3 = .init(0.0, 1.0, 0.0)
    var color: simd_float3 = .init(1.0, 0.0, 0.0)
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // constant, linera, quadratic -> (x, y, z, max range)
    var intensity: Float = 1.0
    var radius: Float = 1.0
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

public func createLight(entityId: EntityID, lightType: LightType) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    setEntityMesh(entityId: entityId, filename: "dirLightMesh", withExtension: "usdc")

    guard let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent)
        return
    }

    localTransform.boundingBox.min = simd_float3(repeating: -0.1)
    localTransform.boundingBox.max = simd_float3(repeating: 0.1)

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    if lightType == .directional {
        applyAxisRotations(entityId: entityId, axis: simd_float3(45.0, 45.0, 45.0))
    }

    ["directional": "directional_light_icon_256x256",
     "point": "point_light_icon_256x256"]
        .forEach { type, name in
            do {
                let texture = try loadTexture(device: renderInfo.device, textureName: name, withExtension: "png")
                switch type {
                case "directional":
                    lightComponent.texture.directional = texture
                case "point":
                    lightComponent.texture.point = texture
                default:
                    break
                }
            } catch {
                handleError(.textureMissing)
            }
        }

    lightComponent.lightType = lightType
}

public func createLight(entityId: EntityID, lightType: String) {
    var type: LightType = .directional

    if lightType == "directional" {
        type = .directional
    } else if lightType == "point" {
        type = .point
    } else if lightType == "area" {
        type = .area
    }

    createLight(entityId: entityId, lightType: type)
}

func getLightParameters() -> LightParameters {
    var lightDirection = simd_float3(0.0, 1.0, 0.0)
    var lightIntensity: Float = 0.0
    var lightColor = simd_float3(0.0, 0.0, 0.0)

    let lightComponentID = getComponentId(for: LightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        if lightComponent.lightType != .directional {
            continue
        }

        let orientationEuler = getLocalOrientationEuler(entityId: entity)
        let orientation = simd_float3(orientationEuler.pitch, orientationEuler.yaw, orientationEuler.roll)

        lightDirection = orientation
        lightIntensity = lightComponent.intensity
        lightColor = lightComponent.color
    }

    var lightParameter = LightParameters()
    lightParameter.direction = lightDirection
    lightParameter.intensity = lightIntensity
    lightParameter.color = lightColor

    return lightParameter
}

func updateLightColor(entityId: EntityID, color: simd_float3) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.color = color
}

func getLightColor(entityId: EntityID) -> simd_float3 {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return .zero
    }

    return lightComponent.color
}

func updateLightAttenuation(entityId: EntityID, attenuation: simd_float3) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.attenuation = simd_float4(attenuation.x, attenuation.y, attenuation.z, 0.0)
}

func getLightAttenuation(entityId: EntityID) -> simd_float3 {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return .zero
    }

    return simd_float3(lightComponent.attenuation.x, lightComponent.attenuation.y, lightComponent.attenuation.z)
}

func updateLightIntensity(entityId: EntityID, intensity: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.intensity = intensity
}

func getLightIntensity(entityId: EntityID) -> Float {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return 0.0
    }

    return lightComponent.intensity
}

func updateLightRadius(entityId: EntityID, radius: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.radius = radius
}

func getLightRadius(entityId: EntityID) -> Float {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return 0.0
    }

    return lightComponent.radius
}

func getPointLightCount() -> Int {
    let lightComponentID = getComponentId(for: LightComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID], in: scene)

    var pointCount = 0

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        if lightComponent.lightType != .point {
            continue
        }

        pointCount += 1
    }

    return pointCount
}

func getPointLights() -> [PointLight] {
    var pointLights: [PointLight] = []

    let lightComponentID = getComponentId(for: LightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entity) else {
            handleError(.noLocalTransformComponent)
            continue
        }

        if lightComponent.lightType != .point {
            continue
        }

        var pointLight = PointLight()
        pointLight.position = getLocalPosition(entityId: entity)
        pointLight.color = lightComponent.color
        pointLight.attenuation = lightComponent.attenuation
        pointLight.intensity = lightComponent.intensity
        pointLight.radius = lightComponent.radius

        pointLights.append(pointLight)
    }

    return pointLights
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
