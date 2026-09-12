//
//  GaussianChunkCull.swift
//  UntoldEngine
//
//  CPU side of the per-chunk path of .untoldgs entities: the chunk-level cull
//  (GaussianChunkCull.metal), the working-set budget and its per-chunk quotas
//  (GaussianWorkingSetBudget.metal) and the fused decode/test/project/compact pass
//  (GaussianChunkPreprocess.metal) — the per-slot buffers a chunked entity carries, the
//  per-frame constants, the encodes, and CPU mirrors of the chunk test, the screen area, the
//  density histogram and its solve, the quota, the opacity band and the per-chunk level rule of
//  the coarse levels (per-chunk-lod-tiers) for tests and callers that want to predict what the
//  GPU keeps.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

/// Mirrors `kGaussianQuadSigma` in Gaussians.metal: how many standard deviations the rendered
/// quad extends along each principal axis, and so how far a chunk's box is padded per unit of
/// the largest splat scale it holds.
let kGaussianQuadSigmaDefault: Float = 3.5

/// Guard band of the per-splat and chunk culls, as a fraction of the half clip extent: a centre
/// (or box) up to 25 % outside the view still counts as visible, so splats whose footprint
/// reaches into the frame from just off-screen are kept.
let gaussianCullClipGuardBand: Float = 0.25

/// NDC depth bias of the HZB tests, shared by the mesh cull, the per-splat cull and the chunk cull.
let gaussianCullHZBOcclusionBias: Float = 0.02

/// Mirrors `kGaussianOpacityBandFraction` (GaussianChunkPreprocess.metal): the ranks of a
/// truncated chunk from this fraction of its quota up to the quota fade linearly to zero.
let gaussianOpacityBandFraction: Float = 0.8

/// The fraction of the working set the quotas aim for, leaving room for the frame's rounding.
let gaussianBudgetHeadroom: Float = 0.98

/// The largest relative rise of the budget scale from one frame to the next; a fall is taken at
/// once (a lower scale never overflows the set, a lagging one would).
let gaussianBudgetMaxStepFraction: Float = 0.1

/// The smallest absolute rise of the budget scale per frame, so a climb from a low scale (a cut
/// from a dense view to one that fits the budget) does not crawl: from 0.06 to 1 in about 17
/// frames instead of 30.
let gaussianBudgetMinStep: Float = 0.05

/// `gaussianBudgetDensityTierCount` and its neighbours (ShaderTypes.h) as Ints: the density
/// histogram the weighted quotas are solved from holds 64 half-octave tiers of splats per view
/// unit of screen area, the first starting at 2^-2; densities above the last tier clamp into it.
let gaussianDensityTierCount = Int(gaussianBudgetDensityTierCount)
let gaussianDensityTiersPerOctave = Int(gaussianBudgetDensityTiersPerOctave)
let gaussianDensityTierLog2Floor = Int(gaussianBudgetDensityTierLog2Floor)

/// Mirrors `kGaussianScreenAreaMin`: the smallest screen area a visible chunk is charged for,
/// 2^-24 view units (a quarter of a pixel at 4K). A chunk no view keeps (`disableChunkCull`)
/// carries it, so it is the densest chunk of the frame and is cut first.
let gaussianScreenAreaMin: Float = 1 / 16_777_216

/// The screen area of a chunk whose padded box reaches behind the eye (the chunk the camera
/// stands in): the whole guard-banded clip volume, (1 + guard band)² — `kGaussianScreenAreaGuard`.
let gaussianScreenAreaGuard: Float = (1 + gaussianCullClipGuardBand) * (1 + gaussianCullClipGuardBand)

/// The smallest rise of the density cap per frame as a fraction of its target, so a climb from
/// a low cap (or from the scale, after the uniform switch is flipped) finishes within about
/// twenty frames.
let gaussianBudgetDensityMinStepFraction: Float = 0.05

/// Mirrors `kGaussianBudgetDensityClimbTail`: the fraction of the request a climb toward a
/// fitting frame leaves to the whole — the cap climbs to the density below which all but the
/// densest tail of the requested splats are whole (`GaussianChunkCullMath.climbDensity`) and
/// becomes whole there, so the smallest chunks on screen set neither the step nor the frames
/// of the climb.
let gaussianBudgetDensityClimbTailFraction: Float = 0.05

/// Bisection steps of the density solve on log2 of the cap, over the octaves from
/// `gaussianBudgetDensityBisectionLog2Floor` to the density at which every chunk is whole:
/// 24 steps over at most 46 octaves give the cap to 3 × 10⁻⁶ octaves.
let gaussianBudgetDensityBisectionSteps = 24
let gaussianBudgetDensityBisectionLog2Floor: Float = -16

/// √2, the ratio between the lower bounds of two consecutive half-octave tiers; the single
/// float the kernel compares the significand against, so CPU and GPU bin every float alike.
let gaussianBudgetDensityTierRatio = Float(2).squareRoot()

/// CPU mirror of the chunk test in `gaussianChunkCull` (GaussianChunkCull.metal), without the
/// HZB part: the chunk's centre AABB padded by `extentPadding(logScaleMax:)` on every side,
/// tested against the guard-banded clip volume of each view; visible if any view keeps it. The
/// test is conservative in the same way as the kernel — a box is rejected only when all eight
/// corners lie beyond the same clip plane — so any splat centre the per-splat cull keeps lies in
/// a chunk this keeps.
enum GaussianChunkCullMath {
    /// How far the largest splat of a chunk can reach from its centre along any axis.
    static func extentPadding(logScaleMax: Float) -> Float {
        kGaussianQuadSigmaDefault * exp(logScaleMax)
    }

    /// The clip-plane test of one box against one view-projection (model matrix folded in).
    static func boxPassesClipPlanes(
        boxMin: simd_float3,
        boxMax: simd_float3,
        viewProjection: simd_float4x4,
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        let limit = max(0, 1 + clipGuardBand)
        var outsideEveryCorner: UInt32 = 0x7F
        for i in 0 ..< 8 {
            let corner = simd_float3(
                (i & 1) != 0 ? boxMax.x : boxMin.x,
                (i & 2) != 0 ? boxMax.y : boxMin.y,
                (i & 4) != 0 ? boxMax.z : boxMin.z
            )
            let c = simd_mul(viewProjection, simd_float4(corner, 1))
            var outside: UInt32 = 0
            if c.w <= 0 { outside |= 0x01 }
            if c.x < -c.w * limit { outside |= 0x02 }
            if c.x > c.w * limit { outside |= 0x04 }
            if c.y < -c.w * limit { outside |= 0x08 }
            if c.y > c.w * limit { outside |= 0x10 }
            if c.z < -c.w * clipGuardBand { outside |= 0x20 }
            if c.z > c.w * limit { outside |= 0x40 }
            outsideEveryCorner &= outside
        }
        return outsideEveryCorner == 0
    }

    /// The chunk's padded box, as the kernel builds it from the decode constants.
    static func paddedBox(aabbMin: simd_float3, aabbMax: simd_float3, logScaleMax: Float) -> (min: simd_float3, max: simd_float3) {
        let pad = extentPadding(logScaleMax: logScaleMax)
        return (aabbMin - simd_float3(repeating: pad), aabbMax + simd_float3(repeating: pad))
    }

    // MARK: Screen area (GaussianChunkCull.metal)

