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

    private struct XRSpatialTranslationSession {
        var entityId: EntityID
        var planePoint: simd_float3
        var planeNormal: simd_float3
        var grabOffset: simd_float3
        var initialEntityWorldPosition: simd_float3
        var initialInputDevicePositionWorld: simd_float3?
    }

    private struct XRSpatialRotationSession {
        var entityId: EntityID
        var initialRotation: simd_quatf
        var initialRayDirectionProjected: simd_float3?
        var initialInputDeviceForwardProjected: simd_float3?
        var rotationAxisWorld: simd_float3
    }

    private struct XRSpatialPendingSession {
        var entityId: EntityID
        var translation: XRSpatialTranslationSession
        var rotation: XRSpatialRotationSession
    }

    private enum XRSpatialManipulationSession {
        case none
        case pending(XRSpatialPendingSession)
        case translating(XRSpatialTranslationSession)
        case rotating(XRSpatialRotationSession)
    }

    public final class UntoldEngineXR {
        private var renderer: UntoldRenderer?
        private var _isRunning = false
        private let lock = NSLock()
        private var spatialManipulationSession: XRSpatialManipulationSession = .none
        private let spatialInputEpsilon: Float = 0.0001
        private let spatialIntentTranslationThresholdMeters: Float = 0.01
        private let spatialIntentRotationThresholdRadians: Float = 0.08
        private let spatialIntentDominanceRatio: Float = 1.15
        public var spatialInteractionDebugLogging = false
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
            spatialManipulationSession = .none
        }

        private func configureSpatialEventBridge() {
            guard let layerRenderer else { return }

            layerRenderer.onSpatialEvent = { events in
                guard InputSystem.shared.xrEventsEnabled else { return }

                for event in events {
                    guard let selectionRay = event.selectionRay else { continue }

                    let origin = simd_float3(
                        Float(selectionRay.origin.x),
                        Float(selectionRay.origin.y),
                        Float(selectionRay.origin.z)
                    )

                    let direction = simd_float3(
                        Float(selectionRay.direction.x),
                        Float(selectionRay.direction.y),
                        Float(selectionRay.direction.z)
                    )

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

                    let snapshot = XRSpatialInputSnapshot(
                        phase: phase,
                        intent: .automatic,
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

            // 4. Apply user interactions to the content and update any app-spefic data
            applySpatialManipulationStep()

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

        private func applySpatialManipulationStep() {
            let snapshots = InputSystem.shared.drainXRSpatialSnapshots()
            guard !snapshots.isEmpty else { return }

            for snapshot in snapshots {
                switch snapshot.phase {
                case .began:
                    beginSpatialManipulation(snapshot)
                case .changed:
                    // Some visionOS streams emit active/changed without explicit began.
                    // Bootstrap manipulation from first changed event.
                    if case .none = spatialManipulationSession {
                        beginSpatialManipulation(snapshot)
                    }
                    updateSpatialManipulation(snapshot)
                case .ended, .cancelled:
                    endSpatialManipulation()
                }
            }
        }

        private func beginSpatialManipulation(_ snapshot: XRSpatialInputSnapshot) {
            let rayDirectionRaw = snapshot.rayDirectionWorld
            let rayLengthSquared = simd_length_squared(rayDirectionRaw)
            guard rayLengthSquared.isFinite, rayLengthSquared > spatialInputEpsilon else { return }
            let rayDirection = rayDirectionRaw / sqrt(rayLengthSquared)

            guard let (pickedEntity, hitDistance) = pickEntity(rayOrigin: snapshot.rayOriginWorld, rayDirection: rayDirection) else {
                endSpatialManipulation()
                return
            }

            activeEntity = pickedEntity

            let translationSession = makeTranslationSession(
                snapshot: snapshot,
                pickedEntity: pickedEntity,
                hitDistance: hitDistance,
                rayDirection: rayDirection
            )

            let rotationSession = makeRotationSession(
                snapshot: snapshot,
                pickedEntity: pickedEntity,
                rayDirection: rayDirection
            )

            switch snapshot.intent {
            case .automatic:
                if let rotationSession {
                    spatialManipulationSession = .pending(.init(
                        entityId: pickedEntity,
                        translation: translationSession,
                        rotation: rotationSession
                    ))
                } else {
                    spatialManipulationSession = .translating(translationSession)
                }

            case .translate:
                spatialManipulationSession = .translating(translationSession)

            case .rotate:
                guard let rotationSession else {
                    endSpatialManipulation()
                    return
                }
                spatialManipulationSession = .rotating(rotationSession)
            }
        }

        private func makeTranslationSession(
            snapshot: XRSpatialInputSnapshot,
            pickedEntity: EntityID,
            hitDistance: Float,
            rayDirection: simd_float3
        ) -> XRSpatialTranslationSession {
            let hitPoint = snapshot.rayOriginWorld + rayDirection * hitDistance
            let entityPosition = getPosition(entityId: pickedEntity)
            let planeNormal = -rayDirection
            let grabOffset = entityPosition - hitPoint

            return .init(
                entityId: pickedEntity,
                planePoint: hitPoint,
                planeNormal: planeNormal,
                grabOffset: grabOffset,
                initialEntityWorldPosition: entityPosition,
                initialInputDevicePositionWorld: snapshot.inputDevicePositionWorld
            )
        }

        private func makeRotationSession(
            snapshot: XRSpatialInputSnapshot,
            pickedEntity: EntityID,
            rayDirection: simd_float3
        ) -> XRSpatialRotationSession? {
            guard let localTransform = scene.get(component: LocalTransformComponent.self, for: pickedEntity) else {
                return nil
            }

            let axis = simd_float3(0, 1, 0)
            let projectedRay = projectDirectionOntoPlane(rayDirection, planeNormal: axis)

            let projectedInputForward: simd_float3?
            if let inputOrientation = snapshot.inputDeviceOrientationWorld {
                let forward = simd_act(inputOrientation, simd_float3(0, 0, -1))
                projectedInputForward = projectDirectionOntoPlane(forward, planeNormal: axis)
            } else {
                projectedInputForward = nil
            }

            guard projectedRay != nil || projectedInputForward != nil else {
                return nil
            }

            return .init(
                entityId: pickedEntity,
                initialRotation: localTransform.rotation,
                initialRayDirectionProjected: projectedRay,
                initialInputDeviceForwardProjected: projectedInputForward,
                rotationAxisWorld: axis
            )
        }

        private func updateSpatialManipulation(_ snapshot: XRSpatialInputSnapshot) {
            let rayDirectionRaw = snapshot.rayDirectionWorld
            let rayLengthSquared = simd_length_squared(rayDirectionRaw)
            guard rayLengthSquared.isFinite, rayLengthSquared > spatialInputEpsilon else { return }
            let rayDirection = rayDirectionRaw / sqrt(rayLengthSquared)

            switch spatialManipulationSession {
            case let .pending(pending):
                guard scene.mask(for: pending.entityId) != nil else {
                    endSpatialManipulation()
                    return
                }

                let translationMagnitude: Float
                if let initialInputDevicePosition = pending.translation.initialInputDevicePositionWorld,
                   let currentInputDevicePosition = snapshot.inputDevicePositionWorld
                {
                    translationMagnitude = simd_length(currentInputDevicePosition - initialInputDevicePosition)
                } else {
                    translationMagnitude = 0
                }

                let rotationMagnitude: Float
                if let initialInputForward = pending.rotation.initialInputDeviceForwardProjected,
                   let currentInputOrientation = snapshot.inputDeviceOrientationWorld
                {
                    let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                    if let currentInputForwardProjected = projectDirectionOntoPlane(currentForward, planeNormal: pending.rotation.rotationAxisWorld) {
                        rotationMagnitude = abs(signedAngleAroundAxis(
                            from: initialInputForward,
                            to: currentInputForwardProjected,
                            axis: pending.rotation.rotationAxisWorld
                        ))
                    } else {
                        rotationMagnitude = 0
                    }
                } else if let initialRayProjected = pending.rotation.initialRayDirectionProjected,
                          let currentRayProjected = projectDirectionOntoPlane(rayDirection, planeNormal: pending.rotation.rotationAxisWorld)
                {
                    rotationMagnitude = abs(signedAngleAroundAxis(
                        from: initialRayProjected,
                        to: currentRayProjected,
                        axis: pending.rotation.rotationAxisWorld
                    ))
                } else {
                    rotationMagnitude = 0
                }

                let translationReady = translationMagnitude >= spatialIntentTranslationThresholdMeters
                let rotationReady = rotationMagnitude >= spatialIntentRotationThresholdRadians

                guard translationReady || rotationReady else { return }

                let translationScore = translationMagnitude / max(spatialIntentTranslationThresholdMeters, spatialInputEpsilon)
                let rotationScore = rotationMagnitude / max(spatialIntentRotationThresholdRadians, spatialInputEpsilon)

                if translationReady, !rotationReady {
                    spatialManipulationSession = .translating(pending.translation)
                } else if rotationReady, !translationReady {
                    spatialManipulationSession = .rotating(pending.rotation)
                } else if translationScore >= rotationScore * spatialIntentDominanceRatio {
                    spatialManipulationSession = .translating(pending.translation)
                } else if rotationScore >= translationScore * spatialIntentDominanceRatio {
                    spatialManipulationSession = .rotating(pending.rotation)
                } else {
                    spatialManipulationSession = translationScore >= rotationScore
                        ? .translating(pending.translation)
                        : .rotating(pending.rotation)
                }

                // Apply immediately once intent is auto-locked.
                switch spatialManipulationSession {
                case let .translating(translation):
                    applySpatialTranslation(snapshot, rayDirection: rayDirection, translation: translation)
                case let .rotating(rotation):
                    applySpatialRotation(snapshot, rayDirection: rayDirection, rotation: rotation)
                default:
                    break
                }

            case let .translating(translation):
                applySpatialTranslation(snapshot, rayDirection: rayDirection, translation: translation)

            case let .rotating(rotation):
                applySpatialRotation(snapshot, rayDirection: rayDirection, rotation: rotation)

            case .none:
                break
            }
        }

        private func applySpatialTranslation(
            _ snapshot: XRSpatialInputSnapshot,
            rayDirection: simd_float3,
            translation: XRSpatialTranslationSession
        ) {
            guard scene.mask(for: translation.entityId) != nil else {
                endSpatialManipulation()
                return
            }

            // Preferred path: pose delta drag. selectionRay can remain static across active events.
            if let initialInputDevicePosition = translation.initialInputDevicePositionWorld,
               let currentInputDevicePosition = snapshot.inputDevicePositionWorld
            {
                let inputDeviceDelta = currentInputDevicePosition - initialInputDevicePosition
                if simd_length_squared(inputDeviceDelta) > (spatialInputEpsilon * spatialInputEpsilon) {
                    let targetWorldPosition = translation.initialEntityWorldPosition + inputDeviceDelta
                    let targetLocalPosition = worldPositionToLocal(
                        entityId: translation.entityId,
                        worldPosition: targetWorldPosition
                    )
                    translateTo(entityId: translation.entityId, position: targetLocalPosition)
                    return
                }
            }

            guard let hitPoint = rayPlaneIntersection(
                rayOrigin: snapshot.rayOriginWorld,
                rayDirection: rayDirection,
                planePoint: translation.planePoint,
                planeNormal: translation.planeNormal
            ) else {
                return
            }

            let targetWorldPosition = hitPoint + translation.grabOffset
            let targetLocalPosition = worldPositionToLocal(
                entityId: translation.entityId,
                worldPosition: targetWorldPosition
            )
            translateTo(entityId: translation.entityId, position: targetLocalPosition)
        }

        private func applySpatialRotation(
            _ snapshot: XRSpatialInputSnapshot,
            rayDirection: simd_float3,
            rotation: XRSpatialRotationSession
        ) {
            guard scene.mask(for: rotation.entityId) != nil else {
                endSpatialManipulation()
                return
            }

            // Preferred path: pose orientation delta for robust pinch-rotate behavior.
            if let initialInputForward = rotation.initialInputDeviceForwardProjected,
               let currentInputOrientation = snapshot.inputDeviceOrientationWorld
            {
                let currentForward = simd_act(currentInputOrientation, simd_float3(0, 0, -1))
                if let currentInputForwardProjected = projectDirectionOntoPlane(currentForward, planeNormal: rotation.rotationAxisWorld) {
                    let signedAngle = signedAngleAroundAxis(
                        from: initialInputForward,
                        to: currentInputForwardProjected,
                        axis: rotation.rotationAxisWorld
                    )

                    let deltaRotation = simd_quatf(angle: signedAngle, axis: rotation.rotationAxisWorld)
                    let targetRotation = simd_normalize(simd_mul(deltaRotation, rotation.initialRotation))
                    rotateTo(entityId: rotation.entityId, rotation: getMatrix4x4FromQuaternion(q: targetRotation))
                    return
                }
            }

            // Fallback path: ray direction projection.
            guard let initialRayProjected = rotation.initialRayDirectionProjected,
                  let currentRayProjected = projectDirectionOntoPlane(rayDirection, planeNormal: rotation.rotationAxisWorld)
            else {
                return
            }

            let signedAngle = signedAngleAroundAxis(
                from: initialRayProjected,
                to: currentRayProjected,
                axis: rotation.rotationAxisWorld
            )

            let deltaRotation = simd_quatf(angle: signedAngle, axis: rotation.rotationAxisWorld)
            let targetRotation = simd_normalize(simd_mul(deltaRotation, rotation.initialRotation))
            rotateTo(entityId: rotation.entityId, rotation: getMatrix4x4FromQuaternion(q: targetRotation))
        }

        private func endSpatialManipulation() {
            spatialManipulationSession = .none
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
