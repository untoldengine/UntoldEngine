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

/**
 @brief Holds references to renderer information such as device, pixel formats, etc
 */
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

/**
 @brief Component used to transform the space of the model
 */
struct Transform{
    simd_float4x4 localSpace=matrix_identity_float4x4;
    simd_float4x4 modelerTransform;
    id<MTLBuffer> uniformSpace;
};

/**
 @brief Struct used by the loading system and Json reader to parse the file containing voxel data
 */
struct VoxelData{
    unsigned int guid;
    simd_float3 color;
};

/**
 @brief Contains information about the voxel current offset adress in memory and its size
 */
struct Voxel{
    unsigned int size;
    unsigned long offset;
};

/**
 @brief Pool of memory to allocate a huge chunk of memory for voxels.
 */
struct VoxelPool{
    id<MTLBuffer> originBuffer;
    id<MTLBuffer> vertexBuffer;
    id<MTLBuffer> normalBuffer;
    id<MTLBuffer> colorBuffer;
    id<MTLBuffer> indicesBuffer;
};

/**
 @brief Component used set up the Grid pipeline
 */
struct GridGraphics{
    id<MTLRenderPipelineState> renderPipelineState;
    id<MTLDepthStencilState> renderDepthStencilState;
    
};

/**
 @brief Component used to set up the voxel Rendering pipeline
 */
struct RenderPipelines{
    id<MTLRenderPipelineState> pipelineState;
    id<MTLDepthStencilState> depthStencilState;
    MTLVertexDescriptor *vertexDescriptor;
    MTLRenderPassDescriptor *passDescriptor;
    MTLRenderPassDepthAttachmentDescriptor *depthDescriptor;
    bool success=false;
};

/**
 @brief Component used to create a compute pipeline
 */
struct ComputePipeline{
    id<MTLComputePipelineState> pipelineState;
    bool success=false;
};

/**
@brief vertex and uniform buffers for the different components
 */
struct Buffer{
    id<MTLBuffer> gridVertex;
    id<MTLBuffer> gridUniform;
    
    //composite
    id<MTLBuffer> quadVerticesBuffer;
    id<MTLBuffer> quadTexCoordsBuffer;

};

/**
 @brief Textures for different rendering passes and components
 */
struct Attachments{
    id<MTLTexture> shadowDepthTexture;
    
    id<MTLTexture> compositeTexture;
    
    //voxel offscreen
    id<MTLTexture> voxelColorTexture;
    id<MTLTexture> voxelDepthTexture;
    
};

}

#endif /* U4DComponents_h */
