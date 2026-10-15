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
    private var savedChosen = false

    override func setUp() {
        super.setUp()
        savedIndirect = renderInfo.perFragmentIndirectLighting
        savedLit = renderInfo.perFragmentLighting
        savedChosen = renderInfo.renderPathChosen
    }

    override func tearDown() {
        renderInfo.perFragmentIndirectLighting = savedIndirect
        renderInfo.perFragmentLighting = savedLit
        renderInfo.renderPathChosen = savedChosen
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

    func testTheDefaultPathIsThePlatforms() {
        // The two settings' defaults (RenderResources) compose the platform's path: forward on
        // visionOS, the headset's measured match for RealityKit's cost; deferred everywhere
        // else, as the engine was built.
        let defaults = RenderInfo()
        #if os(visionOS)
            XCTAssertEqual(RenderInfo.defaultRenderPath, .forward)
            XCTAssertTrue(defaults.perFragmentIndirectLighting)
            XCTAssertTrue(defaults.perFragmentLighting)
        #else
            XCTAssertEqual(RenderInfo.defaultRenderPath, .deferred)
            XCTAssertFalse(defaults.perFragmentIndirectLighting)
            XCTAssertFalse(defaults.perFragmentLighting)
        #endif
        XCTAssertFalse(defaults.renderPathChosen)
    }

    func testTheXRLoopAdoptsForwardUnlessThePathWasChosen() {
        // A Mac rendering a remote immersive space starts deferred like any Mac app and takes
        // the headset's path when its XR loop starts; the adoption is not the app's choice.
        renderInfo.renderPathChosen = false
        renderInfo.perFragmentIndirectLighting = false
        renderInfo.perFragmentLighting = false
        adoptXRRenderPathUnlessChosen()
        XCTAssertEqual(getRenderPath(), .forward)
        XCTAssertFalse(renderInfo.renderPathChosen)

        // A path the app chose stays, whichever way it was set.
        setRendering(.renderPath(.deferred))
        XCTAssertTrue(renderInfo.renderPathChosen)
        adoptXRRenderPathUnlessChosen()
        XCTAssertEqual(getRenderPath(), .deferred)

        renderInfo.renderPathChosen = false
        setRendering(.perFragmentIndirectLighting(.enabled))
        XCTAssertTrue(renderInfo.renderPathChosen)
        adoptXRRenderPathUnlessChosen()
        XCTAssertEqual(getRenderPath(), .hybrid)
    }
}
