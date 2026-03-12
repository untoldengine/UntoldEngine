//
//  UntoldRendererConfig.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
    @MainActor
    static var `default`: UntoldRendererConfig {
        UntoldRendererConfig(
            initPipelineBlocks: DefaultPipeLines(),
            updateRenderingSystemCallback: { view in
                UpdateRenderingSystem(in: view)
            },
            updateXRRenderingSystemCallback: { ctx in
                switch ctx {
                case let .view(v):
                    Task { @MainActor in
                        UpdateRenderingSystem(in: v)
                    }
                case let .xr(cb, desc):
                    UpdateXRRenderingSystem(commandBuffer: cb, passDescriptor: desc)
                }
            }
        )
    }
}
