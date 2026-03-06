//
//  XRSpatialGestureRecognizer.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(visionOS)
    import Foundation
    import simd
    @preconcurrency import UntoldEngine

    final class XRSpatialGestureRecognizer {
        private let spatialInputEpsilon: Float = 0.0001
        private let dragTranslationThresholdMeters: Float = 0.01
        private let dragRotationThresholdRadians: Float = 0.08
        private let dragActivationHysteresisTranslationMeters: Float = 0.002
        private let dragActivationHysteresisRotationRadians: Float = 0.02
        private let dragActivationHoldDurationSeconds: TimeInterval = 0.02
        private let zoomActivationThresholdMeters: Float = 0.0005
        private let maxZoomDeltaPerFrame: Float = 0.08
        private let rotateActivationThresholdRadians: Float = 0.01
        private let maxRotateDeltaPerFrame: Float = 0.35
        private var interactionActive = false
        private var primaryInteractionId: Int?
        private var interactionExceededDragThreshold = false
        private var interactionDragThresholdCandidateTimestamp: TimeInterval?
        private var interactionInitialInputDevicePositionWorld: simd_float3?
        private var interactionLastInputDevicePositionWorld: simd_float3?
        private var interactionInitialRayDirectionWorld: simd_float3?
        private var interactionPickedEntity: EntityID?
        private var leftHandPositionValid = false
        private var rightHandPositionValid = false
        private var lastTwoHandPinchDistanceMeters: Float?
        private var lastTwoHandPinchVectorWorld: simd_float3?

        func updateSpatialInputState() {
            let snapshots = InputSystem.shared.drainXRSpatialSnapshots()
            var state = InputSystem.shared.xrSpatialInputState
            let pickingBackendPreference = InputSystem.shared.getXRSpatialPickingBackendPreference()

            // Tap is edge-triggered. Clear stale value when entering a new frame.
            let hadTap = state.spatialTapActive
            let hadZoom = state.spatialZoomActive || abs(state.spatialZoomDelta) > 0
            let hadRotate = state.spatialRotateActive || abs(state.spatialRotateDeltaRadians) > 0
            let hadPinchDrag = simd_length_squared(state.spatialPinchDragDelta) > 0
            state.spatialTapActive = false
            state.spatialZoomActive = false
            state.spatialZoomDelta = 0
            state.spatialRotateActive = false
            state.spatialRotateDeltaRadians = 0
            state.spatialPinchDragDelta = .zero

            guard !snapshots.isEmpty else {
                if hadTap || hadZoom || hadRotate || hadPinchDrag {
                    InputSystem.shared.xrSpatialInputState = state
                }
                return
            }

            for (snapshotIndex, snapshot) in snapshots.enumerated() {
                updateHandTrackingState(from: snapshot, state: &state)
                updateTwoHandPinchGestures(state: &state, phase: snapshot.phase)

                let isPrimarySnapshot = !interactionActive || snapshot.interactionId == primaryInteractionId
                guard isPrimarySnapshot else {
                    state.spatialPinchActive = interactionActive || state.leftHandPinching || state.rightHandPinching
                    continue
                }

                let phaseBeforeEvent = state.currentPhase
                state.currentPhase = snapshot.phase
                state.timestamp = snapshot.timestamp

                let rayDirectionRaw = snapshot.rayDirectionWorld
                let rayLengthSquared = simd_length_squared(rayDirectionRaw)
                let hasValidRay = rayLengthSquared.isFinite && rayLengthSquared > (spatialInputEpsilon * spatialInputEpsilon)
                let normalizedRayDirection: simd_float3? = hasValidRay ? (rayDirectionRaw / sqrt(rayLengthSquared)) : nil

                if hasValidRay {
                    state.rayOriginWorld = snapshot.rayOriginWorld
                    state.rayDirectionWorld = snapshot.rayDirectionWorld
                }
                if let inputDevicePositionWorld = snapshot.inputDevicePositionWorld {
                    state.inputDevicePositionWorld = inputDevicePositionWorld
                }
                if let inputDeviceOrientationWorld = snapshot.inputDeviceOrientationWorld {
                    state.inputDeviceOrientationWorld = inputDeviceOrientationWorld
                }

                let shouldPickForSnapshot = normalizedRayDirection != nil && (snapshot.phase == .began || (!interactionActive && snapshot.phase == .changed))

                let pickedEntityFromSnapshot: EntityID?
                var pickedEntityDistance = Float.infinity
                if shouldPickForSnapshot,
                   let normalizedRayDirection,
                   let hit = pickEntity(
                       rayOrigin: snapshot.rayOriginWorld,
                       rayDirection: normalizedRayDirection,
                       options: ScenePickOptions(backend: pickingBackendPreference)
                   )
                {
                    pickedEntityFromSnapshot = hit.entityId
                    pickedEntityDistance = hit.distance
                } else {
                    pickedEntityFromSnapshot = nil
                }

                switch snapshot.phase {
                case .began:
                    interactionActive = true
                    primaryInteractionId = snapshot.interactionId
                    interactionExceededDragThreshold = false
                    interactionDragThresholdCandidateTimestamp = nil
                    interactionInitialInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                    interactionLastInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                    interactionInitialRayDirectionWorld = normalizedRayDirection
                    interactionPickedEntity = pickedEntityFromSnapshot

                    state.spatialDragActive = false
                    state.spatialPinchDragDelta = .zero
                    state.pickedEntityId = pickedEntityFromSnapshot
                    state.pickedEntityDistance = pickedEntityDistance

                case .changed:
                    if !interactionActive {
                        interactionActive = true
                        primaryInteractionId = snapshot.interactionId
                        interactionExceededDragThreshold = false
                        interactionDragThresholdCandidateTimestamp = nil
                        interactionInitialInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                        interactionLastInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                        interactionInitialRayDirectionWorld = normalizedRayDirection
                        interactionPickedEntity = pickedEntityFromSnapshot
                        state.pickedEntityId = pickedEntityFromSnapshot
                        state.pickedEntityDistance = pickedEntityDistance
                    }

                    state.spatialPinchDragDelta = computePinchDragDelta(currentInputDevicePositionWorld: snapshot.inputDevicePositionWorld)

                    if let pickedEntityFromSnapshot {
                        interactionPickedEntity = pickedEntityFromSnapshot
                        state.pickedEntityId = pickedEntityFromSnapshot
                    }

                    let translationDelta: Float
                    if let initialInputDevicePositionWorld = interactionInitialInputDevicePositionWorld,
                       let currentInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                    {
                        translationDelta = simd_length(currentInputDevicePositionWorld - initialInputDevicePositionWorld)
                    } else {
                        translationDelta = 0
                    }

                    let rotationDelta: Float
                    if let initialRayDirectionWorld = interactionInitialRayDirectionWorld,
                       let normalizedRayDirection
                    {
                        rotationDelta = angularDistanceRadians(from: initialRayDirectionWorld, to: normalizedRayDirection)
                    } else {
                        rotationDelta = 0
                    }

                    if interactionExceededDragThreshold == false {
                        let translationThresholdCrossed = translationDelta >= dragTranslationThresholdMeters
                        let rotationThresholdCrossed = rotationDelta >= dragRotationThresholdRadians

                        if translationThresholdCrossed || rotationThresholdCrossed {
                            // Immediate activation for clearly intentional motion.
                            let translationStronglyCrossed = translationDelta >= (
                                dragTranslationThresholdMeters + dragActivationHysteresisTranslationMeters
                            )
                            let rotationStronglyCrossed = rotationDelta >= (
                                dragRotationThresholdRadians + dragActivationHysteresisRotationRadians
                            )

                            if translationStronglyCrossed || rotationStronglyCrossed {
                                interactionExceededDragThreshold = true
                                interactionDragThresholdCandidateTimestamp = nil
                            } else if let candidateTimestamp = interactionDragThresholdCandidateTimestamp {
                                // Light crossings must remain above threshold for a short hold window.
                                let elapsed = max(0, snapshot.timestamp - candidateTimestamp)
                                if elapsed >= dragActivationHoldDurationSeconds {
                                    interactionExceededDragThreshold = true
                                    interactionDragThresholdCandidateTimestamp = nil
                                }
                            } else {
                                interactionDragThresholdCandidateTimestamp = snapshot.timestamp
                            }
                        } else {
                            interactionDragThresholdCandidateTimestamp = nil
                        }
                    }
                    state.spatialDragActive = interactionExceededDragThreshold

                case .ended:
                    let hadInteractionContext = interactionActive || phaseBeforeEvent == .began || phaseBeforeEvent == .changed
                    let isTap = hadInteractionContext && !interactionExceededDragThreshold

                    state.spatialTapActive = isTap
                    state.spatialDragActive = false
                    state.spatialPinchDragDelta = .zero
                    state.pickedEntityId = isTap ? interactionPickedEntity : nil

                    resetSpatialInteractionTracking()

                case .cancelled:
                    state.spatialTapActive = false
                    state.spatialDragActive = false
                    state.spatialPinchDragDelta = .zero
                    state.pickedEntityId = nil

                    resetSpatialInteractionTracking()
                }

                state.spatialPinchActive = interactionActive || state.leftHandPinching || state.rightHandPinching
            }

            state.handTrackingActive = state.leftHandPinching || state.rightHandPinching
            InputSystem.shared.xrSpatialInputState = state
        }

        func resetAllSpatialInteractionTracking() {
            resetSpatialInteractionTracking()
            leftHandPositionValid = false
            rightHandPositionValid = false
            lastTwoHandPinchDistanceMeters = nil
            lastTwoHandPinchVectorWorld = nil
        }

        private func updateHandTrackingState(from snapshot: XRSpatialInputSnapshot, state: inout XRSpatialInputState) {
            guard let chirality = snapshot.chirality else { return }

            switch chirality {
            case .left:
                if let position = snapshot.inputDevicePositionWorld {
                    state.leftHandPosition = position
                    leftHandPositionValid = true
                }
                switch snapshot.phase {
                case .began, .changed:
                    state.leftHandPinching = true
                case .ended, .cancelled:
                    state.leftHandPinching = false
                    leftHandPositionValid = false
                }

            case .right:
                if let position = snapshot.inputDevicePositionWorld {
                    state.rightHandPosition = position
                    rightHandPositionValid = true
                }
                switch snapshot.phase {
                case .began, .changed:
                    state.rightHandPinching = true
                case .ended, .cancelled:
                    state.rightHandPinching = false
                    rightHandPositionValid = false
                }
            }
        }

        private func updateTwoHandPinchGestures(state: inout XRSpatialInputState, phase: XRSpatialInteractionPhase) {
            let rotateAxisWorld = resolveTwoHandRotateAxisWorld()
            state.spatialRotateAxisWorld = rotateAxisWorld

            guard state.leftHandPinching,
                  state.rightHandPinching,
                  leftHandPositionValid,
                  rightHandPositionValid
            else {
                lastTwoHandPinchDistanceMeters = nil
                lastTwoHandPinchVectorWorld = nil
                state.spatialZoomActive = false
                state.spatialZoomDelta = 0
                state.spatialRotateActive = false
                state.spatialRotateDeltaRadians = 0
                return
            }

            let currentPinchVectorWorld = state.rightHandPosition - state.leftHandPosition
            let currentDistance = simd_length(currentPinchVectorWorld)
            guard currentDistance.isFinite, currentDistance > spatialInputEpsilon else {
                lastTwoHandPinchDistanceMeters = nil
                lastTwoHandPinchVectorWorld = nil
                state.spatialZoomActive = false
                state.spatialZoomDelta = 0
                state.spatialRotateActive = false
                state.spatialRotateDeltaRadians = 0
                return
            }

            guard phase == .changed else {
                lastTwoHandPinchDistanceMeters = currentDistance
                lastTwoHandPinchVectorWorld = currentPinchVectorWorld
                state.spatialZoomActive = false
                state.spatialZoomDelta = 0
                state.spatialRotateActive = false
                state.spatialRotateDeltaRadians = 0
                return
            }

            var zoomDelta: Float = 0
            if let previousDistance = lastTwoHandPinchDistanceMeters {
                zoomDelta = currentDistance - previousDistance
                if zoomDelta.isFinite {
                    zoomDelta = simd_clamp(zoomDelta, -maxZoomDeltaPerFrame, maxZoomDeltaPerFrame)
                    if abs(zoomDelta) < zoomActivationThresholdMeters {
                        zoomDelta = 0
                    }
                } else {
                    zoomDelta = 0
                }
            }
            state.spatialZoomDelta = zoomDelta
            state.spatialZoomActive = zoomDelta != 0

            let rotateDelta = computeTwoHandRotateDelta(currentPinchVectorWorld: currentPinchVectorWorld, axisWorld: rotateAxisWorld)
            state.spatialRotateDeltaRadians = rotateDelta
            state.spatialRotateActive = rotateDelta != 0

            lastTwoHandPinchDistanceMeters = currentDistance
            lastTwoHandPinchVectorWorld = currentPinchVectorWorld
        }

        private func resolveTwoHandRotateAxisWorld() -> simd_float3 {
            if let camera = CameraSystem.shared.activeCamera {
                let cameraForwardRaw = getForwardAxisVector(entityId: camera)
                let cameraForwardLengthSquared = simd_length_squared(cameraForwardRaw)
                if cameraForwardLengthSquared.isFinite, cameraForwardLengthSquared > (spatialInputEpsilon * spatialInputEpsilon) {
                    return cameraForwardRaw / sqrt(cameraForwardLengthSquared)
                }
            }
            return simd_float3(0, 0, -1)
        }

        private func computeTwoHandRotateDelta(currentPinchVectorWorld: simd_float3, axisWorld: simd_float3) -> Float {
            guard let previousPinchVectorWorld = lastTwoHandPinchVectorWorld,
                  let previousProjected = projectVectorOntoPlane(previousPinchVectorWorld, planeNormal: axisWorld),
                  let currentProjected = projectVectorOntoPlane(currentPinchVectorWorld, planeNormal: axisWorld)
            else {
                return 0
            }

            let sine = simd_dot(axisWorld, simd_cross(previousProjected, currentProjected))
            let cosine = simd_clamp(simd_dot(previousProjected, currentProjected), -1.0, 1.0)
            var rotateDelta = atan2(sine, cosine)
            guard rotateDelta.isFinite else { return 0 }

            rotateDelta = simd_clamp(rotateDelta, -maxRotateDeltaPerFrame, maxRotateDeltaPerFrame)
            if abs(rotateDelta) < rotateActivationThresholdRadians {
                return 0
            }
            return rotateDelta
        }

        private func projectVectorOntoPlane(_ vector: simd_float3, planeNormal: simd_float3) -> simd_float3? {
            let projected = vector - planeNormal * simd_dot(vector, planeNormal)
            let projectedLengthSquared = simd_length_squared(projected)
            guard projectedLengthSquared.isFinite, projectedLengthSquared > (spatialInputEpsilon * spatialInputEpsilon) else {
                return nil
            }
            return projected / sqrt(projectedLengthSquared)
        }

        private func resetSpatialInteractionTracking() {
            interactionActive = false
            primaryInteractionId = nil
            interactionExceededDragThreshold = false
            interactionDragThresholdCandidateTimestamp = nil
            interactionInitialInputDevicePositionWorld = nil
            interactionLastInputDevicePositionWorld = nil
            interactionInitialRayDirectionWorld = nil
            interactionPickedEntity = nil
            lastTwoHandPinchDistanceMeters = nil
            lastTwoHandPinchVectorWorld = nil
        }

        private func computePinchDragDelta(currentInputDevicePositionWorld: simd_float3?) -> simd_float3 {
            guard let previousInputPosition = interactionLastInputDevicePositionWorld,
                  let currentInputPosition = currentInputDevicePositionWorld
            else {
                interactionLastInputDevicePositionWorld = currentInputDevicePositionWorld
                return .zero
            }

            defer { interactionLastInputDevicePositionWorld = currentInputPosition }

            let delta = currentInputPosition - previousInputPosition
            guard delta.x.isFinite, delta.y.isFinite, delta.z.isFinite else {
                return .zero
            }
            return delta
        }

        private func angularDistanceRadians(from: simd_float3, to: simd_float3) -> Float {
            let fromLengthSquared = simd_length_squared(from)
            let toLengthSquared = simd_length_squared(to)
            guard fromLengthSquared > (spatialInputEpsilon * spatialInputEpsilon),
                  toLengthSquared > (spatialInputEpsilon * spatialInputEpsilon)
            else {
                return 0
            }

            let fromNormalized = from / sqrt(fromLengthSquared)
            let toNormalized = to / sqrt(toLengthSquared)
            let cosine = simd_clamp(simd_dot(fromNormalized, toNormalized), -1.0, 1.0)
            return acos(cosine)
        }
    }
#endif
