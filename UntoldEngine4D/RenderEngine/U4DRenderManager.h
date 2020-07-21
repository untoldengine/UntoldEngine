//
//  RenderManager.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//

#ifndef RenderManager_hpp
#define RenderManager_hpp

#import <MetalKit/MetalKit.h>

#include <stdio.h>
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DDualQuaternion.h"
#include "U4DQuaternion.h"
#include "U4DIndex.h"
#include <vector>
#include <simd/simd.h>

namespace U4DEngine {

/**
 * @ingroup renderingengine
 * @brief      The U4DRenderManager class manages all rendering for 3D models, images, skyboxes, etc
 */
    class U4DRenderManager {
        
    private:
        
    protected:
        
        /**
         * @brief Pointer representing a Metal Device
         */
        id <MTLDevice> mtlDevice;
        
        /**
         * @brief Pointer representing the state of the render pipeline
         */
        id<MTLRenderPipelineState> mtlRenderPipelineState;

        /**
         * @brief Pointer for the rendering pipeline descriptor
         */
        MTLRenderPipelineDescriptor *mtlRenderPipelineDescriptor;
        
        /**
         * @brief Pointer for the depth stencil state
         */
        id<MTLDepthStencilState> depthStencilState;
        
        /**
         * @brief Pointer that holds the library of shaders
         */
        id<MTLLibrary> mtlLibrary;
        
        /**
         * @brief Pointer to the shader vertex program
         */
        id<MTLFunction> vertexProgram;
        
        /**
         * @brief Pointer to the shader fragment program
         */
        id<MTLFunction> fragmentProgram;
        
        /**
         * @brief Pointer to the vertex descriptors
         */
        MTLVertexDescriptor* vertexDesc;
        
        /**
         * @brief Pointer to the Depth Stencil descriptor
         */
        MTLDepthStencilDescriptor *depthStencilDescriptor;
        
        /**
         * @brief Pointer to the attribute buffer
         */
        id<MTLBuffer> attributeBuffer;
        
        /**
         * @brief Pointer to the index buffer
         */
        id<MTLBuffer> indicesBuffer;
        
        /**
         * @brief Pointer to the Uniform that holds the Space matrix
         */
        id<MTLBuffer> uniformSpaceBuffer;
        
        /**
         * @brief Pointer to the Uniform that holds the several rendering flags
         */
        id<MTLBuffer> uniformModelRenderFlagsBuffer;
        
        /**
         * @brief Pointer that represents the texture object
         */
        id<MTLTexture> textureObject;

        /**
         * @brief Pointer to the Normal Map texture
         */
        id<MTLTexture> normalMapTextureObject;
        
        /**
         * @brief Pointer to the Sampler State object
         */
        id<MTLSamplerState> samplerStateObject;

        /**
         * @brief Pointer to the Normal Map Sampler
         */
        id<MTLSamplerState> samplerNormalMapStateObject;
        
        /**
         * @brief Pointer to the Sampler descriptor
         */
        MTLSamplerDescriptor *samplerDescriptor;
        
        /**
         * @brief Pointer for second Texture object
         */
        id<MTLTexture> secondaryTextureObject;
        
        /**
         * @brief Uniform for the Light Position
         */
        id<MTLBuffer> lightPositionUniform;
        
        /**
         * @brief Pointer to the Uniform that holds Global data such as time, resolution,etc
         */
        id<MTLBuffer> globalDataUniform;
        
        /**
         * @brief Uniform for the light color
         */
        id<MTLBuffer> lightColorUniform;
        
        /**
         * @brief Uniform for the Particle System property
         */
        id<MTLBuffer> uniformParticleSystemPropertyBuffer;
        
        /**
         * @brief Uniform for the Particle Property
         */
        id<MTLBuffer> uniformParticlePropertyBuffer;
        
        /**
         * @brief Uniform for the Shader Entity Property
         */
        id<MTLBuffer> uniformShaderEntityPropertyBuffer;
        
        /**
         * @brief buffer for the raw image data of a texture
         */
        std::vector<unsigned char> rawImageData;

        /**
         * @brief Width of the texture image
         */
        unsigned int imageWidth;

        /**
         * @brief Height of the texture image
         */
        unsigned int imageHeight;
        
        /**
         * @brief Buffer for the skybox raw data
         */
        std::vector<const char*> skyboxTexturesContainer;
        
        /**
         * @brief Variable to determine if object should be rendered
         */
        bool eligibleToRender;
        
