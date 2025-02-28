//
//  SelectionManager.swift
//
//
//  Created by Harold Serrano on 2/22/25.
//

import Foundation

class SelectionManager: ObservableObject {
    @Published var selectedEntity: EntityID? = nil

    init() {}

    func selectEntity(entityId: EntityID) {
        selectedEntity = entityId
    }
}
