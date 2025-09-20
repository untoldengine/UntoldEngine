
//
//  RenderInitializer.swift
//  Untold Engine
//
//  Created by Harold Serrano on 5/29/23.
//

import CShaderTypes
import Foundation
import MetalKit
import simd

// Helper creation functions

func createPipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexDescriptor: MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    blendEnabled: Bool = false,
    name: String
) -> RenderPipeline? {
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let depthStateDescriptor = MTLDepthStencilDescriptor()

    do {
        let vertexFunction = renderInfo.library.makeFunction(name: vertexShader)!
        pipelineDescriptor.vertexFunction = vertexFunction

        if let fragmentShader {
            let fragmentFunction = renderInfo.library.makeFunction(name: fragmentShader)!
            pipelineDescriptor.fragmentFunction = fragmentFunction
        }

        pipelineDescriptor.vertexDescriptor = vertexDescriptor

        for (index, format) in colorFormats.enumerated() {
            let attachment = pipelineDescriptor.colorAttachments[index]
            attachment?.pixelFormat = format
            if blendEnabled {
                attachment?.isBlendingEnabled = true
                attachment?.rgbBlendOperation = .add
                attachment?.sourceRGBBlendFactor = .sourceAlpha
                attachment?.destinationRGBBlendFactor = .one
                attachment?.alphaBlendOperation = .add
                attachment?.sourceAlphaBlendFactor = .sourceAlpha
                attachment?.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
        }

        pipelineDescriptor.depthAttachmentPixelFormat = depthFormat

        depthStateDescriptor.depthCompareFunction = depthCompareFunction
        depthStateDescriptor.isDepthWriteEnabled = depthEnabled

        let pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)

        return RenderPipeline(
            pipelineState: pipelineState,
            depthState: depthState,
            success: true,
            name: name
        )

    } catch {
        handleError(.pipelineStateCreationFailed, name)
        return nil
    }
}

