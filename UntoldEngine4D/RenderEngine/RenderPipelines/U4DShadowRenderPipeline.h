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
    
    U4DShadowRenderPipeline(std::string uName);
    
    ~U4DShadowRenderPipeline();
    
    void initLibrary(std::string uVertexShader, std::string uFragmentShader);
    
    void initTargetTexture();
    
    void initVertexDesc();

    void initPassDesc();
    
    bool buildPipeline();
    
    void initAdditionalInfo();
    
    void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
    
    
};

}


#endif /* U4DShadowRenderPipeline_hpp */
