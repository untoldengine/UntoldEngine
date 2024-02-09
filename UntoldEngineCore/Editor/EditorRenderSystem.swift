//
//  EditorRenderSystem.swift
//  UntoldEditor
//
//  Created by Harold Serrano on 1/30/24.
//

import Foundation
import MetalKit
import simd

func initEditorTextureResources(){
    
    do{
        editorTextureResources.environmentTexture=try loadHDR("studio.hdr");
        editorTextureResources.environmentTexture?.label="environment texture"
        
        //If the environment was properly loaded, then mip-map it
        if let commandBuffer:MTLCommandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
        
            if let commandEncoder:MTLBlitCommandEncoder=commandBuffer.makeBlitCommandEncoder(){
                commandEncoder.generateMipmaps(for: editorTextureResources.environmentTexture!)
                
                //add a completion handler here
                commandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
                    
                    iblMipmapped=true
                }
                
                commandEncoder.endEncoding()
                commandBuffer.commit()
            }
            
        }
        
        let width:Int=Int(renderInfo.viewPort.x)
        let height:Int=Int(renderInfo.viewPort.y)
        
        //irradiance map
        let irradianceMapDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
        irradianceMapDescriptor.textureType = .type2D
        irradianceMapDescriptor.width = width
        irradianceMapDescriptor.height = height
        irradianceMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
        irradianceMapDescriptor.storageMode = .shared
        irradianceMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        editorTextureResources.irradianceMap=renderInfo.device.makeTexture(descriptor: irradianceMapDescriptor)
        editorTextureResources.irradianceMap?.label="IBL Irradiance Texture"
        
        //specular map
        let specularMapDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
        specularMapDescriptor.textureType = .type2D
        specularMapDescriptor.width = width
        specularMapDescriptor.height = height
        specularMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
        specularMapDescriptor.mipmapLevelCount=6
        specularMapDescriptor.storageMode = .shared
        specularMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        editorTextureResources.specularMap=renderInfo.device.makeTexture(descriptor: specularMapDescriptor)
        editorTextureResources.specularMap?.label="IBL Specular Texture"
        
        //brdf map
        let brdfMapDescriptor:MTLTextureDescriptor=MTLTextureDescriptor()
        brdfMapDescriptor.textureType = .type2D
        brdfMapDescriptor.width = width
        brdfMapDescriptor.height = height
        brdfMapDescriptor.pixelFormat = renderInfo.colorPixelFormat
        brdfMapDescriptor.storageMode = .shared
        brdfMapDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        
        editorTextureResources.brdfMap=renderInfo.device.makeTexture(descriptor: brdfMapDescriptor)
        editorTextureResources.brdfMap?.label="IBL brdf Texture"
        
        renderInfo.iblOffscreenRenderPassDescriptor=MTLRenderPassDescriptor()
        
        renderInfo.iblOffscreenRenderPassDescriptor.renderTargetWidth=width
        renderInfo.iblOffscreenRenderPassDescriptor.renderTargetHeight=height
        renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[0].texture=editorTextureResources.irradianceMap
        renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[1].texture=editorTextureResources.specularMap
        renderInfo.iblOffscreenRenderPassDescriptor.colorAttachments[2].texture=editorTextureResources.brdfMap
        
        
    }catch{
        handleError(.renderPassDescriptorCreationFailed, "IBL render pass descriptor \(error)")
        
    }
}

