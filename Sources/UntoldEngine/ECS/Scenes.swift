
//
//  Scene.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

public struct EntityDesc {
  var index: EntityID
  var mask: ComponentMask
  var freed: Bool = false
}

public struct Scene {

  mutating public func remove<T: Component>(component type: T.Type, from index: EntityID) {
    let entityIndex = getEntityIndex(index)
    guard entities[Int(entityIndex)].index == index else { return }

    let componentId = getComponentId(for: T.self)
    entities[Int(entityIndex)].mask.reset(componentId)
  }

  mutating public func destroyEntity(_ index: EntityID) {
    let entityIndex = getEntityIndex(index)
    let newId = createEntityId(EntityIndex(UInt32.max), getEntityVersion(index) + 1)
    entities[Int(entityIndex)].index = newId
    entities[Int(entityIndex)].mask.reset()
    entities[Int(entityIndex)].freed = true
    freeEntities.append(entityIndex)
  }

  mutating public func newEntity() -> EntityID {
    if let newIndex = freeEntities.popLast() {
      let newId = createEntityId(newIndex, getEntityVersion(entities[Int(newIndex)].index))
      entities[Int(newIndex)].index = newId
      entities[Int(newIndex)].freed = false
      return newId
    } else {
      let entityIndex = EntityIndex(UInt32(entities.count))
      let newEntity = EntityDesc(index: createEntityId(entityIndex, 0), mask: ComponentMask())
      entities.append(newEntity)
      return newEntity.index
    }
  }

  /* explicitly specify type*/
  mutating public func assign<T: Component>(to id: EntityID, component type: T.Type) -> T {
    let componentId = getComponentId(for: T.self)
    let entityIndex = getEntityIndex(id)

    // Ensure the pool for this component type exists
    if componentPool[componentId] == nil {
      componentPool[componentId] = ComponentPool(MemoryLayout<T>.stride)
    }

    // Retrieve the specific component pool
    guard let pool = componentPool[componentId] else {
      fatalError("Component pool for type \(T.self) could not be found.")
    }

    // Allocate and initialize a new component in the pool
    guard let componentPointer = pool.get(Int(entityIndex)) else {
      fatalError("Failed to get component pointer from pool")
    }

    let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
    typedPointer.initialize(to: T())

    // Set the bit for this component to true
    entities[Int(entityIndex)].mask.set(componentId)

    return typedPointer.pointee
  }

  public func get<T: Component>(component type: T.Type, for index: EntityID) -> T? {
    let componentId = getComponentId(for: T.self)
    let entityIndex = getEntityIndex(index)

    if entities.count == 0 {
      return nil
    }
    // Check if the entity has this component
    guard entities[Int(entityIndex)].mask.test(componentId) else {
      return nil
    }

    // Retrieve the specific component pool
    guard let pool = componentPool[componentId] else {
      return nil
    }

    // Get the component from the pool
    if let componentPointer = pool.get(Int(entityIndex)) {
      let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
      return typedPointer.pointee
    }

    return nil
  }

  //data
  var componentPool: [Int: ComponentPool] = [:]
  var entities: [EntityDesc] = []
  var freeEntities: [EntityIndex] = []
}

func createComponentMask(for components: [Int]) -> ComponentMask {
    var mask = ComponentMask()
    for componentId in components {
        mask.set(componentId)
    }
    return mask
}

func queryEntitiesWithComponentIds(_ componentTypes: [Int], in scene: Scene) -> [EntityID] {
    let requiredMask = createComponentMask(for: componentTypes)
    return scene.entities.filter { entity in
        // Use bitwise AND to check if the entity has all required components
        entity.mask.contains(requiredMask)
    }.map { $0.index }
}

