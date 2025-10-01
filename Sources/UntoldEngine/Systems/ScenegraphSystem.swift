//
//  ScenegraphSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd

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
}

public func removeParent(childId: EntityID) {
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

    localTransformComponent.scale = simd_float3(worldTransformComponent.space.columns.0.x, worldTransformComponent.space.columns.1.y, worldTransformComponent.space.columns.2.z)

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
    // Determine the maximum level in the hierarchy
    let maxLevel = scene.getAllEntities().compactMap {
        scene.get(component: ScenegraphComponent.self, for: $0)?.level
    }.max() ?? 0

    // Traverse level by level
    for level in 0 ... maxLevel {
        let entitiesAtLevel = getEntitiesWithLevel(level: level)
        for entityId in entitiesAtLevel {
            updateTransformSystem(entityId: entityId)
        }
    }
}
