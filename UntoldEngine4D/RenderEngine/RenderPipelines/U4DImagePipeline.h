//
//  U4DImagePipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/5/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DImagePipeline_hpp
#define U4DImagePipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"
#include "U4DRenderEntity.h"

namespace U4DEngine {

    class U4DImagePipeline: public U4DRenderPipeline {
        
    private:
        
        
        
    public:
        
        U4DImagePipeline(std::string uName);
        
        ~U4DImagePipeline();
        
        void initTargetTexture();
        
        void initVertexDesc();

        void initPassDesc();
        
        bool buildPipeline();
        
        void initAdditionalInfo();
        
        void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}
#endif /* U4DImagePipeline_hpp */
