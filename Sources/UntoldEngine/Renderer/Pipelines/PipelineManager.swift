//
//  PipelineManager.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

public final class PipelineManager {
    // Thread-safe shared instance
    public static let shared: PipelineManager = .init()

    var _renderPipelinesByType: [RenderPipelineType: RenderPipeline] = [:]
    public var renderPipelinesByType: [RenderPipelineType: RenderPipeline] { _renderPipelinesByType }

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
