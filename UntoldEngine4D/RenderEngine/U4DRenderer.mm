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
#include "U4DSceneManager.h"
#include "Constants.h"

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
    
    MTLRenderPassDescriptor *mtlOffscreenRenderPassDescriptor;
    
    id<MTLLibrary> mtlShadowLibrary;
    
    id<MTLFunction> vertexShadowProgram;
    
    id<MTLFunction> fragmentShadowProgram;

    id<MTLTexture> shadowTexture;
    
    id<MTLTexture> offscreenRenderTexture;
    
    id<MTLTexture> offscreenDepthTexture;
    
    MTLDepthStencilDescriptor *shadowDepthStencilDescriptor;
    
    MTLStencilDescriptor *shadowStencilStateDescriptor;
    
    MTLVertexDescriptor *shadowVertexDesc;
    
    float contentScale;
    
    int frameCount;
    float timePassedSinceLastFrame;
    
    //set up the semaphores
    dispatch_semaphore_t inFlightSemaphore;
    
    
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
        
        inFlightSemaphore=dispatch_semaphore_create(U4DEngine::kMaxBuffersInFlight);
        
        float aspect=mtkView.bounds.size.width/mtkView.bounds.size.height;
        
        firstUpdateCall=false;
        
        U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
        
        director->setMTLDevice(mtlDevice);
        
        director->setAspect(aspect);
        
        director->setDisplayWidthHeight(mtkView.frame.size.width, mtkView.frame.size.height);
        mtkView.depthStencilPixelFormat=MTLPixelFormatDepth32Float;
        
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
        [self initOffscreenRenderPass];
        
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
        
        //init fps time properties
        frameCount=0;
        timePassedSinceLastFrame=0.0;
        
    }else{
        
        // figure out the time since we last we drew
        CFTimeInterval currentTime = CACurrentMediaTime();
        
        timeSinceLastUpdate = currentTime - timeSinceLastUpdatePreviousTime;
        
        // keep track of the time interval between draws
        timeSinceLastUpdatePreviousTime = currentTime;
        
        //get fps
        timePassedSinceLastFrame+=timeSinceLastUpdate;
        
        if(timePassedSinceLastFrame>1.0){
            
            U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
            
            float fps=frameCount/timePassedSinceLastFrame;
            
            frameCount=0.0;
            timePassedSinceLastFrame=0.0;
            
            director->setFPS(fps);
            
        }
        
    }
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    if (currentScene!=nullptr) {
        currentScene->update(timeSinceLastUpdate);
    }
    
}

/// Called whenever the view needs to render
- (void)drawInMTKView:(nonnull MTKView *)view
{
    view.framebufferOnly=false;
    //Wait until the semaphore command buffer has completed its work
    dispatch_semaphore_wait(inFlightSemaphore, DISPATCH_TIME_FOREVER);
    
    //call the update call before the render
    frameCount++;
    
    U4DEngine::U4DDirector *director=U4DEngine::U4DDirector::sharedInstance();
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
    float screenContentScale=director->getScreenScaleFactor();
    
    currentScene->determineVisibility();
    
    if (currentScene!=nullptr) {
        
        view.clearColor = MTLClearColorMake(0.0,0.0,0.0,1.0);
        view.depthStencilPixelFormat=MTLPixelFormatDepth32Float;
        
        // Create a new command buffer for each renderpass to the current drawable
        id <MTLCommandBuffer> commandBuffer = [mtlCommandQueue commandBuffer];
        commandBuffer.label = @"MyCommand";
        
        __block dispatch_semaphore_t block_sema = inFlightSemaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> buffer)
         {
            //GPU work is complete
            //Signal the semaphore to start the CPU work
             dispatch_semaphore_signal(block_sema);
         }];
        
        [self update];
        
        //Check if models are within the frustum, then render shadows
        if(director->getModelsWithinFrustum()==true){
           
            //create a shadow encoder
            id<MTLRenderCommandEncoder> shadowEncoder=[commandBuffer renderCommandEncoderWithDescriptor:mtlShadowRenderPassDescriptor];
            
            [shadowEncoder pushDebugGroup:@"Shadow Pass"];
            shadowEncoder.label = @"MyShadowEncoder";
            
            //set the states
            [shadowEncoder setRenderPipelineState:mtlShadowRenderPipelineState];
            [shadowEncoder setDepthStencilState:mtlShadowDepthStencilState];
            [shadowEncoder setViewport:(MTLViewport){0.0, 0.0, 1024, 1024, 0.0, 1.0 }];
            
            //render every model shadow
            currentScene->renderShadow(shadowEncoder,shadowTexture);
            
            [shadowEncoder popDebugGroup];
            //end encoding
            [shadowEncoder endEncoding];
            
        }
        
        {
            //set offscreen texture render
            
            id<MTLRenderCommandEncoder> offscreenRenderEncoder=[commandBuffer renderCommandEncoderWithDescriptor:mtlOffscreenRenderPassDescriptor];

            [offscreenRenderEncoder pushDebugGroup:@"offscreen Rendering"];
            offscreenRenderEncoder.label=@"Offscreen Render Pass";

            [offscreenRenderEncoder setViewport:(MTLViewport){0.0, 0.0, 1024.0, 1024.0, 0.0, 1.0 }];

            //render models offscreen
            currentScene->renderOffscreen(offscreenRenderEncoder,offscreenRenderTexture);

            [offscreenRenderEncoder popDebugGroup];
            [offscreenRenderEncoder endEncoding];
            
        }
        
