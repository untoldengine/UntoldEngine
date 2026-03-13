//
//  USCPhysicsScriptTest.swift
//  UntoldEngineTests
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

@MainActor
final class USCPhysicsScriptTests: XCTestCase {
    private func makeEntityWithPhysics() -> EntityID {
        let entity = createEntity()
        registerComponent(entityId: entity, componentType: PhysicsComponents.self)
        registerComponent(entityId: entity, componentType: KineticComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: ScenegraphComponent.self)
        return entity
    }

    override func setUp() async throws {
        resetEngineTestState()
        initScriptingSystem()
    }

    override func tearDown() async throws {
        destroyAllEntities()
    }

    func testApplyForceDirectionMagnitudeAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "applyForceAction") { s in
            s.onUpdate()
                .setVariable("dir", to: simd_float3(x: 0, y: 1, z: 0))
                .setVariable("magnitude", to: 3.0)
                .applyWorldForce(direction: .variableRef("dir"),
                                 magnitude: .variableRef("magnitude"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let kinetic = scene.get(component: KineticComponent.self, for: entity)
        XCTAssertEqual(kinetic?.forces.first, simd_float3(0, 3, 0))
    }

    func testApplyLinearImpulseAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "applyImpulse") { s in
            s.onUpdate()
                .setVariable("dir", to: simd_float3(x: 1, y: 0, z: 0))
                .setVariable("magnitude", to: 2.0)
                .applyLinearImpulse(direction: .variableRef("dir"),
                                    magnitude: .variableRef("magnitude"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        XCTAssertGreaterThan(physics?.velocity.x ?? 0, 0)
    }

    func testSetLinearVelocityAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "setVel") { s in
            s.onUpdate()
                .setVariable("velocity", to: simd_float3(x: 3, y: 4, z: 0))
                .setLinearVelocity(.variableRef("velocity"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        XCTAssertEqual(physics?.velocity, simd_float3(3, 4, 0))
    }

    func testAddLinearVelocityAction_Runtime() {
        let entity = makeEntityWithPhysics()
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.velocity = simd_float3(1, 1, 1)
        }

        let script = buildScript(name: "addVel") { s in
            s.onUpdate()
                .setVariable("deltaVelocity", to: simd_float3(x: 1, y: 0, z: -1))
                .addLinearVelocity(.variableRef("deltaVelocity"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        XCTAssertEqual(physics?.velocity, simd_float3(2, 1, 0))
    }

    func testClampLinearSpeedAction_Runtime() {
        let entity = makeEntityWithPhysics()
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.velocity = simd_float3(10, 0, 0)
        }

        let script = buildScript(name: "clampSpeed") { s in
            s.onUpdate()
                .setVariable("minSpeed", to: 2.0)
                .setVariable("maxSpeed", to: 5.0)
                .clampLinearSpeed(min: .variableRef("minSpeed"),
                                  max: .variableRef("maxSpeed"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        let speed = simd_length(physics?.velocity ?? .zero)
        XCTAssertEqual(speed, 5, accuracy: 0.0001)
    }

    func testApplyLinearDampingAction_Runtime() {
        let entity = makeEntityWithPhysics()
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.velocity = simd_float3(10, 0, 0)
        }

        let script = buildScript(name: "damping") { s in
            s.onUpdate()
                .setVariable("damping", to: 0.5)
                .setVariable("deltaTime", to: 1.0)
                .applyLinearDamping(damping: .variableRef("damping"),
                                    deltaTime: .variableRef("deltaTime"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        let speed = simd_length(physics?.velocity ?? .zero)
        XCTAssertLessThan(speed, 10)
    }

    func testApplyAngularImpulseAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "applyAngularImpulse") { s in
            s.onUpdate()
                .setVariable("axis", to: simd_float3(x: 0, y: 1, z: 0))
                .setVariable("magnitude", to: 2.0)
                .applyAngularImpulse(axis: .variableRef("axis"),
                                     magnitude: .variableRef("magnitude"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        XCTAssertGreaterThan(physics?.angularVelocity.y ?? 0, 0)
    }

    func testSetAngularVelocityAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "setAngVel") { s in
            s.onUpdate()
                .setVariable("angularVelocity", to: simd_float3(x: 0, y: 3, z: 0))
                .setAngularVelocity(.variableRef("angularVelocity"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        XCTAssertEqual(physics?.angularVelocity, simd_float3(0, 3, 0))
    }

    func testClampAngularSpeedAction_Runtime() {
        let entity = makeEntityWithPhysics()
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.angularVelocity = simd_float3(0, 10, 0)
        }

        let script = buildScript(name: "clampAngSpeed") { s in
            s.onUpdate()
                .setVariable("maxAngularSpeed", to: 4.0)
                .clampAngularSpeed(max: .variableRef("maxAngularSpeed"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        let speed = simd_length(physics?.angularVelocity ?? .zero)
        XCTAssertEqual(speed, 4.0, accuracy: 0.0001)
    }

    func testApplyAngularDampingAction_Runtime() {
        let entity = makeEntityWithPhysics()
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.angularVelocity = simd_float3(0, 8, 0)
        }

        let script = buildScript(name: "angDamping") { s in
            s.onUpdate()
                .setVariable("damping", to: 0.5)
                .setVariable("deltaTime", to: 1.0)
                .applyAngularDamping(damping: .variableRef("damping"),
                                     deltaTime: .variableRef("deltaTime"))
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        let speed = simd_length(physics?.angularVelocity ?? .zero)
        XCTAssertLessThan(speed, 8)
    }
}