        /**
         * @brief Variable to determine if the 3D object is within the frustum
         */
        bool isWithinFrustum;
        
    public:
        
        /**
         * @brief Constructor for the U4DRenderManager
         * @details The constructor initializes the Metal device and sets the descriptors and pipeline states to NULL
         */
        U4DRenderManager();
        
        /**
         * @brief Destructor for the U4DRenderManager   
         * @details Sets all descriptors and pipeline states to NULL
         */
        virtual ~U4DRenderManager();
        
        /**
         * @brief Sends attributes information to the GPU
         * @details It initializes the library and pipeline. It then loads vertices, normals, UV coordinates and animation data into the GPU
         */
        void loadRenderingInformation();

        /**
         * @brief Initializes the library shaders
         * @details It initializes the vertex and fragment shaders for the entity
         */
        virtual void initMTLRenderLibrary(){};
        
        /**
         * @brief Initializes the Rendering Pipeline
         * @details It prepares the rendering descriptor with the appropriate color attachment, depth attachment, shaders and attributes
         */
        virtual void initMTLRenderPipeline(){};
        
        /**
         * @brief Loads the attributes and Uniform data
         * @details It prepares the attribute data so that it is aligned. It then loads the attributes into a buffer. It also loads uniform data into a buffer
         * @return True if loading is successful
         */
        virtual bool loadMTLBuffer(){};
        
        /**
         * @brief Loads image texture into GPU
         * @details It decodes the current texture image, creates a texture object, a texture sampler, and loads the raw data into a buffer
         */
        virtual void loadMTLTexture(){};
        
        /**
         * @brief Loads additional information for different types of entities
         * @details Some entities requires additional information to be sent to the GPU. This methods allows for different information to be sent.
         */
        virtual void loadMTLAdditionalInformation(){}
        
        /**
         * @brief Loads Normal Map raw data
         * @details It decodes the normal map texture data, creates a texture object, a texture sampler, and loads the normal map data into a buffer
         */
        virtual void loadMTLNormalMapTexture(){};
        
        /**
         * @brief Updates the space matrix of the entity
         * @details Updates the model space matrix of the entity by computing the world, view and perspective/orthogonal (depending on entity type) space matrix
         */
        virtual void updateSpaceUniforms(){};
        
        /**
         * @brief Updates the space matrix of the shadow
         * @details Updates the current shadow matrix by computing the current light space projection matrix
         */
        virtual void updateShadowSpaceUniforms(){};
        
        virtual void updateRenderingInformation(){};
        
        virtual void modifyRenderingInformation(){};
        
        /**
         * @brief updates the time, resolution data uniforms
         * @details The time is the time since the game started. The resolution is the resolution of the screen. This method updates the data so the shaders have uptodate information
         */
        void updateGlobalDataUniforms();
        
        /**
         * @brief sets the the uniforms for the time and resolution uniform
         * @details initializes the uniform buffer used to store the time and resolution data
         */
        void loadMTLGlobalDataUniforms();
        
        /**
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         * 
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
        
        /**
         * @brief Renders the shadow for a 3D entity
         * @details Updates the shadow space matrix, any rendering flags. It also sends the attributes and space uniforms to the GPU
         *
         * @param uRenderShadowEncoder Metal encoder object for the current entity
         * @param uShadowTexture Texture shadow for the current entity
         */
        virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){};
        
        /**
         * @brief Creates a texture object to be applied to an entity
         * @details It creates a texture descriptor, and loads texture raw data into a newly created texture object
         */
        virtual void createTextureObject();
        
        /**
         * @brief Creates a sampler object required for texturing
         * @details Creates a sampler descriptor and sets the filtering and addressing settings. Loads the sampler descriptor into a newly created sampler object.
         */
        void createSamplerObject();
        
        virtual void createSecondaryTextureObject(){};
        
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
        
        /**
         * @brief Set line color for geometric entities
         * @details Geometric entities such as cubes, spheres etc are rendered only with lines. This method sets the particular color.
         * 
         * @param uGeometryLineColor Vector denoting the desired color
         */
        virtual void setGeometryLineColor(U4DVector4n &uGeometryLineColor){};
        
        /**
         * @brief Decodes the image texture
         * @details Decodes the texture using the lodepng library. It flips and inverts the image.
         * 
         * @param uTexture The image representing the texture
         */
        void decodeImage(std::string uTexture);
        
