//
//  FrustumCullingCompute.metal
//  
//
//  Created by Harold Serrano on 8/21/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;

struct VisibleEntity{
    uint index;
    uint version;
};

inline bool aabbInFrustum(float3 c, float3 e, constant FrustumPlanes & f){
    // Center/extents test (fast, conservative)
    for (uint i=0; i<6; ++i){
        float3 n = f.p[i].xyz;
        float d = f.p[i].w;
        float r = abs(n.x)*e.x + abs(n.y)*e.y + abs(n.z)*e.z;
        float s = dot(n,c) + d;
        if (s < -r) return false;
    }
    
    return true;
}

kernel void cullFrustumAABB(constant FrustumPlanes &fru [[buffer(frustumCullingPassPlanesIndex)]],
                            device EntityAABB *entityAABB [[buffer(frustumCullingPassObjectIndex)]],
                            constant uint &count [[buffer(frustumCullingPassObjectCountIndex)]],
                            device VisibleEntity *out[[buffer(frustumCullingPassVisibilityIndex)]],
                            device atomic_uint *outCount [[buffer(frustumCullingPassVisibleCountIndex)]],
                            uint tid [[thread_position_in_grid]]){
    
    if (tid >= count) return;
    
    EntityAABB obj = entityAABB[tid];
    
    bool vis = aabbInFrustum(obj.center.xyz, obj.halfExtent.xyz, fru);
    
    if (vis){
        uint dst = atomic_fetch_add_explicit(outCount, 1u, memory_order_relaxed);
        out[dst].index = obj.index;
        out[dst].version = obj.version;
    }
}

