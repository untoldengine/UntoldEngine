//
//  AssetInstaller.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

struct AssetInstaller {
    let force: Bool

    private let knownFolders = [
        "Models", "Animations", "Gaussians", "Scripts",
        "StreamModels", "Textures", "Shaders", "Scenes", "LUT",
    ]

    func install(pack: AssetPack, into gameDataURL: URL) async throws {
        let zipURL = try await download(pack: pack)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let extractDir = try extract(zipURL: zipURL)
        defer { try? FileManager.default.removeItem(at: extractDir) }

        let packRoot = findPackRoot(in: extractDir)
        let fileCount = try merge(from: packRoot, into: gameDataURL)

        print("")
        printSuccess("Installed \(fileCount) file\(fileCount == 1 ? "" : "s") into GameData")
    }

    // MARK: - Download

    private func download(pack: AssetPack) async throws -> URL {
        guard let url = URL(string: pack.downloadURL) else {
            throw AssetError.invalidURL(pack.downloadURL)
        }

        printInfo("Downloading \(pack.name) (\(pack.size))...")

        let (tempURL, response) = try await URLSession.shared.download(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AssetError.downloadFailed("Server returned a non-200 response")
        }

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".zip")
        try FileManager.default.moveItem(at: tempURL, to: zipURL)

        printSuccess("Download complete")
        return zipURL
    }

    // MARK: - Extraction

    private func extract(zipURL: URL) throws -> URL {
        printInfo("Extracting...")

        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)

        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", extractDir.path]
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let msg = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "Unknown error"
            throw AssetError.extractionFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return extractDir
    }

    /// Finds the single top-level folder inside the extracted directory.
    /// If the ZIP extracts files flat (no root folder), returns extractDir itself.
    private func findPackRoot(in extractDir: URL) -> URL {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: extractDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return extractDir
        }

        let dirs = contents.filter { url in
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            // Exclude macOS metadata folders that some ZIP tools inject
            return isDir.boolValue && !url.lastPathComponent.hasPrefix("__")
        }

        return dirs.count == 1 ? dirs[0] : extractDir
    }

    // MARK: - Merge

    private func merge(from packRoot: URL, into gameDataURL: URL) throws -> Int {
        printInfo("Merging into GameData...")
        print("")

        var totalFiles = 0
        for folder in knownFolders {
            let source = packRoot.appendingPathComponent(folder)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }

            let dest = gameDataURL.appendingPathComponent(folder)
            totalFiles += try mergeDirectory(from: source, into: dest, relativePath: folder)
        }
        return totalFiles
    }

    private func mergeDirectory(from source: URL, into destination: URL, relativePath: String) throws -> Int {
        let fm = FileManager.default

        if !fm.fileExists(atPath: destination.path) {
            try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        }

        let contents = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
        var fileCount = 0

        for item in contents {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)

            let itemRelativePath = relativePath + "/" + item.lastPathComponent
            let destItem = destination.appendingPathComponent(item.lastPathComponent)

            if isDir.boolValue {
                fileCount += try mergeDirectory(from: item, into: destItem, relativePath: itemRelativePath)
            } else if fm.fileExists(atPath: destItem.path) {
                if force || confirm("  \(itemRelativePath) already exists. Overwrite?", default: false) {
                    try fm.removeItem(at: destItem)
                    try fm.copyItem(at: item, to: destItem)
                    print("  → \(itemRelativePath) (overwritten)")
                    fileCount += 1
                } else {
                    print("  ⊘ \(itemRelativePath) (skipped)")
                }
            } else {
                try fm.copyItem(at: item, to: destItem)
                print("  → \(itemRelativePath)")
                fileCount += 1
            }
        }

        return fileCount
    }
}

// MARK: - Errors

enum AssetError: LocalizedError {
    case manifestNotFound
    case packNotFound(String)
    case invalidURL(String)
    case downloadFailed(String)
    case extractionFailed(String)
    case gameDataNotFound
    case ambiguousGameData([URL])

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "Asset manifest not found in CLI bundle"
        case let .packNotFound(id):
            return "Asset pack '\(id)' not found. Run 'untoldengine assets list' to see available packs."
        case let .invalidURL(url):
            return "Invalid download URL: \(url)"
        case let .downloadFailed(msg):
            return "Download failed: \(msg)"
        case let .extractionFailed(msg):
            return "Extraction failed: \(msg)"
        case .gameDataNotFound:
            return """
            Could not find a GameData folder in the current directory.
            Run this command from your project root, or specify the path:
              untoldengine assets install <pack> --output ~/Projects/MyGame/Sources/MyGame/GameData
            """
        case let .ambiguousGameData(paths):
            let list = paths.map { "  \($0.path)" }.joined(separator: "\n")
            return """
            Found multiple GameData folders — specify which one to use with --output:
            \(list)
            """
        }
    }
}
