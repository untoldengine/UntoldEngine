//
//  RenderSystem.cpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#include "U4DRenderSystem.h"
#include "U4DCamera.h"
#include "U4DLight.h"
#include "U4DShaderProtocols.h"
#include "U4DTransformSystem.h"
#include "U4DMathUtils.h"

#include <string>

extern U4DEngine::VoxelPool voxelPool;
extern U4DEngine::RendererInfo renderInfo;
extern U4DEngine::Buffer buffer;
extern U4DEngine::Attachments attachments;
extern U4DEngine::U4DCamera camera;
extern U4DEngine::U4DLight light;

extern U4DEngine::RenderPipelines gridPipeline;
extern U4DEngine::RenderPipelines shadowPipeline;
extern U4DEngine::RenderPipelines voxelPipeline;
extern U4DEngine::RenderPipelines compositePipeline;

namespace U4DEngine {
simd_float3 gridVertices[]={simd_float3{1.0,1.0,0.0},
    simd_float3{-1.0,-1.0,0.0},
    simd_float3{-1.0,1.0,0.0},
    simd_float3{-1.0,-1.0,0.0},
    simd_float3{1.0,1.0,0.0},
    simd_float3{1.0,-1.0,0.0}};

float quadVertices[12]={-1.0,1.0,1.0,
    -1.0,-1.0,-1.0,
    -1.0,1.0,1.0,
    1.0,1.0,-1.0};

float quadTexCoords[12]={0.0,0.0,
    1.0,1.0,
    0.0,1.0,
    0.0,0.0,
    1.0,0.0,
    1.0,1.0};

void initBuffers(){
    
    //Step 6. allocate data for voxel pool
    voxelPool.originBuffer=[renderInfo.device newBufferWithLength:sizeof(simd_float4)*MaxNumberOfBlocks options:MTLResourceStorageModeShared];
    voxelPool.originBuffer.label=@"position buffer";
    
    voxelPool.vertexBuffer=[renderInfo.device newBufferWithLength:sizeof(simd_float4)*numOfVerticesPerBlock*MaxNumberOfBlocks options:MTLResourceStorageModeShared];
    voxelPool.vertexBuffer.label=@"vertices buffer";
    
    voxelPool.normalBuffer=[renderInfo.device newBufferWithLength:sizeof(simd_float4)*numOfVerticesPerBlock*MaxNumberOfBlocks options:MTLResourceStorageModeShared];
    voxelPool.normalBuffer.label=@"normal buffer";
    
    voxelPool.colorBuffer=[renderInfo.device newBufferWithLength:sizeof(simd_float4)*numOfVerticesPerBlock*MaxNumberOfBlocks options:MTLResourceStorageModeShared];
    voxelPool.colorBuffer.label=@"color buffer";
    
    voxelPool.indicesBuffer=[renderInfo.device newBufferWithLength:sizeof(uint16)*numOfIndicesPerBlock*MaxNumberOfBlocks options:MTLResourceStorageModeShared];
    voxelPool.indicesBuffer.label=@"indices buffer";
    
    //grid
    buffer.gridVertex=[renderInfo.device newBufferWithBytes:gridVertices length:sizeof(simd_float3)*6 options:MTLResourceStorageModeShared];
    
    buffer.gridUniform=[renderInfo.device newBufferWithLength:sizeof(UniformSpace) options:MTLResourceStorageModeShared];
    
    //composite
    
    buffer.quadVerticesBuffer=[renderInfo.device newBufferWithBytes:&quadVertices[0] length:sizeof(float)*sizeof(quadVertices)/sizeof(quadVertices[0]) options:MTLResourceStorageModeShared];
    
    buffer.quadTexCoordsBuffer=[renderInfo.device newBufferWithBytes:&quadTexCoords[0] length:sizeof(float)*sizeof(quadTexCoords)/sizeof(quadTexCoords[0]) options:MTLResourceStorageModeShared];
    
}

void initAttachments(){
    
    //    MTLTextureDescriptor *descriptor=[MTLTextureDescriptor new];
    //    descriptor.textureType=MTLTextureType2D;
    //    descriptor.width=renderInfo.drawableSize.x;
    //    descriptor.height=renderInfo.drawableSize.y;
    //    descriptor.pixelFormat=renderInfo.colorPixelFormat;
    //    descriptor.usage=MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite |MTLTextureUsageRenderTarget;
    //    descriptor.storageMode=MTLStorageModeShared;
    //
    //    attachments.texture0=[renderInfo.device newTextureWithDescriptor:descriptor];
    //    attachments.texture0.label=@"sample texture";
    //
    //    [descriptor release];
    
    float width=renderInfo.drawableSize.x;
    float height=renderInfo.drawableSize.y;
    
    //voxel texture
    MTLTextureDescriptor *voxelColorDescriptor=[MTLTextureDescriptor new];
    voxelColorDescriptor.textureType=MTLTextureType2D;
    voxelColorDescriptor.width=width;
    voxelColorDescriptor.height=height;
    voxelColorDescriptor.pixelFormat=renderInfo.colorPixelFormat;
    voxelColorDescriptor.storageMode=MTLStorageModePrivate;
    voxelColorDescriptor.usage=MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget | MTLTextureUsageShaderWrite;
    
    attachments.voxelColorTexture=[renderInfo.device newTextureWithDescriptor:voxelColorDescriptor];
    attachments.voxelColorTexture.label=@"Voxel color texture";
    
    MTLTextureDescriptor *voxelDepthDescriptor=[MTLTextureDescriptor new];
    voxelDepthDescriptor.textureType=MTLTextureType2D;
    voxelDepthDescriptor.width=width;
    voxelDepthDescriptor.height=height;
    voxelDepthDescriptor.pixelFormat=renderInfo.depthPixelFormat;
    voxelDepthDescriptor.storageMode=MTLStorageModePrivate;
    voxelDepthDescriptor.usage=MTLTextureUsageShaderRead | MTLTextureUsageRenderTarget;
    
    attachments.voxelDepthTexture=[renderInfo.device newTextureWithDescriptor:voxelDepthDescriptor];
    attachments.voxelDepthTexture.label=@"Voxel depth texture";
    
    [voxelColorDescriptor release];
    [voxelDepthDescriptor release];
    
    //create shadow depth
    MTLTextureDescriptor *shadowDescriptor=[MTLTextureDescriptor new];
    shadowDescriptor.textureType=MTLTextureType2D;
    shadowDescriptor.width=1024.0;
    shadowDescriptor.height=1024.0;
    shadowDescriptor.pixelFormat=MTLPixelFormatDepth32Float;
    shadowDescriptor.usage=MTLTextureUsageShaderRead |MTLTextureUsageRenderTarget;
    shadowDescriptor.storageMode=MTLStorageModePrivate;
    
    attachments.shadowDepthTexture=[renderInfo.device newTextureWithDescriptor:shadowDescriptor];
    attachments.shadowDepthTexture.label=@"shadow depth texture";
    
    [shadowDescriptor release];
    
    renderInfo.offscreenRenderPassDescriptor=[MTLRenderPassDescriptor new];
    renderInfo.offscreenRenderPassDescriptor.renderTargetWidth=width;
    renderInfo.offscreenRenderPassDescriptor.renderTargetHeight=height;
    renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture=attachments.voxelColorTexture;
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture=attachments.voxelDepthTexture;
    renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
    
}

void initPipelines(){
    
    auto grid=[](std::string vertexShader, std::string fragmentShader){
        
        //Step 4. create a vertex and fragment function shader
        id<MTLFunction> vertexProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:vertexShader.c_str()]];
        id<MTLFunction> fragmentProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:fragmentShader.c_str()]];
        
        
        MTLVertexDescriptor *vertexDescriptor=[[MTLVertexDescriptor alloc] init];
        
        vertexDescriptor.attributes[positionBufferIndex].format=MTLVertexFormatFloat3;
        vertexDescriptor.attributes[positionBufferIndex].bufferIndex=positionBufferIndex;
        vertexDescriptor.attributes[positionBufferIndex].offset=0;
        
        //stride
        vertexDescriptor.layouts[0].stride=sizeof(simd_float3);
        
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
        NSError *error;
        
        
        MTLRenderPipelineDescriptor *pipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        pipelineDescriptor.vertexFunction=vertexProgram;
        pipelineDescriptor.fragmentFunction=fragmentProgram;
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat;
        
        pipelineDescriptor.colorAttachments[0].blendingEnabled=YES;
        
        
        //rgb blending
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation=MTLBlendOperationAdd;
        
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor=MTLBlendFactorSourceAlpha;
        
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor=MTLBlendFactorOne;
        
        //alpha blending
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation=MTLBlendOperationAdd;
        
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor=MTLBlendFactorSourceAlpha;
        
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor=MTLBlendFactorOneMinusSourceAlpha;
        
        
        pipelineDescriptor.vertexDescriptor=vertexDescriptor;
        
        MTLDepthStencilDescriptor *depthDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        depthDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        
        depthDescriptor.depthWriteEnabled=NO;
        
        gridPipeline.depthStencilState=[renderInfo.device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        //create the rendering pipeline object
        
        gridPipeline.pipelineState=[renderInfo.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        
        //release the descriptors-no longer needed
        [pipelineDescriptor release];
        [depthDescriptor release];
        
        if(!gridPipeline.pipelineState){
            
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            
            printf("Error: The Grid pipeline was unable to be created. %s \n",errorDesc.c_str());
            return false;
        }
        
        
        return true;
    };
    
    auto voxel=[](std::string vertexShader, std::string fragmentShader){
        
        //Step 4. create a vertex and fragment function shader
        id<MTLFunction> vertexProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:vertexShader.c_str()]];
        id<MTLFunction> fragmentProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:fragmentShader.c_str()]];
        
        //tell gpu our data organization
        MTLVertexDescriptor *vertexDescriptor=[[MTLVertexDescriptor alloc] init];
        
        //set position
        vertexDescriptor.attributes[positionBufferIndex].format=MTLVertexFormatFloat4;
        vertexDescriptor.attributes[positionBufferIndex].bufferIndex=positionBufferIndex;
        vertexDescriptor.attributes[positionBufferIndex].offset=0;
        
        vertexDescriptor.layouts[positionBufferIndex].stride=sizeof(simd_float4);
        vertexDescriptor.layouts[positionBufferIndex].stepFunction=MTLVertexStepFunctionPerVertex;
        vertexDescriptor.layouts[positionBufferIndex].stepRate=1;
        
        //set normals
        vertexDescriptor.attributes[normalBufferIndex].format=MTLVertexFormatFloat4;
        vertexDescriptor.attributes[normalBufferIndex].bufferIndex=normalBufferIndex;
        vertexDescriptor.attributes[normalBufferIndex].offset=0;
        
        vertexDescriptor.layouts[normalBufferIndex].stride=sizeof(simd_float4);
        vertexDescriptor.layouts[normalBufferIndex].stepFunction=MTLVertexStepFunctionPerVertex;
        vertexDescriptor.layouts[normalBufferIndex].stepRate=1;
        
        //add colors
        vertexDescriptor.attributes[colorBufferIndex].format=MTLVertexFormatFloat4;
        vertexDescriptor.attributes[colorBufferIndex].bufferIndex=colorBufferIndex;
        vertexDescriptor.attributes[colorBufferIndex].offset=0;
        
        vertexDescriptor.layouts[colorBufferIndex].stride=sizeof(simd_float4);
        vertexDescriptor.layouts[colorBufferIndex].stepFunction=MTLVertexStepFunctionPerVertex;
        vertexDescriptor.layouts[colorBufferIndex].stepRate=1;
        
        //Step 5. Build the rendering pipeline
        MTLRenderPipelineDescriptor *pipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        
        //assign the vertex and fragment to the descriptor
        [pipelineDescriptor setVertexFunction:vertexProgram];
        [pipelineDescriptor setFragmentFunction:fragmentProgram];
        [pipelineDescriptor setVertexDescriptor:vertexDescriptor];
        
        //specify the target-texture pixel format
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat;
        
        MTLDepthStencilDescriptor *depthDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        depthDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        
        depthDescriptor.depthWriteEnabled=YES;
        
        //create depth stencil state
        voxelPipeline.depthStencilState=[renderInfo.device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        NSError *error;
        
        //build the rendering pipeline object
        voxelPipeline.pipelineState=[renderInfo.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        
        //release the descriptors-no longer needed
        [pipelineDescriptor release];
        [depthDescriptor release];
        
        if(!voxelPipeline.pipelineState){
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            
            printf("Error: The voxel pipeline was unable to be created. %s",errorDesc.c_str());
            return false;
        }
        
        
        return true;
    };
    
    auto composite=[](std::string vertexShader, std::string fragmentShader){
        
        id<MTLFunction> vertexProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:vertexShader.c_str()]];
        id<MTLFunction> fragmentProgram=[renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:fragmentShader.c_str()]];
        
        //tell gpu our data organization
        MTLVertexDescriptor *vertexDescriptor=[[MTLVertexDescriptor alloc] init];
        
        //set position
        vertexDescriptor.attributes[0].format=MTLVertexFormatFloat4;
        vertexDescriptor.attributes[0].bufferIndex=0;
        vertexDescriptor.attributes[0].offset=0;
        
        vertexDescriptor.attributes[1].format=MTLVertexFormatFloat2;
        vertexDescriptor.attributes[1].bufferIndex=0;
        vertexDescriptor.attributes[1].offset=4*sizeof(float);
        
        vertexDescriptor.layouts[0].stride=8*sizeof(float);
        vertexDescriptor.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
        
        //Step 5. Build the rendering pipeline
        MTLRenderPipelineDescriptor *pipelineDescriptor=[[MTLRenderPipelineDescriptor alloc] init];
        
        //assign the vertex and fragment to the descriptor
        [pipelineDescriptor setVertexFunction:vertexProgram];
        [pipelineDescriptor setFragmentFunction:fragmentProgram];
        [pipelineDescriptor setVertexDescriptor:vertexDescriptor];
        
        //specify the target-texture pixel format
        pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat;
        pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat;
        
        MTLDepthStencilDescriptor *depthDescriptor=[[MTLDepthStencilDescriptor alloc] init];
        
        NSError *error;
        
        //build the rendering pipeline object
        compositePipeline.pipelineState=[renderInfo.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        
        //release the descriptors-no longer needed
        [pipelineDescriptor release];
        
        if(!compositePipeline.pipelineState){
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            
            printf("Error: The composite pipeline was unable to be created. %s",errorDesc.c_str());
            return false;
        }
        
        compositePipeline.success=true;
        
        return true;
    };
    
    auto shadow=[](std::string vertexShader){
        
        id <MTLFunction> vertexFunction = [renderInfo.library newFunctionWithName:[NSString stringWithUTF8String:vertexShader.c_str()]];
        
        //set vertex description
        shadowPipeline.vertexDescriptor=[[MTLVertexDescriptor alloc] init];
        
        //set position
        shadowPipeline.vertexDescriptor.attributes[positionBufferIndex].format=MTLVertexFormatFloat4;
        shadowPipeline.vertexDescriptor.attributes[positionBufferIndex].bufferIndex=positionBufferIndex;
        shadowPipeline.vertexDescriptor.attributes[positionBufferIndex].offset=0;
        
        shadowPipeline.vertexDescriptor.layouts[positionBufferIndex].stride=sizeof(simd_float4);
        shadowPipeline.vertexDescriptor.layouts[positionBufferIndex].stepFunction=MTLVertexStepFunctionPerVertex;
        shadowPipeline.vertexDescriptor.layouts[positionBufferIndex].stepRate=1;
        
        //build pipeline
        NSError *error=nil;
        
        MTLRenderPipelineDescriptor *pipelineDescriptor=[MTLRenderPipelineDescriptor new];
        
        pipelineDescriptor.vertexFunction=vertexFunction;
        pipelineDescriptor.fragmentFunction=nil;
        pipelineDescriptor.vertexDescriptor=shadowPipeline.vertexDescriptor;
        pipelineDescriptor.colorAttachments[0].pixelFormat=MTLPixelFormatInvalid;
        pipelineDescriptor.depthAttachmentPixelFormat=MTLPixelFormatDepth32Float;
        
        MTLDepthStencilDescriptor *depthDescriptor=[MTLDepthStencilDescriptor new];
        depthDescriptor.depthCompareFunction=MTLCompareFunctionLess;
        depthDescriptor.depthWriteEnabled=YES;
        
        shadowPipeline.depthStencilState=[renderInfo.device newDepthStencilStateWithDescriptor:depthDescriptor];
        
        //build the pipeline
        shadowPipeline.pipelineState=[renderInfo.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
        
        //release the descriptors-no longer needed
        [pipelineDescriptor release];
        [depthDescriptor release];
        
        if(!shadowPipeline.pipelineState){
            
            std::string errorDesc= std::string([error.localizedDescription UTF8String]);
            
            printf("Error: The Shadow pipeline was unable to be created. %s",errorDesc.c_str());
            
            [shadowPipeline.vertexDescriptor release];
            shadowPipeline.vertexDescriptor=nullptr;
            shadowPipeline.success=false;
            return false;
        }else{
            
            printf("Success: The Shadow pipeline was properly configured");
            
            shadowPipeline.success=true;
            
            //set the pass descriptor
            shadowPipeline.passDescriptor=[MTLRenderPassDescriptor new];
            
            shadowPipeline.passDescriptor.depthAttachment.texture=attachments.shadowDepthTexture;
            shadowPipeline.passDescriptor.depthAttachment.clearDepth=1.0;
            shadowPipeline.passDescriptor.depthAttachment.loadAction=MTLLoadActionClear;
            shadowPipeline.passDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
            // Set the color attachment to nil (since we don't need to render any color)
            shadowPipeline.passDescriptor.colorAttachments[0].texture = nil;
            shadowPipeline.passDescriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;
            shadowPipeline.passDescriptor.colorAttachments[0].storeAction = MTLStoreActionDontCare;
            
            return true;
        }
        
        
        return false;
    };
    
    grid("vertexGridShader","fragmentGridShader");
    voxel("vertexVoxelShader","fragmentVoxelShader");
    shadow("vertexShadowShader");
    composite("vertexCompositeShader", "fragmentCompositeShader");
}

