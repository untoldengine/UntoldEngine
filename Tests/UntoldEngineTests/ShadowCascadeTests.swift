//
//  ShadowCascadeTests.swift
//  UntoldEngine
//
//  Tests for the two shadow rendering fixes:
//    1. csmCascadeCount reduced from 3 to 2.
//    2. ShadowSystem.makeUniforms() handles variable cascade counts safely —
//       unused GPU uniform slots are filled with identity / zero so the shader
//       reads only the cascades indicated by the cascadeCount field.
//    3. shadowCascadeMaxDistance() clamps each cascade to its own split distance
//       so the near cascade never receives shadow casters beyond its far plane.
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

// MARK: - shadowCascadeMaxDistance

/// Tests for the per-cascade shadow distance helper.  The logic determines how far from
/// the camera an entity may be and still cast a shadow into a given cascade — using the
/// cascade's own split distance as the tighter cap when it is less than the global max.
final class ShadowCascadeMaxDistanceTests: XCTestCase {
    private let globalMax: Float = 40.0

    func testReturnsSplitDistanceWhenSplitIsTighter() {
        // Cascade 0 split (e.g. 25 m) is inside the global 40 m cap → use split.
        let result = shadowCascadeMaxDistance(
            cascadeIdx: 0,
            splitDistances: [25.0, 100.0],
            globalMax: globalMax
        )
        XCTAssertEqual(result, 25.0, accuracy: 1e-6,
                       "When cascade split < globalMax the split distance must be used")
    }

    func testReturnsGlobalMaxWhenSplitIsWider() {
        // Cascade 1 split (e.g. 500 m with far=500) exceeds the global cap → clamp.
        let result = shadowCascadeMaxDistance(
            cascadeIdx: 1,
            splitDistances: [25.0, 500.0],
            globalMax: globalMax
        )
        XCTAssertEqual(result, globalMax, accuracy: 1e-6,
                       "When cascade split > globalMax the global max must be used")
    }

    func testReturnsSplitWhenSplitEqualsGlobalMax() {
        // Exact equality: min(40, 40) = 40.
        let result = shadowCascadeMaxDistance(
            cascadeIdx: 0,
            splitDistances: [40.0, 200.0],
            globalMax: globalMax
        )
        XCTAssertEqual(result, 40.0, accuracy: 1e-6,
                       "When split equals globalMax the result must be globalMax")
    }

    func testFallsBackToGlobalMaxWhenIndexOutOfBounds() {
        // Safety guard: if cascadeIdx >= splitDistances.count use global max.
        let result = shadowCascadeMaxDistance(
            cascadeIdx: 5,
            splitDistances: [25.0, 100.0],
            globalMax: globalMax
        )
        XCTAssertEqual(result, globalMax, accuracy: 1e-6,
                       "Out-of-bounds cascade index must fall back to globalMax, not crash")
    }

    func testFallsBackToGlobalMaxForEmptySplitDistances() {
        let result = shadowCascadeMaxDistance(
            cascadeIdx: 0,
            splitDistances: [],
            globalMax: globalMax
        )
        XCTAssertEqual(result, globalMax, accuracy: 1e-6,
                       "Empty splitDistances must fall back to globalMax")
    }

    func testNearCascadeIsTighterThanFarCascade() {
        // Validates the intent of the fix: cascade 0 gets a smaller max distance
        // than cascade 1 when its split distance is within the global cap.
        let splits: [Float] = [20.0, 500.0]
        let near = shadowCascadeMaxDistance(cascadeIdx: 0, splitDistances: splits, globalMax: globalMax)
        let far = shadowCascadeMaxDistance(cascadeIdx: 1, splitDistances: splits, globalMax: globalMax)
        XCTAssertLessThan(near, far,
                          "Near cascade max distance must be less than far cascade max distance")
        XCTAssertEqual(near, 20.0, accuracy: 1e-6)
        XCTAssertEqual(far, globalMax, accuracy: 1e-6)
    }
}
