//
//  InputSystem+XR.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
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

public struct XRSpatialInputState {
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
        private let lock = NSLock()
        private var pending: [XRSpatialInputSnapshot] = []
        private let maxPending = 128

        func enqueue(_ snapshot: XRSpatialInputSnapshot) {
            lock.lock()
            defer { lock.unlock() }
            if pending.count >= maxPending {
                pending.removeFirst(pending.count - maxPending + 1)
            }
            pending.append(snapshot)
        }

        func drain() -> [XRSpatialInputSnapshot] {
            lock.lock()
            defer { lock.unlock() }
            let snapshots = pending
            pending.removeAll(keepingCapacity: true)
            return snapshots
        }

        func clear() {
            lock.lock()
            defer { lock.unlock() }
            pending.removeAll(keepingCapacity: true)
        }
    }
#endif

public extension InputSystem {
    #if !os(visionOS)
        var xrSpatialInputState: XRSpatialInputState {
            get { XRSpatialInputState() }
            set {}
        }

        func registerXREvents() {}
        func unregisterXREvents() {}
    #else
        private static let xrEventStateLock = NSLock()
        private static var xrInputEventsEnabled = false
        private static let xrSpatialInputQueue = XRSpatialInputQueue()
        private static var _xrSpatialInputState = XRSpatialInputState()

        var xrSpatialInputState: XRSpatialInputState {
            get {
                Self.xrEventStateLock.lock()
                defer { Self.xrEventStateLock.unlock() }
                return Self._xrSpatialInputState
            }
            set {
                Self.xrEventStateLock.lock()
                defer { Self.xrEventStateLock.unlock() }
                Self._xrSpatialInputState = newValue
            }
        }

        func registerXREvents() {
            Self.xrEventStateLock.lock()
            Self.xrInputEventsEnabled = true
            Self.xrEventStateLock.unlock()
        }

        func unregisterXREvents() {
            Self.xrEventStateLock.lock()
            Self.xrInputEventsEnabled = false
            Self.xrEventStateLock.unlock()
            Self.xrSpatialInputQueue.clear()
        }

        var xrEventsEnabled: Bool {
            Self.xrEventStateLock.lock()
            let enabled = Self.xrInputEventsEnabled
            Self.xrEventStateLock.unlock()
            return enabled
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

        func getGazeTarget(maxDistance: Float = 10.0) -> simd_float3 {
            xrSpatialInputState.gazePosition + xrSpatialInputState.gazeDirection * maxDistance
        }
    #endif
}
