//
//  PipelineManager.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 24/9/25.
//

public final class PipelineManager
{
    // Thread-safe shared instance
    public static let shared: PipelineManager = { return PipelineManager() }()
    
    var _renderPipelinesByType: [RenderPipelineType: RenderPipeline] = [:]
    public var renderPipelinesByType: [RenderPipelineType: RenderPipeline] { _renderPipelinesByType }

    @MainActor
    func initRenderPipelines( _ pipelines: [(RenderPipelineType, RenderPipelineInitBlock)] ) {
        for (type, initBlock) in pipelines {
            _renderPipelinesByType[type] = initBlock()
        }
    }
}
