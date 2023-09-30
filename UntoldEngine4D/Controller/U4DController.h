//
//  U4DController.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 8/30/23.
//

#ifndef U4DController_hpp
#define U4DController_hpp

#include <stdio.h>
#import <simd/simd.h>

#include "U4DCamera.h"
#include "U4DMathUtils.h"

extern U4DEngine::U4DCamera camera;

namespace U4DEngine {
struct U4DController{
    
    void dollyTrackBoom(simd::float3 uDelta){
        uDelta.x*=-1.0;
        uDelta.z*=-1.0;
        camera.translateBy(uDelta);
    }
    
    void flyCamera(simd::float2 uDelta){
        
        float rotationAngleX = uDelta.x * 0.01;
        float rotationAngleY = uDelta.y * 0.01;

        quaternion_float rotationX = quaternion_from_axis_angle( simd_float3 { 0.0, 1.0, 0.0 }, rotationAngleX );
        quaternion_float rotationY = quaternion_from_axis_angle( simd_float3 { 1.0, 0.0, 0.0 }, rotationAngleY );

        // apply y-axis rotation first

        quaternion_float newRotation = quaternion_multiply( rotationY, camera.rotation );

        // apply x-axis
        camera.rotation = quaternion_multiply( newRotation, rotationX );

        camera.updateViewMatrix();
        
    }
    
    void orbitCamera(simd::float2 uDelta){
        // inverting x and y input
        uDelta.x *= -0.01;
        uDelta.y *= -0.01;

        camera.orbitAround( uDelta );
    }
    
    void setOrbitTarget(float uOffset){
        simd_float3 direction = -1.0 * camera.localOrientation;
        camera.orbitTarget = camera.localPosition + direction * uOffset;
    }
};
}
#endif /* U4DController_hpp */
