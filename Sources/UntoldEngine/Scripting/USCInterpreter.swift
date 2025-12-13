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

// MARK: - USC Interpreter

/// Interprets and executes USC IR
public class USCInterpreter {
    public init() {}

    /// Execute a complete script
    public func execute(script: USCScript, context: USCContext, forEvent event: String? = nil) {
        var pc = 0 // Program counter
        var inTargetEvent = (event == nil) // If no event specified, execute all
        var currentEvent: String? = nil

        while pc < script.instructions.count {
            let instruction = script.instructions[pc]

            // Check if we hit an event instruction
            if case let .event(eventName) = instruction {
                currentEvent = eventName

                // Determine if we should execute this event block
                if let targetEvent = event {
                    inTargetEvent = (eventName == targetEvent)
                } else {
                    // No specific event requested, execute all events
                    inTargetEvent = true
                }

                pc += 1 // Skip the event instruction itself
                continue
            }

            // Only execute instructions if we're in the target event block
            if inTargetEvent {
                pc = executeInstruction(instruction, at: pc, context: context)
            } else {
                pc += 1 // Skip this instruction
            }
        }
    }

    /// Execute single instruction, return next PC
    private func executeInstruction(_ inst: USCInstruction, at pc: Int, context: USCContext) -> Int {
        switch inst {
        case .event:
            // This should never be called - events are handled in the main execute loop
            fatalError("Event instructions should be handled in execute() main loop")

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

        case let .getKeyState(key, variableName):
            let isPressed = getKeyStateValue(key)
            context.variables[variableName] = .bool(isPressed)
            return pc + 1

        case let .translateTo(entityRef, position):
            let targetEntity = resolveEntity(entityRef, context: context)
            translateTo(entityId: targetEntity, position: position)
            return pc + 1

        case let .translateBy(entityRef, position):
            let targetEntity = resolveEntity(entityRef, context: context)
            translateBy(entityId: targetEntity, position: position)
            return pc + 1

        case let .rotateTo(entityRef, degrees, axis):
            let targetEntity = resolveEntity(entityRef, context: context)
            let degreesValue = resolveValue(degrees, context: context)
            if case let .float(angle) = degreesValue {
                rotateTo(entityId: targetEntity, angle: angle, axis: axis)
            }
            return pc + 1

        case let .rotateBy(entityRef, degrees, axis):
            let targetEntity = resolveEntity(entityRef, context: context)
            let degreesValue = resolveValue(degrees, context: context)
            if case let .float(angle) = degreesValue {
                rotateBy(entityId: targetEntity, angle: angle, axis: axis)
            }
            return pc + 1

        case let .lookAt(entityRef, targetRef):
            let entity = resolveEntity(entityRef, context: context)
            let target = resolveEntity(targetRef, context: context)
            // TODO: Implement lookAt logic
            return pc + 1

        case let .cameraMoveTo(entityRef, position):
            let targetEntity = resolveEntity(entityRef, context: context)
            let resolvedPosition = resolveValue(position, context: context)
            if case let .vec3(x, y, z) = resolvedPosition {
                moveCameraTo(entityId: targetEntity, x, y, z)
            } else {
                Logger.log(message: "[USC] cameraMoveTo failed: expected vec3 position")
            }
            return pc + 1

        case let .cameraLookAt(entityRef, eye, target, up):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let eyeVec = resolveVec3(eye, context: context),
                  let targetVec = resolveVec3(target, context: context),
                  let upVec = resolveVec3(up, context: context)
            else {
                Logger.log(message: "[USC] cameraLookAt failed: missing eye/target/up vec3")
                return pc + 1
            }

            cameraLookAt(entityId: targetEntity,
                         eye: eyeVec,
                         target: targetVec,
                         up: upVec)
            return pc + 1

        case let .cameraMoveWithInput(entityRef,
                                      speed,
                                      deltaTime,
                                      inputW,
                                      inputA,
                                      inputS,
                                      inputD,
                                      inputQ,
                                      inputE):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let speedVal = resolveFloat(speed, context: context),
                  let dtVal = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] cameraMoveWithInput failed: missing speed/deltaTime")
                return pc + 1
            }

