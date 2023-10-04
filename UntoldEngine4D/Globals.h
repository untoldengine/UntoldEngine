//
//  Globals.h
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef Globals_h
#define Globals_h

#include "U4DScene.h"
#include "U4DCamera.h"
#include "U4DController.h"
#include "U4DLight.h"
#include "U4DComponents.h"
#include "CommonProtocols.h"
#include <map>

int U4DEngine::s_componentCounter=0;
unsigned long nextVoxelOffset=0;
float nearPlane=0.1f;
float farPlane=1000.0f;

U4DEngine::callback updateCallbackFunction=nullptr;
U4DEngine::U4DScene scene;
U4DEngine::VoxelPool voxelPool;


U4DEngine::U4DCamera camera;
U4DEngine::U4DController controller;

U4DEngine::RenderPipelines gridPipeline;
U4DEngine::RenderPipelines shadowPipeline;
U4DEngine::RenderPipelines voxelPipeline;
U4DEngine::RenderPipelines compositePipeline;
U4DEngine::Buffer buffer;
U4DEngine::Attachments attachments;
U4DEngine::U4DLight light;

std::map<std::string, U4DEngine::Voxel> voxelAssetMap;

U4DEngine::RendererInfo renderInfo;

#endif /* Globals_h */
