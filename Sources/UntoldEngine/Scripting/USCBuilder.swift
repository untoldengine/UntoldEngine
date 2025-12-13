//
//  USCBuilder.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - Builder DSL
//  Swift API for building USC scripts programmatically.
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// This file was jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import Foundation
import simd

/// Fluent builder for creating USCScripts in Swift
public final class USCBuilder {
    private var instructions: [USCInstruction] = []

    public init() {}

    // MARK: - Events

    @discardableResult
    public func onStart() -> USCBuilder {
        instructions.append(.event("OnStart"))
        return self
    }

    @discardableResult
    public func onUpdate() -> USCBuilder {
        instructions.append(.event("OnUpdate"))
        return self
    }

    @discardableResult
    public func onCollision(tag: String? = nil) -> USCBuilder {
        let name = tag.map { "OnCollision:\($0)" } ?? "OnCollision"
        instructions.append(.event(name))
        return self
    }

    @discardableResult
    public func onEvent(_ name: String) -> USCBuilder {
        instructions.append(.event(name))
        return self
    }

    // MARK: - Flow control

    @discardableResult
    public func ifLess(_ property: String, than value: Float, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: property, as: property))
        instructions.append(.ifCondition(.init(lhs: .variableRef(property), op: .less, rhs: .float(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    @discardableResult
    public func ifGreater(_ property: String, than value: Float, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: property, as: property))
        instructions.append(.ifCondition(.init(left: .variableRef(property), comparison: .greater, right: .float(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    @discardableResult
    public func ifEqual(_ property: String, to value: Float, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: property, as: property))
        instructions.append(.ifCondition(.init(left: .variableRef(property), comparison: .equal, right: .float(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    /// Convenience bool comparison for variables/flags: use when comparing a bool variable to a literal.
    @discardableResult
    public func ifEqual(_ variable: String, to value: Bool, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.ifCondition(.init(left: .variableRef(variable),
                                               comparison: .equal,
                                               right: .bool(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    /// Generic conditional using explicit operands/op
    @discardableResult
    public func ifCondition(lhs: Value, _ op: CompareOp, rhs: Value, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.ifCondition(.init(left: lhs, comparison: op, right: rhs)))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    /// Group math/transform steps for readability.
    @discardableResult
    public func math(_ block: (USCBuilder) -> Void) -> USCBuilder {
        block(self)
        return self
    }

    /// Else block - must follow an if statement
    @discardableResult
    public func `else`(do block: (USCBuilder) -> Void) -> USCBuilder {
        // Replace the last endIf with an else block
        if case .endIf = instructions.last {
            instructions.removeLast()
            instructions.append(.elseBlock)
            let nested = USCBuilder()
            block(nested)
            instructions.append(contentsOf: nested.instructions)
            instructions.append(.endIf)
        }
        return self
    }

    /// Else-if helper: syntactic sugar for else { ifCondition(...) { ... } }
    @discardableResult
    public func elseIf(lhs: Value,
                       _ op: CompareOp,
                       rhs: Value,
                       do block: (USCBuilder) -> Void) -> USCBuilder
    {
        // Replace the trailing endIf with an else + nested if
        if case .endIf = instructions.last {
            instructions.removeLast()
            instructions.append(.elseBlock)

            // Nested if
            instructions.append(.ifCondition(.init(left: lhs, comparison: op, right: rhs)))
            let nested = USCBuilder()
            block(nested)
            instructions.append(contentsOf: nested.instructions)
            instructions.append(.endIf) // close nested if

            instructions.append(.endIf) // close outer if
        }
        return self
    }

    /*
     @discardableResult
     public func wait(_ seconds: Float) -> USCBuilder {
         instructions.append(.delay(seconds: seconds))
         return self
     }

     @discardableResult
     public func loop(_ times: Int, do block: (USCBuilder) -> Void) -> USCBuilder {
         instructions.append(.loop(iterations: times))
         let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
         instructions.append(.endLoop)
         return self
     }
      */

    // MARK: - MATH

    @discardableResult
    public func addFloat(_ lhsVar: String,
                         _ rhsVar: String,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .addFloat(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func addFloat(_ lhsVar: String,
                         literal rhsValue: Float,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .addFloatLiteral(lhs: lhsVar, rhs: rhsValue),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func subtractFloat(_ lhsVar: String,
                              _ rhsVar: String,
                              as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .subFloat(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func subtractFloat(_ lhsVar: String,
                              literal rhsValue: Float,
                              as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .subFloatLiteral(lhs: lhsVar, rhs: rhsValue),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func mulFloat(_ lhsVar: String,
                         _ rhsVar: String,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .mulFloat(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func mulFloat(_ lhsVar: String,
                         literal rhsValue: Float,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .mulFloatLiteral(lhs: lhsVar, rhs: rhsValue),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func divFloat(_ lhsVar: String,
                         _ rhsVar: String,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .divFloat(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func divFloat(_ lhsVar: String,
                         literal rhsValue: Float,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .divFloatLiteral(lhs: lhsVar, rhs: rhsValue),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func addVec3(_ lhsVar: String,
                        _ rhsVar: String,
                        as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .addVec3(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func scaleVec3(_ vecVar: String,
                          by scalarVar: String,
                          as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .scaleVec3(vec: vecVar, scalarVar: scalarVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func scaleVec3(_ vecVar: String,
                          literal scalar: Float,
                          as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .scaleVec3Literal(vec: vecVar, scalar: scalar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func lengthVec3(_ vecVar: String,
                           as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .lengthVec3(vec: vecVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func normalizeVec3(_ vecVar: String,
                              as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .normalizeVec3(vec: vecVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func dotVec3(_ lhsVar: String,
                        _ rhsVar: String,
                        as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .dotVec3(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func crossVec3(_ lhsVar: String,
                          _ rhsVar: String,
                          as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .crossVec3(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    /// Linear interpolation between two vectors: (1 - t) * from + t * to
    @discardableResult
    public func lerpVec3(from: String,
                         to: String,
                         t: String,
                         as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .lerpVec3(from: from, to: to, t: t),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    // MARK: - Boolean Operations

    @discardableResult
    public func orBool(_ lhsVar: String,
                       _ rhsVar: String,
                       as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .orBool(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func andBool(_ lhsVar: String,
                        _ rhsVar: String,
                        as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .andBool(lhs: lhsVar, rhs: rhsVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    @discardableResult
    public func notBool(_ operandVar: String,
                        as outputVar: String) -> USCBuilder
    {
        let inst = MathInstruction(op: .notBool(operand: operandVar),
                                   output: outputVar)
        instructions.append(.math(inst))
        return self
    }

    // Action

    @discardableResult
    public func callAction(_ name: String,
                           args: [String] = [],
                           result: String? = nil) -> USCBuilder
    {
        instructions.append(.callAction(name: name, args: args, result: result))
        return self
    }

    // MARK: - INPUT

    @discardableResult
    public func ifKeyPressed(_ key: String, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.ifInput(.keyPressed(key)))
        let nested = USCBuilder()
        block(nested)
        instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    @discardableResult
    public func ifKeyReleased(_ key: String, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.ifInput(.keyReleased(key)))
        let nested = USCBuilder()
        block(nested)
        instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    @discardableResult
    public func getKeyState(_ key: String, as variableName: String) -> USCBuilder {
        instructions.append(.getKeyState(key: key, as: variableName))
        return self
    }

    // MARK: - Transform

    @discardableResult
    public func translateTo(x: Float, y: Float, z: Float) -> USCBuilder {
        instructions.append(.translateTo(entity: "self", position: simd_float3(x, y, z)))
        return self
    }

    @discardableResult
    public func translateTo(_ v: simd_float3) -> USCBuilder {
        instructions.append(.translateTo(entity: "self", position: v))
        return self
    }

    @discardableResult
    public func translateBy(x: Float, y: Float, z: Float) -> USCBuilder {
        instructions.append(.translateBy(entity: "self", position: simd_float3(x, y, z)))
        return self
    }

    @discardableResult
    public func translateBy(_ v: simd_float3) -> USCBuilder {
        instructions.append(.translateBy(entity: "self", position: v))
        return self
    }

    @discardableResult
    public func rotateTo(degrees: Float, axis: simd_float3) -> USCBuilder {
        instructions.append(.rotateTo(entity: "self", degrees: .float(degrees), axis: axis))
        return self
    }

    @discardableResult
    public func rotateTo(degrees: Value, axis: simd_float3) -> USCBuilder {
        instructions.append(.rotateTo(entity: "self", degrees: degrees, axis: axis))
        return self
    }

    @discardableResult
    public func rotateBy(degrees: Float, axis: simd_float3) -> USCBuilder {
        instructions.append(.rotateBy(entity: "self", degrees: .float(degrees), axis: axis))
        return self
    }

    @discardableResult
    public func rotateBy(degrees: Value, axis: simd_float3) -> USCBuilder {
        instructions.append(.rotateBy(entity: "self", degrees: degrees, axis: axis))
        return self
    }

    @discardableResult
    public func lookAt(_ targetEntityName: String) -> USCBuilder {
        instructions.append(.lookAt(entity: "self", target: targetEntityName))
        return self
    }

    // MARK: - Animation

    @discardableResult
    public func playAnimation(_ name: String, loop: Bool = true) -> USCBuilder {
        instructions.append(.playAnimation(entity: "self", name: name, loop: loop))
        return self
    }

    @discardableResult
    public func stopAnimation() -> USCBuilder {
        instructions.append(.stopAnimation(entity: "self"))
        return self
    }

    // MARK: - Camera

    // Direct camera movement without ScriptAction.
    @discardableResult
    public func cameraMoveTo(_ position: simd_float3) -> USCBuilder {
        instructions.append(.cameraMoveTo(entity: "self",
                                          position: .vec3(x: position.x, y: position.y, z: position.z)))
        return self
    }

    @discardableResult
    public func cameraMoveTo(_ position: Value) -> USCBuilder {
        instructions.append(.cameraMoveTo(entity: "self", position: position))
        return self
    }

    // MARK: - Physics

    @discardableResult
    public func applyForce(force: simd_float3) -> USCBuilder {
        instructions.append(.applyForce(entity: "self", force: .vec3(x: force.x, y: force.y, z: force.z)))
        return self
    }

    @discardableResult
    public func applyForce(force: Value) -> USCBuilder {
        instructions.append(.applyForce(entity: "self", force: force))
        return self
    }

    @discardableResult
    public func applyMoment(force: simd_float3, at point: simd_float3) -> USCBuilder {
        instructions.append(.applyMoment(entity: "self", force: force, at: point))
        return self
    }

    @discardableResult
    public func clearVelocity() -> USCBuilder {
        instructions.append(.clearVelocity(entity: "self"))
        return self
    }

    @discardableResult
    public func clearAngularVelocity() -> USCBuilder {
        instructions.append(.clearAngularVelocity(entity: "self"))
        return self
    }

    @discardableResult
    public func clearForces() -> USCBuilder {
        instructions.append(.clearForces(entity: "self"))
        return self
    }

    @discardableResult
    public func pausePhysicsComponent(isPaused: Bool) -> USCBuilder {
        instructions.append(.pausePhysicsComponent(entity: "self", isPaused: isPaused))
        return self
    }

    @discardableResult
    public func setGravityScale(_ scale: Float) -> USCBuilder {
        instructions.append(.setGravityScale(entity: "self", scale: scale))
        return self
    }

    // MARK: - Properties

    @discardableResult
    public func getProperty(_ key: String, as variableName: String) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: key, as: variableName))
        return self
    }

    @discardableResult
    public func getProperty(of entityName: String,
                            _ key: String,
                            as variableName: String) -> USCBuilder
    {
        instructions.append(.getProperty(entity: entityName, key: key, as: variableName))
        return self
    }

    // MARK: - Properties (enum-based convenience)

    @discardableResult
    public func getProperty(_ key: ScriptProperty,
                            as variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.getProperty(entity: "self", key: keyPath, as: variableName))
        return self
    }

    @discardableResult
    public func getProperty(_ key: ScriptProperty,
                            axis: ScriptAxis,
                            as variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath(axis: axis)
        instructions.append(.getProperty(entity: "self", key: keyPath, as: variableName))
        return self
    }

    @discardableResult
    public func getProperty(of entityName: String,
                            _ key: ScriptProperty,
                            as variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.getProperty(entity: entityName, key: keyPath, as: variableName))
        return self
    }

    @discardableResult
    public func getProperty(of entityName: String,
                            _ key: ScriptProperty,
                            axis: ScriptAxis,
                            as variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath(axis: axis)
        instructions.append(.getProperty(entity: entityName, key: keyPath, as: variableName))
        return self
    }

    @discardableResult
    public func setProperty(_ key: String, to value: Float) -> USCBuilder {
        instructions.append(.setProperty(entity: "self", key: key, value: .float(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: String, to value: Bool) -> USCBuilder {
        instructions.append(.setProperty(entity: "self", key: key, value: .bool(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: String, to value: String) -> USCBuilder {
        instructions.append(.setProperty(entity: "self", key: key, value: .string(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: String, to value: simd_float3) -> USCBuilder {
        instructions.append(.setProperty(entity: "self", key: key, value: .vec3(x: value.x, y: value.y, z: value.z)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: String,
                            toVariable variableName: String) -> USCBuilder
    {
        instructions.append(
            .setProperty(
                entity: "self",
                key: key,
                value: .variableRef(variableName)
            )
        )
        return self
    }

    @discardableResult
    public func setProperty(of entityName: String,
                            _ key: String,
                            toVariable variableName: String) -> USCBuilder
    {
        instructions.append(
            .setProperty(
                entity: entityName,
                key: key,
                value: .variableRef(variableName)
            )
        )
        return self
    }

    @discardableResult
    public func setProperty(_ key: ScriptProperty,
                            to value: Float) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.setProperty(entity: "self", key: keyPath, value: .float(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: ScriptProperty,
                            to value: Bool) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.setProperty(entity: "self", key: keyPath, value: .bool(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: ScriptProperty,
                            to value: String) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.setProperty(entity: "self", key: keyPath, value: .string(value)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: ScriptProperty,
                            to value: simd_float3) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(.setProperty(entity: "self", key: keyPath,
                                         value: .vec3(x: value.x, y: value.y, z: value.z)))
        return self
    }

    @discardableResult
    public func setProperty(_ key: ScriptProperty,
                            toVariable variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(
            .setProperty(
                entity: "self",
                key: keyPath,
                value: .variableRef(variableName)
            )
        )
        return self
    }

    @discardableResult
    public func setProperty(of entityName: String,
                            _ key: ScriptProperty,
                            toVariable variableName: String) -> USCBuilder
    {
        let keyPath = key.keyPath()
        instructions.append(
            .setProperty(
                entity: entityName,
                key: keyPath,
                value: .variableRef(variableName)
            )
        )
        return self
    }

    // MARK: - Variables

    /// Set a variable to a literal float value
    @discardableResult
    public func setVariable(_ name: String, to value: Float) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: .float(value)))
        return self
    }

    /// Set a variable to a literal vec3 value
    @discardableResult
    public func setVariable(_ name: String, to value: simd_float3) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: .vec3(x: value.x, y: value.y, z: value.z)))
        return self
    }

    /// Set a variable to a literal string value
    @discardableResult
    public func setVariable(_ name: String, to value: String) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: .string(value)))
        return self
    }

    /// Set a variable to a literal bool value
    @discardableResult
    public func setVariable(_ name: String, to value: Bool) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: .bool(value)))
        return self
    }

    @discardableResult
    public func setVariable(_ name: String, fromVariable other: String) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: .variableRef(other)))
        return self
    }

    @discardableResult
    public func setVariable(_ name: String, to value: Value) -> USCBuilder {
        instructions.append(.setVariable(name: name, value: value))
        return self
    }

    // MARK: - Conditions

    @discardableResult
    public func log(_ message: String) -> USCBuilder {
        instructions.append(.log(message))
        return self
    }

    /// Log a value (literal or variableRef) with a label.
    @discardableResult
    public func log(_ name: String, value: Value) -> USCBuilder {
        instructions.append(.logValue(name: name, value: value))
        return self
    }

    /// Convenience: log the value of a variable by name.
    @discardableResult
    public func logVariable(_ variableName: String) -> USCBuilder {
        instructions.append(.logValue(name: variableName, value: .variableRef(variableName)))
        return self
    }

    // MARK: - Build / Export

    public func build(name: String, triggerType: TriggerType = .perFrame, executionMode: ExecutionMode = .auto) -> USCScript {
        USCScript(name: name, instructions: instructions, metadata: .init(triggerType: triggerType, executionMode: executionMode))
    }

    public func export(name: String, to url: URL, triggerType: TriggerType = .perFrame, executionMode: ExecutionMode = .auto) throws {
        try saveUSCScript(build(name: name, triggerType: triggerType, executionMode: executionMode), to: url)
    }
}

// MARK: - Convenience constructors

/// Build a script using a closure-based DSL
public func buildScript(name: String, triggerType: TriggerType = .perFrame, executionMode: ExecutionMode = .auto, _ builder: (USCBuilder) -> Void) -> USCScript {
    let b = USCBuilder(); builder(b); return b.build(name: name, triggerType: triggerType, executionMode: executionMode)
}

/// Build and export a script to JSON (.uscript)
public func exportScript(name: String, to url: URL, triggerType: TriggerType = .perFrame, executionMode: ExecutionMode = .auto, _ builder: (USCBuilder) -> Void) throws {
    let b = USCBuilder(); builder(b); try b.export(name: name, to: url, triggerType: triggerType, executionMode: executionMode)
}

public extension USCBuilder {
    @discardableResult
    func cameraLookAt(eye: simd_float3,
                      target: simd_float3,
                      up: simd_float3 = .up) -> USCBuilder
    {
        instructions.append(.cameraLookAt(entity: "self",
                                          eye: .vec3(x: eye.x, y: eye.y, z: eye.z),
                                          target: .vec3(x: target.x, y: target.y, z: target.z),
                                          up: .vec3(x: up.x, y: up.y, z: up.z)))
        return self
    }

    @discardableResult
    func cameraLookAt(eye: Value,
                      target: Value,
                      up: Value) -> USCBuilder
    {
        instructions.append(.cameraLookAt(entity: "self",
                                          eye: eye,
                                          target: target,
                                          up: up))
        return self
    }

    @discardableResult
    func cameraMoveWithInput(speedVar: String,
                             deltaTimeVar: String,
                             wVar: String,
                             aVar: String,
                             sVar: String,
                             dVar: String,
                             qVar: String,
                             eVar: String) -> USCBuilder
    {
        instructions.append(
            .cameraMoveWithInput(entity: "self",
                                 speed: .variableRef(speedVar),
                                 deltaTime: .variableRef(deltaTimeVar),
                                 inputW: .variableRef(wVar),
                                 inputA: .variableRef(aVar),
                                 inputS: .variableRef(sVar),
                                 inputD: .variableRef(dVar),
                                 inputQ: .variableRef(qVar),
                                 inputE: .variableRef(eVar))
        )
        return self
    }
}

// MARK: - Camera/Physics/Steering Instruction Helpers

public extension USCBuilder {
    // Camera helpers
    @discardableResult
    func cameraMoveBy(_ offset: simd_float3) -> USCBuilder {
        instructions.append(.cameraMoveBy(entity: "self",
                                          offset: .vec3(x: offset.x, y: offset.y, z: offset.z)))
        return self
    }

    @discardableResult
    func cameraMoveBy(_ offset: Value) -> USCBuilder {
        instructions.append(.cameraMoveBy(entity: "self", offset: offset))
        return self
    }

    @discardableResult
    func cameraRotate(pitch: Value, yaw: Value, sensitivity: Value? = nil) -> USCBuilder {
        instructions.append(.cameraRotate(entity: "self",
                                          pitch: pitch,
                                          yaw: yaw,
                                          sensitivity: sensitivity))
        return self
    }

    @discardableResult
    func cameraFollow(target: Value,
                      offset: Value,
                      smoothFactor: Value? = nil,
                      deltaTime: Value? = nil) -> USCBuilder
    {
        instructions.append(.cameraFollow(entity: "self",
                                          targetEntity: target,
                                          offset: offset,
                                          smoothFactor: smoothFactor,
                                          deltaTime: deltaTime))
        return self
    }

    @discardableResult
    func cameraFollowLocal(target: Value,
                           localOffset: Value,
                           smoothFactor: Value? = nil,
                           deltaTime: Value? = nil) -> USCBuilder
    {
        instructions.append(.cameraFollowLocal(entity: "self",
                                               targetEntity: target,
                                               localOffset: localOffset,
                                               smoothFactor: smoothFactor,
                                               deltaTime: deltaTime))
        return self
    }

    @discardableResult
    func cameraOrbitTarget(target: Value,
                           radius: Value,
                           speed: Value,
                           deltaTime: Value,
                           offsetY: Value? = nil) -> USCBuilder
    {
        instructions.append(.cameraOrbitTarget(entity: "self",
                                               targetEntity: target,
                                               radius: radius,
                                               speed: speed,
                                               deltaTime: deltaTime,
                                               offsetY: offsetY))
        return self
    }

    // Physics helpers (instruction-based)
    @discardableResult
    func applyLinearImpulse(direction: Value, magnitude: Value) -> USCBuilder {
        instructions.append(.applyLinearImpulse(entity: "self",
                                                direction: direction,
                                                magnitude: magnitude))
        return self
    }

    @discardableResult
    func applyLinearImpulse(direction: simd_float3, magnitude: Float) -> USCBuilder {
        applyLinearImpulse(direction: .vec3(x: direction.x, y: direction.y, z: direction.z),
                           magnitude: .float(magnitude))
    }

    @discardableResult
    func applyWorldForce(direction: Value, magnitude: Value) -> USCBuilder {
        instructions.append(.applyWorldForce(entity: "self",
                                             direction: direction,
                                             magnitude: magnitude))
        return self
    }

    @discardableResult
    func applyWorldForce(direction: simd_float3, magnitude: Float) -> USCBuilder {
        applyWorldForce(direction: .vec3(x: direction.x, y: direction.y, z: direction.z),
                        magnitude: .float(magnitude))
    }

    @discardableResult
    func setLinearVelocity(_ velocity: Value) -> USCBuilder {
        instructions.append(.setLinearVelocity(entity: "self", velocity: velocity))
        return self
    }

    @discardableResult
    func addLinearVelocity(_ deltaVelocity: Value) -> USCBuilder {
        instructions.append(.addLinearVelocity(entity: "self", deltaVelocity: deltaVelocity))
        return self
    }

    @discardableResult
    func clampLinearSpeed(min: Value, max: Value) -> USCBuilder {
        instructions.append(.clampLinearSpeed(entity: "self", minSpeed: min, maxSpeed: max))
        return self
    }

    @discardableResult
    func applyLinearDamping(damping: Value, deltaTime: Value) -> USCBuilder {
        instructions.append(.applyLinearDamping(entity: "self",
                                                damping: damping,
                                                deltaTime: deltaTime))
        return self
    }

    @discardableResult
    func applyAngularImpulse(axis: Value, magnitude: Value) -> USCBuilder {
        instructions.append(.applyAngularImpulse(entity: "self", axis: axis, magnitude: magnitude))
        return self
    }

    @discardableResult
    func setAngularVelocity(_ angularVelocity: Value) -> USCBuilder {
        instructions.append(.setAngularVelocity(entity: "self", angularVelocity: angularVelocity))
        return self
    }

    @discardableResult
    func clampAngularSpeed(max: Value) -> USCBuilder {
        instructions.append(.clampAngularSpeed(entity: "self", maxAngularSpeed: max))
        return self
    }

    @discardableResult
    func applyAngularDamping(damping: Value, deltaTime: Value) -> USCBuilder {
        instructions.append(.applyAngularDamping(entity: "self",
                                                 damping: damping,
                                                 deltaTime: deltaTime))
        return self
    }

    // Steering (returning Vec3 into result variable if provided)
    @discardableResult
    func seek(targetPosition: Value, maxSpeed: Value, result: String? = nil) -> USCBuilder {
        instructions.append(.seek(entity: "self",
                                  targetPosition: targetPosition,
                                  maxSpeed: maxSpeed,
                                  result: result))
        return self
    }

    @discardableResult
    func flee(threatPosition: Value, maxSpeed: Value, result: String? = nil) -> USCBuilder {
        instructions.append(.flee(entity: "self",
                                  threatPosition: threatPosition,
                                  maxSpeed: maxSpeed,
                                  result: result))
        return self
    }

    @discardableResult
    func arrive(targetPosition: Value, maxSpeed: Value, slowingRadius: Value, result: String? = nil) -> USCBuilder {
        instructions.append(.arrive(entity: "self",
                                    targetPosition: targetPosition,
                                    maxSpeed: maxSpeed,
                                    slowingRadius: slowingRadius,
                                    result: result))
        return self
    }

    @discardableResult
    func pursuit(targetEntity: Value, maxSpeed: Value, result: String? = nil) -> USCBuilder {
        instructions.append(.pursuit(entity: "self",
                                     targetEntity: targetEntity,
                                     maxSpeed: maxSpeed,
                                     result: result))
        return self
    }

    @discardableResult
    func evade(threatEntity: Value, maxSpeed: Value, result: String? = nil) -> USCBuilder {
        instructions.append(.evade(entity: "self",
                                   threatEntity: threatEntity,
                                   maxSpeed: maxSpeed,
                                   result: result))
        return self
    }

    @discardableResult
    func steerSeek(targetPosition: Value,
                   maxSpeed: Value,
                   deltaTime: Value,
                   turnSpeed: Value? = nil,
                   weight: Value? = nil) -> USCBuilder
    {
        instructions.append(.steerSeek(entity: "self",
                                       targetPosition: targetPosition,
                                       maxSpeed: maxSpeed,
                                       deltaTime: deltaTime,
                                       turnSpeed: turnSpeed,
                                       weight: weight))
        return self
    }

    @discardableResult
    func steerArrive(targetPosition: Value,
                     maxSpeed: Value,
                     slowingRadius: Value,
                     deltaTime: Value,
                     turnSpeed: Value? = nil) -> USCBuilder
    {
        instructions.append(.steerArrive(entity: "self",
                                         targetPosition: targetPosition,
                                         maxSpeed: maxSpeed,
                                         slowingRadius: slowingRadius,
                                         deltaTime: deltaTime,
                                         turnSpeed: turnSpeed))
        return self
    }

    @discardableResult
    func steerFlee(threatPosition: Value,
                   maxSpeed: Value,
                   deltaTime: Value,
                   turnSpeed: Value? = nil) -> USCBuilder
    {
        instructions.append(.steerFlee(entity: "self",
                                       threatPosition: threatPosition,
                                       maxSpeed: maxSpeed,
                                       deltaTime: deltaTime,
                                       turnSpeed: turnSpeed))
        return self
    }

    @discardableResult
    func steerPursuit(targetEntity: Value,
                      maxSpeed: Value,
                      deltaTime: Value,
                      turnSpeed: Value? = nil) -> USCBuilder
    {
        instructions.append(.steerPursuit(entity: "self",
                                          targetEntity: targetEntity,
                                          maxSpeed: maxSpeed,
                                          deltaTime: deltaTime,
                                          turnSpeed: turnSpeed))
        return self
    }

    @discardableResult
    func orbit(centerPosition: Value,
               radius: Value,
               maxSpeed: Value,
               deltaTime: Value,
               turnSpeed: Value? = nil) -> USCBuilder
    {
        instructions.append(.orbit(entity: "self",
                                   centerPosition: centerPosition,
                                   radius: radius,
                                   maxSpeed: maxSpeed,
                                   deltaTime: deltaTime,
                                   turnSpeed: turnSpeed))
        return self
    }
}
