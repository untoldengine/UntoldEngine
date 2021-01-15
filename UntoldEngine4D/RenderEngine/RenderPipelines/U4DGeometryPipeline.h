//
//  U4DGeometryPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DGeometryPipeline_hpp
#define U4DGeometryPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"

namespace U4DEngine {

    class U4DGeometryPipeline: public U4DRenderPipeline {
    
    private:
        
    public:
        
        U4DGeometryPipeline(id <MTLDevice> uMTLDevice, std::string uName);
        
        ~U4DGeometryPipeline();
        
        void initRenderPassTargetTexture();
        
        void initVertexDesc();

        void initRenderPassDesc();
        
        void initRenderPassPipeline();
        
        void initRenderPassAdditionalInfo();
        
        void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity);
        
    };

}


#endif /* U4DGeometryPipeline_hpp */
