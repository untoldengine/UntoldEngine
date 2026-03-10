//
//  PipelineManager.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

public final class PipelineManager {
    /// Thread-safe shared instance
    public static let shared: PipelineManager = .init()

    var _renderPipelinesByType: [RenderPipelineType: RenderPipeline] = [:]
    public var renderPipelinesByType: [RenderPipelineType: RenderPipeline] {
        _renderPipelinesByType
    }

    func initRenderPipelines(_ pipelines: [(RenderPipelineType, RenderPipelineInitBlock)]) {
        for (type, initBlock) in pipelines {
            _renderPipelinesByType[type] = initBlock()
        }
    }

    // TODO: Make it thread safe but without too much blocking
    public func update(rendererPipeLine: RenderPipeline, forType type: RenderPipelineType) {
        _renderPipelinesByType[type] = rendererPipeLine
    }
}
