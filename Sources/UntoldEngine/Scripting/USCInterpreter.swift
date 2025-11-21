//
//  USCInterpreter.swift
//  UntoldEngine
//
//  USC (Untold Script Core) - Interpreter
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

// This file was jump-started with AI assistance — then refined by humans. If you spot an issue, please submit an issue.

import Foundation
import simd

// MARK: - USC Context

/// Context for script execution
public class USCContext {
    public var entityId: EntityID
    public var variables: [String: Value] = [:]
    public var script: USCScript?

    public init(entityId: EntityID, script: USCScript?) {
        self.entityId = entityId
        self.script = script
    }
}

public typealias USCAction = (_ context: USCContext,
                              _ args: [String: Value]) -> Value?

public class USCActionRegistry {
    public static let shared = USCActionRegistry()
    private init() {}

    private var actions: [String: USCAction] = [:]

    public func register(name: String, action: @escaping USCAction) {
        actions[name] = action
    }

    public func resolve(name: String) -> USCAction? {
        actions[name]
    }
}

/* Usage Example inside init for example
 USCActionRegistry.shared.register(name: "Ball.applyKick") { context, args in
     // args: ["desiredVel": Value, "mass": Value, ...]
     // Access scene via global or injected handle if needed
     // Return a Value? that script can capture
 }
 */

// MARK: - USC Interpreter

/// Interprets and executes USC IR
public class USCInterpreter {
    public init() {}

    /// Execute a complete script
    public func execute(script: USCScript, context: USCContext) {
        var pc = 0 // Program counter

        while pc < script.instructions.count {
            pc = executeInstruction(script.instructions[pc], at: pc, context: context)
        }
    }

