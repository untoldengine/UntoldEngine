//
//  U4DRenderPipeline.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/28/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderPipeline_hpp
#define U4DRenderPipeline_hpp

#include <stdio.h>
#import <MetalKit/MetalKit.h>

#include <string>
#include "CommonProtocols.h" 
#include "U4DRenderPipelineInterface.h"
#include "U4DRenderEntity.h"
#include "U4DEntity.h"

namespace U4DEngine {

    class U4DRenderPipeline: public U4DRenderPipelineInterface {
        
    private:
    
    protected:
        
        /**
         @brief Name of the pass
         */
        std::string name;
        
        /**
         * @brief Pointer representing a Metal Device
         */
        id <MTLDevice> mtlDevice;
        
        /**
         * @brief Pointer representing the state of the render pipeline
         */
        id<MTLRenderPipelineState> mtlRenderPassPipelineState;
        
        /**
         * @brief Pointer for the rendering pipeline descriptor
         */
        MTLRenderPipelineDescriptor *mtlRenderPassPipelineDescriptor;
        
        
        
        
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
        MTLDepthStencilDescriptor *mtlRenderPassDepthStencilDescriptor;
        
        id<MTLDepthStencilState> mtlRenderPassDepthStencilState;
        
        MTLStencilDescriptor *mtlRenderPassStencilStateDescriptor;
        
        MTLRenderPassDepthAttachmentDescriptor *mtlRenderPassDepthAttachmentDescriptor;

        id<MTLBuffer> shadowPropertiesUniform;
        
    public:
        
        U4DRenderPipeline(id <MTLDevice> uMTLDevice, std::string uName);
        
        ~U4DRenderPipeline();
        
        
        
        
        
        id<MTLTexture> targetDepthTexture;
        
        void initRenderPass(std::string uVertexShader, std::string uFragmentShader);
        
        virtual void initRenderPassTargetTexture(){};
        
        virtual void initVertexDesc(){};
        
        void initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader);
        
        virtual void initRenderPassDesc(){};
        
        virtual void initRenderPassPipeline(){};
        
        void initRenderPassAdditionalInfo();
        
//        void bindResources(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uRootEntity, int uRenderPass);
        
        virtual void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){};
        
        id<MTLTexture> getTargetTexture();
        
        void setInputTexture(id<MTLTexture> uInputTexture);
        
        /**
         * @brief Creates a texture object to be applied to an entity
         * @details It creates a texture descriptor, and loads texture raw data into a newly created texture object
         */
        void createTextureObject(id<MTLTexture> &uTextureObject);
        
        /**
         * @brief Creates a sampler object required for texturing
         * @details Creates a sampler descriptor and sets the filtering and addressing settings. Loads the sampler descriptor into a newly created sampler object.
         */
        void createSamplerObject(id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor);
        
        /**
         * @brief Initializes texture sampler object to null
         * @details It initializes the sampler object to null. The object is later used to store sampler settings
         */
        void initTextureSamplerObjectNull();
        
        bool createTextureAndSamplerObjects(id<MTLTexture> &uTextureObject, id<MTLSamplerState> &uSamplerStateObject, MTLSamplerDescriptor *uSamplerDescriptor, std::string uTextureName);
        
        void hotReloadShaders(std::string uFilepath);
        
        std::string getName();
        
        
        
    };

}

#endif /* U4DRenderPipeline_hpp */
