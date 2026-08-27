
//
//  RenderInitializer.swift
//  Untold Engine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit
import simd

// Helper creation functions

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
    mipMapLevels: Int = 1,
    sampleCount: Int = 1
) -> MTLTexture? {
    let descriptor = MTLTextureDescriptor()
    descriptor.textureType = sampleCount > 1 ? .type2DMultisample : textureType
    descriptor.pixelFormat = pixelFormat
    descriptor.width = width
    descriptor.height = height
    descriptor.usage = usage
    descriptor.storageMode = storageMode
    descriptor.mipmapLevelCount = sampleCount > 1 ? 1 : mipMapLevels
    descriptor.sampleCount = max(1, sampleCount)

    let texture = device.makeTexture(descriptor: descriptor)
    texture?.label = label

    // TODO: Figure it out how to support this in game and editor mode
//    DebugTextureRegistry.register(name: label, texture: texture!)

    return texture
}

@inline(__always)
func requestedOpaqueSampleCount() -> Int {
    #if targetEnvironment(simulator)
        // The simulator's two-pass deferred fallback samples the G-buffer as
        // texture2d, which is incompatible with multisampled (memoryless) targets.
        return 1
    #else
        switch antiAliasingMode {
        case .msaa:
            let preferredSampleCount = 4
            guard let device = renderInfo.device else { return 1 }
            return device.supportsTextureSampleCount(preferredSampleCount) ? preferredSampleCount : 1
        case .none, .fxaa, .smaa:
            return 1
        }
    #endif
}

@inline(__always)
func effectiveOpaqueSampleCount() -> Int {
    // G-buffer debug views sample stored albedo/normal as texture2d, so keep those
    // modes single-sample until debug shaders get multisample variants.
    renderInfo.gBufferDebugStorageEnabled ? 1 : requestedOpaqueSampleCount()
}

func updateOpaquePipelinesForSampleCount() {
    guard renderInfo.device != nil, renderInfo.library != nil else { return }

    if let modelPipeline = InitModelPipeline() {
        PipelineManager.shared.update(rendererPipeLine: modelPipeline, forType: .model)
    }
    if let lightPipeline = InitLightPipeline() {
        PipelineManager.shared.update(rendererPipeLine: lightPipeline, forType: .light)
    }
}

func updateOpaqueSampleCountForCurrentState() {
    guard renderInfo.device != nil,
          renderInfo.viewPort != nil,
          renderInfo.viewPort.x > 0,
          renderInfo.viewPort.y > 0
    else {
        return
    }

    let newSampleCount = effectiveOpaqueSampleCount()
    guard renderInfo.opaqueSampleCount != newSampleCount else { return }

    renderInfo.opaqueSampleCount = newSampleCount
    initTextureResources()
    initRenderPassDescriptors()
    reinitSSAOTextures()
    updateOpaquePipelinesForSampleCount()
}

func createSMAALookupTexture(
    device: MTLDevice,
    label: String,
    pixelFormat: MTLPixelFormat,
    width: Int,
    height: Int,
    bytes: [UInt8],
    bytesPerRow: Int,
    expectedByteCount: Int
) -> MTLTexture? {
    guard bytes.count == expectedByteCount else {
        Logger.logWarning(
            message: "\(label) byte count mismatch: expected \(expectedByteCount), got \(bytes.count)"
        )
        return nil
    }

    guard let texture = createTexture(
        device: device,
        label: label,
        pixelFormat: pixelFormat,
        width: width,
        height: height,
        usage: [.shaderRead],
        storageMode: .shared
    ) else {
        return nil
    }

    texture.replace(
        region: MTLRegionMake2D(0, 0, width, height),
        mipmapLevel: 0,
        withBytes: bytes,
        bytesPerRow: bytesPerRow
    )

    return texture
}

@inline(__always)
func calculateHZBMipCount(width: Int, height: Int) -> Int {
    let maxDim = max(1, max(width, height))
    return Int(floor(log2(Double(maxDim)))) + 1
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
    /// Initialize Grid Buffers
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

    /// Initialize Composite Buffers
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

    /// Initialize Point Light Buffer
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

    /// Initialize Spot Light Buffer
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

    /// Initialize Area Light Buffer
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

    /// Initialize Bounding Box Buffer
    func initBoundingBoxBuffer() {
        bufferResources.boundingBoxBuffer = createEmptyBuffer(
            device: renderInfo.device,
            length: MemoryLayout<simd_float4>.stride * boundingBoxVertexCount,
            label: "Bounding Box Buffer"
        )
    }

    // Initialize All Buffers
    initGridBuffers()
    initCompositeBuffers()
    initPointLightBuffer()
    initSpotLightBuffer()
    initAreaLightBuffer()
    initBoundingBoxBuffer()
}

/// Initialize RTX Accumulation Buffer
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

