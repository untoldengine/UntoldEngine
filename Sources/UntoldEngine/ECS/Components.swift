
//
//  Components.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation
import Metal
import MetalKit
import simd

public class Transform: Component {
  var localSpace: simd_float4x4
  var xRot: Float
  var yRot: Float
  var zRot: Float

  var minBox: simd_float3!
  var maxBox: simd_float3!

  var scale: simd_float3!

  public required init() {
    // Initialize default values
    localSpace = matrix4x4Identity()
    xRot = 0.0
    yRot = 0.0
    zRot = 0.0
  }
}

public class Render: Component {
  var spaceUniform: MTLBuffer!
  var mesh: Mesh!

  public required init() {

  }
}

public struct DirectionalLight {
  var direction: simd_float3 = simd_float3(0.0, 1.0, 0.0)
  var color: simd_float3?
  var intensity: Float = 1.0
}

public struct PointLight {
  var position: simd_float3 = simd_float3(0.0, 0.0, 0.0)
  var color: simd_float3 = simd_float3(0.0, 0.0, 0.0)
  var attenuation: simd_float4 = simd_float4(1.0, 0.7, 1.8, 0.0)  //constant, linera, quadratic -> (x, y, z, max range)
  var intensity: Float
  var radius: Float
}

public struct AreaLight {
  var position: simd_float3 = simd_float3(0.0, 0.0, 0.0)  // Center position of the area light
  var color: simd_float3 = simd_float3(1.0, 1.0, 1.0)  // Light color
  var intensity: Float = 1.0  // Light intensity
  //    var width: Float = 1.0                                   // Width of the area light
  //    var height: Float = 1.0                                  // Height of the area light
  //    var forward: simd_float3 = simd_float3(0.0, -1.0, 0.0)    // Normal vector of the light's surface
  //    var right: simd_float3 = simd_float3(1.0, 0.0, 0.0)      // Right vector defining the surface orientation
  //    var up: simd_float3 = simd_float3(0.0, 0.0, 1.0)         // Up vector defining the surface orientation
  //var twoSided: Bool = false                               // Whether the light emits from both sides
}

public class LightComponent: Component {

  enum LightType {
    case point(PointLight)
    case directional(DirectionalLight)
    case area(AreaLight)
  }

  var lightType: LightType?

  public required init() {

  }
}

public class RayTracingComponent: Component {

  public required init() {

  }
}

public struct TransformAndRenderChecker: ComponentChecker {
  static func hasRequiredComponents(entity: EntityDesc) -> Bool {
    let transformId = getComponentId(for: Transform.self)
    let renderId = getComponentId(for: Render.self)
    return entity.mask.test(transformId) && entity.mask.test(renderId)
  }
}

public struct RayTracingComponentChecker: ComponentChecker {
  static func hasRequiredComponents(entity: EntityDesc) -> Bool {
    let transformId = getComponentId(for: Transform.self)
    let renderId = getComponentId(for: Render.self)
    let rayTracingId = getComponentId(for: RayTracingComponent.self)
    return entity.mask.test(transformId) && entity.mask.test(renderId)
      && entity.mask.test(rayTracingId)
  }
}
