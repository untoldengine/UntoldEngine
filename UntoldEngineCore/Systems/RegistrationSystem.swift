//
//  RegistrationSystem.swift
//  Mac_Untold
//
//  Created by Harold Serrano on 2/19/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation

func createEntity()->EntityID{
    return scene.newEntity()
}

func createEntityWithName(entityName name:String)->EntityID{
    let entityId:EntityID=scene.newEntity()
    entityGlobalNameMap[name]=entityId
    return entityId
}

func queryEntityWithName(entityName name:String)->EntityID?{
    guard let value=entityGlobalNameMap[name] else{
        handleError(.entityMissing, name)
        return nil
    }
    
    return value
}

func registerComponent<T: Component>(_ entityId: EntityID, _ componentType: T.Type) {
    _ = scene.assign(to: entityId, component: componentType)
}

func registerGeometry(_ entityId: EntityID,_ assetName: String){
        entityAssetmap[entityId]=assetName
}
