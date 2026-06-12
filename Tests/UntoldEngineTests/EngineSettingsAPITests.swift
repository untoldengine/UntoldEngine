//
//  EngineSettingsAPITests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

@MainActor
final class EngineSettingsAPITests: XCTestCase {
    override func setUp() async throws {
        resetEngineTestState()
        LODConfig.shared = LODConfig()
        bypassPostProcessing = false
        antiAliasingMode = .fxaa
        renderDebugViewMode = .lit
        applyIBL = false
        renderEnvironment = false
        setCamera(.defaultFOV(65.0))
        setCamera(.clipPlanes(near: 0.1, far: 500.0))
        assetBasePath = nil
        enableEngineMetrics = false
        Logger.logLevel = .debug
        Logger.resetCategoryToggles()
        GeometryStreamingSystem.shared.enabled = true
        GeometryStreamingSystem.shared.maxConcurrentTileLoads = 2
        GeometryStreamingSystem.shared.maxConcurrentLoads = 3
        GeometryStreamingSystem.shared.maxConcurrentLODLoads = 4
        GeometryStreamingSystem.shared.maxConcurrentHLODLoads = 4
        GeometryStreamingSystem.shared.enableFrustumGate = true
        GeometryStreamingSystem.shared.frustumGatePadding = 5.0
        GeometryStreamingSystem.shared.tileFrustumGatePadding = 20.0
        GeometryStreamingSystem.shared.maxQueryRadius = 500.0
        GeometryStreamingSystem.shared.floorProximityGateY = 5.0
        GeometryStreamingSystem.shared.interiorZone = nil
        GeometryStreamingSystem.shared.velocityLookAheadTime = 0.5
        GeometryStreamingSystem.shared.velocityLookAheadMinSpeed = 1.5
        GeometryStreamingSystem.shared.enableImportanceSort = true
        GeometryStreamingSystem.shared.enableOcclusionSort = true
        GeometryStreamingSystem.shared.minimumParsedTileResidentSeconds = 8.0
        GeometryStreamingSystem.shared.tileParseTimeoutSeconds = 60.0
        GeometryStreamingSystem.shared.meshLoadTimeoutSeconds = 60.0
        SpatialDebugVisualization.shared.disableAll()
        PostFX.apply(.neutral)
        PostFX.setEnabled(.vignette, false)
        PostFX.setEnabled(.bloomThreshold, false)
        PostFX.setEnabled(.bloomComposite, false)
        PostFX.setEnabled(.chromaticAberration, false)
        PostFX.setEnabled(.depthOfField, false)
        PostFX.setEnabled(.colorCorrection, false)
    }

    func testSetLODUpdatesSharedConfig() {
        setLOD(.fadeTransitions(.enabled(duration: 0.42)))
        setLOD(.distanceBias(1.5))
        setLOD(.hysteresis(3.0))
        setLOD(.updateFrameInterval(0))
        setLOD(.minimumCameraDisplacement(-1))
        setLOD(.distanceThresholds([25, -10, 100]))

        let config = LODConfig.shared
        XCTAssertTrue(config.enableFadeTransitions)
        XCTAssertEqual(config.fadeTransitionTime, 0.42, accuracy: 0.001)
        XCTAssertEqual(config.lodBias, 1.5, accuracy: 0.001)
        XCTAssertEqual(config.hysteresis, 3.0, accuracy: 0.001)
        XCTAssertEqual(config.lodUpdateFrameInterval, 1)
        XCTAssertEqual(config.minimumCameraDisplacementForLODUpdate, 0, accuracy: 0.001)
        XCTAssertEqual(config.lodDistances, [25, 0, 100])

        setLOD(.fadeTransitions(.disabled))
        XCTAssertFalse(LODConfig.shared.enableFadeTransitions)
    }

