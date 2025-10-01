//
//  GizmoSystem.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd
import UntoldEngine


func createGizmo(name: String) {
    var gizmoName: String = name

    removeGizmo()

    if activeEntity == .invalid {
        return
    }

    if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
        gizmoName = "translateGizmo_light"
    }

    // create parent gizmo entity
    parentEntityIdGizmo = createEntity()

    registerTransformComponent(entityId: parentEntityIdGizmo)
    registerSceneGraphComponent(entityId: parentEntityIdGizmo)
    registerComponent(entityId: parentEntityIdGizmo, componentType: GizmoComponent.self)

    setEntityMesh(entityId: parentEntityIdGizmo, filename: gizmoName, withExtension: "usdc")

    translateTo(entityId: parentEntityIdGizmo, position: getPosition(entityId: activeEntity))
    for child in getEntityChildren(parentId: parentEntityIdGizmo) {
        registerComponent(entityId: child, componentType: GizmoComponent.self)
    }

    if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
        let forward = getForwardAxisVector(entityId: activeEntity) * -1.0
        let position = getPosition(entityId: parentEntityIdGizmo) + forward
        translateTo(entityId: findEntity(name: "directionHandle")!, position: position)
    }

    gizmoActive = true
}

func processGizmoAction(entityId: EntityID) {
#if canImport(AppKit)
    if entityId == .invalid {
        return
    }

    if getEntityName(entityId: entityId) == "xAxisTranslate" {
        editorController!.activeAxis = .x
        editorController!.activeMode = .translate
    } else if getEntityName(entityId: entityId) == "yAxisTranslate" {
        editorController!.activeAxis = .y
        editorController!.activeMode = .translate
    } else if getEntityName(entityId: entityId) == "zAxisTranslate" {
        editorController!.activeAxis = .z
        editorController!.activeMode = .translate
    } else if getEntityName(entityId: entityId) == "yAxisRotate" {
        editorController!.activeAxis = .y
        editorController!.activeMode = .rotate
    } else if getEntityName(entityId: entityId) == "xAxisRotate" {
        editorController!.activeAxis = .x
        editorController!.activeMode = .rotate
    } else if getEntityName(entityId: entityId) == "zAxisRotate" {
        editorController!.activeAxis = .z
        editorController!.activeMode = .rotate
    } else if getEntityName(entityId: entityId) == "xAxisScale" {
        editorController!.activeAxis = .x
        editorController!.activeMode = .scale
    } else if getEntityName(entityId: entityId) == "yAxisScale" {
        editorController!.activeAxis = .y
        editorController!.activeMode = .scale
    } else if getEntityName(entityId: entityId) == "zAxisScale" {
        editorController!.activeAxis = .z
        editorController!.activeMode = .scale
    } else if getEntityName(entityId: entityId) == "directionHandle" {
        editorController!.activeMode = .lightRotate
        editorController!.activeAxis = .none
    } else {
        activeHitGizmoEntity = .invalid
        editorController?.activeMode = .none
        editorController?.activeAxis = .none
    }
#endif
}

func hitGizmoToolAxis(entityId: EntityID) -> Bool {
    if entityId == .invalid {
        return false
    }

    let name = getEntityName(entityId: entityId)

    let validNames: Set<String> = [
        "xAxisTranslate", "yAxisTranslate", "zAxisTranslate",
        "xAxisRotate", "yAxisRotate", "zAxisRotate",
        "xAxisScale", "yAxisScale", "zAxisScale",
        "directionHandle",
    ]

    if validNames.contains(name) {
        return true
    } else {
        return false
    }
}

func removeGizmo() {
    if parentEntityIdGizmo != .invalid {
        destroyEntity(entityId: parentEntityIdGizmo)
        parentEntityIdGizmo = .invalid
    }

    gizmoActive = false
}
