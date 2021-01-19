//
//  U4DRenderEntity.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderEntity_hpp
#define U4DRenderEntity_hpp

#import <MetalKit/MetalKit.h>

#include <stdio.h>
#include <map>
#include "U4DMatrix4n.h"
#include "U4DVector3n.h"
#include "U4DVector4n.h"
#include "U4DVector2n.h"
#include "U4DDualQuaternion.h"
#include "U4DQuaternion.h"
#include "U4DIndex.h"
#include "U4DRenderPipelineinterface.h"
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
 * @brief      The U4DRenderEntity class manages all rendering for 3D models, images, skyboxes, etc
 */
    class U4DRenderEntity {
        
    private:
        
    protected:
        
        /**
         * @brief Pointer representing a Metal Device
         */
        id <MTLDevice> mtlDevice;
        
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
        
        std::map<int, U4DRenderPipelineInterface*> renderPassPipelineMap;
        
    public:
        
        /**
         * @brief Constructor for the U4DRenderEntity
         * @details The constructor initializes the Metal device and sets the descriptors and pipeline states to NULL
         */
        U4DRenderEntity();
        
        /**
         * @brief Destructor for the U4DRenderEntity
         * @details Sets all descriptors and pipeline states to NULL
         */
        virtual ~U4DRenderEntity();
        
        
        
        /**
         * @brief Sends attributes information to the GPU
         * @details It initializes the library and pipeline. It then loads vertices, normals, UV coordinates and animation data into the GPU
         */
        void loadRenderingInformation();
        
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
         * @brief Renders the current entity
         * @details Updates the space matrix, any rendering flags, bones and shadows properties. It encodes the pipeline, buffers and issues the draw command
         *
         * @param uRenderEncoder Metal encoder object for the current entity
         */
        virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
        
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
        
        void makePassPipelinePair(int uRenderPassKey, std::string uPipelineName);
        
        U4DRenderPipelineInterface *getPipeline(int uRenderPassKey);
        
    };
    
}
#endif /* U4DRenderEntity_hpp */
