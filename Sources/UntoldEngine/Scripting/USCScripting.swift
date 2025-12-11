//
//  USCScripting.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/20/25.
//
import Foundation
import simd

public func initScriptingSystem() {
    registerCoreMathActions()
    registerCoreGamePlayActions()

    // Register ScriptComponent for scene serialization with custom merge
    // Now supports multi-script arrays and remains backward compatible.
    encodeCustomComponent(type: ScriptComponent.self) { existing, decoded in
        // If decoded has explicit arrays, use them directly.
        // This also covers legacy decode, since our ScriptComponent decoder
        // maps legacy single fields into arrays.
        if !decoded.scripts.isEmpty {
            existing.scripts = decoded.scripts
        } else {
            // If decoded scripts are empty, keep existing.scripts as-is
            // (no change).
        }

        if let decodedPaths = decoded.scriptFilePaths {
            // If decoded has paths, replace existing
            existing.scriptFilePaths = decodedPaths
        } else {
            // If decoded has no paths field, do not overwrite existing paths
            // (keeps existing.scriptFilePaths).
        }
    }
}

private func registerCoreMathActions() {
    let reg = USCActionRegistry.shared

    // Vector addition. Support both qualified and unqualified names used across tests.
    let addVec3Handler: USCAction = { _, args in
        // Preferred conventional names
        if let a = args["a"], case let .vec3(ax, ay, az) = a,
           let b = args["b"], case let .vec3(bx, by, bz) = b
        {
            return .vec3(x: ax + bx, y: ay + by, z: az + bz)
        }

        // Fallback: add the first two vec3s present regardless of key names
        let vecPairs = args.compactMap { _, v -> (Float, Float, Float)? in
            if case let .vec3(x, y, z) = v { return (x, y, z) }
            return nil
        }
        if vecPairs.count >= 2 {
            let a = vecPairs[0], b = vecPairs[1]
            return .vec3(x: a.0 + b.0, y: a.1 + b.1, z: a.2 + b.2)
        }

        return nil
    }

    reg.register(name: "Math.addVec3", action: addVec3Handler)
    reg.register(name: "addVec3", action: addVec3Handler)

    // Optional helpers for completeness (not required by the failing tests):
    reg.register(name: "Math.scaleVec3") { _, args in
        guard let v = args["v"], case let .vec3(x, y, z) = v,
              let s = args["s"], case let .float(scalar) = s else { return nil }
        return .vec3(x: x * scalar, y: y * scalar, z: z * scalar)
    }

    reg.register(name: "Math.lengthVec3") { _, args in
        guard let v = args["v"], case let .vec3(x, y, z) = v else { return nil }
        return .float(sqrtf(x * x + y * y + z * z))
    }
}

