//
//  GizmoSystem.swift
//
//
//  Created by Harold Serrano on 6/9/25.
//

import Foundation
import simd

func createTransformGizmo(){
   
    if(parentEntityIdGizmo != .invalid){
        
        destroyEntity(entityId: parentEntityIdGizmo)
    }
    
    // create parent gizmo entity
    parentEntityIdGizmo = createEntity()
    
    registerTransformComponent(entityId: parentEntityIdGizmo)
    registerSceneGraphComponent(entityId: parentEntityIdGizmo)
   
    setEntityMesh(entityId: parentEntityIdGizmo, filename: "translateGizmo", withExtension: "usdc")
     
    setParent(childId: parentEntityIdGizmo, parentId: activeEntity)
    
    for child in getEntityChildren(parentId: parentEntityIdGizmo){
        registerComponent(entityId: child, componentType: GizmoComponent.self)
    }
    
    gizmoActive = true
}

func createRotateGizmo(){
   
    if(parentEntityIdGizmo != .invalid){
        
        destroyEntity(entityId: parentEntityIdGizmo)
    }
    
    // create parent gizmo entity
    parentEntityIdGizmo = createEntity()
    
    registerTransformComponent(entityId: parentEntityIdGizmo)
    registerSceneGraphComponent(entityId: parentEntityIdGizmo)
   
    setEntityMesh(entityId: parentEntityIdGizmo, filename: "rotateGizmo", withExtension: "usdc")
     
    setParent(childId: parentEntityIdGizmo, parentId: activeEntity)
    
    for child in getEntityChildren(parentId: parentEntityIdGizmo){
        registerComponent(entityId: child, componentType: GizmoComponent.self)
    }
    
    gizmoActive = true
}

func processGizmoAction(entityId: EntityID){
    
    if entityId == .invalid{
        return
    }
    
    if getEntityName(entityId: entityId) == "xAxisTranslate"{
        editorController!.activeAxis = .x
        editorController!.activeMode = .translate
    }else if getEntityName(entityId: entityId) == "yAxisTranslate"{
        editorController!.activeAxis = .y
        editorController!.activeMode = .translate
    }else if getEntityName(entityId: entityId) == "zAxisTranslate"{
        editorController!.activeAxis = .z
        editorController!.activeMode = .translate
    }else if getEntityName(entityId: entityId) == "yAxisRotate"{
        editorController!.activeAxis = .y
        editorController!.activeMode = .rotate
    }else if getEntityName(entityId: entityId) == "xAxisRotate"{
        editorController!.activeAxis = .x
        editorController!.activeMode = .rotate
    }else if getEntityName(entityId: entityId) == "zAxisRotate"{
        editorController!.activeAxis = .z
        editorController!.activeMode = .rotate
    }else{
        activeHitGizmoEntity = .invalid
        editorController?.activeMode = .none
        editorController?.activeAxis = .none

    }
    
}

func removeGizmo(){
   
    if(parentEntityIdGizmo != .invalid){
        
        destroyEntity(entityId: parentEntityIdGizmo)
    }
    
    gizmoActive = false
}
