//
//  EngineStatsMonitorTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class EngineStatsMonitorTests: XCTestCase {
    override func setUp() {
        super.setUp()
        EngineStatsMonitor.shared.reset()
        setEngineStatsLogging(enabled: false)
    }

    override func tearDown() {
        setEngineStatsLogging(enabled: false)
        EngineStatsMonitor.shared.reset()
        super.tearDown()
    }

    func testPublicAPI_returnsDefaultSnapshot() {
        let snapshot = getEngineStatsSnapshot()

        XCTAssertEqual(snapshot.frameIndex, 0)
        XCTAssertEqual(snapshot.timestampSeconds, 0.0)
        XCTAssertEqual(snapshot.timing.frameTotalMs, 0.0)
        XCTAssertEqual(snapshot.render.drawCallsTotal, 0)
        XCTAssertEqual(snapshot.culling.frustumTested, 0)
        XCTAssertEqual(snapshot.streaming.activeLoads, 0)
        XCTAssertEqual(snapshot.batching.batchGroupCount, 0)
    }

    func testMonitorUpdate_changesSnapshotValues() {
        EngineStatsMonitor.shared.update { snapshot in
            snapshot.frameIndex = 42
            snapshot.timestampSeconds = 12.5
            snapshot.timing.updateMs = 3.7
            snapshot.render.drawCallsTotal = 17
            snapshot.culling.frustumPassed = 91
            snapshot.streaming.activeLoads = 2
            snapshot.batching.batchGroupCount = 5
        }

        let snapshot = getEngineStatsSnapshot()

        XCTAssertEqual(snapshot.frameIndex, 42)
        XCTAssertEqual(snapshot.timestampSeconds, 12.5)
        XCTAssertEqual(snapshot.timing.updateMs, 3.7)
        XCTAssertEqual(snapshot.render.drawCallsTotal, 17)
        XCTAssertEqual(snapshot.culling.frustumPassed, 91)
        XCTAssertEqual(snapshot.streaming.activeLoads, 2)
        XCTAssertEqual(snapshot.batching.batchGroupCount, 5)
    }

    func testSetEngineStatsLogging_togglesMonitor() {
        setEngineStatsLogging(enabled: true)
        XCTAssertTrue(EngineStatsMonitor.shared.enableLogging)

        setEngineStatsLogging(enabled: false)
        XCTAssertFalse(EngineStatsMonitor.shared.enableLogging)
    }

    func testSetEngineStatsLogging_configuresProfileAndInterval() {
        setEngineStatsLogging(enabled: true, profile: .verbose, intervalSeconds: 0.25)

        XCTAssertTrue(EngineStatsMonitor.shared.enableLogging)
        XCTAssertEqual(EngineStatsMonitor.shared.loggingProfile, .verbose)
        XCTAssertEqual(EngineStatsMonitor.shared.loggingIntervalSeconds, 0.25)

        setEngineStatsLogging(enabled: true, profile: .compact, intervalSeconds: 0.0)
        XCTAssertEqual(EngineStatsMonitor.shared.loggingProfile, .compact)
        XCTAssertEqual(EngineStatsMonitor.shared.loggingIntervalSeconds, 0.1)
    }

    func testBeginFrame_incrementsFrameAndResetsTiming() {
        EngineStatsMonitor.shared.update { snapshot in
            snapshot.timing.frameTotalMs = 10.0
            snapshot.timing.updateMs = 5.0
            snapshot.timing.renderTotalMs = 4.0
            snapshot.timing.cullingMs = 2.0
        }

        EngineStatsMonitor.shared.beginFrame(timestampSeconds: 99.0)

        let snapshot = getEngineStatsSnapshot()
        XCTAssertEqual(snapshot.frameIndex, 1)
        XCTAssertEqual(snapshot.timestampSeconds, 99.0)
        XCTAssertEqual(snapshot.timing.frameTotalMs, 0.0)
        XCTAssertEqual(snapshot.timing.updateMs, 0.0)
        XCTAssertEqual(snapshot.timing.renderTotalMs, 0.0)
        XCTAssertEqual(snapshot.timing.cullingMs, 0.0)
    }

    func testSnapshot_returnsLastCompletedFrameForNextFrameReads() {
        EngineStatsMonitor.shared.beginFrame(timestampSeconds: 1.0)
        EngineStatsMonitor.shared.update { snapshot in
            snapshot.timing.frameTotalMs = 16.6
            snapshot.timing.updateMs = 4.2
        }
        EngineStatsMonitor.shared.completeFrame()

        // Start next frame; current in-progress timing is reset.
        EngineStatsMonitor.shared.beginFrame(timestampSeconds: 2.0)

        let published = getEngineStatsSnapshot()
        XCTAssertEqual(published.frameIndex, 1)
        XCTAssertEqual(published.timing.frameTotalMs, 16.6)
        XCTAssertEqual(published.timing.updateMs, 4.2)

        let inProgress = getEngineStatsSnapshotInProgress()
        XCTAssertEqual(inProgress.frameIndex, 2)
        XCTAssertEqual(inProgress.timing.frameTotalMs, 0.0)
    }

    func testFormatEngineStatsOverlay_containsCoreSections() {
        var snapshot = EngineStatsSnapshot()
        snapshot.frameIndex = 7
        snapshot.timing.frameTotalMs = 16.0
        snapshot.timing.updateMs = 5.0
        snapshot.timing.renderTotalMs = 8.0
        snapshot.render.drawCallsTotal = 42
        snapshot.render.trianglesTotal = 12000
        snapshot.culling.frustumPassed = 90
        snapshot.culling.frustumTested = 100

        let overlay = formatEngineStatsOverlay(snapshot)
        let compact = formatEngineStatsCompact(snapshot)

        XCTAssertTrue(overlay.contains("Frame 7"))
        XCTAssertTrue(overlay.contains("Timing:"))
        XCTAssertTrue(overlay.contains("Render:"))
        XCTAssertTrue(overlay.contains("Culling:"))
        XCTAssertTrue(compact.contains("frame=7"))
        XCTAssertTrue(compact.contains("drawCalls=42"))
    }
}
