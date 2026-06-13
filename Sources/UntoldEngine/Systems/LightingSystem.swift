
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

private func applyDefaultLightOrientation(entityId: EntityID) {
    // Light shaders/systems assume local forward points along +Y by default.
    // Rotate +Z-forward entities (identity rotation) into +Y-forward.
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

private func sanitizedSpotConeAngle(_ coneAngle: Float) -> Float {
    simd_clamp(coneAngle, minimumSpotConeAngle, maximumSpotConeAngle)
}

public func createDirLight(entityId: EntityID) {
    registerComponent(entityId: entityId, componentType: LightComponent.self)
    registerComponent(entityId: entityId, componentType: DirectionalLightComponent.self)
    registerTransformComponent(entityId: entityId)
    registerSceneGraphComponent(entityId: entityId)

    assignDefaultProceduralLightMesh(entityId: entityId)
    applyDefaultLightOrientation(entityId: entityId)

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
        pointLight.position = getLocalPosition(entityId: entity)
        pointLight.color = lightComponent.color

        let falloff = sanitizedLightFalloff(pointLightComponent.falloff)
        let radius = sanitizedLightRadius(pointLightComponent.radius)
        let linear: Float = simd_mix(0.1, 0.0, falloff)
        let quadratic: Float = simd_mix(0.0, 1.0 / (radius * radius), falloff)
        let constant: Float = 1.0

        pointLight.attenuation = simd_float4(constant, linear, quadratic, 0.0)
        pointLight.intensity = lightComponent.intensity
        pointLight.radius = radius

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

        let falloff = sanitizedLightFalloff(spotLightComponent.falloff)
        let radius = sanitizedLightRadius(spotLightComponent.radius)
        let linear: Float = simd_mix(0.1, 0.0, falloff)
        let quadratic: Float = simd_mix(0.0, 1.0 / (radius * radius), falloff)
        let constant: Float = 1.0

        spotLight.attenuation = simd_float4(constant, linear, quadratic, 0.0)
        spotLight.intensity = lightComponent.intensity

        let coneAngle = sanitizedSpotConeAngle(spotLightComponent.coneAngle)
        spotLight.outerCone = degreesToRadians(degrees: coneAngle)
        let requestedEdgeSoftness = simd_mix(1.0, 10.0, falloff) // values 1 and 10 are emperically chosen. You can tweek these values
        let edgeSoftness = min(requestedEdgeSoftness, max(minimumSpotConeSeparation, coneAngle - minimumSpotConeSeparation))
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
