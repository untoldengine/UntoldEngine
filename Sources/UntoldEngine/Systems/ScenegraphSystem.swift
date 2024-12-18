//
//  ScenegraphSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 12/13/24.
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

public func setParent(childId: EntityID, parentId: EntityID) {
    // get current child level
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: childId) else {
        handleError(.noScenegraphComponent, childId)
        return
    }

    guard let parentScenegraphComponent = scene.get(component: ScenegraphComponent.self, for: parentId) else {
        handleError(.noScenegraphComponent, parentId)
        return
    }

    let currentLevel = parentScenegraphComponent.level
    scenegraphComponent.parent = parentId
    scenegraphComponent.level = currentLevel + 1

    parentScenegraphComponent.children.append(childId)

    // propagate level changes to descendants
    updateDescendantLevels(childId: childId, level: scenegraphComponent.level)
}

public func getEntitiesWithParent(parentId: EntityID) -> [EntityID] {
    guard let scenegraphComponent = scene.get(component: ScenegraphComponent.self, for: parentId) else {
        handleError(.noScenegraphComponent, parentId)
        return [] // not sure about this
    }

    return scenegraphComponent.children
}

public func updateDescendantLevels(childId: EntityID, level: Int) {
    let children = getEntitiesWithParent(parentId: childId)
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
