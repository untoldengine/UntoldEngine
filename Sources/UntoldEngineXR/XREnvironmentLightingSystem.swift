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
        public var prefilterInFlight: Bool
        public var lastPrefilterDurationMs: Double?
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

        #if canImport(ARKit)
            private let environmentLightEstimationProvider: EnvironmentLightEstimationProvider?
        #endif

        public var minimumProbeUpdateInterval: CFTimeInterval = 0.5

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
                environmentLightEstimationProvider != nil
            #else
                false
            #endif
        }

        #if canImport(ARKit)
            public var providerForSession: (any DataProvider)? {
                guard enabled, let environmentLightEstimationProvider else { return nil }
                return environmentLightEstimationProvider
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
                providerRunningValue = false
                prefilterInFlightValue = false
                lastPrefilterDurationMsValue = nil
                lastAcceptedProbeUpdateTime = 0
                prefilterGeneration &+= 1
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
        }

        #if canImport(ARKit)
            private func startProbeMonitor() {
                guard probeMonitorTask == nil else { return }
                guard let provider = environmentLightEstimationProvider else {
                    publishUnavailableProbe(reason: "Environment light estimation unsupported")
                    return
                }

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
                    lock.lock()
                    latestProbeTextureValidValue = hasTexture
                    latestCameraScaleReferenceValue = anchor.cameraScaleReference
                    if !hasTexture {
                        fallbackReasonValue = "XR probe texture unavailable"
                    }
                    lock.unlock()

                    if let environmentTexture = anchor.environmentTexture {
                        scheduleProbePrefilter(
                            environmentTexture: environmentTexture,
                            timestamp: anchor.timestamp,
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
                return
            }

            currentReadTextureSetIndex = textureSetIndex
            let textureSet = textureSets[textureSetIndex]
            fallbackReasonValue = nil
            lock.unlock()

            RuntimeEnvironmentLightingStore.shared.publishXRLighting(
                RuntimeEnvironmentLighting(
                    irradianceMap: textureSet.irradianceMap,
                    specularMap: textureSet.specularMap,
                    brdfMap: textureSet.brdfMap,
                    intensityScale: 1.0,
                    timestamp: timestamp,
                    isValid: true
                )
            )
        }

        private func scheduleProbePrefilter(
            environmentTexture: MTLTexture,
            timestamp: CFTimeInterval,
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
                    durationMs: 0
                )
                return
            }

            commandBuffer.label = "XR Environment Probe IBL Prefilter"
            let startTime = Date().timeIntervalSinceReferenceDate
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
                    durationMs: 0
                )
                return
            }

            commandBuffer.addCompletedHandler { [weak self, retainedAnchor] commandBuffer in
                _ = retainedAnchor
                let durationMs = (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0
                self?.finishPrefilter(
                    succeeded: commandBuffer.status == .completed,
                    textureSetIndex: textureSetIndex,
                    generation: generation,
                    timestamp: timestamp,
                    durationMs: durationMs
                )
            }
            commandBuffer.commit()
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
                prefilterInFlight: prefilterInFlightValue,
                lastPrefilterDurationMs: lastPrefilterDurationMsValue,
                acceptedProbeUpdateCount: acceptedProbeUpdateCountValue,
                skippedProbeUpdateCount: skippedProbeUpdateCountValue,
                fallbackReason: fallbackReasonValue
            )
            lock.unlock()
            return diagnostics
        }
    }
#endif
