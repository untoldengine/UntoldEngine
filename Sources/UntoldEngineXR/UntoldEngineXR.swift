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

    enum XRLayerState { case paused, running, invalidated }

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

        private func startWorldTrackingIfNeeded() async throws {
            guard worldTracking.state != .running else { return }
            try await arSession.run([worldTracking])
        }

        public init?(layerRenderer: LayerRenderer, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
            guard let device, let commandQueue = device.makeCommandQueue() else { return nil }

            self.layerRenderer = layerRenderer

            initUntoldXR(device: device, commandQueue: commandQueue, layerRenderer: layerRenderer)
        }

        public func initUntoldXR(device: MTLDevice, commandQueue: MTLCommandQueue, layerRenderer: LayerRenderer) {
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
            /* TODO: */

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
