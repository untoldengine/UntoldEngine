//
//  RenderPathTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

/// The render path names what the two per-fragment settings compose.
final class RenderPathTests: XCTestCase {
    private var savedIndirect = true
    private var savedLit = true

    override func setUp() {
        super.setUp()
        savedIndirect = renderInfo.perFragmentIndirectLighting
        savedLit = renderInfo.perFragmentLighting
    }

    override func tearDown() {
        renderInfo.perFragmentIndirectLighting = savedIndirect
        renderInfo.perFragmentLighting = savedLit
        super.tearDown()
    }

    func testEachPathSetsTheTwoSettings() {
        setRendering(.renderPath(.deferred))
        XCTAssertFalse(renderInfo.perFragmentIndirectLighting)
        XCTAssertFalse(renderInfo.perFragmentLighting)
        XCTAssertEqual(getRenderPath(), .deferred)

        setRendering(.renderPath(.hybrid))
        XCTAssertTrue(renderInfo.perFragmentIndirectLighting)
        XCTAssertFalse(renderInfo.perFragmentLighting)
        XCTAssertEqual(getRenderPath(), .hybrid)

        setRendering(.renderPath(.forward))
        XCTAssertTrue(renderInfo.perFragmentIndirectLighting)
        XCTAssertTrue(renderInfo.perFragmentLighting)
        XCTAssertEqual(getRenderPath(), .forward)
    }

    func testTheSettingsSetOneByOneReadBackAsAPath() {
        setRendering(.perFragmentIndirectLighting(.disabled))
        setRendering(.perFragmentLighting(.enabled))
        XCTAssertEqual(getRenderPath(), .deferred, "the direct light per fragment needs the indirect: without it the quad lights")
        setRendering(.perFragmentIndirectLighting(.enabled))
        XCTAssertEqual(getRenderPath(), .forward)
        setRendering(.perFragmentLighting(.disabled))
        XCTAssertEqual(getRenderPath(), .hybrid)
    }

    func testForwardIsTheDefault() {
        // The two settings' defaults (RenderResources) are both on.
        let defaults = RenderInfo()
        XCTAssertTrue(defaults.perFragmentIndirectLighting)
        XCTAssertTrue(defaults.perFragmentLighting)
    }
}
