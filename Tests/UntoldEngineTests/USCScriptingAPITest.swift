//
//  USCScriptingAPITest.swift
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

final class USCScriptingAPITest: XCTestCase {
    override func setUp() {
        super.setUp()
        resetEngineTestState()
        initScriptingSystem()
    }

    override func tearDown() {
        super.tearDown()
        destroyAllEntities()
    }

    func registerPhysics(entityId: EntityID) {
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)
    }

    func testTranslateTo_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateTo(x: 1.0, y: 2.0, z: 3.0)
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testTranslateToVec3_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateTo(simd_float3(1.0, 2.0, 3.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testTranslateToSimd3_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateTo(simd_float3(1, 2, 3))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testTranslateBy_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateBy(x: 1.0, y: 2.0, z: 3.0)
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testTranslateByVec3_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateBy(simd_float3(x: 1.0, y: 2.0, z: 3.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testTranslateBySimd3_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .translateBy(simd_float3(1, 2, 3))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        // Now query the ECS
        let transform = getLocalPosition(entityId: entityId)

        XCTAssertEqual(transform.x, 1.0)
        XCTAssertEqual(transform.y, 2.0)
        XCTAssertEqual(transform.z, 3.0)
    }

    func testRotateTo_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .rotateTo(degrees: 90.0, axis: simd_float3(x: 0.0, y: 1.0, z: 0.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let result = getLocalOrientation(entityId: entityId)

        let expectedMatrix = transformQuaternionToMatrix3x3(q: simd_quatf(angle: degreesToRadians(degrees: 90.0), axis: simd_float3(0.0, 1.0, 0.0)))

        // XCTAssertEqual(result, expectedMatrix)
        XCTAssertEqual(result.columns.0.x, expectedMatrix.columns.0.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.y, expectedMatrix.columns.0.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.z, expectedMatrix.columns.0.z, accuracy: 0.01)

        XCTAssertEqual(result.columns.1.x, expectedMatrix.columns.1.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.y, expectedMatrix.columns.1.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.1.z, expectedMatrix.columns.1.z, accuracy: 0.01)

        XCTAssertEqual(result.columns.2.x, expectedMatrix.columns.2.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.y, expectedMatrix.columns.2.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.2.z, expectedMatrix.columns.2.z, accuracy: 0.01)
    }

    func testRotateBy_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .rotateBy(degrees: 45.0, axis: simd_float3(x: 0.0, y: 0.0, z: 1.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }

    func testRotateToWithVariableRef_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("angle", to: 90.0)

            s.onUpdate()
                .rotateTo(degrees: .variableRef("angle"), axis: simd_float3(x: 0.0, y: 1.0, z: 0.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Initialize variable
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Apply rotation
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let result = getLocalOrientation(entityId: entityId)
        let expectedMatrix = transformQuaternionToMatrix3x3(q: simd_quatf(angle: degreesToRadians(degrees: 90.0), axis: simd_float3(0.0, 1.0, 0.0)))

        XCTAssertEqual(result.columns.0.x, expectedMatrix.columns.0.x, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.y, expectedMatrix.columns.0.y, accuracy: 0.01)
        XCTAssertEqual(result.columns.0.z, expectedMatrix.columns.0.z, accuracy: 0.01)
    }

    func testRotateByWithVariableRef_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("rotSpeed", to: 45.0)

            s.onUpdate()
                .rotateBy(degrees: .variableRef("rotSpeed"), axis: simd_float3(x: 0.0, y: 0.0, z: 1.0))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Initialize variable
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Apply rotation
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }

    func testSetVariableWithValueType_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("speed", to: 10.0)
                .setVariable("currentSpeed", to: .variableRef("speed"))
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Both variables should have the same value
        guard case let .float(speed) = context.variables["speed"] else {
            return XCTFail("speed should be a float")
        }
        guard case let .float(currentSpeed) = context.variables["currentSpeed"] else {
            return XCTFail("currentSpeed should be a float")
        }

        XCTAssertEqual(speed, 10.0)
        XCTAssertEqual(currentSpeed, 10.0)
    }

    func testSetAndGetMass_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .setProperty(.mass, to: 5.0)
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let retrievedMass = getMass(entityId: entityId)
        XCTAssertEqual(retrievedMass, 5.0, "Mass should be correctly set and retrieved.")
    }

    func testApplyForce_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .applyForce(force: simd_float3(x: 10, y: 0, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        let force = simd_float3(10, 0, 0)

        XCTAssertEqual(kineticComponent?.forces.first, force, "Force should be correctly applied.")
    }

    func testApplyForceWithVariableRef_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("upwardForce", to: simd_float3(x: 0, y: 15, z: 0))

            s.onUpdate()
                .applyForce(force: .variableRef("upwardForce"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Initialize variable
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Verify variable was set correctly
        guard case let .vec3(x, y, z) = context.variables["upwardForce"] else {
            return XCTFail("upwardForce should be a vec3")
        }
        XCTAssertEqual(x, 0)
        XCTAssertEqual(y, 15)
        XCTAssertEqual(z, 0)

        // Apply force from variable
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        let expectedForce = simd_float3(0, 15, 0)

        XCTAssertEqual(kineticComponent?.forces.first, expectedForce, "Force from variable should be correctly applied.")
    }

    func testApplyMoment_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .applyMoment(force: simd_float3(x: 10, y: 0, z: 0), at: simd_float3(x: 0, y: 1, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        // applyMoment should add torque to the moments array
        XCTAssertNotNil(kineticComponent?.moments.first, "Moment should be applied.")
    }

    func testClearVelocity_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.velocity, to: simd_float3(x: 10, y: 5, z: 3))

            s.onUpdate()
                .clearVelocity()
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Set initial velocity
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let initialVelocity = getVelocity(entityId: entityId)
        XCTAssertEqual(initialVelocity, simd_float3(10, 5, 3), "Velocity should be set initially.")

        // Clear velocity
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let clearedVelocity = getVelocity(entityId: entityId)
        XCTAssertEqual(clearedVelocity, simd_float3(0, 0, 0), "Velocity should be cleared.")
    }

    func testClearAngularVelocity_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.angularVelocity, to: simd_float3(x: 5, y: 10, z: 2))

            s.onUpdate()
                .clearAngularVelocity()
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Set initial angular velocity
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId)

        let initialAngularVelocity = physicsComponent?.angularVelocity

        XCTAssertEqual(initialAngularVelocity, simd_float3(5, 10, 2), "Angular velocity should be set initially.")

        // Clear angular velocity
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let clearedAngularVelocity = physicsComponent?.angularVelocity

        XCTAssertEqual(clearedAngularVelocity, simd_float3(0, 0, 0), "Angular velocity should be cleared.")
    }

    func testClearForces_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .applyForce(force: simd_float3(x: 10, y: 0, z: 0))
                .applyForce(force: simd_float3(x: 5, y: 5, z: 0))

            s.onUpdate()
                .clearForces()
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Apply forces
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let kineticAfterForces = scene.get(component: KineticComponent.self, for: entityId)
        XCTAssertEqual(kineticAfterForces?.forces.count, 2, "Two forces should be applied.")

        // Clear forces
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let kineticAfterClear = scene.get(component: KineticComponent.self, for: entityId)
        XCTAssertEqual(kineticAfterClear?.forces.count, 0, "Forces should be cleared.")
    }

    func testPausePhysicsComponent_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .pausePhysicsComponent(isPaused: true)

            s.onUpdate()
                .pausePhysicsComponent(isPaused: false)
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Pause physics
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let physicsComponent = scene.get(component: PhysicsComponents.self, for: entityId)

        let pausedState = physicsComponent?.pause

        XCTAssertEqual(pausedState, true, "Physics should be paused.")

        // Unpause physics
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let unpausedState = physicsComponent?.pause
        XCTAssertEqual(unpausedState, false, "Physics should be unpaused.")
    }

    func testSetGravityScale_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setGravityScale(0.5)

            s.onUpdate()
                .setGravityScale(2.0)
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        // Set gravity scale to 0.5
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let kineticComponent = scene.get(component: KineticComponent.self, for: entityId)

        let initialScale = kineticComponent?.gravityScale

        XCTAssertEqual(initialScale, 0.5, "Gravity scale should be 0.5.")

        // Set gravity scale to 2.0
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let updatedScale = kineticComponent?.gravityScale

        XCTAssertEqual(updatedScale, 2.0, "Gravity scale should be 2.0.")
    }

    func testStringComparison_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("currentAnimation", to: "idle")
                .setVariable("didExecute", to: false)

            s.onUpdate()
                // Test notEqual - should enter block since currentAnimation is "idle" not "running"
                .ifCondition(lhs: .variableRef("currentAnimation"), .notEqual, rhs: .string("running")) { n in
                    n.setVariable("didExecute", to: true)
                    n.setVariable("currentAnimation", to: "running")
                    n.log("Changed animation to running")
                }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Initialize variables
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Verify initial state
        guard case let .string(initialAnim) = context.variables["currentAnimation"] else {
            return XCTFail("currentAnimation should be a string")
        }
        XCTAssertEqual(initialAnim, "idle")

        // Execute update - should enter the ifCondition block
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        // Verify the block was executed
        guard case let .bool(executed) = context.variables["didExecute"] else {
            return XCTFail("didExecute should be a bool")
        }
        XCTAssertTrue(executed, "Should have entered the notEqual condition")

        // Verify animation was changed
        guard case let .string(updatedAnim) = context.variables["currentAnimation"] else {
            return XCTFail("currentAnimation should be a string")
        }
        XCTAssertEqual(updatedAnim, "running")

        // Run again - should NOT enter block since now equal
        context.variables["didExecute"] = .bool(false)
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .bool(executedAgain) = context.variables["didExecute"] else {
            return XCTFail("didExecute should be a bool")
        }
        XCTAssertFalse(executedAgain, "Should NOT have entered the notEqual condition when strings are equal")
    }

    func testElseBlock_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("value", to: 5.0)
                .setVariable("result", to: "")

            s.onUpdate()
                .ifCondition(lhs: .variableRef("value"), .greater, rhs: .float(10.0)) { n in
                    n.setVariable("result", to: "greater")
                }.else { n in
                    n.setVariable("result", to: "not greater")
                }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .string(result) = context.variables["result"] else {
            return XCTFail("result should be a string")
        }
        XCTAssertEqual(result, "not greater", "Else block should have executed")
    }

    func testSubtractFloat_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("a", to: 10.0)
                .setVariable("b", to: 3.0)
                .subtractFloat("a", "b", as: "result1")
                .subtractFloat("a", literal: 2.0, as: "result2")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .float(result1) = context.variables["result1"] else {
            return XCTFail("result1 should be a float")
        }
        XCTAssertEqual(result1, 7.0, "10 - 3 should equal 7")

        guard case let .float(result2) = context.variables["result2"] else {
            return XCTFail("result2 should be a float")
        }
        XCTAssertEqual(result2, 8.0, "10 - 2 should equal 8")
    }

    func testDivFloat_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setVariable("a", to: 20.0)
                .setVariable("b", to: 4.0)
                .setVariable("c", to: 0.0)
                .divFloat("a", "b", as: "result1")
                .divFloat("a", literal: 5.0, as: "result2")
                .divFloat("a", "c", as: "result3") // Division by zero
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .float(result1) = context.variables["result1"] else {
            return XCTFail("result1 should be a float")
        }
        XCTAssertEqual(result1, 5.0, "20 / 4 should equal 5")

        guard case let .float(result2) = context.variables["result2"] else {
            return XCTFail("result2 should be a float")
        }
        XCTAssertEqual(result2, 4.0, "20 / 5 should equal 4")

        guard case let .float(result3) = context.variables["result3"] else {
            return XCTFail("result3 should be a float")
        }
        XCTAssertEqual(result3, 0.0, "20 / 0 should return 0 (protected)")
    }

    func testDeltaTime_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                .getProperty(.deltaTime, as: "dt")
                .setVariable("speed", to: 100.0)
                .mulFloat("speed", "dt", as: "displacement")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Set a fake delta time for testing
        timeSinceLastUpdate = 0.016 // ~60fps

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .float(dt) = context.variables["dt"] else {
            return XCTFail("dt should be a float")
        }
        XCTAssertEqual(dt, 0.016, accuracy: 0.001, "Delta time should be accessible")

        guard case let .float(displacement) = context.variables["displacement"] else {
            return XCTFail("displacement should be a float")
        }
        XCTAssertEqual(displacement, 1.6, accuracy: 0.01, "Displacement should be speed * deltaTime")
    }

    func testGetVelocity_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onUpdate()
            s.setProperty(.velocity, to: simd_float3(x: 5, y: 0, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let retrievedVelocity = getVelocity(entityId: entityId)
        XCTAssertEqual(retrievedVelocity, simd_float3(5, 0, 0), "Velocity should be correctly retrieved.")
    }

    func testLinearAccelerationUpdateWithForces_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.mass, to: 2.0)

            s.onUpdate()
                .applyForce(force: simd_float3(x: 10, y: 0, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // 1) Run OnStart once – set mass via the script
        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnStart")

        // 2) Simulate 1 second of frames, same as original while-loop test
        var t: Float = 0.0
        while t < 1.0 {
            // Per-frame: script logic + physics update
            interpreter.execute(script: script,
                                context: context,
                                forEvent: "OnUpdate")

            updatePhysicsSystem(deltaTime: 0.01)
            t += 0.01
        }

        // 3) Now check physics state, same as before
        guard let acceleration =
            scene.get(component: PhysicsComponents.self, for: entityId)?.acceleration
        else {
            return XCTFail("PhysicsComponents should exist on entity")
        }

        XCTAssertEqual(acceleration,
                       simd_float3(5, 0, 0),
                       "Acceleration should be correctly calculated.")
    }

    func testLinearVelocityUpdateWithForces_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.mass, to: 2.0)

            s.onUpdate()
                .applyForce(force: simd_float3(x: 10, y: 0, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // 1) Run OnStart once – set mass via the script
        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnStart")

        // 2) Simulate 1 second of frames, same as original while-loop test
        var t: Float = 0.0
        while t < 1.0 {
            // Per-frame: script logic + physics update
            interpreter.execute(script: script,
                                context: context,
                                forEvent: "OnUpdate")

            updatePhysicsSystem(deltaTime: 0.01)
            t += 0.01
        }

        // 3) Now check physics state, same as before
        guard let velocity = scene.get(component: PhysicsComponents.self, for: entityId)?.velocity
        else {
            return XCTFail("PhysicsComponents should exist on entity")
        }

        XCTAssertEqual(velocity.x, 5.0, accuracy: 0.1, "x Velocity should be updated correctly.")
        XCTAssertEqual(velocity.y, 0.0, accuracy: 0.1, "y Velocity should be updated correctly.")
        XCTAssertEqual(velocity.z, 0.0, accuracy: 0.1, "z Velocity should be updated correctly.")
    }

    func testPositionUpdateWithForces_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.mass, to: 2.0)

            s.onUpdate()
                .applyForce(force: simd_float3(x: 10, y: 0, z: 0))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // 1) Run OnStart once – set mass via the script
        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnStart")

        // 2) Simulate 1 second of frames, same as original while-loop test
        var t: Float = 0.0
        while t < 1.0 {
            // Per-frame: script logic + physics update
            interpreter.execute(script: script,
                                context: context,
                                forEvent: "OnUpdate")

            updatePhysicsSystem(deltaTime: 0.001)
            t += 0.001
        }

        let transformComponent = scene.get(component: LocalTransformComponent.self, for: entityId)

        let position = simd_float3(transformComponent!.position.x,
                                   transformComponent!.position.y,
                                   transformComponent!.position.z)

        let expectedPosition = simd_float3(2.5, 0.0, 0)

        XCTAssertEqual(position.x, expectedPosition.x, accuracy: 0.1, "x Position should be correctly calculated.")
        XCTAssertEqual(position.y, expectedPosition.y, accuracy: 0.1, "y Position should be correctly calculated.")
        XCTAssertEqual(position.z, expectedPosition.z, accuracy: 0.1, "z Position should be correctly calculated.")
    }

    func testSeek_Scripted() {
        let script = buildScript(name: "testSeek") { s in
            s.onUpdate()
                .setVariable("targetPosition", to: simd_float3(x: 10, y: 0, z: 0))
                .setVariable("maxSpeed", to: 5.0)
                .seek(targetPosition: .variableRef("targetPosition"),
                      maxSpeed: .variableRef("maxSpeed"),
                      result: "force")
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // 1) Run OnStart once – set mass via the script
        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        updatePhysicsSystem(deltaTime: 0.01)

        // Read result from script variable
        guard case let .vec3(fx, fy, fz)? = context.variables["force"] else {
            return XCTFail("force should be stored as vec3 in context.variables")
        }

        XCTAssertEqual(fx, 5.0, accuracy: 0.001)
        XCTAssertEqual(fy, 0.0, accuracy: 0.001)
        XCTAssertEqual(fz, 0.0, accuracy: 0.001)
    }

    func testFlee_Scripted() {
        let script = buildScript(name: "testFlee") { s in
            s.onUpdate()
                .setVariable("threatPosition", to: simd_float3(x: 5, y: 0, z: 0))
                .setVariable("maxSpeed", to: 5.0)
                .flee(threatPosition: .variableRef("threatPosition"),
                      maxSpeed: .variableRef("maxSpeed"),
                      result: "steering")
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .vec3(x, y, z)? = context.variables["steering"] else {
            return XCTFail("steering should be a vec3 in context.variables")
        }

        let steering = simd_float3(x, y, z)
        let expectedSteering = simd_float3(-5, 0, 0)

        XCTAssertEqual(steering, expectedSteering)
    }

    func testArrive_Scripted() {
        let script = buildScript(name: "testArrive") { s in
            s.onUpdate()
                .arrive(targetPosition: .variableRef("targetPosition"),
                        maxSpeed: .variableRef("maxSpeed"),
                        slowingRadius: .variableRef("slowingRadius"),
                        result: "steering")
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        // Place entity at origin
        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))

        let targetPosition = simd_float3(10, 0, 0)
        let slowingRadius: Float = 0.1
        let maxSpeed: Float = 5.0

        let context = USCContext(entityId: entityId, script: script)
        context.variables["targetPosition"] = .vec3(x: targetPosition.x, y: targetPosition.y, z: targetPosition.z)
        context.variables["maxSpeed"] = .float(maxSpeed)
        context.variables["slowingRadius"] = .float(slowingRadius)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .vec3(sx, sy, sz)? = context.variables["steering"] else {
            return XCTFail("steering should be a vec3 in context.variables")
        }

        let steering = simd_float3(sx, sy, sz)

        // Compute expected just like the original test
        let currentPos = getLocalPosition(entityId: entityId)
        let toTarget = targetPosition - currentPos

        let speed = min(maxSpeed,
                        maxSpeed * (length(toTarget) / slowingRadius))

        let expectedSteering = normalize(toTarget) * speed

        XCTAssertEqual(steering.x, expectedSteering.x, accuracy: 0.001)
        XCTAssertEqual(steering.y, expectedSteering.y, accuracy: 0.001)
        XCTAssertEqual(steering.z, expectedSteering.z, accuracy: 0.001)
    }

    func testPursuit_Scripted() {
        let script = buildScript(name: "testPursuit") { s in
            s.onUpdate()
                .pursuit(targetEntity: .variableRef("targetEntity"),
                         maxSpeed: .variableRef("maxSpeed"),
                         result: "steering")
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        // Target entity setup
        let targetEntityId = createEntity()
        registerPhysics(entityId: targetEntityId)

        // Give it a name your findEntity(name:) can resolve
        setEntityName(entityId: targetEntityId, name: "Target")

        // Place target at (5, 0, 0) with velocity (2, 0, 0)
        translateTo(entityId: targetEntityId, position: simd_float3(5, 0, 0))
        if let physics = scene.get(component: PhysicsComponents.self, for: targetEntityId) {
            physics.velocity = simd_float3(2, 0, 0)
        }

        let maxSpeed: Float = 5.0

        let context = USCContext(entityId: entityId, script: script)
        context.variables["targetEntity"] = .string("Target")
        context.variables["maxSpeed"] = .float(maxSpeed)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .vec3(sx, sy, sz)? = context.variables["steering"] else {
            return XCTFail("steering should be a vec3 in context.variables")
        }

        let steering = simd_float3(sx, sy, sz)
        let expectedSteering = simd_float3(5, 0, 0)

        XCTAssertEqual(steering, expectedSteering)
    }

    func testEvade_Scripted() {
        let script = buildScript(name: "testEvade") { s in
            s.onUpdate()
                .evade(threatEntity: .variableRef("threatEntity"),
                       maxSpeed: .variableRef("maxSpeed"),
                       result: "steering")
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        // Threat entity setup
        let threatEntityId = createEntity()
        registerPhysics(entityId: threatEntityId)

        setEntityName(entityId: threatEntityId, name: "Threat")

        translateTo(entityId: threatEntityId, position: simd_float3(5, 0, 0))
        if let physics = scene.get(component: PhysicsComponents.self, for: threatEntityId) {
            physics.velocity = simd_float3(2, 0, 0)
        }

        let maxSpeed: Float = 5.0

        let context = USCContext(entityId: entityId, script: script)
        context.variables["threatEntity"] = .string("Threat")
        context.variables["maxSpeed"] = .float(maxSpeed)

        let interpreter = USCInterpreter()

        interpreter.execute(script: script,
                            context: context,
                            forEvent: "OnUpdate")

        guard case let .vec3(sx, sy, sz)? = context.variables["steering"] else {
            return XCTFail("steering should be a vec3 in context.variables")
        }

        let steering = simd_float3(sx, sy, sz)
        let expectedSteering = simd_float3(-5, 0, 0)

        XCTAssertEqual(steering, expectedSteering)
    }

    func testOrbit_Scripted() {
        let script = buildScript(name: "testOrbit") { s in
            s.onUpdate()
                .setVariable("centerPosition", to: simd_float3(x: 0, y: 0, z: 0))
                .setVariable("radius", to: 5.0)
                .setVariable("maxSpeed", to: 2.0)
                .setVariable("deltaTime", to: 1.0)
                .orbit(centerPosition: .variableRef("centerPosition"),
                       radius: .variableRef("radius"),
                       maxSpeed: .variableRef("maxSpeed"),
                       deltaTime: .variableRef("deltaTime"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        translateTo(entityId: entityId, position: simd_float3(5, 0, 0)) // start at radius
        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let oldPos = getPosition(entityId: entityId)

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
        updateTransformSystem(entityId: entityId) // orbit modifies transform

        let newPos = getPosition(entityId: entityId)

        XCTAssertNotEqual(oldPos, newPos, "Should have orbited away from starting point")
    }

    func testSteerSeek_Scripted() {
        let script = buildScript(name: "testSteerSeek") { s in
            s.onUpdate()
                .setVariable("targetPosition", to: simd_float3(x: 10, y: 0, z: 0))
                .setVariable("maxSpeed", to: 5.0)
                .setVariable("deltaTime", to: 0.01)
                .steerSeek(targetPosition: .variableRef("targetPosition"),
                           maxSpeed: .variableRef("maxSpeed"),
                           deltaTime: .variableRef("deltaTime"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        var t: Float = 0
        let dt: Float = 0.01
        let target = simd_float3(10, 0, 0)

        while t < 10.0 {
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
            updatePhysicsSystem(deltaTime: dt)
            t += dt

            let pos = getLocalPosition(entityId: entityId)
            if distance(pos, target) < 0.1 { break }
        }

        let finalPos = getLocalPosition(entityId: entityId)
        XCTAssertEqual(finalPos.x, target.x, accuracy: 0.1)
        XCTAssertEqual(finalPos.y, target.y, accuracy: 0.1)
        XCTAssertEqual(finalPos.z, target.z, accuracy: 0.1)
    }

    func testSteerArrive_Scripted() {
        let script = buildScript(name: "testSteerArrive") { s in
            s.onUpdate()
                .setVariable("targetPosition", to: simd_float3(x: 10, y: 0, z: 0))
                .setVariable("maxSpeed", to: 5.0)
                .setVariable("slowingRadius", to: 0.2)
                .setVariable("deltaTime", to: 0.01)
                .steerArrive(targetPosition: .variableRef("targetPosition"),
                             maxSpeed: .variableRef("maxSpeed"),
                             slowingRadius: .variableRef("slowingRadius"),
                             deltaTime: .variableRef("deltaTime"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let target = simd_float3(10, 0, 0)
        let dt: Float = 0.01

        var t: Float = 0
        while t < 10.0 {
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
            updatePhysicsSystem(deltaTime: dt)
            t += dt

            if distance(getLocalPosition(entityId: entityId), target) < 0.1 { break }
        }

        let finalPos = getLocalPosition(entityId: entityId)
        XCTAssertEqual(finalPos.x, target.x, accuracy: 0.1)
        XCTAssertEqual(finalPos.y, target.y, accuracy: 0.1)
        XCTAssertEqual(finalPos.z, target.z, accuracy: 0.1)
    }

    func testSteerFlee_Scripted() {
        let script = buildScript(name: "testSteerFlee") { s in
            s.onUpdate()
                .setVariable("threatPosition", to: simd_float3(x: 5, y: 0, z: 0))
                .setVariable("maxSpeed", to: 5.0)
                .setVariable("deltaTime", to: 0.01)
                .steerFlee(threatPosition: .variableRef("threatPosition"),
                           maxSpeed: .variableRef("maxSpeed"),
                           deltaTime: .variableRef("deltaTime"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let threat = simd_float3(5, 0, 0)
        let dt: Float = 0.01

        var t: Float = 0
        while t < 10.0 {
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
            updatePhysicsSystem(deltaTime: dt)
            t += dt

            let pos = getLocalPosition(entityId: entityId)
            if distance(pos, threat) > 10.0 { break }
        }

        let finalPos = getLocalPosition(entityId: entityId)

        XCTAssertEqual(-finalPos.x, threat.x, accuracy: 0.1)
        XCTAssertEqual(-finalPos.y, threat.y, accuracy: 0.1)
        XCTAssertEqual(-finalPos.z, threat.z, accuracy: 0.1)
    }

    func testSteerPursuit_Scripted() {
        let script = buildScript(name: "testSteerPursuit") { s in
            s.onUpdate()
                .setVariable("targetEntity", to: "Target")
                .setVariable("maxSpeed", to: 50.0) // like your test: maxSpeed * 10
                .setVariable("deltaTime", to: 0.01)
                .steerPursuit(targetEntity: .variableRef("targetEntity"),
                              maxSpeed: .variableRef("maxSpeed"),
                              deltaTime: .variableRef("deltaTime"))
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        let targetId = createEntity()
        registerPhysics(entityId: targetId)

        // Naming target entity so pursuit can resolve it
        setEntityName(entityId: targetId, name: "Target")

        translateTo(entityId: entityId, position: simd_float3(0, 0, 1))
        translateTo(entityId: targetId, position: simd_float3(0, 0, -5))
        clearVelocity(entityId: entityId)
        clearVelocity(entityId: targetId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        // Target moves using steerSeek each frame
        let targetScript = buildScript(name: "targetMove") { s in
            s.onUpdate()
                .setVariable("targetPosition", to: simd_float3(x: 20, y: 0, z: 0))
                .setVariable("maxSpeed", to: 1.0)
                .setVariable("deltaTime", to: 0.01)
                .steerSeek(targetPosition: .variableRef("targetPosition"),
                           maxSpeed: .variableRef("maxSpeed"),
                           deltaTime: .variableRef("deltaTime"))
        }
        let targetCtx = USCContext(entityId: targetId, script: targetScript)

        let dt: Float = 0.01
        var t: Float = 0

        while t < 10.0 {
            // Move target forward
            interpreter.execute(script: targetScript, context: targetCtx, forEvent: "OnUpdate")

            // Pursuer pursues the target
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

            updatePhysicsSystem(deltaTime: dt)

            t += dt

            if distance(getLocalPosition(entityId: entityId),
                        getLocalPosition(entityId: targetId)) < 0.1 { break }
        }

        let finalPos = getLocalPosition(entityId: entityId)
        let finalTargetPos = getLocalPosition(entityId: targetId)

        XCTAssertEqual(distance(finalPos, finalTargetPos), 0.0, accuracy: 0.1)
    }

    func testAlignOrientationInstruction() {
        let script = buildScript(name: "AlignOrientationScript") { s in
            s.onUpdate()
                .alignOrientation(deltaTime: .float(0.016),
                                  turnSpeed: .float(1.0))
        }

        let entity = createEntity()

        registerPhysics(entityId: entity)

        // Give the entity some velocity so alignOrientation has something to use
        if let physics = scene.get(component: PhysicsComponents.self, for: entity) {
            physics.velocity = simd_float3(0, 0, 5)
        }

        let context = USCContext(entityId: entity, script: script)
        let interpreter = USCInterpreter()

        var t: Float = 0
        let dt: Float = 0.01

        while t < 10.0 {
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
            updatePhysicsSystem(deltaTime: dt)
            t += dt
        }

        let forward = getForwardAxisVector(entityId: entity)
        // Should be roughly aligned to +Z (velocity direction)
        XCTAssertEqual(forward.x, 0, accuracy: 0.01)
        XCTAssertEqual(forward.y, 0, accuracy: 0.01)
        XCTAssertGreaterThan(forward.z, 0)
    }

    func testSteerEvadeInstructionAppliesForce() {
        let script = buildScript(name: "EvadeScript") { s in
            s.onUpdate()
                .steerEvade(threatEntity: .string("Threat"),
                            maxSpeed: .float(5.0),
                            result: "force")
        }

        let subject = createEntity()
        let threat = createEntity()
        setEntityName(entityId: threat, name: "Threat")

        registerPhysics(entityId: subject)
        registerPhysics(entityId: threat)

        // Give threat some velocity so prediction makes sense
        if let physics = scene.get(component: PhysicsComponents.self, for: threat) {
            physics.velocity = simd_float3(1, 0, 0)
        }

        let context = USCContext(entityId: subject, script: script)
        let interpreter = USCInterpreter()

        var t: Float = 0
        let dt: Float = 0.01

        while t < 10.0 {
            interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
            updatePhysicsSystem(deltaTime: dt)
            t += dt
        }

        guard case let .vec3(x, _, _) = context.variables["force"] else {
            return XCTFail("force should be a vec3")
        }
        // Evade should push away from the threat's predicted path; x should be negative if threat moves +X
        XCTAssertLessThan(x, 0)
    }

    func testScript_OnStart_SetsMassComponent() {
        let script = buildScript(name: "SetMassOnStart") { s in
            s.onStart()
                .setProperty(.mass, to: 5.0)
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        let mass = getMass(entityId: entityId)
        XCTAssertEqual(mass, 5.0, "Mass should be set via script OnStart")
    }

    func testScript_OnUpdate_TranslateToMovesEntity() {
        let script = buildScript(name: "TranslateOnUpdate") { s in
            s.onUpdate()
                .translateTo(x: 1.0, y: 2.0, z: 3.0)
        }

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: PhysicsComponents.self)
        registerComponent(entityId: entityId, componentType: KineticComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)
        registerComponent(entityId: entityId, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entityId, componentType: ScenegraphComponent.self)

        // Start at origin
        translateTo(entityId: entityId, position: simd_float3(0, 0, 0))

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        let pos = getLocalPosition(entityId: entityId)
        XCTAssertEqual(pos.x, 1.0, accuracy: 0.0001)
        XCTAssertEqual(pos.y, 2.0, accuracy: 0.0001)
        XCTAssertEqual(pos.z, 3.0, accuracy: 0.0001)
    }

    func testScript_OnUpdate_DampsHighVelocity() {
        let script = buildScript(name: "DampVelocity") { s in
            s.onUpdate()
                .getProperty(.velocity, as: "vel")
                .lengthVec3("vel", as: "speed")
                .ifCondition(lhs: .variableRef("speed"),
                             .greater,
                             rhs: .float(10.0))
                { nested in
                    nested.scaleVec3("vel", literal: 0.5, as: "dampedVel")
                        .setProperty(.velocity, toVariable: "dampedVel")
                }
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        // Seed initial velocity with a magnitude > 10
        if let kinetic = scene.get(component: PhysicsComponents.self, for: entityId) {
            kinetic.velocity = simd_float3(20, 0, 0)
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard let updatedKinetic = scene.get(component: PhysicsComponents.self, for: entityId) else {
            return XCTFail("KineticComponent should exist")
        }

        // Velocity should be halved if speed > 10
        XCTAssertEqual(updatedKinetic.velocity.x, 10.0, accuracy: 0.001)
        XCTAssertEqual(updatedKinetic.velocity.y, 0.0, accuracy: 0.001)
        XCTAssertEqual(updatedKinetic.velocity.z, 0.0, accuracy: 0.001)
    }

    func testScript_OnCollisionDamageReducesHealthVariable() {
        let script = buildScript(name: "DamageOnCollision") { s in
            s.onStart()
                .setVariable("health", to: 100.0)

            s.onCollision(tag: "Damage")
                .addFloat("health", literal: -10.0, as: "newHealth")
                .setVariable("health", fromVariable: "newHealth")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // --- Step 1: Run OnStart, ensure health is initialized ---
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .float(initialHealth) = context.variables["health"] else {
            return XCTFail("health should be initialized to 100 by OnStart")
        }
        XCTAssertEqual(initialHealth, 100.0, "OnStart should set health to 100")

        // --- Step 2: Run collision event, ensure newHealth is computed ---
        interpreter.execute(script: script, context: context, forEvent: "OnCollision:Damage")

        print("Variables after collision:", context.variables)

        // Helpful extra check: did addFloat produce newHealth?
        guard case let .float(newHealth) = context.variables["newHealth"] else {
            return XCTFail("newHealth should be computed by addFloat in collision handler")
        }
        XCTAssertEqual(newHealth, 90.0, accuracy: 0.001,
                       "newHealth should be health + (-10)")

        // Final: health should have been overwritten by setVariable(... toVariable: ...)
        guard case let .float(afterDamage) = context.variables["health"] else {
            return XCTFail("health should still exist after collision")
        }
        XCTAssertEqual(afterDamage, 90.0, accuracy: 0.001,
                       "health should be reduced to 90 after collision")
    }

    // MARK: - Boolean Operations Tests

    func testGetKeyState_Scripted() {
        let script = buildScript(name: "testGetKeyState") { s in
            s.onUpdate()
                .getKeyState("w", as: "wPressed")
                .getKeyState("a", as: "aPressed")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Simulate W key pressed
        InputSystem.shared.keyState.wPressed = true
        InputSystem.shared.keyState.aPressed = false

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .bool(wPressed) = context.variables["wPressed"] else {
            return XCTFail("wPressed should be a bool")
        }
        guard case let .bool(aPressed) = context.variables["aPressed"] else {
            return XCTFail("aPressed should be a bool")
        }

        XCTAssertEqual(wPressed, true, "W key should be pressed")
        XCTAssertEqual(aPressed, false, "A key should not be pressed")

        // Reset
        InputSystem.shared.keyState.wPressed = false
    }

    func testOrBool_Scripted() {
        let script = buildScript(name: "testOrBool") { s in
            s.onStart()
                .setVariable("a", to: true)
                .setVariable("b", to: false)
                .orBool("a", "b", as: "result")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .bool(result) = context.variables["result"] else {
            return XCTFail("result should be a bool")
        }

        XCTAssertEqual(result, true, "true OR false should be true")
    }

    func testAndBool_Scripted() {
        let script = buildScript(name: "testAndBool") { s in
            s.onStart()
                .setVariable("a", to: true)
                .setVariable("b", to: false)
                .andBool("a", "b", as: "result")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .bool(result) = context.variables["result"] else {
            return XCTFail("result should be a bool")
        }

        XCTAssertEqual(result, false, "true AND false should be false")
    }

    func testNotBool_Scripted() {
        let script = buildScript(name: "testNotBool") { s in
            s.onStart()
                .setVariable("a", to: true)
                .notBool("a", as: "result")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        guard case let .bool(result) = context.variables["result"] else {
            return XCTFail("result should be a bool")
        }

        XCTAssertEqual(result, false, "NOT true should be false")
    }

    func testIsWASDPressed_Scripted() {
        let script = buildScript(name: "testIsWASDPressed") { s in
            s.onUpdate()
                // Query each key state
                .getKeyState("w", as: "w")
                .getKeyState("a", as: "a")
                .getKeyState("s", as: "s")
                .getKeyState("d", as: "d")
                // Combine with OR: wasd = w || a || s || d
                .orBool("w", "a", as: "wa")
                .orBool("s", "d", as: "sd")
                .orBool("wa", "sd", as: "wasdPressed")
                // Use in conditional
                .ifCondition(lhs: .variableRef("wasdPressed"), .equal, rhs: .bool(true)) { nested in
                    nested.setVariable("moved", to: true)
                }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Test 1: Press W key
        InputSystem.shared.keyState.wPressed = true
        InputSystem.shared.keyState.aPressed = false
        InputSystem.shared.keyState.sPressed = false
        InputSystem.shared.keyState.dPressed = false

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .bool(wasdPressed) = context.variables["wasdPressed"] else {
            return XCTFail("wasdPressed should be a bool")
        }
        XCTAssertEqual(wasdPressed, true, "WASD should be pressed when W is pressed")

        guard case let .bool(moved) = context.variables["moved"] else {
            return XCTFail("moved should be set")
        }
        XCTAssertEqual(moved, true, "moved should be true when WASD is pressed")

        // Test 2: Press A key
        context.variables.removeAll()
        InputSystem.shared.keyState.wPressed = false
        InputSystem.shared.keyState.aPressed = true

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .bool(wasdPressed2) = context.variables["wasdPressed"] else {
            return XCTFail("wasdPressed should be a bool")
        }
        XCTAssertEqual(wasdPressed2, true, "WASD should be pressed when A is pressed")

        // Test 3: No keys pressed
        context.variables.removeAll()
        InputSystem.shared.keyState.wPressed = false
        InputSystem.shared.keyState.aPressed = false
        InputSystem.shared.keyState.sPressed = false
        InputSystem.shared.keyState.dPressed = false

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        guard case let .bool(wasdPressed3) = context.variables["wasdPressed"] else {
            return XCTFail("wasdPressed should be a bool")
        }
        XCTAssertEqual(wasdPressed3, false, "WASD should not be pressed when no keys are pressed")
        XCTAssertNil(context.variables["moved"], "moved should not be set when WASD not pressed")

        // Reset
        InputSystem.shared.keyState.wPressed = false
        InputSystem.shared.keyState.aPressed = false
    }
}
