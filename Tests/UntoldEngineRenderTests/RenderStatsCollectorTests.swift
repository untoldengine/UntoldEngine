//
//  RenderStatsCollectorTests.swift
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
final class RenderStatsCollectorTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        RenderStatsCollector.shared.reset()
    }

    override func tearDown() async throws {
        RenderStatsCollector.shared.reset()
        try await super.tearDown()
    }

    func testRecordIndexedDraw_countsOpaqueAndTriangles() {
        RenderStatsCollector.shared.recordIndexedDraw(
            type: .triangle,
            indexCount: 300,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1)
        XCTAssertEqual(stats.drawCallsOpaque, 1)
        XCTAssertEqual(stats.drawCallsTransparent, 0)
        XCTAssertEqual(stats.drawCallsShadow, 0)
        XCTAssertEqual(stats.drawCallsBatched, 0)
        XCTAssertEqual(stats.trianglesTotal, 100)
    }

    func testRecordMixedDraws_tracksBatchedAndTransparentTriangles() {
        RenderStatsCollector.shared.recordIndexedDraw(
            type: .triangle,
            indexCount: 6,
            category: .shadow,
            batched: true
        )

        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .triangleStrip,
            vertexCount: 4,
            instanceCount: 10,
            category: .transparent
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 2)
        XCTAssertEqual(stats.drawCallsOpaque, 0)
        XCTAssertEqual(stats.drawCallsTransparent, 1)
        XCTAssertEqual(stats.drawCallsShadow, 1)
        XCTAssertEqual(stats.drawCallsBatched, 1)
        XCTAssertEqual(stats.trianglesTotal, 22)
    }
}
