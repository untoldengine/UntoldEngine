//
//  U4DRenderParticleSystem.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 10/9/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderParticleSystem_hpp
#define U4DRenderParticleSystem_hpp

#include <stdio.h>
#include "U4DRenderManager.h"
#include <vector>
#include <simd/simd.h>
#include "U4DParticleSystem.h"
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
    
    /**
     * @ingroup renderingengine
     * @brief The U4DRenderParticleSystem class manages the rendering of particles used in the particle system
     */
    class U4DRenderParticleSystem:public U4DRenderManager {
        
    private:
        
        /**
         * @brief The particle system the class will manage
         */
        U4DParticleSystem *u4dObject;
        
        /**
         * @brief Vector containing the aligned attribute data
         * @details It contains aligned vertices and UVs
         */
        std::vector<AttributeAlignedParticleData> attributeAlignedContainer;
        
        /**
         * @brief Pointer to the null sampler descriptor used for texturing
         */
        MTLSamplerDescriptor *nullSamplerDescriptor;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details sets the particle system entity the class will manage
         * 
         * @param uU4DParticleSystem Particle system entity
         */
        U4DRenderParticleSystem(U4DParticleSystem *uU4DParticleSystem);
        
        /**
         * @brief Destructor for class
         * @details releases the null sampler descriptor
         */
        ~U4DRenderParticleSystem();
        
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
         * @details It decodes the current texture image, creates a texture object, a texture sampler, and loads the raw data into a buffer
         */
        void loadMTLTexture();
        
        /**
         * @brief Loads additional information for the particle system
         * @details Loads additional particle system properties
         */
        void loadMTLAdditionalInformation();
        
        /**
         * @brief Loads particle properties
         * @details Loads the max number of particles to render
         */
        void loadParticlePropertiesInformation();
        
        /**
         * @brief Loads particle system properties
         * @details Loads properties used by the particle system such as textures to use, noise, etc
         */
        void loadParticleSystemPropertiesInformation();
    
        /**
         * @brief Updates the space matrix of the entity
         * @details Updates the model space matrix of the entity by computing the world, view and perspective space matrix
         */
        void updateSpaceUniforms();
        
        /**
         * @brief Updates the particle properties
         * @details Updates the color of the particles
         */
        void updateParticlePropertiesInformation();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix and any rendering flags. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Aligns the attribute data
         * @details Aligns the vertices and uv data. This is necessary to render in Metal
         */
        void alignedAttributeData();
        
        /**
         * @brief Clears the attribute container
         * @details clears vertices and uv containers
         */
        void clearModelAttributeData();
        
        /**
         * @brief Set texture sampler to NULL
         * @details Creates a texture and sampler object and initializes to NULL
         */
        void initTextureSamplerObjectNull();
        
        /**
         * @brief Sets the diffuse texture data
         * @details The diffuse texture is the main texture used for entities
         * 
         * @param uTexture Diffuse texture
         */
        void setDiffuseTexture(const char* uTexture);
        
        /**
         @brief Gets the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        U4DDualQuaternion getEntitySpace();
        
        /**
         @brief Gets the local space of the entity
         
         @return Returns the entity local space-Orientation and Position
         */
        U4DDualQuaternion getEntityLocalSpace();
        
        /**
         @brief Gets the absolute position of the entity
         
         @return Returns the entity absolute position
         */
        U4DVector3n getEntityAbsolutePosition();
        
        /**
         @brief Gets the local position of the entity
         
         @return Returns the entity local position
         */
        U4DVector3n getEntityLocalPosition();
        
        void setRawImageData(std::vector<unsigned char> uRawImageData);
        
        void setImageWidth(unsigned int uImageWidth);
        
        void setImageHeight(unsigned int uImageHeight);
        
        
    };
    
}
#endif /* U4DRenderParticleSystem_hpp */
