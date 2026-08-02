//
//  CustomSystemTest.swift
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
final class CustomSystemTest: XCTestCase {
    override func setUp() {
        clearCustomSystems()
    }

    override func tearDown() {
        clearCustomSystems()
    }

    func testRegisteredSystemsRunInRegistrationOrder() {
        var callOrder: [String] = []
        registerCustomSystem { _ in callOrder.append("first") }
        registerCustomSystem { _ in callOrder.append("second") }

        updateCustomSystems(deltaTime: 0.1)

        XCTAssertEqual(callOrder, ["first", "second"])
    }

    func testUnregisterRemovesOnlyThatSystem() {
        var firstCallCount = 0
        var secondCallCount = 0
        let firstHandle = registerCustomSystem { _ in firstCallCount += 1 }
        registerCustomSystem { _ in secondCallCount += 1 }

        unregisterCustomSystem(firstHandle)
        updateCustomSystems(deltaTime: 0.1)

        XCTAssertEqual(firstCallCount, 0)
        XCTAssertEqual(secondCallCount, 1)
    }

    func testDeltaTimeIsPassedThrough() {
        var receivedDeltaTime: Float?
        registerCustomSystem { deltaTime in receivedDeltaTime = deltaTime }

        updateCustomSystems(deltaTime: 0.25)

        XCTAssertEqual(receivedDeltaTime, 0.25)
    }

    func testClearCustomSystemsRemovesEverySystem() {
        var callCount = 0
        registerCustomSystem { _ in callCount += 1 }
        registerCustomSystem { _ in callCount += 1 }

        clearCustomSystems()
        updateCustomSystems(deltaTime: 0.1)

        XCTAssertEqual(callCount, 0)
    }
}
