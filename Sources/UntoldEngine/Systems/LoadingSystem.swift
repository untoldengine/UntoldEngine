
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation
import MetalKit
import ModelIO

public func getResourceURL(
    forResource resourceName: String,
    withExtension ext: String,
    subResource subName: String? = nil
) -> URL? {
    
    // Define common search paths (relative)
    var searchPaths: [[String]] = [
        ["Assets", "Models", resourceName, "\(resourceName).\(ext)"],
        ["Assets", "Animations", resourceName, "\(resourceName).\(ext)"],
        ["Assets", "HDR", "\(resourceName).\(ext)"]
    ]
    
    if let subName {
        searchPaths.append(["Assets", "Materials", subName, "\(resourceName).\(ext)"])
    }
    
    // 1. Look under assetBasePath if defined
    if let basePath = assetBasePath {
        for components in searchPaths {
            let candidate = components.reduce(basePath) { $0.appendingPathComponent($1) }
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
    }
    
    // 2. Look under main bundle
    for components in searchPaths {
        if let url = urlInBundle(Bundle.main, components: components) {
            return url
        }
    }
    
    // 3. Look under module bundle
    return Bundle.module.url(forResource: resourceName, withExtension: ext)
    
}

private func urlInBundle(_ bundle: Bundle, components: [String]) -> URL? {
    // Last component is the file
    guard let filename = components.last else { return nil }
    let folders = components.dropLast()
    
    let nameExt = filename.split(separator: ".", maxSplits: 1)
    guard nameExt.count == 2 else { return nil }
    
    let resource = String(nameExt[0])
    let ext = String(nameExt[1])
    
    return bundle.url(forResource: resource, withExtension: ext, subdirectory: folders.joined(separator: "/"))
}

#if os(macOS)
public func playSceneAt(url: URL) {
    if let scene = loadGameScene(from: url) {
        destroyAllEntities()
        deserializeScene(sceneData: scene)
    }
}
#endif