    func testSetRenderingUpdatesGlobals() {
        setRendering(.antiAliasing(.smaa))
        if case .smaa = antiAliasingMode {} else {
            XCTFail("Expected SMAA anti-aliasing mode")
        }

        setRendering(.debugView(.depth))
        if case .depth = renderDebugViewMode {} else {
            XCTFail("Expected depth debug view")
        }

        setRendering(.postProcessing(.disabled))
        XCTAssertTrue(bypassPostProcessing)

        setRendering(.postProcessing(.enabled))
        XCTAssertFalse(bypassPostProcessing)

        setRendering(.environment(.ibl(true)))
        setRendering(.environment(.visible(true)))
        XCTAssertTrue(applyIBL)
        XCTAssertTrue(renderEnvironment)

        setRendering(.environment(.ibl(false)))
        setRendering(.environment(.visible(false)))
        XCTAssertFalse(applyIBL)
        XCTAssertFalse(renderEnvironment)
    }

    func testSetEngineUpdatesGlobals() {
        let url = URL(fileURLWithPath: "/tmp/GameData")

        setEngine(.assetBasePath(url))
        setEngine(.metrics(.enabled))

        XCTAssertEqual(assetBasePath, url)
        XCTAssertTrue(enableEngineMetrics)

        setEngine(.metrics(.disabled))
        XCTAssertFalse(enableEngineMetrics)
    }

    func testSetPostFXUpdatesEffectParams() {
        setPostFX(.ssao(.enabled(true)))
        setPostFX(.ssao(.radius(0.8)))
        setPostFX(.ssao(.bias(0.04)))
        setPostFX(.ssao(.intensity(0.7)))

        XCTAssertTrue(SSAOParams.shared.enabled)
        XCTAssertEqual(SSAOParams.shared.radius, 0.8, accuracy: 0.001)
        XCTAssertEqual(SSAOParams.shared.bias, 0.04, accuracy: 0.001)
        XCTAssertEqual(SSAOParams.shared.intensity, 0.7, accuracy: 0.001)

        setPostFX(.colorGrading(.enabled(true)))
        setPostFX(.colorGrading(.exposure(-0.2)))
        setPostFX(.colorGrading(.saturation(0.9)))

        XCTAssertTrue(ColorGradingParams.shared.enabled)
        XCTAssertEqual(ColorGradingParams.shared.exposure, -0.2, accuracy: 0.001)
        XCTAssertEqual(ColorGradingParams.shared.saturation, 0.9, accuracy: 0.001)

        setPostFX(.vignette(.enabled(true)))
        setPostFX(.vignette(.intensity(0.5)))
        setPostFX(.vignette(.center(simd_float2(0.4, 0.6))))

        XCTAssertTrue(VignetteParams.shared.enabled)
        XCTAssertEqual(VignetteParams.shared.intensity, 0.5, accuracy: 0.001)
        XCTAssertEqual(VignetteParams.shared.center.x, 0.4, accuracy: 0.001)
        XCTAssertEqual(VignetteParams.shared.center.y, 0.6, accuracy: 0.001)
    }

    func testSetPostFXPresetAppliesPreset() {
        setPostFX(.preset(.cinematic))

        XCTAssertTrue(ColorGradingParams.shared.enabled)
        XCTAssertEqual(ColorGradingParams.shared.exposure, -0.2, accuracy: 0.001)
        XCTAssertTrue(SSAOParams.shared.enabled)
        XCTAssertEqual(SSAOParams.shared.intensity, 0.5, accuracy: 0.001)
    }

