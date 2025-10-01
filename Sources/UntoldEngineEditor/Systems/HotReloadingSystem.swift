//  HotReloadingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//  Copyright © 2024 Untold Engine Studios. All rights reserved.
//

import CShaderTypes
import Foundation
import MetalKit
import UniformTypeIdentifiers
import UntoldEngine

struct ShaderPipelineConfig {
    let pipelineName: String
    let vertexFunctionName: String
    let fragmentFunctionName: String
    let vertexDescriptor: MTLVertexDescriptor?
    let colorPixelFormats: [MTLPixelFormat]
    let depthPixelFormat: MTLPixelFormat?
    let depthComparison: MTLCompareFunction?
    let depthEnabled: Bool?
    let blendEnabled: Bool?
}

let pipelineConfigs: [String: ShaderPipelineConfig] = [
    "model": ShaderPipelineConfig(
        pipelineName: "model",
        vertexFunctionName: "vertexModelShader",
        fragmentFunctionName: "fragmentModelShader",
        vertexDescriptor: MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.model),
        colorPixelFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthPixelFormat: renderInfo.depthPixelFormat,
        depthComparison: .lessEqual,
        depthEnabled: true,
        blendEnabled: false
    ),

    "tonemapping": ShaderPipelineConfig(
        pipelineName: "Tone-mapping Pipeline",
        vertexFunctionName: "vertexTonemappingShader",
        fragmentFunctionName: "fragmentTonemappingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorPixelFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthPixelFormat: renderInfo.depthPixelFormat,
        depthComparison: nil,
        depthEnabled: false,
        blendEnabled: false

    ),

    "blur": ShaderPipelineConfig(
        pipelineName: "Blur Pipeline",
        vertexFunctionName: "vertexBlurShader",
        fragmentFunctionName: "fragmentBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorPixelFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthPixelFormat: renderInfo.depthPixelFormat,
        depthComparison: nil,
        depthEnabled: false,
        blendEnabled: false
    ),

    "colorgrading": ShaderPipelineConfig(
        pipelineName: "Color Grading Pipeline",
        vertexFunctionName: "vertexColorGradingShader",
        fragmentFunctionName: "fragmentColorGradingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorPixelFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthPixelFormat: renderInfo.depthPixelFormat,
        depthComparison: nil,
        depthEnabled: false,
        blendEnabled: false
    ),
]

func reloadPipeline(named pipelineName: String, with library: MTLLibrary) {
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
        let attachment = descriptor.colorAttachments[index]
        attachment?.pixelFormat = format
        if config.blendEnabled == true {
            attachment?.isBlendingEnabled = true
            attachment?.rgbBlendOperation = .add
            attachment?.sourceRGBBlendFactor = .sourceAlpha
            attachment?.destinationRGBBlendFactor = .one
            attachment?.alphaBlendOperation = .add
            attachment?.sourceAlphaBlendFactor = .sourceAlpha
            attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        }
    }

    if let depthFormat = config.depthPixelFormat {
        descriptor.depthAttachmentPixelFormat = depthFormat
    }

    do {
        let newPipeline = try renderInfo.device.makeRenderPipelineState(descriptor: descriptor)
        let depthState = MTLDepthStencilDescriptor()

        if let depthCompare = config.depthComparison {
            depthState.depthCompareFunction = depthCompare
        }

        if let depthEnabled = config.depthEnabled {
            depthState.isDepthWriteEnabled = depthEnabled
        }

        let newDepthState = renderInfo.device.makeDepthStencilState(descriptor: depthState)

        // Update your pipeline storage

        guard var pipe = PipelineManager.shared.renderPipelinesByType[.model] else {
            print("Failed to get pipeline for: \(pipelineName)")
            return
        }

        // TODO: Check if the value actually changes or becasue its a struct we are just copy by value and it's not changing at all so we had to re-assign the pipe to the manager
        pipe.pipelineState = newPipeline
        pipe.depthState = newDepthState
        PipelineManager.shared.update(rendererPipeLine: pipe, forType: .model)
        print("✅ Reloaded pipeline: \(pipelineName)")
    } catch {
        print("❌ Failed to create pipeline state: \(error)")
    }
}

func updateShadersAndPipeline() {
    #if os(macOS)
        if let library = loadMetalLibraryFromUserSelection() {
            reloadPipeline(named: "model", with: library)
        }
    #endif
}

func selectMetalLibraryFile() -> URL? {
    // We can fix this up  later. The hot-reload system will only work for mac.
    let openPanel = NSOpenPanel()
    openPanel.prompt = "Select .metallib file"
    openPanel.allowedContentTypes = [
        UTType(filenameExtension: "metallib")!,
    ]
    openPanel.allowsMultipleSelection = false
    openPanel.canChooseDirectories = false
    openPanel.canCreateDirectories = false
    openPanel.canChooseFiles = true

    let response = openPanel.runModal()
    if response == .OK, let url = openPanel.url { return url }

    return nil
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
