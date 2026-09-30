//
//  DeformationCompute.metal
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

// Linear blend skinning in compute. Writes deformed position/normal/tangent
// streams consumed by the render passes with skinning disabled, so every pass
// (G-buffer, shadows, transparency, wireframe) sees identical geometry.
//
// Normals use the cofactor matrix (equivalent to inverse-transpose up to a
// uniform factor removed by normalization), which stays correct under
// non-uniform joint scale — unlike the legacy vertex-shader path.
kernel void deformSkinLBS(
    const device simd_float4 *inPositions [[buffer(deformationPassInPositionIndex)]],
    const device simd_float4 *inNormals [[buffer(deformationPassInNormalIndex)]],
    const device simd_float4 *inTangents [[buffer(deformationPassInTangentIndex)]],
    const device ushort4 *jointIndices [[buffer(deformationPassJointIdIndex)]],
    const device simd_float4 *jointWeights [[buffer(deformationPassJointWeightsIndex)]],
    const device simd_float4x4 *jointMatrices [[buffer(deformationPassJointTransformIndex)]],
    device simd_float4 *outPositions [[buffer(deformationPassOutPositionIndex)]],
    device simd_float4 *outNormals [[buffer(deformationPassOutNormalIndex)]],
    device simd_float4 *outTangents [[buffer(deformationPassOutTangentIndex)]],
    const device simd_float4 *morphPositionDeltas [[buffer(deformationPassMorphPositionDeltaIndex)]],
    const device simd_float4 *morphNormalDeltas [[buffer(deformationPassMorphNormalDeltaIndex)]],
    constant DeformationPassParams &params [[buffer(deformationPassParamsIndex)]],
    uint vid [[thread_position_in_grid]])
{
    if (vid >= params.vertexCount) {
        return;
    }

    simd_float4 position = inPositions[vid];
    simd_float4 normal = inNormals[vid];
    simd_float4 tangent = inTangents[vid];

    if (params.hasMorphDeltas != 0) {
        position.xyz += morphPositionDeltas[vid].xyz;
        float3 morphedNormal = normal.xyz + morphNormalDeltas[vid].xyz;
        float morphedLength = length(morphedNormal);
        if (morphedLength > 0.0f) {
            normal.xyz = morphedNormal / morphedLength;
        }
    }

    ushort4 joints = jointIndices[vid];
    simd_float4 weights = jointWeights[vid];
    float weightSum = weights.x + weights.y + weights.z + weights.w;

    if (weightSum <= 0.0001f) {
        outPositions[vid] = position;
        outNormals[vid] = normal;
        outTangents[vid] = tangent;
        return;
    }

    simd_float4x4 skinMatrix =
        weights.x * jointMatrices[joints.x] +
        weights.y * jointMatrices[joints.y] +
        weights.z * jointMatrices[joints.z] +
        weights.w * jointMatrices[joints.w];

    float3x3 skinRotation = float3x3(
        skinMatrix.columns[0].xyz,
        skinMatrix.columns[1].xyz,
        skinMatrix.columns[2].xyz
    );
    float3x3 cofactor = float3x3(
        cross(skinRotation[1], skinRotation[2]),
        cross(skinRotation[2], skinRotation[0]),
        cross(skinRotation[0], skinRotation[1])
    );

    float3 skinnedNormal = cofactor * normal.xyz;
    float normalLength = length(skinnedNormal);
    if (normalLength > 0.0f) {
        skinnedNormal /= normalLength;
    }

    float3 skinnedTangent = skinRotation * tangent.xyz;
    float tangentLength = length(skinnedTangent);
    if (tangentLength > 0.0f) {
        skinnedTangent /= tangentLength;
    }

    outPositions[vid] = simd_float4(
        (skinMatrix * simd_float4(position.xyz, 1.0f)).xyz, position.w
    );
    outNormals[vid] = simd_float4(skinnedNormal, normal.w);
    outTangents[vid] = simd_float4(skinnedTangent, tangent.w);
}

// MARK: - Dual-quaternion skinning

