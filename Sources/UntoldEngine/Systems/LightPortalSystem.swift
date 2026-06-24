//
//  LightPortalSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct LightPortalCandidate: Sendable {
    public let entityId: EntityID
    public let channels: SceneChannel
    public let mode: SceneChannelLightPortalMode
    public let worldTransform: simd_float4x4
    public let localBoundsMin: simd_float3
    public let localBoundsMax: simd_float3
}

public struct LightPortalDiscoveryDiagnostics: Equatable, Sendable {
    public var scannedRenderableEntityCount: Int
    public var candidateCount: Int
    public var skippedHiddenCount: Int
    public var skippedInvisibleRenderComponentCount: Int
    public var skippedDisabledPortalCount: Int
    public var skippedInvalidGeometryCount: Int

    public static let empty = LightPortalDiscoveryDiagnostics(
        scannedRenderableEntityCount: 0,
        candidateCount: 0,
        skippedHiddenCount: 0,
        skippedInvisibleRenderComponentCount: 0,
        skippedDisabledPortalCount: 0,
        skippedInvalidGeometryCount: 0
    )
}

public struct LightPortalProxyLight: Equatable, Sendable {
    public let sourceEntityId: EntityID
    public let channels: SceneChannel
    public let position: simd_float3
    public let forward: simd_float3
    public let right: simd_float3
    public let up: simd_float3
    public let bounds: simd_float2
    public let color: simd_float3
    public let intensity: Float
    public let range: Float
    public let distanceToCamera: Float
    public let useRealWorldTint: Bool
}

public struct LightPortalResolutionDiagnostics: Equatable, Sendable {
    public var discoveredCandidateCount: Int
    public var activePortalCount: Int
    public var skippedByActivationDistanceCount: Int
    public var maxActivePortals: Int

    public static let empty = LightPortalResolutionDiagnostics(
        discoveredCandidateCount: 0,
        activePortalCount: 0,
        skippedByActivationDistanceCount: 0,
        maxActivePortals: 0
    )
}

public struct LightPortalPerformanceDiagnostics: Equatable, Sendable {
    public var lastDiscoveryDurationMs: Double?
    public var lastResolutionDurationMs: Double?
    public var lastScannedRenderableEntityCount: Int
    public var lastDiscoveredCandidateCount: Int
    public var lastResolvedProxyLightCount: Int

    public static let empty = LightPortalPerformanceDiagnostics(
        lastDiscoveryDurationMs: nil,
        lastResolutionDurationMs: nil,
        lastScannedRenderableEntityCount: 0,
        lastDiscoveredCandidateCount: 0,
        lastResolvedProxyLightCount: 0
    )
}

public final class LightPortalSystem: @unchecked Sendable {
    public static let shared = LightPortalSystem()

    private let minimumPortalSurfaceDimension: Float = 0.01
    private let maximumPortalThicknessFraction: Float = 0.25
    private let lock = NSLock()
    private var lastDiagnostics: LightPortalDiscoveryDiagnostics = .empty
    private var lastResolutionDiagnostics: LightPortalResolutionDiagnostics = .empty
    private var lastPerformanceDiagnostics: LightPortalPerformanceDiagnostics = .empty
    private var lastDiagnosticsLogTime: Double = 0

    private init() {}

