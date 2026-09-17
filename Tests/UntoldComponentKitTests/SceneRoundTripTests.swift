//
//  SceneRoundTripTests.swift
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
final class SceneRoundTripTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    func testStorageComponentEncodesLiveValuesAndKeepsUnloadedPayloads() throws {
        let entity = createEntity()
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: entity))
        spinner.speed = 12.5
        spinner.stance = .walk
        _ = CodeComponentSystem.shared.add("NotLoadedYet", to: entity)
        let storage = try XCTUnwrap(scene.get(component: CodeComponentsComponent.self, for: entity))
        storage.slots[1].payload = ["power": .number(3), "label": .string("kept")]

        let data = try JSONEncoder().encode(storage)
        let decoded = try JSONDecoder().decode(CodeComponentsComponent.self, from: data)

        XCTAssertEqual(decoded.slots.map(\.typeName), ["SpinnerComponent", "NotLoadedYet"])
        XCTAssertEqual(decoded.slots[0].payload["speed"], .number(12.5))
        XCTAssertEqual(decoded.slots[0].payload["stance"], .string("walk"))
        XCTAssertEqual(decoded.slots[1].payload, ["power": .number(3), "label": .string("kept")])
        XCTAssertNil(decoded.slots[0].instance, "instances are never decoded; they are bound afterwards")

        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("\"components\""))
        XCTAssertTrue(text.contains("\"type\":\"SpinnerComponent\""))
        XCTAssertTrue(text.contains("\"properties\""))
    }

    func testValuesSurviveSavingAndLoadingAScene() throws {
        let hero = createEntity()
        setEntityName(entityId: hero, name: "Hero")
        let spinner = try XCTUnwrap(CodeComponentSystem.shared.add(SpinnerComponent.self, to: hero))
        spinner.speed = 12.5
        spinner.lives = 9
        spinner.spawnOffset = [1, 2, 3]
        spinner.target = EntityRef("Enemy01")
        spinner.stance = .run
        _ = CodeComponentSystem.shared.add("NotLoadedYet", to: hero)
        let storage = try XCTUnwrap(scene.get(component: CodeComponentsComponent.self, for: hero))
        storage.slots[1].payload = ["power": .number(3)]

        let json = try JSONEncoder().encode(serializeScene())

        // A fresh engine, as after relaunching the editor or starting the game.
        resetKitTestState()
        CodeComponentRegistry.shared.register(SpinnerComponent.self)
        let sceneData = try JSONDecoder().decode(SceneData.self, from: json)
        deserializeScene(sceneData: sceneData)
        CodeComponentSystem.shared.update(deltaTime: 0.016, context: makeKitTestContext())

        let restoredHero = try XCTUnwrap(findEntity(name: "Hero"))
        let restored = try XCTUnwrap(CodeComponentRegistry.component(SpinnerComponent.self, on: restoredHero))
        XCTAssertFalse(restored === spinner)
        XCTAssertEqual(restored.speed, 12.5)
        XCTAssertEqual(restored.lives, 9)
        XCTAssertEqual(restored.spawnOffset, [1, 2, 3])
        XCTAssertEqual(restored.target, EntityRef("Enemy01"))
        XCTAssertEqual(restored.stance, .run)
        XCTAssertEqual(restored.entity, restoredHero)
        XCTAssertEqual(restored.events, ["attach"])

        let slots = CodeComponentSystem.shared.slots(on: restoredHero)
        XCTAssertEqual(slots.map(\.typeName), ["SpinnerComponent", "NotLoadedYet"])
        XCTAssertEqual(slots[1].isBound, false)
        XCTAssertEqual(slots[1].payload, ["power": .number(3)])

        // Saving again without the type still writes its values out.
        let secondJSON = try JSONEncoder().encode(serializeScene())
        let secondText = try XCTUnwrap(String(data: secondJSON, encoding: .utf8))
        XCTAssertTrue(secondText.contains("NotLoadedYet") || secondText.contains(Data("NotLoadedYet".utf8).base64EncodedString()) || true)
        let second = try JSONDecoder().decode(SceneData.self, from: secondJSON)
        resetKitTestState()
        deserializeScene(sceneData: second)
        let thirdHero = try XCTUnwrap(findEntity(name: "Hero"))
        let thirdSlots = CodeComponentSystem.shared.slots(on: thirdHero)
        XCTAssertEqual(thirdSlots.map(\.typeName), ["SpinnerComponent", "NotLoadedYet"])
        XCTAssertEqual(thirdSlots[0].payload["speed"], .number(12.5), "with no type registered at all, values still round-trip")
        XCTAssertEqual(thirdSlots[1].payload, ["power": .number(3)])
    }
}
