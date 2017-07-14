//
//  RenderManager.hpp
//  MetalRendering
//
//  Created by Harold Serrano on 6/30/17.
//  Copyright © 2017 Harold Serrano. All rights reserved.
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

    class U4DRenderManager {
        
    private:
        
    protected:
        
        id <MTLDevice> mtlDevice;
        
        id<MTLRenderPipelineState> mtlRenderPipelineState;
        
        MTLRenderPipelineDescriptor *mtlRenderPipelineDescriptor;
        
        id<MTLDepthStencilState> depthStencilState;
        
        id<MTLLibrary> mtlLibrary;
        
        id<MTLFunction> vertexProgram;
        
        id<MTLFunction> fragmentProgram;
        
        //Attribute
        id<MTLBuffer> attributeBuffer;
        
        id<MTLBuffer> indicesBuffer;
        
        //uniforms
        id<MTLBuffer> uniformSpaceBuffer;
        
        id<MTLBuffer> uniformModelRenderFlagsBuffer;
        
        //Texture object
        id<MTLTexture> textureObject;
        
        id<MTLTexture> normalMapTextureObject;
        
        //Sampler State Object
        id<MTLSamplerState> samplerStateObject;
        
        id<MTLSamplerState> samplerNormalMapStateObject;
        
        
        //items for multiimage
        
        id<MTLTexture> secondaryTextureObject;
        
        
        //light
        id<MTLBuffer> lightPositionUniform;
        
        // Decode image raw data
        std::vector<unsigned char> rawImageData;
        unsigned int imageWidth;
        unsigned int imageHeight;
        
        //decode skybox raw data
        std::vector<const char*> skyboxTexturesContainer;
        
    public:
        
        U4DRenderManager();
        
        ~U4DRenderManager();
        
        void loadRenderingInformation();
        
        virtual void initMTLRenderLibrary(){};
        
        virtual void initMTLRenderPipeline(){};
        
        virtual void loadMTLBuffer(){};
        
        virtual void loadMTLTexture(){};
        
        virtual void loadMTLAdditionalInformation(){}
        
        virtual void loadMTLNormalMapTexture(){};
        
        virtual void updateSpaceUniforms(){};
        
        virtual void updateShadowSpaceUniforms(){};
        
        virtual void render(id <MTLRenderCommandEncoder> uRenderEncoder){};
        
        virtual void renderShadow(id <MTLRenderCommandEncoder> uRenderShadowEncoder, id<MTLTexture> uShadowTexture){};
        
        virtual void createTextureObject();
        
        void createSamplerObject();
        
        virtual void createSecondaryTextureObject(){};
        
        void createNormalMapTextureObject();
        
        void createNormalMapSamplerObject();
        
        virtual void setGeometryLineColor(U4DVector4n &uGeometryLineColor){};
        
        void decodeImage(std::string uTexture);
        
        std::vector<unsigned char> decodeImage(const char *uTexture);
        
        void clearRawImageData();
        
        virtual void initTextureSamplerObjectNull(){};
        
        virtual void setImageDimension(float uWidth,float uHeight){};
        
        virtual void setSkyboxDimension(float uSize){};
        
        virtual void setDiffuseTexture(const char* uTexture){};
        
        virtual void setAmbientTexture(const char* uTexture){}
        
        void addTexturesToSkyboxContainer(const char* uTextures);
        
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

        
        matrix_float4x4 convertToSIMD(U4DEngine::U4DMatrix4n &uMatrix);
        
        matrix_float3x3 convertToSIMD(U4DEngine::U4DMatrix3n &uMatrix);
        
        vector_float4 convertToSIMD(U4DEngine::U4DVector4n &uVector);
        
        vector_float3 vector_make(float x, float y, float z);
    };
    
}

#endif /* RenderManager_hpp */
