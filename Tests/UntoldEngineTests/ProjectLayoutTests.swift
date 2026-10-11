//
//  ProjectLayoutTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class ProjectLayoutTests: XCTestCase {
    var tempDirectory: URL!

    override func setUp() async throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectLayoutTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testLegacyGameDataDirectory() {
        let layout = ProjectLayout(kind: .legacy, projectRoot: tempDirectory, projectName: "MyGame")

        XCTAssertEqual(
            layout.gameDataDirectory,
            tempDirectory.appendingPathComponent("Sources").appendingPathComponent("MyGame").appendingPathComponent("GameData")
        )
        XCTAssertNil(layout.resourcesDirectory, "legacy projects have no Resources folder")
        XCTAssertNil(layout.docsDirectory, "legacy projects have no Docs folder")
    }

    func testRootLevelGameDataDirectory() {
        let layout = ProjectLayout(kind: .rootLevel, projectRoot: tempDirectory, projectName: "MyGame")

        XCTAssertEqual(layout.gameDataDirectory, tempDirectory.appendingPathComponent("GameData"))
        XCTAssertEqual(layout.resourcesDirectory, tempDirectory.appendingPathComponent("Resources"))
        XCTAssertEqual(layout.docsDirectory, tempDirectory.appendingPathComponent("Docs"))
    }

    func testSourcesDirectoryIsTheSameShapeForBothLayouts() {
        let legacy = ProjectLayout(kind: .legacy, projectRoot: tempDirectory, projectName: "MyGame")
        let rootLevel = ProjectLayout(kind: .rootLevel, projectRoot: tempDirectory, projectName: "MyGame")

        XCTAssertEqual(legacy.sourcesDirectory, rootLevel.sourcesDirectory)
        XCTAssertEqual(legacy.sourcesDirectory, tempDirectory.appendingPathComponent("Sources"))
    }

    func testDetectDefaultsToLegacyWhenNeitherLayoutExistsYet() {
        let layout = ProjectLayout.detect(projectRoot: tempDirectory, projectName: "MyGame")
        XCTAssertEqual(layout.kind, .legacy)
    }

    func testDetectFindsLegacyLayoutOnDisk() throws {
        let gameData = tempDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyGame")
            .appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: gameData, withIntermediateDirectories: true)

        let layout = ProjectLayout.detect(projectRoot: tempDirectory, projectName: "MyGame")
        XCTAssertEqual(layout.kind, .legacy)
        XCTAssertEqual(layout.gameDataDirectory.path, gameData.path)
    }

    func testDetectFindsRootLevelLayoutOnDisk() throws {
        let gameData = tempDirectory.appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: gameData, withIntermediateDirectories: true)

        let layout = ProjectLayout.detect(projectRoot: tempDirectory, projectName: "MyGame")
        XCTAssertEqual(layout.kind, .rootLevel)
        XCTAssertEqual(layout.gameDataDirectory.path, gameData.path)
    }

    func testDetectPrefersRootLevelWhenBothExist() throws {
        // A project mid-conversion (or one where both happen to exist) should resolve
        // to the new layout rather than silently using the stale legacy one.
        let legacyGameData = tempDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyGame")
            .appendingPathComponent("GameData")
        let rootGameData = tempDirectory.appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: legacyGameData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootGameData, withIntermediateDirectories: true)

        let layout = ProjectLayout.detect(projectRoot: tempDirectory, projectName: "MyGame")
        XCTAssertEqual(layout.kind, .rootLevel)
    }

    func testDetectFromGameDataDirectoryHandlesLegacyLayout() {
        let gameData = tempDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyGame")
            .appendingPathComponent("GameData")

        let layout = ProjectLayout.detect(gameDataDirectory: gameData)
        XCTAssertEqual(layout.kind, .legacy)
        XCTAssertEqual(layout.projectName, "MyGame")
        XCTAssertEqual(layout.projectRoot.path, tempDirectory.path)
        XCTAssertEqual(layout.gameDataDirectory.path, gameData.path, "round-tripping through gameDataDirectory should land back on the same path")
    }

    func testDetectFromGameDataDirectoryHandlesRootLevelLayout() {
        let projectRoot = tempDirectory.appendingPathComponent("MyGame")
        let gameData = projectRoot.appendingPathComponent("GameData")

        let layout = ProjectLayout.detect(gameDataDirectory: gameData)
        XCTAssertEqual(layout.kind, .rootLevel)
        XCTAssertEqual(layout.projectName, "MyGame")
        XCTAssertEqual(layout.projectRoot.path, projectRoot.path)
        XCTAssertEqual(layout.gameDataDirectory.path, gameData.path, "round-tripping through gameDataDirectory should land back on the same path")
    }

    func testGameDataCategoriesMatchesWhatBuildSystemCreates() {
        XCTAssertEqual(
            ProjectLayout.gameDataCategories,
            ["Scenes", "Scripts", "Models", "StreamModels", "Animations", "Gaussians", "Textures", "Shaders", "LUT"]
        )
    }
}
