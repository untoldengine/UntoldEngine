//
//  U4DSkyboxPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DSkyboxPipeline_hpp
#define U4DSkyboxPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"

namespace U4DEngine {

    class U4DSkyboxPipeline: public U4DRenderPipeline{

    private:
        
    public:
        
        U4DSkyboxPipeline(id <MTLDevice> uMTLDevice, std::string uName);
        
        ~U4DSkyboxPipeline();
        
        void initRenderPassTargetTexture();
        
        void initVertexDesc();

        void initRenderPassDesc();
        
        void initRenderPassPipeline();
        
        void initRenderPassAdditionalInfo();
        
        void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}

#endif /* U4DSkyboxPipeline_hpp */
