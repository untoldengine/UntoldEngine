//
//  WaterRenderPluginTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import UntoldEngine
import WaterRenderPlugin
import XCTest

final class WaterRenderPluginTests: XCTestCase {
    func testPluginManifestAndExtensionNamespaceAreValid() {
        let plugin = WaterRenderPlugin()

        XCTAssertEqual(plugin.manifest.id, WaterRenderPluginContract.pluginID)
        XCTAssertEqual(plugin.manifest.requiredAPIVersion, .current)
        XCTAssertTrue(RenderExtensionPluginValidator.validate(plugin).isValid)
        XCTAssertEqual(
            plugin.makeRenderExtensions().map(\.id),
            [WaterRenderPluginContract.extensionID]
        )
    }

    func testBundledMetallibContainsEveryDeclaredFunction() throws {
        let url = try XCTUnwrap(WaterRenderPlugin.bundledMetallibURL)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(URL: url)

        XCTAssertNotNil(library.makeFunction(name: "waterFixtureTextureKernel"))
        XCTAssertNotNil(library.makeFunction(name: "waterFixtureSurfaceFragment"))
        XCTAssertNotNil(library.makeFunction(name: "waterFixtureProceduralVertex"))
        XCTAssertNotNil(library.makeFunction(name: "waterFixtureProceduralFragment"))
    }

    func testPublicRegistrationEntryPointHasPluginInstallationSignature() {
        let entryPoint: () -> RenderExtensionPluginInstallationResult = registerWaterRenderPlugin
        _ = entryPoint
    }
}
