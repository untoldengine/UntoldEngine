//
//  U4DShadowPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DShadowPass.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"


namespace U4DEngine{

U4DShadowPass::U4DShadowPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
    
    
}

U4DShadowPass::~U4DShadowPass(){
    
}

void U4DShadowPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){ 
    
    U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
    
    id <MTLRenderCommandEncoder> shadowRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:pipeline->mtlRenderPassDescriptor];
    
    [shadowRenderEncoder pushDebugGroup:@"Shadow Pass"];
    shadowRenderEncoder.label = @"Shadow Render Pass";
    
    [shadowRenderEncoder setViewport:(MTLViewport){0.0, 0.0, 1024, 1024, 0.0, 1.0 }];

    [shadowRenderEncoder setDepthBias: 0.01 slopeScale: 1.0f clamp: 0.01];
    
    [shadowRenderEncoder setVertexBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer]; 
    
    
    U4DEntity *child=uRootEntity;

    while (child!=NULL) {
        
        U4DRenderEntity *renderEntity=child->getRenderEntity();
        
        if(renderEntity!=nullptr){
            
            U4DRenderPipelineInterface* shadowPipe=renderEntity->getPipeline(U4DEngine::shadowPass);

            if (shadowPipe!=nullptr) {
                shadowPipe->executePipeline(shadowRenderEncoder, child);
            }
            
        }
        
           child=child->next;

       }
    
    [shadowRenderEncoder popDebugGroup];
    //end encoding
    [shadowRenderEncoder endEncoding];
    
}


}
