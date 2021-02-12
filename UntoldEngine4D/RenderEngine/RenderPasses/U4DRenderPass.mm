//
//  U4DRenderPass.cpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#include "U4DRenderPass.h"
#include "U4DRenderManager.h"

namespace U4DEngine{

    U4DRenderPass::U4DRenderPass(std::string uPipelineName):pipelineName(uPipelineName),pipeline(nullptr){
        
        U4DRenderManager *renderManager=U4DRenderManager::sharedInstance();
        
        pipeline=renderManager->searchPipeline(uPipelineName); 
        
        
    }

    U4DRenderPass::~U4DRenderPass(){
        
    }

    U4DRenderPipelineInterface *U4DRenderPass::getPipeline(){
        return pipeline; 
    }
}
