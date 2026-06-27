//
//  RenderExtensionShaderSupportTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import UntoldEngine
import UntoldEngineShaderSupport
import XCTest

final class RenderExtensionShaderSupportTests: XCTestCase {
    func testModelSurfaceExtensionArgumentBufferABI() {
        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentBufferIndex.rawValue, 10)

        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentTexture0.rawValue, 0)
        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentTexture7.rawValue, 7)

        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentSampler0.rawValue, 8)
        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentSampler7.rawValue, 15)

        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentBuffer0.rawValue, 16)
        XCTAssertEqual(UntoldModelSurfaceExtensionArgumentBuffer15.rawValue, 31)
    }

    func testSwiftModelSurfaceExtensionArgumentConstantsMatchShaderSupport() {
        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.argumentBufferIndex,
            Int(UntoldModelSurfaceExtensionArgumentBufferIndex.rawValue)
        )

        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.texture0,
            Int(UntoldModelSurfaceExtensionArgumentTexture0.rawValue)
        )
        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.texture7,
            Int(UntoldModelSurfaceExtensionArgumentTexture7.rawValue)
        )

        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.sampler0,
            Int(UntoldModelSurfaceExtensionArgumentSampler0.rawValue)
        )
        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.sampler7,
            Int(UntoldModelSurfaceExtensionArgumentSampler7.rawValue)
        )

        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.buffer0,
            Int(UntoldModelSurfaceExtensionArgumentBuffer0.rawValue)
        )
        XCTAssertEqual(
            RenderExtensionModelSurfaceArgument.buffer15,
            Int(UntoldModelSurfaceExtensionArgumentBuffer15.rawValue)
        )
    }

    func testLegacyModelSurfaceExtensionSlotsRemainStableDuringMigration() {
        XCTAssertEqual(UntoldModelSurfaceExtensionFragmentBuffer0.rawValue, 10)
        XCTAssertEqual(UntoldModelSurfaceExtensionFragmentBuffer3.rawValue, 13)

        XCTAssertEqual(UntoldModelSurfaceExtensionFragmentTexture0.rawValue, 10)
        XCTAssertEqual(UntoldModelSurfaceExtensionFragmentTexture3.rawValue, 13)
    }
}
