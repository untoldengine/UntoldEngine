//
//  U4DLoadingSystem.hpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 4/8/23.
//

#ifndef U4DLoadingSystem_hpp
#define U4DLoadingSystem_hpp

#include <stdio.h>
#include <string>
#include <vector>
#include "U4DScene.h"
#include "U4DComponents.h"
#import <MetalKit/MetalKit.h>

extern U4DEngine::U4DScene scene;

namespace U4DEngine {

id<MTLTexture> loadTextures(NSURL *url);
bool loadAsset(EntityID entityId, std::string fileName, std::string assetName, std::string textureName);
bool loadScene(std::string fileName);


//voxel
void loadVoxelAsset(std::string filename);
void insertVoxelIntoGPU(unsigned int uGuid, simd_float3 color);
void addVoxelsToEntity(EntityID entityId, std::string filename);

}

#endif /* U4DLoadingSystem_hpp */
