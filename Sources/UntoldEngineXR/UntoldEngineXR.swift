//
//  UntoldEngineXR.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(visionOS)
    import CompositorServices
    import Foundation
    import Metal
    @preconcurrency import UntoldEngine
    #if canImport(ARKit)
        import ARKit
        import SwiftUI
    #endif

    public enum UntoldImmersionMode {
        case none
        case mixed
        case full
    }

    public final class UntoldEngineXR {
        private var renderer: UntoldRenderer?
        private var _isRunning = false
        private let lock = NSLock()
        private var lastWorldTrackingRecoveryAttemptTime: CFTimeInterval = 0
        private let worldTrackingRecoveryCooldownSeconds: CFTimeInterval = 2.0

        private let layerRenderer: LayerRenderer?

        // Cache last valid device anchor to use when ARKit returns nil
        // (prevents "Presenting a drawable without a device anchor" error)
        private var lastValidDeviceAnchor: DeviceAnchor?

        // Reuse render pass descriptors to avoid allocation churn (2 eyes × 90 FPS = 180 allocs/sec)
        private let passDescriptorLeft = MTLRenderPassDescriptor()
        private let passDescriptorRight = MTLRenderPassDescriptor()

        #if canImport(ARKit)
            private let arSession = ARKitSession()
            private let worldTracking = WorldTrackingProvider()
        #else
            private let arSession: Any? = nil
            private let worldTracking: WorldTrackingProvider? = nil
        #endif

        public init?(layerRenderer: LayerRenderer, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
            guard let device, let commandQueue = device.makeCommandQueue() else { return nil }

            self.layerRenderer = layerRenderer

            initUntoldXR(device: device, commandQueue: commandQueue, layerRenderer: layerRenderer)
        }

        public func initUntoldXR(device: MTLDevice, commandQueue: MTLCommandQueue, layerRenderer: LayerRenderer) {
            configureSpatialEventBridge()

            // Start ARKit tracking asynchronously
            // Use unstructured Task to avoid blocking initialization
            let worldTracking = worldTracking
            let arSession = arSession
            Task {
                do {
                    guard worldTracking.state != .running else { return }
                    try await arSession.run([worldTracking])
                } catch {
                    print("⚠️ Failed to start world tracking: \(error)")
                }
            }

            let configuration = layerRenderer.configuration
            _ = configuration.layout

            let colorPixelFormat = configuration.colorFormat
            let depthPixelFormat = configuration.depthFormat

            // **VERIFY THIS** Need to verify this. Couldn't find any info
            let viewPort = simd_float2(2048, 1984)

            guard let untoldrenderer = UntoldRenderer.createXR(configuration: nil, device: device, commandQueue: commandQueue, colorPixelFormat: colorPixelFormat, depthPixelFormat: depthPixelFormat, viewPort: viewPort) else {
                print("Failed to initialize the renderer")
                return
            }

            renderer = untoldrenderer
        }

        public func setupCallbacks(
            gameUpdate: @escaping (_ deltaTime: Float) -> Void,
            handleInput: @escaping () -> Void
        ) {
            renderer?.setupCallbacks(gameUpdate: gameUpdate, handleInput: handleInput)
        }

        public func enqueueSpatialInputSnapshot(_ snapshot: XRSpatialInputSnapshot) {
            InputSystem.shared.enqueueXRSpatialSnapshot(snapshot)
        }

        public func clearSpatialInput() {
            InputSystem.shared.clearXRSpatialSnapshots()
            InputSystem.shared.xrSpatialInputState = XRSpatialInputState()
            resetAllSpatialInteractionTracking()
        }

        private func configureSpatialEventBridge() {
            guard let layerRenderer else { return }

            layerRenderer.onSpatialEvent = { events in
                guard InputSystem.shared.xrEventsEnabled else { return }

                for event in events {
                    // Extract selection ray if available
                    let origin: simd_float3
                    let direction: simd_float3

                    if let selectionRay = event.selectionRay {
                        origin = simd_float3(
                            Float(selectionRay.origin.x),
                            Float(selectionRay.origin.y),
                            Float(selectionRay.origin.z)
                        )
                        direction = simd_float3(
                            Float(selectionRay.direction.x),
                            Float(selectionRay.direction.y),
                            Float(selectionRay.direction.z)
                        )
                    } else {
                        // No selection ray (can happen on .ended) - use zero vectors
                        // The state update logic will handle this gracefully
                        origin = .zero
                        direction = .zero
                    }

                    let inputDevicePositionWorld: simd_float3?
                    let inputDeviceOrientationWorld: simd_quatf?
                    if let pose3D = event.inputDevicePose?.pose3D {
                        let matrix = pose3D.matrix
                        inputDevicePositionWorld = simd_float3(
                            Float(matrix.columns.3.x),
                            Float(matrix.columns.3.y),
                            Float(matrix.columns.3.z)
                        )

                        let rotationMatrix = simd_float3x3(
                            simd_float3(Float(matrix.columns.0.x), Float(matrix.columns.0.y), Float(matrix.columns.0.z)),
                            simd_float3(Float(matrix.columns.1.x), Float(matrix.columns.1.y), Float(matrix.columns.1.z)),
                            simd_float3(Float(matrix.columns.2.x), Float(matrix.columns.2.y), Float(matrix.columns.2.z))
                        )
                        inputDeviceOrientationWorld = simd_normalize(simd_quatf(rotationMatrix))
                    } else {
                        inputDevicePositionWorld = nil
                        inputDeviceOrientationWorld = nil
                    }

                    let phase: XRSpatialInteractionPhase
                    switch event.phase {
                    case .active:
                        phase = .changed
                    case .ended:
                        phase = .ended
                    case .cancelled:
                        phase = .cancelled
                    default:
                        phase = .began
                    }

                    let chirality: XRSpatialChirality?
                    if let eventChirality = event.chirality {
                        switch eventChirality {
                        case .left:
                            chirality = .left
                        case .right:
                            chirality = .right
                        @unknown default:
                            chirality = nil
                        }
                    } else {
                        chirality = nil
                    }

                    let snapshot = XRSpatialInputSnapshot(
                        interactionId: event.id.hashValue,
                        phase: phase,
                        intent: .automatic,
                        chirality: chirality,
                        rayOriginWorld: origin,
                        rayDirectionWorld: direction,
                        inputDevicePositionWorld: inputDevicePositionWorld,
                        inputDeviceOrientationWorld: inputDeviceOrientationWorld
                    )

                    InputSystem.shared.enqueueXRSpatialSnapshot(snapshot)
                }
            }
        }

        public func start() {
            if renderer == nil {
                return
            }
            lock.lock()
            _isRunning = true
            lock.unlock()
        }

        public func stop() {
            lock.lock()
            _isRunning = false
            lock.unlock()
        }

        public func runLoop() {
            while true {
                autoreleasepool {
                    lock.lock()
                    let running = _isRunning
                    lock.unlock()

                    if !running { return }

                    guard let layerRenderer else {
                        return
                    }

                    switch layerRenderer.state {
                    case .paused:
                        layerRenderer.waitUntilRunning()

                    case .running:
                        // Call the per-frame function here
                        renderNewFrame()

                    case .invalidated:
                        return

                    @unknown default:
                        return
                    }
                }
            }
        }

        // Performs exactly one frame of rendering
        private func renderNewFrame() {
            // 1. Call queryNextFrame() to fetch the next frame to use for drawing
            guard let layerRenderer else { return }

            guard let frame = layerRenderer.queryNextFrame() else { return }

            // 2. Call predictTiming to get the predicted render deadlines for code
            guard let timing = frame.predictTiming() else { return }

            // 3. Call startUpdate() to mark the start of the update phase
            frame.startUpdate()

            // Snapshot loading gate once per frame to keep update/submission behavior consistent.
            let loading = AssetLoadingGate.shared.isLoadingAny

            // 4. Update spatial input state from queued events
            updateSpatialInputState()

            // 5. Perform any rendering-related work that doesn't rely on the device anchor info
            guard let renderer else { return }
            if !loading {
                renderer.updateXR()
            }

            // 6. Call endupdate() to mark the end of the update phase
            frame.endUpdate()

            // 7. Call wait(until:tolerace) to puase your render loop until the optimal rendering time
            LayerRenderer.Clock().wait(until: timing.optimalInputTime, tolerance: .zero)

            // 8. Call startSubmission() to mark the start of submission phase
            frame.startSubmission()

            // 9. Encode any drawing commands that depend on the device position or orientation
            guard let drawable = frame.queryDrawable() else {
                frame.endSubmission()
                return
            }

            // 10. Fetch the predicted device anchor from ARKit using the frameTiming information, and
            // apply the anchor to your frame
            let presentationInstant = drawable.frameTiming.presentationTime
            let presentationTimeCA: TimeInterval = compositorInstantToCATime(presentationInstant)
            var deviceAnchor = queryDeviceAnchorIfTrackingRunning(atTimestamp: presentationTimeCA)

            // If predicted-time query misses, retry at "now" to reduce one-frame anchor gaps.
            if deviceAnchor == nil {
                let nowTimestamp = CACurrentMediaTime()
                if let retryAnchor = queryDeviceAnchorIfTrackingRunning(atTimestamp: nowTimestamp) {
                    deviceAnchor = retryAnchor
                }
            }

            // Use current anchor if valid, otherwise fall back to last valid anchor.
            // This prevents "Presenting a drawable without a device anchor" while maintaining
            // stable rendering. We must always present the drawable once we have it.
            if let anchor = deviceAnchor {
                lastValidDeviceAnchor = anchor
                drawable.deviceAnchor = anchor
            } else if let cachedAnchor = lastValidDeviceAnchor {
                drawable.deviceAnchor = cachedAnchor
            }
            // Note: If we have no cached anchor either, drawable.deviceAnchor remains nil
            // and the render loop will skip rendering but still present (required by compositor)

            // Re-check loading state right before render pass to catch any mutations that started
            // after our initial snapshot. This provides a second layer of protection against races.
            let loadingNow = AssetLoadingGate.shared.isLoadingAny
            let effectiveLoading = loading || loadingNow

            executeXRSystemPass(frame: frame, drawable: drawable, loading: effectiveLoading)

            // 13. Call endSubmission to mark the end of the GPU submission
            frame.endSubmission()
        }

        private let spatialInputEpsilon: Float = 0.0001
        private let dragTranslationThresholdMeters: Float = 0.01
        private let dragRotationThresholdRadians: Float = 0.08
        private let zoomActivationThresholdMeters: Float = 0.0005
        private let maxZoomDeltaPerFrame: Float = 0.08
        private let rotateActivationThresholdRadians: Float = 0.01
        private let maxRotateDeltaPerFrame: Float = 0.35
        private var interactionActive = false
        private var primaryInteractionId: Int?
        private var interactionExceededDragThreshold = false
        private var interactionInitialInputDevicePositionWorld: simd_float3?
        private var interactionLastInputDevicePositionWorld: simd_float3?
        private var interactionInitialRayDirectionWorld: simd_float3?
        private var interactionPickedEntity: EntityID?
        private var leftHandPositionValid = false
        private var rightHandPositionValid = false
        private var lastTwoHandPinchDistanceMeters: Float?
        private var lastTwoHandPinchVectorWorld: simd_float3?

        private func updateSpatialInputState() {
            let snapshots = InputSystem.shared.drainXRSpatialSnapshots()
            var state = InputSystem.shared.xrSpatialInputState

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

            for snapshot in snapshots {
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

                let pickedEntityFromSnapshot: EntityID?
                if let normalizedRayDirection,
                   let (pickedEntity, _) = pickEntity(rayOrigin: snapshot.rayOriginWorld, rayDirection: normalizedRayDirection)
                {
                    pickedEntityFromSnapshot = pickedEntity
                } else {
                    pickedEntityFromSnapshot = nil
                }

                switch snapshot.phase {
                case .began:
                    interactionActive = true
                    primaryInteractionId = snapshot.interactionId
                    interactionExceededDragThreshold = false
                    interactionInitialInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                    interactionLastInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                    interactionInitialRayDirectionWorld = normalizedRayDirection
                    interactionPickedEntity = pickedEntityFromSnapshot

                    state.spatialDragActive = false
                    state.spatialPinchDragDelta = .zero
                    state.pickedEntityId = pickedEntityFromSnapshot

                case .changed:
                    if !interactionActive {
                        interactionActive = true
                        primaryInteractionId = snapshot.interactionId
                        interactionExceededDragThreshold = false
                        interactionInitialInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                        interactionLastInputDevicePositionWorld = snapshot.inputDevicePositionWorld
                        interactionInitialRayDirectionWorld = normalizedRayDirection
                        interactionPickedEntity = nil
                        state.pickedEntityId = nil
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

                    if translationDelta >= dragTranslationThresholdMeters || rotationDelta >= dragRotationThresholdRadians {
                        interactionExceededDragThreshold = true
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

        private func resetAllSpatialInteractionTracking() {
            resetSpatialInteractionTracking()
            leftHandPositionValid = false
            rightHandPositionValid = false
            lastTwoHandPinchDistanceMeters = nil
            lastTwoHandPinchVectorWorld = nil
        }

        private func resetSpatialInteractionTracking() {
            interactionActive = false
            primaryInteractionId = nil
            interactionExceededDragThreshold = false
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

        func executeXRSystemPass(frame _: LayerRenderer.Frame, drawable: LayerRenderer.Drawable, loading: Bool) {
            // Wait for available command buffer slot to prevent unbounded memory growth
            commandBufferSemaphore.wait()

            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
                // Failed to create command buffer - release semaphore
                commandBufferSemaphore.signal()
                return
            }

            // Update viewport to match actual drawable size (per-eye texture dimensions)
            if let firstColorTexture = drawable.colorTextures.first {
                let actualViewPort = simd_float2(Float(firstColorTexture.width), Float(firstColorTexture.height))
                if renderInfo.viewPort != actualViewPort {
                    renderInfo.viewPort = actualViewPort
                    renderer!.initSizeableResources()
                    print("✓ Updated VisionOS viewport to: \(actualViewPort)")
                }
            }

            // Update visible entity list only when not loading (avoids reading mutating ECS data).
            // When loading, we render from the last-known-good visible list.
            if !loading {
                visibleEntityIds = tripleVisibleEntities.snapshotForRead(frame: cullFrameIndex)
            }

            // Skip render prep (culling, gaussian, bitonic) while loading.
            // The render graph still executes using the stale visibleEntityIds.
            if !loading {
                EngineProfiler.shared.beginScope(.renderPrep)
                performFrustumCulling(commandBuffer: commandBuffer)
                executeGaussianDepth(commandBuffer)
                executeBitonicSort(commandBuffer)
                EngineProfiler.shared.endScope(.renderPrep)
            }

            for (viewIndex, view) in drawable.views.enumerated() {
                let anchor = drawable.deviceAnchor
                guard let originFromDevice: simd_float4x4 = anchor?.originFromAnchorTransform else {
                    continue
                }

                let deviceFromView: simd_float4x4 = view.transform
                var cameraMatrix: simd_float4x4 = matrix_multiply(originFromDevice, deviceFromView)

                cameraMatrix = simd_inverse(cameraMatrix)

                let projection: simd_float4x4 = drawable.computeProjection(convention: .rightUpForward, viewIndex: viewIndex)

                // Reuse pre-allocated pass descriptor to avoid allocation churn
                let passDescriptor = viewIndex == 0 ? passDescriptorLeft : passDescriptorRight
                passDescriptor.colorAttachments[0].texture = drawable.colorTextures[viewIndex]
                passDescriptor.colorAttachments[0].storeAction = .store
                passDescriptor.colorAttachments[0].loadAction = .clear

                passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: Double(getAlphaForImmersionMode()))

                passDescriptor.depthAttachment.texture = drawable.depthTextures[viewIndex]
                passDescriptor.depthAttachment.loadAction = .clear
                passDescriptor.depthAttachment.storeAction = .store
                passDescriptor.depthAttachment.clearDepth = 1.0

                // call the visionXR render graph
                guard let renderer else {
                    // Early return - signal semaphore
                    commandBufferSemaphore.signal()
                    return
                }

                renderInfo.currentEye = viewIndex
                EngineProfiler.shared.beginScope(.encode)
                renderer.renderXR(commandBuffer: commandBuffer, passDescriptor: passDescriptor, viewMatrix: cameraMatrix, projectionMatrix: projection, eyeIndex: viewIndex)
                EngineProfiler.shared.endScope(.encode)
            }

            drawable.encodePresent(commandBuffer: commandBuffer)

            EngineProfiler.shared.attach(to: commandBuffer, label: "XRFrame")

            // Add completion handler to signal semaphore when GPU work is done
            commandBuffer.addCompletedHandler { _ in
                commandBufferSemaphore.signal()
            }

            commandBuffer.commit()
        }

        private func queryDeviceAnchorIfTrackingRunning(atTimestamp timestamp: TimeInterval) -> DeviceAnchor? {
            #if canImport(ARKit)
                guard worldTracking.state == .running else {
                    scheduleWorldTrackingRecoveryIfNeeded()
                    return nil
                }
                return worldTracking.queryDeviceAnchor(atTimestamp: timestamp)
            #else
                _ = timestamp
                return nil
            #endif
        }

        private func scheduleWorldTrackingRecoveryIfNeeded() {
            #if canImport(ARKit)
                let now = CACurrentMediaTime()
                guard now - lastWorldTrackingRecoveryAttemptTime >= worldTrackingRecoveryCooldownSeconds else {
                    return
                }

                lastWorldTrackingRecoveryAttemptTime = now

                let worldTracking = worldTracking
                let arSession = arSession

                Task {
                    do {
                        guard worldTracking.state != .running else { return }
                        try await arSession.run([worldTracking])
                        print("✓ XR world tracking restarted")
                    } catch {
                        print("⚠️ XR world tracking recovery failed: \(error)")
                    }
                }
            #endif
        }

        func createPoseForTiming(at timing: LayerRenderer.Frame.Timing) -> DeviceAnchor? {
            guard worldTracking.state == .running else {
                return nil
            }

            // Convert compositor time -> Core Animation time
            let caTimestamp = compositorInstantToCATime(timing.presentationTime)

            // Query ARKit for the predicted device anchor pose
            return worldTracking.queryDeviceAnchor(atTimestamp: caTimestamp)
        }

        @inline(__always)
        private func compositorInstantToCATime(_ instant: LayerRenderer.Clock.Instant) -> TimeInterval {
            let compositorClock = LayerRenderer.Clock()
            let nowInstant = compositorClock.now
            let nowCA = CACurrentMediaTime()

            // Compute duration between now and the target instant
            let duration: Duration = nowInstant.duration(to: instant)

            // Convert Duration → seconds
            let components = duration.components
            let seconds = Double(components.seconds) + Double(components.attoseconds) / 1e18

            return nowCA + seconds
        }

        public func setImmersionMode(xrImmersionMode: UntoldImmersionMode) {
            switch xrImmersionMode {
            case .full:
                renderInfo.immersionStyle = .full
            case .mixed:
                renderInfo.immersionStyle = .mixed
            default:
                break
            }
        }
    }

#endif
