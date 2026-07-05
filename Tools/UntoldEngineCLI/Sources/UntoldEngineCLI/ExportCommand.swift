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

        Example:
          untoldengine export --input model.usdz --output model.untold --convert-orientation --compress-geometry
          untoldengine export --input model.blend --output model.untold --convert-orientation --compress-geometry
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

    func run() throws {
        let inputURL = resolvePath(input).standardizedFileURL
        let outputURL = resolvePath(output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ExportError.inputNotFound(inputURL.path)
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
        if compressGeometry { exporterArguments.append("--compress-geometry") }
        if animation { exporterArguments.append("--animation") }

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

    var errorDescription: String? {
        switch self {
        case let .inputNotFound(path):
            return "Input asset does not exist: \(path)"
        case .blenderNotFound:
            return "Blender was not found. Install Blender, use --blender, or set BLENDER_BIN."
        case let .blenderNotExecutable(path):
            return "Blender is not executable at: \(path)"
        case let .exporterNotInstalled(path):
            return "Exporter support files were not found. Reinstall the CLI. Expected: \(path)"
        case let .exportFailed(status):
            return "Blender exporter failed with exit status \(status)"
        }
    }
}
