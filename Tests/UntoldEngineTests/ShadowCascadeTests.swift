//
//  ShadowCascadeTests.swift
//  UntoldEngine
//
//  Tests for the shadow cascade configuration:
//    1. csmCascadeCount reduced from 3 to 2.
//    2. ShadowSystem.makeUniforms() handles variable cascade counts safely —
//       unused GPU uniform slots are filled with identity / zero so the shader
//       reads only the cascades indicated by the cascadeCount field.
//    3. ShadowSystem.cascadeBlendStart() computes the camera-distance at which each
//       cascade begins cross-fading into the next, shared by the CPU and the shader.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

// MARK: - Cascade count

final class CsmCascadeCountTests: XCTestCase {
    func testCascadeCountIsTwo() {
        // Regression guard: csmCascadeCount was lowered from 3 to 2 for indoor scenes.
        // Changing it back without updating makeUniforms() or the split-distance logic
        // would silently reintroduce the old shadow draw-call overhead.
        XCTAssertEqual(csmCascadeCount, 2,
                       "csmCascadeCount must be 2 for indoor scenes — raise to 3 only for outdoor wide-range shadows")
    }
}

// MARK: - Max shadow casting distance API

final class MaxShadowCastingDistanceAPITests: XCTestCase {
    override func tearDown() {
        // RenderPasses.maxShadowCastingDistance is a process-global knob; restore the engine
        // default so other tests in this process don't inherit a value this test set.
        setRendering(.maxShadowCastingDistance(40.0))
        super.tearDown()
    }

    func testSetAndGetRoundTrip() {
        setRendering(.maxShadowCastingDistance(2.5))
        XCTAssertEqual(getMaxShadowCastingDistance(), 2.5, accuracy: 0.0001)
    }

    func testValueIsClampedToAPositiveMinimum() {
        // A zero or negative distance would make the shadow-distance reject in
        // RenderPasses.shadowCasterEntityIds degenerate (shadowEntityBeyondMaxDistance treats
        // maxDistance <= 0 as "cull nothing", so this guards against accidentally disabling the
        // cull entirely rather than tightening it).
        setRendering(.maxShadowCastingDistance(-5.0))
        XCTAssertGreaterThan(getMaxShadowCastingDistance(), 0.0)
    }
}

// MARK: - ShadowSystem.makeUniforms

