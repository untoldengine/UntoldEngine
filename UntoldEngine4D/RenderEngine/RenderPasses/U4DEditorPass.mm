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
    U4DLogger *logger=U4DLogger::sharedInstance();
    
    static U4DEntity *activeChild=nullptr;
    static bool showWorldPropery=false;
    static bool showScenegraph=false;
    static bool showLog=false;
    
    float fps=director->getFPS();
    std::string profilerData=debugger->profilerData;
    
    MTLRenderPassDescriptor *mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
           mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
           mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
           mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
    
    
    id <MTLRenderCommandEncoder> imGUIRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

    if(imGUIRenderEncoder!=nil){

        [imGUIRenderEncoder pushDebugGroup:@"Editor Comp Pass"];
        imGUIRenderEncoder.label = @"Editor Comp Render Pass";

        // Start the Dear ImGui frame
        ImGui_ImplMetal_NewFrame(mtlRenderPassDescriptor);
#if TARGET_OS_OSX
        ImGui_ImplOSX_NewFrame(director->getMTLView());
#endif
        ImGui::NewFrame();

        {
            ImGui::StyleColorsDark2();
            ImGui::Begin("Debugger");                          // Create a window called "Hello, world!" and append into it.

            ImGui::Text("FPS: %f",fps);               // Display some text (you can use a format strings too)
            ImGui::Text("Profiler:\n %s",profilerData.c_str());
            
            ImGui::Separator();
            ImGui::Checkbox("Show Scenegraph", &showScenegraph);
            ImGui::Checkbox("Show World Property", &showWorldPropery);
            ImGui::Checkbox("Show Log", &showLog);
            ImGui::End();
        }
        
        if(showWorldPropery){
            ImGui::Begin("World Properties");
            ImGui::Text("Camera");
            U4DCamera *camera=U4DCamera::sharedInstance();
            
            U4DVector3n cameraPos=camera->getAbsolutePosition();
            U4DVector3n cameraOrient=camera->getAbsoluteOrientation();
            
            float pos[3] = {cameraPos.x,cameraPos.y,cameraPos.z};
            float orient[3]={cameraOrient.x,cameraOrient.y,cameraOrient.z};

            ImGui::SliderFloat3("Position", (float*)&pos,-50.0,50.0);
            ImGui::SliderFloat3("Orientation", (float*)&orient,-90.0,90.0);

            camera->translateTo(pos[0], pos[1], pos[2]);
            camera->rotateTo(orient[0], orient[1], orient[2]);
            
            ImGui::Separator();
            ImGui::Text("Light");
            U4DDirectionalLight *dirLight=U4DDirectionalLight::sharedInstance();
            
            U4DVector3n lightPos=dirLight->getAbsolutePosition();
            U4DVector3n lightOrient=dirLight->getAbsoluteOrientation();
            U4DVector3n diffuseColor=dirLight->getDiffuseColor();
            
            float lightpos[3] = {lightPos.x,lightPos.y,lightPos.z};
            float lightorient[3]={lightOrient.x,lightOrient.y,lightOrient.z};
            float color[3] = {diffuseColor.x,diffuseColor.y,diffuseColor.z};
            
            ImGui::SliderFloat3("Light Position", (float*)&lightpos,-30.0,30.0);
            ImGui::SliderFloat3("Light Orientation", (float*)&lightorient,-90.0,90.0);
            ImGui::SliderFloat3("Color", (float*)&color,0.0,1.0);
            
            diffuseColor=U4DVector3n(color[0],color[1],color[2]);
            
            dirLight->translateTo(lightpos[0], lightpos[1], lightpos[2]);
            dirLight->rotateTo(lightorient[0], lightorient[1], lightorient[2]);
            dirLight->setDiffuseColor(diffuseColor);
            
            ImGui::End();
        }
        
        if(showScenegraph){
            ImGui::Begin("Scene Property");
            if (ImGui::TreeNode("Scenegraph"))
            {
                
                U4DEntity *child=debugger->world->next;
                
                while (child!=nullptr) {
                    
                    if (child->getEntityType()==U4DEngine::MODEL) {
                        
                        char buf[32];
                        
                        sprintf(buf, "%s", child->getName().c_str());
                        
                        if (ImGui::Selectable(buf,activeChild==child)) {
                            activeChild=child;
                            
                        }

                    }
                    
                    child=child->next;
                    
                }
            
                {
                    ImGui::Begin("Entity Properties");

                    if (activeChild!=nullptr) {
                        
                        U4DVector3n childPos=activeChild->getAbsolutePosition();
                        U4DVector3n childOrient=activeChild->getAbsoluteOrientation();
                        
                        float pos[3] = {childPos.x,childPos.y,childPos.z};
                        float orient[3]={childOrient.x,childOrient.y,childOrient.z};

                        ImGui::Text("Entity Name: %s",activeChild->getName().c_str());
                        
                        ImGui::Text("Transform");
                        ImGui::SliderFloat3("Position", (float*)&pos,-20.0,20.0);
                        ImGui::SliderFloat3("Orientation", (float*)&orient,-180.0,180.0);

                        ImGui::Separator();
                        
                        ImGui::Text("Rigid Body");
                        std::string isKineticsBehavior=activeChild->isKineticsBehaviorEnabled()?"true":"false";
                        std::string isCollisionBehavior=activeChild->isCollisionBehaviorEnabled()?"true":"false";
                        
                        ImGui::Text("Kinetics Behavior: %s",isKineticsBehavior.c_str());
                        ImGui::Text("Collision Behavior: %s",isCollisionBehavior.c_str());
                        
                        
                        activeChild->translateTo(pos[0], pos[1], pos[2]);
                        activeChild->rotateTo(orient[0], orient[1], orient[2]);
                        
                    }

                    ImGui::End();

                }
                
                ImGui::TreePop();
            
            }
            
            ImGui::End();
        
        }
        
        if(showLog){
            
//            ImGuiTextBuffer Buf;
//            static bool scrollToBottom=true;
//
//
//            const char* t=logger->buffer;
//            Buf.append(t);
//
//            scrollToBottom=true;
//
//            ImGui::Begin("Log");
//                ImGui::TextUnformatted(Buf.begin());
//                if (scrollToBottom) {
//                    ImGui::SetScrollHere(1.0f);
//                }
//                scrollToBottom=false;
//            ImGui::End();
        }
        
        // Rendering
        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, uCommandBuffer, imGUIRenderEncoder);

        [imGUIRenderEncoder popDebugGroup];
        //end encoding
        [imGUIRenderEncoder endEncoding];

    }
    
}


}
