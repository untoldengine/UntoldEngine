//
//  EditorFuncUtils.swift
//
//
//  Created by Harold Serrano on 8/1/25.
//

import Foundation
import SwiftUI
import UntoldEngine


func bindingForWrapMode(entityId: EntityID, textureType: TextureType, onChange: @escaping () -> Void) -> Binding<WrapMode> {
    Binding<WrapMode>(
        get: {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  let material = renderComponent.mesh[0].submeshes[0].material
            else {
                return .clampToEdge // fallback
            }

            switch textureType {
            case .baseColor:
                return material.baseColor.wrapMode
            case .normal:
                return material.normal.wrapMode
            case .roughness:
                return material.roughness.wrapMode
            case .metallic:
                return material.metallic.wrapMode
            }
        },
        set: { newValue in
            updateTextureSampler(entityId: entityId, textureType: textureType, wrapMode: newValue)
            onChange()
        }
    )
}

func bindingForSTScale(entityId: EntityID, onChange: @escaping () -> Void) -> Binding<Float> {
    Binding<Float>(
        get: {
            guard let rc = scene.get(component: RenderComponent.self, for: entityId),
                  let material = rc.mesh[0].submeshes[0].material
            else {
                return 1.0
            }
            return material.stScale
        },
        set: { newValue in
            updateMaterialSTScale(entityId: entityId, stScale: newValue)
            onChange()
        }
    )
}

func bindingForMaterialRoughness(entityId: EntityID, onChange: @escaping () -> Void) -> Binding<Float> {
    Binding<Float>(
        get: {
            getMaterialRoughness(entityId: entityId)
        },
        set: { newValue in
            updateMaterialRoughness(entityId: entityId, roughness: newValue)
            onChange()
        }
    )
}
