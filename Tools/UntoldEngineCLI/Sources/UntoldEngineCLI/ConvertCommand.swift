//
//  ConvertCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  ConvertCommand.swift
//  UntoldEngineCLI
//
//  Moves an existing project from the legacy layout (GameData nested under
//  Sources/<Project>/GameData) to the root-level one (GameData, Resources and
//  Docs at the project root).
//

import ArgumentParser
import Foundation
import UntoldEngine

struct ConvertCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Move a project from the legacy GameData layout to the root-level one",
        discussion: """
        Moves GameData from Sources/<Project>/GameData to the project root, creates empty
        Resources/ and Docs/ folders there, writes a .gitignore if the project doesn't have
        one yet, and rewrites project.yml (regenerating the Xcode project with xcodegen).

        Refuses to run if the project is already on the root-level layout, or if GameData
        isn't where the legacy layout expects it.

        Examples:
          # Convert the project in the current directory
          untoldengine convert MyGame

          # Convert a project at a specific path
          untoldengine convert ~/Projects/MyGame
        """
    )

    // MARK: - Arguments

    @Argument(help: "Project name or path to the project directory")
    var project: String

    // MARK: - Execution

    func run() async throws {
        printInfo("🔁 UntoldEngine Project Layout Converter")
        print("")

        let projectURL = resolveProjectPath()

        guard FileManager.default.fileExists(atPath: projectURL.path) else {
            throw ConvertError.projectNotFound(projectURL.path)
        }

        printInfo("Project: \(projectURL.path)")
        print("")

        do {
            let result = try BuildSystem.shared.convertProjectLayout(
                projectRoot: projectURL,
                projectName: projectURL.lastPathComponent
            ) { message in
                printProgress(message)
            }

            print("")
            printSuccess("Converted \(result.projectRoot.lastPathComponent) to the root-level layout")
        } catch {
            print("")
            throw ConvertError.conversionFailed(error.localizedDescription)
        }
    }

    // MARK: - Helper Methods

    private func resolveProjectPath() -> URL {
        let resolved = resolvePath(project)

        // If the path doesn't end with the project name (user provided just name),
        // assume it's in the default output directory, same convention as `update`.
        if !resolved.path.contains("/") {
            let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let defaultOutput = homeDir.appendingPathComponent("UntoldEngineBuilds")
            return defaultOutput.appendingPathComponent(project)
        }

        return resolved
    }
}

// MARK: - Convert Errors

enum ConvertError: LocalizedError {
    case projectNotFound(String)
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .projectNotFound(path):
            return "Project not found: \(path)"
        case let .conversionFailed(message):
            return "Conversion failed: \(message)"
        }
    }
}
