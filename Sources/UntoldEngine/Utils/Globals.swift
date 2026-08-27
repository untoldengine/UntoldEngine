
//
//  Globals.swift
//  UntoldEngine3D
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit
import simd

// Asset ID
public typealias EntityID = UInt64
public typealias EntityIndex = UInt32
public typealias EntityVersion = UInt32

public extension EntityID {
    static let invalid: EntityID = .max
}

let MAX_COMPONENTS = 128
let MAX_ENTITIES = 20000

let maxNumPointLights: Int = 100
let maxNumSpotLights: Int = 100
let maxAreaLights: Int = 100

private final class CoreRuntimeGlobals: @unchecked Sendable {
    static let shared = CoreRuntimeGlobals()

    let lock = NSRecursiveLock()
    var scene = Scene()
    var shadowSystem: ShadowSystem!
    var pointShadowState: PointShadowState!
    var spotShadowState: SpotShadowState!
    var renderInfo = RenderInfo()
    var vertexDescriptor = VertexDescriptors()
    var bufferResources = BufferResources()
    var tripleBufferResources = TripleBufferResources()
    var textureResources = TextureResources()
    var rayTracingPipeline = ComputePipeline()
    var clearRayTracingPipeline = ComputePipeline()
    var frustumCullingPipeline = ComputePipeline()
    var reduceScanMarkVisiblePipeline = ComputePipeline()
    var reduceScanLocalScanPipeline = ComputePipeline()
    var reduceScanBlockScanPipeline = ComputePipeline()
    var reduceScanScatterCompactedPipeline = ComputePipeline()
    var hzbBuildPyramidPipeline = ComputePipeline()
    var hzbOcclusionCullingPipeline = ComputePipeline()
    var gaussianResetVisibleCountPipeline = ComputePipeline()
    var gaussianFrustumCullPipeline = ComputePipeline()
    var gaussianPreprocessPipeline = ComputePipeline()
    var gaussianDepthPipeline = ComputePipeline()
    var radixClearHistogramPipeline = ComputePipeline()
    var radixHistogramPipeline = ComputePipeline()
    var radixScanPerTGPipeline = ComputePipeline()
    var radixScanPipeline = ComputePipeline()
    var radixScatterPipeline = ComputePipeline()
    var radixHistogramBuffer: MTLBuffer?
    var radixPerTGHistBuffer: MTLBuffer?
    var radixSortTempBuffer: MTLBuffer?
    var scenePickingAccelStructResources = AccelStructResources()
    var scenePickingPipeline = ComputePipeline()
    var environmentMesh: MTKMesh!

    private init() {}
}

public var scene: Scene {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.scene
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.scene = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.scene
    }
}

var shadowSystem: ShadowSystem! {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.shadowSystem
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.shadowSystem = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.shadowSystem
    }
}

var pointShadowState: PointShadowState! {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.pointShadowState
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.pointShadowState = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.pointShadowState
    }
}

var spotShadowState: SpotShadowState! {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.spotShadowState
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.spotShadowState = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.spotShadowState
    }
}

public var renderInfo: RenderInfo {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.renderInfo
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.renderInfo = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.renderInfo
    }
}

public var vertexDescriptor: VertexDescriptors {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.vertexDescriptor
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.vertexDescriptor = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.vertexDescriptor
    }
}

public var bufferResources: BufferResources {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.bufferResources
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.bufferResources = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.bufferResources
    }
}

var tripleBufferResources: TripleBufferResources {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.tripleBufferResources
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.tripleBufferResources = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.tripleBufferResources
    }
}

public var textureResources: TextureResources {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.textureResources
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.textureResources = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.textureResources
    }
}

var entityMeshMap: [EntityID: [Mesh]] {
    get { RuntimeGlobalsStore.shared.entityMeshMap }
    set { RuntimeGlobalsStore.shared.entityMeshMap = newValue }
} // Holds all meshes loaded

var entityNameMap: [EntityID: String] {
    get { RuntimeGlobalsStore.shared.entityNameMap }
    set { RuntimeGlobalsStore.shared.entityNameMap = newValue }
} // links entity Id to names

var reverseEntityNameMap: [String: [EntityID]] {
    get { RuntimeGlobalsStore.shared.reverseEntityNameMap }
    set { RuntimeGlobalsStore.shared.reverseEntityNameMap = newValue }
}

/// Timing properties
var timeSinceLastUpdatePreviousTime: TimeInterval! {
    get { RuntimeGlobalsStore.shared.timeSinceLastUpdatePreviousTime }
    set { RuntimeGlobalsStore.shared.timeSinceLastUpdatePreviousTime = newValue }
}

public var timeSinceLastUpdate: Float! {
    get { RuntimeGlobalsStore.shared.timeSinceLastUpdate }
    set { RuntimeGlobalsStore.shared.timeSinceLastUpdate = newValue }
}

var firstUpdateCall: Bool {
    get { RuntimeGlobalsStore.shared.firstUpdateCall }
    set { RuntimeGlobalsStore.shared.firstUpdateCall = newValue }
}

var frameCount: Int {
    get { RuntimeGlobalsStore.shared.frameCount }
    set { RuntimeGlobalsStore.shared.frameCount = newValue }
}

var timePassedSinceLastFrame: Float {
    get { RuntimeGlobalsStore.shared.timePassedSinceLastFrame }
    set { RuntimeGlobalsStore.shared.timePassedSinceLastFrame = newValue }
}

/// Frustum info
public var far: Float {
    get { RuntimeGlobalsStore.shared.cameraFarPlane }
    set { RuntimeGlobalsStore.shared.cameraFarPlane = max(newValue, RuntimeGlobalsStore.shared.cameraNearPlane + 0.001) }
}