    /// The clip-plane test of one box against one view-projection together with the box's
    /// screen area in that view, in the operation order of the kernel's corner loop: the NDC
    /// rect of the corners in front of the eye, clipped to the guard-banded view, as a fraction
    /// of the view's width times its height — 1 for a box filling the view, 0 for a rejected
    /// box, the whole guard-banded volume ((1 + guard band)²) for a box that reaches behind
    /// the eye. The area is not clamped to `gaussianScreenAreaMin`; `chunkScreenArea` does that.
    static func screenArea(
        boxMin: simd_float3,
        boxMax: simd_float3,
        viewProjection: simd_float4x4,
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> (passes: Bool, area: Float) {
        let limit = max(0, 1 + clipGuardBand)
        var outsideEveryCorner: UInt32 = 0x7F
        var behind = false
        var ndcMin = simd_float2(repeating: .infinity)
        var ndcMax = simd_float2(repeating: -.infinity)
        for i in 0 ..< 8 {
            let corner = simd_float3(
                (i & 1) != 0 ? boxMax.x : boxMin.x,
                (i & 2) != 0 ? boxMax.y : boxMin.y,
                (i & 4) != 0 ? boxMax.z : boxMin.z
            )
            let c = simd_mul(viewProjection, simd_float4(corner, 1))
            var outside: UInt32 = 0
            if c.w <= 0 { outside |= 0x01 }
            if c.x < -c.w * limit { outside |= 0x02 }
            if c.x > c.w * limit { outside |= 0x04 }
            if c.y < -c.w * limit { outside |= 0x08 }
            if c.y > c.w * limit { outside |= 0x10 }
            if c.z < -c.w * clipGuardBand { outside |= 0x20 }
            if c.z > c.w * limit { outside |= 0x40 }
            outsideEveryCorner &= outside
            if c.w > 0 {
                let ndc = simd_float2(c.x, c.y) / c.w
                ndcMin = simd_min(ndcMin, ndc)
                ndcMax = simd_max(ndcMax, ndc)
            } else {
                behind = true
            }
        }
        guard outsideEveryCorner == 0 else { return (false, 0) }
        if behind { return (true, limit * limit) }
        let lo = simd_clamp(ndcMin, simd_float2(repeating: -limit), simd_float2(repeating: limit))
        let hi = simd_clamp(ndcMax, simd_float2(repeating: -limit), simd_float2(repeating: limit))
        let extent = simd_max(hi - lo, simd_float2(repeating: 0)) * 0.5
        return (true, extent.x * extent.y)
    }

    /// The screen area `gaussianChunkCull` writes for a chunk under `constants` (without the
    /// HZB part): the larger of the areas of the views that keep its padded box (`viewCount`
    /// 1 or 2), clamped to `gaussianScreenAreaMin ... (1 + guard band)²` — the minimum when no
    /// view keeps it, as a `forceAllVisible` chunk gets — or `Float(splatCount)` when the
    /// constants ask for uniform quotas.
    static func chunkScreenArea(chunk: GaussianChunkDecodeConstants, constants: GaussianChunkCullConstants) -> Float {
        if constants.uniformQuotas != 0 {
            return Float(chunk.splatCount)
        }
        let box = paddedBox(
            aabbMin: simd_float3(chunk.aabbMinX, chunk.aabbMinY, chunk.aabbMinZ),
            aabbMax: simd_float3(chunk.aabbMaxX, chunk.aabbMaxY, chunk.aabbMaxZ),
            logScaleMax: chunk.logScaleMax
        )
        let limit = max(0, 1 + constants.clipGuardBand)
        var area: Float = 0
        let view0 = screenArea(boxMin: box.min, boxMax: box.max, viewProjection: constants.viewProjection0, clipGuardBand: constants.clipGuardBand)
        if view0.passes { area = max(area, view0.area) }
        if constants.viewCount > 1 {
            let view1 = screenArea(boxMin: box.min, boxMax: box.max, viewProjection: constants.viewProjection1, clipGuardBand: constants.clipGuardBand)
            if view1.passes { area = max(area, view1.area) }
        }
        return min(max(area, gaussianScreenAreaMin), limit * limit)
    }

    // MARK: Density tiers and the histogram (GaussianChunkCull.metal, GaussianWorkingSetBudget.metal)

    /// The histogram tier of a density (splats per view unit of area), from the float's own
    /// exponent and significand exactly as the kernel takes it from `frexp` — never from a
    /// logarithm, so CPU and GPU bin the same float identically: tier 2(e + 2) + 1 when the
    /// significand is at least √2, else 2(e + 2), clamped to the 64 tiers.
    static func densityTier(density: Float) -> Int {
        guard density > 0 else { return 0 }
        guard density.isFinite else { return gaussianDensityTierCount - 1 }
        let exponent = Int(density.exponent)
        let half = density.significand >= gaussianBudgetDensityTierRatio ? 1 : 0
        let tier = gaussianDensityTiersPerOctave * (exponent - gaussianDensityTierLog2Floor) + half
        return min(max(tier, 0), gaussianDensityTierCount - 1)
    }

    /// The lower density bound of tier `tier`: 2^(−2 + tier / 2), built as the kernel builds it
    /// (√2 or 1 scaled by a power of two, bit-identical on both sides). Accepts the tier past the
    /// last one, the density at which every chunk of the last tier is whole.
    static func densityTierFloor(_ tier: Int) -> Float {
        Float(sign: .plus, exponent: (tier >> 1) + gaussianDensityTierLog2Floor, significand: (tier & 1) != 0 ? gaussianBudgetDensityTierRatio : 1)
    }

    /// The histogram `gaussianChunkCull` accumulates for `chunks` (splat count and the real
    /// screen area of each visible chunk): per tier the splats and Σ ceil(area × tier floor),
    /// `visibleChunks` the count; the header fields are left at zero.
    static func densityHistogram(chunks: [(splatCount: UInt32, screenArea: Float)]) -> GaussianBudgetDensityHistogram {
        densityHistogram(levelledChunks: chunks.map { LevelledChunk(splatCount: $0.splatCount, screenArea: $0.screenArea) })
    }

    /// One visible chunk of an entity as the cull sees it, for the histogram and request mirrors:
    /// its full splat count `splatCount`, its resident ranks (the whole count for a
    /// whole-resident entity; 0 unlists a chunk without an available coarse level), its screen
    /// area, and its coarse levels — the runtime's level 1 and 2 counts (`coarse1`, `coarse2`)
    /// and which are available (`availableLevels` bit 0 = level 1, bit 1 = level 2; 0 = the
    /// chunk, or the entity, has none).
    struct LevelledChunk {
        var splatCount: UInt32
        var residentRanks: UInt32
        var screenArea: Float
        var coarse1: UInt32 = 0
        var coarse2: UInt32 = 0
        var availableLevels: UInt32 = 0

        init(splatCount: UInt32, residentRanks: UInt32? = nil, screenArea: Float, coarse1: UInt32 = 0, coarse2: UInt32 = 0, availableLevels: UInt32 = 0) {
            self.splatCount = splatCount
            self.residentRanks = residentRanks ?? splatCount
            self.screenArea = screenArea
            self.coarse1 = coarse1
            self.coarse2 = coarse2
            self.availableLevels = availableLevels
        }

        /// The rule's availability mask: bit 0 fine (resident ranks), bit 1 level 1, bit 2 level 2.
        var availability: UInt32 {
            (residentRanks > 0 ? 1 : 0)
                | ((availableLevels & 1) != 0 && coarse1 > 0 ? 2 : 0)
                | ((availableLevels & 2) != 0 && coarse2 > 0 ? 4 : 0)
        }

        /// Whether the cull lists the chunk: something resident, or a coarse level available.
        var isListed: Bool {
            residentRanks > 0 || (availability & 6) != 0
        }

        /// The count of the finest available coarse level (0 without one).
        var finestCoarseCount: UInt32 {
            let availability = availability
            if (availability & 2) != 0 { return coarse1 }
            if (availability & 4) != 0 { return coarse2 }
            return 0
        }

        /// What the cull lists as the chunk's splats: the resident ranks, at least the count of
        /// the finest available coarse level (a non-resident chunk of a paged entity lists that
        /// count alone), so the fine regime is never charged less than a coarse level draws.
        var listedSplats: UInt32 {
            max(min(splatCount, residentRanks), finestCoarseCount)
        }
    }

    /// The histogram `gaussianChunkCull` accumulates for an entity with coarse levels: a chunk
    /// with a level is binned by its full density and adds its listed splats to `splats` and
    /// `levelledSplats`, its scaled area to `scaledArea` and `levelledScaledArea`, and the counts
    /// the rule would draw in the two coarse regimes to `coarse1`/`coarse2` (the finest available
    /// level's count for level 1, the coarsest's for level 2); a chunk without one bins as
    /// before. Unlisted chunks are skipped.
    static func densityHistogram(levelledChunks chunks: [LevelledChunk]) -> GaussianBudgetDensityHistogram {
        var tiers = [GaussianBudgetDensityTier](repeating: GaussianBudgetDensityTier(splats: 0, scaledArea: 0), count: gaussianDensityTierCount)
        var listed = 0
        for chunk in chunks where chunk.isListed {
            listed += 1
            let availability = chunk.availability
            let hasLevel = (availability & 6) != 0
            let tier = densityTier(density: Float(hasLevel ? chunk.splatCount : chunk.listedSplats) / chunk.screenArea)
            let scaledArea = UInt32(ceil(chunk.screenArea * densityTierFloor(tier)))
            tiers[tier].splats &+= chunk.listedSplats
            tiers[tier].scaledArea &+= scaledArea
            if hasLevel {
                tiers[tier].coarse1 &+= chunk.finestCoarseCount
                tiers[tier].coarse2 &+= (availability & 4) != 0 ? chunk.coarse2 : chunk.coarse1
                tiers[tier].levelledSplats &+= chunk.listedSplats
                tiers[tier].levelledScaledArea &+= scaledArea
            }
        }
        var histogram = GaussianBudgetDensityHistogram()
        histogram.setTiers(tiers)
        histogram.visibleChunks = UInt32(listed)
        return histogram
    }

    /// The bounded grant G(d) = Σ_t min(splats_t, d × scaledArea_t / ρ_t): at least the sum
    /// over the histogram's chunks of min(n, d × area) — the total the per-chunk rule grants
    /// at cap `d` — since each tier's scaled area over-estimates its area; continuous and
    /// non-decreasing in `d`. Summed in tier order in single precision, as the kernel sums it.
    static func boundedGrant(histogram: GaussianBudgetDensityHistogram, density: Float) -> Float {
        var total: Float = 0
        for (tier, entry) in histogram.tierArray.enumerated() where entry.splats > 0 {
            let area = Float(entry.scaledArea) / densityTierFloor(tier)
            total += min(Float(entry.splats), density * area)
        }
        return total
    }

    /// The bounded request R(d) of `gaussianBoundedRequest` (GaussianWorkingSetBudget.metal):
    /// `boundedGrant` for the tiers without levelled chunks, and for a tier's levelled chunks the
    /// term of the regime the level rule picks at `density` — k = tier(min(density, floor))
    /// against the tier: fine (min(levelledSplats, d × their own area), at least the level-1
    /// counts) while k ≥ t − s1 − 1, the level-1 counts while k ≥ t − s2 − 1, the level-2 counts
    /// below — each population with its own over-estimated area. At least the sum of the
    /// per-chunk quotas at the levels the quota pass picks; non-decreasing in `density`. Same
    /// operation order as the kernel.
    static func boundedRequest(histogram: GaussianBudgetDensityHistogram, density: Float, densityFloor: Float = .infinity, tierShifts: (Int, Int)) -> Float {
        let k = densityTier(density: min(density, densityFloor))
        var total: Float = 0
        for (tier, entry) in histogram.tierArray.enumerated() where entry.splats > 0 {
            let splats = Float(entry.splats)
            let area = Float(entry.scaledArea) / densityTierFloor(tier)
            let levelled = min(entry.levelledSplats, entry.splats)
            if levelled == 0 {
                total += min(splats, density * area)
                continue
            }
            let levelledSplats = Float(levelled)
            let levelledArea = Float(min(entry.levelledScaledArea, entry.scaledArea)) / densityTierFloor(tier)
            let fineOnly = splats - levelledSplats
            if fineOnly > 0 {
                total += min(fineOnly, density * (area - levelledArea))
            }
            let delta = k - tier
            if delta >= -tierShifts.0 - 1 {
                total += max(min(levelledSplats, density * levelledArea), Float(entry.coarse1))
            } else if delta >= -tierShifts.1 - 1 {
                total += Float(entry.coarse1)
            } else {
                total += Float(entry.coarse2)
            }
        }
        return total
    }

    /// The density at which every chunk of the histogram is whole: the floor of the tier past
    /// the highest non-empty one; +inf when the histogram is empty.
    static func fullDensity(histogram: GaussianBudgetDensityHistogram) -> Float {
        guard let highest = histogram.tierArray.lastIndex(where: { $0.splats > 0 }) else { return .infinity }
        return densityTierFloor(highest + 1)
    }

    /// The density a climb toward a fitting frame aims for and becomes whole at: the floor of
    /// the tier above the densest tiers holding together at most `tailFraction` of the
    /// histogram's splats (floor(tailFraction × request) splats), walked from the top — every
    /// chunk outside that tail is whole there, and the tail's chunks, the smallest on screen,
    /// become whole with the cap instead of setting its step; the full density when the tail
    /// holds no whole tier, +inf when the histogram is empty.
    static func climbDensity(histogram: GaussianBudgetDensityHistogram, tailFraction: Float = gaussianBudgetDensityClimbTailFraction) -> Float {
        let tiers = histogram.tierArray
        guard var tier = tiers.lastIndex(where: { $0.splats > 0 }) else { return .infinity }
        let requested = tiers.reduce(UInt32(0)) { $0 &+ $1.splats }
        let tail = UInt32(tailFraction * Float(requested))
        var tailSplats: UInt32 = 0
        while tier >= 0, tailSplats &+ tiers[tier].splats <= tail {
            tailSplats &+= tiers[tier].splats
            tier -= 1
        }
        return densityTierFloor(tier + 1)
    }

    /// The target density cap of a frame whose histogram sums to the request: +inf when the
    /// request fits (`fits`) or is empty, 0 when nothing is granted, else the largest cap the
    /// bisection on log2 finds with G(cap) ≤ `grant` — the lower endpoint of its last
    /// interval, so the bound holds in the same float arithmetic.
    static func densityCap(histogram: GaussianBudgetDensityHistogram, grant: UInt32, fits: Bool = false) -> Float {
        let tiers = histogram.tierArray
        let requested = tiers.reduce(UInt32(0)) { $0 &+ $1.splats }
        if requested == 0 || fits { return .infinity }
        if grant == 0 { return 0 }
        let grantValue = Float(grant)
        var lo = gaussianBudgetDensityBisectionLog2Floor
        var hi = log2(fullDensity(histogram: histogram))
        if boundedGrant(histogram: histogram, density: exp2(lo)) > grantValue { return 0 }
        for _ in 0 ..< gaussianBudgetDensityBisectionSteps {
            let mid = (lo + hi) * 0.5
            if boundedGrant(histogram: histogram, density: exp2(mid)) <= grantValue {
                lo = mid
            } else {
                hi = mid
            }
        }
        return exp2(lo)
    }

    /// The density cap applied after the hysteresis: the target when it is at or below the
    /// previous frame's cap (a fall is taken at once; "whole", +inf, stays whole), else the
    /// previous cap raised by at most max(`maxStepFraction` × previous, `minStepFraction` ×
    /// the target — `climbDensity` when the target is +inf), never past the target, and +inf
    /// once a climb toward a fitting frame reaches `climbDensity`. A previous cap of zero
    /// climbs like any other (by the step, as the scale climbs from zero), so a chunked entity
    /// that drew nothing beside a whole-buffer one that filled the set fades in rather than
    /// pops when room appears. `takeTarget` (the first frame, a reset, the budget switched off,
    /// no chunked request) takes the target, as does a previous cap that is not a number at or
    /// above zero (a guard: the state never holds one).
    static func smoothedDensityCap(
        target: Float,
        previous: Float,
        climbDensity: Float,
        takeTarget: Bool = false,
        maxStepFraction: Float = gaussianBudgetMaxStepFraction,
        minStepFraction: Float = gaussianBudgetDensityMinStepFraction
    ) -> Float {
        if takeTarget || !(previous >= 0) || target <= previous {
            return target
        }
        let stepTarget = target.isInfinite ? climbDensity : target
        let step = max(previous * maxStepFraction, minStepFraction * stepTarget)
        var cap = min(previous + step, target)
        if target.isInfinite, cap >= climbDensity {
            cap = .infinity
        }
        return cap
    }

    /// Frames a rise of the density cap from `previous` to `target` takes through
    /// `smoothedDensityCap` (with `climbDensity` standing in for an infinite target).
    static func framesToReachDensity(target: Float, from previous: Float, climbDensity: Float? = nil) -> Int {
        let climb = climbDensity ?? target
        var cap = previous
        var frames = 0
        while cap < target, frames < 10000 {
            cap = smoothedDensityCap(target: target, previous: cap, climbDensity: climb)
            frames += 1
        }
        return frames
    }

    /// A visible chunk's quota under `densityCap`: its whole count when densityCap × screenArea
    /// reaches it (+inf always does), else floor(densityCap × screenArea) — the one float product
    /// the kernel computes.
    static func quota(densityCap: Float, splatCount: UInt32, screenArea: Float) -> UInt32 {
        let product = densityCap * screenArea
        guard product < Float(splatCount) else { return splatCount }
        return UInt32(max(0, floor(product)))
    }

    // MARK: Per-chunk levels (GaussianDensityTier.h, GaussianWorkingSetBudget.metal, GaussianChunkPreprocess.metal)

    /// The half-octave tiers under a chunk's own density at which a coarse level of ratio
    /// 2^ratioLog2 is chosen: 2 × (ratioLog2 − 1) — the fine quota min(n, d × A) falls below
    /// twice the level's count there.
    static func tierShift(ratioLog2: UInt8) -> Int {
        2 * (max(Int(ratioLog2), 1) - 1)
    }

    /// The tier distance that stands for a zero cap (`kGaussianLevelRuleMinusInfinity`).
    static let levelRuleMinusInfinity = -(4 * gaussianDensityTierCount)

    private static func levelWanted(deltaTier: Int, tierShifts: (Int, Int), margin: Int) -> Int {
        if deltaTier >= -tierShifts.0 + margin { return 0 }
        if deltaTier >= -tierShifts.1 + margin { return 1 }
        return 2
    }

    /// Mirror of `gaussianLevelRule`: the level for `deltaTier` = tier(effective cap) − tier(n / A),
    /// the level drawn last frame and the availability mask (bit 0 fine, bit 1 level 1, bit 2
    /// level 2): fine while deltaTier ≥ −s1, level 1 while −s2 ≤ deltaTier < −s1, level 2
    /// below; moving finer than `previous` needs one more tier; a wanted level that is not
    /// available steps to the next coarser available one, else to the next finer available one.
    static func levelRule(deltaTier: Int, previous: Int, available: UInt32, tierShifts: (Int, Int)) -> Int {
        var want = levelWanted(deltaTier: deltaTier, tierShifts: tierShifts, margin: 0)
        if want < previous {
            want = min(previous, levelWanted(deltaTier: deltaTier, tierShifts: tierShifts, margin: 1))
        }
        // The wanted level when available, else the next coarser available one, else the next
        // finer available one (the three levels spelled out: the pager runs this per chunk).
        let bits = available & 7
        if bits & (1 << UInt32(want)) != 0 { return want }
        if want < 2, bits & (1 << UInt32(want + 1)) != 0 { return want + 1 }
        if want < 1, bits & 4 != 0 { return 2 }
        if want > 0, bits & (1 << UInt32(want - 1)) != 0 { return want - 1 }
        if want > 1, bits & 1 != 0 { return 0 }
        return want
    }

    /// The cap side of the level rule, computed once per frame or pass: the tier of the
    /// effective cap min(cap, floor), or the stand-in for a cap that is not above zero.
    struct LevelCap: Equatable {
        var tier = 0
        var isZero = false
    }

    /// `LevelCap` of `densityCap` under the density floor (+inf when off).
    @inline(__always)
    static func levelCap(densityCap: Float, densityFloor: Float) -> LevelCap {
        let effective = min(densityCap, densityFloor)
        return effective > 0 ? LevelCap(tier: densityTier(density: effective), isZero: false) : LevelCap(tier: 0, isZero: true)
    }

    /// The level rule's tier distance, tier(effective cap) − tier(n / A), for a chunk of
    /// `splatCount` splats covering `screenArea`; `levelRuleMinusInfinity` at a zero cap.
    @inline(__always)
    static func levelDeltaTier(cap: LevelCap, splatCount: UInt32, screenArea: Float) -> Int {
        cap.isZero ? levelRuleMinusInfinity : cap.tier - densityTier(density: Float(splatCount) / screenArea)
    }

    /// The level at `deltaTier` under `mode`: `levelRule` under `.auto`, fine under
    /// `.fineOnly`, the coarsest available level under `.coarseOnly`. The one rule the pager's
    /// wants, its mirror of the level drawn and `level(densityCap:…)` run.
    @inline(__always)
    static func level(mode: GaussianLevelMode, deltaTier: Int, previous: Int, available: UInt32, tierShifts: (Int, Int)) -> Int {
        switch mode {
        case .fineOnly:
            return 0
        case .coarseOnly:
            if (available & 4) != 0 { return 2 }
            if (available & 2) != 0 { return 1 }
            return 0
        case .auto:
            return levelRule(deltaTier: deltaTier, previous: previous, available: available, tierShifts: tierShifts)
        }
    }

    /// Mirror of `gaussianChunkLevel`: the level a chunk of `splatCount` splats covering
    /// `screenArea` takes at `densityCap` and the density floor (+inf when off), given the level
    /// it drew last frame, its availability mask and the entity's tier shifts; the debug modes
    /// force fine, or the coarsest available level.
    static func level(
        densityCap: Float,
        densityFloor: Float = .infinity,
        splatCount: UInt32,
        screenArea: Float,
        previous: Int,
        available: UInt32,
        tierShifts: (Int, Int),
        levelMode: GaussianLevelMode = .auto
    ) -> Int {
        let deltaTier = levelDeltaTier(cap: levelCap(densityCap: densityCap, densityFloor: densityFloor), splatCount: splatCount, screenArea: screenArea)
        return level(mode: levelMode, deltaTier: deltaTier, previous: previous, available: available, tierShifts: tierShifts)
    }

    /// The quota of a chunk drawn at `level`: fine on its resident ranks, min(resident,
    /// floor(cap × area)) as `quota(densityCap:splatCount:screenArea:)`; a coarse level on its
    /// count (`counts.0` level 1, `counts.1` level 2).
    static func levelQuota(level: Int, densityCap: Float, splatCount: UInt32, residentRanks: UInt32? = nil, screenArea: Float, counts: (UInt32, UInt32)) -> UInt32 {
        switch level {
        case 0: return quota(densityCap: densityCap, splatCount: min(splatCount, residentRanks ?? splatCount), screenArea: screenArea)
        case 1: return quota(densityCap: densityCap, splatCount: counts.0, screenArea: screenArea)
        default: return quota(densityCap: densityCap, splatCount: counts.1, screenArea: screenArea)
        }
    }

    /// The coverage-preserving cross-fade of an opacity at weight `w`: 1 − (1 − α)^w, so the
    /// incoming window at `w` and the outgoing at `1 − w` compose to 1 − α (`gaussianCoverageWeight`).
    static func coverageWeight(alpha: Float, weight: Float) -> Float {
        1 - pow(1 - alpha, weight)
    }

    /// The fade weight of a chunk switched at `switchFrame`, as the fused pass counts it:
    /// clamp((frame − switchFrame + 1) / fadeFrames, 0, 1); 1 when fades are off.
    static func fadeWeight(frame: UInt32, switchFrame: UInt32, fadeFrames: UInt32) -> Float {
        guard fadeFrames != 0 else { return 1 }
        return min(max(Float(frame &- switchFrame &+ 1) / Float(fadeFrames), 0), 1)
    }

    /// The `chunkIndex` word of a visible-chunk entry of an entity with coarse levels: the chunk
    /// index (below 2^24) with the level in bits 24–25 and the outgoing bit 26.
    static func visibleChunkTag(chunkIndex: UInt32, level: Int, outgoing: Bool = false) -> UInt32 {
        precondition(chunkIndex <= kGaussianVisibleChunkIndexMask, "chunk indices carry tag bits above 2^24")
        return (chunkIndex & kGaussianVisibleChunkIndexMask)
            | ((UInt32(level) << kGaussianVisibleChunkLevelShift) & kGaussianVisibleChunkLevelMask)
            | (outgoing ? kGaussianVisibleChunkOutgoing : 0)
    }

    /// The chunk index, level and outgoing flag of a visible-chunk entry's `chunkIndex` word.
    static func decodeVisibleChunkTag(_ word: UInt32) -> (chunkIndex: UInt32, level: Int, outgoing: Bool) {
        (
            word & kGaussianVisibleChunkIndexMask,
            Int((word & kGaussianVisibleChunkLevelMask) >> kGaussianVisibleChunkLevelShift),
            (word & kGaussianVisibleChunkOutgoing) != 0
        )
    }

    /// Visible if the padded box passes any of `viewProjections` (the frame's eyes; one in mono).
    static func chunkIsVisible(
        aabbMin: simd_float3,
        aabbMax: simd_float3,
        logScaleMax: Float,
        viewProjections: [simd_float4x4],
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        let box = paddedBox(aabbMin: aabbMin, aabbMax: aabbMax, logScaleMax: logScaleMax)
        return viewProjections.contains { viewProjection in
            boxPassesClipPlanes(boxMin: box.min, boxMax: box.max, viewProjection: viewProjection, clipGuardBand: clipGuardBand)
        }
    }

    /// The same for a chunk entry of the file index.
    static func chunkIsVisible(
        _ entry: UntoldGSChunkEntry,
        viewProjections: [simd_float4x4],
        clipGuardBand: Float = gaussianCullClipGuardBand
    ) -> Bool {
        chunkIsVisible(
            aabbMin: entry.aabbMin,
            aabbMax: entry.aabbMax,
            logScaleMax: entry.logScaleMax,
            viewProjections: viewProjections,
            clipGuardBand: clipGuardBand
        )
    }

    // MARK: Budget mirrors (GaussianWorkingSetBudget.metal, GaussianChunkPreprocess.metal)

    /// The scale a frame targets: 1 while the chunked request fits what the whole-buffer
    /// entities' `reservedSplats` leave of the budget, else the fraction of every visible chunk
    /// that fits the headroom's share of that room (0 when nothing is left).
    static func targetScale(requestedSplats: Int, budget: Int, reservedSplats: Int = 0, headroom: Float = gaussianBudgetHeadroom) -> Float {
        guard requestedSplats > budget - reservedSplats else { return 1 }
        let room = max(headroom * Float(budget) - Float(reservedSplats), 0)
        return min(1, room / Float(requestedSplats))
    }

    /// The scale applied after the hysteresis: the target when it is at or below the previous
    /// frame's scale, else the previous scale raised by at most max(`maxStepFraction` × previous,
    /// `minStep`); the first frame, and a frame with no chunked request (`requestedSplats` 0,
    /// nothing drawn under the scale), take the target.
    static func smoothedScale(
        target: Float,
        previous: Float?,
        requestedSplats: Int = 1,
        maxStepFraction: Float = gaussianBudgetMaxStepFraction,
        minStep: Float = gaussianBudgetMinStep
    ) -> Float {
        guard let previous, requestedSplats > 0 else { return target }
        let clamped = min(max(previous, 0), 1)
        guard target > clamped else { return target }
        let step = max(clamped * maxStepFraction, minStep)
        return min(target, clamped + step)
    }

    /// Frames a rise from `previous` to `target` takes through `smoothedScale`.
    static func framesToReach(target: Float, from previous: Float) -> Int {
        var scale = previous
        var frames = 0
        while scale < target, frames < 10000 {
            scale = smoothedScale(target: target, previous: scale)
            frames += 1
        }
        return frames
    }

    /// A visible chunk's quota at `scale`: floor(scale × splatCount), never above the count.
    static func quota(scale: Float, splatCount: UInt32) -> UInt32 {
        guard scale < 1 else { return splatCount }
        return min(splatCount, UInt32(max(0, floor(scale * Float(splatCount)))))
    }

    /// The opacity multiplier of rank `rank` in a chunk granted `quota` of its `splatCount`.
    static func opacityBandFactor(rank: UInt32, quota: UInt32, splatCount: UInt32) -> Float {
        guard quota < splatCount else { return 1 }
        let bandStart = UInt32(gaussianOpacityBandFraction * Float(quota))
        guard rank >= bandStart, quota > bandStart else { return 1 }
        return Float(quota - rank) / Float(quota - bandStart)
    }
}

extension GaussianBudgetDensityHistogram {
    /// The tiers as an array (the C array imports as a tuple).
    var tierArray: [GaussianBudgetDensityTier] {
        withUnsafeBytes(of: tiers) { Array($0.bindMemory(to: GaussianBudgetDensityTier.self)) }
    }

