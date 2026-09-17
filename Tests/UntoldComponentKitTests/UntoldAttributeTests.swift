//
//  UntoldAttributeTests.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldComponentKit
@testable import UntoldEngine
import XCTest

@MainActor
final class UntoldAttributeTests: XCTestCase {
    func testReflectionListsAttributesInDeclarationOrderAndSkipsPlainProperties() {
        let names = SpinnerComponent().untoldAttributes().map(\.name)
        XCTAssertEqual(names, [
            "speed", "lives", "invincible", "nickname", "notes",
            "spawnOffset", "tint", "target", "clip", "stance",
        ])
    }

    func testReflectionWalksSuperclassFirst() {
        XCTAssertEqual(DerivedMover().untoldAttributes().map(\.name), ["baseSpeed", "boost"])
    }

    func testKindsHintsAndLabels() throws {
        let entries = SpinnerComponent().untoldAttributes()
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        let speed = try XCTUnwrap(byName["speed"])
        XCTAssertEqual(speed.attribute.kind, .float)
        XCTAssertEqual(speed.attribute.range, 0 ... 20)
        XCTAssertEqual(speed.attribute.step, 0.5)
        XCTAssertEqual(speed.displayLabel, "Speed")

        XCTAssertEqual(byName["lives"]?.attribute.kind, .int)
        XCTAssertEqual(byName["invincible"]?.attribute.kind, .bool)
        XCTAssertEqual(byName["nickname"]?.attribute.kind, .string)
        XCTAssertEqual(byName["notes"]?.attribute.kind, .text)
        XCTAssertEqual(byName["spawnOffset"]?.attribute.kind, .vector3)
        XCTAssertEqual(byName["spawnOffset"]?.displayLabel, "Spawn Offset")
        XCTAssertEqual(byName["tint"]?.attribute.kind, .color)
        XCTAssertEqual(byName["target"]?.attribute.kind, .entity)
        XCTAssertEqual(byName["clip"]?.attribute.kind, .asset(category: "Animations"))
        XCTAssertEqual(byName["stance"]?.attribute.kind, .enumeration(cases: ["idle", "walk", "run"]))
    }

    func testWritesThroughTheReflectedWrapperReachTheComponent() throws {
        let spinner = SpinnerComponent()
        let speed = try XCTUnwrap(spinner.untoldAttributes().first { $0.name == "speed" })

        XCTAssertTrue(speed.attribute.setAttributeValue(.number(12.5)))
        XCTAssertEqual(spinner.speed, 12.5)

        spinner.speed += 0.5
        XCTAssertEqual(speed.attribute.attributeValue, .number(13))
    }

    func testValuesOfTheWrongShapeAreRejectedAndLeaveTheProperty() throws {
        let spinner = SpinnerComponent()
        let entries = Dictionary(uniqueKeysWithValues: spinner.untoldAttributes().map { ($0.name, $0.attribute) })

        XCTAssertFalse(try XCTUnwrap(entries["speed"]).setAttributeValue(.string("fast")))
        XCTAssertFalse(try XCTUnwrap(entries["spawnOffset"]).setAttributeValue(.array([1, 2])))
        XCTAssertFalse(try XCTUnwrap(entries["stance"]).setAttributeValue(.string("flying")))
        XCTAssertFalse(try XCTUnwrap(entries["lives"]).setAttributeValue(.number(.nan)))

        XCTAssertEqual(spinner.speed, 5)
        XCTAssertEqual(spinner.spawnOffset, [0, 1, 0])
        XCTAssertEqual(spinner.stance, .idle)
        XCTAssertEqual(spinner.lives, 3)
    }

    func testTypedValuesCoerceFromTheirJSONShape() {
        XCTAssertEqual(Int(0).applying(.number(3.6)), 4)
        XCTAssertEqual(Float(0).applying(.number(2.5)), 2.5)
        XCTAssertEqual(SIMD3<Float>.zero.applying(.array([1, 2, 3])), [1, 2, 3])
        XCTAssertEqual(SIMD4<Float>.zero.applying(.array([1, 2, 3, 4])), [1, 2, 3, 4])
        XCTAssertEqual(EntityRef().applying(.object(["entity": "Enemy01"])), EntityRef("Enemy01"))
        XCTAssertNil(EntityRef().applying(.object(["asset": "x"])))
    }

