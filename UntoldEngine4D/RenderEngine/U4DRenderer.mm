//
//  U4DRenderer.cpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/1/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//


#include "U4DRenderer.h"
#include "U4DDirector.h"
#include "U4DCamera.h"



/// Main class performing the rendering
@implementation U4DRenderer
{
    //Metal
    id <MTLDevice> mtlDevice;
    id <MTLCommandQueue> mtlCommandQueue;
    
    //Timing properties
    CFTimeInterval timeSinceLastUpdatePreviousTime;
    NSTimeInterval timeSinceLastUpdate;
    bool firstUpdateCall;
    
    //Shadow Texture
    id<MTLRenderPipelineState> mtlShadowRenderPipelineState;
    
    MTLRenderPipelineDescriptor *mtlShadowRenderPipelineDescriptor;
    
    MTLRenderPassDescriptor *mtlShadowRenderPassDescriptor;
    
    id<MTLDepthStencilState> mtlShadowDepthStencilState;
    
    id<MTLLibrary> mtlShadowLibrary;
    
    id<MTLFunction> vertexShadowProgram;
    
    id<MTLFunction> fragmentShadowProgram;

    id<MTLTexture> shadowTexture;
    
    MTLDepthStencilDescriptor *shadowDepthStencilDescriptor;
    
    MTLStencilDescriptor *shadowStencilStateDescriptor;
    
    MTLVertexDescriptor *shadowVertexDesc;
    
    float contentScale;
    
}

/// Initialize with the MetalKit view from which we'll obtain our Metal device.  We'll also use this
/// mtkView object to set the pixelformat and other properties of our drawable
- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView
{
    self = [super init];
    if(self)
    {
        mtlDevice = mtkView.device;
        
        mtlCommandQueue = [mtlDevice newCommandQueue];
        
        float aspect=mtkView.bounds.size.width/mtkView.bounds.size.height;
        
        firstUpdateCall=false;
        
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        director->setMTLDevice(mtlDevice);
        
        director->setAspect(aspect);
        
        director->setDisplayWidthHeight(mtkView.frame.size.width, mtkView.frame.size.height);
        
        director->setMTLView(mtkView);
        
        //compute perspective space
        U4DEngine::U4DMatrix4n perspectiveSpace=director->computePerspectiveSpace(45.0f, aspect, 0.1f, 100.0f);
        director->setPerspectiveSpace(perspectiveSpace);
        
        //compute orthographic space
        U4DEngine::U4DMatrix4n orthographicSpace=director->computeOrthographicSpace(-1.0, 1.0, -1.0, 1.0, -1.0f, 1.0f);
        director->setOrthographicSpace(orthographicSpace);
        
        //compute orthographic shadow space
        U4DEngine::U4DMatrix4n orthographicShadowSpace=director->computeOrthographicSpace(-20.0, 20.0, -20.0, 20.0, -10.0, 10.0f);
        director->setOrthographicShadowSpace(orthographicShadowSpace);
        
        
        [self initShadows];
        
    }
    
    return self;
}


#pragma mark - MTKViewDelegate methods

- (void)update{

    if (!firstUpdateCall) {
        
        //init the time properties for the update
        
        timeSinceLastUpdate= 0.0;
        
        timeSinceLastUpdatePreviousTime = CACurrentMediaTime();
        
        firstUpdateCall=true;
        
    }else{
        
        // figure out the time since we last we drew
        CFTimeInterval currentTime = CACurrentMediaTime();
        
        timeSinceLastUpdate = currentTime - timeSinceLastUpdatePreviousTime;
        
        // keep track of the time interval between draws
        timeSinceLastUpdatePreviousTime = currentTime;
        
    }
    
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    director->update(timeSinceLastUpdate);
    
}

/// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    //call the update call before the render
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    float screenContentScale=director->getScreenScaleFactor();
    
    [self update];
    
    director->determineVisibility();
    
    view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1.0);
    view.depthStencilPixelFormat=MTLPixelFormatDepth32Float;
    
    // Create a new command buffer for each renderpass to the current drawable
    id <MTLCommandBuffer> commandBuffer = [mtlCommandQueue commandBuffer];
    commandBuffer.label = @"MyCommand";
    
    //Check if models are within the frustum, then render shadows
    if(director->getModelsWithinFrustum()==true){
       [self renderShadows:commandBuffer];
    }
    
    // Obtain a renderPassDescriptor generated from the view's drawable textures
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;

    // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll
    //   skip any rendering this frame because we have no drawable to draw to
    if(renderPassDescriptor != nil)
    {
        
        id <MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        
        renderEncoder.label = @"MyRenderEncoder";
        
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, view.bounds.size.width*screenContentScale, view.bounds.size.height*screenContentScale, 0.0, 1.0 }];
        
        //Render Models here
        director->render(renderEncoder);
        
        
        // We would normally use a render command encoder to tell Metal to draw our objects,
        //   but for the purposes of this sample, we will create it which implicitly invokes
        //   a GPU command to clear our drawable
        
        // Since we aren't drawing anything, indicate we're finished using this encoder
        [renderEncoder endEncoding];
        
    }
    
    // Add a final command to present the cleared drawable to the screen
    [commandBuffer presentDrawable:view.currentDrawable];
    
    // Finalize rendering here & push the command buffer to the GPU
    [commandBuffer commit];
    
    [commandBuffer waitUntilCompleted];
}

/// Called whenever the view size changes or a relayout occurs (such as changing from landscape to
///   portrait mode)
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
}

//Shadow methods

