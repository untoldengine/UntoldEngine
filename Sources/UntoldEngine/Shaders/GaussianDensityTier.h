//
//  GaussianDensityTier.h
//  UntoldEngine
//
//  The half-octave density tiers of GaussianBudgetDensityHistogram, shared by the chunk cull
//  that accumulates them (GaussianChunkCull.metal) and the budget solve that reads them
//  (GaussianWorkingSetBudget.metal). The tier is taken from the float's own exponent and
//  significand, never from a logarithm, so the CPU mirror (GaussianChunkCullMath.densityTier)
//  bins every float exactly as the GPU does. The per-chunk level rule of the coarse levels
//  (per-chunk-lod-tiers) lives here too: integer tier arithmetic shared by the quota pass that
//  chooses each chunk's level, the solve that charges the same rule for every candidate cap,
//  and the CPU mirror.
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

// MARK: - The per-chunk level rule (per-chunk-lod-tiers)

// The tier distance that stands for "the cap is zero": far below every threshold, so the rule
// picks the coarsest level (nothing is drawn at a zero cap either way).
constant int kGaussianLevelRuleMinusInfinity = -(4 * gaussianBudgetDensityTierCount);

// The level a chunk draws given deltaTier = tier(min(cap, floor)) − tier(splatCount / area),
// the level it drew last frame (`previous`) and which levels it has (`available`: bit 0 fine —
// resident ranks for a paged chunk, always for a whole-resident one — bit 1 level 1, bit 2
// level 2), with the entity's tier shifts s1 = 2 × (ratioLog2[0] − 1), s2 = 2 × (ratioLog2[1]
// − 1). Wanted: fine while deltaTier ≥ −s1 (the fine quota min(n, cap · A) is still at least
// 2 × m1 there, up to the tier quantisation), level 1 while −s2 ≤ deltaTier < −s1, level 2
// below. Hysteresis: moving to a finer level than `previous` needs one more half-octave
// (deltaTier ≥ threshold + 1); moving coarser is taken at once. Availability: a wanted level
// that is not available steps to the next coarser available one, else to the next finer
// available one; with nothing available the wanted level is returned (the cull lists no such
// chunk). Integer arithmetic on both sides: GaussianChunkCullMath.levelRule mirrors it exactly.
static inline uint gaussianLevelWantedAt(int deltaTier, int s1, int s2, int margin)
{
    if (deltaTier >= -s1 + margin) return 0u;
    if (deltaTier >= -s2 + margin) return 1u;
    return 2u;
}

static inline uint gaussianLevelRule(int deltaTier, uint previous, uint available, uint tierShift1, uint tierShift2)
{
    const int s1 = (int)tierShift1;
    const int s2 = (int)tierShift2;
    uint want = gaussianLevelWantedAt(deltaTier, s1, s2, 0);
    if (want < previous) {
        // Finer than last frame: only past the band, and never finer than the band allows.
        want = min(previous, gaussianLevelWantedAt(deltaTier, s1, s2, 1));
    }
    for (uint level = want; level <= 2u; ++level) {
        if ((available & (1u << level)) != 0u) return level;
    }
    for (int level = (int)want - 1; level >= 0; --level) {
        if ((available & (1u << (uint)level)) != 0u) return (uint)level;
    }
    return want;
}

// The level of a chunk for the frame's density cap and floor (GaussianChunkLevelConstants
// .densityFloor, +inf when off): deltaTier from the tiers of min(cap, floor) and of the chunk's
// own density, −∞ when that effective cap is zero; fine only / coarsest available for the
// debug modes. Mirrored by GaussianChunkCullMath.level.
static inline uint gaussianChunkLevel(
    float densityCap, float densityFloor, float splatCount, float screenArea,
    uint previous, uint available, uint tierShift1, uint tierShift2, uint levelMode)
{
    if (levelMode == (uint)gaussianChunkLevelModeFineOnly) return 0u;
    if (levelMode == (uint)gaussianChunkLevelModeCoarseOnly) {
        if ((available & 4u) != 0u) return 2u;
        if ((available & 2u) != 0u) return 1u;
        return 0u;
    }
    const float effective = min(densityCap, densityFloor);
    const int deltaTier = (effective > 0.0f)
        ? (int)gaussianDensityTier(effective) - (int)gaussianDensityTier(splatCount / screenArea)
        : kGaussianLevelRuleMinusInfinity;
    return gaussianLevelRule(deltaTier, previous, available, tierShift1, tierShift2);
}

// The availability mask of a chunk from its coarse bits (GaussianChunkResidency.coarseAvailable
// for a paged entity, both levels for a whole-resident one), the level counts (a chunk too small
// for a level has count 0) and the levels the entity has resident (hasCoarse), plus fine.
static inline uint gaussianLevelAvailability(bool fineAvailable, uint coarseBits, uint m1, uint m2, uint hasCoarse)
{
    uint mask = fineAvailable ? 1u : 0u;
    if (hasCoarse >= 1u && m1 != 0u && (coarseBits & 1u) != 0u) mask |= 2u;
    if (hasCoarse >= 2u && m2 != 0u && (coarseBits & 2u) != 0u) mask |= 4u;
    return mask;
}

// The level state's fields (GaussianChunkLevelState.word0).
static inline uint gaussianLevelStateLevel(uint word0) { return word0 & kGaussianChunkLevelStateLevelMask; }
// 0 = none, else the outgoing level + 1.
static inline uint gaussianLevelStateOut(uint word0) { return (word0 & kGaussianChunkLevelStateOutMask) >> kGaussianChunkLevelStateOutShift; }
static inline uint gaussianLevelStatePending(uint word0) { return (word0 & kGaussianChunkLevelStatePendingMask) >> kGaussianChunkLevelStatePendingShift; }
static inline bool gaussianLevelStatePendingValid(uint word0) { return (word0 & kGaussianChunkLevelStatePendingValid) != 0u; }
static inline uint gaussianLevelStateOutCount(uint word0) { return word0 >> kGaussianChunkLevelStateCountShift; }
static inline uint gaussianLevelStateWord(uint level, uint outPlusOne, uint pending, bool pendingValid, uint outCount)
{
    return (level & kGaussianChunkLevelStateLevelMask)
        | ((outPlusOne << kGaussianChunkLevelStateOutShift) & kGaussianChunkLevelStateOutMask)
        | ((pending << kGaussianChunkLevelStatePendingShift) & kGaussianChunkLevelStatePendingMask)
        | (pendingValid ? kGaussianChunkLevelStatePendingValid : 0u)
        | (min(outCount, 0x00FFFFFFu) << kGaussianChunkLevelStateCountShift);
}

// Whether the state's outgoing window is still fading at `frame`: an outgoing level is set and
// fewer than fadeFrames frames passed since the switch (fadeFrames 0: never).
static inline bool gaussianLevelStateFading(GaussianChunkLevelState state, uint frame, uint fadeFrames)
{
    return gaussianLevelStateOut(state.word0) != 0u && fadeFrames != 0u && (frame - state.switchFrame) < fadeFrames;
}

// The coverage-preserving cross-fade weight of an opacity: 1 − (1 − α)^w, so the incoming
// window at w and the outgoing at 1 − w compose to 1 − α over a surface both cover.
static inline float gaussianCoverageWeight(float alpha, float w)
{
    return 1.0f - pow(1.0f - alpha, w);
}

#endif /* GaussianDensityTier_h */
