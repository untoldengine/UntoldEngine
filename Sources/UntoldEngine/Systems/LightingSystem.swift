
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
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // constant, linera, quadratic -> (x, y, z, max range)
    var position: simd_float3 = .init(0.0, 1.0, 0.0)
    var color: simd_float3 = .init(1.0, 0.0, 0.0)
    var intensity: Float = 1.0
    var radius: Float = 1.0
}

public struct SpotLight {
    var attenuation: simd_float4 = .init(1.0, 0.7, 1.8, 0.0) // constant, linera, quadratic -> (x, y, z, max range)
    var direction: simd_float3 = .init(1.0, 1.0, 1.0)
    var position: simd_float3 = .init(0.0, 1.0, 0.0)
    var color: simd_float3 = .init(1.0, 0.0, 0.0)
    var intensity: Float = 1.0
    var innerCone: Float = 0.0
    var outerCone: Float = 0.0
}

public struct AreaLight {
    var position: simd_float3 = .init(0.0, 0.0, 0.0) // Center position of the area light
    var color: simd_float3 = .init(1.0, 1.0, 1.0) // Light color
    var forward: simd_float3 = .init(0.0, 0.0, -1.0) // Normal vector of the light's surface
    var right: simd_float3 = .init(1.0, 0.0, 0.0) // Right vector defining the surface orientation
    var up: simd_float3 = .init(0.0, 1.0, 0.0) // Up vector defining the surface orientation
    var bounds: simd_float2 = .one
    var intensity: Float = 1.0 // Light intensity
    var twoSided: Bool = false // Whether the light emits from both sides
}

public func createDirLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: LightDebugComponent.self)
    registerComponent(entityId: entityId, componentType: DirectionalLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    setEntityMesh(entityId: entityId, filename: "dir_light_debug_mesh", withExtension: "usdc")

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .directional

    do {
        let texture = try loadTexture(device: renderInfo.device, textureName: "directional_light_icon_256x256", withExtension: "png")

        lightComponent.texture.directional = texture

    } catch {
        handleError(.textureMissing)
    }
}

public func createPointLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: LightDebugComponent.self)
    registerComponent(entityId: entityId, componentType: PointLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    setEntityMesh(entityId: entityId, filename: "point_light_debug_mesh", withExtension: "usdc")

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
    registerComponent(entityId: entityId, componentType: LightDebugComponent.self)
    registerComponent(entityId: entityId, componentType: SpotLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    setEntityMesh(entityId: entityId, filename: "spot_light_debug_mesh", withExtension: "usdc")

    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    lightComponent.lightType = .spotlight
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

    setEntityMesh(entityId: entityId, filename: "area_light_debug_mesh", withExtension: "usdc")

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

        let forward = getForwardAxisVector(entityId: entity)
        lightDirection = simd_float3(forward.x, forward.y, forward.z)
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

func getLightFalloff(entityId: EntityID) -> Float {
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

func updateLightFalloff(entityId: EntityID, falloff: Float) {
    guard let lightComponent = scene.get(component: LightComponent.self, for: entityId) else {
        handleError(.noLightComponent)
        return
    }

    if lightComponent.lightType == .point {
        guard let pointLightComponent = scene.get(component: PointLightComponent.self, for: entityId) else {
            handleError(.noPointLightComponent)
            return
        }

        pointLightComponent.falloff = falloff

    } else if lightComponent.lightType == .spotlight {
        guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
            handleError(.noSpotLightComponent)
            return
        }

        spotLightComponent.falloff = falloff
    }
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

func getSpotLightCount() -> Int {
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
        pointLight.position = getLocalPosition(entityId: entity)
        pointLight.color = lightComponent.color

        let linear: Float = simd_mix(0.1, 0.0, pointLightComponent.falloff)
        let quadratic: Float = simd_mix(0.0, 1.0 / (pointLightComponent.radius * pointLightComponent.radius), pointLightComponent.falloff)
        let constant: Float = 1.0

        pointLight.attenuation = simd_float4(constant, linear, quadratic, 0.0)
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

        // get orientation
        let forward = getForwardAxisVector(entityId: entity) * -1.0
        var spotLight = SpotLight()
        spotLight.direction = simd_float3(forward.x, forward.y, forward.z)
        spotLight.position = getLocalPosition(entityId: entity)
        spotLight.color = lightComponent.color

        let linear: Float = simd_mix(0.1, 0.0, spotLightComponent.falloff)
        let quadratic: Float = simd_mix(0.0, 1.0 / (spotLightComponent.radius * spotLightComponent.radius), spotLightComponent.falloff)
        let constant: Float = 1.0

        spotLight.attenuation = simd_float4(constant, linear, quadratic, 0.0)
        spotLight.intensity = lightComponent.intensity

        spotLight.outerCone = degreesToRadians(degrees: spotLightComponent.coneAngle)
        let edgeSoftness = simd_mix(1.0, 10.0, spotLightComponent.falloff) // values 1 and 10 are emperically chosen. You can tweek these values
        spotLight.innerCone = spotLight.outerCone - degreesToRadians(degrees: edgeSoftness)

        spotLights.append(spotLight)
    }

    return spotLights
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

func getLightConeAngle(entityId: EntityID) -> Float {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return 0.0
    }

    return spotLightComponent.coneAngle
}

func updateLightConeAngle(entityId: EntityID, coneAngle: Float) {
    guard let spotLightComponent = scene.get(component: SpotLightComponent.self, for: entityId) else {
        handleError(.noSpotLightComponent)
        return
    }

    spotLightComponent.coneAngle = coneAngle
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
        areaLight.forward = getForwardAxisVector(entityId: entity)
        areaLight.right = getRightAxisVector(entityId: entity)
        areaLight.up = getUpAxisVector(entityId: entity)
        let (width, height, _) = getDimension(entityId: entity)
        areaLight.bounds = simd_float2(width, height)
        areaLight.twoSided = areaLightComponent.twoSided
        areaLights.append(areaLight)
    }

    return areaLights
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

func handleLightScaleInput(projectedAmount: Float, axis: simd_float3) {
    if let pointLightComponent = scene.get(component: PointLightComponent.self, for: activeEntity) {
        pointLightComponent.radius += projectedAmount
    }

    if let spotLightComponent = scene.get(component: SpotLightComponent.self, for: activeEntity) {
        spotLightComponent.coneAngle += projectedAmount * 10.0
    }

    if scene.get(component: AreaLightComponent.self, for: activeEntity) != nil {
        let scale: simd_float3 = getScale(entityId: activeEntity)
        let newScale: simd_float3 = axis * projectedAmount + scale

        scaleTo(entityId: activeEntity, scale: newScale)
    }
}
