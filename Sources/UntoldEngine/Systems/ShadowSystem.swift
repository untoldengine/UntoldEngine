//
//  ShadowSystem.swift
//  Untold Engine 
//
//  Created by Harold Serrano on 6/6/24.
//

import Foundation
import simd

struct ShadowSystem {

  init() {

  }

  mutating func updateViewFromSunPerspective() {

    //Scene's center
    let targetPoint: simd_float3 = simd_float3(0.0, 0.0, 0.0)
    let width: Float = 50.0
    let height: Float = 50.0

    if let directionalLightID = lightingSystem.activeDirectionalLightID,
      let directionalLight: DirectionalLight = lightingSystem.getDirectionalLight(
        entityID: directionalLightID)
    {

      let lightPosition = targetPoint + normalize(directionalLight.direction) * 100

      let viewMatrix: simd_float4x4 = matrix_look_at_right_hand(
        lightPosition, simd_float3(0.0, 0.0, 0.0), simd_float3(0.0, 1.0, 0.0))

      dirLightSpaceMatrix = simd_mul(
        matrix_ortho_right_hand(
          -width / 2.0, width / 2.0, -height / 2.0, height / 2.0, near, farZ: far), viewMatrix)

    } else {
      dirLightSpaceMatrix = nil
    }

  }

  //data

  var dirLightSpaceMatrix: simd_float4x4!

}