func initEditorBuffers(){
    
    let editorVoxelChunks={
        
        //Allocate memory in the mtlbuffer
        editorVoxelPool.originBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.originBuffer?.label="Editor Voxel Origin Buffer"
        
        editorVoxelPool.vertexBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.vertexBuffer?.label="Editor Voxel Vertex Buffer"
        
        editorVoxelPool.normalBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.normalBuffer?.label="Editor Voxel Normal Buffer"
        
        editorVoxelPool.indicesBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<UInt32>.stride*numOfIndicesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.indicesBuffer?.label="Editor Voxel Indices Buffer"
        
        editorVoxelPool.colorBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.colorBuffer?.label="Editor Voxel Color Buffer"
        
        editorVoxelPool.baseColorBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.baseColorBuffer?.label="Editor Voxel base Color Buffer"
        
        editorVoxelPool.voxelVisible=renderInfo.device.makeBuffer(length: MemoryLayout<Bool>.stride*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.voxelVisible?.label="Editor Voxel visible Buffer"
        
        editorVoxelPool.roughnessBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<Float>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.roughnessBuffer?.label="Editor Voxel Roughness Buffer"
        
        editorVoxelPool.metallicBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<Float>.stride*numOfVerticesPerBlock*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorVoxelPool.metallicBuffer?.label="Editor Voxel Metallic Buffer"
        
        let visible:[Bool]=Array(repeating: false, count: maxNumberOfBlocks)
        
        //initialize visible buffer as false
        editorVoxelPool.voxelVisible!.contents().initializeMemory(as: Bool.self, from: visible, count: visible.count)
        
        editorBufferResources.voxelUniforms=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
    }
    
    let ghostVoxel={
        
        editorBufferResources.ghostVoxelBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*ghostVoxelVertices.count, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.ghostVoxelIndicesBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_int4>.stride*ghostVoxelIndices.count, options: [MTLResourceOptions.storageModeShared])!
        
        var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: ghostVoxelVertices.count)
        
        for (i,value) in ghostVoxelVertices.enumerated(){
            newVertices[i]=value
        }
            

        //set the indices
        var newIndices:[simd_int4]=Array(repeating: simd_int4(0,0,0,0), count: ghostVoxelIndices.count)
        
        for (i,value) in ghostVoxelIndices.enumerated(){
            newIndices[i]=value
        }
        
        editorBufferResources.ghostVoxelBuffer!.contents().advanced(by: 0).copyMemory(from: newVertices, byteCount: MemoryLayout<simd_float3>.stride*ghostVoxelVertices.count)


        editorBufferResources.ghostVoxelIndicesBuffer!.contents().advanced(by: 0).copyMemory(from: newIndices, byteCount: MemoryLayout<simd_int4>.stride*ghostVoxelIndices.count)
        
        editorBufferResources.ghostVoxelUniforms=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
        
        
    }
    
    let intersection={
        
        editorBufferResources.voxelRayUniform=renderInfo.device.makeBuffer(length: MemoryLayout<RayUniforms>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.intersectionTest=renderInfo.device.makeBuffer(length: MemoryLayout<Int>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.tIntersectionParam=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.pointIntersect=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.blockIntersectedGuid=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.planeRayIntersectionResult=renderInfo.device.makeBuffer(length: MemoryLayout<Bool>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.planeRayIntersectionPoint=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.planeRayIntersectionTime=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        var zero=0;
        var zerovec:simd_float3=simd_float3(0.0,0.0,0.0)
        var maxInt:UInt=UInt.max
        var planeIntersect:Bool=false
        
        editorBufferResources.intersectionTest?.contents().initializeMemory(as: Int.self, from:&zero, count:1)
        editorBufferResources.tIntersectionParam?.contents().initializeMemory(as: UInt.self, from: &maxInt, count: 1)
        editorBufferResources.pointIntersect?.contents().initializeMemory(as: simd_float3.self, from: &zerovec, count:1 )
        editorBufferResources.planeRayIntersectionResult?.contents().initializeMemory(as: Bool.self, from:&planeIntersect, count:1)
        editorBufferResources.planeRayIntersectionTime?.contents().initializeMemory(as: UInt.self, from: &maxInt, count: 1)
        editorBufferResources.planeRayIntersectionPoint?.contents().initializeMemory(as: simd_float3.self, from: &zerovec, count:1 )
    }
    
    let plane={
        
        editorBufferResources.planeBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride*planeVertices.count, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.planeIndicesBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_int4>.stride*planeIndices.count, options: [MTLResourceOptions.storageModeShared])!
        
        var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: planeVertices.count)
        
        for (i,value) in planeVertices.enumerated(){
            newVertices[i]=value
        }
            

        //set the indices
        var newIndices:[simd_int4]=Array(repeating: simd_int4(0,0,0,0), count: planeIndices.count)
        
        for (i,value) in planeIndices.enumerated(){
            newIndices[i]=value
        }
        
        editorBufferResources.planeBuffer!.contents().advanced(by: 0).copyMemory(from: newVertices, byteCount: MemoryLayout<simd_float3>.stride*planeVertices.count)


        editorBufferResources.planeIndicesBuffer!.contents().advanced(by: 0).copyMemory(from: newIndices, byteCount: MemoryLayout<simd_int4>.stride*planeIndices.count)
        
        editorBufferResources.planeUniforms=renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride, options: [MTLResourceOptions.storageModeShared])
        
    }
    
    let serializer={
        
        editorBufferResources.serializeBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<VoxelData>.stride*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.voxelSerializeCountBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.voxelSerializeCountBuffer?.contents().initializeMemory(as: UInt.self, to: 0)
        
    }
    
    let boxGuidIntersection={
        
        editorBufferResources.boxGuidIntersectionBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<VoxelData>.stride*maxNumberOfBlocks, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.boxGuidIntersectionCountBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        
        editorBufferResources.boxGuidIntersectionCountBuffer?.contents().initializeMemory(as: UInt.self, to: 0)
        
    }
    
    let normalPlaneIntersect={
        
        editorBufferResources.normalPlaneIntersectionTest=renderInfo.device.makeBuffer(length: MemoryLayout<Int>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.normalPlaneTIntersectionParam=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        editorBufferResources.normalPlanePointIntersect=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        
        var zero=0;
        var zerovec:simd_float3=simd_float3(0.0,0.0,0.0)
        var maxInt:UInt=UInt.max
        
        editorBufferResources.normalPlaneIntersectionTest?.contents().initializeMemory(as: Int.self, from:&zero, count:1)
        editorBufferResources.normalPlaneTIntersectionParam?.contents().initializeMemory(as: UInt.self, from: &maxInt, count: 1)
        editorBufferResources.normalPlanePointIntersect?.contents().initializeMemory(as: simd_float3.self, from: &zerovec, count:1 )
    }
    
    editorVoxelChunks()
    intersection()
    ghostVoxel()
    plane()
    serializer()
    boxGuidIntersection()
    normalPlaneIntersect()
}


