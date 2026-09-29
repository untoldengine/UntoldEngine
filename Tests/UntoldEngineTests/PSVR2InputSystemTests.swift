//
//  PSVR2InputSystemTests.swift
//  UntoldEngineTests
//

import GameController
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class PSVR2InputSystemTests: XCTestCase {
    override func setUp() {
        InputSystem.shared.psvr2SenseControllerState = PSVR2SenseControllerState()
        InputSystem.shared.gameControllerState = GameControllerState()
        InputSystem.shared.psvr2ControllerChirality = [:]
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

    func testThumbstickRoutesToLeftOrRightByChirality() {
        let leftWand = GCController()
        let rightWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(leftWand)] = .left
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(rightWand)] = .right

        InputSystem.shared.updatePSVR2Thumbstick(x: 0.5, y: -0.25, for: leftWand)
        InputSystem.shared.updatePSVR2Thumbstick(x: -0.6, y: 0.8, for: rightWand)

        let state = getGameControllerState()
        XCTAssertEqual(state.leftThumbstickX, 0.5)
        XCTAssertEqual(state.leftThumbstickY, -0.25)
        XCTAssertTrue(state.leftThumbStickActive)
        XCTAssertEqual(state.rightThumbstickX, -0.6)
        XCTAssertEqual(state.rightThumbstickY, 0.8)
        XCTAssertTrue(state.rightThumbStickActive)
    }

    func testThumbstickBelowDeadzoneIsNotActive() {
        let leftWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(leftWand)] = .left

        InputSystem.shared.updatePSVR2Thumbstick(x: 0.05, y: -0.05, for: leftWand)

        XCTAssertFalse(getGameControllerState().leftThumbStickActive)
    }

    func testThumbstickPressedRoutesByChirality() {
        let rightWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(rightWand)] = .right

        InputSystem.shared.updatePSVR2ThumbstickPressed(true, for: rightWand)

        let state = getGameControllerState()
        XCTAssertTrue(state.rightThumbstickPressed)
        XCTAssertFalse(state.leftThumbstickPressed)
    }

    func testThumbstickEventFromUnresolvedControllerIsIgnored() {
        let unresolvedWand = GCController()

        InputSystem.shared.updatePSVR2Thumbstick(x: 1, y: 1, for: unresolvedWand)
        InputSystem.shared.updatePSVR2ThumbstickPressed(true, for: unresolvedWand)

        let state = getGameControllerState()
        XCTAssertEqual(state.leftThumbstickX, 0)
        XCTAssertEqual(state.rightThumbstickX, 0)
        XCTAssertFalse(state.leftThumbstickPressed)
        XCTAssertFalse(state.rightThumbstickPressed)
    }

    func testRightWandFaceButtonsRouteToAAndB() {
        let rightWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(rightWand)] = .right

        InputSystem.shared.updatePSVR2ButtonA(true, for: rightWand)
        InputSystem.shared.updatePSVR2ButtonB(true, for: rightWand)

        let state = getGameControllerState()
        XCTAssertTrue(state.aPressed)
        XCTAssertTrue(state.bPressed)
        XCTAssertFalse(state.xPressed)
        XCTAssertFalse(state.yPressed)
    }

    func testLeftWandFaceButtonsRouteToXAndY() {
        let leftWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(leftWand)] = .left

        InputSystem.shared.updatePSVR2ButtonA(true, for: leftWand)
        InputSystem.shared.updatePSVR2ButtonB(true, for: leftWand)

        let state = getGameControllerState()
        XCTAssertTrue(state.xPressed)
        XCTAssertTrue(state.yPressed)
        XCTAssertFalse(state.aPressed)
        XCTAssertFalse(state.bPressed)
    }

    func testGripRoutesToLeftOrRightShoulderByChirality() {
        let leftWand = GCController()
        let rightWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(leftWand)] = .left
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(rightWand)] = .right

        InputSystem.shared.updatePSVR2Grip(true, for: leftWand)
        InputSystem.shared.updatePSVR2Grip(true, for: rightWand)

        let state = getGameControllerState()
        XCTAssertTrue(state.leftShoulderPressed)
        XCTAssertTrue(state.rightShoulderPressed)
    }

    func testTriggerRoutesToLeftOrRightByChirality() {
        let leftWand = GCController()
        let rightWand = GCController()
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(leftWand)] = .left
        InputSystem.shared.psvr2ControllerChirality[ObjectIdentifier(rightWand)] = .right

        InputSystem.shared.updatePSVR2Trigger(value: 0.75, pressed: true, for: leftWand)
        InputSystem.shared.updatePSVR2Trigger(value: 0.4, pressed: false, for: rightWand)

        let state = getGameControllerState()
        XCTAssertEqual(state.leftTriggerValue, 0.75)
        XCTAssertTrue(state.leftTriggerPressed)
        XCTAssertEqual(state.rightTriggerValue, 0.4)
        XCTAssertFalse(state.rightTriggerPressed)
    }

    func testFaceButtonAndTriggerEventsFromUnresolvedControllerAreIgnored() {
        let unresolvedWand = GCController()

        InputSystem.shared.updatePSVR2ButtonA(true, for: unresolvedWand)
        InputSystem.shared.updatePSVR2ButtonB(true, for: unresolvedWand)
        InputSystem.shared.updatePSVR2Grip(true, for: unresolvedWand)
        InputSystem.shared.updatePSVR2Trigger(value: 1, pressed: true, for: unresolvedWand)

        let state = getGameControllerState()
        XCTAssertFalse(state.aPressed)
        XCTAssertFalse(state.bPressed)
        XCTAssertFalse(state.xPressed)
        XCTAssertFalse(state.yPressed)
        XCTAssertFalse(state.leftShoulderPressed)
        XCTAssertFalse(state.rightShoulderPressed)
        XCTAssertEqual(state.leftTriggerValue, 0)
        XCTAssertEqual(state.rightTriggerValue, 0)
    }
}
