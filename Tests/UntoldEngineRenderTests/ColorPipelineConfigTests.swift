//
//  ColorPipelineConfigTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
@testable import UntoldEngine
import XCTest

@MainActor
final class ColorPipelineConfigTests: XCTestCase {
    func testPresentOutputConfig_usesHardwareSRGB_forSRGBFormats() {
        let bgra = PresentOutputConfig(pixelFormat: .bgra8Unorm_srgb)
        let rgba = PresentOutputConfig(pixelFormat: .rgba8Unorm_srgb)

        XCTAssertEqual(bgra.encodingMode, .hardwareSRGB, "sRGB BGRA output should use hardware sRGB encode")
        XCTAssertEqual(rgba.encodingMode, .hardwareSRGB, "sRGB RGBA output should use hardware sRGB encode")
    }

    func testPresentOutputConfig_usesManualSRGBOETF_forLinearFormats() {
        let bgraLinear = PresentOutputConfig(pixelFormat: .bgra8Unorm)
        let rgbaLinear = PresentOutputConfig(pixelFormat: .rgba8Unorm)

        XCTAssertEqual(bgraLinear.encodingMode, .manualSRGBOETF, "Linear BGRA output should use manual sRGB OETF")
        XCTAssertEqual(rgbaLinear.encodingMode, .manualSRGBOETF, "Linear RGBA output should use manual sRGB OETF")
    }

    func testColorPipelineConfigStandard_keepsStableWorkingFormats() {
        let pipeline = ColorPipelineConfig.standard(presentFormat: .bgra8Unorm_srgb)

        XCTAssertEqual(pipeline.working.gBufferAlbedo, .rgba16Float)
        XCTAssertEqual(pipeline.working.sceneColor, .rgba16Float)
        XCTAssertEqual(pipeline.working.postProcess, .rgba16Float)
        XCTAssertEqual(pipeline.working.lookOutput, .rgba16Float)
        XCTAssertEqual(pipeline.present.pixelFormat, .bgra8Unorm_srgb)
    }

    func testPixelFormat_isSRGBFormat_onlyForSupportedSRGBTargets() {
        XCTAssertTrue(MTLPixelFormat.bgra8Unorm_srgb.isSRGBFormat)
        XCTAssertTrue(MTLPixelFormat.rgba8Unorm_srgb.isSRGBFormat)
        XCTAssertFalse(MTLPixelFormat.bgra8Unorm.isSRGBFormat)
        XCTAssertFalse(MTLPixelFormat.rgba16Float.isSRGBFormat)
    }
}
