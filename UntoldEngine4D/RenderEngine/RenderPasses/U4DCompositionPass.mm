//
//  U4DCompositionPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DCompositionPass.h"
#include "U4DRenderManager.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DShaderProtocols.h"
#include "U4DEntity.h"
#include "U4DDirector.h"

namespace U4DEngine{

U4DCompositionPass::U4DCompositionPass(std::string uPipelineName):U4DRenderPass(uPipelineName){
    
    
    
}

U4DCompositionPass::~U4DCompositionPass(){
    
}

void U4DCompositionPass::executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){
    
    U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
    U4DDirector *director=U4DDirector::sharedInstance();
    MTLRenderPassDescriptor *mtlRenderPassDescriptor = director->getMTLView().currentRenderPassDescriptor;
    
    pipeline->albedoTexture=uPreviousRenderPass->getPipeline()->albedoTexture;
    pipeline->normalTexture=uPreviousRenderPass->getPipeline()->normalTexture;
    pipeline->positionTexture=uPreviousRenderPass->getPipeline()->positionTexture;
    pipeline->depthTexture=uPreviousRenderPass->getPipeline()->depthTexture;
    
    //blit Encoder Pass-THIS SECTION WAS REMOVED SINCE IT BREAKS WHEN SWITCHING SCREENS. FOR NOW, NO TRANSPARENCIES WILL WORK.
//    id<MTLBlitCommandEncoder> blitCommandEncoder=uCommandBuffer.blitCommandEncoder;
//
//    [blitCommandEncoder copyFromTexture:uPreviousRenderPass->getPipeline()->depthTexture sourceSlice:0 sourceLevel:0 sourceOrigin:MTLOriginMake(0.0, 0.0, 0.0) sourceSize:MTLSizeMake(director->getMTLView().drawableSize.width,director->getMTLView().drawableSize.height,1) toTexture:mtlRenderPassDescriptor.depthAttachment.texture destinationSlice:0 destinationLevel:0 destinationOrigin:MTLOriginMake(0.0, 0.0, 0.0)];
//
//    [blitCommandEncoder endEncoding];
//    mtlRenderPassDescriptor.depthAttachment.clearDepth=1.0;
//    mtlRenderPassDescriptor.depthAttachment.storeAction=MTLStoreActionStore;
//    mtlRenderPassDescriptor.depthAttachment.loadAction=MTLLoadActionLoad;
   
    mtlRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1);
    mtlRenderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    mtlRenderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    
    //Composition Pass
    id <MTLRenderCommandEncoder> compositionRenderEncoder =
    [uCommandBuffer renderCommandEncoderWithDescriptor:mtlRenderPassDescriptor];

    if(compositionRenderEncoder!=nil){

        [compositionRenderEncoder pushDebugGroup:@"Composition Pass"];
        compositionRenderEncoder.label = @"Composition Render Pass";

        [compositionRenderEncoder setViewport:(MTLViewport){0.0, 0.0, (director->getMTLView().drawableSize.width), (director->getMTLView().drawableSize.height), 0.0, 1.0 }];

        [compositionRenderEncoder setFragmentBuffer:renderManager->globalDataUniform offset:0 atIndex:fiGlobalDataBuffer];

        [compositionRenderEncoder setFragmentBuffer:renderManager->directionalLightPropertiesUniform offset:0 atIndex:fiDirLightPropertiesBuffer];

        [compositionRenderEncoder setFragmentBuffer:renderManager->pointLightsPropertiesUniform offset:0 atIndex:fiPointLightsPropertiesBuffer];

        pipeline->executePipeline(compositionRenderEncoder);

        [compositionRenderEncoder popDebugGroup];
        //end encoding
        [compositionRenderEncoder endEncoding];

    }
    
}


}
