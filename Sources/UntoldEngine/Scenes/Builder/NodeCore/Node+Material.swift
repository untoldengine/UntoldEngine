//
//  Node+Material.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
import SwiftUI

@MainActor
public protocol NodeMaterial: NodeProtocol {}

@MainActor
public extension NodeMaterial {
    func materialData(
        roughness: Float = 0,
        metallic: Float = 0,
        emissive: (Float, Float, Float) = (0, 0, 0),
        baseColor: (Float, Float, Float, Float) = (0, 0, 0, 0),
        baseColorResource: String? = nil,
        roughnessResource: String? = nil,
        metallicResource: String? = nil,
        normalResource: String? = nil,
        heightResource: String? = nil
    ) -> Self {
        updateMaterialColor(entityId: entityID, color: colorFromSimd(simd_float4(baseColor.0, baseColor.1, baseColor.2, baseColor.3)))
        updateMaterialRoughness(entityId: entityID, roughness: roughness)
        updateMaterialMetallic(entityId: entityID, metallic: metallic)
        updateMaterialEmmisive(entityId: entityID, emmissive: simd_float3(emissive.0, emissive.1, emissive.2))

        func updateMaterialResource(_ resource: String?, _ type: TextureType) {
            if let r = resource, let url = LoadingSystem.shared.resourceURL(forResource: r.filename, withExtension: r.extensionName) {
                updateMaterialTexture(entityId: entityID, textureType: type, path: url)
            }
        }

        updateMaterialResource(baseColorResource, .baseColor)
        updateMaterialResource(roughnessResource, .roughness)
        updateMaterialResource(metallicResource, .metallic)
        updateMaterialResource(normalResource, .normal)
        updateMaterialResource(heightResource, .height)

        return self
    }

    func baseColor(_ red: Float, _ green: Float, _ blue: Float, _ alpha: Float = 1.0) -> Self {
        updateMaterialColor(entityId: entityID, color: colorFromSimd(simd_float4(red, green, blue, alpha)))
        return self
    }

    func roughness(_ value: Float) -> Self {
        updateMaterialRoughness(entityId: entityID, roughness: value)
        return self
    }

    func metallic(_ value: Float) -> Self {
        updateMaterialMetallic(entityId: entityID, metallic: value)
        return self
    }

    func emissive(_ red: Float, _ green: Float, _ blue: Float) -> Self {
        updateMaterialEmmisive(entityId: entityID, emmissive: simd_float3(red, green, blue))
        return self
    }
}