static inline float4 deformQuatFromMatrix(float3x3 m)
{
    // Branching Shepperd-style conversion, robust for all rotations.
    float trace = m[0][0] + m[1][1] + m[2][2];
    float4 q;
    if (trace > 0.0f) {
        float s = sqrt(trace + 1.0f) * 2.0f;
        q = float4((m[1][2] - m[2][1]) / s,
                   (m[2][0] - m[0][2]) / s,
                   (m[0][1] - m[1][0]) / s,
                   0.25f * s);
    } else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) {
        float s = sqrt(1.0f + m[0][0] - m[1][1] - m[2][2]) * 2.0f;
        q = float4(0.25f * s,
                   (m[1][0] + m[0][1]) / s,
                   (m[2][0] + m[0][2]) / s,
                   (m[1][2] - m[2][1]) / s);
    } else if (m[1][1] > m[2][2]) {
        float s = sqrt(1.0f + m[1][1] - m[0][0] - m[2][2]) * 2.0f;
        q = float4((m[1][0] + m[0][1]) / s,
                   0.25f * s,
                   (m[2][1] + m[1][2]) / s,
                   (m[2][0] - m[0][2]) / s);
    } else {
        float s = sqrt(1.0f + m[2][2] - m[0][0] - m[1][1]) * 2.0f;
        q = float4((m[2][0] + m[0][2]) / s,
                   (m[2][1] + m[1][2]) / s,
                   0.25f * s,
                   (m[0][1] - m[1][0]) / s);
    }
    return normalize(q);
}

static inline float4 deformQuatMul(float4 a, float4 b)
{
    return float4(a.w * b.xyz + b.w * a.xyz + cross(a.xyz, b.xyz),
                  a.w * b.w - dot(a.xyz, b.xyz));
}

static inline float3 deformQuatRotate(float4 q, float3 v)
{
    return v + 2.0f * cross(q.xyz, cross(q.xyz, v) + q.w * v);
}

// Converts the joint matrix palette (world * inverseBind, possibly carrying
// per-joint scale) into rotation/translation dual quaternions plus a factored
// per-axis scale. One thread per joint.
kernel void deformDualQuatPalette(
    const device simd_float4x4 *jointMatrices [[buffer(dualQuatPaletteJointTransformIndex)]],
    device JointDualQuat *outPalette [[buffer(dualQuatPaletteOutIndex)]],
    constant DualQuatPaletteParams &params [[buffer(dualQuatPaletteParamsIndex)]],
    uint jointId [[thread_position_in_grid]])
{
    if (jointId >= params.jointCount) {
        return;
    }

    simd_float4x4 m = jointMatrices[jointId];
    float3 c0 = m.columns[0].xyz;
    float3 c1 = m.columns[1].xyz;
    float3 c2 = m.columns[2].xyz;

    float3 scale = float3(length(c0), length(c1), length(c2));
    float3 safeScale = max(scale, float3(1e-6f));
    float3x3 rotation = float3x3(c0 / safeScale.x, c1 / safeScale.y, c2 / safeScale.z);
    // A negative determinant (mirrored bind) cannot be represented by a
    // quaternion; fold the flip into the scale on one axis.
    if (determinant(rotation) < 0.0f) {
        rotation[0] = -rotation[0];
        scale.x = -scale.x;
    }

    float4 real = deformQuatFromMatrix(rotation);
    float3 translation = m.columns[3].xyz;
    float4 dual = 0.5f * deformQuatMul(float4(translation, 0.0f), real);

    JointDualQuat entry;
    entry.real = real;
    entry.dual = dual;
    entry.scale = simd_float4(scale, 0.0f);
    outPalette[jointId] = entry;
}