    func testSetGeometryStreamingUpdatesStreamingSystem() {
        let zone = AABB(min: simd_float3(-1, -2, -3), max: simd_float3(1, 2, 3))

        setGeometryStreaming(.enabled(false))
        setGeometryStreaming(.tileConcurrency(0))
        setGeometryStreaming(.meshConcurrency(0))
        setGeometryStreaming(.lodConcurrency(0))
        setGeometryStreaming(.hlodConcurrency(0))
        setGeometryStreaming(.queryRadius(-10))
        setGeometryStreaming(.floorProximityGateY(-4))
        setGeometryStreaming(.interiorZone(zone))
        setGeometryStreaming(.frustumGate(.enabled(meshPadding: -2, tilePadding: 12)))
        setGeometryStreaming(.velocityLookAhead(time: -1, minSpeed: 3))
        setGeometryStreaming(.candidateSorting(importance: false, occlusion: false))
        setGeometryStreaming(.minimumParsedTileResidentSeconds(-1))
        setGeometryStreaming(.timeouts(tileParse: -5, meshLoad: 9))

        let streaming = GeometryStreamingSystem.shared
        XCTAssertFalse(streaming.enabled)
        XCTAssertEqual(streaming.maxConcurrentTileLoads, 1)
        XCTAssertEqual(streaming.maxConcurrentLoads, 1)
        XCTAssertEqual(streaming.maxConcurrentLODLoads, 1)
        XCTAssertEqual(streaming.maxConcurrentHLODLoads, 1)
        XCTAssertEqual(streaming.maxQueryRadius, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.floorProximityGateY, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.interiorZone?.min.x ?? 0, -1, accuracy: 0.001)
        XCTAssertTrue(streaming.enableFrustumGate)
        XCTAssertEqual(streaming.frustumGatePadding, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.tileFrustumGatePadding, 12, accuracy: 0.001)
        XCTAssertEqual(streaming.velocityLookAheadTime, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.velocityLookAheadMinSpeed, 3, accuracy: 0.001)
        XCTAssertFalse(streaming.enableImportanceSort)
        XCTAssertFalse(streaming.enableOcclusionSort)
        XCTAssertEqual(streaming.minimumParsedTileResidentSeconds, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.tileParseTimeoutSeconds, 0, accuracy: 0.001)
        XCTAssertEqual(streaming.meshLoadTimeoutSeconds, 9, accuracy: 0.001)

        setGeometryStreaming(.frustumGate(.disabled))
        XCTAssertFalse(streaming.enableFrustumGate)
    }

    func testSetBatchingUpdatesRuntimeTuning() {
        setBatching(.enabled(true))
        setBatching(.cellSize(24))
        setBatching(.maxDirtyCellsPerTick(0))
        setBatching(.retireDelayFrames(0))
        setBatching(.maxRetirementsPerTick(0))
        setBatching(.backgroundArtifactBuild(false))
        setBatching(.visibilityGatedBuild(false))
        setBatching(.maxBuildDispatchesPerTick(0))
        setBatching(.maxArtifactAppliesPerTick(0))
        setBatching(.rebuildBudgets(vertices: 0, indices: 0, bytes: 0))
        setBatching(.runtimeCellLimits(vertices: 0, indices: 0, bytes: 0))
        setBatching(.quiescenceFramesBeforeBuild(-1))
        setBatching(.recentVisibilityWindowFrames(-1))

        let batching = BatchingSystem.shared
        XCTAssertTrue(batching.isEnabled())
        XCTAssertEqual(batching.getBatchCellSize(), 24, accuracy: 0.001)
        XCTAssertEqual(batching.getMaxDirtyCellsPerTick(), 1)
        XCTAssertEqual(batching.getBatchRetireDelayFrames(), 1)
        XCTAssertEqual(batching.getMaxRetirementsPerTick(), 1)
        XCTAssertFalse(batching.isBackgroundArtifactBuildEnabled())
        XCTAssertFalse(batching.isVisibilityGatedBatchBuildEnabled())

        let tuning = batching.getRuntimeBatchingTuning()
        XCTAssertEqual(tuning.maxBuildDispatchesPerTick, 1)
        XCTAssertEqual(tuning.maxArtifactAppliesPerTick, 1)
        XCTAssertEqual(tuning.maxRebuildVerticesPerTick, 1)
        XCTAssertEqual(tuning.maxRebuildIndicesPerTick, 1)
        XCTAssertEqual(tuning.maxRebuildBufferBytesPerTick, 1)
        XCTAssertEqual(tuning.maxRuntimeCellVertices, 1)
        XCTAssertEqual(tuning.maxRuntimeCellIndices, 1)
        XCTAssertEqual(tuning.maxRuntimeCellBufferBytes, 1)
        XCTAssertEqual(tuning.quiescenceFramesBeforeBatchBuild, 0)
        XCTAssertEqual(tuning.recentVisibilityWindowFrames, 0)
    }

