//
//  FrustumCullingCompute.metal
//  
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
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
    float epsilon = 0.0001;
    
    for (uint i=0; i<6; ++i){
        float3 n = f.p[i].xyz;
        float d = f.p[i].w;
        float r = abs(n.x)*e.x + abs(n.y)*e.y + abs(n.z)*e.z;
        float s = dot(n,c) + d;
        if (s < -r - epsilon) return false;
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

kernel void markVisibleAABB(constant FrustumPlanes &fru [[buffer(markVisibilityPassFrustumIndex)]],
                            device EntityAABB *entityAABB [[buffer(markVisibilityPassEntityAABBIndex)]],
                            constant uint &count [[buffer(markVisibilityPassEntityAABBCountIndex)]],
                            device uint *flags [[buffer(markVisibilityPassFlagIndex)]],
                            uint gid [[thread_position_in_grid]]){
    
    if (gid >= count) return;
    
    EntityAABB o = entityAABB[gid];
    flags[gid] = aabbInFrustum(o.center.xyz, o.halfExtent.xyz, fru) ? 1u : 0u;
    
}

kernel void scanLocalExclusive(device uint *flags [[buffer(scanLocalPassFlagIndex)]],
                               device uint *indices [[buffer(scanLocalPassIndicesIndex)]],
                               device uint *blockSums [[buffer(scanLocalPassBlockSumsIndex)]],
                               constant uint &count [[buffer(scanLocalPassCountIndex)]],
                               uint tg_id [[threadgroup_position_in_grid]],
                               uint tid   [[thread_index_in_threadgroup]]
                               ){
    
    threadgroup uint sharedData[BLOCK_SIZE];
    
    const uint base  = tg_id * BLOCK_SIZE;
    const uint gid   = base + tid;
    const uint valid = (count > base) ? min((uint)BLOCK_SIZE, count - base) : 0;

    uint x = (tid < valid) ? flags[gid] : 0u;
    sharedData[tid] = x;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Hillis–Steele inclusive scan (simple & fine for 256)
    for (uint offset = 1; offset < BLOCK_SIZE; offset <<= 1) {
        uint t = 0u;
        if (tid >= offset) t = sharedData[tid - offset];
        threadgroup_barrier(mem_flags::mem_threadgroup);
        sharedData[tid] += t;
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid < valid) {
        indices[gid] = sharedData[tid] - x; // exclusive = inclusive - input
    }

    if (tid == 0) {
        uint sum = (valid == 0) ? 0u : (sharedData[valid - 1]); // inclusive total for the block
        blockSums[tg_id] = sum;
    }
}

kernel void scanBlockSumsExclusive(
    device   uint *blockSums    [[buffer(scanBlockSumPassSumIndex)]],
    device   uint *blockOffsets [[buffer(scanBlockSumPassOffsetIndex)]],
    constant uint &numBlocks    [[buffer(scanBlockSumPassNumBlocksIndex)]],
    uint tid [[thread_index_in_threadgroup]]
){
    // Launch 1 TG with threadsPerTG = nextPow2(numBlocks) (≤ 1024)
    threadgroup uint s[1024];

    uint N = 1u;
    while (N < numBlocks) N <<= 1;

    s[tid] = (tid < numBlocks) ? blockSums[tid] : 0u;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Blelloch up-sweep
    for (uint offset = 1; offset < N; offset <<= 1) {
        uint idx = ((tid + 1) * (offset << 1)) - 1;
        if (idx < N) s[idx] += s[idx - offset];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    // Set last to 0 for EXCLUSIVE
    if (tid == 0) s[N - 1] = 0u;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Blelloch down-sweep
    for (uint offset = N >> 1; offset >= 1; offset >>= 1) {
        uint idx = ((tid + 1) * (offset << 1)) - 1;
        if (idx < N) {
            uint t = s[idx - offset];
            s[idx - offset] = s[idx];
            s[idx] += t;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        if (offset == 1) break; // avoid underflow
    }

    if (tid < numBlocks) blockOffsets[tid] = s[tid];
}

kernel void scatterCompacted(
    device   uint        *flags        [[buffer(compactPassFlagsIndex)]],
    device   uint        *indices      [[buffer(compactPassIndicesIndex)]],
    device   uint        *blockOffsets [[buffer(compactPassBlockOffsetIndex)]],
    device   EntityAABB  *objs         [[buffer(compactPassEntityAABBIndex)]],
    constant uint        &count        [[buffer(compactPassCountIndex)]],
    device   VisibleEntity        *outIndices   [[buffer(compactPassVisibilityIndicesIndex)]],  // compacted entity indices
    device   uint        *visibleCount [[buffer(compactPassVisibilityCountIndex)]],
    uint gid [[thread_position_in_grid]]
){
    if (gid >= count) return;

    const uint f = flags[gid];
    const uint localIdx  = indices[gid];
    const uint blockId   = gid / BLOCK_SIZE;
    const uint globalIdx = localIdx + blockOffsets[blockId];

    if (f != 0u) {
        outIndices[globalIdx].index = objs[gid].index;  // or write {index,version}/entityID here
        outIndices[globalIdx].version = objs[gid].version;
    }

    // The last thread can compute total visible (exclusive prefix of last + last flag)
    if (gid == count - 1) {
        visibleCount[0] = globalIdx + f;
    }
}