    /// Execute single instruction, return next PC
    private func executeInstruction(_ inst: USCInstruction, at pc: Int, context: USCContext) -> Int {
        switch inst {
        case .event:
            // Event already triggered, just continue
            return pc + 1

        // Math
        case let .math(mathInst):
            executeMath(mathInst, context: context)
            return pc + 1

        // Action
        case let .callAction(name, argNames, resultVar):
            executeAction(name: name, argNames: argNames, resultVar: resultVar, context: context)
            return pc + 1

        // Input
        case let .ifInput(inputCond):
            if evaluateInput(inputCond) {
                return pc + 1
            } else {
                return findMatchingEnd(from: pc, instructions: context.script!.instructions)
            }

        case let .translateTo(entityRef, position):
            let targetEntity = resolveEntity(entityRef, context: context)
            translateTo(entityId: targetEntity, position: position.simd)
            return pc + 1

        case let .translateBy(entityRef, position):
            let targetEntity = resolveEntity(entityRef, context: context)
            translateBy(entityId: targetEntity, position: position.simd)
            return pc + 1

        case let .rotateTo(entityRef, degrees, axis):
            let targetEntity = resolveEntity(entityRef, context: context)
            rotateTo(entityId: targetEntity, angle: degrees, axis: axis.simd)
            return pc + 1

        case let .rotateBy(entityRef, degrees, axis):
            let targetEntity = resolveEntity(entityRef, context: context)
            rotateBy(entityId: targetEntity, angle: degrees, axis: axis.simd)
            return pc + 1

        case let .lookAt(entityRef, targetRef):
            let entity = resolveEntity(entityRef, context: context)
            let target = resolveEntity(targetRef, context: context)
            // TODO: Implement lookAt logic
            return pc + 1

        case let .playAnimation(entityRef, name, loop):
            let targetEntity = resolveEntity(entityRef, context: context)
            changeAnimation(entityId: targetEntity, name: name)
            return pc + 1

        case let .stopAnimation(entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            pauseAnimationComponent(entityId: targetEntity, isPaused: true)
            return pc + 1

        case .setAnimationSpeed:
            // TODO: Implement animation speed control
            return pc + 1

        case let .applyForce(entityRef, force):
            let targetEntity = resolveEntity(entityRef, context: context)
            applyForce(entityId: targetEntity, force: force.simd)
            return pc + 1

        case let .setVelocity(entityRef, velocity):
            let targetEntity = resolveEntity(entityRef, context: context)
            setVelocity(entityId: targetEntity, velocity: velocity.simd)
            return pc + 1

        case let .getProperty(entityRef, key, varName):
            let targetEntity = resolveEntity(entityRef, context: context)
            if let value = getPropertyValue(entityId: targetEntity, key: key) {
                context.variables[varName] = value
            }
            return pc + 1

        case let .setProperty(entityRef, key, value):
            let targetEntity = resolveEntity(entityRef, context: context)
            let resolvedValue = resolveValue(value, context: context)
            setPropertyValue(entityId: targetEntity, key: key, value: resolvedValue)
            return pc + 1

        case let .ifCondition(condition):
            if evaluateCondition(condition, context: context) {
                return pc + 1 // Enter if block
            } else {
                // Skip to matching endIf or else
                return findMatchingEnd(from: pc, instructions: context.script!.instructions)
            }

        case .elseBlock:
            // If we hit else, we were in true branch, skip to endIf
            return findMatchingEndIf(from: pc, instructions: context.script!.instructions)

        case .endIf:
            return pc + 1

        case .delay:
            // TODO: Implement delay logic (requires async/coroutine support)
            return pc + 1

        case .loop:
            // TODO: Implement loop logic (requires maintaining loop counters)
            return pc + 1

        case .endLoop:
            // TODO: Implement loop logic (requires maintaining loop counters)
            return pc + 1

        case let .log(message):
            Logger.log(message: "[USC] \(message)")
            return pc + 1
        }
    }

    // MARK: - Helper Methods

    private func evaluateInput(_ cond: InputCondition) -> Bool {
        switch cond {
        case let .keyPressed(key):
            // Map key string to keyState
            switch key.uppercased() {
            case "W": return InputSystem.shared.keyState.wPressed
            case "A": return InputSystem.shared.keyState.aPressed
            case "S": return InputSystem.shared.keyState.sPressed
            case "D": return InputSystem.shared.keyState.dPressed
            case "Q": return InputSystem.shared.keyState.qPressed
            case "E": return InputSystem.shared.keyState.ePressed
            case "SPACE": return InputSystem.shared.keyState.spacePressed
            default: return false
            }

        case let .keyReleased(key):
            // Map key string to keyState
            switch key.uppercased() {
            case "W": return !InputSystem.shared.keyState.wPressed
            case "A": return !InputSystem.shared.keyState.aPressed
            case "S": return !InputSystem.shared.keyState.sPressed
            case "D": return !InputSystem.shared.keyState.dPressed
            case "Q": return !InputSystem.shared.keyState.qPressed
            case "E": return !InputSystem.shared.keyState.ePressed
            case "SPACE": return !InputSystem.shared.keyState.spacePressed
            default: return false
            }
        }
    }

    /// Resolve entity reference ("self", "player", etc.)
    private func resolveEntity(_ ref: String, context: USCContext) -> EntityID {
        if ref == "self" {
            return context.entityId
        }
        // Look up by name
        if let entity = findEntity(name: ref) {
            return entity
        }
        return context.entityId // Fallback to self
    }

    /// Resolve value (literal or variable reference)
    private func resolveValue(_ value: Value, context: USCContext) -> Value {
        switch value {
        case let .variableRef(name):
            return context.variables[name] ?? .float(0)
        default:
            return value
        }
    }

    /// Evaluate condition
    private func evaluateCondition(_ condition: Condition, context: USCContext) -> Bool {
        let lhs = resolveValue(condition.lhs, context: context)
        let rhs = resolveValue(condition.rhs, context: context)

        // Extract float values for comparison
        guard case let .float(lhsVal) = lhs,
              case let .float(rhsVal) = rhs
        else {
            return false
        }

        switch condition.op {
        case .less: return lhsVal < rhsVal
        case .greater: return lhsVal > rhsVal
        case .equal: return abs(lhsVal - rhsVal) < 0.001
        case .notEqual: return abs(lhsVal - rhsVal) >= 0.001
        case .lessOrEqual: return lhsVal <= rhsVal
        case .greaterOrEqual: return lhsVal >= rhsVal
        }
    }

    /// Find matching endIf or else for if statement
    private func findMatchingEnd(from pc: Int, instructions: [USCInstruction]) -> Int {
        var depth = 1
        var current = pc + 1

        while current < instructions.count {
            switch instructions[current] {
            case .ifCondition, .ifInput:
                depth += 1
            case .elseBlock where depth == 1:
                return current + 1 // Jump into else block
            case .endIf:
                depth -= 1
                if depth == 0 {
                    return current + 1
                }
            default:
                break
            }
            current += 1
        }
        return instructions.count // No matching end found
    }

    /// Find matching endIf (skip else blocks)
    private func findMatchingEndIf(from pc: Int, instructions: [USCInstruction]) -> Int {
        var depth = 1
        var current = pc + 1

        while current < instructions.count {
            switch instructions[current] {
            case .ifCondition, .ifInput:
                depth += 1
            case .endIf:
                depth -= 1
                if depth == 0 {
                    return current + 1
                }
            default:
                break
            }
            current += 1
        }
        return instructions.count // No matching endIf found
    }

    private func executeAction(name: String,
                               argNames: [String],
                               resultVar: String?,
                               context: USCContext)
    {
        guard let action = USCActionRegistry.shared.resolve(name: name) else {
            Logger.log(message: "[USC] Unknown action: \(name)")
            return
        }

        var argsDict: [String: Value] = [:]
        for argName in argNames {
            if let value = context.variables[argName] {
                argsDict[argName] = value
            }
        }

        if let result = action(context, argsDict), let resultVar {
            context.variables[resultVar] = result
        }
    }

    private func executeMath(_ inst: MathInstruction, context: USCContext) {
        func getVar(_ name: String) -> Value? {
            context.variables[name]
        }

        func setVar(_ name: String, _ value: Value) {
            context.variables[name] = value
        }

        switch inst.op {
        case let .addFloat(lhs, rhs):
            guard case let .float(a)? = getVar(lhs),
                  case let .float(b)? = getVar(rhs) else { return }
            setVar(inst.output, .float(a + b))

        case let .addFloatLiteral(lhs, rhsLiteral):
            guard case let .float(a)? = getVar(lhs) else { return }
            setVar(inst.output, .float(a + rhsLiteral))

        case let .mulFloat(lhs, rhs):
            guard case let .float(a)? = getVar(lhs),
                  case let .float(b)? = getVar(rhs) else { return }
            setVar(inst.output, .float(a * b))

        case let .mulFloatLiteral(lhs, rhsLiteral):
            guard case let .float(a)? = getVar(lhs) else { return }
            setVar(inst.output, .float(a * rhsLiteral))

        case let .addVec3(lhs, rhs):
            guard case let .vec3(ax, ay, az)? = getVar(lhs),
                  case let .vec3(bx, by, bz)? = getVar(rhs) else { return }
            setVar(inst.output, .vec3(x: ax + bx, y: ay + by, z: az + bz))

        case let .scaleVec3(vecVar, scalarVar):
            guard case let .vec3(x, y, z)? = getVar(vecVar),
                  case let .float(s)? = getVar(scalarVar) else { return }
            setVar(inst.output, .vec3(x: x * s, y: y * s, z: z * s))

        case let .scaleVec3Literal(vecVar, scalar):
            guard case let .vec3(x, y, z)? = getVar(vecVar) else { return }
            setVar(inst.output, .vec3(x: x * scalar, y: y * scalar, z: z * scalar))

        case let .lengthVec3(vecVar):
            guard case let .vec3(x, y, z)? = getVar(vecVar) else { return }
            let len = sqrtf(x * x + y * y + z * z)
            setVar(inst.output, .float(len))
        }
    }

    // MARK: - Property Access (Stub implementations)

//    private func getPropertyValue(entityId: EntityID, key: String) -> Value? {
//        // TODO: Implement property access
//        // This would access component properties based on key path
//        // e.g., "position.y", "speed", "health", etc.
//        return nil
//    }
//
//    private func setPropertyValue(entityId: EntityID, key: String, value: Value) {
//        // TODO: Implement property modification
//        // This would modify component properties
//    }
}

// MARK: - Engine Function Wrappers

// Note: These functions already exist in UntoldEngine, we're just calling them
/*
 private func applyForce(entityId: EntityID, direction: simd_float3, magnitude: Float) {
     // Normalize direction and apply force
     let normalizedDir = simd_normalize(direction)
     let force = normalizedDir * magnitude

     // Check if entity has kinetic component
     guard let kineticComp = scene.get(component: KineticComponent.self, for: entityId) else {
         return
     }

     // Apply force to velocity
     if var kinetic = scene.get(component: KineticComponent.self, for: entityId) {
         kinetic.velocity += force * 0.016  // Assume ~60 FPS for now
     }
 }

 private func setVelocity(entityId: EntityID, velocity: simd_float3) {
     guard var kineticComp = scene.get(component: KineticComponent.self, for: entityId) else {
         return
     }
     kineticComp.velocity = velocity
 }
 */
