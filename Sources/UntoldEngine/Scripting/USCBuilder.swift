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

// This file were jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

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

    @discardableResult
    public func wait(_ seconds: Float) -> USCBuilder {
        instructions.append(.delay(seconds: seconds))
        return self
    }

    @discardableResult
    public func loop(_ times: Int, do block: (USCBuilder) -> Void) -> USCBuilder {
        instructions.append(.loop(iterations: times))
        let nested = USCBuilder(); block(nested); instructions.append(contentsOf: nested.instructions)
        return self
    }

    // MARK: - MATH

    /*
     In USC script, it would look like this:
     s.onUpdate()
         .getProperty("ball.motionAccumulator", as: "acc")
         .getProperty("ball.desiredVelocity", as: "input")
         .scaleVec3("acc", literal: 0.4, as: "accScaled")
         .scaleVec3("input", literal: 0.6, as: "inputScaled")
         .addVec3("accScaled", "inputScaled", as: "newAcc")
         .setProperty("ball.motionAccumulator", toVariable: "newAcc")
     */
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
    /*
     In USC script, it would look like this (see USCSripting for more examples):
     s.onUpdate()
      .getProperty("ball.desiredVelocity", as: "desiredVel")
      .getProperty("mass", as: "mass")
      .callAction("Ball.applyKick",
                  args: ["desiredVel", "mass"],
                  result: "newAcc")
      .setProperty("ball.motionAccumulator", toVariable: "newAcc")

     */

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
    public func rotateTo(degrees: Float, axis: Vec3) -> USCBuilder {
        instructions.append(.rotateTo(entity: "self", degrees: degrees, axis: axis))
        return self
    }

    @discardableResult
    public func rotateBy(degrees: Float, axis: Vec3) -> USCBuilder {
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

    @discardableResult
    public func setAnimationSpeed(_ speed: Float) -> USCBuilder {
        instructions.append(.setAnimationSpeed(entity: "self", speed: speed))
        return self
    }

    // MARK: - Physics

    @discardableResult
    public func applyForce(force: Vec3) -> USCBuilder {
        instructions.append(.applyForce(entity: "self", force: force))
        return self
    }

//    @discardableResult
//    public func applyUpwardForce(_ magnitude: Float) -> USCBuilder {
//        applyForce(direction: .init(x: 0, y: 1, z: 0), magnitude: magnitude)
//    }
//
//    @discardableResult
//    public func applyForwardForce(_ magnitude: Float) -> USCBuilder {
//        applyForce(direction: .init(x: 0, y: 0, z: -1), magnitude: magnitude)
//    }

    @discardableResult
    public func setVelocity(_ v: Vec3) -> USCBuilder {
        instructions.append(.setVelocity(entity: "self", velocity: v))
        return self
    }

    // MARK: - Properties

    /*
     // self
     .getProperty("position", as: "selfPos")
     */
    @discardableResult
    public func getProperty(_ key: String, as variableName: String) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: key, as: variableName))
        return self
    }

    /*
     // other entity
     .getProperty(of: "Player", "position", as: "playerPos")
     */
    @discardableResult
    public func getProperty(of entityName: String,
                            _ key: String,
                            as variableName: String) -> USCBuilder
    {
        instructions.append(.getProperty(entity: entityName, key: key, as: variableName))
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

    // MARK: - Debug

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
