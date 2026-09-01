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

import Metal
@testable import UntoldEngine
import XCTest

private let minimalCubeLUTFixture = """
TITLE "Test LUT"
LUT_3D_SIZE 2
0.0 0.0 0.0
1.0 0.0 0.0
0.0 1.0 0.0
1.0 1.0 0.0
0.0 0.0 1.0
1.0 0.0 1.0
0.0 1.0 1.0
1.0 1.0 1.0
"""

final class SceneSerializerMetadataTests: XCTestCase {
    private var previousAssetBasePath: URL?
    private var previousApplyIBL = false
    private var previousRenderEnvironment = false
    private var previousHDRURL = ""
    private var previousAmbientIntensity: Float = 0.4
    private var previousTonemapOperator: TonemapOperator = .aces
    private var previousDevice: MTLDevice!
    private var tempRoot: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousAssetBasePath = assetBasePath
        previousApplyIBL = applyIBL
        previousRenderEnvironment = renderEnvironment
        previousHDRURL = hdrURL
        previousAmbientIntensity = ambientIntensity
        previousTonemapOperator = TonemapParams.shared.operator
        previousDevice = renderInfo.device

        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("SceneSerializerMetadataTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        assetBasePath = tempRoot
        applyIBL = false
        renderEnvironment = false
        hdrURL = ""
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        renderInfo.device = device
        SceneAuthoredSourceStore.shared.clear()
        ColorLUTParams.shared.clear()
        ColorGradeLUTParams.shared.clear()
    }

    override func tearDownWithError() throws {
        SceneAuthoredSourceStore.shared.clear()
        ColorLUTParams.shared.clear()
        ColorGradeLUTParams.shared.clear()
        TonemapParams.shared.operator = previousTonemapOperator
        renderInfo.device = previousDevice
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

    // MARK: - Tonemap Operator

    func testSerializeScenePersistsTonemapOperator() {
        TonemapParams.shared.operator = .agx

        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.tonemapOperator, .agx)
    }

    func testDeserializeSceneRestoresTonemapOperator() {
        TonemapParams.shared.operator = .aces
        var sceneData = SceneData()
        sceneData.tonemapOperator = .agx

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        XCTAssertEqual(TonemapParams.shared.operator, .agx)
    }

    func testSceneDataRoundTripsTonemapOperator() throws {
        var sceneData = SceneData()
        sceneData.tonemapOperator = .agx

        let encoded = try JSONEncoder().encode(sceneData)
        let decoded = try JSONDecoder().decode(SceneData.self, from: encoded)

        XCTAssertEqual(decoded.tonemapOperator, .agx)
    }

    func testDeserializeSceneWithNoTonemapOperatorLeavesCurrentValueUnchanged() {
        TonemapParams.shared.operator = .agx
        let sceneData = SceneData() // tonemapOperator is nil, as in an older saved scene

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        XCTAssertEqual(TonemapParams.shared.operator, .agx, "Absent tonemapOperator must not reset the runtime value")
    }

    // MARK: - Standalone Color Grade LUT

    private func stageMinimalCubeFixture(named name: String = "test") throws {
        let lutDirectory = tempRoot.appendingPathComponent("LUT", isDirectory: true)
        try FileManager.default.createDirectory(at: lutDirectory, withIntermediateDirectories: true)
        try minimalCubeLUTFixture.write(
            to: lutDirectory.appendingPathComponent(name).appendingPathExtension("cube"),
            atomically: true,
            encoding: .utf8
        )
    }

    func testSerializeScenePersistsStandaloneColorGradeLUT() throws {
        try stageMinimalCubeFixture()
        setColorGradeLUT(filename: "test")

        let sceneData = serializeScene()

        XCTAssertEqual(sceneData.colorGradeLUTFilename, "test")
        XCTAssertEqual(sceneData.colorGradeLUTExtension, "cube")
    }

    func testSerializeSceneOmitsColorGradeLUTFilenameWhenNoneSet() {
        let sceneData = serializeScene()

        XCTAssertNil(sceneData.colorGradeLUTFilename)
    }

    func testDeserializeSceneRestoresStandaloneColorGradeLUT() throws {
        try stageMinimalCubeFixture()

        var sceneData = SceneData()
        sceneData.colorGradeLUTFilename = "test"
        sceneData.colorGradeLUTExtension = "cube"

        deserializeScene(sceneData: sceneData, meshLoadingMode: .sync)

        XCTAssertTrue(ColorGradeLUTParams.shared.enabled)
        XCTAssertEqual(ColorGradeLUTParams.shared.source?.filename, "test")
        XCTAssertEqual(ColorGradeLUTParams.shared.source?.extension, "cube")
    }

    func testSceneDataRoundTripsColorGradeLUTFilename() throws {
        var sceneData = SceneData()
        sceneData.colorGradeLUTFilename = "warm_grade"
        sceneData.colorGradeLUTExtension = "cube"

        let encoded = try JSONEncoder().encode(sceneData)
        let decoded = try JSONDecoder().decode(SceneData.self, from: encoded)

        XCTAssertEqual(decoded.colorGradeLUTFilename, "warm_grade")
        XCTAssertEqual(decoded.colorGradeLUTExtension, "cube")
    }
}
