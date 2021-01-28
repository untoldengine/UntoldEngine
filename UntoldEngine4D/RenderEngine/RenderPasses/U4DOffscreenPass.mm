//
//  U4DOffscreenPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DOffscreenPass.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"


namespace U4DEngine{

U4DOffscreenPass::U4DOffscreenPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
    
    
}

U4DOffscreenPass::~U4DOffscreenPass(){
    
}

void U4DOffscreenPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    id <MTLRenderCommandEncoder> offscreenRenderEncoder=[uCommandBuffer renderCommandEncoderWithDescriptor:pipeline->mtlRenderPassDescriptor];
            
    [offscreenRenderEncoder pushDebugGroup:@"Offscreen pass"];
    offscreenRenderEncoder.label=@"Offscreen render pass";

    U4DEntity *child=uRootEntity;

    while (child!=NULL) {

        U4DRenderEntity *renderEntity=child->getRenderEntity();

        if(renderEntity!=nullptr){

            U4DRenderPipelineInterface* renderPipeline=renderEntity->getPipeline(U4DEngine::offscreenPass);

            if (renderPipeline!=nullptr) {
                renderPipeline->executePass(offscreenRenderEncoder, child);
            }

        }

           child=child->next;

       }

    [offscreenRenderEncoder popDebugGroup];
    [offscreenRenderEncoder endEncoding];
    
}


}
