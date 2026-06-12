//
//  EngineSettingsAPITests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class EngineSettingsAPITests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        LODConfig.shared = LODConfig()
        bypassPostProcessing = false
        antiAliasingMode = .fxaa
        renderDebugViewMode = .lit
        assetBasePath = nil
        enableEngineMetrics = false
        PostFX.apply(.neutral)
        PostFX.setEnabled(.vignette, false)
        PostFX.setEnabled(.bloomThreshold, false)
        PostFX.setEnabled(.bloomComposite, false)
        PostFX.setEnabled(.chromaticAberration, false)
        PostFX.setEnabled(.depthOfField, false)
        PostFX.setEnabled(.colorCorrection, false)
    }

    func testSetLODUpdatesSharedConfig() {
        setLOD(.fadeTransitions(.enabled(duration: 0.42)))
        setLOD(.distanceBias(1.5))
        setLOD(.hysteresis(3.0))
        setLOD(.updateFrameInterval(0))
        setLOD(.minimumCameraDisplacement(-1))
        setLOD(.distanceThresholds([25, -10, 100]))

        let config = LODConfig.shared
        XCTAssertTrue(config.enableFadeTransitions)
        XCTAssertEqual(config.fadeTransitionTime, 0.42, accuracy: 0.001)
        XCTAssertEqual(config.lodBias, 1.5, accuracy: 0.001)
        XCTAssertEqual(config.hysteresis, 3.0, accuracy: 0.001)
        XCTAssertEqual(config.lodUpdateFrameInterval, 1)
        XCTAssertEqual(config.minimumCameraDisplacementForLODUpdate, 0, accuracy: 0.001)
        XCTAssertEqual(config.lodDistances, [25, 0, 100])

        setLOD(.fadeTransitions(.disabled))
        XCTAssertFalse(LODConfig.shared.enableFadeTransitions)
    }

    func testSetRenderingUpdatesGlobals() {
        setRendering(.antiAliasing(.smaa))
        if case .smaa = antiAliasingMode {} else {
            XCTFail("Expected SMAA anti-aliasing mode")
        }

        setRendering(.debugView(.depth))
        if case .depth = renderDebugViewMode {} else {
            XCTFail("Expected depth debug view")
        }

        setRendering(.postProcessing(.disabled))
        XCTAssertTrue(bypassPostProcessing)

        setRendering(.postProcessing(.enabled))
        XCTAssertFalse(bypassPostProcessing)
    }

    func testSetEngineUpdatesGlobals() {
        let url = URL(fileURLWithPath: "/tmp/GameData")

        setEngine(.assetBasePath(url))
        setEngine(.metrics(.enabled))

        XCTAssertEqual(assetBasePath, url)
        XCTAssertTrue(enableEngineMetrics)

        setEngine(.metrics(.disabled))
        XCTAssertFalse(enableEngineMetrics)
    }

    func testSetPostFXUpdatesEffectParams() {
        setPostFX(.ssao(.enabled(true)))
        setPostFX(.ssao(.radius(0.8)))
        setPostFX(.ssao(.bias(0.04)))
        setPostFX(.ssao(.intensity(0.7)))

        XCTAssertTrue(SSAOParams.shared.enabled)
        XCTAssertEqual(SSAOParams.shared.radius, 0.8, accuracy: 0.001)
        XCTAssertEqual(SSAOParams.shared.bias, 0.04, accuracy: 0.001)
        XCTAssertEqual(SSAOParams.shared.intensity, 0.7, accuracy: 0.001)

        setPostFX(.colorGrading(.enabled(true)))
        setPostFX(.colorGrading(.exposure(-0.2)))
        setPostFX(.colorGrading(.saturation(0.9)))

        XCTAssertTrue(ColorGradingParams.shared.enabled)
        XCTAssertEqual(ColorGradingParams.shared.exposure, -0.2, accuracy: 0.001)
        XCTAssertEqual(ColorGradingParams.shared.saturation, 0.9, accuracy: 0.001)

        setPostFX(.vignette(.enabled(true)))
        setPostFX(.vignette(.intensity(0.5)))
        setPostFX(.vignette(.center(simd_float2(0.4, 0.6))))

        XCTAssertTrue(VignetteParams.shared.enabled)
        XCTAssertEqual(VignetteParams.shared.intensity, 0.5, accuracy: 0.001)
        XCTAssertEqual(VignetteParams.shared.center.x, 0.4, accuracy: 0.001)
        XCTAssertEqual(VignetteParams.shared.center.y, 0.6, accuracy: 0.001)
    }

    func testSetPostFXPresetAppliesPreset() {
        setPostFX(.preset(.cinematic))

        XCTAssertTrue(ColorGradingParams.shared.enabled)
        XCTAssertEqual(ColorGradingParams.shared.exposure, -0.2, accuracy: 0.001)
        XCTAssertTrue(SSAOParams.shared.enabled)
        XCTAssertEqual(SSAOParams.shared.intensity, 0.5, accuracy: 0.001)
    }
}
