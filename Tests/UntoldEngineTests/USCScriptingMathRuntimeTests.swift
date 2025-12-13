//
//  USCScriptingMathRuntimeTests.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class USCScriptingMathRuntimeTests: XCTestCase {
    override func setUp() {
        super.setUp()
        initScriptingSystem()
    }

    override func tearDown() {
        destroyAllEntities()
        super.tearDown()
    }

    // MARK: - addFloat (var, var)

    func testAddFloat_VarVar_Runtime() {
        let script = buildScript(name: "AddFloatVarVar") { s in
            s.addFloat("a", "b", as: "sum")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["a"] = .float(2.0)
        context.variables["b"] = .float(3.5)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(sum) = context.variables["sum"] else {
            return XCTFail("sum should be a float")
        }

        XCTAssertEqual(sum, 5.5, accuracy: 0.0001)
    }

    // MARK: - addFloat (var, literal)

    func testAddFloat_VarLiteral_Runtime() {
        let script = buildScript(name: "AddFloatVarLiteral") { s in
            s.addFloat("base", literal: 1.5, as: "result")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["base"] = .float(4.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(result) = context.variables["result"] else {
            return XCTFail("result should be a float")
        }

        XCTAssertEqual(result, 5.5, accuracy: 0.0001)
    }

    // MARK: - mulFloat (var, var)

    func testMulFloat_VarVar_Runtime() {
        let script = buildScript(name: "MulFloatVarVar") { s in
            s.mulFloat("x", "y", as: "product")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["x"] = .float(2.0)
        context.variables["y"] = .float(3.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(product) = context.variables["product"] else {
            return XCTFail("product should be a float")
        }

        XCTAssertEqual(product, 6.0, accuracy: 0.0001)
    }

    // MARK: - mulFloat (var, literal)

    func testMulFloat_VarLiteral_Runtime() {
        let script = buildScript(name: "MulFloatVarLiteral") { s in
            s.mulFloat("speed", literal: 2.5, as: "scaledSpeed")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["speed"] = .float(4.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(scaled) = context.variables["scaledSpeed"] else {
            return XCTFail("scaledSpeed should be a float")
        }

        XCTAssertEqual(scaled, 10.0, accuracy: 0.0001)
    }

    // MARK: - addVec3 (var, var)

    func testAddVec3_VarVar_Runtime() {
        let script = buildScript(name: "AddVec3VarVar") { s in
            s.addVec3("v1", "v2", as: "sum")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["v1"] = .vec3(x: 1.0, y: 2.0, z: 3.0)
        context.variables["v2"] = .vec3(x: -1.0, y: 0.5, z: 4.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["sum"] else {
            return XCTFail("sum should be a vec3")
        }

        XCTAssertEqual(x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(y, 2.5, accuracy: 0.0001)
        XCTAssertEqual(z, 7.0, accuracy: 0.0001)
    }

    // MARK: - scaleVec3 (vecVar, scalarVar)

    func testScaleVec3_VarScalarVar_Runtime() {
        let script = buildScript(name: "ScaleVec3VarScalarVar") { s in
            s.scaleVec3("dir", by: "scalar", as: "scaled")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["dir"] = .vec3(x: 1.0, y: 0.0, z: -1.0)
        context.variables["scalar"] = .float(2.5)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["scaled"] else {
            return XCTFail("scaled should be a vec3")
        }

        XCTAssertEqual(x, 2.5, accuracy: 0.0001)
        XCTAssertEqual(y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(z, -2.5, accuracy: 0.0001)
    }

    // MARK: - scaleVec3 (vecVar, literal)

    func testScaleVec3_VarLiteral_Runtime() {
        let script = buildScript(name: "ScaleVec3VarLiteral") { s in
            s.scaleVec3("dir", literal: 3.0, as: "scaled")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["dir"] = .vec3(x: 0.5, y: 1.0, z: -2.0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["scaled"] else {
            return XCTFail("scaled should be a vec3")
        }

        XCTAssertEqual(x, 1.5, accuracy: 0.0001)
        XCTAssertEqual(y, 3.0, accuracy: 0.0001)
        XCTAssertEqual(z, -6.0, accuracy: 0.0001)
    }

    // MARK: - lengthVec3

    func testLengthVec3_Runtime() {
        let script = buildScript(name: "LengthVec3") { s in
            s.lengthVec3("v", as: "len")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        context.variables["v"] = .vec3(x: 3.0, y: 4.0, z: 0.0) // length = 5

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(len) = context.variables["len"] else {
            return XCTFail("len should be a float")
        }

        XCTAssertEqual(len, 5.0, accuracy: 0.0001)
    }

    // MARK: - normalizeVec3

    func testNormalizeVec3_Runtime() {
        let script = buildScript(name: "NormalizeVec3") { s in
            s.normalizeVec3("v", as: "unit")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        context.variables["v"] = .vec3(x: 0, y: 3, z: 4) // length 5

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["unit"] else {
            return XCTFail("unit should be a vec3")
        }
        XCTAssertEqual(x, 0, accuracy: 0.0001)
        XCTAssertEqual(y, 0.6, accuracy: 0.0001)
        XCTAssertEqual(z, 0.8, accuracy: 0.0001)
    }

    func testDotVec3_Runtime() {
        let script = buildScript(name: "DotVec3") { s in
            s.dotVec3("a", "b", as: "dot")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        context.variables["a"] = .vec3(x: 1, y: 2, z: 3)
        context.variables["b"] = .vec3(x: 4, y: -2, z: 0.5)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(dot) = context.variables["dot"] else {
            return XCTFail("dot should be a float")
        }
        // Use consistent Double literals to avoid slow type-checking
        let expected: Double = (1.0 * 4.0) + (2.0 * -2.0) + (3.0 * 0.5)
        XCTAssertEqual(Double(dot), expected, accuracy: 0.0001)
    }

    func testCrossVec3_Runtime() {
        let script = buildScript(name: "CrossVec3") { s in
            s.crossVec3("a", "b", as: "cross")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        context.variables["a"] = .vec3(x: 1, y: 0, z: 0)
        context.variables["b"] = .vec3(x: 0, y: 1, z: 0)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["cross"] else {
            return XCTFail("cross should be a vec3")
        }
        XCTAssertEqual(x, 0, accuracy: 0.0001)
        XCTAssertEqual(y, 0, accuracy: 0.0001)
        XCTAssertEqual(z, 1, accuracy: 0.0001)
    }

    func testLerpVec3_Runtime() {
        let script = buildScript(name: "LerpVec3") { s in
            s.lerpVec3(from: "a", to: "b", t: "t", as: "lerped")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        context.variables["a"] = .vec3(x: 0, y: 0, z: 0)
        context.variables["b"] = .vec3(x: 10, y: 0, z: -10)
        context.variables["t"] = .float(0.25)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .vec3(x, y, z) = context.variables["lerped"] else {
            return XCTFail("lerped should be a vec3")
        }
        XCTAssertEqual(x, 2.5, accuracy: 0.0001)
        XCTAssertEqual(y, 0, accuracy: 0.0001)
        XCTAssertEqual(z, -2.5, accuracy: 0.0001)
    }

    // MARK: - math grouping helper

    func testMathBlock_GroupsInstructionsButExecutesSame() {
        let script = buildScript(name: "MathBlock") { s in
            s.math { m in
                m.getProperty(.velocity, as: "vel")
                m.lengthVec3("vel", as: "speed")
                m.ifGreater("speed", than: 10.0) { n in
                    n.normalizeVec3("vel", as: "dir")
                    n.scaleVec3("dir", literal: 10.0, as: "clamped")
                    n.setProperty(.velocity, toVariable: "clamped")
                }
            }
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)
        context.variables["velocity"] = .vec3(x: 0, y: 0, z: 12) // length = 12

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        // Should have been clamped to length 10 along same direction
        guard case let .vec3(x, y, z) = context.variables["velocity"] else {
            return XCTFail("velocity should be a vec3")
        }
        let length = simd_length(simd_float3(x, y, z))
        XCTAssertEqual(length, 10.0, accuracy: 0.0001)
    }

    // MARK: - setVariable + addFloat / mulFloat

    func testAddFloat_UsingSetVariableForInputs() {
        let script = buildScript(name: "AddFloatWithSetVariable") { s in
            s.setVariable("a", to: 2.0)
                .setVariable("b", to: 3.5)
                .addFloat("a", "b", as: "sum")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(sum) = context.variables["sum"] else {
            return XCTFail("sum should be a float")
        }

        XCTAssertEqual(sum, 5.5, accuracy: 0.0001)
    }

    func testMulFloat_UsingSetVariableForInputs() {
        let script = buildScript(name: "MulFloatWithSetVariable") { s in
            s.setVariable("x", to: 4.0)
                .setVariable("y", to: 1.5)
                .mulFloat("x", "y", as: "product")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(product) = context.variables["product"] else {
            return XCTFail("product should be a float")
        }

        XCTAssertEqual(product, 6.0, accuracy: 0.0001)
    }

    // MARK: - setVariable(... toVariable:) copy

    func testSetVariableCopiesFromAnotherVariable() {
        let script = buildScript(name: "CopyVariable") { s in
            s.setVariable("orig", to: 42.0)
                .mulFloat("orig", literal: 2.0, as: "tmp")
                .setVariable("answer", fromVariable: "tmp")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        guard case let .float(answer) = context.variables["answer"] else {
            return XCTFail("answer should be a float")
        }

        XCTAssertEqual(answer, 84.0, accuracy: 0.0001)
    }

    // MARK: - Vec3 pipeline with variables only

    func testVec3Math_UsingOnlyScriptVariables() {
        let script = buildScript(name: "Vec3Pipeline") { s in
            s.setVariable("v1", to: simd_float3(1.0, 2.0, 3.0))
                .setVariable("v2", to: simd_float3(-1.0, 0.0, 1.0))
                // sum = v1 + v2
                .addVec3("v1", "v2", as: "sum")
                // len = length(sum)
                .lengthVec3("sum", as: "len")
                // scaled = sum * 0.5
                .scaleVec3("sum", literal: 0.5, as: "scaled")
        }

        let entityId = createEntity()
        let context = USCContext(entityId: entityId, script: script)

        let interpreter = USCInterpreter()
        interpreter.execute(script: script, context: context)

        // sum = (0, 2, 4)
        guard case let .vec3(sx, sy, sz) = context.variables["sum"] else {
            return XCTFail("sum should be a vec3")
        }
        XCTAssertEqual(sx, 0.0, accuracy: 0.0001)
        XCTAssertEqual(sy, 2.0, accuracy: 0.0001)
        XCTAssertEqual(sz, 4.0, accuracy: 0.0001)

        // len = sqrt(0^2 + 2^2 + 4^2) = sqrt(20)
        guard case let .float(len) = context.variables["len"] else {
            return XCTFail("len should be a float")
        }
        XCTAssertEqual(len, sqrt(20.0), accuracy: 0.0001)

        // scaled = sum * 0.5 = (0, 1, 2)
        guard case let .vec3(cx, cy, cz) = context.variables["scaled"] else {
            return XCTFail("scaled should be a vec3")
        }
        XCTAssertEqual(cx, 0.0, accuracy: 0.0001)
        XCTAssertEqual(cy, 1.0, accuracy: 0.0001)
        XCTAssertEqual(cz, 2.0, accuracy: 0.0001)
    }
}