func initEditorRenderPipelines(){
    
    // MARK: - Ghost Voxel Init pipe
    let ghostVoxel={(vertexShader:String,fragmentShader:String) -> Bool in
        
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
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled=true
        ghostVoxelPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        //create a pipeline
        
        do{
            ghostVoxelPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            ghostVoxelPipeline.success = true
            
        }catch{
            Logger.logError(message: "could not compute the feedback render pipeline state. Error info: \(error)")
            return false
        }
        
        return true
    }
    
    // MARK: - Plane Init pipe
    let plane={(vertexShader:String,fragmentShader:String) -> Bool in
        
        
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
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled=true
        planePipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        //create a pipeline
        
        do{
            planePipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
            
            planePipeline.success = true
        }catch{
            Logger.logError(message: "could not compute the Plane render pipeline state. Error info: \(error)")
            return false
        }
        
        
        return true
    }
    
    // MARK: - IBL Pre-Filter init pipe
    let iblPrefilter={(vertexShader:String,fragmentShader:String) -> Bool in
        
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
        pipelineDescriptor.colorAttachments[1].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.colorAttachments[2].pixelFormat=renderInfo.colorPixelFormat
        
        //pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.less
        depthStateDescriptor.isDepthWriteEnabled=false
        
        iblPrefilterPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)!
        
        //create a pipeline
        
        do{
            iblPrefilterPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }catch{
            Logger.logError(message: "Could not compute the IBL Pre-Filter pipeline state. Error info: \(error)")
            return false
        }
        
        iblPrefilterPipeline.success=true
        
        return true
        
    }
    
    // MARK: - Environment Init pipe
    let environment={(vertexShader:String,fragmentShader:String) -> Bool in
        
        //tell the gpu how data is organized
        let vertexDescriptor:MTLVertexDescriptor=MTLVertexDescriptor()
        
        //set position
        vertexDescriptor.attributes[0].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[0].bufferIndex=0
        vertexDescriptor.attributes[0].offset=0
                
        vertexDescriptor.attributes[1].format=MTLVertexFormat.float3
        vertexDescriptor.attributes[1].bufferIndex=0
        vertexDescriptor.attributes[1].offset=MemoryLayout<simd_float3>.stride
                
        vertexDescriptor.attributes[2].format=MTLVertexFormat.float2
        vertexDescriptor.attributes[2].bufferIndex=0
        vertexDescriptor.attributes[2].offset=2*MemoryLayout<simd_float3>.stride
        
        vertexDescriptor.layouts[0].stride=2*MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride

        //create shading functions
        let vertexFunction:MTLFunction=renderInfo.library.makeFunction(name: vertexShader)!
        let fragmentFunction:MTLFunction=renderInfo.library.makeFunction(name: fragmentShader)!
        
        
        //build the pipeline
        
        //create the pipeline descriptor
        let pipelineDescriptor=MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction=vertexFunction
        pipelineDescriptor.fragmentFunction=fragmentFunction
        pipelineDescriptor.vertexDescriptor=vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat
        //pipelineDescriptor.stencilAttachmentPixelFormat=renderInfo.depthPixelFormat
        
        let depthStateDescriptor=MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction=MTLCompareFunction.lessEqual
        depthStateDescriptor.isDepthWriteEnabled=false
        environmentPipeline.depthState=renderInfo.device.makeDepthStencilState(descriptor: depthStateDescriptor)
        
        //create a pipeline
        
        do{
            environmentPipeline.pipelineState=try renderInfo.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }catch{
            Logger.logError(message: "Could not compute the Environment pipeline state. Error info: \(error)")
            return false
        }
        
        //create the mesh
        
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        
        let mdlMesh:MDLMesh = MDLMesh.newEllipsoid(withRadii: simd_float3(5.0,5.0,5.0), radialSegments: 24, verticalSegments: 24, geometryType: .triangles, inwardNormals: true, hemisphere: false, allocator: bufferAllocator)

        let mdlVertexDescriptor:MDLVertexDescriptor=MDLVertexDescriptor()
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
                fatalError("could not get the mdl attributes")
            //return false
        }
        
        attributes[0].name=MDLVertexAttributePosition
        attributes[0].format=MDLVertexFormat.float3
        attributes[0].bufferIndex=0
        attributes[0].offset=0
        
        attributes[1].name=MDLVertexAttributeNormal
        attributes[1].format=MDLVertexFormat.float3
        attributes[1].bufferIndex=0
        attributes[1].offset=MemoryLayout<simd_float3>.stride
        
        attributes[2].name=MDLVertexAttributeTextureCoordinate
        attributes[2].format=MDLVertexFormat.float2
        attributes[2].bufferIndex=0
        attributes[2].offset=2*MemoryLayout<simd_float3>.stride
        
        // Initialize the layout
        mdlVertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 2*MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride)
        
        guard let bufferLayouts = mdlVertexDescriptor.layouts as? [MDLVertexBufferLayout] else {
            fatalError("Could not get the MDL layouts")
        }
 
        bufferLayouts[0].stride = 2*MemoryLayout<simd_float3>.stride + MemoryLayout<simd_float2>.stride
        
        mdlMesh.vertexDescriptor = mdlVertexDescriptor
        
        do {
            environmentMesh=try MTKMesh(mesh: mdlMesh, device: renderInfo.device)
        } catch {
            fatalError("Unable to build MetalKit Mesh. Error info: ")
        }
        
        environmentPipeline.success=true
        
        return true
    }
    
    _ = ghostVoxel("vertexFeedbackShader", "fragmentFeedbackShader")
    _ = plane("vertexPlaneShader", "fragmentPlaneShader")
    _ = environment("vertexEnvironmentShader","fragmentEnvironmentShader")
    _ = iblPrefilter("vertexIBLPreFilterShader","fragmentIBLPreFilterShader")
}