// Dual-quaternion linear blending: volume-preserving rotation blend (fixes
// LBS candy-wrapper collapse), linear blend of the factored per-joint scale.
kernel void deformSkinDQS(
    const device simd_float4 *inPositions [[buffer(deformationPassInPositionIndex)]],
    const device simd_float4 *inNormals [[buffer(deformationPassInNormalIndex)]],
    const device simd_float4 *inTangents [[buffer(deformationPassInTangentIndex)]],
    const device ushort4 *jointIndices [[buffer(deformationPassJointIdIndex)]],
    const device simd_float4 *jointWeights [[buffer(deformationPassJointWeightsIndex)]],
    const device JointDualQuat *palette [[buffer(deformationPassJointTransformIndex)]],
    device simd_float4 *outPositions [[buffer(deformationPassOutPositionIndex)]],
    device simd_float4 *outNormals [[buffer(deformationPassOutNormalIndex)]],
    device simd_float4 *outTangents [[buffer(deformationPassOutTangentIndex)]],
    const device simd_float4 *morphPositionDeltas [[buffer(deformationPassMorphPositionDeltaIndex)]],
    const device simd_float4 *morphNormalDeltas [[buffer(deformationPassMorphNormalDeltaIndex)]],
    constant DeformationPassParams &params [[buffer(deformationPassParamsIndex)]],
    uint vid [[thread_position_in_grid]])
{
    if (vid >= params.vertexCount) {
        return;
    }

    simd_float4 position = inPositions[vid];
    simd_float4 normal = inNormals[vid];
    simd_float4 tangent = inTangents[vid];

    if (params.hasMorphDeltas != 0) {
        position.xyz += morphPositionDeltas[vid].xyz;
        float3 morphedNormal = normal.xyz + morphNormalDeltas[vid].xyz;
        float morphedLength = length(morphedNormal);
        if (morphedLength > 0.0f) {
            normal.xyz = morphedNormal / morphedLength;
        }
    }

    ushort4 joints = jointIndices[vid];
    simd_float4 weights = jointWeights[vid];
    float weightSum = weights.x + weights.y + weights.z + weights.w;

    if (weightSum <= 0.0001f) {
        outPositions[vid] = position;
        outNormals[vid] = normal;
        outTangents[vid] = tangent;
        return;
    }

    JointDualQuat dq0 = palette[joints.x];
    JointDualQuat dq1 = palette[joints.y];
    JointDualQuat dq2 = palette[joints.z];
    JointDualQuat dq3 = palette[joints.w];

    // Antipodality: hemisphere-align every quaternion with the first
    // (highest-weight) influence before blending.
    float s1 = dot(dq0.real, dq1.real) < 0.0f ? -1.0f : 1.0f;
    float s2 = dot(dq0.real, dq2.real) < 0.0f ? -1.0f : 1.0f;
    float s3 = dot(dq0.real, dq3.real) < 0.0f ? -1.0f : 1.0f;

    float4 real = weights.x * dq0.real
        + weights.y * s1 * dq1.real
        + weights.z * s2 * dq2.real
        + weights.w * s3 * dq3.real;
    float4 dual = weights.x * dq0.dual
        + weights.y * s1 * dq1.dual
        + weights.z * s2 * dq2.dual
        + weights.w * s3 * dq3.dual;
    float3 scale = weights.x * dq0.scale.xyz
        + weights.y * dq1.scale.xyz
        + weights.z * dq2.scale.xyz
        + weights.w * dq3.scale.xyz;

    float realLength = max(length(real), 1e-6f);
    real /= realLength;
    dual /= realLength;

    float3 translation = 2.0f * (real.w * dual.xyz - dual.w * real.xyz + cross(real.xyz, dual.xyz));
    float3 safeScale = sign(scale) * max(abs(scale), float3(1e-6f));

    float3 skinnedPosition = deformQuatRotate(real, position.xyz * scale) + translation;
    float3 skinnedNormal = deformQuatRotate(real, normal.xyz / safeScale);
    float3 skinnedTangent = deformQuatRotate(real, tangent.xyz * scale);

    float normalLength = length(skinnedNormal);
    if (normalLength > 0.0f) { skinnedNormal /= normalLength; }
    float tangentLength = length(skinnedTangent);
    if (tangentLength > 0.0f) { skinnedTangent /= tangentLength; }

    outPositions[vid] = simd_float4(skinnedPosition, position.w);
    outNormals[vid] = simd_float4(skinnedNormal, normal.w);
    outTangents[vid] = simd_float4(skinnedTangent, tangent.w);
}

// MARK: - Direct Delta Mush

