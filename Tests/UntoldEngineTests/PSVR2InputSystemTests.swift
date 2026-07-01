//
//  PSVR2InputSystemTests.swift
//  UntoldEngineTests
//

import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class PSVR2InputSystemTests: XCTestCase {
    override func setUp() {
        InputSystem.shared.psvr2SenseControllerState = PSVR2SenseControllerState()
    }

    func testDefaultStateIsDisconnectedAndUntracked() {
        let state = PSVR2SenseControllerState()
        XCTAssertFalse(state.isConnected)
        XCTAssertFalse(state.left.isTracked)
        XCTAssertFalse(state.right.isTracked)
        XCTAssertEqual(state.left.trackingState, .unavailable)
        XCTAssertEqual(state.right.trackingState, .unavailable)
    }

    func testApplyLeftPoseUpdatesOnlyLeftController() {
        var transform = matrix_identity_float4x4
        transform.columns.3 = SIMD4(1, 2, 3, 1)

        InputSystem.shared.applyPSVR2Pose(
            chirality: .left,
            tracked: true,
            trackingState: .positionAndOrientation,
            transform: transform,
            velocity: SIMD3(4, 5, 6),
            angularVelocity: SIMD3(7, 8, 9)
        )

        let state = getPSVR2SenseState()
        XCTAssertTrue(state.left.isTracked)
        XCTAssertEqual(state.left.position, SIMD3(1, 2, 3))
        XCTAssertEqual(state.left.velocity, SIMD3(4, 5, 6))
        XCTAssertEqual(state.left.angularVelocity, SIMD3(7, 8, 9))
        XCTAssertFalse(state.right.isTracked)
    }

    func testApplyRightPosePreservesConnectionAndLeftPose() {
        InputSystem.shared.psvr2SenseControllerState.isConnected = true
        InputSystem.shared.psvr2SenseControllerState.left.isTracked = true

        InputSystem.shared.applyPSVR2Pose(
            chirality: .right,
            tracked: true,
            trackingState: .positionAndOrientationLowAccuracy,
            transform: matrix_identity_float4x4,
            velocity: .zero,
            angularVelocity: .zero
        )

        let state = getPSVR2SenseState()
        XCTAssertTrue(state.isConnected)
        XCTAssertTrue(state.left.isTracked)
        XCTAssertTrue(state.right.isTracked)
        XCTAssertEqual(state.right.trackingState, .positionAndOrientationLowAccuracy)
    }

    func testStateQueryReturnsValueSnapshot() {
        InputSystem.shared.psvr2SenseControllerState.left.position = SIMD3(1, 0, 0)
        let snapshot = getPSVR2SenseState()
        InputSystem.shared.psvr2SenseControllerState.left.position = SIMD3(2, 0, 0)
        XCTAssertEqual(snapshot.left.position, SIMD3(1, 0, 0))
    }

    func testConnectionQueryReflectsState() {
        XCTAssertFalse(isPSVR2SenseConnected())
        InputSystem.shared.psvr2SenseControllerState.isConnected = true
        XCTAssertTrue(isPSVR2SenseConnected())
    }
}
