
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


public func loadDirectionalLight(
  _ filename: URL, fileextension: String, direction: simd_float3, color: simd_float3,
  intensity: Float
) {

  var meshes = [Mesh]()

  meshes = Mesh.loadMeshes(
    url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

  for mesh in meshes {

    let entity = createEntityWithName(entityName: "Sun_" + String(lightingSystem.dirLight.count))

    activeEntity = entity

    registerComponent(entity, Render.self)
    registerComponent(entity, Transform.self)
    registerComponent(entity, LightComponent.self)

    let r = scene.get(component: Render.self, for: entity)
    r?.mesh = mesh

    let t = scene.get(component: Transform.self, for: entity)
    t?.localSpace = mesh.localSpace
    t?.minBox = mesh.minBox
    t?.maxBox = mesh.maxBox

    let camPosition = camera.localPosition - camera.zAxis * 5.0

    translateEntityBy(entity, camPosition)

    //add it to the lighting system
    let sun = DirectionalLight(direction: direction, color: color, intensity: intensity)

    let l = scene.get(component: LightComponent.self, for: entity)
    l?.lightType = .directional(sun)

    lightingSystem.addDirectionalLight(entityID: entity, light: sun)

  }

}

func loadPointLight(
  _ filename: URL, fileextension: String, position: simd_float3, color: simd_float3,
  intensity: Float, radius: Float
) {

  var meshes = [Mesh]()

  meshes = Mesh.loadMeshes(
    url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

  for mesh in meshes {

    let entity = createEntityWithName(
      entityName: "PointLight_" + String(lightingSystem.pointLight.count))

    activeEntity = entity
    registerComponent(entity, Render.self)
    registerComponent(entity, Transform.self)
    registerComponent(entity, LightComponent.self)

    let r = scene.get(component: Render.self, for: entity)
    r?.mesh = mesh

    let t = scene.get(component: Transform.self, for: entity)
    t?.localSpace = mesh.localSpace
    t?.minBox = mesh.minBox
    t?.maxBox = mesh.maxBox
    translateEntityBy(entity, position)
    let l = scene.get(component: LightComponent.self, for: entity)
    let pointlight: PointLight = PointLight(
      position: position, color: color, attenuation: simd_float4(1.0, 0.7, 1.8, 0.0),
      intensity: intensity, radius: radius)
    l?.lightType = .point(pointlight)

    //add it to the lighting system
    lightingSystem.addPointLight(entityID: entity, light: pointlight)

  }
}

func loadAreaLight(
  _ filename: URL, fileextension: String, position: simd_float3, color: simd_float3,
  intensity: Float, radius: Float
) {

  var meshes = [Mesh]()

  meshes = Mesh.loadMeshes(
    url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

  for mesh in meshes {

    let entity = createEntityWithName(entityName: "Area" + String(lightingSystem.pointLight.count))

    activeEntity = entity
    registerComponent(entity, Render.self)
    registerComponent(entity, Transform.self)
    registerComponent(entity, LightComponent.self)

    let r = scene.get(component: Render.self, for: entity)
    r?.mesh = mesh
    r?.mesh.submeshes[0].material?.emit = true
    let t = scene.get(component: Transform.self, for: entity)
    t?.localSpace = mesh.localSpace
    t?.minBox = mesh.minBox
    t?.maxBox = mesh.maxBox

    let l = scene.get(component: LightComponent.self, for: entity)

    var position: simd_float3 = simd_float3(0.0, 0.0, 0.0)  // Center position of the area light
    var color: simd_float3 = simd_float3(1.0, 1.0, 1.0)  // Light color
    //        var intensity: Float = 1.0                               // Light intensity
    //        var width: Float = 1.0                                   // Width of the area light
    //        var height: Float = 1.0                                  // Height of the area light
    //        var normal: simd_float3 = simd_float3(0.0, -1.0, 0.0)    // Normal vector of the light's surface
    //        var right: simd_float3 = simd_float3(1.0, 0.0, 0.0)      // Right vector defining the surface orientation
    //        var up: simd_float3 = simd_float3(0.0, 0.0, 1.0)         // Up vector defining the surface orientation
    //        var twoSided: Bool = false

    var arealight: AreaLight = AreaLight(position: position, color: color)

    l?.lightType = .area(arealight)

    //add it to the lighting system
    lightingSystem.addAreaLight(entityID: entity, light: arealight)

  }
}

func addNewPointLight() {

    guard let url:URL=getResourceURL(forResource: "pointLight", withExtension: "usdc")else{
        print("Unable to find file pointLight.usdc")
        return
    }

    let camPosition = camera.localPosition - camera.zAxis * 5.0

  loadPointLight(
    url, fileextension: url.pathExtension, position: camPosition,
    color: simd_float3(1.0, 1.0, 1.0), intensity: 1.0, radius: 1.0)

}

func addNewAreaLight() {

    guard let url:URL=getResourceURL(forResource: "areaLight", withExtension: "usdc")else{
        print("Unable to find file areaLight.usdc")
        return
    }


  loadAreaLight(
    url, fileextension: url.pathExtension, position: simd_float3(0.0, 1.0, 0.0),
    color: simd_float3(1.0, 1.0, 1.0), intensity: 1.0, radius: 1.0)

}

public func addNewSunLight() {

  guard let url:URL=getResourceURL(forResource: "sunMesh", withExtension: "usdc")else{
    print("Unable to find file sunMesh.usdc")
    return
  }


 loadDirectionalLight(
    url, fileextension: url.pathExtension, direction: simd_float3(0.0, 1.0, 0.01),
    color: simd_float3(1.0, 1.0, 1.0), intensity: 1.0)

}
