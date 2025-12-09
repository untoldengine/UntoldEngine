//
//  USCPhysicsScriptTest.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd
@testable import UntoldEngine
import XCTest

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

    override func setUp() {
        super.setUp()
        initScriptingSystem()
    }

    override func tearDown() {
        destroyAllEntities()
        super.tearDown()
    }

    func testApplyForceDirectionMagnitudeAction_Runtime() {
        let entity = makeEntityWithPhysics()

        let script = buildScript(name: "applyForceAction") { s in
            s.onUpdate()
                .setVariable("dir", to: Vec3(x: 0, y: 1, z: 0))
                .setVariable(ScriptArgKey.magnitude.rawValue, to: 3.0)
                .setVariable("worldDirection", fromVariable: "dir")
                .callAction(.applyWorldForce, args: ["worldDirection", ScriptArgKey.magnitude.rawValue])
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
                .setVariable("dir", to: Vec3(x: 1, y: 0, z: 0))
                .setVariable(ScriptArgKey.magnitude.rawValue, to: 2.0)
                .setVariable("direction", fromVariable: "dir")
                .callAction(.applyLinearImpulse, args: ["direction", ScriptArgKey.magnitude.rawValue])
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
                .setVariable("velocity", to: Vec3(x: 3, y: 4, z: 0))
                .callAction(.setLinearVelocity, args: ["velocity"])
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
                .setVariable("deltaVelocity", to: Vec3(x: 1, y: 0, z: -1))
                .callAction(.addLinearVelocity, args: ["deltaVelocity"])
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
                .setVariable(ScriptArgKey.minSpeed.rawValue, to: 2.0)
                .setVariable(ScriptArgKey.maxSpeed.rawValue, to: 5.0)
                .callAction(.clampLinearSpeed, args: [.minSpeed, .maxSpeed])
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
                .setVariable(ScriptArgKey.damping.rawValue, to: 0.5)
                .setVariable(ScriptArgKey.deltaTime.rawValue, to: 1.0)
                .callAction(.applyLinearDamping, args: [.damping, .deltaTime])
        }

        let ctx = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: ctx, forEvent: "OnUpdate")

        let physics = scene.get(component: PhysicsComponents.self, for: entity)
        let speed = simd_length(physics?.velocity ?? .zero)
        XCTAssertLessThan(speed, 10)
    }
}
