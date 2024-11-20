
//
//  RenderInitializer.swift
//  Untold Engine
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import MetalKit
import simd

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
    initBoundingBoxBuffer()
    initRTXAccumulationBuffer()
}

func initRenderPassDescriptors() {
    // shadow render pass
    renderInfo.shadowRenderPassDescriptor = MTLRenderPassDescriptor()
    renderInfo.shadowRenderPassDescriptor.renderTargetWidth = 1024
    renderInfo.shadowRenderPassDescriptor.renderTargetHeight = 1024
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].texture = nil
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].storeAction = .dontCare
    renderInfo.shadowRenderPassDescriptor.depthAttachment.texture = textureResources.shadowMap
    renderInfo.shadowRenderPassDescriptor.depthAttachment.clearDepth = 1.0
    renderInfo.shadowRenderPassDescriptor.depthAttachment.loadAction = .clear
    renderInfo.shadowRenderPassDescriptor.depthAttachment.storeAction = .store

    // offscreen render pass descriptor
    renderInfo.offscreenRenderPassDescriptor = MTLRenderPassDescriptor()
    renderInfo.offscreenRenderPassDescriptor.renderTargetWidth = Int(renderInfo.viewPort.x)
    renderInfo.offscreenRenderPassDescriptor.renderTargetHeight = Int(renderInfo.viewPort.y)

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].texture =
        textureResources.colorMap
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].texture =
        textureResources.normalMap
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)].texture =
        textureResources.positionMap

    renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture = textureResources.depthMap
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].loadAction =
        .clear // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].clearColor =
        MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].storeAction =
        .store // or .load

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].loadAction =
        .clear // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].clearColor =
        MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
        .storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
        .loadAction = .clear // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
        .clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
        .storeAction = .store
}

