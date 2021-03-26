//
//  U4DCompositionPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 1/22/21.
//  Copyright © 2021 Untold Engine Studios. All rights reserved.
//

#ifndef U4DCompositionPipeline_hpp
#define U4DCompositionPipeline_hpp

#include <stdio.h>
#include "U4DRenderPipeline.h"

namespace U4DEngine{

    class U4DCompositionPipeline: public U4DRenderPipeline{
        
    private:
        
        id<MTLBuffer> quadVerticesBuffer;
        id<MTLBuffer> quadTexCoordsBuffer;
        id<MTLBuffer> uniformSpaceBuffer;
        
        float quadVertices[12]={-1.0,1.0, 1.0,-1.0, -1.0,-1.0, -1.0,1.0, 1.0,1.0, 1.0,-1.0};
        float quadTexCoords[12]={0.0,0.0, 1.0,1.0, 0.0,1.0, 0.0,0.0, 1.0,0.0, 1.0,1.0};
        
    public:
        
        U4DCompositionPipeline(std::string uName);
        
        ~U4DCompositionPipeline();
        
        void initVertexDesc();
        
        void initTargetTexture();
        
        void initPassDesc();
        
        bool buildPipeline();
        
        void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder);
        
    };

}


#endif /* U4DCompositionPipeline_hpp */
