//
//  InputSystemAPI.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

// MARK: - Input Config

public enum XRInputProperty: Sendable {
    case pickingBackend(ScenePickingBackendPreference)
    case twoHandRotateAxisMode(XRSpatialTwoHandRotateAxisMode)
    case sceneReady(Bool)
}

public enum InputProperty: Sendable {
    case xr(XRInputProperty)
}

public func setInput(_ property: InputProperty) {
    switch property {
    case let .xr(xrProperty):
        applyXRInputProperty(xrProperty)
    }
}

private func applyXRInputProperty(_ property: XRInputProperty) {
    switch property {
    case let .pickingBackend(preference):
        InputSystem.shared.setXRSpatialPickingBackendPreference(preference)
    case let .twoHandRotateAxisMode(mode):
        InputSystem.shared.setXRTwoHandRotateAxisMode(mode)
    case let .sceneReady(ready):
        InputSystem.shared.setXRSceneReady(ready)
    }
}

// MARK: - Input Actions

public func registerXREvents() {
    InputSystem.shared.registerXREvents()
}

public func unregisterXREvents() {
    InputSystem.shared.unregisterXREvents()
}

// MARK: - Input Queries

public func getXRSpatialInputState() -> XRSpatialInputState {
    InputSystem.shared.xrSpatialInputState
}

public func isXRSceneReady() -> Bool {
    InputSystem.shared.isXRSceneReady()
}

// MARK: - Spatial Manipulation Config (visionOS)

#if os(visionOS)

    public enum SpatialManipulationProperty: Sendable {
        case inputEpsilon(Float)
        case intentTranslationThreshold(Float)
        case intentRotationThreshold(Float)
        case intentDominanceRatio(Float)
        case zoomScale(min: Float, max: Float)
        case rotationDeltaLimit(perFrame: Float, twoHand: Float)
        case twoHandRotationDeadzone(Float)
        case rotationSmoothing(factor: Float, deadzone: Float)
        case classificationFrames(Int)
    }

    public func setSpatialManipulation(_ property: SpatialManipulationProperty) {
        let system = SpatialManipulationSystem.shared
        switch property {
        case let .inputEpsilon(value):
            system.inputEpsilon = max(value, 0)
        case let .intentTranslationThreshold(value):
            system.intentTranslationThresholdMeters = max(value, 0)
        case let .intentRotationThreshold(value):
            system.intentRotationThresholdRadians = max(value, 0)
        case let .intentDominanceRatio(value):
            system.intentDominanceRatio = max(value, 1)
        case let .zoomScale(minScale, maxScale):
            system.minZoomScale = min(minScale, maxScale)
            system.maxZoomScale = max(minScale, maxScale)
        case let .rotationDeltaLimit(perFrame, twoHand):
            system.maxRotationDeltaPerFrameRadians = max(perFrame, 0)
            system.maxTwoHandRotationDeltaPerFrameRadians = max(twoHand, 0)
        case let .twoHandRotationDeadzone(value):
            system.twoHandRotationDeadzoneRadians = max(value, 0)
        case let .rotationSmoothing(factor, deadzone):
            system.rotationDeltaSmoothingFactor = min(max(factor, 0), 1)
            system.rotationDeltaDeadzoneRadians = max(deadzone, 0)
        case let .classificationFrames(value):
            system.manipulationClassificationFrames = max(value, 0)
        }
    }

    // MARK: - Spatial Manipulation Lifecycle

    public func processPinchTransformLifecycle(from state: XRSpatialInputState) {
        SpatialManipulationSystem.shared.processPinchTransformLifecycle(from: state)
    }

    public func applyPinchDragIfNeeded(
        from state: XRSpatialInputState,
        entityId: EntityID? = nil,
        sensitivity: Float = 1.0
    ) {
        SpatialManipulationSystem.shared.applyPinchDragIfNeeded(from: state, entityId: entityId, sensitivity: sensitivity)
    }

    public func processAnchoredPinchDragLifecycle(
        from state: XRSpatialInputState,
        entityId: EntityID? = nil,
        sensitivity: Float = 1.0,
        dragPlane: SpatialDragPlane = .unconstrained
    ) {
        SpatialManipulationSystem.shared.processAnchoredPinchDragLifecycle(
            from: state,
            entityId: entityId,
            sensitivity: sensitivity,
            dragPlane: dragPlane
        )
    }

    public func processAnchoredSceneDragLifecycle(from state: XRSpatialInputState, sensitivity: Float = 1.0) {
        SpatialManipulationSystem.shared.processAnchoredSceneDragLifecycle(from: state, sensitivity: sensitivity)
    }

    public func processAnchoredSceneManipulationLifecycle(
        from state: XRSpatialInputState,
        dragSensitivity: Float = 1.0,
        rotateSensitivity: Float = 1.0
    ) {
        SpatialManipulationSystem.shared.processAnchoredSceneManipulationLifecycle(
            from: state,
            dragSensitivity: dragSensitivity,
            rotateSensitivity: rotateSensitivity
        )
    }

    public func processAnchoredSceneRotateLifecycle(from state: XRSpatialInputState, sensitivity: Float = 1.0) {
        SpatialManipulationSystem.shared.processAnchoredSceneRotateLifecycle(from: state, sensitivity: sensitivity)
    }

    public func applyTwoHandZoomIfNeeded(
        from state: XRSpatialInputState,
        entityId: EntityID? = nil,
        sensitivity: Float = 1.0
    ) {
        SpatialManipulationSystem.shared.applyTwoHandZoomIfNeeded(from: state, entityId: entityId, sensitivity: sensitivity)
    }

    public func applyTwoHandRotateIfNeeded(
        from state: XRSpatialInputState,
        entityId: EntityID? = nil,
        sensitivity: Float = 1.0,
        axisOverrideWorld: simd_float3? = nil
    ) {
        SpatialManipulationSystem.shared.applyTwoHandRotateIfNeeded(
            from: state,
            entityId: entityId,
            sensitivity: sensitivity,
            axisOverrideWorld: axisOverrideWorld
        )
    }

    // MARK: - Spatial Manipulation Session Control

    public func resetSpatialManipulation() {
        SpatialManipulationSystem.shared.reset()
    }

    public func endSpatialManipulation() {
        SpatialManipulationSystem.shared.endSpatialManipulation()
    }

    public func beginAnchoredPinchDragIfNeeded(
        from state: XRSpatialInputState,
        entityId: EntityID? = nil,
        dragPlane: SpatialDragPlane = .unconstrained
    ) {
        SpatialManipulationSystem.shared.beginAnchoredPinchDragIfNeeded(
            from: state,
            entityId: entityId,
            dragPlane: dragPlane
        )
    }

    public func endAnchoredPinchDrag() {
        SpatialManipulationSystem.shared.endAnchoredPinchDrag()
    }

    public func beginAnchoredSceneDragIfNeeded(from state: XRSpatialInputState) {
        SpatialManipulationSystem.shared.beginAnchoredSceneDragIfNeeded(from: state)
    }

    public func endAnchoredSceneDrag() {
        SpatialManipulationSystem.shared.endAnchoredSceneDrag()
    }

    public func endAnchoredSceneManipulation() {
        SpatialManipulationSystem.shared.endAnchoredSceneManipulation()
    }

    public func endAnchoredSceneRotate() {
        SpatialManipulationSystem.shared.endAnchoredSceneRotate()
    }

#endif
