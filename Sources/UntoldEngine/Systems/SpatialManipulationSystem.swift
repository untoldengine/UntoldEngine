//
//  SpatialManipulationSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

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
        var initialRayDirectionProjected: simd_float3?
        var initialInputDeviceForwardProjected: simd_float3?
        var rotationAxisWorld: simd_float3
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

    public final class SpatialManipulationSystem {
        public static let shared: SpatialManipulationSystem = .init()

        public var inputEpsilon: Float = 0.0001
        public var intentTranslationThresholdMeters: Float = 0.01
        public var intentRotationThresholdRadians: Float = 0.08
        public var intentDominanceRatio: Float = 1.15
        public var minZoomScale: Float = 0.05
        public var maxZoomScale: Float = 20.0

        private var manipulationSession: SpatialManipulationSession = .none

        private init() {}

        public func reset() {
            manipulationSession = .none
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

            let entityWorldPosition = getPosition(entityId: entityId)
            var hitPoint = entityWorldPosition
            if let (hitEntity, hitDistance) = pickEntity(rayOrigin: state.rayOriginWorld, rayDirection: rayDirection),
               hitEntity == entityId
            {
                hitPoint = state.rayOriginWorld + rayDirection * hitDistance
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

            if projectedRay == nil, projectedInputForward == nil {
                manipulationSession = .translating(translation)
                return
            }

            let rotation = SpatialRotationSession(
                entityId: entityId,
                initialRotation: localRotation,
                initialRayDirectionProjected: projectedRay,
                initialInputDeviceForwardProjected: projectedInputForward,
                rotationAxisWorld: rotationAxis
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
                if let initialInputForward = pending.rotation.initialInputDeviceForwardProjected,
                   let currentInputOrientation = state.inputDeviceOrientationWorld
                {
                    let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                    if let currentInputForwardProjected = projectDirectionOntoPlane(
                        currentForward,
                        planeNormal: pending.rotation.rotationAxisWorld
                    ) {
                        rotationMagnitude = abs(signedAngleAroundAxis(
                            from: initialInputForward,
                            to: currentInputForwardProjected,
                            axis: pending.rotation.rotationAxisWorld
                        ))
                    } else {
                        rotationMagnitude = 0
                    }
                } else if let initialRayProjected = pending.rotation.initialRayDirectionProjected,
                          let currentRayProjected = projectDirectionOntoPlane(
                              rayDirection,
                              planeNormal: pending.rotation.rotationAxisWorld
                          )
                {
                    rotationMagnitude = abs(signedAngleAroundAxis(
                        from: initialRayProjected,
                        to: currentRayProjected,
                        axis: pending.rotation.rotationAxisWorld
                    ))
                } else {
                    rotationMagnitude = 0
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
                updateSpatialDragRotation(from: state, rayDirection: rayDirection, session: rotation)

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

        public func applyTwoHandZoomIfNeeded(from state: XRSpatialInputState, sensitivity _: Float = 1.0) {
            guard state.leftHandPinching, state.rightHandPinching, state.spatialZoomActive else { return }

            // process zoom
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

        private func updateSpatialDragRotation(from state: XRSpatialInputState, rayDirection: simd_float3, session: SpatialRotationSession) {
            guard scene.mask(for: session.entityId) != nil else {
                endSpatialManipulation()
                return
            }

            if let initialInputForward = session.initialInputDeviceForwardProjected,
               let currentInputOrientation = state.inputDeviceOrientationWorld
            {
                let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                if let currentInputForwardProjected = projectDirectionOntoPlane(
                    currentForward,
                    planeNormal: session.rotationAxisWorld
                ) {
                    let signedAngle = signedAngleAroundAxis(
                        from: initialInputForward,
                        to: currentInputForwardProjected,
                        axis: session.rotationAxisWorld
                    )
                    let deltaRotation = simd_quatf(angle: signedAngle, axis: session.rotationAxisWorld)
                    let targetRotation = simd_normalize(simd_mul(deltaRotation, session.initialRotation))
                    rotateTo(entityId: session.entityId, rotation: getMatrix4x4FromQuaternion(q: targetRotation))
                    return
                }
            }

            guard let initialRayProjected = session.initialRayDirectionProjected,
                  let currentRayProjected = projectDirectionOntoPlane(rayDirection, planeNormal: session.rotationAxisWorld)
            else { return }

            let signedAngle = signedAngleAroundAxis(
                from: initialRayProjected,
                to: currentRayProjected,
                axis: session.rotationAxisWorld
            )
            let deltaRotation = simd_quatf(angle: signedAngle, axis: session.rotationAxisWorld)
            let targetRotation = simd_normalize(simd_mul(deltaRotation, session.initialRotation))
            rotateTo(entityId: session.entityId, rotation: getMatrix4x4FromQuaternion(q: targetRotation))
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
    }
#endif
