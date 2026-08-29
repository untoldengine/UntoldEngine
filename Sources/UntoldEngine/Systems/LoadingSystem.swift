
//
//  LoadingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit
import ModelIO

public final class LoadingSystem: @unchecked Sendable {
    public static let shared: LoadingSystem = .init()

    public typealias GetResourceURLBlock = (String, String, String?) -> URL?
    private let lock = NSLock()
    private var _resourceURLFn: GetResourceURLBlock? = getResourceURL

    private init() {}

    public var resourceURLFn: GetResourceURLBlock? {
        get {
            lock.lock()
            let value = _resourceURLFn
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            _resourceURLFn = newValue
            lock.unlock()
        }
    }

    public func resourceURL(forResource resourceName: String, withExtension ext: String, subResource subName: String? = nil) -> URL? {
        resourceURLFn?(resourceName, ext, subName)
    }
}

public func getResourceURL(resourceName: String, ext: String, subName: String?) -> URL? {
    // 0) Check if resourceName is an absolute path (starts with "/" or "~")
    // This provides better UX - users can provide absolute paths without setting assetBasePath
    let fm = FileManager.default
    if resourceName.hasPrefix("/") || resourceName.hasPrefix("~") {
        // Expand tilde if present
        let expandedPath = NSString(string: resourceName).expandingTildeInPath
        let absoluteURL = URL(fileURLWithPath: expandedPath)

        // If extension is provided in the path, use it directly
        if fm.fileExists(atPath: absoluteURL.path) {
            return absoluteURL
        }

        // Otherwise, try appending the extension
        let urlWithExt = absoluteURL.appendingPathExtension(ext)
        if fm.fileExists(atPath: urlWithExt.path) {
            return urlWithExt
        }

        if let assetBasePath {
            let base = effectiveAssetBaseURL(assetBasePath)
            // If a scene stores an absolute path from another machine, preserve any
            // known GameData suffix first, then fall back to flattened SwiftPM resources.
            let requestedURL = absoluteURL.pathExtension.isEmpty ? urlWithExt : absoluteURL
            if let relativeComponents = resourceSuffixComponents(from: requestedURL) {
                let structuredCandidate = relativeComponents.reduce(base) { $0.appendingPathComponent($1) }
                if fm.fileExists(atPath: structuredCandidate.path) {
                    return structuredCandidate
                }
            }

            let flatName = requestedURL.deletingPathExtension().lastPathComponent
            let flatCandidate = base.appendingPathComponent(flatName).appendingPathExtension(ext)
            if fm.fileExists(atPath: flatCandidate.path) {
                return flatCandidate
            }
        }
    }

    // Flat layout (no top-level "Assets")
    var searchPaths: [[String]] = [
        ["Models", resourceName, "\(resourceName).\(ext)"],
        ["StreamModels", resourceName, "\(resourceName).\(ext)"],
        ["Animations", resourceName, "\(resourceName).\(ext)"],
        ["HDR", "\(resourceName).\(ext)"],
        ["Gaussians", "\(resourceName).\(ext)"],
        ["Scripts", "\(resourceName).\(ext)"],
        ["Scenes", "\(resourceName).\(ext)"],
        ["Textures", "\(resourceName).\(ext)"],
    ]
    if let subName {
        searchPaths.append(["Materials", subName, "\(resourceName).\(ext)"])
    }

    // 1) External base path (folder OR .bundle OR already a Resources dir)
    if let basePath = assetBasePath {
        let base = effectiveAssetBaseURL(basePath)

        // Try FLAT root first (handles your current packaging)
        let flat = base.appendingPathComponent("\(resourceName).\(ext)")
        if fm.fileExists(atPath: flat.path) { return flat }

        // Then try structured subdirectories
        let searchPaths: [[String]] = [
            ["Models", resourceName, "\(resourceName).\(ext)"],
            ["StreamModels", resourceName, "\(resourceName).\(ext)"],
            ["Animations", resourceName, "\(resourceName).\(ext)"],
            ["HDR", "\(resourceName).\(ext)"],
            ["Gaussians", "\(resourceName).\(ext)"],
            ["Scripts", "\(resourceName).\(ext)"],
            ["Scenes", "\(resourceName).\(ext)"],
            ["Textures", "\(resourceName).\(ext)"],
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

private func effectiveAssetBaseURL(_ basePath: URL) -> URL {
    if basePath.pathExtension == "bundle",
       let bundle = Bundle(url: basePath),
       let resourceURL = bundle.resourceURL
    {
        return resourceURL
    }

    return basePath
}

private func resourceSuffixComponents(from url: URL) -> [String]? {
    let knownResourceDirectories: Set = [
        "Models",
        "StreamModels",
        "Animations",
        "HDR",
        "Gaussians",
        "Scripts",
        "Scenes",
        "Materials",
        "Textures",
        "Shaders",
    ]
    let components = url.pathComponents

    guard let resourceDirectoryIndex = components.firstIndex(where: { knownResourceDirectories.contains($0) }) else {
        return nil
    }

    return Array(components[resourceDirectoryIndex...])
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

public func playSceneAt(url: URL, completion: (() -> Void)? = nil) {
    guard let scene = loadGameScene(from: url) else {
        completion?()
        return
    }

    // Scene files always live at `<assetBasePath>/Scenes/<name>.untoldscene`. If the asset
    // base path hasn't been configured yet (e.g. setupAssetPaths() wasn't called), derive it
    // from the scene file's own location rather than trusting a path baked into the scene data.
    if assetBasePath == nil, url.deletingLastPathComponent().lastPathComponent == "Scenes" {
        assetBasePath = url.deletingLastPathComponent().deletingLastPathComponent()
    }

    destroyAllEntities {
        deserializeScene(sceneData: scene) {
            completion?()
        }

        // Rebind as soon as authored entities are created to avoid referencing a destroyed
        // startup camera while async mesh loads are still finishing.
        CameraSystem.shared.activeCamera = findGameCamera()
    }
}

/// Script registry to cache loaded scripts by name
private final class ScriptRegistryStore: @unchecked Sendable {
    static let shared = ScriptRegistryStore()

    private let lock = NSLock()
    private var scriptsByName: [String: USCScript] = [:]

    private init() {}

    var scripts: [String: USCScript] {
        get {
            lock.lock()
            let value = scriptsByName
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            scriptsByName = newValue
            lock.unlock()
        }
    }
}

public var scriptRegistry: [String: USCScript] {
    get { ScriptRegistryStore.shared.scripts }
    set { ScriptRegistryStore.shared.scripts = newValue }
}

/// Clear all loaded USC scripts from the in-memory registry.
public func clearScriptRegistry() {
    scriptRegistry.removeAll()
}

/// Load all USC scripts from a directory
/// - Parameter scriptsURL: URL to the Scripts directory. If nil, uses assetBasePath/Scripts
/// - Returns: The number of scripts loaded successfully
@discardableResult
public func loadScripts(from scriptsURL: URL? = nil) -> Int {
    scriptRegistry.removeAll()

    // Determine the scripts path
    let scriptsPath: URL
    if let providedURL = scriptsURL {
        scriptsPath = providedURL
    } else {
        guard let basePath = assetBasePath else {
            Logger.log(message: "⚠️  Cannot load scripts: assetBasePath is not set")
            return 0
        }
        scriptsPath = basePath.appendingPathComponent("Scripts", isDirectory: true)
    }

    // Check if Scripts directory exists
    guard FileManager.default.fileExists(atPath: scriptsPath.path) else {
        Logger.log(message: "⚠️  Scripts directory not found at: \(scriptsPath.path)")
        return 0
    }

    var loadedCount = 0
    var failedCount = 0

    do {
        let contents = try FileManager.default.contentsOfDirectory(
            at: scriptsPath,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for fileURL in contents {
            // Only process .uscript files
            guard fileURL.pathExtension.lowercased() == "uscript" else {
                continue
            }

            // Attempt to load the script
            if let script = loadUSCScript(from: fileURL) {
                scriptRegistry[script.name] = script
                loadedCount += 1
                Logger.log(message: "✅ Loaded script: \(script.name)")
            } else {
                failedCount += 1
                Logger.log(message: "❌ Failed to load script: \(fileURL.lastPathComponent)")
            }
        }
    } catch {
        Logger.log(message: "❌ Error reading Scripts directory: \(error.localizedDescription)")
        return 0
    }

    let totalAttempted = loadedCount + failedCount
    if totalAttempted > 0 {
        Logger.log(message: "📜 Script loading complete: \(loadedCount)/\(totalAttempted) scripts loaded successfully")
    } else {
        Logger.log(message: "ℹ️  No .uscript files found in Scripts directory")
    }

    return loadedCount
}

/// Get a loaded script by name from the registry
public func getScript(named name: String) -> USCScript? {
    scriptRegistry[name]
}

/// Check if a script is loaded
public func isScriptLoaded(named name: String) -> Bool {
    scriptRegistry[name] != nil
}

/// Reload a specific script from disk
@discardableResult
public func reloadScript(named name: String) -> Bool {
    guard let basePath = assetBasePath else {
        Logger.log(message: "⚠️  Cannot reload script: assetBasePath is not set")
        return false
    }

    let scriptsPath = basePath.appendingPathComponent("Scripts", isDirectory: true)
    let scriptURL = scriptsPath.appendingPathComponent("\(name).uscript")

    guard let script = loadUSCScript(from: scriptURL) else {
        Logger.log(message: "❌ Failed to reload script: \(name)")
        return false
    }

    scriptRegistry[script.name] = script
    Logger.log(message: "🔄 Reloaded script: \(script.name)")
    return true
}

/// Find LOD file URLs for a given base path
/// Returns array of URLs for each LOD level found
public func findLODFiles(basePath: URL, lodCount: Int = 4) -> [URL] {
    var lodURLs: [URL] = []

    // Strip existing LOD suffix if present (e.g., tree_LOD0.usdz -> tree.usdz)
    let fileNameWithoutExt = basePath.deletingPathExtension().lastPathComponent
    let baseDirectory = basePath.deletingLastPathComponent()
    let ext = basePath.pathExtension

    // Remove _LOD\d+ pattern if it exists
    let baseFileName: String
    if let range = fileNameWithoutExt.range(of: "_LOD[0-9]+$", options: .regularExpression) {
        baseFileName = String(fileNameWithoutExt[..<range.lowerBound])
    } else {
        baseFileName = fileNameWithoutExt
    }

    for lodIndex in 0 ..< lodCount {
        // Construct LOD file path: baseName_LOD{N}.ext
        let lodFileName = "\(baseFileName)_LOD\(lodIndex).\(ext)"
        let lodPath = baseDirectory.appendingPathComponent(lodFileName)

        // Check if file exists
        guard FileManager.default.fileExists(atPath: lodPath.path) else {
            Logger.logWarning(message: "LOD\(lodIndex) not found: \(lodPath.lastPathComponent)")
            break
        }

        lodURLs.append(lodPath)
    }

    return lodURLs
}
