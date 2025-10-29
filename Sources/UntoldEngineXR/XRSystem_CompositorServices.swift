//
//  XRSystem_CompositorServices.swift
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
    #endif

    enum XRLayerState { case paused, running, invalidated }

    public final class CompositorXRSystem: XRSystem {
        private var renderer: UntoldRenderer?
        private var _isRunning = false
        private let lock = NSLock()

        private let layerRenderer: LayerRenderer?

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
            Task {
                do {
                    try await startWorldTrackingIfNeeded()
                } catch {
                    print("⚠️ Failed to start world tracking: \(error)")
                }
            }

            let configuration = layerRenderer.configuration
            _ = configuration.layout

            let colorPixelFormat = configuration.colorFormat
            let depthPixelFormat = configuration.depthFormat

            // **VERIFY THIS** Need to verify this. Couldn't find any info
            let viewPort = simd_float2(1024, 1024)

            guard let untoldrenderer = UntoldRenderer.createXR(configuration: nil, device: device, commandQueue: commandQueue, colorPixelFormat: colorPixelFormat, depthPixelFormat: depthPixelFormat, viewPort: viewPort) else {
                print("Failed to initialize the renderer")
                return
            }

            renderer = untoldrenderer
        }

        public func start() {
            if renderer == nil {
                return
            }
            lock.lock()
            _isRunning = true
            lock.unlock()
        }

        public func stop() {}

        public func runLoop() {
            while true {
                lock.lock()
                let running = _isRunning
                lock.unlock()

                if !running { break }

                guard let layerRenderer else {
                    break
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

        // Performs exactly one frame of rendering
        private func renderNewFrame() {
            // 1. Call queryNextFrame() to fetch the next frame to use for drawing
            guard let layerRenderer else { return }

            guard let frame = layerRenderer.queryNextFrame() else { return }

            // 2. Call predictTiming to get the predicted render deadlines for code
            guard let timing = frame.predictTiming() else { return }

            // 3. Call startUpdate() to mark the start of the update phase
            frame.startUpdate()

            // 4. Apply user interactions to the content and update any app-spefic data
            /* TODO: */

            // 5. Perform any rendering-related work that doesn't rely on the device anchor info
            guard let renderer else { return }
            renderer.updateXR()

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
            let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: presentationTimeCA)
            drawable.deviceAnchor = deviceAnchor

            executeXRSystemPass(frame: frame, drawable: drawable)

            // 13. Call endSubmission to mark the end of the GPU submission
            frame.endSubmission()
        }

        func executeXRSystemPass(frame _: LayerRenderer.Frame, drawable: LayerRenderer.Drawable) {
            let commandBuffer: MTLCommandBuffer = renderInfo.commandQueue.makeCommandBuffer()!

            for (viewIndex, view) in drawable.views.enumerated() {
                let anchor = drawable.deviceAnchor
                guard let originFromDevice: simd_float4x4 = anchor?.originFromAnchorTransform else {
                    continue
                }

                let deviceFromView: simd_float4x4 = view.transform
                var cameraMatrix: simd_float4x4 = matrix_multiply(originFromDevice, deviceFromView)

                cameraMatrix = simd_inverse(cameraMatrix)

                let projection: simd_float4x4 = drawable.computeProjection(convention: .rightUpForward, viewIndex: viewIndex)

                // create a pass descriptor
                let passDescriptor = MTLRenderPassDescriptor()
                passDescriptor.colorAttachments[0].texture = drawable.colorTextures[viewIndex]
                passDescriptor.colorAttachments[0].storeAction = .store
                passDescriptor.colorAttachments[0].loadAction = .clear
                passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

                passDescriptor.depthAttachment.texture = drawable.depthTextures[viewIndex]
                passDescriptor.depthAttachment.loadAction = .clear
                passDescriptor.depthAttachment.storeAction = .store
                passDescriptor.depthAttachment.clearDepth = 1.0

                // call the visionXR render graph
                guard let renderer else { return }

                renderInfo.currentEye = viewIndex
                renderer.renderXR(commandBuffer: commandBuffer, passDescriptor: passDescriptor, viewMatrix: cameraMatrix, projectionMatrix: projection, eyeIndex: viewIndex)
            }

            drawable.encodePresent(commandBuffer: commandBuffer)

            commandBuffer.commit()
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
    }

#endif
