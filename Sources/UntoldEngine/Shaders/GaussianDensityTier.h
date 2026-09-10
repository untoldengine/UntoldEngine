//
//  GaussianDensityTier.h
//  UntoldEngine
//
//  The half-octave density tiers of GaussianBudgetDensityHistogram, shared by the chunk cull
//  that accumulates them (GaussianChunkCull.metal) and the budget solve that reads them
//  (GaussianWorkingSetBudget.metal). The tier is taken from the float's own exponent and
//  significand, never from a logarithm, so the CPU mirror (GaussianChunkCullMath.densityTier)
//  bins every float exactly as the GPU does.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef GaussianDensityTier_h
#define GaussianDensityTier_h

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// √2 as the one float both sides compare the significand against (Swift: Float(2).squareRoot()).
constant float kGaussianDensityTierRatio = 1.41421354f;

// The tier of a density (splats per view unit of screen area): with density = m · 2^e,
// m in [1, 2), tier 2(e + 2) when m < √2 and 2(e + 2) + 1 from √2 on, clamped into the
// 64 tiers. Densities above 2^30 — chunks that would get less than a splat at any realistic
// cap — clamp into the last tier, which keeps the grant's bound one-sided and only costs fill.
static inline uint gaussianDensityTier(float density)
{
    if (!(density > 0.0f)) return 0u;
    if (isinf(density)) return (uint)(gaussianBudgetDensityTierCount - 1);
    int exponent;
    const float fraction = frexp(density, exponent);   // [0.5, 1) × 2^exponent
    const float significand = 2.0f * fraction;         // [1, 2) × 2^(exponent − 1)
    const int upperHalf = (significand >= kGaussianDensityTierRatio) ? 1 : 0;
    const int tier = gaussianBudgetDensityTiersPerOctave * ((exponent - 1) - gaussianBudgetDensityTierLog2Floor) + upperHalf;
    return (uint)clamp(tier, 0, gaussianBudgetDensityTierCount - 1);
}

// The lower density bound of a tier, 2^(−2 + tier / 2): a power of two, or √2 times one —
// bit-identical to GaussianChunkCullMath.densityTierFloor. Accepts the tier past the last one
// (2^30, the density at which every chunk of the last tier is whole).
static inline float gaussianDensityTierFloor(uint tier)
{
    return ldexp(((tier & 1u) != 0u) ? kGaussianDensityTierRatio : 1.0f, (int)(tier >> 1) + gaussianBudgetDensityTierLog2Floor);
}

#endif /* GaussianDensityTier_h */
