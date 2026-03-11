//
//  InputSystem+XR.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os
import simd

public enum XRSpatialInteractionPhase: Sendable {
    case began
    case changed
    case ended
    case cancelled
}

public enum XRSpatialChirality: Sendable {
    case left
    case right
}

public enum XRSpatialTwoHandRotateAxisMode: Sendable, Equatable {
    case cameraForward
    case dynamic
    case dynamicSnapped
}

public struct XRSpatialInputState: Sendable {
    // Gesture detection (engine detects these)
    public var spatialTapActive = false
    public var spatialDragActive = false
    public var spatialPinchActive = false
    public var spatialZoomActive = false
    public var spatialZoomDelta: Float = 0
    public var spatialPinchDragDelta: simd_float3 = .zero
    public var spatialRotateActive = false
    public var spatialRotateDeltaRadians: Float = 0
    public var spatialRotateAxisWorld: simd_float3 = .init(0, 0, -1)

    // Spatial interaction data
    public var rayOriginWorld: simd_float3 = .zero
    public var rayDirectionWorld: simd_float3 = .zero
    public var inputDevicePositionWorld: simd_float3?
    public var inputDeviceOrientationWorld: simd_quatf?

    // Picked entity (engine provides this via ray casting)
    public var pickedEntityId: EntityID?
    public var pickedEntityDistance: Float = .infinity
    public var pickedEntityWorldPosition: simd_float3?

    // Hand tracking (future expansion - placeholder)
    public var handTrackingActive = false
    public var leftHandPosition: simd_float3 = .zero
    public var rightHandPosition: simd_float3 = .zero
    public var leftHandPinching = false
    public var rightHandPinching = false

    // Gaze tracking (future expansion - placeholder)
    public var gazePosition: simd_float3 = .zero
    public var gazeDirection: simd_float3 = .zero

    // Phase tracking
    public var currentPhase: XRSpatialInteractionPhase = .ended
    public var timestamp: TimeInterval = 0

    public init() {}
}

#if os(visionOS)
    public enum XRSpatialManipulationIntent: Sendable {
        case automatic
        case translate
        case rotate
    }

    public struct XRSpatialInputSnapshot: Sendable {
        public var interactionId: Int
        public var phase: XRSpatialInteractionPhase
        public var intent: XRSpatialManipulationIntent
        public var chirality: XRSpatialChirality?
        public var rayOriginWorld: simd_float3
        public var rayDirectionWorld: simd_float3
        public var inputDevicePositionWorld: simd_float3?
        public var inputDeviceOrientationWorld: simd_quatf?
        public var timestamp: TimeInterval

        public init(
            interactionId: Int = 0,
            phase: XRSpatialInteractionPhase,
            intent: XRSpatialManipulationIntent,
            chirality: XRSpatialChirality? = nil,
            rayOriginWorld: simd_float3,
            rayDirectionWorld: simd_float3,
            inputDevicePositionWorld: simd_float3? = nil,
            inputDeviceOrientationWorld: simd_quatf? = nil,
            timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
        ) {
            self.interactionId = interactionId
            self.phase = phase
            self.intent = intent
            self.chirality = chirality
            self.rayOriginWorld = rayOriginWorld
            self.rayDirectionWorld = rayDirectionWorld
            self.inputDevicePositionWorld = inputDevicePositionWorld
            self.inputDeviceOrientationWorld = inputDeviceOrientationWorld
            self.timestamp = timestamp
        }
    }

    private final class XRSpatialInputQueue {
        private let lock = OSAllocatedUnfairLock(initialState: [XRSpatialInputSnapshot]())
        private let maxPending = 128

        func enqueue(_ snapshot: XRSpatialInputSnapshot) {
            lock.withLock { pending in
                if pending.count >= maxPending {
                    pending.removeFirst(pending.count - maxPending + 1)
                }
                pending.append(snapshot)
            }
        }

        func drain() -> [XRSpatialInputSnapshot] {
            lock.withLock { pending in
                let snapshots = pending
                pending.removeAll(keepingCapacity: true)
                return snapshots
            }
        }

        func clear() {
            lock.withLock { pending in
                pending.removeAll(keepingCapacity: true)
            }
        }
    }
#endif

public extension InputSystem {
    #if !os(visionOS)
        var xrSpatialInputState: XRSpatialInputState {
            get { XRSpatialInputState() }
            set {}
        }

        func setXRSpatialPickingBackendPreference(_: ScenePickingBackendPreference) {}
        func setXRSceneReady(_ ready: Bool) {
            setSceneReady(ready)
        }

        func isXRSceneReady() -> Bool {
            isSceneReady()
        }

        func getXRSpatialPickingBackendPreference() -> ScenePickingBackendPreference {
            .octreeGPUPreferred
        }

        func registerXREvents() {}
        func unregisterXREvents() {}
        func setXRTwoHandRotateAxisMode(_: XRSpatialTwoHandRotateAxisMode) {}
        func getXRTwoHandRotateAxisMode() -> XRSpatialTwoHandRotateAxisMode {
            .dynamicSnapped
        }

        func hasTwoHandRotateSignal() -> Bool {
            false
        }

        func getTwoHandRotateSignal() -> (deltaRadians: Float, axisWorld: simd_float3)? {
            nil
        }
    #else
        private struct XREventState {
            var inputEventsEnabled = false
            var spatialInputState = XRSpatialInputState()
            var spatialPickingBackendPreference: ScenePickingBackendPreference = .octreeGPUPreferred
            var twoHandRotateAxisMode: XRSpatialTwoHandRotateAxisMode = .dynamicSnapped
        }

