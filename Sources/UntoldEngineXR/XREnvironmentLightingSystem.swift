//
//  XREnvironmentLightingSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#if os(visionOS)
    import Foundation
    import Metal
    import simd
    import UntoldEngine
    #if canImport(ARKit)
        import ARKit
    #endif

    public struct XREnvironmentLightingDiagnostics: Sendable, Equatable {
        public var enabled: Bool
        public var providerSupported: Bool
        public var providerRunning: Bool
        public var latestProbeTimestamp: CFTimeInterval?
        public var latestProbeTextureValid: Bool
        public var latestCameraScaleReference: Float?
        public var latestIntensityScale: Float
        public var latestTintColor: simd_float3
        public var prefilterInFlight: Bool
        public var lastPrefilterDurationMs: Double?
        public var realWorldLightingContribution: Float
        public var acceptedProbeUpdateCount: Int
        public var skippedProbeUpdateCount: Int
        public var fallbackReason: String?
        /// The probe texture as ARKit last handed it over: pixel format, face size, mip count.
        public var latestProbeDescription: String = ""
        /// The intensity scale as published to the renderer (smoothed), and how many times a
        /// prefiltered probe has been published.
        public var publishedIntensityScale: Float?
        public var publishCount: Int = 0
        /// The mean luminance of each face of the last probe read back (+x, −x, +y, −y, +z, −z),
        /// before the intensity scale: where the room's light is in the probe's frame.
        public var latestProbeFaceLuminance: [Float] = []
    }

    public final class XREnvironmentLightingSystem: @unchecked Sendable {
        private let lock = NSLock()
        private var enabledValue = false
        private var providerRunningValue = false
        private var latestProbeTimestampValue: CFTimeInterval?
        private var latestProbeTextureValidValue = false
        private var latestCameraScaleReferenceValue: Float?
        private var latestIntensityScaleValue: Float = 1.0
        private var latestTintColorValue = simd_float3(1.0, 1.0, 1.0)
        private var prefilterInFlightValue = false
        private var lastPrefilterDurationMsValue: Double?
        private var acceptedProbeUpdateCountValue = 0
        private var skippedProbeUpdateCountValue = 0
        private var fallbackReasonValue: String?
        private var latestProbeDescriptionValue = ""
        private var publishCountValue = 0
        private var latestProbeFaceLuminanceValue: [Float] = []
        private var lastAcceptedProbeUpdateTime: CFTimeInterval = 0
        /// The newest probe not yet prefiltered: one that arrived while another was being
        /// prefiltered, or inside the minimum interval. ARKit sends its estimates in a burst
        /// when the provider starts and may then send nothing for a long while in a still
        /// room, so the newest one must not be dropped.
        private struct PendingProbe {
            var texture: MTLTexture
            var timestamp: CFTimeInterval
            var intensityScale: Float
            var retainedAnchor: Any
        }

        private var pendingProbeValue: PendingProbe?
        private var pendingProbeDrainTask: Task<Void, Never>?
        private var lastReadbackStartTime: CFTimeInterval?
        private var readbackInFlightValue = false
        /// Bumped when the system is disabled: a readback or a transition step from before
        /// then has nothing to come back to.
        private var sessionGeneration: UInt64 = 0
        /// The light's transition. The newest estimate read back is the target: its first
        /// mip's texels (six faces, row by row, linear rgb), its scale and its tint. What is
        /// shown is the current, which moves towards the target step by step; each step
        /// uploads the current texels into the blend cube, prefilters it and publishes.
        private var targetProbeTexels: [Float] = []
        private var targetProbeSize = 0
        private var targetIntensityScaleValue: Float = 1.0
        private var targetTintColorValue = simd_float3(1.0, 1.0, 1.0)
        private var targetTimestampValue: CFTimeInterval = 0
        private var targetGeneration: UInt64 = 0
        private var currentProbeTexels: [Float] = []
        private var currentProbeSize = 0
        private var currentIntensityScaleValue: Float = 1.0
        private var currentTintColorValue = simd_float3(1.0, 1.0, 1.0)
        private var blendedProbeCube: MTLTexture?
        private var transitionRunning = false
        private var lastTransitionStepTime: CFTimeInterval?
        private var publishedIntensityScaleValue: Float?
        private var probeMonitorTask: Task<Void, Never>?
        private var textureSets: [RuntimeEnvironmentLightingTextureSet] = []
        private var currentReadTextureSetIndex = 0
        private var prefilterGeneration: UInt64 = 0
        /// The probe's camera scale reference at which the room's light is applied as it is.
        /// Calibrated against RealityKit's lighting of the same object in the same room (a
        /// dartboard's white segments matched the passthrough's whites at a reference of
        /// 19016 with a scale of about 19): the reference over a thousand.
        private let cameraScaleReferenceWhitePoint: Float = 1000.0

        #if canImport(ARKit)
            /// ARKit data providers are one-shot: an instance that has been passed to
            /// ARKitSession.run can never be run again, so makeProviderForSessionRun
            /// swaps in a fresh instance (guarded by lock) for every session run.
            private var environmentLightEstimationProvider: EnvironmentLightEstimationProvider?
        #endif

        /// The least time between two prefilters: a probe that arrives inside it waits, and the
        /// newest one waiting is the one prefiltered.
        public var minimumProbeUpdateInterval: CFTimeInterval = 0.5

        /// The time constant (seconds) of the light's transition from one estimate to the
        /// next. A new estimate does not replace the light at once: the probe's texels, its
        /// scale and its tint move towards it exponentially, re-prefiltered every
        /// `transitionStepInterval`, so a step in the camera's exposure or in what the probe
        /// sees when the wearer turns towards a window becomes a fade, not a cut. 0 publishes
        /// each estimate as it arrives.
        public var lightingSmoothingTimeConstant: CFTimeInterval = 3.0

        /// How often the transition re-prefilters the blended probe while it is under way.
        public var transitionStepInterval: CFTimeInterval = 0.1

        public init() {
            #if canImport(ARKit)
                if EnvironmentLightEstimationProvider.isSupported {
                    environmentLightEstimationProvider = EnvironmentLightEstimationProvider()
                } else {
                    environmentLightEstimationProvider = nil
                }
            #endif
        }

        deinit {
            probeMonitorTask?.cancel()
        }

        public var enabled: Bool {
            lock.lock()
            let value = enabledValue
            lock.unlock()
            return value
        }

        public var providerSupported: Bool {
            #if canImport(ARKit)
                EnvironmentLightEstimationProvider.isSupported
            #else
                false
            #endif
        }

        #if canImport(ARKit)
            public var providerForSession: (any DataProvider)? {
                guard enabled else { return nil }
                lock.lock()
                let provider = environmentLightEstimationProvider
                lock.unlock()
                return provider
            }

            /// Creates a fresh provider for an ARKitSession run and re-wires the probe
            /// monitor to it. ARKit data providers are one-shot — an instance that has
            /// been passed to ARKitSession.run can never be run again — so the session
            /// owner must call this before every run instead of reusing providerForSession.
            public func makeProviderForSessionRun() -> (any DataProvider)? {
                guard enabled, EnvironmentLightEstimationProvider.isSupported else { return nil }
                let provider = EnvironmentLightEstimationProvider()
                lock.lock()
                environmentLightEstimationProvider = provider
                lock.unlock()
                restartProbeMonitor(with: provider)
                return provider
            }
        #else
            public func makeProviderForSessionRun() -> Any? {
                nil
            }
        #endif

        public func setEnabled(_ enabled: Bool) {
            lock.lock()
            enabledValue = enabled
            if !enabled {
                fallbackReasonValue = nil
                latestProbeTimestampValue = nil
                latestProbeTextureValidValue = false
                latestCameraScaleReferenceValue = nil
                latestIntensityScaleValue = 1.0
                latestTintColorValue = simd_float3(1.0, 1.0, 1.0)
                providerRunningValue = false
                prefilterInFlightValue = false
                lastPrefilterDurationMsValue = nil
                lastAcceptedProbeUpdateTime = 0
                pendingProbeValue = nil
                pendingProbeDrainTask?.cancel()
                pendingProbeDrainTask = nil
                lastReadbackStartTime = nil
                readbackInFlightValue = false
                prefilterGeneration &+= 1
                sessionGeneration &+= 1
                targetProbeTexels = []
                currentProbeTexels = []
                transitionRunning = false
                lastTransitionStepTime = nil
                publishedIntensityScaleValue = nil
                RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
            }
            lock.unlock()

            if enabled {
                startProbeMonitor()
            } else {
                stopProbeMonitor()
            }
        }

        public func markProviderRunning(_ running: Bool) {
            lock.lock()
            providerRunningValue = running
            lock.unlock()
        }

        public func shouldAcceptProbeUpdate(timestamp: CFTimeInterval) -> Bool {
            lock.lock()
            defer { lock.unlock() }

            guard enabledValue else {
                skippedProbeUpdateCountValue += 1
                fallbackReasonValue = "XR lighting disabled"
                return false
            }

            lastAcceptedProbeUpdateTime = timestamp
            latestProbeTimestampValue = timestamp
            acceptedProbeUpdateCountValue += 1
            fallbackReasonValue = nil
            return true
        }

        public func publishUnavailableProbe(reason: String) {
            lock.lock()
            latestProbeTextureValidValue = false
            fallbackReasonValue = reason
            lock.unlock()
            RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
        }

        #if canImport(ARKit)
            private func startProbeMonitor() {
                guard probeMonitorTask == nil else { return }
                lock.lock()
                let provider = environmentLightEstimationProvider
                lock.unlock()
                guard let provider else {
                    publishUnavailableProbe(reason: "Environment light estimation unsupported")
                    return
                }

                restartProbeMonitor(with: provider)
            }

            /// anchorUpdates streams are tied to a specific provider instance and end
            /// when that instance stops, so each fresh provider needs a fresh monitor.
            private func restartProbeMonitor(with provider: EnvironmentLightEstimationProvider) {
                probeMonitorTask?.cancel()
                probeMonitorTask = Task(priority: .utility) { [weak self, provider] in
                    for await update in provider.anchorUpdates {
                        if Task.isCancelled { break }
                        self?.handleProbeAnchorUpdate(update)
                    }
                }
            }

            private func stopProbeMonitor() {
                probeMonitorTask?.cancel()
                probeMonitorTask = nil
            }

            private func handleProbeAnchorUpdate(_ update: AnchorUpdate<EnvironmentProbeAnchor>) {
                switch update.event {
                case .added, .updated:
                    let anchor = update.anchor
                    guard shouldAcceptProbeUpdate(timestamp: anchor.timestamp) else { return }

                    let hasTexture = anchor.environmentTexture != nil
                    if let texture = anchor.environmentTexture {
                        let description = "\(Self.pixelFormatName(texture.pixelFormat)) \(texture.width)×\(texture.height) ×\(texture.mipmapLevelCount) mips"
                        lock.lock()
                        latestProbeDescriptionValue = description
                        lock.unlock()
                    }
                    let intensityScale = updateProbeCameraScaleReference(
                        anchor.cameraScaleReference,
                        hasTexture: hasTexture
                    )

                    if let environmentTexture = anchor.environmentTexture {
                        enqueueProbe(PendingProbe(
                            texture: environmentTexture,
                            timestamp: anchor.timestamp,
                            intensityScale: intensityScale,
                            retainedAnchor: anchor
                        ))
                    }

                case .removed:
                    publishUnavailableProbe(reason: "XR probe anchor removed")

                @unknown default:
                    publishUnavailableProbe(reason: "Unknown XR probe update")
                }
            }
        #else
            private func startProbeMonitor() {}

            private func stopProbeMonitor() {}
        #endif

        private func ensureTextureSets() -> Bool {
            if textureSets.count == 2 { return true }

            guard let first = makeRuntimeEnvironmentLightingTextureSet(labelPrefix: "XR Runtime IBL A"),
                  let second = makeRuntimeEnvironmentLightingTextureSet(labelPrefix: "XR Runtime IBL B")
            else {
                fallbackReasonValue = "Unable to allocate XR IBL textures"
                return false
            }

            textureSets = [first, second]
            currentReadTextureSetIndex = 0
            return true
        }

        private func beginPrefilterIfPossible() -> (textureSetIndex: Int, textureSet: RuntimeEnvironmentLightingTextureSet, generation: UInt64)? {
            lock.lock()
            defer { lock.unlock() }

            guard enabledValue else {
                fallbackReasonValue = "XR lighting disabled"
                return nil
            }

            guard !prefilterInFlightValue else {
                skippedProbeUpdateCountValue += 1
                return nil
            }

            guard ensureTextureSets() else {
                return nil
            }

            let writeIndex = currentReadTextureSetIndex == 0 ? 1 : 0
            let textureSet = textureSets[writeIndex]
            prefilterGeneration &+= 1
            prefilterInFlightValue = true
            fallbackReasonValue = nil
            return (writeIndex, textureSet, prefilterGeneration)
        }

        /// Publishes the prefiltered set with the scale and tint it is given; false when it
        /// could not (disabled, superseded, or the prefilter failed, which publishes nothing).
        @discardableResult
        private func finishPrefilter(
            succeeded: Bool,
            textureSetIndex: Int,
            generation: UInt64,
            timestamp: CFTimeInterval,
            intensityScale: Float,
            tintColor: simd_float3,
            durationMs: Double
        ) -> Bool {
            lock.lock()

            guard enabledValue, generation == prefilterGeneration else {
                lock.unlock()
                return false
            }

            prefilterInFlightValue = false
            lastPrefilterDurationMsValue = durationMs

            guard succeeded, textureSets.indices.contains(textureSetIndex) else {
                fallbackReasonValue = "XR probe prefilter failed"
                lock.unlock()
                RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
                return false
            }

            currentReadTextureSetIndex = textureSetIndex
            let textureSet = textureSets[textureSetIndex]
            latestTintColorValue = tintColor
            publishedIntensityScaleValue = intensityScale
            fallbackReasonValue = nil
            publishCountValue += 1
            lock.unlock()

            RuntimeEnvironmentLightingStore.shared.publishXRLighting(
                RuntimeEnvironmentLighting(
                    irradianceMap: textureSet.irradianceMap,
                    specularMap: textureSet.specularMap,
                    brdfMap: textureSet.brdfMap,
                    intensityScale: intensityScale,
                    tintColor: tintColor,
                    timestamp: timestamp,
                    isValid: true
                )
            )
            return true
        }

        private func updateProbeCameraScaleReference(_ cameraScaleReference: Float?, hasTexture: Bool) -> Float {
            lock.lock()
            defer { lock.unlock() }

            latestProbeTextureValidValue = hasTexture
            latestCameraScaleReferenceValue = cameraScaleReference
            if !hasTexture {
                fallbackReasonValue = "XR probe texture unavailable"
                latestIntensityScaleValue = 0.0
                latestTintColorValue = simd_float3(1.0, 1.0, 1.0)
                RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
            }

            guard let cameraScaleReference,
                  cameraScaleReference.isFinite,
                  cameraScaleReference > 0.0001
            else {
                latestIntensityScaleValue = hasTexture ? 1.0 : 0.0
                return latestIntensityScaleValue
            }

            let intensityScale = min(max(cameraScaleReference / cameraScaleReferenceWhitePoint, 0.0), 64.0)
            latestIntensityScaleValue = intensityScale
            return intensityScale
        }

        private struct EnvironmentTintReadback {
            var buffer: MTLBuffer
            var pixelFormat: MTLPixelFormat
            var width: Int
            var height: Int
            var bytesPerRow: Int
            var faceBytes: Int
            var faceCount: Int
        }

        /// Takes a probe in: the newest one waits for the readback in flight and for the
        /// minimum interval, then is read back and becomes the light's target; an older one
        /// still waiting is superseded.
        private func enqueueProbe(_ probe: PendingProbe) {
            lock.lock()
            pendingProbeValue = probe
            lock.unlock()
            drainPendingProbe()
        }

        /// Reads the waiting probe back once no readback is in flight and the interval has
        /// passed; until then the readback's completion, or a timer for the rest of the
        /// interval, comes back here.
        private func drainPendingProbe() {
            lock.lock()
            guard enabledValue, let probe = pendingProbeValue, !readbackInFlightValue else {
                lock.unlock()
                return
            }
            let now = ProcessInfo.processInfo.systemUptime
            if let lastStart = lastReadbackStartTime {
                let remaining = minimumProbeUpdateInterval - (now - lastStart)
                if remaining > 0 {
                    if pendingProbeDrainTask == nil {
                        pendingProbeDrainTask = Task { [weak self] in
                            try? await Task.sleep(for: .seconds(remaining))
                            guard !Task.isCancelled else { return }
                            self?.drainTimerFired()
                        }
                    }
                    lock.unlock()
                    return
                }
            }
            pendingProbeValue = nil
            lastReadbackStartTime = now
            lock.unlock()
            scheduleProbeReadback(
                environmentTexture: probe.texture,
                timestamp: probe.timestamp,
                intensityScale: probe.intensityScale,
                retainedAnchor: probe.retainedAnchor
            )
        }

        /// The rest of the interval has passed: the waiting probe may go now.
        private func drainTimerFired() {
            lock.lock()
            pendingProbeDrainTask = nil
            lock.unlock()
            drainPendingProbe()
        }

        /// Reads the probe back: its first mip, the texels the light's transition blends, and
        /// its last mip, the per-face light the diagnostics report and the tint comes from.
        private func scheduleProbeReadback(
            environmentTexture: MTLTexture,
            timestamp: CFTimeInterval,
            intensityScale: Float,
            retainedAnchor: Any
        ) {
            guard environmentTexture.textureType == .typeCube else {
                publishUnavailableProbe(reason: "XR probe texture is not a cube texture")
                return
            }

            lock.lock()
            guard enabledValue, !readbackInFlightValue else {
                lock.unlock()
                return
            }
            readbackInFlightValue = true
            let session = sessionGeneration
            lock.unlock()

            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
                  let texels = encodeEnvironmentTintReadback(commandBuffer: commandBuffer, environmentTexture: environmentTexture, mipLevel: 0),
                  let faces = encodeEnvironmentTintReadback(commandBuffer: commandBuffer, environmentTexture: environmentTexture)
            else {
                lock.lock()
                readbackInFlightValue = false
                lock.unlock()
                publishUnavailableProbe(reason: "XR probe readback could not be encoded")
                return
            }

            commandBuffer.label = "XR Environment Probe Readback"
            commandBuffer.addCompletedHandler { [weak self, retainedAnchor] commandBuffer in
                _ = retainedAnchor
                guard let self else { return }
                let succeeded = commandBuffer.status == .completed
                let tintColor = succeeded ? self.environmentTint(from: faces) : simd_float3(1.0, 1.0, 1.0)
                let rgb = succeeded ? self.probeTexels(from: texels) : []
                self.probeEstimateArrived(
                    texels: rgb,
                    size: texels.width,
                    intensityScale: intensityScale,
                    tintColor: tintColor,
                    timestamp: timestamp,
                    session: session,
                    succeeded: succeeded
                )
            }
            commandBuffer.commit()
        }

        /// A readback's texels, face by face and row by row, as linear rgb.
        private func probeTexels(from readback: EnvironmentTintReadback) -> [Float] {
            let contents = readback.buffer.contents()
            let bytesPerPixel = readback.bytesPerRow / max(readback.width, 1)
            var texels: [Float] = []
            texels.reserveCapacity(readback.faceCount * readback.width * readback.height * 3)
            for face in 0 ..< readback.faceCount {
                for y in 0 ..< readback.height {
                    for x in 0 ..< readback.width {
                        let offset = face * readback.faceBytes + y * readback.bytesPerRow + x * bytesPerPixel
                        let c = environmentTintPixel(contents: contents, offset: offset, pixelFormat: readback.pixelFormat)
                        texels.append(c.x)
                        texels.append(c.y)
                        texels.append(c.z)
                    }
                }
            }
            return texels
        }

        /// An estimate has been read back: it is the target the shown light moves to. The
        /// first estimate, or one of another size, is shown as it is.
        private func probeEstimateArrived(
            texels: [Float],
            size: Int,
            intensityScale: Float,
            tintColor: simd_float3,
            timestamp: CFTimeInterval,
            session: UInt64,
            succeeded: Bool
        ) {
            lock.lock()
            readbackInFlightValue = false
            guard enabledValue, session == sessionGeneration else {
                lock.unlock()
                return
            }
            guard succeeded, !texels.isEmpty else {
                lock.unlock()
                publishUnavailableProbe(reason: "XR probe readback failed")
                drainPendingProbe()
                return
            }
            targetProbeTexels = texels
            targetProbeSize = size
            targetIntensityScaleValue = intensityScale
            targetTintColorValue = tintColor
            targetTimestampValue = timestamp
            targetGeneration &+= 1
            if currentProbeTexels.count != texels.count {
                currentProbeTexels = texels
                currentProbeSize = size
                currentIntensityScaleValue = intensityScale
                currentTintColorValue = tintColor
            }
            let start = !transitionRunning
            if start {
                transitionRunning = true
                lastTransitionStepTime = ProcessInfo.processInfo.systemUptime
            }
            lock.unlock()
            if start {
                transitionStep()
            }
            drainPendingProbe()
        }

        /// One step of the light's transition: the shown texels, scale and tint move towards
        /// the target by the time constant's share of the time since the last step, the blend
        /// cube is prefiltered and published. The step that reaches the target is the last
        /// until a new estimate arrives.
        private func transitionStep() {
            lock.lock()
            guard enabledValue, !currentProbeTexels.isEmpty, targetProbeTexels.count == currentProbeTexels.count else {
                transitionRunning = false
                lock.unlock()
                return
            }
            let now = ProcessInfo.processInfo.systemUptime
            let deltaTime = lastTransitionStepTime.map { min(max(now - $0, 0.0), 10.0) } ?? 0.0
            let timeConstant = lightingSmoothingTimeConstant
            var alpha: Float = timeConstant > 0.0 ? Float(1.0 - exp(-deltaTime / timeConstant)) : 1.0
            var maxDifference: Float = 0.0
            var maxTarget: Float = 0.0
            for index in currentProbeTexels.indices {
                maxDifference = max(maxDifference, abs(targetProbeTexels[index] - currentProbeTexels[index]))
                maxTarget = max(maxTarget, targetProbeTexels[index])
            }
            let scaleDifference = abs(targetIntensityScaleValue - currentIntensityScaleValue)
            // Close enough counts as there: the step snaps to the target and is the last.
            let final = alpha >= 1.0
                || (maxDifference <= 0.002 * max(maxTarget, 1.0) && scaleDifference <= 0.005 * max(targetIntensityScaleValue, 0.01))
            if final {
                alpha = 1.0
            }
            for index in currentProbeTexels.indices {
                currentProbeTexels[index] += (targetProbeTexels[index] - currentProbeTexels[index]) * alpha
            }
            currentIntensityScaleValue += (targetIntensityScaleValue - currentIntensityScaleValue) * alpha
            currentTintColorValue += (targetTintColorValue - currentTintColorValue) * alpha
            lastTransitionStepTime = now
            let shownGeneration = targetGeneration
            let session = sessionGeneration
            let texels = currentProbeTexels
            let size = currentProbeSize
            let intensityScale = currentIntensityScaleValue
            let tintColor = currentTintColorValue
            let timestamp = targetTimestampValue
            lock.unlock()

            guard let cube = uploadBlendedProbe(texels: texels, size: size) else {
                lock.lock()
                transitionRunning = false
                lock.unlock()
                publishUnavailableProbe(reason: "XR probe blend texture unavailable")
                return
            }
            prefilterBlendedProbe(cube, intensityScale: intensityScale, tintColor: tintColor, timestamp: timestamp) { [weak self] published in
                self?.continueTransition(after: shownGeneration, session: session, final: final || !published)
            }
        }

        /// After a step: the next one after the interval, or none when the target is reached
        /// and no newer estimate has arrived in the meantime.
        private func continueTransition(after shownGeneration: UInt64, session: UInt64, final: Bool) {
            lock.lock()
            guard enabledValue, session == sessionGeneration else {
                transitionRunning = false
                lock.unlock()
                return
            }
            if final, targetGeneration == shownGeneration {
                transitionRunning = false
                lock.unlock()
                return
            }
            let interval = final ? 0.0 : transitionStepInterval
            lock.unlock()
            Task { [weak self] in
                if interval > 0.0 {
                    try? await Task.sleep(for: .seconds(interval))
                }
                self?.transitionStep()
            }
        }

        /// The shown texels, uploaded into the blend cube the prefilter reads.
        private func uploadBlendedProbe(texels: [Float], size: Int) -> MTLTexture? {
            lock.lock()
            if blendedProbeCube == nil || blendedProbeCube?.width != size {
                let descriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba16Float, size: size, mipmapped: true)
                descriptor.usage = [.shaderRead, .shaderWrite]
                descriptor.storageMode = .shared
                blendedProbeCube = renderInfo.device.makeTexture(descriptor: descriptor)
                blendedProbeCube?.label = "XR Environment Probe Blend"
            }
            let cube = blendedProbeCube
            lock.unlock()
            guard let cube, texels.count == 6 * size * size * 3 else { return nil }

            let faceTexels = size * size
            var half = [UInt16](repeating: 0, count: faceTexels * 4)
            for face in 0 ..< 6 {
                for index in 0 ..< faceTexels {
                    let base = (face * faceTexels + index) * 3
                    half[index * 4] = Float16(texels[base]).bitPattern
                    half[index * 4 + 1] = Float16(texels[base + 1]).bitPattern
                    half[index * 4 + 2] = Float16(texels[base + 2]).bitPattern
                    half[index * 4 + 3] = Float16(1.0).bitPattern
                }
                half.withUnsafeBytes { bytes in
                    cube.replace(
                        region: MTLRegionMake2D(0, 0, size, size),
                        mipmapLevel: 0,
                        slice: face,
                        withBytes: bytes.baseAddress!,
                        bytesPerRow: size * 8,
                        bytesPerImage: faceTexels * 8
                    )
                }
            }
            return cube
        }

        /// Prefilters the blend cube into the free texture set and publishes it; the completion
        /// says whether it was published.
        private func prefilterBlendedProbe(
            _ cube: MTLTexture,
            intensityScale: Float,
            tintColor: simd_float3,
            timestamp: CFTimeInterval,
            completion: @escaping (Bool) -> Void
        ) {
            guard let prefilter = beginPrefilterIfPossible() else {
                completion(false)
                return
            }
            let textureSetIndex = prefilter.textureSetIndex
            let textureSet = prefilter.textureSet
            let generation = prefilter.generation

            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
                  let blit = commandBuffer.makeBlitCommandEncoder()
            else {
                finishPrefilter(succeeded: false, textureSetIndex: textureSetIndex, generation: generation, timestamp: timestamp, intensityScale: intensityScale, tintColor: tintColor, durationMs: 0)
                completion(false)
                return
            }

            commandBuffer.label = "XR Environment Probe IBL Prefilter"
            blit.generateMipmaps(for: cube)
            blit.endEncoding()
            let startTime = Date().timeIntervalSinceReferenceDate
            guard executeXRIBLCubePreFilterPass(commandBuffer: commandBuffer, environmentCubeTexture: cube, target: textureSet) else {
                finishPrefilter(succeeded: false, textureSetIndex: textureSetIndex, generation: generation, timestamp: timestamp, intensityScale: intensityScale, tintColor: tintColor, durationMs: 0)
                completion(false)
                return
            }

            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                let durationMs = (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0
                let published = self?.finishPrefilter(
                    succeeded: commandBuffer.status == .completed,
                    textureSetIndex: textureSetIndex,
                    generation: generation,
                    timestamp: timestamp,
                    intensityScale: intensityScale,
                    tintColor: tintColor,
                    durationMs: durationMs
                ) ?? false
                completion(published)
            }
            commandBuffer.commit()
        }

        private func encodeEnvironmentTintReadback(
            commandBuffer: MTLCommandBuffer,
            environmentTexture: MTLTexture,
            mipLevel: Int? = nil
        ) -> EnvironmentTintReadback? {
            guard let bytesPerPixel = environmentTintBytesPerPixel(for: environmentTexture.pixelFormat),
                  let blit = commandBuffer.makeBlitCommandEncoder()
            else { return nil }

            let mipLevel = min(max(mipLevel ?? (environmentTexture.mipmapLevelCount - 1), 0), max(environmentTexture.mipmapLevelCount - 1, 0))
            let width = max(environmentTexture.width >> mipLevel, 1)
            let height = max(environmentTexture.height >> mipLevel, 1)
            let bytesPerRow = width * bytesPerPixel
            let faceBytes = bytesPerRow * height
            let faceCount = 6
            let bufferLength = faceBytes * faceCount

            guard let buffer = renderInfo.device.makeBuffer(length: bufferLength, options: .storageModeShared) else {
                blit.endEncoding()
                return nil
            }
            buffer.label = "XR Environment Probe Tint Readback"

            for face in 0 ..< faceCount {
                blit.copy(
                    from: environmentTexture,
                    sourceSlice: face,
                    sourceLevel: mipLevel,
                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSize(width: width, height: height, depth: 1),
                    to: buffer,
                    destinationOffset: face * faceBytes,
                    destinationBytesPerRow: bytesPerRow,
                    destinationBytesPerImage: faceBytes
                )
            }
            blit.endEncoding()

            return EnvironmentTintReadback(
                buffer: buffer,
                pixelFormat: environmentTexture.pixelFormat,
                width: width,
                height: height,
                bytesPerRow: bytesPerRow,
                faceBytes: faceBytes,
                faceCount: faceCount
            )
        }

        /// A readable name for the probe's pixel format (Metal prints only the raw value).
        private static func pixelFormatName(_ pixelFormat: MTLPixelFormat) -> String {
            switch pixelFormat {
            case .rgba16Float: return "rgba16Float"
            case .rgba32Float: return "rgba32Float"
            case .rgba8Unorm: return "rgba8Unorm"
            case .rgba8Unorm_srgb: return "rgba8Unorm_srgb"
            case .bgra8Unorm: return "bgra8Unorm"
            case .bgra8Unorm_srgb: return "bgra8Unorm_srgb"
            case .rg11b10Float: return "rg11b10Float"
            case .rgb9e5Float: return "rgb9e5Float"
            case .bgr10a2Unorm: return "bgr10a2Unorm"
            case .rgb10a2Unorm: return "rgb10a2Unorm"
            default: return "pixelFormat \(pixelFormat.rawValue)"
            }
        }

        private func environmentTintBytesPerPixel(for pixelFormat: MTLPixelFormat) -> Int? {
            switch pixelFormat {
            case .rgba16Float:
                return 8
            case .rgba32Float:
                return 16
            case .rgba8Unorm, .rgba8Unorm_srgb, .bgra8Unorm, .bgra8Unorm_srgb:
                return 4
            default:
                return nil
            }
        }

        private func environmentTint(from readback: EnvironmentTintReadback) -> simd_float3 {
            let contents = readback.buffer.contents()
            var total = simd_float3(0.0, 0.0, 0.0)
            var sampleCount: Float = 0.0

            var faceLuminance: [Float] = []
            for face in 0 ..< readback.faceCount {
                let faceBase = face * readback.faceBytes
                var faceTotal = simd_float3(0.0, 0.0, 0.0)
                for y in 0 ..< readback.height {
                    let rowBase = faceBase + y * readback.bytesPerRow
                    for x in 0 ..< readback.width {
                        let offset = rowBase + x * environmentTintBytesPerPixel(for: readback.pixelFormat)!
                        faceTotal += environmentTintPixel(contents: contents, offset: offset, pixelFormat: readback.pixelFormat)
                        sampleCount += 1.0
                    }
                }
                total += faceTotal
                let faceSamples = Float(max(readback.width * readback.height, 1))
                faceLuminance.append(simd_dot(faceTotal / faceSamples, simd_float3(0.2126, 0.7152, 0.0722)))
            }
            lock.lock()
            latestProbeFaceLuminanceValue = faceLuminance
            lock.unlock()

            guard sampleCount > 0.0 else { return simd_float3(1.0, 1.0, 1.0) }
            let average = total / sampleCount
            let luminance = simd_dot(average, simd_float3(0.2126, 0.7152, 0.0722))
            guard luminance.isFinite, luminance > 0.0001 else { return simd_float3(1.0, 1.0, 1.0) }

            let tint = average / luminance
            return simd_clamp(tint, simd_float3(0.25, 0.25, 0.25), simd_float3(2.5, 2.5, 2.5))
        }

        private func environmentTintPixel(contents: UnsafeMutableRawPointer, offset: Int, pixelFormat: MTLPixelFormat) -> simd_float3 {
            switch pixelFormat {
            case .rgba16Float:
                let pointer = contents.advanced(by: offset).assumingMemoryBound(to: UInt16.self)
                return simd_float3(
                    Float(Float16(bitPattern: pointer[0])),
                    Float(Float16(bitPattern: pointer[1])),
                    Float(Float16(bitPattern: pointer[2]))
                )
            case .rgba32Float:
                let pointer = contents.advanced(by: offset).assumingMemoryBound(to: Float.self)
                return simd_float3(pointer[0], pointer[1], pointer[2])
            case .rgba8Unorm, .rgba8Unorm_srgb:
                let pointer = contents.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                return simd_float3(Float(pointer[0]), Float(pointer[1]), Float(pointer[2])) / 255.0
            case .bgra8Unorm, .bgra8Unorm_srgb:
                let pointer = contents.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                return simd_float3(Float(pointer[2]), Float(pointer[1]), Float(pointer[0])) / 255.0
            default:
                return simd_float3(1.0, 1.0, 1.0)
            }
        }

        public func diagnostics() -> XREnvironmentLightingDiagnostics {
            lock.lock()
            #if canImport(ARKit)
                let providerRunning = environmentLightEstimationProvider?.state == .running
            #else
                let providerRunning = providerRunningValue
            #endif
            let diagnostics = XREnvironmentLightingDiagnostics(
                enabled: enabledValue,
                providerSupported: providerSupported,
                providerRunning: providerRunning,
                latestProbeTimestamp: latestProbeTimestampValue,
                latestProbeTextureValid: latestProbeTextureValidValue,
                latestCameraScaleReference: latestCameraScaleReferenceValue,
                latestIntensityScale: latestIntensityScaleValue,
                latestTintColor: latestTintColorValue,
                prefilterInFlight: prefilterInFlightValue,
                lastPrefilterDurationMs: lastPrefilterDurationMsValue,
                realWorldLightingContribution: RuntimeEnvironmentLightingStore.shared.realWorldLightingContribution,
                acceptedProbeUpdateCount: acceptedProbeUpdateCountValue,
                skippedProbeUpdateCount: skippedProbeUpdateCountValue,
                fallbackReason: fallbackReasonValue,
                latestProbeDescription: latestProbeDescriptionValue,
                publishedIntensityScale: publishedIntensityScaleValue,
                publishCount: publishCountValue,
                latestProbeFaceLuminance: latestProbeFaceLuminanceValue
            )
            lock.unlock()
            return diagnostics
        }
    }
#endif
