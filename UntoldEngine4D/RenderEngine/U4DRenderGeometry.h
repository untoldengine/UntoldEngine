//
//  U4DRenderGeometry.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/13/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderGeometry_hpp
#define U4DRenderGeometry_hpp

#include <stdio.h>
#include "U4DRenderEntity.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"

#include "U4DMesh.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        
    }AttributeAlignedGeometryData;
    
}

namespace U4DEngine {
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderGeometry manages the rendering of geometric entities such as cubes, spheres, etc
     */
    class U4DRenderGeometry:public U4DRenderEntity {
        
    private:
        
        /**
         * @brief The bounding volume entity the class will manage
         */
        U4DMesh *u4dObject;
        
    protected:
        
        /**
         * @brief pointer to the buffer that holds the geometry properties, as as line color
         */
        id<MTLBuffer> uniformGeometryBuffer;
        
        /**
         * @brief vector that holds the aligned attributes
         */
        std::vector<AttributeAlignedGeometryData> attributeAlignedContainer;
        
        /**
         * @brief Color lines for the geometry. The engine will use this color to render the lines of the geometry
         */
        U4DVector4n geometryLineColor;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details Sets the bounding volume the class will manate
         */
        U4DRenderGeometry(U4DMesh *uU4DGeometricObject);
        
        /**
         * @brief Destructor for the class
         */
        ~U4DRenderGeometry();
        
        
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
         * @brief Loads additional information into buffer
         * @details loads the color of the geometrical shape
         */
        void loadMTLAdditionalInformation();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Updates the geometry rendering data
         * @details This method is called by the geometry U4DMesh class whenever the data changes
         */
        void updateRenderingInformation();
        
        /**
         * @brief Modifies geometry rendering data if required
         * @details This method is called by the U4DMesh class. If the attribute container size changes, it loads a new set of attributes.
         */
        void modifyRenderingInformation();
        
        /**
         * @brief Aligns attribute data
         * @details Aligns the vertices before sending them to the GPU
         */
        void alignedAttributeData();
        
        /**
         * @brief Sets the color for the geometry
         * @details Sets the line color used for rendering the geometrical figure
         * 
         * @param uGeometryLineColor line color
         */
        void setGeometryLineColor(U4DVector4n &uGeometryLineColor);
        
        /**
         * @brief Clears the attribute container
         * @details clears vertices containers
         */
        void clearModelAttributeData();
        
        
    };
    
}

#endif /* U4DRenderGeometry_hpp */
