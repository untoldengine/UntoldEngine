//
//  U4DRenderPipelineInterface.hpp
//  UntoldEngine
//
//  Created by Harold Serrano on 12/29/20.
//  Copyright © 2020 Untold Engine Studios. All rights reserved.
//

#ifndef U4DRenderPipelineInterface_hpp
#define U4DRenderPipelineInterface_hpp

#include <stdio.h>
#include <string>
#import <MetalKit/MetalKit.h>
#include "U4DEntity.h"

class U4DRenderEntity;

namespace U4DEngine {

    class U4DRenderPipelineInterface {

    public:
        
        /**
         * @brief Pointer representing the render pass descriptor
         */
        MTLRenderPassDescriptor *mtlRenderPassDescriptor;
        
        id<MTLTexture> targetTexture;
        
        id<MTLTexture> inputTexture;
        
        id<MTLTexture> albedoTexture;
        id<MTLTexture> normalTexture;
        id<MTLTexture> positionTexture;
        id<MTLTexture> depthTexture;
        
        virtual ~U4DRenderPipelineInterface(){};
        
        virtual void initPipeline(std::string uVertexShader, std::string uFragmentShader)=0;
        virtual void initTargetTexture()=0;
        virtual void initVertexDesc()=0;
        virtual void initLibrary(std::string uVertexShader, std::string uFragmentShader)=0;
        virtual void initPassDesc()=0;
        virtual bool buildPipeline()=0;
        virtual void initAdditionalInfo()=0;
               
        virtual void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity)=0;
        
        virtual void executePipeline(id <MTLRenderCommandEncoder> uRenderEncoder)=0;
        
        virtual void hotReloadShaders(std::string uFilepath, std::string uVertexShader, std::string uFragmentShader)=0;
        
        virtual std::string getName()=0;
        
        virtual std::string getVertexShaderName()=0;
        
        virtual std::string getFragmentShaderName()=0;
        
    };

}

#endif /* U4DRenderPipelineInterface_hpp */
