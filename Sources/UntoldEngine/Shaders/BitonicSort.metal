//
//  BitonicSort.metal
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"
using namespace metal;


// Depth-sorting key: front-to-back or back-to-front without float->int scaling
inline uint float_to_sortable_u32(float x) {
    uint u = as_type<uint>(x);
    // Map IEEE754 to a total order in unsigned ints:
    //   negatives (sign=1)  -> flip all bits
    //   non-negatives       -> flip sign bit
    uint mask = (u >> 31) ? 0xffffffffu : 0x80000000u;
    return u ^ mask;
}

inline float eye_space_depth(const float4x4 modelView, float3 worldPos) {
    float4 v = modelView * float4(worldPos, 1.0);
    // If camera looks down -Z, nearer = smaller (-v.z); make it non-negative
    return max(-v.z, 0.0f);
}

kernel void gaussianDepthKeys(device uint64_t *outKeys              [[buffer(gaussianIndicesIndex)]],
                              const device GaussianSplat *splats     [[buffer(gaussianSplatIndex)]],
                              constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
                              constant Uniforms &uniforms     [[buffer(gaussianUniformIndex)]],
                              uint index                              [[thread_position_in_grid]],
                              uint gridSize                           [[threads_per_grid]])
{
    if (index >= numOfSplats) return;

    // 1) Eye-space depth
    float z = eye_space_depth(uniforms.modelViewMatrix, splats[index].center.xyz);

    // 2) Convert to lexicographically sortable unsigned int
    uint keyFrontToBack = float_to_sortable_u32(z);

    // gaussian sorting
    //uint keyBackToFront = 0xffffffffu - keyFrontToBack;

    // 3) Pack [key | index] for 64-bit radix sort (key in high bits)
    uint64_t packed = (uint64_t)keyFrontToBack << 32 | (uint64_t)index;
    outKeys[index] = packed;
}

kernel void gaussianBitonicSort(device uint64_t *splatIndices [[buffer(gaussianIndicesIndex)]],
                                constant uint &numOfSplats [[buffer(gaussianNumberOfSplatsIndex)]],
                                constant int &comparisonDistance [[buffer(gaussianComparisonDistanceIndex)]],
                                constant int &subArraySize [[buffer(gaussianSubArraySizeIndex)]],
                                uint threadIdx [[thread_position_in_grid]]){

    if(threadIdx >= numOfSplats) return;
    
    uint i = threadIdx;
    
    // find the index to compare with
    uint comparisonIndex = i ^ comparisonDistance;
    
    if(comparisonIndex > i && comparisonIndex < numOfSplats){
        // access index for the current element
        uint64_t currentElement=splatIndices[i];
        uint64_t compareElement=splatIndices[comparisonIndex];
        
        // determine the correct order based on subarray size
        bool ascending = ((i & subArraySize)==0);
        
        // perform the swap
        if((ascending && currentElement > compareElement) || (!ascending && currentElement < compareElement)){
            // swap the indices
            uint64_t temp = currentElement;
            splatIndices[i] = compareElement;
            splatIndices[comparisonIndex] = temp;
        }
    }
}
