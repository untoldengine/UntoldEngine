//
//  USCScriptingConditionRuntimeTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@testable import UntoldEngine
import XCTest


@MainActor
final class USCScriptingConditionRuntimeTests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        initScriptingSystem()
    }

    override func tearDown() async throws {
        destroyAllEntities()
    }

    // MARK: - ifLess (property-based) runtime tests

    func testIfLess_ExecutesBlockWhenPropertyBelowThreshold() {
        let script = buildScript(name: "IfLessHealthLow") { s in
            s.onUpdate()
                // First set the property "health" to a low value
                .setProperty("health", to: 10.0)
                // if health < 50 { lowHealthTriggered = true }
                .ifLess("health", than: 50.0) { n in
                    n.setVariable("lowHealthTriggered", to: true)
                }
        }

        let entityId = createEntity()

        // If health is backed by a component, make sure relevant components are present
        // (adjust this to match your actual health storage if needed)
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // The helper inserts:
        //  - getProperty("health", as: "health")
        //  - ifCondition(lhs: .variableRef("health"), op: .less, rhs: .float(50))
        // so we expect the block to have run and set lowHealthTriggered
        guard case let .bool(flag) = context.variables["lowHealthTriggered"] else {
            return XCTFail("lowHealthTriggered should be a bool")
        }
        XCTAssertTrue(flag)
    }

    func testIfLess_DoesNotExecuteBlockWhenPropertyAboveThreshold() {
        let script = buildScript(name: "IfLessHealthHigh") { s in
            s.onUpdate()
                .setProperty("health", to: 100.0)
                .ifLess("health", than: 50.0) { n in
                    n.setVariable("lowHealthTriggered", to: true)
                }
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Condition should be false -> no variable set
        XCTAssertNil(context.variables["lowHealthTriggered"])
    }

    // MARK: - ifGreater (property-based) runtime tests

    func testIfGreater_ExecutesBlockWhenPropertyAboveThreshold() {
        let script = buildScript(name: "IfGreaterSpeedFast") { s in
            s.onUpdate()
                .setProperty("speed", to: 20.0)
                .ifGreater("speed", than: 5.0) { n in
                    n.setVariable("isFast", to: true)
                }
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .bool(isFast) = context.variables["isFast"] else {
            return XCTFail("isFast should be a bool")
        }
        XCTAssertTrue(isFast)
    }

    func testIfGreater_DoesNotExecuteBlockWhenPropertyBelowThreshold() {
        let script = buildScript(name: "IfGreaterSpeedSlow") { s in
            s.onUpdate()
                .setProperty("speed", to: 2.0)
                .ifGreater("speed", than: 5.0) { n in
                    n.setVariable("isFast", to: true)
                }
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        XCTAssertNil(context.variables["isFast"])
    }

    // MARK: - ifEqual (property-based) runtime tests

    func testIfEqual_ExecutesBlockWhenPropertyMatches() {
        let script = buildScript(name: "IfEqualStateIdle") { s in
            s.onUpdate()
                // Representing "state" as a numeric code for this test
                .setProperty("state", to: 1.0)
                .ifEqual("state", to: 1.0) { n in
                    n.setVariable("isIdle", to: true)
                }
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .bool(isIdle) = context.variables["isIdle"] else {
            return XCTFail("isIdle should be a bool")
        }
        XCTAssertTrue(isIdle)
    }

    func testIfEqual_DoesNotExecuteBlockWhenPropertyDiffers() {
        let script = buildScript(name: "IfEqualStateNotIdle") { s in
            s.onUpdate()
                .setProperty("state", to: 2.0)
                .ifEqual("state", to: 1.0) { n in
                    n.setVariable("isIdle", to: true)
                }
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        XCTAssertNil(context.variables["isIdle"])
    }

    // MARK: - Generic ifCondition(lhs: Value, op, rhs: Value)

    func testIfCondition_GenericWithVariableRef_ExecutesBlock() {
        let script = buildScript(name: "GenericIfCondition") { s in
            s.onUpdate()
                .setVariable("speed", to: 12.0)
                .ifCondition(lhs: .variableRef("speed"),
                             .greater,
                             rhs: .float(10.0))
                { n in
                    n.setVariable("isFast", to: true)
                }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .bool(isFast) = context.variables["isFast"] else {
            return XCTFail("isFast should be a bool")
        }
        XCTAssertTrue(isFast)
    }

    func testIfCondition_GenericWithVariableRef_DoesNotExecuteWhenFalse() {
        let script = buildScript(name: "GenericIfConditionFalse") { s in
            s.onUpdate()
                .setVariable("speed", to: 3.0)
                .ifCondition(lhs: .variableRef("speed"),
                             .greater,
                             rhs: .float(10.0))
                { n in
                    n.setVariable("isFast", to: true)
                }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        XCTAssertNil(context.variables["isFast"])
    }
}
