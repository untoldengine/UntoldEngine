
//
//  RegistrationSystem.swift
//  Untold Engine 
//
//  Created by Harold Serrano on 2/19/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation

public func createEntity() -> EntityID {
  return scene.newEntity()
}

public func registerComponent<T: Component>(_ entityId: EntityID, _ componentType: T.Type) {
  _ = scene.assign(to: entityId, component: componentType)
}

public func destroyEntity(_ entityID: EntityID) {

  selectedModel = false

  var r = scene.get(component: Render.self, for: entityID)
  var t = scene.get(component: Transform.self, for: entityID)
  r?.mesh = nil

  scene.remove(component: Render.self, from: entityID)
  scene.remove(component: Transform.self, from: entityID)

  r = nil
  t = nil

  if let l = scene.get(component: LightComponent.self, for: entityID) {
    lightingSystem.removeLight(entityID: entityID)
    scene.remove(component: LightComponent.self, from: entityID)

  }

  scene.destroyEntity(entityID)
}
