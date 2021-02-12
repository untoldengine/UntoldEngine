//
//  U4DFinalPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DFinalPass.h"
#include "U4DDirector.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"


namespace U4DEngine{

U4DFinalPass::U4DFinalPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
}

U4DFinalPass::~U4DFinalPass(){
    
}

void U4DFinalPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
    U4DDirector *director=U4DDirector::sharedInstance();
    
    pipeline->inputTexture=uPreviousRenderPass->getPipeline()->targetTexture;

    MTLRenderPassDescriptor *mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
           mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
           mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
           mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    
    
    
    //Note: The following changes will be need to be done in the U4DFinalPass class if using the U4DComposition pass, you need to make sure that the mtlRenderPassDescriptor depth attachment load action is set to load. And the the mtlRenderPassDescriptor color attachment[0] load action is set to load. Moreover, the pass to pipeline mapping needs to be modified for all 3D models. That is, comment out the mapping  U4DEngine::finalPass->"modelpipeline" in U4DModel.mm class. All of these changes are needed because you are using g-buffer and a composition pass which is already taking care of most of these items.
    //Here is an example:
    /*mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionLoad;
     
     mtlRenderPassDescriptor.depthAttachment.clearDepth=1.0;
     mtlRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
     mtlRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionLoad;
     */
    
    id <MTLRenderCommandEncoder> finalCompRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

    if(finalCompRenderEncoder!=nil){

        [finalCompRenderEncoder pushDebugGroup:@"Final Comp Pass"];
        finalCompRenderEncoder.label = @"Final Comp Render Pass";
        
        [finalCompRenderEncoder setViewport:(MTLViewport){0.0, 0.0, (director->getMTLView().drawableSize.width), (director->getMTLView().drawableSize.height), 0.0, 1.0 }];
        
        [finalCompRenderEncoder setVertexBuffer:renderManager->globalDataUniform offset:0 atIndex:viGlobalDataBuffer];

        [finalCompRenderEncoder setVertexBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:viDirLightPropertiesBuffer];

        [finalCompRenderEncoder setFragmentBuffer:renderManager->globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];

        [finalCompRenderEncoder setFragmentBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];

        //inpute texture here is the depth texture for the shadow
        [finalCompRenderEncoder setFragmentTexture:pipeline->inputTexture atIndex:fiDepthTexture];
        
        
        U4DEntity *child=uRootEntity;

        while (child!=NULL) {

            U4DRenderEntity *renderEntity=child->getRenderEntity();

            if(renderEntity!=nullptr){

                U4DRenderPipelineInterface* renderPipeline=renderEntity->getPipeline(U4DEngine::finalPass);

                if (renderPipeline!=nullptr) {
                    renderPipeline->executePass(finalCompRenderEncoder, child);
                }

            }

            child=child->next;

           }

        [finalCompRenderEncoder popDebugGroup];
        //end encoding
        [finalCompRenderEncoder endEncoding];

    }
    
}


}