public var near: Float {
    get { RuntimeGlobalsStore.shared.cameraNearPlane }
    set { RuntimeGlobalsStore.shared.cameraNearPlane = max(newValue, 0.0001) }
}

public var fov: Float {
    get { RuntimeGlobalsStore.shared.cameraDefaultFOV }
    set { RuntimeGlobalsStore.shared.cameraDefaultFOV = min(max(newValue, 1.0), 179.0) }
}

// Shadow max parameters (legacy single-cascade — kept for reference)
let shadowMaxWidth: Float = 300.0
let shadowMaxHeight: Float = 300.0

// CSM: per-cascade shadow map resolution and cascade count.
// 2 cascades is sufficient for indoor/room-scale scenes and cuts shadow draw calls by ~33%.
// Raise to 3 for outdoor scenes that need a wide far cascade (> 40 m shadow range).
let csmCascadeCount: Int = 2
let shadowResolution: simd_int2 = .init(2048, 2048)

var rayTracingPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.rayTracingPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.rayTracingPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.rayTracingPipeline
    }
}

var clearRayTracingPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.clearRayTracingPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.clearRayTracingPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.clearRayTracingPipeline
    }
}

var frustumCullingPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.frustumCullingPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.frustumCullingPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.frustumCullingPipeline
    }
}

var reduceScanMarkVisiblePipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.reduceScanMarkVisiblePipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.reduceScanMarkVisiblePipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.reduceScanMarkVisiblePipeline
    }
}

var reduceScanLocalScanPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.reduceScanLocalScanPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.reduceScanLocalScanPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.reduceScanLocalScanPipeline
    }
}

var reduceScanBlockScanPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.reduceScanBlockScanPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.reduceScanBlockScanPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.reduceScanBlockScanPipeline
    }
}

var reduceScanScatterCompactedPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.reduceScanScatterCompactedPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.reduceScanScatterCompactedPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.reduceScanScatterCompactedPipeline
    }
}

var hzbBuildPyramidPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.hzbBuildPyramidPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.hzbBuildPyramidPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.hzbBuildPyramidPipeline
    }
}

var hzbOcclusionCullingPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.hzbOcclusionCullingPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.hzbOcclusionCullingPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.hzbOcclusionCullingPipeline
    }
}

var gaussianDepthPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.gaussianDepthPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.gaussianDepthPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.gaussianDepthPipeline
    }
}

var gaussianResetVisibleCountPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.gaussianResetVisibleCountPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.gaussianResetVisibleCountPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.gaussianResetVisibleCountPipeline
    }
}

var gaussianFrustumCullPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.gaussianFrustumCullPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.gaussianFrustumCullPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.gaussianFrustumCullPipeline
    }
}

var gaussianPreprocessPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.gaussianPreprocessPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.gaussianPreprocessPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.gaussianPreprocessPipeline
    }
}

var radixClearHistogramPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixClearHistogramPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixClearHistogramPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.radixClearHistogramPipeline
    }
}

var radixHistogramPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixHistogramPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixHistogramPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.radixHistogramPipeline
    }
}

var radixScanPerTGPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixScanPerTGPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixScanPerTGPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.radixScanPerTGPipeline
    }
}

var radixPerTGHistBuffer: MTLBuffer? {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixPerTGHistBuffer
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixPerTGHistBuffer = newValue
        state.lock.unlock()
    }
}

var radixScanPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixScanPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixScanPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.radixScanPipeline
    }
}

var radixScatterPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixScatterPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixScatterPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.radixScatterPipeline
    }
}

var radixHistogramBuffer: MTLBuffer? {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixHistogramBuffer
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixHistogramBuffer = newValue
        state.lock.unlock()
    }
}

var radixSortTempBuffer: MTLBuffer? {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.radixSortTempBuffer
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.radixSortTempBuffer = newValue
        state.lock.unlock()
    }
}

/// Scene picking
var scenePickingAccelStructResources: AccelStructResources {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.scenePickingAccelStructResources
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.scenePickingAccelStructResources = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.scenePickingAccelStructResources
    }
}

var scenePickingPipeline: ComputePipeline {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.scenePickingPipeline
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.scenePickingPipeline = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.scenePickingPipeline
    }
}

/// Environment Mesh
var environmentMesh: MTKMesh! {
    get {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        return state.environmentMesh
    }
    set {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        state.environmentMesh = newValue
        state.lock.unlock()
    }
    _modify {
        let state = CoreRuntimeGlobals.shared
        state.lock.lock()
        defer { state.lock.unlock() }
        yield &state.environmentMesh
    }
}

private final class RuntimeGlobalsStore: @unchecked Sendable {
    static let shared = RuntimeGlobalsStore()

