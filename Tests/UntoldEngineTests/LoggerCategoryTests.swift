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
    private var previousLogLevel: LogLevel = .debug

    override func setUp() {
        super.setUp()
        previousLogLevel = Logger.logLevel
        Logger.logLevel = .debug
        Logger.resetCategoryToggles()
    }

    override func tearDown() {
        Logger.resetCategoryToggles()
        Logger.logLevel = previousLogLevel
        super.tearDown()
    }

    func testHighVolumeStreamingCategoriesAreDisabledByDefault() {
        Logger.resetCategoryToggles()

        XCTAssertFalse(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .streamingHeartbeat))
        XCTAssertFalse(Logger.isEnabled(category: .textureStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureLoading))
        XCTAssertFalse(Logger.isEnabled(category: .lightPortal))
        XCTAssertFalse(Logger.isEnabled(category: .gaussian))
    }

    func testStreamingCategoriesCanBeEnabledIndividually() {
        Logger.resetCategoryToggles()

        Logger.enable(category: .tileStreaming)

        XCTAssertTrue(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .textureLoading))
        XCTAssertFalse(Logger.isEnabled(category: .streamingHeartbeat))
        XCTAssertFalse(Logger.isEnabled(category: .lightPortal))
        XCTAssertFalse(Logger.isEnabled(category: .gaussian))
    }

    func testGaussianCategoryCanBeEnabledIndividually() {
        Logger.resetCategoryToggles()

        setLogger(.category(.gaussian, true))

        XCTAssertTrue(Logger.isEnabled(category: .gaussian))
        XCTAssertFalse(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .batching))
    }

    func testWarningsRespectCategoryToggles() {
        Logger.resetCategoryToggles()

        var disabledWarningEvaluated = false
        Logger.logWarning(
            message: {
                disabledWarningEvaluated = true
                return "disabled tile streaming warning"
            }(),
            category: LogCategory.tileStreaming.rawValue
        )
        XCTAssertFalse(disabledWarningEvaluated)

        Logger.enable(category: .tileStreaming)

        var enabledWarningEvaluated = false
        Logger.logWarning(
            message: {
                enabledWarningEvaluated = true
                return "enabled tile streaming warning"
            }(),
            category: LogCategory.tileStreaming.rawValue
        )
        XCTAssertTrue(enabledWarningEvaluated)
    }
}
