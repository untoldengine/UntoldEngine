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
#include <vector>
#include <simd/simd.h>
#include "U4DRenderPipelineInterface.h"
#include "U4DEntity.h"

namespace U4DEngine {

/**
 * @ingroup renderingengine
 * @brief      The U4DRenderManager class manages all rendering for 3D models, images, skyboxes, etc
 */
    class U4DRenderManager {
        
    private:
        
        
        
        /**
         @brief Instace for the U4DRenderManager singleton
         */
        static U4DRenderManager* instance;
        
        std::vector<U4DRenderPipelineInterface*> renderingPipelineContainer;
        
        
        
    protected:
        
        /**
         * @brief Constructor for the U4DRenderManager
         * @details The constructor initializes the Metal device and sets the descriptors and pipeline states to NULL
         */
        U4DRenderManager();
        
        /**
         * @brief Destructor for the U4DRenderManager
         * @details Sets all descriptors and pipeline states to NULL
         */
        ~U4DRenderManager();
        
    public:
        
        static U4DRenderManager* sharedInstance();
        
        /**
         * @brief Pointer to the Uniform that holds Global data such as time, resolution,etc
         */
        id<MTLBuffer> globalDataUniform;
        
        id<MTLBuffer> directionalLightPropertiesUniform;
        
        id<MTLBuffer> pointLightsPropertiesUniform;
        
        
        void initRenderPipelines(id <MTLDevice> uMTLDevice);
        
        void render(id <MTLCommandBuffer> uCommandBuffer, U4DEntity *uRootEntity);
        
        void updateGlobalDataUniforms();
        
        void updateDirLightDataUniforms();
        
        void updatePointLightDataUniforms();
        
        U4DRenderPipelineInterface* searchPipeline(std::string uPipelineName);
        
        void addRenderPipeline(U4DRenderPipelineInterface* uRenderPipeline);
        
    };
    
}

#endif /* RenderManager_hpp */
