//
//  U4DComponents.h
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef U4DComponents_h
#define U4DComponents_h

#import <MetalKit/MetalKit.h>
#include <simd/simd.h>

namespace U4DEngine {

struct RendererInfo{

    id <MTLDevice> device;
    id <MTLCommandQueue> commandQueue;
    id <MTLLibrary> library;
    MTLRenderPassDescriptor *renderPassDescriptor;
    MTLRenderPassDescriptor *offscreenRenderPassDescriptor;
    MTLPixelFormat colorPixelFormat;
    MTLPixelFormat depthPixelFormat;
    simd_float2 drawableSize;
    matrix_float4x4 projectionMatrix;
};

struct Transform{
    simd_float4x4 localSpace=matrix_identity_float4x4;
    simd_float4x4 modelerTransform;
    id<MTLBuffer> uniformSpace;
};

struct VoxelData{
    unsigned int guid;
    simd_float3 color;
};

struct Voxel{
    unsigned int size;
    unsigned long offset;
};

struct VoxelPool{
    id<MTLBuffer> originBuffer;
    id<MTLBuffer> vertexBuffer;
    id<MTLBuffer> normalBuffer;
    id<MTLBuffer> colorBuffer;
    id<MTLBuffer> indicesBuffer;
};

struct GridGraphics{
    id<MTLRenderPipelineState> renderPipelineState;
    id<MTLDepthStencilState> renderDepthStencilState;
    
};

struct RenderPipelines{
    id<MTLRenderPipelineState> pipelineState;
    id<MTLDepthStencilState> depthStencilState;
    MTLVertexDescriptor *vertexDescriptor;
    MTLRenderPassDescriptor *passDescriptor;
    MTLRenderPassDepthAttachmentDescriptor *depthDescriptor;
    bool success=false;
};

struct ComputePipeline{
    id<MTLComputePipelineState> pipelineState;
    bool success=false;
};


struct Buffer{
    id<MTLBuffer> gridVertex;
    id<MTLBuffer> gridUniform;
    
    //composite
    id<MTLBuffer> quadVerticesBuffer;
    id<MTLBuffer> quadTexCoordsBuffer;

};

struct Attachments{
    id<MTLTexture> shadowDepthTexture;
    
    id<MTLTexture> compositeTexture;
    
    //voxel offscreen
    id<MTLTexture> voxelColorTexture;
    id<MTLTexture> voxelDepthTexture;
    
};

}

#endif /* U4DComponents_h */
