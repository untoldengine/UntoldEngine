//
//  ComputePipelines.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import MetalKit

public struct ComputePipeline {
    public var pipelineState: MTLComputePipelineState?
    public var success: Bool = false
    public var name: String?

    public init() {}
}

public func CreateComputePipeline(
    into pipeline: inout ComputePipeline,
    device: MTLDevice,
    library: MTLLibrary,
    functionName: String,
    pipelineName: String
) {
    do {
        let built = try buildComputePipeline(
            device: device,
            library: library,
            functionName: functionName,
            pipelineName: pipelineName
        )
        pipeline.pipelineState = built.pipelineState
        pipeline.name = built.name
        pipeline.success = built.success
    } catch PipelineCreationError.missingFunction {
        pipeline.name = pipelineName
        handleError(.kernelCreationFailed, pipelineName)
    } catch {
        pipeline.name = pipelineName
        pipeline.success = false
        handleError(.pipelineStateCreationFailed, "\(pipelineName): \(failureReason(for: error))")
    }
}

/// Builds a compute pipeline, throwing a `PipelineCreationError` that says why Metal
/// could not create it. `CreateComputePipeline` wraps this for callers that only
/// need the success flag.
func buildComputePipeline(
    device: MTLDevice,
    library: MTLLibrary,
    functionName: String,
    pipelineName: String
) throws -> ComputePipeline {
    guard let function = library.makeFunction(name: functionName) else {
        throw PipelineCreationError.missingFunction(name: functionName)
    }

    let state: MTLComputePipelineState
    do {
        state = try device.makeComputePipelineState(function: function)
    } catch {
        throw PipelineCreationError.pipelineStateCreationFailed(underlying: error)
    }

    var pipeline = ComputePipeline()
    pipeline.pipelineState = state
    pipeline.name = pipelineName
    pipeline.success = true
    return pipeline
}
