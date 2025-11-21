//
//  USCScripting.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/20/25.
//
import Foundation

public func initScriptingSystem() {
    registerCoreMathActions()
    registerCoreGamePlayActions()
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

    /* Example on how you can register your own math function. Use these as reference */
    /*
     reg.register(name: "Math.addVec3") { _, args in
         guard
             let a = args["a"], case let .vec3(ax, ay, az) = a,
             let b = args["b"], case let .vec3(bx, by, bz) = b
         else { return nil }

         return .vec3(x: ax + bx, y: ay + by, z: az + bz)
     }

     reg.register(name: "Math.scaleVec3") { _, args in
         guard
             let v = args["v"], case let .vec3(x, y, z) = v,
             let s = args["s"], case let .float(scalar) = s
         else { return nil }

         return .vec3(x: x * scalar, y: y * scalar, z: z * scalar)
     }

     reg.register(name: "Math.lengthVec3") { _, args in
         guard let v = args["v"], case let .vec3(x, y, z) = v else {
             return nil
         }
         return .float(sqrt(x * x + y * y + z * z))
     }
      */
}

/*
 In USC script, you can now do this:

 s.onUpdate()
  .callAction("Gameplay.jump", args: ["jumpStrength"])

 */
private func registerCoreGamePlayActions() {
    let reg = USCActionRegistry.shared

    reg.register(name: "Gameplay.jump") { _, args in
        guard let strength = args["strength"],
              case let .float(jumpForce) = strength
        else { return nil }

        // Implement apply upward force
        // applyUpwardForce(entityId: context.entityId, magnitude: jumpForce)
        return nil
    }

    reg.register(name: "Gameplay.moveForward") { _, args in
        guard let speed = args["speed"],
              case let .float(v) = speed
        else { return nil }

        // Implement apply forward force
        // applyForwardForce(entityId: context.entityId, magnitude: v)
        return nil
    }
}