- (void)renderShadows:(id <MTLCommandBuffer>) uCommandBuffer{
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    //create a shadow command buffer
    
    //create a shadow encoder
    id<MTLRenderCommandEncoder> shadowEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:mtlShadowRenderPassDescriptor];
    
    shadowEncoder.label = @"MyShadowEncoder";
    
    //set the states
    [shadowEncoder setRenderPipelineState:mtlShadowRenderPipelineState];
    [shadowEncoder setDepthStencilState:mtlShadowDepthStencilState];
    [shadowEncoder setViewport:(MTLViewport){0.0, 0.0, 1024, 1024, 0.0, 1.0 }];
    
    //render every model shadow
    director->renderShadow(shadowEncoder,shadowTexture);
    
    //end encoding
    [shadowEncoder endEncoding];
    
    
}

- (void) initShadows{
    
    [self loadShadowMTLTexture];
    [self initShadowMTLRenderPass];
    [self initShadowMTLRenderLibrary];

    [self initShadowMTLRenderPipeline];
    
}

- (void) initShadowMTLRenderLibrary{
    
    mtlShadowLibrary=[mtlDevice newDefaultLibrary];
    
    vertexShadowProgram=[mtlShadowLibrary newFunctionWithName:@"vertexShadowShader"];
    fragmentShadowProgram=nil;
    
}

- (void) initShadowMTLRenderPass{
    
    //create a shadow pass descriptor
    mtlShadowRenderPassDescriptor=[MTLRenderPassDescriptor new];
    
    MTLRenderPassDepthAttachmentDescriptor *shadowAttachment=mtlShadowRenderPassDescriptor.depthAttachment;
    
    //Set the texture on the render pass descriptor
    shadowAttachment.texture=shadowTexture;
    
    //Set other properties on the render pass descriptor
    shadowAttachment.clearDepth=0.0;
    shadowAttachment.loadAction=MTLLoadActionClear;
    shadowAttachment.storeAction=MTLStoreActionStore;
    
    
}

- (void) initShadowMTLRenderPipeline{
    
    //set the pipeline descriptor
    
    mtlShadowRenderPipelineDescriptor=[MTLRenderPipelineDescriptor new];
    mtlShadowRenderPipelineDescriptor.vertexFunction=vertexShadowProgram;
    mtlShadowRenderPipelineDescriptor.fragmentFunction=nil;
    mtlShadowRenderPipelineDescriptor.depthAttachmentPixelFormat=shadowTexture.pixelFormat;
    
    shadowVertexDesc=[[MTLVertexDescriptor alloc] init];
    
    //position data
    shadowVertexDesc.attributes[0].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[0].bufferIndex=0;
    shadowVertexDesc.attributes[0].offset=0;
    
    //normal data
    shadowVertexDesc.attributes[1].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[1].bufferIndex=0;
    shadowVertexDesc.attributes[1].offset=4*sizeof(float);
    
    //uv data
    shadowVertexDesc.attributes[2].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[2].bufferIndex=0;
    shadowVertexDesc.attributes[2].offset=8*sizeof(float);
    
    //tangent data
    shadowVertexDesc.attributes[3].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[3].bufferIndex=0;
    shadowVertexDesc.attributes[3].offset=12*sizeof(float);
    
    //Material data
    shadowVertexDesc.attributes[4].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[4].bufferIndex=0;
    shadowVertexDesc.attributes[4].offset=16*sizeof(float);
    
    //vertex weight
    shadowVertexDesc.attributes[5].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[5].bufferIndex=0;
    shadowVertexDesc.attributes[5].offset=20*sizeof(float);
    
    //bone index
    shadowVertexDesc.attributes[6].format=MTLVertexFormatFloat4;
    shadowVertexDesc.attributes[6].bufferIndex=0;
    shadowVertexDesc.attributes[6].offset=24*sizeof(float);
    
    //stride with padding
    shadowVertexDesc.layouts[0].stride=28*sizeof(float);
    
    shadowVertexDesc.layouts[0].stepFunction=MTLVertexStepFunctionPerVertex;
    
    
    mtlShadowRenderPipelineDescriptor.vertexDescriptor=shadowVertexDesc;
    mtlShadowRenderPipelineDescriptor.vertexFunction=vertexShadowProgram;
    
    //Set the depth stencil descriptors
    shadowDepthStencilDescriptor=[[MTLDepthStencilDescriptor alloc] init];
    shadowDepthStencilDescriptor.depthCompareFunction=MTLCompareFunctionGreater;
    shadowDepthStencilDescriptor.depthWriteEnabled=YES;
    
    //add stencil description
    shadowStencilStateDescriptor=[[MTLStencilDescriptor alloc] init];
    shadowStencilStateDescriptor.stencilCompareFunction=MTLCompareFunctionAlways;
    shadowStencilStateDescriptor.stencilFailureOperation=MTLStencilOperationKeep;

    shadowDepthStencilDescriptor.frontFaceStencil=shadowStencilStateDescriptor;
    shadowDepthStencilDescriptor.backFaceStencil=shadowStencilStateDescriptor;

    
    mtlShadowDepthStencilState=[mtlDevice newDepthStencilStateWithDescriptor:shadowDepthStencilDescriptor];
    
    //create the render pipeline
    mtlShadowRenderPipelineState=[mtlDevice newRenderPipelineStateWithDescriptor:mtlShadowRenderPipelineDescriptor error:nil];
    
}

- (void) loadShadowMTLTexture{
    
    MTLTextureDescriptor *shadowTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1024 height:1024 mipmapped:NO];
    
    shadowTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    shadowTexture=[mtlDevice newTextureWithDescriptor:shadowTextureDescriptor];
    
}

- (void)dealloc{
    [super dealloc];
    [shadowDepthStencilDescriptor release];
    [shadowStencilStateDescriptor release];
    [shadowVertexDesc release];
}






@end