func createComputePipeline(
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

func createBuffer<T>(
    device: MTLDevice,
    data: [T],
    options: MTLResourceOptions = .storageModeShared,
    label: String
) -> MTLBuffer? {
    guard !data.isEmpty else {
        Logger.logWarning(message: "Attempted to create buffer with empty data: \(label)")
        return nil
    }
    let buffer = device.makeBuffer(
        length: MemoryLayout<T>.stride * data.count,
        options: options
    )
    buffer?.contents().initializeMemory(as: T.self, from: data, count: data.count)
    buffer?.label = label
    return buffer
}

func createEmptyBuffer(
    device: MTLDevice,
    length: Int,
    options: MTLResourceOptions = .storageModeShared,
    label: String
) -> MTLBuffer? {
    guard length > 0 else {
        Logger.logWarning(message: "Attempted to create buffer with invalid length: \(label)")
        return nil
    }
    let buffer = device.makeBuffer(length: length, options: options)
    buffer?.label = label
    return buffer
}

func createTexture(
    device: MTLDevice,
    label: String,
    textureType: MTLTextureType = .type2D,
    pixelFormat: MTLPixelFormat,
    width: Int,
    height: Int,
    usage: MTLTextureUsage,
    storageMode: MTLStorageMode,
    mipMapLevels: Int = 1
) -> MTLTexture? {
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = textureType
    descriptor.pixelFormat = pixelFormat
    descriptor.width = width
    descriptor.height = height
    descriptor.usage = usage
    descriptor.storageMode = storageMode
    descriptor.mipmapLevelCount = mipMapLevels

    let texture = device.makeTexture(descriptor: descriptor)
    texture?.label = label

    DebugTextureRegistry.register(name: label, texture: texture!)

    return texture
}

func configureAttachment(
    descriptor: MTLRenderPassAttachmentDescriptor?,
    texture: MTLTexture?,
    loadAction: MTLLoadAction,
    storeAction: MTLStoreAction,
    clearColor: MTLClearColor? = nil,
    clearDepth: Double? = nil
) {
    guard let descriptor else { return }
    descriptor.texture = texture
    descriptor.loadAction = loadAction
    descriptor.storeAction = storeAction

    // Handle clear color for color attachments
    if let colorDescriptor = descriptor as? MTLRenderPassColorAttachmentDescriptor, let clearColor {
        colorDescriptor.clearColor = clearColor
    }

    // Handle clear depth for depth attachments
    if let depthDescriptor = descriptor as? MTLRenderPassDepthAttachmentDescriptor, let clearDepth {
        depthDescriptor.clearDepth = clearDepth
    }
}

func createRenderPassDescriptor(
    width: Int,
    height: Int,
    colorAttachments: [(MTLTexture?, MTLLoadAction, MTLStoreAction, MTLClearColor?)],
    depthAttachment: (MTLTexture?, MTLLoadAction, MTLStoreAction, Double?)? = nil
) -> MTLRenderPassDescriptor {
    let descriptor = MTLRenderPassDescriptor()
    descriptor.renderTargetWidth = width
    descriptor.renderTargetHeight = height

    for (index, attachmentConfig) in colorAttachments.enumerated() {
        configureAttachment(
            descriptor: descriptor.colorAttachments[index],
            texture: attachmentConfig.0,
            loadAction: attachmentConfig.1,
            storeAction: attachmentConfig.2,
            clearColor: attachmentConfig.3
        )
    }

    if let depthConfig = depthAttachment {
        configureAttachment(
            descriptor: descriptor.depthAttachment,
            texture: depthConfig.0,
            loadAction: depthConfig.1,
            storeAction: depthConfig.2,
            clearDepth: depthConfig.3
        )
    }

    return descriptor
}

// Initialization routines

func initBufferResources() {
    // Initialize Grid Buffers
    func initGridBuffers() {
        bufferResources.gridVertexBuffer = createBuffer(
            device: renderInfo.device,
            data: gridVertices,
            label: "Grid Vertices"
        )
        bufferResources.gridUniforms = createEmptyBuffer(
            device: renderInfo.device,
            length: MemoryLayout<Uniforms>.stride,
            label: "Grid Uniforms"
        )
    }

    // Initialize Composite Buffers
    func initCompositeBuffers() {
        bufferResources.quadVerticesBuffer = createBuffer(
            device: renderInfo.device,
            data: quadVertices,
            label: "Quad Vertices"
        )
        bufferResources.quadTexCoordsBuffer = createBuffer(
            device: renderInfo.device,
            data: quadTexCoords,
            label: "Quad TexCoords"
        )
        bufferResources.quadIndexBuffer = createBuffer(
            device: renderInfo.device,
            data: quadIndices,
            label: "Quad Indices"
        )
    }

    // Initialize Point Light Buffer
    func initPointLightBuffer() {
        let maxLights = 1024
        let headerSize = MemoryLayout<UInt32>.stride * 4 // 4 * u32 (count + pad) = 16B
        let perLight = MemoryLayout<PointLightUniform>.stride // should be 64
        let rawSize = headerSize + perLight * maxLights

        // Pad to 16 bytes (you could also pad to 256 if you like being extra safe)
        let blockSize = align(rawSize, to: 16)

        let options: MTLResourceOptions = [.storageModeShared]
        bufferResources.pointLightBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: blockSize,
            options: options,
            label: "Point Lights"
        )
    }

    // Initialize Spot Light Buffer
    func initSpotLightBuffer() {
        let maxLights = 1024
        let headerSize = MemoryLayout<UInt32>.stride * 4 // 4 * u32 (count + pad) = 16B
        let perLight = MemoryLayout<SpotLightUniform>.stride // should be 64
        let rawSize = headerSize + perLight * maxLights

        // Pad to 16 bytes (you could also pad to 256 if you like being extra safe)
        let blockSize = align(rawSize, to: 16)

        let options: MTLResourceOptions = [.storageModeShared]
        bufferResources.spotLightBuffer = createEmptyBuffer(
            device: renderInfo.device, length: blockSize, options: options, label: "Spot Lights"
        )
    }

    // Initialize Area Light Buffer
    func initAreaLightBuffer() {
        let maxLights = 1024
        let headerSize = MemoryLayout<UInt32>.stride * 4 // 4 * u32 (count + pad) = 16B
        let perLight = MemoryLayout<AreaLightUniform>.stride // should be 64
        let rawSize = headerSize + perLight * maxLights

        // Pad to 16 bytes (you could also pad to 256 if you like being extra safe)
        let blockSize = align(rawSize, to: 16)

        let options: MTLResourceOptions = [.storageModeShared]
        bufferResources.areaLightBuffer = createEmptyBuffer(device: renderInfo.device, length: blockSize, options: options, label: "Area Light")
    }

    // Initialize Bounding Box Buffer
    func initBoundingBoxBuffer() {
        bufferResources.boundingBoxBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: MemoryLayout<simd_float4>.stride * boundingBoxVertexCount,
            label: "Bounding Box Buffer"
        )
    }

    // Initialize RTX Accumulation Buffer
    func initRTXAccumulationBuffer() {
        let width = Int(renderInfo.viewPort.x)
        let height = Int(renderInfo.viewPort.y)
        let bufferLength = MemoryLayout<simd_float3>.stride * width * height
        bufferResources.accumulationBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: bufferLength,
            label: "Accumulation Buffer"
        )
    }

    // Initialize All Buffers
    initGridBuffers()
    initCompositeBuffers()
    initPointLightBuffer()
    initSpotLightBuffer()
    initAreaLightBuffer()
    initBoundingBoxBuffer()
    initRTXAccumulationBuffer()
}

