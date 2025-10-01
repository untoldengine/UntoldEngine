//
//  EditorCameraSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import UntoldEngine

public func findSceneCamera() -> EntityID {
    for entityId in scene.getAllEntities() {
        if hasComponent(entityId: entityId, componentType: CameraComponent.self), hasComponent(entityId: entityId, componentType: SceneCameraComponent.self) {
            return entityId
        }
    }

    // if scene camera was not found, then create one

    let sceneCamera = createEntity()
    createSceneCamera(entityId: sceneCamera)
    return sceneCamera
}

public func createSceneCamera(entityId: EntityID) {
    setEntityName(entityId: entityId, name: "Scene Camera")
    registerComponent(entityId: entityId, componentType: CameraComponent.self)
    registerComponent(entityId: entityId, componentType: SceneCameraComponent.self)

    cameraLookAt(entityId: entityId,
                 eye: cameraDefaultEye, target: cameraTargetDefault,
                 up: cameraUpDefault)
}