    /// One tier.
    func tier(_ index: Int) -> GaussianBudgetDensityTier {
        withUnsafeBytes(of: tiers) { $0.bindMemory(to: GaussianBudgetDensityTier.self)[index] }
    }

    /// Replaces the tiers with `values` (at most `gaussianDensityTierCount`; the rest stay).
    mutating func setTiers(_ values: [GaussianBudgetDensityTier]) {
        withUnsafeMutableBytes(of: &tiers) { bytes in
            let tiers = bytes.bindMemory(to: GaussianBudgetDensityTier.self)
            for (index, value) in values.prefix(tiers.count).enumerated() {
                tiers[index] = value
            }
        }
    }

    /// The request the tiers hold: Σ splats.
    var requestedSplats: UInt32 {
        tierArray.reduce(UInt32(0)) { $0 &+ $1.splats }
    }
}

extension GaussianBudgetDensityTier {
    /// A tier without levelled chunks (the coarse words zero).
    init(splats: UInt32, scaledArea: UInt32) {
        self.init()
        self.splats = splats
        self.scaledArea = scaledArea
    }
}

/// The per-chunk level state `gaussianComputeChunkQuotas` keeps (`GaussianChunkLevelState`,
/// ShaderTypes.h) unpacked: the level drawn, the outgoing window's level (nil = none) and count,
/// the pending level of a detected switch, and the frame of the last commit.
extension GaussianChunkLevelState {
    /// The initial state: fine, nothing fading, nothing pending (all zero).
    static let initial = GaussianChunkLevelState()

