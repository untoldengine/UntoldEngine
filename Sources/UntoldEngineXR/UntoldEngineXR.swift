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
        private var missingAnchorFrameCount: Int = 0
        private var lastAnchorDiagnosticsLogTime: CFTimeInterval = 0
        private let anchorDiagnosticsLogIntervalSeconds: CFTimeInterval = 1.0

        // Reuse render pass descriptors to avoid allocation churn (2 eyes × 90 FPS = 180 allocs/sec)
        private let passDescriptorLeft = MTLRenderPassDescriptor()
        private let passDescriptorRight = MTLRenderPassDescriptor()
        private let spatialGestureRecognizer = XRSpatialGestureRecognizer()

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
                guard isSceneReady() else { return }
                guard AssetLoadingGate.shared.isLoadingAny == false else { return }

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
            #if ENGINE_STATS_ENABLED
                let xrFrameStartTime = CACurrentMediaTime()
                EngineStatsMonitor.shared.beginFrame(timestampSeconds: xrFrameStartTime)
                RenderStatsCollector.shared.reset()
            #endif

            // Snapshot loading gate once per frame to keep update/submission behavior consistent.
            let loading = AssetLoadingGate.shared.isLoadingAny
            let sceneReady = isSceneReady()
            let allowSpatialInputProcessing = !loading && sceneReady

            // 4. Update spatial input state from queued events
            if allowSpatialInputProcessing {
                updateSpatialInputState()
            } else {
                clearSpatialInput()
            }

            // 5. Perform any rendering-related work that doesn't rely on the device anchor info
            guard let renderer else { return }
            if !loading {
                _ = renderer.updateXR(useExternalStatsLifecycle: true)
            }

            // 6. Call endupdate() to mark the end of the update phase
            frame.endUpdate()

            // 7. Call wait(until:tolerace) to puase your render loop until the optimal rendering time
            LayerRenderer.Clock().wait(until: timing.optimalInputTime, tolerance: .zero)

            // 8. Call startSubmission() to mark the start of submission phase
            frame.startSubmission()

            // 9. Encode any drawing commands that depend on the device position or orientation
            guard let drawable = frame.queryDrawable() else {
                #if ENGINE_STATS_ENABLED
                    renderer.finalizeXRStatsAndMonitors(frameStartTime: xrFrameStartTime)
                #else
                    renderer.finalizeXRStatsAndMonitors(frameStartTime: 0.0)
                #endif
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
                if missingAnchorFrameCount > 0 {
                    print("✓ XR device anchor recovered after \(missingAnchorFrameCount) missing frame(s)")
                }
                missingAnchorFrameCount = 0
                lastValidDeviceAnchor = anchor
                drawable.deviceAnchor = anchor
            } else if let cachedAnchor = lastValidDeviceAnchor {
                missingAnchorFrameCount += 1
                if shouldLogAnchorDiagnostics() {
                    print("⚠️ XR device anchor missing for \(missingAnchorFrameCount) frame(s); using cached anchor")
                }
                drawable.deviceAnchor = cachedAnchor
            } else {
                missingAnchorFrameCount += 1
                if shouldLogAnchorDiagnostics() {
                    print("⚠️ XR device anchor missing for \(missingAnchorFrameCount) frame(s); no cached anchor available")
                }
            }
            // Note: If we have no cached anchor either, drawable.deviceAnchor remains nil
            // and the render loop will skip rendering but still present (required by compositor)

            // Re-check loading state right before render pass to catch any mutations that started
            // after our initial snapshot. This provides a second layer of protection against races.
            let loadingNow = AssetLoadingGate.shared.isLoadingAny
            let effectiveLoading = loading || loadingNow

            executeXRSystemPass(frame: frame, drawable: drawable, loading: effectiveLoading)
            #if ENGINE_STATS_ENABLED
                renderer.finalizeXRStatsAndMonitors(frameStartTime: xrFrameStartTime)
            #else
                renderer.finalizeXRStatsAndMonitors(frameStartTime: 0.0)
            #endif

            // 13. Call endSubmission to mark the end of the GPU submission
            frame.endSubmission()
        }

        private func updateSpatialInputState() {
            spatialGestureRecognizer.updateSpatialInputState()
        }

        private func resetAllSpatialInteractionTracking() {
            spatialGestureRecognizer.resetAllSpatialInteractionTracking()
        }

        func executeXRSystemPass(frame _: LayerRenderer.Frame, drawable: LayerRenderer.Drawable, loading: Bool) {
            // Wait for available command buffer slot to prevent unbounded memory growth
            commandBufferSemaphore.wait()

            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
                // Failed to create command buffer - release semaphore
                commandBufferSemaphore.signal()
                return
            }
            #if ENGINE_STATS_ENABLED
                let renderTotalStart = CACurrentMediaTime()
            #endif
            renderInfo.currentInFlightFrameSlot = acquireUniformFrameSlot()

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
                SceneRootTransform.shared.updateIfNeeded()
                #if ENGINE_STATS_ENABLED
                    let renderPrepStart = CACurrentMediaTime()
                    let cullingStart = CACurrentMediaTime()
                #endif
                EngineProfiler.shared.beginScope(.renderPrep)
                performFrustumCulling(commandBuffer: commandBuffer)
                #if ENGINE_STATS_ENABLED
                    let cullingMs = (CACurrentMediaTime() - cullingStart) * 1000.0
                    EngineStatsMonitor.shared.update { snapshot in
                        snapshot.timing.cullingMs += cullingMs
                    }
                #endif
                executeGaussianDepth(commandBuffer)
                executeBitonicSort(commandBuffer)
                EngineProfiler.shared.endScope(.renderPrep)
                #if ENGINE_STATS_ENABLED
                    let renderPrepMs = (CACurrentMediaTime() - renderPrepStart) * 1000.0
                    EngineStatsMonitor.shared.update { snapshot in
                        snapshot.timing.renderPrepMs += renderPrepMs
                    }
                #endif
            }

            for (viewIndex, view) in drawable.views.enumerated() {
                let anchor = drawable.deviceAnchor
                let originFromDevice = anchor?.originFromAnchorTransform
                guard let originFromDevice else {
                    continue
                }

                let deviceFromView: simd_float4x4 = view.transform
                var cameraMatrix: simd_float4x4 = matrix_multiply(originFromDevice, deviceFromView)

                cameraMatrix = simd_inverse(cameraMatrix)

                let projection: simd_float4x4 = drawable.computeProjection(convention: .rightUpBack, viewIndex: viewIndex)

                // Reuse pre-allocated pass descriptor to avoid allocation churn
                let passDescriptor = viewIndex == 0 ? passDescriptorLeft : passDescriptorRight
                passDescriptor.colorAttachments[0].texture = drawable.colorTextures[viewIndex]
                passDescriptor.colorAttachments[0].storeAction = .store
                passDescriptor.colorAttachments[0].loadAction = .clear

                passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: Double(getAlphaForImmersionMode()))

                passDescriptor.depthAttachment.texture = drawable.depthTextures[viewIndex]
                passDescriptor.depthAttachment.loadAction = .clear
                passDescriptor.depthAttachment.storeAction = .store
                passDescriptor.depthAttachment.clearDepth = 0.0

                // call the visionXR render graph
                guard let renderer else {
                    // Early return - signal semaphore
                    commandBufferSemaphore.signal()
                    return
                }

                renderInfo.currentEye = viewIndex

                #if ENGINE_STATS_ENABLED
                    let encodeStart = CACurrentMediaTime()
                #endif
                EngineProfiler.shared.beginScope(.encode)
                renderer.renderXR(commandBuffer: commandBuffer, passDescriptor: passDescriptor, viewMatrix: cameraMatrix, projectionMatrix: projection, eyeIndex: viewIndex)
                EngineProfiler.shared.endScope(.encode)
                #if ENGINE_STATS_ENABLED
                    let encodeMs = (CACurrentMediaTime() - encodeStart) * 1000.0
                    EngineStatsMonitor.shared.update { snapshot in
                        snapshot.timing.encodeMs += encodeMs
                    }
                #endif
            }

            // Temporal HZB schedule for stereo:
            // run once after both eyes are rendered so next frame culling can consume it.
            buildHZBDepthPyramid(commandBuffer)

            drawable.encodePresent(commandBuffer: commandBuffer)

            EngineProfiler.shared.attach(to: commandBuffer, label: "XRFrame")

            // Add completion handler to signal semaphore when GPU work is done
            commandBuffer.addCompletedHandler { cb in
                #if ENGINE_STATS_ENABLED
                    let gpuExecutionMs = (cb.gpuEndTime - cb.gpuStartTime) * 1000.0
                    EngineStatsMonitor.shared.recordGPUCompletion(executionMs: gpuExecutionMs)
                #endif
                commandBufferSemaphore.signal()
            }

            #if ENGINE_STATS_ENABLED
                let submitStart = CACurrentMediaTime()
            #endif
            commandBuffer.commit()
            #if ENGINE_STATS_ENABLED
                let submitMs = (CACurrentMediaTime() - submitStart) * 1000.0
                let renderTotalMs = (CACurrentMediaTime() - renderTotalStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.submitMs += submitMs
                    snapshot.timing.renderTotalMs += renderTotalMs
                }
            #endif
        }

        private func shouldLogAnchorDiagnostics() -> Bool {
            let now = CACurrentMediaTime()
            guard now - lastAnchorDiagnosticsLogTime >= anchorDiagnosticsLogIntervalSeconds else {
                return false
            }

            lastAnchorDiagnosticsLogTime = now
            return true
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
