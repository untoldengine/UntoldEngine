//
//  AgXToneMappingTests.swift
//  UntoldEngineTests
//
//  A Swift CPU port of LookShader.metal's agxToneMapping, mirroring
//  ShadersUtils.metal line-for-line, so the ported constants/math have a
//  visible, testable reference independent of dispatching the actual GPU
//  shader. This locks in the behavior as currently believed correct and
//  guards against silent regressions if the Metal side is edited without
//  updating this copy -- it does NOT prove pixel-parity against a real
//  Blender AgX render (no Blender available in this environment). The
//  assertions below check the well-documented qualitative signature of real
//  AgX (lifted shadows/midtones vs ACES, gamut-compression desaturation of
//  saturated colors, soft highlight rolloff that resists full clipping) as
//  the best available substitute for that missing empirical comparison.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import XCTest

private let agxInsetRows: [[Double]] = [
    [0.856627153315983, 0.137318972929847, 0.11189821299995],
    [0.0951212405381588, 0.761241990602591, 0.0767994186031903],
    [0.0482516061458583, 0.101439036467562, 0.811302368396859],
]

private let agxOutsetRows: [[Double]] = [
    [1.1271005818144368, -0.11060664309660323, -0.016493938717834573],
    [-0.1413297634984383, 1.157823702216272, -0.016493938717834257],
    [-0.14132976349843826, -0.11060664309660294, 1.2519364065950405],
]

private let agxMinEv = -12.47393
private let agxMaxEv = 4.026069

private func matVec(_ rows: [[Double]], _ v: [Double]) -> [Double] {
    rows.map { row in row[0] * v[0] + row[1] * v[1] + row[2] * v[2] }
}

private func agxContrastApprox(_ x: [Double]) -> [Double] {
    x.map { xi -> Double in
        let x2 = xi * xi
        let x4 = x2 * x2
        return 15.5 * x4 * x2 - 40.14 * x4 * xi + 31.96 * x4 - 6.868 * x2 * xi + 0.4298 * x2 + 0.1191 * xi - 0.00232
    }
}

/// CPU reference for LookShader.metal's agxToneMapping (see ShadersUtils.metal).
private func agxToneMappingReference(_ color: [Double]) -> [Double] {
    var c = color.map { max($0, 0.0) }
    c = matVec(agxInsetRows, c)
    c = c.map { max($0, 1e-10) }
    c = c.map { min(max(log2($0), agxMinEv), agxMaxEv) }
    c = c.map { ($0 - agxMinEv) / (agxMaxEv - agxMinEv) }
    c = agxContrastApprox(c)
    c = matVec(agxOutsetRows, c)
    return c.map { min(max($0, 0.0), 1.0) }
}

/// CPU reference for ShadersUtils.metal's ACESFilmicToneMapping, for comparison.
private func acesReference(_ color: [Double]) -> [Double] {
    let a = 2.51, b = 0.03, c = 2.43, d = 0.59, e = 0.14
    return color.map { x in min(max((x * (a * x + b)) / (x * (c * x + d) + e), 0.0), 1.0) }
}

final class AgXToneMappingTests: XCTestCase {
    func testBlackStaysBlack() {
        let result = agxToneMappingReference([0, 0, 0])
        for channel in result {
            XCTAssertEqual(channel, 0.0, accuracy: 1e-9)
        }
    }

    func testOutputIsBoundedZeroToOne() {
        for value: Double in [0, 0.001, 0.18, 1, 4, 100, 1000] {
            let result = agxToneMappingReference([value, value, value])
            for channel in result {
                XCTAssertGreaterThanOrEqual(channel, 0.0)
                XCTAssertLessThanOrEqual(channel, 1.0)
            }
        }
    }

    func testMonotonicAlongGreyRamp() {
        let greys: [Double] = [0.0001, 0.001, 0.01, 0.05, 0.1, 0.18, 0.3, 0.5, 1.0, 2.0, 4.0, 8.0, 20.0, 100.0]
        var previous = -1.0
        for grey in greys {
            let value = agxToneMappingReference([grey, grey, grey])[0]
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9, "AgX must not darken as scene-linear brightness increases")
            previous = value
        }
    }

    /// AgX's signature trait vs ACES/Filmic: it lifts 18% middle grey much
    /// higher (flatter, less contrasty) instead of keeping it comparatively dark.
    func test18PercentGreyLiftsHigherThanACES() {
        let agxGrey = agxToneMappingReference([0.18, 0.18, 0.18])[0]
        let acesGrey = acesReference([0.18, 0.18, 0.18])[0]
        XCTAssertGreaterThan(agxGrey, acesGrey + 0.15, "AgX is expected to lift midtones well above ACES's Narkowicz fit")
        XCTAssertEqual(agxGrey, 0.5187, accuracy: 0.01)
        XCTAssertEqual(acesGrey, 0.2669, accuracy: 0.01)
    }

    /// AgX's signature gamut-compression: pure saturated single-channel input
    /// bleeds noticeably into the other two channels (desaturates), unlike
    /// ACES's per-channel Narkowicz fit which leaves the other channels at 0.
    func testSaturatedRedDesaturatesAcrossChannels() {
        let agxRed = agxToneMappingReference([0.18, 0, 0])
        let acesRed = acesReference([0.18, 0, 0])
        XCTAssertGreaterThan(agxRed[1], 0.05, "AgX should bleed some green into a pure-red input")
        XCTAssertGreaterThan(agxRed[2], 0.01, "AgX should bleed a little blue into a pure-red input")
        XCTAssertEqual(acesRed[1], 0.0, accuracy: 1e-9, "ACES's per-channel fit should not bleed at all")
        XCTAssertEqual(acesRed[2], 0.0, accuracy: 1e-9, "ACES's per-channel fit should not bleed at all")
    }

    /// AgX's signature soft-highlight rolloff: even very large overexposure
    /// (100x) doesn't fully clip to 1.0, unlike ACES which does.
    func testExtremeHighlightsDoNotFullyClip() {
        let agxBright = agxToneMappingReference([100, 100, 100])[0]
        let acesBright = acesReference([100, 100, 100])[0]
        XCTAssertLessThan(agxBright, 1.0)
        XCTAssertEqual(acesBright, 1.0, accuracy: 1e-6, "ACES's Narkowicz fit is expected to hard-clip by this exposure")
    }

    /// Shadows lift dramatically more than ACES -- another widely-documented
    /// AgX trait (sometimes described as "flat"/"washed out" shadows).
    func testDeepShadowsLiftFarAboveACES() {
        let agxDark = agxToneMappingReference([0.001, 0.001, 0.001])[0]
        let acesDark = acesReference([0.001, 0.001, 0.001])[0]
        XCTAssertGreaterThan(agxDark, acesDark * 10, "AgX shadows should be lifted well above ACES's near-linear response here")
    }
}