            func boolValue(_ v: Value) -> Bool {
                if case let .bool(b) = resolveValue(v, context: context) { return b }
                return false
            }

            let input = (
                w: boolValue(inputW),
                a: boolValue(inputA),
                s: boolValue(inputS),
                d: boolValue(inputD),
                q: boolValue(inputQ),
                e: boolValue(inputE)
            )

            moveCameraWithInput(entityId: targetEntity,
                                input: input,
                                speed: speedVal,
                                deltaTime: dtVal)
            return pc + 1

        case let .cameraMoveBy(entityRef, offset):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let delta = resolveVec3(offset, context: context) else {
                Logger.log(message: "[USC] cameraMoveBy failed: missing offset vec3")
                return pc + 1
            }
            cameraMoveBy(entityId: targetEntity, delta: delta, space: .world)
            return pc + 1

        case let .cameraRotate(entityRef, pitch, yaw, sensitivity):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let pitchVal = resolveFloat(pitch, context: context),
                  let yawVal = resolveFloat(yaw, context: context)
            else {
                Logger.log(message: "[USC] cameraRotate failed: missing pitch/yaw")
                return pc + 1
            }
            let sensVal = resolveFloatOptional(sensitivity, context: context) ?? 1.0
            rotateCamera(entityId: targetEntity,
                         pitch: pitchVal,
                         yaw: yawVal,
                         sensitivity: sensVal)
            return pc + 1

        case let .cameraFollow(entityRef, targetEntityValue, offset, smoothFactor, deltaTime):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let targetName = resolveString(targetEntityValue, context: context),
                  let offsetVec = resolveVec3(offset, context: context)
            else {
                Logger.log(message: "[USC] cameraFollow failed: missing targetEntity/offset")
                return pc + 1
            }

            guard let followTarget = findEntity(name: targetName) else {
                Logger.log(message: "[USC] cameraFollow failed: entity '\(targetName)' not found")
                return pc + 1
            }

            let smooth = resolveFloatOptional(smoothFactor, context: context) ?? 0.0
            let dt = resolveFloatOptional(deltaTime, context: context) ?? 0.0

            cameraFollow(entityId: targetEntity,
                         targetEntity: followTarget,
                         offset: offsetVec,
                         smoothFactor: smooth,
                         deltaTime: dt)
            return pc + 1

        case let .cameraFollowLocal(entityRef, targetEntityValue, localOffset, smoothFactor, deltaTime):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let targetName = resolveString(targetEntityValue, context: context),
                  let offsetVec = resolveVec3(localOffset, context: context)
            else {
                Logger.log(message: "[USC] cameraFollowLocal failed: missing targetEntity/localOffset")
                return pc + 1
            }

            guard let followTarget = findEntity(name: targetName) else {
                Logger.log(message: "[USC] cameraFollowLocal failed: entity '\(targetName)' not found")
                return pc + 1
            }

            let smooth = resolveFloatOptional(smoothFactor, context: context) ?? 0.0
            let dt = resolveFloatOptional(deltaTime, context: context) ?? 0.0

            cameraFollowLocal(entityId: targetEntity,
                              targetEntity: followTarget,
                              localOffset: offsetVec,
                              smoothFactor: smooth,
                              deltaTime: dt)
            return pc + 1

