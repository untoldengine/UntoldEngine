//
//  MuscleCompute.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// Volumetric muscles: XPBD membrane cages (fiber / cross-fiber / shear edge
// constraints on a closed tube of rings) with one exact volume constraint per
// muscle, simulated in model space, attached to the joint palette, colliding
// against bone capsules, and wrapped onto the skinned surface as a delta
// relative to the passive reference pose. Runs inside the deformation pass,
// after skinning.
//
// Solver: small steps (several substeps, one iteration each) so Lagrange
// multipliers start at zero every substep. Edge corrections are gathered per
// particle (prebuilt CSR adjacency, no atomics) and averaged (Jacobi); the
// volume constraint is a single constraint per muscle, so every particle can
// evaluate the exact same delta lambda from the shared gradient buffer.

static inline float3 muscleClosestOnSegment(float3 p, float3 a, float3 b)
{
    float3 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-12f), 0.0f, 1.0f);
    return a + t * ab;
}

// Pushes `x` out of a bone capsule. The push-out is partial (half the
// penetration per substep) so a cage authored overlapping its bone settles
// instead of being kicked; `collided` lets the caller kill the particle's
// velocity (inelastic contact).
static inline float3 muscleResolveCapsule(float3 x, float4 c0, float4 c1, thread bool &collided)
{
    float radius = c0.w;
    if (radius <= 0.0f) {
        return x;
    }
    float3 q = muscleClosestOnSegment(x, c0.xyz, c1.xyz);
    float3 d = x - q;
    float len = length(d);
    if (len >= radius) {
        return x;
    }
    collided = true;
    float3 direction;
    if (len < 1e-6f) {
        // On the axis: push along any direction perpendicular to the bone.
        float3 axis = normalize(c1.xyz - c0.xyz + float3(1e-6f, 0.0f, 0.0f));
        float3 side = abs(axis.y) < 0.9f ? float3(0.0f, 1.0f, 0.0f) : float3(1.0f, 0.0f, 0.0f);
        direction = normalize(cross(axis, side));
    } else {
        direction = d / len;
    }
    return x + direction * (0.5f * (radius - len));
}

// Passive reference: where the particle would sit if the muscle simply followed
// its attachments at rest length (axis interpolation + rotated radial offset).
// The skin wrap applies (simulated - reference), so a relaxed muscle adds
// nothing on top of skinning.
static inline float3 muscleReferencePosition(MuscleParticleInfo info, MuscleFrameParams m)
{
    float t = info.restPosition.w;
    float3 radial = (m.referenceRotation * float4(info.restRadial.xyz, 0.0f)).xyz;
    return m.originCurrent.xyz + t * (m.insertionCurrent.xyz - m.originCurrent.xyz) + radial;
}

kernel void musclePredict(
    device simd_float4 *positions [[buffer(musclePassPositionsIndex)]],
    device simd_float4 *prevPositions [[buffer(musclePassPrevPositionsIndex)]],
    const device MuscleParticleInfo *infos [[buffer(musclePassParticleInfoIndex)]],
    const device MuscleFrameParams *muscles [[buffer(musclePassMuscleParamsIndex)]],
    constant MuscleSimParams &params [[buffer(musclePassParamsIndex)]],
    uint pid [[thread_position_in_grid]])
{
    if (pid >= params.particleCount) {
        return;
    }
    MuscleParticleInfo info = infos[pid];
    MuscleFrameParams m = muscles[info.muscleIndex];
    simd_float4 x4 = positions[pid];
    float3 x = x4.xyz;
    float3 prev = prevPositions[pid].xyz;
    prevPositions[pid] = simd_float4(x, 0.0f);

    if (info.attachment == MUSCLE_ATTACHMENT_ORIGIN) {
        positions[pid] = simd_float4((m.originJoint * simd_float4(info.restPosition.xyz, 1.0f)).xyz, 0.0f);
        return;
    }
    if (info.attachment == MUSCLE_ATTACHMENT_INSERTION) {
        positions[pid] = simd_float4((m.insertionJoint * simd_float4(info.restPosition.xyz, 1.0f)).xyz, 0.0f);
        return;
    }
    if (info.attachment == MUSCLE_ATTACHMENT_CENTER) {
        return;
    }

    float dt = params.dt;
    float3 v = (x - prev) / dt;
    v *= max(0.0f, 1.0f - m.damping * dt);
    v += params.gravity.xyz * dt;
    float speed = length(v);
    if (speed > params.maxVelocity) {
        v *= params.maxVelocity / speed;
    }
    positions[pid] = simd_float4(x + v * dt, x4.w);
}

