
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

public final class LoadingSystem {
    public static var shared: LoadingSystem = .init()

    public typealias GetResourceURLBlock = (String, String, String?) -> URL?
    public var resourceURLFn: GetResourceURLBlock? = getResourceURL

    public func resourceURL(forResource resourceName: String, withExtension ext: String, subResource subName: String? = nil) -> URL? {
        resourceURLFn?(resourceName, ext, subName)
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

    // 1) External base path (folder OR .bundle OR already a Resources dir)
    if let basePath = assetBasePath {
        let fm = FileManager.default

        // If .bundle, hop into Contents/Resources on macOS
        let base: URL = {
            if basePath.pathExtension == "bundle",
               let bundle = Bundle(url: basePath),
               let res = bundle.resourceURL
            {
                return res
            }
            return basePath
        }()

        // Try FLAT root first (handles your current packaging)
        let flat = base.appendingPathComponent("\(resourceName).\(ext)")
        if fm.fileExists(atPath: flat.path) { return flat }

        // Then try structured subdirectories
        let searchPaths: [[String]] = [
            ["Models", resourceName, "\(resourceName).\(ext)"],
            ["Animations", resourceName, "\(resourceName).\(ext)"],
            ["HDR", "\(resourceName).\(ext)"],
        ] + (subName.map { [["Materials", $0, "\(resourceName).\(ext)"]] } ?? [])

        for components in searchPaths {
            let candidate = components.reduce(base) { $0.appendingPathComponent($1) }
            if fm.fileExists(atPath: candidate.path) { return candidate }
        }
    }

    // 2) Main bundle without folders ( the default one in Xcode )
    if let url = Bundle.main.url(forResource: resourceName, withExtension: ext) {
        return url
    }

    // 3) Main bundle (search subdirectories) usually swift package preserve the folder structure
    for components in searchPaths {
        if let url = urlInBundle(Bundle.main, components: components) {
            return url
        }
    }

    // 4) Module bundle (UNCHANGED: top-level only, for engine-internal content)
    return Bundle.module.url(forResource: resourceName, withExtension: ext)
}

private func urlInBundle(_ bundle: Bundle, components: [String]) -> URL? {
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
