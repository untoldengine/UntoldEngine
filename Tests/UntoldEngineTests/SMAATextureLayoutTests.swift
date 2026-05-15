//
//  SMAATextureLayoutTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class SMAATextureLayoutTests: XCTestCase {
    func testAreaTextureLayoutMatchesGeneratedBytes() {
        XCTAssertEqual(SMAATextureLayout.areaWidth, 160)
        XCTAssertEqual(SMAATextureLayout.areaHeight, 560)
        XCTAssertEqual(SMAATextureLayout.areaBytesPerRow, 160 * 2)
        XCTAssertEqual(smaaAreaTexBytes.count, 160 * 560 * 2)
        XCTAssertEqual(smaaAreaTexBytes.count, SMAATextureLayout.areaByteCount)
    }

    func testSearchTextureLayoutMatchesGeneratedBytes() {
        XCTAssertEqual(SMAATextureLayout.searchWidth, 64)
        XCTAssertEqual(SMAATextureLayout.searchHeight, 16)
        XCTAssertEqual(SMAATextureLayout.searchBytesPerRow, 64)
        XCTAssertEqual(smaaSearchTexBytes.count, 64 * 16)
        XCTAssertEqual(smaaSearchTexBytes.count, SMAATextureLayout.searchByteCount)
    }
}