func initRenderPassDescriptors() {
    let opaqueSampleCount = max(1, renderInfo.opaqueSampleCount)
    let usesMSAA = opaqueSampleCount > 1
    let gBufferColorTextures: [MTLTexture?] = usesMSAA
        ? [
            textureResources.msaaColorMap,
            textureResources.msaaNormalMap,
            textureResources.msaaPositionMap,
            textureResources.msaaMaterialMap,
            textureResources.msaaEmissiveMap,
        ]
        : [
            textureResources.colorMap,
            textureResources.normalMap,
            textureResources.positionMap,
            textureResources.materialMap,
            textureResources.emissiveMap,
        ]
    let opaqueColorTexture = usesMSAA ? textureResources.msaaDeferredColorMap : textureResources.deferredColorMap
    let opaqueDepthTexture = usesMSAA ? textureResources.msaaDepthMap : textureResources.depthMap

    // Environment Render Pass
    renderInfo.environmentRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.environmentColorMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .dontCare, sceneDepthClearValue())
    )

    // CSM Shadow Render Passes — one descriptor per cascade, each clears its own array slice.
    renderInfo.csmRenderPassDescriptors.removeAll()
    for cascadeIdx in 0 ..< csmCascadeCount {
        let desc = MTLRenderPassDescriptor()
        desc.renderTargetWidth = Int(shadowResolution.x)
        desc.renderTargetHeight = Int(shadowResolution.y)
        desc.depthAttachment.texture = textureResources.csmShadowMap
        desc.depthAttachment.loadAction = .clear
        desc.depthAttachment.storeAction = .store
        desc.depthAttachment.clearDepth = 1.0
        desc.depthAttachment.slice = cascadeIdx
        renderInfo.csmRenderPassDescriptors.append(desc)
    }

    renderInfo.pointShadowRenderPassDescriptors.removeAll()
    for faceIdx in 0 ..< 6 {
        let desc = MTLRenderPassDescriptor()
        desc.renderTargetWidth = Int(shadowResolution.x)
        desc.renderTargetHeight = Int(shadowResolution.y)
        desc.depthAttachment.texture = textureResources.pointShadowCubeMap
        desc.depthAttachment.loadAction = .clear
        desc.depthAttachment.storeAction = .store
        desc.depthAttachment.clearDepth = 1.0
        desc.depthAttachment.slice = faceIdx
        renderInfo.pointShadowRenderPassDescriptors.append(desc)
    }

    renderInfo.spotShadowRenderPassDescriptor = MTLRenderPassDescriptor()
    renderInfo.spotShadowRenderPassDescriptor.renderTargetWidth = Int(shadowResolution.x)
    renderInfo.spotShadowRenderPassDescriptor.renderTargetHeight = Int(shadowResolution.y)
    renderInfo.spotShadowRenderPassDescriptor.depthAttachment.texture = textureResources.spotShadowMap
    renderInfo.spotShadowRenderPassDescriptor.depthAttachment.loadAction = .clear
    renderInfo.spotShadowRenderPassDescriptor.depthAttachment.storeAction = .store
    renderInfo.spotShadowRenderPassDescriptor.depthAttachment.clearDepth = 1.0

    // Combined G-buffer + lighting render pass (TBDR).
    // Attachments 0-4 are normally memoryless G-buffer slots and are discarded at
    // the end. G-buffer debug views switch them to stored textures so the later
    // debug pass can sample them; the simulator always stores them for its
    // texture-based light pass.
    #if targetEnvironment(simulator)
        let gBufferStoreAction: MTLStoreAction = .store
    #else
        let gBufferStoreAction: MTLStoreAction = renderInfo.gBufferDebugStorageEnabled ? .store : .dontCare
    #endif
    renderInfo.offscreenRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (gBufferColorTextures[0], .clear, gBufferStoreAction, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (gBufferColorTextures[1], .clear, gBufferStoreAction, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (gBufferColorTextures[2], .clear, gBufferStoreAction, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (gBufferColorTextures[3], .clear, gBufferStoreAction, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (gBufferColorTextures[4], .clear, gBufferStoreAction, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            (opaqueColorTexture, .clear, usesMSAA ? .multisampleResolve : .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (opaqueDepthTexture, .clear, usesMSAA ? .multisampleResolve : .store, sceneDepthClearValue())
    )
    if usesMSAA {
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[5].resolveTexture = textureResources.deferredColorMap
        renderInfo.offscreenRenderPassDescriptor.depthAttachment.resolveTexture = textureResources.depthMap
    }

    // Deferred Render Pass
    renderInfo.deferredRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.deferredColorMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, sceneDepthClearValue())
    )

    // SSAO Render Pass
    renderInfo.ssaoRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.ssaoTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.ssaoDepthMap, .dontCare, .store, sceneDepthClearValue())
    )

    // SSAO Blur Render Pass
    renderInfo.ssaoBlurRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.ssaoBlurTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.ssaoBlurDepthTexture, .dontCare, .store, sceneDepthClearValue())
    )

    // Post-Processing Render Pass
    renderInfo.postProcessRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.bloomCompositeTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .dontCare, .store, sceneDepthClearValue())
    )

    // Gizmo Render Pass
    renderInfo.gizmoRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [(textureResources.gizmoColorTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0))],
        depthAttachment: (textureResources.gizmoDepthTexture, .dontCare, .store, sceneDepthClearValue())
    )

    // Gaussian Offscreen Render Pass - shares depth buffer with 3D models
    renderInfo.gaussianRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.gaussianColorMap, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: (textureResources.depthMap, .load, .dontCare, sceneDepthClearValue()) // Load existing depth from models
    )

    renderInfo.sceneCompositeRenderPassDescriptor = createRenderPassDescriptor(
        width: Int(renderInfo.viewPort.x),
        height: Int(renderInfo.viewPort.y),
        colorAttachments: [
            (textureResources.sceneCompositeTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: nil
    )
}

func gBufferDebugModeNeedsStoredTargets(_ mode: RenderDebugViewMode) -> Bool {
    switch mode {
    case .albedo, .normal, .position, .roughness, .metallic, .heightDebug, .pomOffsetDebug:
        return true
    case .lit, .depth, .ssaoBlurred, .fxaaEdgeDebug, .smaaEdges, .smaaBlend, .smaaDifference, .occlusionDebug,
         .preTonemapHDRLuminance, .postTonemapOutput:
        return false
    }
}

func updateGBufferStorageForCurrentDebugMode() {
    guard renderInfo.viewPort != nil,
          renderInfo.viewPort.x > 0,
          renderInfo.viewPort.y > 0
    else {
        return
    }

    let shouldStoreGBuffer = gBufferDebugModeNeedsStoredTargets(renderDebugViewMode)
    guard renderInfo.gBufferDebugStorageEnabled != shouldStoreGBuffer else { return }

    let previousSampleCount = renderInfo.opaqueSampleCount
    renderInfo.gBufferDebugStorageEnabled = shouldStoreGBuffer
    if previousSampleCount != effectiveOpaqueSampleCount() {
        updateOpaqueSampleCountForCurrentState()
    } else {
        initGBufferTextureResources()
        initRenderPassDescriptors()
    }
}

func initGBufferTextureResources() {
    let wf = renderInfo.colorPipeline.working
    let viewportWidth = max(1, Int(renderInfo.viewPort.x))
    let viewportHeight = max(1, Int(renderInfo.viewPort.y))
    let opaqueSampleCount = max(1, renderInfo.opaqueSampleCount)

    // G-buffer textures: memoryless in normal rendering; persistent when a debug
    // view needs to sample the G-buffer after the TBDR pass, and always in the
    // simulator, where the light pass samples the G-buffer as textures because
    // framebuffer fetch is unsupported there.
    #if targetEnvironment(simulator)
        let gBufferNeedsStorage = true
    #else
        let gBufferNeedsStorage = renderInfo.gBufferDebugStorageEnabled
    #endif
    let gBufferUsage: MTLTextureUsage = gBufferNeedsStorage
        ? [.renderTarget, .shaderRead]
        : [.renderTarget]
    let gBufferStorageMode: MTLStorageMode = gBufferNeedsStorage
        ? .private
        : .memoryless

    textureResources.colorMap = createTexture(
        device: renderInfo.device,
        label: "Color Texture",
        pixelFormat: wf.gBufferAlbedo,
        width: viewportWidth,
        height: viewportHeight,
        usage: gBufferUsage,
        storageMode: gBufferStorageMode
    )

    textureResources.normalMap = createTexture(
        device: renderInfo.device,
        label: "Normal Texture",
        pixelFormat: wf.gBufferNormal,
        width: viewportWidth,
        height: viewportHeight,
        usage: gBufferUsage,
        storageMode: gBufferStorageMode
    )

    textureResources.positionMap = createTexture(
        device: renderInfo.device,
        label: "Position Texture",
        pixelFormat: wf.gBufferPosition,
        width: viewportWidth,
        height: viewportHeight,
        usage: gBufferUsage,
        storageMode: gBufferStorageMode
    )

    textureResources.emissiveMap = createTexture(
        device: renderInfo.device,
        label: "Emissive Texture",
        pixelFormat: wf.gBufferEmissive,
        width: viewportWidth,
        height: viewportHeight,
        usage: gBufferUsage,
        storageMode: gBufferStorageMode
    )

    textureResources.materialMap = createTexture(
        device: renderInfo.device,
        label: "Material Texture",
        pixelFormat: wf.gBufferMaterial,
        width: viewportWidth,
        height: viewportHeight,
        usage: gBufferUsage,
        storageMode: gBufferStorageMode
    )

    if opaqueSampleCount > 1 {
        textureResources.msaaColorMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Color Texture",
            pixelFormat: wf.gBufferAlbedo,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: opaqueSampleCount
        )
        textureResources.msaaNormalMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Normal Texture",
            pixelFormat: wf.gBufferNormal,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: opaqueSampleCount
        )
        textureResources.msaaPositionMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Position Texture",
            pixelFormat: wf.gBufferPosition,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: opaqueSampleCount
        )
        textureResources.msaaEmissiveMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Emissive Texture",
            pixelFormat: wf.gBufferEmissive,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: opaqueSampleCount
        )
        textureResources.msaaMaterialMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Material Texture",
            pixelFormat: wf.gBufferMaterial,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: opaqueSampleCount
        )
    } else {
        textureResources.msaaColorMap = nil
        textureResources.msaaNormalMap = nil
        textureResources.msaaPositionMap = nil
        textureResources.msaaMaterialMap = nil
        textureResources.msaaEmissiveMap = nil
    }
}

