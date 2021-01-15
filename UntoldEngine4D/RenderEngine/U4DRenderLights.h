//
//  U4DRenderLights.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/11/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderLights_hpp
#define U4DRenderLights_hpp

#include <stdio.h>
#include "U4DRenderEntity.h"
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
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderLights class manages the rendering of the light entity. Note, it wiil simply render a sphere.
     */
    class U4DRenderLights:public U4DRenderEntity {
        
    private:
        
        /**
         * @brief The light entity the class will manage
         */
        U4DLights *u4dObject;
        
        /**
         * @brief Vector containing the aligned attributes
         * @details It contains aligned vertices
         */
        std::vector<AttributeAlignedLightData> attributeAlignedContainer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the light entity it will manage
         * 
         * @param uU4DLights light entity
         */
        U4DRenderLights(U4DLights *uU4DLights);
        
        /**
         * @brief Destructor for class
         */
        ~U4DRenderLights();
        
        /**
         @brief Returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         * @brief Loads the attributes and Uniform data
         * @details It prepares the attribute data so that it is aligned. It then loads the attributes into a buffer. It also loads uniform data into a buffer
         * @return True if loading is successful
         */
        bool loadMTLBuffer();
        
        /**
         * @brief Updates the space matrix of the entity
         * @details Updates the model space matrix of the entity by computing the world, view and perspective space matrix
         */
        void updateSpaceUniforms();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Aligns the attribute data
         * @details aligns the vertices before sending them to the GPU
         */
        void alignedAttributeData();
        
        /**
         * @brief Clears the attribute container
         * @details clears vertices containers
         */
        void clearModelAttributeData();
        
    };
    
}

#endif /* U4DRenderLights_hpp */
