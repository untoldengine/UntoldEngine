//
//  U4DRenderPassInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderPassInterface_hpp
#define U4DRenderPassInterface_hpp

#include <stdio.h>
#import <MetalKit/MetalKit.h>
#include "U4DEntity.h"
#include "U4DRenderPipelineInterface.h"

namespace U4DEngine {

class U4DRenderPassInterface {
    
    
public:
    
    virtual ~U4DRenderPassInterface(){};

    virtual void executePass(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity, U4DRenderPassInterface *uPreviousRenderPass)=0;
    
    virtual U4DRenderPipelineInterface *getPipeline()=0;
    
};

}


#endif /* U4DRenderPassInterface_hpp */