func initTextureResources() {
    renderInfo.opaqueSampleCount = effectiveOpaqueSampleCount()

    let wf = renderInfo.colorPipeline.working
    let viewportWidth = max(1, Int(renderInfo.viewPort.x))
    let viewportHeight = max(1, Int(renderInfo.viewPort.y))

    // Recreated on resize/init. Mark invalid until a new pyramid is built from depth.
    renderInfo.hzbIsValid = false

    // CSM Shadow Array Texture — one depth slice per cascade.
    let csmDesc = MTLTextureDescriptor()
    csmDesc.textureType = .type2DArray
    csmDesc.pixelFormat = .depth32Float
    csmDesc.width = Int(shadowResolution.x)
    csmDesc.height = Int(shadowResolution.y)
    csmDesc.arrayLength = csmCascadeCount
    csmDesc.usage = [.shaderRead, .renderTarget]
    csmDesc.storageMode = .private
    textureResources.csmShadowMap = renderInfo.device.makeTexture(descriptor: csmDesc)
    textureResources.csmShadowMap?.label = "CSM Shadow Cascade Array"

    let pointShadowDesc = MTLTextureDescriptor()
    pointShadowDesc.textureType = .typeCube
    pointShadowDesc.pixelFormat = .depth32Float
    pointShadowDesc.width = Int(shadowResolution.x)
    pointShadowDesc.height = Int(shadowResolution.y)
    pointShadowDesc.usage = [.shaderRead, .renderTarget]
    pointShadowDesc.storageMode = .private
    textureResources.pointShadowCubeMap = renderInfo.device.makeTexture(descriptor: pointShadowDesc)
    textureResources.pointShadowCubeMap?.label = "Point Shadow Cube Map"

    let spotShadowDesc = MTLTextureDescriptor()
    spotShadowDesc.textureType = .type2D
    spotShadowDesc.pixelFormat = .depth32Float
    spotShadowDesc.width = Int(shadowResolution.x)
    spotShadowDesc.height = Int(shadowResolution.y)
    spotShadowDesc.usage = [.shaderRead, .renderTarget]
    spotShadowDesc.storageMode = .private
    textureResources.spotShadowMap = renderInfo.device.makeTexture(descriptor: spotShadowDesc)
    textureResources.spotShadowMap?.label = "Spot Shadow Map"

    initGBufferTextureResources()

    // Depth Texture
    textureResources.depthMap = createTexture(
        device: renderInfo.device,
        label: "Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    if renderInfo.opaqueSampleCount > 1 {
        textureResources.msaaDepthMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Depth Texture",
            pixelFormat: renderInfo.depthPixelFormat,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: renderInfo.opaqueSampleCount
        )
    } else {
        textureResources.msaaDepthMap = nil
    }

    // HZB uses a dedicated source depth so wireframe channels can contribute
    // filled occluder depth without changing visible scene color.
    textureResources.hzbSourceDepthMap = createTexture(
        device: renderInfo.device,
        label: "HZB Source Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // Gaussian pass reads a snapshot of the opaque depth to occlude splats behind
    // walls/geometry. Copied fresh each frame from depthMap (see gaussianExecution).
    textureResources.gaussianOpaqueDepthSnapshot = createTexture(
        device: renderInfo.device,
        label: "Gaussian Opaque Depth Snapshot",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // Deferred Depth Texture
    textureResources.deferredDepthMap = createTexture(
        device: renderInfo.device,
        label: "Deferred Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // SSAO Depth Texture
    textureResources.ssaoDepthMap = createTexture(
        device: renderInfo.device,
        label: "ssao Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // SSAO Blur Depth Texture
    textureResources.ssaoBlurDepthTexture = createTexture(
        device: renderInfo.device,
        label: "ssao Blur Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // Deferred Color Texture
    textureResources.deferredColorMap = createTexture(
        device: renderInfo.device,
        label: "Deferred Color Texture",
        pixelFormat: wf.sceneColor,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    if renderInfo.opaqueSampleCount > 1 {
        textureResources.msaaDeferredColorMap = createTexture(
            device: renderInfo.device,
            label: "MSAA Deferred Color Texture",
            pixelFormat: wf.sceneColor,
            width: viewportWidth,
            height: viewportHeight,
            usage: [.renderTarget],
            storageMode: .memoryless,
            sampleCount: renderInfo.opaqueSampleCount
        )
    } else {
        textureResources.msaaDeferredColorMap = nil
    }

    // Post-process textures: nil them out on init/resize.
    // They are lazy-allocated by ensurePostProcessTexturesExist() only when
    // at least one post-process effect is enabled.
    textureResources.tonemapTexture = nil
    textureResources.blurTextureHor = nil
    textureResources.blurTextureVer = nil
    textureResources.colorCorrectionTexture = nil
    textureResources.bloomThresholdTextuture = nil
    textureResources.bloomCompositeTexture = nil
    textureResources.vignetteTexture = nil
    textureResources.chromaticAberrationTexture = nil
    textureResources.depthOfFieldTexture = nil

    // SSAO texture
    textureResources.ssaoTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Texture",
        pixelFormat: SSAOParams.shared.quality.textureFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // SSAO Blur texture
    textureResources.ssaoBlurTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Blur Texture",
        pixelFormat: SSAOParams.shared.quality.textureFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Gizmo Textures
    textureResources.gizmoDepthTexture = createTexture(
        device: renderInfo.device,
        label: "Gizmo Depth Texture",
        pixelFormat: renderInfo.depthPixelFormat,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    )

    // Gizmo Color texture
    textureResources.gizmoColorTexture = createTexture(
        device: renderInfo.device,
        label: "Gizmo Color Texture",
        pixelFormat: wf.gizmo,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Environment color texture
    textureResources.environmentColorMap = createTexture(
        device: renderInfo.device,
        label: "Environment Color Texture",
        pixelFormat: wf.environment,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Gaussian Color texture
    textureResources.gaussianColorMap = createTexture(
        device: renderInfo.device,
        label: "Gaussian Color Texture",
        pixelFormat: wf.gaussian,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.sceneCompositeTexture = createTexture(
        device: renderInfo.device,
        label: "Scene Composite Texture",
        pixelFormat: wf.sceneComposite,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.lookTexture = createTexture(
        device: renderInfo.device,
        label: "Look Output Texture",
        pixelFormat: wf.lookOutput,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.antiAliasingTexture = createTexture(
        device: renderInfo.device,
        label: "Anti-Aliasing Output Texture",
        pixelFormat: wf.lookOutput,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.smaaEdgesTexture = createTexture(
        device: renderInfo.device,
        label: "SMAA Edges Texture",
        pixelFormat: .rg8Unorm,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    textureResources.smaaBlendTexture = createTexture(
        device: renderInfo.device,
        label: "SMAA Blend Texture",
        pixelFormat: .rgba8Unorm,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .renderTarget],
        storageMode: .shared
    )

    textureResources.smaaAreaTexture = createSMAALookupTexture(
        device: renderInfo.device,
        label: "SMAA Area Texture",
        pixelFormat: .rg8Unorm,
        width: SMAATextureLayout.areaWidth,
        height: SMAATextureLayout.areaHeight,
        bytes: smaaAreaTexBytes,
        bytesPerRow: SMAATextureLayout.areaBytesPerRow,
        expectedByteCount: SMAATextureLayout.areaByteCount
    )

    textureResources.smaaSearchTexture = createSMAALookupTexture(
        device: renderInfo.device,
        label: "SMAA Search Texture",
        pixelFormat: .r8Unorm,
        width: SMAATextureLayout.searchWidth,
        height: SMAATextureLayout.searchHeight,
        bytes: smaaSearchTexBytes,
        bytesPerRow: SMAATextureLayout.searchBytesPerRow,
        expectedByteCount: SMAATextureLayout.searchByteCount
    )

    // HZB depth pyramid texture and per-mip views
    let hzbMipCount = calculateHZBMipCount(width: viewportWidth, height: viewportHeight)
    textureResources.hzbDepthPyramid = createTexture(
        device: renderInfo.device,
        label: "HZB Depth Pyramid",
        pixelFormat: .r32Float,
        width: viewportWidth,
        height: viewportHeight,
        usage: [.shaderRead, .shaderWrite],
        storageMode: .private,
        mipMapLevels: hzbMipCount
    )

    textureResources.hzbMipViews.removeAll(keepingCapacity: true)
    textureResources.hzbDebugMipTexture = nil
    renderInfo.hzbMipCount = 0

    if let hzbTexture = textureResources.hzbDepthPyramid {
        textureResources.hzbMipViews.reserveCapacity(hzbTexture.mipmapLevelCount)
        for level in 0 ..< hzbTexture.mipmapLevelCount {
            if let mipView = hzbTexture.makeTextureView(
                pixelFormat: hzbTexture.pixelFormat,
                textureType: .type2D,
                levels: level ..< (level + 1),
                slices: 0 ..< 1
            ) {
                mipView.label = "HZB Depth Pyramid Mip \(level)"
                textureResources.hzbMipViews.append(mipView)
            } else {
                Logger.logWarning(message: "Failed to create HZB mip view for level \(level)")
            }
        }

        renderInfo.hzbMipCount = textureResources.hzbMipViews.count
    }

    // XR stereo: allocate per-eye depth maps and HZB pyramids so each eye's
    // depth is kept separate, enabling geometrically correct per-eye occlusion culling.
    if renderInfo.isXRStereoMode {
        for eye in 0 ..< 2 {
            textureResources.depthMapEye[eye] = createTexture(
                device: renderInfo.device,
                label: "Depth Texture Eye \(eye)",
                pixelFormat: renderInfo.depthPixelFormat,
                width: viewportWidth,
                height: viewportHeight,
                usage: [.shaderRead, .renderTarget],
                storageMode: .private
            )

            let eyeHzb = createTexture(
                device: renderInfo.device,
                label: "HZB Depth Pyramid Eye \(eye)",
                pixelFormat: .r32Float,
                width: viewportWidth,
                height: viewportHeight,
                usage: [.shaderRead, .shaderWrite],
                storageMode: .private,
                mipMapLevels: hzbMipCount
            )
            textureResources.hzbDepthPyramidEye[eye] = eyeHzb

            textureResources.hzbMipViewsEye[eye].removeAll(keepingCapacity: true)
            if let hzbTex = eyeHzb {
                textureResources.hzbMipViewsEye[eye].reserveCapacity(hzbTex.mipmapLevelCount)
                for level in 0 ..< hzbTex.mipmapLevelCount {
                    if let mipView = hzbTex.makeTextureView(
                        pixelFormat: hzbTex.pixelFormat,
                        textureType: .type2D,
                        levels: level ..< (level + 1),
                        slices: 0 ..< 1
                    ) {
                        mipView.label = "HZB Depth Pyramid Eye \(eye) Mip \(level)"
                        textureResources.hzbMipViewsEye[eye].append(mipView)
                    } else {
                        Logger.logWarning(message: "Failed to create HZB mip view for eye \(eye) level \(level)")
                    }
                }
            }
        }
    }

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

/// Identifies a completed IBL bake so a later `initIBLResources()` call (e.g. from a
/// viewport resize, or a fresh headless renderer in a test) can reuse it instead of
/// re-decoding the HDR file and re-running the two blocking GPU prefilter passes.
private struct IBLBakeCacheKey: Equatable {
    let resolvedPath: String
    let modificationDate: Date
    let iblSize: Int
    let pixelFormat: MTLPixelFormat
    let device: ObjectIdentifier
}

private final class IBLBakeCacheState: @unchecked Sendable {
    let lock = NSLock()
    var key: IBLBakeCacheKey?
    var irradianceMap: MTLTexture?
    var specularMap: MTLTexture?
    var iblBRDFMap: MTLTexture?
    var environmentTexture: MTLTexture?
    var iblEnvironmentTexture: MTLTexture?
}

private let iblBakeCacheState = IBLBakeCacheState()

/// Invalidates the cached IBL bake so the next `initIBLResources()` call re-decodes and
/// re-prefilters the HDR environment, even if the resolved path/mtime look unchanged
/// (e.g. a file was rewritten in place within the same mtime-resolution window).
public func invalidateIBLBakeCache() {
    iblBakeCacheState.lock.lock()
    defer { iblBakeCacheState.lock.unlock() }
    iblBakeCacheState.key = nil
    iblBakeCacheState.irradianceMap = nil
    iblBakeCacheState.specularMap = nil
    iblBakeCacheState.iblBRDFMap = nil
    iblBakeCacheState.environmentTexture = nil
    iblBakeCacheState.iblEnvironmentTexture = nil
}

private func iblBakeCacheKey(
    hdrName: String, directory: URL?, iblSize: Int, pixelFormat: MTLPixelFormat, device: MTLDevice
) -> IBLBakeCacheKey? {
    guard let url = try? loadImage(hdrName, from: directory) else { return nil }
    guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
          let modificationDate = attributes[.modificationDate] as? Date
    else { return nil }

    return IBLBakeCacheKey(
        resolvedPath: url.path,
        modificationDate: modificationDate,
        iblSize: iblSize,
        pixelFormat: pixelFormat,
        device: ObjectIdentifier(device)
    )
}

func initIBLResources() {
    let wf = renderInfo.colorPipeline.working
    // IBL maps are low-frequency lookup textures — fixed small size,
    // NOT viewport-sized.  All three share a single render pass so
    // they must have the same dimensions.
    let iblSize = 256

    let cacheKey = iblBakeCacheKey(hdrName: hdrURL, directory: resourceURL, iblSize: iblSize, pixelFormat: wf.ibl, device: renderInfo.device)

    if let cacheKey {
        iblBakeCacheState.lock.lock()
        let isHit = iblBakeCacheState.key == cacheKey
        let irradianceMap = iblBakeCacheState.irradianceMap
        let specularMap = iblBakeCacheState.specularMap
        let iblBRDFMap = iblBakeCacheState.iblBRDFMap
        let environmentTexture = iblBakeCacheState.environmentTexture
        let iblEnvironmentTexture = iblBakeCacheState.iblEnvironmentTexture
        iblBakeCacheState.lock.unlock()

        if isHit, let irradianceMap, let specularMap, let iblBRDFMap, let environmentTexture, let iblEnvironmentTexture {
            textureResources.irradianceMap = irradianceMap
            textureResources.specularMap = specularMap
            textureResources.iblBRDFMap = iblBRDFMap
            textureResources.environmentTexture = environmentTexture
            textureResources.iblEnvironmentTexture = iblEnvironmentTexture

            renderInfo.iblOffscreenRenderPassDescriptor = MTLRenderPassDescriptor()
            renderInfo.iblOffscreenRenderPassDescriptor.renderTargetWidth = iblSize
            renderInfo.iblOffscreenRenderPassDescriptor.renderTargetHeight = iblSize
            renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[0].texture = irradianceMap
            renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[1].texture = specularMap
            renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[2].texture = iblBRDFMap

            iblSuccessful = true
            return
        }
    }

    // Irradiance Map
    textureResources.irradianceMap = createTexture(
        device: renderInfo.device,
        label: "IBL Irradiance Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared
    )

    // Specular Map (with mip-mapping)
    textureResources.specularMap = createTexture(
        device: renderInfo.device,
        label: "IBL Specular Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared,
        mipMapLevels: 6
    )

    // BRDF Map
    textureResources.iblBRDFMap = createTexture(
        device: renderInfo.device,
        label: "IBL BRDF Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .shaderWrite, .renderTarget],
        storageMode: .shared
    )

    // create a render pass descriptor
    renderInfo.iblOffscreenRenderPassDescriptor = MTLRenderPassDescriptor()

    renderInfo.iblOffscreenRenderPassDescriptor.renderTargetWidth = iblSize
    renderInfo.iblOffscreenRenderPassDescriptor.renderTargetHeight = iblSize
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[0].texture =
        textureResources.irradianceMap
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[1].texture =
        textureResources.specularMap
    renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[2].texture =
        textureResources.iblBRDFMap

    generateHDR(hdrURL, from: resourceURL)

    if iblSuccessful, let cacheKey,
       let irradianceMap = textureResources.irradianceMap,
       let specularMap = textureResources.specularMap,
       let iblBRDFMap = textureResources.iblBRDFMap,
       let environmentTexture = textureResources.environmentTexture,
       let iblEnvironmentTexture = textureResources.iblEnvironmentTexture
    {
        iblBakeCacheState.lock.lock()
        iblBakeCacheState.key = cacheKey
        iblBakeCacheState.irradianceMap = irradianceMap
        iblBakeCacheState.specularMap = specularMap
        iblBakeCacheState.iblBRDFMap = iblBRDFMap
        iblBakeCacheState.environmentTexture = environmentTexture
        iblBakeCacheState.iblEnvironmentTexture = iblEnvironmentTexture
        iblBakeCacheState.lock.unlock()
    }
}

func createShadowVertexDescriptor() -> MTLVertexDescriptor {
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].format =
        MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].bufferIndex = Int(
        shadowPassModelPositionIndex.rawValue
    )
    vertexDescriptor.attributes[Int(shadowPassModelPositionIndex.rawValue)].offset = 0

    // set joint id
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].format =
        MTLVertexFormat.ushort4
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].bufferIndex = Int(
        shadowPassJointIdIndex.rawValue
    )
    vertexDescriptor.attributes[Int(shadowPassJointIdIndex.rawValue)].offset = 0

    // set joint weights
    vertexDescriptor.attributes[Int(shadowPassJointWeightsIndex.rawValue)].format =
        MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(shadowPassJointWeightsIndex.rawValue)].bufferIndex = Int(
        shadowPassJointWeightsIndex.rawValue
    )
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
        stride: MemoryLayout<simd_float4>.stride
    )

    vertexDescriptor.model.layouts[Int(modelPassNormalIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride
    )

    vertexDescriptor.model.layouts[Int(modelPassUVIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float2>.stride
    )

    vertexDescriptor.model.layouts[Int(modelPassTangentIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride
    )

    vertexDescriptor.model.layouts[Int(modelPassJointIdIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_ushort4>.stride
    )

    vertexDescriptor.model.layouts[Int(modelPassJointWeightsIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride
    )

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

public func createPostProcessVertexDescriptor() -> MTLVertexDescriptor {
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

func createGaussianVertexDescriptor() -> MTLVertexDescriptor {
    // tell the gpu how data is organized
    MTLVertexDescriptor()
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

/// Lazily allocates the post-process render target chain.
/// Called from the render graph when at least one post-process effect is enabled.
func ensurePostProcessTexturesExist() {
    // Already allocated — nothing to do.
    guard textureResources.depthOfFieldTexture == nil else { return }

    let wf = renderInfo.colorPipeline.working
    let w = max(1, Int(renderInfo.viewPort.x))
    let h = max(1, Int(renderInfo.viewPort.y))
    let usage: MTLTextureUsage = [.shaderRead, .renderTarget, .shaderWrite]
    let storage: MTLStorageMode = .shared

    textureResources.tonemapTexture = createTexture(
        device: renderInfo.device, label: "Tonemap Texture",
        pixelFormat: wf.sceneColor, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.blurTextureHor = createTexture(
        device: renderInfo.device, label: "Blur Texture Hor",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.blurTextureVer = createTexture(
        device: renderInfo.device, label: "Blur Texture Ver",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.colorCorrectionTexture = createTexture(
        device: renderInfo.device, label: "Color Correction Debug Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.bloomThresholdTextuture = createTexture(
        device: renderInfo.device, label: "Bloom Threshold Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.bloomCompositeTexture = createTexture(
        device: renderInfo.device, label: "Bloom Composite Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.vignetteTexture = createTexture(
        device: renderInfo.device, label: "Vignette Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.chromaticAberrationTexture = createTexture(
        device: renderInfo.device, label: "Chromatic Aberration Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )

    textureResources.depthOfFieldTexture = createTexture(
        device: renderInfo.device, label: "Depth of Field Texture",
        pixelFormat: wf.postProcess, width: w, height: h,
        usage: usage, storageMode: storage
    )
}

func initSSAOResources() {
    // init ssao kernel based on quality setting
    let sampleCount = SSAOParams.shared.quality.sampleCount
    let kernelData = generateSSAOKernel(sampleCount: sampleCount)
    bufferResources.ssaoKernelBuffer = renderInfo.device.makeBuffer(bytes: kernelData,
                                                                    length: MemoryLayout<SIMD3<Float>>.stride * kernelData.count,
                                                                    options: [])

    // init ssao noise texture
    textureResources.ssaoNoiseTexture = generateSSAONoiseTexture(device: renderInfo.device)
}

/// Reinitialize SSAO textures when quality changes
func reinitSSAOTextures() {
    let fullWidth = Int(renderInfo.viewPort.x)
    let fullHeight = Int(renderInfo.viewPort.y)
    if fullWidth == 0 || fullHeight == 0 { return }

    let quality = SSAOParams.shared.quality
    let scale = quality.resolutionScale
    let format = quality.textureFormat

    let ssaoWidth = Int(Float(fullWidth) * scale)
    let ssaoHeight = Int(Float(fullHeight) * scale)

    // Always recreate full-res textures with quality format (for High quality or final output)
    textureResources.ssaoTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Texture",
        pixelFormat: format,
        width: fullWidth,
        height: fullHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    textureResources.ssaoBlurTexture = createTexture(
        device: renderInfo.device,
        label: "SSAO Blur Texture",
        pixelFormat: format,
        width: fullWidth,
        height: fullHeight,
        usage: [.shaderRead, .renderTarget, .shaderWrite],
        storageMode: .shared
    )

    // Recreate render pass descriptors for full-res
    renderInfo.ssaoRenderPassDescriptor = createRenderPassDescriptor(
        width: fullWidth,
        height: fullHeight,
        colorAttachments: [
            (textureResources.ssaoTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: nil
    )

    renderInfo.ssaoBlurRenderPassDescriptor = createRenderPassDescriptor(
        width: fullWidth,
        height: fullHeight,
        colorAttachments: [
            (textureResources.ssaoBlurTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
        ],
        depthAttachment: nil
    )

    // Create low-res SSAO texture if needed
    if scale < 1.0 {
        textureResources.ssaoTextureLowRes = createTexture(
            device: renderInfo.device,
            label: "SSAO Texture Low Res",
            pixelFormat: format,
            width: ssaoWidth,
            height: ssaoHeight,
            usage: [.shaderRead, .renderTarget],
            storageMode: .shared
        )

        textureResources.ssaoBlurTextureLowRes = createTexture(
            device: renderInfo.device,
            label: "SSAO Blur Texture Low Res",
            pixelFormat: format,
            width: ssaoWidth,
            height: ssaoHeight,
            usage: [.shaderRead, .renderTarget],
            storageMode: .shared
        )

        textureResources.ssaoBlurHorizontal = createTexture(
            device: renderInfo.device,
            label: "SSAO Blur Horizontal",
            pixelFormat: format,
            width: ssaoWidth,
            height: ssaoHeight,
            usage: [.shaderRead, .renderTarget],
            storageMode: .shared
        )

        // Low-res render pass descriptor
        renderInfo.ssaoLowResRenderPassDescriptor = createRenderPassDescriptor(
            width: ssaoWidth,
            height: ssaoHeight,
            colorAttachments: [
                (textureResources.ssaoTextureLowRes, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            ],
            depthAttachment: nil
        )

        // Bilateral blur render pass descriptors
        renderInfo.ssaoBlurHorizontalRenderPassDescriptor = createRenderPassDescriptor(
            width: ssaoWidth,
            height: ssaoHeight,
            colorAttachments: [
                (textureResources.ssaoBlurHorizontal, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            ],
            depthAttachment: nil
        )

        renderInfo.ssaoBlurVerticalRenderPassDescriptor = createRenderPassDescriptor(
            width: ssaoWidth,
            height: ssaoHeight,
            colorAttachments: [
                (textureResources.ssaoBlurTextureLowRes, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            ],
            depthAttachment: nil
        )

        // Upsample render pass descriptor (full res output)
        renderInfo.ssaoUpsampleRenderPassDescriptor = createRenderPassDescriptor(
            width: fullWidth,
            height: fullHeight,
            colorAttachments: [
                (textureResources.ssaoBlurTexture, .clear, .store, MTLClearColorMake(0.0, 0.0, 0.0, 0.0)),
            ],
            depthAttachment: nil
        )
    }

    // Reinitialize kernel if sample count changed
    let sampleCount = quality.sampleCount
    if ssaoKernelSize != sampleCount {
        let kernelData = generateSSAOKernel(sampleCount: sampleCount)
        bufferResources.ssaoKernelBuffer = renderInfo.device.makeBuffer(bytes: kernelData,
                                                                        length: MemoryLayout<SIMD3<Float>>.stride * kernelData.count,
                                                                        options: [])
    }
}
