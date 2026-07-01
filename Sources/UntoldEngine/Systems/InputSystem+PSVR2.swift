//
//  InputSystem+PSVR2.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
@preconcurrency import GameController
import simd

#if os(visionOS)
    import ARKit
#endif

/// Tracking quality reported by visionOS for one PSVR2 Sense controller.
public enum PSVR2TrackingState: Sendable, Equatable {
    case unavailable
    case orientationOnly
    case positionAndOrientation
    case positionAndOrientationLowAccuracy
}

/// The world-space pose and motion of one PSVR2 Sense controller.
public struct PSVR2ControllerPose: Sendable, Equatable {
    public var isTracked = false
    public var trackingState: PSVR2TrackingState = .unavailable
    public var originFromControllerTransform = matrix_identity_float4x4
    public var position = simd_float3.zero
    public var orientation = simd_quatf(angle: 0, axis: simd_float3(0, 1, 0))
    public var velocity = simd_float3.zero
    public var angularVelocity = simd_float3.zero

    public init() {}
}

/// Spatial state for the paired PSVR2 Sense controllers on visionOS 26 or later.
/// Standard buttons, sticks, shoulders, and triggers remain available through
/// `getGameControllerState()`.
public struct PSVR2SenseControllerState: Sendable, Equatable {
    public var isConnected = false
    public var left = PSVR2ControllerPose()
    public var right = PSVR2ControllerPose()

    public init() {}
}

public extension Notification.Name {
    /// Posted when the PSVR2 accessory provider must be added to or removed from
    /// the app's active ARKitSession.
    static let psvr2AccessoryTrackingConfigurationDidChange = Notification.Name(
        "UntoldEngine.PSVR2AccessoryTrackingConfigurationDidChange"
    )
}

extension InputSystem {
    func isPSVR2SpatialController(_ controller: GCController) -> Bool {
        #if os(visionOS)
            if #available(visionOS 26.0, *) {
                return controller.productCategory == GCProductCategorySpatialController
            }
        #endif
        return false
    }

    func configurePSVR2IfNeeded(_ controller: GCController) {
        #if os(visionOS)
            guard #available(visionOS 26.0, *),
                  controller.productCategory == GCProductCategorySpatialController
            else { return }

            guard !psvr2SpatialControllers.contains(where: { $0 === controller }) else { return }

            psvr2SpatialControllers.append(controller)
            psvr2SenseControllerState.isConnected = true
            rebuildPSVR2AccessoryProvider()
            Logger.log(message: "PSVR2 Sense spatial controller connected: \(controller.vendorName ?? "unknown")")
        #else
            _ = controller
        #endif
    }

    func clearPSVR2IfNeeded(_ controller: GCController) {
        #if os(visionOS)
            guard #available(visionOS 26.0, *),
                  psvr2SpatialControllers.contains(where: { $0 === controller })
            else { return }
            psvr2SpatialControllers.removeAll(where: { $0 === controller })
            psvr2AccessoryLoadTask?.cancel()
            psvr2AnchorMonitorTask?.cancel()
            psvr2AccessoryLoadTask = nil
            psvr2AnchorMonitorTask = nil
            if psvr2SpatialControllers.isEmpty {
                psvr2AccessoryTrackingProviderStorage = nil
                psvr2SenseControllerState = PSVR2SenseControllerState()
                NotificationCenter.default.post(name: .psvr2AccessoryTrackingConfigurationDidChange, object: self)
            } else {
                rebuildPSVR2AccessoryProvider()
            }
        #else
            _ = controller
        #endif
    }

    /// Applies a spatial update in a platform-neutral form so pose conversion is testable.
    func applyPSVR2Pose(
        chirality: XRSpatialChirality,
        tracked: Bool,
        trackingState: PSVR2TrackingState,
        transform: simd_float4x4,
        velocity: simd_float3,
        angularVelocity: simd_float3
    ) {
        var pose = PSVR2ControllerPose()
        pose.isTracked = tracked
        pose.trackingState = trackingState
        pose.originFromControllerTransform = transform
        pose.position = transform.columns.3.xyz
        let rotation = simd_float3x3(
            transform.columns.0.xyz,
            transform.columns.1.xyz,
            transform.columns.2.xyz
        )
        pose.orientation = simd_normalize(simd_quatf(rotation))
        pose.velocity = velocity
        pose.angularVelocity = angularVelocity

        switch chirality {
        case .left:
            psvr2SenseControllerState.left = pose
        case .right:
            psvr2SenseControllerState.right = pose
        }
    }
}

#if os(visionOS)
    @available(visionOS 26.0, *)
    extension InputSystem {
        private func rebuildPSVR2AccessoryProvider() {
            psvr2AccessoryLoadTask?.cancel()
            psvr2AccessoryGeneration += 1
            let generation = psvr2AccessoryGeneration
            let controllers = psvr2SpatialControllers
            psvr2AccessoryLoadTask = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    var accessories: [Accessory] = []
                    for controller in controllers {
                        try await accessories.append(Accessory(device: controller))
                    }
                    guard !Task.isCancelled, psvr2AccessoryGeneration == generation else { return }
                    let provider = AccessoryTrackingProvider(accessories: accessories)
                    psvr2AccessoryTrackingProviderStorage = provider
                    monitorPSVR2Anchors(from: provider)
                    NotificationCenter.default.post(
                        name: .psvr2AccessoryTrackingConfigurationDidChange,
                        object: self
                    )
                    Logger.log(message: "PSVR2 accessories loaded for 6-DoF tracking: \(accessories.count)")
                } catch {
                    Logger.log(message: "PSVR2 accessory loading failed: \(error)")
                }
            }
        }

        private func monitorPSVR2Anchors(from provider: AccessoryTrackingProvider) {
            psvr2AnchorMonitorTask?.cancel()
            psvr2AnchorMonitorTask = Task { @MainActor [weak self] in
                for await update in provider.anchorUpdates {
                    guard let self, !Task.isCancelled else { return }
                    applyPSVR2Anchor(update.anchor, removed: update.event == .removed)
                }
            }
        }

        private func applyPSVR2Anchor(_ anchor: AccessoryAnchor, removed: Bool) {
            let chirality = anchor.heldChirality ?? anchor.accessory.inherentChirality
            let engineChirality: XRSpatialChirality
            switch chirality {
            case .left: engineChirality = .left
            case .right: engineChirality = .right
            case .unspecified: return
            @unknown default: return
            }

            let state: PSVR2TrackingState
            switch anchor.trackingState {
            case .untracked: state = .unavailable
            case .orientationTracked: state = .orientationOnly
            case .positionOrientationTracked: state = .positionAndOrientation
            case .positionOrientationTrackedLowAccuracy: state = .positionAndOrientationLowAccuracy
            @unknown default: state = .unavailable
            }

            applyPSVR2Pose(
                chirality: engineChirality,
                tracked: anchor.isTracked && !removed,
                trackingState: removed ? .unavailable : state,
                transform: anchor.originFromAnchorTransform,
                velocity: removed ? .zero : anchor.velocity,
                angularVelocity: removed ? .zero : anchor.angularVelocity
            )
        }
    }
#endif

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}