func initRenderPassDescriptors() {
    // Shadow Render Pass
    renderInfo.shadowRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(shadowResolution.x),
        height: Int(shadowResolution.y),
        colorAttachments: [(nil, .dontCare, .dontCare, nil)],
        depthAttachment: (textureResources.shadowMap, .clear, .store, 1.0)
    )

    // Offscreen Render Pass
    renderInfo.offscreenRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.colorMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.normalMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.positionMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.materialMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.emissiveMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, nil)
    )

    // Deferred Render Pass
    renderInfo.deferredRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.deferredColorMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ]
    )

    // SSAO Render Pass
    renderInfo.ssaoRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.ssaoTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.ssaoDepthMap, .dontCare, .store, nil)
    )

    // SSAO Blur Render Pass
    renderInfo.ssaoBlurRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.ssaoBlurTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.ssaoBlurDepthTexture, .dontCare, .store, nil)
    )

    // Post-Processing Render Pass
    renderInfo.postProcessRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.bloomCompositeTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, nil)
    )

    // Gizmo Render Pass
    renderInfo.gizmoRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [(textureResources.gizmoColorTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0))],
        depthAttachment: (textureResources.gizmoDepthTexture, .dontCare, .store, nil)
    )
}

func initTextureResources() {
    // Shadow Texture
    textureResources.shadowMap = createTexture(
        device: renderInfo.device,
        label: "Shadow Texture",
        pixelFormat: .depth32Float,
        width: Int(shadowResolution.x),
        height: Int(shadowResolution.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // Color Texture
    textureResources.colorMap = createTexture(
        device: renderInfo.device,
        label: "Color Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Normal Texture
    textureResources.normalMap = createTexture(
        device: renderInfo.device,
        label: "Normal Texture",
        pixelFormat: .rgba16Float,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Position Texture
    textureResources.positionMap = createTexture(
        device: renderInfo.device,
        label: "Position Texture",
        pixelFormat: .rgba16Float,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Emissive Texture
    textureResources.emissiveMap = createTexture(
        device: renderInfo.device,
        label: "Emissive Texture",
        pixelFormat: .rgba8Unorm,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Depth Texture
    textureResources.depthMap = createTexture(
        device: renderInfo.device,
        label: "Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    // Deferred Depth Texture
    textureResources.deferredDepthMap = createTexture(
        device: renderInfo.device,
        label: "Deferred Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    // SSAO Depth Texture
    textureResources.ssaoDepthMap = createTexture(
        device: renderInfo.device,
        label: "ssao Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    // SSAO Blur Depth Texture
    textureResources.ssaoBlurDepthTexture = createTexture(
        device: renderInfo.device,
        label: "ssao Blur Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    // Material Texture
    textureResources.materialMap = createTexture(
        device: renderInfo.device,
        label: "Material Texture",
        pixelFormat: .rgba8Unorm,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Deferred Color Texture
    textureResources.deferredColorMap = createTexture(
        device: renderInfo.device,
        label: "Deferred Color Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Tone Map debug texture
    textureResources.tonemapTexture = createTexture(
        device: renderInfo.device,
        label: "Tonemap Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Blur Map debug texture
    textureResources.blurTextureHor = createTexture(
        device: renderInfo.device,
        label: "Blur Texture Hor",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.blurTextureVer = createTexture(
        device: renderInfo.device,
        label: "Blur Texture Ver",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Color grading Map debug texture
    textureResources.colorGradingTexture = createTexture(
        device: renderInfo.device,
        label: "Color Grading Debug Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Color correction Map debug texture
    textureResources.colorCorrectionTexture = createTexture(
        device: renderInfo.device,
        label: "Color Correction Debug Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Bloom Threshold texture
    textureResources.bloomThresholdTextuture = createTexture(
        device: renderInfo.device,
        label: "Bloom Threshold Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Bloom Composite texture
    textureResources.bloomCompositeTexture = createTexture(
        device: renderInfo.device,
        label: "Bloom Composite Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Vignette texture
    textureResources.vignetteTexture = createTexture(
        device: renderInfo.device,
        label: "Vignette Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Chromatic Aberration texture
    textureResources.chromaticAberrationTexture = createTexture(
        device: renderInfo.device,
        label: "Chromatic Aberration Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Depth of Field texture
    textureResources.depthOfFieldTexture = createTexture(
        device: renderInfo.device,
        label: "Depth of Field Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // SSAO texture
    textureResources.ssaoTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // SSAO Blur texture
    textureResources.ssaoBlurTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Blur Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Gizmo Textures
    textureResources.gizmoDepthTexture = createTexture(
        device: renderInfo.device,
        label: "Gizmo Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    textureResources.gizmoColorTexture = createTexture(
        device: renderInfo.device,
        label: "Gizmo Color Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Area light textures
//    textureResources.areaTextureLTCMag = try? loadTexture(device: renderInfo.device, textureName: "ltc_mag", withExtension: "png")
//
//    textureResources.areaTextureLTCMat = try? loadTexture(device: renderInfo.device, textureName: "ltc_mat", withExtension: "png")

    let flattenedLTC1: [simd_float4] = LTC1.compactMap { row in
        guard row.count == 4 else { return nil }
        return simd_float4(row[0], row[1], row[2], row[3])
    }

    let flattenedLTC2: [simd_float4] = LTC2.compactMap { row in
        guard row.count == 4 else { return nil }
        return simd_float4(row[0], row[1], row[2], row[3])
    }

    textureResources.areaTextureLTCMat = makeFloat4Texture(data: flattenedLTC1, width: 64, height: 64)
    textureResources.areaTextureLTCMag = makeFloat4Texture(data: flattenedLTC2, width: 64, height: 64)
}

func initIBLResources() {
    let width = Int(renderInfo.viewPort.x)
    let height = Int(renderInfo.viewPort.y)

    // Irradiance Map
    textureResources.irradianceMap = createTexture(
        device: renderInfo.device,
        label: "IBL Irradiance Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: width,
        height: height,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared
    )

    // Specular Map (with mip-mapping)
    // Specular Map
    textureResources.specularMap = createTexture(
        device: renderInfo.device,
        label: "IBL Specular Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: width,
        height: height,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared,
        mipMapLevels: 6
    )

    // BRDF Map
    textureResources.iblBRDFMap = createTexture(
        device: renderInfo.device,
        label: "IBL BRDF Texture",
        pixelFormat: renderInfo.colorPixelFormat,
        width: width,
        height: height,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared
    )

    // create a render pass descriptor
    renderInfo.iblOffscreenRenderPassDescriptor = MTLRenderPassDescriptor()

    renderInfo.iblOffscreenRenderPassDescriptor.renderTargetWidth = Int(renderInfo.viewPort.x)
    renderInfo.iblOffscreenRenderPassDescriptor.renderTargetHeight = Int(renderInfo.viewPort.y)
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[0].texture =
        textureResources.irradianceMap
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[1].texture =
        textureResources.specularMap
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[2].texture =
        textureResources.iblBRDFMap

    generateHDR(hdrURL, from: resourceURL)
}

func createShadowVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].format =
        MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].bufferIndex = Int(
        shadowPassModelPositionIndex.rawValue)
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].offset = 0

    // set joint id
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].format =
        MTLVertexFormat.ushort4
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].bufferIndex = Int(
        shadowPassJointIdIndex.rawValue)
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].offset = 0

    // set joint weights
    vertexDescriptor.attributes[Int(shadowPassJointWeightsIndex.rawValue)].format =
        MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(shadowPassJointWeightsIndex.rawValue)].bufferIndex = Int(
        shadowPassJointWeightsIndex.rawValue)
    vertexDescriptor.attributes[Int(shadowPassJointWeightsIndex.rawValue)].offset = 0

    // stride
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stride =
        MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stepFunction =
        MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stepRate = 1
    
    vertexDescriptor.layouts[Int(shadowPassJointIdIndex.rawValue)].stride =
        MemoryLayout<simd_ushort4>.stride
    vertexDescriptor.layouts[Int(shadowPassJointIdIndex.rawValue)].stepFunction =
        MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(shadowPassJointIdIndex.rawValue)].stepRate = 1

    vertexDescriptor.layouts[Int(shadowPassJointWeightsIndex.rawValue)].stride =
        MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[Int(shadowPassJointWeightsIndex.rawValue)].stepFunction =
        MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(shadowPassJointWeightsIndex.rawValue)].stepRate = 1

    return vertexDescriptor
}

func createGridVertexDescriptor() -> MTLVertexDescriptor {
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    return vertexDescriptor
}

func createModelVertexDescriptor() -> MTLVertexDescriptor? {
    // tell the gpu how data is organized
    vertexDescriptor.model = MDLVertexDescriptor()

    vertexDescriptor.model.attributes[Int(modelPassVerticesIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributePosition,
        format: .float4,
        offset: 0,
        bufferIndex: Int(modelPassVerticesIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(modelPassNormalIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeNormal,
        format: .float4,
        offset: 0,
        bufferIndex: Int(modelPassNormalIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(modelPassUVIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeTextureCoordinate,
        format: .float2,
        offset: 0,
        bufferIndex: Int(modelPassUVIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(modelPassTangentIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeTangent, format: .float4, offset: 0,
        bufferIndex: Int(modelPassTangentIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(modelPassJointIdIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeJointIndices, format: .uShort4, offset: 0,
        bufferIndex: Int(modelPassJointIdIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(modelPassJointWeightsIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeJointWeights, format: .float4, offset: 0,
        bufferIndex: Int(modelPassJointWeightsIndex.rawValue)
    )

    vertexDescriptor.model.layouts[Int(modelPassVerticesIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(modelPassNormalIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(modelPassUVIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float2>.stride)

    vertexDescriptor.model.layouts[Int(modelPassTangentIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(modelPassJointIdIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_ushort4>.stride)

    vertexDescriptor.model.layouts[Int(modelPassJointWeightsIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    guard let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.model) else {
        return nil
    }

    return vertexDescriptor
}

func createGizmoVertexDescriptor() -> MTLVertexDescriptor? {
    // tell the gpu how data is organized
    vertexDescriptor.gizmo = MDLVertexDescriptor()

    vertexDescriptor.gizmo.attributes[Int(modelPassVerticesIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributePosition,
        format: .float4,
        offset: 0,
        bufferIndex: Int(modelPassVerticesIndex.rawValue)
    )

    vertexDescriptor.gizmo.layouts[Int(modelPassVerticesIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    guard let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.gizmo) else {
        return nil
    }

    return vertexDescriptor
}

func createGeometryVertexDescriptor() -> MTLVertexDescriptor {
    // tell the gpu how data is organized
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    return vertexDescriptor
}

func createLightVisualVertexDescriptor() -> MTLVertexDescriptor {
    // tell the gpu how data is organized
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(lightVisualPassPositionIndex.rawValue)].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[Int(lightVisualPassPositionIndex.rawValue)].bufferIndex = Int(lightVisualPassPositionIndex.rawValue)
    vertexDescriptor.attributes[Int(lightVisualPassPositionIndex.rawValue)].offset = 0

    vertexDescriptor.attributes[Int(lightVisualPassUVIndex.rawValue)].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[Int(lightVisualPassUVIndex.rawValue)].bufferIndex = Int(lightVisualPassUVIndex.rawValue)
    vertexDescriptor.attributes[Int(lightVisualPassUVIndex.rawValue)].offset = 0

    vertexDescriptor.layouts[Int(lightVisualPassPositionIndex.rawValue)].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[Int(lightVisualPassPositionIndex.rawValue)].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(lightVisualPassPositionIndex.rawValue)].stepRate = 1

    vertexDescriptor.layouts[Int(lightVisualPassUVIndex.rawValue)].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[Int(lightVisualPassUVIndex.rawValue)].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(lightVisualPassUVIndex.rawValue)].stepRate = 1

    return vertexDescriptor
}

func createCompositeVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createPreCompositeVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createDebugVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createLightVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createPostProcessVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createIBLPreFilterVertexDescriptor() -> MTLVertexDescriptor {
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[1].bufferIndex = 1
    vertexDescriptor.attributes[1].offset = 0

    // stride
    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
    vertexDescriptor.layouts[1].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[1].stepRate = 1

    return vertexDescriptor
}

func createEnvironmentVertexDescriptor() -> MTLVertexDescriptor {
    // tell the gpu how data is organized
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(envPassPositionIndex.rawValue)].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[Int(envPassPositionIndex.rawValue)].offset = 0

    vertexDescriptor.attributes[Int(envPassNormalIndex.rawValue)].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[Int(envPassNormalIndex.rawValue)].bufferIndex = 0
    vertexDescriptor.attributes[Int(envPassNormalIndex.rawValue)].offset =
        MemoryLayout<simd_float3>.stride

    vertexDescriptor.attributes[Int(envPassUVIndex.rawValue)].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[Int(envPassUVIndex.rawValue)].bufferIndex = 0
    vertexDescriptor.attributes[Int(envPassUVIndex.rawValue)].offset =
        2 * MemoryLayout<simd_float3>.stride

    vertexDescriptor.layouts[0].stride =
        2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride

    return vertexDescriptor
}

func createOutlineVertexDescriptor() -> MTLVertexDescriptor? {
    // tell the gpu how data is organized
    let vertexDescriptor = MTLVertexDescriptor()

    vertexDescriptor.attributes[Int(modelPassVerticesIndex.rawValue)].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(modelPassVerticesIndex.rawValue)].bufferIndex = Int(modelPassVerticesIndex.rawValue)
    vertexDescriptor.attributes[Int(modelPassVerticesIndex.rawValue)].offset = 0

    vertexDescriptor.attributes[Int(modelPassNormalIndex.rawValue)].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(modelPassNormalIndex.rawValue)].bufferIndex = Int(modelPassNormalIndex.rawValue)
    vertexDescriptor.attributes[Int(modelPassNormalIndex.rawValue)].offset = 0

    vertexDescriptor.layouts[Int(modelPassVerticesIndex.rawValue)].stride = MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[Int(modelPassNormalIndex.rawValue)].stride = MemoryLayout<simd_float4>.stride

    return vertexDescriptor
}

func initSSAOResources() {
    // init ssao kernel
    let kernelData = generateSSAOKernel()
    bufferResources.ssaoKernelBuffer = renderInfo.device.makeBuffer(bytes: kernelData,
                                                                    length: MemoryLayout<SIMD3<Float>>.stride * kernelData.count,
                                                                    options: [])

    // init ssao noise texture
    textureResources.ssaoNoiseTexture = generateSSAONoiseTexture(device: renderInfo.device)
}

func initRenderPipelines() {
    // Grid Pipeline
    if let gridPipe = createPipeline(
        vertexShader: "vertexGridShader",
        fragmentShader: "fragmentGridShader",
        vertexDescriptor: createGridVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.less,
        depthEnabled: false,
        blendEnabled: true,
        name: "Grid Pipeline"
    ) {
        gridPipeline = gridPipe
    }

    // Shadow Pipeline
    if let shadowPipe = createPipeline(
        vertexShader: "vertexShadowShader",
        fragmentShader: nil,
        vertexDescriptor: createShadowVertexDescriptor(),
        colorFormats: [.invalid],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: MTLCompareFunction.less,
        name: "Shadow Pipeline"
    ) {
        shadowPipeline = shadowPipe
    }

    // Model Pipeline
    if let modelPipe = createPipeline(
        vertexShader: "vertexModelShader",
        fragmentShader: "fragmentModelShader",
        vertexDescriptor: createModelVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float, .rgba8Unorm, .rgba8Unorm],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Model Pipeline"
    ) {
        modelPipeline = modelPipe
    }

    // Light Pipeline
    if let lightPipe = createPipeline(
        vertexShader: "vertexLightShader",
        fragmentShader: "fragmentLightShader",
        vertexDescriptor: createLightVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: .invalid,
        depthEnabled: false,
        name: "Light Pipeline"
    ) {
        lightPipeline = lightPipe
    }

    // Gizmo Pipeline
    if let gizmoPipe = createPipeline(
        vertexShader: "vertexGizmoShader",
        fragmentShader: "fragmentGizmoShader",
        vertexDescriptor: createGizmoVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Gizmo Pipeline"
    ) {
        gizmoPipeline = gizmoPipe
    }

    // Geometry Pipeline
    if let geometryPipe = createPipeline(
        vertexShader: "vertexGeometryShader",
        fragmentShader: "fragmentGeometryShader",
        vertexDescriptor: createGeometryVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Geometry Pipeline"
    ) {
        geometryPipeline = geometryPipe
    }

    // Highlight Pipeline
    if let highlightPipe = createPipeline(
        vertexShader: "vertexGeometryShader",
        fragmentShader: "fragmentGeometryShader",
        vertexDescriptor: createGeometryVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .always,
        depthEnabled: false,
        name: "Highlight Pipeline"
    ) {
        hightlightPipeline = highlightPipe
    }

    // Light Visual Pipeline
    if let lightVisual = createPipeline(
        vertexShader: "vertexLightVisualShader",
        fragmentShader: "fragmentLightVisualShader",
        vertexDescriptor: createLightVisualVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: true,
        name: "Light Visual Pipeline"
    ) {
        lightVisualPipeline = lightVisual
    }

    // Outline Pipeline
    if let outlinePipe = createPipeline(
        vertexShader: "vertexOutlineShader",
        fragmentShader: "fragmentOutlineShader",
        vertexDescriptor: createOutlineVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .lessEqual,
        depthEnabled: true,
        name: "Outline Pipeline"
    ) {
        outlinePipeline = outlinePipe
    }

    if let compositePipe = createPipeline(
        vertexShader: "vertexCompositeShader",
        fragmentShader: "fragmentCompositeShader",
        vertexDescriptor: createCompositeVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Composite Pipeline"
    ) {
        compositePipeline = compositePipe
    }

    if let preCompositePipe = createPipeline(
        vertexShader: "vertexPreCompositeShader",
        fragmentShader: "fragmentPreCompositeShader",
        vertexDescriptor: createPreCompositeVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Pre-Composite Pipeline"
    ) {
        preCompositePipeline = preCompositePipe
    }

    if let debugPipe = createPipeline(
        vertexShader: "vertexDebugShader",
        fragmentShader: "fragmentDebugShader",
        vertexDescriptor: createDebugVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "Debug Pipeline"
    ) {
        debuggerPipeline = debugPipe
    }

    if let tonePipe = createPipeline(
        vertexShader: "vertexTonemappingShader",
        fragmentShader: "fragmentTonemappingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Tone-mapping Pipeline"
    ) {
        tonemappingPipeline = tonePipe
    }

    if let blurPipe = createPipeline(
        vertexShader: "vertexBlurShader",
        fragmentShader: "fragmentBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Blur Pipeline"
    ) {
        blurPipeline = blurPipe
    }

    if let colorGradingPipe = createPipeline(
        vertexShader: "vertexColorGradingShader",
        fragmentShader: "fragmentColorGradingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "ColorGrading Pipeline"
    ) {
        colorGradingPipeline = colorGradingPipe
    }

    if let colorCorrectionPipe = createPipeline(
        vertexShader: "vertexColorCorrectionShader",
        fragmentShader: "fragmentColorCorrectionShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Color Correction Pipeline"
    ) {
        colorCorrectionPipeline = colorCorrectionPipe
    }

    // Bloom Threshold pipeline
    if let bloomThresholdPipe = createPipeline(
        vertexShader: "vertexBloomThresholdShader",
        fragmentShader: "fragmentBloomThresholdShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Bloom Threshold Pipeline"
    ) {
        bloomThresholdPipeline = bloomThresholdPipe
    }

    // Bloom Composite pipeline
    if let bloomCompositePipe = createPipeline(
        vertexShader: "vertexBloomCompositeShader",
        fragmentShader: "fragmentBloomCompositeShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        blendEnabled: true,
        name: "Bloom Composite Pipeline"
    ) {
        bloomCompositePipeline = bloomCompositePipe
    }

    // vignette pipeline
    if let vignettePipe = createPipeline(
        vertexShader: "vertexVignetteShader",
        fragmentShader: "fragmentVignetteShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Vignette Pipeline"
    ) {
        vignettePipeline = vignettePipe
    }

    // Chromatic Aberration pipeline
    if let chromaticAberrationPipe = createPipeline(
        vertexShader: "vertexChromaticAberrationShader",
        fragmentShader: "fragmentChromaticAberrationShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Chromatic Aberration Pipeline"
    ) {
        chromaticAberrationPipeline = chromaticAberrationPipe
    }

    // Depth of Field pipeline
    if let depthOfFieldPipe = createPipeline(
        vertexShader: "vertexDepthOfFieldShader",
        fragmentShader: "fragmentDepthOfFieldShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Depth of Field Pipeline"
    ) {
        depthOfFieldPipeline = depthOfFieldPipe
    }

    // SSAO pipeline
    if let ssaoPipe = createPipeline(
        vertexShader: "vertexSSAOShader",
        fragmentShader: "fragmentSSAOShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SSAO Pipeline"
    ) {
        ssaoPipeline = ssaoPipe
    }

    if let ssaoBlurPipe = createPipeline(
        vertexShader: "vertexSSAOBlurShader",
        fragmentShader: "fragmentSSAOBlurShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SSAO Blur Pipeline"
    ) {
        ssaoBlurPipeline = ssaoBlurPipe
    }

    if let environmentPipe = createPipeline(
        vertexShader: "vertexEnvironmentShader",
        fragmentShader: "fragmentEnvironmentShader",
        vertexDescriptor: createEnvironmentVertexDescriptor(),
        colorFormats: [.bgra8Unorm_srgb],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Environment Pipeline"
    ) {
        environmentPipeline = environmentPipe

        // create the mesh

        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

        let mdlMesh = MDLMesh.newEllipsoid(
            withRadii: simd_float3(5.0, 5.0, 5.0), radialSegments: 24, verticalSegments: 24,
            geometryType: .triangles, inwardNormals: true, hemisphere: false, allocator: bufferAllocator
        )

        let mdlVertexDescriptor = MDLVertexDescriptor()
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            fatalError("could not get the mdl attributes")
            // return false
        }

        attributes[0].name = MDLVertexAttributePosition
        attributes[0].format = MDLVertexFormat.float3
        attributes[0].bufferIndex = 0
        attributes[0].offset = 0

        attributes[1].name = MDLVertexAttributeNormal
        attributes[1].format = MDLVertexFormat.float3
        attributes[1].bufferIndex = 0
        attributes[1].offset = MemoryLayout<simd_float3>.stride

        attributes[2].name = MDLVertexAttributeTextureCoordinate
        attributes[2].format = MDLVertexFormat.float2
        attributes[2].bufferIndex = 0
        attributes[2].offset = 2 * MemoryLayout<simd_float3>.stride

        // Initialize the layout
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(
            stride: 2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride)

        guard let bufferLayouts = mdlVertexDescriptor.layouts as? [MDLVertexBufferLayout] else {
            fatalError("Could not get the MDL layouts")
        }

        bufferLayouts[0].stride =
            2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride

        mdlMesh.vertexDescriptor = mdlVertexDescriptor

        do {
            environmentMesh = try MTKMesh(mesh: mdlMesh, device: renderInfo.device)
        } catch {
            fatalError("Unable to build MetalKit Mesh. Error info: ")
        }

        environmentPipeline.success = true
    }

    if let iblPreFilterPipe = createPipeline(
        vertexShader: "vertexIBLPreFilterShader",
        fragmentShader: "fragmentIBLPreFilterShader",
        vertexDescriptor: createIBLPreFilterVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, renderInfo.colorPixelFormat, renderInfo.colorPixelFormat],
        depthFormat: .invalid,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "IBL-Pre Filer Pipeline"
    ) {
        iblPrefilterPipeline = iblPreFilterPipe
    }
}
