//
//  U4DRender3DModel.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRender3DModel_hpp
#define U4DRender3DModel_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include <vector>
#include <simd/simd.h>
#include "U4DModel.h"
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
        simd::float4 normal;
        simd::float4 uv; //making it a float4 for padding memory alignment
        simd::float4 tangent;
        simd::float4 materialIndex;
        simd::float4 vertexWeight;
        simd::float4 boneIndex;
        
    }AttributeAlignedModelData;

}


namespace U4DEngine {

    class U4DRender3DModel:public U4DRenderManager {
        
    private:
        
        U4DModel *u4dObject;
        
        U4DMatrix4n lightShadowProjectionSpace;
        
        id<MTLTexture> shadowTexture;
        
        //uniforms
        id<MTLBuffer> uniformMaterialBuffer;
        
        id<MTLBuffer> uniformBoneBuffer;
        
        std::vector<AttributeAlignedModelData> attributeAlignedContainer;
        
    public:
        
        U4DRender3DModel(U4DModel *uU4DModel);
        
        ~U4DRender3DModel();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void loadMTLTexture();
        
        void loadMTLAdditionalInformation();
        
        void loadMTLNormalMapTexture();
        
        void loadMTLMaterialInformation();
        
        void updateSpaceUniforms();
        
        void updateShadowSpaceUniforms();
        
        void updateBoneSpaceUniforms();
        
        void updateModelRenderFlags();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture);
        
        void initTextureSamplerObjectNull();
        
        void alignedAttributeData();
        
        void clearModelAttributeData();
        
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



#endif /* U4DRender3DModel_hpp */
