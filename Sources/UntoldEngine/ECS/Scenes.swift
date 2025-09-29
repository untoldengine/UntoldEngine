
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
    var pendingDestroy: Bool = false
}

public struct Scene {
    func exists(_ id: EntityID) -> Bool {
        let idx = getEntityIndex(id)
        guard idx < entities.count else { return false }
        let e = entities[Int(idx)]
        return e.entityId == id && !e.freed && !e.pendingDestroy
    }

    public mutating func remove<T: Component>(component _: T.Type, from entityId: EntityID) {
        let entityIndex = getEntityIndex(entityId)
        let e = entities[Int(entityIndex)]

        guard e.entityId == entityId, !e.freed else {
            handleError(.entityMissing, entityId)
            return
        }

        let componentId = getComponentId(for: T.self)
        entities[Int(entityIndex)].mask.reset(componentId)
    }

    // Phase A: mark entity for destroy
    public mutating func markDestroy(_ entityId: EntityID) {
        let idx = getEntityIndex(entityId)
        guard entities[Int(idx)].entityId == entityId, !entities[Int(idx)].freed else {
            return
        }
        entities[Int(idx)].pendingDestroy = true
    }

    public mutating func markDestroyAll() {
        for e in getAllEntities() {
            markDestroy(e)
        }
    }

    // Phase B: Finalizze (call one per frame)
    public mutating func finalizePendingDestroys() {
        for i in entities.indices {
            if entities[i].pendingDestroy, !entities[i].freed {
                destroyEntityFinalize(at: i)
            }
        }
    }

    private mutating func destroyEntityFinalize(at entityIndexInt: Int) {
        let oldId = entities[entityIndexInt].entityId
        let idx = getEntityIndex(oldId)
        let newVersion = getEntityVersion(oldId) &+ 1
        let tombstone = createEntityId(idx, newVersion)
        entities[entityIndexInt].entityId = tombstone
        entities[entityIndexInt].mask.resetAll()
        entities[entityIndexInt].pendingDestroy = false
        entities[entityIndexInt].freed = true
        freeEntities.append(idx)
    }

    public mutating func newEntity() -> EntityID {
        if let newIndex = freeEntities.popLast() {
            let newId = createEntityId(newIndex, getEntityVersion(entities[Int(newIndex)].entityId))
            entities[Int(newIndex)].entityId = newId
            entities[Int(newIndex)].freed = false
            entities[Int(newIndex)].pendingDestroy = false
            entities[Int(newIndex)].mask.resetAll()
            return newId
        } else {
            let entityIndex = EntityIndex(UInt32(entities.count))
            let newEntity = EntityDesc(entityId: createEntityId(entityIndex, 0), mask: ComponentMask(), freed: false, pendingDestroy: false)
            entities.append(newEntity)
            return newEntity.entityId
        }
    }

    /* explicitly specify type*/
    public mutating func assign<T: Component>(to entityId: EntityID, component _: T.Type) -> T? {
        let componentId = getComponentId(for: T.self)
        let entityIndex = getEntityIndex(entityId)
        let e = entities[Int(entityIndex)]
        guard e.entityId == entityId, !e.freed, !e.pendingDestroy else {
            handleError(.entityMissing, entityId)
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

        let e = entities[Int(entityIndex)]
        guard e.entityId == entityId, !e.freed else {
            handleError(.entityMissing, entityId)
            return nil
        }

        guard e.mask.test(componentId) else {
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

    func getAllEntities() -> [EntityID] {
        entities.compactMap { entityDesc in
            entityDesc.freed || entityDesc.pendingDestroy ? nil : entityDesc.entityId
        }
    }

    func mask(for entityId: EntityID) -> ComponentMask? {
        let idx = getEntityIndex(entityId)
        let e = entities[Int(idx)]
        guard e.entityId == entityId, !e.freed, !e.pendingDestroy else { return nil }
        return e.mask
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

public func queryEntitiesWithComponentIds(_ componentTypes: [Int], in scene: Scene) -> [EntityID] {
    let requiredMask = createComponentMask(for: componentTypes)

    var out: [EntityID] = []
    out.reserveCapacity(64)

    for id in scene.getAllEntities() { // already excludes freed
        if let mask = scene.mask(for: id),
           mask.contains(requiredMask)
        {
            out.append(id)
        }
    }
    return out
}

public func hasComponent(entityId: EntityID, componentType: (some Any).Type) -> Bool {
    let entityIndex: EntityIndex = getEntityIndex(entityId)

    let entityMask = scene.entities[Int(entityIndex)].mask

    let componentId = getComponentId(for: componentType)

    return entityMask.test(componentId)
}

func getAllEntityComponentsTypes(entityId: EntityID) -> [Any.Type] {
    let entityIndex: EntityIndex = getEntityIndex(entityId)
    let entityMask = scene.entities[Int(entityIndex)].mask

    var components: [Any.Type] = []

    for (_, typeInfo) in componentIDs {
        let componentId = typeInfo.id

        // check if the entity's mask includes this component
        if entityMask.test(componentId) {
            components.append(typeInfo.type)
        }
    }

    return components
}

public func getAllEntityComponentsIds(entityId: EntityID) -> [Int] {
    var componentIdsArray: [Int] = []

    let componentTypes: [Any.Type] = getAllEntityComponentsTypes(entityId: entityId)

    for componentType in componentTypes {
        let typeId = ObjectIdentifier(componentType)

        if let typeInfo = componentIDs[typeId] {
            componentIdsArray.append(typeInfo.id)
        }
    }

    return componentIdsArray
}

// Custom System registry
var customSystems: [(Float) -> Void] = []

public func registerCustomSystem(_ system: @escaping (Float) -> Void) {
    customSystems.append(system)
}

public func updateCustomSystems(deltaTime: Float) {
    for system in customSystems {
        system(deltaTime)
    }
}