/// ShadowSystem is a plain struct with no Metal dependencies; makeUniforms() reads
/// only its own fields and produces a CSMUniforms value safe to inspect in tests.
final class ShadowSystemMakeUniformsTests: XCTestCase {
    // Helper: build a non-identity 4x4 matrix with a recognisable value.
    private func sentinel(_ v: Float) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3.x = v
        return m
    }

    func testCascadeCountFieldMatchesGlobal() {
        let sys = ShadowSystem()
        let u = sys.makeUniforms()
        XCTAssertEqual(u.cascadeCount, Int32(csmCascadeCount),
                       "cascadeCount in the GPU uniform must match the engine constant")
    }

    func testCascadeBlendStartsArePackedIntoUniforms() {
        var sys = ShadowSystem()
        sys.cascadeBlendStarts[0] = 18.0
        if csmCascadeCount > 1 { sys.cascadeBlendStarts[1] = 56.0 }

        let starts = sys.makeUniforms().cascadeBlendStarts
        XCTAssertEqual(starts.0, 18.0, accuracy: 1e-6)
        if csmCascadeCount > 1 {
            XCTAssertEqual(starts.1, 56.0, accuracy: 1e-6)
        }
        if csmCascadeCount < 3 {
            XCTAssertEqual(starts.2, starts.0, accuracy: 1e-6)
        }
    }

    func testCascadeWorldTexelSizesArePackedIntoUniforms() {
        var sys = ShadowSystem()
        sys.cascadeWorldTexelSizes[0] = 0.01
        if csmCascadeCount > 1 { sys.cascadeWorldTexelSizes[1] = 0.04 }

        let sizes = sys.makeUniforms().cascadeWorldTexelSizes
        XCTAssertEqual(sizes.0, 0.01, accuracy: 1e-6)
        if csmCascadeCount > 1 {
            XCTAssertEqual(sizes.1, 0.04, accuracy: 1e-6)
        }
        if csmCascadeCount < 3 {
            XCTAssertEqual(sizes.2, sizes.0, accuracy: 1e-6)
        }
    }

    func testCascadeDepthSpansArePackedIntoUniforms() {
        var sys = ShadowSystem()
        sys.cascadeDepthSpans[0] = 12.0
        if csmCascadeCount > 1 { sys.cascadeDepthSpans[1] = 36.0 }

        let spans = sys.makeUniforms().cascadeDepthSpans
        XCTAssertEqual(spans.0, 12.0, accuracy: 1e-6)
        if csmCascadeCount > 1 {
            XCTAssertEqual(spans.1, 36.0, accuracy: 1e-6)
        }
        if csmCascadeCount < 3 {
            XCTAssertEqual(spans.2, spans.0, accuracy: 1e-6)
        }
    }

    func testUsedSlotsCarryAssignedMatrices() {
        var sys = ShadowSystem()
        let m0 = sentinel(1.0)
        let m1 = sentinel(2.0)
        sys.cascadeLightSpaceMatrices[0] = m0
        if csmCascadeCount > 1 { sys.cascadeLightSpaceMatrices[1] = m1 }

        let u = sys.makeUniforms()
        let (r0, r1, _) = u.lightSpaceMatrices

        XCTAssertEqual(r0.columns.3.x, 1.0, accuracy: 1e-6,
                       "Cascade 0 matrix must be passed through unchanged")
        if csmCascadeCount > 1 {
            XCTAssertEqual(r1.columns.3.x, 2.0, accuracy: 1e-6,
                           "Cascade 1 matrix must be passed through unchanged")
        }
    }

    func testUnusedMatrixSlotIsIdentity() {
        // When csmCascadeCount < 3 the third matrix slot must default to identity
        // so the shader does not read garbage when it checks cascadeCount first.
        guard csmCascadeCount < 3 else {
            // With 3 cascades all slots are used — test is inapplicable.
            return
        }
        let sys = ShadowSystem()
        let u = sys.makeUniforms()
        let (_, _, m2) = u.lightSpaceMatrices
        XCTAssertEqual(m2, matrix_identity_float4x4,
                       "Unused matrix slot (index 2) must be identity when csmCascadeCount < 3")
    }

    func testUnusedSplitSlotIsZero() {
        guard csmCascadeCount < 3 else { return }
        let sys = ShadowSystem()
        let u = sys.makeUniforms()
        XCTAssertEqual(u.cascadeSplits.2, 0.0, accuracy: 1e-6,
                       "Unused split slot (index 2) must be 0 when csmCascadeCount < 3")
    }

    func testUsedSplitValuesMatchInput() {
        var sys = ShadowSystem()
        sys.cascadeSplitDistances[0] = 25.0
        if csmCascadeCount > 1 { sys.cascadeSplitDistances[1] = 100.0 }

        let u = sys.makeUniforms()
        XCTAssertEqual(u.cascadeSplits.0, 25.0, accuracy: 1e-6,
                       "Cascade 0 split must match the value set on the system")
        if csmCascadeCount > 1 {
            XCTAssertEqual(u.cascadeSplits.1, 100.0, accuracy: 1e-6,
                           "Cascade 1 split must match the value set on the system")
        }
    }

    func testDefaultSoftnessValuesArePackedIntoUniforms() {
        let sys = ShadowSystem()
        let u = sys.makeUniforms()

        XCTAssertEqual(u.shadowSoftnessNear, 2.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessFar, 5.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessDepthScale, 1.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessEnabled, 1.0, accuracy: 1e-6)
    }

    func testCustomSoftnessValuesArePackedIntoUniforms() {
        var sys = ShadowSystem()
        sys.setSoftness(ShadowSoftnessSettings(
            enabled: false,
            nearRadiusTexels: 2.0,
            farRadiusTexels: 5.0,
            depthScale: 0.5,
            xrRadiusScale: 1.0
        ))

        let u = sys.makeUniforms()
        XCTAssertEqual(u.shadowSoftnessNear, 2.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessFar, 5.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessDepthScale, 0.5, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessEnabled, 0.0, accuracy: 1e-6)
    }

    func testSoftnessSettingsAreClampedBeforePacking() {
        var sys = ShadowSystem()
        sys.setSoftness(ShadowSoftnessSettings(
            enabled: true,
            nearRadiusTexels: -5.0,
            farRadiusTexels: -1.0,
            depthScale: 10.0,
            xrRadiusScale: 0.5
        ))

        let u = sys.makeUniforms()
        XCTAssertEqual(u.shadowSoftnessNear, 0.25, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessFar, 0.25, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessDepthScale, 2.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessEnabled, 1.0, accuracy: 1e-6)
    }

    func testXRSoftnessScaleIsAppliedWhenStereoRenderingIsActive() {
        let originalXRMode = renderInfo.isXRStereoMode
        defer { renderInfo.isXRStereoMode = originalXRMode }

        renderInfo.isXRStereoMode = true
        var sys = ShadowSystem()
        sys.setSoftness(ShadowSoftnessSettings(
            enabled: true,
            nearRadiusTexels: 2.0,
            farRadiusTexels: 5.0,
            depthScale: 1.0,
            xrRadiusScale: 1.5
        ))

        let u = sys.makeUniforms()
        XCTAssertEqual(u.shadowSoftnessNear, 3.0, accuracy: 1e-6)
        XCTAssertEqual(u.shadowSoftnessFar, 7.5, accuracy: 1e-6)
    }
}

