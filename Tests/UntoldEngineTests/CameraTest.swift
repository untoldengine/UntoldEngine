//
//  CameraTest.swift
//
//
//  Created by Harold Serrano on 12/16/24.
//

import simd
@testable import UntoldEngine
import XCTest

final class CameraTests: XCTestCase {
    var camera: Camera!

    override func setUp() {
        super.setUp()
        camera = Camera()
    }

    override func tearDown() {
        camera = nil
        super.tearDown()
    }

    // MARK: - Translation Tests

    func testTranslateTo() {
        camera.translateTo(10, 20, 30)
        XCTAssertEqual(camera.localPosition, simd_float3(10, 20, 30))
    }

    func testTranslateBy() {
        camera.translateTo(0, 0, 0)
        camera.translateBy(delU: 1, delV: 2, delN: 3)
        XCTAssertNotEqual(camera.localPosition, simd_float3(0, 0, 0))
    }

    // MARK: - View Matrix Update

    func testViewMatrixUpdate() {
        camera.translateTo(0, 0, 10)
        camera.updateViewMatrix()
        let expectedPosition = simd_float3(0, 0, -10)
        let actualPosition = camera.getPosition()
        XCTAssertEqual(actualPosition, expectedPosition)
    }

    // MARK: - LookAt Tests

    func testLookAt() {
        let eye = simd_float3(0, 0, 10)
        let target = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        camera.lookAt(eye: eye, target: target, up: up)

        XCTAssertEqual(camera.localPosition, eye)
        XCTAssertEqual(camera.zAxis, simd_float3(0, 0, 1))
    }

    // MARK: - Orbit Tests

    func testOrbitAround() {
        camera.translateTo(0, 0, 10)
        camera.orbitAround(simd_float2(0.5, 0.5))
        XCTAssertNotEqual(camera.localPosition, simd_float3(0, 0, 10))
    }

    // MARK: - Rotation Tests

    func testCameraLookAboutAxis() {
        camera.cameraLookAboutAxis(uDelta: simd_float2(10, 0))
        XCTAssertNotEqual(camera.rotation, quaternion_identity())
    }

    func testRotateCamera() {
        camera.rotateCamera(yaw: .pi / 4, pitch: .pi / 4, sensitivity: 1.0)
        XCTAssertNotEqual(camera.rotation, quaternion_identity())
    }

    // MARK: - Movement Tests

    func testMoveCameraAlongAxis() {
        camera.translateTo(0, 0, 0)
        camera.moveCameraAlongAxis(uDelta: simd_float3(1, 2, 3))
        XCTAssertNotEqual(camera.localPosition, simd_float3(0, 0, 0))
    }

    func testMoveCameraWithInput() {
        camera.translateTo(0, 0, 0)
        camera.moveCameraWithInput(input: (w: true, a: false, s: false, d: false, q: false, e: false), speed: 1, deltaTime: 1)
        XCTAssertEqual(camera.localPosition.z, -1.0, accuracy: 0.0001)
    }
}