        /**
         * @brief Decodes the image texture
         * @details Decodes the texture using the lodepng library. It flips and inverts the image.
         * 
         * @param uTexture The image representing the texture
         * @return Buffer containing the raw image data
         */
        std::vector<unsigned char> decodeImage(const char *uTexture);
        
        /**
         * @brief Clear the raw image data
         * @details Clears the decode image data used for texturing
         */
        void clearRawImageData();
        
        /**
         * @brief Clears the attribute container
         * @details clears vertices, normals, uv, tangent,materials, bone and vertex weights containers
         */
        virtual void clearModelAttributeData(){};
        
        /**
         * @brief Initializes texture sampler object to null
         * @details It initializes the sampler object to null. The object is later used to store sampler settings
         */
        virtual void initTextureSamplerObjectNull(){};
        
        /**
         * @brief Sets the texture0 image for the image
         * @details It sets the texture that will be decoded into raw data and loaded into the texture buffer
         *
         * @param uTexture texture name
         */
        virtual void setTexture0(const char* uTexture){};
        
        /**
         * @brief Sets the texture image1 for the image
         * @details It sets the texture that will be decoded into raw data and loaded into the texture buffer
         *
         * @param uTexture texture name
         */
        virtual void setTexture1(const char* uTexture){};
        
        /**
         * @brief Loads textures into skybox container
         * @details Loads all six textures into the skybox container
         * 
         * @param uTextures Skybox textures
         */
        void addTexturesToSkyboxContainer(const char* uTextures);
        
        /**
         * @brief Returns skybox textures
         * @details Returns a vector containing all six skybox textures
         * @return skybox textures
         */
        std::vector<const char*> getSkyboxTexturesContainer();

        
        /**
         @brief Method which returns the absolute space of the entity
         
         @return Returns the entity absolure space-Orientation and Position
         */
        virtual U4DDualQuaternion getEntitySpace(){};
        
        /**
         @brief Method which returns the local space of the entity
         
         @return Returns the entity local space-Orientation and Position
         */
        virtual U4DDualQuaternion getEntityLocalSpace(){};
        
        /**
         @brief Method which returns the absolute position of the entity
         
         @return Returns the entity absolute position
         */
        virtual U4DVector3n getEntityAbsolutePosition(){};
        
        /**
         @brief Method which returns the local position of the entity
         
         @return Returns the entity local position
         */
        virtual U4DVector3n getEntityLocalPosition(){};

        /**
         * @brief Converts 4x4 matrix to SIMD format
         * @details Converts 4x4 matrix to SIMD format used by the GPU shaders
         * 
         * @param uMatrix 3x3 Matrix
         * @return Matrix in SIMD format
         */
        matrix_float4x4 convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix);
        
        /**
         * @brief Converts 3x3 matrix to SIMD format
         * @details Converts 3x3 matrix to SIMD format used by the GPU shaders
         * 
         * @param uMatrix 3x3 Matrix    
         * @return Matrix in SIMD format
         */
        matrix_float3x3 convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix);
        
        /**
         * @brief Converts vector of 4 dimensions into SIMD format
         * @details Converts vector of 4n dimentsions into SIMD format
         * 
         * @param uVector 4n vector dimension
         * @return vector in SIMD format
         */
        vector_float4 convertToSIMD(U4DEngine::U4DVector4n &uVector);
        
        /**
         * @brief Converts vector of 3 dimensions into SIMD format
         * @details Converts vector of 3n dimentsions into SIMD format
         * 
         * @param uVector 3n vector dimension
         * @return vector in SIMD format
         */
        vector_float3 convertToSIMD(U4DEngine::U4DVector3n &uVector);
        
        /**
         * @brief Converts vector of 2 dimensions into SIMD format
         * @details Converts vector of 2n dimentsions into SIMD format
         * 
         * @param uVector 2n vector dimension
         * @return vector in SIMD format
         */
        vector_float2 convertToSIMD(U4DEngine::U4DVector2n &uVector);
        
        /**
         * @brief Sets property used to determine if entity is within frustum
         * @details If the property is set, the entity is rendered, else is ignored
         * 
         * @param uValue true for is within the frustum, false if is not
         */
        void setIsWithinFrustum(bool uValue);
        
        virtual void setRawImageData(std::vector<unsigned char> uRawImageData){};
        
        virtual void setImageWidth(unsigned int uImageWidth){};
        
        virtual void setImageHeight(unsigned int uImageHeight){};
        
    };
    
}

#endif /* RenderManager_hpp */
