
//
//  RenderSystem.swift
//  Untold Engine 
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import MetalKit
import simd

func initBufferResources() {

  let grid = {

    //assign the buffer to gridVertexBuffer
    bufferResources.gridVertexBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<simd_float3>.stride * gridVertices.count,
      options: [MTLResourceOptions.storageModeShared])

    bufferResources.gridVertexBuffer!.contents().initializeMemory(
      as: simd_float3.self, from: gridVertices, count: gridVertices.count)

    bufferResources.gridVertexBuffer?.label = "grid vertices"

    bufferResources.gridUniforms = renderInfo.device.makeBuffer(
      length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
    bufferResources.gridUniforms?.label = "grid uniforms"
  }

  let composite = {

    //set the bufferResources
    bufferResources.quadVerticesBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<simd_float3>.stride * quadVertices.count,
      options: [MTLResourceOptions.storageModeShared])!

    bufferResources.quadTexCoordsBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<simd_float2>.stride * quadTexCoords.count,
      options: [MTLResourceOptions.storageModeShared])!

    bufferResources.quadIndexBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<UInt16>.stride * quadIndices.count,
      options: [MTLResourceOptions.storageModeShared])!

    bufferResources.quadVerticesBuffer?.label = "quad vertices"
    bufferResources.quadTexCoordsBuffer?.label = "quad tex"
    bufferResources.quadIndexBuffer?.label = "quad index"

    bufferResources.quadVerticesBuffer!.contents().initializeMemory(
      as: simd_float3.self, from: quadVertices, count: quadVertices.count)

    bufferResources.quadTexCoordsBuffer!.contents().initializeMemory(
      as: simd_float2.self, from: quadTexCoords, count: quadTexCoords.count)

    bufferResources.quadIndexBuffer!.contents().initializeMemory(
      as: UInt16.self, from: quadIndices, count: quadIndices.count)

  }

  let pointLights = {

    bufferResources.pointLightBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<PointLight>.stride * maxNumPointLights,
      options: [MTLResourceOptions.storageModeShared])!

    bufferResources.pointLightBuffer?.label = "Point Lights"
  }

  let boundingBox = {

    bufferResources.boundingBoxBuffer = renderInfo.device.makeBuffer(
      length: MemoryLayout<simd_float4>.stride * boundingBoxVertexCount,
      options: MTLResourceOptions.storageModeShared)
    bufferResources.boundingBoxBuffer?.label = "Bounding Box Buffer"
  }

  let rtxAccumulation = {
    let width = renderInfo.viewPort.x
    let height = renderInfo.viewPort.y
    let bufferLength = MemoryLayout<simd_float3>.stride * Int(width) * Int(height)
    bufferResources.accumulationBuffer = renderInfo.device.makeBuffer(
      length: bufferLength, options: .storageModeShared)
  }

  grid()
  composite()
  pointLights()
  boundingBox()
  rtxAccumulation()
}

func initRenderPassDescriptors() {

  //shadow render pass
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

  //offscreen render pass descriptor
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
    .clear  // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].clearColor =
    MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].storeAction =
    .store  // or .load

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].loadAction =
    .clear  // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].clearColor =
    MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)]
    .storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
    .loadAction = .clear  // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
    .clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)]
    .storeAction = .store

}