    private let lock = NSRecursiveLock()
    private var componentCounterValue: Int = 0
    private var globalEntityCounterValue: UInt32 = 0
    private var timeSinceLastUpdatePreviousTimeValue: TimeInterval?
    private var timeSinceLastUpdateValue: Float?
    private var firstUpdateCallValue: Bool = false
    private var frameCountValue: Int = 0
    private var timePassedSinceLastFrameValue: Float = 0.0
    private var envRotationAngleValue: Float = 0.0
    private var currentGlobalTimeValue: Float = 0.0
    private var physicsAccumulatorValue: Float = 0.0
    private var ssaoKernelSizeValue: Int = 64
    private var cullFrameIndexValue: Int = 0
    private var cullSubmitIndexValue: Int = 0
    private var needsFinalizeDestroysValue: Bool = false
    private var hasPendingDestroysValue: Bool = false
    private var visibleEntityIdsValue: [EntityID] = []
    private var scenePickingSystemInitializedValue: Bool = false
    private var scenePickingDirtyEntitiesValue: Set<EntityID> = []
    private var scenePickingGPUAvailableValue: Bool = false
    private var scenePickingIgnoreRayIntersectionWithTransparentsValue: Bool = false
    private var iblSuccessfulValue: Bool = false
    private var gameModeValue: Bool = true
    private var applyIBLValue: Bool = false
    private var renderEnvironmentValue: Bool = false
    private var ambientIntensityValue: Float = 0.4
    private var hdrURLValue: String = "teatro_massimo_2k.hdr"
    private var resourceURLValue: URL?
    private var assetBasePathValue: URL?
    private var activeEntityValue: EntityID = .invalid
    private var enableEngineMetricsValue: Bool = false
    private var bypassPostProcessingValue: Bool = false
    private var antiAliasingModeValue: AntiAliasingMode = .fxaa
    private var renderDebugViewModeValue: RenderDebugViewMode = .lit
    private var pomQualitySettingsValue: POMQualitySettings = .platformDefault
    private var cameraDefaultFOVValue: Float = 65.0
    private var cameraNearPlaneValue: Float = 0.1
    private var cameraFarPlaneValue: Float = 500.0
    private var entityMeshMapValue: [EntityID: [Mesh]] = [:]
    private var entityNameMapValue: [EntityID: String] = [:]
    private var reverseEntityNameMapValue: [String: [EntityID]] = [:]
    private var currentFrameFrustumValue: Frustum?

    private init() {}

    var componentCounter: Int {
        get {
            lock.lock()
            let value = componentCounterValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            componentCounterValue = newValue
            lock.unlock()
        }
    }

    var globalEntityCounter: UInt32 {
        get {
            lock.lock()
            let value = globalEntityCounterValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            globalEntityCounterValue = newValue
            lock.unlock()
        }
    }

    var timeSinceLastUpdatePreviousTime: TimeInterval? {
        get {
            lock.lock()
            let value = timeSinceLastUpdatePreviousTimeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            timeSinceLastUpdatePreviousTimeValue = newValue
            lock.unlock()
        }
    }

    var timeSinceLastUpdate: Float? {
        get {
            lock.lock()
            let value = timeSinceLastUpdateValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            timeSinceLastUpdateValue = newValue
            lock.unlock()
        }
    }

    var firstUpdateCall: Bool {
        get {
            lock.lock()
            let value = firstUpdateCallValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            firstUpdateCallValue = newValue
            lock.unlock()
        }
    }

    var frameCount: Int {
        get {
            lock.lock()
            let value = frameCountValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            frameCountValue = newValue
            lock.unlock()
        }
    }

    var timePassedSinceLastFrame: Float {
        get {
            lock.lock()
            let value = timePassedSinceLastFrameValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            timePassedSinceLastFrameValue = newValue
            lock.unlock()
        }
    }

    var envRotationAngle: Float {
        get {
            lock.lock()
            let value = envRotationAngleValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            envRotationAngleValue = newValue
            lock.unlock()
        }
    }

    var currentGlobalTime: Float {
        get {
            lock.lock()
            let value = currentGlobalTimeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            currentGlobalTimeValue = newValue
            lock.unlock()
        }
    }

    var physicsAccumulator: Float {
        get {
            lock.lock()
            let value = physicsAccumulatorValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            physicsAccumulatorValue = newValue
            lock.unlock()
        }
    }

    var ssaoKernelSize: Int {
        get {
            lock.lock()
            let value = ssaoKernelSizeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            ssaoKernelSizeValue = newValue
            lock.unlock()
        }
    }

    var cullFrameIndex: Int {
        get {
            lock.lock()
            let value = cullFrameIndexValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            cullFrameIndexValue = newValue
            lock.unlock()
        }
    }

    var cullSubmitIndex: Int {
        get {
            lock.lock()
            let value = cullSubmitIndexValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            cullSubmitIndexValue = newValue
            lock.unlock()
        }
    }

    var needsFinalizeDestroys: Bool {
        get {
            lock.lock()
            let value = needsFinalizeDestroysValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            needsFinalizeDestroysValue = newValue
            lock.unlock()
        }
    }

    var hasPendingDestroys: Bool {
        get {
            lock.lock()
            let value = hasPendingDestroysValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            hasPendingDestroysValue = newValue
            lock.unlock()
        }
    }

    var visibleEntityIds: [EntityID] {
        get {
            lock.lock()
            let value = visibleEntityIdsValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            visibleEntityIdsValue = newValue
            lock.unlock()
        }
    }

    var currentFrameFrustum: Frustum? {
        get {
            lock.lock()
            let value = currentFrameFrustumValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            currentFrameFrustumValue = newValue
            lock.unlock()
        }
    }

    var scenePickingSystemInitialized: Bool {
        get {
            lock.lock()
            let value = scenePickingSystemInitializedValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            scenePickingSystemInitializedValue = newValue
            lock.unlock()
        }
    }

    var scenePickingDirtyEntities: Set<EntityID> {
        get {
            lock.lock()
            let value = scenePickingDirtyEntitiesValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            scenePickingDirtyEntitiesValue = newValue
            lock.unlock()
        }
    }

    var scenePickingGPUAvailable: Bool {
        get {
            lock.lock()
            let value = scenePickingGPUAvailableValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            scenePickingGPUAvailableValue = newValue
            lock.unlock()
        }
    }

