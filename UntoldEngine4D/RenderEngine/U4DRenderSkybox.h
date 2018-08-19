//
//  U4DRenderSkybox.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/12/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderSkybox_hpp
#define U4DRenderSkybox_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DSkybox.h"


namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        
    }AttributeAlignedSkyboxData;
    
}

namespace U4DEngine {
    
    class U4DRenderSkybox:public U4DRenderManager {
        
    private:
        
        U4DSkybox *u4dObject;
        
        //Texture object
        id<MTLTexture> textureSkyboxObject[6];
        
        std::vector<AttributeAlignedSkyboxData> attributeAlignedContainer;
        
    public:
        
        U4DRenderSkybox(U4DSkybox *uU4DSkybox);
        
        ~U4DRenderSkybox();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void loadMTLTexture();
        
        void updateSpaceUniforms();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void createTextureObject();
        
        void alignedAttributeData();
        
        void setDiffuseTexture(const char* uTexture);
        
        void clearModelAttributeData();
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
    };
    
}
#endif /* U4DRenderSkybox_hpp */