func initTextureResources() {

  //shadow texture descriptor

  let shadowDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  shadowDescriptor.textureType = .type2D
  shadowDescriptor.pixelFormat = .depth32Float
  shadowDescriptor.width = 1024
  shadowDescriptor.height = 1024
  shadowDescriptor.usage = [.shaderRead, .renderTarget]
  shadowDescriptor.storageMode = .private

  //create texture
  textureResources.shadowMap = renderInfo.device.makeTexture(descriptor: shadowDescriptor)
  textureResources.shadowMap?.label = "Shadow Texture"

  let colorDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  colorDescriptor.textureType = .type2D
  colorDescriptor.pixelFormat = renderInfo.colorPixelFormat
  colorDescriptor.width = Int(renderInfo.viewPort.x)
  colorDescriptor.height = Int(renderInfo.viewPort.y)
  colorDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
  colorDescriptor.storageMode = .shared

  //create texture
  textureResources.colorMap = renderInfo.device.makeTexture(descriptor: colorDescriptor)
  textureResources.colorMap?.label = "Color Texture"

  let normalDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  normalDescriptor.textureType = .type2D
  normalDescriptor.pixelFormat = .rgba16Float
  normalDescriptor.width = Int(renderInfo.viewPort.x)
  normalDescriptor.height = Int(renderInfo.viewPort.y)
  normalDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
  normalDescriptor.storageMode = .shared

  textureResources.normalMap = renderInfo.device.makeTexture(descriptor: normalDescriptor)
  textureResources.normalMap?.label = "Normal Texture"

  let positionDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  positionDescriptor.textureType = .type2D
  positionDescriptor.pixelFormat = .rgba16Float
  positionDescriptor.width = Int(renderInfo.viewPort.x)
  positionDescriptor.height = Int(renderInfo.viewPort.y)
  positionDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
  positionDescriptor.storageMode = .shared

  textureResources.positionMap = renderInfo.device.makeTexture(descriptor: positionDescriptor)
  textureResources.positionMap?.label = "Position Texture"

  let depthDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  depthDescriptor.textureType = .type2D
  depthDescriptor.pixelFormat = renderInfo.depthPixelFormat
  depthDescriptor.width = Int(renderInfo.viewPort.x)
  depthDescriptor.height = Int(renderInfo.viewPort.y)
  depthDescriptor.usage = [.shaderRead, .renderTarget]
  depthDescriptor.storageMode = .shared

  textureResources.depthMap = renderInfo.device.makeTexture(descriptor: depthDescriptor)
  textureResources.depthMap?.label = "Offscreen Depth Texture"

  let rayTracingDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  rayTracingDescriptor.textureType = .type2D
  rayTracingDescriptor.pixelFormat = renderInfo.colorPixelFormat
  rayTracingDescriptor.width = Int(renderInfo.viewPort.x)
  rayTracingDescriptor.height = Int(renderInfo.viewPort.y)
  rayTracingDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
  rayTracingDescriptor.storageMode = .shared

  //create texture
  textureResources.rayTracingDestTexture = renderInfo.device.makeTexture(
    descriptor: rayTracingDescriptor)
  textureResources.rayTracingDestTexture?.label = "Ray Tracing Dest Texture"

  textureResources.rayTracingPreviousTexture = renderInfo.device.makeTexture(
    descriptor: rayTracingDescriptor)
  textureResources.rayTracingPreviousTexture?.label = "Ray Tracing Prev Texture"

  let rayTracingRandomDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
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

  for i in 0..<(width * height) {
    randomValues[i] = UInt32.random(in: 0..<(1024 * 1024))
  }

  let region = MTLRegionMake2D(0, 0, width, height)
  textureResources.rayTracingRandomTexture?.replace(
    region: region, mipmapLevel: 0, withBytes: randomValues,
    bytesPerRow: MemoryLayout<UInt32>.size * width)

  randomValues.deallocate()

  let rayTracingTextArrayDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  rayTracingTextArrayDescriptor.textureType = .type2D
  rayTracingTextArrayDescriptor.pixelFormat = renderInfo.colorPixelFormat
  rayTracingTextArrayDescriptor.width = Int(renderInfo.viewPort.x)
  rayTracingTextArrayDescriptor.height = Int(renderInfo.viewPort.y)
  rayTracingTextArrayDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
  rayTracingTextArrayDescriptor.storageMode = .shared
  //rayTracingTextArrayDescriptor.arrayLength = 10

  textureResources.rayTracingDestTextureArray = renderInfo.device.makeTexture(
    descriptor: rayTracingTextArrayDescriptor)
  textureResources.rayTracingDestTextureArray?.label = "Ray Tracing Texture Array"

  textureResources.rayTracingAccumTexture = Array(
    repeating: textureResources.rayTracingDestTexture!, count: 2)

  for i in 0..<2 {
    textureResources.rayTracingAccumTexture[i] = renderInfo.device.makeTexture(
      descriptor: rayTracingDescriptor)!
    textureResources.rayTracingAccumTexture[i].label = String(i)
  }

}

