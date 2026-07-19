//
//  TexbakeCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation

struct TexbakeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "texbake",
        abstract: "Bake source textures into UntoldEngine .utex files",
        discussion: """
        Converts one image or a directory of images to ASTC-compressed .utex
        files, or patches .untold texture references after baking.

        Examples:
          untoldengine texbake --input Textures/wall_normal.png
          untoldengine texbake --dir Textures
          untoldengine texbake --patch-refs model.untold
        """
    )

    @Option(name: .long, help: "Source PNG, JPEG, TGA, or BMP image")
    var input: String?

    @Option(name: .long, help: "Destination .utex path (defaults beside the input)")
    var output: String?

    @Option(name: .long, help: "Texture slot override")
    var slot: String?

    @Option(name: .long, help: "Bake all supported images in this directory")
    var dir: String?

    @Option(name: .long, help: "Quality: fastest, fast, medium, thorough, or exhaustive")
    var quality: String = "thorough"

    @Flag(name: .long, help: "Retain intermediate files")
    var keepTemp = false

    @Option(name: .long, help: "Patch one .untold file or all .untold files in a directory")
    var patchRefs: String?

    func run() throws {
        guard input != nil || dir != nil || patchRefs != nil else {
            throw ValidationError("Provide --input, --dir, or --patch-refs.")
        }
        let selectedModes = [input != nil, dir != nil, patchRefs != nil].filter { $0 }.count
        guard selectedModes == 1 else {
            throw ValidationError("Use only one of --input, --dir, or --patch-refs at a time.")
        }

        var arguments = try [resolveTexbakeScript().path]
        if let input { arguments += ["--input", resolvePath(input).standardizedFileURL.path] }
        if let output { arguments += ["--output", resolvePath(output).standardizedFileURL.path] }
        if let slot { arguments += ["--slot", slot] }
        if let dir { arguments += ["--dir", resolvePath(dir).standardizedFileURL.path] }
        arguments += ["--quality", quality]
        if keepTemp { arguments.append("--keep-temp") }
        if let patchRefs { arguments += ["--patch-refs", resolvePath(patchRefs).standardizedFileURL.path] }

        let process = Process()
        process.executableURL = try resolvePython3()
        process.arguments = arguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw TexbakeError.failed(process.terminationStatus)
        }
    }
}

/// Shared with ExportCommand's --optimize, which also needs to run texbake.py.
func resolvePython3() throws -> URL {
    if let override = ProcessInfo.processInfo.environment["PYTHON3_BIN"], !override.isEmpty {
        let path = resolvePath(override).path
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw TexbakeError.pythonNotExecutable(path)
        }
        return URL(fileURLWithPath: path)
    }

    for directory in ProcessInfo.processInfo.environment["PATH", default: ""].split(separator: ":") {
        let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent("python3")
        if FileManager.default.isExecutableFile(atPath: candidate.path) { return candidate }
    }
    throw TexbakeError.pythonNotFound
}

func resolveTexbakeScript() throws -> URL {
    try resolveSupportScript(named: "texbake.py") { TexbakeError.notInstalled($0) }
}

enum TexbakeError: LocalizedError {
    case pythonNotFound
    case pythonNotExecutable(String)
    case notInstalled(String)
    case failed(Int32)

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "python3 was not found on PATH. Install Python 3 or set PYTHON3_BIN."
        case let .pythonNotExecutable(path):
            return "Python is not executable at: \(path)"
        case let .notInstalled(path):
            return "Texture baker support file was not found. Reinstall the CLI. Expected: \(path)"
        case let .failed(status):
            return "Texture baker failed with exit status \(status)"
        }
    }
}
