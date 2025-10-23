//
//  SelectionManager.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//
import Foundation
import UntoldEngine

protocol SelectionDelegate: AnyObject {
    func didSelectEntity(_ entityId: EntityID)
    func resetActiveAxis()
}

class SceneGraphModel: ObservableObject {
    @Published var childrenMap: [EntityID: [EntityID]] = [:]

    func refreshHierarchy() {
        let allEntities = getAllGameEntities()

        childrenMap = Dictionary(grouping: allEntities) { entityId in
            // If there's no ScenegraphComponent (e.g., camera), treat as root
            if !hasComponent(entityId: entityId, componentType: ScenegraphComponent.self) {
                return .invalid
            }
            return getEntityParent(entityId: entityId) ?? .invalid
        }
    }

    func getChildren(entityId: EntityID?) -> [EntityID] {
        childrenMap[entityId ?? .invalid] ?? []
    }
}

class SelectionManager: ObservableObject {
    @Published var selectedEntity: EntityID? = .invalid

    init() {}

    func selectEntity(entityId: EntityID) {
        selectedEntity = entityId

        if hasComponent(entityId: entityId, componentType: RenderComponent.self), hasComponent(entityId: entityId, componentType: LocalTransformComponent.self) {
            activeEntity = entityId
            guard let localTransform = scene.get(component: LocalTransformComponent.self, for: activeEntity) else { return }

            updateBoundingBoxBuffer(min: localTransform.boundingBox.min, max: localTransform.boundingBox.max)

            createGizmo(name: "translateGizmo")
        } else {
            activeEntity = .invalid
        }
    }
}
