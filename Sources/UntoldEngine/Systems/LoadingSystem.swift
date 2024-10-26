
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func loadScene(filename: URL, withExtension: String) {

   var meshes = [Mesh]()

  meshes = Mesh.loadMeshes(
    url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

    for mesh in meshes{
       meshDictionary[mesh.name]=mesh 
    }

}


public func loadScene(filename: String, withExtension: String) {

  guard let url:URL=getResourceURL(forResource: filename, withExtension: withExtension)else{
    print("Unable to find file \(filename)")
    return
  }
    
    loadScene(filename: url , withExtension: url.pathExtension)

}


public func addMeshToEntity(entity:EntityID, name:String){

    guard let r = scene.get(component: Render.self, for:entity)else{
        print("Entity does not have a Render Component. Please add one")  
        return
    }

    if let meshValue = meshDictionary[name]{
        
        r.mesh = meshValue

    }else{
        print("asset not found in list")
    }
    
}

