//
//  ScriptingAPITest.swift
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

final class ScriptingAPITest: XCTestCase {
    override func setUp() {
        super.setUp()
        // Initialize scripting system
        initScriptingSystem()
    }
    
    override func tearDown() {
        super.tearDown()
        destroyAllEntities()
    }
    
    func registerPhysics(entityId: EntityID){
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
                .translateTo(Vec3(x: 1.0, y: 2.0, z: 3.0))
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
                .translateTo(simd_float3(1,2,3))
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
                .translateBy(Vec3(x: 1.0, y: 2.0, z: 3.0))
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
                .translateBy(simd_float3(1,2,3))
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
                .rotateTo(degrees: 90.0, axis: Vec3(x: 0.0, y: 1.0, z: 0.0))
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
    
    func testRotateBy_Scripted(){
        
        let script = buildScript(name: "test") { s in
            
            s.onUpdate()
                .rotateBy(degrees: 45.0, axis: Vec3(x: 0.0, y: 0.0, z: 1.0))
        }
        
        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        
        let interpreter = USCInterpreter()
        
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
        
        let updatedMatrix = getLocalOrientation(entityId: entityId)
        XCTAssertNotEqual(updatedMatrix, simd_float3x3(1)) // Ensure it updated
    }
    
    func testSetAndGetMass_Scripted(){
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
                .applyForce(force: Vec3(x: 10, y: 0, z: 0))
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
    
    func testClearForces_Scripted() {
        
    }
    
    func testGetVelocity_Scripted() {
        
        let script = buildScript(name: "test") { s in
            s.onUpdate()
                s.setProperty(.velocity, to: Vec3(x: 5, y: 0, z: 0))
        }
        
        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        let context = USCContext(entityId: entityId, script: script)
        
        let interpreter = USCInterpreter()
        
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
        
        let retrievedVelocity = getVelocity(entityId: entityId)
        XCTAssertEqual(retrievedVelocity, simd_float3(5,0,0), "Velocity should be correctly retrieved.")
        
    }
    
    func testLinearAccelerationUpdateWithForces_Scripted() {
        let script = buildScript(name: "test") { s in
            s.onStart()
                .setProperty(.mass, to: 2.0)

            s.onUpdate()
                .applyForce(force: Vec3(x: 10, y: 0, z: 0))
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
                .applyForce(force: Vec3(x: 10, y: 0, z: 0))
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
                .applyForce(force: Vec3(x: 10, y: 0, z: 0))
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
                .setVariable(ScriptArgKey.targetPosition.rawValue, to: Vec3(x: 10, y: 0, z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue, to: 5.0)
                .callAction(.seek, args: [.targetPosition, .maxSpeed], result: "force")
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
                .setVariable(ScriptArgKey.threatPosition.rawValue, to: Vec3(x: 5,y: 0,z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue, to: 5.0)
                .callAction(.flee,
                            args: [.threatPosition, .maxSpeed],
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
                .callAction(.arrive,
                            args: [.targetPosition, .maxSpeed, .slowingRadius],
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
        context.variables[ScriptArgKey.targetPosition.rawValue] =
            .vec3(x: targetPosition.x, y: targetPosition.y, z: targetPosition.z)
        context.variables[ScriptArgKey.maxSpeed.rawValue] =
            .float(maxSpeed)
        context.variables[ScriptArgKey.slowingRadius.rawValue] =
            .float(slowingRadius)

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
                .callAction(.pursuit,
                            args: [.targetEntity, .maxSpeed],
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
        context.variables[ScriptArgKey.targetEntity.rawValue] =
            .string("Target")
        context.variables[ScriptArgKey.maxSpeed.rawValue] =
            .float(maxSpeed)

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
                .callAction(.evade,
                            args: [.threatEntity, .maxSpeed],
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
        context.variables[ScriptArgKey.threatEntity.rawValue] =
            .string("Threat")
        context.variables[ScriptArgKey.maxSpeed.rawValue] =
            .float(maxSpeed)

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
                .setVariable(ScriptArgKey.centerPosition.rawValue,
                             to: Vec3(x: 0, y: 0, z: 0))
                .setVariable(ScriptArgKey.radius.rawValue,
                             to: 5.0)
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 2.0)
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 1.0)
                .callAction(.orbit,
                            args: [.centerPosition, .radius, .maxSpeed, .deltaTime])
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        
        translateTo(entityId: entityId, position: simd_float3(5, 0, 0))   // start at radius
        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let oldPos = getPosition(entityId: entityId)

        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")
        updateTransformSystem(entityId: entityId)   // orbit modifies transform

        let newPos = getPosition(entityId: entityId)

        XCTAssertNotEqual(oldPos, newPos, "Should have orbited away from starting point")
    }

    func testSteerSeek_Scripted() {
        let script = buildScript(name: "testSteerSeek") { s in
            s.onUpdate()
                .setVariable(ScriptArgKey.targetPosition.rawValue,
                             to: Vec3(x: 10, y: 0, z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 5.0)
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 0.01)
                .callAction(.steerSeek,
                            args: [.targetPosition, .maxSpeed, .deltaTime])
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        translateTo(entityId: entityId, position: simd_float3(0,0,0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        var t: Float = 0
        let dt: Float = 0.01
        let target = simd_float3(10,0,0)

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
                .setVariable(ScriptArgKey.targetPosition.rawValue,
                             to: Vec3(x: 10, y: 0, z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 5.0)
                .setVariable(ScriptArgKey.slowingRadius.rawValue,
                             to: 0.2)
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 0.01)
                .callAction(.steerArrive,
                            args: [.targetPosition, .maxSpeed, .slowingRadius, .deltaTime])
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        
        translateTo(entityId: entityId, position: simd_float3(0,0,0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let target = simd_float3(10,0,0)
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
                .setVariable(ScriptArgKey.threatPosition.rawValue,
                             to: Vec3(x: 5, y: 0, z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 5.0)
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 0.01)
                .callAction(.steerFlee,
                            args: [.threatPosition, .maxSpeed, .deltaTime])
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        
        translateTo(entityId: entityId, position: simd_float3(0,0,0))
        clearVelocity(entityId: entityId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        let threat = simd_float3(5,0,0)
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
                .setVariable(ScriptArgKey.targetEntity.rawValue,
                             to: "Target")
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 50.0)          // like your test: maxSpeed * 10
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 0.01)
                .callAction(.steerPursuit,
                            args: [.targetEntity, .maxSpeed, .deltaTime])
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)
        
        let targetId = createEntity()
        registerPhysics(entityId: targetId)
        
        // Naming target entity so pursuit can resolve it
        setEntityName(entityId: targetId, name: "Target")

        translateTo(entityId: entityId, position: simd_float3(0,0,1))
        translateTo(entityId: targetId, position: simd_float3(0,0,-5))
        clearVelocity(entityId: entityId)
        clearVelocity(entityId: targetId)

        let interpreter = USCInterpreter()
        let context = USCContext(entityId: entityId, script: script)

        // Target moves using steerSeek each frame
        let targetScript = buildScript(name: "targetMove") { s in
            s.onUpdate()
                .setVariable(ScriptArgKey.targetPosition.rawValue,
                             to: Vec3(x: 20, y: 0, z: 0))
                .setVariable(ScriptArgKey.maxSpeed.rawValue,
                             to: 1.0)
                .setVariable(ScriptArgKey.deltaTime.rawValue,
                             to: 0.01)
                .callAction(.steerSeek,
                            args: [.targetPosition, .maxSpeed, .deltaTime])
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
                             rhs: .float(10.0)) { nested in
                    nested.scaleVec3("vel", literal: 0.5, as: "dampedVel")
                          .setProperty(.velocity, toVariable: "dampedVel")
                }
        }

        let entityId = createEntity()
        registerPhysics(entityId: entityId)

        // Seed initial velocity with a magnitude > 10
        if var kinetic = scene.get(component: PhysicsComponents.self, for: entityId) {
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



}
