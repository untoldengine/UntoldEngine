//
//  FrameMetricsCollectorTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest

final class FrameMetricsCollectorTests: XCTestCase {
    // MARK: - Empty state

    func testSnapshot_returnsEmptyWhenNoSamples() {
        let collector = FrameMetricsCollector()
        let snapshot = collector.snapshot()

        XCTAssertEqual(snapshot.sampleCount, 0)
        XCTAssertEqual(snapshot.meanMs, 0.0)
        XCTAssertEqual(snapshot.p95Ms, 0.0)
        XCTAssertEqual(snapshot.p99Ms, 0.0)
        XCTAssertEqual(snapshot.minMs, 0.0)
        XCTAssertEqual(snapshot.maxMs, 0.0)
    }

    // MARK: - Single sample

    func testSnapshot_singleSample_allStatsEqualThatSample() {
        let collector = FrameMetricsCollector()
        collector.record(7.5)

        let snapshot = collector.snapshot()
        XCTAssertEqual(snapshot.sampleCount, 1)
        XCTAssertEqual(snapshot.meanMs, 7.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.minMs, 7.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxMs, 7.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.p95Ms, 7.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.p99Ms, 7.5, accuracy: 0.001)
    }

    // MARK: - Percentile correctness

    func testSnapshot_percentiles_knownSamples() {
        // Record 1.0 ms through 100.0 ms in order.
        // After sorting: [1, 2, ..., 100]
        // p95Index = Int(99 * 0.95) = 94  → validSamples[94] = 95.0
        // p99Index = Int(99 * 0.99) = 98  → validSamples[98] = 99.0
        let collector = FrameMetricsCollector(capacity: 200)
        for i in 1 ... 100 {
            collector.record(Double(i))
        }

        let snapshot = collector.snapshot()
        XCTAssertEqual(snapshot.sampleCount, 100)
        XCTAssertEqual(snapshot.meanMs, 50.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.minMs, 1.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.maxMs, 100.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.p95Ms, 95.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.p99Ms, 99.0, accuracy: 0.001)
    }

    // MARK: - Ring buffer rollover

    func testRingBuffer_rollover_sampleCountCapsAtCapacity() {
        let capacity = 50
        let collector = FrameMetricsCollector(capacity: capacity)

        for i in 0 ..< (capacity + 10) {
            collector.record(Double(i))
        }

        // sampleCount should not exceed capacity.
        let snapshot = collector.snapshot()
        XCTAssertEqual(snapshot.sampleCount, capacity)
    }

    func testRingBuffer_rollover_statsReflectLatestWindow() {
        // Fill a tiny ring with 1s, then overwrite with 100s.
        // After rollover the mean should shift toward 100.
        let capacity = 10
        let collector = FrameMetricsCollector(capacity: capacity)

        for _ in 0 ..< capacity {
            collector.record(1.0)
        }
        for _ in 0 ..< capacity {
            collector.record(100.0)
        }

        let snapshot = collector.snapshot()
        XCTAssertEqual(snapshot.sampleCount, capacity)
        XCTAssertGreaterThan(snapshot.meanMs, 1.0, "Mean should have shifted after rollover")
    }

    // MARK: - Reset

    func testReset_clearsAllSamples() {
        let collector = FrameMetricsCollector(capacity: 10)
        collector.record(5.0)
        collector.record(10.0)
        collector.reset()

        let snapshot = collector.snapshot()
        XCTAssertEqual(snapshot.sampleCount, 0)
    }

    // MARK: - Thread safety

    func testThreadSafety_concurrentRecordsDoNotCrash() {
        let collector = FrameMetricsCollector(capacity: 100)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let iterations = 500

        for i in 0 ..< iterations {
            group.enter()
            queue.async {
                collector.record(Double(i % 50))
                group.leave()
            }
        }

        group.wait()

        // If we reach here without a crash the lock is doing its job.
        let snapshot = collector.snapshot()
        XCTAssertGreaterThan(snapshot.sampleCount, 0)
    }

    func testThreadSafety_concurrentRecordAndSnapshot_doesNotCrash() {
        let collector = FrameMetricsCollector(capacity: 100)
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0 ..< 200 {
            group.enter()
            queue.async {
                collector.record(Double(i))
                group.leave()
            }
            group.enter()
            queue.async {
                _ = collector.snapshot()
                group.leave()
            }
        }

        group.wait()
        XCTAssertGreaterThan(collector.snapshot().sampleCount, 0)
    }
}