func initTextureResources() {
    // shadow texture descriptor

    let shadowDescriptor = MTLTextureDescriptor()
    shadowDescriptor.textureType = .type2D
    shadowDescriptor.pixelFormat = .depth32Float
    shadowDescriptor.width = 1024
    shadowDescriptor.height = 1024
    shadowDescriptor.usage = [.shaderRead, .renderTarget]
    shadowDescriptor.storageMode = .private

    // create texture
    textureResources.shadowMap = renderInfo.device.makeTexture(descriptor: shadowDescriptor)
    textureResources.shadowMap?.label = "Shadow Texture"

    let colorDescriptor = MTLTextureDescriptor()
    colorDescriptor.textureType = .type2D
    colorDescriptor.pixelFormat = renderInfo.colorPixelFormat
    colorDescriptor.width = Int(renderInfo.viewPort.x)
    colorDescriptor.height = Int(renderInfo.viewPort.y)
    colorDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    colorDescriptor.storageMode = .shared

    // create texture
    textureResources.colorMap = renderInfo.device.makeTexture(descriptor: colorDescriptor)
    textureResources.colorMap?.label = "Color Texture"

    let normalDescriptor = MTLTextureDescriptor()
    normalDescriptor.textureType = .type2D
    normalDescriptor.pixelFormat = .rgba16Float
    normalDescriptor.width = Int(renderInfo.viewPort.x)
    normalDescriptor.height = Int(renderInfo.viewPort.y)
    normalDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    normalDescriptor.storageMode = .shared

    textureResources.normalMap = renderInfo.device.makeTexture(descriptor: normalDescriptor)
    textureResources.normalMap?.label = "Normal Texture"

    let positionDescriptor = MTLTextureDescriptor()
    positionDescriptor.textureType = .type2D
    positionDescriptor.pixelFormat = .rgba16Float
    positionDescriptor.width = Int(renderInfo.viewPort.x)
    positionDescriptor.height = Int(renderInfo.viewPort.y)
    positionDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    positionDescriptor.storageMode = .shared

    textureResources.positionMap = renderInfo.device.makeTexture(descriptor: positionDescriptor)
    textureResources.positionMap?.label = "Position Texture"

    let depthDescriptor = MTLTextureDescriptor()
    depthDescriptor.textureType = .type2D
    depthDescriptor.pixelFormat = renderInfo.depthPixelFormat
    depthDescriptor.width = Int(renderInfo.viewPort.x)
    depthDescriptor.height = Int(renderInfo.viewPort.y)
    depthDescriptor.usage = [.shaderRead, .renderTarget]
    depthDescriptor.storageMode = .shared

    textureResources.depthMap = renderInfo.device.makeTexture(descriptor: depthDescriptor)
    textureResources.depthMap?.label = "Offscreen Depth Texture"

    let rayTracingDescriptor = MTLTextureDescriptor()
    rayTracingDescriptor.textureType = .type2D
    rayTracingDescriptor.pixelFormat = renderInfo.colorPixelFormat
    rayTracingDescriptor.width = Int(renderInfo.viewPort.x)
    rayTracingDescriptor.height = Int(renderInfo.viewPort.y)
    rayTracingDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    rayTracingDescriptor.storageMode = .shared

    // create texture
    textureResources.rayTracingDestTexture = renderInfo.device.makeTexture(
        descriptor: rayTracingDescriptor)
    textureResources.rayTracingDestTexture?.label = "Ray Tracing Dest Texture"

    textureResources.rayTracingPreviousTexture = renderInfo.device.makeTexture(
        descriptor: rayTracingDescriptor)
    textureResources.rayTracingPreviousTexture?.label = "Ray Tracing Prev Texture"

    let rayTracingRandomDescriptor = MTLTextureDescriptor()
    rayTracingRandomDescriptor.textureType = .type2D
    rayTracingRandomDescriptor.pixelFormat = .r32Uint
    rayTracingRandomDescriptor.width = Int(renderInfo.viewPort.x)
    rayTracingRandomDescriptor.height = Int(renderInfo.viewPort.y)
    rayTracingRandomDescriptor.usage = [.shaderRead]
    rayTracingRandomDescriptor.storageMode = .shared

    textureResources.rayTracingRandomTexture = renderInfo.device.makeTexture(
        descriptor: rayTracingRandomDescriptor)
    textureResources.rayTracingRandomTexture?.label = "Ray Tracing Random Texture"

    let width = Int(renderInfo.viewPort.x)
    let height = Int(renderInfo.viewPort.y)
    let randomValues = UnsafeMutablePointer<UInt32>.allocate(capacity: width * height)

    for i in 0 ..< (width * height) {
        randomValues[i] = UInt32.random(in: 0 ..< (1024 * 1024))
    }

    let region = MTLRegionMake2D(0, 0, width, height)
    textureResources.rayTracingRandomTexture?.replace(
        region: region, mipmapLevel: 0, withBytes: randomValues,
        bytesPerRow: MemoryLayout<UInt32>.size * width
    )

    randomValues.deallocate()

    let rayTracingTextArrayDescriptor = MTLTextureDescriptor()
    rayTracingTextArrayDescriptor.textureType = .type2D
    rayTracingTextArrayDescriptor.pixelFormat = renderInfo.colorPixelFormat
    rayTracingTextArrayDescriptor.width = Int(renderInfo.viewPort.x)
    rayTracingTextArrayDescriptor.height = Int(renderInfo.viewPort.y)
    rayTracingTextArrayDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    rayTracingTextArrayDescriptor.storageMode = .shared
    // rayTracingTextArrayDescriptor.arrayLength = 10

    textureResources.rayTracingDestTextureArray = renderInfo.device.makeTexture(
        descriptor: rayTracingTextArrayDescriptor)
    textureResources.rayTracingDestTextureArray?.label = "Ray Tracing Texture Array"

    textureResources.rayTracingAccumTexture = Array(
        repeating: textureResources.rayTracingDestTexture!, count: 2
    )

    for i in 0 ..< 2 {
        textureResources.rayTracingAccumTexture[i] = renderInfo.device.makeTexture(
            descriptor: rayTracingDescriptor)!
        textureResources.rayTracingAccumTexture[i].label = String(i)
    }
}

