//
//  U4DRenderImage.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
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

#include "U4DLogger.h"

namespace U4DEngine {
    
    typedef struct{
        
        simd::float4 position;
        simd::float2 uv;
        simd::float2 padding;
        
    }AttributeAlignedImageData;
    
}

namespace U4DEngine {

    /**
     * @ingroup renderingengine
     * @brief The U4DRenderImage class manages the rendering of all 2D images 
     * 
     */
    class U4DRenderImage:public U4DRenderManager {
        
    private:
        
        /**
         * @brief the image object the class will manage
         */
        U4DImage *u4dObject;
        
    protected:
        
        /**
         * @brief vector for the aligned attribute data. The attributes need to be aligned before they are processed by the GPU
         */
        std::vector<AttributeAlignedImageData> attributeAlignedContainer;
        
        /**
         * @brief Pointer to the null sampler descriptor used for texturing
         */
        MTLSamplerDescriptor *nullSamplerDescriptor;
        
        /**
         * @brief Pointer that represents the texture object
         */
        id<MTLTexture> textureObject;
        
        /**
         * @brief Pointer to the Sampler State object
         */
        id<MTLSamplerState> samplerStateObject;
        
        /**
         * @brief Pointer to the Sampler descriptor
         */
        MTLSamplerDescriptor *samplerDescriptor;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It sets the image entity it will manage
         * 
         * @param uU4DImage image entity
         */
        U4DRenderImage(U4DImage *uU4DImage);
        
        /**
         * @brief Destructor for class
         */
        ~U4DRenderImage();
        
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
         * @brief Set texture sampler to NULL
         * @details Creates a texture and sampler object and initializes to NULL
         */
        void initTextureSamplerObjectNull();

    };

}



#endif /* U4DRenderImage_hpp */
