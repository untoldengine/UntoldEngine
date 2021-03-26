//
//  U4DModelPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DModelPipeline_hpp
#define U4DModelPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"
#include "U4DRenderEntity.h"

namespace U4DEngine {

    class U4DModelPipeline: public U4DRenderPipeline {
        
    private:
        
    public:
        
        U4DModelPipeline(std::string uName);
        
        ~U4DModelPipeline();
        
        void initTargetTexture();
        
        void initVertexDesc();

        void initPassDesc();
        
        bool buildPipeline();
        
        void initAdditionalInfo();
        
        void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}


#endif /* U4DModelPipeline_hpp */