    func testAssetRefKeepsItsDeclaredCategoryWhenAValueIsApplied() throws {
        let declared = AssetRef(category: .animations)
        let applied = try XCTUnwrap(declared.applying(.object(["asset": "Animations/run.untold"])))
        XCTAssertEqual(applied.path, "Animations/run.untold")
        XCTAssertEqual(applied.category, .animations)
    }

    func testPayloadRoundTripAppliesEveryAttribute() {
        let source = SpinnerComponent()
        source.speed = 9.25
        source.lives = 1
        source.invincible = true
        source.nickname = "boss"
        source.notes = "two\nlines"
        source.spawnOffset = [4, 5, 6]
        source.tint = [0.1, 0.2, 0.3, 1]
        source.target = EntityRef("Enemy01")
        source.clip = AssetRef("Animations/run.untold", category: .animations)
        source.stance = .run

        let copy = SpinnerComponent()
        let report = copy.applyAttributePayload(source.attributePayload())

        XCTAssertEqual(report.applied.count, 10)
        XCTAssertTrue(report.missing.isEmpty && report.dropped.isEmpty && report.rejected.isEmpty)
        XCTAssertEqual(copy.speed, 9.25)
        XCTAssertEqual(copy.lives, 1)
        XCTAssertTrue(copy.invincible)
        XCTAssertEqual(copy.nickname, "boss")
        XCTAssertEqual(copy.notes, "two\nlines")
        XCTAssertEqual(copy.spawnOffset, [4, 5, 6])
        XCTAssertEqual(copy.tint, [0.1, 0.2, 0.3, 1])
        XCTAssertEqual(copy.target, EntityRef("Enemy01"))
        XCTAssertEqual(copy.clip.path, "Animations/run.untold")
        XCTAssertEqual(copy.stance, .run)
        XCTAssertEqual(copy.runtimeOnly, 42)
    }

    func testApplyReportsMissingDroppedAndRejectedKeys() {
        let mover = DerivedMover()
        let report = mover.applyAttributePayload([
            "boost": .string("lots"),
            "removedLongAgo": .number(1),
        ])

        XCTAssertEqual(report.applied, [])
        XCTAssertEqual(report.missing, ["baseSpeed"])
        XCTAssertEqual(report.rejected, ["boost"])
        XCTAssertEqual(report.dropped, ["removedLongAgo"])
        XCTAssertEqual(mover.boost, 2)
    }

    func testAttributeValueJSONKeepsBooleansAndNumbersApart() throws {
        let json = Data(#"{"flag":true,"count":1,"name":"x","vector":[1,2,3],"ref":{"entity":"E"}}"#.utf8)
        let decoded = try JSONDecoder().decode([String: UntoldAttributeValue].self, from: json)

        XCTAssertEqual(decoded["flag"], .bool(true))
        XCTAssertEqual(decoded["count"], .number(1))
        XCTAssertEqual(decoded["name"], .string("x"))
        XCTAssertEqual(decoded["vector"], .array([1, 2, 3]))
        XCTAssertEqual(decoded["ref"], .object(["entity": "E"]))

        let reencoded = try JSONEncoder().encode(decoded)
        XCTAssertEqual(try JSONDecoder().decode([String: UntoldAttributeValue].self, from: reencoded), decoded)
    }

    func testHumanizedIdentifier() {
        XCTAssertEqual(humanizedIdentifier("jumpHeight"), "Jump Height")
        XCTAssertEqual(humanizedIdentifier("HZBCull"), "HZB Cull")
        XCTAssertEqual(humanizedIdentifier("PlayerController2D"), "Player Controller 2D")
        XCTAssertEqual(humanizedIdentifier("speed"), "Speed")
        XCTAssertEqual(SpinnerComponent.displayName, "Spinner Component")
    }
}
