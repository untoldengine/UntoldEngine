//
//  RenderExtensionPluginTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private final class TestPluginRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String

    init(id: String) {
        self.id = id
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private struct TestRenderExtensionPlugin: RenderExtensionPlugin {
    let manifest: RenderExtensionPluginManifest
    let extensions: [any RenderExtension]

    func makeRenderExtensions() -> [any RenderExtension] {
        extensions
    }
}

final class RenderExtensionPluginTest: XCTestCase {
    func testPluginVersionsAreComparableAndCodable() throws {
        let version = RenderExtensionPluginVersion(major: 1, minor: 4, patch: 2)
        let newerVersion = RenderExtensionPluginVersion(major: 1, minor: 5, patch: 0)

        XCTAssertLessThan(version, newerVersion)
        XCTAssertEqual(version.description, "1.4.2")
        XCTAssertEqual(
            try JSONDecoder().decode(
                RenderExtensionPluginVersion.self,
                from: JSONEncoder().encode(version)
            ),
            version
        )
    }

    func testValidPluginContractPassesValidation() {
        let plugin = makePlugin(
            id: "com.untold.water",
            extensionIDs: ["com.untold.water", "com.untold.water.caustics"]
        )

        let report = RenderExtensionPluginValidator.validate(plugin)

        XCTAssertTrue(report.isValid)
        XCTAssertTrue(report.errors.isEmpty)
    }

    func testManifestDefaultsToCurrentExtensionAPIVersion() {
        let plugin = makePlugin(id: "com.untold.water")

        XCTAssertEqual(plugin.manifest.requiredAPIVersion, .current)
        XCTAssertEqual(RenderExtensionAPIVersion.current.rawValue, 1)
    }

    func testMalformedManifestReportsAllIndependentErrors() {
        let plugin = makePlugin(
            id: "water plugin",
            displayName: " ",
            requiredAPIVersion: RenderExtensionAPIVersion(2),
            extensionIDs: []
        )

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate(plugin).errors,
            [
                .pluginIDMustBeNamespaced("water plugin"),
                .emptyDisplayName(pluginID: "water plugin"),
                .unsupportedAPIVersion(
                    pluginID: "water plugin",
                    required: RenderExtensionAPIVersion(2),
                    supported: .current
                ),
                .noExtensions(pluginID: "water plugin"),
            ]
        )
    }

    func testPluginIDRequiresPackageNamespace() {
        let plugin = makePlugin(id: "water", extensionIDs: ["water"])

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate(plugin).errors,
            [.pluginIDMustBeNamespaced("water")]
        )
    }

    func testWhitespaceOnlyPluginAndExtensionIDsAreEmpty() {
        let plugin = makePlugin(id: " ", extensionIDs: ["\n"])

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate(plugin).errors,
            [
                .emptyPluginID,
                .emptyExtensionID(pluginID: " "),
            ]
        )
    }

    func testExtensionIDsMustBelongToPluginNamespace() {
        let plugin = makePlugin(
            id: "com.untold.water",
            extensionIDs: ["com.other.grass"]
        )

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate(plugin).errors,
            [
                .extensionIDOutsidePluginNamespace(
                    pluginID: "com.untold.water",
                    extensionID: "com.other.grass"
                ),
            ]
        )
    }

    func testDuplicateAndEmptyExtensionIDsAreRejected() {
        let plugin = makePlugin(
            id: "com.untold.water",
            extensionIDs: ["com.untold.water.surface", "com.untold.water.surface", ""]
        )

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate(plugin).errors,
            [
                .duplicateExtensionID(
                    pluginID: "com.untold.water",
                    extensionID: "com.untold.water.surface"
                ),
                .emptyExtensionID(pluginID: "com.untold.water"),
            ]
        )
    }

    func testPluginCollectionRejectsDuplicatePluginIDsOnce() {
        let first = makePlugin(id: "com.untold.water")
        let second = makePlugin(id: "com.untold.water")
        let third = makePlugin(id: "com.untold.water")

        XCTAssertEqual(
            RenderExtensionPluginValidator.validate([first, second, third]).errors,
            [.duplicatePluginID("com.untold.water")]
        )
    }

    func testValidationCanTargetExplicitEngineAPIVersion() {
        let plugin = makePlugin(
            id: "com.untold.water",
            requiredAPIVersion: RenderExtensionAPIVersion(2)
        )

        XCTAssertTrue(
            RenderExtensionPluginValidator.validate(
                plugin,
                supportedAPIVersion: RenderExtensionAPIVersion(2)
            ).isValid
        )
    }

    private func makePlugin(
        id: String,
        displayName: String = "Water Rendering",
        requiredAPIVersion: RenderExtensionAPIVersion = .current,
        extensionIDs: [String]? = nil
    ) -> TestRenderExtensionPlugin {
        TestRenderExtensionPlugin(
            manifest: RenderExtensionPluginManifest(
                id: id,
                displayName: displayName,
                version: RenderExtensionPluginVersion(major: 1, minor: 0, patch: 0),
                requiredAPIVersion: requiredAPIVersion
            ),
            extensions: (extensionIDs ?? [id]).map(TestPluginRenderExtension.init(id:))
        )
    }
}