    public func discoverCandidates() -> [LightPortalCandidate] {
        let startTime = Date().timeIntervalSinceReferenceDate
        guard hasSceneChannelLightPortalsEnabled() else {
            setDiagnostics(.empty)
            setPerformanceDiagnostics(.empty)
            return []
        }

        let renderComponentId = getComponentId(for: RenderComponent.self)
        let worldTransformComponentId = getComponentId(for: WorldTransformComponent.self)
        let localTransformComponentId = getComponentId(for: LocalTransformComponent.self)
        let entityIds = queryEntitiesWithComponentIds(
            [renderComponentId, worldTransformComponentId, localTransformComponentId],
            in: scene
        ).sorted()

        var candidates: [LightPortalCandidate] = []
        var diagnostics = LightPortalDiscoveryDiagnostics.empty
        diagnostics.scannedRenderableEntityCount = entityIds.count

        for entityId in entityIds {
            guard let renderComponent = scene.get(component: RenderComponent.self, for: entityId) else {
                continue
            }

            if renderComponent.isVisible == false {
                diagnostics.skippedInvisibleRenderComponentCount += 1
                continue
            }

            if shouldHideSceneEntity(entityId: entityId) {
                diagnostics.skippedHiddenCount += 1
                continue
            }

            let channels = getEntitySceneChannels(entityId: entityId)
            let mode = sceneChannelLightPortalMode(for: channels)
            guard case .enabled = mode else {
                diagnostics.skippedDisabledPortalCount += 1
                continue
            }

            guard let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
            else {
                continue
            }

            guard isValidPortalGeometry(localBoundsMin: localTransform.boundingBox.min, localBoundsMax: localTransform.boundingBox.max) else {
                diagnostics.skippedInvalidGeometryCount += 1
                continue
            }

            candidates.append(
                LightPortalCandidate(
                    entityId: entityId,
                    channels: channels,
                    mode: mode,
                    worldTransform: worldTransform.space,
                    localBoundsMin: localTransform.boundingBox.min,
                    localBoundsMax: localTransform.boundingBox.max
                )
            )
        }

        diagnostics.candidateCount = candidates.count
        setDiagnostics(diagnostics)
        updatePerformanceDiagnostics { performance in
            performance.lastDiscoveryDurationMs = Self.elapsedMilliseconds(since: startTime)
            performance.lastScannedRenderableEntityCount = diagnostics.scannedRenderableEntityCount
            performance.lastDiscoveredCandidateCount = diagnostics.candidateCount
        }
        return candidates
    }

    public func resolveProxyLights(cameraPosition: simd_float3) -> [LightPortalProxyLight] {
        let candidates = discoverCandidates()
        let resolved = resolveProxyLights(from: candidates, cameraPosition: cameraPosition)
        setResolutionDiagnostics(resolved.diagnostics)
        return resolved.proxyLights
    }

    public func resolveProxyLightsForActiveCamera() -> [LightPortalProxyLight] {
        guard let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            let candidates = discoverCandidates()
            let resolved = resolveProxyLights(from: candidates, cameraPosition: nil)
            setResolutionDiagnostics(resolved.diagnostics)
            return resolved.proxyLights
        }

