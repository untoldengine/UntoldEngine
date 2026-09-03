//
//  SkyPassSmokeTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class SkyPassSmokeTest: BaseRenderSetup {
    override func initializeAssets() {
        // Controlled horizon-level camera, looking toward -Z, so sun angles sweeping through
        // that direction are actually visible in frame (rather than relying on whatever camera
        // the default UnitTestRender scene happens to ship with).
        let camera = findGameCamera()
        cameraLookAt(entityId: camera, eye: simd_float3(0.0, 2.0, 0.0), target: simd_float3(0.0, 2.0, -10.0), up: simd_float3(0.0, 1.0, 0.0))
    }

    func testSkyPassRendersAtDifferentSunAngles() throws {
        renderEnvironment = false
        renderSkyBackground = true

        let sun: EntityID
        if let existing = LightingSystem.shared.activeDirectionalLight {
            // The base render test harness (or camera setup) may already have created and
            // activated a default directional light entity; reuse it rather than creating a
            // second one that createDirLight() would silently ignore (it only adopts a new
            // light as active when none is set yet).
            sun = existing
        } else {
            sun = createEntity()
            setEntityName(entityId: sun, name: "Sun")
            createDirLight(entityId: sun)
        }
        updateLightIntensity(entityId: sun, intensity: 3.0)
        updateLightColor(entityId: sun, color: simd_float3(1.0, 0.95, 0.9))

        // pitch/yaw/roll chosen empirically against getDirectionalLightShaderDirection() so the
        // resulting world-space sun direction sweeps from overhead, to the horizon in front of
        // the camera (-Z), to below the horizon.
        let angles: [(String, Float)] = [
            ("Noon", -90.0),
            ("Sunset", 188.0),
            ("Night", 90.0),
        ]

        for (label, pitchDegrees) in angles {
            rotateTo(entityId: sun, pitch: pitchDegrees, yaw: 0.0, roll: 0.0)
            let params = getDirectionalLightParameters()
            print("[SkyPassSmokeTest] \(label): pitch=\(pitchDegrees) sunDirection=\(params.direction)")

            // Warm-up draws: the first few draw() calls after a scene/state change (or the very
            // first time this pipeline runs in the process) can land before triple-buffered
            // resources settle / the pipeline is warm, same as other render tests in this suite.
            for _ in 0 ..< 4 {
                renderer.draw(in: renderer.metalView)
            }

            guard let texture = textureResources.environmentColorMap else {
                XCTFail("environmentColorMap should exist")
                return
            }

            testGenerateRenderTarget(targetName: "SkySmoke_\(label)", texture: texture)
        }
    }
}