func initIBLResources() {

  let width: Int = Int(renderInfo.viewPort.x)
  let height: Int = Int(renderInfo.viewPort.y)

  //irradiance map
  let irradianceMapDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  irradianceMapDescriptor.textureType = .type2D
  irradianceMapDescriptor.width = width
  irradianceMapDescriptor.height = height
  irradianceMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
  irradianceMapDescriptor.storageMode = .shared
  irradianceMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

  textureResources.irradianceMap = renderInfo.device.makeTexture(
    descriptor: irradianceMapDescriptor)
  textureResources.irradianceMap?.label = "IBL Irradiance Texture"

  //specular map
  let specularMapDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  specularMapDescriptor.textureType = .type2D
  specularMapDescriptor.width = width
  specularMapDescriptor.height = height
  specularMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
  specularMapDescriptor.mipmapLevelCount = 6
  specularMapDescriptor.storageMode = .shared
  specularMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

  textureResources.specularMap = renderInfo.device.makeTexture(descriptor: specularMapDescriptor)
  textureResources.specularMap?.label = "IBL Specular Texture"

  //texture needs to be mip-mapped

  //brdf map
  let brdfMapDescriptor: MTLTextureDescriptor = MTLTextureDescriptor()
  brdfMapDescriptor.textureType = .type2D
  brdfMapDescriptor.width = width
  brdfMapDescriptor.height = height
  brdfMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
  brdfMapDescriptor.storageMode = .shared
  brdfMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]

  textureResources.iblBRDFMap = renderInfo.device.makeTexture(descriptor: brdfMapDescriptor)
  textureResources.iblBRDFMap?.label = "IBL brdf Texture"

  //create a render pass descriptor
  renderInfo.iblOffscreenRenderPassDescriptor = MTLRenderPassDescriptor()

  renderInfo.iblOffscreenRenderPassDescriptor.renderTargetWidth = Int(renderInfo.viewPort.x)
  renderInfo.iblOffscreenRenderPassDescriptor.renderTargetHeight = Int(renderInfo.viewPort.y)
  renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[0].texture =
    textureResources.irradianceMap
  renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[1].texture =
    textureResources.specularMap
  renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[2].texture =
    textureResources.iblBRDFMap

  generateHDR(hdrURL,from: resourceURL)

}

func generateHDR(_ hdrName: String, from directory: URL? = nil) {

  do {
    textureResources.environmentTexture = try loadHDR(hdrName, from: directory)
    textureResources.environmentTexture?.label = "environment texture"


    //If the environment was properly loaded, then mip-map it

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

    //add a completion handler here
    envMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in

    }

    envMipMapBlitEncoder.endEncoding()
    envMipMapCommandBuffer.commit()
    envMipMapCommandBuffer.waitUntilCompleted()

    //execute the ibl pre-filter
    guard
      let iblPreFilterCommandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()
    else {
      handleError(.iblPreFilterCreationFailed)
      return
    }

    executeIBLPreFilterPass(
      uCommandBuffer: iblPreFilterCommandBuffer, textureResources.environmentTexture!)

    //add a completion handler here
    iblPreFilterCommandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in

    }

    iblPreFilterCommandBuffer.commit()
    iblPreFilterCommandBuffer.waitUntilCompleted()

    //mipmap the specular texture

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

    //add a completion handler here
    specMipMapCommandBuffer.addCompletedHandler { (_ commandBuffer) -> Swift.Void in

      iblSuccessful = true
      //print("IBL Pre-Filters created successfully")
    }

    specMipMapBlitEncoder.endEncoding()
    specMipMapCommandBuffer.commit()
    specMipMapCommandBuffer.waitUntilCompleted()

  } catch {
    handleError(.iBLCreationFailed)

  }

}