// Volume gradient of the closed cage at each particle: the sum of
// (b x c) / 6 over its incident outward triangles. w carries invMass *
// |gradient|^2 so the solve can total the constraint's mass-weighted norm.
kernel void muscleVolumeGradient(
    const device simd_float4 *positions [[buffer(musclePassPositionsIndex)]],
    const device MuscleSurfaceTriangle *triangles [[buffer(musclePassTrianglesIndex)]],
    const device uint *triOffsets [[buffer(musclePassParticleTriOffsetsIndex)]],
    const device uint *triList [[buffer(musclePassParticleTriListIndex)]],
    device simd_float4 *gradients [[buffer(musclePassGradientsIndex)]],
    constant MuscleSimParams &params [[buffer(musclePassParamsIndex)]],
    uint pid [[thread_position_in_grid]])
{
    if (pid >= params.particleCount) {
        return;
    }
    float3 gradient = float3(0.0f);
    for (uint k = triOffsets[pid]; k < triOffsets[pid + 1]; k++) {
        MuscleSurfaceTriangle tri = triangles[triList[k]];
        float3 pa = positions[tri.a].xyz;
        float3 pb = positions[tri.b].xyz;
        float3 pc = positions[tri.c].xyz;
        if (tri.a == pid) {
            gradient += cross(pb, pc);
        } else if (tri.b == pid) {
            gradient += cross(pc, pa);
        } else {
            gradient += cross(pa, pb);
        }
    }
    gradient /= 6.0f;
    float invMass = positions[pid].w;
    gradients[pid] = simd_float4(gradient, invMass * dot(gradient, gradient));
}

kernel void muscleSolve(
    const device simd_float4 *src [[buffer(musclePassPositionsIndex)]],
    device simd_float4 *dst [[buffer(musclePassPositionsOutIndex)]],
    device simd_float4 *prevPositions [[buffer(musclePassPrevPositionsIndex)]],
    const device MuscleParticleInfo *infos [[buffer(musclePassParticleInfoIndex)]],
    const device MuscleEdge *edges [[buffer(musclePassEdgesIndex)]],
    const device uint *edgeOffsets [[buffer(musclePassParticleEdgeOffsetsIndex)]],
    const device uint *edgeList [[buffer(musclePassParticleEdgeListIndex)]],
    const device simd_float4 *gradients [[buffer(musclePassGradientsIndex)]],
    const device MuscleFrameParams *muscles [[buffer(musclePassMuscleParamsIndex)]],
    constant MuscleSimParams &params [[buffer(musclePassParamsIndex)]],
    uint pid [[thread_position_in_grid]])
{
    if (pid >= params.particleCount) {
        return;
    }
    simd_float4 x4 = src[pid];
    MuscleParticleInfo info = infos[pid];

    if (info.attachment == MUSCLE_ATTACHMENT_CENTER) {
        // Follow the ring that starts right after this particle.
        float3 mean = float3(0.0f);
        for (uint slot = 1; slot <= info.ringSegments; slot++) {
            mean += src[pid + slot].xyz;
        }
        dst[pid] = simd_float4(mean / max((float)info.ringSegments, 1.0f), 0.0f);
        return;
    }

    float wi = x4.w;
    if (wi <= 0.0f) {
        dst[pid] = x4;
        return;
    }
    float3 x = x4.xyz;
    MuscleFrameParams m = muscles[info.muscleIndex];

    // Distance constraints, averaged over the particle's edges.
    float3 edgeCorrection = float3(0.0f);
    uint edgeCount = 0;
    for (uint k = edgeOffsets[pid]; k < edgeOffsets[pid + 1]; k++) {
        MuscleEdge e = edges[edgeList[k]];
        uint other = (e.a == pid) ? e.b : e.a;
        simd_float4 q4 = src[other];
        float3 d = x - q4.xyz;
        float len = length(d);
        if (len < 1e-7f) {
            continue;
        }
        float rest = e.restLength * mix(1.0f, m.fiberScale, e.fiber);
        float alpha = mix(m.crossAlpha, m.fiberAlpha, e.fiber);
        float denom = wi + q4.w + alpha;
        if (denom < 1e-9f) {
            continue;
        }
        float deltaLambda = -(len - rest) / denom;
        edgeCorrection += wi * deltaLambda * (d / len);
        edgeCount++;
    }
    if (edgeCount > 0) {
        x += edgeCorrection * (params.relaxation / (float)edgeCount);
    }

    // Volume constraint of the whole muscle: V = (1/3) sum p_i . grad_i over
    // the closed surface, one exact projection shared by all its particles.
    float volume = 0.0f;
    float denom = m.volumeAlpha;
    uint end = m.particleStart + m.particleCount;
    for (uint i = m.particleStart; i < end; i++) {
        simd_float4 g = gradients[i];
        volume += dot(src[i].xyz, g.xyz);
        denom += g.w;
    }
    volume /= 3.0f;
    if (denom > 1e-14f) {
        float deltaLambda = -(volume - m.restVolume) / denom;
        x += wi * deltaLambda * gradients[pid].xyz * params.relaxation;
    }

    bool collided = false;
    x = muscleResolveCapsule(x, m.capsuleA0, m.capsuleA1, collided);
    x = muscleResolveCapsule(x, m.capsuleB0, m.capsuleB1, collided);
    if (collided) {
        prevPositions[pid] = simd_float4(x, 0.0f);
    }
    dst[pid] = simd_float4(x, wi);
}

