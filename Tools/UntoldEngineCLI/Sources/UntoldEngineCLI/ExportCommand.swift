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
import UntoldEngine

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

        Gaussian `.ply` inputs skip Blender and export directly to `.untoldgs`.

        Example:
          untoldengine export --input model.usdz --output model.untold --convert-orientation --optimize
          untoldengine export --input model.blend --output model.untold --convert-orientation --optimize
          untoldengine export --input splats.ply --output splats.untoldgs
          untoldengine export --input splats.ply --output splats.untoldgs --lod-levels 4
        """
    )

    @Option(name: .long, help: "Source .usd, .usda, .usdc, .usdz, .blend, or Gaussian .ply asset")
    var input: String

    @Option(name: .long, help: "Destination .untold or .untoldgs file")
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

    @Flag(name: .customLong("bake-color-management"), help: "Bake the scene's active View Transform/Look/Exposure/Gamma into an RGBA16Float LUT targeting canonical sRGB output")
    var bakeColorManagement = false

    @Option(name: .customLong("color-lut-size"), help: "Grid size (N) for the NxNxN color-grading LUT")
    var colorLutSize: Int = 32

    @Option(name: .customLong("lod-levels"), help: "Gaussian .ply export only: number of progressive .untoldgs tiers to generate. Default 1 writes --output directly; values greater than 1 write <name>_lod0.untoldgs, <name>_lod1.untoldgs, ...")
    var lodLevels: Int = 1

    func run() throws {
        let inputURL = resolvePath(input).standardizedFileURL
        let outputURL = resolvePath(output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ExportError.inputNotFound(inputURL.path)
        }

        if inputURL.pathExtension.lowercased() == "ply" {
            guard outputURL.pathExtension.lowercased() == "untoldgs" else {
                throw ExportError.unsupportedPLYExportOutput(outputURL.pathExtension)
            }
            guard lodLevels > 0 else {
                throw ExportError.invalidLODLevels(lodLevels)
            }
            try runGaussianSplatExport(inputURL: inputURL, outputURL: outputURL)
            return
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
        if bakeColorManagement {
            exporterArguments.append("--bake-color-management")
            exporterArguments += ["--color-lut-size", String(colorLutSize)]
        }

        printInfo("Using Blender: \(blenderURL.path)")
        printInfo("Exporting \(inputURL.path)")

        let process = Process()
        process.executableURL = blenderURL
        process.arguments = [
            "--background",
            "--factory-startup",
            // Without this, Blender exits 0 even when the Python script
            // raises an uncaught exception, so a real export failure would
            // otherwise be reported as success.
            "--python-exit-code", "1",
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

    private func runGaussianSplatExport(inputURL: URL, outputURL: URL) throws {
        printInfo("Exporting Gaussian splats \(inputURL.path)")
        let bakeResult = try bakeGaussianSplatProgressiveTiers(
            plyURL: inputURL,
            outputBaseURL: outputURL,
            levelCount: lodLevels
        )
        // meanSquaredSplatExtent is baked into each .untoldgs file and read automatically when
        // the engine loads it — printed here only as a diagnostic (e.g. to compare density
        // across source captures), not something to copy anywhere.
        for tier in bakeResult.tiers {
            printSuccess("Exported: \(tier.url.path) (meanSquaredSplatExtent: \(tier.meanSquaredSplatExtent))")
        }

        // boundingBoxHalfExtent is NOT baked into the files (the engine can auto-compute it for
        // non-streaming loads instead) — pass this into setEntityGaussianProgressive/
        // setEntityGaussianStreaming's boundingBoxHalfExtent if you want it set explicitly, e.g.
        // for the streaming path, which requires a real box before any tier is ever read.
        let halfExtent = (bakeResult.boundingBoxMax - bakeResult.boundingBoxMin) * 0.5
        printInfo("boundingBoxHalfExtent: (\(halfExtent.x), \(halfExtent.y), \(halfExtent.z))")
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
        try resolveBlenderExecutable(override: blender)
    }

    private func resolveExporter() throws -> URL {
        try resolveSupportScript(named: "untoldexporter.py") { ExportError.exporterNotInstalled($0) }
    }
}

enum ExportError: LocalizedError {
    case inputNotFound(String)
    case exporterNotInstalled(String)
    case exportFailed(Int32)
    case optimizeFailed(Int32)
    case unsupportedPLYExportOutput(String)
    case invalidLODLevels(Int)

    var errorDescription: String? {
        switch self {
        case let .inputNotFound(path):
            return "Input asset does not exist: \(path)"
        case let .exporterNotInstalled(path):
            return "Exporter support files were not found. Reinstall the CLI. Expected: \(path)"
        case let .exportFailed(status):
            return "Blender exporter failed with exit status \(status)"
        case let .optimizeFailed(status):
            return "Texture optimization (texbake) failed with exit status \(status)"
        case let .unsupportedPLYExportOutput(pathExtension):
            let suffix = pathExtension.isEmpty ? "<none>" : ".\(pathExtension)"
            return "Gaussian .ply export supports only .untoldgs output, got \(suffix)"
        case let .invalidLODLevels(value):
            return "--lod-levels must be a positive integer, got \(value)"
        }
    }
}
