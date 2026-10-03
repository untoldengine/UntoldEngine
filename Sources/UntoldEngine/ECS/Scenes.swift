
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
        if e.mask.test(componentId) {
            quarantineComponent(componentId, at: Int(entityIndex))
        }
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
            quarantineComponent(componentId, at: Int(entityIndex))
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
        EntityLifecycleEvents.shared.dispatchEntityDestroyed(oldId)

        for componentId in entities[entityIndexInt].mask.activeComponentIds() {
            quarantineComponent(componentId, at: entityIndexInt)
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
            EntityLifecycleEvents.shared.dispatchEntityCreated(newId)
            return newId
        } else {
            let entityIndex = EntityIndex(UInt32(entities.count))
            let newEntity = EntityDesc(entityId: createEntityId(entityIndex, 0), mask: ComponentMask(), freed: false, pendingDestroy: false)
            entities.append(newEntity)
            EntityLifecycleEvents.shared.dispatchEntityCreated(newEntity.entityId)
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

        // Ensure the pool for this component type exists and has room for this entity
        if componentPool[componentId] == nil {
            componentPool[componentId] = ComponentPool(for: T.self)
        }
        componentPool[componentId]?.reserve(upTo: Int(entityIndex))

        // An entity that already has the component gets a new one, and the one it had
        // leaves the scene as a removed one does.
        if e.mask.test(componentId) {
            quarantineComponent(componentId, at: Int(entityIndex))
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
        return pool.component(at: Int(entityIndex), as: T.self)
    }

    /// Moves the component in the slot of the entity at `entityIndex` to its pool's
    /// quarantine. For a component the entity's mask says the entity has: the mask is
    /// the record of which slots hold a component, so each one leaves once.
    private mutating func quarantineComponent(_ componentId: Int, at entityIndex: Int) {
        componentPool[componentId]?.quarantineComponent(at: entityIndex)
    }

    /// Takes out of quarantine the components that no copy of the scene can read any
    /// more, for the caller to release once the scene is no longer being changed: a
    /// component's deinit may read the scene. What a copy still holds back stays for
    /// the next call (see ComponentQuarantine).
    mutating func takeReleasableComponents() -> [AnyObject] {
        var released: [AnyObject] = []
        // Each pool is asked in place: a copy of it made for the asking would count
        // as a reader.
        var position = componentPool.startIndex
        while position != componentPool.endIndex {
            componentPool.values[position].takeQuarantinedComponents(into: &released)
            componentPool.formIndex(after: &position)
        }
        return released
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

public func queryEntities(with componentTypes: [any Component.Type]) -> [EntityID] {
    let componentIds = componentTypes.map { getComponentId(for: $0) }
    return queryEntitiesWithComponentIds(componentIds, in: scene)
}

public func hasComponent(entityId: EntityID, componentType: (some Any).Type) -> Bool {
    let entityIndex: EntityIndex = getEntityIndex(entityId)
    guard entityIndex < scene.entities.count else { return false }

    let entityMask = scene.entities[Int(entityIndex)].mask

    let componentId = getComponentId(for: componentType)

    return entityMask.test(componentId)
}

public func getEntityComponent<T: Component>(
    entityId: EntityID,
    componentType: T.Type = T.self
) -> T? {
    guard scene.exists(entityId) else {
        return nil
    }
    return scene.get(component: componentType, for: entityId)
}

public func removeEntityComponent(
    entityId: EntityID,
    componentType: (some Component).Type
) {
    guard scene.exists(entityId), hasComponent(entityId: entityId, componentType: componentType) else {
        return
    }
    scene.remove(component: componentType, from: entityId)
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

/// A lightweight, low-ceremony way for game code to attach a per-frame closure to its own
/// `Component` types without conforming to `EngineExtension`. Meant for a single game's own
/// gameplay logic, not for distributable plugins — those should use `EngineExtension`/
/// `RenderExtension`, which carry a namespaced identity and formal lifecycle contract this
/// mechanism deliberately does not require.
public struct CustomSystemHandle: Hashable, Sendable {
    private let id: UUID

    fileprivate init() {
        id = UUID()
    }
}

private final class CustomSystemsState: @unchecked Sendable {
    let lock = NSLock()
    var systemsByHandle: [CustomSystemHandle: (Float) -> Void] = [:]
    var order: [CustomSystemHandle] = []
}

private let customSystemsState = CustomSystemsState()

@discardableResult
public func registerCustomSystem(_ system: @escaping (Float) -> Void) -> CustomSystemHandle {
    enforceSceneMainActor()
    let handle = CustomSystemHandle()
    customSystemsState.lock.lock()
    customSystemsState.systemsByHandle[handle] = system
    customSystemsState.order.append(handle)
    customSystemsState.lock.unlock()
    return handle
}

public func unregisterCustomSystem(_ handle: CustomSystemHandle) {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    customSystemsState.systemsByHandle.removeValue(forKey: handle)
    customSystemsState.order.removeAll { $0 == handle }
    customSystemsState.lock.unlock()
}

public func updateCustomSystems(deltaTime: Float) {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    let systems = customSystemsState.order.compactMap { customSystemsState.systemsByHandle[$0] }
    customSystemsState.lock.unlock()
    for system in systems {
        system(deltaTime)
    }
}

func clearCustomSystems() {
    enforceSceneMainActor()
    customSystemsState.lock.lock()
    customSystemsState.systemsByHandle.removeAll()
    customSystemsState.order.removeAll()
    customSystemsState.lock.unlock()
}