static inline float3x3 deformInverse3x3(float3x3 m, thread bool &ok)
{
    float3 r0 = cross(m[1], m[2]);
    float det = dot(m[0], r0);
    if (abs(det) < 1e-12f) {
        ok = false;
        return float3x3(1.0f);
    }
    ok = true;
    float invDet = 1.0f / det;
    // Rows of the inverse are the cofactor columns over the determinant.
    float3 r1 = cross(m[2], m[0]);
    float3 r2 = cross(m[0], m[1]);
    return float3x3(
        float3(r0.x, r1.x, r2.x) * invDet,
        float3(r0.y, r1.y, r2.y) * invDet,
        float3(r0.z, r1.z, r2.z) * invDet
    );
}

static inline float deformFrobenius(float3x3 m)
{
    return sqrt(dot(m[0], m[0]) + dot(m[1], m[1]) + dot(m[2], m[2]));
}

// Scaled Newton polar iteration X <- 0.5 (z X + (1/z) X^-T) with the norm
// ratio scaling z = sqrt(|X^-1| / |X|): converges to the rotation factor in
// a few steps even for the small/ill-scaled covariance matrices DDM builds.
static inline float3x3 deformPolarRotation(float3x3 m)
{
    float3x3 x = m;
    for (int i = 0; i < 8; i++) {
        bool ok = true;
        float3x3 inv = deformInverse3x3(x, ok);
        if (!ok) { break; }
        float3x3 invT = float3x3(
            float3(inv[0][0], inv[1][0], inv[2][0]),
            float3(inv[0][1], inv[1][1], inv[2][1]),
            float3(inv[0][2], inv[1][2], inv[2][2])
        );
        float z = sqrt(max(deformFrobenius(invT), 1e-12f) / max(deformFrobenius(x), 1e-12f));
        x = 0.5f * (z * x + (1.0f / z) * invT);
    }
    return x;
}

static inline simd_float4x4 deformExpandSymmetric(const device float *m)
{
    // [a00,a01,a02,a03,a11,a12,a13,a22,a23,a33] upper triangle, row-major.
    return simd_float4x4(
        simd_float4(m[0], m[1], m[2], m[3]),
        simd_float4(m[1], m[4], m[5], m[6]),
        simd_float4(m[2], m[5], m[7], m[8]),
        simd_float4(m[3], m[6], m[8], m[9])
    );
}

