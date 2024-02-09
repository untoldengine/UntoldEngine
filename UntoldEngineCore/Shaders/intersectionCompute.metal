//
//  intersectionCompute.metal
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/21/23.
//

#include <metal_stdlib>
#import "ShaderTypes.h"
#include "ComputeHelperFunctions.h"

using namespace metal;

kernel void voxelIntersect(device float3 *voxels[[buffer(voxelOrigin)]], 
                           device bool *visible[[buffer((voxelVisible))]],
                           device RayUniforms &uniforms[[buffer(intersectionUniform)]],
                           device uint *rayBoxDidIntersect[[buffer(intersectionResult)]],
                           device atomic_uint *tParam[[buffer(intersectionTParam)]],
                           device simd_float3 *pointIntersect[[buffer(intersectionPointInt)]],
                           device atomic_uint *blockIntersectedGuid[[buffer(intersectGuid)]],
                           device bool &planeRayDidIntersect[[buffer(planeRayIntersectionResult)]],
                           device atomic_uint *tParamPlane[[buffer(planeRayIntersectionTime)]],
                           device simd_float3 *planeRayIntersectionPoint [[buffer(planeRayIntersectionPoint)]],
                           uint guid [[thread_position_in_grid]],
                           uint threadid [[thread_position_in_threadgroup]],
                           uint blockDim [[threads_per_threadgroup]],
                           uint blockid[[threadgroup_position_in_grid]]){

    Ray ray;
    ray.origin=uniforms.rayOrigin;
    ray.direction=uniforms.rayDirection;
    
    if(guid==0){

        Plane plane;
        plane.normal=simd_float3{0.0,1.0,0.0};
        plane.d=0;
        thread uint tPlaneCompare=0;
        rayIntersectsPlane(plane, ray, &tParamPlane[0],&tPlaneCompare);
    }
    
    if(visible[guid]==true){
    
        Box box;

        box.origin= voxels[guid]+modelOffset;

        box.halfWidth=float3(1.0,1.0,1.0)*scale;
        
        simd_float3 q=simd_float3(0.0,0.0,0.0);
        thread uint tCompare=0;
        
        rayIntersectsBox(box,ray,&tParam[0],&tCompare);
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if(atomic_load_explicit(&tParam[0], memory_order_relaxed)==tCompare && tCompare!=0){
            rayBoxDidIntersect[0]=1;
            
            float t=as_type<float>(atomic_load_explicit(&tParam[0], memory_order_relaxed));
            q=ray.origin+t*ray.direction;
            
            pointIntersect[0]=getPlaneNormal(q, box);
            //pointIntersect[0]=getPlaneNormal(q, box);
            atomic_exchange_explicit(&blockIntersectedGuid[0], guid, memory_order_relaxed);
        }
        
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if(guid==0){
        if( as_type<float>(atomic_load_explicit(&tParam[0], memory_order_relaxed)) < as_type<float>(atomic_load_explicit(&tParamPlane[0], memory_order_relaxed)) ){
            planeRayDidIntersect=false;
        }else{
            
            float t=as_type<float>(atomic_load_explicit(&tParamPlane[0], memory_order_relaxed));
            
            if(t>=0.0f){
                planeRayIntersectionPoint[0]=ray.origin + t*ray.direction;
        
            }
            
            simd_float3 planeGuidFloat=(planeRayIntersectionPoint[0]+planeOffset);
            planeGuidFloat.y=0.0;
            if(planeGuidFloat.x>0 && planeGuidFloat.x<planeScale &&
               planeGuidFloat.z>0 && planeGuidFloat.z<planeScale){
                planeGuidFloat=floor(planeGuidFloat*(1.0/(2.0*scale)));
                planeRayDidIntersect=true;
                rayBoxDidIntersect[0]=1;
                uint planeGuid=grid3dToIndexMap(simd_uint3(planeGuidFloat),chunkSize,chunkSize,chunkSize);
                atomic_exchange_explicit(&blockIntersectedGuid[0], planeGuid, memory_order_relaxed);
            }
            
        }
    }
    
}

kernel void voxelBoxIntersect(device float3 *voxels[[buffer(voxelInBoxOriginIndex)]],
                              device bool *visible[[buffer((voxelInBoxVisibleIndex))]],
                              device RayUniforms &uniforms[[buffer(voxelInBoxRayIndex)]],
                              constant simd_float3 &boxOrigin[[buffer(voxelInBoxOrignIndex)]],
                              constant simd_float3 &boxHalfwidth[[buffer(voxelInBoxHalfwidthIndex)]],
                              device VoxelData *voxelIntersected[[buffer(voxelInBoxInterceptedIndex)]],
                              device atomic_uint *count[[buffer(voxelInBoxCountIndex)]],
                              uint guid [[thread_position_in_grid]],
                              uint threadid [[thread_position_in_threadgroup]],
                              uint blockDim [[threads_per_threadgroup]],
                              uint blockid[[threadgroup_position_in_grid]]){
    
    threadgroup bool intersected=false;
    
    Ray ray;
    ray.origin=uniforms.rayOrigin;
    ray.direction=uniforms.rayDirection;
    
    Box box;
    box.origin=boxOrigin*2.0*scale+modelOffset;
    box.halfWidth=boxHalfwidth*scale;
    
    if(threadid==0){
        
        intersected=lazyRayIntersectBox(box, ray);
        
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    if(intersected){
        
        simd_float3 voxelOrigin=simd_float3(indexTo3DGridMap(guid,chunkSize,chunkSize,chunkSize))*2.0*scale+modelOffset;
        
        simd_float3 minCorner=-box.halfWidth+box.origin;
        simd_float3 maxCorner=box.origin+box.halfWidth;
    
        bool insideX = voxelOrigin.x >= minCorner.x && voxelOrigin.x <= maxCorner.x;
        bool insideY = voxelOrigin.y >= minCorner.y && voxelOrigin.y <= maxCorner.y;
        bool insideZ = voxelOrigin.z >= minCorner.z && voxelOrigin.z <= maxCorner.z;
        VoxelData voxelData;
        voxelData.guid=guid;
        if(intersected && insideX && insideY && insideZ){
    
            voxelIntersected[atomic_fetch_add_explicit(&count[0], 1, memory_order_relaxed)]=voxelData;
    
        }
    }

}


kernel void getPlaneNormalCompute(device RayUniforms &uniforms[[buffer(planeNormalRayIndex)]],
                            constant simd_float3 &boxOrigin[[buffer(planeNormalBoxOriginIndex)]],
                            constant simd_float3 &boxHalfwidth[[buffer(planeNormalBoxHalfwidthIndex)]],
                            device atomic_uint *tParam[[buffer(planeNormalTParamIndex)]],
                            device simd_float3 *planeNoramlIntersect[[buffer(planeNormalInterceptPointIndex)]],
                            device uint *rayBoxDidIntersect[[buffer(planeNormalIntResultIndex)]],
                            uint guid [[thread_position_in_grid]],
                            uint threadid [[thread_position_in_threadgroup]],
                            uint blockDim [[threads_per_threadgroup]],
                            uint blockid[[threadgroup_position_in_grid]]){
    
    
//    simd_float3 globalBoxOrigin=(maxBox+minBox)*0.5;
    simd_float3 q=simd_float3(0.0,0.0,0.0);
    thread uint tCompare=0;
    thread bool intersected=false;
    Ray ray;
    ray.origin=uniforms.rayOrigin;
    ray.direction=uniforms.rayDirection;
    
    Box box;
    box.origin=boxOrigin*2.0*scale+modelOffset;
    box.halfWidth=boxHalfwidth*scale;

    rayIntersectsBox(box,ray,&tParam[0],&tCompare);
    //intersected=lazyRayIntersectBox(box, ray);
    //if(intersected){
        
    if(atomic_load_explicit(&tParam[0], memory_order_relaxed)==tCompare && tCompare!=0){
        rayBoxDidIntersect[0]=1;
        
        float t=as_type<float>(atomic_load_explicit(&tParam[0], memory_order_relaxed));
        q=ray.origin+t*ray.direction;
        
        planeNoramlIntersect[0]=getPlaneNormal(q, box);
        
        
    }
    
}
