//
//  DebugLinesTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class DebugLinesTests: XCTestCase {
    override func tearDown() {
        clearDebugLines()
        super.tearDown()
    }

    func testNamedSetsAreReplacedRemovedAndSnapshotInNameOrder() {
        let store = DebugLineStore.shared
        store.removeAll()
        XCTAssertTrue(store.isEmpty)

        let red = simd_float4(1, 0, 0, 1)
        let a = DebugLineSegment(from: simd_float3(0, 0, 0), to: simd_float3(1, 0, 0), color: red)
        let b = DebugLineSegment(from: simd_float3(0, 1, 0), to: simd_float3(0, 2, 0), color: red)
        setDebugLines([a], named: "z")
        setDebugLines([b], named: "a")
        XCTAssertFalse(store.isEmpty)
        XCTAssertEqual(store.snapshot(), [[b], [a]], "sets come back sorted by name")

        setDebugLines([b, a], named: "z")
        XCTAssertEqual(store.snapshot(), [[b], [b, a]], "same name replaces the set")

        setDebugLines([], named: "a")
        XCTAssertEqual(store.snapshot(), [[b, a]], "an empty list removes the set")

        clearDebugLines(named: "z")
        XCTAssertTrue(store.isEmpty)
    }
}
