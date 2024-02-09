//
//  RenderSystem.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 5/29/23.
//

import Foundation
import MetalKit
import simd




func initGeneralBuffers(){
    
    let grid={
        
        //assign the buffer to gridVertexBuffer
        coreBufferResources.gridVertexBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*gridVertices.count, options: [MTLResourceOptions.storageModeShared])
        
        coreBufferResources.gridVertexBuffer!.contents().initializeMemory(as: simd_float3.self,from: gridVertices, count: gridVertices.count)
        
        coreBufferResources.gridVertexBuffer?.label="grid vertices"
        
        coreBufferResources.gridUniforms=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
        coreBufferResources.gridUniforms?.label="grid uniforms"
    }
    
    let composite={
        
        //set the coreBufferResources
        coreBufferResources.quadVerticesBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*quadVertices.count, options: [MTLResourceOptions.storageModeShared])!
        
        coreBufferResources.quadTexCoordsBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float2>.stride*quadTexCoords.count, options: [MTLResourceOptions.storageModeShared])!
        
        coreBufferResources.quadIndexBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<UInt16>.stride*quadIndices.count, options: [MTLResourceOptions.storageModeShared])!
        
        coreBufferResources.quadVerticesBuffer?.label="quad vertices"
        coreBufferResources.quadTexCoordsBuffer?.label="quad tex"
        coreBufferResources.quadIndexBuffer?.label="quad index"
        
        coreBufferResources.quadVerticesBuffer!.contents().initializeMemory(as: simd_float3.self,from: quadVertices, count: quadVertices.count)
        
        coreBufferResources.quadTexCoordsBuffer!.contents().initializeMemory(as: simd_float2.self,from: quadTexCoords, count: quadTexCoords.count)
        
        coreBufferResources.quadIndexBuffer!.contents().initializeMemory(as: UInt16.self,from: quadIndices, count: quadIndices.count)
        
    }
    
    let pointLights={
        
        coreBufferResources.pointLightBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<PointLight>.stride*maxNumPointLights, options: [MTLResourceOptions.storageModeShared])!
        
        coreBufferResources.pointLightBuffer?.label="Point Lights"
    }
    
    grid()
    composite()
    pointLights()
}

func initMemoryPool() {
    
    let voxelMemoryPool={
        
        vertexMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Vertex Buffer")
        
        normalMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Normal Buffer")

        indicesMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<UInt32>.stride*numOfIndicesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Indices Buffer")
        
        colorMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Color Buffer")
        
        roughnessMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<Float>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Roughness Buffer")
       
        metallicMemoryPool=MemoryPoolManager(renderInfo.device,MemoryLayout<Float>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, MAX_ENTITIES,"Pool Metallic Buffer")
        
    }
    
    voxelMemoryPool()
    
}

func initRenderPassDescriptors(){

    //shadow render pass
    renderInfo.shadowRenderPassDescriptor=MTLRenderPassDescriptor()
    renderInfo.shadowRenderPassDescriptor.renderTargetWidth=1024
    renderInfo.shadowRenderPassDescriptor.renderTargetHeight=1024
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].texture=nil
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].loadAction = .dontCare
    renderInfo.shadowRenderPassDescriptor.colorAttachments[0].storeAction = .dontCare
    renderInfo.shadowRenderPassDescriptor.depthAttachment.texture = coreTextureResources.shadowMap
    renderInfo.shadowRenderPassDescriptor.depthAttachment.clearDepth = 1.0;
    renderInfo.shadowRenderPassDescriptor.depthAttachment.loadAction = .clear
    renderInfo.shadowRenderPassDescriptor.depthAttachment.storeAction = . store
    
    //offscreen render pass descriptor
    renderInfo.offscreenRenderPassDescriptor=MTLRenderPassDescriptor()
    renderInfo.offscreenRenderPassDescriptor.renderTargetWidth=Int(renderInfo.viewPort.x)
    renderInfo.offscreenRenderPassDescriptor.renderTargetHeight=Int(renderInfo.viewPort.y)
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture=coreTextureResources.colorMap
    
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[1].texture=coreTextureResources.normalMap
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[2].texture=coreTextureResources.positionMap
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture=coreTextureResources.depthMap
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction = .store
    
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[1].loadAction = .clear // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[1].storeAction = .store

    renderInfo.offscreenRenderPassDescriptor.colorAttachments[2].loadAction = .clear // or .load
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[2].storeAction = .store

    
//    renderInfo.offscreenRenderPassDescriptor.colorAttachments[1].clearColor = MTLClearColor(0.0,0.0,0.0,1.0)
//    renderInfo.offscreenRenderPassDescriptor.colorAttachments[2].clearColor = MTLClearColor(0.0,0.0,0.0,1.0)

    
}

