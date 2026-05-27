//
//  LoggerCategoryTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class LoggerCategoryTests: XCTestCase {
    override func tearDown() {
        Logger.resetCategoryToggles()
        super.tearDown()
    }

    func testHighVolumeStreamingCategoriesAreDisabledByDefault() {
        Logger.resetCategoryToggles()

        XCTAssertFalse(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .streamingHeartbeat))
        XCTAssertFalse(Logger.isEnabled(category: .textureStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureLoading))
    }

    func testStreamingCategoriesCanBeEnabledIndividually() {
        Logger.resetCategoryToggles()

        Logger.enable(category: .tileStreaming)

        XCTAssertTrue(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureLoading))
        XCTAssertFalse(Logger.isEnabled(category: .streamingHeartbeat))
    }
}
