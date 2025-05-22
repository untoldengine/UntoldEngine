//  HotReloadingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 3/12/24.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import CShaderTypes
import Foundation
import MetalKit

struct ShaderPipelineConfig {
    let pipelineName: String
    let vertexFunctionName: String
    let fragmentFunctionName: String
    let vertexDescriptor: MTLVertexDescriptor?
    let colorPixelFormats: [MTLPixelFormat]
    let depthPixelFormat: MTLPixelFormat?
}

let pipelineConfigs: [String: ShaderPipelineConfig] = [
    "model": ShaderPipelineConfig(
        pipelineName: "model",
        vertexFunctionName: "vertexModelShader",
        fragmentFunctionName: "fragmentModelShader",
        vertexDescriptor: MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.model),
        colorPixelFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float], depthPixelFormat: renderInfo.depthPixelFormat
    ),
]

func reloadPipeline(named pipelineName: String, with library: MTLLibrary, pipe: inout RenderPipeline) {
    guard let config = pipelineConfigs[pipelineName] else {
        print("No pipeline config found for: \(pipelineName)")
        return
    }

    guard let vertexFunction = library.makeFunction(name: config.vertexFunctionName),
          let fragmentFunction = library.makeFunction(name: config.fragmentFunctionName)
    else {
        print("Failed to load functions for pipeline: \(pipelineName)")
        return
    }

    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = vertexFunction
    descriptor.fragmentFunction = fragmentFunction
    descriptor.vertexDescriptor = config.vertexDescriptor

    for (index, format) in config.colorPixelFormats.enumerated() {
        descriptor.colorAttachments[index].pixelFormat = format
    }

    if let depthFormat = config.depthPixelFormat {
        descriptor.depthAttachmentPixelFormat = depthFormat
    }

    do {
        let newPipeline = try renderInfo.device.makeRenderPipelineState(descriptor: descriptor)
        let depthState = MTLDepthStencilDescriptor()
        depthState.depthCompareFunction = .lessEqual
        depthState.isDepthWriteEnabled = true

        let newDepthState = renderInfo.device.makeDepthStencilState(descriptor: depthState)

        // Update your pipeline storage

        pipe.pipelineState = newPipeline
        pipe.depthState = newDepthState
        print("✅ Reloaded pipeline: \(pipelineName)")
    } catch {
        print("❌ Failed to create pipeline state: \(error)")
    }
}

func updateShadersAndPipeline() {
    if let library = loadMetalLibraryFromUserSelection() {
        reloadPipeline(named: "model", with: library, pipe: &modelPipeline)
    }
}

func selectMetalLibraryFile() -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.prompt = "Select .metallib file"
    openPanel.allowedFileTypes = ["metallib"]
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.canCreateDirectories = false
    openPanel.canChooseFiles = true

    let response = openPanel.runModal()
    if response == .OK, let url = openPanel.url {
        return url
    } else {
        return nil
    }
}

func loadMetalLibraryFromUserSelection() -> MTLLibrary? {
    guard let fileURL = selectMetalLibraryFile() else {
        print("User did not select a file")
        return nil
    }

    do {
        let library = try renderInfo.device.makeLibrary(URL: fileURL)
        return library
    } catch {
        print("❌ Failed to load the metallib file: \(error)")
        return nil
    }
}
