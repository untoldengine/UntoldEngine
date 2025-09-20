
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func getResourceURL(forResource resourceName: String, withExtension ext: String, subResource subName: String? = nil) -> URL? {
    if let basePath = assetBasePath {
        let assetMeshPath = basePath
            .appendingPathComponent("Assets")
            .appendingPathComponent("Models")
            .appendingPathComponent(resourceName)
            .appendingPathComponent("\(resourceName).\(ext)")
        if FileManager.default.fileExists(atPath: assetMeshPath.path) {
            return assetMeshPath
        }

        let assetAnimationPath = basePath
            .appendingPathComponent("Assets")
            .appendingPathComponent("Animations")
            .appendingPathComponent(resourceName)
            .appendingPathComponent("\(resourceName).\(ext)")
        if FileManager.default.fileExists(atPath: assetAnimationPath.path) {
            return assetAnimationPath
        }

        let assetHDRPath = basePath
            .appendingPathComponent("Assets")
            .appendingPathComponent("HDR")
            .appendingPathComponent("\(resourceName).\(ext)")
        if FileManager.default.fileExists(atPath: assetHDRPath.path) {
            return assetHDRPath
        }

        // Materials
        if let subName {
            let assetMaterialPath = basePath
                .appendingPathComponent("Assets")
                .appendingPathComponent("Materials")
                .appendingPathComponent(subName)
                .appendingPathComponent("\(resourceName).\(ext)")
            if FileManager.default.fileExists(atPath: assetMaterialPath.path) {
                return assetMaterialPath
            }
        }
    }

    // check Bundle.main for the resourc
    if let mainBundleUrl = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        return mainBundleUrl
    }

    // else search in bundle module
    return Bundle.module.url(forResource: resourceName, withExtension: ext)
}
#if os(macOS)
public func playSceneAt(url: URL) {
    if let scene = loadGameScene(from: url) {
        destroyAllEntities()
        deserializeScene(sceneData: scene)
    }
}
#endif
