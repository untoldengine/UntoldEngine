//
//  BakeLODsCommandTests.swift
//  UntoldEngineCLI
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import ArgumentParser
import Foundation
import UntoldEngine
@testable import UntoldEngineCLI
import UntoldEngineMeshCook
import XCTest

final class BakeLODsCommandTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("BakeLODsCommandTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
        super.tearDown()
    }

    /// A cooked model of the engine's render tests: seven meshes, 2,264 triangles.
    private func copyStadium(to url: URL) throws {
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UntoldEngineCLITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // UntoldEngineCLI
            .deletingLastPathComponent() // Tools
            .deletingLastPathComponent() // repository root
            .appendingPathComponent("Tests/UntoldEngineRenderTests/Resources/Models/stadium/stadium.untold")
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw XCTSkip("cooked fixture not found at \(source.path)")
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: url)
    }

    func testRatiosAreReadFromACommaSeparatedList() throws {
        XCTAssertEqual(try BakeLODsCommand.parseRatios("0.5,0.15,0.03"), [0.5, 0.15, 0.03])
        XCTAssertEqual(try BakeLODsCommand.parseRatios(" 0.25 , 0.05 "), [0.25, 0.05])
        for text in ["", "half", "0.5,,0.1", "0.5;0.1"] {
            XCTAssertThrowsError(try BakeLODsCommand.parseRatios(text), text) { error in
                XCTAssertEqual(error as? BakeLODsError, .invalidRatios(text))
            }
        }
    }

    func testTheDefaultsAreTheCooksDefaults() throws {
        let command = try BakeLODsCommand.parse(["--input", "site.untoldpack"])
        let defaults = UntoldMeshLODOptions()

        XCTAssertEqual(try BakeLODsCommand.parseRatios(command.ratios), defaults.ratios)
        XCTAssertEqual(command.minTriangles, defaults.minimumTriangles)
        XCTAssertEqual(command.pixelsPerTriangle, defaults.pixelsPerTriangle)
    }

    func testAModelGetsItsLevelsNextToIt() throws {
        let modelURL = directory.appendingPathComponent("stadium.untold")
        try copyStadium(to: modelURL)

        let command = try BakeLODsCommand.parse(["--input", modelURL.path])
        try command.run()

        for level in 1 ... 3 {
            XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent("stadium_LOD\(level).untold").path))
        }
    }

    func testAPackGetsItsChainsInTheManifest() throws {
        try copyStadium(to: directory.appendingPathComponent("Site/Stadium/Stadium.untold"))
        let packURL = directory.appendingPathComponent("Site.untoldpack")
        let manifest = """
        {"formatVersion": 1, "sourceAsset": "Site.blend", "models": [
          {"displayName": "Stadium", "path": "Site/Stadium/Stadium.untold",
           "transform": [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]}
        ]}
        """
        try Data(manifest.utf8).write(to: packURL)

        let command = try BakeLODsCommand.parse(["--input", packURL.path, "--ratios", "0.5,0.1"])
        try command.run()

        let chain = try XCTUnwrap(loadUntoldPack(url: packURL)?.lodChains?["Site/Stadium/Stadium.untold"])
        XCTAssertEqual(chain.map(\.path), ["Site/Stadium/Stadium_LOD1.untold", "Site/Stadium/Stadium_LOD2.untold"])
    }

    func testOtherInputsAreRefused() throws {
        let missing = try BakeLODsCommand.parse(["--input", directory.appendingPathComponent("nothing.untoldpack").path])
        XCTAssertThrowsError(try missing.run()) { error in
            guard case BakeLODsError.inputNotFound = error else { return XCTFail("unexpected error \(error)") }
        }

        let sourceURL = directory.appendingPathComponent("model.blend")
        try Data().write(to: sourceURL)
        let source = try BakeLODsCommand.parse(["--input", sourceURL.path])
        XCTAssertThrowsError(try source.run()) { error in
            XCTAssertEqual(error as? BakeLODsError, .unsupportedInput("blend"))
        }

        let modelURL = directory.appendingPathComponent("stadium.untold")
        try copyStadium(to: modelURL)
        let decreasing = try BakeLODsCommand.parse(["--input", modelURL.path, "--ratios", "0.1,0.5"])
        XCTAssertThrowsError(try decreasing.run()) { error in
            guard case UntoldMeshLODError.invalidOptions = error else { return XCTFail("unexpected error \(error)") }
        }
    }

    func testExportBuildsTheChainsOfAPackUnlessAskedNotTo() throws {
        XCTAssertFalse(try ExportCommand.parse(["--input", "site.blend", "--output", "site.untold"]).noLODs)
        XCTAssertTrue(try ExportCommand.parse(["--input", "site.blend", "--output", "site.untold", "--no-lods"]).noLODs)
    }
}
