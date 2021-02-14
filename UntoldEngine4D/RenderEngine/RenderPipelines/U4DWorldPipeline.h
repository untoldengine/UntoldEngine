//
//  U4DWorldPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DWorldPipeline_hpp
#define U4DWorldPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"

namespace U4DEngine {

    class U4DWorldPipeline: public U4DRenderPipeline {
        
    private:
        
    public:
        
        U4DWorldPipeline(std::string uName);
        
        ~U4DWorldPipeline();
        
        void initTargetTexture();
        
        void initVertexDesc();

        void initPassDesc();
        
        bool buildPipeline();
        
        void initAdditionalInfo();
        
        void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}

#endif /* U4DWorldPipeline_hpp */
