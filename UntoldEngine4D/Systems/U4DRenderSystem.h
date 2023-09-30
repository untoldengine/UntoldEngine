//
//  RenderSystem.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef RenderSystem_hpp
#define RenderSystem_hpp

#include <stdio.h>
#include "U4DScene.h"
#include "U4DComponents.h"
#import <MetalKit/MetalKit.h>

namespace U4DEngine {

void initBuffers();
void initAttachments();

void initPipelines();
void renderVoxelPass(U4DScene &scene, id<MTLCommandBuffer> uCommandBuffer);
void renderGridPass(id<MTLCommandBuffer> uCommandBuffer);
void shadowPass(U4DScene &scene, id<MTLCommandBuffer> uCommandBuffer);
void compositePass(id<MTLCommandBuffer> uCommandBuffer);

bool initMeshShaderPipeline(id<MTLDevice> mtlDevice);
void renderMeshShaderPass(id<MTLCommandBuffer> uCommandBuffer);

}

#endif /* RenderSystem_hpp */
