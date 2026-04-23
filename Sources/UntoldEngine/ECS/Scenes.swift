
//
//  Scenes.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

@inline(__always)
private func enforceSceneMainActor() {
    // Scene mutations are synchronized through lock-backed global state.
}

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
        enforceSceneMainActor()
        let entityIndex = getEntityIndex(entityId)
        guard entityIndex < entities.count else {
            handleError(.entityMissing, entityId)
            return
        }
        let e = entities[Int(entityIndex)]

        guard e.entityId == entityId, !e.freed else {
            handleError(.entityMissing, entityId)
            return
        }

        let componentId = getComponentId(for: T.self)
        entities[Int(entityIndex)].mask.reset(componentId)
        componentIndex[componentId]?.remove(entityId)
    }

    public mutating func removeAllComponents(from entityId: EntityID) {
        enforceSceneMainActor()
        let entityIndex = getEntityIndex(entityId)
        guard entityIndex < entities.count else {
            handleError(.entityMissing, entityId)
            return
        }
        let e = entities[Int(entityIndex)]

        guard e.entityId == entityId, !e.freed else {
            handleError(.entityMissing, entityId)
            return
        }

        for componentId in e.mask.activeComponentIds() {
            componentIndex[componentId]?.remove(entityId)
        }
        entities[Int(entityIndex)].mask.resetAll()
    }

    /// Phase A: mark entity for destroy
    public mutating func markDestroy(_ entityId: EntityID) {
        enforceSceneMainActor()
        let idx = getEntityIndex(entityId)
        guard idx < entities.count else {
            return
        }
        guard entities[Int(idx)].entityId == entityId, !entities[Int(idx)].freed else {
            return
        }
        entities[Int(idx)].pendingDestroy = true
    }

    public mutating func markDestroyAll() {
        enforceSceneMainActor()
        for e in getAllEntities() {
            markDestroy(e)
        }
    }

    /// Phase B: Finalizze (call one per frame)
    public mutating func finalizePendingDestroys() {
        enforceSceneMainActor()
        for i in entities.indices {
            if entities[i].pendingDestroy, !entities[i].freed {
                destroyEntityFinalize(at: i)
            }
        }
    }

    private mutating func destroyEntityFinalize(at entityIndexInt: Int) {
        enforceSceneMainActor()
        let oldId = entities[entityIndexInt].entityId

        // Unregister from spatial systems before destroying
        OctreeSystem.shared.unregisterEntity(oldId)

        for componentId in entities[entityIndexInt].mask.activeComponentIds() {
            componentIndex[componentId]?.remove(oldId)
        }

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
        enforceSceneMainActor()
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

    /** explicitly specify type */
    public mutating func assign<T: Component>(to entityId: EntityID, component _: T.Type) -> T? {
        enforceSceneMainActor()
        let componentId = getComponentId(for: T.self)
        let entityIndex = getEntityIndex(entityId)
        guard entityIndex < entities.count else {
            handleError(.entityMissing, entityId)
            return nil
        }
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
        componentIndex[componentId, default: []].insert(entityId)

        return typedPointer.pointee
    }

    public func get<T: Component>(component _: T.Type, for entityId: EntityID) -> T? {
        let componentId = getComponentId(for: T.self)
        let entityIndex = getEntityIndex(entityId)

        if entities.count == 0 {
            handleError(.noentitiesinscene)
            return nil
        }

        guard entityIndex < entities.count else {
            handleError(.entityMissing, entityId)
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

    public func getAllEntities() -> [EntityID] {
        entities.compactMap { entityDesc in
            entityDesc.freed || entityDesc.pendingDestroy ? nil : entityDesc.entityId
        }
    }

    public func mask(for entityId: EntityID) -> ComponentMask? {
        let idx = getEntityIndex(entityId)
        guard idx < entities.count else { return nil }
        let e = entities[Int(idx)]
        guard e.entityId == entityId, !e.freed, !e.pendingDestroy else { return nil }
        return e.mask
    }

    // data
    var componentPool: [Int: ComponentPool] = [:]
    var entities: [EntityDesc] = []
    var freeEntities: [EntityIndex] = []
    var componentIndex: [Int: Set<EntityID>] = [:]
}

func createComponentMask(for components: [Int]) -> ComponentMask {
    var mask = ComponentMask()
    for componentId in components {
        mask.set(componentId)
    }
    return mask
}

public func queryEntitiesWithComponentIds(_ componentTypes: [Int], in scene: Scene) -> [EntityID] {
    guard !componentTypes.isEmpty else { return [] }

    // Sort by smallest index set first to minimize intersection cost
    let sorted = componentTypes.sorted {
        (scene.componentIndex[$0]?.count ?? 0) < (scene.componentIndex[$1]?.count ?? 0)
    }

    guard let firstId = sorted.first,
          var candidates = scene.componentIndex[firstId] else { return [] }

    for componentId in sorted.dropFirst() {
        guard let nextSet = scene.componentIndex[componentId] else { return [] }
        candidates = candidates.intersection(nextSet)
        if candidates.isEmpty { return [] }
    }

    // Exclude entities marked for destroy (pendingDestroy window)
    return candidates.filter { scene.exists($0) }
}

public func hasComponent(entityId: EntityID, componentType: (some Any).Type) -> Bool {
    let entityIndex: EntityIndex = getEntityIndex(entityId)
    guard entityIndex < scene.entities.count else { return false }

    let entityMask = scene.entities[Int(entityIndex)].mask

    let componentId = getComponentId(for: componentType)

    return entityMask.test(componentId)
}

func getAllEntityComponentsTypes(entityId: EntityID) -> [Any.Type] {
    let entityIndex: EntityIndex = getEntityIndex(entityId)
    guard entityIndex < scene.entities.count else { return [] }
    let entityMask = scene.entities[Int(entityIndex)].mask

    var components: [Any.Type] = []
    let typeInfoById = componentTypeInfosSnapshot()

    for (_, typeInfo) in typeInfoById {
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

        if let typeInfo = componentTypeInfo(for: typeId) {
            componentIdsArray.append(typeInfo.id)
        }
    }

    return componentIdsArray
}

/// Custom System registry
private final class CustomSystemsState: @unchecked Sendable {
    let lock = NSLock()
    var systems: [(Float) -> Void] = []
}

private let customSystemsState = CustomSystemsState()

public func registerCustomSystem(_ system: @escaping (Float) -> Void) {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    customSystemsState.systems.append(system)
    customSystemsState.lock.unlock()
}

public func updateCustomSystems(deltaTime: Float) {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    let systems = customSystemsState.systems
    customSystemsState.lock.unlock()
    for system in systems {
        system(deltaTime)
    }
}

func clearCustomSystems(keepingCapacity: Bool = true) {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    customSystemsState.systems.removeAll(keepingCapacity: keepingCapacity)
    customSystemsState.lock.unlock()
}
