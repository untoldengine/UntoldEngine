//
//  U4DRenderPass.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderPass_hpp
#define U4DRenderPass_hpp

#include <stdio.h>
#import <MetalKit/MetalKit.h>
#include "U4DEntity.h"
#include "U4DRenderPipelineInterface.h"
#include "U4DRenderPassInterface.h"

namespace U4DEngine {

    class U4DRenderPass: public U4DRenderPassInterface {

    private:
        
        std::string pipelineName;
    
    protected:
                
        U4DRenderPipelineInterface *pipeline; 
        
        
    public:
        
        U4DRenderPass(std::string uPipelineName);
        
        ~U4DRenderPass();
        
        virtual void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass){};
        
        U4DRenderPipelineInterface *getPipeline();
        
    };

}

#endif /* U4DRenderPass_hpp */
