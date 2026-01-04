//
//  UpdateCommand.swift
//  UntoldEngineCLI
//
//  Command for updating game data in existing projects
//

import AppKit
import ArgumentParser
import Foundation
import UntoldEngine

struct UpdateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "update",
        abstract: "Update game data in an existing project",
        discussion: """
        Updates only the GameData folder in an existing project, preserving any custom code changes.
        This is useful when you've modified scenes, scripts, or assets and want to refresh the built project.

        Examples:
          # Update project in default location
          untoldengine-create update MyGame --asset-path ~/GameAssets

          # Update project at specific path
          untoldengine-create update ~/Projects/MyGame --asset-path ~/GameAssets
        """
    )

    // MARK: - Arguments

    @Argument(help: "Project name or path to the project directory")
    var project: String

    // MARK: - Options

    @Option(name: .long, help: "Path to game assets directory")
    var assetPath: String?

    // MARK: - Execution

    func run() async throws {
        printInfo("🔄 UntoldEngine Project Updater")
        print("")

        // 1. Resolve project path
        let projectURL = resolveProjectPath()

        // 2. Validate project exists
        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw UpdateError.projectNotFound(projectURL.path)
        }

        printInfo("Project: \(projectURL.path)")

        // 3. Resolve and validate asset path
        let assetURL = try resolveAssetPath()

        // 4. Set assetBasePath for BuildSystem
        assetBasePath = assetURL
        printSuccess("Asset base path set: \(assetURL.path)")
        print("")

        // 5. Create minimal build settings for update
        // We need to extract the project name from the path
        let projectName = projectURL.lastPathComponent

        let settings = BuildSettings(
            projectName: projectName,
            bundleIdentifier: "com.temp.placeholder", // Not used for updates
            outputPath: projectURL.deletingLastPathComponent(),
            target: .macOS(deployment: .v15), // Not used for updates
            scenes: [],
            includeDebugInfo: true,
            optimizationLevel: .none,
            teamID: nil,
            isIOSAR: false
        )

        // 6. Run update
        try await runUpdate(settings: settings, projectPath: projectURL)
    }

    // MARK: - Helper Methods

    private func resolveProjectPath() -> URL {
        let resolved = resolvePath(project)

        // If the path doesn't end with the project name (user provided just name),
        // assume it's in the default output directory
        if !resolved.path.contains("/") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let defaultOutput = homeDir.appendingPathComponent("UntoldEngineBuilds")
            return defaultOutput.appendingPathComponent(project)
        }

        return resolved
    }

    private func resolveAssetPath() throws -> URL {
        // If no asset path provided, prompt for it
        guard let assetPathStr = assetPath else {
            printWarning("No asset path provided")
            let input = prompt("Enter path to game assets", default: ".")
            let resolved = resolvePath(input)

            let validation = validateAssetPath(resolved)
            if !validation.isValid {
                throw UpdateError.invalidAssetPath(validation.message)
            }

            return resolved
        }

        // Resolve the provided path
        let resolved = resolvePath(assetPathStr)

        // Validate
        let validation = validateAssetPath(resolved)
        if !validation.isValid {
            throw UpdateError.invalidAssetPath(validation.message)
        }

        return resolved
    }

    private func runUpdate(settings: BuildSettings, projectPath: URL) async throws {
        printInfo("🔄 Updating game data...")
        print("")

        do {
            let result = try await BuildSystem.shared.updateGameData(settings: settings) { progress in
                printProgress(progress)
            }

            print("")
            printSuccess("Update completed in \(String(format: "%.2f", result.updateTime))s")
            printInfo("Updated \(result.updatedAssets.count) assets")
            print("")

            // Offer to open in Xcode
            let xcodeProjectPath = projectPath.appendingPathComponent("\(settings.projectName).xcodeproj")
            if confirm("Open project in Xcode?", default: false) {
                NSWorkspace.shared.open(xcodeProjectPath)
            }

        } catch {
            print("")
            throw UpdateError.updateFailed(error.localizedDescription)
        }
    }
}

// MARK: - Update Errors

enum UpdateError: LocalizedError {
    case projectNotFound(String)
    case invalidAssetPath(String)
    case updateFailed(String)

    var errorDescription: String? {
        switch self {
        case let .projectNotFound(path):
            return "Project not found: \(path)"
        case let .invalidAssetPath(message):
            return "Invalid asset path: \(message)"
        case let .updateFailed(message):
            return "Update failed: \(message)"
        }
    }
}
