//
//  USCInstruction.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - Instruction Set Definition
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

// This file was jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import Foundation
import simd

public enum InputCondition: Codable {
    case keyPressed(String)
    case keyReleased(String)
}

public struct MathInstruction: Codable {
    public var op: MathOp
    public var output: String // variable name where result is stored

    public init(op: MathOp, output: String) {
        self.op = op
        self.output = output
    }
}

public enum MathOp: Codable {
    case addFloat(lhs: String, rhs: String) // variables
    case addFloatLiteral(lhs: String, rhs: Float) // var + literal
    case subFloat(lhs: String, rhs: String) // var - var
    case subFloatLiteral(lhs: String, rhs: Float) // var - literal
    case mulFloat(lhs: String, rhs: String)
    case mulFloatLiteral(lhs: String, rhs: Float)
    case divFloat(lhs: String, rhs: String) // var / var
    case divFloatLiteral(lhs: String, rhs: Float) // var / literal

    case addVec3(lhs: String, rhs: String)
    case scaleVec3(vec: String, scalarVar: String)
    case scaleVec3Literal(vec: String, scalar: Float)

    case lengthVec3(vec: String) // vec -> float
    case normalizeVec3(vec: String) // vec -> vec
    case dotVec3(lhs: String, rhs: String) // vec dot vec -> float
    case crossVec3(lhs: String, rhs: String) // vec x vec -> vec
    case lerpVec3(from: String, to: String, t: String) // vec lerp vec with float t
    case lerpFloat(from: String, to: String, t: String) // float lerp
    case reflectVec3(vec: String, normal: String) // reflect vec around normal
    case projectVec3(vec: String, onto: String) // project vec onto another vec
    case angleBetweenVec3(lhs: String, rhs: String) // returns degrees (float)
    case clampFloat(value: String, minVar: String?, maxVar: String?) // clamp float variable
    case clampVec3(value: String, minVar: String?, maxVar: String?) // component-wise clamp vec3 variable

    // Boolean operations
    case orBool(lhs: String, rhs: String) // bool || bool
    case andBool(lhs: String, rhs: String) // bool && bool
    case notBool(operand: String) // !bool
}

// MARK: - USC Instruction Set

/// Core USC instruction types
public enum USCInstruction: Codable {
    // Flow control
    case event(String) // OnUpdate, OnCollision:Tag, etc.
    case ifCondition(Condition) // Conditional branching
    case elseBlock // Else clause
    case endIf // Close if block
    case delay(seconds: Float) // Wait before next instruction
    case loop(iterations: Int) // Repeat N times
    case endLoop // Close loop block

    /// Math
    case math(MathInstruction)

    /// Action
    case callAction(name: String, args: [String], result: String?)

    // Input
    case ifInput(InputCondition)
    case getKeyState(key: String, as: String) // Query key state into bool variable

    // Entity operations
    case translateTo(entity: String, position: simd_float3)
    case translateBy(entity: String, position: simd_float3) // Move entity
    case rotateTo(entity: String, degrees: Value, axis: simd_float3) // Rotate entity (supports float or variableRef)
    case rotateBy(entity: String, degrees: Value, axis: simd_float3) // Rotate by entity (supports float or variableRef)
    case lookAt(entity: String, target: String) // Orient towards target

    // Animation
    // `transitionHalflife` is optional so scripts serialized before it
    // existed still decode; nil means the engine default.
    case playAnimation(entity: String, name: String, loop: Bool, transitionHalflife: Float?)
    case stopAnimation(entity: String)