    init(level: Int, outLevel: Int? = nil, outCount: UInt32 = 0, pending: Int? = nil, switchFrame: UInt32 = 0) {
        self.init()
        word0 = (UInt32(level) & kGaussianChunkLevelStateLevelMask)
            | ((UInt32((outLevel ?? -1) + 1) << kGaussianChunkLevelStateOutShift) & kGaussianChunkLevelStateOutMask)
            | ((UInt32(pending ?? 0) << kGaussianChunkLevelStatePendingShift) & kGaussianChunkLevelStatePendingMask)
            | (pending != nil ? kGaussianChunkLevelStatePendingValid : 0)
            | (min(outCount, 0x00FF_FFFF) << kGaussianChunkLevelStateCountShift)
        self.switchFrame = switchFrame
    }

    /// The level drawn (0 fine, 1, 2).
    var level: Int {
        Int(word0 & kGaussianChunkLevelStateLevelMask)
    }

    /// The outgoing window's level, nil when nothing is fading out.
    var outLevel: Int? {
        let out = (word0 & kGaussianChunkLevelStateOutMask) >> kGaussianChunkLevelStateOutShift
        return out == 0 ? nil : Int(out) - 1
    }

    /// The pending level of a switch detected last frame, nil when none.
    var pending: Int? {
        (word0 & kGaussianChunkLevelStatePendingValid) != 0 ? Int((word0 & kGaussianChunkLevelStatePendingMask) >> kGaussianChunkLevelStatePendingShift) : nil
    }

