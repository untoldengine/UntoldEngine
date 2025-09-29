//
//  MeshShaderPipeline.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 29/9/25.
//

import MetalKit


public struct MeshShaderPipeline
{
    var depthState: MTLDepthStencilState?
    var pipelineState: MTLRenderPipelineState?
    var passDescriptor: MTLRenderPassDescriptor?
    var uniformSpaceBuffer: MTLBuffer?
    var success: Bool = false
}
