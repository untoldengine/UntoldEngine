//
//  ComputePipelines.swift
//  UntoldEngine
//
//  Created by Javier Segura Perez on 24/9/25.
//

import MetalKit

public struct ComputePipeline
{
    public var pipelineState: MTLComputePipelineState? = nil
    public var success: Bool = false
    public var name: String? = nil
    
    public init() {}
}

public func CreateComputePipeline(
    into pipeline: inout ComputePipeline,
    device: MTLDevice,
    library: MTLLibrary,
    functionName: String,
    pipelineName: String
) {
    // Create kernel
    guard let function = library.makeFunction(name: functionName) else {
        pipeline.name = pipelineName
        handleError(.kernelCreationFailed, pipelineName)
        return
    }

    // Create pipeline
    do {
        let state = try device.makeComputePipelineState(function: function)

        pipeline.pipelineState = state
        pipeline.name = pipelineName
        pipeline.success = true
    } catch {
        pipeline.name = pipelineName
        pipeline.success = false
        handleError(.pipelineStateCreationFailed, pipelineName)
        return
    }
}
