//
//  SelectionManager.swift
//
//
//  Created by Harold Serrano on 2/22/25.
//

import Foundation

protocol SelectionDelegate: AnyObject {
    func didSelectEntity(_ entityId: EntityID)
    func resetActiveAxis()
}

class EditorController: SelectionDelegate, ObservableObject {
    let selectionManager: SelectionManager
    @Published var activeMode: TransformManipulationMode = .none
    @Published var activeAxis: TransformAxis = .none

    init(selectionManager: SelectionManager) {
        self.selectionManager = selectionManager
        inputSystem.selectionDelegate = self
    }

    func didSelectEntity(_ entityId: EntityID) {
        DispatchQueue.main.async {
            self.selectionManager.selectEntity(entityId: entityId)
        }
    }

    func resetActiveAxis() {
        activeAxis = .none
    }

    func refreshInspector() {
        DispatchQueue.main.async {
            self.selectionManager.objectWillChange.send()
        }
    }
}

class SceneGraphModel: ObservableObject {
    @Published var childrenMap: [EntityID: [EntityID]] = [:]

    func refreshHierarchy() {
        let allEntities = getAllGameEntities()
        childrenMap = Dictionary(grouping: allEntities) {
            getEntityParent(entityId: $0) ?? .invalid
        }
    }

    func getChildren(entityId: EntityID?) -> [EntityID] {
        childrenMap[entityId ?? .invalid] ?? []
    }
}

public class EditorComponentsState: ObservableObject {
    public static let shared = EditorComponentsState()

    @Published public var components: [EntityID: [ObjectIdentifier: ComponentOption_Editor]] = [:]

    func clear() {
        components.removeAll()
    }
}

public class EditorAssetBasePath: ObservableObject {
    public static let shared = EditorAssetBasePath()

    @Published public var basePath: URL? = assetBasePath
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
