
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
        bufferResources.pointLightBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: MemoryLayout<PointLight>.stride * maxNumPointLights,
            label: "Point Lights"
        )
    }

    // Initialize Spot Light Buffer
    func initSpotLightBuffer() {
        bufferResources.spotLightBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: MemoryLayout<SpotLight>.stride * maxNumSpotLights,
            label: "Spot Lights"
        )
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
    initBoundingBoxBuffer()
    initRTXAccumulationBuffer()
}

func initRenderPassDescriptors() {
    // Shadow Render Pass
    renderInfo.shadowRenderPassDescriptor = createRenderPassDescriptor(
        width: 1024,
        height: 1024,
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
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, nil)
    )
    
    // Offscreen Render Pass
    renderInfo.postProcessRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.bloomCompositeTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.normalMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (textureResources.positionMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, nil)
    )
}

func initTextureResources() {
    // Shadow Texture
    textureResources.shadowMap = createTexture(
        device: renderInfo.device,
        label: "Shadow Texture",
        pixelFormat: .depth32Float,
        width: 1024,
        height: 1024,
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

    // stride
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stride =
        MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stepFunction =
        MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(shadowPassModelPositionIndex.rawValue)].stepRate = 1

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

func initRenderPipelines() {
    // Grid Pipeline
    if let gridPipe = createPipeline(
        vertexShader: "vertexGridShader",
        fragmentShader: "fragmentGridShader",
        vertexDescriptor: createGridVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        name: "Model Pipeline"
    ) {
        modelPipeline = modelPipe
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

    // Light Visual Pipeline
    if let lightVisual = createPipeline(
        vertexShader: "vertexLightVisualShader",
        fragmentShader: "fragmentLightVisualShader",
        vertexDescriptor: createLightVisualVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat],
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
        colorFormats: [renderInfo.colorPixelFormat],
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
        colorFormats: [renderInfo.colorPixelFormat],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Bloom Composite Pipeline"
    ) {
        bloomCompositePipeline = bloomCompositePipe
    }
    
    // vignette pipeline
    if let vignettePipe = createPipeline(
        vertexShader: "vertexVignetteShader",
        fragmentShader: "fragmentVignetteShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
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
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "SSAO Pipeline"
    ) {
        ssaoPipeline = ssaoPipe
    }
    
    if let environmentPipe = createPipeline(
        vertexShader: "vertexEnvironmentShader",
        fragmentShader: "fragmentEnvironmentShader",
        vertexDescriptor: createEnvironmentVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
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
