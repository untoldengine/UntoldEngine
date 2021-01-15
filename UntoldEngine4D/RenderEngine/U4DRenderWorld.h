//
//  U4DRenderWorld.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderWorld_hpp
#define U4DRenderWorld_hpp

#include <stdio.h>
#include "U4DRenderEntity.h"
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
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderWorld class manages the rendering of the world entity. It mainly renders the grid lines
     */
    class U4DRenderWorld:public U4DRenderEntity {
        
    private:
        
        /**
         * @brief the world entity the class will manage
         */
        U4DWorld *u4dObject;
        
        /**
         * @brief Vector containing the aligned attribute data
         * @details It contains the aligned vertices. The alignment is necessary in Metal
         */
        std::vector<AttributeAlignedWorldData> attributeAlignedContainer;
        
        /**
         * @brief The number of vertices to create a grid
         */
        int gridVertexCount;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details Sets the world entity it will manage
         */
        U4DRenderWorld(U4DWorld *uU4DWorld);
        
        /**
         * @brief Desctructor for class
         */
        ~U4DRenderWorld();
        
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
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Aligns the attribute data
         * @details It aligns the vertices before sending them to the GPU
         */
        void alignedAttributeData();
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolute space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         * @brief Clears the attribute container
         * @details clears vertices containers
         */
        void clearModelAttributeData();
    };
    
}

#endif /* U4DRenderWorld_hpp */
