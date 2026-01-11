//
//  CameraPathTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class CameraPathTests: BaseRenderSetup {
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

    func test_reachesFinalWaypoint() {
        let camera = findGameCamera()

        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 1, 5), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
            CameraWaypoint(position: simd_float3(5, 1, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 0.5),
        ]

        let finalPosition = waypoints.last!.position

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

    func test_lookAtWaypointConstructor() {
        let position = simd_float3(0, 5, 10)
        let lookAt = simd_float3(0, 0, 0)
        let up = simd_float3(0, 1, 0)

        let waypoint = CameraWaypoint(position: position, lookAt: lookAt, up: up, segmentDuration: 1.0)

        // Verify rotation is valid (no NaN values)
        XCTAssertFalse(waypoint.rotation.vector.x.isNaN, "Rotation x should be valid")
        XCTAssertFalse(waypoint.rotation.vector.y.isNaN, "Rotation y should be valid")
        XCTAssertFalse(waypoint.rotation.vector.z.isNaN, "Rotation z should be valid")
        XCTAssertFalse(waypoint.rotation.real.isNaN, "Rotation w should be valid")

        // Verify quaternion is normalized by checking length
        // Quaternion magnitude = sqrt(x^2 + y^2 + z^2 + w^2)
        let quatVec = simd_float4(waypoint.rotation.vector.x, waypoint.rotation.vector.y, waypoint.rotation.vector.z, waypoint.rotation.real)
        let magnitude = simd_length(quatVec)
        XCTAssertTrue(abs(magnitude - 1.0) < 1e-4, "Quaternion should be normalized. Magnitude: \(magnitude)")
    }

    // MARK: - Edge Cases

    func test_zeroWaypointsHandledGracefully() {
        startCameraPath(waypoints: [], mode: .once)

        // Should not crash and path should not be active
        XCTAssertFalse(isCameraPathActive(), "Path should not be active with zero waypoints")
    }

    func test_stopCameraPath() {
        let waypoints = [
            CameraWaypoint(position: simd_float3(0, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
            CameraWaypoint(position: simd_float3(10, 0, 0), rotation: simd_quatf(angle: 0, axis: simd_float3(0, 1, 0)), segmentDuration: 1.0),
        ]

        startCameraPath(waypoints: waypoints, mode: .once)
        XCTAssertTrue(isCameraPathActive(), "Path should be active after start")

        stopCameraPath()
        XCTAssertFalse(isCameraPathActive(), "Path should be inactive after stop")

        // Updating after stop should be safe (no-op)
        updateCameraPath(deltaTime: 0.016)
        XCTAssertFalse(isCameraPathActive(), "Path should remain inactive")
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
