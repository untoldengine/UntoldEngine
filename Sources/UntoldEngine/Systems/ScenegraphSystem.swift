//
//  ScenegraphSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// Set to true whenever any entity's transformDirty flag is raised.
// traverseSceneGraph bails out immediately when false, eliminating the
// O(n) entity scan on frames where nothing in the scene graph moved.
nonisolated(unsafe) var anyTransformDirty: Bool = false

func updateTransformSystem(entityId: EntityID) {
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: entityId) else {
        handleError(.noLocalTransformComponent, entityId)
        return
    }

    guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
        handleError(.noWorldTransformComponent, entityId)
        return
    }

    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        handleError(.noScenegraphComponent, entityId)
        return
    }

    let T = matrix4x4Translation(localTransformComponent.position.x, localTransformComponent.position.y, localTransformComponent.position.z)
    let R = getMatrix4x4FromQuaternion(q: localTransformComponent.rotation)
    let S = matrix4x4Scale(localTransformComponent.scale.x, localTransformComponent.scale.y, localTransformComponent.scale.z)

    localTransformComponent.space = T * R * S

    if scenegraphComponent.parent != EntityID.invalid {
        let parent = scenegraphComponent.parent

        guard let parentWorldTransformComponent = scene.get(component: WorldTransformComponent.self, for: parent) else {
            handleError(.noWorldTransformComponent, parent)
            return
        }

        worldTransformComponent.space = simd_mul(parentWorldTransformComponent.space, localTransformComponent.space)

    } else {
        worldTransformComponent.space = localTransformComponent.space
    }
}

public func setParent(childId: EntityID, parentId: EntityID, offset: simd_float3 = simd_float3(0.0, 0.0, 0.0)) {
    withWorldMutationGate {
        // get current child level
        guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: childId) else {
            handleError(.noScenegraphComponent, childId)
            return
        }

        guard let parentScenegraphComponent = scene.get(component: ScenegraphComponent.self, for: parentId) else {
            handleError(.noScenegraphComponent, parentId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: childId) else {
            handleError(.noLocalTransformComponent, childId)
            return
        }

        // set position the entity will be with respect to the parent
        localTransformComponent.position += offset

        let currentLevel = parentScenegraphComponent.level
        scenegraphComponent.parent = parentId
        scenegraphComponent.level = currentLevel + 1

        parentScenegraphComponent.children.append(childId)

        // propagate level changes to descendants
        updateDescendantLevels(childId: childId, level: scenegraphComponent.level)

        // Eagerly update world transforms and mark child hierarchy dirty for spatial partitioning
        syncWorldTransformAndMarkOctreeDirty(entityId: childId)
    }
}

public func removeParent(childId: EntityID) {
    withWorldMutationGate {
        // get current child level
        guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: childId) else {
            handleError(.noScenegraphComponent, childId)
            return
        }

        guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: childId) else {
            handleError(.noLocalTransformComponent, childId)
            return
        }

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: childId) else {
            handleError(.noWorldTransformComponent, childId)
            return
        }

        // set the current local tranform of the ball to the world transform before the detachment

        localTransformComponent.position = simd_float3(worldTransformComponent.space.columns.3.x, worldTransformComponent.space.columns.3.y, worldTransformComponent.space.columns.3.z)

        let upperLeft = matrix3x3_upper_left(worldTransformComponent.space)
        localTransformComponent.scale = simd_float3(
            length(upperLeft.columns.0),
            length(upperLeft.columns.1),
            length(upperLeft.columns.2)
        )

        localTransformComponent.rotation = transformMatrix3nToQuaternion(m: matrix3x3_upper_left(worldTransformComponent.space))

        // does it have a parent?
        let currentLevel = scenegraphComponent.level

        // if current level is equal to zero, it means it doesn't have a parent, there is nothing to unlink
        if currentLevel == 0 {
            return
        }

        // if it does have a parent, get the parent Id
        let parentId: EntityID = scenegraphComponent.parent

        // update the child info
        scenegraphComponent.parent = .invalid
        scenegraphComponent.level = currentLevel - 1

        // Remove the child from the parent list
        guard let parentScenegraphComponent = scene.get(component: ScenegraphComponent.self, for: parentId) else {
            handleError(.noScenegraphComponent, parentId)
            return
        }

        // remove all instances of childId
        parentScenegraphComponent.children.removeAll { $0 == childId }

        // update all child descendants
        updateDescendantLevels(childId: childId, level: scenegraphComponent.level)

        // Eagerly update world transforms and mark child hierarchy dirty for spatial partitioning
        syncWorldTransformAndMarkOctreeDirty(entityId: childId)
    }
}

public func getEntityChildren(parentId: EntityID) -> [EntityID] {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: parentId) else {
        handleError(.noScenegraphComponent, parentId)
        return [] // not sure about this
    }

    return scenegraphComponent.children
}

public func getEntityParent(entityId: EntityID) -> EntityID? {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        handleError(.noScenegraphComponent, entityId)
        return nil
    }

    if scenegraphComponent.parent == .invalid {
        return nil
    }

    return scenegraphComponent.parent
}

public func isParent(entityId: EntityID) -> Bool {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: entityId) else {
        handleError(.noScenegraphComponent, entityId)
        return false
    }

    return scenegraphComponent.children.count > 0
}

public func updateDescendantLevels(childId: EntityID, level: Int) {
    let children = getEntityChildren(parentId: childId)
    for descendant in children {
        // get current child level
        guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: descendant) else {
            continue
        }

        scenegraphComponent.level = level + 1

        updateDescendantLevels(childId: descendant, level: scenegraphComponent.level)
    }
}

func getEntitiesWithLevel(level: Int) -> [EntityID] {
    scene.entities.compactMap { entityDesc in
        guard
            !entityDesc.freed, // Exclude freed entities
            let hierarchy = scene.get(component: ScenegraphComponent.self, for: entityDesc.entityId),
            hierarchy.level == level
        else {
            return nil
        }
        return entityDesc.entityId
    }
}

public func traverseSceneGraph() {
    guard anyTransformDirty else { return }

    let maxLevel = scene.getAllEntities().compactMap {
        scene.get(component: ScenegraphComponent.self, for: $0)?.level
    }.max() ?? 0

    for level in 0 ... maxLevel {
        let entitiesAtLevel = getEntitiesWithLevel(level: level)
        for entityId in entitiesAtLevel {
            guard let local = scene.get(component: LocalTransformComponent.self, for: entityId),
                  local.transformDirty
            else { continue }

            updateTransformSystem(entityId: entityId)
            local.transformDirty = false

            // Parent world transform changed — children must recompute theirs.
            for childId in getEntityChildren(parentId: entityId) {
                if let childLocal = scene.get(component: LocalTransformComponent.self, for: childId) {
                    childLocal.transformDirty = true
                    anyTransformDirty = true
                }
            }
        }
    }

    anyTransformDirty = false
}