// MARK: - ShadowSystem.cascadeBlendStart

/// Tests for the single source of truth behind the cascade cross-fade boundary.
/// This value is computed once per frame on the CPU and uploaded via makeUniforms()
/// so the shader reads it directly instead of re-deriving it from cascadeSplits —
/// see cascadeBlendStart's doc comment for why this replaced two independently
/// hand-matched formulas (one in Swift, one in Metal).
final class ShadowSystemCascadeBlendStartTests: XCTestCase {
    private let splits: [Float] = [20.0, 60.0, 150.0]

    func testBlendStartMatchesSplitWhenBlendFractionIsZero() {
        let result = ShadowSystem.cascadeBlendStart(cascadeIdx: 0, splits: splits, blendFraction: 0.0)
        XCTAssertEqual(result, splits[0], accuracy: 1e-6,
                       "With no blending, cascade 0 must fade out exactly at its own far split")
    }

    func testBlendStartForFirstCascadeUsesZeroAsIntervalStart() {
        // Cascade 0's interval is [0, 20]; blend width = 20 * 0.1 = 2.
        let result = ShadowSystem.cascadeBlendStart(cascadeIdx: 0, splits: splits, blendFraction: 0.1)
        XCTAssertEqual(result, 18.0, accuracy: 1e-6,
                       "Cascade 0 must start fading 10% of its own interval length before its split")
    }

    func testBlendStartForLaterCascadeUsesPreviousSplitAsIntervalStart() {
        // Cascade 1's interval is [20, 60], length 40; blend width = 40 * 0.1 = 4.
        let result = ShadowSystem.cascadeBlendStart(cascadeIdx: 1, splits: splits, blendFraction: 0.1)
        XCTAssertEqual(result, 56.0, accuracy: 1e-6,
                       "Cascade 1 must start fading 10% of its own interval length before its split")
    }

    func testBlendFractionIsClampedToOneHalf() {
        // Without this clamp, a fraction above 0.5 could push blendStart before the
        // interval's own start. The shader no longer computes this at all — it reads
        // cascadeBlendStarts directly — so this clamp is now the only place it happens.
        let unclamped = ShadowSystem.cascadeBlendStart(cascadeIdx: 0, splits: splits, blendFraction: 0.9)
        let clampedAtHalf = ShadowSystem.cascadeBlendStart(cascadeIdx: 0, splits: splits, blendFraction: 0.5)
        XCTAssertEqual(unclamped, clampedAtHalf, accuracy: 1e-6,
                       "A blend fraction above 0.5 must be clamped to keep blendStart inside the interval")
    }

