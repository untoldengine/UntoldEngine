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
        
        virtual ~U4DRenderPipelineInterface(){};
        
        virtual void initRenderPass(std::string uVertexShader, std::string uFragmentShader)=0;
        virtual void initRenderPassTargetTexture()=0;
        virtual void initVertexDesc()=0;
        virtual void initRenderPassLibrary(std::string uVertexShader, std::string uFragmentShader)=0;
        virtual void initRenderPassDesc()=0;
        virtual void initRenderPassPipeline()=0;
        virtual void initRenderPassAdditionalInfo()=0;
        
//        virtual void bindResources(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uRootEntity, int uRenderPass)=0;
        
        virtual void executePass(id <MTLRenderCommandEncoder> uRenderEncoder, U4DEntity *uEntity)=0;
        
        virtual std::string getName()=0;
        
    };

}

#endif /* U4DRenderPipelineInterface_hpp */
