//
//  GPUHelperFunctions.metal
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/3/23.
//

#include <metal_stdlib>
#include "ComputeHelperFunctions.h"
using namespace metal;

void swap(thread float &a, thread float &b){

    float temp=a;
    a=b;
    b=temp;
}

void rayIntersectsPlane(thread Plane &uPlane, thread Ray &uRay, device atomic_uint *tPlaneSharedMin, thread uint *tCompare){
    
    float tMin=(uPlane.d-dot(uPlane.normal, uRay.origin))/dot(uPlane.normal, uRay.direction);
    
    *tCompare=as_type<uint>(tMin);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&tPlaneSharedMin[0], *tCompare, memory_order_relaxed);
    
//    if(intersectionParam>=0.0f){
//        intersectionPoint=uRay.origin + intersectionParam*uRay.direction;
//
//    }
    
   
}

bool lazyRayIntersectBox(thread Box &uBox, thread Ray &uRay){
    float bMin[3]={-uBox.halfWidth.x+uBox.origin.x,-uBox.halfWidth.y+uBox.origin.y,-uBox.halfWidth.z+uBox.origin.z};

    float bMax[3]={uBox.halfWidth.x+uBox.origin.x,uBox.halfWidth.y+uBox.origin.y,uBox.halfWidth.z+uBox.origin.z};
    
    float p[3]={uRay.origin.x, uRay.origin.y, uRay.origin.z};
    float d[3]={uRay.direction.x, uRay.direction.y, uRay.direction.z};

    float tMin=0.0f;
    float tMax=FLT_MAX;

    //for all three slabs

    for(int i=0;i<3;i++){

       {
            //compute intersection t value of ray with near and far plane of slab

            float ood=1.0f/d[i];
            float t1=(bMin[i]-p[i])*ood;
            float t2=(bMax[i]-p[i])*ood;

            //make t1 be intersection with near plane, t2 with far plane
            if(t1>t2) swap(t1,t2);

            //Compute the intersection of slab intersection intervals
            tMin=max(tMin,t1);
            tMax=min(tMax,t2);

            //exit with no collision as soon as slab intersection becomes empty
           if(tMin>tMax) return false;
        }
    }
    
    return true;
}

void rayIntersectsBox(thread Box &uBox, thread Ray &uRay,device atomic_uint *tSharedMin, thread uint *tCompare){
    
    float bMin[3]={-uBox.halfWidth.x+uBox.origin.x,-uBox.halfWidth.y+uBox.origin.y,-uBox.halfWidth.z+uBox.origin.z};

    float bMax[3]={uBox.halfWidth.x+uBox.origin.x,uBox.halfWidth.y+uBox.origin.y,uBox.halfWidth.z+uBox.origin.z};
    
    float p[3]={uRay.origin.x, uRay.origin.y, uRay.origin.z};
    float d[3]={uRay.direction.x, uRay.direction.y, uRay.direction.z};

    float tMin=0.0f;
    float tMax=FLT_MAX;

    //for all three slabs

    for(int i=0;i<3;i++){

       {
            //compute intersection t value of ray with near and far plane of slab

            float ood=1.0f/d[i];
            float t1=(bMin[i]-p[i])*ood;
            float t2=(bMax[i]-p[i])*ood;

            //make t1 be intersection with near plane, t2 with far plane
            if(t1>t2) swap(t1,t2);

            //Compute the intersection of slab intersection intervals
            tMin=max(tMin,t1);
            tMax=min(tMax,t2);

            //exit with no collision as soon as slab intersection becomes empty
           if(tMin>tMax) return;
        }
    }

    *tCompare=as_type<uint>(tMin);
    threadgroup_barrier(mem_flags::mem_threadgroup);
    atomic_fetch_min_explicit(&tSharedMin[0], *tCompare, memory_order_relaxed);
    
}

simd_float3 getPlaneNormal(simd_float3 q, Box box){
    
    
    float epsilon=0.001;
    
    if (abs(q.x-(box.halfWidth.x+box.origin.x)) < epsilon){
        return simd_float3(1.0,0.0,0.0);
    }else if(abs(q.y-(box.halfWidth.y+box.origin.y))< epsilon){
        return simd_float3(0.0,1.0,0.0);
    }else if(abs(q.z-(box.halfWidth.z+box.origin.z))<epsilon){
        return simd_float3(0.0,0.0,1.0);
    }else if(abs(-q.x-(box.halfWidth.x-box.origin.x))<epsilon){
        return simd_float3(-1.0,0.0,0.0);
    }else if(abs(-q.y-(box.halfWidth.y-box.origin.y))<epsilon){
        return simd_float3(0.0,-1.0,0.0);
    }else if(abs(-q.z-(box.halfWidth.z-box.origin.z))<epsilon){
        return simd_float3(0.0,0.0,-1.0);
    }
    
    return simd_float3(0.0,0.0,0.0);
    
}

int grid3dToIndexMap(simd_uint3 coord, uint sizeX, uint sizeY, uint sizeZ){
    uint index=uint(coord.x)+uint(coord.z)*sizeX+uint(coord.y)*sizeX*sizeZ;
    return index;
    
}

simd_uint3 indexTo3DGridMap(uint index, uint sizeX, uint sizeY, uint sizeZ){
    
    uint x=index % sizeX;
    uint z=(index/sizeX)%sizeZ;
    uint y=index/(sizeX*sizeZ);
    
    return simd_uint3(x,y,z);
}
