//
//  SelectionManager.swift
//
//
//  Created by Harold Serrano on 2/22/25.
//

import Foundation

protocol SelectionDelegate: AnyObject {
    func didSelectEntity(_ entityId: EntityID)
}

class EditorController: SelectionDelegate {
    let selectionManager: SelectionManager

    init(selectionManager: SelectionManager) {
        self.selectionManager = selectionManager
        inputSystem.selectionDelegate = self
    }

    func didSelectEntity(_ entityId: EntityID) {
        DispatchQueue.main.async {
            self.selectionManager.selectEntity(entityId: entityId)
        }
    }
}

class SelectionManager: ObservableObject {
    @Published var selectedEntity: EntityID? = nil

    init() {}

    func selectEntity(entityId: EntityID) {
        print("entity has been selected \(entityId)")
        selectedEntity = entityId
    }
}
