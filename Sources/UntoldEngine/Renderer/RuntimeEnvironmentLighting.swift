//
//  RuntimeEnvironmentLighting.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import simd

public enum RuntimeEnvironmentLightingMode: Sendable, Equatable {
    case authoredOnly
    case staticIBL
    case realWorldEstimate
}

public struct RuntimeEnvironmentLighting {
    public var irradianceMap: MTLTexture?
    public var specularMap: MTLTexture?
    public var brdfMap: MTLTexture?
    public var intensityScale: Float
    public var tintColor: simd_float3
    public var timestamp: CFTimeInterval
    public var isValid: Bool

    public init(
        irradianceMap: MTLTexture?,
        specularMap: MTLTexture?,
        brdfMap: MTLTexture?,
        intensityScale: Float = 1.0,
        tintColor: simd_float3 = simd_float3(1.0, 1.0, 1.0),
        timestamp: CFTimeInterval = Date().timeIntervalSinceReferenceDate,
        isValid: Bool
    ) {
        self.irradianceMap = irradianceMap
        self.specularMap = specularMap
        self.brdfMap = brdfMap
        self.intensityScale = intensityScale
        self.tintColor = tintColor
        self.timestamp = timestamp
        self.isValid = isValid
    }
}

func resolveCurrentEnvironmentLighting() -> ResolvedEnvironmentLighting {
    RuntimeEnvironmentLightingStore.shared.resolve(
        staticIrradianceMap: textureResources.irradianceMap,
        staticSpecularMap: textureResources.specularMap,
        staticBRDFMap: textureResources.iblBRDFMap,
        staticIBLEnabled: applyIBL,
        ambientIntensity: ambientIntensity
    )
}

public struct RuntimeEnvironmentLightingTextureSet {
    public var irradianceMap: MTLTexture
    public var specularMap: MTLTexture
    public var brdfMap: MTLTexture
}

public struct ResolvedEnvironmentLighting {
    public var irradianceMap: MTLTexture?
    public var specularMap: MTLTexture?
    public var brdfMap: MTLTexture?
    public var applyIBL: Bool
    public var ambientIntensity: Float
    public var mode: RuntimeEnvironmentLightingMode
    public var fallbackReason: String?
}

