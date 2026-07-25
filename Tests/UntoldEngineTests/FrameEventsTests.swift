//
//  FrameEventsTests.swift
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

@MainActor
final class FrameEventsTests: XCTestCase {
    private func makeEvent(renderer: UntoldRenderer) -> UpdateEvent {
        UpdateEvent(deltaTime: 1.0 / 60.0, renderer: renderer)
    }

    func testMulticastDispatchAndCancellation() {
        let renderer = UntoldRenderer()
        let dispatcher = FrameEventDispatcher()

        XCTAssertFalse(dispatcher.hasSubscribers)

        var firstCount = 0
        var secondCount = 0
        var lastDelta: TimeInterval = 0

        let first = dispatcher.subscribe { event in
            firstCount += 1
            lastDelta = event.deltaTime
        }
        let second = dispatcher.subscribe { _ in
            secondCount += 1
        }

        XCTAssertTrue(dispatcher.hasSubscribers)

        dispatcher.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 1)
        XCTAssertEqual(lastDelta, 1.0 / 60.0, accuracy: 1e-9)

        first.cancel()
        first.cancel() // idempotent

        dispatcher.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(firstCount, 1)
        XCTAssertEqual(secondCount, 2)

        second.cancel()
        XCTAssertFalse(dispatcher.hasSubscribers)

        dispatcher.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(secondCount, 2)
    }

    func testRendererOnUpdateSubscription() {
        let renderer = UntoldRenderer()

        var received: TimeInterval = -1
        let token = renderer.onUpdate { event in
            received = event.deltaTime
        }

        XCTAssertTrue(renderer.frameEvents.hasSubscribers)

        renderer.frameEvents.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(received, 1.0 / 60.0, accuracy: 1e-9)

        token.cancel()
        XCTAssertFalse(renderer.frameEvents.hasSubscribers)
    }

    func testCancellationDuringDispatchIsSafe() {
        let renderer = UntoldRenderer()
        let dispatcher = FrameEventDispatcher()

        var token: EventSubscription?
        var count = 0
        token = dispatcher.subscribe { _ in
            count += 1
            token?.cancel() // reentrant cancel while dispatching
        }

        dispatcher.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(count, 1)
        XCTAssertFalse(dispatcher.hasSubscribers)

        dispatcher.dispatch(makeEvent(renderer: renderer))
        XCTAssertEqual(count, 1)
    }
}
