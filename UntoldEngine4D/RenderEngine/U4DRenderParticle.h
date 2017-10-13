//
//  U4DRenderParticle.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/9/17.
//  Copyright © 2017 Untold Game Studio. All rights reserved.
//

#ifndef U4DRenderParticle_hpp
#define U4DRenderParticle_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include <vector>
#include <simd/simd.h>
#include "U4DParticle.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DDualQuaternion.h"
#include "U4DQuaternion.h"

#include "U4DLogger.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        simd::float4 uv; //making it a float4 for padding memory alignment
        
    }AttributeAlignedParticleData;
    
}


namespace U4DEngine {
    
    class U4DRenderParticle:public U4DRenderManager {
        
    private:
        
        U4DParticle *u4dObject;
        
        std::vector<AttributeAlignedParticleData> attributeAlignedContainer;
        
    public:
        
        U4DRenderParticle(U4DParticle *uU4DParticle);
        
        ~U4DRenderParticle();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void loadMTLTexture();
        
        void loadMTLAdditionalInformation();
        
        void loadParticleInstancePropertiesInformation();
        
        void loadParticlePropertiesInformation();
        
        void loadParticleAnimationInformation();
        
        void updateParticleAnimationTime();
        
        void updateSpaceUniforms();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void alignedAttributeData();
        
        void clearModelAttributeData();
        
        void initTextureSamplerObjectNull();
        
        void clearParticleData();
        
        void setDiffuseTexture(const char* uTexture);
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         @brief Method which returns the local space of the entity
         
         @return Returns the entity local space-Orientation and Position
         */
        U4DDualQuaternion getEntityLocalSpace();
        
        /**
         @brief Method which returns the absolute position of the entity
         
         @return Returns the entity absolute position
         */
        U4DVector3n getEntityAbsolutePosition();
        
        /**
         @brief Method which returns the local position of the entity
         
         @return Returns the entity local position
         */
        U4DVector3n getEntityLocalPosition();
        
        
    };
    
}
#endif /* U4DRenderParticle_hpp */
