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

    // MARK: - Instance count triangle multiplication

    func testRecordPrimitiveDraw_instanceCount_multipliesTriangles() {
        // 6 vertices / 3 = 2 triangles per instance × 5 instances = 10
        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .triangle,
            vertexCount: 6,
            instanceCount: 5,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1)
        XCTAssertEqual(stats.trianglesTotal, 10)
    }

    // MARK: - Triangle strip count

    func testRecordPrimitiveDraw_triangleStrip_correctTriangleCount() {
        // triangleStrip with 5 vertices = max(0, 5-2) = 3 triangles
        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .triangleStrip,
            vertexCount: 5,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1)
        XCTAssertEqual(stats.trianglesTotal, 3)
    }

    func testRecordPrimitiveDraw_triangleStripTooShort_zeroTriangles() {
        // A strip with fewer than 3 vertices cannot form a triangle.
        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .triangleStrip,
            vertexCount: 2,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1)
        XCTAssertEqual(stats.trianglesTotal, 0)
    }

    // MARK: - Non-triangle primitives

    func testRecordPrimitiveDraw_linePrimitive_zeroTriangles() {
        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .line,
            vertexCount: 10,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1, "Draw call should still be counted")
        XCTAssertEqual(stats.trianglesTotal, 0, "Line primitives produce no triangles")
    }

    func testRecordPrimitiveDraw_pointPrimitive_zeroTriangles() {
        RenderStatsCollector.shared.recordPrimitiveDraw(
            type: .point,
            vertexCount: 8,
            category: .opaque
        )

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 1)
        XCTAssertEqual(stats.trianglesTotal, 0)
    }

    // MARK: - Reset

    func testReset_clearAllCounters() {
        RenderStatsCollector.shared.recordIndexedDraw(type: .triangle, indexCount: 30, category: .opaque)
        RenderStatsCollector.shared.recordPrimitiveDraw(type: .triangle, vertexCount: 9, category: .shadow)
        RenderStatsCollector.shared.reset()

        let stats = RenderStatsCollector.shared.snapshot()
        XCTAssertEqual(stats.drawCallsTotal, 0)
        XCTAssertEqual(stats.drawCallsOpaque, 0)
        XCTAssertEqual(stats.drawCallsShadow, 0)
        XCTAssertEqual(stats.trianglesTotal, 0)
    }
}
