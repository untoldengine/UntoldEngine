//
//  ColorPrimariesTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class ColorPrimariesTests: XCTestCase {
    func testEachChoiceSelectsItsShaderBranch() {
        // The shader's ColorPrimariesID: sRGB 0, Display P3 1.
        XCTAssertEqual(ColorPrimaries.sRGB.shaderValue, 0)
        XCTAssertEqual(ColorPrimaries.displayP3.shaderValue, 1)
    }

    func testTheSettingReachesTheLookPassAndDefaultsToSRGB() {
        let saved = TonemapParams.shared.primaries
        defer { setPostFX(.colorPrimaries(saved)) }
        setPostFX(.colorPrimaries(.displayP3))
        XCTAssertEqual(TonemapParams.shared.primaries, .displayP3)
        setPostFX(.colorPrimaries(.sRGB))
        XCTAssertEqual(TonemapParams.shared.primaries, .sRGB)
        TonemapParams.shared.primaries = .displayP3
        TonemapParams.shared.resetToDefaults()
        XCTAssertEqual(TonemapParams.shared.primaries, .sRGB, "the default")
    }
}