public func makeRuntimeEnvironmentLightingTextureSet(labelPrefix: String) -> RuntimeEnvironmentLightingTextureSet? {
    let currentRenderInfo = renderInfo
    let wf = currentRenderInfo.colorPipeline.working
    let iblSize = 256

    guard let irradianceMap = createTexture(
        device: currentRenderInfo.device,
        label: "\(labelPrefix) Irradiance Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    ) else { return nil }

    guard let specularMap = createTexture(
        device: currentRenderInfo.device,
        label: "\(labelPrefix) Specular Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private,
        mipMapLevels: 6
    ) else { return nil }

    guard let brdfMap = createTexture(
        device: currentRenderInfo.device,
        label: "\(labelPrefix) BRDF Texture",
        pixelFormat: wf.ibl,
        width: iblSize,
        height: iblSize,
        usage: [.shaderRead, .renderTarget],
        storageMode: .private
    ) else { return nil }

    return RuntimeEnvironmentLightingTextureSet(
        irradianceMap: irradianceMap,
        specularMap: specularMap,
        brdfMap: brdfMap
    )
}

public final class RuntimeEnvironmentLightingStore: @unchecked Sendable {
    public static let shared = RuntimeEnvironmentLightingStore()

    private let lock = NSLock()
    private var modeValue: RuntimeEnvironmentLightingMode = .staticIBL
    private var realWorldLightingContributionValue: Float = 1.0
    private var xrLightingValue: RuntimeEnvironmentLighting?
    private var modeObservers: [UUID: @Sendable (RuntimeEnvironmentLightingMode) -> Void] = [:]

    private init() {}

    public var mode: RuntimeEnvironmentLightingMode {
        get {
            lock.lock()
            let value = modeValue
            lock.unlock()
            return value
        }
        set {
            setMode(newValue)
        }
    }

    public func setMode(_ mode: RuntimeEnvironmentLightingMode, notifyIfUnchanged: Bool = false) {
        lock.lock()
        let oldMode = modeValue
        modeValue = mode
        let shouldNotify = notifyIfUnchanged || oldMode != mode
        let observers = shouldNotify ? Array(modeObservers.values) : []
        lock.unlock()

        resetLightPortalAreaLightCache()

        for observer in observers {
            observer(mode)
        }
    }

    @discardableResult
    public func observeLightingModeChanges(
        _ observer: @escaping @Sendable (RuntimeEnvironmentLightingMode) -> Void
    ) -> UUID {
        let id = UUID()
        lock.lock()
        modeObservers[id] = observer
        lock.unlock()
        return id
    }

    public func removeLightingModeChangeObserver(_ id: UUID) {
        lock.lock()
        modeObservers.removeValue(forKey: id)
        lock.unlock()
    }

    public var realWorldLightingContribution: Float {
        get {
            lock.lock()
            let value = realWorldLightingContributionValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            realWorldLightingContributionValue = Self.sanitizedContribution(newValue)
            lock.unlock()
            resetLightPortalAreaLightCache()
        }
    }

    public func publishXRLighting(_ lighting: RuntimeEnvironmentLighting?) {
        lock.lock()
        xrLightingValue = lighting
        lock.unlock()
        resetLightPortalAreaLightCache()
    }

    public func latestXRLighting() -> RuntimeEnvironmentLighting? {
        lock.lock()
        let value = xrLightingValue
        lock.unlock()
        return value
    }

    public func reset() {
        lock.lock()
        let oldMode = modeValue
        modeValue = .staticIBL
        realWorldLightingContributionValue = 1.0
        xrLightingValue = nil
        let observers = oldMode == .staticIBL ? [] : Array(modeObservers.values)
        lock.unlock()

        resetLightPortalAreaLightCache()

        for observer in observers {
            observer(.staticIBL)
        }
    }

    public func resolve(
        staticIrradianceMap: MTLTexture?,
        staticSpecularMap: MTLTexture?,
        staticBRDFMap: MTLTexture?,
        staticIBLEnabled: Bool,
        ambientIntensity: Float
    ) -> ResolvedEnvironmentLighting {
        lock.lock()
        let currentMode = modeValue
        let realWorldLightingContribution = realWorldLightingContributionValue
        let xrLighting = xrLightingValue
        lock.unlock()

        let staticLighting = ResolvedEnvironmentLighting(
            irradianceMap: staticIrradianceMap,
            specularMap: staticSpecularMap,
            brdfMap: staticBRDFMap,
            applyIBL: staticIBLEnabled,
            ambientIntensity: ambientIntensity,
            mode: .staticIBL,
            fallbackReason: nil
        )

        switch currentMode {
        case .authoredOnly:
            return ResolvedEnvironmentLighting(
                irradianceMap: staticIrradianceMap,
                specularMap: staticSpecularMap,
                brdfMap: staticBRDFMap,
                applyIBL: false,
                ambientIntensity: ambientIntensity,
                mode: .authoredOnly,
                fallbackReason: nil
            )

        case .staticIBL:
            return staticLighting

        case .realWorldEstimate:
            guard let xrLighting,
                  xrLighting.isValid,
                  let irradianceMap = xrLighting.irradianceMap,
                  let specularMap = xrLighting.specularMap,
                  let brdfMap = xrLighting.brdfMap
            else {
                var fallback = staticLighting
                fallback.fallbackReason = "XR lighting unavailable"
                return fallback
            }

            return ResolvedEnvironmentLighting(
                irradianceMap: irradianceMap,
                specularMap: specularMap,
                brdfMap: brdfMap,
                applyIBL: true,
                ambientIntensity: ambientIntensity * xrLighting.intensityScale * realWorldLightingContribution,
                mode: currentMode,
                fallbackReason: nil
            )
        }
    }

    private static func sanitizedContribution(_ value: Float) -> Float {
        guard value.isFinite else { return 1.0 }
        return max(value, 0.0)
    }
}