    /// The outgoing window's splat count.
    var outCount: UInt32 {
        word0 >> kGaussianChunkLevelStateCountShift
    }

    /// Whether the outgoing window is still fading at `frame` (`gaussianLevelStateFading`).
    func isFading(frame: UInt32, fadeFrames: UInt32) -> Bool {
        outLevel != nil && fadeFrames != 0 && (frame &- switchFrame) < fadeFrames
    }
}

/// The visible-chunk record with `visibleChunks` chunks holding `visibleSplats` splats counted as
/// visible — a freshly loaded entity's state until its first chunk cull, with every chunk listed.
func makeGaussianVisibleChunkSet(visibleChunks: UInt32, visibleSplats: UInt32) -> GaussianVisibleSet {
    var set = GaussianVisibleSet()
    set.visibleCount = visibleSplats
    set.threadgroupCount = visibleChunks
    set.overflowCount = 0
    set.threadgroupsPerGrid = (visibleChunks, 1, 1)
    set.vertexCount = 4
    set.instanceCount = visibleSplats
    set.vertexStart = 0
    set.baseInstance = 0
    return set
}

/// Allocates the per-in-flight-slot visible-chunk list and record of a chunk table, each slot
/// seeded with every chunk visible. An entity with coarse levels lists up to two entries per
/// chunk (the incoming window and, while a switch fades, the outgoing one): `entriesPerChunk`
/// 2 sizes the lists for it. Returns nil when a buffer cannot be made.
func allocateGaussianVisibleChunkBuffers(for table: GaussianChunkTable, entriesPerChunk: Int? = nil) -> GaussianChunkTable? {
    guard let device = renderInfo.device else { return nil }
    let entries: [GaussianVisibleChunk] = table.index.chunks.enumerated().map { index, chunk in
        GaussianVisibleChunk(chunkIndex: UInt32(index), splatCount: chunk.splatCount, quota: chunk.splatCount, screenArea: Float(chunk.splatCount))
    }
    let splatTotal = entries.reduce(UInt32(0)) { $0 &+ $1.splatCount }
    // Two entries per chunk for an entity with coarse levels (the incoming window and, while a
    // switch fades, the outgoing one), one otherwise.
    let perChunk = entriesPerChunk ?? (table.hasCoarse ? 2 : 1)
    let listLength = max(1, entries.count * max(1, perChunk)) * MemoryLayout<GaussianVisibleChunk>.stride

    var result = table
    result.visibleChunks = []
    result.visibleChunkSets = []
    for slot in 0 ..< maxInFlightCommandBuffers {
        guard let list = device.makeBuffer(length: listLength, options: .storageModeShared),
              let set = device.makeBuffer(length: MemoryLayout<GaussianVisibleSet>.stride, options: .storageModeShared)
        else { return nil }
        list.label = "Gaussian Visible Chunks \(slot)"
        set.label = "Gaussian Visible Chunk Set \(slot)"
        if !entries.isEmpty {
            list.contents().copyMemory(from: entries, byteCount: entries.count * MemoryLayout<GaussianVisibleChunk>.stride)
        }
        set.contents().storeBytes(
            of: makeGaussianVisibleChunkSet(visibleChunks: UInt32(entries.count), visibleSplats: splatTotal),
            as: GaussianVisibleSet.self
        )
        result.visibleChunks.append(list)
        result.visibleChunkSets.append(set)
    }
    return result
}

/// The compiled kernels of the per-chunk path, or nil while any of them is missing (a `.untoldgs`
/// is then decoded at load into the whole-buffer path like a `.ply`).
struct GaussianChunkCullPipelineStates {
    let reset: MTLComputePipelineState
    let cull: MTLComputePipelineState
    let finalize: MTLComputePipelineState
    /// `gaussianChunkDecodePreprocess`: the fused decode, test, project and compact.
    let decodePreprocess: MTLComputePipelineState
    let resetBudget: MTLComputePipelineState
    let budgetScale: MTLComputePipelineState
    let chunkQuotas: MTLComputePipelineState
    let publishBudget: MTLComputePipelineState
    /// `gaussianReserveBudgetSplats`: a whole-buffer entity's visible count, reserved before the quotas.
    let reserveBudget: MTLComputePipelineState