        return resolveProxyLights(cameraPosition: SceneRootTransform.shared.effectiveCameraPosition(cameraComponent.localPosition))
    }

    public func discoveryDiagnostics() -> LightPortalDiscoveryDiagnostics {
        lock.lock()
        let diagnostics = lastDiagnostics
        lock.unlock()
        return diagnostics
    }

    public func resolutionDiagnostics() -> LightPortalResolutionDiagnostics {
        lock.lock()
        let diagnostics = lastResolutionDiagnostics
        lock.unlock()
        return diagnostics
    }

    public func performanceDiagnostics() -> LightPortalPerformanceDiagnostics {
        lock.lock()
        let diagnostics = lastPerformanceDiagnostics
        lock.unlock()
        return diagnostics
    }

    func resetDiagnostics() {
        setDiagnostics(.empty)
        setResolutionDiagnostics(.empty)
        setPerformanceDiagnostics(.empty)
        lock.lock()
        lastDiagnosticsLogTime = 0
        lock.unlock()
    }

    /// Logs light portal diagnostics at most once per `interval` seconds.
    ///
    /// No-op when the LightPortal log category is disabled. Enable with
    /// `setLogger(.category(.lightPortal, true))`.
    public func logDiagnosticsIfDue(interval: Double = 1.0) {
        guard Logger.isEnabled(category: .lightPortal) else { return }
        let now = CFAbsoluteTimeGetCurrent()
        lock.lock()
        guard now - lastDiagnosticsLogTime >= interval else {
            lock.unlock()
            return
        }
        lastDiagnosticsLogTime = now
        let discovery = lastDiagnostics
        let resolution = lastResolutionDiagnostics
        let performance = lastPerformanceDiagnostics
        lock.unlock()

        emitDiagnostics(discovery: discovery, resolution: resolution, performance: performance)
    }

    /// Emits light portal diagnostics immediately, bypassing the rate-limit timer.
    ///
    /// No-op when the LightPortal log category is disabled.
    public func logDiagnosticsNow() {
        guard Logger.isEnabled(category: .lightPortal) else { return }
        lock.lock()
        lastDiagnosticsLogTime = CFAbsoluteTimeGetCurrent()
        let discovery = lastDiagnostics
        let resolution = lastResolutionDiagnostics
        let performance = lastPerformanceDiagnostics
        lock.unlock()

        emitDiagnostics(discovery: discovery, resolution: resolution, performance: performance)
    }

    private func setDiagnostics(_ diagnostics: LightPortalDiscoveryDiagnostics) {
        lock.lock()
        lastDiagnostics = diagnostics
        lock.unlock()
    }

    private func setResolutionDiagnostics(_ diagnostics: LightPortalResolutionDiagnostics) {
        lock.lock()
        lastResolutionDiagnostics = diagnostics
        lock.unlock()
    }

    private func setPerformanceDiagnostics(_ diagnostics: LightPortalPerformanceDiagnostics) {
        lock.lock()
        lastPerformanceDiagnostics = diagnostics
        lock.unlock()
    }

    private func updatePerformanceDiagnostics(_ update: (inout LightPortalPerformanceDiagnostics) -> Void) {
        lock.lock()
        update(&lastPerformanceDiagnostics)
        lock.unlock()
    }

    private func emitDiagnostics(
        discovery: LightPortalDiscoveryDiagnostics,
        resolution: LightPortalResolutionDiagnostics,
        performance: LightPortalPerformanceDiagnostics
    ) {
        let render = getLightPortalRenderDiagnostics()
        Logger.log(
            message: "[LightPortal] scanned=\(discovery.scannedRenderableEntityCount)"
                + " candidates=\(discovery.candidateCount)"
                + " active=\(resolution.activePortalCount)/\(resolution.maxActivePortals)"
                + " portalLights=\(render.portalAreaLightCount)"
                + " authoredAreaLights=\(render.authoredAreaLightCount)"
                + " remainingAreaLightCapacity=\(render.remainingAreaLightCapacity)",
            category: LogCategory.lightPortal.rawValue
        )
        Logger.log(
            message: "[LightPortal] discoveryMs=\(Self.formattedMilliseconds(performance.lastDiscoveryDurationMs))"
                + " resolutionMs=\(Self.formattedMilliseconds(performance.lastResolutionDurationMs))"
                + " skippedHidden=\(discovery.skippedHiddenCount)"
                + " skippedInvisible=\(discovery.skippedInvisibleRenderComponentCount)"
                + " skippedDisabled=\(discovery.skippedDisabledPortalCount)"
                + " skippedInvalidGeometry=\(discovery.skippedInvalidGeometryCount)"
                + " skippedByDistance=\(resolution.skippedByActivationDistanceCount)",
            category: LogCategory.lightPortal.rawValue
        )
        Logger.log(
            message: "[LightPortal] envScale=\(String(format: "%.3f", render.environmentIntensityScale))"
                + " contribution=\(String(format: "%.3f", render.realWorldLightingContribution))"
                + " xrValid=\(render.xrLightingValid)"
                + " intensityMax=\(Self.formattedFloat(render.maxEffectivePortalIntensity))"
                + " fallback=\(render.fallbackReason ?? "none")",
            category: LogCategory.lightPortal.rawValue
        )
    }

    private func resolveProxyLights(
        from candidates: [LightPortalCandidate],
        cameraPosition: simd_float3?
    ) -> (proxyLights: [LightPortalProxyLight], diagnostics: LightPortalResolutionDiagnostics) {
        let startTime = Date().timeIntervalSinceReferenceDate
        var diagnostics = LightPortalResolutionDiagnostics.empty
        diagnostics.discoveredCandidateCount = candidates.count

        defer {
            updatePerformanceDiagnostics { performance in
                performance.lastResolutionDurationMs = Self.elapsedMilliseconds(since: startTime)
                performance.lastDiscoveredCandidateCount = diagnostics.discoveredCandidateCount
                performance.lastResolvedProxyLightCount = diagnostics.activePortalCount
            }
        }

        var maxActivePortals = 0
        var activeChannelCapsByRawValue: [UInt64: Int] = [:]
        var resolvedProxyLights: [LightPortalProxyLight] = []
        var channelRawValuesByEntityId: [EntityID: [UInt64]] = [:]

        for candidate in candidates {
            guard case let .enabled(
                intensity,
                range,
                useRealWorldTint,
                candidateMaxActivePortals,
                activationDistance
            ) = candidate.mode else {
                continue
            }

            maxActivePortals = max(maxActivePortals, candidateMaxActivePortals)
            let portalChannelRawValues = enabledLightPortalRawChannelValues(in: candidate.channels)
            channelRawValuesByEntityId[candidate.entityId] = portalChannelRawValues
            for rawValue in portalChannelRawValues {
                let channel = SceneChannel(rawValue: rawValue)
                if case let .enabled(_, _, _, channelMaxActivePortals, _) = getSceneChannelLightPortalMode(channel) {
                    activeChannelCapsByRawValue[rawValue] = channelMaxActivePortals
                }
            }

            let position = portalCenter(candidate)
            let frame = portalFrame(candidate)
            let distanceToCamera: Float
            if let cameraPosition {
                distanceToCamera = distanceToPortalRectangle(cameraPosition, center: position, frame: frame)
                if distanceToCamera > activationDistance {
                    diagnostics.skippedByActivationDistanceCount += 1
                    continue
                }
            } else {
                distanceToCamera = 0.0
            }

            resolvedProxyLights.append(
                LightPortalProxyLight(
                    sourceEntityId: candidate.entityId,
                    channels: candidate.channels,
                    position: position,
                    forward: frame.forward,
                    right: frame.right,
                    up: frame.up,
                    bounds: frame.bounds,
                    color: simd_float3(1.0, 1.0, 1.0),
                    intensity: intensity,
                    range: range,
                    distanceToCamera: distanceToCamera,
                    useRealWorldTint: useRealWorldTint
                )
            )
        }

        resolvedProxyLights.sort {
            if $0.distanceToCamera == $1.distanceToCamera {
                return $0.sourceEntityId < $1.sourceEntityId
            }
            return $0.distanceToCamera < $1.distanceToCamera
        }

        diagnostics.maxActivePortals = maxActivePortals
        if maxActivePortals <= 0 {
            diagnostics.activePortalCount = 0
            return ([], diagnostics)
        }

        var selectedProxyLights: [LightPortalProxyLight] = []
        var activeCountsByRawValue: [UInt64: Int] = [:]
        for proxyLight in resolvedProxyLights {
            let rawValues = channelRawValuesByEntityId[proxyLight.sourceEntityId] ?? []
            let cappedRawValues = rawValues.filter { activeChannelCapsByRawValue[$0] != nil }

            if cappedRawValues.isEmpty {
                if selectedProxyLights.count >= maxActivePortals {
                    continue
                }
            } else {
                let hasRemainingChannelCapacity = cappedRawValues.allSatisfy { rawValue in
                    let cap = activeChannelCapsByRawValue[rawValue] ?? 0
                    return (activeCountsByRawValue[rawValue] ?? 0) < cap
                }
                guard hasRemainingChannelCapacity else { continue }
            }

            selectedProxyLights.append(proxyLight)
            for rawValue in cappedRawValues {
                activeCountsByRawValue[rawValue, default: 0] += 1
            }
        }
        diagnostics.activePortalCount = selectedProxyLights.count
        return (selectedProxyLights, diagnostics)
    }

    private static func elapsedMilliseconds(since startTime: TimeInterval) -> Double {
        (Date().timeIntervalSinceReferenceDate - startTime) * 1000.0
    }

    private static func formattedMilliseconds(_ value: Double?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.3f", value)
    }

    private static func formattedFloat(_ value: Float?) -> String {
        guard let value else { return "n/a" }
        return String(format: "%.3f", value)
    }

    private func portalCenter(_ candidate: LightPortalCandidate) -> simd_float3 {
        let localCenter = (candidate.localBoundsMin + candidate.localBoundsMax) * 0.5
        let worldCenter = simd_mul(candidate.worldTransform, simd_float4(localCenter, 1.0))
        return simd_float3(worldCenter.x, worldCenter.y, worldCenter.z)
    }

    private struct PortalFrame {
        var forward: simd_float3
        var right: simd_float3
        var up: simd_float3
        var bounds: simd_float2
    }

    private struct PortalAxis {
        var index: Int
        var localSize: Float
    }

    private func portalFrame(_ candidate: LightPortalCandidate) -> PortalFrame {
        let localSize = abs(candidate.localBoundsMax - candidate.localBoundsMin)
        let axes = [
            PortalAxis(index: 0, localSize: localSize.x),
            PortalAxis(index: 1, localSize: localSize.y),
            PortalAxis(index: 2, localSize: localSize.z),
        ].sorted {
            if $0.localSize == $1.localSize {
                return $0.index < $1.index
            }
            return $0.localSize > $1.localSize
        }

        let rightAxis = axes[0].index
        let upAxis = axes[1].index
        let normalAxis = axes[2].index

        let rightWorld = worldAxis(candidate.worldTransform, axis: rightAxis)
        let upWorld = worldAxis(candidate.worldTransform, axis: upAxis)
        let forwardWorld = worldAxis(candidate.worldTransform, axis: normalAxis)

        return PortalFrame(
            forward: normalizedAxis(forwardWorld, fallback: simd_float3(0.0, 0.0, 1.0)),
            right: normalizedAxis(rightWorld, fallback: simd_float3(1.0, 0.0, 0.0)),
            up: normalizedAxis(upWorld, fallback: simd_float3(0.0, 1.0, 0.0)),
            bounds: simd_float2(
                max(localSizeForAxis(localSize, axis: rightAxis) * simd_length(rightWorld), 0.001),
                max(localSizeForAxis(localSize, axis: upAxis) * simd_length(upWorld), 0.001)
            )
        )
    }

    private func isValidPortalGeometry(localBoundsMin: simd_float3, localBoundsMax: simd_float3) -> Bool {
        let localSize = abs(localBoundsMax - localBoundsMin)
        guard localSize.x.isFinite, localSize.y.isFinite, localSize.z.isFinite else {
            return false
        }

        let sortedSizes = [localSize.x, localSize.y, localSize.z].sorted(by: >)
        guard sortedSizes[0] >= minimumPortalSurfaceDimension,
              sortedSizes[1] >= minimumPortalSurfaceDimension
        else {
            return false
        }

        let thickness = sortedSizes[2]
        return thickness <= sortedSizes[1] * maximumPortalThicknessFraction
    }

    private func enabledLightPortalRawChannelValues(in channels: SceneChannel) -> [UInt64] {
        rawChannelValues(in: channels).filter { rawValue in
            let channel = SceneChannel(rawValue: rawValue)
            if case .enabled = getSceneChannelLightPortalMode(channel) {
                return true
            }
            return false
        }
    }

    private func rawChannelValues(in channels: SceneChannel) -> [UInt64] {
        var values: [UInt64] = []
        var remaining = channels.rawValue
        while remaining != 0 {
            let rawValue = remaining & (~remaining &+ 1)
            values.append(rawValue)
            remaining &= ~rawValue
        }
        return values
    }

    private func distanceToPortalRectangle(_ point: simd_float3, center: simd_float3, frame: PortalFrame) -> Float {
        let toPoint = point - center
        let planeDistance = abs(simd_dot(toPoint, frame.forward))
        let rectangleDistance = abs(simd_float2(simd_dot(toPoint, frame.right), simd_dot(toPoint, frame.up))) - frame.bounds * 0.5
        let edgeDistance = simd_length(max(rectangleDistance, simd_float2.zero))
        return simd_length(simd_float2(planeDistance, edgeDistance))
    }

    private func worldAxis(_ transform: simd_float4x4, axis: Int) -> simd_float3 {
        switch axis {
        case 0:
            return simd_float3(transform.columns.0.x, transform.columns.0.y, transform.columns.0.z)
        case 1:
            return simd_float3(transform.columns.1.x, transform.columns.1.y, transform.columns.1.z)
        default:
            return simd_float3(transform.columns.2.x, transform.columns.2.y, transform.columns.2.z)
        }
    }

    private func localSizeForAxis(_ localSize: simd_float3, axis: Int) -> Float {
        switch axis {
        case 0:
            return localSize.x
        case 1:
            return localSize.y
        default:
            return localSize.z
        }
    }

    private func normalizedAxis(_ value: simd_float3, fallback: simd_float3) -> simd_float3 {
        let lengthSquared = simd_length_squared(value)
        guard lengthSquared > 0.000001, lengthSquared.isFinite else {
            return fallback
        }
        return simd_normalize(value)
    }
}

public func discoverSceneLightPortalCandidates() -> [LightPortalCandidate] {
    LightPortalSystem.shared.discoverCandidates()
}

public func getLightPortalDiscoveryDiagnostics() -> LightPortalDiscoveryDiagnostics {
    LightPortalSystem.shared.discoveryDiagnostics()
}

public func resolveSceneLightPortalProxyLights(cameraPosition: simd_float3) -> [LightPortalProxyLight] {
    LightPortalSystem.shared.resolveProxyLights(cameraPosition: cameraPosition)
}

public func resolveSceneLightPortalProxyLightsForActiveCamera() -> [LightPortalProxyLight] {
    LightPortalSystem.shared.resolveProxyLightsForActiveCamera()
}

public func getLightPortalResolutionDiagnostics() -> LightPortalResolutionDiagnostics {
    LightPortalSystem.shared.resolutionDiagnostics()
}

public func getLightPortalPerformanceDiagnostics() -> LightPortalPerformanceDiagnostics {
    LightPortalSystem.shared.performanceDiagnostics()
}
