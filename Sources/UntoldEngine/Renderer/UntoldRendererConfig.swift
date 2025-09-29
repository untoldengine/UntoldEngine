//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 24/9/25.
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
