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

typedef struct{
    
    uint32_t offset=0.0;

    uint8_t index=0;

    void* address;
    
}TRIPLEBUFFER;

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
         * @brief Pointer representing the state of the offscreen render pipeline
         */
        id<MTLRenderPipelineState> mtlOffscreenRenderPipelineState;

        /**
         * @brief Pointer for the rendering pipeline descriptor
         */
        MTLRenderPipelineDescriptor *mtlRenderPipelineDescriptor;
        
        
        /**
         @todo document this
         */
        MTLRenderPipelineDescriptor *mtlOffscreenRenderPipelineDescriptor;
        
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
         * @brief Pointer that holds the library of offscreen shaders
         */
        id<MTLLibrary> mtlOffscreenRenderLibrary;
        
        /**
         * @brief Pointer to the shader vertex program for offscreen rendering
         */
        id<MTLFunction> vertexOffscreenProgram;
        
        /**
         * @brief Pointer to the shader fragment program for offscreen rendering
         */
        id<MTLFunction> fragmentOffscreenProgram;
        
        
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
         * @brief Pointer to the Uniform that holds Global data such as time, resolution,etc
         */
        id<MTLBuffer> globalDataUniform;
        
        /**
         * @brief Variable to determine if object should be rendered
         */
        bool eligibleToRender;
        
        /**
         * @brief Variable to determine if the 3D object is within the frustum
         */
        bool isWithinFrustum;
        
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
         @todo document this
         */
        virtual void initMTLOffscreenRenderLibrary(){};
        
        /**
         @todo document this
         */
        virtual void initMTLOffscreenRenderPipeline(){};
        
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
         * @brief Updates the space matrix of the entity
         * @details Updates the model space matrix of the entity by computing the world, view and perspective/orthogonal (depending on entity type) space matrix
         */
        virtual void updateSpaceUniforms(){};
        
        /**
         @todo document this
         */
        virtual void updateAllUniforms(){};
        
        /**
         * @brief Updates the space matrix of the shadow
         * @details Updates the current shadow matrix by computing the current light space projection matrix
         */
    
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
         @todo document this
         */
        virtual void renderOffscreen(id <MTLRenderCommandEncoder> uRenderOffscreenEncoder, id<MTLTexture> uOffscreenTexture){};
        
        /**
         * @brief Creates a texture object to be applied to an entity
         * @details It creates a texture descriptor, and loads texture raw data into a newly created texture object
         */
        virtual void createTextureObject(id<MTLTexture> &uTextureObject);
        
        /**
         * @brief Creates a sampler object required for texturing
         * @details Creates a sampler descriptor and sets the filtering and addressing settings. Loads the sampler descriptor into a newly created sampler object.
         */
        void createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor);
        
        /**
         * @brief Set line color for geometric entities
         * @details Geometric entities such as cubes, spheres etc are rendered only with lines. This method sets the particular color.
         * 
         * @param uGeometryLineColor Vector denoting the desired color
         */
        virtual void setGeometryLineColor(U4DVector4n &uGeometryLineColor){};
        
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
         * @brief Sets property used to determine if entity is within frustum
         * @details If the property is set, the entity is rendered, else is ignored
         * 
         * @param uValue true for is within the frustum, false if is not
         */
        void setIsWithinFrustum(bool uValue);
        
        void setRawImageData(std::vector<unsigned char> uRawImageData);
        
        void setImageWidth(unsigned int uImageWidth);
        
        void setImageHeight(unsigned int uImageHeight);
        
        bool createTextureAndSamplerObjects(id<MTLTexture> &uTextureObject, id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor, std::string uTextureName);
        
        virtual void hotReloadShaders(std::string uFilepath){};
        
        
    };
    
}

#endif /* RenderManager_hpp */
