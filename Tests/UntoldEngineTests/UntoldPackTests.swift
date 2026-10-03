//
//  UntoldPackTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import simd
@testable import UntoldEngine
import XCTest

final class UntoldPackTests: XCTestCase {
    private var previousAssetBasePath: URL?
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAssetBasePath = assetBasePath
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("UntoldPackTests-\(UUID().uuidString)", isDirectory: true)
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

    /// Mirrors the exact JSON shape scripts/untoldexplorer.py's
    /// write_untoldpack_manifest() emits: row-major nested arrays for `transform`,
    /// matching the same convention as .untold's own local_transform_rows.
    private func writePack(named name: String, models: [(displayName: String, path: String, translationX: Float)]) throws -> URL {
        let modelsJSON = models.map { model in
            """
            {
              "displayName": "\(model.displayName)",
              "path": "\(model.path)",
              "transform": [
                [1.0, 0.0, 0.0, \(model.translationX)],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
              ]
            }
            """
        }.joined(separator: ",\n")

        let json = """
        {
          "formatVersion": 1,
          "sourceAsset": "Robot.blend",
          "models": [\(modelsJSON)]
        }
        """
        let packURL = tempRoot.appendingPathComponent(name).appendingPathExtension("untoldpack")
        try Data(json.utf8).write(to: packURL)
        return packURL
    }

    func testLoadUntoldPackDecodesModelsAndTransform() throws {
        let packURL = try writePack(named: "Robot", models: [
            (displayName: "Body", path: "Body/Body.untold", translationX: 0.0),
            (displayName: "Arm", path: "Arm/Arm.untold", translationX: 2.5),
        ])

        let pack = try XCTUnwrap(loadUntoldPack(url: packURL))
        XCTAssertEqual(pack.formatVersion, 1)
        XCTAssertEqual(pack.sourceAsset, "Robot.blend")
        XCTAssertEqual(pack.models.count, 2)
        XCTAssertEqual(pack.models[0].displayName, "Body")
        XCTAssertEqual(pack.models[1].path, "Arm/Arm.untold")
        // Row 0, column 3 of the source JSON (translation.x) must land in the
        // decoded matrix's translation column, matching the .untold binary's
        // own row-major-JSON / column-major-simd convention.
        XCTAssertEqual(pack.models[1].transform.columns.3.x, 2.5, accuracy: 0.0001)
    }

    func testCreateUntoldSceneWritesOneEntityPerModelWithResolvedTransform() throws {
        let packURL = try writePack(named: "Robot", models: [
            (displayName: "Body", path: "Body/Body.untold", translationX: 0.0),
            (displayName: "Arm", path: "Arm/Arm.untold", translationX: 2.5),
        ])
        let sceneURL = tempRoot.appendingPathComponent("Robot.untoldscene")

        XCTAssertTrue(createUntoldScene(fromPackAt: packURL, savingTo: sceneURL))

        let sceneData = try JSONDecoder().decode(SceneData.self, from: Data(contentsOf: sceneURL))
        XCTAssertEqual(sceneData.entities.count, 2)

        let arm = try XCTUnwrap(sceneData.entities.first { $0.name == "Arm" })
        XCTAssertEqual(arm.position.x, 2.5, accuracy: 0.0001)
        XCTAssertEqual(arm.asset?.kind, .model)
        XCTAssertEqual(arm.asset?.path, "Arm/Arm.untold")
        XCTAssertTrue(arm.hasRenderingComponent)
        XCTAssertTrue(arm.hasLocalTransformComponent)
    }

    func testCreateUntoldSceneDecomposesMirroredScale() throws {
        // A negative-X-scale linear part, as Blender emits for a mirrored object.
        let json = """
        {
          "formatVersion": 1,
          "sourceAsset": "Mirror.blend",
          "models": [
            {
              "displayName": "MirroredProp",
              "path": "MirroredProp/MirroredProp.untold",
              "transform": [
                [-1.0, 0.0, 0.0, 3.0],
                [0.0, 1.0, 0.0, 0.0],
                [0.0, 0.0, 1.0, 0.0],
                [0.0, 0.0, 0.0, 1.0]
              ]
            }
          ]
        }
        """
        let packURL = tempRoot.appendingPathComponent("Mirror").appendingPathExtension("untoldpack")
        try Data(json.utf8).write(to: packURL)
        let sceneURL = tempRoot.appendingPathComponent("Mirror.untoldscene")

        XCTAssertTrue(createUntoldScene(fromPackAt: packURL, savingTo: sceneURL))

        let sceneData = try JSONDecoder().decode(SceneData.self, from: Data(contentsOf: sceneURL))
        let entity = try XCTUnwrap(sceneData.entities.first)
        // decomposeTRS must preserve the reflection as a negative scale rather than
        // collapsing it to a positive one (column length is always positive on its
        // own) -- otherwise mirrored Blender objects silently un-mirror on load.
        XCTAssertEqual(entity.scale.x, -1.0, accuracy: 0.0001)
        XCTAssertEqual(entity.scale.y, 1.0, accuracy: 0.0001)
        XCTAssertEqual(entity.scale.z, 1.0, accuracy: 0.0001)
        XCTAssertEqual(entity.position.x, 3.0, accuracy: 0.0001)
    }

