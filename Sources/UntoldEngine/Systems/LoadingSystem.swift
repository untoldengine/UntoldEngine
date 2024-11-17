
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func getResourceURL(forResource resourceName: String, withExtension ext: String) -> URL? {
    // First, check Bundle.module for the resource
    if let url = Bundle.module.url(forResource: resourceName, withExtension: ext) {
        return url
    }

    // If not found in Bundle.module, check Bundle.main
    return Bundle.main.url(forResource: resourceName, withExtension: ext)
}

public func loadScene(filename: URL, withExtension _: String, flip: Bool = true) {
    var meshes = [Mesh]()

    meshes = Mesh.loadMeshes(
        url: filename, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, flip: flip
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

public func loadBulkScene(filename: String, withExtension: String, flip: Bool = true) {
    var meshes = [Mesh]()

    guard let url: URL = getResourceURL(forResource: filename, withExtension: withExtension) else {
        print("Unable to find file \(filename)")
        return
    }

    meshes = Mesh.loadMeshes(url: url, vertexDescriptor: vertexDescriptor.model, device: renderInfo.device, flip: flip)

    for mesh in meshes {
        meshDictionary[mesh.name] = mesh

        let entity: EntityID = createEntity()
        registerDefaultComponents(entityId: entity, name: mesh.name)
    }
}
