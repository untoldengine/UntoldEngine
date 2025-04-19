//
//  ShadowSystem.swift
//  Untold Engine
//
//  Created by Harold Serrano on 6/6/24.
//

import Foundation
import simd

struct ShadowSystem {
    init() {}

    mutating func updateViewFromSunPerspective() {
        // Scene's center
        let targetPoint = simd_float3(0.0, 0.0, 0.0)
        let width: Float = shadowMaxWidth
        let height: Float = shadowMaxHeight

        // search for the dir light entity
        let lightComponentID = getComponentId(for: LightComponent.self)
        let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

        let entities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID], in: scene)

        // clear the space matrix on every pass
        dirLightSpaceMatrix = nil

        for entity in entities {
            guard let lightComponent = scene.get(component: LightComponent.self, for: entity) else {
                handleError(.noLightComponent)
                continue
            }

            if lightComponent.lightType != .directional {
                continue
            }

            let axisOfRotation = getAxisRotations(entityId: entity)

            let rotX = matrix4x4Rotation(radians: degreesToRadians(degrees: axisOfRotation.x), axis: [1, 0, 0])
            let rotY = matrix4x4Rotation(radians: degreesToRadians(degrees: axisOfRotation.y), axis: [0, 1, 0])
            let rotZ = matrix4x4Rotation(radians: degreesToRadians(degrees: axisOfRotation.z), axis: [0, 0, 1])

            let rotationMatrix = rotZ * rotY * rotX

            let forward = normalize(simd_mul(rotationMatrix, simd_float4(0, 0, -1, 0)))

            let lightPosition = targetPoint - simd_float3(forward.x, forward.y, forward.z) * 100

            let viewMatrix: simd_float4x4 = matrix_look_at_right_hand(
                lightPosition, simd_float3(0.0, 0.0, 0.0), simd_float3(0.0, 1.0, 0.0)
            )

            dirLightSpaceMatrix = simd_mul(
                matrix_ortho_right_hand(
                    -width / 2.0, width / 2.0, -height / 2.0, height / 2.0, near, farZ: far
                ), viewMatrix
            )
        }
    }

    // data

    var dirLightSpaceMatrix: simd_float4x4!
}