    static func current() -> GaussianChunkCullPipelineStates? {
        guard gaussianResetVisibleChunkSetPipeline.success,
              gaussianChunkCullPipeline.success,
              gaussianFinalizeVisibleChunksPipeline.success,
              gaussianChunkDecodePreprocessPipeline.success,
              gaussianResetBudgetRequestPipeline.success,
              gaussianComputeBudgetScalePipeline.success,
              gaussianComputeChunkQuotasPipeline.success,
              gaussianPublishBudgetStatePipeline.success,
              gaussianReserveBudgetSplatsPipeline.success,
              let reset = gaussianResetVisibleChunkSetPipeline.pipelineState,
              let cull = gaussianChunkCullPipeline.pipelineState,
              let finalize = gaussianFinalizeVisibleChunksPipeline.pipelineState,
              let decodePreprocess = gaussianChunkDecodePreprocessPipeline.pipelineState,
              let resetBudget = gaussianResetBudgetRequestPipeline.pipelineState,
              let budgetScale = gaussianComputeBudgetScalePipeline.pipelineState,
              let chunkQuotas = gaussianComputeChunkQuotasPipeline.pipelineState,
              let publishBudget = gaussianPublishBudgetStatePipeline.pipelineState,
              let reserveBudget = gaussianReserveBudgetSplatsPipeline.pipelineState
        else { return nil }
        return GaussianChunkCullPipelineStates(
            reset: reset,
            cull: cull,
            finalize: finalize,
            decodePreprocess: decodePreprocess,
            resetBudget: resetBudget,
            budgetScale: budgetScale,
            chunkQuotas: chunkQuotas,
            publishBudget: publishBudget,
            reserveBudget: reserveBudget
        )
    }
}

/// The view-projections one entity's chunks are tested against this frame. In a stereo frame
/// these are the two eyes: each eye's projection × the scene root's effective view of the raw
/// per-eye view `renderXR` last received (`renderInfo.xrEye0/1View`, `xrEye0/1Projection`) ×
/// the entity's model matrix. Rebuilding them here rather than reusing the composed
/// `renderInfo.xrEye0/1ViewProjection` matters: those carry the scene root of the frame that
/// drew them, while the per-splat pass this frame uses `effectiveViewMatrix` with the root
/// `updateIfNeeded` just committed — with the same root on both sides, eye 1's matrix here is
/// exactly the per-splat matrix (`cameraComponent.viewSpace` and `perspectiveSpace` hold the
/// last eye's raw view and projection), so the chunk stage still never removes a splat the
/// per-splat test keeps, even on a frame the root jumped (recentre, pinch-drag). The chunk list
/// itself is eye-agnostic — a chunk only one eye sees survives — but in Stage 1 the per-splat
/// stage that follows still filters against that single head-centre view; the either-eye rule
/// only changes the stereo image once the fused per-chunk pass replaces it. In mono, or before
/// the first stereo frame has written the eye matrices, both are the camera's projection × view
/// × model and `count` is 1.
func gaussianChunkCullViewProjections(
    modelMatrix: simd_float4x4,
    viewMatrix: simd_float4x4
) -> (first: simd_float4x4, second: simd_float4x4, count: UInt32) {
    if renderInfo.isXRStereoMode,
       renderInfo.xrEye0Projection != matrix_identity_float4x4,
       renderInfo.xrEye1Projection != matrix_identity_float4x4
    {
        let root = SceneRootTransform.shared
        let eye0 = simd_mul(renderInfo.xrEye0Projection, simd_mul(root.effectiveViewMatrix(renderInfo.xrEye0View), modelMatrix))
        let eye1 = simd_mul(renderInfo.xrEye1Projection, simd_mul(root.effectiveViewMatrix(renderInfo.xrEye1View), modelMatrix))
        return (eye0, eye1, 2)
    }
    let headViewProjection = simd_mul(renderInfo.perspectiveSpace, simd_mul(viewMatrix, modelMatrix))
    return (headViewProjection, headViewProjection, 1)
}

/// The constants of one entity's chunk cull this frame. `uniformQuotas` is the frame's
/// `GaussianDebugOptions.disableScreenWeightedQuotas`, read once per frame by the caller so the
/// cull and the scale kernel agree (the fused pass's rebuilt constants carry it and ignore it).
/// `paged` is 0 for a whole-resident entity, 1 for one whose records live in a page pool
/// (`GaussianPageManager`), 2 for a demand-only cull of a warming tier.
func gaussianChunkCullConstants(
    chunkTable: GaussianChunkTable,
    modelMatrix: simd_float4x4,
    viewMatrix: simd_float4x4,
    hzbValid: Bool,
    forceAllVisible: Bool = GaussianDebugOptions.shared.disableChunkCull,
    uniformQuotas: Bool,
    paged: UInt32 = 0
) -> GaussianChunkCullConstants {
    let views = gaussianChunkCullViewProjections(modelMatrix: modelMatrix, viewMatrix: viewMatrix)
    var constants = GaussianChunkCullConstants()
    constants.viewProjection0 = views.first
    constants.viewProjection1 = views.second
    constants.viewCount = views.count
    constants.viewport = renderInfo.viewPort ?? simd_float2(1, 1)
    constants.clipGuardBand = gaussianCullClipGuardBand
    constants.hzbOcclusionBias = gaussianCullHZBOcclusionBias
    constants.chunkCount = UInt32(chunkTable.chunkCount)
    constants.hzbValid = hzbValid ? 1 : 0
    constants.hzbReverseZ = renderInfo.reverseZEnabled ? 1 : 0
    constants.hzbMipCount = UInt32(max(0, renderInfo.hzbMipCount))
    constants.forceAllVisible = forceAllVisible ? 1 : 0
    constants.uniformQuotas = uniformQuotas ? 1 : 0
    constants.paged = paged
    return constants
}

/// Byte offset of the histogram's visible-chunk counter, the word `gaussianFinalizeVisibleChunks`
/// binds at `gaussianChunkCullDensityHistogramIndex`.
let gaussianDensityHistogramVisibleChunksOffset = MemoryLayout<GaussianBudgetDensityHistogram>.offset(of: \.visibleChunks) ?? 2060

/// Byte offset of the budget state's `transitionSplats`, the first of the three level words
/// (`transitionSplats`, `coarseChunks`, `coarseSplats`) the cull and the quota pass add to.
let gaussianBudgetStateTransitionOffset = MemoryLayout<GaussianBudgetState>.offset(of: \.transitionSplats) ?? 32

// MARK: - Per-chunk levels

/// The GPU buffers of an entity's coarse levels the three per-chunk kernels bind: the coarse
/// rows of the decode constants (`GaussianChunkDecodeConstants × levelCount × chunkCount`,
/// level-major), the coarse records (`uint4 × coarseRecordCount`, as stored in the file) and
/// the persistent per-chunk level state (`GaussianChunkLevelState × chunkCount`). nil binds the
/// fine constants as a never-read stand-in and `GaussianChunkLevelConstants()` (hasCoarse 0).
struct GaussianChunkLevelBuffers {
    let coarseTable: MTLBuffer
    let coarseRecords: MTLBuffer
    let levelState: MTLBuffer
}

/// The density floor of the level rule (`GaussianChunkLevelConstants.densityFloor`): at most
/// `maxSplatsPerPixel` splats per pixel of the viewport, in splats per view unit of screen area
/// — `maxSplatsPerPixel × viewport.x × viewport.y`; +inf when the knob is off (0 or not finite).
func gaussianDensityFloor(viewport: simd_float2, maxSplatsPerPixel: Float = GaussianRuntimeLimits.maxSplatsPerPixel) -> Float {
    guard maxSplatsPerPixel > 0, maxSplatsPerPixel.isFinite else { return .infinity }
    let pixels = max(viewport.x, 1) * max(viewport.y, 1)
    return maxSplatsPerPixel * pixels
}

/// The level constants of one chunked entity for a frame: `levelCount` resident coarse levels
/// (0 keeps every kernel on the paths without levels), the file's ratios (the runtime's level 1
/// is the file's finest resident level: `ratioLog2` holds the resident levels' ratios, finest
/// first), the frame clock (the pager's tick, or the entity's executed-frame counter), and the
/// frame's switches. `cull` supplies the chunk count, `paged` and `uniformQuotas` the quota pass
/// needs; `viewport` (and `maxSplatsPerPixel`) the density floor.
func gaussianChunkLevelConstants(
    levelCount: Int,
    ratioLog2: [UInt8],
    frameIndex: UInt32,
    cull: GaussianChunkCullConstants,
    viewport: simd_float2? = nil,
    fadeFrames: UInt32 = GaussianDebugOptions.shared.disableLevelCrossFade ? 0 : GaussianPagingPolicy.fadeFrames,
    levelMode: GaussianLevelMode = GaussianDebugOptions.shared.gaussianLevelMode,
    debugTint: Bool = GaussianDebugOptions.shared.levelDebugTint,
    maxSplatsPerPixel: Float = GaussianRuntimeLimits.maxSplatsPerPixel
) -> GaussianChunkLevelConstants {
    var constants = GaussianChunkLevelConstants()
    let resident = max(0, min(levelCount, ratioLog2.count, Int(UntoldGSFormat.maxCoarseLevels)))
    constants.hasCoarse = UInt32(resident)
    if resident > 0 {
        constants.tierShift1 = UInt32(GaussianChunkCullMath.tierShift(ratioLog2: ratioLog2[0]))
        constants.tierShift2 = UInt32(GaussianChunkCullMath.tierShift(ratioLog2: ratioLog2[min(1, resident - 1)]))
    }
    constants.frameIndex = frameIndex
    constants.fadeFrames = fadeFrames
    constants.levelMode = levelMode.rawValue
    constants.debugTint = debugTint ? 1 : 0
    constants.densityFloor = gaussianDensityFloor(viewport: viewport ?? cull.viewport, maxSplatsPerPixel: maxSplatsPerPixel)
    constants.chunkCount = cull.chunkCount
    constants.paged = cull.paged
    constants.uniformQuotas = cull.uniformQuotas
    return constants
}

/// The level constants of an entity whose chunk table carries a coarse table: the resident levels
/// and their ratios from it, the frame clock from the caller (the pager's tick, or
/// `GaussianChunkTable.executedFrames`), the switches from the frame.
func gaussianChunkLevelConstants(
    coarse: GaussianCoarseTable,
    frameIndex: UInt32,
    cull: GaussianChunkCullConstants,
    viewport: simd_float2? = nil,
    fadeFrames: UInt32 = GaussianDebugOptions.shared.disableLevelCrossFade ? 0 : GaussianPagingPolicy.fadeFrames,
    levelMode: GaussianLevelMode = GaussianDebugOptions.shared.gaussianLevelMode,
    debugTint: Bool = GaussianDebugOptions.shared.levelDebugTint,
    maxSplatsPerPixel: Float = GaussianRuntimeLimits.maxSplatsPerPixel
) -> GaussianChunkLevelConstants {
    gaussianChunkLevelConstants(
        levelCount: coarse.levelCount,
        ratioLog2: coarse.ratioLog2,
        frameIndex: frameIndex,
        cull: cull,
        viewport: viewport,
        fadeFrames: fadeFrames,
        levelMode: levelMode,
        debugTint: debugTint,
        maxSplatsPerPixel: maxSplatsPerPixel
    )
}

/// The coarse levels a component draws this frame: its chunk table's coarse table, unless the
/// pager faulted them (a CRC mismatch on a piece: the entity then draws fine only for good).
func gaussianActiveCoarseTable(_ component: GaussianComponent) -> GaussianCoarseTable? {
    guard let coarse = component.chunkTable?.coarse else { return nil }
    if component.pager?.coarseFaulted == true { return nil }
    return coarse
}

/// Encodes one entity's chunk cull for one in-flight slot on an open compute encoder: reset the
/// record, one thread per chunk (binning every visible chunk into `densityHistogram`), finalize
/// into indirect arguments and add the entity's visible splat total to `budgetState`'s request
/// and its chunk count to the histogram. Serial on the encoder, so the quota and fused
/// dispatches that follow see the final list. A paged entity (`constants.paged == 1`) binds
/// this slot's residency and demand tables; an unpaged one binds the chunk table as a
/// never-read stand-in at both indices. An entity with coarse levels binds them (`levels`,
/// `levelConstants`); without, the stand-ins and `hasCoarse == 0`. Returns the dispatch count.
func encodeGaussianChunkCull(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer,
    densityHistogram: MTLBuffer,
    constants: GaussianChunkCullConstants,
    hzbTexture: MTLTexture?,
    residency: MTLBuffer? = nil,
    demand: MTLBuffer? = nil,
    levels: GaussianChunkLevelBuffers? = nil,
    levelConstants: GaussianChunkLevelConstants = GaussianChunkLevelConstants()
) -> Int {
    encoder.setComputePipelineState(pipelines.reset)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))

    encodeGaussianChunkCullDispatch(
        encoder,
        pipelines: pipelines,
        chunkTable: chunkTable,
        visibleChunks: visibleChunks,
        chunkSet: chunkSet,
        budgetState: budgetState,
        densityHistogram: densityHistogram,
        constants: constants,
        hzbTexture: hzbTexture,
        residency: residency,
        demand: demand,
        levels: levels,
        levelConstants: levelConstants
    )

    encodeGaussianFinalizeVisibleChunks(encoder, pipelines: pipelines, chunkSet: chunkSet, budgetState: budgetState, densityHistogram: densityHistogram)

    return 3
}