// Skin wrap: adds the bound tet's (simulated - reference) displacement to the
// already-skinned vertex and re-orients the normal/tangent with the tet's
// deformation gradient (cofactor for the normal), blended by the binding
// weight. Runs after the skinning kernels on the deformed streams in place.
kernel void muscleSkinWrap(
    device simd_float4 *positions [[buffer(musclePassSkinPositionsIndex)]],
    device simd_float4 *normals [[buffer(musclePassSkinNormalsIndex)]],
    device simd_float4 *tangents [[buffer(musclePassSkinTangentsIndex)]],
    const device MuscleSkinBinding *bindings [[buffer(musclePassSkinBindingIndex)]],
    const device simd_float4 *particles [[buffer(musclePassPositionsIndex)]],
    const device MuscleParticleInfo *infos [[buffer(musclePassParticleInfoIndex)]],
    const device MuscleTet *tets [[buffer(musclePassTetsIndex)]],
    const device MuscleFrameParams *muscles [[buffer(musclePassMuscleParamsIndex)]],
    constant MuscleSimParams &params [[buffer(musclePassParamsIndex)]],
    uint vid [[thread_position_in_grid]])
{
    if (vid >= params.skinVertexCount) {
        return;
    }
    MuscleSkinBinding binding = bindings[vid];
    if (binding.tetIndex == MUSCLE_SKIN_UNBOUND) {
        return;
    }
    MuscleTet tet = tets[binding.tetIndex];
    MuscleFrameParams m = muscles[tet.muscleIndex];
    float w = binding.weight * m.skinWeight;
    if (w <= 0.0f) {
        return;
    }

    uint4 v = tet.vertices;
    float3 x0 = particles[v.x].xyz;
    float3 x1 = particles[v.y].xyz;
    float3 x2 = particles[v.z].xyz;
    float3 x3 = particles[v.w].xyz;
    float3 r0 = muscleReferencePosition(infos[v.x], m);
    float3 r1 = muscleReferencePosition(infos[v.y], m);
    float3 r2 = muscleReferencePosition(infos[v.z], m);
    float3 r3 = muscleReferencePosition(infos[v.w], m);

    float4 b = binding.barycentric;
    float3 delta = b.x * (x0 - r0) + b.y * (x1 - r1) + b.z * (x2 - r2) + b.w * (x3 - r3);

    simd_float4 position = positions[vid];
    position.xyz += w * delta;
    positions[vid] = position;

    float3x3 dCur = float3x3(x1 - x0, x2 - x0, x3 - x0);
    float3x3 dRef = float3x3(r1 - r0, r2 - r0, r3 - r0);
    bool ok = true;
    float3x3 invRef = deformInverse3x3(dRef, ok);
    if (!ok) {
        return;
    }
    float3x3 f = dCur * invRef;
    float3x3 cofactor = float3x3(
        cross(f[1], f[2]),
        cross(f[2], f[0]),
        cross(f[0], f[1])
    );

    simd_float4 normal = normals[vid];
    float3 wrappedNormal = cofactor * normal.xyz;
    float normalLength = length(wrappedNormal);
    if (normalLength > 1e-8f) {
        wrappedNormal /= normalLength;
        float3 blended = mix(normal.xyz, wrappedNormal, w);
        float blendedLength = length(blended);
        if (blendedLength > 1e-8f) {
            normal.xyz = blended / blendedLength;
            normals[vid] = normal;
        }
    }

    simd_float4 tangent = tangents[vid];
    float3 wrappedTangent = f * tangent.xyz;
    float tangentLength = length(wrappedTangent);
    if (tangentLength > 1e-8f) {
        wrappedTangent /= tangentLength;
        float3 blended = mix(tangent.xyz, wrappedTangent, w);
        float blendedLength = length(blended);
        if (blendedLength > 1e-8f) {
            tangent.xyz = blended / blendedLength;
            tangents[vid] = tangent;
        }
    }
}
