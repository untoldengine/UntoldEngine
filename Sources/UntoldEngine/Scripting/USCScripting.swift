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

/*
 In USC Script you can do something like this:
 let script = buildScript(name: "CombineVelocity") { s in
     s.onUpdate()
      // read two direction vectors from components
      .getProperty("moveDirection", as: "moveDir")
      .getProperty("externalForceDir", as: "externalDir")

      // sum = moveDir + externalDir
      .callAction("Math.addVec3",
                  args: ["a", "b"],   // names expected by the action
                  result: "combinedDir")

      // write result back into velocity
      .setProperty("velocity", toVariable: "combinedDir")
 }

 */
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

/*
 In USC script, you can now do this:

 s.onUpdate()
  .callAction("Gameplay.jump", args: ["jumpStrength"])

 */
private func registerCoreGamePlayActions() {
    let reg = USCActionRegistry.shared

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