    func testSetSpatialDebugUpdatesVisualization() {
        setSpatialDebug(.octreeLeafBounds(.enabled(maxLeafNodeCount: -1, occupiedOnly: false, colorMode: .residency)))
        setSpatialDebug(.tileBounds(enabled: true, maxTileNodeCount: -1))
        setSpatialDebug(.staticBatchCellBounds(enabled: true, maxCellCount: -1, colorMode: .lod))
        setSpatialDebug(.lodLevels(true))
        setSpatialDebug(.textureStreamingTiers(true))

        let debug = SpatialDebugVisualization.shared
        XCTAssertTrue(debug.enabled)
        XCTAssertTrue(debug.showOctreeLeafBounds)
        XCTAssertEqual(debug.maxLeafNodeCount, 0)
        XCTAssertFalse(debug.octreeLeafOccupiedOnly)
        XCTAssertEqual(debug.octreeLeafColorMode, .residency)
        XCTAssertTrue(debug.showTileBounds)
        XCTAssertEqual(debug.maxTileNodeCount, 0)
        XCTAssertTrue(debug.showStaticBatchCellBounds)
        XCTAssertEqual(debug.maxStaticBatchCellCount, 0)
        XCTAssertEqual(debug.staticBatchCellColorMode, .lod)
        XCTAssertTrue(debug.colorRenderablesByLOD)
        XCTAssertTrue(debug.colorRenderablesByStreamingTier)

        setSpatialDebug(.disabled)
        XCTAssertFalse(debug.enabled)
        XCTAssertFalse(debug.showOctreeLeafBounds)
        XCTAssertFalse(debug.showTileBounds)
        XCTAssertFalse(debug.showStaticBatchCellBounds)
        XCTAssertFalse(debug.colorRenderablesByLOD)
        XCTAssertFalse(debug.colorRenderablesByStreamingTier)
    }

    func testSetLoggerUpdatesLoggerState() {
        setLogger(.level(.warning))
        setLogger(.category(.tileStreaming, true))
        setLogger(.categories([.batching, .textureStreaming], true))

        XCTAssertEqual(Logger.logLevel, .warning)
        XCTAssertTrue(Logger.isEnabled(category: .tileStreaming))
        XCTAssertTrue(Logger.isEnabled(category: .batching))
        XCTAssertTrue(Logger.isEnabled(category: .textureStreaming))

        setLogger(.resetCategories)
        XCTAssertFalse(Logger.isEnabled(category: .tileStreaming))
        XCTAssertFalse(Logger.isEnabled(category: .batching))
        XCTAssertFalse(Logger.isEnabled(category: .textureStreaming))
    }

    func testSetCameraUpdatesCameraGlobals() {
        let camera = createEntity()

        setCamera(.active(camera))
        setCamera(.defaultFOV(70.0))
        setCamera(.clipPlanes(near: 0.05, far: 1000.0))

        XCTAssertEqual(CameraSystem.shared.activeCamera, camera)
        XCTAssertEqual(fov, 70.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.05, accuracy: 0.001)
        XCTAssertEqual(far, 1000.0, accuracy: 0.001)

        setCamera(.defaultFOV(200.0))
        setCamera(.clipPlanes(near: -1.0, far: 0.0))

        XCTAssertEqual(fov, 179.0, accuracy: 0.001)
        XCTAssertEqual(near, 0.0001, accuracy: 0.00001)
        XCTAssertGreaterThan(far, near)

        setCamera(.active(nil))
        XCTAssertNil(CameraSystem.shared.activeCamera)
    }
}
