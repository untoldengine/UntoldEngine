
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO


public func loadScene(filename: String, withExtension: String, _ appendModel: Bool = false) {

  //destroy all entities before loading new ones
  if appendModel == false {
    selectedModel = false
    activeEntity = 0
    var entitiesToDelete: [EntityDesc] = []

    if scene.entities.count > 0 {

      for entity in scene.entities {

        if !entity.freed {
          var r = scene.get(component: Render.self, for: entity.index)
          var t = scene.get(component: Transform.self, for: entity.index)
          r?.mesh = nil

          scene.remove(component: Render.self, from: entity.index)
          scene.remove(component: Transform.self, from: entity.index)

          r = nil
          t = nil

          entitiesToDelete.append(entity)
        }

      }

      for entities in entitiesToDelete {
        scene.destroyEntity(entities.index)
      }
    }
  }

  guard let url:URL=getResourceURL(forResource: filename, withExtension: withExtension)else{
    print("Unable to find file \(filename)")
    return
  }

  var meshes = [Mesh]()

  meshes = Mesh.loadMeshes(
    url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

  for mesh in meshes {

    //set up entities
    var modelName = "mesh"

    if let meshName = mesh.name {
      modelName = meshName
    }

    let entity = createEntityWithName(entityName: modelName )

    activeEntity = entity
    
    registerComponent(entity, Render.self)
    registerComponent(entity, Transform.self)

    let r = scene.get(component: Render.self, for: entity)
    r?.mesh = mesh

    let t = scene.get(component: Transform.self, for: entity)

    if let localSpace = mesh.localSpace {
      t?.localSpace = localSpace
    }

    t?.minBox = mesh.minBox
    t?.maxBox = mesh.maxBox

  }

}

//load material database
func loadMaterialFile() -> Data? {
  guard let url = Bundle.module.url(forResource: "materialdatabase", withExtension: "json") else {
    print("Material Database file not found.")
    return nil
  }
  do {
    return try Data(contentsOf: url)
  } catch {
    print("Failed to load material database file: \(error)")
    return nil
  }
}

func parseMaterials(from data: Data) -> [MaterialMERL]? {
  let decoder = JSONDecoder()
  do {
    let database = try decoder.decode(MaterialDatabase.self, from: data)
    return database.materials
  } catch {
    print("Error parsing materials: \(error)")
    return nil
  }
}

func createMaterialDictionary(from materials: [MaterialMERL]) -> [String: MaterialMERL] {
  var materialDict = [String: MaterialMERL]()
  for material in materials {
    materialDict[material.name] = material
  }
  return materialDict
}

// Function to construct a URL for a given mesh name within a directory in the main bundle
func constructMeshURL(directoryName: String, meshName: String) -> URL? {
  // Get the URL for the directory in the main bundle
  guard let directoryURL = Bundle.module.url(forResource: directoryName, withExtension: nil) else {
    print("Directory not found in bundle: \(directoryName)")
    return nil
  }

  // Append the mesh name to the directory URL
  let meshURL = directoryURL.appendingPathComponent(meshName)

  return meshURL
}

// Function to load JSON data from the main bundle and decode it into an array of strings
func loadModelNames(from fileName: String) -> [String]? {
  // Get the URL for the file in the main bundle
  guard let url = Bundle.module.url(forResource: fileName, withExtension: "json") else {
    print("File not found in bundle: \(fileName).json")
    return nil
  }

  do {
    // Read the file contents
    let data = try Data(contentsOf: url)

    // Decode the JSON data
    let modelNames = try JSONDecoder().decode([String].self, from: data)
    return modelNames
  } catch {
    print("Error reading or decoding file: \(error)")
    return nil
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