bool initMeshShaderPipeline(id<MTLDevice> mtlDevice){
    /*
     id<MTLLibrary> mtlLibrary=[mtlDevice newDefaultLibrary];
     
     //Step 4. create a vertex and fragment function shader
     id<MTLFunction> objectProgram=[mtlLibrary newFunctionWithName:@"objectMainShader"];
     id<MTLFunction> meshProgram=[mtlLibrary newFunctionWithName:@"meshMainShader"];
     id<MTLFunction> fragmentProgram=[mtlLibrary newFunctionWithName:@"fragmentMainShader"];
     
     NSError *error=nil;
     
     MTLMeshRenderPipelineDescriptor *pipelineDescriptor=[MTLMeshRenderPipelineDescriptor new];
     
     pipelineDescriptor.objectFunction=objectProgram;
     pipelineDescriptor.meshFunction=meshProgram;
     pipelineDescriptor.fragmentFunction=fragmentProgram;
     
     pipelineDescriptor.colorAttachments[0].pixelFormat=renderInfo.colorPixelFormat;
     pipelineDescriptor.depthAttachmentPixelFormat=renderInfo.depthPixelFormat;
     
     MTLDepthStencilDescriptor *depthDescriptor=[MTLDepthStencilDescriptor new];
     depthDescriptor.depthCompareFunction=MTLCompareFunctionLess;
     depthDescriptor.depthWriteEnabled=YES;
     meshShaderPipeline.depthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:depthDescriptor];
     
     
     MTLPipelineOption options = MTLPipelineOptionNone;
     
     meshShaderPipeline.pipelineState = [mtlDevice newRenderPipelineStateWithMeshDescriptor:pipelineDescriptor
     options:options
     reflection:nil
     error:&error];
     //release the descriptors-no longer needed
     [pipelineDescriptor release];
     [depthDescriptor release];
     
     if(!meshShaderPipeline.pipelineState){
     
     std::string errorDesc= std::string([error.localizedDescription UTF8String]);
     
     printf("Success: The Mesh pipeline was unable to be created. %s",errorDesc.c_str());
     }else{
     
     printf("Success: The Mesh pipeline was properly configured");
     
     meshShaderPipeline.success=true;
     
     return true;
     }
     
     
     return false;
     */
}