func initCoreTextureResources(){
    
    //shadow texture descriptor
    
    let shadowDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
    shadowDescriptor.textureType = .type2D
    shadowDescriptor.pixelFormat = .depth32Float
    shadowDescriptor.width = 1024
    shadowDescriptor.height=1024
    shadowDescriptor.usage = [.shaderRead, .renderTarget]
    shadowDescriptor.storageMode = .private
    
    //create texture
    coreTextureResources.shadowMap=renderInfo.device.makeTexture(descriptor: shadowDescriptor)
    coreTextureResources.shadowMap?.label="Shadow Texture"
    
    let colorDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
    colorDescriptor.textureType = .type2D
    colorDescriptor.pixelFormat = renderInfo.colorPixelFormat
    colorDescriptor.width=Int(renderInfo.viewPort.x)
    colorDescriptor.height=Int(renderInfo.viewPort.y)
    colorDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    colorDescriptor.storageMode = .shared
    
    //create texture
    coreTextureResources.colorMap=renderInfo.device.makeTexture(descriptor: colorDescriptor)
    coreTextureResources.colorMap?.label="Color Texture"
    
    let normalDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
    normalDescriptor.textureType = .type2D
    normalDescriptor.pixelFormat = .rgba16Float
    normalDescriptor.width=Int(renderInfo.viewPort.x)
    normalDescriptor.height=Int(renderInfo.viewPort.y)
    normalDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    normalDescriptor.storageMode = .shared
    
    coreTextureResources.normalMap=renderInfo.device.makeTexture(descriptor: normalDescriptor)
    coreTextureResources.normalMap?.label="Normal Texture"
    
    let positionDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
    positionDescriptor.textureType = .type2D
    positionDescriptor.pixelFormat = .rgba16Float
    positionDescriptor.width=Int(renderInfo.viewPort.x)
    positionDescriptor.height=Int(renderInfo.viewPort.y)
    positionDescriptor.usage = [.shaderRead, .renderTarget, .shaderWrite]
    positionDescriptor.storageMode = .shared
    
    coreTextureResources.positionMap=renderInfo.device.makeTexture(descriptor: positionDescriptor)
    coreTextureResources.positionMap?.label="Position Texture"
    
    let depthDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
    depthDescriptor.textureType = .type2D
    depthDescriptor.pixelFormat = renderInfo.depthPixelFormat
    depthDescriptor.width=Int(renderInfo.viewPort.x)
    depthDescriptor.height=Int(renderInfo.viewPort.y)
    depthDescriptor.usage = [.shaderRead, .renderTarget]
    depthDescriptor.storageMode = .shared
    
    coreTextureResources.depthMap=renderInfo.device.makeTexture(descriptor: depthDescriptor)
    coreTextureResources.depthMap?.label="Depth Texture"
}

func initCoreRenderPipelines(){
    
    // MARK: - Shadows Init pipe
    let shadow={(vertexShader:String,fragmentShader:String) -> Bool in
        
        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        //let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
     
        //set the vertex descriptor
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        //set position
        vertexDescriptor.attributes[Int(shadowVoxelOriginIndex.rawValue)].format=MTLVertexFormat.float4;
        vertexDescriptor.attributes[Int(shadowVoxelOriginIndex.rawValue)].bufferIndex=Int(shadowVoxelOriginIndex.rawValue);
        vertexDescriptor.attributes[Int(shadowVoxelOriginIndex.rawValue)].offset=0;
        
        // stride
        vertexDescriptor.layouts[Int(shadowVoxelOriginIndex.rawValue)].stride = MemoryLayout<simd_float4>.stride
        vertexDescriptor.layouts[Int(shadowVoxelOriginIndex.rawValue)].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[Int(shadowVoxelOriginIndex.rawValue)].stepRate=1
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=nil
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.invalid
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled=true
        
        shadowPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        //create a pipeline
        
        do{
            shadowPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            shadowPipeline.success=true
            
        }catch{
            Logger.logError(message: "Could not compute the Shadow pipeline state. Error info: \(error)")
            return false
        }
        
        return true
    }
    
    _ = shadow("vertexShadowShader", "fragmentShadowShader")
}



