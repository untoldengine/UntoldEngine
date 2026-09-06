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
import simd
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
        The --splat-* flags register the capture onto its mesh twin (up axis,
        scale, yaw, translation), crop away floaters and the
        captured floor, drop near-transparent splats, and pick the
        spherical-harmonics degree and chunk size. Values that start with a
        minus sign must use the --option=value form.

        Example:
          untoldengine export --input model.usdz --output model.untold --convert-orientation --optimize
          untoldengine export --input model.blend --output model.untold --convert-orientation --optimize
          untoldengine export --input splats.ply --output splats.untoldgs
          untoldengine export --input splats.ply --output splats.untoldgs --lod-levels 4
          untoldengine export --input sofa.ply --output sofa.untoldgs --splat-up-axis z \\
            --splat-scale 0.5 --splat-translate 0,0.4,0 --splat-crop=-1,0,-1,1,1.2,1 --splat-sh-degree 2
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

    @Option(name: .customLong("color-grade-lut"), help: "Path to an externally-authored standard .cube 3D LUT to stage and apply as a post-tonemap creative grade. Nothing is rendered from Blender -- the .cube is copied as-is and loaded directly by the engine")
    var colorGradeLUT: String?

    @Option(name: .customLong("lod-levels"), help: "Gaussian .ply export only: number of progressive .untoldgs tiers to generate. Default 1 writes --output directly; values greater than 1 write <name>_lod0.untoldgs, <name>_lod1.untoldgs, ...")
    var lodLevels: Int = 1

    @Option(name: .customLong("splat-chunk-splats"), help: "Gaussian .ply export only: splats per chunk, a power of two between 2 and 16384 (1024 for objects, 4096 for environments)")
    var splatChunkSplats: Int = 1024

    @Option(name: .customLong("splat-sh-degree"), help: "Gaussian .ply export only: spherical-harmonics degree to keep, 0...3 (default: the source degree)")
    var splatSHDegree: Int?

    @Option(name: .customLong("splat-min-opacity"), help: "Gaussian .ply export only: drop splats with a lower opacity")
    var splatMinOpacity: Float = 0.005

    @Option(name: .customLong("splat-max-count"), help: "Gaussian .ply export only: keep at most this many splats, the most important by opacity and size (0 = no limit). The runtime loads at most \(UntoldGSCookOptions.splatBudgetMobile) per entity on Vision Pro, iPhone, iPad and Apple TV and \(UntoldGSCookOptions.splatBudgetMac) on the Mac.")
    var splatMaxCount: Int = 0

    @Option(name: .customLong("splat-crop"), help: "Gaussian .ply export only: crop box in the output space, minX,minY,minZ,maxX,maxY,maxZ")
    var splatCrop: String?

    @Option(name: .customLong("splat-crop-margin"), help: "Gaussian .ply export only: grow the crop box on every side, in metres")
    var splatCropMargin: Float = 0

    @Option(name: .customLong("splat-scale"), help: "Gaussian .ply export only: uniform scale applied to the capture")
    var splatScale: Float = 1

    @Option(name: .customLong("splat-yaw-degrees"), help: "Gaussian .ply export only: rotation about +Y applied after --splat-flip-yz, in degrees")
    var splatYawDegrees: Float = 0

    @Option(name: .customLong("splat-translate"), help: "Gaussian .ply export only: translation applied after rotation and scale, x,y,z")
    var splatTranslate: String?

    @Option(name: .customLong("splat-up-axis"), help: "Gaussian .ply export only: which axis points up in the capture: y (engine convention, default), z (scanner/CAD, rotated to Y-up), or -y (3DGS training convention)")
    var splatUpAxis: String = "y"

    @Flag(name: .customLong("splat-flip-yz"), help: "Gaussian .ply export only: same as --splat-up-axis=-y")
    var splatFlipYZ = false

    @Flag(name: .customLong("splat-environment"), help: "Gaussian .ply export only: cook as an environment payload")
    var splatEnvironment = false

    @Flag(name: .customLong("splat-antialiased"), help: "Gaussian .ply export only: mark the payload as cooked with the anti-aliased (3D smoothing) convention")
    var splatAntialiased = false

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
            try runGaussianSplatExport(inputURL: inputURL, outputURL: outputURL, cookOptions: makeSplatCookOptions())
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
        if let colorGradeLUT {
            let lutURL = resolvePath(colorGradeLUT).standardizedFileURL
            guard FileManager.default.fileExists(atPath: lutURL.path) else {
                throw ExportError.colorGradeLUTNotFound(lutURL.path)
            }
            exporterArguments += ["--color-grade-lut", lutURL.path]
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

    private func runGaussianSplatExport(inputURL: URL, outputURL: URL, cookOptions: UntoldGSCookOptions) throws {
        printInfo("Exporting Gaussian splats \(inputURL.path)")
        let bakeResult: GaussianProgressiveBakeResult
        do {
            bakeResult = try bakeGaussianSplatProgressiveTiers(
                plyURL: inputURL,
                outputBaseURL: outputURL,
                levelCount: lodLevels,
                cookOptions: cookOptions
            )
        } catch let error as UntoldGSCookError {
            throw ExportError.splatCookFailed(error.description)
        }
        let report = bakeResult.cookReport
        printInfo("Splats: \(report.keptSplatCount) of \(report.inputSplatCount) kept "
            + "(opacity \(report.prunedByOpacity), degenerate \(report.prunedByDegenerateGeometry), crop \(report.prunedByCrop), budget \(report.prunedByBudget)), "
            + "SH degree \(report.shDegree), \(splatChunkSplats) splats per chunk")
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

    // MARK: - Gaussian cooking flags

    /// `--validate` already occupies the `validate` name on this command, so flag checks run
    /// here and surface as `ExportError.invalidSplatFlag` with their own message.
    private func makeSplatCookOptions() throws -> UntoldGSCookOptions {
        guard splatChunkSplats >= 2, splatChunkSplats <= 16384, splatChunkSplats & (splatChunkSplats - 1) == 0 else {
            throw ExportError.invalidSplatFlag("--splat-chunk-splats must be a power of two between 2 and 16384")
        }
        if let splatSHDegree, !(0 ... 3).contains(splatSHDegree) {
            throw ExportError.invalidSplatFlag("--splat-sh-degree must be between 0 and 3")
        }
        guard splatScale > 0 else {
            throw ExportError.invalidSplatFlag("--splat-scale must be positive")
        }

        var options = UntoldGSCookOptions()
        options.log2ChunkSplats = UInt8(splatChunkSplats.trailingZeroBitCount)
        options.shDegree = splatSHDegree.map { UInt8($0) }
        options.minimumOpacity = splatMinOpacity
        guard splatMaxCount >= 0 else {
            throw ExportError.invalidSplatFlag("--splat-max-count must be zero or positive")
        }
        options.maxSplatCount = splatMaxCount > 0 ? splatMaxCount : nil
        options.cropMargin = splatCropMargin
        options.isEnvironment = splatEnvironment
        options.antialiased = splatAntialiased
        if let splatCrop {
            let values = try parseFloats(splatCrop, count: 6, option: "--splat-crop")
            options.cropMin = SIMD3<Float>(values[0], values[1], values[2])
            options.cropMax = SIMD3<Float>(values[3], values[4], values[5])
        }

        guard let upAxis = UntoldGSCaptureUpAxis(rawValue: splatUpAxis.lowercased()) else {
            throw ExportError.invalidSplatUpAxis(splatUpAxis)
        }
        var translation = SIMD3<Float>.zero
        if let splatTranslate {
            let values = try parseFloats(splatTranslate, count: 3, option: "--splat-translate")
            translation = SIMD3<Float>(values[0], values[1], values[2])
        }
        options.transform = UntoldGSCookOptions.transform(
            upAxis: splatFlipYZ ? .negativeY : upAxis,
            scale: splatScale,
            yawDegrees: splatYawDegrees,
            translation: translation
        )
        return options
    }

    private func parseFloats(_ text: String, count: Int, option: String) throws -> [Float] {
        let values = text.split(separator: ",").map { Float($0.trimmingCharacters(in: .whitespaces)) }
        guard values.count == count, !values.contains(nil) else {
            throw ExportError.invalidSplatFlag("\(option) expects \(count) comma-separated numbers")
        }
        return values.compactMap(\.self)
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
    case colorGradeLUTNotFound(String)
    case splatCookFailed(String)
    case invalidSplatUpAxis(String)
    case invalidSplatFlag(String)

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
        case let .colorGradeLUTNotFound(path):
            return "--color-grade-lut path does not exist: \(path)"
        case let .splatCookFailed(reason):
            return "Gaussian splat cook failed: \(reason)"
        case let .invalidSplatUpAxis(value):
            return "--splat-up-axis must be y, z or -y, got \(value)"
        case let .invalidSplatFlag(reason):
            return reason
        }
    }
}
