//
//  GizmoSystem.swift
//
//
//  Created by Harold Serrano on 6/9/25.
//

import Foundation
import simd

func createGizmo(name: String) {
    if parentEntityIdGizmo != .invalid {
        destroyEntity(entityId: parentEntityIdGizmo)
    }
    
    if activeEntity == .invalid{
        return
    }

    // create parent gizmo entity
    parentEntityIdGizmo = createEntity()

    registerTransformComponent(entityId: parentEntityIdGizmo)
    registerSceneGraphComponent(entityId: parentEntityIdGizmo)
    registerComponent(entityId: parentEntityIdGizmo, componentType: GizmoComponent.self)

    setEntityMesh(entityId: parentEntityIdGizmo, filename: name, withExtension: "usdc")

    translateTo(entityId: parentEntityIdGizmo, position: getPosition(entityId: activeEntity))
    for child in getEntityChildren(parentId: parentEntityIdGizmo) {
        registerComponent(entityId: child, componentType: GizmoComponent.self)
    }
    
    let distanceToCamera = length(getCameraPosition(entityId: getMainCamera()) - getPosition(entityId: parentEntityIdGizmo))
    
    guard let localTransformComponent = scene.get(component: LocalTransformComponent.self, for: parentEntityIdGizmo)else{
        handleError(.noLocalTransformComponent, parentEntityIdGizmo)
        return
    }
    
    let desiredScale = baseGizmoScaleFactor / distanceToCamera

    let clampedScale = simd_clamp(
        simd_float3(repeating: desiredScale),
        simd_float3(repeating: minGizmoScale),
        simd_float3(repeating: maxGizmoScale)
    )

    localTransformComponent.scale = clampedScale

    gizmoActive = true
}

func processGizmoAction(entityId: EntityID) {
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
        if hasComponent(entityId: activeEntity, componentType: LightComponent.self) {
            return
        }
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
    } else {
        activeHitGizmoEntity = .invalid
        editorController?.activeMode = .none
        editorController?.activeAxis = .none
    }
}

func removeGizmo() {
    if parentEntityIdGizmo != .invalid {
        destroyEntity(entityId: parentEntityIdGizmo)
        parentEntityIdGizmo = .invalid
    }

    gizmoActive = false
}
