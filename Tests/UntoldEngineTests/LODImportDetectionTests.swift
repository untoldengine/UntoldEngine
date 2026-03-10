//
//  LODImportDetectionTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class LODImportDetectionTests: XCTestCase {
    func testParseLODAssetNameValidCases() {
        let parsedUpper = parseLODAssetName("Tree_LOD0")
        XCTAssertNotNil(parsedUpper)
        XCTAssertEqual(parsedUpper?.baseName, "Tree")
        XCTAssertEqual(parsedUpper?.lodIndex, 0)

        let parsedLower = parseLODAssetName("tree_lod12")
        XCTAssertNotNil(parsedLower)
        XCTAssertEqual(parsedLower?.baseName, "tree")
        XCTAssertEqual(parsedLower?.lodIndex, 12)
    }

    func testParseLODAssetNameInvalidCases() {
        XCTAssertNil(parseLODAssetName("TreeLOD0"))
        XCTAssertNil(parseLODAssetName("Tree_LOD"))
        XCTAssertNil(parseLODAssetName("Tree_LOD0a"))
        XCTAssertNil(parseLODAssetName("_LOD0"))
    }

    func testParseLODAssetNameUsesLastLODToken() {
        let parsed = parseLODAssetName("tree_LOD0_proxy_LOD2")
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.baseName, "tree_LOD0_proxy")
        XCTAssertEqual(parsed?.lodIndex, 2)
    }

    func testDetectImportedLODGroupsIgnoresNonLODNames() {
        let sourceNames = [
            "tree",
            "tree_LOD0",
            "tree_LOD1",
            "Camera",
            "Light",
        ]

        let result = detectImportedLODGroups(fromSourceNames: sourceNames)
        XCTAssertTrue(result.ambiguousBaseNames.isEmpty)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups.first?.baseName, "tree")
        XCTAssertEqual(result.groups.first?.levels.map(\.lodIndex), [0, 1])
    }

    func testDetectImportedLODGroupsSkipsOnlyAmbiguousBase() {
        let sourceNames = [
            "tree_LOD0",
            "tree_LOD1",
            "rock_LOD0",
            "rock_LOD00", // same base/index as rock_LOD0 -> ambiguous base
            "car_LOD0",
            "car_LOD1",
        ]

        let result = detectImportedLODGroups(fromSourceNames: sourceNames)
        XCTAssertEqual(result.ambiguousBaseNames, Set(["rock"]))
        XCTAssertEqual(result.groups.map(\.baseName), ["car", "tree"])
    }

    func testDetectImportedLODGroupsRequiresAtLeastTwoLevels() {
        let sourceNames = [
            "single_LOD0",
            "pair_LOD0",
            "pair_LOD1",
        ]

        let result = detectImportedLODGroups(fromSourceNames: sourceNames)
        XCTAssertEqual(result.groups.count, 1)
        XCTAssertEqual(result.groups.first?.baseName, "pair")
    }

    func testMissingLODIndices() {
        let levels = [
            ImportedLODNameLevelCandidate(lodIndex: 0, sourceName: "tree_LOD0"),
            ImportedLODNameLevelCandidate(lodIndex: 3, sourceName: "tree_LOD3"),
        ]

        XCTAssertEqual(missingLODIndices(for: levels), [1, 2])
    }

    func testDefaultLODMaxDistanceUsesConfiguredAndExtrapolates() {
        let distances: [Float] = [50, 100, 200]
        XCTAssertEqual(defaultLODMaxDistance(for: 0, configuredDistances: distances), 50)
        XCTAssertEqual(defaultLODMaxDistance(for: 2, configuredDistances: distances), 200)
        XCTAssertEqual(defaultLODMaxDistance(for: 3, configuredDistances: distances), 300)
        XCTAssertEqual(defaultLODMaxDistance(for: 4, configuredDistances: distances), 400)
    }
}
