//
//  removeAllCompute.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/3/23.
//

#include <metal_stdlib>
#import "ShaderTypes.h"
using namespace metal;


kernel void removeAllVoxels(device float3 *voxels[[buffer(voxelOrigin)]],device float3 *voxelVertices[[buffer(voxelVertices)]], device bool *visible[[buffer((voxelVisible))]], uint guid [[thread_position_in_grid]], uint threadid [[thread_position_in_threadgroup]], uint blockDim [[threads_per_threadgroup]], uint blockid[[threadgroup_position_in_grid]]){
    
    simd_float3 origin=simd_float3(-FLT_MAX,-FLT_MAX,-FLT_MAX);
    simd_float3 zero=simd_float3(0.0,0.0,0.0);
    
    voxels[guid]=origin;
    
    for(int i=0;i<24;i++){
        voxelVertices[guid*24+i]=zero;
    }
    
    visible[guid]=false;
    
}
