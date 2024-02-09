//
//  EditorComponents.swift
//  UntoldEditor
//
//  Created by Harold Serrano on 1/30/24.
//

import Foundation
import simd
import MetalKit

//EDITOR
struct EditorVoxelPool{

    //voxel buffer pool
    var originBuffer:MTLBuffer?
    var vertexBuffer:MTLBuffer? //float
    var normalBuffer:MTLBuffer?
    var indicesBuffer:MTLBuffer? //int
    var colorBuffer:MTLBuffer?
    var baseColorBuffer:MTLBuffer?
    var voxelVisible:MTLBuffer?
    
    //material property
    var roughnessBuffer:MTLBuffer?
    var metallicBuffer:MTLBuffer?
}

struct EditorBufferResources{
    var voxelUniforms:MTLBuffer?
    var quadVerticesBuffer:MTLBuffer?
    var quadTexCoordsBuffer:MTLBuffer?
    var quadIndexBuffer:MTLBuffer?
    
    //ray intersection
    var intersectionTest:MTLBuffer?
    var tIntersectionParam:MTLBuffer?
    var pointIntersect:MTLBuffer?
    var blockIntersectedGuid:MTLBuffer?
    var voxelRayUniform:MTLBuffer?
    
    
    var planeRayIntersectionResult:MTLBuffer?
    var planeRayIntersectionPoint:MTLBuffer?
    var planeRayIntersectionTime:MTLBuffer?
    
    //feedback voxel
    var ghostVoxelUniforms:MTLBuffer?
    var ghostVoxelBuffer:MTLBuffer?
    var ghostVoxelIndicesBuffer:MTLBuffer?
    
    //plane vertices
    var planeBuffer:MTLBuffer?
    var planeIndicesBuffer:MTLBuffer?
    var planeUniforms:MTLBuffer?
    
    //serialize buffer
    var serializeBuffer:MTLBuffer?
    var voxelSerializeCountBuffer:MTLBuffer?
    
    //box guid intersection
    var boxGuidIntersectionBuffer:MTLBuffer?
    var boxGuidIntersectionCountBuffer:MTLBuffer?
    
    //normal plane compute
    var normalPlaneTIntersectionParam:MTLBuffer?
    var normalPlanePointIntersect:MTLBuffer?
    var normalPlaneIntersectionTest:MTLBuffer?
}

struct EditorTextureResources{
    var environmentTexture:MTLTexture?
    var irradianceMap:MTLTexture?
    var specularMap:MTLTexture?
    var brdfMap:MTLTexture?
}

struct UserOperation{
    var guid:UInt
    var neighborGuid:UInt
    var voxelAction:ActiveState
    var color:simd_float3
    var previousColor:simd_float3
    var normal:simd_float3
    var action:Bool
    var floor:Bool
}

struct IntersectionInfo{
    var guid:UInt!
    var guidEnd:UInt!
    var normal:simd_float3!
    var didRayIntersectPlane:Bool!
    var guidArray:[VoxelData]!
}

struct LimitedStack<Element> {
    private var elements: [Element] = []
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    mutating func append(_ element: Element) {
        if elements.count >= maxSize {
            elements.removeFirst()
        }
        elements.append(element)
    }

    mutating func popLast() -> Element? {
        guard !elements.isEmpty else {
            return nil
        }
        return elements.removeLast()
    }

    func top() -> Element? {
        return elements.last
    }

    func isEmpty() -> Bool {
        return elements.isEmpty
    }

    func count() -> Int {
        return elements.count
    }
    
    mutating func clear() {
        elements.removeAll()
    }
}
