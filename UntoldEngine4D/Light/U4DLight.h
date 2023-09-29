//
//  U4DLight.hpp
//  UntoldEnginePro
//
//  Created by Harold Serrano on 5/7/23.
//

#ifndef U4DLight_hpp
#define U4DLight_hpp

#include <stdio.h>
#include <simd/simd.h>
#include "U4DMathUtils.h"

namespace U4DEngine {

struct U4DLight{
    
    void translateTo(simd_float3 uPosition){
        
        simd_float4 lightPosition = simd_float4{uPosition.x,uPosition.y,uPosition.z,1.0};
        
//        //this section is necessary since the coordinate system of Blender is different than that of Metal
//        float lightY=lightPosition.y;
//        lightPosition.y=-lightPosition.z;
//        lightPosition.z=lightY;
//
//        position=lightPosition.xyz;
        position=uPosition;
    }
    
    
    
    void updateSpace(){
        
        viewMatrix=matrix_look_at_right_hand(position, simd_float3{0.0,0.0,0.0}, simd_float3{0.0,1.0,0.0});
        
        orthoViewMatrix=simd_mul(orthoMatrix, viewMatrix);
    }
    
    simd_float4x4 orthoViewMatrix;
    simd_float4x4 orthoMatrix;
    simd_float4x4 viewMatrix;
    simd_float3 position;
    
};

}
#endif /* U4DLight_hpp */
