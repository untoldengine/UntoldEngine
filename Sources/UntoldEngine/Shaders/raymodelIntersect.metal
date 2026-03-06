//
//  raymodelIntersect.metal
//  UntoldEngineRTX
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
#include "ShaderStructs.h"
#include "ShadersUtils.h"

using namespace metal;
using namespace raytracing;


kernel void rayModelIntersectKernel(uint2 tid [[thread_position_in_grid]],
                             instance_acceleration_structure accelerationStructure [[buffer(rayModelAccelStructIndex)]],
                             device MTLAccelerationStructureInstanceDescriptor   *instances                 [[buffer(rayModelBufferInstanceIndex)]],
                             constant simd_float3 &origin [[buffer(rayModelOriginIndex)]],
                             constant simd_float3 &direction [[buffer(rayModelDirectionIndex)]],
                             device RayModelPickOutput &pickOutput [[buffer(rayModelInstanceHitIndex)]]) {


    ray ray;
    ray.origin = origin;
    ray.direction = direction;
    ray.min_distance = 1e-4f;
    ray.max_distance = INFINITY;

    intersector<triangle_data,instancing> i;
    typename intersector<triangle_data,instancing>::result_type intersection;

    // Get the closest intersection, not the first intersection. This is the default, but
    // the sample adjusts this property below when it casts shadow rays.
    i.accept_any_intersection(false);

    // Check for intersection between the ray and the acceleration structure. If the sample
    // isn't using intersection functions, it doesn't need to include one.
    intersection=i.intersect(ray,accelerationStructure);

    // Stop if the ray didn't hit anything and has bounced out of the scene.
//    if (intersection.type==intersection_type::none){
//
//    }

    //check for an intersection with a triangle, if so, shade it
    if (intersection.type == intersection_type::triangle) {
        pickOutput.instanceHit = intersection.instance_id;
        pickOutput.distance = intersection.distance;
        pickOutput.triangleIndex = intersection.primitive_id;
        pickOutput.barycentric = intersection.triangle_barycentric_coord;
    } else {
        pickOutput.instanceHit = -1;
        pickOutput.distance = INFINITY;
        pickOutput.triangleIndex = 0;
        pickOutput.barycentric = simd_float2(0.0, 0.0);
    }
}
