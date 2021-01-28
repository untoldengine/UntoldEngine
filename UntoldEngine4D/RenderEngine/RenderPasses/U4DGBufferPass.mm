//
//  U4DGBufferPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DGBufferPass.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"


namespace U4DEngine{

U4DGBufferPass::U4DGBufferPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
}

U4DGBufferPass::~U4DGBufferPass(){
    
}

void U4DGBufferPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
    
    id <MTLRenderCommandEncoder> gBufferRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:pipeline->mtlRenderPassDescriptor];

    [gBufferRenderEncoder pushDebugGroup:@"G-Buffer Pass"];
    gBufferRenderEncoder.label = @"G-Buffer Render Pass";

    [gBufferRenderEncoder setVertexBuffer:renderManager->globalDataUniform offset:0 atIndex:viGlobalDataBuffer];

    [gBufferRenderEncoder setVertexBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer];

    [gBufferRenderEncoder setFragmentBuffer:renderManager->globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];

    [gBufferRenderEncoder setFragmentBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];

    pipeline->inputTexture=uPreviousRenderPass->getPipeline()->targetTexture;

    U4DEntity *child=uRootEntity;

    while (child!=NULL) {

        U4DRenderEntity *renderEntity=child->getRenderEntity();

        if(renderEntity!=nullptr){

            U4DRenderPipelineInterface* gBufferPipeline=renderEntity->getPipeline(U4DEngine::gBufferPass);

            if (gBufferPipeline!=nullptr) {
                gBufferPipeline->executePass(gBufferRenderEncoder, child);
            }

        }

           child=child->next;

       }

    [gBufferRenderEncoder popDebugGroup];
    //end encoding
    [gBufferRenderEncoder endEncoding];
    
}


}
