//
//  U4DRenderLights.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/11/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRenderLights_hpp
#define U4DRenderLights_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"

#include "U4DLights.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        
    }AttributeAlignedLightData;
    
}

namespace U4DEngine {
    
    class U4DRenderLights:public U4DRenderManager {
        
    private:
        
        U4DLights *u4dObject;
        
        std::vector<AttributeAlignedLightData> attributeAlignedContainer;
        
    public:
        
        U4DRenderLights(U4DLights *uU4DLights);
        
        ~U4DRenderLights();
        
        U4DDualQuaternion getEntitySpace();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void updateSpaceUniforms();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void alignedAttributeData();
        
    };
    
}

#endif /* U4DRenderLights_hpp */
