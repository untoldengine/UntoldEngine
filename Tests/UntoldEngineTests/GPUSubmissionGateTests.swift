//
//  GPUSubmissionGateTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import QuartzCore
@testable import UntoldEngine
import XCTest

/// The GPU gate is open unless the app is inactive or in the background, where the system
/// refuses GPU work: closed, it holds the engine's loaders and loops until it opens again, never
/// the main thread, and it counts the resumes for the frame clock.
final class GPUSubmissionGateTests: XCTestCase {
    /// What a waiter on another thread saw, read back on the test's thread.
    private final class WaitRecord: @unchecked Sendable {
        private let lock = NSLock()
        private var openValue = false
        private var returnedAtValue: CFTimeInterval = 0

        func record(open: Bool, returnedAt: CFTimeInterval) {
            lock.withLock {
                openValue = open
                returnedAtValue = returnedAt
            }
        }

        var open: Bool {
            lock.withLock { openValue }
        }

        var returnedAt: CFTimeInterval {
            lock.withLock { returnedAtValue }
        }
    }

    func testTheGateStartsOpenAndAWaitReturnsAtOnce() {
        let gate = GPUSubmissionGate()
        XCTAssertTrue(gate.isOpen)
        XCTAssertEqual(gate.resumeCount, 0)
        let start = CACurrentMediaTime()
        XCTAssertTrue(gate.waitUntilOpen(timeout: 1.0))
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.5)
    }

    func testClosingAndOpeningCountsTheResumesOnce() {
        let gate = GPUSubmissionGate()
        gate.close(reason: "test")
        XCTAssertFalse(gate.isOpen)
        // Closing a closed gate changes nothing.
        gate.close(reason: "test again")
        XCTAssertFalse(gate.isOpen)
        gate.open(reason: "test")
        XCTAssertTrue(gate.isOpen)
        XCTAssertEqual(gate.resumeCount, 1)
        // Opening an open gate counts no resume.
        gate.open(reason: "test again")
        XCTAssertEqual(gate.resumeCount, 1)
        gate.close(reason: "test")
        gate.open(reason: "test")
        XCTAssertEqual(gate.resumeCount, 2)
    }

    func testAClosedGateHoldsAThreadUntilItOpens() {
        let gate = GPUSubmissionGate()
        gate.close(reason: "test")
        let record = WaitRecord()
        let released = expectation(description: "the waiter is released")
        DispatchQueue.global().async {
            let open = gate.waitUntilOpen(timeout: 5.0)
            record.record(open: open, returnedAt: CACurrentMediaTime())
            released.fulfill()
        }
        // The waiter holds while the gate stays closed.
        Thread.sleep(forTimeInterval: 0.2)
        XCTAssertEqual(record.returnedAt, 0)
        let openedAt = CACurrentMediaTime()
        gate.open(reason: "test")
        wait(for: [released], timeout: 5.0)
        XCTAssertTrue(record.open)
        XCTAssertGreaterThanOrEqual(record.returnedAt, openedAt)
    }

    func testAWaitWithATimeoutGivesUpOnAGateStillClosed() {
        let gate = GPUSubmissionGate()
        gate.close(reason: "test")
        let record = WaitRecord()
        let done = expectation(description: "the wait times out")
        let start = CACurrentMediaTime()
        DispatchQueue.global().async {
            let open = gate.waitUntilOpen(timeout: 0.2)
            record.record(open: open, returnedAt: CACurrentMediaTime())
            done.fulfill()
        }
        wait(for: [done], timeout: 5.0)
        XCTAssertFalse(record.open)
        XCTAssertGreaterThanOrEqual(record.returnedAt - start, 0.15)
    }

    func testTheMainThreadNeverWaits() {
        XCTAssertTrue(Thread.isMainThread)
        let gate = GPUSubmissionGate()
        gate.close(reason: "test")
        let start = CACurrentMediaTime()
        XCTAssertFalse(gate.waitUntilOpen())
        XCTAssertFalse(gate.waitUntilOpen(timeout: 1.0))
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.1)
    }

    func testAnAsyncWaiterIsReleasedWhenTheGateOpens() async {
        let gate = GPUSubmissionGate()
        gate.close(reason: "test")
        let waiter = Task { () -> CFTimeInterval in
            await gate.waitUntilOpen()
            return CACurrentMediaTime()
        }
        // The waiter holds while the gate stays closed.
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(gate.isOpen)
        let openedAt = CACurrentMediaTime()
        gate.open(reason: "test")
        let releasedAt = await waiter.value
        XCTAssertGreaterThanOrEqual(releasedAt, openedAt)
    }

    func testAnAsyncWaitOnAnOpenGateReturnsAtOnce() async {
        let gate = GPUSubmissionGate()
        let start = CACurrentMediaTime()
        await gate.waitUntilOpen()
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.1)
    }

    func testWaitingForCommittedWorkWithNoneNotedReturnsAtOnce() {
        let gate = GPUSubmissionGate()
        let start = CACurrentMediaTime()
        gate.waitForCommittedWork()
        XCTAssertLessThan(CACurrentMediaTime() - start, 0.1)
    }
}
