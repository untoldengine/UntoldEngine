//
//  TonemapOperatorTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class TonemapOperatorTests: XCTestCase {
    func testEachOperatorSelectsItsShaderBranch() {
        // The shader's TonemapOperatorID: ACES 0, AgX 1, none 2.
        XCTAssertEqual(TonemapOperator.aces.shaderValue, 0)
        XCTAssertEqual(TonemapOperator.agx.shaderValue, 1)
        XCTAssertEqual(TonemapOperator.none.shaderValue, 2)
    }

    func testTheSettingReachesTheLookPass() {
        let saved = TonemapParams.shared.operator
        defer { setPostFX(.tonemapOperator(saved)) }
        setPostFX(.tonemapOperator(.none))
        XCTAssertEqual(TonemapParams.shared.operator, .none)
        setPostFX(.tonemapOperator(.aces))
        XCTAssertEqual(TonemapParams.shared.operator, .aces)
    }
}
