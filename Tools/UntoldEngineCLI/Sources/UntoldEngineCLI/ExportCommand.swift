//
//  ExportCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation

struct ExportCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export",
        abstract: "Convert a USD/USDZ asset or .blend file to UntoldEngine's .untold format",
        discussion: """
        Runs the UntoldEngine exporter through Blender. Input and output paths
        may be absolute or relative to the current directory.

        --optimize compresses geometry and, if the export produced a Textures
        directory, bakes those textures to .utex and patches the .untold
        references — equivalent to running --compress-geometry followed by
        `untoldengine texbake --dir` and `untoldengine texbake --patch-refs`.

        Example:
          untoldengine export --input model.usdz --output model.untold --convert-orientation --optimize
          untoldengine export --input model.blend --output model.untold --convert-orientation --optimize
        """
    )

    @Option(name: .long, help: "Source .usd, .usda, .usdc, .usdz, or .blend asset")
    var input: String

    @Option(name: .long, help: "Destination .untold file")
    var output: String

    @Option(name: .long, help: "Override the Blender executable path")
    var blender: String?

    @Option(name: .long, help: "Untold file type (tile, lod, hlod, shared, animation)")
    var fileType: String = "tile"

    @Option(name: .long, help: "Export only this mesh from a multi-mesh asset")
    var meshName: String?

    @Flag(name: .customLong("convert-orientation"), help: "Convert data into UntoldEngine orientation (+Z forward, +Y up)")
    var convertOrientation = false

    @Option(name: .long, help: "Input orientation (blender-native or engine-oriented)")
    var sourceOrientation: String = "blender-native"

    @Flag(name: .long, help: "Write a companion validation JSON file")
    var validate = false

    @Flag(name: .long, help: "LZ4-compress vertex and index chunks")
    var compressGeometry = false

    @Flag(name: .long, help: "Export animation clips without mesh geometry")
    var animation = false

    @Flag(name: .long, help: "Compress geometry and bake/patch textures after export (implies --compress-geometry)")
    var optimize = false

    @Flag(name: .customLong("bake-materials"), help: "Bake node-graph materials the engine cannot evaluate (Mix, Math, procedural textures, ...) into flat textures so the export matches Blender")
    var bakeMaterials = false

    @Option(name: .customLong("bake-resolution"), help: "Square resolution for baked material textures (max: \(ExportCommand.maxBakeResolution)). Override per material via a material['untold_bake_resolution'] custom property")
    var bakeResolution: Int = 1024

    @Flag(name: .customLong("no-bake-cache"), help: "Disable the persistent bake cache and force every divergent material to be re-baked, even if unchanged since the last export")
    var noBakeCache = false

    /// Keep in sync with MAX_BAKE_RESOLUTION in scripts/untoldexplorer.py.
    static let maxBakeResolution = 8192

    func run() throws {
        let inputURL = resolvePath(input).standardizedFileURL
        let outputURL = resolvePath(output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ExportError.inputNotFound(inputURL.path)
        }
        guard bakeResolution > 0 else {
            throw ExportError.invalidBakeResolution(bakeResolution)
        }
        let clampedBakeResolution = min(bakeResolution, Self.maxBakeResolution)
        if clampedBakeResolution != bakeResolution {
            printInfo("--bake-resolution \(bakeResolution) is very high; clamping to \(clampedBakeResolution).")
        }

        let blenderURL = try resolveBlender()
        let exporterURL = try resolveExporter()

        var exporterArguments = [
            "--input", inputURL.path,
            "--output", outputURL.path,
            "--file-type", fileType,
            "--source-orientation", sourceOrientation,
        ]
        if let meshName { exporterArguments += ["--mesh-name", meshName] }
        if convertOrientation { exporterArguments.append("--convert-orientation") }
        if validate { exporterArguments.append("--validate") }
        if compressGeometry || optimize { exporterArguments.append("--compress-geometry") }
        if animation { exporterArguments.append("--animation") }
        if bakeMaterials {
            exporterArguments.append("--bake-materials")
            exporterArguments += ["--bake-resolution", String(clampedBakeResolution)]
            if noBakeCache { exporterArguments.append("--no-bake-cache") }
        }

        printInfo("Using Blender: \(blenderURL.path)")
        printInfo("Exporting \(inputURL.path)")

        let process = Process()
        process.executableURL = blenderURL
        process.arguments = [
            "--background",
            "--factory-startup",
            "--python", exporterURL.path,
            "--",
        ] + exporterArguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportError.exportFailed(process.terminationStatus)
        }
        printSuccess("Exported: \(outputURL.path)")

        if optimize {
            try optimizeTextures(outputURL: outputURL)
        }
    }

    private func optimizeTextures(outputURL: URL) throws {
        let texturesDir = outputURL.deletingLastPathComponent().appendingPathComponent("Textures")
        guard validateDirectory(texturesDir) else {
            printInfo("No Textures directory found beside the output; skipping texture optimization.")
            return
        }

        let python3URL = try resolvePython3()
        let texbakeScriptURL = try resolveTexbakeScript()

        printInfo("Baking textures: \(texturesDir.path)")
        try runPython(python3URL, [texbakeScriptURL.path, "--dir", texturesDir.path])

        printInfo("Patching texture references: \(outputURL.path)")
        try runPython(python3URL, [texbakeScriptURL.path, "--patch-refs", outputURL.path])

        printSuccess("Optimized textures: \(texturesDir.path)")
    }

    private func runPython(_ python3URL: URL, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = python3URL
        process.arguments = arguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExportError.optimizeFailed(process.terminationStatus)
        }
    }

    private func resolveBlender() throws -> URL {
        if let blender {
            return try executableURL(at: resolvePath(blender).path)
        }
        if let environmentPath = ProcessInfo.processInfo.environment["BLENDER_BIN"], !environmentPath.isEmpty {
            return try executableURL(at: resolvePath(environmentPath).path)
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
        throw ExportError.blenderNotFound
    }

    private func executableURL(at path: String) throws -> URL {
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw ExportError.blenderNotExecutable(path)
        }
        return URL(fileURLWithPath: path)
    }

    private func resolveExporter() throws -> URL {
        if let supportDirectory = ProcessInfo.processInfo.environment["UNTOLDENGINE_EXPORTER_DIR"] {
            let candidate = URL(fileURLWithPath: supportDirectory).appendingPathComponent("untoldexporter.py")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }

        let executableURL = Bundle.main.executableURL
            ?? URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let installedExporter = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("libexec/untoldengine/untoldexporter.py")
        if FileManager.default.fileExists(atPath: installedExporter.path) {
            return installedExporter
        }

        // Supports `swift run` from Tools/UntoldEngineCLI during development.
        let developmentExporter = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("../../scripts/untoldexporter.py")
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: developmentExporter.path) {
            return developmentExporter
        }

        throw ExportError.exporterNotInstalled(installedExporter.path)
    }
}

enum ExportError: LocalizedError {
    case inputNotFound(String)
    case blenderNotFound
    case blenderNotExecutable(String)
    case exporterNotInstalled(String)
    case exportFailed(Int32)
    case optimizeFailed(Int32)
    case invalidBakeResolution(Int)

    var errorDescription: String? {
        switch self {
        case let .inputNotFound(path):
            return "Input asset does not exist: \(path)"
        case .blenderNotFound:
            return """
            Blender was not found. Download it from https://www.blender.org/download/ \
            (tested with Blender 5.1.0), then use --blender /path/to/Blender or set BLENDER_BIN.
            """
        case let .blenderNotExecutable(path):
            return "Blender is not executable at: \(path)"
        case let .exporterNotInstalled(path):
            return "Exporter support files were not found. Reinstall the CLI. Expected: \(path)"
        case let .exportFailed(status):
            return "Blender exporter failed with exit status \(status)"
        case let .optimizeFailed(status):
            return "Texture optimization (texbake) failed with exit status \(status)"
        case let .invalidBakeResolution(value):
            return "--bake-resolution must be a positive integer, got \(value)"
        }
    }
}
