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
#include "U4DRenderManager.h"

#include "imgui.h"
#include "imgui_impl_metal.h"

#if TARGET_OS_OSX
#include "imgui_impl_osx.h"

#endif

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
        mtkView.framebufferOnly=false; //this seems to be needed for the referred rendering.
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
        
        U4DEngine::U4DRenderManager *renderManager=U4DEngine::U4DRenderManager::sharedInstance();
        renderManager->initRenderPipelines();
        
        IMGUI_CHECKVERSION();
        ImGui::CreateContext();
        ImGuiIO& io = ImGui::GetIO(); (void)io;
        //io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;     // Enable Keyboard Controls
        //io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls

        // Setup Dear ImGui style
        ImGui::StyleColorsDark();
        //ImGui::StyleColorsClassic();

        // Setup Renderer backend
        ImGui_ImplMetal_Init(mtlDevice);
        
        
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
    
    U4DEngine::U4DSceneManager *sceneManager=U4DEngine::U4DSceneManager::sharedInstance();
    U4DEngine::U4DScene *currentScene=sceneManager->getCurrentScene();
    
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
        
        // Obtain a renderPassDescriptor generated from the view's drawable textures
        MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
        renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        
        // If we've gotten a renderPassDescriptor we can render to the drawable, otherwise we'll
        //   skip any rendering this frame because we have no drawable to draw to
        if(renderPassDescriptor != nil)
        {

            //Render Models here
            currentScene->render(commandBuffer);
            
        }
           
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



- (void)dealloc{
    [super dealloc];
    
}


@end
