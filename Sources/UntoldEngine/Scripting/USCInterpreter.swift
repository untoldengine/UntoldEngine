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

// MARK: - USC Interpreter

/// Interprets and executes USC IR
public class USCInterpreter {
    public init() {}
    
    /// Execute a complete script
    public func execute(script: USCScript, context: USCContext) {
        var pc = 0  // Program counter
        
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
            
        case .translate(let entityRef, let offset):
            let targetEntity = resolveEntity(entityRef, context: context)
            translateBy(entityId: targetEntity, position: offset.simd)
            return pc + 1
            
        case .rotate(let entityRef, let axis, let degrees):
            let targetEntity = resolveEntity(entityRef, context: context)
            rotateTo(entityId: targetEntity, angle: degrees, axis: axis.simd)
            return pc + 1
            
        case .lookAt(let entityRef, let targetRef):
            let entity = resolveEntity(entityRef, context: context)
            let target = resolveEntity(targetRef, context: context)
            // TODO: Implement lookAt logic
            return pc + 1
            
        case .playAnimation(let entityRef, let name, let loop):
            let targetEntity = resolveEntity(entityRef, context: context)
            //playAnimation(entityId: targetEntity, name: name)
            // TODO: Handle loop parameter
            return pc + 1
            
        case .stopAnimation(let entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            //stopAnimation(entityId: targetEntity)
            return pc + 1
            
        case .setAnimationSpeed:
            // TODO: Implement animation speed control
            return pc + 1
            
        case .applyForce(let entityRef, let direction, let magnitude):
            let targetEntity = resolveEntity(entityRef, context: context)
            //applyForce(entityId: targetEntity, direction: direction.simd, magnitude: magnitude)
            return pc + 1
            
        case .setVelocity(let entityRef, let velocity):
            let targetEntity = resolveEntity(entityRef, context: context)
            setVelocity(entityId: targetEntity, velocity: velocity.simd)
            return pc + 1
            
        case .getProperty(let entityRef, let key, let varName):
            let targetEntity = resolveEntity(entityRef, context: context)
            if let value = getPropertyValue(entityId: targetEntity, key: key) {
                context.variables[varName] = value
            }
            return pc + 1
            
        case .setProperty(let entityRef, let key, let value):
            let targetEntity = resolveEntity(entityRef, context: context)
            let resolvedValue = resolveValue(value, context: context)
            setPropertyValue(entityId: targetEntity, key: key, value: resolvedValue)
            return pc + 1
            
        case .ifCondition(let condition):
            if evaluateCondition(condition, context: context) {
                return pc + 1  // Enter if block
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
            
        case .log(let message):
            Logger.log(message: "[USC] \(message)")
            return pc + 1
        }
    }
    
    // MARK: - Helper Methods
    
    /// Resolve entity reference ("self", "player", etc.)
    private func resolveEntity(_ ref: String, context: USCContext) -> EntityID {
        if ref == "self" {
            return context.entityId
        }
        // Look up by name
        if let entity = findEntity(name: ref) {
            return entity
        }
        return context.entityId  // Fallback to self
    }
    
    /// Resolve value (literal or variable reference)
    private func resolveValue(_ value: Value, context: USCContext) -> Value {
        switch value {
        case .variableRef(let name):
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
        guard case .float(let lhsVal) = lhs,
              case .float(let rhsVal) = rhs else {
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
            case .ifCondition:
                depth += 1
            case .elseBlock where depth == 1:
                return current + 1  // Jump into else block
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
        return instructions.count  // No matching end found
    }
    
    /// Find matching endIf (skip else blocks)
    private func findMatchingEndIf(from pc: Int, instructions: [USCInstruction]) -> Int {
        var depth = 1
        var current = pc + 1
        
        while current < instructions.count {
            switch instructions[current] {
            case .ifCondition:
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
        return instructions.count  // No matching endIf found
    }
    
    // MARK: - Property Access (Stub implementations)
    
    private func getPropertyValue(entityId: EntityID, key: String) -> Value? {
        // TODO: Implement property access
        // This would access component properties based on key path
        // e.g., "position.y", "speed", "health", etc.
        return nil
    }
    
    private func setPropertyValue(entityId: EntityID, key: String, value: Value) {
        // TODO: Implement property modification
        // This would modify component properties
    }
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
