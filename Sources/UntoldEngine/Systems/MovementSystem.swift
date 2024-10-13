
//
//  MovementSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 2/23/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import Foundation
import simd

public struct MovementSystem {

  var movementSpeed: Float = 5.0

  public func update(_ entityId: EntityID, _ deltaTime: Float) {

    if gameMode == false {
      return
    }
    //get the transform for the entity
    guard let t = scene.get(component: Transform.self, for: entityId) else {
      return
    }

    var forward: simd_float3 = simd_float3(
      t.localSpace.columns.2.x,
      t.localSpace.columns.2.y,
      t.localSpace.columns.2.z)
    forward = normalize(forward)

    var position: simd_float3 = simd_float3(
      t.localSpace.columns.3.x,
      t.localSpace.columns.3.y,
      t.localSpace.columns.3.z)

    let up: simd_float3 = simd_float3(0.0, 1.0, 0.0)
    var right: simd_float3 = cross(forward, up)
    right = normalize(right)

    //rotate entity
    if inputSystem.mouseDeltaX != 0 && inputSystem.mouseActive {
      let yaw = inputSystem.mouseDeltaX * 20.0 * deltaTime

      rotateBy(entityId, yaw, up)
    }

    if inputSystem.mouseDeltaY != 0 && inputSystem.mouseActive {
      let pitch = inputSystem.mouseDeltaY * 20.0 * deltaTime

      rotateBy(entityId, pitch, right)
    }

    //translate entity
    if inputSystem.keyState.wPressed {
      //move forward
      position += forward * movementSpeed * deltaTime

    }

    if inputSystem.keyState.sPressed {
      //move backward
      position += -forward * movementSpeed * deltaTime
    }

    if inputSystem.keyState.aPressed {
      //move left
      position += -right * movementSpeed * deltaTime
    }

    if inputSystem.keyState.dPressed {
      //move right
      position += right * movementSpeed * deltaTime
    }

    t.localSpace.columns.3.x = position.x
    t.localSpace.columns.3.y = position.y
    t.localSpace.columns.3.z = position.z

  }
}
