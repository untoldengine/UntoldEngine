//
//  ScriptingTests.swift
//  UntoldEngineTests
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

@testable import UntoldEngine
import XCTest

final class ScriptingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Initialize scripting system
        initScriptingSystem()
    }

    override func tearDown() {
        super.tearDown()
        destroyAllEntities()
    }

    // MARK: - Instruction Creation Tests

    func testEventInstructionCreation() {
        let builder = USCBuilder()
        builder.onStart()

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.name, "TestScript")
        XCTAssertEqual(script.instructions.count, 1)

        if case let .event(name) = script.instructions[0] {
            XCTAssertEqual(name, "OnStart")
        } else {
            XCTFail("Expected event instruction")
        }
    }

    func testMultipleEventInstructions() {
        let builder = USCBuilder()
        builder.onStart()
        builder.onUpdate()
        builder.onCollision(tag: "Enemy")

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.instructions.count, 3)

        if case let .event(name) = script.instructions[0] {
            XCTAssertEqual(name, "OnStart")
        } else {
            XCTFail("Expected OnStart event")
        }

        if case let .event(name) = script.instructions[1] {
            XCTAssertEqual(name, "OnUpdate")
        } else {
            XCTFail("Expected OnUpdate event")
        }

        if case let .event(name) = script.instructions[2] {
            XCTAssertEqual(name, "OnCollision:Enemy")
        } else {
            XCTFail("Expected OnCollision:Enemy event")
        }
    }

    // MARK: - Flow Control Tests

    func testIfConditionInstruction() {
        let builder = USCBuilder()
        builder.ifCondition(lhs: .float(5.0), .greater, rhs: .float(3.0)) { _ in }

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.instructions.count, 2) // ifCondition + endIf

        if case let .ifCondition(condition) = script.instructions[0] {
            XCTAssertEqual(condition.op, .greater)
        } else {
            XCTFail("Expected ifCondition instruction")
        }

        if case .endIf = script.instructions[1] {
            // Success
        } else {
            XCTFail("Expected endIf instruction")
        }
    }

    func testNestedIfConditions() {
        let builder = USCBuilder()
        builder.ifCondition(lhs: .float(5.0), .greater, rhs: .float(3.0)) { nested in
            nested.ifCondition(lhs: .float(10.0), .less, rhs: .float(20.0)) { _ in }
        }

        let script = builder.build(name: "TestScript")

        // Should have: ifCondition, ifCondition, endIf, endIf
        XCTAssertEqual(script.instructions.count, 4)
    }

    func testLoopInstruction() {
        let builder = USCBuilder()
        builder.loop(3) { nested in
            nested.log("Loop iteration")
        }

        let script = builder.build(name: "TestScript")

        // Should have: loop, log, endLoop
        XCTAssertEqual(script.instructions.count, 3)

        if case let .loop(iterations) = script.instructions[0] {
            XCTAssertEqual(iterations, 3)
        } else {
            XCTFail("Expected loop instruction")
        }

        if case .endLoop = script.instructions[2] {
            // Success
        } else {
            XCTFail("Expected endLoop instruction")
        }
    }

    // MARK: - Math Operation Tests

    func testAddFloatInstruction() {
        let builder = USCBuilder()
        builder.addFloat("a", "b", as: "result")

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .math(mathInst) = script.instructions[0] {
            if case let .addFloat(lhs, rhs) = mathInst.op {
                XCTAssertEqual(lhs, "a")
                XCTAssertEqual(rhs, "b")
                XCTAssertEqual(mathInst.output, "result")
            } else {
                XCTFail("Expected addFloat operation")
            }
        } else {
            XCTFail("Expected math instruction")
        }
    }

    func testMulFloatLiteralInstruction() {
        let builder = USCBuilder()
        builder.mulFloat("x", literal: 2.5, as: "result")

        let script = builder.build(name: "TestScript")

        if case let .math(mathInst) = script.instructions[0] {
            if case let .mulFloatLiteral(lhs, rhs) = mathInst.op {
                XCTAssertEqual(lhs, "x")
                XCTAssertEqual(rhs, 2.5)
            } else {
                XCTFail("Expected mulFloatLiteral operation")
            }
        } else {
            XCTFail("Expected math instruction")
        }
    }

    func testVec3Operations() {
        let builder = USCBuilder()
        builder.addVec3("v1", "v2", as: "sum")
        builder.scaleVec3("v1", literal: 2.0, as: "scaled")
        builder.lengthVec3("v1", as: "length")

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.instructions.count, 3)

        if case let .math(mathInst) = script.instructions[0] {
            if case .addVec3 = mathInst.op {
                XCTAssertEqual(mathInst.output, "sum")
            } else {
                XCTFail("Expected addVec3 operation")
            }
        }

        if case let .math(mathInst) = script.instructions[1] {
            if case .scaleVec3Literal = mathInst.op {
                XCTAssertEqual(mathInst.output, "scaled")
            } else {
                XCTFail("Expected scaleVec3Literal operation")
            }
        }

        if case let .math(mathInst) = script.instructions[2] {
            if case .lengthVec3 = mathInst.op {
                XCTAssertEqual(mathInst.output, "length")
            } else {
                XCTFail("Expected lengthVec3 operation")
            }
        }
    }

    // MARK: - Action Tests

    func testCallActionInstruction() {
        let builder = USCBuilder()
        builder.callAction("Math.addVec3", args: ["a", "b"], result: "result")

        let script = builder.build(name: "TestScript")

        if case let .callAction(name, args, result) = script.instructions[0] {
            XCTAssertEqual(name, "Math.addVec3")
            XCTAssertEqual(args, ["a", "b"])
            XCTAssertEqual(result, "result")
        } else {
            XCTFail("Expected callAction instruction")
        }
    }

    func testActionRegistry() {
        let registry = USCActionRegistry.shared

        // Register a test action
        registry.register(name: "Test.add") { _, args in
            guard let a = args["a"], case let .float(aVal) = a,
                  let b = args["b"], case let .float(bVal) = b
            else {
                return nil
            }
            return .float(aVal + bVal)
        }

        // Verify action was registered
        let action = registry.resolve(name: "Test.add")
        XCTAssertNotNil(action)

        // Test action execution
        let context = USCContext(entityId: createEntity(), script: nil)
        let result = action?(context, ["a": .float(5.0), "b": .float(3.0)])

        if case let .float(value) = result {
            XCTAssertEqual(value, 8.0)
        } else {
            XCTFail("Expected float result")
        }
    }

    // MARK: - Input Tests

    func testInputInstructions() {
        let builder = USCBuilder()
        builder.ifKeyPressed("W") { nested in
            nested.log("W pressed")
        }

        let script = builder.build(name: "TestScript")

        // Should have: ifInput, log, endIf
        XCTAssertEqual(script.instructions.count, 3)

        if case let .ifInput(condition) = script.instructions[0] {
            if case let .keyPressed(key) = condition {
                XCTAssertEqual(key, "W")
            } else {
                XCTFail("Expected keyPressed condition")
            }
        } else {
            XCTFail("Expected ifInput instruction")
        }
    }

    // MARK: - Transform Tests

    func testTranslateToInstruction() {
        let builder = USCBuilder()
        builder.translateTo(x: 1.0, y: 2.0, z: 3.0)

        let script = builder.build(name: "TestScript")

        if case let .translateTo(entity, position) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(position.x, 1.0)
            XCTAssertEqual(position.y, 2.0)
            XCTAssertEqual(position.z, 3.0)
        } else {
            XCTFail("Expected translateTo instruction")
        }
    }

    func testRotateByInstruction() {
        let builder = USCBuilder()
        builder.rotateBy(degrees: 45.0, axis: Vec3(x: 0, y: 1, z: 0))

        let script = builder.build(name: "TestScript")

        if case let .rotateBy(entity, degrees, axis) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(degrees, 45.0)
            XCTAssertEqual(axis.y, 1.0)
        } else {
            XCTFail("Expected rotateBy instruction")
        }
    }

    // MARK: - Property Access Tests

    func testGetPropertyInstruction() {
        let builder = USCBuilder()
        builder.getProperty("position", as: "pos")

        let script = builder.build(name: "TestScript")

        if case let .getProperty(entity, key, varName) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "position")
            XCTAssertEqual(varName, "pos")
        } else {
            XCTFail("Expected getProperty instruction")
        }
    }

    func testSetPropertyInstruction() {
        let builder = USCBuilder()
        builder.setProperty("speed", to: 10.0)
        builder.setProperty("name", to: "Player")
        builder.setProperty("active", to: true)

        let script = builder.build(name: "TestScript")

        XCTAssertEqual(script.instructions.count, 3)

        if case let .setProperty(_, _, value) = script.instructions[0] {
            if case let .float(floatValue) = value {
                XCTAssertEqual(floatValue, 10.0)
            } else {
                XCTFail("Expected float value")
            }
        }

        if case let .setProperty(_, _, value) = script.instructions[1] {
            if case let .string(stringValue) = value {
                XCTAssertEqual(stringValue, "Player")
            } else {
                XCTFail("Expected string value")
            }
        }

        if case let .setProperty(_, _, value) = script.instructions[2] {
            if case let .bool(boolValue) = value {
                XCTAssertEqual(boolValue, true)
            } else {
                XCTFail("Expected bool value")
            }
        }
    }

    func testSetPropertyWithVariable() {
        let builder = USCBuilder()
        builder.setProperty("velocity", toVariable: "newVel")

        let script = builder.build(name: "TestScript")

        if case let .setProperty(_, _, value) = script.instructions[0] {
            if case let .variableRef(varName) = value {
                XCTAssertEqual(varName, "newVel")
            } else {
                XCTFail("Expected variableRef value")
            }
        }
    }

    // MARK: - Script Building Tests

    func testBuildScriptWithMetadata() {
        let builder = USCBuilder()
        builder.onUpdate()

        let script = builder.build(
            name: "UpdateScript",
            triggerType: .perFrame,
            executionMode: .interpreted
        )

        XCTAssertEqual(script.name, "UpdateScript")
        XCTAssertEqual(script.metadata.triggerType, .perFrame)
        XCTAssertEqual(script.metadata.executionMode, .interpreted)
    }

    func testBuildScriptConvenienceFunction() {
        let script = buildScript(name: "TestScript", triggerType: .event) { builder in
            builder.onCollision()
            builder.log("Collision detected")
        }

        XCTAssertEqual(script.name, "TestScript")
        XCTAssertEqual(script.metadata.triggerType, .event)
        XCTAssertEqual(script.instructions.count, 2)
    }

    // MARK: - Interpreter Tests

    func testInterpreterExecutesMathOperations() {
        let script = buildScript(name: "MathTest") { builder in
            builder.onStart()
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        // Set up variables
        context.variables["a"] = .float(5.0)
        context.variables["b"] = .float(3.0)

        // Create script with math operations
        let mathScript = buildScript(name: "MathOps") { builder in
            builder.addFloat("a", "b", as: "sum")
            builder.mulFloat("a", literal: 2.0, as: "doubled")
        }

        context.script = mathScript
        let interpreter = USCInterpreter()
        interpreter.execute(script: mathScript, context: context)

        // Verify results
        if case let .float(sum) = context.variables["sum"] {
            XCTAssertEqual(sum, 8.0)
        } else {
            XCTFail("Expected sum to be 8.0")
        }

        if case let .float(doubled) = context.variables["doubled"] {
            XCTAssertEqual(doubled, 10.0)
        } else {
            XCTFail("Expected doubled to be 10.0")
        }
    }

    func testInterpreterExecutesVec3Math() {
        let entityId = createEntity()

        let script = buildScript(name: "Vec3Test") { builder in
            builder.addVec3("v1", "v2", as: "result")
            builder.lengthVec3("result", as: "length")
        }

        let context = USCContext(entityId: entityId, script: script)
        context.variables["v1"] = .vec3(x: 1.0, y: 0.0, z: 0.0)
        context.variables["v2"] = .vec3(x: 2.0, y: 3.0, z: 0.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        if case let .vec3(x, y, z) = context.variables["result"] {
            XCTAssertEqual(x, 3.0)
            XCTAssertEqual(y, 3.0)
            XCTAssertEqual(z, 0.0)
        } else {
            XCTFail("Expected vec3 result")
        }

        if case let .float(length) = context.variables["length"] {
            XCTAssertEqual(length, sqrt(18.0), accuracy: 0.001)
        } else {
            XCTFail("Expected length as float")
        }
    }

    func testInterpreterEvaluatesConditions() {
        let entityId = createEntity()

        let script = buildScript(name: "ConditionTest") { builder in
            builder.ifCondition(lhs: .float(10.0), .greater, rhs: .float(5.0)) { nested in
                nested.log("Condition true")
            }
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // This should execute without errors
        interpreter.execute(script: script, context: context)

        // Test should pass if no crash occurs
        XCTAssertTrue(true)
    }

    // MARK: - Vec3 Helper Tests

    func testVec3Constants() {
        XCTAssertEqual(Vec3.zero.x, 0.0)
        XCTAssertEqual(Vec3.zero.y, 0.0)
        XCTAssertEqual(Vec3.zero.z, 0.0)

        XCTAssertEqual(Vec3.up.x, 0.0)
        XCTAssertEqual(Vec3.up.y, 1.0)
        XCTAssertEqual(Vec3.up.z, 0.0)

        XCTAssertEqual(Vec3.forward.x, 0.0)
        XCTAssertEqual(Vec3.forward.y, 0.0)
        XCTAssertEqual(Vec3.forward.z, -1.0)
    }

    func testVec3SimdConversion() {
        let vec = Vec3(x: 1.0, y: 2.0, z: 3.0)
        let simdVec = vec.simd

        XCTAssertEqual(simdVec.x, 1.0)
        XCTAssertEqual(simdVec.y, 2.0)
        XCTAssertEqual(simdVec.z, 3.0)
    }

    // MARK: - Script Metadata Tests

    func testScriptMetadataDefaults() {
        let metadata = ScriptMetadata.default

        XCTAssertEqual(metadata.triggerType, .perFrame)
        XCTAssertEqual(metadata.executionMode, .auto)
    }

    func testTriggerTypeValues() {
        XCTAssertEqual(TriggerType.event.rawValue, "event")
        XCTAssertEqual(TriggerType.perFrame.rawValue, "perFrame")
        XCTAssertEqual(TriggerType.manual.rawValue, "manual")
    }

    // MARK: - Complex Script Tests

    func testComplexScript() {
        let script = buildScript(name: "ComplexScript") { builder in
            builder.onUpdate()
                .getProperty("velocity", as: "vel")
                .lengthVec3("vel", as: "speed")
                .ifCondition(lhs: .variableRef("speed"), .greater, rhs: .float(10.0)) { nested in
                    nested.scaleVec3("vel", literal: 0.9, as: "dampedVel")
                        .setProperty("velocity", toVariable: "dampedVel")
                }
                .log("Update complete")
        }

        XCTAssertEqual(script.name, "ComplexScript")
        XCTAssertGreaterThan(script.instructions.count, 5)

        // Verify first instruction is OnUpdate event
        if case let .event(name) = script.instructions[0] {
            XCTAssertEqual(name, "OnUpdate")
        } else {
            XCTFail("Expected OnUpdate event")
        }
    }

    func testScriptWithMultipleActions() {
        let script = buildScript(name: "ActionScript") { builder in
            builder.onStart()
                .callAction("Math.addVec3", args: ["a", "b"], result: "sum")
                .callAction("Math.lengthVec3", args: ["sum"], result: "length")
                .setProperty("distance", toVariable: "length")
        }

        var actionCount = 0
        for instruction in script.instructions {
            if case .callAction = instruction {
                actionCount += 1
            }
        }

        XCTAssertEqual(actionCount, 2)
    }

    // MARK: - Comparison Operators Tests

    func testComparisonOperators() {
        let ops: [CompareOp] = [.less, .greater, .equal, .notEqual, .lessOrEqual, .greaterOrEqual]

        XCTAssertEqual(ops.count, 6)
        XCTAssertEqual(CompareOp.less.rawValue, "less")
        XCTAssertEqual(CompareOp.greater.rawValue, "greater")
        XCTAssertEqual(CompareOp.equal.rawValue, "equal")
    }

    // MARK: - Value Type Tests

    func testValueTypes() {
        let floatValue = Value.float(3.14)
        let vec3Value = Value.vec3(x: 1.0, y: 2.0, z: 3.0)
        let stringValue = Value.string("test")
        let boolValue = Value.bool(true)
        let varRefValue = Value.variableRef("myVar")

        // Test that values can be created without errors
        XCTAssertNotNil(floatValue)
        XCTAssertNotNil(vec3Value)
        XCTAssertNotNil(stringValue)
        XCTAssertNotNil(boolValue)
        XCTAssertNotNil(varRefValue)
    }

    // MARK: - Multi-Event Script Tests

    func testScriptWithBothOnStartAndOnUpdate() {
        let script = buildScript(name: "MultiEventScript") { builder in
            builder.onStart()
                .log("Start executed")
                .setProperty("initialized", to: true)
            builder.onUpdate()
                .log("Update executed")
                .setProperty("frameCount", to: 1.0)
        }

        XCTAssertEqual(script.name, "MultiEventScript")
        XCTAssertEqual(script.instructions.count, 6) // 2 events + 4 instructions

        // Verify both events are present
        var hasOnStart = false
        var hasOnUpdate = false

        for instruction in script.instructions {
            if case let .event(name) = instruction {
                if name == "OnStart" {
                    hasOnStart = true
                }
                if name == "OnUpdate" {
                    hasOnUpdate = true
                }
            }
        }

        XCTAssertTrue(hasOnStart, "Script should have OnStart event")
        XCTAssertTrue(hasOnUpdate, "Script should have OnUpdate event")
    }

    func testInterpreterExecutesOnlyTargetEvent() {
        let entityId = createEntity()

        let script = buildScript(name: "SelectiveEvent") { builder in
            builder.onStart()
                .setProperty("startExecuted", to: true)
            builder.onUpdate()
                .setProperty("updateExecuted", to: true)
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Execute only OnStart
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        // Verify only OnStart was executed
        if case let .bool(startExecuted) = context.variables["startExecuted"] {
            XCTAssertTrue(startExecuted, "OnStart should have executed")
        } else {
            XCTFail("startExecuted variable should be set")
        }

        // Verify OnUpdate was NOT executed
        XCTAssertNil(context.variables["updateExecuted"], "OnUpdate should not have executed")

        // Now execute OnUpdate
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        // Verify OnUpdate was executed
        if case let .bool(updateExecuted) = context.variables["updateExecuted"] {
            XCTAssertTrue(updateExecuted, "OnUpdate should have executed")
        } else {
            XCTFail("updateExecuted variable should be set")
        }
    }

    func testScriptWithMultipleCollisionEvents() {
        let script = buildScript(name: "MultiCollision") { builder in
            builder.onCollision(tag: "Enemy")
                .log("Enemy collision")
            builder.onCollision(tag: "Pickup")
                .log("Pickup collision")
            builder.onUpdate()
                .log("Update")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Execute only Enemy collision
        interpreter.execute(script: script, context: context, forEvent: "OnCollision:Enemy")

        // Should execute without errors
        XCTAssertTrue(true)
    }

    func testInterpreterWithNoEventFilter() {
        let entityId = createEntity()

        let script = buildScript(name: "AllEvents") { builder in
            builder.onStart()
                .setProperty("counter", to: 1.0)
            builder.onUpdate()
                .setProperty("counter", to: 2.0)
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Execute without event filter (should execute all events)
        interpreter.execute(script: script, context: context, forEvent: nil)

        // The last setProperty should win
        if case let .float(counter) = context.variables["counter"] {
            XCTAssertEqual(counter, 2.0)
        } else {
            XCTFail("counter variable should be set")
        }
    }

    func testComplexMultiEventScript() {
        let entityId = createEntity()

        let script = buildScript(name: "ComplexMultiEvent") { builder in
            builder.onStart()
                .setProperty("health", to: 100.0)
                .setProperty("speed", to: 5.0)
                .log("Initialized")
            builder.onUpdate()
                .getProperty("speed", as: "currentSpeed")
                .mulFloat("currentSpeed", literal: 1.01, as: "newSpeed")
                .setProperty("speed", toVariable: "newSpeed")
            builder.onCollision(tag: "Damage")
                .getProperty("health", as: "currentHealth")
                .addFloat("currentHealth", literal: -10.0, as: "newHealth")
                .setProperty("health", toVariable: "newHealth")
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()

        // Execute OnStart
        interpreter.execute(script: script, context: context, forEvent: "OnStart")

        if case let .float(health) = context.variables["health"] {
            XCTAssertEqual(health, 100.0)
        } else {
            XCTFail("health should be initialized")
        }

        if case let .float(speed) = context.variables["speed"] {
            XCTAssertEqual(speed, 5.0)
        } else {
            XCTFail("speed should be initialized")
        }

        // Execute OnUpdate
        interpreter.execute(script: script, context: context, forEvent: "OnUpdate")

        if case let .float(speed) = context.variables["speed"] {
            XCTAssertEqual(speed, 5.05, accuracy: 0.01)
        } else {
            XCTFail("speed should be updated")
        }

        // Execute OnCollision:Damage
        interpreter.execute(script: script, context: context, forEvent: "OnCollision:Damage")

        if case let .float(health) = context.variables["health"] {
            XCTAssertEqual(health, 90.0)
        } else {
            XCTFail("health should be decreased")
        }
    }

    // MARK: - Variable Tests

    func testSetVariableFloat() {
        let builder = USCBuilder()
        builder.setVariable("speed", to: 5.0)

        let script = builder.build(name: "TestScript")

        if case let .setVariable(name, value) = script.instructions[0] {
            XCTAssertEqual(name, "speed")
            if case let .float(floatValue) = value {
                XCTAssertEqual(floatValue, 5.0)
            } else {
                XCTFail("Expected float value")
            }
        } else {
            XCTFail("Expected setVariable instruction")
        }
    }

    func testSetVariableVec3() {
        let builder = USCBuilder()
        builder.setVariable("direction", to: Vec3(x: 1.0, y: 0.0, z: 0.0))

        let script = builder.build(name: "TestScript")

        if case let .setVariable(name, value) = script.instructions[0] {
            XCTAssertEqual(name, "direction")
            if case let .vec3(x, y, z) = value {
                XCTAssertEqual(x, 1.0)
                XCTAssertEqual(y, 0.0)
                XCTAssertEqual(z, 0.0)
            } else {
                XCTFail("Expected vec3 value")
            }
        } else {
            XCTFail("Expected setVariable instruction")
        }
    }

    func testSetVariableString() {
        let builder = USCBuilder()
        builder.setVariable("targetEntity", to: "Player")

        let script = builder.build(name: "TestScript")

        if case let .setVariable(name, value) = script.instructions[0] {
            XCTAssertEqual(name, "targetEntity")
            if case let .string(stringValue) = value {
                XCTAssertEqual(stringValue, "Player")
            } else {
                XCTFail("Expected string value")
            }
        } else {
            XCTFail("Expected setVariable instruction")
        }
    }

    func testSetVariableBool() {
        let builder = USCBuilder()
        builder.setVariable("isActive", to: true)

        let script = builder.build(name: "TestScript")

        if case let .setVariable(name, value) = script.instructions[0] {
            XCTAssertEqual(name, "isActive")
            if case let .bool(boolValue) = value {
                XCTAssertEqual(boolValue, true)
            } else {
                XCTFail("Expected bool value")
            }
        } else {
            XCTFail("Expected setVariable instruction")
        }
    }

    func testInterpreterExecutesSetVariable() {
        let entityId = createEntity()

        let script = buildScript(name: "VarTest") { builder in
            builder.setVariable("maxSpeed", to: 10.0)
            builder.setVariable("target", to: "Enemy")
        }

        let context = USCContext(entityId: entityId, script: script)
        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        // Verify variables were set
        if case let .float(maxSpeed) = context.variables["maxSpeed"] {
            XCTAssertEqual(maxSpeed, 10.0)
        } else {
            XCTFail("maxSpeed variable should be set")
        }

        if case let .string(target) = context.variables["target"] {
            XCTAssertEqual(target, "Enemy")
        } else {
            XCTFail("target variable should be set")
        }
    }

    // MARK: - ScriptProperty / ScriptAxis Tests

    func testScriptPropertyRawValues() {
        XCTAssertEqual(ScriptProperty.position.rawValue, "position")
        XCTAssertEqual(ScriptProperty.rotation.rawValue, "rotation")
        XCTAssertEqual(ScriptProperty.scale.rawValue, "scale")

        XCTAssertEqual(ScriptProperty.velocity.rawValue, "velocity")
        XCTAssertEqual(ScriptProperty.acceleration.rawValue, "acceleration")
        XCTAssertEqual(ScriptProperty.mass.rawValue, "mass")

        XCTAssertEqual(ScriptProperty.intensity.rawValue, "intensity")
        XCTAssertEqual(ScriptProperty.color.rawValue, "color")
    }

    func testScriptAxisRawValues() {
        XCTAssertEqual(ScriptAxis.x.rawValue, "x")
        XCTAssertEqual(ScriptAxis.y.rawValue, "y")
        XCTAssertEqual(ScriptAxis.z.rawValue, "z")
    }

    func testScriptPropertyKeyPaths() {
        // No axis
        XCTAssertEqual(ScriptProperty.position.keyPath(), "position")
        XCTAssertEqual(ScriptProperty.velocity.keyPath(), "velocity")
        XCTAssertEqual(ScriptProperty.intensity.keyPath(), "intensity")

        // With axis
        XCTAssertEqual(ScriptProperty.position.keyPath(axis: .x), "position.x")
        XCTAssertEqual(ScriptProperty.velocity.keyPath(axis: .y), "velocity.y")
        XCTAssertEqual(ScriptProperty.color.keyPath(axis: .z), "color.z")
    }

    // MARK: - Enum-based Property Access Builder Tests

    func testGetPropertyUsingEnumOnSelf() {
        let builder = USCBuilder()
        builder.getProperty(.position, as: "pos")

        let script = builder.build(name: "EnumPropertyTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .getProperty(entity, key, varName) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "position") // from ScriptProperty.position.keyPath()
            XCTAssertEqual(varName, "pos")
        } else {
            XCTFail("Expected getProperty instruction")
        }
    }

    func testGetPropertyUsingEnumWithAxis() {
        let builder = USCBuilder()
        builder.getProperty(.velocity, axis: .y, as: "velY")

        let script = builder.build(name: "EnumPropertyAxisTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .getProperty(entity, key, varName) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "velocity.y") // from ScriptProperty.velocity.keyPath(axis: .y)
            XCTAssertEqual(varName, "velY")
        } else {
            XCTFail("Expected getProperty instruction with axis")
        }
    }

    func testGetPropertyOfOtherEntityUsingEnum() {
        let builder = USCBuilder()
        builder.getProperty(of: "Player", .position, as: "playerPos")

        let script = builder.build(name: "EnumPropertyOtherEntityTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .getProperty(entity, key, varName) = script.instructions[0] {
            XCTAssertEqual(entity, "Player")
            XCTAssertEqual(key, "position")
            XCTAssertEqual(varName, "playerPos")
        } else {
            XCTFail("Expected getProperty instruction for other entity")
        }
    }

    // MARK: - Enum-based SetProperty Builder Tests

    func testSetPropertyFloatUsingEnum() {
        let builder = USCBuilder()
        builder.setProperty(.mass, to: 5.0)

        let script = builder.build(name: "EnumSetPropertyFloatTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .setProperty(entity, key, value) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "mass")

            if case let .float(mass) = value {
                XCTAssertEqual(mass, 5.0)
            } else {
                XCTFail("Expected float value for mass")
            }
        } else {
            XCTFail("Expected setProperty instruction")
        }
    }

    func testSetPropertyVec3UsingEnum() {
        let builder = USCBuilder()
        let color = Vec3(x: 1.0, y: 0.5, z: 0.25)
        builder.setProperty(.color, to: color)

        let script = builder.build(name: "EnumSetPropertyVec3Test")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .setProperty(entity, key, value) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "color")

            if case let .vec3(x, y, z) = value {
                XCTAssertEqual(x, 1.0)
                XCTAssertEqual(y, 0.5)
                XCTAssertEqual(z, 0.25)
            } else {
                XCTFail("Expected vec3 value for color")
            }
        } else {
            XCTFail("Expected setProperty instruction")
        }
    }

    func testSetPropertyVariableUsingEnum() {
        let builder = USCBuilder()
        builder.setProperty(.velocity, toVariable: "newVel")

        let script = builder.build(name: "EnumSetPropertyVariableTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .setProperty(entity, key, value) = script.instructions[0] {
            XCTAssertEqual(entity, "self")
            XCTAssertEqual(key, "velocity")

            if case let .variableRef(varName) = value {
                XCTAssertEqual(varName, "newVel")
            } else {
                XCTFail("Expected variableRef value for velocity")
            }
        } else {
            XCTFail("Expected setProperty instruction")
        }
    }

    func testSetPropertyOfOtherEntityUsingEnum() {
        let builder = USCBuilder()
        builder.setProperty(of: "Light1", .intensity, toVariable: "intensityVar")

        let script = builder.build(name: "EnumSetPropertyOtherEntityTest")

        XCTAssertEqual(script.instructions.count, 1)

        if case let .setProperty(entity, key, value) = script.instructions[0] {
            XCTAssertEqual(entity, "Light1")
            XCTAssertEqual(key, "intensity")

            if case let .variableRef(varName) = value {
                XCTAssertEqual(varName, "intensityVar")
            } else {
                XCTFail("Expected variableRef value for intensity")
            }
        } else {
            XCTFail("Expected setProperty instruction")
        }
    }

}