    func testCreateUntoldSceneFailsWithoutAssetBasePath() throws {
        let packURL = try writePack(named: "Robot", models: [
            (displayName: "Body", path: "Body/Body.untold", translationX: 0.0),
        ])
        assetBasePath = nil
        let sceneURL = tempRoot.appendingPathComponent("Robot.untoldscene")

        XCTAssertFalse(createUntoldScene(fromPackAt: packURL, savingTo: sceneURL))
    }

    // MARK: - resolveProbedAssetURL (extension-less mesh/animation resolution)

    func testResolveProbedAssetURLPrefersPackOverUntold() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Foo").appendingPathExtension("untoldpack"))
        try Data().write(to: tempRoot.appendingPathComponent("Foo").appendingPathExtension("untold"))

        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Foo", ext: "", probeExtensions: ["untoldpack", "untold"]))
        XCTAssertEqual(url.pathExtension, "untoldpack")
    }

    func testResolveProbedAssetURLFallsBackToUntoldWhenNoPackExists() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Foo").appendingPathExtension("untold"))

        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Foo", ext: "", probeExtensions: ["untoldpack", "untold"]))
        XCTAssertEqual(url.pathExtension, "untold")
    }

    func testResolveProbedAssetURLPrefersUntoldAnimOverUntoldForAnimations() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Walk").appendingPathExtension("untoldanim"))
        try Data().write(to: tempRoot.appendingPathComponent("Walk").appendingPathExtension("untold"))

        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Walk", ext: "", probeExtensions: ["untoldanim", "untold"]))
        XCTAssertEqual(url.pathExtension, "untoldanim")
    }

    func testResolveProbedAssetURLHonorsExplicitExtensionOverProbing() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Foo").appendingPathExtension("untoldpack"))
        try Data().write(to: tempRoot.appendingPathComponent("Foo").appendingPathExtension("untold"))

        // A non-empty ext (explicit withExtension, or one embedded in filename) must
        // resolve exactly that file and skip probing entirely, even when a
        // higher-priority candidate also exists.
        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Foo", ext: "untold", probeExtensions: ["untoldpack", "untold"]))
        XCTAssertEqual(url.pathExtension, "untold")
    }

    func testResolveProbedAssetURLReturnsNilWhenNoCandidateExists() throws {
        XCTAssertNil(resolveProbedAssetURL(filename: "Missing", ext: "", probeExtensions: ["untoldpack", "untold"]))
    }

    func testResolveProbedAssetURLPrefersUntoldGSOverPLYForGaussianSplats() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("untoldgs"))
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("ply"))

        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Splat", ext: "", probeExtensions: ["untoldgs", "ply"]))
        XCTAssertEqual(url.pathExtension, "untoldgs")
    }

    func testResolveProbedAssetURLFallsBackToPLYWhenNoUntoldGSExists() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("ply"))

        let url = try XCTUnwrap(resolveProbedAssetURL(filename: "Splat", ext: "", probeExtensions: ["untoldgs", "ply"]))
        XCTAssertEqual(url.pathExtension, "ply")
    }

    func testResolveProbedAssetReturnsResolvedExtensionAlongsideURL() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("ply"))

        let resolved = try XCTUnwrap(resolveProbedAsset(filename: "Splat", ext: "", probeExtensions: ["untoldgs", "ply"]))
        XCTAssertEqual(resolved.extension, "ply")
        XCTAssertEqual(resolved.url.pathExtension, "ply")
    }

    func testResolveProbedAssetHonorsExplicitExtensionWithoutProbing() throws {
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("untoldgs"))
        try Data().write(to: tempRoot.appendingPathComponent("Splat").appendingPathExtension("ply"))

        let resolved = try XCTUnwrap(resolveProbedAsset(filename: "Splat", ext: "ply", probeExtensions: ["untoldgs", "ply"]))
        XCTAssertEqual(resolved.extension, "ply")
    }
}
