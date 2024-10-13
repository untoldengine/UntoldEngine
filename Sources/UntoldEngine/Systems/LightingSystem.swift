
//
//  Lights.swift
//  Untold Engine 
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import simd

struct LightingSystem {

  var dirLight: [EntityID: DirectionalLight] = [:]
  var pointLight: [EntityID: PointLight] = [:]
  var areaLight: [EntityID: AreaLight] = [:]
  
  var activeDirectionalLightID: EntityID?
  var activePointLightID: EntityID?
  var activeAreaLightID: EntityID?
  
  init() {

  }

  mutating func addDirectionalLight(entityID: EntityID, light: DirectionalLight) {
    activeDirectionalLightID = entityID
    dirLight[entityID] = light
  }

  mutating func addPointLight(entityID: EntityID, light: PointLight) {
    activePointLightID = entityID
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

    guard activeDirectionalLightID == entityID else { return }

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

    guard activePointLightID == entityID else { return }

    if var light = pointLight[entityID] {

      light.position = newPosition
      light.color = newColor
      light.intensity = newIntensity
      light.radius = newRadius
      pointLight[entityID] = light
    }

  }

  mutating func removeLight(entityID: EntityID) {

    if activeDirectionalLightID == entityID {
      activeDirectionalLightID = nil
    }

    if activePointLightID == entityID {
      activePointLightID = nil
    }

    dirLight.removeValue(forKey: entityID)
    pointLight.removeValue(forKey: entityID)
    //spot light goes here too
  }

  func checkCurrentEntityLightType(entityID: EntityID) {
    guard let l = scene.get(component: LightComponent.self, for: entityID) else { return }

    if case .directional(_) = l.lightType {
      lightingSystem.activeDirectionalLightID = entityID
    }

    if case .point(_) = l.lightType {
      lightingSystem.activePointLightID = entityID
    }

    if case .area(_) = l.lightType {
      lightingSystem.activeAreaLightID = entityID
    }

  }

}
