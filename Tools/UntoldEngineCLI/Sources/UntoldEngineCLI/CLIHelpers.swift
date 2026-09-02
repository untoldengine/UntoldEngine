//
//  CLIHelpers.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  CLIHelpers.swift
//  UntoldEngineCLI
//
//  CLI utility functions for path resolution, validation, and terminal output
//

import Foundation

// MARK: - Terminal Colors

enum TerminalColor: String {
    case reset = "\u{001B}[0m"
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case magenta = "\u{001B}[35m"
    case cyan = "\u{001B}[36m"
    case white = "\u{001B}[37m"
}

func printSuccess(_ message: String) {
    print("\(TerminalColor.green.rawValue)✅ \(message)\(TerminalColor.reset.rawValue)")
}

func printError(_ message: String) {
    print("\(TerminalColor.red.rawValue)❌ \(message)\(TerminalColor.reset.rawValue)")
}

func printWarning(_ message: String) {
    print("\(TerminalColor.yellow.rawValue)⚠️  \(message)\(TerminalColor.reset.rawValue)")
}

func printInfo(_ message: String) {
    print("\(TerminalColor.cyan.rawValue)ℹ️  \(message)\(TerminalColor.reset.rawValue)")
}

func printProgress(_ message: String) {
    print("\(TerminalColor.blue.rawValue)\(message)\(TerminalColor.reset.rawValue)")
}

// MARK: - Path Resolution

/// Resolves a path string to an absolute URL, handling special cases like ".", "~", and relative paths
func resolvePath(_ pathString: String) -> URL {
    let path = NSString(string: pathString).expandingTildeInPath

    if path.hasPrefix("/") {
        // Already absolute
        return URL(fileURLWithPath: path)
    } else if path == "." {
        // Current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    } else {
        // Relative path - resolve against current directory
        let currentDir = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: currentDir).appendingPathComponent(path)
    }
}

/// Validates that a path exists and is a directory
func validateDirectory(_ url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

// MARK: - Process Execution

/// Runs a process with stdout/stderr connected to this process's own, so the
/// child's output streams live (e.g. pip's install progress). Returns the
/// exit status; callers decide what error to throw on non-zero.
@discardableResult
func runInheritedProcess(_ executableURL: URL, _ arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

// MARK: - Blender Resolution

/// Shared by every command that shells out to Blender (`export`, `export-tiles`).
enum BlenderResolutionError: LocalizedError {
    case blenderNotFound
    case blenderNotExecutable(String)
    case blenderPython3NotFound(String)

    var errorDescription: String? {
        switch self {
        case .blenderNotFound:
            return """
            Blender was not found. Download it from https://www.blender.org/download/ \
            (tested with Blender 5.1.0), then use --blender /path/to/Blender or set BLENDER_BIN.
            """
        case let .blenderNotExecutable(path):
            return "Blender is not executable at: \(path)"
        case let .blenderPython3NotFound(blenderPath):
            return "Could not find Blender's bundled python3 next to \(blenderPath)."
        }
    }
}

/// Resolves the Blender executable to run, checking (in order): an explicit
/// `--blender` override, the `BLENDER_BIN` environment variable, the standard
/// macOS app bundle location, and PATH.
func resolveBlenderExecutable(override: String?) throws -> URL {
    if let override {
        return try blenderExecutableURL(at: resolvePath(override).path)
    }
    if let environmentPath = ProcessInfo.processInfo.environment["BLENDER_BIN"], !environmentPath.isEmpty {
        return try blenderExecutableURL(at: resolvePath(environmentPath).path)
    }

    let applicationPath = "/Applications/Blender.app/Contents/MacOS/Blender"
    if FileManager.default.isExecutableFile(atPath: applicationPath) {
        return URL(fileURLWithPath: applicationPath)
    }

    let pathDirectories = ProcessInfo.processInfo.environment["PATH", default: ""]
        .split(separator: ":")
        .map(String.init)
    for directory in pathDirectories {
        let candidate = URL(fileURLWithPath: directory).appendingPathComponent("blender")
        if FileManager.default.isExecutableFile(atPath: candidate.path) {
            return candidate
        }
    }
    throw BlenderResolutionError.blenderNotFound
}

private func blenderExecutableURL(at path: String) throws -> URL {
    guard FileManager.default.isExecutableFile(atPath: path) else {
        throw BlenderResolutionError.blenderNotExecutable(path)
    }
    return URL(fileURLWithPath: path)
}

/// Resolves Blender's own bundled python3 (macOS app bundle layout:
/// `Blender.app/Contents/Resources/<version>/python/bin/python3.x`).
///
/// This is a different interpreter than the system `python3` `resolvePython3()`
/// finds — Blender's exporter script runs inside this bundled interpreter, which
/// has its own separate site-packages. Needed for installing packages (e.g. lz4)
/// that must be importable *inside a running Blender export*, with an ABI-compatible
/// build for whatever Python version this specific Blender bundles.
func resolveBlenderPython3(override: String?) throws -> URL {
    let blenderURL = try resolveBlenderExecutable(override: override)
    // .../Blender.app/Contents/MacOS/Blender -> .../Blender.app/Contents/Resources
    let resourcesDir = blenderURL
        .deletingLastPathComponent() // MacOS
        .deletingLastPathComponent() // Contents
        .appendingPathComponent("Resources", isDirectory: true)

    let fm = FileManager.default
    guard let versionDirs = try? fm.contentsOfDirectory(at: resourcesDir, includingPropertiesForKeys: nil) else {
        throw BlenderResolutionError.blenderPython3NotFound(blenderURL.path)
    }
    // Prefer the newest version directory if more than one is present (e.g. after an update).
    for versionDir in versionDirs.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }) {
        let pythonBinDir = versionDir.appendingPathComponent("python", isDirectory: true).appendingPathComponent("bin", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: pythonBinDir, includingPropertiesForKeys: nil) else { continue }
        for entry in entries where entry.lastPathComponent.hasPrefix("python3") {
            if fm.isExecutableFile(atPath: entry.path) {
                return entry
            }
        }
    }
    throw BlenderResolutionError.blenderPython3NotFound(blenderURL.path)
}