/// The cull dispatch alone: one thread per chunk of `chunkTable`. `budgetState` nil (a
/// demand-only cull) binds a stand-in for the transition counter the kernel then never adds to.
private func encodeGaussianChunkCullDispatch(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer?,
    densityHistogram: MTLBuffer,
    constants: GaussianChunkCullConstants,
    hzbTexture: MTLTexture?,
    residency: MTLBuffer?,
    demand: MTLBuffer?,
    levels: GaussianChunkLevelBuffers?,
    levelConstants: GaussianChunkLevelConstants
) {
    var constants = constants
    var levelConstants = levelConstants
    if levels == nil {
        levelConstants.hasCoarse = 0
    }
    encoder.setComputePipelineState(pipelines.cull)
    encoder.setBuffer(chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullChunkTableIndex.rawValue))
    encoder.setBytes(&constants, length: MemoryLayout<GaussianChunkCullConstants>.stride, index: Int(gaussianChunkCullConstantsIndex.rawValue))
    encoder.setBuffer(visibleChunks, offset: 0, index: Int(gaussianChunkCullVisibleChunksIndex.rawValue))
    // The record's two counters: visibleCount (splat total) at offset 0, threadgroupCount
    // (visible chunks) at offset 4 — see GaussianVisibleSet.
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianChunkCullSplatTotalIndex.rawValue))
    encoder.setBuffer(chunkSet, offset: MemoryLayout<UInt32>.stride, index: Int(gaussianChunkCullChunkTotalIndex.rawValue))
    // The state's transitionSplats, the outgoing windows of fading chunks (entities with levels).
    if let budgetState {
        encoder.setBuffer(budgetState, offset: gaussianBudgetStateTransitionOffset, index: Int(gaussianChunkCullBudgetStateIndex.rawValue))
    } else {
        encoder.setBuffer(chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullBudgetStateIndex.rawValue))
    }
    // The histogram's tiers as atomic words: 8t the splats, 8t + 1 the scaled area, 8t + 2 … 8t + 4 the level words.
    encoder.setBuffer(densityHistogram, offset: 0, index: Int(gaussianChunkCullDensityHistogramIndex.rawValue))
    // Paged entities only; the kernel never reads these with paged == 0.
    encoder.setBuffer(residency ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullResidencyIndex.rawValue))
    encoder.setBuffer(demand ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullDemandIndex.rawValue))
    // Entities with coarse levels only; the kernel never reads these with hasCoarse == 0.
    encoder.setBuffer(levels?.coarseTable ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullCoarseTableIndex.rawValue))
    encoder.setBuffer(levels?.levelState ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkCullLevelStateIndex.rawValue))
    encoder.setBytes(&levelConstants, length: MemoryLayout<GaussianChunkLevelConstants>.stride, index: Int(gaussianChunkCullLevelConstantsIndex.rawValue))
    encoder.setTexture(hzbTexture, index: Int(gaussianChunkCullHZBDepthPyramidTextureIndex.rawValue))
    let tew = pipelines.cull.threadExecutionWidth
    let block = max(min(256, pipelines.cull.maxTotalThreadsPerThreadgroup) / tew * tew, tew)
    encoder.dispatchThreadgroups(
        MTLSizeMake((chunkTable.chunkCount + block - 1) / block, 1, 1),
        threadsPerThreadgroup: MTLSizeMake(block, 1, 1)
    )
}

/// Encodes a demand-only cull of a paged tier that is warming before the LOD system switches to
/// it: one thread per chunk writes the chunk's seen screen area into `demand` and returns —
/// no list, no record, nothing added to the frame's request or histogram. `constants.paged`
/// must be 2 (the list and counters bound here are the tier's own slot buffers, which the
/// kernel then never touches). Returns the dispatch count.
func encodeGaussianChunkDemand(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    densityHistogram: MTLBuffer,
    demand: MTLBuffer,
    constants: GaussianChunkCullConstants,
    hzbTexture: MTLTexture?
) -> Int {
    var constants = constants
    constants.paged = 2
    encodeGaussianChunkCullDispatch(
        encoder,
        pipelines: pipelines,
        chunkTable: chunkTable,
        visibleChunks: visibleChunks,
        chunkSet: chunkSet,
        budgetState: nil,
        densityHistogram: densityHistogram,
        constants: constants,
        hzbTexture: hzbTexture,
        residency: nil,
        demand: demand,
        levels: nil,
        levelConstants: GaussianChunkLevelConstants()
    )
    return 1
}

