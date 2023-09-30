//
//  U4DMathUtils.cpp
//  Copyright © 2017 Untold Engine Studios. All rights reserved.
//
//  Created by Harold Serrano on 3/5/23.
//

#include "U4DMathUtils.h"
#include <assert.h>
#include <stdlib.h>

uint32_t seed_lo, seed_hi;

static float inline F16ToF32(const __fp16 *address) {
    return *address;
}

float AAPL_SIMD_OVERLOAD float32_from_float16(uint16_t i) {
    return F16ToF32((__fp16 *)&i);
}

static inline void F32ToF16(float F32, __fp16 *F16Ptr) {
    *F16Ptr = F32;
}

uint16_t AAPL_SIMD_OVERLOAD float16_from_float32(float f) {
    uint16_t f16;
    F32ToF16(f, (__fp16 *)&f16);
    return f16;
}

vector_float3 AAPL_SIMD_OVERLOAD generate_random_vector(float min, float max)
{
    vector_float3 rand;

    float range = max - min;
    rand.x = ((double)random() / (double) (0x7FFFFFFF)) * range + min;
    rand.y = ((double)random() / (double) (0x7FFFFFFF)) * range + min;
    rand.z = ((double)random() / (double) (0x7FFFFFFF)) * range + min;

    return rand;
}

void AAPL_SIMD_OVERLOAD seedRand(uint32_t seed) {
    seed_lo = seed; seed_hi = ~seed;
}

int32_t AAPL_SIMD_OVERLOAD randi(void) {
    seed_hi = (seed_hi<<16) + (seed_hi>>16);
    seed_hi += seed_lo; seed_lo += seed_hi;
    return seed_hi;
}

float AAPL_SIMD_OVERLOAD randf(float x) {
    return (x * randi() / (float)0x7FFFFFFF);
}

float AAPL_SIMD_OVERLOAD degrees_from_radians(float radians) {
    return (radians / M_PI) * 180;
}

float AAPL_SIMD_OVERLOAD radians_from_degrees(float degrees) {
    return (degrees / 180) * M_PI;
}

static vector_float3 AAPL_SIMD_OVERLOAD vector_make(float x, float y, float z) {
    return (vector_float3){ x, y, z };
}

vector_float3 AAPL_SIMD_OVERLOAD vector_lerp(vector_float3 v0, vector_float3 v1, float t) {
    return ((1 - t) * v0) + (t * v1);
}

vector_float4 AAPL_SIMD_OVERLOAD vector_lerp(vector_float4 v0, vector_float4 v1, float t) {
    return ((1 - t) * v0) + (t * v1);
}

//------------------------------------------------------------------------------
// matrix_make_rows takes input data with rows of elements.
// This way, the calling code matrix data can look like the rows
// of a matrix made for transforming column vectors.

