
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

public func createEntityWithNameAndMesh(_ name: String, _ filename:URL)->EntityID{

    let entity: EntityID = createEntityWithName(entityName: name)
    let mesh:Mesh = loadMesh(filename)

    registerComponent(entity, Render.self)
    registerComponent(entity, Transform.self)

    let r = scene.get(component: Render.self, for: entity)
    r?.mesh = mesh

    let t = scene.get(component: Transform.self, for: entity)

    if let localSpace = mesh.localSpace {
      t?.localSpace = localSpace
    }

    t?.minBox = mesh.minBox
    t?.maxBox = mesh.maxBox

    return entity
}


public func createEntityWithName(entityName name: String) -> EntityID {
  let entityId: EntityID = scene.newEntity()
  entityDictionary[name] = entityId
  reverseEntityDictionary[entityId] = name
  return entityId
}

public func queryEntityWithName(entityName name: String) -> EntityID? {
  guard let value = entityDictionary[name] else {
    handleError(.entityMissing, name)
    return nil
  }

  return value
}

public func queryEntityWithID(entityId entity: EntityID) -> String? {
  guard let value = reverseEntityDictionary[entity] else {
    handleError(.entityMissing, entity)
    return nil
  }

  return value
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

  let name: String = reverseEntityDictionary[entityID]!
  entityDictionary.removeValue(forKey: name)
  reverseEntityDictionary.removeValue(forKey: entityID)

  scene.destroyEntity(entityID)
}