void compositePass(id<MTLCommandBuffer> uCommandBuffer){
    
    MTLRenderPassDescriptor *renderPassDescriptor = renderInfo.renderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;

    if(renderInfo.renderPassDescriptor == nil) return;
    
    id<MTLRenderCommandEncoder> renderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder pushDebugGroup:@"Composite Pass"];
    renderEncoder.label = @"Render Composite Pass";
    
    //Configure encoder with the pipeline
    [renderEncoder setRenderPipelineState:compositePipeline.pipelineState];
    
    [renderEncoder setVertexBuffer:buffer.quadVerticesBuffer offset:0 atIndex:0];
    [renderEncoder setVertexBuffer:buffer.quadTexCoordsBuffer offset:0 atIndex:1];
    [renderEncoder setFragmentTexture:renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture atIndex:0];
    [renderEncoder setFragmentTexture:renderInfo.renderPassDescriptor.colorAttachments[0].texture atIndex:1];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:sizeof(quadVertices)/sizeof(quadVertices[0])];
    
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}

void renderVoxelPass(U4DScene &scene, id<MTLCommandBuffer> uCommandBuffer){

    MTLRenderPassDescriptor *renderPassDescriptor = renderInfo.offscreenRenderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

    id<MTLRenderCommandEncoder> renderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder pushDebugGroup:@"Voxel Pass"];
    renderEncoder.label = @"Render Voxel Pass";
    
    updateVoxelSpace();
    
    //Configure encoder with the pipeline
    [renderEncoder setRenderPipelineState:voxelPipeline.pipelineState];
    [renderEncoder setDepthStencilState:voxelPipeline.depthStencilState];
    
    //set the vertex buffer object
    [renderEncoder setVertexBuffer:voxelPool.vertexBuffer offset:0 atIndex:positionBufferIndex];
    [renderEncoder setVertexBuffer:voxelPool.normalBuffer offset:0 atIndex:normalBufferIndex];
    [renderEncoder setVertexBuffer:voxelPool.colorBuffer offset:0 atIndex:colorBufferIndex];
    
    [renderEncoder setVertexBytes:&light.orthoViewMatrix length:sizeof(light.orthoViewMatrix) atIndex:lightOrthoViewSpaceBufferIndex];
    
    [renderEncoder setVertexBytes:&light.position length:sizeof(light.position) atIndex:lightPositionBufferIndex];
    
    [renderEncoder setFragmentBytes:&light.position length:sizeof(light.position) atIndex:lightPositionBufferIndex];
    
    [renderEncoder setFragmentTexture:attachments.shadowDepthTexture atIndex:shadowTextureIndex];
    
    for(EntityID ent:U4DSceneView<Voxel,Transform>(scene)){
        Voxel *pVoxel=scene.Get<Voxel>(ent);
        Transform *pTransform=scene.Get<Transform>(ent);
        
        
        [renderEncoder setVertexBuffer:pTransform->uniformSpace offset:0 atIndex:uniformSpaceBufferIndex];
        
        [renderEncoder setFragmentBuffer:pTransform->uniformSpace offset:0 atIndex:uniformSpaceBufferIndex];
        
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:pVoxel->size*numOfIndicesPerBlock indexType:MTLIndexTypeUInt16 indexBuffer:voxelPool.indicesBuffer indexBufferOffset:pVoxel->offset*numOfIndicesPerBlock*sizeof(uint16)];
        
    }
    
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}

