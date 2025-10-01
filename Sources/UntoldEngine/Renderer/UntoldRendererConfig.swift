//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import MetalKit

public struct UntoldRendererConfig
{
    var metalView: MTKView?
    var initRenderPipelineBlocks: [ (RenderPipelineType, RenderPipelineInitBlock) ]
    var updateRenderingSystemCallback: UpdateRenderingSystemCallback
    
    public init(
        metalView: MTKView? = nil,
        initPipelineBlocks: [(RenderPipelineType, RenderPipelineInitBlock)],
        updateRenderingSystemCallback: @escaping UpdateRenderingSystemCallback
    ) {
        self.metalView = metalView
        self.initRenderPipelineBlocks = initPipelineBlocks
        self.updateRenderingSystemCallback = updateRenderingSystemCallback
    }
}

extension UntoldRendererConfig {
    public static var `default`: UntoldRendererConfig {
        return UntoldRendererConfig(
            initPipelineBlocks: DefaultPipeLines(),
            updateRenderingSystemCallback: UpdateRenderingSystem
        )
    }
}
