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
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderSkybox class manages the rendering of the skybox entity
     * 
     */
    class U4DRenderSkybox:public U4DRenderManager {
        
    private:
        
        /**
         * @brief the skybox entity the class will manage
         */
        U4DSkybox *u4dObject;
        
        /**
         * @brief Pointer to the uniform buffer that holds all 6 textures for the skybox         
         */
        id<MTLTexture> textureSkyboxObject[6];
        
        /**
         * @brief vector for the aligned attribute data. The attributes need to be aligned before they are processed by the GPU
         */
        std::vector<AttributeAlignedSkyboxData> attributeAlignedContainer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the skybox entity it will manage
         */
        U4DRenderSkybox(U4DSkybox *uU4DSkybox);
        
        /**
         * @brief Destructor for class
         */
        ~U4DRenderSkybox();
        
        /**
         * @brief Initializes the library shaders
         * @details It initializes the vertex and fragment shaders for the entity
         */
        void initMTLRenderLibrary();
        
        /**
         * @brief Initializes the Rendering Pipeline
         * @details It prepares the rendering descriptor with the appropriate color attachment, depth attachment, shaders and attributes
         */
        void initMTLRenderPipeline();
        
        /**
         * @brief Loads the attributes and Uniform data
         * @details It prepares the attribute data so that it is aligned. It then loads the attributes into a buffer. It also loads uniform data into a buffer
         * @return True if loading is successful
         */
        bool loadMTLBuffer();
        
        /**
         * @brief Loads image texture into GPU
         * @details It creates a texture object, a texture sampler, and loads the raw data into a buffer for all 6 textures
         */
        void loadMTLTexture();
        
        /**
         * @brief Updates the space matrix of the entity
         * @details Updates the image space matrix of the entity by computing the world, view and perspective space matrix
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
         * @brief Creates the texture object for the skybox
         * @details It computes the size of the skybox and creates a texture object for the skybox
         */
        void createTextureObject();
        
        /**
         * @brief It aligns all attribute data
         * @details Aligns vertices and uv. This is necessary when using Metal
         */
        void alignedAttributeData();
        
        /**
         * @brief Sets the texture image for the image
         * @details It sets the texture that will be decoded into raw data and loaded into the texture buffer
         *
         * @param uTexture texture name
         */
        void setTexture0(const char* uTexture);
        
        /**
         * @brief clears all attributes containers
         * @details clears attributes containers such as vertices and UVs
         */
        void clearModelAttributeData();
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        
    };
    
}
#endif /* U4DRenderSkybox_hpp */
