//
//  TransformSystem.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#ifndef TransformSystem_hpp
#define TransformSystem_hpp

#include <stdio.h>
#include "U4DScene.h"
#include "U4DComponents.h"
#include <simd/simd.h>

extern U4DEngine::U4DScene scene;

namespace U4DEngine {

void updateModelUniformBuffer();

void updateVoxelSpace();

void translateTo(EntityID entityId, simd_float3 uPosition);

void translateBy(EntityID entityId, simd_float3 uPosition);

void rotateTo(EntityID entityId, float uAngle, simd_float3 uAxis);

void rotateBy(EntityID entityId, float uAngle, simd_float3 uAxis);

void scaleBy(EntityID entityId, float uScale);

void scaleBy(EntityID entityId, float uX, float uY, float uZ);

}
#endif /* TransformSystem_hpp */
