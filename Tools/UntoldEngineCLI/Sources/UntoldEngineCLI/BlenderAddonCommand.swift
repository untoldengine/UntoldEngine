//
//  BlenderAddonCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation

struct BlenderAddonCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "blender-addon",
        abstract: "Package the Blender add-on into an installable zip",
        discussion: """
        Runs scripts/untold-blender-addon/package.sh, which bundles the
        add-on source with fresh vendored copies of the exporter scripts
        (untoldexplorer.py, texbake.py, tilestreamingpartition.py) into
        scripts/untold-blender-addon/build/untold_exporter.zip.

        This is an engine-repo tool: run it from the UntoldEngine repository
        root, the same way you'd run `swift build`.

        Example:
          untoldengine blender-addon
        """
    )

    func run() throws {
        let packageScript = resolvePath("scripts/untold-blender-addon/package.sh")
        guard FileManager.default.fileExists(atPath: packageScript.path) else {
            throw BlenderAddonError.scriptNotFound(packageScript.path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [packageScript.path]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw BlenderAddonError.packagingFailed(process.terminationStatus)
        }
    }
}

enum BlenderAddonError: LocalizedError {
    case scriptNotFound(String)
    case packagingFailed(Int32)

    var errorDescription: String? {
        switch self {
        case let .scriptNotFound(path):
            return "Could not find \(path). Run this command from the UntoldEngine repository root."
        case let .packagingFailed(status):
            return "Packaging the Blender add-on failed with exit status \(status)"
        }
    }
}