func initEditorComputePipeline(){
    
    let voxelRay={(kernelShader:String) -> Bool in
     
        //create a kernel
        guard let kernel=renderInfo.library.makeFunction(name: kernelShader) else{
            print("Unable to create voxel ray kernel")
            return false
        }
        
        //create a pipeline
        
        do{
            voxelRayPipeline.pipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Voxel Ray Intersection Compute Pipeline")
            return false
        }
        
        return true
    }
    
    let voxelRemove={(kernelShader:String) -> Bool in
     
        //create a kernel
        guard let kernel=renderInfo.library.makeFunction(name: kernelShader) else{
            print("Unable to create voxel remove kernel")
            return false
        }
        
        //create a pipeline
        
        do{
            voxelRemoveAllPipeline.pipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Voxel Remove All Compute Pipeline")
            return false
        }
        
        return true
    }
    
    let voxelSerialize={(kernelShader:String) -> Bool in
     
        //create a kernel
        guard let kernel=renderInfo.library.makeFunction(name: kernelShader) else{
            print("Unable to create voxel serialize kernel")
            return false
        }
        
        //create a pipeline
        
        do{
            serializePipeline.pipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Voxel Serialize Compute Pipeline")
            return false
        }
        
        return true
    }
    
    let voxelBoxIntersect={(kernelShader:String) -> Bool in
     
        //create a kernel
        guard let kernel=renderInfo.library.makeFunction(name: kernelShader) else{
            print("Unable to create voxel serialize kernel")
            return false
        }
        
        //create a pipeline
        
        do{
            voxelBoxIntersectPipeline.pipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Voxe-Box Intersect Compute Pipeline")
            return false
        }
        
        return true
    }
    
    let planeNormal={(kernelShader:String) -> Bool in
     
        //create a kernel
        guard let kernel=renderInfo.library.makeFunction(name: kernelShader) else{
            print("Unable to create Normal Plane kernel")
            return false
        }
        
        //create a pipeline
        
        do{
            normalPlaneComputePipeline.pipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Normal Plane Intersect Compute Pipeline")
            return false
        }
        
        return true
    }
    
    //call the closures
    _ = voxelRay("voxelIntersect")
    _ = voxelRemove("removeAllVoxels")
    _ = voxelSerialize("serializeVoxels")
    _ = voxelBoxIntersect("voxelBoxIntersect")
    _ = planeNormal("getPlaneNormalCompute")
}