void renderGridPass(id<MTLCommandBuffer> uCommandBuffer){
    
    MTLRenderPassDescriptor *renderPassDescriptor = renderInfo.renderPassDescriptor;
    
    if(renderInfo.renderPassDescriptor==nil){
        return;
    }
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

    id<MTLRenderCommandEncoder> renderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    [renderEncoder pushDebugGroup:@"Grid Pass"];
    renderEncoder.label = @"Render Grid Pass";
    
    //update the uniform
    UniformSpace uniforms;
    
    matrix_float4x4 modelMatrix = matrix4x4_identity();
    simd_float4x4 viewMatrix=simd_inverse(camera.viewSpace);
    uniforms.modelViewSpace = matrix_multiply(viewMatrix, modelMatrix);
    uniforms.projectionSpace = simd_inverse(renderInfo.projectionMatrix);
    uniforms.viewSpace=viewMatrix;
    
    
    memcpy(buffer.gridUniform.contents, (void*)&uniforms, sizeof(UniformSpace));
    
    [renderEncoder setRenderPipelineState:gridPipeline.pipelineState];
    [renderEncoder setDepthStencilState:gridPipeline.depthStencilState];
    
    //encode the buffers
    [renderEncoder setVertexBuffer:buffer.gridVertex offset:0 atIndex:positionBufferIndex];
    
    [renderEncoder setVertexBuffer:buffer.gridUniform offset:0 atIndex:uniformSpaceBufferIndex];
    
    [renderEncoder setFragmentBuffer:buffer.gridUniform offset:0 atIndex:uniformSpaceBufferIndex];
    
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}



