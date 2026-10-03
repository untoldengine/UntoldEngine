//
//  SmallObjectCullingTests.swift
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

final class SmallObjectCullingTests: XCTestCase {
    private var savedPixels: Float = 0

    override func setUp() {
        super.setUp()
        savedPixels = SmallObjectCulling.minimumPixels
    }

    override func tearDown() {
        SmallObjectCulling.minimumPixels = savedPixels
        super.tearDown()
    }

    /// A view 1,000 pixels high with a 90° field of view: a sphere of radius r at
    /// distance d is 1000 * r / d pixels tall.
    private func culling(pixels: Float, camera: simd_float3 = .zero) -> SmallObjectCulling {
        SmallObjectCulling(cameraPosition: camera, minimumPixels: pixels, viewportHeight: 1000, tanHalfFovY: 1)
    }

    func testASphereUnderTheLimitIsCulledAndOneOverItIsNot() {
        let test = culling(pixels: 2)

        // Radius 0.5 at 200 is 2.5 pixels; at 300 it is 1.67.
        XCTAssertFalse(test.culls(center: simd_float3(0, 0, -200), radius: 0.5))
        XCTAssertTrue(test.culls(center: simd_float3(0, 0, -300), radius: 0.5))
        // The same sphere as far away, off to the side.
        XCTAssertTrue(test.culls(center: simd_float3(300, 0, 0), radius: 0.5))
    }

    func testTheLimitScalesWithTheViewAndTheFieldOfView() {
        let center = simd_float3(0, 0, -300)
        // Twice the pixels for the same field of view: 3.33 pixels now.
        let largerView = SmallObjectCulling(cameraPosition: .zero, minimumPixels: 2, viewportHeight: 2000, tanHalfFovY: 1)
        XCTAssertFalse(largerView.culls(center: center, radius: 0.5))
        // A narrower field of view magnifies: 3.33 pixels as well.
        let narrower = SmallObjectCulling(cameraPosition: .zero, minimumPixels: 2, viewportHeight: 1000, tanHalfFovY: 0.5)
        XCTAssertFalse(narrower.culls(center: center, radius: 0.5))
    }

    func testDistanceIsMeasuredFromTheCamera() {
        let test = culling(pixels: 2, camera: simd_float3(0, 0, -250))

        XCTAssertFalse(test.culls(center: simd_float3(0, 0, -300), radius: 0.5), "50 away: 10 pixels")
        XCTAssertTrue(test.culls(center: simd_float3(0, 0, 50), radius: 0.5), "300 away: 1.67 pixels")
    }

    func testNothingIsCulledWithALimitOfZero() {
        let test = culling(pixels: 0)

        XCTAssertFalse(test.culls(center: simd_float3(0, 0, -100_000), radius: 0.001))
        XCTAssertFalse(culling(pixels: -3).culls(center: simd_float3(0, 0, -100_000), radius: 0.001))
    }

    func testAnObjectTheCameraIsInsideOfIsNeverCulled() {
        let test = culling(pixels: 500)

        XCTAssertFalse(test.culls(center: simd_float3(0, 0, -1), radius: 2))
        XCTAssertFalse(test.culls(center: .zero, radius: 0.001))
    }

    /// Bounds that are a single point do not say how large the object draws.
    func testBoundsWithNoSizeAreNeverCulled() {
        let test = culling(pixels: 2)
        let point = simd_float3(5, 5, -1000)

        XCTAssertFalse(test.culls(center: point, radius: 0))
        XCTAssertFalse(test.culls(worldMin: point, worldMax: point))
    }

    func testABoxIsMeasuredByTheSphereAroundIt() {
        let test = culling(pixels: 2)
        // A long thin beam: 2 x 0.02 x 0.02. Its sphere has a radius just over 1.
        let low = simd_float3(-1, -0.01, -0.01)
        let high = simd_float3(1, 0.01, 0.01)
        let offset = simd_float3(0, 0, -400)

        XCTAssertFalse(test.culls(worldMin: low + offset, worldMax: high + offset), "2.5 pixels long, however thin")
        XCTAssertTrue(test.culls(worldMin: low + offset * 2, worldMax: high + offset * 2), "1.25 pixels long")
    }

    func testAViewWithoutHeightCullsNothing() {
        let test = SmallObjectCulling(cameraPosition: .zero, minimumPixels: 2, viewportHeight: 0, tanHalfFovY: 1)

        XCTAssertFalse(test.culls(center: simd_float3(0, 0, -1000), radius: 0.001))
    }

    func testTheSettingIsOnePixelByDefaultAndNeverNegative() {
        XCTAssertEqual(savedPixels, 1, "the default")

        setRendering(.smallObjectCulling(pixels: 4))
        XCTAssertEqual(getSmallObjectCullingPixels(), 4)

        setRendering(.smallObjectCulling(pixels: -2))
        XCTAssertEqual(getSmallObjectCullingPixels(), 0)

        setRendering(.smallObjectCulling(pixels: .nan))
        XCTAssertEqual(getSmallObjectCullingPixels(), 0)
    }

    func testThereIsNoTestWhenTheSettingIsOff() {
        setRendering(.smallObjectCulling(pixels: 0))

        XCTAssertNil(SmallObjectCulling.forCurrentFrame())
    }
}
