//
//  LoadUntoldSceneContractTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

@testable import UntoldEngine
import XCTest

final class LoadUntoldSceneContractTests: XCTestCase {
    private var previousAssetBasePath: URL?
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAssetBasePath = assetBasePath
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("LoadUntoldSceneContractTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        assetBasePath = tempRoot
    }

    override func tearDownWithError() throws {
        assetBasePath = previousAssetBasePath
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testLoadUntoldSceneAcceptsNameWithoutExtension() throws {
        try writeScene(named: "LevelOne")

        let expectation = expectation(description: "scene load completes")
        loadUntoldScene(named: "LevelOne", meshLoadingMode: .sync) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadUntoldSceneAcceptsUntoldSceneExtension() throws {
        try writeScene(named: "LevelTwo")

        let expectation = expectation(description: "scene load completes")
        loadUntoldScene(named: "LevelTwo.untoldscene", meshLoadingMode: .sync) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadUntoldSceneRejectsOtherExtensions() {
        let expectation = expectation(description: "scene load rejects invalid extension")
        loadUntoldScene(named: "LevelThree.json", meshLoadingMode: .sync) { success in
            XCTAssertFalse(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadUntoldSceneFallsBackToFlatGameDataResource() throws {
        try writeScene(named: "FlatLevel", inScenesDirectory: false)

        let expectation = expectation(description: "flat scene load completes")
        loadUntoldScene(named: "FlatLevel", meshLoadingMode: .sync) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLoadUntoldScenePrefersScenesDirectoryOverFlatResource() throws {
        try writeScene(named: "PreferredLevel", inScenesDirectory: true)

        let flatSceneURL = tempRoot
            .appendingPathComponent("PreferredLevel")
            .appendingPathExtension("untoldscene")
        try Data("not valid scene json".utf8).write(to: flatSceneURL)

        let expectation = expectation(description: "structured scene load completes")
        loadUntoldScene(named: "PreferredLevel", meshLoadingMode: .sync) { success in
            XCTAssertTrue(success)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    private func writeScene(named name: String, inScenesDirectory: Bool = true) throws {
        let directory = inScenesDirectory
            ? tempRoot.appendingPathComponent("Scenes", isDirectory: true)
            : tempRoot!
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sceneURL = directory
            .appendingPathComponent(name)
            .appendingPathExtension("untoldscene")
        let sceneData = SceneData()
        let data = try JSONEncoder().encode(sceneData)
        try data.write(to: sceneURL)
    }
}