void renderMeshShaderPass(id<MTLCommandBuffer> uCommandBuffer){
    
}



void shadowPass(U4DScene &scene, id<MTLCommandBuffer> uCommandBuffer){
    
    id<MTLRenderCommandEncoder> renderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:shadowPipeline.passDescriptor];
    if(renderEncoder== nullptr) return;
    
    updateVoxelSpace();
    light.updateSpace();
    
    [renderEncoder pushDebugGroup:@"Shadow Pass"];
    renderEncoder.label = @"Shadow Render Pass";
    
    [renderEncoder setRenderPipelineState:shadowPipeline.pipelineState];
    [renderEncoder setDepthStencilState:shadowPipeline.depthStencilState];
    [renderEncoder setDepthBias: 0.01 slopeScale: 1.0f clamp: 0.01];
    [renderEncoder setViewport:(MTLViewport){0.0, 0.0, 1024.0, 1024.0, 0.0, 1.0 }];
    [renderEncoder setVertexBytes:&light.orthoViewMatrix length:sizeof(light.orthoViewMatrix) atIndex:lightOrthoViewSpaceBufferIndex];
    
    //set the vertex buffer object
    [renderEncoder setVertexBuffer:voxelPool.vertexBuffer offset:0 atIndex:positionBufferIndex];
    
    for(EntityID ent:U4DSceneView<Voxel,Transform>(scene)){
        Voxel *pVoxel=scene.Get<Voxel>(ent);
        Transform *pTransform=scene.Get<Transform>(ent);
        
        [renderEncoder setVertexBuffer:pTransform->uniformSpace offset:0 atIndex:uniformSpaceBufferIndex];
        
        [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:pVoxel->size*numOfIndicesPerBlock indexType:MTLIndexTypeUInt16 indexBuffer:voxelPool.indicesBuffer indexBufferOffset:pVoxel->offset*numOfIndicesPerBlock*sizeof(uint16)];
        
    }
    
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];
}

}
