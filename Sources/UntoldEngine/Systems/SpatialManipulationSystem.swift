//
//  SpatialManipulationSystem.swift
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

    private struct SpatialTranslationSession {
        var entityId: EntityID
        var planePoint: simd_float3
        var planeNormal: simd_float3
        var grabOffset: simd_float3
        var initialEntityWorldPosition: simd_float3
        var initialInputDevicePositionWorld: simd_float3?
    }

    private struct SpatialRotationSession {
        var entityId: EntityID
        var initialRotation: simd_quatf
        var initialProjectedDirection: simd_float3
        var rotationAxisWorld: simd_float3
        var rotationInputMode: SpatialRotationInputMode
        var lastProjectedDirection: simd_float3
        var accumulatedAngleRadians: Float
        var smoothedDeltaRadians: Float
    }

    private enum SpatialRotationInputMode {
        case inputDeviceForward
        case rayDirection
    }

    private struct SpatialPendingSession {
        var translation: SpatialTranslationSession
        var rotation: SpatialRotationSession
    }

    private enum SpatialManipulationSession {
        case none
        case pending(SpatialPendingSession)
        case translating(SpatialTranslationSession)
        case rotating(SpatialRotationSession)
    }

    private struct AnchoredPinchDragSession {
        var entityId: EntityID
        var initialInputDevicePositionWorld: simd_float3
        var initialEntityWorldPosition: simd_float3
    }

    private struct AnchoredSceneDragSession {
        var initialInputDevicePositionWorld: simd_float3
        var initialScenePosition: simd_float3
    }

    public final class SpatialManipulationSystem {
        public static let shared: SpatialManipulationSystem = .init()

        public var inputEpsilon: Float = 0.0001
        public var intentTranslationThresholdMeters: Float = 0.01
        public var intentRotationThresholdRadians: Float = 0.08
        public var intentDominanceRatio: Float = 1.15
        public var minZoomScale: Float = 0.05
        public var maxZoomScale: Float = 20.0
        public var maxRotationDeltaPerFrameRadians: Float = 0.12
        public var maxTwoHandRotationDeltaPerFrameRadians: Float = 0.35
        public var twoHandRotationDeadzoneRadians: Float = 0.001
        public var rotationDeltaSmoothingFactor: Float = 0.25
        public var rotationDeltaDeadzoneRadians: Float = 0.002

        private var manipulationSession: SpatialManipulationSession = .none
        private var anchoredPinchDragSession: AnchoredPinchDragSession?
        private var anchoredSceneDragSession: AnchoredSceneDragSession?

        private init() {}

        public func reset() {
            manipulationSession = .none
            anchoredPinchDragSession = nil
            anchoredSceneDragSession = nil
        }

        public func processPinchTransformLifecycle(from state: XRSpatialInputState) {
            if state.currentPhase == .changed {
                beginSpatialManipulationIfNeeded(from: state)
            }

            if state.spatialDragActive {
                updateSpatialManipulation(from: state)
            }

            if state.currentPhase == .ended || state.currentPhase == .cancelled {
                endSpatialManipulation()
            }
        }

        public func beginSpatialManipulationIfNeeded(from state: XRSpatialInputState) {
            guard case .none = manipulationSession else { return }
            guard let entityId = state.pickedEntityId, scene.mask(for: entityId) != nil else { return }

            let rayDirectionRaw = state.rayDirectionWorld
            let rayLengthSquared = simd_length_squared(rayDirectionRaw)
            guard rayLengthSquared.isFinite, rayLengthSquared > (inputEpsilon * inputEpsilon) else { return }
            let rayDirection = rayDirectionRaw / sqrt(rayLengthSquared)
            let pickingBackendPreference = InputSystem.shared.getXRSpatialPickingBackendPreference()

            let entityWorldPosition = getPosition(entityId: entityId)
            var hitPoint = entityWorldPosition
            if let hit = pickEntity(
                rayOrigin: state.rayOriginWorld,
                rayDirection: rayDirection,
                options: ScenePickOptions(backend: pickingBackendPreference)
            ),
                hit.entityId == entityId
            {
                hitPoint = hit.worldPosition
            }

            let translation = SpatialTranslationSession(
                entityId: entityId,
                planePoint: hitPoint,
                planeNormal: -rayDirection,
                grabOffset: entityWorldPosition - hitPoint,
                initialEntityWorldPosition: entityWorldPosition,
                initialInputDevicePositionWorld: state.inputDevicePositionWorld
            )

            let localRotationMatrix = getLocalOrientation(entityId: entityId)
            let localRotation = simd_normalize(transformMatrix3nToQuaternion(m: localRotationMatrix))
            let rotationAxis = simd_float3(0, 1, 0)
            let projectedRay = projectDirectionOntoPlane(rayDirection, planeNormal: rotationAxis)

            let projectedInputForward: simd_float3?
            if let inputOrientation = state.inputDeviceOrientationWorld {
                let forward = simd_act(inputOrientation, simd_float3(0, 0, -1))
                projectedInputForward = projectDirectionOntoPlane(forward, planeNormal: rotationAxis)
            } else {
                projectedInputForward = nil
            }

            let rotationInputMode: SpatialRotationInputMode
            let initialProjectedDirection: simd_float3
            if let projectedInputForward {
                rotationInputMode = .inputDeviceForward
                initialProjectedDirection = projectedInputForward
            } else if let projectedRay {
                rotationInputMode = .rayDirection
                initialProjectedDirection = projectedRay
            } else {
                manipulationSession = .translating(translation)
                return
            }

            let rotation = SpatialRotationSession(
                entityId: entityId,
                initialRotation: localRotation,
                initialProjectedDirection: initialProjectedDirection,
                rotationAxisWorld: rotationAxis,
                rotationInputMode: rotationInputMode,
                lastProjectedDirection: initialProjectedDirection,
                accumulatedAngleRadians: 0,
                smoothedDeltaRadians: 0
            )

            manipulationSession = .pending(SpatialPendingSession(translation: translation, rotation: rotation))
        }

        public func updateSpatialManipulation(from state: XRSpatialInputState) {
            let rayDirectionRaw = state.rayDirectionWorld
            let rayLengthSquared = simd_length_squared(rayDirectionRaw)
            guard rayLengthSquared.isFinite, rayLengthSquared > (inputEpsilon * inputEpsilon) else { return }
            let rayDirection = rayDirectionRaw / sqrt(rayLengthSquared)

            switch manipulationSession {
            case let .pending(pending):
                let translationMagnitude: Float
                if let initialInputDevicePosition = pending.translation.initialInputDevicePositionWorld,
                   let currentInputDevicePosition = state.inputDevicePositionWorld
                {
                    translationMagnitude = simd_length(currentInputDevicePosition - initialInputDevicePosition)
                } else {
                    translationMagnitude = 0
                }

                let rotationMagnitude: Float
                switch pending.rotation.rotationInputMode {
                case .inputDeviceForward:
                    if let currentInputOrientation = state.inputDeviceOrientationWorld {
                        let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                        if let currentInputForwardProjected = projectDirectionOntoPlane(
                            currentForward,
                            planeNormal: pending.rotation.rotationAxisWorld
                        ) {
                            rotationMagnitude = abs(signedAngleAroundAxis(
                                from: pending.rotation.initialProjectedDirection,
                                to: currentInputForwardProjected,
                                axis: pending.rotation.rotationAxisWorld
                            ))
                        } else {
                            rotationMagnitude = 0
                        }
                    } else {
                        rotationMagnitude = 0
                    }
                case .rayDirection:
                    if let currentRayProjected = projectDirectionOntoPlane(
                        rayDirection,
                        planeNormal: pending.rotation.rotationAxisWorld
                    ) {
                        rotationMagnitude = abs(signedAngleAroundAxis(
                            from: pending.rotation.initialProjectedDirection,
                            to: currentRayProjected,
                            axis: pending.rotation.rotationAxisWorld
                        ))
                    } else {
                        rotationMagnitude = 0
                    }
                }

                let translationReady = translationMagnitude >= intentTranslationThresholdMeters
                let rotationReady = rotationMagnitude >= intentRotationThresholdRadians

                if translationReady, !rotationReady {
                    manipulationSession = .translating(pending.translation)
                } else if rotationReady, !translationReady {
                    manipulationSession = .rotating(pending.rotation)
                } else if translationReady, rotationReady {
                    let translationScore = translationMagnitude / max(intentTranslationThresholdMeters, inputEpsilon)
                    let rotationScore = rotationMagnitude / max(intentRotationThresholdRadians, inputEpsilon)

                    if translationScore >= rotationScore * intentDominanceRatio {
                        manipulationSession = .translating(pending.translation)
                    } else if rotationScore >= translationScore * intentDominanceRatio {
                        manipulationSession = .rotating(pending.rotation)
                    } else {
                        manipulationSession = translationScore >= rotationScore
                            ? .translating(pending.translation)
                            : .rotating(pending.rotation)
                    }
                } else {
                    manipulationSession = .translating(pending.translation)
                }

                updateSpatialManipulation(from: state)

            case let .translating(translation):
                updateSpatialDragTranslation(from: state, session: translation)

            case let .rotating(rotation):
                var updatedRotation = rotation
                let continueRotation = updateSpatialDragRotation(from: state, rayDirection: rayDirection, session: &updatedRotation)
                if continueRotation {
                    manipulationSession = .rotating(updatedRotation)
                } else {
                    endSpatialManipulation()
                }

            case .none:
                break
            }
        }

        public func endSpatialManipulation() {
            manipulationSession = .none
        }

        public func applyPinchDragIfNeeded(from state: XRSpatialInputState, entityId: EntityID? = nil, sensitivity: Float = 1.0) {
            guard state.spatialPinchActive else { return }
            guard let target = resolveManipulationTarget(explicitEntityId: entityId, state: state),
                  scene.mask(for: target) != nil
            else {
                return
            }

            let dragDelta = InputSystem.shared.getPinchDragDelta() * sensitivity
            guard dragDelta.x.isFinite, dragDelta.y.isFinite, dragDelta.z.isFinite else { return }

            if simd_length_squared(dragDelta) <= (inputEpsilon * inputEpsilon) {
                return
            }

            let currentWorldPosition = getPosition(entityId: target)
            let targetWorldPosition = currentWorldPosition + dragDelta
            let targetLocalPosition = worldPositionToLocal(entityId: target, worldPosition: targetWorldPosition)
            translateTo(entityId: target, position: targetLocalPosition)
        }

        /// Session-based anchored drag that avoids per-frame delta accumulation.
        ///
        /// Call this each frame from your input loop.
        /// It captures the initial hand + entity world positions and applies absolute displacement.
        public func processAnchoredPinchDragLifecycle(from state: XRSpatialInputState, entityId: EntityID? = nil, sensitivity: Float = 1.0) {
            if state.currentPhase == .ended || state.currentPhase == .cancelled {
                endAnchoredPinchDrag()
                return
            }

            guard state.spatialPinchActive else {
                if anchoredPinchDragSession != nil, state.spatialDragActive == false {
                    endAnchoredPinchDrag()
                }
                return
            }

            if anchoredPinchDragSession == nil {
                beginAnchoredPinchDragIfNeeded(from: state, entityId: entityId)
            }

            guard state.spatialDragActive,
                  let session = anchoredPinchDragSession
            else {
                return
            }

            guard scene.mask(for: session.entityId) != nil else {
                endAnchoredPinchDrag()
                return
            }

            guard let currentInputDevicePosition = state.inputDevicePositionWorld else { return }
            guard currentInputDevicePosition.x.isFinite,
                  currentInputDevicePosition.y.isFinite,
                  currentInputDevicePosition.z.isFinite
            else { return }

            let clampedSensitivity = max(sensitivity, 0)
            let delta = (currentInputDevicePosition - session.initialInputDevicePositionWorld) * clampedSensitivity
            guard delta.x.isFinite, delta.y.isFinite, delta.z.isFinite else { return }

            let targetWorldPosition = session.initialEntityWorldPosition + delta
            let targetLocalPosition = worldPositionToLocal(entityId: session.entityId, worldPosition: targetWorldPosition)
            translateTo(entityId: session.entityId, position: targetLocalPosition)
        }

        public func beginAnchoredPinchDragIfNeeded(from state: XRSpatialInputState, entityId: EntityID? = nil) {
            guard anchoredPinchDragSession == nil else { return }

            guard let target = resolveManipulationTarget(explicitEntityId: entityId, state: state),
                  scene.mask(for: target) != nil,
                  let initialInputDevicePosition = state.inputDevicePositionWorld
            else {
                return
            }

            guard initialInputDevicePosition.x.isFinite,
                  initialInputDevicePosition.y.isFinite,
                  initialInputDevicePosition.z.isFinite
            else {
                return
            }

            anchoredPinchDragSession = AnchoredPinchDragSession(
                entityId: target,
                initialInputDevicePositionWorld: initialInputDevicePosition,
                initialEntityWorldPosition: getPosition(entityId: target)
            )
        }

        public func endAnchoredPinchDrag() {
            anchoredPinchDragSession = nil
        }

        // MARK: - Anchored Scene Drag

        /// Session-based anchored drag that translates the entire scene root.
        ///
        /// Call this each frame from your input loop.
        /// It captures the initial hand position + scene root position and applies absolute displacement
        /// via `translateSceneTo`, keeping static batches intact.
        public func processAnchoredSceneDragLifecycle(from state: XRSpatialInputState, sensitivity: Float = 1.0) {
            if state.currentPhase == .ended || state.currentPhase == .cancelled {
                endAnchoredSceneDrag()
                return
            }

            guard state.spatialPinchActive else {
                if anchoredSceneDragSession != nil, state.spatialDragActive == false {
                    endAnchoredSceneDrag()
                }
                return
            }

            if anchoredSceneDragSession == nil {
                beginAnchoredSceneDragIfNeeded(from: state)
            }

            guard state.spatialDragActive,
                  let session = anchoredSceneDragSession
            else {
                return
            }

            guard let currentInputDevicePosition = state.inputDevicePositionWorld else { return }
            guard currentInputDevicePosition.x.isFinite,
                  currentInputDevicePosition.y.isFinite,
                  currentInputDevicePosition.z.isFinite
            else { return }

            let clampedSensitivity = max(sensitivity, 0)
            let delta = (currentInputDevicePosition - session.initialInputDevicePositionWorld) * clampedSensitivity
            guard delta.x.isFinite, delta.y.isFinite, delta.z.isFinite else { return }

            translateSceneTo(position: session.initialScenePosition + delta)
        }

        public func beginAnchoredSceneDragIfNeeded(from state: XRSpatialInputState) {
            guard anchoredSceneDragSession == nil else { return }

            guard let initialInputDevicePosition = state.inputDevicePositionWorld else { return }
            guard initialInputDevicePosition.x.isFinite,
                  initialInputDevicePosition.y.isFinite,
                  initialInputDevicePosition.z.isFinite
            else { return }

            anchoredSceneDragSession = AnchoredSceneDragSession(
                initialInputDevicePositionWorld: initialInputDevicePosition,
                initialScenePosition: SceneRootTransform.shared.position
            )
        }

        public func endAnchoredSceneDrag() {
            anchoredSceneDragSession = nil
        }

        public func applyTwoHandZoomIfNeeded(
            from state: XRSpatialInputState,
            entityId: EntityID? = nil,
            sensitivity: Float = 1.0
        ) {
            guard state.leftHandPinching, state.rightHandPinching, state.spatialZoomActive else { return }

            guard let target = resolveTwoHandTransformTarget(from: state, explicitEntityId: entityId),
                  scene.mask(for: target) != nil
            else {
                return
            }

            let clampedSensitivity = max(sensitivity, 0)
            let zoomDelta = InputSystem.shared.getSpatialZoomDelta() * clampedSensitivity
            guard zoomDelta.isFinite else { return }

            if abs(zoomDelta) < inputEpsilon {
                return
            }

            let scaleFactor = max(0, 1 + zoomDelta)
            var targetScale = getScale(entityId: target) * scaleFactor
            targetScale.x = simd_clamp(targetScale.x, minZoomScale, maxZoomScale)
            targetScale.y = simd_clamp(targetScale.y, minZoomScale, maxZoomScale)
            targetScale.z = simd_clamp(targetScale.z, minZoomScale, maxZoomScale)

            guard targetScale.x.isFinite, targetScale.y.isFinite, targetScale.z.isFinite else { return }
            scaleTo(entityId: target, scale: targetScale)
        }

        public func applyTwoHandRotateIfNeeded(
            from state: XRSpatialInputState,
            entityId: EntityID? = nil,
            sensitivity: Float = 1.0,
            axisOverrideWorld: simd_float3? = nil
        ) {
            guard state.leftHandPinching, state.rightHandPinching, state.spatialRotateActive else { return }
            guard let target = resolveTwoHandTransformTarget(from: state, explicitEntityId: entityId),
                  scene.mask(for: target) != nil
            else {
                return
            }

            let clampedSensitivity = max(sensitivity, 0)
            var deltaRadians = InputSystem.shared.getSpatialRotateDelta() * clampedSensitivity
            guard deltaRadians.isFinite else { return }

            deltaRadians = simd_clamp(
                deltaRadians,
                -maxTwoHandRotationDeltaPerFrameRadians,
                maxTwoHandRotationDeltaPerFrameRadians
            )
            if abs(deltaRadians) < twoHandRotationDeadzoneRadians {
                return
            }

            var axisWorld = axisOverrideWorld ?? InputSystem.shared.getSpatialRotateAxisWorld()
            guard axisWorld.x.isFinite, axisWorld.y.isFinite, axisWorld.z.isFinite else { return }
            let axisLengthSquared = simd_length_squared(axisWorld)
            guard axisLengthSquared > (inputEpsilon * inputEpsilon) else { return }
            axisWorld /= sqrt(axisLengthSquared)

            let axisLocal = resolveAxisInTargetLocalSpace(axisWorld: axisWorld, targetEntityId: target)
            let deltaRotation = simd_quatf(angle: deltaRadians, axis: axisLocal)
            let currentLocalMatrix = getLocalOrientation(entityId: target)
            let currentRotation = simd_normalize(simd_quatf(currentLocalMatrix))
            let newRotation = simd_normalize(deltaRotation * currentRotation)

            guard newRotation.vector.x.isFinite,
                  newRotation.vector.y.isFinite,
                  newRotation.vector.z.isFinite,
                  newRotation.vector.w.isFinite
            else { return }

            rotateTo(entityId: target, rotation: getMatrix4x4FromQuaternion(q: newRotation))
        }

        private func updateSpatialDragTranslation(from state: XRSpatialInputState, session: SpatialTranslationSession) {
            guard scene.mask(for: session.entityId) != nil else {
                endSpatialManipulation()
                return
            }

            if let initialInputDevicePosition = session.initialInputDevicePositionWorld,
               let currentInputDevicePosition = state.inputDevicePositionWorld
            {
                let delta = currentInputDevicePosition - initialInputDevicePosition
                if simd_length_squared(delta) > (inputEpsilon * inputEpsilon) {
                    let targetWorldPosition = session.initialEntityWorldPosition + delta
                    let targetLocalPosition = worldPositionToLocal(entityId: session.entityId, worldPosition: targetWorldPosition)
                    translateTo(entityId: session.entityId, position: targetLocalPosition)
                    return
                }
            }

            let rayDirectionRaw = state.rayDirectionWorld
            let rayLengthSquared = simd_length_squared(rayDirectionRaw)
            guard rayLengthSquared.isFinite, rayLengthSquared > (inputEpsilon * inputEpsilon) else { return }
            let rayDirection = rayDirectionRaw / sqrt(rayLengthSquared)

            guard let hitPoint = rayPlaneIntersection(
                rayOrigin: state.rayOriginWorld,
                rayDirection: rayDirection,
                planePoint: session.planePoint,
                planeNormal: session.planeNormal
            ) else { return }

            let targetWorldPosition = hitPoint + session.grabOffset
            let targetLocalPosition = worldPositionToLocal(entityId: session.entityId, worldPosition: targetWorldPosition)
            translateTo(entityId: session.entityId, position: targetLocalPosition)
        }

        private func updateSpatialDragRotation(from state: XRSpatialInputState, rayDirection: simd_float3, session: inout SpatialRotationSession) -> Bool {
            guard scene.mask(for: session.entityId) != nil else {
                return false
            }

            let currentProjectedDirection: simd_float3?
            switch session.rotationInputMode {
            case .inputDeviceForward:
                if let currentInputOrientation = state.inputDeviceOrientationWorld {
                    let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                    currentProjectedDirection = projectDirectionOntoPlane(
                        currentForward,
                        planeNormal: session.rotationAxisWorld
                    )
                } else {
                    currentProjectedDirection = nil
                }
            case .rayDirection:
                currentProjectedDirection = projectDirectionOntoPlane(
                    rayDirection,
                    planeNormal: session.rotationAxisWorld
                )
            }

            guard let currentProjectedDirection else {
                return true
            }

            var incrementalDelta = signedAngleAroundAxis(
                from: session.lastProjectedDirection,
                to: currentProjectedDirection,
                axis: session.rotationAxisWorld
            )
            guard incrementalDelta.isFinite else {
                session.lastProjectedDirection = currentProjectedDirection
                return true
            }

            incrementalDelta = simd_clamp(
                incrementalDelta,
                -maxRotationDeltaPerFrameRadians,
                maxRotationDeltaPerFrameRadians
            )

            if abs(incrementalDelta) < rotationDeltaDeadzoneRadians {
                incrementalDelta = 0
            }

            let smoothing = simd_clamp(rotationDeltaSmoothingFactor, 0, 1)
            let reversingDirection = session.smoothedDeltaRadians * incrementalDelta < 0
            if reversingDirection {
                // Avoid cross-sign blending drag when user flips twist direction.
                session.smoothedDeltaRadians = incrementalDelta
            } else {
                session.smoothedDeltaRadians = simd_mix(session.smoothedDeltaRadians, incrementalDelta, smoothing)
            }

            if abs(session.smoothedDeltaRadians) >= rotationDeltaDeadzoneRadians {
                session.accumulatedAngleRadians += session.smoothedDeltaRadians
            }

            if !session.accumulatedAngleRadians.isFinite {
                session.accumulatedAngleRadians = 0
                session.smoothedDeltaRadians = 0
            }

            let deltaRotation = simd_quatf(angle: session.accumulatedAngleRadians, axis: session.rotationAxisWorld)
            let targetRotation = simd_normalize(simd_mul(deltaRotation, session.initialRotation))
            rotateTo(entityId: session.entityId, rotation: getMatrix4x4FromQuaternion(q: targetRotation))
            session.lastProjectedDirection = currentProjectedDirection
            return true
        }

        private func resolveManipulationTarget(explicitEntityId: EntityID?, state: XRSpatialInputState) -> EntityID? {
            if let explicitEntityId {
                return explicitEntityId
            }
            if let picked = state.pickedEntityId {
                return picked
            }
            return activeManipulationEntityId()
        }

        private func activeManipulationEntityId() -> EntityID? {
            switch manipulationSession {
            case let .pending(pending):
                return pending.translation.entityId
            case let .translating(translation):
                return translation.entityId
            case let .rotating(rotation):
                return rotation.entityId
            case .none:
                return nil
            }
        }

        private func resolveTwoHandTransformTarget(from state: XRSpatialInputState, explicitEntityId: EntityID? = nil) -> EntityID? {
            if let explicitEntityId {
                return explicitEntityId
            }
            guard let picked = state.pickedEntityId else { return nil }
            if let parent = getEntityParent(entityId: picked), scene.mask(for: parent) != nil {
                return parent
            }
            return picked
        }

        private func resolveAxisInTargetLocalSpace(axisWorld: simd_float3, targetEntityId: EntityID) -> simd_float3 {
            guard let parentId = getEntityParent(entityId: targetEntityId),
                  scene.mask(for: parentId) != nil
            else {
                return axisWorld
            }

            let parentWorldRotationMatrix = getOrientation(entityId: parentId)
            let parentWorldRotation = simd_normalize(simd_quatf(parentWorldRotationMatrix))
            var axisLocal = simd_act(parentWorldRotation.inverse, axisWorld)
            guard axisLocal.x.isFinite, axisLocal.y.isFinite, axisLocal.z.isFinite else {
                return axisWorld
            }

            let axisLengthSquared = simd_length_squared(axisLocal)
            guard axisLengthSquared > (inputEpsilon * inputEpsilon) else {
                return axisWorld
            }
            axisLocal /= sqrt(axisLengthSquared)
            return axisLocal
        }
    }
#endif
