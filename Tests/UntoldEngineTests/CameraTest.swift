//
//  CameraTest.swift
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

final class CameraTests: XCTestCase {
    var camera: EntityID!

    override func setUp() {
        super.setUp()
        resetEngineTestState()
        camera = createEntity()

        CameraSystem.shared.activeCamera = camera
        createGameCamera(entityId: camera)
        Logger.logLevel = .none
    }

    override func tearDown() {
        super.tearDown()
        destroyEntity(entityId: camera)
    }

    // MARK: - Translation Tests

    func testTranslateTo() {
        moveCameraTo(entityId: camera, 10, 20, 30)
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertEqual(cameraComponent.localPosition, simd_float3(10, 20, 30))
    }

    func testTranslateToSyncsLocalTransform() {
        translateTo(entityId: camera, position: simd_float3(2, 4, 6))
        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: camera) else {
            return
        }
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertEqual(localTransform.position, simd_float3(2, 4, 6))
        XCTAssertEqual(cameraComponent.localPosition, simd_float3(2, 4, 6))
        XCTAssertEqual(getCameraPosition(entityId: camera), simd_float3(2, 4, 6))
    }

    func testTranslateBy() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        moveCameraBy(entityId: camera, delU: 1, delV: 2, delN: 3)
        XCTAssertNotEqual(getCameraPosition(entityId: camera), simd_float3(0, 0, 0))
    }

    func testTranslateByUsesCameraAxes() {
        translateTo(entityId: camera, position: .zero)
        rotateTo(entityId: camera, angle: 90, axis: simd_float3(0, 1, 0))

        translateBy(entityId: camera, position: simd_float3(0, 0, 1))

        guard let localTransform = scene.get(component: LocalTransformComponent.self, for: camera) else {
            return
        }

        let forward = forwardDirectionVector(from: localTransform.rotation)
        XCTAssertEqual(localTransform.position.x, forward.x, accuracy: 0.0001)
        XCTAssertEqual(localTransform.position.y, forward.y, accuracy: 0.0001)
        XCTAssertEqual(localTransform.position.z, forward.z, accuracy: 0.0001)
    }

    // MARK: - View Matrix Update

    func testViewMatrixUpdate() {
        moveCameraTo(entityId: camera, 0, 0, 10)
        updateCameraViewMatrix(entityId: camera)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }

        let expectedPosition = simd_float3(0, 0, 10)
        XCTAssertEqual(cameraComponent.localPosition, expectedPosition)
    }

    // MARK: - LookAt Tests

    func testLookAt() {
        let eye = simd_float3(0, 0, 10)
        let target = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        cameraLookAt(entityId: camera, eye: eye, target: target, up: up)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }

        XCTAssertEqual(cameraComponent.localPosition, eye)
        XCTAssertEqual(cameraComponent.zAxis, simd_float3(0, 0, 1))
    }

    // MARK: - Orbit Tests

    func testOrbitAround() {
        moveCameraTo(entityId: camera, 0, 0, 10)
        orbitCameraAround(entityId: camera, uDelta: simd_float2(0.5, 0.5))

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }

        XCTAssertNotEqual(cameraComponent.localPosition, simd_float3(0, 0, 10))
    }

    // MARK: - Rotation Tests

    func testCameraLookAboutAxis() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        cameraComponent.rotation = .init(simd_float4x4.identity)

        cameraLookAboutAxis(entityId: camera, uDelta: simd_float2(1, 0))

        XCTAssertEqual(cameraComponent.rotation, simd_quatf(ix: 0.0, iy: 0.004999979, iz: 0.0, r: 0.9999875))
    }

    func testRotateCamera() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        cameraComponent.rotation = .init(simd_float4x4.identity)

        rotateCamera(entityId: camera, pitch: .pi / 4, yaw: .pi / 4, sensitivity: 1.0)
        let expectedRotation = simd_quatf(ix: 0.35355338, iy: 0.35355338, iz: 0.14644662, r: 0.8535534)

        XCTAssertEqual(cameraComponent.rotation.real, expectedRotation.real, accuracy: 0.01)
        XCTAssertEqual(cameraComponent.rotation.vector.x, expectedRotation.vector.x, accuracy: 0.01)
        XCTAssertEqual(cameraComponent.rotation.vector.y, expectedRotation.vector.y, accuracy: 0.01)
        XCTAssertEqual(cameraComponent.rotation.vector.z, expectedRotation.vector.z, accuracy: 0.01)
    }

    // MARK: - Movement Tests

    func testMoveCameraAlongAxis() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        moveCameraAlongAxis(entityId: camera, uDelta: simd_float3(1, 2, 3))
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertNotEqual(cameraComponent.localPosition, simd_float3(0, 0, 0))
    }

    func testMoveCameraWithInput() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        moveCameraWithInput(entityId: camera, input: (w: true, a: false, s: false, d: false, q: false, e: false), speed: 1, deltaTime: 1)
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertEqual(cameraComponent.localPosition.z, -1.0, accuracy: 0.1)
    }

    func testGetMainCamera() {
        XCTAssertEqual(findGameCamera(), camera, "Could not find Main camera")
    }

    func testCameraMoveByWorld() {
        moveCameraTo(entityId: camera, 0, 0, 0)
        cameraMoveBy(entityId: camera, delta: simd_float3(1, 2, 3), space: .world)
        guard let cam = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertEqual(cam.localPosition, simd_float3(1, 2, 3))
    }

    func testCameraFollowNoSmooth() {
        let target = createEntity()
        registerComponent(entityId: target, componentType: LocalTransformComponent.self)
        translateTo(entityId: target, position: simd_float3(10, 0, 0))
        setEntityName(entityId: target, name: "Target")

        moveCameraTo(entityId: camera, 0, 0, 0)
        cameraFollow(entityId: camera,
                     targetEntity: target,
                     offset: simd_float3(0, 2, -5),
                     smoothFactor: 0,
                     deltaTime: 0)

        guard let cam = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        XCTAssertEqual(cam.localPosition, simd_float3(10, 2, -5))
    }

    func testCameraFollowDeadZone() {
        let target = createEntity()
        registerComponent(entityId: target, componentType: LocalTransformComponent.self)
        translateTo(entityId: target, position: simd_float3(0.5, 0, 0))

        moveCameraTo(entityId: camera, 0, 0, 0)
        guard let cam = scene.get(component: CameraComponent.self, for: camera) else {
            return
        }
        cam.rotation = .init(simd_float4x4.identity)
        updateCameraViewMatrix(entityId: camera)

        cameraFollowDeadZone(entityId: camera,
                             targetEntity: target,
                             offset: simd_float3(0, 0, 0),
                             deadZoneExtents: simd_float3(1, 1, 1),
                             smoothFactor: 0,
                             deltaTime: 0)

        XCTAssertEqual(cam.localPosition, simd_float3(0, 0, 0))

        translateTo(entityId: target, position: simd_float3(3, 0, 0))

        cameraFollowDeadZone(entityId: camera,
                             targetEntity: target,
                             offset: simd_float3(0, 0, 0),
                             deadZoneExtents: simd_float3(1, 1, 1),
                             smoothFactor: 0,
                             deltaTime: 0)

        XCTAssertEqual(cam.localPosition, simd_float3(2, 0, 0))
    }
}