func initGeneralRenderPipelines(){
    
    // MARK: - Grid Init pipe
    let grid={(vertexShader:String,fragmentShader:String) -> Bool in
        
        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
        
        //tell the gpu how data is organized
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        //set position
        vertexDescriptor.attributes[0].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[0].bufferIndex=0
        vertexDescriptor.attributes[0].offset=0
        
        vertexDescriptor.layouts[0].stride=MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[0].stepRate=1
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=fragmentFunction
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        //blending
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled=true

        //rgb blending
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperation.add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactor.sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactor.one
        
        //alpha blending
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperation.add
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactor.sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactor.oneMinusSourceAlpha
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled=false
        gridPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        //create a pipeline
        gridPipeline.name="Grid Pipeline"
        
        do{
            gridPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            gridPipeline.success = true
            
        }catch{
            handleError(.pipelineStateCreationFailed, gridPipeline.name!)
            return false
        }
        
        return true
    }
    
    // MARK: - Voxel Init pipe
    let voxel={(vertexShader:String,fragmentShader:String) -> Bool in
        
        
        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
        
        //tell the gpu how data is organized
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        //set position
        vertexDescriptor.attributes[0].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[0].bufferIndex=0
        vertexDescriptor.attributes[0].offset=0
        
        vertexDescriptor.layouts[0].stride=MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[0].stepRate=1
        
        //set normals
        vertexDescriptor.attributes[1].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[1].bufferIndex=1
        vertexDescriptor.attributes[1].offset=0
        
        vertexDescriptor.layouts[1].stride=MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[1].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[1].stepRate=1
        
        //set colors
        vertexDescriptor.attributes[2].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[2].bufferIndex=2
        vertexDescriptor.attributes[2].offset=0
        
        vertexDescriptor.layouts[2].stride=MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[2].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[2].stepRate=1
        
        //set roughness
        vertexDescriptor.attributes[3].format=MTLVertexFormat.float
        vertexDescriptor.attributes[3].bufferIndex=3
        vertexDescriptor.attributes[3].offset=0
        
        vertexDescriptor.layouts[3].stride=MemoryLayout<Float>.stride
        vertexDescriptor.layouts[3].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[3].stepRate=1
        
        //set metallic
        vertexDescriptor.attributes[4].format=MTLVertexFormat.float
        vertexDescriptor.attributes[4].bufferIndex=4
        vertexDescriptor.attributes[4].offset=0
        
        vertexDescriptor.layouts[4].stride=MemoryLayout<Float>.stride
        vertexDescriptor.layouts[4].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[4].stepRate=1
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=fragmentFunction
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        pipelineDescriptor.colorAttachments[Int(colorTarget.rawValue)].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.colorAttachments[Int(normalTarget.rawValue)].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.colorAttachments[Int(positionTarget.rawValue)].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled=true
        voxelPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        voxelPipeline.name="Voxel Pipeline"
        //create a pipeline
        
        do{
            voxelPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            coreBufferResources.voxelUniforms=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
            
            voxelPipeline.success=true
            
        }catch{
            handleError(.pipelineStateCreationFailed, voxelPipeline.name!)
            return false
        }
        
        
        return true
    }
    
    // MARK: - Mesh Shader Init pipe
    let meshShader={(objectShaderName:String, meshShaderName:String,fragmentShaderName:String) in
        
    }
    
    
    // MARK: - Composite Init pipe
    let composite={(vertexShader:String,fragmentShader:String) -> Bool in
        
        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
     
        //set the vertex descriptor
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format=MTLVertexFormat.float3;
        vertexDescriptor.attributes[0].bufferIndex=0;
        vertexDescriptor.attributes[0].offset=0;
        
        vertexDescriptor.attributes[1].format = MTLVertexFormat.float2;
        vertexDescriptor.attributes[1].bufferIndex = 1;
        vertexDescriptor.attributes[1].offset = 0;

        // stride
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[0].stepRate=1
        
        vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
        vertexDescriptor.layouts[1].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[1].stepRate=1
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=fragmentFunction
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled=false
        
        compositePipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        compositePipeline.name="Composite pipeline"
        //create a pipeline
        
        do{
            compositePipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            compositePipeline.success=true
            
        }catch{
            handleError(.pipelineStateCreationFailed, compositePipeline.name!)
            return false
        }
        
        
        return true
        
    }
    
    // MARK: - Post-Process Init pipe
    let postProcess={(postProcessPipeline:inout RenderPipeline,_ name:String, vertexShader:String,fragmentShader:String) -> Bool in
        
        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
     
        //set the vertex descriptor
        //set the vertex descriptor
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format=MTLVertexFormat.float3;
        vertexDescriptor.attributes[0].bufferIndex=0;
        vertexDescriptor.attributes[0].offset=0;
        
        vertexDescriptor.attributes[1].format = MTLVertexFormat.float2;
        vertexDescriptor.attributes[1].bufferIndex = 1;
        vertexDescriptor.attributes[1].offset = 0;

        // stride
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[0].stepRate=1
        
        vertexDescriptor.layouts[1].stride = MemoryLayout<simd_float2>.stride
        vertexDescriptor.layouts[1].stepFunction=MTLVertexStepFunction.perVertex
        vertexDescriptor.layouts[1].stepRate=1
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=fragmentFunction
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled=false
        
        postProcessPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        //create a pipeline
        postProcessPipeline.name=name
        
        do{
            postProcessPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            postProcessPipeline.success=true
            
        }catch{
            handleError(.pipelineStateCreationFailed, postProcessPipeline.name!)
            return false
        }
        
        return true
        
    }
    
    
    
    // MARK: - initialize pipe lambdas
    //call the closures
    _ = grid("vertexGridShader","fragmentGridShader")
    _ = voxel("vertexBlockShader","fragmentBlockShader")
    _ = composite("vertexCompositeShader","fragmentCompositeShader")
    
}






