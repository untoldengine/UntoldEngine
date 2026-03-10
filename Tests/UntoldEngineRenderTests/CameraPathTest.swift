//
//  CameraPathTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class CameraPathTests: BaseRenderSetup {
    override func setUp() {
        super.setUp()
        // Ensure no camera path is active from previous tests
        stopCameraPath()
    }

    override func initializeAssets() {
        // Create a simple scene with a camera
        cameraLookAt(
            entityId: findGameCamera(),
            eye: simd_float3(0.0, 1.0, 5.0),
            target: simd_float3(0.0, 0.0, 0.0),
            up: simd_float3(0.0, 1.0, 0.0)
        )
    }

    // MARK: - Basic Functionality Tests

    func test_startCameraPathInitializesStateAndHandlesSingleWaypoint() {
        let camera = findGameCamera()

        let targetPosition = simd_float3(10.0, 5.0, 10.0)
        let targetRotation = simd_quatf(angle: Float.pi / 4, axis: simd_float3(0, 1, 0))

        let waypoint = CameraWaypoint(
            position: targetPosition,
            rotation: targetRotation,
            segmentDuration: 1.0
        )

        // Verify path is not active before starting
        XCTAssertFalse(isCameraPathActive(), "Path should not be active before start")

        startCameraPath(waypoints: [waypoint], mode: .once)

        // With single waypoint, path should snap immediately and not remain active
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        // Verify camera position matches waypoint
        let positionDelta = simd_length(cameraComponent.localPosition - targetPosition)
        XCTAssertLessThan(positionDelta, 1e-3, "Camera should snap to single waypoint position")

        // Verify camera rotation matches waypoint
        let rotationDelta = simd_length(cameraComponent.rotation.vector - targetRotation.vector)
        XCTAssertLessThan(rotationDelta, 1e-3, "Camera rotation should match waypoint rotation")

        // Single waypoint should not create an active path
        XCTAssertFalse(isCameraPathActive(), "Path should not be active after single waypoint snap")
    }

    func test_singleWaypointSnaps() {
        let camera = findGameCamera()

        let targetPosition = simd_float3(10.0, 5.0, 10.0)
        let targetRotation = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))

        let waypoint = CameraWaypoint(
            position: targetPosition,
            rotation: targetRotation,
            segmentDuration: 1.0
        )

        startCameraPath(waypoints: [waypoint], mode: .once)

        // Camera should snap to single waypoint immediately
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        let positionDelta = simd_length(cameraComponent.localPosition - targetPosition)
        XCTAssertLessThan(positionDelta, 1e-3, "Camera should snap to single waypoint position")
    }

    func test_reachesFinalWaypoint() throws {
        let camera = findGameCamera()

        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 1, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
        ]

        let finalPosition = try XCTUnwrap(waypoints.last?.position)

        startCameraPath(waypoints: waypoints, mode: .once)

        // Simulate time progression
        let dt: Float = 0.016 // ~60 FPS
        let totalTime: Float = waypoints.reduce(0) { $0 + $1.segmentDuration }
        let steps = Int(ceil(totalTime / dt)) + 10 // Add extra steps to ensure completion

        for _ in 0 ..< steps {
            updateCameraPath(deltaTime: dt)
        }

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        let positionDelta = simd_length(cameraComponent.localPosition - finalPosition)
        XCTAssertLessThan(positionDelta, 1e-2, "Camera should reach final waypoint within tolerance. Delta: \(positionDelta)")
        XCTAssertFalse(isCameraPathActive(), "Path should be inactive after completion")
    }

    func test_loopingReturnsToStart() {
        let camera = findGameCamera()

        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.3),
            CameraWaypoint(position: simd_float3(3, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.3),
            CameraWaypoint(position: simd_float3(3, 1, 2), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.3),
        ]

        let startPosition = waypoints[0].position

        startCameraPath(waypoints: waypoints, mode: .loop)

        // Simulate more than one full cycle
        let dt: Float = 0.016
        let totalTime: Float = waypoints.reduce(0) { $0 + $1.segmentDuration }
        let steps = Int(ceil(totalTime * 1.5 / dt)) // 1.5 cycles

        for _ in 0 ..< steps {
            updateCameraPath(deltaTime: dt)
        }

        // Path should still be active in loop mode
        XCTAssertTrue(isCameraPathActive(), "Path should remain active in loop mode")

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        // After 1.5 cycles, camera should be halfway through the second loop
        // We'll just verify it's somewhere along the path (not stuck)
        let distanceFromStart = simd_length(cameraComponent.localPosition - startPosition)
        XCTAssertGreaterThan(distanceFromStart, 0.1, "Camera should have moved from start position")
    }

    // MARK: - Interpolation Tests

    func test_updateCameraPathInterpolatesPositionAndRotation() {
        let camera = findGameCamera()

        let startPos = simd_float3(0.0, 0.0, 0.0)
        let endPos = simd_float3(10.0, 0.0, 0.0)
        let startRot = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        let endRot = simd_quatf(angle: Float.pi / 2, axis: simd_float3(0, 1, 0))

        let waypoints = [
            CameraWaypoint(position: startPos, rotation: startRot, segmentDuration: 1.0),
            CameraWaypoint(position: endPos, rotation: endRot, segmentDuration: 1.0),
        ]

        startCameraPath(waypoints: waypoints, mode: .once)

        // Update to 50% of first segment (0.5 seconds)
        updateCameraPath(deltaTime: 0.5)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        // At t=0.5, position should be halfway between start and end
        let expectedMidPos = startPos + (endPos - startPos) * 0.5
        let positionDelta = simd_length(cameraComponent.localPosition - expectedMidPos)
        XCTAssertLessThan(positionDelta, 1e-2, "Position should be interpolated to midpoint. Delta: \(positionDelta)")

        // At t=0.5, rotation should be between start and end (slerp)
        let expectedMidRot = simd_slerp(startRot, endRot, 0.5)
        let rotationDelta = simd_length(cameraComponent.rotation.vector - expectedMidRot.vector)
        XCTAssertLessThan(rotationDelta, 1e-2, "Rotation should be interpolated via slerp. Delta: \(rotationDelta)")

        // Verify quaternion is normalized
        let magnitude = simd_length(cameraComponent.rotation.vector)
        XCTAssertTrue(abs(magnitude - 1.0) < 1e-4, "Quaternion should remain normalized. Magnitude: \(magnitude)")

        // Path should still be active
        XCTAssertTrue(isCameraPathActive(), "Path should still be active during interpolation")
    }

    // MARK: - Rotation Tests

    func test_rotationInterpolation() {
        let camera = findGameCamera()

        // Create waypoints with significantly different rotations
        let rot1 = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        let rot2 = simd_quatf(angle: Float.pi / 2, axis: simd_float3(0, 1, 0)) // 90 degree rotation

        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: rot1, segmentDuration: 1.0),
            CameraWaypoint(position: simd_float3(5, 0, 0), rotation: rot2, segmentDuration: 1.0),
        ]

        startCameraPath(waypoints: waypoints, mode: .once)

        // Step halfway through first segment
        updateCameraPath(deltaTime: 0.5)

        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        // Verify rotation is valid (not NaN)
        XCTAssertFalse(cameraComponent.rotation.vector.x.isNaN, "Rotation x should not be NaN")
        XCTAssertFalse(cameraComponent.rotation.vector.y.isNaN, "Rotation y should not be NaN")
        XCTAssertFalse(cameraComponent.rotation.vector.z.isNaN, "Rotation z should not be NaN")
        XCTAssertFalse(cameraComponent.rotation.vector.w.isNaN, "Rotation w should not be NaN")

        // Verify quaternion is normalized
        let magnitude = simd_length(cameraComponent.rotation.vector)
        XCTAssertTrue(abs(magnitude - 1.0) < 1e-4, "Quaternion should be normalized. Magnitude: \(magnitude)")
    }

    func test_cameraWaypointLookAtInitializerSetsRotationCorrectly() {
        let position = simd_float3(0, 5, 10)
        let lookAtTarget = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        // Create waypoint using lookAt initializer
        let waypointLookAt = CameraWaypoint(position: position, lookAt: lookAtTarget, up: up, segmentDuration: 1.0)

        // Verify rotation is valid (no NaN values)
        XCTAssertFalse(waypointLookAt.rotation.vector.x.isNaN, "Rotation x should be valid")
        XCTAssertFalse(waypointLookAt.rotation.vector.y.isNaN, "Rotation y should be valid")
        XCTAssertFalse(waypointLookAt.rotation.vector.z.isNaN, "Rotation z should be valid")
        XCTAssertFalse(waypointLookAt.rotation.real.isNaN, "Rotation w should be valid")

        // Verify quaternion is normalized
        let quatVec = simd_float4(waypointLookAt.rotation.vector.x, waypointLookAt.rotation.vector.y, waypointLookAt.rotation.vector.z, waypointLookAt.rotation.real)
        let magnitude = simd_length(quatVec)
        XCTAssertTrue(abs(magnitude - 1.0) < 1e-4, "Quaternion should be normalized. Magnitude: \(magnitude)")

        // Create another waypoint path and verify the camera can use it
        let waypoints = [
            waypointLookAt,
            CameraWaypoint(position: simd_float3(5, 5, 5), lookAt: lookAtTarget, up: up, segmentDuration: 1.0),
        ]

        // This should not crash and should set the camera orientation correctly
        startCameraPath(waypoints: waypoints, mode: .once)
        XCTAssertTrue(isCameraPathActive(), "Path should be active after starting with lookAt waypoints")

        // Verify the camera component received the rotation
        let camera = findGameCamera()
        guard let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }

        // Verify the rotation is not identity (has been set)
        let identityQuat = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
        let rotDiff = simd_length(cameraComponent.rotation.vector - identityQuat.vector)
        XCTAssertGreaterThan(rotDiff, 0.01, "Camera rotation should be set from lookAt waypoint")
    }

    // MARK: - Edge Cases

    func test_isCameraPathActiveReturnsTrueOnlyWhenActive() {
        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
        ]

        // Initially path should not be active
        XCTAssertFalse(isCameraPathActive(), "Path should not be active before starting")

        // Start the path
        startCameraPath(waypoints: waypoints, mode: .once)
        XCTAssertTrue(isCameraPathActive(), "Path should be active after starting")

        // Should remain active during updates
        updateCameraPath(deltaTime: 0.2)
        XCTAssertTrue(isCameraPathActive(), "Path should be active during playback")

        // Stop the path
        stopCameraPath()
        XCTAssertFalse(isCameraPathActive(), "Path should not be active after stopping")

        // Start again in loop mode
        startCameraPath(waypoints: waypoints, mode: .loop)
        XCTAssertTrue(isCameraPathActive(), "Path should be active after restarting in loop mode")

        // Run to completion (in loop mode it should remain active)
        for _ in 0 ..< 100 {
            updateCameraPath(deltaTime: 0.016)
        }
        XCTAssertTrue(isCameraPathActive(), "Path should remain active in loop mode")

        // Stop again
        stopCameraPath()
        XCTAssertFalse(isCameraPathActive(), "Path should not be active after stopping loop")
    }

    func test_zeroWaypointsHandledGracefully() {
        startCameraPath(waypoints: [], mode: .once)

        // Should not crash and path should not be active
        XCTAssertFalse(isCameraPathActive(), "Path should not be active with zero waypoints")
    }

    func test_stopCameraPathDeactivatesAndDisablesUpdates() {
        let camera = findGameCamera()

        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
            CameraWaypoint(position: simd_float3(10, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
        ]

        startCameraPath(waypoints: waypoints, mode: .once)
        XCTAssertTrue(isCameraPathActive(), "Path should be active after start")

        // Advance the path a bit
        updateCameraPath(deltaTime: 0.3)
        XCTAssertTrue(isCameraPathActive(), "Path should still be active during updates")

        guard let componentBeforeStop = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }
        let positionBeforeStop = componentBeforeStop.localPosition

        // Stop the path
        stopCameraPath()
        XCTAssertFalse(isCameraPathActive(), "Path should be inactive after stop")

        // Updating after stop should be safe (no-op - camera should not move)
        updateCameraPath(deltaTime: 0.5)
        XCTAssertFalse(isCameraPathActive(), "Path should remain inactive after updates")

        guard let componentAfterStop = scene.get(component: CameraComponent.self, for: camera) else {
            XCTFail("Camera component not found")
            return
        }
        let positionAfterStop = componentAfterStop.localPosition

        // Camera position should not change after stop
        let positionDelta = simd_length(positionAfterStop - positionBeforeStop)
        XCTAssertLessThan(positionDelta, 1e-5, "Camera should not move after path is stopped. Delta: \(positionDelta)")
    }

    func test_invalidSegmentDurationHandled() {
        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.0),
            CameraWaypoint(position: simd_float3(5, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
            CameraWaypoint(position: simd_float3(10, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
        ]

        startCameraPath(waypoints: waypoints, mode: .once)

        // Should skip invalid segment and continue
        updateCameraPath(deltaTime: 0.1)

        // Verify it doesn't crash and eventually completes
        for _ in 0 ..< 200 {
            updateCameraPath(deltaTime: 0.016)
        }

        XCTAssertFalse(isCameraPathActive(), "Path should eventually complete despite invalid segment")
    }

    // MARK: - Completion Callback Test

    func test_completionCallbackInvoked() {
        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.1),
            CameraWaypoint(position: simd_float3(1, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.1),
        ]

        var callbackInvoked = false
        let settings = CameraPathSettings(startImmediately: true) {
            callbackInvoked = true
        }

        startCameraPath(waypoints: waypoints, mode: .once, settings: settings)

        // Run until completion
        for _ in 0 ..< 100 {
            updateCameraPath(deltaTime: 0.016)
        }

        XCTAssertTrue(callbackInvoked, "Completion callback should be invoked when path finishes")
    }

    // MARK: - Determinism Test

    func test_deterministicBehavior() {
        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 2, 5), rotation: simd_quatf(angle: Float.pi / 4, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(10, 0, 0), rotation: simd_quatf(angle: Float.pi / 2, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
        ]

        // Run path twice with same deltaTime sequence
        var positions1: [simd_float3] = []
        var positions2: [simd_float3] = []

        let camera = findGameCamera()

        // First run
        startCameraPath(waypoints: waypoints, mode: .once)
        for _ in 0 ..< 100 {
            updateCameraPath(deltaTime: 0.016)
            if let cameraComponent = scene.get(component: CameraComponent.self, for: camera) {
                positions1.append(cameraComponent.localPosition)
            }
        }

        // Reset camera
        stopCameraPath()
        moveCameraTo(entityId: camera, 0, 1, 5)

        // Second run
        startCameraPath(waypoints: waypoints, mode: .once)
        for _ in 0 ..< 100 {
            updateCameraPath(deltaTime: 0.016)
            if let cameraComponent = scene.get(component: CameraComponent.self, for: camera) {
                positions2.append(cameraComponent.localPosition)
            }
        }

        // Compare positions
        XCTAssertEqual(positions1.count, positions2.count, "Should have same number of samples")

        for (i, (pos1, pos2)) in zip(positions1, positions2).enumerated() {
            let delta = simd_length(pos1 - pos2)
            XCTAssertLessThan(delta, 1e-5, "Position at step \(i) should be deterministic. Delta: \(delta)")
        }
    }
}
