//
//  U4DRenderImage.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRenderImage_hpp
#define U4DRenderImage_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DImage.h"


namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        simd::float2 uv;
        simd::float2 padding;
        
    }AttributeAlignedImageData;
    
}

namespace U4DEngine {

    class U4DRenderImage:public U4DRenderManager {
        
    private:
        
        U4DImage *u4dObject;
        
        std::vector<AttributeAlignedImageData> attributeAlignedContainer;
        
    public:
        
        U4DRenderImage(U4DImage *uU4DImage);
        
        ~U4DRenderImage();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void loadMTLTexture();
        
        void updateSpaceUniforms();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void alignedAttributeData();
        
        void setImageDimension(float uWidth,float uHeight);
        
        void setDiffuseTexture(const char* uTexture);
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        void clearModelAttributeData();

    };

}



#endif /* U4DRenderImage_hpp */
