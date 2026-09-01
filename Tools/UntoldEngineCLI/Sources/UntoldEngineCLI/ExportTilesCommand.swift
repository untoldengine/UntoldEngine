//
//  ExportTilesCommand.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation

struct ExportTilesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "export-tiles",
        abstract: "Partition a USD/USDZ scene into UntoldEngine streaming tiles",
        discussion: """
        Runs the UntoldEngine tile-streaming partitioner through Blender,
        writing per-tile .untold payloads plus a manifest into --output-dir.

        --optimize compresses geometry and, if the export produced a shared
        Textures directory, bakes those textures to .utex and patches every
        tile's .untold references — equivalent to running --compress-geometry
        followed by `untoldengine texbake --dir` and `untoldengine texbake
        --patch-refs` against the whole output directory.

        Example:
          untoldengine export-tiles --input scene.usdz --output-dir tile_exports \\
            --tile-size-x 25 --tile-size-z 25 --optimize
          untoldengine export-tiles --input scene.blend --output-dir tile_exports \\
            --tile-size-x 25 --tile-size-z 25
        """
    )

    @Option(name: .long, help: "Source .usd, .usda, .usdc, .usdz, or .blend scene")
    var input: String?

    @Option(name: .customLong("output-dir"), help: "Directory for exported tile payloads and manifest")
    var outputDir: String

    @Option(name: .long, help: "Override the Blender executable path")
    var blender: String?

    @Option(name: .customLong("tile-size-x"), help: "Grid tile width in metres (ignored in --quadtree/--kdtree mode)")
    var tileSizeX: Double?

    @Option(name: .customLong("tile-size-y"), help: "Grid tile height in metres")
    var tileSizeY: Double = 10000.0

    @Option(name: .customLong("tile-size-z"), help: "Grid tile depth in metres (ignored in --quadtree/--kdtree mode)")
    var tileSizeZ: Double?

    @Flag(name: .customLong("auto-tile-size"), help: "Enable automatic tile-size selection")
    var autoTileSize = false

    @Flag(name: .long, help: "Use floor+quadtree partitioning")
    var quadtree = false

    @Flag(name: .long, help: "Use floor+KD-tree partitioning (inline annotation only)")
    var kdtree = false

    @Option(name: .customLong("min-objects-per-tile-tier"), help: "Collapse underfilled tile-tiers upward until reaching this many objects (default: 4)")
    var minObjectsPerTileTier: Int?

    @Option(name: .customLong("scene-profile"), help: "Streaming radius profile: auto, indoor, or outdoor")
    var sceneProfile: String = "auto"

    @Option(name: .customLong("tier-radius"), help: "Override a semantic tier's radii: TIER=STREAM,UNLOAD[,PRIORITY]. Repeatable.")
    var tierRadius: [String] = []

    @Option(name: .customLong("untagged-semantic-tier"), help: "Semantic tier for meshes without an explicit override: Auto, ExteriorShell, StructuralInterior, RoomContents, or FineProps")
    var untaggedSemanticTier: String = "Auto"

    @Option(name: .customLong("floor-count"), help: "Pin the number of floors for inline quadtree/KD-tree annotation")
    var floorCount: Int?

    @Option(name: .customLong("floor-band-height"), help: "Pin the per-floor band height in metres for inline annotation")
    var floorBandHeight: Double?

    @Flag(name: .customLong("visible-only"), help: "Export only visible mesh objects")
    var visibleOnly = false

    @Flag(name: .customLong("all-meshes"), help: "Export all mesh objects, including hidden ones")
    var allMeshes = false

    @Flag(name: .customLong("debug-aabb-only"), help: "Export debug AABB payloads instead of real geometry")
    var debugAABBOnly = false

    @Flag(name: .customLong("generate-hlod"), help: "Enable HLOD export")
    var generateHLOD = false

    @Flag(name: .customLong("generate-lod"), help: "Enable per-tile LOD export")
    var generateLOD = false

    @Option(name: .customLong("lod-level"), help: "Override per-tile LOD levels: DISTANCE:RATIO. Repeatable.")
    var lodLevel: [String] = []

    @Option(name: .customLong("hlod-level"), help: "Override HLOD levels: SUFFIX:DISTANCE:RATIO. Repeatable.")
    var hlodLevel: [String] = []

    @Flag(name: .long, help: "Export only a small tile patch near the world origin (fast iteration mode)")
    var sample = false

    @Option(name: .customLong("sample-fraction"), help: "Fraction of total tiles to keep in sample mode (default: 0.10)")
    var sampleFraction: Double?

    @Flag(name: .long, help: "Export only the outer shell of tiles, skipping interior tiles")
    var perimeter = false

    @Option(name: .customLong("perimeter-depth"), help: "How many tiles inward from the boundary to keep (default: 1)")
    var perimeterDepth: Int?

    @Option(name: .customLong("parallel-workers"), help: "Number of parallel Blender worker processes (0=auto, 1=sequential)")
    var parallelWorkers: Int?

    @Flag(name: .customLong("dry-run"), help: "Plan the partition without writing payload files")
    var dryRun = false

    @Flag(name: .customLong("write-manifest-in-dry-run"), help: "Write the manifest JSON even when --dry-run is enabled")
    var writeManifestInDryRun = false

    @Flag(name: .customLong("compress-geometry"), help: "LZ4-compress vertex and index chunks in every tile payload")
    var compressGeometry = false

    @Flag(name: .long, help: "Compress geometry and bake/patch textures after export (implies --compress-geometry)")
    var optimize = false

    @Flag(name: .customLong("bake-color-management"), help: "Bake the scene's active View Transform/Look/Exposure/Gamma into a scene-wide color-grading LUT referenced from the manifest's colorLUT key")
    var bakeColorManagement = false

    @Option(name: .customLong("color-lut-size"), help: "Grid size (N) for the NxNxN color-grading LUT")
    var colorLutSize: Int = 32

    func run() throws {
        let outputDirURL = resolvePath(outputDir).standardizedFileURL

        var inputURL: URL?
        if let input {
            let resolved = resolvePath(input).standardizedFileURL
            guard FileManager.default.fileExists(atPath: resolved.path) else {
                throw ExportTilesError.inputNotFound(resolved.path)
            }
            inputURL = resolved
        }

        let blenderURL = try resolveBlenderExecutable(override: blender)
        let partitionerURL = try resolveTilePartitioner()

        var partitionerArguments = ["--output-dir", outputDirURL.path]
        if let inputURL { partitionerArguments += ["--input", inputURL.path] }
        if let tileSizeX { partitionerArguments += ["--tile-size-x", String(tileSizeX)] }
        partitionerArguments += ["--tile-size-y", String(tileSizeY)]
        if let tileSizeZ { partitionerArguments += ["--tile-size-z", String(tileSizeZ)] }
        if autoTileSize { partitionerArguments.append("--auto-tile-size") }

        if quadtree { partitionerArguments.append("--quadtree") }
        if kdtree { partitionerArguments.append("--kdtree") }
        if let minObjectsPerTileTier { partitionerArguments += ["--min-objects-per-tile-tier", String(minObjectsPerTileTier)] }
        partitionerArguments += ["--scene-profile", sceneProfile]
        for override in tierRadius {
            partitionerArguments += ["--tier-radius", override]
        }
        partitionerArguments += ["--untagged-semantic-tier", untaggedSemanticTier]
        if let floorCount { partitionerArguments += ["--floor-count", String(floorCount)] }
        if let floorBandHeight { partitionerArguments += ["--floor-band-height", String(floorBandHeight)] }

        if visibleOnly { partitionerArguments.append("--visible-only") }
        if allMeshes { partitionerArguments.append("--all-meshes") }
        if debugAABBOnly { partitionerArguments.append("--debug-aabb-only") }

        if generateHLOD { partitionerArguments.append("--generate-hlod") }
        if generateLOD { partitionerArguments.append("--generate-lod") }
        for level in lodLevel {
            partitionerArguments += ["--lod-level", level]
        }
        for level in hlodLevel {
            partitionerArguments += ["--hlod-level", level]
        }

        if sample { partitionerArguments.append("--sample") }
        if let sampleFraction { partitionerArguments += ["--sample-fraction", String(sampleFraction)] }
        if perimeter { partitionerArguments.append("--perimeter") }
        if let perimeterDepth { partitionerArguments += ["--perimeter-depth", String(perimeterDepth)] }

        if let parallelWorkers { partitionerArguments += ["--parallel-workers", String(parallelWorkers)] }
        if dryRun { partitionerArguments.append("--dry-run") }
        if writeManifestInDryRun { partitionerArguments.append("--write-manifest-in-dry-run") }

        if compressGeometry || optimize { partitionerArguments.append("--compress-geometry") }
        if bakeColorManagement {
            partitionerArguments.append("--bake-color-management")
            partitionerArguments += ["--color-lut-size", String(colorLutSize)]
        }

        printInfo("Using Blender: \(blenderURL.path)")
        printInfo("Partitioning tiles into \(outputDirURL.path)")

        let process = Process()
        process.executableURL = blenderURL
        process.arguments = [
            "--background",
            "--factory-startup",
            // Without this, Blender exits 0 even when the Python script
            // raises an uncaught exception, so a real export failure would
            // otherwise be reported as success.
            "--python-exit-code", "1",
            "--python", partitionerURL.path,
            "--",
        ] + partitionerArguments
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ExportTilesError.exportFailed(process.terminationStatus)
        }
        printSuccess("Exported tiles: \(outputDirURL.path)")

        if optimize, !dryRun {
            try optimizeTextures(outputDirURL: outputDirURL)
        }
    }

    private func optimizeTextures(outputDirURL: URL) throws {
        let texturesDir = outputDirURL.appendingPathComponent("Textures")
        guard validateDirectory(texturesDir) else {
            printInfo("No Textures directory found in the output directory; skipping texture optimization.")
            return
        }

        let python3URL = try resolvePython3()
        let texbakeScriptURL = try resolveTexbakeScript()

        printInfo("Baking textures: \(texturesDir.path)")
        try runPython(python3URL, [texbakeScriptURL.path, "--dir", texturesDir.path])

        printInfo("Patching texture references in: \(outputDirURL.path)")
        try runPython(python3URL, [texbakeScriptURL.path, "--patch-refs", outputDirURL.path])

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
            throw ExportTilesError.optimizeFailed(process.terminationStatus)
        }
    }

    private func resolveTilePartitioner() throws -> URL {
        try resolveSupportScript(named: "tilestreamingpartition.py") { ExportTilesError.partitionerNotInstalled($0) }
    }
}

enum ExportTilesError: LocalizedError {
    case inputNotFound(String)
    case partitionerNotInstalled(String)
    case exportFailed(Int32)
    case optimizeFailed(Int32)

    var errorDescription: String? {
        switch self {
        case let .inputNotFound(path):
            return "Input asset does not exist: \(path)"
        case let .partitionerNotInstalled(path):
            return "Tile partitioner support file was not found. Reinstall the CLI. Expected: \(path)"
        case let .exportFailed(status):
            return "Blender tile partitioner failed with exit status \(status)"
        case let .optimizeFailed(status):
            return "Texture optimization (texbake) failed with exit status \(status)"
        }
    }
}
