//
//  U4DRenderShaderEntity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 7/7/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderShaderEntity_hpp
#define U4DRenderShaderEntity_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DIndex.h"
#include "U4DShaderEntity.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        simd::float2 uv;
        simd::float2 padding;
        
    }AttributeAlignedShaderEntityData;
    
}

namespace U4DEngine {

    /**
     * @ingroup renderingengine
     * @brief The U4DRenderShaderEntity class manages the rendering of all 2D images
     *
     */
    class U4DRenderShaderEntity:public U4DRenderManager {
        
    private:
        
        /**
         * @brief the shader object the class will manage
         */
        U4DShaderEntity *u4dObject;
        
        /**
         * @brief Pointer to the null sampler descriptor used for texturing
         */
        MTLSamplerDescriptor *nullSamplerDescriptor;
        
        /**
         * @brief Uniform for the Shader Entity Property
         */
        id<MTLBuffer> uniformShaderEntityPropertyBuffer;
        
        /**
         * @brief Pointer that represents the texture object
         */
        id<MTLTexture> textureObject[4];
        
        /**
         * @brief Pointer to the Sampler State object
         */
        id<MTLSamplerState> samplerStateObject[4];
        
        /**
         * @brief Pointer to the Sampler descriptor
         */
        MTLSamplerDescriptor *samplerDescriptor[4];
        
    protected:
        
        /**
         * @brief vector for the aligned attribute data. The attributes need to be aligned before they are processed by the GPU
         */
        std::vector<AttributeAlignedShaderEntityData> attributeAlignedContainer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the image entity it will manage
         *
         * @param uU4DShaderEntity image entity
         */
        U4DRenderShaderEntity(U4DShaderEntity *uU4DShaderEntity);
        
        /**
         * @brief Destructor for class
         */
        ~U4DRenderShaderEntity();
        
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
        virtual bool loadMTLBuffer();
        
        /**
         * @brief Loads image texture into GPU
         * @details It decodes the current texture image, creates a texture object, a texture sampler, and loads the raw data into a buffer
         */
        void loadMTLTexture();
        
        /**
         * @brief Updates the space matrix of the entity
         * @details Updates the image space matrix of the entity by computing the world, view and orthogonal space matrix
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
         * @brief It aligns all attribute data
         * @details Aligns vertices and uv. This is necessary when using Metal
         */
        void alignedAttributeData();
        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         * @brief clears all attributes containers
         * @details clears attributes containers such as vertices and UVs
         */
        virtual void clearModelAttributeData();
        
        /**
        * @brief Update the users parameters used in the shader
        */
        void updateShaderEntityParams();
        
        /**
         * @brief Loads additional information for the particle system
         * @details Loads additional particle system properties
         */
        void loadMTLAdditionalInformation();
        
        
        void initTextureSamplerObjectNull();

    };

}
#endif /* U4DRenderShaderEntity_hpp */
