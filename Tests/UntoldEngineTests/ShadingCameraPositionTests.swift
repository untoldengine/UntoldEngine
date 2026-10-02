//
//  ShadingCameraPositionTests.swift
//
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
final class ShadingCameraPositionTests: XCTestCase {
    let srt = SceneRootTransform.shared
    let eps: Float = 1e-4

    override func setUp() async throws {
        srt.position = .zero
        srt.rotation = simd_quatf()
        srt.scale = .one
        srt.updateIfNeeded()
        renderInfo.xrEyeCameraPosition = nil
    }

    override func tearDown() async throws {
        srt.position = .zero
        srt.updateIfNeeded()
        renderInfo.xrEyeCameraPosition = nil
    }

    func testEyePositionIsTheTranslationOfTheInverseViewMatrix() {
        // An eye 3.2 cm left of a head at (0, 1.6, 2), turned 30 degrees about Y.
        let rotation = simd_float4x4(simd_quatf(angle: .pi / 6, axis: simd_float3(0, 1, 0)))
        var eyeTransform = rotation
        eyeTransform.columns.3 = simd_float4(-0.032, 1.6, 2, 1)
        let viewMatrix = simd_inverse(eyeTransform)

        let position = eyePosition(fromViewMatrix: viewMatrix)

        XCTAssertEqual(position.x, -0.032, accuracy: eps)
        XCTAssertEqual(position.y, 1.6, accuracy: eps)
        XCTAssertEqual(position.z, 2, accuracy: eps)
    }

    func testOutsideXRShadingUsesTheCameraPosition() {
        let camera = CameraComponent()
        camera.localPosition = simd_float3(1, 2, 3)

        let position = shadingCameraPosition(camera)

        XCTAssertEqual(position.x, 1, accuracy: eps)
        XCTAssertEqual(position.y, 2, accuracy: eps)
        XCTAssertEqual(position.z, 3, accuracy: eps)
    }

    func testInXRShadingUsesTheEyeBeingDrawnNotTheHeadCentre() {
        let camera = CameraComponent()
        camera.localPosition = simd_float3(0, 1.6, 0)
        renderInfo.xrEyeCameraPosition = simd_float3(0.032, 1.6, 0)

        let position = shadingCameraPosition(camera)

        XCTAssertEqual(position.x, 0.032, accuracy: eps)
    }

    func testTheEyePositionGoesThroughTheSceneRootLikeTheCameraDid() {
        let camera = CameraComponent()
        renderInfo.xrEyeCameraPosition = simd_float3(0.032, 1.6, 0)
        srt.position = simd_float3(5, 0, 0)
        srt.updateIfNeeded()

        let expected = srt.effectiveCameraPosition(simd_float3(0.032, 1.6, 0))
        let position = shadingCameraPosition(camera)

        XCTAssertEqual(position.x, expected.x, accuracy: eps)
        XCTAssertEqual(position.y, expected.y, accuracy: eps)
        XCTAssertEqual(position.z, expected.z, accuracy: eps)
    }
}