/// The finalize of one entity's chunk record: indirect arguments, the request into `budgetState`
/// and the visible chunk count into the histogram's counter (bound at its byte offset).
private func encodeGaussianFinalizeVisibleChunks(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer,
    densityHistogram: MTLBuffer
) {
    encoder.setComputePipelineState(pipelines.finalize)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianChunkCullBudgetStateIndex.rawValue))
    encoder.setBuffer(densityHistogram, offset: gaussianDensityHistogramVisibleChunksOffset, index: Int(gaussianChunkCullDensityHistogramIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Encodes an empty visible-chunk record for one entity — reset and finalize, no cull — so a
/// hidden entity (opacityScale 0) lists no chunk, asks nothing of the budget, adds no chunk to
/// the histogram and dispatches no threadgroup of the fused pass. Returns the dispatch count.
func encodeGaussianEmptyChunkSet(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer,
    densityHistogram: MTLBuffer
) -> Int {
    encoder.setComputePipelineState(pipelines.reset)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianVisibleCountIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
    encodeGaussianFinalizeVisibleChunks(encoder, pipelines: pipelines, chunkSet: chunkSet, budgetState: budgetState, densityHistogram: densityHistogram)
    return 2
}

// MARK: - Budget and quotas

/// The scale kernel's inputs for a frame whose shared set holds `budget` records.
/// `resetHysteresis` makes the frame take its target as a first frame would; `uniformQuotas`
/// is the frame's `disableScreenWeightedQuotas`, the value the chunk culls were given.
/// `densityFloor` and `tierShifts` are the level rule's inputs the solve folds in for the
/// frame's entities with coarse levels — the floor of the frame's viewport, the maximum shifts
/// over those entities: a larger shift keeps a chunk fine further under its own density, so the
/// maximum is the most fine-leaning rule, and `R(d)` charges the fine term wherever any entity
/// still draws fine (an entity with smaller shifts draws a coarse count there, at most the fine
/// term's floor) — one-sided; unused when no tier holds a levelled chunk.
func gaussianBudgetScaleConstants(
    budget: Int,
    forceUnitScale: Bool = GaussianDebugOptions.shared.disableWorkingSetBudget,
    resetHysteresis: Bool = false,
    uniformQuotas: Bool,
    densityFloor: Float = .infinity,
    tierShifts: (UInt32, UInt32) = (0, 0)
) -> GaussianBudgetScaleConstants {
    var constants = GaussianBudgetScaleConstants()
    constants.budget = UInt32(max(0, min(budget, Int(UInt32.max))))
    constants.forceUnitScale = forceUnitScale ? 1 : 0
    constants.headroom = gaussianBudgetHeadroom
    constants.maxStepFraction = gaussianBudgetMaxStepFraction
    constants.minStep = gaussianBudgetMinStep
    constants.resetHysteresis = resetHysteresis ? 1 : 0
    constants.uniformQuotas = uniformQuotas ? 1 : 0
    constants.densityMinStepFraction = gaussianBudgetDensityMinStepFraction
    constants.densityFloor = densityFloor
    constants.tierShift1 = tierShifts.0
    constants.tierShift2 = tierShifts.1
    return constants
}

/// One threadgroup of one thread per histogram tier: the shape of the budget reset and publish.
private let gaussianDensityHistogramThreadgroup = MTLSizeMake(gaussianDensityTierCount, 1, 1)

/// Zeroes the frame's request, reservation and grant counters and the density histogram, before
/// any entity's cull. One dispatch of one threadgroup, a thread per tier.
func encodeGaussianBudgetReset(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, budgetState: MTLBuffer, densityHistogram: MTLBuffer) {
    encoder.setComputePipelineState(pipelines.resetBudget)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.setBuffer(densityHistogram, offset: 0, index: Int(gaussianBudgetDensityHistogramIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: gaussianDensityHistogramThreadgroup)
}

/// Reserves one whole-buffer entity's visible count out of the frame's budget, after its
/// `gaussianFinalizeVisibleSet` on the same encoder and before the scale dispatch. One dispatch.
func encodeGaussianBudgetReserve(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, visibleSet: MTLBuffer, budgetState: MTLBuffer) {
    encoder.setComputePipelineState(pipelines.reserveBudget)
    encoder.setBuffer(visibleSet, offset: 0, index: Int(gaussianBudgetChunkSetIndex.rawValue))
    // reservedSplats is the state's seventh word — see GaussianBudgetState.
    encoder.setBuffer(budgetState, offset: 6 * MemoryLayout<UInt32>.stride, index: Int(gaussianBudgetReservedTotalIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Turns the frame's request into its scale and, from the histogram, its density cap, after
/// every entity's chunk cull. One dispatch.
func encodeGaussianBudgetScale(_ encoder: MTLComputeCommandEncoder, pipelines: GaussianChunkCullPipelineStates, budgetState: MTLBuffer, densityHistogram: MTLBuffer, constants: GaussianBudgetScaleConstants) {
    var constants = constants
    encoder.setComputePipelineState(pipelines.budgetScale)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.setBytes(&constants, length: MemoryLayout<GaussianBudgetScaleConstants>.stride, index: Int(gaussianBudgetScaleConstantsIndex.rawValue))
    encoder.setBuffer(densityHistogram, offset: 0, index: Int(gaussianBudgetDensityHistogramIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(1, 1, 1))
}

/// Grants one entity's visible chunks their quotas at the frame's density cap, after the scale
/// dispatch: one threadgroup striding over the visible-chunk list. An entity with coarse levels
/// binds them (`levels`, `levelConstants`, and this slot's `residency` when paged) and the pass
/// chooses each chunk's level; without, the stand-ins and `hasCoarse == 0`. One dispatch.
func encodeGaussianChunkQuotas(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    chunkTable: GaussianChunkTable,
    visibleChunks: MTLBuffer,
    chunkSet: MTLBuffer,
    budgetState: MTLBuffer,
    residency: MTLBuffer? = nil,
    levels: GaussianChunkLevelBuffers? = nil,
    levelConstants: GaussianChunkLevelConstants = GaussianChunkLevelConstants()
) {
    var levelConstants = levelConstants
    if levels == nil {
        levelConstants.hasCoarse = 0
    }
    encoder.setComputePipelineState(pipelines.chunkQuotas)
    encoder.setBuffer(chunkSet, offset: 0, index: Int(gaussianBudgetChunkSetIndex.rawValue))
    encoder.setBuffer(visibleChunks, offset: 0, index: Int(gaussianBudgetVisibleChunksIndex.rawValue))
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    // quotaSplats is the state's second word — see GaussianBudgetState.
    encoder.setBuffer(budgetState, offset: MemoryLayout<UInt32>.stride, index: Int(gaussianBudgetQuotaTotalIndex.rawValue))
    // Entities with coarse levels only; the kernel never reads these with hasCoarse == 0.
    encoder.setBuffer(levels?.levelState ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianBudgetLevelStateIndex.rawValue))
    encoder.setBuffer(residency ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianBudgetResidencyIndex.rawValue))
    encoder.setBuffer(levels?.coarseTable ?? chunkTable.constantsBuffer, offset: 0, index: Int(gaussianBudgetCoarseTableIndex.rawValue))
    encoder.setBytes(&levelConstants, length: MemoryLayout<GaussianChunkLevelConstants>.stride, index: Int(gaussianBudgetLevelConstantsIndex.rawValue))
    encoder.setBuffer(chunkTable.constantsBuffer, offset: 0, index: Int(gaussianBudgetChunkTableIndex.rawValue))
    // The state's transitionSplats, coarseChunks and coarseSplats — see GaussianBudgetState.
    encoder.setBuffer(budgetState, offset: gaussianBudgetStateTransitionOffset, index: Int(gaussianBudgetLevelTotalsIndex.rawValue))
    let tew = pipelines.chunkQuotas.threadExecutionWidth
    let threads = max(min(chunkTable.chunkCount, pipelines.chunkQuotas.maxTotalThreadsPerThreadgroup) / tew * tew, tew)
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(threads, 1, 1))
}

/// Copies the frame's final budget state and density histogram into `readback` and
/// `densityReadback` for the CPU. One dispatch of one threadgroup, a thread per tier.
func encodeGaussianBudgetPublish(
    _ encoder: MTLComputeCommandEncoder,
    pipelines: GaussianChunkCullPipelineStates,
    budgetState: MTLBuffer,
    readback: MTLBuffer,
    densityHistogram: MTLBuffer,
    densityReadback: MTLBuffer
) {
    encoder.setComputePipelineState(pipelines.publishBudget)
    encoder.setBuffer(budgetState, offset: 0, index: Int(gaussianBudgetStateIndex.rawValue))
    encoder.setBuffer(readback, offset: 0, index: Int(gaussianBudgetReadbackIndex.rawValue))
    encoder.setBuffer(densityHistogram, offset: 0, index: Int(gaussianBudgetDensityHistogramIndex.rawValue))
    encoder.setBuffer(densityReadback, offset: 0, index: Int(gaussianBudgetDensityReadbackIndex.rawValue))
    encoder.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: gaussianDensityHistogramThreadgroup)
}

// MARK: - Fused decode and preprocess

/// The per-entity inputs of `gaussianChunkDecodePreprocess` beyond the shared working set. A
/// paged entity (`cullConstants.paged == 1`) also binds this slot's residency and page tables
/// and its paging constants; an unpaged one leaves them nil and the kernel never reads them. An
/// entity with coarse levels binds them (`levels`, `levelConstants`); without, the stand-ins
/// and `hasCoarse == 0`.
struct GaussianChunkPreprocessInputs {
    var packedSplats: MTLBuffer
    var chunkTable: GaussianChunkTable
    var visibleChunks: MTLBuffer
    var uniforms: Uniforms
    var cullConstants: GaussianChunkCullConstants
    var viewport: simd_float2
    var sphericalHarmonics: MTLBuffer?
    var shMetadata: GaussianSHMetadata
    var localCameraPosition: simd_float3
    var entityConstants: GaussianPreprocessEntityConstants
    var hzbTexture: MTLTexture?
    var residency: MTLBuffer?
    var pageTable: MTLBuffer?
    var pagingConstants = GaussianChunkPagingConstants()
    var levels: GaussianChunkLevelBuffers?
    var levelConstants = GaussianChunkLevelConstants()
}

/// Threads per threadgroup of the fused pass: one threadgroup covers one chunk, striding when
/// the chunk holds more splats than the pipeline allows per group.
func gaussianChunkPreprocessThreadsPerThreadgroup(chunkTable: GaussianChunkTable, pipelineState: MTLComputePipelineState) -> Int {
    max(1, min(chunkTable.splatsPerChunk, pipelineState.maxTotalThreadsPerThreadgroup))
}

/// Binds the fused pass for one entity and dispatches it: one threadgroup per visible chunk,
/// indirect from `chunkSet`'s dispatch arguments, or `threadgroups` direct dispatches when a
/// test drives it by hand. `threadsPerThreadgroup` defaults to the chunk width.
func encodeGaussianChunkDecodePreprocess(
    _ encoder: MTLComputeCommandEncoder,
    pipelineState: MTLComputePipelineState,
    inputs: GaussianChunkPreprocessInputs,
    chunkSet: MTLBuffer,
    sharedRecords: MTLBuffer,
    sharedKeys: MTLBuffer,
    sharedVisibleSet: MTLBuffer,
    threadsPerThreadgroup: Int? = nil,
    threadgroups: Int? = nil
) {
    var inputs = inputs
    encoder.setComputePipelineState(pipelineState)
    encoder.setBuffer(inputs.packedSplats, offset: 0, index: Int(gaussianChunkPreprocessPackedIndex.rawValue))
    encoder.setBuffer(inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessChunkTableIndex.rawValue))
    encoder.setBuffer(inputs.visibleChunks, offset: 0, index: Int(gaussianChunkPreprocessVisibleChunksIndex.rawValue))
    encoder.setBytes(&inputs.uniforms, length: MemoryLayout<Uniforms>.stride, index: Int(gaussianChunkPreprocessUniformIndex.rawValue))
    encoder.setBytes(&inputs.cullConstants, length: MemoryLayout<GaussianChunkCullConstants>.stride, index: Int(gaussianChunkPreprocessCullConstantsIndex.rawValue))
    encoder.setBytes(&inputs.viewport, length: MemoryLayout<simd_float2>.stride, index: Int(gaussianChunkPreprocessViewportIndex.rawValue))
    // Without harmonics the metadata's degree is 0 and the kernel never reads the buffer.
    encoder.setBuffer(inputs.sphericalHarmonics ?? inputs.packedSplats, offset: 0, index: Int(gaussianChunkPreprocessSHIndex.rawValue))
    encoder.setBytes(&inputs.shMetadata, length: MemoryLayout<GaussianSHMetadata>.stride, index: Int(gaussianChunkPreprocessSHMetadataIndex.rawValue))
    encoder.setBytes(&inputs.localCameraPosition, length: MemoryLayout<simd_float3>.stride, index: Int(gaussianChunkPreprocessLocalCameraIndex.rawValue))
    encoder.setBytes(&inputs.entityConstants, length: MemoryLayout<GaussianPreprocessEntityConstants>.stride, index: Int(gaussianChunkPreprocessEntityConstantsIndex.rawValue))
    encoder.setBuffer(sharedRecords, offset: 0, index: Int(gaussianChunkPreprocessWorkingSetIndex.rawValue))
    encoder.setBuffer(sharedKeys, offset: 0, index: Int(gaussianChunkPreprocessSharedKeysIndex.rawValue))
    encoder.setBuffer(sharedVisibleSet, offset: 0, index: Int(gaussianChunkPreprocessSharedVisibleSetIndex.rawValue))
    // Paged entities only; with paged == 0 the kernel reads none of these.
    encoder.setBuffer(inputs.residency ?? inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessResidencyIndex.rawValue))
    encoder.setBuffer(inputs.pageTable ?? inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessPageTableIndex.rawValue))
    encoder.setBytes(&inputs.pagingConstants, length: MemoryLayout<GaussianChunkPagingConstants>.stride, index: Int(gaussianChunkPreprocessPagingConstantsIndex.rawValue))
    // Entities with coarse levels only; with hasCoarse == 0 the kernel reads none of these.
    if inputs.levels == nil {
        inputs.levelConstants.hasCoarse = 0
    }
    encoder.setBuffer(inputs.levels?.coarseRecords ?? inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessCoarseRecordsIndex.rawValue))
    encoder.setBuffer(inputs.levels?.coarseTable ?? inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessCoarseTableIndex.rawValue))
    encoder.setBuffer(inputs.levels?.levelState ?? inputs.chunkTable.constantsBuffer, offset: 0, index: Int(gaussianChunkPreprocessLevelStateIndex.rawValue))
    encoder.setBytes(&inputs.levelConstants, length: MemoryLayout<GaussianChunkLevelConstants>.stride, index: Int(gaussianChunkPreprocessLevelConstantsIndex.rawValue))
    encoder.setTexture(inputs.hzbTexture, index: Int(gaussianChunkPreprocessHZBDepthPyramidTextureIndex.rawValue))

    let threads = threadsPerThreadgroup ?? gaussianChunkPreprocessThreadsPerThreadgroup(chunkTable: inputs.chunkTable, pipelineState: pipelineState)
    if let threadgroups {
        encoder.dispatchThreadgroups(MTLSizeMake(threadgroups, 1, 1), threadsPerThreadgroup: MTLSizeMake(threads, 1, 1))
    } else {
        encoder.dispatchThreadgroups(
            indirectBuffer: chunkSet,
            indirectBufferOffset: Int(gaussianVisibleSetDispatchArgumentsOffset),
            threadsPerThreadgroup: MTLSizeMake(threads, 1, 1)
        )
    }
}
