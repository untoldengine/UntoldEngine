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
    
    func initRenderPipelines( _ pipelines: [(RenderPipelineType, RenderPipelineInitBlock)] ) {
        for (type, initBlock) in pipelines {
            _renderPipelinesByType[type] = initBlock()
        }
    }
    
    // TODO: Make it thread safe but without too much blocking
    public func update( rendererPipeLine: RenderPipeline, forType type: RenderPipelineType ) {
        _renderPipelinesByType[type] = rendererPipeLine
    }
}
