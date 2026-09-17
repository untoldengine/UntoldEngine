//
//  UntoldMenuTests.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldComponentKit
import XCTest

@MainActor
final class UntoldMenuTests: XCTestCase {
    func testReflectionListsMenuItemsInDeclarationOrder() {
        let items = SampleExtension().untoldMenuItems()
        XCTAssertEqual(items.map(\.name), ["preview", "blendCap", "reset", "bake"])
        XCTAssertEqual(items.map(\.menu.domain), [.view, .debug, .debug, .tools])
    }

    func testPathsAreNormalizedAndNeverNameARoot() {
        let items = SampleExtension().untoldMenuItems().map(\.menu)

        XCTAssertEqual(items[0].pathComponents, ["Preview Twins"])
        XCTAssertEqual(items[0].submenuPath, [])
        XCTAssertEqual(items[0].title, "Preview Twins")
        XCTAssertEqual(items[0].identifier, "view/Preview Twins")

        XCTAssertEqual(items[1].pathComponents, ["Splat Twin", "Blend Cap"], "whitespace around segments is trimmed")
        XCTAssertEqual(items[1].submenuPath, ["Splat Twin"])
        XCTAssertEqual(items[1].identifier, "debug/Splat Twin/Blend Cap")
    }

    func testDomainsAreTheClosedSetOfRoots() {
        XCTAssertEqual(UntoldMenuDomain.allCases.map(\.rootTitle), ["File", "View", "Debug", "Tools"])
    }

    func testToggleReadsWritesAndReportsItsOptions() {
        let sample = SampleExtension()
        let preview = sample.untoldMenuItems()[0].menu

        XCTAssertEqual(preview.kind, .toggle)
        XCTAssertEqual(preview.menuValue, .bool(true))
        XCTAssertEqual(preview.tooltip, "Swap meshes for their splat twins")
        XCTAssertTrue(preview.persists)
        XCTAssertTrue(preview.isEnabled)

        XCTAssertTrue(preview.setMenuValue(.bool(false)))
        XCTAssertFalse(sample.preview)
        XCTAssertFalse(preview.setMenuValue(.choice("64")), "a toggle refuses a choice")
    }

    func testChoiceListsCasesWithTitlesAndRefusesUnknownValues() {
        let sample = SampleExtension()
        let blendCap = sample.untoldMenuItems()[1].menu

        XCTAssertEqual(blendCap.kind, .choice([
            UntoldMenuChoice(rawValue: "64", title: "64"),
            UntoldMenuChoice(rawValue: "128", title: "128"),
            UntoldMenuChoice(rawValue: "unlimited", title: "Unlimited"),
        ]))
        XCTAssertEqual(blendCap.menuValue, .choice("64"))

        XCTAssertTrue(blendCap.setMenuValue(.choice("128")))
        XCTAssertEqual(sample.blendCap, .c128)
        XCTAssertFalse(blendCap.setMenuValue(.choice("512")))
        XCTAssertEqual(sample.blendCap, .c128)
    }

    func testActionRunsWithItsOwnerAndHoldsNoValue() {
        let sample = SampleExtension()
        let reset = sample.untoldMenuItems()[2].menu

        XCTAssertEqual(reset.kind, .action)
        XCTAssertNil(reset.menuValue)
        XCTAssertFalse(reset.persists)
        XCTAssertEqual(reset.keyEquivalent, "r")

        reset.perform(owner: sample)
        reset.perform(owner: sample)
        XCTAssertEqual(sample.resetCount, 2)
    }

    func testPersistAndEnabledOptions() {
        let bake = SampleExtension().untoldMenuItems()[3].menu
        XCTAssertFalse(bake.persists)
        XCTAssertFalse(bake.isEnabled)
    }

    func testValidationFlagsEmptyPathsAndDuplicates() {
        let issues = EditorExtension.validate(BrokenExtension().untoldMenuItems())
        XCTAssertEqual(issues, [
            .emptyPath(property: "untitled"),
            .duplicate(identifier: "debug/Splat Twin/Same"),
        ])
        XCTAssertTrue(EditorExtension.validate(SampleExtension().untoldMenuItems()).isEmpty)
    }

    func testValidationCatchesClashesAcrossExtensions() {
        let combined = SampleExtension().untoldMenuItems() + SampleExtension().untoldMenuItems()
        XCTAssertEqual(EditorExtension.validate(combined).count, 4)
    }
}
