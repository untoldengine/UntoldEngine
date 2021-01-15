//
//  U4DShadowRenderPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShadowRenderPipeline_hpp
#define U4DShadowRenderPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"
#include "U4DRenderEntity.h"

namespace U4DEngine {

class U4DShadowRenderPipeline:public U4DRenderPipeline {
    
private:
    
    
public:
    
    U4DShadowRenderPipeline(id <MTLDevice> uMTLDevice, std::string uName);
    
    ~U4DShadowRenderPipeline();
    
    void initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader);
    
    void initRenderPassTargetTexture();
    
    void initVertexDesc();

    void initRenderPassDesc();
    
    void initRenderPassPipeline();
    
    void initRenderPassAdditionalInfo();
    
    
    void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
    
    
};

}


#endif /* U4DShadowRenderPipeline_hpp */
