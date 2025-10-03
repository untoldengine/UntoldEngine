
//
//  LoadingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import MetalKit
import ModelIO

    
public final class LoadingSystem
{
    public static var shared: LoadingSystem = LoadingSystem()
    
    public typealias GetResourceURLBlock = (String, String, String?) -> URL?
    public var resourceURLFn: GetResourceURLBlock? = getResourceURL
    
    public func resourceURL(forResource resourceName: String, withExtension ext: String, subResource subName: String? = nil) -> URL? {
        return resourceURLFn?(resourceName, ext, subName)
    }
}

public func getResourceURL(resourceName: String, ext: String, subName: String?) -> URL? {
    // Flat layout (no top-level "Assets")
    var searchPaths: [[String]] = [
        ["Models", resourceName, "\(resourceName).\(ext)"],
        ["Animations", resourceName, "\(resourceName).\(ext)"],
        ["HDR", "\(resourceName).\(ext)"],
    ]
    if let subName {
        searchPaths.append(["Materials", subName, "\(resourceName).\(ext)"])
    }

    // 1) External base path
    if let basePath = assetBasePath {
        for components in searchPaths {
            let candidate = components.reduce(basePath) { $0.appendingPathComponent($1) }
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
    }
    
    // 2) Main bundle without folders ( the default one in Xcode )
    if let url = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        return url
    }
        
    // 3) Main bundle (search subdirectories) usully swift package preserve the folder structure
    for components in searchPaths {
        if let url = urlInBundle(Bundle.main, components: components) {
            return url
        }
    }

    // 4) Module bundle (UNCHANGED: top-level only, for engine-internal content)
    return Bundle.module.url(forResource: resourceName, withExtension: ext)
}

fileprivate func urlInBundle(_ bundle: Bundle, components: [String]) -> URL? {
    guard let filename = components.last else { return nil }
    let folders = components.dropLast()
    let parts = filename.split(separator: ".", maxSplits: 1)
    guard parts.count == 2 else { return nil }
    let name = String(parts[0])
    let ext = String(parts[1])

    return bundle.url(
        forResource: name,
        withExtension: ext,
        subdirectory: folders.joined(separator: "/")
    )
}

#if os(macOS)
    public func playSceneAt(url: URL) {
        if let scene = loadGameScene(from: url) {
            destroyAllEntities()
            deserializeScene(sceneData: scene)

            CameraSystem.shared.activeCamera = findGameCamera()
        }
    }
#endif
