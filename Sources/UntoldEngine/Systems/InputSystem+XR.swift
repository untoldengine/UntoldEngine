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

#if os(visionOS)
    public enum XRSpatialInteractionPhase: Sendable {
        case began
        case changed
        case ended
        case cancelled
    }

    public enum XRSpatialManipulationIntent: Sendable {
        case automatic
        case translate
        case rotate
    }

    public struct XRSpatialInputSnapshot: Sendable {
        public var phase: XRSpatialInteractionPhase
        public var intent: XRSpatialManipulationIntent
        public var rayOriginWorld: simd_float3
        public var rayDirectionWorld: simd_float3
        public var inputDevicePositionWorld: simd_float3?
        public var inputDeviceOrientationWorld: simd_quatf?
        public var timestamp: TimeInterval

        public init(
            phase: XRSpatialInteractionPhase,
            intent: XRSpatialManipulationIntent,
            rayOriginWorld: simd_float3,
            rayDirectionWorld: simd_float3,
            inputDevicePositionWorld: simd_float3? = nil,
            inputDeviceOrientationWorld: simd_quatf? = nil,
            timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
        ) {
            self.phase = phase
            self.intent = intent
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
        func registerXREvents() {}
        func unregisterXREvents() {}
    #else
        private static let xrEventStateLock = NSLock()
        private static var xrInputEventsEnabled = false
        private static let xrSpatialInputQueue = XRSpatialInputQueue()

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
    #endif
}