        case let .cameraOrbitTarget(entityRef, targetEntityValue, radius, speed, deltaTime, offsetY):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let targetName = resolveString(targetEntityValue, context: context),
                  let radiusVal = resolveFloat(radius, context: context),
                  let speedVal = resolveFloat(speed, context: context),
                  let dtVal = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] cameraOrbitTarget failed: missing targetEntity/radius/speed/deltaTime")
                return pc + 1
            }

            guard let centerEntity = findEntity(name: targetName) else {
                Logger.log(message: "[USC] cameraOrbitTarget failed: entity '\(targetName)' not found")
                return pc + 1
            }

            let offsetYVal = resolveFloatOptional(offsetY, context: context) ?? 0.0

            cameraOrbitTarget(entityId: targetEntity,
                              centerEntity: centerEntity,
                              radius: radiusVal,
                              angularSpeed: speedVal,
                              deltaTime: dtVal,
                              offsetY: offsetYVal)
            return pc + 1

        case let .playAnimation(entityRef, name, loop):
            let targetEntity = resolveEntity(entityRef, context: context)
            changeAnimation(entityId: targetEntity, name: name, withPause: !loop)
            return pc + 1

        case let .stopAnimation(entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            pauseAnimationComponent(entityId: targetEntity, isPaused: true)
            return pc + 1

        case let .applyLinearImpulse(entityRef, direction, magnitude):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let dir = resolveVec3(direction, context: context),
                  let mag = resolveFloat(magnitude, context: context)
            else {
                Logger.log(message: "[USC] applyLinearImpulse failed: missing direction/magnitude")
                return pc + 1
            }
            applyLinearImpulse(entityId: targetEntity, direction: dir, magnitude: mag)
            return pc + 1

        case let .applyWorldForce(entityRef, direction, magnitude):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let dir = resolveVec3(direction, context: context),
                  let mag = resolveFloat(magnitude, context: context)
            else {
                Logger.log(message: "[USC] applyWorldForce failed: missing direction/magnitude")
                return pc + 1
            }
            applyForce(entityId: targetEntity, direction: dir, magnitude: mag)
            return pc + 1

        case let .setLinearVelocity(entityRef, velocity):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let vel = resolveVec3(velocity, context: context) else {
                Logger.log(message: "[USC] setLinearVelocity failed: missing velocity vec3")
                return pc + 1
            }
            setLinearVelocity(entityId: targetEntity, velocity: vel)
            return pc + 1

        case let .addLinearVelocity(entityRef, deltaVelocity):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let vel = resolveVec3(deltaVelocity, context: context) else {
                Logger.log(message: "[USC] addLinearVelocity failed: missing deltaVelocity vec3")
                return pc + 1
            }
            addLinearVelocity(entityId: targetEntity, deltaVelocity: vel)
            return pc + 1

        case let .clampLinearSpeed(entityRef, minSpeed, maxSpeed):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let min = resolveFloat(minSpeed, context: context),
                  let max = resolveFloat(maxSpeed, context: context)
            else {
                Logger.log(message: "[USC] clampLinearSpeed failed: missing minSpeed/maxSpeed")
                return pc + 1
            }
            clampLinearSpeed(entityId: targetEntity, minSpeed: min, maxSpeed: max)
            return pc + 1

        case let .applyLinearDamping(entityRef, damping, deltaTime):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let dampingVal = resolveFloat(damping, context: context) else {
                Logger.log(message: "[USC] applyLinearDamping failed: missing damping")
                return pc + 1
            }
            let dt = resolveFloat(deltaTime, context: context) ?? 0.0
            applyLinearDamping(entityId: targetEntity, dampingFactor: dampingVal, deltaTime: dt)
            return pc + 1

        case let .applyAngularImpulse(entityRef, axis, magnitude):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let axisVec = resolveVec3(axis, context: context),
                  let mag = resolveFloat(magnitude, context: context)
            else {
                Logger.log(message: "[USC] applyAngularImpulse failed: missing axis/magnitude")
                return pc + 1
            }
            applyAngularImpulse(entityId: targetEntity, axis: axisVec, magnitude: mag)
            return pc + 1

        case let .setAngularVelocity(entityRef, angularVelocity):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let vel = resolveVec3(angularVelocity, context: context) else {
                Logger.log(message: "[USC] setAngularVelocity failed: missing angularVelocity vec3")
                return pc + 1
            }
            setAngularVelocity(entityId: targetEntity, angularVelocity: vel)
            return pc + 1

        case let .clampAngularSpeed(entityRef, maxAngularSpeed):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let max = resolveFloat(maxAngularSpeed, context: context) else {
                Logger.log(message: "[USC] clampAngularSpeed failed: missing maxAngularSpeed")
                return pc + 1
            }
            clampAngularSpeed(entityId: targetEntity, maxAngularSpeed: max)
            return pc + 1

        case let .applyAngularDamping(entityRef, damping, deltaTime):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let dampingVal = resolveFloat(damping, context: context) else {
                Logger.log(message: "[USC] applyAngularDamping failed: missing damping")
                return pc + 1
            }
            let dt = resolveFloat(deltaTime, context: context) ?? 0.0
            applyAngularDamping(entityId: targetEntity, dampingFactor: dampingVal, deltaTime: dt)
            return pc + 1

        case let .applyForce(entityRef, forceValue):
            let targetEntity = resolveEntity(entityRef, context: context)
            let resolvedForce = resolveValue(forceValue, context: context)
            if case let .vec3(x, y, z) = resolvedForce {
                applyForce(entityId: targetEntity, force: simd_float3(x, y, z))
            }
            return pc + 1

        case let .applyMoment(entityRef, force, at):
            let targetEntity = resolveEntity(entityRef, context: context)
            applyMoment(entityId: targetEntity, force: force, at: at)
            return pc + 1

        case let .clearVelocity(entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            clearVelocity(entityId: targetEntity)
            return pc + 1

        case let .clearAngularVelocity(entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            clearAngularVelocity(entityId: targetEntity)
            return pc + 1

        case let .clearForces(entityRef):
            let targetEntity = resolveEntity(entityRef, context: context)
            clearForces(entityId: targetEntity)
            return pc + 1

        case let .pausePhysicsComponent(entityRef, isPaused):
            let targetEntity = resolveEntity(entityRef, context: context)
            pausePhysicsComponent(entityId: targetEntity, isPaused: isPaused)
            return pc + 1

        case let .setGravityScale(entityRef, scale):
            let targetEntity = resolveEntity(entityRef, context: context)
            setGravityScale(entityId: targetEntity, gravityScale: scale)
            return pc + 1

        case let .getProperty(entityRef, key, varName):
            let targetEntity = resolveEntity(entityRef, context: context)
            if let value = getPropertyValue(entityId: targetEntity, key: key, context: context) {
                context.variables[varName] = value
            }
            return pc + 1

        case let .setProperty(entityRef, key, value):
            let targetEntity = resolveEntity(entityRef, context: context)
            let resolvedValue = resolveValue(value, context: context)
            setPropertyValue(entityId: targetEntity, key: key, value: resolvedValue, context: context)
            return pc + 1

        case let .setVariable(name, value):
            let resolvedValue = resolveValue(value, context: context)
            context.variables[name] = resolvedValue
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

        case let .logValue(name, value):
            let resolved = resolveValue(value, context: context)
            let contentValue = loggerContentValue(resolved)
            Logger.log(message: "[USC] \(name): \(contentValue)")
            return pc + 1

        case let .seek(entityRef, targetPosition, maxSpeed, resultVar):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let targetPos = resolveVec3(targetPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context)
            else {
                Logger.log(message: "[USC] seek failed: missing args")
                return pc + 1
            }
            let force = seek(entityId: targetEntity, targetPosition: targetPos, maxSpeed: max)
            if let resultVar {
                context.variables[resultVar] = .vec3(x: force.x, y: force.y, z: force.z)
            }
            return pc + 1

        case let .flee(entityRef, threatPosition, maxSpeed, resultVar):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let threatPos = resolveVec3(threatPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context)
            else {
                Logger.log(message: "[USC] flee failed: missing args")
                return pc + 1
            }
            let force = flee(entityId: targetEntity, threatPosition: threatPos, maxSpeed: max)
            if let resultVar {
                context.variables[resultVar] = .vec3(x: force.x, y: force.y, z: force.z)
            }
            return pc + 1

        case let .arrive(entityRef, targetPosition, maxSpeed, slowingRadius, resultVar):
            let targetEntity = resolveEntity(entityRef, context: context)
            guard let targetPos = resolveVec3(targetPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let slow = resolveFloat(slowingRadius, context: context)
            else {
                Logger.log(message: "[USC] arrive failed: missing args")
                return pc + 1
            }
            let force = arrive(entityId: targetEntity,
                               targetPosition: targetPos,
                               maxSpeed: max,
                               slowingRadius: slow)
            if let resultVar {
                context.variables[resultVar] = .vec3(x: force.x, y: force.y, z: force.z)
            }
            return pc + 1

        case let .pursuit(entityRef, targetEntityValue, maxSpeed, resultVar):
            let pursuer = resolveEntity(entityRef, context: context)
            guard let targetName = resolveString(targetEntityValue, context: context),
                  let max = resolveFloat(maxSpeed, context: context)
            else {
                Logger.log(message: "[USC] pursuit failed: missing args")
                return pc + 1
            }
            guard let target = findEntity(name: targetName) else {
                Logger.log(message: "[USC] pursuit failed: entity '\(targetName)' not found")
                return pc + 1
            }
            let force = pursuit(entityId: pursuer, targetEntity: target, maxSpeed: max)
            if let resultVar {
                context.variables[resultVar] = .vec3(x: force.x, y: force.y, z: force.z)
            }
            return pc + 1

        case let .evade(entityRef, threatEntityValue, maxSpeed, resultVar):
            let evader = resolveEntity(entityRef, context: context)
            guard let threatName = resolveString(threatEntityValue, context: context),
                  let max = resolveFloat(maxSpeed, context: context)
            else {
                Logger.log(message: "[USC] evade failed: missing args")
                return pc + 1
            }
            guard let threat = findEntity(name: threatName) else {
                Logger.log(message: "[USC] evade failed: entity '\(threatName)' not found")
                return pc + 1
            }
            let force = evade(entityId: evader, threatEntity: threat, maxSpeed: max)
            if let resultVar {
                context.variables[resultVar] = .vec3(x: force.x, y: force.y, z: force.z)
            }
            return pc + 1

        case let .steerSeek(entityRef, targetPosition, maxSpeed, deltaTime, turnSpeed, weight):
            let entity = resolveEntity(entityRef, context: context)
            guard let targetPos = resolveVec3(targetPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let dt = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] steerSeek failed: missing args")
                return pc + 1
            }
            let turn = resolveFloatOptional(turnSpeed, context: context) ?? 1.0
            let w = resolveFloatOptional(weight, context: context) ?? 1.0
            steerSeek(entityId: entity,
                      targetPosition: targetPos,
                      maxSpeed: max,
                      deltaTime: dt,
                      turnSpeed: turn,
                      weight: w)
            return pc + 1

        case let .steerArrive(entityRef, targetPosition, maxSpeed, slowingRadius, deltaTime, turnSpeed):
            let entity = resolveEntity(entityRef, context: context)
            guard let targetPos = resolveVec3(targetPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let slow = resolveFloat(slowingRadius, context: context),
                  let dt = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] steerArrive failed: missing args")
                return pc + 1
            }
            let turn = resolveFloatOptional(turnSpeed, context: context) ?? 1.0
            steerArrive(entityId: entity,
                        targetPosition: targetPos,
                        maxSpeed: max,
                        slowingRadius: slow,
                        deltaTime: dt,
                        turnSpeed: turn)
            return pc + 1

        case let .steerFlee(entityRef, threatPosition, maxSpeed, deltaTime, turnSpeed):
            let entity = resolveEntity(entityRef, context: context)
            guard let threatPos = resolveVec3(threatPosition, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let dt = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] steerFlee failed: missing args")
                return pc + 1
            }
            let turn = resolveFloatOptional(turnSpeed, context: context) ?? 1.0
            steerFlee(entityId: entity,
                      threatPosition: threatPos,
                      maxSpeed: max,
                      deltaTime: dt,
                      turnSpeed: turn)
            return pc + 1

        case let .steerPursuit(entityRef, targetEntityValue, maxSpeed, deltaTime, turnSpeed):
            let entity = resolveEntity(entityRef, context: context)
            guard let targetName = resolveString(targetEntityValue, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let dt = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] steerPursuit failed: missing args")
                return pc + 1
            }
            guard let target = findEntity(name: targetName) else {
                Logger.log(message: "[USC] steerPursuit failed: entity '\(targetName)' not found")
                return pc + 1
            }
            let turn = resolveFloatOptional(turnSpeed, context: context) ?? 1.0
            steerPursuit(entityId: entity,
                         targetEntity: target,
                         maxSpeed: max,
                         deltaTime: dt,
                         turnSpeed: turn)
            return pc + 1

        case let .steerFollowPath(entityRef):
            Logger.log(message: "[USC] steerFollowPath not yet implemented - requires path handling")
            return pc + 1

        case let .orbit(entityRef, centerPosition, radius, maxSpeed, deltaTime, turnSpeed):
            let entity = resolveEntity(entityRef, context: context)
            guard let centerPos = resolveVec3(centerPosition, context: context),
                  let r = resolveFloat(radius, context: context),
                  let max = resolveFloat(maxSpeed, context: context),
                  let dt = resolveFloat(deltaTime, context: context)
            else {
                Logger.log(message: "[USC] orbit failed: missing args")
                return pc + 1
            }
            let turn = resolveFloatOptional(turnSpeed, context: context) ?? 1.0
            orbit(entityId: entity,
                  centerPosition: centerPos,
                  radius: r,
                  maxSpeed: max,
                  deltaTime: dt,
                  turnSpeed: turn)
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

    private func loggerContentValue(_ value: Value) -> String {
        switch value {
        case let .float(f): return "\(f)"
        case let .vec3(x, y, z): return "vec3(\(x), \(y), \(z))"
        case let .string(s): return "\"\(s)\""
        case let .bool(b): return "\(b)"
        case let .variableRef(name): return "variableRef(\(name))"
        }
    }

    private func resolveVec3(_ value: Value, context: USCContext) -> simd_float3? {
        if case let .vec3(x, y, z) = resolveValue(value, context: context) {
            return simd_float3(x, y, z)
        }
        return nil
    }

    private func resolveFloat(_ value: Value, context: USCContext) -> Float? {
        if case let .float(f) = resolveValue(value, context: context) {
            return f
        }
        return nil
    }

    private func resolveFloatOptional(_ value: Value?, context: USCContext) -> Float? {
        guard let value else { return nil }
        return resolveFloat(value, context: context)
    }

    private func resolveString(_ value: Value, context: USCContext) -> String? {
        if case let .string(s) = resolveValue(value, context: context) {
            return s
        }
        return nil
    }

    /// Evaluate condition
    private func evaluateCondition(_ condition: Condition, context: USCContext) -> Bool {
        let lhs = resolveValue(condition.left, context: context)
        let rhs = resolveValue(condition.right, context: context)

        // Try boolean comparison first
        if case let .bool(lhsVal) = lhs,
           case let .bool(rhsVal) = rhs
        {
            switch condition.comparison {
            case .equal: return lhsVal == rhsVal
            case .notEqual: return lhsVal != rhsVal
            default: return false // Other ops not valid for bool
            }
        }

        // Try string comparison
        if case let .string(lhsVal) = lhs,
           case let .string(rhsVal) = rhs
        {
            switch condition.comparison {
            case .equal: return lhsVal == rhsVal
            case .notEqual: return lhsVal != rhsVal
            default: return false // Other ops not valid for string
            }
        }

        // Extract float values for comparison
        guard case let .float(lhsVal) = lhs,
              case let .float(rhsVal) = rhs
        else {
            return false
        }

        switch condition.comparison {
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

        case let .subFloat(lhs, rhs):
            guard case let .float(a)? = getVar(lhs),
                  case let .float(b)? = getVar(rhs) else { return }
            setVar(inst.output, .float(a - b))

        case let .subFloatLiteral(lhs, rhsLiteral):
            guard case let .float(a)? = getVar(lhs) else { return }
            setVar(inst.output, .float(a - rhsLiteral))

        case let .mulFloat(lhs, rhs):
            guard case let .float(a)? = getVar(lhs),
                  case let .float(b)? = getVar(rhs) else { return }
            setVar(inst.output, .float(a * b))

        case let .mulFloatLiteral(lhs, rhsLiteral):
            guard case let .float(a)? = getVar(lhs) else { return }
            setVar(inst.output, .float(a * rhsLiteral))

        case let .divFloat(lhs, rhs):
            guard case let .float(a)? = getVar(lhs),
                  case let .float(b)? = getVar(rhs) else { return }
            // Protect against divide by zero
            if abs(b) < 0.0001 {
                Logger.log(message: "[USC] Warning: Division by zero, result set to 0")
                setVar(inst.output, .float(0))
            } else {
                setVar(inst.output, .float(a / b))
            }

        case let .divFloatLiteral(lhs, rhsLiteral):
            guard case let .float(a)? = getVar(lhs) else { return }
            // Protect against divide by zero
            if abs(rhsLiteral) < 0.0001 {
                Logger.log(message: "[USC] Warning: Division by zero, result set to 0")
                setVar(inst.output, .float(0))
            } else {
                setVar(inst.output, .float(a / rhsLiteral))
            }

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

        case let .normalizeVec3(vecVar):
            guard case let .vec3(x, y, z)? = getVar(vecVar) else { return }
            let v = simd_float3(x, y, z)
            let len = simd_length(v)
            if len > 0.0001 {
                let n = v / len
                setVar(inst.output, .vec3(x: n.x, y: n.y, z: n.z))
            } else {
                setVar(inst.output, .vec3(x: 0, y: 0, z: 0))
            }

        case let .dotVec3(lhs, rhs):
            guard case let .vec3(ax, ay, az)? = getVar(lhs),
                  case let .vec3(bx, by, bz)? = getVar(rhs) else { return }
            let dot = ax * bx + ay * by + az * bz
            setVar(inst.output, .float(dot))

        case let .crossVec3(lhs, rhs):
            guard case let .vec3(ax, ay, az)? = getVar(lhs),
                  case let .vec3(bx, by, bz)? = getVar(rhs) else { return }
            let a = simd_float3(ax, ay, az)
            let b = simd_float3(bx, by, bz)
            let c = simd_cross(a, b)
            setVar(inst.output, .vec3(x: c.x, y: c.y, z: c.z))

        case let .lerpVec3(from, to, t):
            guard case let .vec3(ax, ay, az)? = getVar(from),
                  case let .vec3(bx, by, bz)? = getVar(to),
                  case let .float(tVal)? = getVar(t) else { return }
            let a = simd_float3(ax, ay, az)
            let b = simd_float3(bx, by, bz)
            let lerped = simd_mix(a, b, simd_make_float3(tVal, tVal, tVal))
            setVar(inst.output, .vec3(x: lerped.x, y: lerped.y, z: lerped.z))

        case let .orBool(lhs, rhs):
            guard case let .bool(a)? = getVar(lhs),
                  case let .bool(b)? = getVar(rhs) else { return }
            setVar(inst.output, .bool(a || b))

        case let .andBool(lhs, rhs):
            guard case let .bool(a)? = getVar(lhs),
                  case let .bool(b)? = getVar(rhs) else { return }
            setVar(inst.output, .bool(a && b))

        case let .notBool(operand):
            guard case let .bool(a)? = getVar(operand) else { return }
            setVar(inst.output, .bool(!a))
        }
    }

    /// Get key state from InputSystem
    private func getKeyStateValue(_ key: String) -> Bool {
        switch key.uppercased() {
        case "W": return InputSystem.shared.keyState.wPressed
        case "A": return InputSystem.shared.keyState.aPressed
        case "S": return InputSystem.shared.keyState.sPressed
        case "D": return InputSystem.shared.keyState.dPressed
        case "Q": return InputSystem.shared.keyState.qPressed
        case "E": return InputSystem.shared.keyState.ePressed
        case "SPACE": return InputSystem.shared.keyState.spacePressed
        case "SHIFT": return InputSystem.shared.keyState.shiftPressed
        case "CTRL": return InputSystem.shared.keyState.ctrlPressed
        case "ALT": return InputSystem.shared.keyState.altPressed
        default: return false
        }
    }
}
