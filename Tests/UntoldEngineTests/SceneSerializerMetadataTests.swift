//
//  SceneSerializerMetadataTests.swift
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

final class SceneSerializerMetadataTests: XCTestCase {
    private var previousAssetBasePath: URL?
    private var previousApplyIBL = false
    private var previousRenderEnvironment = false
    private var previousHDRURL = ""
    private var previousAmbientIntensity: Float = 0.4
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAssetBasePath = assetBasePath
        previousApplyIBL = applyIBL
        previousRenderEnvironment = renderEnvironment
        previousHDRURL = hdrURL
        previousAmbientIntensity = ambientIntensity

        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SceneSerializerMetadataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        assetBasePath = tempRoot
        applyIBL = false
        renderEnvironment = false
        hdrURL = ""
        SceneAuthoredSourceStore.shared.clear()
        ColorLUTParams.shared.clear()
    }

    override func tearDownWithError() throws {
        SceneAuthoredSourceStore.shared.clear()
        ColorLUTParams.shared.clear()
        assetBasePath = previousAssetBasePath
        applyIBL = previousApplyIBL
        renderEnvironment = previousRenderEnvironment
        hdrURL = previousHDRURL
        ambientIntensity = previousAmbientIntensity
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
        try super.tearDownWithError()
    }

    func testSerializeScenePersistsSceneAuthoredSource() {
        let source = SceneAssetReference(
            kind: .model,
            path: "Models/Office/office.untold",
            displayName: "office"
        )
        SceneAuthoredSourceStore.shared.source = source

        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.sceneAuthoredSource?.kind, .model)
        XCTAssertEqual(sceneData.sceneAuthoredSource?.path, "Models/Office/office.untold")
        XCTAssertEqual(sceneData.sceneAuthoredSource?.displayName, "office")
    }

    func testSceneDataRoundTripsSceneAuthoredSource() throws {
        var sceneData = SceneData()
        sceneData.sceneAuthoredSource = SceneAssetReference(
            kind: .streamModel,
            path: "StreamModels/City/manifest.json",
            displayName: "City"
        )

        let encoded = try JSONEncoder().encode(sceneData)
        let decoded = try JSONDecoder().decode(SceneData.self, from: encoded)

        XCTAssertEqual(decoded.sceneAuthoredSource?.kind, .streamModel)
        XCTAssertEqual(decoded.sceneAuthoredSource?.path, "StreamModels/City/manifest.json")
        XCTAssertEqual(decoded.sceneAuthoredSource?.displayName, "City")
    }

    func testSerializeScenePersistsIBLWithoutRenderedEnvironment() throws {
        let hdrDirectory = tempRoot.appendingPathComponent("HDR", isDirectory: true)
        try FileManager.default.createDirectory(at: hdrDirectory, withIntermediateDirectories: true)
        try Data().write(to: hdrDirectory.appendingPathComponent("studio.hdr"))

        applyIBL = true
        renderEnvironment = false
        hdrURL = "studio.hdr"
        ambientIntensity = 0.7

        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.environment?.applyIBL, true)
        XCTAssertEqual(sceneData.environment?.renderEnvironment, false)
        XCTAssertEqual(sceneData.environment?.hdr, "studio.hdr")
        XCTAssertEqual(sceneData.environment?.ambientIntensity, 0.7)
    }

    func testDeserializeSceneRestoresHDRWhenIBLIsDisabled() {
        var sceneData = SceneData()
        sceneData.environment = EnvironmentData(
            applyIBL: false,
            renderEnvironment: true,
            hdr: "studio.hdr",
            ambientIntensity: 0.55
        )

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        XCTAssertFalse(applyIBL)
        XCTAssertTrue(renderEnvironment)
        XCTAssertEqual(hdrURL, "studio.hdr")
        XCTAssertEqual(ambientIntensity, 0.55)
    }
}
