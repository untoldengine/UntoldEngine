//
//  SelectionManager.swift
//
//
//  Created by Harold Serrano on 2/22/25.
//

import Foundation

class SelectionManager: ObservableObject {
    @Published var selectedEntity: EntityID? = nil
    @Published var hasMesh: Bool = false
    @Published var hasKinetics: Bool = false

    init() {}

    func selectEntity(entityId: EntityID) {
        selectedEntity = entityId
    }

    func deselectEntity() {
        selectedEntity = nil
        hasMesh = false
        hasKinetics = false
    }
}
