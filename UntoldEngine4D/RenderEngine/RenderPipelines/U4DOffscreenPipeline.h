//
//  U4DOffscreenPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/7/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DOffscreenPipeline_hpp
#define U4DOffscreenPipeline_hpp

#include <stdio.h>
#include "U4DModelPipeline.h"

namespace U4DEngine {

    class U4DOffscreenPipeline: public U4DModelPipeline {

    private:
        
    public:
        
        U4DOffscreenPipeline(std::string uName);
        
        ~U4DOffscreenPipeline();
        
        void initPassDesc();
        
        void initTargetTexture();
        
        bool buildPipeline();
        
        void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}


#endif /* U4DOffscreenPipeline_hpp */