private func registerCoreGamePlayActions() {
    let reg = USCActionRegistry.shared

    // Camera scripted actions
    reg.register(name: ScriptActionName.cameraMoveTo.rawValue) { context, args in
        // 1. Extract the position argument as a Vec3
        guard let posValue = args[ScriptArgKey.position.rawValue],
              case let .vec3(x, y, z) = posValue
        else {
            Logger.log(message: "[USC] cameraMoveTo action failed: missing or invalid 'position' arg")
            return nil
        }

        // 2. Call into your existing camera API
        moveCameraTo(entityId: context.entityId, x, y, z)

        // 3. No return value (pure side effect)
        return nil
    }

    // 1) camera.lookAt: eye / target / up vec3
    reg.register(name: ScriptActionName.cameraLookAt.rawValue) { context, args in
        guard
            let eyeVal = args[ScriptArgKey.eye.rawValue],
            case let .vec3(ex, ey, ez) = eyeVal,
            let targetVal = args[ScriptArgKey.target.rawValue],
            case let .vec3(tx, ty, tz) = targetVal,
            let upVal = args[ScriptArgKey.up.rawValue],
            case let .vec3(ux, uy, uz) = upVal
        else {
            Logger.log(message: "[USC] cameraLookAt failed: missing or invalid args")
            return nil
        }

        let eye = simd_float3(ex, ey, ez)
        let target = simd_float3(tx, ty, tz)
        let up = simd_float3(ux, uy, uz)

        cameraLookAt(entityId: context.entityId,
                     eye: eye,
                     target: target,
                     up: up)

        return nil
    }

    // 2) camera.moveWithInput: speed, dt, 6 booleans
    reg.register(name: ScriptActionName.cameraMoveWithInput.rawValue) { context, args in
        guard
            let speedVal = args[ScriptArgKey.speed.rawValue],
            case let .float(speed) = speedVal,
            let dtVal = args[ScriptArgKey.deltaTime.rawValue],
            case let .float(dt) = dtVal
        else {
            Logger.log(message: "[USC] cameraMoveWithInput failed: missing speed/deltaTime")
            return nil
        }

        func boolArg(_ key: ScriptArgKey) -> Bool {
            if let v = args[key.rawValue], case let .bool(b) = v {
                return b
            }
            return false
        }

        let input = (
            w: boolArg(.inputW),
            a: boolArg(.inputA),
            s: boolArg(.inputS),
            d: boolArg(.inputD),
            q: boolArg(.inputQ),
            e: boolArg(.inputE)
        )

        moveCameraWithInput(entityId: context.entityId,
                            input: input,
                            speed: speed,
                            deltaTime: dt)
        return nil
    }

    reg.register(name: ScriptActionName.cameraMoveBy.rawValue) { context, args in
        guard let deltaVal = args[ScriptArgKey.offset.rawValue],
              case let .vec3(x, y, z) = deltaVal
        else {
            Logger.log(message: "[USC] cameraMoveBy failed: missing offset vec3")
            return nil
        }
        cameraMoveBy(entityId: context.entityId, delta: simd_float3(x, y, z), space: .world)
        return nil
    }

    reg.register(name: ScriptActionName.cameraRotate.rawValue) { context, args in
        guard
            let pitchVal = args[ScriptArgKey.pitch.rawValue],
            case let .float(pitch) = pitchVal,
            let yawVal = args[ScriptArgKey.yaw.rawValue],
            case let .float(yaw) = yawVal
        else {
            Logger.log(message: "[USC] cameraRotate failed: missing pitch/yaw")
            return nil
        }

        let sensitivity = (args[ScriptArgKey.sensitivity.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 1.0
        rotateCamera(entityId: context.entityId, pitch: pitch, yaw: yaw, sensitivity: Float(sensitivity))
        return nil
    }

    reg.register(name: ScriptActionName.cameraFollow.rawValue) { context, args in
        guard
            let targetNameVal = args[ScriptArgKey.targetEntity.rawValue],
            case let .string(targetName) = targetNameVal,
            let offsetVal = args[ScriptArgKey.offset.rawValue],
            case let .vec3(ox, oy, oz) = offsetVal
        else {
            Logger.log(message: "[USC] cameraFollow failed: missing targetEntity/offset")
            return nil
        }

        guard let targetEntity = findEntity(name: targetName) else {
            Logger.log(message: "[USC] cameraFollow failed: entity '\(targetName)' not found")
            return nil
        }

        let smooth = (args[ScriptArgKey.smoothFactor.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0
        let dt = (args[ScriptArgKey.deltaTime.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0

        cameraFollow(entityId: context.entityId,
                     targetEntity: targetEntity,
                     offset: simd_float3(ox, oy, oz),
                     smoothFactor: Float(smooth),
                     deltaTime: Float(dt))
        return nil
    }

    reg.register(name: "cameraFollowLocal") { context, args in
        guard
            let targetNameVal = args[ScriptArgKey.targetEntity.rawValue],
            case let .string(targetName) = targetNameVal,
            let offsetVal = args[ScriptArgKey.localOffset.rawValue],
            case let .vec3(ox, oy, oz) = offsetVal
        else {
            Logger.log(message: "[USC] cameraFollowLocal failed: missing targetEntity/localOffset")
            return nil
        }

        guard let targetEntity = findEntity(name: targetName) else {
            Logger.log(message: "[USC] cameraFollowLocal failed: entity '\(targetName)' not found")
            return nil
        }

        let smooth = (args[ScriptArgKey.smoothFactor.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0
        let dt = (args[ScriptArgKey.deltaTime.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0

        cameraFollowLocal(entityId: context.entityId,
                          targetEntity: targetEntity,
                          localOffset: simd_float3(ox, oy, oz),
                          smoothFactor: Float(smooth),
                          deltaTime: Float(dt))
        return nil
    }

    // Physics linear motion
    reg.register(name: ScriptActionName.applyLinearImpulse.rawValue) { context, args in
        guard
            let dirVal = args[.direction], case let .vec3(x, y, z) = dirVal,
            let magVal = args[.magnitude], case let .float(mag) = magVal
        else {
            Logger.log(message: "[USC] applyLinearImpulse failed: missing direction/magnitude")
            return nil
        }
        applyLinearImpulse(entityId: context.entityId, direction: simd_float3(x, y, z), magnitude: mag)
        return nil
    }

    reg.register(name: ScriptActionName.applyWorldForce.rawValue) { context, args in
        guard
            let dirVal = args[.worldDirection], case let .vec3(x, y, z) = dirVal,
            let magVal = args[.magnitude], case let .float(mag) = magVal
        else {
            Logger.log(message: "[USC] applyWorldForce failed: missing worldDirection/magnitude")
            return nil
        }
        applyForce(entityId: context.entityId,
                   direction: simd_float3(x, y, z),
                   magnitude: mag)
        return nil
    }

    reg.register(name: ScriptActionName.setLinearVelocity.rawValue) { context, args in
        guard let velVal = args[.velocity], case let .vec3(x, y, z) = velVal else {
            Logger.log(message: "[USC] setLinearVelocity failed: missing velocity vec3")
            return nil
        }
        setLinearVelocity(entityId: context.entityId, velocity: simd_float3(x, y, z))
        return nil
    }

    reg.register(name: ScriptActionName.addLinearVelocity.rawValue) { context, args in
        guard let velVal = args[.deltaVelocity], case let .vec3(x, y, z) = velVal else {
            Logger.log(message: "[USC] addLinearVelocity failed: missing deltaVelocity vec3")
            return nil
        }
        addLinearVelocity(entityId: context.entityId, deltaVelocity: simd_float3(x, y, z))
        return nil
    }

    reg.register(name: ScriptActionName.clampLinearSpeed.rawValue) { context, args in
        guard
            let minVal = args[ScriptArgKey.minSpeed.rawValue], case let .float(min) = minVal,
            let maxVal = args[ScriptArgKey.maxSpeed.rawValue], case let .float(max) = maxVal
        else {
            Logger.log(message: "[USC] clampLinearSpeed failed: missing minSpeed/maxSpeed")
            return nil
        }
        clampLinearSpeed(entityId: context.entityId, minSpeed: min, maxSpeed: max)
        return nil
    }

    reg.register(name: ScriptActionName.applyLinearDamping.rawValue) { context, args in
        guard let dampingVal = args[ScriptArgKey.damping.rawValue], case let .float(d) = dampingVal else {
            Logger.log(message: "[USC] applyLinearDamping failed: missing damping")
            return nil
        }
        let dt = (args[ScriptArgKey.deltaTime.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0
        applyLinearDamping(entityId: context.entityId, dampingFactor: d, deltaTime: Float(dt))
        return nil
    }

    reg.register(name: ScriptActionName.applyAngularImpulse.rawValue) { context, args in
        guard
            let axisVal = args[.axis], case let .vec3(x, y, z) = axisVal,
            let magVal = args[.magnitude], case let .float(mag) = magVal
        else {
            Logger.log(message: "[USC] applyAngularImpulse failed: missing axis/magnitude")
            return nil
        }
        applyAngularImpulse(entityId: context.entityId, axis: simd_float3(x, y, z), magnitude: mag)
        return nil
    }

    reg.register(name: ScriptActionName.setAngularVelocity.rawValue) { context, args in
        guard let velVal = args[.angularVelocity], case let .vec3(x, y, z) = velVal else {
            Logger.log(message: "[USC] setAngularVelocity failed: missing angularVelocity vec3")
            return nil
        }
        setAngularVelocity(entityId: context.entityId, angularVelocity: simd_float3(x, y, z))
        return nil
    }

    reg.register(name: ScriptActionName.clampAngularSpeed.rawValue) { context, args in
        guard let maxVal = args[ScriptArgKey.maxAngularSpeed.rawValue], case let .float(max) = maxVal else {
            Logger.log(message: "[USC] clampAngularSpeed failed: missing maxAngularSpeed")
            return nil
        }
        clampAngularSpeed(entityId: context.entityId, maxAngularSpeed: max)
        return nil
    }

    reg.register(name: ScriptActionName.applyAngularDamping.rawValue) { context, args in
        guard let dampingVal = args[ScriptArgKey.damping.rawValue], case let .float(d) = dampingVal else {
            Logger.log(message: "[USC] applyAngularDamping failed: missing damping")
            return nil
        }
        let dt = (args[ScriptArgKey.deltaTime.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0
        applyAngularDamping(entityId: context.entityId, dampingFactor: d, deltaTime: Float(dt))
        return nil
    }

    reg.register(name: ScriptActionName.cameraOrbitTarget.rawValue) { context, args in
        guard
            let centerNameVal = args[ScriptArgKey.targetEntity.rawValue],
            case let .string(centerName) = centerNameVal,
            let radiusVal = args[ScriptArgKey.radius.rawValue],
            case let .float(radius) = radiusVal,
            let speedVal = args[ScriptArgKey.speed.rawValue],
            case let .float(speed) = speedVal,
            let dtVal = args[ScriptArgKey.deltaTime.rawValue],
            case let .float(dt) = dtVal
        else {
            Logger.log(message: "[USC] cameraOrbitTarget failed: missing targetEntity/radius/speed/deltaTime")
            return nil
        }

        guard let centerEntity = findEntity(name: centerName) else {
            Logger.log(message: "[USC] cameraOrbitTarget failed: entity '\(centerName)' not found")
            return nil
        }

        let offsetY = (args[ScriptArgKey.offset.rawValue].flatMap { if case let .float(f) = $0 { return Double(f) } else { return nil } }) ?? 0.0

        cameraOrbitTarget(entityId: context.entityId,
                          centerEntity: centerEntity,
                          radius: radius,
                          angularSpeed: speed,
                          deltaTime: dt,
                          offsetY: Float(offsetY))
        return nil
    }

    // Steering scripted actions
    reg.register(name: .seek) { context, args in
        guard let targetPos = args[.targetPosition], case let .vec3(x, y, z) = targetPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal
        else {
            Logger.log(message: "[USC] seek action failed: missing args")
            return nil
        }

        let targetPosition = simd_float3(x, y, z)
        let steeringForce = seek(entityId: context.entityId, targetPosition: targetPosition, maxSpeed: maxSpeed)

        // Return the steering force so scripts can use it
        return .vec3(x: steeringForce.x, y: steeringForce.y, z: steeringForce.z)
    }

    reg.register(name: .flee) { context, args in
        guard let threatPos = args[.threatPosition], case let .vec3(x, y, z) = threatPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal
        else {
            Logger.log(message: "[USC] flee action failed: missing args")
            return nil
        }

        let threatPosition = simd_float3(x, y, z)
        let steeringForce = flee(entityId: context.entityId, threatPosition: threatPosition, maxSpeed: maxSpeed)

        return .vec3(x: steeringForce.x, y: steeringForce.y, z: steeringForce.z)
    }

    reg.register(name: .arrive) { context, args in
        guard let targetPos = args[.targetPosition], case let .vec3(x, y, z) = targetPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let slowingRadiusVal = args[.slowingRadius], case let .float(slowingRadius) = slowingRadiusVal
        else {
            Logger.log(message: "[USC] arrive action failed: missing args")
            return nil
        }

        let targetPosition = simd_float3(x, y, z)
        let steeringForce = arrive(entityId: context.entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: slowingRadius)

        return .vec3(x: steeringForce.x, y: steeringForce.y, z: steeringForce.z)
    }

    reg.register(name: .pursuit) { context, args in
        guard let targetEntityName = args[.targetEntity], case let .string(entityName) = targetEntityName,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal
        else {
            Logger.log(message: "[USC] pursuit action failed: missing args")
            return nil
        }

        guard let targetEntity = findEntity(name: entityName) else {
            Logger.log(message: "[USC] pursuit action failed: entity '\(entityName)' not found")
            return nil
        }

        let steeringForce = pursuit(entityId: context.entityId, targetEntity: targetEntity, maxSpeed: maxSpeed)

        return .vec3(x: steeringForce.x, y: steeringForce.y, z: steeringForce.z)
    }

    reg.register(name: .evade) { context, args in
        guard let threatEntityName = args[.threatEntity], case let .string(entityName) = threatEntityName,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal
        else {
            Logger.log(message: "[USC] evade action failed: missing args")
            return nil
        }

        guard let threatEntity = findEntity(name: entityName) else {
            Logger.log(message: "[USC] evade action failed: entity '\(entityName)' not found")
            return nil
        }

        let steeringForce = evade(entityId: context.entityId, threatEntity: threatEntity, maxSpeed: maxSpeed)

        return .vec3(x: steeringForce.x, y: steeringForce.y, z: steeringForce.z)
    }

    // High-level steering behaviors (apply force directly, no return value)

    reg.register(name: .steerSeek) { context, args in
        guard let targetPos = args[.targetPosition], case let .vec3(x, y, z) = targetPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let deltaTimeVal = args[.deltaTime], case let .float(deltaTime) = deltaTimeVal
        else {
            Logger.log(message: "[USC] steerSeek action failed: missing args")
            return nil
        }

        let turnSpeed = (args[.turnSpeed].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)
        let weight = (args["weight"].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)

        let targetPosition = simd_float3(x, y, z)
        steerSeek(entityId: context.entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, deltaTime: deltaTime, turnSpeed: turnSpeed, weight: weight)

        return nil // Applies force directly
    }

    reg.register(name: .steerArrive) { context, args in
        guard let targetPos = args[.targetPosition], case let .vec3(x, y, z) = targetPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let slowingRadiusVal = args[.slowingRadius], case let .float(slowingRadius) = slowingRadiusVal,
              let deltaTimeVal = args[.deltaTime], case let .float(deltaTime) = deltaTimeVal
        else {
            Logger.log(message: "[USC] steerArrive action failed: missing args")
            return nil
        }

        let turnSpeed = (args[.turnSpeed].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)

        let targetPosition = simd_float3(x, y, z)
        steerArrive(entityId: context.entityId, targetPosition: targetPosition, maxSpeed: maxSpeed, slowingRadius: slowingRadius, deltaTime: deltaTime, turnSpeed: turnSpeed)

        return nil // Applies force directly
    }

    reg.register(name: .steerFlee) { context, args in
        guard let threatPos = args[.threatPosition], case let .vec3(x, y, z) = threatPos,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let deltaTimeVal = args[.deltaTime], case let .float(deltaTime) = deltaTimeVal
        else {
            Logger.log(message: "[USC] steerFlee action failed: missing args")
            return nil
        }

        let turnSpeed = (args[.turnSpeed].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)

        let threatPosition = simd_float3(x, y, z)
        steerFlee(entityId: context.entityId, threatPosition: threatPosition, maxSpeed: maxSpeed, deltaTime: deltaTime, turnSpeed: turnSpeed)

        return nil // Applies force directly
    }

    reg.register(name: .steerPursuit) { context, args in
        guard let targetEntityName = args[.targetEntity], case let .string(entityName) = targetEntityName,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let deltaTimeVal = args[.deltaTime], case let .float(deltaTime) = deltaTimeVal
        else {
            Logger.log(message: "[USC] steerPursuit action failed: missing args")
            return nil
        }

        guard let targetEntity = findEntity(name: entityName) else {
            Logger.log(message: "[USC] steerPursuit action failed: entity '\(entityName)' not found")
            return nil
        }

        let turnSpeed = (args[.turnSpeed].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)

        steerPursuit(entityId: context.entityId, targetEntity: targetEntity, maxSpeed: maxSpeed, deltaTime: deltaTime, turnSpeed: turnSpeed)

        return nil // Applies force directly
    }

    reg.register(name: .steerFollowPath) { _, _ in
        // Note: path needs to be stored as component property or in context
        // For now, this is a placeholder - paths need special handling
        Logger.log(message: "[USC] steerFollowPath not yet implemented - requires path handling")
        return nil
    }

    reg.register(name: .orbit) { context, args in
        guard let centerPos = args[.centerPosition], case let .vec3(x, y, z) = centerPos,
              let radiusVal = args[.radius], case let .float(radius) = radiusVal,
              let maxSpeedVal = args[.maxSpeed], case let .float(maxSpeed) = maxSpeedVal,
              let deltaTimeVal = args[.deltaTime], case let .float(deltaTime) = deltaTimeVal
        else {
            Logger.log(message: "[USC] orbit action failed: missing args")
            return nil
        }

        let turnSpeed = (args[.turnSpeed].flatMap { if case let .float(f) = $0 { return f } else { return nil } }) ?? Float(1.0)

        let centerPosition = simd_float3(x, y, z)
        orbit(entityId: context.entityId, centerPosition: centerPosition, radius: radius, maxSpeed: maxSpeed, deltaTime: deltaTime, turnSpeed: turnSpeed)

        return nil // Applies directly
    }
}
