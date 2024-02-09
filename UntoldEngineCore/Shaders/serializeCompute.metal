//
//  serializeCompute.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/6/23.
//

#include <metal_stdlib>
#import "ShaderTypes.h"
using namespace metal;

kernel void serializeVoxels(device simd_float3 *voxels[[buffer(voxelOrigin)]],
                            device bool *visible[[buffer((voxelVisible))]],
                            device simd_float3 *color[[buffer(voxelBaseColor)]],
                            device float *roughness[[buffer(voxelRoughness)]],
                            device float *metallic[[buffer(voxelMetallic)]],
                            device VoxelData *serialize[[buffer(voxelSerialized)]],
                            device atomic_uint *count[[buffer(voxelSerializedCount)]],
                            uint guid [[thread_position_in_grid]],
                            uint threadid [[thread_position_in_threadgroup]],
                            uint blockDim [[threads_per_threadgroup]],
                            uint blockid[[threadgroup_position_in_grid]]){
    
    //check if the voxel is visible
    if(visible[guid]){
        
        VoxelData voxelData;
        voxelData.guid=guid;
        voxelData.color=color[guid];
        //24 is the number of vertices in a voxel
        voxelData.material=float3(roughness[24*guid],metallic[24*guid],0.0);
        
        serialize[atomic_fetch_add_explicit(&count[0], 1, memory_order_relaxed)]=voxelData;
        
    }
    
    
    
}


