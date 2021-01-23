//
//  U4DGBufferPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/21/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGBufferPipeline_hpp
#define U4DGBufferPipeline_hpp

#include <stdio.h>
#include "U4DModelPipeline.h"

namespace U4DEngine {

class U4DGBufferPipeline: public U4DModelPipeline {

private:
    
public:
    
    U4DGBufferPipeline(id <MTLDevice> uMTLDevice, std::string uName);
    
    ~U4DGBufferPipeline();
    
    void initRenderPassTargetTexture();
    
    void initRenderPassDesc();
    
    void initRenderPassPipeline();
    
    void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
    
};

}

#endif /* U4DGBufferPipeline_hpp */