    // Camera
    case cameraMoveTo(entity: String, position: Value)
    case cameraLookAt(entity: String, eye: Value, target: Value, up: Value)
    case cameraMoveWithInput(entity: String,
                             speed: Value,
                             deltaTime: Value,
                             inputW: Value,
                             inputA: Value,
                             inputS: Value,
                             inputD: Value,
                             inputQ: Value,
                             inputE: Value)
    case cameraMoveBy(entity: String, offset: Value)
    case cameraRotate(entity: String, pitch: Value, yaw: Value, sensitivity: Value?)
    case cameraFollow(entity: String, targetEntity: Value, offset: Value, smoothFactor: Value?, deltaTime: Value?)
    case cameraFollowLocal(entity: String, targetEntity: Value, localOffset: Value, smoothFactor: Value?, deltaTime: Value?)
    case cameraOrbitTarget(entity: String, targetEntity: Value, radius: Value, speed: Value, deltaTime: Value, offsetY: Value?)

    // Physics
    case applyLinearImpulse(entity: String, direction: Value, magnitude: Value)
    case applyWorldForce(entity: String, direction: Value, magnitude: Value)
    case setLinearVelocity(entity: String, velocity: Value)
    case addLinearVelocity(entity: String, deltaVelocity: Value)
    case clampLinearSpeed(entity: String, minSpeed: Value, maxSpeed: Value)
    case applyLinearDamping(entity: String, damping: Value, deltaTime: Value)
    case applyAngularImpulse(entity: String, axis: Value, magnitude: Value)
    case setAngularVelocity(entity: String, angularVelocity: Value)
    case clampAngularSpeed(entity: String, maxAngularSpeed: Value)
    case applyAngularDamping(entity: String, damping: Value, deltaTime: Value)
    case applyForce(entity: String, force: Value) // Supports Vec3 literal or variableRef
    case applyMoment(entity: String, force: simd_float3, at: simd_float3)
    case clearVelocity(entity: String)
    case clearAngularVelocity(entity: String)
    case clearForces(entity: String)
    case pausePhysicsComponent(entity: String, isPaused: Bool)
    case setGravityScale(entity: String, scale: Float)

    // Properties
    case getProperty(entity: String, key: String, as: String) // Read value into variable
    case setProperty(entity: String, key: String, value: Value)

    /// Variables
    case setVariable(name: String, value: Value) // Create/set variable directly

    // Debugging
    case log(String) // Console output
    case logValue(name: String, value: Value) // Log a value (literal or variableRef) with a label

    // Steering behaviors (can return Vec3 into result variable)
    case seek(entity: String, targetPosition: Value, maxSpeed: Value, result: String?)
    case flee(entity: String, threatPosition: Value, maxSpeed: Value, result: String?)
    case arrive(entity: String, targetPosition: Value, maxSpeed: Value, slowingRadius: Value, result: String?)
    case pursuit(entity: String, targetEntity: Value, maxSpeed: Value, result: String?)
    case evade(entity: String, threatEntity: Value, maxSpeed: Value, result: String?)

    // Steering force application (side effects)
    case steerSeek(entity: String, targetPosition: Value, maxSpeed: Value, deltaTime: Value, turnSpeed: Value?, weight: Value?)
    case steerArrive(entity: String, targetPosition: Value, maxSpeed: Value, slowingRadius: Value, deltaTime: Value, turnSpeed: Value?)
    case steerFlee(entity: String, threatPosition: Value, maxSpeed: Value, deltaTime: Value, turnSpeed: Value?)
    case steerPursuit(entity: String, targetEntity: Value, maxSpeed: Value, deltaTime: Value, turnSpeed: Value?)
    case steerFollowPath(entity: String) // placeholder until path data exists
    case orbit(entity: String, centerPosition: Value, radius: Value, maxSpeed: Value, deltaTime: Value, turnSpeed: Value?)
    case steerEvade(entity: String, threatEntity: Value, maxSpeed: Value, result: String?)
    case alignOrientation(entity: String, deltaTime: Value, turnSpeed: Value)
}

// MARK: - Value Types

/// Values that can be passed to instructions
public enum Value: Codable {
    case float(Float)
    case vec3(x: Float, y: Float, z: Float)
    case string(String)
    case bool(Bool)
    case variableRef(String) // Reference to runtime variable
}

// MARK: - Conditions

