//
//  U4DRenderWorld.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRenderWorld_hpp
#define U4DRenderWorld_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DDualQuaternion.h"
#include "U4DQuaternion.h"

#include "U4DWorld.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        
    }AttributeAlignedWorldData;
    
}

namespace U4DEngine {
    
    class U4DRenderWorld:public U4DRenderManager {
        
    private:
        
        U4DWorld *u4dObject;
        
        std::vector<AttributeAlignedWorldData> attributeAlignedContainer;
        
    public:
        
        U4DRenderWorld(U4DWorld *uU4DWorld);
        
        ~U4DRenderWorld();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        void loadMTLBuffer();
        
        void updateSpaceUniforms();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void alignedAttributeData();
        
        U4DDualQuaternion getEntitySpace();
    };
    
}

#endif /* U4DRenderWorld_hpp */