// MARK: - Support Script Resolution

/// Resolves a Blender/Python support script (e.g. `untoldexporter.py`,
/// `texbake.py`, `tilestreamingpartition.py`) by filename, checking (in
/// order): the `UNTOLDENGINE_EXPORTER_DIR` override, the installed libexec
/// location beside the running binary, and `scripts/` in the repo root for
/// `swift run` during development. Throws the caller's own not-installed
/// error, built from the installed-path candidate, if none is found.
func resolveSupportScript(named filename: String, notInstalled: (String) -> Error) throws -> URL {
    if let supportDirectory = ProcessInfo.processInfo.environment["UNTOLDENGINE_EXPORTER_DIR"] {
        let candidate = URL(fileURLWithPath: supportDirectory).appendingPathComponent(filename)
        if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
    }

    let executableURL = Bundle.main.executableURL
        ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    let installedScript = executableURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("libexec/untoldengine/\(filename)")
    if FileManager.default.fileExists(atPath: installedScript.path) {
        return installedScript
    }

    // Supports `swift run` from Tools/UntoldEngineCLI during development.
    let developmentScript = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("../../scripts/\(filename)")
        .standardizedFileURL
    if FileManager.default.fileExists(atPath: developmentScript.path) {
        return developmentScript
    }

    throw notInstalled(installedScript.path)
}

// MARK: - Asset Folder Structure

/// Creates the standard UntoldEngine asset folder structure
/// Matches the structure created by the editor in AssetBrowserView.swift:362-369
func createAssetFolderStructure(at basePath: URL) throws {
    let fm = FileManager.default
    let requiredFolders = ["Models", "Animations", "HDR", "Gaussians", "Materials", "Scenes", "Scripts", "LUT"]

    // Create base directory if it doesn't exist
    if !fm.fileExists(atPath: basePath.path) {
        try fm.createDirectory(at: basePath, withIntermediateDirectories: true, attributes: nil)
        printInfo("Created base directory: \(basePath.path)")
    }

    // Create required subdirectories
    for folder in requiredFolders {
        let folderURL = basePath.appendingPathComponent(folder, isDirectory: true)
        if !fm.fileExists(atPath: folderURL.path) {
            try fm.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            printInfo("Created folder: \(folder)/")
        }
    }
}

