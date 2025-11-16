//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import MetalKit

public struct UntoldRendererConfig {
    var metalView: MTKView?
    var initRenderPipelineBlocks: [(RenderPipelineType, RenderPipelineInitBlock)]
    var updateRenderingSystemCallback: UpdateRenderingSystemCallback

    var updateXRRenderingSystemCallback: UpdateXRRenderingSystemCallback?

    public init(
        metalView: MTKView? = nil,
        initPipelineBlocks: [(RenderPipelineType, RenderPipelineInitBlock)],
        updateRenderingSystemCallback: @escaping UpdateRenderingSystemCallback,
        updateXRRenderingSystemCallback: UpdateXRRenderingSystemCallback? = nil
    ) {
        self.metalView = metalView
        initRenderPipelineBlocks = initPipelineBlocks
        self.updateRenderingSystemCallback = updateRenderingSystemCallback
        self.updateXRRenderingSystemCallback = updateXRRenderingSystemCallback
    }
}

public extension UntoldRendererConfig {
    static var `default`: UntoldRendererConfig {
        UntoldRendererConfig(
            initPipelineBlocks: DefaultPipeLines(),
            updateRenderingSystemCallback: { view in
                UpdateRenderingSystem(in: view)
            },
            updateXRRenderingSystemCallback: { ctx in
                switch ctx {
                case let .view(v):
                    UpdateRenderingSystem(in: v)
                case let .xr(cb, desc):
                    UpdateXRRenderingSystem(commandBuffer: cb, passDescriptor: desc)
                }
            }
        )
    }
    
    static var gaussiansplats: UntoldRendererConfig {
        UntoldRendererConfig(
            initPipelineBlocks: GaussianSplatPipeLines(),
            updateRenderingSystemCallback: { view in
                UpdateGaussianRenderingSystem(in: view)
            }
        )
    }
}
