//
//  U4DRenderGeometry.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
//

#ifndef U4DRenderGeometry_hpp
#define U4DRenderGeometry_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"

#include "U4DBoundingVolume.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        
    }AttributeAlignedGeometryData;
    
}

namespace U4DEngine {
    
    class U4DRenderGeometry:public U4DRenderManager {
        
    private:
        
        U4DBoundingVolume *u4dObject;
        
        //uniforms
        id<MTLBuffer> uniformGeometryBuffer;
        
        std::vector<AttributeAlignedGeometryData> attributeAlignedContainer;
        
        U4DVector4n geometryLineColor;
        
    public:
        
        U4DRenderGeometry(U4DBoundingVolume *uU4DGeometricObject);
        
        ~U4DRenderGeometry();
        
        void initMTLRenderLibrary();
        
        void initMTLRenderPipeline();
        
        bool loadMTLBuffer();
        
        void updateSpaceUniforms();
        
        void loadMTLAdditionalInformation();
        
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        void alignedAttributeData();
        
        void setGeometryLineColor(U4DVector4n &uGeometryLineColor);
        
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

#endif /* U4DRenderGeometry_hpp */
