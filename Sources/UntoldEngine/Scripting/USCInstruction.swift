//
//  USCInstruction.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - Instruction Set Definition
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
    case mulFloat(lhs: String, rhs: String)
    case mulFloatLiteral(lhs: String, rhs: Float)

    case addVec3(lhs: String, rhs: String)
    case scaleVec3(vec: String, scalarVar: String)
    case scaleVec3Literal(vec: String, scalar: Float)

    case lengthVec3(vec: String) // vec -> float
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

    // Math
    case math(MathInstruction)

    // Action
    case callAction(name: String, args: [String], result: String?)

    // Input
    case ifInput(InputCondition)

    // Entity operations
    case translateTo(entity: String, position: Vec3)
    case translateBy(entity: String, position: Vec3) // Move entity
    case rotateTo(entity: String, degrees: Value, axis: Vec3) // Rotate entity (supports float or variableRef)
    case rotateBy(entity: String, degrees: Value, axis: Vec3) // Rotate by entity (supports float or variableRef)
    case lookAt(entity: String, target: String) // Orient towards target

    // Animation
    case playAnimation(entity: String, name: String, loop: Bool)
    case stopAnimation(entity: String)

    // Physics
    case applyForce(entity: String, force: Vec3)
    case applyMoment(entity: String, force: Vec3, at: Vec3)
    case clearVelocity(entity: String)
    case clearAngularVelocity(entity: String)
    case clearForces(entity: String)
    case pausePhysicsComponent(entity: String, isPaused: Bool)
    case setGravityScale(entity: String, scale: Float)

    // Properties
    case getProperty(entity: String, key: String, as: String) // Read value into variable
    case setProperty(entity: String, key: String, value: Value)

    // Variables
    case setVariable(name: String, value: Value) // Create/set variable directly

    // Debugging
    case log(String) // Console output
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
    public var lhs: Value
    public var op: CompareOp
    public var rhs: Value

    public init(lhs: Value, op: CompareOp, rhs: Value) {
        self.lhs = lhs
        self.op = op
        self.rhs = rhs
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
public struct ScriptMetadata: Codable {
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
public enum TriggerType: String, Codable {
    case event // OnCollision, OnTriggerEnter - runs once per event
    case perFrame // OnUpdate - runs every frame
    case manual // Called explicitly from code
}

/// Execution mode
public enum ExecutionMode: String, Codable {
    case interpreted // Always run via interpreter
    case compiled // Always generate Swift code
    case auto // Engine decides (events=interpreted, perFrame=compiled)
}

// MARK: - Vec3 Helper

/// Helper for 3D vectors
public struct Vec3: Codable {
    public var x: Float
    public var y: Float
    public var z: Float

    public init(x: Float, y: Float, z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var simd: simd_float3 {
        simd_float3(x, y, z)
    }

    // Common vectors
    public static let zero = Vec3(x: 0, y: 0, z: 0)
    public static let one = Vec3(x: 1, y: 1, z: 1)
    public static let forward = Vec3(x: 0, y: 0, z: -1)
    public static let backward = Vec3(x: 0, y: 0, z: 1)
    public static let up = Vec3(x: 0, y: 1, z: 0)
    public static let down = Vec3(x: 0, y: -1, z: 0)
    public static let right = Vec3(x: 1, y: 0, z: 0)
    public static let left = Vec3(x: -1, y: 0, z: 0)
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
