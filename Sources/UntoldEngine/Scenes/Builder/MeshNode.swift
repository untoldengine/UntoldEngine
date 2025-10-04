//
//  ModelNode.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import SwiftUI
import simd

public class MeshNode: Node3D, NodeAnimations, NodeKinetics
{
    public convenience init (resource: String, entityID: EntityID? = nil, name: String? = nil) {
        self.init(resource: resource, entityID: entityID, name: name) { }
    }
    
    public convenience init (resource: String, entityID: EntityID? = nil, name: String? = nil, @SceneBuilder content: @escaping () -> [any NodeProtocol]) {
        self.init(entityID: entityID, name: name, content: content)
        
        if name == nil { setEntityName(entityId: self.entityID, name: resource) }
        
        setEntityMesh(entityId: self.entityID, filename: resource.filename, withExtension: resource.extensionName)
        registerSceneGraphComponent(entityId: self.entityID)
    }
    
    public func materialData(
        roughness: Float = 0,
        metallic:Float = 0,
        emissive:(Float, Float, Float) = (0,0,0),
        baseColor:(Float, Float, Float, Float) = (0,0,0,0),
        baseColorResource:String? = nil,
        roughnessResource:String? = nil,
        metallicResource:String? = nil,
        normalResource:String? = nil
    ) -> Self {
        
        updateMaterialColor(entityId: entityID, color: colorFromSimd(simd_float4(baseColor.0, baseColor.1, baseColor.2, baseColor.3)))
        updateMaterialRoughness(entityId: entityID, roughness: roughness)
        updateMaterialMetallic(entityId: entityID, metallic: metallic)
        updateMaterialEmmisive(entityId: entityID, emmissive: simd_float3(emissive.0, emissive.1, emissive.2))

        func updateMaterialResource( _ resource: String?, _ type: TextureType ) {
            if let r = resource, let url = LoadingSystem.shared.resourceURL(forResource: r.filename, withExtension: r.extensionName) {
                updateMaterialTexture(entityId: entityID, textureType: type, path: url)
            }
        }
        
        updateMaterialResource(baseColorResource, .baseColor)
        updateMaterialResource(roughnessResource, .roughness)
        updateMaterialResource(metallicResource, .metallic)
        updateMaterialResource(normalResource, .normal)
        
        return self
    }
}
