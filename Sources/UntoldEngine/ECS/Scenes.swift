
//
//  Scenes.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation

public struct EntityDesc {
    var entityId: EntityID
    var mask: ComponentMask
    var freed: Bool = false
}

public struct Scene {
    public mutating func remove<T: Component>(component _: T.Type, from entityId: EntityID) {
        let entityIndex = getEntityIndex(entityId)
        guard entities[Int(entityIndex)].entityId == entityId else {
            handleError(.entityMissing)
            return
        }

        let componentId = getComponentId(for: T.self)
        entities[Int(entityIndex)].mask.reset(componentId)
    }

    public mutating func destroyEntity(_ entityId: EntityID) {
        let entityIndex = getEntityIndex(entityId)
        guard entities[Int(entityIndex)].entityId == entityId else {
            handleError(.entityMissing)
            return
        }
        let newId = createEntityId(EntityIndex(UInt32.max), getEntityVersion(entityId) + 1)
        entities[Int(entityIndex)].entityId = newId
        entities[Int(entityIndex)].mask.reset()
        entities[Int(entityIndex)].freed = true
        freeEntities.append(entityIndex)
    }

    public mutating func newEntity() -> EntityID {
        if let newIndex = freeEntities.popLast() {
            let newId = createEntityId(newIndex, getEntityVersion(entities[Int(newIndex)].entityId))
            entities[Int(newIndex)].entityId = newId
            entities[Int(newIndex)].freed = false
            return newId
        } else {
            let entityIndex = EntityIndex(UInt32(entities.count))
            let newEntity = EntityDesc(entityId: createEntityId(entityIndex, 0), mask: ComponentMask())
            entities.append(newEntity)
            return newEntity.entityId
        }
    }

    /* explicitly specify type*/
    public mutating func assign<T: Component>(to entityId: EntityID, component _: T.Type) -> T? {
        let componentId = getComponentId(for: T.self)
        let entityIndex = getEntityIndex(entityId)

        guard entities[Int(entityIndex)].entityId == entityId else {
            handleError(.entityMissing)
            return nil
        }

        // Ensure the pool for this component type exists
        if componentPool[componentId] == nil {
            componentPool[componentId] = ComponentPool(MemoryLayout<T>.stride)
        }

        // Retrieve the specific component pool
        guard let pool = componentPool[componentId] else {
            handleError(.componentNotFound)
            return nil
        }

        // Allocate and initialize a new component in the pool
        guard let componentPointer = pool.get(Int(entityIndex)) else {
            handleError(.failedToGetComponentPointer)
            return nil
        }

        let typedPointer = componentPointer.bindMemory(to: T.self, capacity: 1)
        typedPointer.initialize(to: T())

        // Set the bit for this component to true
        entities[Int(entityIndex)].mask.set(componentId)

        return typedPointer.pointee
    }

    public func get<T: Component>(component _: T.Type, for entityId: EntityID) -> T? {
        let componentId = getComponentId(for: T.self)
        let entityIndex = getEntityIndex(entityId)

        if entities.count == 0 {
            handleError(.noentitiesinscene)
            return nil
        }

        guard entities[Int(entityIndex)].entityId == entityId else {
            handleError(.entityMissing)
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
    
    func getAllEntities()->[EntityID]{
        
        return entities.compactMap { entityDesc in
            entityDesc.freed ? nil : entityDesc.entityId
        }
    }
    

    // data
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
    }.map { $0.entityId }
}
