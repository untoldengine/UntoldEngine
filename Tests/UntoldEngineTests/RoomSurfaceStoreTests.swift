//
//  RoomSurfaceStoreTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

private func makeWallSurface(center: simd_float3 = .init(0, 1, -2)) -> RoomSurface {
    RoomSurface(
        center: center,
        normal: .init(0, 0, 1),
        tangentU: .init(1, 0, 0),
        tangentV: .init(0, 1, 0),
        extentU: 1.0,
        extentV: 1.0,
        kind: .wall
    )
}

final class RoomSurfaceStoreTests: XCTestCase {
    /// The bug this store fixes: a tracker that reports "removed" the
    /// instant it stops confirming a surface (e.g. the user looked away)
    /// must not make that surface vanish from physics. `markUnconfirmed`
    /// keeps the record around instead of deleting it.
    func testSurfaceSurvivesBecomingUnconfirmed() {
        let store = RoomSurfaceStore()
        let id = UUID()
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 0)
        XCTAssertEqual(store.currentSurfaces.count, 1)

        store.markUnconfirmed(sourceID: id)

        XCTAssertEqual(
            store.currentSurfaces.count, 1,
            "an unconfirmed surface must still be fed to physics"
        )
    }

    /// Only after staying unconfirmed for longer than `staleTimeout` should
    /// a surface actually be dropped.
    func testUnconfirmedSurfaceIsPurgedOnlyAfterStaleTimeout() {
        let store = RoomSurfaceStore(staleTimeout: 10)
        let id = UUID()
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 0)
        store.markUnconfirmed(sourceID: id)

        store.purgeStale(now: 5)
        XCTAssertEqual(store.currentSurfaces.count, 1, "not stale yet")

        store.purgeStale(now: 11)
        XCTAssertEqual(store.currentSurfaces.count, 0, "past the stale timeout")
    }

    /// Re-confirming the same source ID after an unconfirmed gap (ARKit
    /// re-detecting under the SAME anchor) must not create a duplicate.
    func testReconfirmingSameSourceUpdatesInPlace() {
        let store = RoomSurfaceStore()
        let id = UUID()
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 0)
        store.markUnconfirmed(sourceID: id)
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 5)

        XCTAssertEqual(store.currentSurfaces.count, 1)
    }

    /// ARKit commonly re-detects a surface it previously lost under a BRAND
    /// NEW anchor ID (merge, or a fresh re-scan). Geometry in roughly the
    /// same place, same orientation, should fold into the existing record
    /// rather than stack a second, overlapping collider.
    func testOverlappingSurfaceFromNewSourceIDMergesIntoExistingRecord() {
        let store = RoomSurfaceStore()
        let originalID = UUID()
        store.upsert(sourceID: originalID, surface: makeWallSurface(), at: 0)
        store.markUnconfirmed(sourceID: originalID)

        let reacquiredID = UUID()
        let nearlySamePlace = makeWallSurface(center: .init(0.05, 1.0, -2.0))
        store.upsert(sourceID: reacquiredID, surface: nearlySamePlace, at: 5)

        XCTAssertEqual(
            store.currentSurfaces.count, 1,
            "a spatial match should merge, not duplicate"
        )
    }

    /// A genuinely distinct surface (far away, or facing a different way)
    /// must never be folded into an unrelated record.
    func testDistantSurfaceFromNewSourceIDDoesNotMerge() {
        let store = RoomSurfaceStore()
        store.upsert(sourceID: UUID(), surface: makeWallSurface(), at: 0)
        store.upsert(
            sourceID: UUID(),
            surface: makeWallSurface(center: .init(5, 1, -2)),
            at: 0
        )

        XCTAssertEqual(store.currentSurfaces.count, 2)
    }

    /// Once a source ID has been folded into an existing record via merge,
    /// later removing THAT source ID must mark the merged record
    /// unconfirmed, not silently no-op.
    func testMarkUnconfirmedAfterMergeAffectsMergedRecord() {
        let store = RoomSurfaceStore(staleTimeout: 10)
        let originalID = UUID()
        store.upsert(sourceID: originalID, surface: makeWallSurface(), at: 0)
        store.markUnconfirmed(sourceID: originalID)

        let reacquiredID = UUID()
        store.upsert(sourceID: reacquiredID, surface: makeWallSurface(), at: 5)
        store.markUnconfirmed(sourceID: reacquiredID)

        store.purgeStale(now: 16)
        XCTAssertEqual(store.currentSurfaces.count, 0)
    }

    func testRemoveAllClearsRecordsAndSourceMap() {
        let store = RoomSurfaceStore()
        let id = UUID()
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 0)
        store.removeAll()

        XCTAssertEqual(store.currentSurfaces.count, 0)
        XCTAssertEqual(store.recordCount, 0)

        // A fresh upsert under the same ID after a clear must not resurrect
        // stale internal state.
        store.upsert(sourceID: id, surface: makeWallSurface(), at: 100)
        XCTAssertEqual(store.currentSurfaces.count, 1)
    }
}
