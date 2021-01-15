//
//  U4DShaderEntityPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/13/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DShaderEntityPipeline_hpp
#define U4DShaderEntityPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"

namespace U4DEngine {

    class U4DShaderEntityPipeline: public U4DRenderPipeline {
        
    private:
        
    public:
        
        U4DShaderEntityPipeline(id <MTLDevice> uMTLDevice, std::string uName);
        
        ~U4DShaderEntityPipeline();

        void initRenderPassTargetTexture();
        
        void initVertexDesc();

        void initRenderPassDesc();
        
        void initRenderPassPipeline();
        
        void initRenderPassAdditionalInfo();
        
        void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}
#endif /* U4DShaderEntityPipeline_hpp */