//        //create blit encoder
//        id<MTLBlitCommandEncoder> blitEncoder=[commandBuffer blitCommandEncoder];
//        [blitEncoder pushDebugGroup:@"Blit Encoder"];
//        blitEncoder.label=@"Blit Encoder-active";
//
//        [blitEncoder copyFromTexture:offscreenRenderTexture toTexture:view.currentDrawable.texture];
//
//        [blitEncoder popDebugGroup];
//        [blitEncoder endEncoding];
        
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        //renderPassDescriptor.depthAttachment.loadAction=MTLLoadActionClear;
        //renderPassDescriptor.depthAttachment.clearDepth=1.0;

        //start final pass
        // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll
        //   skip any rendering this frame because we have no drawable to draw to
        if(renderPassDescriptor != nil)
        {
            
            id <MTLRenderCommandEncoder> renderEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            [renderEncoder pushDebugGroup:@"final pass"];
            renderEncoder.label = @"MyRenderEncoder";
            
            [renderEncoder setViewport:(MTLViewport){0.0, 0.0, view.bounds.size.width*screenContentScale, view.bounds.size.height*screenContentScale, 0.0, 1.0 }];
            
            //Render Models here
            currentScene->render(renderEncoder);
            
            
            [renderEncoder popDebugGroup];
            // Indicate we're finished using this encoder
            [renderEncoder endEncoding];
            
        }
        
        // Add a final command to present the cleared drawable to the screen-Original
        //[commandBuffer presentDrawable:view.currentDrawable];
        
        //This method is the latest method provided by Metal, but it seems buggy. Sometimes, it creates micro-stuttering. Leaving it here for now. Don't forget to remove this warning
        if (@available(macOS 10.15.4, *)) {
            [commandBuffer presentDrawable:view.currentDrawable afterMinimumDuration:1.0/view.preferredFramesPerSecond];
        } else {
            // Fallback on earlier versions
            [commandBuffer presentDrawable:view.currentDrawable];
        }
        
        // Finalize rendering here & push the command buffer to the GPU
        [commandBuffer commit];
        
    }
    
    //check if there is a request to change scene, and if it is safe to do so
    if(sceneManager->getRequestToChangeScene()){
        sceneManager->isSafeToChangeScene();
    }
    
    
}

/// Called whenever the view size changes or a relayout occurs (such as changing from landscape to
///   portrait mode)
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size{
}

//Shadow methods

- (void)renderShadows:(id <MTLCommandBuffer>) uCommandBuffer{
    
    //U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    //U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    //create a shadow command buffer
    
//    //create a shadow encoder
//    id<MTLRenderCommandEncoder> shadowEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:mtlShadowRenderPassDescriptor];
//
//    shadowEncoder.label = @"MyShadowEncoder";
//
//    //set the states
//    [shadowEncoder setRenderPipelineState:mtlShadowRenderPipelineState];
//    [shadowEncoder setDepthStencilState:mtlShadowDepthStencilState];
//    [shadowEncoder setViewport:(MTLViewport){0.0, 0.0, 1024, 1024, 0.0, 1.0 }];
//
//    //render every model shadow
//    currentScene->renderShadow(shadowEncoder,shadowTexture);
//
//    //end encoding
//    [shadowEncoder endEncoding];
    
    
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
    
    shadowTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    shadowTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    shadowTexture=[mtlDevice newTextureWithDescriptor:shadowTextureDescriptor];
    
}

- (void) initOffscreenRenderPass{
    
    
    //create texture descriptor
    MTLTextureDescriptor *offscreenRenderTextureDescriptor = [MTLTextureDescriptor new];
    offscreenRenderTextureDescriptor.textureType = MTLTextureType2D;
    offscreenRenderTextureDescriptor.width = 1024.0;
    offscreenRenderTextureDescriptor.height = 1024.0;
    offscreenRenderTextureDescriptor.pixelFormat = MTLPixelFormatRGBA8Unorm;
    offscreenRenderTextureDescriptor.usage = MTLTextureUsageRenderTarget |
                          MTLTextureUsageShaderRead;
    
    //create first pass texture
    
    offscreenRenderTexture=[mtlDevice newTextureWithDescriptor:offscreenRenderTextureDescriptor];
    
    //create depth texture
    MTLTextureDescriptor *offscreenDepthTextureDescriptor=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float width:1024 height:1024 mipmapped:NO];
    
    offscreenDepthTextureDescriptor.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
    offscreenDepthTextureDescriptor.storageMode=MTLStorageModePrivate;
    
    offscreenDepthTexture=[mtlDevice newTextureWithDescriptor:offscreenDepthTextureDescriptor];
    
    //set up the offscreen render pass descriptor
    
    mtlOffscreenRenderPassDescriptor=[MTLRenderPassDescriptor new];
    mtlOffscreenRenderPassDescriptor.colorAttachments[0].texture=offscreenRenderTexture;
    mtlOffscreenRenderPassDescriptor.depthAttachment.texture=offscreenDepthTexture;
    
    mtlOffscreenRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    mtlOffscreenRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0);
    mtlOffscreenRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    mtlOffscreenRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionClear;
    mtlOffscreenRenderPassDescriptor.depthAttachment.clearDepth=1.0;
    mtlOffscreenRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
    
}

- (void)dealloc{
    [super dealloc];
    [shadowDepthStencilDescriptor release];
    [shadowStencilStateDescriptor release];
    [shadowVertexDesc release];
}






@end
