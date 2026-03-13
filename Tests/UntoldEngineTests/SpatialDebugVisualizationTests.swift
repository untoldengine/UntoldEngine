//
//  SpatialDebugVisualizationTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

@MainActor
final class SpatialDebugVisualizationTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        SpatialDebugVisualization.shared.disableAll()
        SpatialDebugVisualization.shared.maxLeafNodeCount = 2000
        SpatialDebugVisualization.shared.octreeLeafOccupiedOnly = true
        SpatialDebugVisualization.shared.octreeLeafColorMode = .plain
    }

    override func tearDown() async throws {
        SpatialDebugVisualization.shared.disableAll()
    }

    func testConfigureOctreeLeafBoundsUpdatesSettings() {
        setOctreeLeafBoundsDebug(
            enabled: true,
            maxLeafNodeCount: 128,
            occupiedOnly: false,
            colorMode: .culling
        )

        let settings = SpatialDebugVisualization.shared
        XCTAssertTrue(settings.enabled)
        XCTAssertTrue(settings.showOctreeLeafBounds)
        XCTAssertEqual(settings.maxLeafNodeCount, 128)
        XCTAssertFalse(settings.octreeLeafOccupiedOnly)
        XCTAssertEqual(settings.octreeLeafColorMode, .culling)
    }

    func testConfigureOctreeLeafBoundsClampsNegativeMaxCount() {
        setOctreeLeafBoundsDebug(
            enabled: true,
            maxLeafNodeCount: -7,
            occupiedOnly: true,
            colorMode: .plain
        )

        XCTAssertEqual(
            SpatialDebugVisualization.shared.maxLeafNodeCount,
            0,
            "maxLeafNodeCount should clamp to 0"
        )
    }

    func testLODLevelDebugToggleUpdatesMasterEnabledState() {
        setLODLevelDebug(enabled: true)
        XCTAssertTrue(SpatialDebugVisualization.shared.colorRenderablesByLOD)
        XCTAssertTrue(SpatialDebugVisualization.shared.enabled)

        setLODLevelDebug(enabled: false)
        XCTAssertFalse(SpatialDebugVisualization.shared.colorRenderablesByLOD)
        XCTAssertFalse(SpatialDebugVisualization.shared.enabled)
    }

    func testDisablingOctreeKeepsMasterEnabledIfLODDebugIsOn() {
        setLODLevelDebug(enabled: true)
        setOctreeLeafBoundsDebug(enabled: false, colorMode: .plain)

        let settings = SpatialDebugVisualization.shared
        XCTAssertFalse(settings.showOctreeLeafBounds)
        XCTAssertTrue(settings.colorRenderablesByLOD)
        XCTAssertTrue(settings.enabled, "Master debug should remain enabled while LOD coloring is on")
    }

    func testDisableAllClearsOctreeAndLODDebugFlags() {
        setOctreeLeafBoundsDebug(enabled: true, colorMode: .residency)
        setLODLevelDebug(enabled: true)

        disableSpatialDebugVisualization()

        let settings = SpatialDebugVisualization.shared
        XCTAssertFalse(settings.enabled)
        XCTAssertFalse(settings.showOctreeLeafBounds)
        XCTAssertFalse(settings.colorRenderablesByLOD)
    }
}
