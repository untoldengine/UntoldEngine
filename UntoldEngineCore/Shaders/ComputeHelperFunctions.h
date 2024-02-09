//
//  ComputeHelperFunctions.h
//  UntoldEngine
//
//  Created by Harold Serrano on 11/27/23.
//

#ifndef ComputeHelperFunctions_h
#define ComputeHelperFunctions_h

using namespace metal;

//globals
constant int chunkSize=32;
constant float scale=0.1;
constant float planeScale=chunkSize*scale*2.0;
constant simd_float3 modelOffset=simd_float3(-(planeScale/2.0 - scale),scale,-(planeScale/2.0 - scale) );
constant simd_float3 planeOffset=simd_float3(planeScale/2.0,0.0,planeScale/2.0);


struct Box{
    simd::float3 origin;
    simd::float3 halfWidth;
};

struct Plane{
    simd::float3 normal;
    float d;
};

struct Ray{
    simd::float3 origin;
    simd::float3 direction;
};

void swap(thread float &a, thread float &b);

void rayIntersectsPlane(thread Plane &uPlane, thread Ray &uRay, device atomic_uint *tPlaneSharedMin, thread uint *tCompare);

bool lazyRayIntersectBox(thread Box &uBox, thread Ray &uRay);

void rayIntersectsBox(thread Box &uBox, thread Ray &uRay,device atomic_uint *tSharedMin, thread uint *tCompare);

simd_float3 getPlaneNormal(simd_float3 q, Box box);

int grid3dToIndexMap(simd_uint3 coord, uint sizeX, uint sizeY, uint sizeZ);

simd_uint3 indexTo3DGridMap(uint index, uint sizeX, uint sizeY, uint sizeZ);

#endif /* ComputeHelperFunctions_h */
