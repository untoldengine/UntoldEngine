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
         @brief Name of the pipeline
         */
        std::string name;
        
        /**
         @brief Vertex Shader name
         */
        std::string vertexShaderName;
        
        /**
         @brief Fragment Shader name
         */
        std::string fragmentShaderName;
        
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
        
        U4DRenderPipeline(std::string uName);
        
        ~U4DRenderPipeline();
        
        id<MTLTexture> targetDepthTexture;
        
        void initPipeline(std::string uVertexShader, std::string uFragmentShader);
        
        virtual void initTargetTexture(){};
        
        virtual void initVertexDesc(){};
        
        void initLibrary(std::string uVertexShader, std::string uFragmentShader);
        
        virtual void initPassDesc(){};
        
        virtual bool buildPipeline(){};
        
        void initAdditionalInfo();
               
        virtual void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity){};
        
        virtual void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder){};
        
        id<MTLTexture> getTargetTexture();
        
        void setInputTexture(id<MTLTexture> uInputTexture);
        
        void hotReloadShaders(std::string uFilepath, std::string uVertexShader, std::string uFragmentShader);
        
        std::string getName();
        
        std::string getVertexShaderName();
        
        std::string getFragmentShaderName();
        
    };

}

#endif /* U4DRenderPipeline_hpp */
