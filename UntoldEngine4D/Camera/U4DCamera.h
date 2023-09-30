//
//  U4DCamera.hpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/9/23.
//

#ifndef U4DCamera_hpp
#define U4DCamera_hpp

#include <stdio.h>
#include "U4DMathUtils.h"
#include <simd/simd.h>

namespace U4DEngine {
struct U4DCamera {
    
    void translateTo( simd::float3 uTranslation ) {

        localPosition = uTranslation;
        viewSpace.columns[3] = simd::float4 { uTranslation.x, uTranslation.y, uTranslation.z, 1.0 };
    }

    void translateBy( simd::float3 uPosition ) {
        localPosition.x += uPosition.x * xaxis.x + uPosition.y * yaxis.x + uPosition.z * zaxis.x;
        localPosition.y += uPosition.x * xaxis.y + uPosition.y * yaxis.y + uPosition.z * zaxis.y;
        localPosition.z += uPosition.x * xaxis.z + uPosition.y * yaxis.z + uPosition.z * zaxis.z;

        updateViewMatrix();
    }

    void updateViewMatrix() {

        rotation = quaternion_normalize( rotation );

        xaxis = right_direction_vector_from_quaternion( rotation );
        yaxis = up_direction_vector_from_quaternion( rotation );
        zaxis = forward_direction_vector_from_quaternion( rotation );

        viewSpace = matrix4x4_from_quaternion( rotation );

        viewSpace.columns[3] = simd_float4 { -simd::dot( xaxis, localPosition ), -simd::dot( yaxis, localPosition ), -simd::dot( zaxis, localPosition ), 1 };

        localOrientation = zaxis;
    }

    void lookAt( simd::float3 eye, simd::float3 target, simd::float3 up ) {

        rotation = quaternion_normalize( quaternion_conjugate( quaternion_lookAt( eye, target, up ) ) );
        localPosition = eye;

        updateViewMatrix();
    }

    void orbitAround( simd_float2 uPosition ) {

        // Get the vector pointing to the target
        simd_float3 targetV = localPosition - orbitTarget;
        float length = simd_length( targetV );
        simd_float3 direction = simd_normalize( targetV );

        // rot about yaw first
        quaternion_float rotationX = quaternion_from_axis_angle( simd_float3 { 0.0, 1.0, 0.0 }, uPosition.x );
        direction = quaternion_rotate_vector( rotationX, direction );
        simd_float3 newUpAxis = quaternion_rotate_vector( rotationX, yaxis );

        direction = simd_normalize( direction );
        newUpAxis = simd_normalize( newUpAxis );

        // now compute the right axis
        simd_float3 rightAxis = simd_cross( newUpAxis, direction );

        rightAxis = simd_normalize( rightAxis );

        // then rotate about the right axis
        quaternion_float rotationY = quaternion_from_axis_angle( rightAxis, uPosition.y );
        direction = quaternion_rotate_vector( rotationY, direction );
        newUpAxis = quaternion_rotate_vector( rotationY, newUpAxis );

        direction = simd_normalize( direction );
        newUpAxis = simd_normalize( newUpAxis );

        localPosition = orbitTarget + direction * length;

        lookAt( localPosition, orbitTarget, newUpAxis );
    }

    
    
    //data
    simd_float4x4 viewSpace=matrix4x4_identity();
    quaternion_float rotation = quaternion_identity();
    simd::float3 localOrientation = simd::float3 { 0.0, 0.0, 0.0 };
    simd::float3 localPosition = simd::float3 { 0.0, 0.0, 0.0 };

    simd_float3 xaxis;

    simd_float3 yaxis;

    simd_float3 zaxis;
    
    float fov = 65.0f;

    simd_float3 orbitTarget;
        
    };
}

#endif /* U4DCamera_hpp */
