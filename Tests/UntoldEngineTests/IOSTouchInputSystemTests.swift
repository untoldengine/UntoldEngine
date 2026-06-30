//
//  IOSTouchInputSystemTests.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

// MARK: - IOSTouchState Struct Tests (platform-independent)

final class IOSTouchStateTests: XCTestCase {
    // MARK: M1 — Struct defaults

    func test_iosTouchState_defaultValues_allFalseAndZero() {
        let state = IOSTouchState()

        XCTAssertFalse(state.isDragging)
        XCTAssertEqual(state.dragX, 0)
        XCTAssertEqual(state.dragY, 0)
        XCTAssertEqual(state.dragDeltaX, 0)
        XCTAssertEqual(state.dragDeltaY, 0)
        XCTAssertNil(state.dragGestureState)

        XCTAssertFalse(state.tapped)
        XCTAssertEqual(state.tapX, 0)
        XCTAssertEqual(state.tapY, 0)

        XCTAssertFalse(state.doubleTapped)
        XCTAssertEqual(state.doubleTapX, 0)
        XCTAssertEqual(state.doubleTapY, 0)

        XCTAssertFalse(state.twoFingerPanning)
        XCTAssertEqual(state.twoFingerDeltaX, 0)
        XCTAssertEqual(state.twoFingerDeltaY, 0)

        XCTAssertFalse(state.isPinching)
        XCTAssertEqual(state.pinchScaleDelta, 0)
    }

    // MARK: M1 — Field mutations are independent

    func test_iosTouchState_dragging_doesNotAffectOtherFields() {
        var state = IOSTouchState()
        state.isDragging = true
        state.dragX = 120
        state.dragY = 80
        state.dragDeltaX = 5
        state.dragDeltaY = -3
        state.dragGestureState = .changed

        XCTAssertFalse(state.tapped)
        XCTAssertFalse(state.doubleTapped)
        XCTAssertFalse(state.twoFingerPanning)
        XCTAssertFalse(state.isPinching)
        XCTAssertEqual(state.tapX, 0)
        XCTAssertEqual(state.twoFingerDeltaX, 0)
        XCTAssertEqual(state.pinchScaleDelta, 0)
    }

    func test_iosTouchState_pinching_doesNotAffectDrag() {
        var state = IOSTouchState()
        state.isPinching = true
        state.pinchScaleDelta = 0.15

        XCTAssertFalse(state.isDragging)
        XCTAssertFalse(state.twoFingerPanning)
        XCTAssertEqual(state.dragX, 0)
        XCTAssertEqual(state.twoFingerDeltaX, 0)
    }

    func test_iosTouchState_twoFingerPan_doesNotAffectTap() {
        var state = IOSTouchState()
        state.twoFingerPanning = true
        state.twoFingerDeltaX = 12
        state.twoFingerDeltaY = -7

        XCTAssertFalse(state.tapped)
        XCTAssertFalse(state.doubleTapped)
        XCTAssertEqual(state.tapX, 0)
    }

    // MARK: M1 — Reset via reassignment

    func test_iosTouchState_reset_clearsAllFields() {
        var state = IOSTouchState()
        state.isDragging = true
        state.dragX = 200
        state.tapped = true
        state.twoFingerPanning = true
        state.isPinching = true
        state.pinchScaleDelta = 0.5
        state.dragGestureState = .began

        state = IOSTouchState()

        XCTAssertFalse(state.isDragging)
        XCTAssertEqual(state.dragX, 0)
        XCTAssertFalse(state.tapped)
        XCTAssertFalse(state.twoFingerPanning)
        XCTAssertFalse(state.isPinching)
        XCTAssertEqual(state.pinchScaleDelta, 0)
        XCTAssertNil(state.dragGestureState)
    }

    // MARK: M2 — PanGestureState assignments

    func test_iosTouchState_dragGestureState_canBeSetAndCleared() {
        var state = IOSTouchState()

        state.dragGestureState = .began
        XCTAssertEqual(state.dragGestureState, .began)

        state.dragGestureState = .changed
        XCTAssertEqual(state.dragGestureState, .changed)

        state.dragGestureState = .ended
        XCTAssertEqual(state.dragGestureState, .ended)

        state.dragGestureState = nil
        XCTAssertNil(state.dragGestureState)
    }

    // MARK: M2 — Tap position tracking

    func test_iosTouchState_tap_positionStoredCorrectly() {
        var state = IOSTouchState()
        state.tapped = true
        state.tapX = 320
        state.tapY = 240

        XCTAssertTrue(state.tapped)
        XCTAssertEqual(state.tapX, 320, accuracy: 0.001)
        XCTAssertEqual(state.tapY, 240, accuracy: 0.001)
    }

    func test_iosTouchState_doubleTap_positionStoredCorrectly() {
        var state = IOSTouchState()
        state.doubleTapped = true
        state.doubleTapX = 160
        state.doubleTapY = 90

        XCTAssertTrue(state.doubleTapped)
        XCTAssertEqual(state.doubleTapX, 160, accuracy: 0.001)
        XCTAssertEqual(state.doubleTapY, 90, accuracy: 0.001)
        // Tap fields must not be contaminated
        XCTAssertFalse(state.tapped)
        XCTAssertEqual(state.tapX, 0)
    }

