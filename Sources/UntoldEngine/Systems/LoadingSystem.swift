
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func loadScene(filename: URL, withExtension _: String) {
    var meshes = [Mesh]()

    meshes = Mesh.loadMeshes(
        url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device
    )

    for mesh in meshes {
        meshDictionary[mesh.name] = mesh
    }
}

public func loadScene(filename: String, withExtension: String) {
    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        print("Unable to find file \(filename)")
        return
    }

    loadScene(filename: url, withExtension: url.pathExtension)
}

public func addMeshToEntity(entityId: EntityID, name: String) {
    if let meshValue = meshDictionary[name] {
        registerComponent(entityId: entityId, componentType: RenderComponent.self)
        registerComponent(entityId: entityId, componentType: TransformComponent.self)

        guard let r = scene.get(component: RenderComponent.self, for: entityId) else {
            print("Entity does not have a Render Component. Please add one")
            return
        }

        guard let t = scene.get(component: TransformComponent.self, for: entityId) else {
            print("Entity does not have a Transform Component. Please add one")
            return
        }

        r.mesh = meshValue

        t.localSpace = meshValue.localSpace
        t.maxBox = meshValue.maxBox
        t.minBox = meshValue.minBox

    } else {
        print("asset not found in list")
    }
}

public func loadBulkScene(filename: String, withExtension: String) {
    var meshes = [Mesh]()

    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        print("Unable to find file \(filename)")
        return
    }

    meshes = Mesh.loadMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device)

    for mesh in meshes {
        meshDictionary[mesh.name] = mesh

        let entity: EntityID = createEntity()
        addMeshToEntity(entityId: entity, name: mesh.name)
    }
}
