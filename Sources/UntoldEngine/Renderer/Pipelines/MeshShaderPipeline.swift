//
//  MeshShaderPipeline.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
