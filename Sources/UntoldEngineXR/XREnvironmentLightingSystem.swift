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
        private var lastAcceptedProbeUpdateTime: CFTimeInterval = 0
        private var probeMonitorTask: Task<Void, Never>?
        private var textureSets: [RuntimeEnvironmentLightingTextureSet] = []
        private var currentReadTextureSetIndex = 0
        private var prefilterGeneration: UInt64 = 0
        private let cameraScaleReferenceWhitePoint: Float = 5000.0
        private var smoothedIntensityScaleValue: Float?
        private var smoothedTintColorValue = simd_float3(1.0, 1.0, 1.0)
        private var lastSmoothedLightingTimestamp: CFTimeInterval?

        #if canImport(ARKit)
            /// ARKit data providers are one-shot: an instance that has been passed to
            /// ARKitSession.run can never be run again, so makeProviderForSessionRun
            /// swaps in a fresh instance (guarded by lock) for every session run.
            private var environmentLightEstimationProvider: EnvironmentLightEstimationProvider?
        #endif

        public var minimumProbeUpdateInterval: CFTimeInterval = 0.5

        /// Exponential-smoothing time constant (seconds) applied to the probe-driven
        /// intensity scale and tint before publishing. The raw values track headset
        /// camera auto-exposure (`cameraScaleReference`) and can step sharply when the
        /// user looks toward or away from bright real-world light sources; without
        /// smoothing every real-world-tinted light portal steps in brightness with
        /// head movement. Set to 0 to publish raw values immediately.
        public var lightingSmoothingTimeConstant: CFTimeInterval = 1.0

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
                prefilterGeneration &+= 1
                smoothedIntensityScaleValue = nil
                smoothedTintColorValue = simd_float3(1.0, 1.0, 1.0)
                lastSmoothedLightingTimestamp = nil
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

            guard timestamp - lastAcceptedProbeUpdateTime >= minimumProbeUpdateInterval else {
                skippedProbeUpdateCountValue += 1
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
                    let intensityScale = updateProbeCameraScaleReference(
                        anchor.cameraScaleReference,
                        hasTexture: hasTexture
                    )

                    if let environmentTexture = anchor.environmentTexture {
                        scheduleProbePrefilter(
                            environmentTexture: environmentTexture,
                            timestamp: anchor.timestamp,
                            intensityScale: intensityScale,
                            retainedAnchor: anchor
                        )
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

        private func finishPrefilter(
            succeeded: Bool,
            textureSetIndex: Int,
            generation: UInt64,
            timestamp: CFTimeInterval,
            intensityScale: Float,
            tintColor: simd_float3,
            durationMs: Double
        ) {
            lock.lock()

            guard enabledValue, generation == prefilterGeneration else {
                lock.unlock()
                return
            }

            prefilterInFlightValue = false
            lastPrefilterDurationMsValue = durationMs

            guard succeeded, textureSets.indices.contains(textureSetIndex) else {
                fallbackReasonValue = "XR probe prefilter failed"
                lock.unlock()
                RuntimeEnvironmentLightingStore.shared.publishXRLighting(nil)
                return
            }

            currentReadTextureSetIndex = textureSetIndex
            let textureSet = textureSets[textureSetIndex]
            latestTintColorValue = tintColor
            fallbackReasonValue = nil

            // Smooth the published intensity/tint so auto-exposure steps in the raw
            // probe estimate don't pop every real-world-tinted light in the scene.
            // Diagnostics keep the raw values; only the published lighting is smoothed.
            var publishedIntensityScale = intensityScale
            var publishedTintColor = tintColor
            if let previousScale = smoothedIntensityScaleValue,
               let previousTimestamp = lastSmoothedLightingTimestamp,
               lightingSmoothingTimeConstant > 0.0
            {
                let deltaTime = min(max(timestamp - previousTimestamp, 0.0), 10.0)
                let alpha = Float(1.0 - exp(-deltaTime / lightingSmoothingTimeConstant))
                publishedIntensityScale = previousScale + (intensityScale - previousScale) * alpha
                publishedTintColor = smoothedTintColorValue + (tintColor - smoothedTintColorValue) * alpha
            }
            smoothedIntensityScaleValue = publishedIntensityScale
            smoothedTintColorValue = publishedTintColor
            lastSmoothedLightingTimestamp = timestamp
            lock.unlock()

            RuntimeEnvironmentLightingStore.shared.publishXRLighting(
                RuntimeEnvironmentLighting(
                    irradianceMap: textureSet.irradianceMap,
                    specularMap: textureSet.specularMap,
                    brdfMap: textureSet.brdfMap,
                    intensityScale: publishedIntensityScale,
                    tintColor: publishedTintColor,
                    timestamp: timestamp,
                    isValid: true
                )
            )
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

            let intensityScale = min(max(cameraScaleReference / cameraScaleReferenceWhitePoint, 0.0), 8.0)
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

        private func scheduleProbePrefilter(
            environmentTexture: MTLTexture,
            timestamp: CFTimeInterval,
            intensityScale: Float,
            retainedAnchor: Any
        ) {
            guard environmentTexture.textureType == .typeCube else {
                publishUnavailableProbe(reason: "XR probe texture is not a cube texture")
                return
            }

            guard let prefilter = beginPrefilterIfPossible() else { return }
            let textureSetIndex = prefilter.textureSetIndex
            let textureSet = prefilter.textureSet
            let generation = prefilter.generation

            guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
                finishPrefilter(
                    succeeded: false,
                    textureSetIndex: textureSetIndex,
                    generation: generation,
                    timestamp: timestamp,
                    intensityScale: intensityScale,
                    tintColor: simd_float3(1.0, 1.0, 1.0),
                    durationMs: 0
                )
                return
            }

            commandBuffer.label = "XR Environment Probe IBL Prefilter"
            let startTime = Date().timeIntervalSinceReferenceDate
            let tintReadback = encodeEnvironmentTintReadback(
                commandBuffer: commandBuffer,
                environmentTexture: environmentTexture
            )
            let encoded = executeXRIBLCubePreFilterPass(
                commandBuffer: commandBuffer,
                environmentCubeTexture: environmentTexture,
                target: textureSet
            )

            guard encoded else {
                finishPrefilter(
                    succeeded: false,
                    textureSetIndex: textureSetIndex,
                    generation: generation,
                    timestamp: timestamp,
                    intensityScale: intensityScale,
                    tintColor: simd_float3(1.0, 1.0, 1.0),
                    durationMs: 0
                )
                return
            }

            commandBuffer.addCompletedHandler { [weak self, retainedAnchor] commandBuffer in
                _ = retainedAnchor
                let durationMs = (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0
                let tintColor = tintReadback.map { self?.environmentTint(from: $0) ?? simd_float3(1.0, 1.0, 1.0) }
                    ?? simd_float3(1.0, 1.0, 1.0)
                self?.finishPrefilter(
                    succeeded: commandBuffer.status == .completed,
                    textureSetIndex: textureSetIndex,
                    generation: generation,
                    timestamp: timestamp,
                    intensityScale: intensityScale,
                    tintColor: tintColor,
                    durationMs: durationMs
                )
            }
            commandBuffer.commit()
        }

        private func encodeEnvironmentTintReadback(
            commandBuffer: MTLCommandBuffer,
            environmentTexture: MTLTexture
        ) -> EnvironmentTintReadback? {
            guard let bytesPerPixel = environmentTintBytesPerPixel(for: environmentTexture.pixelFormat),
                  let blit = commandBuffer.makeBlitCommandEncoder()
            else { return nil }

            let mipLevel = max(environmentTexture.mipmapLevelCount - 1, 0)
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

            for face in 0 ..< readback.faceCount {
                let faceBase = face * readback.faceBytes
                for y in 0 ..< readback.height {
                    let rowBase = faceBase + y * readback.bytesPerRow
                    for x in 0 ..< readback.width {
                        let offset = rowBase + x * environmentTintBytesPerPixel(for: readback.pixelFormat)!
                        total += environmentTintPixel(contents: contents, offset: offset, pixelFormat: readback.pixelFormat)
                        sampleCount += 1.0
                    }
                }
            }

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
                fallbackReason: fallbackReasonValue
            )
            lock.unlock()
            return diagnostics
        }
    }
#endif
