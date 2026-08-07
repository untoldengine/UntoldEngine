//
//  UntoldEngineXR.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(visionOS)
    import CompositorServices
    import Foundation
    import Metal
    import UntoldEngine
    #if canImport(ARKit)
        import ARKit
        import SwiftUI
    #endif

    public enum UntoldImmersionMode {
        case none
        case mixed
        case full
    }

    public final class UntoldEngineXR: @unchecked Sendable {
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
        private var arKitProviderRunAttemptCount: Int = 0
        private let arKitProviderRunLock = NSLock()
        private var arKitProviderRunInProgress = false
        private var pendingARKitProviderRunReason: String?
        private var lastARKitProviderRunFailureTime: CFTimeInterval = -.infinity
        private let arKitProviderFailureCooldownSeconds: CFTimeInterval = 2.0
        private var lastXRStallDiagnosticsLogTime: CFTimeInterval = 0
        private let xrStallDiagnosticsLogIntervalSeconds: CFTimeInterval = 1.0

        // Reuse render pass descriptors to avoid allocation churn (2 eyes × 90 FPS = 180 allocs/sec)
        private let passDescriptorLeft = MTLRenderPassDescriptor()
        private let passDescriptorRight = MTLRenderPassDescriptor()
        private let spatialGestureRecognizer = XRSpatialGestureRecognizer()
        private let xrEnvironmentLightingSystem = XREnvironmentLightingSystem()
        private var runtimeLightingModeObserverId: UUID?
        private var psvr2TrackingObserver: NSObjectProtocol?

        /// Task handle for the plane-update monitor so we can cancel it on shutdown.
        private var planeMonitorTask: Task<Void, Never>?

        /// Task handle for the ARKitSession event monitor (provider state changes,
        /// authorization changes) so we can cancel it on shutdown.
        private var sessionEventMonitorTask: Task<Void, Never>?

        #if canImport(ARKit)
            private let arSession = ARKitSession()
            // ARKit data providers are one-shot: an instance that has been passed to
            // arSession.run can never be run again, so runARKitProvidersOnce swaps in
            // freshly created instances (guarded by arKitProviderRunLock) on every run.
            private var worldTracking = WorldTrackingProvider()
            private var planeDetection = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
        #else
            private let arSession: Any? = nil
            private let worldTracking: WorldTrackingProvider? = nil
        #endif

        @MainActor
        public init?(layerRenderer: LayerRenderer, device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
            guard let device, let commandQueue = device.makeCommandQueue() else { return nil }

            self.layerRenderer = layerRenderer

            initUntoldXR(device: device, commandQueue: commandQueue, layerRenderer: layerRenderer)
        }

        deinit {
            if let runtimeLightingModeObserverId {
                RuntimeEnvironmentLightingStore.shared.removeLightingModeChangeObserver(runtimeLightingModeObserverId)
            }
            if let psvr2TrackingObserver {
                NotificationCenter.default.removeObserver(psvr2TrackingObserver)
            }
        }

        @MainActor
        public func initUntoldXR(device: MTLDevice, commandQueue: MTLCommandQueue, layerRenderer: LayerRenderer) {
            configureSpatialEventBridge()
            configurePSVR2TrackingObserver()
            registerRuntimeLightingModeObserverIfNeeded()
            applyXRLightingMode(RuntimeEnvironmentLightingStore.shared.mode)
            startSessionEventMonitor()

            // The plane monitor is wired up inside runARKitProvidersOnce, since it
            // must follow the fresh PlaneDetectionProvider created for each run.
            startARKitProviders(reason: "startup")

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

        @MainActor
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

        private func configurePSVR2TrackingObserver() {
            guard psvr2TrackingObserver == nil else { return }
            psvr2TrackingObserver = NotificationCenter.default.addObserver(
                forName: .psvr2AccessoryTrackingConfigurationDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scheduleARKitProviderRun(reason: "PSVR2 accessory configuration changed")
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
            planeMonitorTask?.cancel()
            planeMonitorTask = nil
            sessionEventMonitorTask?.cancel()
            sessionEventMonitorTask = nil
            xrEnvironmentLightingSystem.setEnabled(false)
            RealSurfacePlaneStore.shared.clear()
        }

        private func startARKitProviders(reason: String = "unspecified") {
            #if canImport(ARKit)
                scheduleARKitProviderRun(reason: reason)
            #endif
        }

        /// Watches ARKitSession.events and logs every provider state change with the
        /// error ARKit attaches — the only place the system says WHY tracking paused
        /// or stopped. Also feeds the recovery path so a pause of the current world
        /// tracking provider is handled event-driven instead of waiting for an anchor
        /// query to miss.
        private func startSessionEventMonitor() {
            #if canImport(ARKit)
                guard sessionEventMonitorTask == nil else { return }
                let arSession = arSession
                sessionEventMonitorTask = Task { [weak self] in
                    for await event in arSession.events {
                        guard let self else { break }
                        if Task.isCancelled { break }
                        switch event {
                        case let .dataProviderStateChanged(providers, newState, error):
                            let names = providers.map { String(describing: type(of: $0)) }.joined(separator: ",")
                            let errorText = error.map { ", error=\($0)" } ?? ""
                            print("XR ARKit session event: t=\(xrLogTimestamp()), providers=\(names), newState=\(newState)\(errorText)")
                            if newState == .paused || newState == .stopped {
                                let current = currentWorldTracking()
                                if providers.contains(where: { ($0 as AnyObject) === current }) {
                                    scheduleWorldTrackingRecoveryIfNeeded()
                                }
                            }
                        case let .authorizationChanged(type, status):
                            print("XR ARKit session event: t=\(xrLogTimestamp()), authorizationChanged type=\(type), status=\(status)")
                        default:
                            print("XR ARKit session event: t=\(xrLogTimestamp()), \(event)")
                        }
                    }
                }
            #endif
        }

        private func xrLogTimestamp() -> String {
            String(format: "%.3f", CACurrentMediaTime())
        }

        private func scheduleARKitProviderRun(reason: String) {
            #if canImport(ARKit)
                let now = CACurrentMediaTime()
                let delaySeconds: CFTimeInterval

                arKitProviderRunLock.lock()
                if arKitProviderRunInProgress {
                    pendingARKitProviderRunReason = reason
                    arKitProviderRunLock.unlock()
                    print("XR ARKit providers run coalesced: reason=\(reason)")
                    return
                }

                let timeSinceFailure = now - lastARKitProviderRunFailureTime
                delaySeconds = max(arKitProviderFailureCooldownSeconds - timeSinceFailure, 0.0)
                arKitProviderRunInProgress = true
                arKitProviderRunLock.unlock()

                launchARKitProviderRunTask(reason: reason, delaySeconds: delaySeconds)
            #endif
        }

        private func launchARKitProviderRunTask(reason: String, delaySeconds: CFTimeInterval) {
            #if canImport(ARKit)
                Task { [weak self] in
                    guard let self else { return }

                    if delaySeconds > 0.0 {
                        let delayText = String(format: "%.2f", delaySeconds * 1000.0)
                        print("XR ARKit providers run delayed by failure cooldown: delayMs=\(delayText), reason=\(reason)")
                        try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000.0))
                        if Task.isCancelled {
                            finishARKitProviderRun(succeeded: false)
                            return
                        }
                    }

                    let effectiveReason = consumePendingARKitProviderRunReason(defaultReason: reason)
                    let succeeded = await runARKitProvidersOnce(reason: effectiveReason)
                    finishARKitProviderRun(succeeded: succeeded)
                }
            #endif
        }

        private func consumePendingARKitProviderRunReason(defaultReason: String) -> String {
            arKitProviderRunLock.lock()
            let reason = pendingARKitProviderRunReason ?? defaultReason
            pendingARKitProviderRunReason = nil
            arKitProviderRunLock.unlock()
            return reason
        }

        private func finishARKitProviderRun(succeeded: Bool) {
            #if canImport(ARKit)
                let pendingReason: String?
                arKitProviderRunLock.lock()
                if !succeeded {
                    lastARKitProviderRunFailureTime = CACurrentMediaTime()
                }
                pendingReason = pendingARKitProviderRunReason
                pendingARKitProviderRunReason = nil
                arKitProviderRunInProgress = false
                arKitProviderRunLock.unlock()

                if let pendingReason {
                    scheduleARKitProviderRun(reason: pendingReason)
                }
            #else
                _ = succeeded
            #endif
        }

        #if canImport(ARKit)
            private func runARKitProvidersOnce(reason: String) async -> Bool {
                let arSession = arSession
                let xrEnvironmentLightingSystem = xrEnvironmentLightingSystem

                // ARKit data providers are one-shot: an instance that has already been
                // passed to arSession.run can never be run again (re-running it leaves
                // world tracking paused forever). Create fresh instances for every run.
                let worldTracking = WorldTrackingProvider()
                let planeDetection = PlaneDetectionProvider(alignments: [.horizontal, .vertical])
                installFreshARKitProviders(worldTracking: worldTracking, planeDetection: planeDetection)

                let attempt = nextARKitProviderRunAttempt()
                let startTime = CACurrentMediaTime()

                do {
                    // Check world sensing authorization before attempting plane detection.
                    let authStatus = await arSession.queryAuthorization(for: [.worldSensing])
                    let worldSensingAllowed = authStatus[.worldSensing] != .denied
                    let authMs = (CACurrentMediaTime() - startTime) * 1000.0

                    var providers: [any DataProvider] = [worldTracking]
                    var providerNames = ["WorldTrackingProvider"]

                    if worldSensingAllowed {
                        if PlaneDetectionProvider.isSupported {
                            providers.append(planeDetection)
                            providerNames.append("PlaneDetectionProvider")
                            restartPlaneMonitor(with: planeDetection)
                        } else {
                            print("⚠️ PlaneDetectionProvider is not supported on this device")
                        }
                    } else {
                        print("⚠️ World sensing authorization denied — plane detection disabled. Grant permission in Settings > Privacy > World Sensing.")
                    }

                    let lightingProvider = xrEnvironmentLightingSystem.makeProviderForSessionRun()
                    if let lightingProvider {
                        providers.append(lightingProvider)
                        providerNames.append("EnvironmentLightingProvider")
                    }

                    if #available(visionOS 26.0, *),
                       let accessoryProvider = InputSystem.shared.makePSVR2AccessoryTrackingProviderForSessionRun()
                    {
                        providers.append(accessoryProvider)
                        providerNames.append("PSVR2 AccessoryTrackingProvider")
                    }

                    let providerList = providerNames.joined(separator: ",")
                    print("XR ARKit providers run starting: t=\(xrLogTimestamp()), attempt=\(attempt), reason=\(reason), providers=\(providerList), worldSensingAllowed=\(worldSensingAllowed), authMs=\(String(format: "%.2f", authMs))")
                    try await arSession.run(providers)
                    xrEnvironmentLightingSystem.markProviderRunning(lightingProvider != nil)
                    let durationMs = (CACurrentMediaTime() - startTime) * 1000.0
                    let durationText = String(format: "%.2f", durationMs)
                    print("XR ARKit providers run completed: t=\(xrLogTimestamp()), attempt=\(attempt), durationMs=\(durationText), worldTrackingState=\(String(describing: worldTracking.state))")
                    return true
                } catch {
                    xrEnvironmentLightingSystem.markProviderRunning(false)
                    let durationMs = (CACurrentMediaTime() - startTime) * 1000.0
                    let durationText = String(format: "%.2f", durationMs)
                    print("XR ARKit providers run failed: t=\(xrLogTimestamp()), attempt=\(attempt), durationMs=\(durationText), worldTrackingState=\(String(describing: worldTracking.state)), error=\(error)")
                    print("⚠️ Failed to start ARKit providers: \(error)")
                    return false
                }
            }
        #endif

        private func nextARKitProviderRunAttempt() -> Int {
            arKitProviderRunLock.lock()
            arKitProviderRunAttemptCount += 1
            let attempt = arKitProviderRunAttemptCount
            arKitProviderRunLock.unlock()
            return attempt
        }

        #if canImport(ARKit)
            private func installFreshARKitProviders(worldTracking: WorldTrackingProvider, planeDetection: PlaneDetectionProvider) {
                arKitProviderRunLock.lock()
                self.worldTracking = worldTracking
                self.planeDetection = planeDetection
                arKitProviderRunLock.unlock()
            }

            private func currentWorldTracking() -> WorldTrackingProvider {
                arKitProviderRunLock.lock()
                let provider = worldTracking
                arKitProviderRunLock.unlock()
                return provider
            }

            private func isARKitProviderRunInProgress() -> Bool {
                arKitProviderRunLock.lock()
                let inProgress = arKitProviderRunInProgress
                arKitProviderRunLock.unlock()
                return inProgress
            }
        #endif

        private func isRunning() -> Bool {
            lock.lock()
            let running = _isRunning
            lock.unlock()
            return running
        }

        public func runLoop() {
            while true {
                var shouldExit = false
                autoreleasepool {
                    let running = isRunning()

                    if !running {
                        shouldExit = true
                        return
                    }

                    guard let layerRenderer else {
                        shouldExit = true
                        return
                    }

                    switch layerRenderer.state {
                    case .paused:
                        layerRenderer.waitUntilRunning()

                    case .running:
                        // Call the per-frame function here
                        renderNewFrame()

                    case .invalidated:
                        shouldExit = true

                    @unknown default:
                        shouldExit = true
                    }
                }

                if shouldExit { break }
            }
        }

        /// Performs exactly one frame of rendering
        private func renderNewFrame() {
            // 1. Call queryNextFrame() to fetch the next frame to use for drawing
            guard let layerRenderer else { return }
            guard isRunning() else { return }

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

            // Drive the progressive asset loader from the main thread.
            // runLoop() runs on the visionOS compositor render thread, so tick() (which
            // requires the main thread via dispatchPrecondition) must be dispatched here.
            // This mirrors what UntoldEngine.swift does inside draw() on the MTKViewDelegate
            // main-thread path. Without this, progressive jobs never advance in XR.
            DispatchQueue.main.async {
                ProgressiveAssetLoader.shared.tick()
            }

            // 4. Update spatial input state from queued events
            if allowSpatialInputProcessing {
                updateSpatialInputState()
            } else {
                clearSpatialInput()
            }

            // 5. Perform any rendering-related work that doesn't rely on the device anchor info
            guard let renderer else { return }

            // Always sync the physical headset position into ECS camera components, even while
            // assets are loading. syncStreamingCameraPosition only writes three fields on the
            // camera entity — it never touches mesh entities being mutated by the loading pipeline,
            // so there is no race. Without this, the streaming systems resume from the pre-load
            // camera position after a long load, causing a one-tick position jump for any distance
            // that accumulated while the user was walking during the load.
            syncStreamingCameraPosition()

            if !loading {
                renderer.updateXR(useExternalStatsLifecycle: true)
            }

            // 6. Call endupdate() to mark the end of the update phase
            frame.endUpdate()

            // 7. Call wait(until:tolerace) to puase your render loop until the optimal rendering time
            LayerRenderer.Clock().wait(until: timing.optimalInputTime, tolerance: .zero)

            // The compositor or app state can transition while waiting. If not running anymore,
            // skip submission entirely to avoid using an invalid frame.
            guard isRunning(), layerRenderer.state == .running else { return }

            // 8. Call startSubmission() to mark the start of submission phase
            frame.startSubmission()
            var shouldEndSubmission = true
            defer {
                if shouldEndSubmission, layerRenderer.state == .running {
                    frame.endSubmission()
                }
            }

            // 9. Encode any drawing commands that depend on the device position or orientation
            guard let drawable = frame.queryDrawable() else {
                #if ENGINE_STATS_ENABLED
                    renderer.finalizeXRStatsAndMonitors(frameStartTime: xrFrameStartTime)
                #else
                    renderer.finalizeXRStatsAndMonitors(frameStartTime: 0.0)
                #endif
                // queryDrawable() can fail during shutdown/teardown; in that case the
                // frame is already invalid and endSubmission() must not be called.
                shouldEndSubmission = false
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
                    printXRAnchorDiagnostics(message: "XR device anchor missing; using cached anchor")
                }
                drawable.deviceAnchor = cachedAnchor
            } else {
                missingAnchorFrameCount += 1
                if shouldLogAnchorDiagnostics() {
                    printXRAnchorDiagnostics(message: "XR device anchor missing; no cached anchor available")
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
        }

        private func updateSpatialInputState() {
            spatialGestureRecognizer.updateSpatialInputState()
        }

        // MARK: - Plane Detection

        /// Restarts the plane-update monitor on the given provider. Called from
        /// runARKitProvidersOnce, since anchorUpdates streams are tied to a specific
        /// provider instance and end when that instance stops.
        private func restartPlaneMonitor(with planeDetection: PlaneDetectionProvider) {
            planeMonitorTask?.cancel()
            planeMonitorTask = Task(priority: .utility) {
                var trackedPlanes: [UUID: TrackedPlane] = [:]
                for await update in planeDetection.anchorUpdates {
                    if Task.isCancelled { break }
                    let anchor = update.anchor
                    switch update.event {
                    case .added, .updated:
                        let alignment: RealSurfaceAlignment
                        switch anchor.alignment {
                        case .horizontal:
                            alignment = .horizontal
                        case .vertical:
                            alignment = .vertical
                        @unknown default:
                            alignment = .horizontal
                        }

                        let classification: RealSurfaceKind
                        switch anchor.classification {
                        case .floor:
                            classification = .floor
                        case .ceiling:
                            classification = .ceiling
                        case .wall:
                            classification = .wall
                        case .table:
                            classification = .table
                        case .seat:
                            classification = .seat
                        case .door:
                            classification = .door
                        case .window:
                            classification = .window
                        default:
                            classification = .unknown
                        }

                        let tracked = TrackedPlane(
                            id: anchor.id,
                            originFromAnchorTransform: anchor.originFromAnchorTransform,
                            anchorFromExtentTransform: anchor.geometry.extent.anchorFromExtentTransform,
                            extentWidth: anchor.geometry.extent.width,
                            extentHeight: anchor.geometry.extent.height,
                            alignment: alignment,
                            classification: classification
                        )
                        trackedPlanes[anchor.id] = tracked

                    case .removed:
                        trackedPlanes.removeValue(forKey: anchor.id)

                    @unknown default:
                        break
                    }

                    RealSurfacePlaneStore.shared.update(planes: Array(trackedPlanes.values))
                }
            }
        }

        private func resetAllSpatialInteractionTracking() {
            spatialGestureRecognizer.resetAllSpatialInteractionTracking()
        }

        func executeXRSystemPass(frame _: LayerRenderer.Frame, drawable: LayerRenderer.Drawable, loading: Bool) {
            // Wait for available command buffer slot to prevent unbounded memory growth
            let semaphoreWaitStart = CACurrentMediaTime()
            let firstWaitResult = commandBufferSemaphore.wait(timeout: .now() + .milliseconds(100))
            if firstWaitResult == .timedOut {
                let waitMs = (CACurrentMediaTime() - semaphoreWaitStart) * 1000.0
                if shouldLogXRStallDiagnostics() {
                    printXRCommandBufferStallDiagnostics(waitMs: waitMs, phase: "initial-timeout")
                }
                commandBufferSemaphore.wait()
            }
            let semaphoreWaitMs = (CACurrentMediaTime() - semaphoreWaitStart) * 1000.0
            if semaphoreWaitMs > 16.0, shouldLogXRStallDiagnostics() {
                printXRCommandBufferStallDiagnostics(waitMs: semaphoreWaitMs, phase: "acquired")
            }

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
                    renderer?.initSizeableResources()
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
                executeGaussianFrustumCulling(commandBuffer)
                executeGaussianDepth(commandBuffer)
                executeRadixSort(commandBuffer)
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

            // Build the HZB depth pyramid once after both eyes are rendered.
            // In stereo mode the mono pyramid (from the last eye rendered) is used
            // for both per-eye VP occlusion tests in executeFrustumCulling.
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

        /// Extracts the headset world position from the device anchor and pushes it into the
        /// ECS camera components read by all four OOC systems (StreamingRegionManager,
        /// GeometryStreamingSystem, TextureStreamingSystem, LODSystem).
        ///
        /// Uses the headset center position (originFromAnchorTransform.columns.3) rather than
        /// a per-eye position — the ~3 cm per-eye IPD offset is irrelevant for streaming radii.
        ///
        /// Queries at CACurrentMediaTime() for the freshest position; falls back to
        /// lastValidDeviceAnchor on a tracking gap (one-frame lag is harmless for streaming).
        private func syncStreamingCameraPosition() {
            #if canImport(ARKit)
                let anchor = queryDeviceAnchorIfTrackingRunning(atTimestamp: CACurrentMediaTime())
                    ?? lastValidDeviceAnchor
                guard let anchor else { return }
                let t = anchor.originFromAnchorTransform
                renderer?.setXRCameraWorldPosition(simd_float3(t.columns.3.x, t.columns.3.y, t.columns.3.z))
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

        private func shouldLogXRStallDiagnostics() -> Bool {
            let now = CACurrentMediaTime()
            guard now - lastXRStallDiagnosticsLogTime >= xrStallDiagnosticsLogIntervalSeconds else {
                return false
            }

            lastXRStallDiagnosticsLogTime = now
            return true
        }

        private func printXRAnchorDiagnostics(message: String) {
            #if canImport(ARKit)
                let portalDiagnostics = getLightPortalRenderDiagnostics()
                let lightingDiagnostics = xrEnvironmentLightingSystem.diagnostics()
                let layerState = layerRenderer.map { String(describing: $0.state) } ?? "nil"
                print(
                    "⚠️ \(message): missingFrameCount=\(missingAnchorFrameCount), " +
                        "worldTrackingState=\(String(describing: currentWorldTracking().state)), " +
                        "layerState=\(layerState), " +
                        "lastValidAnchorAvailable=\(lastValidDeviceAnchor != nil), " +
                        "xrLightingValid=\(lightingDiagnostics.latestProbeTextureValid), " +
                        "xrIntensityScale=\(String(describing: lightingDiagnostics.latestIntensityScale)), " +
                        "portalAreaLightCount=\(portalDiagnostics.portalAreaLightCount), " +
                        "totalPortalIntensity=\(portalDiagnostics.totalEffectivePortalIntensity), " +
                        "portalFallback=\(String(describing: portalDiagnostics.fallbackReason))"
                )
            #else
                _ = message
            #endif
        }

        private func printXRCommandBufferStallDiagnostics(waitMs: Double, phase: String) {
            #if canImport(ARKit)
                let portalDiagnostics = getLightPortalRenderDiagnostics()
                let lightingDiagnostics = xrEnvironmentLightingSystem.diagnostics()
                let layerState = layerRenderer.map { String(describing: $0.state) } ?? "nil"
                let waitText = String(format: "%.2f", waitMs)
                print(
                    "⚠️ XR command buffer semaphore stall: phase=\(phase), waitMs=\(waitText), " +
                        "missingAnchorFrameCount=\(missingAnchorFrameCount), " +
                        "worldTrackingState=\(String(describing: currentWorldTracking().state)), " +
                        "layerState=\(layerState), " +
                        "xrLightingValid=\(lightingDiagnostics.latestProbeTextureValid), " +
                        "xrIntensityScale=\(String(describing: lightingDiagnostics.latestIntensityScale)), " +
                        "portalAreaLightCount=\(portalDiagnostics.portalAreaLightCount), " +
                        "totalPortalIntensity=\(portalDiagnostics.totalEffectivePortalIntensity), " +
                        "portalFallback=\(String(describing: portalDiagnostics.fallbackReason))"
                )
            #else
                _ = waitMs
                _ = phase
            #endif
        }

        private func queryDeviceAnchorIfTrackingRunning(atTimestamp timestamp: TimeInterval) -> DeviceAnchor? {
            #if canImport(ARKit)
                let worldTracking = currentWorldTracking()
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
                // A run in progress means a fresh provider is already starting up;
                // its state stays .initialized until arSession.run returns, and
                // scheduling recovery here would just queue a pointless extra run.
                guard !isARKitProviderRunInProgress() else { return }

                let now = CACurrentMediaTime()
                guard now - lastWorldTrackingRecoveryAttemptTime >= worldTrackingRecoveryCooldownSeconds else {
                    if shouldLogAnchorDiagnostics() {
                        printXRAnchorDiagnostics(message: "XR world tracking recovery suppressed by cooldown")
                    }
                    return
                }

                lastWorldTrackingRecoveryAttemptTime = now

                let worldTracking = currentWorldTracking()
                guard worldTracking.state != .running else { return }
                startARKitProviders(reason: "worldTrackingState=\(String(describing: worldTracking.state))")
                print("✓ XR ARKit providers recovery scheduled: t=\(xrLogTimestamp()), worldTrackingState=\(String(describing: worldTracking.state)), missingAnchorFrameCount=\(missingAnchorFrameCount)")
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

        public func setXRLightingMode(_ mode: RuntimeEnvironmentLightingMode) {
            RuntimeEnvironmentLightingStore.shared.setMode(mode, notifyIfUnchanged: true)
        }

        public func setXRLightingContribution(_ factor: Float) {
            RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution = factor
        }

        private func applyXRLightingMode(_ mode: RuntimeEnvironmentLightingMode) {
            switch mode {
            case .realWorldEstimate:
                xrEnvironmentLightingSystem.setEnabled(true)
            case .authoredOnly, .staticIBL:
                xrEnvironmentLightingSystem.setEnabled(false)
            }
        }

        private func registerRuntimeLightingModeObserverIfNeeded() {
            guard runtimeLightingModeObserverId == nil else { return }

            runtimeLightingModeObserverId = RuntimeEnvironmentLightingStore.shared.observeLightingModeChanges { [weak self] mode in
                self?.handleRuntimeLightingModeChanged(mode)
            }
        }

        private func handleRuntimeLightingModeChanged(_ mode: RuntimeEnvironmentLightingMode) {
            applyXRLightingMode(mode)
            startARKitProviders(reason: "RuntimeEnvironmentLightingStore.mode=\(mode)")
        }

        public func xrEnvironmentLightingDiagnostics() -> XREnvironmentLightingDiagnostics {
            xrEnvironmentLightingSystem.diagnostics()
        }
    }

#endif
