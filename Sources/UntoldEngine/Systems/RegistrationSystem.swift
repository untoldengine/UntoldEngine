
//
//  RegistrationSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 2/19/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation

public func createEntity() -> EntityID {
    return scene.newEntity()
}

public func registerComponent<T: Component>(entityId: EntityID, componentType: T.Type) {
    _ = scene.assign(to: entityId, component: componentType)
}

public func destroyEntity(entityID: EntityID) {
    selectedModel = false

    var renderComponent = scene.get(component: RenderComponent.self, for: entityID)
    var transformComponent = scene.get(component: TransformComponent.self, for: entityID)
    renderComponent?.mesh = nil

    scene.remove(component: RenderComponent.self, from: entityID)
    scene.remove(component: TransformComponent.self, from: entityID)

    renderComponent = nil
    transformComponent = nil

    if let lightComponent = scene.get(component: LightComponent.self, for: entityID) {
        lightingSystem.removeLight(entityID: entityID)
        scene.remove(component: LightComponent.self, from: entityID)
    }

    scene.destroyEntity(entityID)
}
