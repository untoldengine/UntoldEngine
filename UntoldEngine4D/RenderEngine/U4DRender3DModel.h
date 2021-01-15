//
//  U4DRender3DModel.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 7/4/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRender3DModel_hpp
#define U4DRender3DModel_hpp

#include <stdio.h>
#include "U4DRenderEntity.h"
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

    /**
     * @ingroup renderingengine
     * @brief The U4DRender3DModel class manages the rendering of 3D models
     * @details It manages the rendering of all 3D models such as game characters. It also manages shadows and animation rendering.
     * 
     */
    class U4DRender3DModel:public U4DRenderEntity {
        
    private:
        
        /**
         * @brief The 3D model pointer the class will manage
         */
        U4DModel *u4dObject;
        
        
        
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
        
        /**
         * @brief pointer to the material information buffer, such as diffuse, specular colors and intensities.
         */
        id<MTLBuffer> uniformMaterialBuffer;
        
        /**
         * @brief pointer to the bone buffer used for 3D animations
         */
        id<MTLBuffer> uniformBoneBuffer;
        
        /**
         * @brief Null sampler descriptor. This is used during the initialization.
         */
        MTLSamplerDescriptor *nullSamplerDescriptor;
        
        /**
         * @brief vector for the aligned attribute data. The attributes need to be aligned before they are processed by the GPU
         */
        std::vector<AttributeAlignedModelData> attributeAlignedContainer;
        
        /**
         * @brief Pointer to the Uniform that holds the several rendering flags
         */
        id<MTLBuffer> uniformModelRenderFlagsBuffer;

        /**
         * @brief Pointer to the Normal Map texture
         */
        id<MTLTexture> normalMapTextureObject;
        
        /**
         * @brief Pointer to the Normal Map Sampler
         */
        id<MTLSamplerState> samplerNormalMapStateObject;
        
        /**
        * @brief Pointer to the Normal Map Sampler descriptor
        */
        MTLSamplerDescriptor *normalSamplerDescriptor;
        
        

        /**
         @brief Uniform for the model user-defined parameters
         */
        id<MTLBuffer> uniformModelShaderParametersBuffer;
        
        
        
        //variables for triple buffering
        
        TRIPLEBUFFER spaceTripleBuffer;
        
        TRIPLEBUFFER shadowTripleBuffer;
        
        TRIPLEBUFFER boneTripleBuffer;
        
    public:
        
        /**
         * @brief Constructor for class
         * @details It initializes the buffers and textures used for rendering
         * 
         * @param uU4DModel 3D entity which will be managed by the class
         */
        U4DRender3DModel(U4DModel *uU4DModel);
        
        /**
         * @brief class destructor
         * @details It releases the bone buffer, shadow buffer and sampler descriptor.
         */
        ~U4DRender3DModel();
        
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
         * @brief Loads additional information for the 3D model
         * @details It loads Normal Map texture, material and light information
         */
        void loadMTLAdditionalInformation();
        
        /**
         * @brief Loads Normal Map raw data
         * @details It decodes the normal map texture data, creates a texture object, a texture sampler, and loads the normal map data into a buffer
         */
        void loadMTLNormalMapTexture();
        
        /**
         * @brief Loads material information for rendering into the GPU
         * @details It loads information about the diffuse and specular material. As well, as their intensity. This information is used for lighting
         */
        void loadMTLMaterialInformation();
        
        
        /**
         * @brief Updates the space matrix of the 3D entity
         * @details It updates the space matrix of the entity by using the current world and camera space matrix
         */
        void updateSpaceUniforms();
        
        
        
        /**
         * @brief Updates the space matrix of each bone used in animation
         * @details It accesses the entity's armature and updates each bone space matrix
         */
        void updateBoneSpaceUniforms();
        
        /**
         * @brief Updates the rendering flags for the 3D model
         * @details It updates flags such as if shadows, normal map texturing, armatures should be enabled or disabled
         */
        void updateModelRenderFlags();
        
        /**
         @todo document this
         */
        void updateAllUniforms();
        
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        void render(id <MTLRenderCommandEncoder> uRenderEncoder);
        
        /**
         * @brief Initializes a null texture sampler object
         * @details It creates a null texture object, null normal map texture object, null shadow texture object and a null sampler object
         */
        void initTextureSamplerObjectNull();
        
        /**
         * @brief It aligns all attribute data
         * @details Aligns vertices, normal vectors, uv, tangent, material data, vertex weights and bone indices. This is necessary when using Metal
         */
        void alignedAttributeData();
        
        /**
         * @brief clears all attributes containers
         * @details clears attributes containers such as vertices, normal maps, uv, tangent, material data, vertex weights and bones
         */
        void clearModelAttributeData();
        
        /**
        * @brief Update the users parameters used in the shader
        */
        void updateModelShaderParametersUniform();
        
        /**
         * @brief Creates a Normal Map Texture
         * @details Creates a texture descriptor and a texture object. Copies the Normal Map raw image data into the texture object.
         */
        void createNormalMapTextureObject();
        
        /**
         * @brief Creates a Normal Map Sampler
         * @details Creates a sampler descriptor, sets the filtering and addressing setting and creates a sampler object using the sampler descriptor
         */
        void createNormalMapSamplerObject();
        
    };

}



#endif /* U4DRender3DModel_hpp */