// Indices are m<column><row>
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_make_rows(
                                   float m00, float m10, float m20,
                                   float m01, float m11, float m21,
                                   float m02, float m12, float m22) {
    return (matrix_float3x3){ {
            { m00, m01, m02 },      // each line here provides column data
            { m10, m11, m12 },
            { m20, m21, m22 } } };
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_make_rows(
                                   float m00, float m10, float m20, float m30,
                                   float m01, float m11, float m21, float m31,
                                   float m02, float m12, float m22, float m32,
                                   float m03, float m13, float m23, float m33) {
    return (matrix_float4x4){ {
        { m00, m01, m02, m03 },     // each line here provides column data
        { m10, m11, m12, m13 },
        { m20, m21, m22, m23 },
        { m30, m31, m32, m33 } } };
}

// each arg is a column vector
matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_make_columns(
                                   vector_float3 col0,
                                   vector_float3 col1,
                                   vector_float3 col2) {
    return (matrix_float3x3){ col0, col1, col2 };
}

// each arg is a column vector
matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_make_columns(
                                   vector_float4 col0,
                                   vector_float4 col1,
                                   vector_float4 col2,
                                   vector_float4 col3) {
    return (matrix_float4x4){ col0, col1, col2, col3 };
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_from_quaternion(quaternion_float q) {
    float xx = q.x * q.x;
    float xy = q.x * q.y;
    float xz = q.x * q.z;
    float xw = q.x * q.w;
    float yy = q.y * q.y;
    float yz = q.y * q.z;
    float yw = q.y * q.w;
    float zz = q.z * q.z;
    float zw = q.z * q.w;

    // indices are m<column><row>
    float m00 = 1 - 2 * (yy + zz);
    float m10 = 2 * (xy - zw);
    float m20 = 2 * (xz + yw);

    float m01 = 2 * (xy + zw);
    float m11 = 1 - 2 * (xx + zz);
    float m21 = 2 * (yz - xw);

    float m02 = 2 * (xz - yw);
    float m12 = 2 * (yz + xw);
    float m22 = 1 - 2 * (xx + yy);

    return matrix_make_rows(m00, m10, m20,
                            m01, m11, m21,
                            m02, m12, m22);
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_rotation(float radians, vector_float3 axis) {
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;
    return matrix_make_rows(    ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st,
                            y * x * ci + z * st,     ct + y * y * ci, y * z * ci - x * st,
                            z * x * ci - y * st, z * y * ci + x * st,     ct + z * z * ci );
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_rotation(float radians, float x, float y, float z) {
    return matrix3x3_rotation(radians, vector_make(x, y, z));
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_scale(float sx, float sy, float sz) {
    return matrix_make_rows(sx,  0,  0,
                             0, sy,  0,
                             0,  0, sz);
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_scale(vector_float3 s) {
    return matrix_make_rows(s.x,   0,   0,
                              0, s.y,   0,
                              0,   0, s.z);
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix3x3_upper_left(matrix_float4x4 m) {
    vector_float3 x = m.columns[0].xyz;
    vector_float3 y = m.columns[1].xyz;
    vector_float3 z = m.columns[2].xyz;
    return matrix_make_columns(x, y, z);
}

matrix_float3x3 AAPL_SIMD_OVERLOAD matrix_inverse_transpose(matrix_float3x3 m) {
    return matrix_invert(matrix_transpose(m));
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_from_quaternion(quaternion_float q) {

    float xx = q.x * q.x;
    float xy = q.x * q.y;
    float xz = q.x * q.z;
    float xw = q.x * q.w;
    float yy = q.y * q.y;
    float yz = q.y * q.z;
    float yw = q.y * q.w;
    float zz = q.z * q.z;
    float zw = q.z * q.w;

    // indices are m<column><row>
    float m00 = 1 - 2 * (yy + zz);
    float m10 = 2 * (xy - zw);
    float m20 = 2 * (xz + yw);

    float m01 = 2 * (xy + zw);
    float m11 = 1 - 2 * (xx + zz);
    float m21 = 2 * (yz - xw);

    float m02 = 2 * (xz - yw);
    float m12 = 2 * (yz + xw);
    float m22 = 1 - 2 * (xx + yy);

    matrix_float4x4 matrix = matrix_make_rows(m00, m10, m20, 0,
                                              m01, m11, m21, 0,
                                              m02, m12, m22, 0,
                                                0,   0,   0, 1);
    return matrix;
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_rotation(float radians, vector_float3 axis) {
    axis = vector_normalize(axis);
    float ct = cosf(radians);
    float st = sinf(radians);
    float ci = 1 - ct;
    float x = axis.x, y = axis.y, z = axis.z;
    return matrix_make_rows(
                        ct + x * x * ci, x * y * ci - z * st, x * z * ci + y * st, 0,
                    y * x * ci + z * st,     ct + y * y * ci, y * z * ci - x * st, 0,
                    z * x * ci - y * st, z * y * ci + x * st,     ct + z * z * ci, 0,
                                      0,                   0,                   0, 1);
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_rotation(float radians, float x, float y, float z) {
    return matrix4x4_rotation(radians, vector_make(x, y, z));
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_identity(void) {
    return matrix_make_rows(1, 0, 0, 0,
                            0, 1, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale(float sx, float sy, float sz) {
    return matrix_make_rows(sx,  0,  0, 0,
                             0, sy,  0, 0,
                             0,  0, sz, 0,
                             0,  0,  0, 1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale(vector_float3 s) {
    return matrix_make_rows(s.x,   0,   0, 0,
                              0, s.y,   0, 0,
                              0,   0, s.z, 0,
                              0,   0,   0, 1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_translation(float tx, float ty, float tz) {
    return matrix_make_rows(1, 0, 0, tx,
                            0, 1, 0, ty,
                            0, 0, 1, tz,
                            0, 0, 0,  1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_translation(vector_float3 t) {
    return matrix_make_rows(1, 0, 0, t.x,
                            0, 1, 0, t.y,
                            0, 0, 1, t.z,
                            0, 0, 0,   1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix4x4_scale_translation(vector_float3 s, vector_float3 t) {
    return matrix_make_rows(s.x,   0,   0, t.x,
                              0, s.y,   0, t.y,
                              0,   0, s.z, t.z,
                              0,   0,   0,   1 );
}


matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_left_hand(vector_float3 eye,
                                                            vector_float3 target,
                                                            vector_float3 up) {
    vector_float3 z = vector_normalize(target - eye);
    vector_float3 x = vector_normalize(vector_cross(up, z));
    vector_float3 y = vector_cross(z, x);
    vector_float3 t = vector_make(-vector_dot(x, eye), -vector_dot(y, eye), -vector_dot(z, eye));

    return matrix_make_rows(x.x, x.y, x.z, t.x,
                            y.x, y.y, y.z, t.y,
                            z.x, z.y, z.z, t.z,
                              0,   0,   0,   1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_left_hand(float eyeX, float eyeY, float eyeZ,
                                                            float centerX, float centerY, float centerZ,
                                                            float upX, float upY, float upZ) {
    vector_float3 eye = vector_make(eyeX, eyeY, eyeZ);
    vector_float3 center = vector_make(centerX, centerY, centerZ);
    vector_float3 up = vector_make(upX, upY, upZ);

    return matrix_look_at_left_hand(eye, center, up);
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_right_hand(vector_float3 eye,
                                                             vector_float3 target,
                                                             vector_float3 up) {
    vector_float3 z = vector_normalize(eye - target);
    vector_float3 x = vector_normalize(vector_cross(up, z));
    vector_float3 y = vector_cross(z, x);
    vector_float3 t = vector_make(-vector_dot(x, eye), -vector_dot(y, eye), -vector_dot(z, eye));

    return matrix_make_rows(x.x, x.y, x.z, t.x,
                            y.x, y.y, y.z, t.y,
                            z.x, z.y, z.z, t.z,
                              0,   0,   0,   1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_look_at_right_hand(float eyeX, float eyeY, float eyeZ,
                                                             float centerX, float centerY, float centerZ,
                                                             float upX, float upY, float upZ) {
    vector_float3 eye = vector_make(eyeX, eyeY, eyeZ);
    vector_float3 center = vector_make(centerX, centerY, centerZ);
    vector_float3 up = vector_make(upX, upY, upZ);

    return matrix_look_at_right_hand(eye, center, up);
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_ortho_left_hand(float left, float right, float bottom, float top, float nearZ, float farZ) {
    return matrix_make_rows(
        2 / (right - left),                  0,                  0, (left + right) / (left - right),
                         0, 2 / (top - bottom),                  0, (top + bottom) / (bottom - top),
                         0,                  0, 1 / (farZ - nearZ),          nearZ / (nearZ - farZ),
                         0,                  0,                  0,                               1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_ortho_right_hand(float left, float right, float bottom, float top, float nearZ, float farZ) {
    return matrix_make_rows(
        2 / (right - left),                  0,                   0, (left + right) / (left - right),
        0,                  2 / (top - bottom),                   0, (top + bottom) / (bottom - top),
        0,                                   0, -1 / (farZ - nearZ),          nearZ / (nearZ - farZ),
        0,                                   0,                   0,                               1 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_perspective_left_hand(float fovyRadians, float aspect, float nearZ, float farZ) {
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (farZ - nearZ);
    return matrix_make_rows(xs,  0,  0,           0,
                             0, ys,  0,           0,
                             0,  0, zs, -nearZ * zs,
                             0,  0,  1,           0 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_perspective_right_hand(float fovyRadians, float aspect, float nearZ, float farZ) {
    float ys = 1 / tanf(fovyRadians * 0.5);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    return matrix_make_rows(xs,  0,  0,          0,
                             0, ys,  0,          0,
                             0,  0, zs, nearZ * zs,
                             0,  0, -1,          0 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_perspective_frustum_right_hand(float l, float r, float b, float t, float n, float f) {
    return matrix_make_rows(
        2 * n / (r - l),                0, (r + l) / (r - l),                 0,
                     0,   2 * n / (t - b), (t + b) / (t - b),                 0,
                     0,                 0,      -f / (f - n), -f * n  / (f - n),
                     0,                 0,                -1,                 0 );
}

matrix_float4x4 AAPL_SIMD_OVERLOAD matrix_inverse_transpose(matrix_float4x4 m) {
    return matrix_invert(matrix_transpose(m));
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion(float x, float y, float z, float w) {
    return (quaternion_float){ x, y, z, w };
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion(vector_float3 v, float w) {
    return (quaternion_float){ v.x, v.y, v.z, w };
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_identity() {
    return quaternion(0, 0, 0, 1);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_axis_angle(vector_float3 axis, float radians) {
    float t = radians * 0.5;
    return quaternion(axis.x * sinf(t), axis.y * sinf(t), axis.z * sinf(t), cosf(t));
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_euler(vector_float3 euler) {
    quaternion_float q;

    float cx = cosf(euler.x / 2.f);
    float cy = cosf(euler.y / 2.f);
    float cz = cosf(euler.z / 2.f);
    float sx = sinf(euler.x / 2.f);
    float sy = sinf(euler.y / 2.f);
    float sz = sinf(euler.z / 2.f);

    q.w = cx * cy * cz + sx * sy * sz;
    q.x = sx * cy * cz - cx * sy * sz;
    q.y = cx * sy * cz + sx * cy * sz;
    q.z = cx * cy * sz - sx * sy * cz;

    return q;
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion(matrix_float3x3 m) {
    float m00 = m.columns[0].x;
    float m11 = m.columns[1].y;
    float m22 = m.columns[2].z;
    float x = sqrtf(1 + m00 - m11 - m22) * 0.5;
    float y = sqrtf(1 - m00 + m11 - m22) * 0.5;
    float z = sqrtf(1 - m00 - m11 + m22) * 0.5;
    float w = sqrtf(1 + m00 + m11 + m22) * 0.5;
    return quaternion(x, y, z, w);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion(matrix_float4x4 m) {
    return quaternion(matrix3x3_upper_left(m));
}

float AAPL_SIMD_OVERLOAD quaternion_length(quaternion_float q) {
    //  return sqrt(q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w);
    return vector_length(q);
}

float AAPL_SIMD_OVERLOAD quaternion_length_squared(quaternion_float q) {
    //  return q.x*q.x + q.y*q.y + q.z*q.z + q.w*q.w;
    return vector_length_squared(q);
}

vector_float3 AAPL_SIMD_OVERLOAD quaternion_axis(quaternion_float q) {
    // This query doesn't make sense if w > 1, but we do our best by
    // forcing q to be a unit quaternion if it obviously isn't
    if (q.w > 1.0)
    {
        q = quaternion_normalize(q);
    }

    float axisLen = sqrtf(1 - q.w * q.w);

    if (axisLen < 1e-5)
    {
        // At lengths this small, direction is arbitrary
        return vector_make(1, 0, 0);
    }
    else
    {
        return vector_make(q.x / axisLen, q.y / axisLen, q.z / axisLen);
    }
}

float AAPL_SIMD_OVERLOAD quaternion_angle(quaternion_float q) {
    return 2 * acosf(q.w);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_normalize(quaternion_float q) {
    //  return q / quaternion_length(q);
    return vector_normalize(q);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_inverse(quaternion_float q) {
    return quaternion_conjugate(q) / quaternion_length_squared(q);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_conjugate(quaternion_float q) {
    return quaternion(-q.x, -q.y, -q.z, q.w);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_multiply(quaternion_float q0, quaternion_float q1) {
    quaternion_float q;

    q.x = q0.w*q1.x + q0.x*q1.w + q0.y*q1.z - q0.z*q1.y;
    q.y = q0.w*q1.y - q0.x*q1.z + q0.y*q1.w + q0.z*q1.x;
    q.z = q0.w*q1.z + q0.x*q1.y - q0.y*q1.x + q0.z*q1.w;
    q.w = q0.w*q1.w - q0.x*q1.x - q0.y*q1.y - q0.z*q1.z;
    return q;
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_slerp(quaternion_float q0, quaternion_float q1, float t) {
    quaternion_float q;

    float cosHalfTheta = vector_dot(q0, q1);
    if (fabs(cosHalfTheta) >= 1.f) ///q0=q1 or q0=q1
    {
        return q0;
    }

    float halfTheta = acosf(cosHalfTheta);
    float sinHalfTheta = sqrtf(1.f - cosHalfTheta * cosHalfTheta);
    if (fabs(sinHalfTheta) < 0.001f)
    {    // q0 & q1 180 degrees not defined
        return q0*0.5f + q1*0.5f;
    }
    float srcWeight = sin((1 - t) * halfTheta) / sinHalfTheta;
    float dstWeight = sin(t * halfTheta) / sinHalfTheta;

    q = srcWeight*q0 + dstWeight*q1;

    return q;
}

vector_float3 AAPL_SIMD_OVERLOAD quaternion_rotate_vector(quaternion_float q, vector_float3 v) {
    vector_float3 qp = vector_make(q.x, q.y, q.z);
    float w = q.w;
    return 2 * vector_dot(qp, v) * qp +
           ((w * w) - vector_dot(qp, qp)) * v +
           2 * w * vector_cross(qp, v);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_matrix3x3(matrix_float3x3 m)
{
    quaternion_float q;

    float trace = 1 + m.columns[0][0] + m.columns[1][1] + m.columns[2][2];

    if(trace > 0)
    {
        float diagonal = sqrt(trace) * 2.0;

        q.x = (m.columns[2][1] - m.columns[1][2]) / diagonal;
        q.y = (m.columns[0][2] - m.columns[2][0]) / diagonal;
        q.z = (m.columns[1][0] - m.columns[0][1]) / diagonal;
        q.w = diagonal / 4.0;

    }  else if ((m.columns[0][0] > m.columns[1][1] ) &&
                (m.columns[0][0] > m.columns[2][2])) {

        float diagonal = sqrt( 1.0 + m.columns[0][0] - m.columns[1][1] - m.columns[2][2] ) * 2.0;

        q.x = diagonal / 4.0;
        q.y = (m.columns[0][1] + m.columns[1][0]) / diagonal;
        q.z = (m.columns[0][2] + m.columns[2][0]) / diagonal;
        q.w = (m.columns[2][1] - m.columns[1][2]) / diagonal;

    } else if ( m.columns[1][1] > m.columns[2][2]) {

        float diagonal = sqrt(1.0 + m.columns[1][1] - m.columns[0][0] - m.columns[2][2]) * 2.0;

        q.x = (m.columns[0][1] + m.columns[1][0]) / diagonal;
        q.y = diagonal / 4.0;
        q.z = (m.columns[1][2] + m.columns[2][1]) / diagonal;
        q.w = (m.columns[0][2] - m.columns[2][0]) / diagonal;

    } else {

        float diagonal = sqrt(1.0 + m.columns[2][2] - m.columns[0][0] - m.columns[1][1]) * 2.0;

        q.x = (m.columns[0][2] + m.columns[2][0]) / diagonal;
        q.y = (m.columns[1][2] + m.columns[2][1]) / diagonal;
        q.z = diagonal / 4.0;
        q.w = (m.columns[1][0] - m.columns[0][1]) / diagonal;
    }

    q = quaternion_normalize(q);
    return q;
}

static inline quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_direction_vectors(vector_float3 forward, vector_float3 up, int right_handed) {

    forward = vector_normalize(forward);
    up = vector_normalize(up);

    vector_float3 side = vector_normalize(vector_cross(up, forward));

    matrix_float3x3 m = { side, up, forward };

    quaternion_float q = quaternion_from_matrix3x3(m);

    if(right_handed) {
        q = q.yxwz;
        q.xw = -q.xw;
    }

    q = vector_normalize(q);

    return q;
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_direction_vectors_right_hand(vector_float3 forward, vector_float3 up) {

    return quaternion_from_direction_vectors(forward, up, 1);
}

quaternion_float AAPL_SIMD_OVERLOAD quaternion_from_direction_vectors_left_hand(vector_float3 forward, vector_float3 up) {

    return quaternion_from_direction_vectors(forward, up, 0);
}

vector_float3 AAPL_SIMD_OVERLOAD forward_direction_vector_from_quaternion(quaternion_float q) {
    vector_float3 direction;
    direction.x = 2.0 * (q.x*q.z - q.w*q.y);
    direction.y = 2.0 * (q.y*q.z + q.w*q.x);
    direction.z = 1.0 - 2.0 * ((q.x * q.x) + (q.y * q.y));

    direction = vector_normalize(direction);
    return direction;
}

vector_float3 AAPL_SIMD_OVERLOAD up_direction_vector_from_quaternion(quaternion_float q) {
    vector_float3 direction;
    direction.x = 2.0 * (q.x*q.y + q.w*q.z);
    direction.y = 1.0 - 2.0 * (q.x*q.x + q.z*q.z);
    direction.z = 2.0 * (q.y*q.z - q.w*q.x);

    direction = vector_normalize(direction);
    // Negate for a right-handed coordinate system
    return direction;
}

vector_float3 AAPL_SIMD_OVERLOAD right_direction_vector_from_quaternion(quaternion_float q) {
    vector_float3 direction;
    direction.x = 1.0 - 2.0 * (q.y * q.y + q.z * q.z);
    direction.y = 2.0 * (q.x * q.y - q.w * q.z);
    direction.z = 2.0 * (q.x * q.z + q.w * q.y);

    direction = vector_normalize(direction);
    // Negate for a right-handed coordinate system
    return direction;
}

vector_float3 quaternion_to_euler( quaternion_float q ) {

    float test = 2.0 * ( q.x * q.z - q.w * q.y );

    float x = 0.0;
    float y = 0.0;
    float z = 0.0;

    if ( test != 1.0 && test != -1.0 ) {

        x = atan2( 2.0 * ( q.y * q.z + q.w * q.x ), 1.0 - 2.0 * ( q.x * q.x + q.y * q.y ) );
        y = asin( -2.0 * ( q.x * q.z - q.w * q.y ) );
        z = atan2( 2.0 * ( q.x * q.y + q.w * q.z ), 1.0 - 2.0 * ( q.y * q.y + q.z * q.z ) );
    } else if ( test == 1.0 ) {
        z = atan2( q.x * q.y + q.w * q.z, 0.5 - ( q.y * q.y + q.z * q.z ) );
        y = M_PI_2;
        x = -z + atan2( q.x * q.y - q.w * q.z, q.x * q.z + q.w * q.y );
    } else if ( test == -1.0 ) {
        z = atan2( q.x * q.y + q.w * q.z, 0.5 - ( q.y * q.y + q.z * q.z ) );
        y = M_PI_2;
        x = z + atan2( q.x * q.y - q.w * q.z, q.x * q.z + q.w * q.y );
    }

    return vector_float3 { x, y, z };
}

quaternion_float quaternion_lookAt( simd::float3 eye, simd::float3 target, simd::float3 up ) {

    // for info on how I produce the lookat matrix, see http://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
    // There are several conditions that we have to test in order to obtain the correct w,x,i,j
    // if you are completely lost at how quaternion works take a look at this https://eater.net/quaternions
    simd_float3 forward = simd_normalize( eye - target );
    simd_float3 right = simd_normalize( simd_cross( up, forward ) );
    simd_float3 newUp = simd_cross( forward, right );

    quaternion_float q;

    float trace = right.x + newUp.y + forward.z;

    if ( trace > 0.0 ) {
        float s = 0.5 / sqrt( trace + 1.0 );
        q.w = 0.25 / s;
        q.x = ( newUp.z - forward.y ) * s;
        q.y = ( forward.x - right.z ) * s;
        q.z = ( right.y - newUp.x ) * s;
    } else {

        if ( right.x > newUp.y && right.x > forward.z ) {

            float s = 2.0 * sqrt( 1.0 + right.x - newUp.y - forward.z );
            q.w = ( newUp.z - forward.y ) / s;
            q.x = 0.25 * s;
            q.y = ( newUp.x + right.y ) / s;
            q.z = ( forward.x + right.z ) / s;

        } else if ( newUp.y > forward.z ) {
            float s = 2.0 * sqrt( 1.0 + newUp.y - right.x - forward.z );
            q.w = ( forward.x - right.z ) / s;
            q.x = ( newUp.x + right.y ) / s;
            q.y = 0.25 * s;
            q.z = ( forward.y + newUp.z ) / s;
        } else {
            float s = 2.0 * sqrt( 1.0 + forward.z - right.x - newUp.y );
            q.w = ( right.y - newUp.x ) / s;
            q.x = ( forward.x + right.z ) / s;
            q.y = ( forward.y + newUp.z ) / s;
            q.z = 0.25 * s;
        }
    }

    return q;
}

quaternion_float quaternion_from_two_vectors( vector_float3 v1, vector_float3 v2, vector_float3 up ) {

    // calculate the dot product between the two vectors
    float dot = simd_dot( v1, v2 );

    // if the vectors are parallel or antiparallel, choose any arbitrary orthogonal axis
    if ( std::abs( dot + 1.0 ) < 0.000001 ) {
        vector_float3 axis = simd_cross( up, v1 );

        if ( simd_equal( axis, vector_float3 { 0.0, 0.0, 0.0 } ) ) {
            // the up vector is parallel to the target vector, so rotate around the up vector
            return quaternion_from_axis_angle( up, M_PI );
        } else {
            // use the orthogonal axis for rotation
            return quaternion_from_axis_angle( simd_normalize( axis ), M_PI );
        }
    }

    // calculate the cross product between the two vectors
    vector_float3 cross = simd_cross( v1, v2 );

    // calculate the rotation angle
    float angle = std::acos( dot );

    // create the quaternion from the axis-angle representation
    return quaternion_from_axis_angle( simd_normalize( cross ), angle );
}

simd_uint3 indexTo3DGridMap(unsigned int index, unsigned int sizeX, unsigned int sizeY, unsigned int sizeZ){
    
    unsigned int x=index%sizeX;
    unsigned int z=(index/sizeX)%sizeZ;
    unsigned int y=index/(sizeX*sizeZ);
    
    return simd_make_uint3(x, y, z);
}

unsigned int grid3DToIndexMap(simd_uint3 coord, unsigned int sizeX, unsigned int sizeY, unsigned int sizeZ ){
    unsigned int index=coord.x+coord.z*sizeX+coord.y*sizeX*sizeZ;
    return index;
}