/// Validates that an asset path has the expected structure (either GameData/ or the individual folders)
func validateAssetPath(_ url: URL) -> (isValid: Bool, message: String) {
    let fm = FileManager.default

    // Check if path exists
    guard fm.fileExists(atPath: url.path) else {
        return (false, "Path does not exist: \(url.path)")
    }

    // Check if it's a directory
    var isDirectory: ObjCBool = false
    fm.fileExists(atPath: url.path, isDirectory: &isDirectory)
    guard isDirectory.boolValue else {
        return (false, "Path is not a directory: \(url.path)")
    }

    // Check for GameData subdirectory (optional but common)
    let gameDataPath = url.appendingPathComponent("GameData")
    if fm.fileExists(atPath: gameDataPath.path) {
        return (true, "Found GameData directory")
    }

    // Check for required folders (Scenes and Scripts are minimum)
    let scenesPath = url.appendingPathComponent("Scenes")
    let scriptsPath = url.appendingPathComponent("Scripts")

    let hasFolders = fm.fileExists(atPath: scenesPath.path) || fm.fileExists(atPath: scriptsPath.path)

    if hasFolders {
        return (true, "Found asset folder structure")
    }

    // Path exists but doesn't have the structure - we'll create it
    return (true, "Will create asset folder structure")
}

// MARK: - Bundle Identifier Validation

/// Validates a bundle identifier format (e.g., com.company.app)
func validateBundleIdentifier(_ bundleId: String) -> Bool {
    // Bundle ID pattern: reverse domain notation
    let pattern = "^[a-zA-Z0-9]+(\\.[a-zA-Z0-9]+)*$"

    guard let regex = try? NSRegularExpression(pattern: pattern) else {
        return false
    }

    let range = NSRange(bundleId.startIndex..., in: bundleId)
    return regex.firstMatch(in: bundleId, range: range) != nil
}

/// Generates a default bundle identifier from a project name
func generateBundleIdentifier(projectName: String) -> String {
    // Convert project name to lowercase and replace spaces/special chars with dots
    let sanitized = projectName
        .lowercased()
        .replacingOccurrences(of: " ", with: "")
        .filter { $0.isLetter || $0.isNumber }

    return "com.untoldengine.\(sanitized)"
}

// MARK: - GameData Discovery

/// Searches `startingAt` and up to `depth` levels of subdirectories for a `GameData` folder.
/// Skips hidden directories and `.build` to avoid slow traversal of tooling artifacts.
func findGameDataDirectory(startingAt url: URL, depth: Int = 3) -> [URL] {
    let fm = FileManager.default

    let candidate = url.appendingPathComponent("GameData")
    var isDir: ObjCBool = false
    if fm.fileExists(atPath: candidate.path, isDirectory: &isDir), isDir.boolValue {
        return [candidate]
    }

    guard depth > 0,
          let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey])
    else { return [] }

    var results: [URL] = []
    for item in contents {
        let name = item.lastPathComponent
        guard !name.hasPrefix("."), name != "build" else { continue }
        var itemIsDir: ObjCBool = false
        fm.fileExists(atPath: item.path, isDirectory: &itemIsDir)
        if itemIsDir.boolValue {
            results += findGameDataDirectory(startingAt: item, depth: depth - 1)
        }
    }
    return results
}

// MARK: - Interactive Prompts

/// Prompts the user for input with a default value
func prompt(_ message: String, default defaultValue: String? = nil) -> String {
    if let defaultValue {
        print("\(message) [\(defaultValue)]: ", terminator: "")
    } else {
        print("\(message): ", terminator: "")
    }

    if let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines), !input.isEmpty {
        return input
    }

    return defaultValue ?? ""
}

/// Prompts the user for a yes/no confirmation
func confirm(_ message: String, default defaultYes: Bool = false) -> Bool {
    let suffix = defaultYes ? "[Y/n]" : "[y/N]"
    print("\(message) \(suffix): ", terminator: "")

    guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
        return defaultYes
    }

    if input.isEmpty {
        return defaultYes
    }

    return input == "y" || input == "yes"
}