        private static let xrEventStateLock = OSAllocatedUnfairLock(initialState: XREventState())
        private static let xrSpatialInputQueue = XRSpatialInputQueue()

        var xrSpatialInputState: XRSpatialInputState {
            get {
                Self.xrEventStateLock.withLock { state in
                    state.spatialInputState
                }
            }
            set {
                Self.xrEventStateLock.withLock { state in
                    state.spatialInputState = newValue
                }
            }
        }

        func registerXREvents() {
            Self.xrEventStateLock.withLock { state in
                state.inputEventsEnabled = true
            }
        }

        func unregisterXREvents() {
            Self.xrEventStateLock.withLock { state in
                state.inputEventsEnabled = false
            }
            Self.xrSpatialInputQueue.clear()
        }

        var xrEventsEnabled: Bool {
            Self.xrEventStateLock.withLock { state in
                state.inputEventsEnabled
            }
        }

        func enqueueXRSpatialSnapshot(_ snapshot: XRSpatialInputSnapshot) {
            Self.xrSpatialInputQueue.enqueue(snapshot)
        }

        func drainXRSpatialSnapshots() -> [XRSpatialInputSnapshot] {
            Self.xrSpatialInputQueue.drain()
        }

        func clearXRSpatialSnapshots() {
            Self.xrSpatialInputQueue.clear()
        }

        func setXRSpatialPickingBackendPreference(_ preference: ScenePickingBackendPreference) {
            Self.xrEventStateLock.withLock { state in
                state.spatialPickingBackendPreference = preference
            }
        }

        func setXRSceneReady(_ ready: Bool) {
            setSceneReady(ready)
        }

        func isXRSceneReady() -> Bool {
            isSceneReady()
        }

        func getXRSpatialPickingBackendPreference() -> ScenePickingBackendPreference {
            Self.xrEventStateLock.withLock { state in
                state.spatialPickingBackendPreference
            }
        }

        func setXRTwoHandRotateAxisMode(_ mode: XRSpatialTwoHandRotateAxisMode) {
            Self.xrEventStateLock.withLock { state in
                state.twoHandRotateAxisMode = mode
            }
        }

        func getXRTwoHandRotateAxisMode() -> XRSpatialTwoHandRotateAxisMode {
            Self.xrEventStateLock.withLock { state in
                state.twoHandRotateAxisMode
            }
        }

        // MARK: - Helper Query Methods

        func hasSpatialTap() -> Bool {
            xrSpatialInputState.spatialTapActive
        }

        func hasSpatialDrag() -> Bool {
            xrSpatialInputState.spatialDragActive
        }

        func hasSpatialPinch() -> Bool {
            xrSpatialInputState.spatialPinchActive
        }

        func hasSpatialZoom() -> Bool {
            xrSpatialInputState.spatialZoomActive
        }

        func getSpatialZoomDelta() -> Float {
            xrSpatialInputState.spatialZoomDelta
        }

        func hasSpatialRotate() -> Bool {
            xrSpatialInputState.spatialRotateActive
        }

        func getSpatialRotateDelta() -> Float {
            xrSpatialInputState.spatialRotateDeltaRadians
        }

        func getSpatialRotateAxisWorld() -> simd_float3 {
            xrSpatialInputState.spatialRotateAxisWorld
        }

        func hasTwoHandRotateSignal() -> Bool {
            let state = xrSpatialInputState
            return state.leftHandPinching && state.rightHandPinching && state.spatialRotateActive
        }

        func getTwoHandRotateSignal() -> (deltaRadians: Float, axisWorld: simd_float3)? {
            let state = xrSpatialInputState
            guard state.leftHandPinching, state.rightHandPinching, state.spatialRotateActive else {
                return nil
            }
            return (state.spatialRotateDeltaRadians, state.spatialRotateAxisWorld)
        }

        func getPinchDragDelta() -> simd_float3 {
            xrSpatialInputState.spatialPinchDragDelta
        }

        func isUserPinching() -> Bool {
            xrSpatialInputState.spatialPinchActive
                || xrSpatialInputState.leftHandPinching
                || xrSpatialInputState.rightHandPinching
        }

        func getPinchPosition() -> simd_float3? {
            if xrSpatialInputState.rightHandPinching {
                return xrSpatialInputState.rightHandPosition
            } else if xrSpatialInputState.leftHandPinching {
                return xrSpatialInputState.leftHandPosition
            }
            if xrSpatialInputState.spatialPinchActive {
                return xrSpatialInputState.inputDevicePositionWorld
            }
            return nil
        }

        func getPickedEntityWorldPosition() -> simd_float3? {
            xrSpatialInputState.pickedEntityWorldPosition
        }

        func getGazeTarget(maxDistance: Float = 10.0) -> simd_float3? {
            let position = xrSpatialInputState.gazePosition
            let direction = xrSpatialInputState.gazeDirection

            guard
                position.x.isFinite, position.y.isFinite, position.z.isFinite,
                direction.x.isFinite, direction.y.isFinite, direction.z.isFinite,
                maxDistance.isFinite, maxDistance > 0
            else {
                return nil
            }

            let directionLengthSquared = simd_length_squared(direction)
            guard directionLengthSquared > 0 else {
                return nil
            }

            let normalizedDirection = direction / sqrt(directionLengthSquared)
            return position + normalizedDirection * maxDistance
        }
    #endif
}