    var scenePickingIgnoreRayIntersectionWithTransparents: Bool {
        get {
            lock.lock()
            let value = scenePickingIgnoreRayIntersectionWithTransparentsValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            scenePickingIgnoreRayIntersectionWithTransparentsValue = newValue
            lock.unlock()
        }
    }

    var iblSuccessful: Bool {
        get {
            lock.lock()
            let value = iblSuccessfulValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            iblSuccessfulValue = newValue
            lock.unlock()
        }
    }

    var gameMode: Bool {
        get {
            lock.lock()
            let value = gameModeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            gameModeValue = newValue
            lock.unlock()
        }
    }

    var applyIBL: Bool {
        get {
            lock.lock()
            let value = applyIBLValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            applyIBLValue = newValue
            lock.unlock()
        }
    }

    var renderEnvironment: Bool {
        get {
            lock.lock()
            let value = renderEnvironmentValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            renderEnvironmentValue = newValue
            lock.unlock()
        }
    }

    var ambientIntensity: Float {
        get {
            lock.lock()
            let value = ambientIntensityValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            ambientIntensityValue = newValue
            lock.unlock()
        }
    }

    var hdrURL: String {
        get {
            lock.lock()
            let value = hdrURLValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            hdrURLValue = newValue
            lock.unlock()
        }
    }

    var resourceURL: URL? {
        get {
            lock.lock()
            let value = resourceURLValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            resourceURLValue = newValue
            lock.unlock()
        }
    }

    var assetBasePath: URL? {
        get {
            lock.lock()
            let value = assetBasePathValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            assetBasePathValue = newValue
            lock.unlock()
        }
    }

    var activeEntity: EntityID {
        get {
            lock.lock()
            let value = activeEntityValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            activeEntityValue = newValue
            lock.unlock()
        }
    }

    var enableEngineMetrics: Bool {
        get {
            lock.lock()
            let value = enableEngineMetricsValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            enableEngineMetricsValue = newValue
            lock.unlock()
        }
    }

    var bypassPostProcessing: Bool {
        get {
            lock.lock()
            let value = bypassPostProcessingValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            bypassPostProcessingValue = newValue
            lock.unlock()
        }
    }

    var antiAliasingMode: AntiAliasingMode {
        get {
            lock.lock()
            let value = antiAliasingModeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            antiAliasingModeValue = newValue
            lock.unlock()
        }
    }

    var renderDebugViewMode: RenderDebugViewMode {
        get {
            lock.lock()
            let value = renderDebugViewModeValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            renderDebugViewModeValue = newValue
            lock.unlock()
        }
    }

    var pomQualitySettings: POMQualitySettings {
        get {
            lock.lock()
            let value = pomQualitySettingsValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            pomQualitySettingsValue = newValue
            lock.unlock()
        }
    }

    var entityMeshMap: [EntityID: [Mesh]] {
        get {
            lock.lock()
            let value = entityMeshMapValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            entityMeshMapValue = newValue
            lock.unlock()
        }
    }

    var entityNameMap: [EntityID: String] {
        get {
            lock.lock()
            let value = entityNameMapValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            entityNameMapValue = newValue
            lock.unlock()
        }
    }

    var reverseEntityNameMap: [String: [EntityID]] {
        get {
            lock.lock()
            let value = reverseEntityNameMapValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            reverseEntityNameMapValue = newValue
            lock.unlock()
        }
    }

    var cameraDefaultFOV: Float {
        get {
            lock.lock()
            let value = cameraDefaultFOVValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            cameraDefaultFOVValue = newValue
            lock.unlock()
        }
    }

    var cameraNearPlane: Float {
        get {
            lock.lock()
            let value = cameraNearPlaneValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            cameraNearPlaneValue = newValue
            if cameraFarPlaneValue <= cameraNearPlaneValue {
                cameraFarPlaneValue = cameraNearPlaneValue + 0.001
            }
            lock.unlock()
        }
    }

    var cameraFarPlane: Float {
        get {
            lock.lock()
            let value = cameraFarPlaneValue
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            cameraFarPlaneValue = max(newValue, cameraNearPlaneValue + 0.001)
            lock.unlock()
        }
    }
}

/// ibl
var componentCounter: Int {
    get { RuntimeGlobalsStore.shared.componentCounter }
    set { RuntimeGlobalsStore.shared.componentCounter = newValue }
}

var globalEntityCounter: UInt32 {
    get { RuntimeGlobalsStore.shared.globalEntityCounter }
    set { RuntimeGlobalsStore.shared.globalEntityCounter = newValue }
}

public var iblSuccessful: Bool {
    get { RuntimeGlobalsStore.shared.iblSuccessful }
    set { RuntimeGlobalsStore.shared.iblSuccessful = newValue }
}

// let usdRotation:simd_float4x4=matrix4x4Identity()

