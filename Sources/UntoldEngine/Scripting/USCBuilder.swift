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

import Foundation
import simd

/// Fluent builder for creating USCScripts in Swift
public final class USCBuilder {
    private var instructions: [USCInstruction] = []

    public init() {}

    // MARK: - Events
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

    // MARK: - Transform
    @discardableResult
    public func translate(x: Float, y: Float, z: Float) -> USCBuilder {
        instructions.append(.translate(entity: "self", offset: .init(x: x, y: y, z: z)))
        return self
    }

    @discardableResult
    public func translate(_ v: Vec3) -> USCBuilder {
        instructions.append(.translate(entity: "self", offset: v))
        return self
    }

    @discardableResult
    public func translate(_ v: simd_float3) -> USCBuilder {
        instructions.append(.translate(entity: "self", offset: .init(x: v.x, y: v.y, z: v.z)))
        return self
    }

    @discardableResult
    public func rotate(axis: Vec3, degrees: Float) -> USCBuilder {
        instructions.append(.rotate(entity: "self", axis: axis, degrees: degrees))
        return self
    }

    @discardableResult
    public func rotateX(_ degrees: Float) -> USCBuilder { rotate(axis: .init(x: 1, y: 0, z: 0), degrees: degrees) }
    @discardableResult
    public func rotateY(_ degrees: Float) -> USCBuilder { rotate(axis: .init(x: 0, y: 1, z: 0), degrees: degrees) }
    @discardableResult
    public func rotateZ(_ degrees: Float) -> USCBuilder { rotate(axis: .init(x: 0, y: 0, z: 1), degrees: degrees) }

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
    public func applyForce(direction: Vec3, magnitude: Float) -> USCBuilder {
        instructions.append(.applyForce(entity: "self", direction: direction, magnitude: magnitude))
        return self
    }

    @discardableResult
    public func applyUpwardForce(_ magnitude: Float) -> USCBuilder {
        applyForce(direction: .init(x: 0, y: 1, z: 0), magnitude: magnitude)
    }

    @discardableResult
    public func applyForwardForce(_ magnitude: Float) -> USCBuilder {
        applyForce(direction: .init(x: 0, y: 0, z: -1), magnitude: magnitude)
    }

    @discardableResult
    public func setVelocity(_ v: Vec3) -> USCBuilder {
        instructions.append(.setVelocity(entity: "self", velocity: v))
        return self
    }

    // MARK: - Properties
    @discardableResult
    public func getProperty(_ key: String, as variableName: String) -> USCBuilder {
        instructions.append(.getProperty(entity: "self", key: key, as: variableName))
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
