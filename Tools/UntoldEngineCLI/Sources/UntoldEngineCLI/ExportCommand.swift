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

        Gaussian `.ply` or `.spz` inputs skip Blender and export directly to
        `.untoldgs`. `.spz` support is limited to legacy gzip versions 2-3;
        newer v4 (NGSP/ZSTD) files are rejected with a clear error --
        re-export from the source tool as v2/v3, or convert through `.ply`.
        The --splat-* flags register the capture onto its mesh twin (up axis,
        scale, yaw, translation), crop away floaters and the
        captured floor, drop near-transparent splats, and pick the
        spherical-harmonics degree and chunk size. Values that start with a
        minus sign must use the --option=value form.

        --animation exports clip data only (no mesh) to a `.untoldanim` file --
        a plain `.untold` container under the hood, but named distinctly so it's
        never mistaken for a mesh (setEntityMeshAsync rejects it; use
        setEntityAnimations instead).

        If the source .blend scene contains more than one independent model
        (more than one object with no parent among the exported objects), the
        exporter writes a <name>.untoldpack manifest next to --output instead
        of a single .untold file, plus one self-contained .untold per model
        under its own subfolder. --optimize bakes textures for every model
        in the pack.

        Example:
          untoldengine export --input model.usdz --output model.untold --convert-orientation --optimize
          untoldengine export --input model.blend --output model.untold --convert-orientation --optimize
          untoldengine export --input model.blend --output walk.untoldanim --animation
          untoldengine export --input splats.ply --output splats.untoldgs
          untoldengine export --input splats.ply --output splats.untoldgs --lod-levels 4
          untoldengine export --input capture.spz --output capture.untoldgs
          untoldengine export --input sofa.ply --output sofa.untoldgs --splat-up-axis z \\
            --splat-scale 0.5 --splat-translate 0,0.4,0 --splat-crop=-1,0,-1,1,1.2,1 --splat-sh-degree 2
        """
    )

    @Option(name: .long, help: "Source .usd, .usda, .usdc, .usdz, .blend, or Gaussian .ply/.spz asset")
    var input: String

    @Option(name: .long, help: "Destination .untold, .untoldanim (with --animation), or .untoldgs file")
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

    @Flag(name: .long, help: "Export animation clips without mesh geometry; requires a .untoldanim --output path")
    var animation = false

    @Flag(name: .long, help: "Compress geometry and bake/patch textures after export (implies --compress-geometry)")
    var optimize = false

    @Option(name: .customLong("color-grade-lut"), help: "Path to an externally-authored standard .cube 3D LUT to stage and apply as a post-tonemap creative grade. Nothing is rendered from Blender -- the .cube is copied as-is and loaded directly by the engine")
    var colorGradeLUT: String?

    @Option(name: .customLong("lod-levels"), help: "Gaussian .ply/.spz export only: number of progressive .untoldgs tiers to generate. Default 1 writes --output directly; values greater than 1 write <name>_lod0.untoldgs, <name>_lod1.untoldgs, ...")
    var lodLevels: Int = 1

    @Option(name: .customLong("splat-chunk-splats"), help: "Gaussian .ply/.spz export only: splats per chunk, a power of two between 2 and 16384 (1024 for objects, 4096 for environments)")
    var splatChunkSplats: Int = 1024

    @Option(name: .customLong("splat-coarse-levels"), help: "Gaussian .ply/.spz export only: per-chunk coarse levels baked into the file: auto (the --splat-coarse-ratio-log2 levels for tiers of at least \(UntoldGSFormat.coarseLevelsAutomaticMinimumChunks) chunks, none below), 0 (never), 1 or 2 (always)")
    var splatCoarseLevels: String = "auto"

    @Option(name: .customLong("splat-coarse-ratio-log2"), help: "Gaussian .ply/.spz export only: log2 of the merge ratio per coarse level, comma-separated and strictly increasing, each 1...log2(--splat-chunk-splats); level L holds one merged splat per 2^ratio fine splats of a chunk")
    var splatCoarseRatioLog2: String = "3,6"

    @Option(name: .customLong("splat-sh-degree"), help: "Gaussian .ply/.spz export only: spherical-harmonics degree to keep, 0...3 (default: the source degree)")
    var splatSHDegree: Int?

    @Option(name: .customLong("splat-min-opacity"), help: "Gaussian .ply/.spz export only: drop splats with a lower opacity")
    var splatMinOpacity: Float = 0.005

    @Option(name: .customLong("splat-max-count"), help: "Gaussian .ply/.spz export only: keep at most this many splats, the most important by opacity and size (0 = no limit). The runtime loads at most \(UntoldGSCookOptions.splatBudgetMobile) per entity on Vision Pro, iPhone, iPad and Apple TV and \(UntoldGSCookOptions.splatBudgetMac) on the Mac.")
    var splatMaxCount: Int = 0

    @Option(name: .customLong("splat-crop"), help: "Gaussian .ply/.spz export only: crop box in the output space, minX,minY,minZ,maxX,maxY,maxZ")
    var splatCrop: String?

    @Option(name: .customLong("splat-crop-margin"), help: "Gaussian .ply/.spz export only: grow the crop box on every side, in metres")
    var splatCropMargin: Float = 0

    @Option(name: .customLong("splat-scale"), help: "Gaussian .ply/.spz export only: uniform scale applied to the capture")
    var splatScale: Float = 1

    @Option(name: .customLong("splat-yaw-degrees"), help: "Gaussian .ply/.spz export only: rotation about +Y applied after --splat-flip-yz, in degrees")
    var splatYawDegrees: Float = 0

    @Option(name: .customLong("splat-translate"), help: "Gaussian .ply/.spz export only: translation applied after rotation and scale, x,y,z")
    var splatTranslate: String?

    @Option(name: .customLong("splat-up-axis"), help: "Gaussian .ply/.spz export only: which axis points up in the capture: y (engine convention, default), z (scanner/CAD, rotated to Y-up), or -y (3DGS training convention)")
    var splatUpAxis: String = "y"

    @Flag(name: .customLong("splat-flip-yz"), help: "Gaussian .ply/.spz export only: same as --splat-up-axis=-y")
    var splatFlipYZ = false

    @Flag(name: .customLong("splat-environment"), help: "Gaussian .ply/.spz export only: cook as an environment payload")
    var splatEnvironment = false

    @Flag(name: .customLong("splat-antialiased"), help: "Gaussian .ply/.spz export only: mark the payload as cooked with the anti-aliased (3D smoothing) convention")
    var splatAntialiased = false

    func run() throws {
        let inputURL = resolvePath(input).standardizedFileURL
        let outputURL = resolvePath(output).standardizedFileURL

        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw ExportError.inputNotFound(inputURL.path)
        }

        let inputExtension = inputURL.pathExtension.lowercased()
        if inputExtension == "ply" || inputExtension == "spz" {
            guard outputURL.pathExtension.lowercased() == "untoldgs" else {
                throw ExportError.unsupportedGaussianExportOutput(outputURL.pathExtension)
            }
            guard lodLevels > 0 else {
                throw ExportError.invalidLODLevels(lodLevels)
            }
            try runGaussianSplatExport(inputURL: inputURL, outputURL: outputURL, cookOptions: makeSplatCookOptions())
            return
        }

        if animation {
            guard outputURL.pathExtension.lowercased() == "untoldanim" else {
                throw ExportError.unsupportedAnimationExportOutput(outputURL.pathExtension)
            }
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

        // If the source scene contained more than one independent model, the
        // exporter writes a .untoldpack manifest plus one self-contained
        // .untold per model under --output's directory instead of a single
        // file at --output itself (see group_export_nodes_by_root in
        // scripts/untoldexplorer.py). Snapshot both possible outputs' mtimes
        // before running so we can tell which one THIS run actually wrote,
        // rather than trusting file existence alone (see below).
        let packURL = outputURL.deletingPathExtension().appendingPathExtension("untoldpack")
        let outputMTimeBefore = modificationDate(at: outputURL)
        let packMTimeBefore = modificationDate(at: packURL)

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

        // A file existing post-export isn't proof THIS run produced it: the
        // exporter script the CLI just ran may predate the exporter-side stale
        // cleanup (untoldengine export runs whatever copy `untoldengine install`
        // last placed, not the live repo), which can leave last run's leftover
        // pack/single-file artifact sitting beside this run's real output. Compare
        // mtimes from before/after the process instead of just checking existence,
        // so a leftover from an older export -- of either kind -- doesn't get
        // mistaken for this run's output, or worse, cause this run's real output
        // to be deleted as "stale".
        let packWrittenThisRun = FileManager.default.fileExists(atPath: packURL.path)
            && modificationDate(at: packURL) != packMTimeBefore
        let outputWrittenThisRun = FileManager.default.fileExists(atPath: outputURL.path)
            && modificationDate(at: outputURL) != outputMTimeBefore

        if packWrittenThisRun {
            guard let pack = loadUntoldPack(url: packURL) else {
                throw ExportError.packManifestUnreadable(packURL.path)
            }

            // The exporter itself removes a stale single-file export when it detects
            // a scene has moved from one model to several (see the cleanup after
            // write_untoldpack_manifest() in scripts/untoldexplorer.py). This is a
            // belt-and-suspenders repeat of that same check for an installed exporter
            // that predates it -- only when outputURL wasn't written by this run,
            // since a leftover from an older export is the only thing safe to remove.
            if FileManager.default.fileExists(atPath: outputURL.path), !outputWrittenThisRun {
                try? FileManager.default.removeItem(at: outputURL)
                printInfo("Removed stale single-file export: \(outputURL.path)")
            }

            printSuccess("Exported pack: \(packURL.path) (\(pack.models.count) model(s))")
            for model in pack.models {
                printInfo("  \(model.displayName ?? model.path) -> \(model.path)")
            }
            if optimize {
                for model in pack.models {
                    let modelURL = packURL.deletingLastPathComponent().appendingPathComponent(model.path)
                    try optimizeTextures(outputURL: modelURL)
                }
            }
        } else {
            // Mirror image of the above: an old pack manifest from a previous
            // multi-model export at this stem may still be sitting here, left by
            // an installed exporter that predates write_single_untold_from_nodes()'s
            // own pack cleanup. Only clean it up when this run didn't touch it, so a
            // caller still loading `withExtension: "untoldpack"` can't silently pick
            // up a now-outdated model set.
            if FileManager.default.fileExists(atPath: packURL.path), !packWrittenThisRun {
                if let stalePack = loadUntoldPack(url: packURL) {
                    for model in stalePack.models {
                        let modelDir = packURL.deletingLastPathComponent()
                            .appendingPathComponent(model.path)
                            .deletingLastPathComponent()
                        try? FileManager.default.removeItem(at: modelDir)
                    }
                }
                try? FileManager.default.removeItem(at: packURL)
                printInfo("Removed stale pack manifest: \(packURL.path)")
            }

            printSuccess("Exported: \(outputURL.path)")
            if optimize {
                try optimizeTextures(outputURL: outputURL)
            }
        }
    }

    private func modificationDate(at url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    private func runGaussianSplatExport(inputURL: URL, outputURL: URL, cookOptions: UntoldGSCookOptions) throws {
        printInfo("Exporting Gaussian splats \(inputURL.path)")
        // Progress on stderr — one updating line on a terminal, a line per phase otherwise — and
        // Ctrl-C mapped to the cook's cancellation, so an interrupted export leaves no file.
        let progress = GaussianExportProgressPrinter()
        GaussianExportCancellation.install()
        defer {
            GaussianExportCancellation.uninstall()
            progress.finish()
        }
        let control = UntoldGSCookControl(
            progress: { progress.report($0) },
            isCancelled: { GaussianExportCancellation.isRequested }
        )
        let bakeResult: GaussianProgressiveBakeResult
        do {
            switch inputURL.pathExtension.lowercased() {
            case "spz":
                bakeResult = try bakeGaussianSplatProgressiveTiers(
                    spzURL: inputURL,
                    outputBaseURL: outputURL,
                    levelCount: lodLevels,
                    cookOptions: cookOptions,
                    control: control
                )
            default:
                bakeResult = try bakeGaussianSplatProgressiveTiers(
                    plyURL: inputURL,
                    outputBaseURL: outputURL,
                    levelCount: lodLevels,
                    cookOptions: cookOptions,
                    control: control
                )
            }
        } catch UntoldGSCookError.cancelled {
            progress.finish()
            throw ExportError.splatCookCancelled
        } catch let error as UntoldGSCookError {
            throw ExportError.splatCookFailed(error.description)
        } catch let error as UntoldGSError {
            throw ExportError.splatCookFailed(error.description)
        } catch let error as NSError where error.domain == NSPOSIXErrorDomain || error.domain == NSCocoaErrorDomain {
            // The writer's file: a full disk, a directory that cannot be created, a rename
            // refused — the system's own words, with the path it names.
            throw ExportError.outputWriteFailure(error)
        } catch let error as SPZError {
            // Most commonly a v4/NGSP (ZSTD) file -- a different, unsupported container, not a
            // parse failure -- so this needs to reach the user as a clear message, not a crash.
            throw ExportError.splatSourceReadFailed(error.description)
        } catch let error as PLYError {
            throw ExportError.splatSourceReadFailed(error.description)
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
            printInfo("  " + coarseLevelSummary(tier.coarseReport))
        }

        // boundingBoxHalfExtent is NOT baked into the files (the engine can auto-compute it for
        // non-streaming loads instead) — pass this into setEntityGaussianProgressive/
        // setEntityGaussianTileStreaming's boundingBoxHalfExtent if you want it set explicitly, e.g.
        // for the streaming path, which requires a real box before any tier is ever read.
        let halfExtent = (bakeResult.boundingBoxMax - bakeResult.boundingBoxMin) * 0.5
        printInfo("boundingBoxHalfExtent: (\(halfExtent.x), \(halfExtent.y), \(halfExtent.z))")
    }

    /// `coarse levels: 2 (128 + 16 per 1024-chunk), 2,812,608 records, 45.0 MB`, or `none`.
    private func coarseLevelSummary(_ report: UntoldGSCoarseLevelReport?) -> String {
        guard let report else { return "coarse levels: none" }
        let perChunk = report.recordsPerFullChunk(splatsPerChunk: splatChunkSplats).map(String.init).joined(separator: " + ")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let records = formatter.string(from: NSNumber(value: report.recordCount)) ?? "\(report.recordCount)"
        let size = report.bytes >= 1_000_000
            ? String(format: "%.1f MB", Double(report.bytes) / 1_000_000)
            : String(format: "%.1f KB", Double(report.bytes) / 1000)
        var summary = "coarse levels: \(report.levelCount) (\(perChunk) per \(splatChunkSplats)-chunk), \(records) records, \(size)"
        if report.chunksWithoutLevels > 0 {
            summary += ", \(report.chunksWithoutLevels) chunks too small for a level"
        }
        return summary
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
        options.coarseLevels = try parseCoarseLevels(log2ChunkSplats: options.log2ChunkSplats)
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

    /// `--splat-coarse-levels auto|0|1|2` with `--splat-coarse-ratio-log2 a,b`: the ratios are
    /// checked here (strictly increasing, 1…log2 of the chunk size, one per level) so a bad flag
    /// fails before the PLY is read.
    private func parseCoarseLevels(log2ChunkSplats: UInt8) throws -> UntoldGSCoarseLevelPolicy {
        let ratioText = splatCoarseRatioLog2.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let ratios = ratioText.map { Int($0) }
        guard !ratios.isEmpty, ratios.count <= UntoldGSFormat.maxCoarseLevels, !ratios.contains(nil) else {
            throw ExportError.invalidSplatFlag("--splat-coarse-ratio-log2 expects one or two comma-separated integers")
        }
        let ratioValues = ratios.compactMap(\.self)
        let levels = splatCoarseLevels.trimmingCharacters(in: .whitespaces).lowercased()
        // Under `auto` the writer clamps the ratios to the chunk size (a 16-splat chunk cannot
        // hold a 1 : 64 level); asked for explicitly they must fit.
        let maximumRatio = levels == "auto" ? Int(UntoldGSFormat.maxLog2ChunkSplats) : Int(log2ChunkSplats)
        var previous = 0
        for ratio in ratioValues {
            guard ratio > previous, ratio <= maximumRatio else {
                throw ExportError.invalidSplatFlag("--splat-coarse-ratio-log2 must increase strictly within 1...\(maximumRatio) (log2 of --splat-chunk-splats)")
            }
            previous = ratio
        }

        func levelOptions(count: Int) throws -> UntoldGSCoarseLevelOptions {
            guard ratioValues.count >= count else {
                throw ExportError.invalidSplatFlag("--splat-coarse-ratio-log2 needs \(count) values for \(count) coarse levels")
            }
            var options = UntoldGSCoarseLevelOptions.default
            options.levelCount = count
            options.ratioLog2 = ratioValues.prefix(count).map { UInt8($0) }
            return options
        }
        switch levels {
        case "auto":
            return try .automatic(template: levelOptions(count: min(ratioValues.count, UntoldGSFormat.maxCoarseLevels)))
        case "0":
            return .off
        case "1", "2":
            return try .levels(levelOptions(count: Int(levels) ?? 1))
        default:
            throw ExportError.invalidSplatFlag("--splat-coarse-levels must be auto, 0, 1 or 2")
        }
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
    case unsupportedGaussianExportOutput(String)
    case invalidLODLevels(Int)
    case colorGradeLUTNotFound(String)
    case splatCookFailed(String)
    case splatCookCancelled
    case splatSourceReadFailed(String)
    case splatOutputWriteFailed(path: String?, reason: String)
    case invalidSplatUpAxis(String)
    case invalidSplatFlag(String)
    case packManifestUnreadable(String)
    case unsupportedAnimationExportOutput(String)

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
        case let .unsupportedGaussianExportOutput(pathExtension):
            let suffix = pathExtension.isEmpty ? "<none>" : ".\(pathExtension)"
            return "Gaussian .ply/.spz export supports only .untoldgs output, got \(suffix)"
        case let .invalidLODLevels(value):
            return "--lod-levels must be a positive integer, got \(value)"
        case let .colorGradeLUTNotFound(path):
            return "--color-grade-lut path does not exist: \(path)"
        case let .splatCookFailed(reason):
            return "Gaussian splat cook failed: \(reason)"
        case .splatCookCancelled:
            return "Gaussian splat cook cancelled; no file was written"
        case let .splatSourceReadFailed(reason):
            return "Failed to read Gaussian source: \(reason)"
        case let .splatOutputWriteFailed(path, reason):
            return "Failed to write Gaussian splat output\(path.map { " \($0)" } ?? ""): \(reason)"
        case let .invalidSplatUpAxis(value):
            return "--splat-up-axis must be y, z or -y, got \(value)"
        case let .invalidSplatFlag(reason):
            return reason
        case let .packManifestUnreadable(path):
            return "Exporter wrote a .untoldpack manifest but it could not be read back: \(path)"
        case let .unsupportedAnimationExportOutput(pathExtension):
            let suffix = pathExtension.isEmpty ? "<none>" : ".\(pathExtension)"
            return "--animation export supports only .untoldanim output, got \(suffix)"
        }
    }

    /// The write failure for a POSIX or Cocoa file error: the path it names and, for a POSIX
    /// code, `strerror`'s words (`No space left on device`) rather than the NSError's dump.
    static func outputWriteFailure(_ error: NSError) -> ExportError {
        let path = error.userInfo[NSFilePathErrorKey] as? String
        let reason = error.domain == NSPOSIXErrorDomain
            ? String(cString: strerror(Int32(error.code)))
            : error.localizedDescription
        return .splatOutputWriteFailed(path: path, reason: reason)
    }
}

// MARK: - Gaussian cook progress

/// Prints `UntoldGSCookProgress` on stderr: on a terminal one line rewritten in place
/// (`read      42 %  overall  15 %  12.3 s`), otherwise a line when a phase or tier starts
/// with the seconds elapsed since the export began, so a log stays readable and shows where
/// the time went.
final class GaussianExportProgressPrinter {
    private let interactive = isatty(STDERR_FILENO) != 0
    private let start = DispatchTime.now()
    private var lastPhase: UntoldGSCookPhase?
    private var lastTier = -1
    private var lastPercent = -1
    private var lineOpen = false

    private var elapsed: String {
        String(format: "%.1f s", Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1e9)
    }

    func report(_ progress: UntoldGSCookProgress) {
        let percent = Int((progress.fraction * 100).rounded(.down))
        let phaseChanged = progress.phase != lastPhase || progress.tierIndex != lastTier
        guard phaseChanged || percent != lastPercent else { return }
        lastPhase = progress.phase
        lastTier = progress.tierIndex
        lastPercent = percent
        let tier = progress.tierCount > 1 ? "  tier \(progress.tierIndex + 1)/\(progress.tierCount)" : ""
        let overall = Int((progress.overall * 100).rounded(.down))
        if interactive {
            let line = String(format: "\r%-8@ %3d %%  overall %3d %%%@  %@", progress.phase.rawValue as NSString, percent, overall, tier as NSString, elapsed as NSString)
            write(line.padding(toLength: max(line.count, 56), withPad: " ", startingAt: 0))
            lineOpen = true
        } else if phaseChanged {
            write("\(progress.phase.rawValue)\(tier)  overall \(overall) %  \(elapsed)\n")
        }
    }

    /// Ends the in-place line, if one is open.
    func finish() {
        guard lineOpen else { return }
        write("\n")
        lineOpen = false
    }

    private func write(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }
}

/// SIGINT → the cook's cancellation flag, for the duration of an export.
enum GaussianExportCancellation {
    private nonisolated(unsafe) static var requested: sig_atomic_t = 0
    private nonisolated(unsafe) static var previousHandler: sig_t?

    static var isRequested: Bool {
        requested != 0
    }

    static func install() {
        requested = 0
        previousHandler = signal(SIGINT) { _ in
            GaussianExportCancellation.requested = 1
        }
    }

    static func uninstall() {
        signal(SIGINT, previousHandler ?? SIG_DFL)
        previousHandler = nil
    }
}
