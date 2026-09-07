//
//  UntoldAssetPatcherRenderTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import simd
@testable import UntoldEngine
import XCTest

/// A `.untold` the exporter cooked, linked to a splat payload by `UntoldAssetPatcher`, comes
/// up through `setEntityMesh` with the link on the mesh entity as `GaussianAssetLinkComponent`.
@MainActor
final class UntoldAssetPatcherRenderTest: BaseRenderSetup {
    private var temporaryFiles: [URL] = []

    override func tearDown() async throws {
        destroyAllEntities()
        for url in temporaryFiles {
            try? FileManager.default.removeItem(at: url)
        }
        temporaryFiles.removeAll()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    func testPatchedCookedAssetArrivesAsALinkComponent() throws {
        let sourceURL = try XCTUnwrap(Bundle.module.url(forResource: "singlecube", withExtension: "untold"))
        let original = try Data(contentsOf: sourceURL)
        let entityId = try XCTUnwrap(UntoldReader().readAsset(from: original).entities.first?.entityId)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("UntoldAssetPatcherRenderTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        temporaryFiles.append(directory)
        let link = UntoldAssetPatcher.GaussianAssetLink(
            payloadPath: "singlecube.untoldgs",
            lodCount: 1,
            lodSplatCounts: [4096],
            lodSwitchScreenHeights: [0],
            occluderShrinkMeters: 0.03,
            exposureOffsetEV: 0.5,
            swapDistanceMeters: 12
        )
        let patched = try UntoldAssetPatcher.settingGaussianAsset(link, onEntity: entityId, in: original)
        let untoldURL = directory.appendingPathComponent("singlecube.untold")
        try patched.write(to: untoldURL, options: .atomic)

        let entity = createEntity()
        setEntityMesh(entityId: entity, filename: untoldURL.deletingPathExtension().path, withExtension: "untold")

        XCTAssertNotNil(scene.get(component: RenderComponent.self, for: entity), "The cube mesh still loads")
        let component = try XCTUnwrap(scene.get(component: GaussianAssetLinkComponent.self, for: entity), "The patched record arrives as link data")
        XCTAssertEqual(component.payloadURL?.standardizedFileURL, directory.appendingPathComponent("singlecube.untoldgs").standardizedFileURL, "Payload resolved next to the .untold file")
        XCTAssertTrue(component.isMeshTwin)
        XCTAssertEqual(component.lodCount, 1)
        XCTAssertEqual(component.lodSplatCounts, [4096])
        XCTAssertEqual(component.lodSwitchScreenHeights, [0])
        XCTAssertEqual(component.occluderShrinkMeters, 0.03)
        XCTAssertEqual(component.exposureOffsetEV, 0.5)
        XCTAssertEqual(component.swapDistanceMeters, 12)
        XCTAssertNil(scene.get(component: GaussianComponent.self, for: entity), "Linking loads nothing")
    }
}
