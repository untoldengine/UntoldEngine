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

// MARK: - Asset Folder Structure

/// Creates the standard UntoldEngine asset folder structure
/// Matches the structure created by the editor in AssetBrowserView.swift:362-369
func createAssetFolderStructure(at basePath: URL) throws {
    let fm = FileManager.default
    let requiredFolders = ["Models", "Animations", "HDR", "Gaussians", "Materials", "Scenes", "Scripts"]

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
