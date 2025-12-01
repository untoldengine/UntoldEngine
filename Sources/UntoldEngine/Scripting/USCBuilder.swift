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
        instructions.append(.ifCondition(.init(lhs: .variableRef(property), op: .greater, rhs: .float(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    @discardableResult
    public func ifEqual(_ property: String, to value: Float, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: property, as: property))
        instructions.append(.ifCondition(.init(lhs: .variableRef(property), op: .equal, rhs: .float(value))))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
        return self
    }

    /// Generic conditional using explicit operands/op
    @discardableResult
    public func ifCondition(lhs: Value, _ op: CompareOp, rhs: Value, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.ifCondition(.init(lhs: lhs, op: op, rhs: rhs)))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        instructions.append(.endIf)
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

    // Action

    @discardableResult
    public func callAction(_ name: String,
                           args: [String] = [],
                           result: String? = nil) -> USCBuilder
    {
        instructions.append(.callAction(name: name, args: args, result: result))
        return self
    }

    @discardableResult
    public func callAction(_ action: ScriptActionName,
                           args: [String] = [],
                           result: String? = nil) -> USCBuilder
    {
        callAction(action.rawValue, args: args, result: result)
    }

    @discardableResult
    public func callAction(_ action: ScriptActionName,
                           args: [ScriptArgKey],
                           result: String? = nil) -> USCBuilder
    {
        let argNames = args.map(\.rawValue)
        return callAction(action.rawValue, args: argNames, result: result)
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

    // MARK: - Transform

    @discardableResult
    public func translateTo(x: Float, y: Float, z: Float) -> USCBuilder {
        instructions.append(.translateTo(entity: "self", position: .init(x: x, y: y, z: z)))
        return self
    }

    @discardableResult
    public func translateTo(_ v: Vec3) -> USCBuilder {
        instructions.append(.translateTo(entity: "self", position: v))
        return self
    }

    @discardableResult
    public func translateTo(_ v: simd_float3) -> USCBuilder {
        instructions.append(.translateTo(entity: "self", position: .init(x: v.x, y: v.y, z: v.z)))
        return self
    }

    @discardableResult
    public func translateBy(x: Float, y: Float, z: Float) -> USCBuilder {
        instructions.append(.translateBy(entity: "self", position: .init(x: x, y: y, z: z)))
        return self
    }

    @discardableResult
    public func translateBy(_ v: Vec3) -> USCBuilder {
        instructions.append(.translateBy(entity: "self", position: v))
        return self
    }

    @discardableResult
    public func translateBy(_ v: simd_float3) -> USCBuilder {
        instructions.append(.translateBy(entity: "self", position: .init(x: v.x, y: v.y, z: v.z)))
        return self
    }

    @discardableResult
    public func rotateTo(degrees: Float, axis: Vec3) -> USCBuilder {
        instructions.append(.rotateTo(entity: "self", degrees: .float(degrees), axis: axis))
        return self
    }

    @discardableResult
    public func rotateTo(degrees: Value, axis: Vec3) -> USCBuilder {
        instructions.append(.rotateTo(entity: "self", degrees: degrees, axis: axis))
        return self
    }

    @discardableResult
    public func rotateBy(degrees: Float, axis: Vec3) -> USCBuilder {
        instructions.append(.rotateBy(entity: "self", degrees: .float(degrees), axis: axis))
        return self
    }

    @discardableResult
    public func rotateBy(degrees: Value, axis: Vec3) -> USCBuilder {
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

    // MARK: - Physics

    @discardableResult
    public func applyForce(force: Vec3) -> USCBuilder {
        instructions.append(.applyForce(entity: "self", force: force))
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
    public func setProperty(_ key: String, to value: Vec3) -> USCBuilder {
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
                            to value: Vec3) -> USCBuilder
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
    public func setVariable(_ name: String, to value: Vec3) -> USCBuilder {
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
    func cameraLookAt(eye: Vec3,
                      target: Vec3,
                      up: Vec3 = .up) -> USCBuilder
    {
        setVariable("eye", to: eye)
        setVariable("target", to: target)
        setVariable("up", to: up)

        setVariable(ScriptArgKey.eye.rawValue, fromVariable: "eye")
        setVariable(ScriptArgKey.target.rawValue, fromVariable: "target")
        setVariable(ScriptArgKey.up.rawValue, fromVariable: "up")

        return callAction(.cameraLookAt,
                          args: [.eye, .target, .up])
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
        setVariable(ScriptArgKey.speed.rawValue, fromVariable: speedVar)
        setVariable(ScriptArgKey.deltaTime.rawValue, fromVariable: deltaTimeVar)

        setVariable(ScriptArgKey.inputW.rawValue, fromVariable: wVar)
        setVariable(ScriptArgKey.inputA.rawValue, fromVariable: aVar)
        setVariable(ScriptArgKey.inputS.rawValue, fromVariable: sVar)
        setVariable(ScriptArgKey.inputD.rawValue, fromVariable: dVar)
        setVariable(ScriptArgKey.inputQ.rawValue, fromVariable: qVar)
        setVariable(ScriptArgKey.inputE.rawValue, fromVariable: eVar)

        return callAction(.cameraMoveWithInput,
                          args: [.speed, .deltaTime,
                                 .inputW, .inputA, .inputS,
                                 .inputD, .inputQ, .inputE])
    }
}