/// Condition for if statements
public struct Condition: Codable {
    /// Left-hand side of the comparison
    public var left: Value
    /// Comparison operator
    public var comparison: CompareOp
    /// Right-hand side of the comparison
    public var right: Value

    public init(left: Value, comparison: CompareOp, right: Value) {
        self.left = left
        self.comparison = comparison
        self.right = right
    }

    /// Legacy initializer kept for compatibility with existing code
    @available(*, deprecated, message: "Use init(left:comparison:right:) for readability.")
    public init(lhs: Value, op: CompareOp, rhs: Value) {
        self.init(left: lhs, comparison: op, right: rhs)
    }

    private enum CodingKeys: String, CodingKey {
        case left = "lhs"
        case comparison = "op"
        case right = "rhs"
    }
}

/// Comparison operators
public enum CompareOp: String, Codable {
    case less
    case greater
    case equal
    case notEqual
    case lessOrEqual
    case greaterOrEqual
}

// MARK: - USC Script

/// A complete USC script
public struct USCScript: Codable {
    public var name: String
    public var instructions: [USCInstruction]
    public var metadata: ScriptMetadata

    public init(name: String, instructions: [USCInstruction], metadata: ScriptMetadata = .default) {
        self.name = name
        self.instructions = instructions
        self.metadata = metadata
    }
}

/// Script metadata
public struct ScriptMetadata: Codable, Sendable {
    public var triggerType: TriggerType
    public var executionMode: ExecutionMode

    public init(triggerType: TriggerType, executionMode: ExecutionMode) {
        self.triggerType = triggerType
        self.executionMode = executionMode
    }

    public static let `default` = ScriptMetadata(
        triggerType: .perFrame,
        executionMode: .auto
    )
}

/// Trigger type for scripts
public enum TriggerType: String, Codable, Sendable {
    case event // OnCollision, OnTriggerEnter - runs once per event
    case perFrame // OnUpdate - runs every frame
    case manual // Called explicitly from code
}

/// Execution mode
public enum ExecutionMode: String, Codable, Sendable {
    case interpreted // Always run via interpreter
    case compiled // Always generate Swift code
    case auto // Engine decides (events=interpreted, perFrame=compiled)
}

// MARK: - Vec3 Helper

/// Use simd_float3 as the vector type in scripts.
public extension simd_float3 {
    init(x: Float, y: Float, z: Float) {
        self.init(x, y, z)
    }

    // Common vectors
    static let zero = simd_float3(0, 0, 0)
    static let one = simd_float3(1, 1, 1)
    static let forward = simd_float3(0, 0, -1)
    static let backward = simd_float3(0, 0, 1)
    static let up = simd_float3(0, 1, 0)
    static let down = simd_float3(0, -1, 0)
    static let right = simd_float3(1, 0, 0)
    static let left = simd_float3(-1, 0, 0)
}

// MARK: - Helper Functions

/// Load USC script from JSON file
public func loadUSCScript(from url: URL) -> USCScript? {
    // Ensure it's a file URL
    guard url.isFileURL else {
        Logger.log(message: "Invalid URL: must be a file URL")
        return nil
    }

    // Check if file exists and is readable
    guard FileManager.default.isReadableFile(atPath: url.path) else {
        Logger.log(message: "File not accessible or doesn't exist: \(url.path)")
        return nil
    }

    guard let data = try? Data(contentsOf: url) else {
        print("❌ Failed to load USC script from: \(url.path)")
        return nil
    }

    let decoder = JSONDecoder()
    guard let script = try? decoder.decode(USCScript.self, from: data) else {
        print("❌ Failed to decode USC script from: \(url.path)")
        return nil
    }

    print("✅ Loaded USC script: \(script.name)")
    return script
}

/// Save USC script to JSON file
public func saveUSCScript(_ script: USCScript, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(script)
    try data.write(to: url)
    print("✅ Saved USC script: \(script.name) to \(url.path)")
}
