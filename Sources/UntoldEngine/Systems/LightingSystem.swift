
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

public func createDirLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: DirectionalLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    setEntityMesh(entityId: entityId, filename: "dirLightMesh", withExtension: "usdc")

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .directional

    applyAxisRotations(entityId: entityId, axis: simd_float3(-45.0, 0.0, -45.0))

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

    setEntityMesh(entityId: entityId, filename: "lightmesh", withExtension: "usdc")

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

func getDirectionalLightParameters() -> LightParameters {
    var lightDirection = simd_float3(0.0, 1.0, 0.0)
    var lightIntensity: Float = 0.0
    var lightColor = simd_float3(0.0, 0.0, 0.0)

    let lightComponentID = getComponentId(for: LightComponent.self)
    let dirLightComponentID = getComponentId(for: DirectionalLightComponent.self)
    let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

    let lightEntities = queryEntitiesWithComponentIds([lightComponentID, dirLightComponentID, localTransformComponentID], in: scene)

    for entity in lightEntities {
        guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
            handleError(.noLightComponent)
            continue
        }

        guard scene.get(component: DirectionalLightComponent.self, for: entity) != nil else {
            handleError(.noDirLightComponent)
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

func getLightAttenuation(entityId: EntityID) -> simd_float3 {
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

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }

        pointLightComponent.radius = radius

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }

        spotLightComponent.radius = radius
    }
}

func getLightRadius(entityId: EntityID) -> Float {
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

func getPointLightCount() -> Int {
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
        pointLight.position = getLocalPosition(entityId: entity)
        pointLight.color = lightComponent.color
        pointLight.attenuation = pointLightComponent.attenuation
        pointLight.intensity = lightComponent.intensity
        pointLight.radius = pointLightComponent.radius

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
