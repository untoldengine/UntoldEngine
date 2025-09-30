//
//  RendererInitializer.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 29/9/25.
//

import MetalKit
import UntoldEngine
import CShaderTypes


func createGizmoVertexDescriptor() -> MTLVertexDescriptor? {
    // tell the gpu how data is organized
    vertexDescriptor.gizmo = MDLVertexDescriptor()

    vertexDescriptor.gizmo.attributes[Int(modelPassVerticesIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributePosition,
        format: .float4,
        offset: 0,
        bufferIndex: Int(modelPassVerticesIndex.rawValue)
    )

    vertexDescriptor.gizmo.layouts[Int(modelPassVerticesIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    guard let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.gizmo) else {
        return nil
    }

    return vertexDescriptor
}

func createDebugVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}