    // MARK: M2 — Pinch scale delta sign

    func test_iosTouchState_pinchScaleDelta_canBeNegative() {
        var state = IOSTouchState()
        state.isPinching = true
        state.pinchScaleDelta = -0.08

        XCTAssertTrue(state.isPinching)
        XCTAssertEqual(state.pinchScaleDelta, -0.08, accuracy: 0.0001)
    }

    func test_iosTouchState_pinchScaleDelta_canBePositive() {
        var state = IOSTouchState()
        state.isPinching = true
        state.pinchScaleDelta = 0.12

        XCTAssertEqual(state.pinchScaleDelta, 0.12, accuracy: 0.0001)
    }

    // MARK: M3 — InputSystem stored property

    func test_inputSystem_iosTouchState_defaultValues() {
        let input = InputSystem.shared
        // Reset before reading
        input.iosTouchState = IOSTouchState()

        let state = input.iosTouchState
        XCTAssertFalse(state.isDragging)
        XCTAssertFalse(state.tapped)
        XCTAssertFalse(state.doubleTapped)
        XCTAssertFalse(state.twoFingerPanning)
        XCTAssertFalse(state.isPinching)
    }

    func test_inputSystem_iosTouchState_canBeDirectlyMutated() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()

        input.iosTouchState.isDragging = true
        input.iosTouchState.dragX = 50
        input.iosTouchState.dragY = 100

        XCTAssertTrue(input.iosTouchState.isDragging)
        XCTAssertEqual(input.iosTouchState.dragX, 50, accuracy: 0.001)
        XCTAssertEqual(input.iosTouchState.dragY, 100, accuracy: 0.001)
    }

    func test_inputSystem_iosTouchState_resetClearsAllMutations() {
        let input = InputSystem.shared
        input.iosTouchState.isDragging = true
        input.iosTouchState.isPinching = true
        input.iosTouchState.tapped = true

        input.iosTouchState = IOSTouchState()

        XCTAssertFalse(input.iosTouchState.isDragging)
        XCTAssertFalse(input.iosTouchState.isPinching)
        XCTAssertFalse(input.iosTouchState.tapped)
    }

    // MARK: M3 — getIOSTouchState free function

    func test_getIOSTouchState_returnsSameValueAsSharedProperty() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()
        input.iosTouchState.dragX = 77
        input.iosTouchState.isDragging = true

        let queried = getIOSTouchState()
        XCTAssertEqual(queried.dragX, 77, accuracy: 0.001)
        XCTAssertTrue(queried.isDragging)
    }

    func test_getIOSTouchState_defaultState_matchesStruct() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()

        let state = getIOSTouchState()
        XCTAssertFalse(state.isDragging)
        XCTAssertFalse(state.tapped)
        XCTAssertEqual(state.pinchScaleDelta, 0)
    }

    // MARK: M4 — Cross-contamination: iOS state does not bleed into mouse/keyboard

    func test_iosTouchState_mutation_doesNotAffectKeyState() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()
        let keysBefore = input.keyState

        input.iosTouchState.isDragging = true
        input.iosTouchState.tapped = true

        // Key state must be unchanged
        XCTAssertEqual(input.keyState.leftMousePressed, keysBefore.leftMousePressed)
        XCTAssertEqual(input.keyState.wPressed, keysBefore.wPressed)
    }

    func test_iosTouchState_mutation_doesNotAffectMouseFields() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()
        let mouseBefore = (input.mouseX, input.mouseY, input.mouseActive)

        input.iosTouchState.dragX = 300
        input.iosTouchState.dragY = 400
        input.iosTouchState.isDragging = true

        // Direct mouse fields must be unchanged
        XCTAssertEqual(input.mouseX, mouseBefore.0)
        XCTAssertEqual(input.mouseY, mouseBefore.1)
        XCTAssertEqual(input.mouseActive, mouseBefore.2)
    }

    func test_iosTouchState_mutation_doesNotAffectGameControllerState() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()
        let aBeforePress = input.gameControllerState.aPressed

        input.iosTouchState.tapped = true
        input.iosTouchState.doubleTapped = true

        XCTAssertEqual(input.gameControllerState.aPressed, aBeforePress)
    }

    // MARK: M4 — Snapshot semantics

    func test_getIOSTouchState_returnsValueSnapshot_notLiveReference() {
        let input = InputSystem.shared
        input.iosTouchState = IOSTouchState()
        input.iosTouchState.pinchScaleDelta = 0.1

        let snapshot = getIOSTouchState()
        input.iosTouchState.pinchScaleDelta = 0.9

        // Snapshot should still hold original value — IOSTouchState is a value type
        XCTAssertEqual(snapshot.pinchScaleDelta, 0.1, accuracy: 0.001)
    }
}
