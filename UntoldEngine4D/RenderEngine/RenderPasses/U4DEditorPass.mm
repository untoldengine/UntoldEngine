//
//  U4DEditorPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/29/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DEditorPass.h"
#include "U4DDirector.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"
#include "U4DProfilerManager.h"
#include "U4DDebugger.h"
#include "U4DCamera.h"
#include "U4DDirectionalLight.h"
#include "U4DLogger.h"

#include "imgui.h"
#include "imgui_impl_metal.h"

#if TARGET_OS_OSX
#include "imgui_impl_osx.h"

#endif

namespace U4DEngine{

U4DEditorPass::U4DEditorPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
}

U4DEditorPass::~U4DEditorPass(){
    
}

void U4DEditorPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    
    U4DDirector *director=U4DDirector::sharedInstance();
    U4DDebugger *debugger=U4DDebugger::sharedInstance();
    
    float fps=director->getFPS();
    std::string profilerData=debugger->profilerData;
    
    MTLRenderPassDescriptor *mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
           mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
           mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
           mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    
    
    id <MTLRenderCommandEncoder> editorRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

    if(editorRenderEncoder!=nil){

        [editorRenderEncoder pushDebugGroup:@"Editor Comp Pass"];
        editorRenderEncoder.label = @"Editor Comp Render Pass";

        // Start the Dear ImGui frame
        ImGui_ImplMetal_NewFrame(mtlRenderPassDescriptor);
         #if TARGET_OS_OSX
         ImGui_ImplOSX_NewFrame(director->getMTLView());
         #endif
         ImGui::NewFrame();

         {
             
             ImGui::Begin("Debugger");                          // Create a window called "Hello, world!" and append into it.

             ImGui::Text("FPS: %f",fps);               // Display some text (you can use a format strings too)
             ImGui::Text("Profiler:\n %s",profilerData.c_str());

             ImGui::End();
         }
        
        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, uCommandBuffer, editorRenderEncoder);

        [editorRenderEncoder popDebugGroup];
        //end encoding
        [editorRenderEncoder endEncoding];

    }
    
}


}