    func testOutOfBoundsCascadeIndexReturnsZeroInsteadOfCrashing() {
        let result = ShadowSystem.cascadeBlendStart(cascadeIdx: 5, splits: splits, blendFraction: 0.1)
        XCTAssertEqual(result, 0.0, accuracy: 1e-6)
    }
}

// MARK: - Cascade world-space caster reach

/// Tests for the direction-agnostic distance reject in RenderPasses.shadowCasterEntityIds:
/// a caster farther than `cascadeWorldRadii[i] + maxShadowCastingDistance` from
/// `cascadeWorldCenters[i]` cannot matter to that cascade regardless of light direction,
/// so it is safe to drop before the more expensive light-space frustum test.
final class ShadowSystemCascadeCasterReachTests: XCTestCase {
    private let originalMaxShadowCastingDistance = RenderPasses.maxShadowCastingDistance

    override func tearDown() {
        RenderPasses.maxShadowCastingDistance = originalMaxShadowCastingDistance
    }

    func testCasterWellWithinReachIsNotExcluded() {
        RenderPasses.maxShadowCastingDistance = 40.0
        let center = simd_float3(100, 0, 0)
        let radius: Float = 20.0
        let cascadeReach = radius + RenderPasses.maxShadowCastingDistance

        // A caster sitting right at the edge of the cascade's own bounding sphere.
        let casterMin = simd_float3(100 + radius - 1, -1, -1)
        let casterMax = simd_float3(100 + radius + 1, 1, 1)

        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: casterMin, worldMax: casterMax,
            cameraPosition: center, maxDistance: cascadeReach
        ), "A caster at the edge of the cascade's own bounding sphere must never be excluded")
    }

    func testCasterAtExactHorizonOfALowAngleShadowIsNotExcluded() {
        // The whole point of this reject: a caster far from the cascade along the
        // light's raking direction, but still within the engine's own shadow-distance
        // horizon of the cascade's bounding sphere, must still be included — this is
        // exactly the class of caster the old camera-depth cull incorrectly dropped.
        RenderPasses.maxShadowCastingDistance = 100.0
        let center = simd_float3.zero
        let radius: Float = 10.0
        let cascadeReach = radius + RenderPasses.maxShadowCastingDistance // 110

        let farCaster = simd_float3(cascadeReach - 1, 0, 0)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: farCaster, worldMax: farCaster,
            cameraPosition: center, maxDistance: cascadeReach
        ), "A caster just inside the combined radius+horizon distance must be included")
    }

    func testCasterBeyondTheEnginesShadowHorizonIsExcluded() {
        RenderPasses.maxShadowCastingDistance = 40.0
        let center = simd_float3.zero
        let radius: Float = 5.0
        let cascadeReach = radius + RenderPasses.maxShadowCastingDistance // 45

        let veryFarCaster = simd_float3(cascadeReach + 1000, 0, 0)
        XCTAssertTrue(shadowEntityBeyondMaxDistance(
            worldMin: veryFarCaster, worldMax: veryFarCaster,
            cameraPosition: center, maxDistance: cascadeReach
        ), "A caster far beyond the engine's own shadow-distance horizon must be excluded")
    }

    func testZeroGlobalShadowDistanceDisablesTheReject() {
        // maxDistance == 0 means "no cap" per shadowEntityBeyondMaxDistance's contract.
        RenderPasses.maxShadowCastingDistance = 0.0
        let center = simd_float3.zero
        let radius: Float = 0.0
        let cascadeReach = radius + RenderPasses.maxShadowCastingDistance

        let veryFarCaster = simd_float3(1.0e6, 0, 0)
        XCTAssertFalse(shadowEntityBeyondMaxDistance(
            worldMin: veryFarCaster, worldMax: veryFarCaster,
            cameraPosition: center, maxDistance: cascadeReach
        ), "A zero combined reach must disable the reject entirely, not exclude everything")
    }
}