func initRenderPipelines() {

  // MARK: - Shadows Init pipe
  let shadow = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    //let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

    //set position
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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = nil
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.invalid
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = true

    shadowPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)!

    //create a pipeline

    do {
      shadowPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      shadowPipeline.success = true

    } catch {
      Logger.logError(message: "Could not compute the Shadow pipeline state. Error info: \(error)")
      return false
    }

    return true
  }

  // MARK: - Grid Init pipe
  let grid = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //tell the gpu how data is organized
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

    //set position
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    //blending
    pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true

    //rgb blending
    pipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperation.add
    pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactor.sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactor.one

    //alpha blending
    pipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperation.add
    pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactor.sourceAlpha
    pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor =
      MTLBlendFactor.oneMinusSourceAlpha

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = false
    gridPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)!

    //create a pipeline
    gridPipeline.name = "Grid Pipeline"

    do {
      gridPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      gridPipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, gridPipeline.name!)
      return false
    }

    return true
  }

  // MARK: - Model Init pipe
  let model = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //tell the gpu how data is organized
    vertexDescriptor.model = MDLVertexDescriptor()

      vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)] = MDLVertexAttribute(
      name: MDLVertexAttributePosition,
      format: .float4,
      offset: 0,
      bufferIndex: Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue))

      vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)] = MDLVertexAttribute(
      name: MDLVertexAttributeNormal,
      format: .float4,
      offset: 0,
      bufferIndex: Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue))

      vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)] = MDLVertexAttribute(
      name: MDLVertexAttributeTextureCoordinate,
      format: .float2,
      offset: 0,
      bufferIndex: Int(ModelPassBufferIndices.modelPassUVIndex.rawValue))

      vertexDescriptor.model.attributes[Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)] = MDLVertexAttribute(
      name: MDLVertexAttributeTangent, format: .float4, offset: 0,
      bufferIndex: Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue))

      vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassVerticesIndex.rawValue)] = MDLVertexBufferLayout(
      stride: MemoryLayout<simd_float4>.stride)

      vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassNormalIndex.rawValue)] = MDLVertexBufferLayout(
      stride: MemoryLayout<simd_float4>.stride)

      vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassUVIndex.rawValue)] = MDLVertexBufferLayout(
      stride: MemoryLayout<simd_float2>.stride)

      vertexDescriptor.model.layouts[Int(ModelPassBufferIndices.modelPassTangentIndex.rawValue)] = MDLVertexBufferLayout(
      stride: MemoryLayout<simd_float4>.stride)

    let vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(vertexDescriptor.model)

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
      pipelineDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].pixelFormat =
      renderInfo.colorPixelFormat
      pipelineDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].pixelFormat = .rgba16Float
      pipelineDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)].pixelFormat = .rgba16Float

    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
    depthStateDescriptor.isDepthWriteEnabled = true

    modelPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)

    modelPipeline.name = "Model Pipeline"
    //create a pipeline

    do {
      modelPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      modelPipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, modelPipeline.name!)
      return false
    }

    return true
  }

  // MARK: - Geometry Init pipe
  let geometry = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //tell the gpu how data is organized
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

    //set position
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float4
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0

    vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float4>.stride
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunction.perVertex
    vertexDescriptor.layouts[0].stepRate = 1

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
      pipelineDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].pixelFormat =
      renderInfo.colorPixelFormat
      pipelineDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].pixelFormat = .rgba16Float
      pipelineDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)].pixelFormat = .rgba16Float
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
    depthStateDescriptor.isDepthWriteEnabled = true

    geometryPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)

    geometryPipeline.name = "Geometry Pipeline"
    //create a pipeline

    do {
      geometryPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      geometryPipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, geometryPipeline.name!)
      return false
    }

    return true
  }

  // MARK: - Mesh Shader Init pipe
  let meshShader = {
    (objectShaderName: String, meshShaderName: String, fragmentShaderName: String) in

  }

  // MARK: - Composite Init pipe
  let composite = {
    (pipeline: inout RenderPipeline, _ name: String, vertexShader: String, fragmentShader: String)
      -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    pipeline.name = name
    //create a pipeline

    do {
      pipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      pipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, pipeline.name!)
      return false
    }

    return true

  }

  // MARK: - Pre Composite Init pipe
  let precomposite = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    preCompositePipeline.name = "Pre Composite pipeline"
    //create a pipeline

    do {
      preCompositePipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      preCompositePipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, preCompositePipeline.name!)
      return false
    }

    return true

  }

  // MARK: - Debug Init pipe
  let debug = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = false

    debuggerPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)!

    debuggerPipeline.name = "Debugger pipeline"
    //create a pipeline

    do {
      debuggerPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      debuggerPipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, debuggerPipeline.name!)
      return false
    }

    return true

  }

  // MARK: - Post-Process Init pipe
  let postProcess = {
    (
      postProcessPipeline: inout RenderPipeline, _ name: String, vertexShader: String,
      fragmentShader: String
    ) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

      pipelineDescriptor.colorAttachments[Int(RenderTargets.colorTarget.rawValue)].pixelFormat =
      renderInfo.colorPixelFormat
      pipelineDescriptor.colorAttachments[Int(RenderTargets.normalTarget.rawValue)].pixelFormat = .rgba16Float
      pipelineDescriptor.colorAttachments[Int(RenderTargets.positionTarget.rawValue)].pixelFormat = .rgba16Float

    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat

    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    //        let depthStateDescriptor=MTLDepthStencilDescriptor()
    //        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
    //        depthStateDescriptor.isDepthWriteEnabled=false
    //
    //        postProcessPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!

    //create a pipeline
    postProcessPipeline.name = name

    do {
      postProcessPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)

      postProcessPipeline.success = true

    } catch {
      handleError(.pipelineStateCreationFailed, postProcessPipeline.name!)
      return false
    }

    return true

  }

  // MARK: - IBL Pre-Filter init pipe
  let iblPrefilter = { (vertexShader: String, fragmentShader: String) -> Bool in

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //set the vertex descriptor
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

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

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.colorAttachments[1].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.colorAttachments[2].pixelFormat = renderInfo.colorPixelFormat

    //pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.less
    depthStateDescriptor.isDepthWriteEnabled = false

    iblPrefilterPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)!

    //create a pipeline
    iblPrefilterPipeline.name = "IBL Pipeline"

    do {
      iblPrefilterPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)
      iblPrefilterPipeline.success = true
    } catch {
      handleError(.pipelineStateCreationFailed, iblPrefilterPipeline.name!)
      return false
    }

    return true

  }

  // MARK: - Environment Init pipe
  let environment = { (vertexShader: String, fragmentShader: String) -> Bool in

    //tell the gpu how data is organized
    let vertexDescriptor: MTLVertexDescriptor = MTLVertexDescriptor()

    //set position
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

    //create shading functions
    let vertexFunction: MTLFunction = renderInfo.library.makeFunction(name: vertexShader)!
    let fragmentFunction: MTLFunction = renderInfo.library.makeFunction(name: fragmentShader)!

    //build the pipeline

    //create the pipeline descriptor
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
    pipelineDescriptor.colorAttachments[0].pixelFormat = renderInfo.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = renderInfo.depthPixelFormat
    //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat

    let depthStateDescriptor = MTLDepthStencilDescriptor()
    depthStateDescriptor.depthCompareFunction = MTLCompareFunction.lessEqual
    depthStateDescriptor.isDepthWriteEnabled = false
    environmentPipeline.depthState = renderInfo.device.makeDepthStencilState(
      descriptor: depthStateDescriptor)

    environmentPipeline.name = "Environment Pipeline"
    //create a pipeline

    do {
      environmentPipeline.pipelineState = try renderInfo.device.makeRenderPipelineState(
        descriptor: pipelineDescriptor)
    } catch {
      handleError(.pipelineStateCreationFailed, environmentPipeline.name!)
      return false
    }

    //create the mesh

    let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

    let mdlMesh: MDLMesh = MDLMesh.newEllipsoid(
      withRadii: simd_float3(5.0, 5.0, 5.0), radialSegments: 24, verticalSegments: 24,
      geometryType: .triangles, inwardNormals: true, hemisphere: false, allocator: bufferAllocator)

    let mdlVertexDescriptor: MDLVertexDescriptor = MDLVertexDescriptor()
    guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
      fatalError("could not get the mdl attributes")
      //return false
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

    return true
  }

  // MARK: - initialize pipe lambdas
  //call the closures
  _ = grid("vertexGridShader", "fragmentGridShader")
  _ = shadow("vertexShadowShader", "fragmentShadowShader")
  _ = model("vertexModelShader", "fragmentModelShader")
  _ = geometry("vertexGeometryShader", "fragmentGeometryShader")
  _ = composite(&compositePipeline, "composite", "vertexCompositeShader", "fragmentCompositeShader")
  _ = composite(
    &rayCompositePipeline, "ray-composite", "vertexRayCompositeShader", "fragmentRayCompositeShader"
  )


  _ = precomposite("vertexPreCompositeShader", "fragmentPreCompositeShader")
  _ = debug("vertexDebugShader", "fragmentDebugShader")
  _ = postProcess(
    &postProcessPipeline, "post-process", "vertexPostProcessShader", "fragmentPostProcessShader")
  _ = environment("vertexEnvironmentShader", "fragmentEnvironmentShader")
  _ = iblPrefilter("vertexIBLPreFilterShader", "fragmentIBLPreFilterShader")
  _ = postProcess(&lightingPipeline, "lightingPipeline", "vertexLightShader", "fragmentLightShader")
  _ = postProcess(
    &tonemappingPipeline, "tonemappingPipeline", "vertexTonemappingShader",
    "fragmentTonemappingShader")

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
    from: vertices, byteCount: vertices.count * MemoryLayout<SIMD4<Float>>.stride)

}