func initIBLResources() {
    let width = Int(renderInfo.viewPort.x)
    let height = Int(renderInfo.viewPort.y)

    // irradiance map
    let irradianceMapDescriptor = MTLTextureDescriptor()
    irradianceMapDescriptor.textureType = .type2D
    irradianceMapDescriptor.width = width
    irradianceMapDescriptor.height = height
    irradianceMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
    irradianceMapDescriptor.storageMode = .shared
    irradianceMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

    textureResources.irradianceMap = renderInfo.device.makeTexture(
        descriptor: irradianceMapDescriptor)
    textureResources.irradianceMap?.label = "IBL Irradiance Texture"

    // specular map
    let specularMapDescriptor = MTLTextureDescriptor()
    specularMapDescriptor.textureType = .type2D
    specularMapDescriptor.width = width
    specularMapDescriptor.height = height
    specularMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
    specularMapDescriptor.mipmapLevelCount = 6
    specularMapDescriptor.storageMode = .shared
    specularMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

    textureResources.specularMap = renderInfo.device.makeTexture(descriptor: specularMapDescriptor)
    textureResources.specularMap?.label = "IBL Specular Texture"

    // texture needs to be mip-mapped

    // brdf map
    let brdfMapDescriptor = MTLTextureDescriptor()
    brdfMapDescriptor.textureType = .type2D
    brdfMapDescriptor.width = width
    brdfMapDescriptor.height = height
    brdfMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
    brdfMapDescriptor.storageMode = .shared
    brdfMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

    textureResources.iblBRDFMap = renderInfo.device.makeTexture(descriptor: brdfMapDescriptor)
    textureResources.iblBRDFMap?.label = "IBL brdf Texture"

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

func generateHDR(_ hdrName: String, from directory: URL? = nil) {
    do {
        textureResources.environmentTexture = try loadHDR(hdrName, from: directory)
        textureResources.environmentTexture?.label = "environment texture"

        // If the environment was properly loaded, then mip-map it

        guard let envMipMapCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblMipMapCreationFailed)
            return
        }

        guard
            let envMipMapBlitEncoder: MTLBlitCommandEncoder =
            envMipMapCommandBuffer.makeBlitCommandEncoder()
        else {
            handleError(.iblMipMapBlitCreationFailed)
            return
        }

        envMipMapBlitEncoder.generateMipmaps(for: textureResources.environmentTexture!)

        // add a completion handler here
        envMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) in
        }

        envMipMapBlitEncoder.endEncoding()
        envMipMapCommandBuffer.commit()
        envMipMapCommandBuffer.waitUntilCompleted()

        // execute the ibl pre-filter
        guard
            let iblPreFilterCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblPreFilterCreationFailed)
            return
        }

        executeIBLPreFilterPass(
            uCommandBuffer: iblPreFilterCommandBuffer, textureResources.environmentTexture!
        )

        // add a completion handler here
        iblPreFilterCommandBuffer.addCompletedHandler { (_ commandBuffer) in
        }

        iblPreFilterCommandBuffer.commit()
        iblPreFilterCommandBuffer.waitUntilCompleted()

        // mipmap the specular texture

        guard
            let specMipMapCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
        else {
            handleError(.iblSpecMipMapCreationFailed)
            return
        }

        guard
            let specMipMapBlitEncoder: MTLBlitCommandEncoder =
            specMipMapCommandBuffer.makeBlitCommandEncoder()
        else {
            handleError(.iblSpecMipMapBlitCreationFailed)
            return
        }

        specMipMapBlitEncoder.generateMipmaps(for: textureResources.specularMap!)

        // add a completion handler here
        specMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) in

            iblSuccessful = true
            // print("IBL Pre-Filters created successfully")
        }

        specMipMapBlitEncoder.endEncoding()
        specMipMapCommandBuffer.commit()
        specMipMapCommandBuffer.waitUntilCompleted()

    } catch {
        handleError(.iBLCreationFailed)
    }
}

func createShadowVertexDescriptor() -> MTLVertexDescriptor{
    
    // set the vertex descriptor
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].format =
        MTLVertexFormat.float4
    vertexDescriptor.attributes[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].bufferIndex = Int(
        ShadowBufferIndices.shadowModelPositionIndex.rawValue)
    vertexDescriptor.attributes[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].offset = 0

    // stride
    vertexDescriptor.layouts[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].stride =
        MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].stepFunction =
        MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[Int(ShadowBufferIndices.shadowModelPositionIndex.rawValue)].stepRate = 1
    
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

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributePosition,
        format: .float4,
        offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeNormal,
        format: .float4,
        offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeTextureCoordinate,
        format: .float2,
        offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeTangent, format: .float4, offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassJointIdIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeJointIndices, format: .uShort4, offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassJointIdIndex.rawValue)
    )

    vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassJointWeightsIndex.rawValue)] = MDLVertexAttribute(
        name: MDLVertexAttributeJointWeights, format: .float4, offset: 0,
        bufferIndex: Int(ModelPassBufferIndices.modelPassJointWeightsIndex.rawValue)
    )

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float2>.stride)

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassJointIdIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_ushort4>.stride)

    vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassJointWeightsIndex.rawValue)] = MDLVertexBufferLayout(
        stride: MemoryLayout<simd_float4>.stride)

    guard let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.model) else{
        return nil
    }
    
    return vertexDescriptor
    
}

func createGeometryVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createCompositeVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createPreCompositeVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createDebugVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createPostProcessVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createIBLPreFilterVertexDescriptor() -> MTLVertexDescriptor{
    
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

func createEnvironmentVertexDescriptor() -> MTLVertexDescriptor{

    // tell the gpu how data is organized
    let vertexDescriptor = MTLVertexDescriptor()

    // set position
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassPositionIndex.rawValue)].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassPositionIndex.rawValue)].offset = 0

    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassNormalIndex.rawValue)].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassNormalIndex.rawValue)].bufferIndex = 0
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassNormalIndex.rawValue)].offset =
        MemoryLayout<simd_float3>.stride

    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassUVIndex.rawValue)].format = MTLVertexFormat.float2
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassUVIndex.rawValue)].bufferIndex = 0
    vertexDescriptor.attributes[Int(EnvironmentPassBufferIndices.envPassUVIndex.rawValue)].offset =
        2 * MemoryLayout<simd_float3>.stride

    vertexDescriptor.layouts[0].stride =
        2 * MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride
    
    return vertexDescriptor
}

func createPipeline(
    vertexShader: String,
    fragmentShader: String?,
    vertexDescriptor:MTLVertexDescriptor?,
    colorFormats: [MTLPixelFormat],
    depthFormat: MTLPixelFormat,
    depthCompareFunction: MTLCompareFunction = .lessEqual,
    depthEnabled: Bool = true,
    blendEnabled: Bool = false,
    name: String ) -> RenderPipeline? {
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    let depthStateDescriptor = MTLDepthStencilDescriptor()
    
    do{
        
        let vertexFunction = renderInfo.library.makeFunction(name: vertexShader)!
                pipelineDescriptor.vertexFunction = vertexFunction

        if let fragmentShader = fragmentShader {
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

        depthStateDescriptor.depthCompareFunction = .lessEqual
        depthStateDescriptor.isDepthWriteEnabled = true

        let pipelineState = try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        let depthState = renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)

        return RenderPipeline(
            pipelineState: pipelineState,
            depthState: depthState,
            success: true,
            name: name
        )
        
    }catch{
        Logger.logError(message: "Failed to create pipeline \(name): \(error)")
        return nil
    }
    
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
    ){
        geometryPipeline = geometryPipe
    }
    
    if let compositePipe = createPipeline(
        vertexShader: "vertexCompositeShader",
        fragmentShader: "fragmentCompositeShader",
        vertexDescriptor: createCompositeVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Composite Pipeline"
    ){
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
    ){
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
    ){
        debuggerPipeline = debugPipe
    }
    
    if let postProcessPipe = createPipeline(
        vertexShader: "vertexPostProcessShader",
        fragmentShader: "fragmentPostProcessShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Post-Process Pipeline"
    ){
        postProcessPipeline = postProcessPipe
    }
    
    if let tonePipe = createPipeline(
        vertexShader: "vertexTonemappingShader",
        fragmentShader: "fragmentTonemappingShader",
        vertexDescriptor: createPostProcessVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat, .rgba16Float, .rgba16Float],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Tone-mapping Pipeline"
    ){
        tonemappingPipeline = tonePipe
    }
    
    if let environmentPipe = createPipeline(
        vertexShader: "vertexEnvironmentShader",
        fragmentShader: "fragmentEnvironmentShader",
        vertexDescriptor: createEnvironmentVertexDescriptor(),
        colorFormats: [renderInfo.colorPixelFormat],
        depthFormat: renderInfo.depthPixelFormat,
        depthEnabled: false,
        name: "Environment Pipeline"
    ){
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
        depthFormat: renderInfo.depthPixelFormat,
        depthCompareFunction: .less,
        depthEnabled: false,
        name: "IBL-Pre Filer Pipeline"
    ){
        iblPrefilterPipeline = iblPreFilterPipe
    }
    
    
}

func updateBoundingBoxBuffer(min: SIMD3<Float>, max: SIMD3<Float>) {
    let vertices: [SIMD4<Float>] = [
        // Bottom face
        SIMD4(min.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, min.z, 1.0),
        SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, min.y, max.z, 1.0),
        SIMD4(max.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, max.z, 1.0),
        SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, min.y, min.z, 1.0),

        // Top face
        SIMD4(min.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
        SIMD4(max.x, max.y, min.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
        SIMD4(max.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
        SIMD4(min.x, max.y, max.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),

        // Vertical edges
        SIMD4(min.x, min.y, min.z, 1.0), SIMD4(min.x, max.y, min.z, 1.0),
        SIMD4(max.x, min.y, min.z, 1.0), SIMD4(max.x, max.y, min.z, 1.0),
        SIMD4(max.x, min.y, max.z, 1.0), SIMD4(max.x, max.y, max.z, 1.0),
        SIMD4(min.x, min.y, max.z, 1.0), SIMD4(min.x, max.y, max.z, 1.0),
    ]

    let bufferPointer = bufferResources.boundingBoxBuffer?.contents()
    bufferPointer!.copyMemory(
        from: vertices, byteCount: vertices.count * MemoryLayout<SIMD4<Float>>.stride
    )
}