// Direct Delta Mush (v1): Psi = sum_j M_j * Omega_ij, rotation from the polar
// decomposition of Q - q p^T, translation t = q - R p, output R * u + t.
kernel void deformSkinDDM(
    const device simd_float4 *inPositions [[buffer(deformationPassInPositionIndex)]],
    const device simd_float4 *inNormals [[buffer(deformationPassInNormalIndex)]],
    const device simd_float4 *inTangents [[buffer(deformationPassInTangentIndex)]],
    const device simd_float4x4 *jointMatrices [[buffer(deformationPassJointTransformIndex)]],
    const device DDMOmegaEntry *omegas [[buffer(deformationPassOmegaIndex)]],
    device simd_float4 *outPositions [[buffer(deformationPassOutPositionIndex)]],
    device simd_float4 *outNormals [[buffer(deformationPassOutNormalIndex)]],
    device simd_float4 *outTangents [[buffer(deformationPassOutTangentIndex)]],
    const device simd_float4 *morphPositionDeltas [[buffer(deformationPassMorphPositionDeltaIndex)]],
    const device simd_float4 *morphNormalDeltas [[buffer(deformationPassMorphNormalDeltaIndex)]],
    constant DeformationPassParams &params [[buffer(deformationPassParamsIndex)]],
    uint vid [[thread_position_in_grid]])
{
    if (vid >= params.vertexCount) {
        return;
    }

    simd_float4 position = inPositions[vid];
    simd_float4 normal = inNormals[vid];
    simd_float4 tangent = inTangents[vid];

    if (params.hasMorphDeltas != 0) {
        position.xyz += morphPositionDeltas[vid].xyz;
        float3 morphedNormal = normal.xyz + morphNormalDeltas[vid].xyz;
        float morphedLength = length(morphedNormal);
        if (morphedLength > 0.0f) {
            normal.xyz = morphedNormal / morphedLength;
        }
    }

    simd_float4x4 psi = simd_float4x4(0.0f);
    bool hasInfluence = false;
    for (uint slot = 0; slot < DDM_OMEGAS_PER_VERTEX; slot++) {
        const device DDMOmegaEntry &entry = omegas[vid * DDM_OMEGAS_PER_VERTEX + slot];
        if (entry.jointIndex == 0xFFFFFFFFu) {
            continue;
        }
        hasInfluence = true;
        psi += jointMatrices[entry.jointIndex] * deformExpandSymmetric(entry.m);
    }

    if (!hasInfluence) {
        outPositions[vid] = position;
        outNormals[vid] = normal;
        outTangents[vid] = tangent;
        return;
    }

    // psi columns hold [Q q; p^T w]: Q the 3x3 block, q the last column,
    // p the last row (from the symmetric homogeneous outer products).
    float3x3 qBlock = float3x3(psi.columns[0].xyz, psi.columns[1].xyz, psi.columns[2].xyz);
    float3 qVec = psi.columns[3].xyz;
    float3 pVec = float3(psi.columns[0].w, psi.columns[1].w, psi.columns[2].w);
    float wSum = psi.columns[3].w;
    if (wSum > 1e-6f) {
        qBlock *= 1.0f / wSum;
        qVec /= wSum;
        pVec /= wSum;
    }

    // Q - q p^T (outer product subtracts the centroid correlation).
    float3x3 crossCov = qBlock - float3x3(
        qVec * pVec.x,
        qVec * pVec.y,
        qVec * pVec.z
    );

    float3x3 rotation = deformPolarRotation(crossCov);
    float3 translation = qVec - rotation * pVec;

    float3 skinnedPosition = rotation * position.xyz + translation;
    float3 skinnedNormal = rotation * normal.xyz;
    float3 skinnedTangent = rotation * tangent.xyz;

    outPositions[vid] = simd_float4(skinnedPosition, position.w);
    outNormals[vid] = simd_float4(skinnedNormal, normal.w);
    outTangents[vid] = simd_float4(skinnedTangent, tangent.w);
}

// MARK: - Morph targets

kernel void deformClearMorphDeltas(
    device simd_float4 *positionDeltas [[buffer(morphPassPositionDeltaIndex)]],
    device simd_float4 *normalDeltas [[buffer(morphPassNormalDeltaIndex)]],
    constant MorphPassParams &params [[buffer(morphPassParamsIndex)]],
    uint vid [[thread_position_in_grid]])
{
    if (vid >= params.vertexCount) {
        return;
    }
    positionDeltas[vid] = simd_float4(0.0f);
    normalDeltas[vid] = simd_float4(0.0f);
}

// Accumulates one target's sparse deltas, scaled by weight. Entries within a
// target touch unique vertices, so threads never collide inside a dispatch;
// consecutive target dispatches are ordered by Metal's hazard tracking.
kernel void deformMorphAccumulate(
    const device MorphSparseEntry *entries [[buffer(morphPassEntriesIndex)]],
    device simd_float4 *positionDeltas [[buffer(morphPassPositionDeltaIndex)]],
    device simd_float4 *normalDeltas [[buffer(morphPassNormalDeltaIndex)]],
    constant MorphPassParams &params [[buffer(morphPassParamsIndex)]],
    uint tid [[thread_position_in_grid]])
{
    if (tid >= params.entryCount) {
        return;
    }
    MorphSparseEntry entry = entries[params.entryOffset + tid];
    if (entry.vertexIndex >= params.vertexCount) {
        return;
    }

    float3 dPosition = float3(
        (float)as_type<half>(entry.dPosition[0]),
        (float)as_type<half>(entry.dPosition[1]),
        (float)as_type<half>(entry.dPosition[2])
    );
    float3 dNormal = float3(
        (float)as_type<half>(entry.dNormal[0]),
        (float)as_type<half>(entry.dNormal[1]),
        (float)as_type<half>(entry.dNormal[2])
    );

    positionDeltas[entry.vertexIndex].xyz += dPosition * params.weightTimesScale;
    normalDeltas[entry.vertexIndex].xyz += dNormal * params.weightTimesScale;
}
