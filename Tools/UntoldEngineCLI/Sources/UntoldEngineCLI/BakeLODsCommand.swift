//
//  BakeLODsCommand.swift
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
import UntoldEngineMeshCook

struct BakeLODsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bake-lods",
        abstract: "Build the automatic LOD chain of a cooked .untoldpack or .untold model",
        discussion: """
        Writes simplified copies of a model next to it (<name>_LOD1.untold,
        <name>_LOD2.untold, ...), built with meshoptimizer, one per --ratios
        entry. A level the simplifier cannot reduce by a worthwhile amount is
        left out, and so is the whole chain of a model under --min-triangles or
        of a skinned or morphing one.

        With a .untoldpack, every distinct model of the pack gets its chain (a
        model placed many times is simplified once) and the manifest records
        them under "lodChains"; the engine then loads the levels with the pack
        and switches between them by the size of each placement on screen. The
        source asset is not needed: the chains are built from the cooked files.

        `untoldengine export` runs this step for the packs it writes, so the
        command is for packs cooked earlier or with other settings. Running it
        again replaces the levels of the run before.

        Each level records the screen size from which it is detailed enough: the
        size at which its triangles cover --pixels-per-triangle pixels each on a
        viewport 1080 pixels high. A higher value switches to the simpler levels
        sooner.

        Examples:
          untoldengine bake-lods --input GameData/Models/site.untoldpack
          untoldengine bake-lods --input site.untoldpack --ratios 0.5,0.25,0.1,0.02
          untoldengine bake-lods --input Models/tree/tree.untold --min-triangles 500
        """
    )

    @Option(name: .long, help: "The .untoldpack manifest or the .untold model to build chains for")
    var input: String

    @Option(name: .long, help: "Share of the triangles each level aims for, finest first, comma-separated")
    var ratios: String = "0.5,0.15,0.03"

    @Option(name: .customLong("min-triangles"), help: "Models with fewer triangles get no chain")
    var minTriangles: Int = 2000

    @Option(name: .customLong("pixels-per-triangle"), help: "Screen pixels a triangle of a level covers when the level takes over (at 1080 lines)")
    var pixelsPerTriangle: Float = 4

    func run() throws {
        let inputURL = resolvePath(input).standardizedFileURL
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw BakeLODsError.inputNotFound(inputURL.path)
        }
        let options = try UntoldMeshLODOptions(
            ratios: Self.parseRatios(ratios),
            minimumTriangles: minTriangles,
            pixelsPerTriangle: pixelsPerTriangle
        )

        switch inputURL.pathExtension.lowercased() {
        case "untoldpack":
            let report = try Self.bakePack(at: inputURL, options: options)
            Self.printReport(report, packURL: inputURL)
        case "untold":
            let chain = try UntoldMeshLODCooker.cookChain(forModelAt: inputURL, options: options)
            Self.printChain(chain, modelURL: inputURL)
        default:
            throw BakeLODsError.unsupportedInput(inputURL.pathExtension)
        }
    }

    static func parseRatios(_ text: String) throws -> [Float] {
        let values = text.split(separator: ",", omittingEmptySubsequences: false).map { Float($0.trimmingCharacters(in: .whitespaces)) }
        guard !values.isEmpty, !values.contains(nil) else {
            throw BakeLODsError.invalidRatios(text)
        }
        return values.compactMap { $0 }
    }

    /// Cooks the chains of a pack with a progress line on stderr.
    static func bakePack(at packURL: URL, options: UntoldMeshLODOptions) throws -> UntoldPackLODReport {
        printInfo("Building LOD chains for \(packURL.lastPathComponent)")
        let isTerminal = isatty(fileno(stderr)) != 0
        let report = try UntoldMeshLODCooker.cookChains(forPackAt: packURL, options: options) { done, total in
            // One updating line on a terminal; a line every tenth of the way otherwise.
            if isTerminal {
                FileHandle.standardError.write(Data("\r  \(done) / \(total) models".utf8))
            } else if done == total || done % max(total / 10, 1) == 0 {
                FileHandle.standardError.write(Data("  \(done) / \(total) models\n".utf8))
            }
        }
        if isTerminal {
            FileHandle.standardError.write(Data("\n".utf8))
        }
        return report
    }

    static func printReport(_ report: UntoldPackLODReport, packURL: URL) {
        for failure in report.failures {
            printWarning("No LOD chain for \(failure.path): \(failure.reason)")
        }
        for path in report.blockedPaths {
            printWarning("No LOD chain for \(path): a file that is not one of its levels already has a level's name (<name>_LOD<n>)")
        }
        guard report.chainCount > 0 else {
            printInfo("No model of \(packURL.lastPathComponent) needed a LOD chain (\(report.modelCount) model(s))")
            return
        }
        let megabytes = String(format: "%.1f MB", Double(report.levelBytes) / 1_048_576)
        printSuccess(
            "LOD chains: \(report.chainCount) of \(report.modelCount) model(s), \(report.levelCount) level file(s), \(megabytes)"
        )
        printInfo(
            "  \(grouped(report.chainedTriangleCount)) triangles in those models, \(grouped(report.coarsestTriangleCount)) at their coarsest level"
        )
    }

    static func printChain(_ chain: UntoldMeshLODChain, modelURL: URL) {
        if let reason = chain.skipped {
            printInfo("No LOD chain for \(modelURL.lastPathComponent) (\(grouped(chain.triangleCount)) triangles): \(describe(reason))")
            return
        }
        printSuccess("LOD chain for \(modelURL.lastPathComponent) (\(grouped(chain.triangleCount)) triangles)")
        for level in chain.levels {
            let share = String(format: "%.1f %%", 100 * Double(level.triangleCount) / Double(max(chain.triangleCount, 1)))
            printInfo(
                "  \(level.url.lastPathComponent): \(grouped(level.triangleCount)) triangles (\(share)), from screen size \(String(format: "%.3f", level.screenSize))"
            )
        }
    }

    private static func describe(_ reason: UntoldMeshLODChain.SkipReason) -> String {
        switch reason {
        case .belowMinimumTriangles: "fewer triangles than --min-triangles"
        case .deforms: "skinned, morphing or animation-only models keep their full meshes"
        case .gaussianTwin: "the mesh twin of a Gaussian splat swaps to its splat"
        case .isLevel: "the file is a level of another model"
        case .levelNameTaken: "a file that is not one of its levels already has a level's name (<name>_LOD<n>)"
        case .irreducible: "the simplifier could not reduce it by a worthwhile amount"
        }
    }

    private static func grouped(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

enum BakeLODsError: LocalizedError, Equatable {
    case inputNotFound(String)
    case unsupportedInput(String)
    case invalidRatios(String)

    var errorDescription: String? {
        switch self {
        case let .inputNotFound(path):
            "Input not found: \(path)"
        case let .unsupportedInput(pathExtension):
            "bake-lods needs a .untoldpack or .untold input, not .\(pathExtension)"
        case let .invalidRatios(text):
            "--ratios must be comma-separated numbers such as 0.5,0.15,0.03 (got \"\(text)\")"
        }
    }
}
