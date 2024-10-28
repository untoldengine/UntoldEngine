
//
//  CommonRenderPasses.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal
import MetalKit
import CShaderTypes

struct RenderPasses {

  static let gridExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if gridPipeline.success == false {
      handleError(.pipelineStateNulled, gridPipeline.name!)
      return
    }

    //update uniforms
    var gridUniforms = Uniforms()

    let modelMatrix = simd_float4x4.init(1.0)

    var viewMatrix: simd_float4x4 = camera.viewSpace
    viewMatrix = viewMatrix.inverse
    let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

    gridUniforms.modelViewMatrix = modelViewMatrix
    gridUniforms.viewMatrix = viewMatrix

    //Note, the perspective projection space has to be inverted to create the infinite grid
    gridUniforms.projectionMatrix = renderInfo.perspectiveSpace.inverse

    if let gridUniformBuffer = bufferResources.gridUniforms {
      gridUniformBuffer.contents().copyMemory(
        from: &gridUniforms, byteCount: MemoryLayout<Uniforms>.stride)
    } else {
      handleError(.bufferAllocationFailed, bufferResources.gridUniforms!.label!)
      return
    }

    //create the encoder

    let encoderDescriptor = renderInfo.renderPassDescriptor!

    encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
    encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
    encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Grid Pass")
      return
    }

    renderEncoder.label = "Grid Pass"

    renderEncoder.pushDebugGroup("Grid Pass")

    renderEncoder.setRenderPipelineState(gridPipeline.pipelineState!)
    renderEncoder.setDepthStencilState(gridPipeline.depthState)

    //send the uniforms
    renderEncoder.setVertexBuffer(
      bufferResources.gridVertexBuffer, offset: 0, index: Int(gridPassPositionIndex.rawValue))

    renderEncoder.setVertexBuffer(
      bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue))

    renderEncoder.setFragmentBuffer(
      bufferResources.gridUniforms, offset: 0, index: Int(gridPassUniformIndex.rawValue))

    //send buffer data

    renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 6)

    renderEncoder.updateFence(renderInfo.fence, after: .fragment)

    renderEncoder.popDebugGroup()

    renderEncoder.endEncoding()
  }

  static let executeEnvironmentPass: (MTLCommandBuffer) -> Void = { commandBuffer in

    if environmentPipeline.success == false {
      handleError(.pipelineStateNulled, environmentPipeline.name!)
      return
    }

    let encoderDescriptor = renderInfo.renderPassDescriptor!

    encoderDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1)
    encoderDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
    encoderDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Environment Pass")
      return
    }

    renderEncoder.label = "Environment Pass"

    renderEncoder.pushDebugGroup("Environment Pass")

    renderEncoder.setCullMode(.back)

    renderEncoder.setFrontFacing(.clockwise)

    renderEncoder.setRenderPipelineState(environmentPipeline.pipelineState!)

    renderEncoder.setDepthStencilState(environmentPipeline.depthState)

    var environmentConstants = EnvironmentConstants()
    environmentConstants.modelMatrix = matrix4x4Identity()
    environmentConstants.environmentRotation = matrix4x4Identity()
    environmentConstants.projectionMatrix = renderInfo.perspectiveSpace
    environmentConstants.viewMatrix = camera.viewSpace

    //remove the translational part of the view matrix to make the environment stay "infinitely" far away
    environmentConstants.viewMatrix.columns.3 = simd_float4(0.0, 0.0, 0.0, 1.0)

    //    let viewports = drawable.views.map { $0.textureMap.viewport }
    //
    //    renderEncoder.setViewports(viewports)
    //
    //    if drawable.views.count > 1 {
    //        var viewMappings = (0..<drawable.views.count).map {
    //            MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
    //                                              renderTargetArrayIndexOffset: UInt32($0))
    //        }
    //        renderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
    //    }
    //
    for (index, element) in environmentMesh.vertexDescriptor.layouts.enumerated() {
      guard let layout = element as? MDLVertexBufferLayout else {
        return
      }

      if layout.stride != 0 {
        let buffer = environmentMesh.vertexBuffers[index]
        renderEncoder.setVertexBuffer(buffer.buffer, offset: buffer.offset, index: index)
      }
    }

    renderEncoder.setVertexBytes(
      &environmentConstants, length: MemoryLayout<EnvironmentConstants>.stride,
      index: Int(envPassConstantIndex.rawValue))

    renderEncoder.setVertexBytes(
      &envRotationAngle, length: MemoryLayout<Float>.stride,
      index: Int(envPassRotationAngleIndex.rawValue))

    renderEncoder.setFragmentTexture(textureResources.environmentTexture, index: 0)

    for submesh in environmentMesh.submeshes {
      renderEncoder.drawIndexedPrimitives(
        type: submesh.primitiveType,
        indexCount: submesh.indexCount,
        indexType: submesh.indexType,
        indexBuffer: submesh.indexBuffer.buffer,
        indexBufferOffset: submesh.indexBuffer.offset)

    }

    renderEncoder.popDebugGroup()

    renderEncoder.endEncoding()
  }

  static let shadowExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if shadowPipeline.success == false {
      handleError(.pipelineStateNulled, shadowPipeline.name!)
      return
    }

    shadowSystem.updateViewFromSunPerspective()

    //if shadow has no dir light space matrix then no need to proceed
    guard let dirLight = shadowSystem.dirLightSpaceMatrix else { return }

    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(
        descriptor: renderInfo.shadowRenderPassDescriptor)
    else {
      handleError(.renderPassCreationFailed, "shadow Pass")

      return
    }

    renderEncoder.label = "Shadow Pass"
    renderEncoder.pushDebugGroup("Shadow Pass")
    renderEncoder.setRenderPipelineState(shadowPipeline.pipelineState!)
    renderEncoder.setDepthStencilState(shadowPipeline.depthState!)

    renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    renderEncoder.setDepthBias(0.005, slopeScale: 1.0, clamp: 1.0)
    renderEncoder.setViewport(
      MTLViewport(originX: 0.0, originY: 0.0, width: 1024, height: 1024, znear: 0.0, zfar: 1.0))

    //send buffer data
    renderEncoder.setVertexBytes(
      &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
      index: Int(shadowModelLightMatrixUniform.rawValue))

    //need to send light ortho view matrix

    //send info for each entity that conforms to shadows
    // Create a component query for entities with both Transform and Render components
    let componentQuery = ComponentQuery<TransformAndRenderChecker>(scene: scene)

    // Iterate over the entities found by the component query
    for entityId in componentQuery {

      //for lights components, we avoid them casting shadows
      let lightComponent = scene.get(component: LightComponent.self, for: entityId)

      if lightComponent != nil {
        continue
      }

      //update uniforms
      var modelUniforms = Uniforms()

      if let transform = scene.get(component: Transform.self, for: entityId) {

        var modelMatrix = transform.localSpace

        //modelMatrix=simd_mul(usdRotation, modelMatrix)

        let viewMatrix: simd_float4x4 = camera.viewSpace

        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

        let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse
        let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

        modelUniforms.modelViewMatrix = modelViewMatrix
        modelUniforms.normalMatrix = normalMatrix
        modelUniforms.viewMatrix = viewMatrix
        modelUniforms.modelMatrix = modelMatrix
        modelUniforms.cameraPosition = camera.localPosition
        modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

      }

      //rendering component data should go here

      //create the encoder
      if let render = scene.get(component: Render.self, for: entityId) {

        if render.spaceUniform == nil {
          render.spaceUniform = renderInfo.device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
        }

        if let modelUniformBuffer = render.spaceUniform {
          modelUniformBuffer.contents().copyMemory(
            from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
        } else {
          handleError(.bufferAllocationFailed, "Model Uniform Buffer")
          return
        }

        renderEncoder.setVertexBuffer(
          render.spaceUniform, offset: 0, index: Int(shadowModelUniform.rawValue))

        renderEncoder.setVertexBuffer(
          render.mesh.metalKitMesh.vertexBuffers[Int(shadowModelPositionIndex.rawValue)].buffer,
          offset: 0, index: Int(shadowModelPositionIndex.rawValue))

        for subMesh in render.mesh.submeshes {

          renderEncoder.drawIndexedPrimitives(
            type: subMesh.metalKitSubmesh.primitiveType,
            indexCount: subMesh.metalKitSubmesh.indexCount,
            indexType: subMesh.metalKitSubmesh.indexType,
            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset)
        }

      }
    }

    renderEncoder.updateFence(renderInfo.fence, after: .fragment)

    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()

  }

  static let modelExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if modelPipeline.success == false {
      handleError(.pipelineStateNulled, modelPipeline.name!)
      return
    }

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
      .loadAction = .clear
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
      .loadAction = .clear
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
      .loadAction = .clear

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
      .storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
      .storeAction = .store
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
      .storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store

    let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor!

    guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Model Pass")

      return
    }

    renderEncoder.label = "Model Pass"

    renderEncoder.pushDebugGroup("Model Pass")

    renderEncoder.setRenderPipelineState(modelPipeline.pipelineState!)
    renderEncoder.setDepthStencilState(modelPipeline.depthState)

    renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    renderEncoder.setCullMode(.back)

    renderEncoder.setFrontFacing(.counterClockwise)

    renderEncoder.setVertexBytes(
      &shadowSystem.dirLightSpaceMatrix, length: MemoryLayout<simd_float4x4>.stride,
      index: Int(modelPassLightOrthoViewMatrixIndex.rawValue))

    var lightDirection = simd_float3(0.0, 1.0, 0.0)
    var lightIntensity: Float = 0.0
    var lightColor: simd_float3 = simd_float3(0.0, 0.0, 0.0)
    if let directionalLightID = lightingSystem.dirLight.keys.first,
      let directionalLight: DirectionalLight = lightingSystem.getDirectionalLight(
        entityID: directionalLightID)
    {

      lightDirection = directionalLight.direction
      lightIntensity = directionalLight.intensity
      lightColor = directionalLight.color
    }

    renderEncoder.setVertexBytes(
      &lightDirection, length: MemoryLayout<simd_float3>.stride,
      index: Int(modelPassLightDirectionIndex.rawValue))

    renderEncoder.setFragmentBytes(
      &lightDirection, length: MemoryLayout<simd_float3>.stride,
      index: Int(modelPassLightDirectionIndex.rawValue))

    renderEncoder.setFragmentBytes(
      &lightIntensity, length: MemoryLayout<Float>.stride,
      index: Int(modelPassLightIntensityIndex.rawValue))

    renderEncoder.setFragmentBytes(
      &lightColor, length: MemoryLayout<simd_float3>.stride,
      index: Int(modelPassLightDirectionColorIndex.rawValue))

    renderEncoder.setFragmentBytes(
      &envRotationAngle, length: MemoryLayout<Float>.stride,
      index: Int(modelPassIBLRotationAngleIndex.rawValue))

    //ibl
    renderEncoder.setFragmentTexture(
      textureResources.irradianceMap, index: Int(modelIBLIrradianceTextureIndex.rawValue))
    renderEncoder.setFragmentTexture(
      textureResources.specularMap, index: Int(modelIBLSpecularTextureIndex.rawValue))
    renderEncoder.setFragmentTexture(
      textureResources.iblBRDFMap, index: Int(modelIBLBRDFMapTextureIndex.rawValue))

    var brdfParameters: BRDFSelectionUniform = BRDFSelectionUniform()
    brdfParameters.applyIBL = applyIBL
    brdfParameters.brdfSelection = Int32(BRDFSelection.rawValue)
    brdfParameters.ndfSelection = Int32(NDFSelection.rawValue)
    brdfParameters.ambientIntensity = ambientIntensity
    brdfParameters.gsSelection = Int32(GeomShadowSelection.rawValue)

    renderEncoder.setFragmentBytes(
      &brdfParameters, length: MemoryLayout<BRDFSelectionUniform>.stride,
      index: Int(modelPassBRDFIndex.rawValue))

    if let pointLightBuffer = bufferResources.pointLightBuffer {

      // if lightingSystem.currentPointLightCount != lightingSystem.pointLight.count {
      let pointLightArray = Array(lightingSystem.pointLight.values)

      pointLightArray.withUnsafeBufferPointer { bufferPointer in
        guard let baseAddress = bufferPointer.baseAddress else { return }
        pointLightBuffer.contents().copyMemory(
          from: baseAddress,
          byteCount: MemoryLayout<PointLight>.stride * lightingSystem.pointLight.count)
      }

      //lightingSystem.currentPointLightCount=lightingSystem.pointLight.count
      //}

    } else {
      handleError(.bufferAllocationFailed, bufferResources.pointLightBuffer!.label!)
      return
    }

    renderEncoder.setFragmentBuffer(
      bufferResources.pointLightBuffer, offset: 0, index: Int(modelPassPointLightsIndex.rawValue))

    var pointLightCount: Int = lightingSystem.pointLight.count

    renderEncoder.setFragmentBytes(
      &pointLightCount, length: MemoryLayout<Int>.stride,
      index: Int(modelPassPointLightsCountIndex.rawValue))

    renderEncoder.setFragmentTexture(
      textureResources.shadowMap, index: Int(shadowTextureIndex.rawValue))

    // Create a component query for entities with both Transform and Render components
    let componentQuery = ComponentQuery<TransformAndRenderChecker>(scene: scene)

    // Iterate over the entities found by the component query
    for entityId in componentQuery {

      //update uniforms
      var modelUniforms = Uniforms()

      if let transform = scene.get(component: Transform.self, for: entityId) {

        var modelMatrix = transform.localSpace

        //modelMatrix=simd_mul(usdRotation, modelMatrix)

        let viewMatrix: simd_float4x4 = camera.viewSpace

        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

        let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse
        let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

        modelUniforms.modelViewMatrix = modelViewMatrix
        modelUniforms.normalMatrix = normalMatrix
        modelUniforms.viewMatrix = viewMatrix
        modelUniforms.modelMatrix = modelMatrix
        modelUniforms.cameraPosition = camera.localPosition
        modelUniforms.projectionMatrix = renderInfo.perspectiveSpace

      }

      //rendering component data should go here

      //create the encoder
      if let render = scene.get(component: Render.self, for: entityId) {

        if render.spaceUniform == nil {
          render.spaceUniform = renderInfo.device.makeBuffer(
            length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
        }

        if let modelUniformBuffer = render.spaceUniform {
          modelUniformBuffer.contents().copyMemory(
            from: &modelUniforms, byteCount: MemoryLayout<Uniforms>.stride)
        } else {
          handleError(.bufferAllocationFailed, "Model Uniform buffer")
          return
        }

        renderEncoder.setVertexBuffer(
          render.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue))

        renderEncoder.setFragmentBuffer(
          render.spaceUniform, offset: 0, index: Int(modelPassUniformIndex.rawValue))

        renderEncoder.setVertexBuffer(
          render.mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer,
          offset: 0, index: Int(modelPassVerticesIndex.rawValue))

        renderEncoder.setVertexBuffer(
          render.mesh.metalKitMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer,
          offset: 0, index: Int(modelPassNormalIndex.rawValue))

        renderEncoder.setVertexBuffer(
          render.mesh.metalKitMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer, offset: 0,
          index: Int(modelPassUVIndex.rawValue))

        renderEncoder.setVertexBuffer(
          render.mesh.metalKitMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer,
          offset: 0, index: Int(modelPassTangentIndex.rawValue))

        for subMesh in render.mesh.submeshes {

          //set base texture
          renderEncoder.setFragmentTexture(
            subMesh.material?.baseColor, index: Int(modelBaseTextureIndex.rawValue))

          renderEncoder.setFragmentTexture(
            subMesh.material?.roughness, index: Int(modelRoughnessTextureIndex.rawValue))

          renderEncoder.setFragmentTexture(
            subMesh.material?.metallic, index: Int(modelMetallicTextureIndex.rawValue))

          var disneyParameters: DisneyParametersUniform = DisneyParametersUniform()
          disneyParameters.specular = subMesh.material!.specular
          disneyParameters.specularTint = subMesh.material!.specularTint
          disneyParameters.subsurface = subMesh.material!.subsurface
          disneyParameters.anisotropic = subMesh.material!.anisotropic
          disneyParameters.sheen = subMesh.material!.sheen
          disneyParameters.sheenTint = subMesh.material!.sheenTint
          disneyParameters.clearCoat = subMesh.material!.clearCoat
          disneyParameters.clearCoatGloss = subMesh.material!.clearCoatGloss
          disneyParameters.baseColor = subMesh.material!.baseColorValue
          disneyParameters.roughness = subMesh.material!.roughnessValue
          disneyParameters.metallic = subMesh.material!.metallicValue
          disneyParameters.ior = subMesh.material!.ior
          disneyParameters.edgeTint = subMesh.material!.edgeTint
          disneyParameters.interactWithLight = subMesh.material!.interactWithLight

          disneyParameters.hasTexture = simd_int4(
            Int32(subMesh.material!.hasBaseMap),
            Int32(subMesh.material!.hasRoughMap),
            Int32(subMesh.material!.hasMetalMap),
            0)

          renderEncoder.setFragmentBytes(
            &disneyParameters, length: MemoryLayout<DisneyParametersUniform>.stride,
            index: Int(modelDisneyParameterIndex.rawValue))

          var hasNormal: Bool = ((subMesh.material?.normal) != nil)
          renderEncoder.setFragmentBytes(
            &hasNormal, length: MemoryLayout<Bool>.stride,
            index: Int(modelHasNormalTextureIndex.rawValue))

          renderEncoder.setFragmentTexture(
            subMesh.material?.normal, index: Int(modelNormalTextureIndex.rawValue))

          renderEncoder.drawIndexedPrimitives(
            type: subMesh.metalKitSubmesh.primitiveType,
            indexCount: subMesh.metalKitSubmesh.indexCount,
            indexType: subMesh.metalKitSubmesh.indexType,
            indexBuffer: subMesh.metalKitSubmesh.indexBuffer.buffer,
            indexBufferOffset: subMesh.metalKitSubmesh.indexBuffer.offset)
        }

      }
    }
    renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()

  }

  static let highlightExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    // if selectedModel == false {
    //   return
    // }
    //
    // if geometryPipeline.success == false {
    //   handleError(.pipelineStateNulled, geometryPipeline.name!)
    //   return
    // }
    //
    // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
    //   .loadAction = .load
    // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
    //   .loadAction = .load
    // renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
    //   .loadAction = .load
    //
    // renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
    //
    // let encoderDescriptor = renderInfo.offscreenRenderPassDescriptor!
    //
    // guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
    // else {
    //
    //   handleError(.renderPassCreationFailed, "Highlight Pass")
    //
    //   return
    // }
    //
    // renderEncoder.label = "Highlight Pass"
    //
    // renderEncoder.pushDebugGroup("Highlight Pass")
    //
    // renderEncoder.setRenderPipelineState(geometryPipeline.pipelineState!)
    // 
    // renderEncoder.setDepthStencilState(geometryPipeline.depthState)
    //
    // renderEncoder.waitForFence(renderInfo.fence, before: .vertex)
    //
    // renderEncoder.setCullMode(.back)
    //
    // renderEncoder.setFrontFacing(.counterClockwise)
    //
    // if let t = scene.get(component: Transform.self, for: activeEntity) {
    //
    //   renderEncoder.setVertexBuffer(bufferResources.boundingBoxBuffer, offset: 0, index: 0)
    //   
    //   renderEncoder.setVertexBytes(
    //     &camera.viewSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 1)
    //   renderEncoder.setVertexBytes(
    //     &renderInfo.perspectiveSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 2)
    //   renderEncoder.setVertexBytes(
    //     &t.localSpace, length: MemoryLayout<matrix_float4x4>.stride, index: 3)
    //   renderEncoder.drawPrimitives(type: .line, vertexStart: 0, vertexCount: boundingBoxVertexCount)
    //
    // }
    //
    // renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    // renderEncoder.popDebugGroup()
    // renderEncoder.endEncoding()
    //
  }

  static let compositeExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if !compositePipeline.success {
      handleError(.pipelineStateNulled, compositePipeline.name!)
      return
    }

    let renderPassDescriptor = renderInfo.renderPassDescriptor!

    //set the states for the pipeline
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.load
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

    //clear it so that it doesn't have any effect on the final output
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .clear

    //set your encoder here
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Composite Pass")
      return
    }

    renderEncoder.label = "Composite Pass"

    renderEncoder.pushDebugGroup("Composite Pass")

    renderEncoder.setRenderPipelineState(compositePipeline.pipelineState!)

    renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

    renderEncoder.setFragmentTexture(
      renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 0)

    //set the draw command

    renderEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: 6,
      indexType: .uint16,
      indexBuffer: bufferResources.quadIndexBuffer!,
      indexBufferOffset: 0)

    renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()
  }

  static let preCompositeExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if !preCompositePipeline.success {
      handleError(.pipelineStateNulled, preCompositePipeline.name!)
      return
    }

    let renderPassDescriptor = renderInfo.renderPassDescriptor!

    //set the states for the pipeline
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

    //clear it so that it doesn't have any effect on the final output
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
      .loadAction = .load

    //set your encoder here
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Pre Composite Pass")
      return
    }

    renderEncoder.label = "Pre Composite Pass"

    renderEncoder.pushDebugGroup("Pre Composite Pass")

    renderEncoder.setRenderPipelineState(preCompositePipeline.pipelineState!)

    renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

    renderEncoder.setFragmentTexture(
      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture,
      index: 0)

    renderEncoder.setFragmentTexture(
      renderInfo.renderPassDescriptor.colorAttachments[0].texture, index: 1)

    renderEncoder.setFragmentTexture(
      renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 2)

    //set the draw command

    renderEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: 6,
      indexType: .uint16,
      indexBuffer: bufferResources.quadIndexBuffer!,
      indexBufferOffset: 0)

    renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()
  }

  static let debuggerExecution: (MTLCommandBuffer) -> Void = { commandBuffer in

    if !debuggerPipeline.success {
      handleError(.pipelineStateNulled, debuggerPipeline.name!)
      return
    }

    let renderPassDescriptor = renderInfo.renderPassDescriptor!

    //set the states for the pipeline
    renderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = MTLLoadAction.load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
      .loadAction = .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
      .loadAction = .load

    renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .clear

    //set your encoder here
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Debugger Pass")
      return
    }

    renderEncoder.label = "Debugger Pass"

    renderEncoder.pushDebugGroup("Debugger Pass")

    renderEncoder.setRenderPipelineState(debuggerPipeline.pipelineState!)
    renderEncoder.setDepthStencilState(debuggerPipeline.depthState)

    renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    let windowWidth: Float = renderInfo.viewPort.x
    let windowHeight: Float = renderInfo.viewPort.y

    // Define viewports
    var viewPortsArray: [MTLViewport] = [
      MTLViewport(
        originX: 0, originY: 0, width: Double(windowWidth) / 2, height: Double(windowHeight) / 2,
        znear: 0.0, zfar: 1.0),
      MTLViewport(
        originX: Double(windowWidth) / 2, originY: 0, width: Double(windowWidth) / 2,
        height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
      MTLViewport(
        originX: 0, originY: Double(windowHeight) / 2, width: Double(windowWidth) / 2,
        height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
      MTLViewport(
        originX: Double(windowWidth) / 2, originY: Double(windowHeight) / 2,
        width: Double(windowWidth) / 2, height: Double(windowHeight) / 2, znear: 0.0, zfar: 1.0),
    ]

    // Define scissor rects
    var scissorRectsArray: [MTLScissorRect] = [
      MTLScissorRect(x: 0, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
      MTLScissorRect(
        x: Int(windowWidth) / 2, y: 0, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
      MTLScissorRect(
        x: 0, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2, height: Int(windowHeight) / 2),
      MTLScissorRect(
        x: Int(windowWidth) / 2, y: Int(windowHeight) / 2, width: Int(windowWidth) / 2,
        height: Int(windowHeight) / 2),
    ]

    renderEncoder.setViewports(viewPortsArray)
    renderEncoder.setScissorRects(scissorRectsArray)

    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

    for i in 0..<4 {

      var currentViewport: Int = i

      renderEncoder.setVertexBytes(&currentViewport, length: MemoryLayout<Int>.stride, index: 5)

      if i == 0 {
        renderEncoder.setFragmentTexture(
          renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
            .texture, index: 0)
      } else if i == 1 {
        renderEncoder.setFragmentTexture(
          renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
            .texture, index: 0)
      } else if i == 2 {
        renderEncoder.setFragmentTexture(
          renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
            .texture, index: 0)
      } else if i == 3 {
        renderEncoder.setFragmentTexture(
          renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: 1)
      }

      //set the draw command

      renderEncoder.drawIndexedPrimitives(
        type: .triangle,
        indexCount: 6,
        indexType: .uint16,
        indexBuffer: bufferResources.quadIndexBuffer!,
        indexBufferOffset: 0)

    }

    renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()
  }

  static let executeBlitColorTexture: (MTLCommandBuffer) -> Void = { commandBuffer in

    //create a blit encoder
    let blitEncoder = commandBuffer.makeBlitCommandEncoder()
    blitEncoder?.waitForFence(renderInfo.fence)

    let width = renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture!.width
    let height = renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture!.height

    blitEncoder?.copy(
      from: renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture!,
      sourceSlice: 0,
      sourceLevel: 0,
      sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
      sourceSize: MTLSize(width: width, height: height, depth: 1),
      to: textureResources.rayTracingDestTextureArray!,
      destinationSlice: 0,
      destinationLevel: 0,
      destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))

    blitEncoder?.updateFence(renderInfo.fence)
    blitEncoder?.endEncoding()

  }

  static func executePostProcess(_ pipeline: RenderPipeline) -> (MTLCommandBuffer) -> Void {
    return { commandBuffer in

      if !pipeline.success {
        handleError(.pipelineStateNulled, "Post Process Pipeline")
        return
      }

      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
        .loadAction = .load
      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
        .loadAction = .load
      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
        .loadAction = .load

      renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

      let renderPassDescriptor = renderInfo.offscreenRenderPassDescriptor!

      //set your encoder here
      guard
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      else {
        handleError(.renderPassCreationFailed, "Post Process \(pipeline.name!) Pass")
        return
      }

      renderEncoder.label = "Post-Processing Pass"

      renderEncoder.pushDebugGroup("Post-Processing")

      renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

      renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

      renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
      renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

      renderEncoder.setFragmentTexture(
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
          .texture, index: 0)

      //set the draw command
      renderEncoder.drawIndexedPrimitives(
        type: .triangle,
        indexCount: 6,
        indexType: .uint16,
        indexBuffer: bufferResources.quadIndexBuffer!,
        indexBufferOffset: 0)

      renderEncoder.updateFence(renderInfo.fence, after: .fragment)
      renderEncoder.popDebugGroup()
      renderEncoder.endEncoding()
    }
  }

  static func executeLightPass(_ pipeline: RenderPipeline) -> (MTLCommandBuffer) -> Void {
    return { commandBuffer in
      /*
            if(!pipeline.success){
                handleError(.pipelineStateNulled, "Lighting Pipeline")
                return
            }

            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].loadAction = .load
            renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].loadAction = .load


            renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

            let renderPassDescriptor=renderInfo.offscreenRenderPassDescriptor!

            //set your encoder here
            guard let renderEncoder=commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)else{
                handleError(.renderPassCreationFailed, "Lighting \(pipeline.name!) Pass")
                return
            }

            renderEncoder.label = "Lighting Pass"

            renderEncoder.pushDebugGroup("Lighting Pass")

            renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

            renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

            renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

            renderEncoder.setFragmentBytes(&camera.viewSpace, length: MemoryLayout<simd_float4x4>.stride, index: Int(lightPassCameraSpaceIndex.rawValue))

            renderEncoder.setFragmentBytes(&lightingSystem.dirLight.direction, length: MemoryLayout<simd_float3>.stride, index: Int(lightPassLightDirectionIndex.rawValue))

            renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)].texture, index: Int(lightPassAlbedoTextureIndex.rawValue));

            renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)].texture, index: Int(lightPassNormalTextureIndex.rawValue));

            renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)].texture, index: Int(lightPassPositionTextureIndex.rawValue));


            renderEncoder.setFragmentTexture(renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture, index: Int(lightPassDepthTextureIndex.rawValue))

            renderEncoder.setFragmentBytes(&ambientIntensity, length: MemoryLayout<Float>.stride, index: Int(lightPassAmbientIntensityIndex.rawValue))

            //ibl
            renderEncoder.setFragmentTexture(textureResources.irradianceMap, index: Int(lightPassIBLIrradianceTextureIndex.rawValue))
            renderEncoder.setFragmentTexture(textureResources.specularMap, index: Int(lightPassIBLSpecularTextureIndex.rawValue))
            renderEncoder.setFragmentTexture(textureResources.iblBRDFMap, index: Int(lightPassIBLBRDFMapTextureIndex.rawValue))

            renderEncoder.setFragmentBytes(&BRDFSelection, length: MemoryLayout<Int>.stride, index: Int(lightPassNDFSelectionIndex.rawValue))

            renderEncoder.setFragmentBytes(&applyIBL, length: MemoryLayout<Bool>.stride, index: Int(lightPassApplyIBLIndex.rawValue))

            //set the draw command
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: 6,
                                                indexType: .uint16,
                                                indexBuffer: bufferResources.quadIndexBuffer!,
                                                indexBufferOffset: 0)

            renderEncoder.updateFence(renderInfo.fence, after: .fragment)
            renderEncoder.popDebugGroup()
            renderEncoder.endEncoding()
             */
    }
  }

  static let executeRayCompositePass: (MTLCommandBuffer) -> Void = { commandBuffer in

    if !rayCompositePipeline.success {
      handleError(.pipelineStateNulled, rayCompositePipeline.name!)
      return
    }

    let renderPassDescriptor = renderInfo.renderPassDescriptor!

    //set the states for the pipeline
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store

    //clear it so that it doesn't have any effect on the final output
    //renderPassDescriptor.depthAttachment.loadAction = .clear
    //renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store
    //renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .clear
    //        //set your encoder here
    guard
      let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
    else {

      handleError(.renderPassCreationFailed, "Ray Composite Pass")
      return
    }

    renderEncoder.label = "Ray Composite Pass"

    renderEncoder.pushDebugGroup("Ray Composite Pass")

    renderEncoder.setRenderPipelineState(rayCompositePipeline.pipelineState!)

    //renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

    renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
    renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
    renderEncoder.setFragmentTexture(textureResources.rayTracingDestTexture, index: 0)

    //set the draw command

    renderEncoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: 6,
      indexType: .uint16,
      indexBuffer: bufferResources.quadIndexBuffer!,
      indexBufferOffset: 0)

    //renderEncoder.updateFence(renderInfo.fence, after: .fragment)
    renderEncoder.popDebugGroup()
    renderEncoder.endEncoding()

  }

  static func executeTonemapPass(_ pipeline: RenderPipeline) -> (MTLCommandBuffer) -> Void {
    return { commandBuffer in

      if !pipeline.success {
        handleError(.pipelineStateNulled, "Tone-mapping Pipeline")
        return
      }

      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
        .loadAction = .load
      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(normalTarget.rawValue)]
        .loadAction = .load
      renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(positionTarget.rawValue)]
        .loadAction = .load

      renderInfo.offscreenRenderPassDescriptor.depthAttachment.loadAction = .load

      let renderPassDescriptor = renderInfo.offscreenRenderPassDescriptor!

      //set your encoder here
      guard
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      else {
        handleError(.renderPassCreationFailed, "Tonemapping \(pipeline.name!) Pass")
        return
      }

      renderEncoder.label = "Tone-mapping Pass"

      renderEncoder.pushDebugGroup("Tone-mapping Pass")

      renderEncoder.setRenderPipelineState(pipeline.pipelineState!)

      renderEncoder.waitForFence(renderInfo.fence, before: .vertex)

      renderEncoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
      renderEncoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)

      renderEncoder.setFragmentTexture(
        renderInfo.offscreenRenderPassDescriptor.colorAttachments[Int(colorTarget.rawValue)]
          .texture, index: Int(toneMapPassColorTextureIndex.rawValue))

      renderEncoder.setFragmentBytes(
        &toneMapOperator, length: MemoryLayout<Int>.stride,
        index: Int(toneMapPassToneMappingIndex.rawValue))
      //set the draw command
      renderEncoder.drawIndexedPrimitives(
        type: .triangle,
        indexCount: 6,
        indexType: .uint16,
        indexBuffer: bufferResources.quadIndexBuffer!,
        indexBufferOffset: 0)

      renderEncoder.updateFence(renderInfo.fence, after: .fragment)
      renderEncoder.popDebugGroup()
      renderEncoder.endEncoding()
    }
  }

}
