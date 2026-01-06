//
//  CreateCommand.swift
//  UntoldEngineCLI
//
//  Command for creating new UntoldEngine game projects
//

import AppKit
import ArgumentParser
import Foundation
import UntoldEngine

struct CreateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new UntoldEngine game project",
        discussion: """
        Creates a new game project with the specified platform and configuration.
        The project structure will be created in the current directory.

        Examples:
          # Create macOS project (in current directory)
          mkdir MyGame && cd MyGame
          untoldengine-create create MyGame

          # Create iOS project with custom bundle ID
          mkdir MobileGame && cd MobileGame
          untoldengine-create create MobileGame --platform ios --bundle-id com.company.game

          # Create visionOS project with custom output location
          untoldengine-create create VRGame --platform visionos --output ~/Projects
        """
    )

    // MARK: - Arguments

    @Argument(help: "Name of the project to create")
    var projectName: String

    // MARK: - Options

    @Option(name: .shortAndLong, help: "Target platform (macos, ios, ios-ar, visionos)")
    var platform: String = "macos"

    @Option(name: .long, help: "Bundle identifier (e.g., com.company.game)")
    var bundleId: String?

    @Option(name: .shortAndLong, help: "Output directory (default: current directory)")
    var output: String?

    @Option(name: .long, help: "macOS deployment version (13, 14, 15)")
    var macosVersion: String = "15"

    @Option(name: .long, help: "iOS deployment version (16, 17, 18)")
    var iosVersion: String = "17"

    @Option(name: .long, help: "visionOS deployment version (1, 2)")
    var visionosVersion: String = "2"

    @Option(name: .long, help: "Apple Developer Team ID for code signing")
    var teamId: String?

    @Option(name: .long, help: "Optimization level (none, speed, size)")
    var optimization: String = "none"

    @Flag(name: .long, inversion: .prefixedNo, help: "Include debug information")
    var debug: Bool = true

    // MARK: - Execution

    func run() async throws {
        printInfo("🎮 UntoldEngine Project Creator")
        printInfo("Creating project: \(projectName)")
        print("")

        // 1. Resolve output directory (default: current directory)
        let outputURL = resolveOutputDirectory()

        // 2. Generate and validate bundle identifier
        let finalBundleId = bundleId ?? generateBundleIdentifier(projectName: projectName)
        guard validateBundleIdentifier(finalBundleId) else {
            throw CLIError.invalidBundleIdentifier(finalBundleId)
        }

        // 3. Create build settings
        let settings = try createBuildSettings(
            outputURL: outputURL,
            bundleId: finalBundleId
        )

        // 4. Calculate where GameData will be created by BuildSystem
        let projectDir = outputURL.appendingPathComponent(projectName)
        let gameDataPath = projectDir
            .appendingPathComponent("Sources")
            .appendingPathComponent(projectName)
            .appendingPathComponent("GameData")

        // 5. Set assetBasePath to the GameData location
        // BuildSystem will create the folder structure here when it bundles assets
        assetBasePath = gameDataPath

        // 6. Show configuration summary
        printConfigurationSummary(settings: settings, projectDir: projectDir, gameDataPath: gameDataPath)

        // 7. Run build
        try await runBuild(settings: settings, gameDataPath: gameDataPath)
    }

    // MARK: - Helper Methods

    private func resolveOutputDirectory() -> URL {
        if let outputStr = output {
            return resolvePath(outputStr)
        }

        // Default: current directory
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private func createBuildSettings(outputURL: URL, bundleId: String) throws -> BuildSettings {
        // Parse platform
        let buildTarget: BuildTarget
        var isIOSAR = false

        switch platform.lowercased() {
        case "macos":
            let version = parseMacOSVersion(macosVersion)
            buildTarget = .macOS(deployment: version)

        case "ios":
            let version = parseIOSVersion(iosVersion)
            buildTarget = .iOS(deployment: version)

        case "ios-ar":
            let version = parseIOSVersion(iosVersion)
            buildTarget = .iOS(deployment: version)
            isIOSAR = true

        case "visionos":
            let version = parseVisionOSVersion(visionosVersion)
            buildTarget = .visionOS(deployment: version)

        default:
            throw CLIError.invalidPlatform(platform)
        }

        // Parse optimization
        let optimizationLevel: OptimizationLevel
        switch optimization.lowercased() {
        case "none":
            optimizationLevel = .none
        case "speed":
            optimizationLevel = .speed
        case "size":
            optimizationLevel = .size
        default:
            throw CLIError.invalidOptimization(optimization)
        }

        return BuildSettings(
            projectName: projectName,
            bundleIdentifier: bundleId,
            outputPath: outputURL,
            target: buildTarget,
            scenes: [],
            includeDebugInfo: debug,
            optimizationLevel: optimizationLevel,
            teamID: teamId,
            isIOSAR: isIOSAR
        )
    }

    private func parseMacOSVersion(_ version: String) -> MacOSVersion {
        switch version {
        case "13", "13.0":
            return .v13
        case "14", "14.0":
            return .v14
        case "15", "15.0":
            return .v15
        default:
            return .v15
        }
    }

    private func parseIOSVersion(_ version: String) -> IOSVersion {
        switch version {
        case "16", "16.0":
            return .v16
        case "17", "17.0":
            return .v17
        case "18", "18.0":
            return .v18
        default:
            return .v17
        }
    }

    private func parseVisionOSVersion(_ version: String) -> VisionOSVersion {
        switch version {
        case "1", "1.0":
            return .v1
        case "2", "2.0":
            return .v2
        case "26", "26.0":
            return .v26
        default:
            return .v26
        }
    }

    private func printConfigurationSummary(settings: BuildSettings, projectDir: URL, gameDataPath: URL) {
        print("📋 Configuration:")
        print("   Project Name:    \(settings.projectName)")
        print("   Bundle ID:       \(settings.bundleIdentifier)")
        print("   Platform:        \(settings.target.platformName) \(settings.target.deploymentTarget)")
        if settings.isIOSAR {
            print("   AR Support:      Enabled")
        }
        print("   Project Dir:     \(projectDir.path)")
        print("   GameData Path:   \(gameDataPath.path)")
        print("   Optimization:    \(settings.optimizationLevel.rawValue)")
        print("   Debug Info:      \(settings.includeDebugInfo ? "Yes" : "No")")
        if let teamID = settings.teamID {
            print("   Team ID:         \(teamID)")
        }
        print("")
    }

    private func runBuild(settings: BuildSettings, gameDataPath: URL) async throws {
        printInfo("🔨 Starting build process...")
        print("")

        do {
            let result = try await BuildSystem.shared.build(settings: settings) { progress in
                printProgress(progress)
            }

            print("")
            printSuccess("Build completed in \(String(format: "%.2f", result.buildTime))s")
            printSuccess("Project created at: \(result.xcodeProjectPath.deletingLastPathComponent().path)")
            printInfo("Bundled \(result.bundledAssets.count) assets")
            print("")
            printInfo("📁 Add your game assets to: \(gameDataPath.path)")
            print("")

            // Offer to open in Xcode
            if confirm("Open project in Xcode?", default: true) {
                NSWorkspace.shared.open(result.xcodeProjectPath)
            }

        } catch {
            print("")
            throw CLIError.buildFailed(error.localizedDescription)
        }
    }
}

// MARK: - CLI Errors

enum CLIError: LocalizedError {
    case invalidBundleIdentifier(String)
    case invalidPlatform(String)
    case invalidOptimization(String)
    case buildFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidBundleIdentifier(bundleId):
            return "Invalid bundle identifier: \(bundleId). Use format: com.company.app"
        case let .invalidPlatform(platform):
            return "Invalid platform: \(platform). Valid options: macos, ios, ios-ar, visionos"
        case let .invalidOptimization(opt):
            return "Invalid optimization: \(opt). Valid options: none, speed, size"
        case let .buildFailed(message):
            return "Build failed: \(message)"
        }
    }
}
