//
//  FindGameDataDirectoryTests.swift
//  UntoldEngineCLI
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngineCLI
import XCTest

final class FindGameDataDirectoryTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUp() {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FindGameDataDirectoryTests_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    /// `/var` is a symlink to `/private/var` on macOS, and `FileManager.contentsOfDirectory`
    /// resolves it inconsistently depending on recursion depth. Normalize before comparing.
    private func resolvedPath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().path
    }

    override func tearDown() {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    func testFindsRootLevelGameData() throws {
        let gameData = tempDirectory.appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: gameData, withIntermediateDirectories: true)

        let found = findGameDataDirectory(startingAt: tempDirectory)
        XCTAssertEqual(found.map(resolvedPath), [resolvedPath(gameData)])
    }

    func testFindsLegacyNestedGameData() throws {
        let gameData = tempDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyGame")
            .appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: gameData, withIntermediateDirectories: true)

        let found = findGameDataDirectory(startingAt: tempDirectory)
        XCTAssertEqual(found.map(resolvedPath), [resolvedPath(gameData)])
    }

    func testReturnsEmptyWhenNoGameDataExists() throws {
        try FileManager.default.createDirectory(
            at: tempDirectory.appendingPathComponent("Sources"), withIntermediateDirectories: true
        )

        XCTAssertTrue(findGameDataDirectory(startingAt: tempDirectory).isEmpty)
    }

    func testFindsBothRootLevelAndLegacyGameDataWhenMidConversion() throws {
        // A project between `untoldengine convert` moving the root GameData into place and
        // deleting the stale legacy one should surface both, not silently pick one.
        let rootGameData = tempDirectory.appendingPathComponent("GameData")
        let legacyGameData = tempDirectory
            .appendingPathComponent("Sources")
            .appendingPathComponent("MyGame")
            .appendingPathComponent("GameData")
        try FileManager.default.createDirectory(at: rootGameData, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: legacyGameData, withIntermediateDirectories: true)

        let found = Set(findGameDataDirectory(startingAt: tempDirectory).map(resolvedPath))
        XCTAssertEqual(found, [resolvedPath(rootGameData), resolvedPath(legacyGameData)])
    }

    func testDoesNotRecurseIntoAMatchedGameDataFolder() throws {
        // A category folder literally named "GameData" inside GameData itself would be
        // bizarre, but confirms the recursion-skip doesn't miss real matches either.
        let gameData = tempDirectory.appendingPathComponent("GameData")
        try FileManager.default.createDirectory(
            at: gameData.appendingPathComponent("Scenes"), withIntermediateDirectories: true
        )

        let found = findGameDataDirectory(startingAt: tempDirectory)
        XCTAssertEqual(found.map(resolvedPath), [resolvedPath(gameData)])
    }
}