let gridVertices: [simd_float3] = [
    simd_float3(1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(-1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(1.0, 1.0, 0.0),
    simd_float3(1.0, -1.0, 0.0),
]

let quadVertices: [simd_float3] = [
    simd_float3(-1.0, 1.0, 0.0),
    simd_float3(-1.0, -1.0, 0.0),
    simd_float3(1.0, -1.0, 0.0),
    simd_float3(1.0, 1.0, 0.0),
]

let quadTexCoords: [simd_float2] = [
    simd_float2(0.0, 0.0),
    simd_float2(0.0, 1.0),
    simd_float2(1.0, 1.0),
    simd_float2(1.0, 0.0),
]

public let quadIndices: [UInt16] = [
    0, 1, 3, // First Triangle
    3, 1, 2, // Second Triangle
]

public enum TextureType: String, CaseIterable, Identifiable {
    case baseColor
    case roughness
    case metallic
    case normal
    case height

    public var id: Self {
        self
    } // Satisfies Identifiable conformance

    public var displayName: String {
        switch self {
        case .baseColor: return "Base Color"
        case .roughness: return "Roughness"
        case .metallic: return "Metallic"
        case .normal: return "Normal"
        case .height: return "Height"
        }
    }
}

public enum RenderDebugViewMode: Int, CaseIterable, Sendable {
    case lit = 0
    case albedo = 1
    case normal = 2
    case depth = 3
    case ssaoBlurred = 4
    case fxaaEdgeDebug = 5
    case smaaEdges = 6
    case smaaBlend = 7
    case smaaDifference = 8
    /// Renders the lit scene with green wireframe AABBs around HZB-occluded entities.
    case occlusionDebug = 9
    /// Visualizes the G-buffer world-position texture as repeating world-space RGB bands.
    case position = 10
    /// Visualizes the G-buffer roughness channel.
    case roughness = 11
    /// Visualizes the G-buffer metallic channel.
    case metallic = 12
    /// Visualizes scene luminance before Look/ACES tonemapping.
    case preTonemapHDRLuminance = 13
    /// Routes the normal post-tonemap output explicitly for color-pipeline checks.
    case postTonemapOutput = 14
    /// Visualizes the raw height-map sample used by Parallax Occlusion Mapping.
    case heightDebug = 15
    /// Visualizes the magnitude of the POM UV displacement as a heatmap.
    case pomOffsetDebug = 16
}

/// Runtime tuning for Parallax Occlusion Mapping's per-pixel ray-march cost.
///
/// `minSteps`/`maxSteps` bound the adaptive step count (fewer near-normal, more at grazing
/// angles). `maxDistance`/`fadeStartDistance` fade POM out entirely beyond a configurable
/// distance — the single highest-leverage performance control, since most height-mapped
/// surfaces in a scene (background walls, distant floors) don't need a per-pixel ray march at
/// all. The fade is smooth (no popping at the cutoff) and gates the ray march itself, not just
/// the visual result, so distant fragments skip the cost entirely.
public struct POMQualitySettings: Equatable, Sendable {
    public var minSteps: Float
    public var maxSteps: Float
    /// Distance beyond which POM fully fades to flat (normal-mapping-only).
    public var maxDistance: Float
    /// Distance at which the fade begins. Must be less than `maxDistance`.
    public var fadeStartDistance: Float

    public init(
        minSteps: Float = 8.0,
        maxSteps: Float = 32.0,
        maxDistance: Float = 20.0,
        fadeStartDistance: Float = 12.0
    ) {
        self.minSteps = minSteps
        self.maxSteps = maxSteps
        self.maxDistance = maxDistance
        self.fadeStartDistance = fadeStartDistance
    }

    /// Platform-appropriate default. visionOS renders stereo (effectively doubling
    /// per-pixel fragment work), so it defaults to a lower max step count and a tighter
    /// distance cutoff than desktop/iOS — mirroring the same XR-vs-desktop default-profile
    /// pattern used elsewhere in the renderer (e.g. `TextureLoader.defaultMaxTextureDimension`,
    /// CSM cascade count).
    public static var platformDefault: POMQualitySettings {
        #if os(visionOS)
            POMQualitySettings(minSteps: 4.0, maxSteps: 16.0, maxDistance: 15.0, fadeStartDistance: 9.0)
        #else
            POMQualitySettings(minSteps: 8.0, maxSteps: 32.0, maxDistance: 20.0, fadeStartDistance: 12.0)
        #endif
    }
}

// TODO: try to remove this var, because only make sense on the editor side
public var gameMode: Bool {
    get { RuntimeGlobalsStore.shared.gameMode }
    set { RuntimeGlobalsStore.shared.gameMode = newValue }
}

public var applyIBL: Bool {
    get { RuntimeGlobalsStore.shared.applyIBL }
    set { RuntimeGlobalsStore.shared.applyIBL = newValue }
}

public var renderEnvironment: Bool {
    get { RuntimeGlobalsStore.shared.renderEnvironment }
    set { RuntimeGlobalsStore.shared.renderEnvironment = newValue }
}

public var ambientIntensity: Float {
    get { RuntimeGlobalsStore.shared.ambientIntensity }
    set { RuntimeGlobalsStore.shared.ambientIntensity = newValue }
}

/// hightlight
public let boundingBoxVertexCount = 24

var envRotationAngle: Float {
    get { RuntimeGlobalsStore.shared.envRotationAngle }
    set { RuntimeGlobalsStore.shared.envRotationAngle = newValue }
}

public var hdrURL: String {
    get { RuntimeGlobalsStore.shared.hdrURL }
    set { RuntimeGlobalsStore.shared.hdrURL = newValue }
}

public var resourceURL: URL? {
    get { RuntimeGlobalsStore.shared.resourceURL }
    set { RuntimeGlobalsStore.shared.resourceURL = newValue }
}

var currentGlobalTime: Float {
    get { RuntimeGlobalsStore.shared.currentGlobalTime }
    set { RuntimeGlobalsStore.shared.currentGlobalTime = newValue }
}

// Physics system

enum InertiaTensorType: Int {
    case cubic
    case spherical
    case cylindrical
}

public var assetBasePath: URL? {
    get { RuntimeGlobalsStore.shared.assetBasePath }
    set { RuntimeGlobalsStore.shared.assetBasePath = newValue }
}

public var activeEntity: EntityID {
    get { RuntimeGlobalsStore.shared.activeEntity }
    set { RuntimeGlobalsStore.shared.activeEntity = newValue }
}

/// Transform Manipulation mode
public enum TransformManipulationMode {
    case translate
    case rotate
    case scale
    case lightRotate
    case none
}

public enum TransformAxis {
    case x, y, z, none
}

/// mtk view color
/// Graphite Gray
let mtkBackgroundColor = MTLClearColorMake(40.0 / 255.0, 40.0 / 255.0, 45.0 / 255.0, 1.0)

let fixedStep: Float = 1.0 / 60.0
var physicsAccumulator: Float {
    get { RuntimeGlobalsStore.shared.physicsAccumulator }
    set { RuntimeGlobalsStore.shared.physicsAccumulator = newValue }
}

/// ssao kernel size
var ssaoKernelSize: Int {
    get { RuntimeGlobalsStore.shared.ssaoKernelSize }
    set { RuntimeGlobalsStore.shared.ssaoKernelSize = newValue }
}

// Camera defaults
public let cameraDefaultEye: simd_float3 = .init(0.0, 1.0, 4.0)
public let cameraTargetDefault: simd_float3 = .init(0.0, 0.0, -2.0)
public let cameraUpDefault: simd_float3 = .init(0.0, 1.0, 0.0)

/// Culling
public struct EntityAABB {
    public var center: simd_float4
    public var halfExtent: simd_float4
    public var index: UInt32
    public var version: UInt32
    public var pad0: UInt32 = 0
    public var pad1: UInt32 = 0
}

struct VisibleEntity {
    var center: simd_float4
    var halfExtent: simd_float4
    var index: UInt32
    var version: UInt32
    var pad0: UInt32 = 0
    var pad1: UInt32 = 0
}

public var visibleEntityIds: [EntityID] {
    get { RuntimeGlobalsStore.shared.visibleEntityIds }
    set { RuntimeGlobalsStore.shared.visibleEntityIds = newValue }
}

var currentFrameFrustum: Frustum? {
    get { RuntimeGlobalsStore.shared.currentFrameFrustum }
    set { RuntimeGlobalsStore.shared.currentFrameFrustum = newValue }
}

public let tripleVisibleEntities = TripleCPUBuffer<EntityID>(inFlight: 3, initialCapacity: MAX_ENTITIES)
public var cullFrameIndex: Int {
    get { RuntimeGlobalsStore.shared.cullFrameIndex }
    set { RuntimeGlobalsStore.shared.cullFrameIndex = newValue }
}

public var cullSubmitIndex: Int {
    get { RuntimeGlobalsStore.shared.cullSubmitIndex }
    set { RuntimeGlobalsStore.shared.cullSubmitIndex = newValue }
}

public var needsFinalizeDestroys: Bool {
    get { RuntimeGlobalsStore.shared.needsFinalizeDestroys }
    set { RuntimeGlobalsStore.shared.needsFinalizeDestroys = newValue }
}

var hasPendingDestroys: Bool {
    get { RuntimeGlobalsStore.shared.hasPendingDestroys }
    set { RuntimeGlobalsStore.shared.hasPendingDestroys = newValue }
}

var scenePickingSystemInitialized: Bool {
    get { RuntimeGlobalsStore.shared.scenePickingSystemInitialized }
    set { RuntimeGlobalsStore.shared.scenePickingSystemInitialized = newValue }
}

var scenePickingDirtyEntities: Set<EntityID> {
    get { RuntimeGlobalsStore.shared.scenePickingDirtyEntities }
    set { RuntimeGlobalsStore.shared.scenePickingDirtyEntities = newValue }
}

var scenePickingGPUAvailable: Bool {
    get { RuntimeGlobalsStore.shared.scenePickingGPUAvailable }
    set { RuntimeGlobalsStore.shared.scenePickingGPUAvailable = newValue }
}

var scenePickingIgnoreRayIntersectionWithTransparents: Bool {
    get { RuntimeGlobalsStore.shared.scenePickingIgnoreRayIntersectionWithTransparents }
    set { RuntimeGlobalsStore.shared.scenePickingIgnoreRayIntersectionWithTransparents = newValue }
}

// Command buffer synchronization - limit in-flight frames to prevent memory accumulation.
public let maxInFlightCommandBuffers = 3
public let commandBufferSemaphore = DispatchSemaphore(value: maxInFlightCommandBuffers)

/// Uniform buffering:
/// index by (in-flight frame slot, eye) to avoid CPU writes from newer frames clobbering
/// uniforms still in use by the GPU.
public let stereoEyeCount = 2

private final class UniformFrameSlotState: @unchecked Sendable {
    static let shared = UniformFrameSlotState()

    private let lock = NSLock()
    private var counter: Int = 0

    private init() {}

    func acquireSlot(maxInFlight: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let slot = counter % maxInFlight
        counter += 1
        return slot
    }
}

@inline(__always)
public func totalPerMeshUniformBuffers() -> Int {
    maxInFlightCommandBuffers * stereoEyeCount
}

@inline(__always)
public func acquireUniformFrameSlot() -> Int {
    UniformFrameSlotState.shared.acquireSlot(maxInFlight: maxInFlightCommandBuffers)
}

@inline(__always)
public func currentUniformBufferIndex() -> Int {
    (renderInfo.currentInFlightFrameSlot * stereoEyeCount) + renderInfo.currentEye
}

/// Engine profiling/benchmarking
public var enableEngineMetrics: Bool {
    get { RuntimeGlobalsStore.shared.enableEngineMetrics }
    set { RuntimeGlobalsStore.shared.enableEngineMetrics = newValue }
}

public var bypassPostProcessing: Bool {
    get { RuntimeGlobalsStore.shared.bypassPostProcessing }
    set { RuntimeGlobalsStore.shared.bypassPostProcessing = newValue }
}

/// Selects the active anti-aliasing pass inserted after the look pass.
public enum AntiAliasingMode: Sendable {
    case none
    case fxaa
    case smaa
    case msaa

    var usesPostLookPass: Bool {
        switch self {
        case .fxaa, .smaa:
            return true
        case .none, .msaa:
            return false
        }
    }
}

public var antiAliasingMode: AntiAliasingMode {
    get { RuntimeGlobalsStore.shared.antiAliasingMode }
    set { RuntimeGlobalsStore.shared.antiAliasingMode = newValue }
}

public var renderDebugViewMode: RenderDebugViewMode {
    get { RuntimeGlobalsStore.shared.renderDebugViewMode }
    set { RuntimeGlobalsStore.shared.renderDebugViewMode = newValue }
}

public func setPOMQuality(_ settings: POMQualitySettings) {
    RuntimeGlobalsStore.shared.pomQualitySettings = settings
}

public func getPOMQuality() -> POMQualitySettings {
    RuntimeGlobalsStore.shared.pomQualitySettings
}

public final class ToneMappingParams: ObservableObject, @unchecked Sendable {
    static let shared = ToneMappingParams()

    @Published var toneMapOperator: Int = 0
    @Published var gamma: Float = 1.0 // original = 2.2
}

public final class ColorGradingParams: ObservableObject, @unchecked Sendable {
    public static let shared = ColorGradingParams()

    @Published public var brightness: Float = 0.0
    @Published public var contrast: Float = 1.0
    @Published public var saturation: Float = 1.0
    @Published public var exposure: Float = 0.0
    @Published public var temperature: Float = 0.0 // -1.0 to 1.0 (-1.0 bluish, 0.0 neutral, +1.0 warm, yellowish/orange)
    @Published public var tint: Float = 0.0 // -1.0 to 1.0 Green (-)/Magenta (+)
    @Published public var enabled: Bool = false
}

/// Scene-wide color-grading LUT, baked from the source Blender scene's View
/// Transform/Look/Exposure/Gamma (see UntoldColorManagementRecordV1). Unlike
/// ColorGradingParams/ToneMappingParams above, this is asset-derived, not a
/// user-authored creative override. Installation and removal are owned by the
/// scene-authored payload loader, never by individual mesh residency.
struct ColorLUTSnapshot {
    let enabled: Bool
    let lutTexture: MTLTexture?
    let shaperMinStops: Float
    let shaperMaxStops: Float
    let lutSize: Int
}

public final class ColorLUTParams: @unchecked Sendable {
    public static let shared = ColorLUTParams()

    private struct State {
        var enabled = false
        var lutTexture: MTLTexture?
        var shaperMinStops: Float = -10.0
        var shaperMaxStops: Float = 6.0
        var lutSize = 0
    }

    private let lock = NSLock()
    private var state = State()

    public var enabled: Bool {
        get { snapshot().enabled }
        set { setEnabled(newValue) }
    }

    public func setEnabled(_ enabled: Bool) {
        lock.lock()
        state.enabled = enabled && state.lutTexture != nil
        lock.unlock()
    }

    func replace(texture: MTLTexture, shaperMinStops: Float, shaperMaxStops: Float, lutSize: Int) {
        lock.lock()
        state = State(
            enabled: true,
            lutTexture: texture,
            shaperMinStops: shaperMinStops,
            shaperMaxStops: shaperMaxStops,
            lutSize: lutSize
        )
        lock.unlock()
    }

    public func clear() {
        lock.lock()
        state = State()
        lock.unlock()
    }

    func snapshot() -> ColorLUTSnapshot {
        lock.lock()
        let value = ColorLUTSnapshot(
            enabled: state.enabled,
            lutTexture: state.lutTexture,
            shaperMinStops: state.shaperMinStops,
            shaperMaxStops: state.shaperMaxStops,
            lutSize: state.lutSize
        )
        lock.unlock()
        return value
    }
}

final class SceneAuthoredSourceStore: @unchecked Sendable {
    static let shared = SceneAuthoredSourceStore()

    private let lock = NSLock()
    private var storedSource: SceneAssetReference?

    var source: SceneAssetReference? {
        get {
            lock.lock()
            let value = storedSource
            lock.unlock()
            return value
        }
        set {
            lock.lock()
            storedSource = newValue
            lock.unlock()
        }
    }

    func clear() {
        source = nil
    }
}

public final class ColorCorrectionParams: ObservableObject, @unchecked Sendable {
    static let shared = ColorCorrectionParams()

    @Published var lift: simd_float3 = .zero // RGB adjustment for shadows (0 - 2)
    @Published var gamma: simd_float3 = .one // RGB adjustment for midtones (0.5 - 2.5)
    @Published var gain: simd_float3 = .one // RGB adjustment for highlights (0 - 2)
    @Published var enabled: Bool = false
}

public final class BloomThresholdParams: ObservableObject, @unchecked Sendable {
    public static let shared = BloomThresholdParams()

    @Published public var threshold: Float = 0.5 // 0.0 to 5.0
    @Published public var intensity: Float = 0.0 // 0.0 to 2.0
    @Published public var enabled: Bool = false
}

public final class BloomCompositeParams: ObservableObject, @unchecked Sendable {
    public static let shared = BloomCompositeParams()

    @Published public var intensity: Float = 1.0 // 0.0 to 2.0
    @Published public var enabled: Bool = false
}

public final class VignetteParams: ObservableObject, @unchecked Sendable {
    public static let shared = VignetteParams()

    @Published public var intensity: Float = 0.7 // 0.0 to 1.0
    @Published public var radius: Float = 0.75 // 0.5 to 1.0
    @Published public var softness: Float = 0.45 // 0.0 to 1.0
    @Published public var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published public var enabled: Bool = false
}

public final class ChromaticAberrationParams: ObservableObject, @unchecked Sendable {
    public static let shared = ChromaticAberrationParams()

    @Published public var intensity: Float = 0.0 // 0.0 to 0.1
    @Published public var center: simd_float2 = .init(0.5, 0.5) // 0-1
    @Published public var enabled: Bool = false
}

public final class DepthOfFieldParams: ObservableObject, @unchecked Sendable {
    public static let shared = DepthOfFieldParams()

    @Published public var focusDistance: Float = 1.0 // 0.0 to 1.0
    @Published public var focusRange: Float = 0.1 // 0.01-0.3
    @Published public var maxBlur: Float = 0 // 0.005-0.05
    @Published public var enabled: Bool = false
}

struct WireframeRenderState {
    var color: simd_float4 = .init(0.2, 0.85, 1.0, 0.65)
    var distanceFadeEnabled: Bool = false
    var fadeStartDistance: Float = 8.0
    var fadeEndDistance: Float = 40.0
    var minimumAlpha: Float = 0.08
}

let wireframeRenderStateLock = NSLock()
nonisolated(unsafe) var wireframeRenderState = WireframeRenderState()

public func setWireframeParams(
    color: simd_float4,
    fadeEnabled: Bool = false,
    fadeStart: Float = 8.0,
    fadeEnd: Float = 40.0,
    minimumAlpha: Float = 0.08
) {
    wireframeRenderStateLock.lock()
    wireframeRenderState.color = color
    wireframeRenderState.distanceFadeEnabled = fadeEnabled
    wireframeRenderState.fadeStartDistance = fadeStart
    wireframeRenderState.fadeEndDistance = fadeEnd
    wireframeRenderState.minimumAlpha = minimumAlpha
    wireframeRenderStateLock.unlock()
}

public final class FXAAParams: ObservableObject, @unchecked Sendable {
    public static let shared = FXAAParams()

    @Published public var subpixelQuality: Float = 0.75 // 0.0–1.0; higher = stronger sub-pixel smoothing
    @Published public var edgeThreshold: Float = 0.125 // minimum local contrast to trigger AA
    @Published public var edgeThresholdMin: Float = 0.0625 // absolute threshold floor (skip very dark edges)
}

public final class SMAAParams: ObservableObject, @unchecked Sendable {
    public static let shared = SMAAParams()

    @Published public var edgeThreshold: Float = 0.1
}

/// SSAO Quality Settings
public enum SSAOQuality: Int, CaseIterable, Sendable {
    case fast = 0
    case balanced = 1
    case high = 2

    var sampleCount: Int {
        switch self {
        case .fast: return 8
        case .balanced: return 16
        case .high: return 32
        }
    }

    var resolutionScale: Float {
        switch self {
        case .fast: return 0.5 // half-res
        case .balanced: return 0.5 // half-res
        case .high: return 1.0 // full-res
        }
    }

    var useDepthAwareUpsample: Bool {
        switch self {
        case .fast: return false // simple bilinear
        case .balanced: return true
        case .high: return false // no upsample needed
        }
    }

    var useBilateralBlur: Bool {
        switch self {
        case .fast: return false
        case .balanced: return true
        case .high: return true
        }
    }

    var textureFormat: MTLPixelFormat {
        switch self {
        case .fast: return .r8Unorm
        case .balanced: return .r8Unorm
        case .high: return .r16Float
        }
    }
}

public final class SSAOParams: ObservableObject, @unchecked Sendable {
    public static let shared = SSAOParams()

    @Published public var radius: Float = 0.5 // 0.1 to 2.0 how far to sample
    @Published public var bias: Float = 0.025 // 0.01-0.1 avoid self occusion
    @Published public var intensity: Float = 0 // 0.5-2.0 Final multiplier
    @Published public var enabled: Bool = false
    @Published public var quality: SSAOQuality = .balanced {
        didSet {
            // Automatically reinitialize textures and pipeline when quality changes
            if quality != oldValue {
                reinitSSAOTextures()

                // Recreate SSAO pipelines with new format
                if let newSSAOPipeline = InitSSAOPipeline() {
                    PipelineManager.shared.update(rendererPipeLine: newSSAOPipeline, forType: .ssao)
                }
                if let newSSAOBlurPipeline = InitSSAOBlurPipeline() {
                    PipelineManager.shared.update(rendererPipeLine: newSSAOBlurPipeline, forType: .ssaoBlur)
                }
                if let newBilateralPipeline = InitSSAOBilateralBlurPipeline() {
                    PipelineManager.shared.update(rendererPipeLine: newBilateralPipeline, forType: .ssaoBilateralBlur)
                }
                if let newUpsamplePipeline = InitSSAOUpsamplePipeline() {
                    PipelineManager.shared.update(rendererPipeLine: newUpsamplePipeline, forType: .ssaoUpsample)
                }

                print("🔧 SSAO Quality changed to: \(quality) - textures & pipelines reinitialized")
            }
        }
    }

    // Performance telemetry
    public var lastSSAOTime: Double = 0.0 // milliseconds
    public var lastBlurTime: Double = 0.0 // milliseconds
    public var frameCount: Int = 0
    public var avgSSAOTime: Double = 0.0
    public var avgBlurTime: Double = 0.0
}

public enum UntoldImmersionMode: Sendable {
    case none
    case mixed
    case full
    case ar
}
