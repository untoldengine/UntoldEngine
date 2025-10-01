//
//  ShadowSystem.swift
//  Untold Engine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
        let lightComponentID = getComponentId(for: DirectionalLightComponent.self)
        let localTransformComponentID = getComponentId(for: LocalTransformComponent.self)

        let entities = queryEntitiesWithComponentIds([lightComponentID, localTransformComponentID], in: scene)

        // clear the space matrix on every pass
        dirLightSpaceMatrix = nil

        for entity in entities {
            guard scene.get(component: DirectionalLightComponent.self, for: entity) != nil else {
                handleError(.noDirLightComponent)
                continue
            }

            let forward = getForwardAxisVector(entityId: entity) * -1.0

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
