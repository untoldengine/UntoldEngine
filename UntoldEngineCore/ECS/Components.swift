//
//  Components.swift
//  ECSinSwift
//
//  Created by Harold Serrano on 1/14/24.
//

import Foundation
import simd
import Metal

class Transform: Component {
    var localTransform: simd_float4x4
    
    required init() {
        // Initialize default values
        localTransform=matrix4x4Identity()
        
    }
}

class Render: Component{
    
    var entityDataSize:Int
    var indexCount:Int
    var indexOffset:Int
    var spaceUniform:MTLBuffer!
    
    required init(){
        entityDataSize=0
        indexCount=0
        indexOffset=0
    }
}

class Light: Component{
    
    var index:Int
    
    required init() {
        index=0
    }
}


struct TransformAndRenderChecker: ComponentChecker {
    static func hasRequiredComponents(entity: EntityDesc) -> Bool {
        let transformId = getComponentId(for: Transform.self)
        let renderId = getComponentId(for: Render.self)
        return entity.mask.test(transformId) && entity.mask.test(renderId)
    }
}

