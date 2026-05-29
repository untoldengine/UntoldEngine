
//
//  UntoldEngine.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import MetalKit
import simd

public protocol UntoldRendererDelegate {
    func willDraw(in view: MTKView)
    func didDraw(in view: MTKView)
}

public class UntoldRenderer: NSObject, MTKViewDelegate {
    public let metalView: MTKView

    var gameUpdateCallback: ((_ deltaTime: Float) -> Void)?
    var handleInputCallback: (() -> Void)?

    private var configuration: UntoldRendererConfig
    public var delegate: UntoldRendererDelegate?
    public var pendingResize = false

    @MainActor
    init(configuration: UntoldRendererConfig? = nil) {
        self.configuration = configuration ?? .default

        // Set the metal view from configuration or create new one
        metalView = self.configuration.metalView ?? MTKView()

        #if canImport(AppKit)
            Logger.addSink(LogStore.shared)
        #endif

        super.init()
    }

    @MainActor
    public static func create(configuration: UntoldRendererConfig? = nil) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        guard let device = MTLCreateSystemDefaultDevice() else {
            handleError(.metalDeviceNotFound)
            return nil
        }
        renderer.metalView.device = device
        renderer.metalView.depthStencilPixelFormat = .depth32Float
        renderer.metalView.colorPixelFormat = .bgra8Unorm_srgb
        renderer.metalView.preferredFramesPerSecond = 60
        (renderer.metalView.layer as? CAMetalLayer)?.contentsScale = 1.0
        renderer.metalView.framebufferOnly = false
        renderer.metalView.delegate = renderer

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }
        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = true
        renderInfo.colorPixelFormat = .rgba16Float
        renderInfo.depthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(renderer.metalView.drawableSize.width), Float(renderer.metalView.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = renderer.metalView.colorPixelFormat
        renderInfo.presentDepthPixelFormat = renderer.metalView.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            handleError(.metalLibraryNotFound, error.localizedDescription)
        }

        renderer.initResources()

        return renderer
    }

    @MainActor
    public static func create(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device

        // Create a command queue
        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }

        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = true
        renderInfo.colorPixelFormat = .rgba16Float
        renderInfo.depthPixelFormat = view.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(
            Float(view.drawableSize.width), Float(view.drawableSize.height)
        )
        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = view.colorPixelFormat
        renderInfo.presentDepthPixelFormat = view.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            handleError(.metalLibraryNotFound, error.localizedDescription)
        }

        renderer.initResources()

        return renderer
    }

    public func setupCallbacks(
        gameUpdate: @escaping (_ deltaTime: Float) -> Void,
        handleInput: @escaping () -> Void
    ) {
        gameUpdateCallback = gameUpdate
        handleInputCallback = handleInput
    }

    func initResources() {
        initBufferResources()

        PipelineManager.shared.initRenderPipelines(configuration.initRenderPipelineBlocks)

        initSizeableResources() // TODO: Find a better name function

        shadowSystem = ShadowSystem()

        // init ssao kernels
        initSSAOResources()

        initFrustumCulllingCompute()

        TextureStreamingSystem.shared.configure(device: renderInfo.device)

        initGuassianComputePipelines()
        initScenePickingSystem()

        initScriptingSystem()

        // Create defautls objects.
        let gameCamera = createEntity()
        setEntityName(entityId: gameCamera, name: "Main Camera")
        createGameCamera(entityId: gameCamera)

        let light = createEntity()
        setEntityName(entityId: light, name: "Directional Light")
        createDirLight(entityId: light)

        CameraSystem.shared.activeCamera = gameCamera

        #if os(visionOS)
            BatchingSystem.shared.applyRuntimeBatchingTuning(.visionOSBalanced)
        #else
            BatchingSystem.shared.applyRuntimeBatchingTuning(.macOSBalanced)
        #endif

        Logger.log(message: "Untold Engine Starting. Version 0.12.16")
    }

    public func initSizeableResources() {
        if renderInfo.viewPort.x == 0 || renderInfo.viewPort.y == 0 { return }

        initRTXAccumulationBuffer()

        initTextureResources()
        initRenderPassDescriptors()
        initIBLResources()

        // Initialize SSAO quality-based textures (must come after initTextureResources)
        reinitSSAOTextures()
    }

    func calculateDeltaTime() {
        if !firstUpdateCall {
            // init the time properties for the update

            timeSinceLastUpdate = 0.0

            timeSinceLastUpdatePreviousTime = CACurrentMediaTime()

            firstUpdateCall = true

            // init fps time properties
            frameCount = 0
            timePassedSinceLastFrame = 0.0

        } else {
            // figure out the time since we last we drew
            let currentTime: TimeInterval = CACurrentMediaTime()

            timeSinceLastUpdate = Float(currentTime - timeSinceLastUpdatePreviousTime)

            // keep track of the time interval between draws
            timeSinceLastUpdatePreviousTime = currentTime

            // get fps
            timePassedSinceLastFrame += Float(timeSinceLastUpdate)

            if timePassedSinceLastFrame > 0.1 {
                // let fps:Float=Float(frameCount)/timePassedSinceLastFrame

                frameCount = 0
                timePassedSinceLastFrame = 0.0
            }
        }
    }

    private enum StatsLifecycleMode {
        case internalManaged
        case externalManaged
    }

    #if ENGINE_STATS_ENABLED
        private func publishEngineStats(frameStartTime: Double) {
            let frameTotalMs: Double
            if let dt = timeSinceLastUpdate as Float?, dt > 0 {
                frameTotalMs = Double(dt) * 1000.0
            } else {
                frameTotalMs = (CACurrentMediaTime() - frameStartTime) * 1000.0
            }
            let hzbStats = getHZBDebugStats()
            let geometryStreamingStats = GeometryStreamingSystem.shared.getStats()
            let meshResourceStats = MeshResourceManager.shared.getStats()
            let integrationStats = SystemIntegrationMonitor.shared.stats
            let batchGroups = BatchingSystem.shared.batchGroups
            let batchedMeshCount = batchGroups.reduce(0) { $0 + $1.entityIds.count }
            let gateBlockedMs = AssetLoadingGate.shared.consumeBlockedMsSinceLastSample()
            let gateActiveLoads = AssetLoadingGate.shared.activeLoadCount
            let drawStats = RenderStatsCollector.shared.snapshot()

            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.frameTotalMs = frameTotalMs

                snapshot.render.drawCallsTotal = drawStats.drawCallsTotal
                snapshot.render.drawCallsOpaque = drawStats.drawCallsOpaque
                snapshot.render.drawCallsTransparent = drawStats.drawCallsTransparent
                snapshot.render.drawCallsShadow = drawStats.drawCallsShadow
                snapshot.render.drawCallsBatched = drawStats.drawCallsBatched
                snapshot.render.trianglesTotal = drawStats.trianglesTotal
                snapshot.render.visibleInstances = max(visibleEntityIds.count, hzbStats.visibleAfterOcclusionCount)

                snapshot.culling.frustumTested = hzbStats.frustumTestedCount
                snapshot.culling.frustumPassed = hzbStats.frustumCandidateCount
                snapshot.culling.frustumFailed = max(0, hzbStats.frustumTestedCount - hzbStats.frustumCandidateCount)
                if hzbStats.usedHZBThisFrame {
                    snapshot.culling.occlusionTested = hzbStats.frustumCandidateCount
                    snapshot.culling.occlusionPassed = hzbStats.visibleAfterOcclusionCount
                    snapshot.culling.occlusionFailed = hzbStats.occludedCount
                } else {
                    snapshot.culling.occlusionTested = 0
                    snapshot.culling.occlusionPassed = 0
                    snapshot.culling.occlusionFailed = 0
                }
                snapshot.culling.usedHZB = hzbStats.usedHZBThisFrame
                snapshot.culling.optimizedFrustumPath = hzbStats.optimizedFrustumPath
                snapshot.culling.hzbIsValid = hzbStats.hzbIsValid
                snapshot.culling.hzbMipCount = hzbStats.hzbMipCount
                snapshot.culling.selectedHZBMipLevel = hzbStats.selectedMipLevel
                snapshot.culling.selectedHZBMipSize = hzbStats.selectedMipSize

                snapshot.streaming.activeLoads = geometryStreamingStats.activeLoads
                snapshot.streaming.loadCandidates = geometryStreamingStats.loadCandidates
                snapshot.streaming.pendingLoadBacklog = geometryStreamingStats.pendingLoadBacklog
                snapshot.streaming.residentMeshEntities = meshResourceStats.activeEntities
                snapshot.streaming.cachedMeshResources = meshResourceStats.cachedMeshCount
                snapshot.streaming.pendingUploadCount = gateActiveLoads
                snapshot.streaming.blockedByGateMs = gateBlockedMs
                snapshot.streaming.loadedStreamingEntities = geometryStreamingStats.loadedCount
                snapshot.streaming.loadingStreamingEntities = geometryStreamingStats.loadingCount
                snapshot.streaming.unloadedStreamingEntities = geometryStreamingStats.unloadedCount

                snapshot.batching.batchGroupCount = batchGroups.count
                snapshot.batching.batchedMeshCount = batchedMeshCount
                snapshot.batching.rebuildsThisSecond = integrationStats.batchRebuildsThisSecond
            }
            EngineStatsMonitor.shared.completeFrame()
        }
    #endif

    private func tickFrameMonitors() {
        // Integration/HZB monitors remain runtime-driven and are available in all build configs.
        SystemIntegrationMonitor.shared.tick()
        HZBDebugMonitor.shared.tick()
        #if ENGINE_STATS_ENABLED
            EngineStatsMonitor.shared.tick()
        #endif
    }

    @discardableResult
    private func runFrame(beforeRender: (() -> Void)? = nil,
                          render: (() -> Void)? = nil,
                          afterRender: (() -> Void)? = nil,
                          statsLifecycle: StatsLifecycleMode = .internalManaged) -> Bool
    {
        #if ENGINE_STATS_ENABLED
            let wallFrameStartTime = CACurrentMediaTime()
            let frameStartTime: Double
            switch statsLifecycle {
            case .internalManaged:
                frameStartTime = wallFrameStartTime
                EngineStatsMonitor.shared.beginFrame(timestampSeconds: frameStartTime)
                RenderStatsCollector.shared.reset()
            case .externalManaged:
                frameStartTime = 0.0
            }
        #endif
        EngineProfiler.shared.beginFrame()
        lockWorldAccessGate()
        defer { unlockWorldAccessGate() }

        // finalize destroys once per frame
        if needsFinalizeDestroys {
            needsFinalizeDestroys = false
            if hasPendingDestroys {
                finalizePendingDestroys()
                hasPendingDestroys = false
            }
        }

        MemoryBudgetManager.shared.beginFrame()

        // must have a valid camera
        guard CameraSystem.shared.activeCamera != .invalid else {
            handleError(.noActiveCamera)
            #if ENGINE_STATS_ENABLED
                if statsLifecycle == .internalManaged {
                    let frameTotalMs = (CACurrentMediaTime() - frameStartTime) * 1000.0
                    EngineStatsMonitor.shared.update { snapshot in
                        snapshot.timing.frameTotalMs = frameTotalMs
                    }
                    EngineStatsMonitor.shared.completeFrame()
                }
            #endif
            EngineProfiler.shared.endFrame()
            return false
        }

        // Get camera position
        if let camera = CameraSystem.shared.activeCamera,
           let transform = scene.get(component: WorldTransformComponent.self, for: camera)
        {
            let cameraPos = simd_float3(
                transform.space.columns.3.x,
                transform.space.columns.3.y,
                transform.space.columns.3.z
            )
            let cameraLocalPos = scene.get(component: CameraComponent.self, for: camera)?.localPosition ?? cameraPos

            // === SYSTEM INTEGRATION PIPELINE ===
            // Order matters: Streaming -> LOD -> Batching -> Render

            // 1. Update streaming region manager
            #if ENGINE_STATS_ENABLED
                let streamingRegionStart = CACurrentMediaTime()
            #endif
            EngineProfiler.shared.beginScope(.streamingRegion)
            StreamingRegionManager.shared.update(
                cameraPosition: cameraPos,
                deltaTime: fixedStep
            )
            EngineProfiler.shared.endScope(.streamingRegion)
            #if ENGINE_STATS_ENABLED
                let streamingRegionMs = (CACurrentMediaTime() - streamingRegionStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.streamingRegionMs += streamingRegionMs
                }
            #endif

            // 2. Update geometry streaming (decides what meshes exist in memory)
            #if ENGINE_STATS_ENABLED
                let geometryStreamingStart = CACurrentMediaTime()
            #endif
            EngineProfiler.shared.beginScope(.geometryStreaming)
            GeometryStreamingSystem.shared.update(
                cameraPosition: cameraPos,
                deltaTime: fixedStep
            )
            EngineProfiler.shared.endScope(.geometryStreaming)
            #if ENGINE_STATS_ENABLED
                let geometryStreamingMs = (CACurrentMediaTime() - geometryStreamingStart) * 1000.0
                EngineStatsMonitor.shared.update { snapshot in
                    snapshot.timing.geometryStreamingMs += geometryStreamingMs
                }
            #endif

            // 2b. Update texture streaming (upgrades/downgrades texture resolution by distance)
            TextureStreamingSystem.shared.update(
                cameraPosition: cameraLocalPos,
                deltaTime: fixedStep
            )
        }

        frameCount += 1

        // pre-render hook (e.g., editor hot reload)
        beforeRender?()

        // simulation/update pipeline
        #if ENGINE_STATS_ENABLED
            let updateStart = CACurrentMediaTime()
        #endif
        EngineProfiler.shared.beginScope(.update)
        calculateDeltaTime()
        traverseSceneGraph()
        handleInputCallback?()

        // 3. LOD selection (decides which representation is active, checks residency)
        LODSystem.shared.update(deltaTime: fixedStep)

        // 4. Flush events (residency and LOD change events are processed)
        SystemEventBus.shared.flushEvents()

        // 5. Batching incremental update (consumes LOD change events)
        // Note: ProgressiveAssetLoader.shared.tick() is called before runFrame() in draw()
        // (non-XR) or via DispatchQueue.main.async in UntoldEngineXR.renderNewFrame() (XR).
        // It is NOT called here because runFrame() is invoked from the visionOS compositor
        // render thread in XR, which violates tick()'s main-thread precondition.
        #if ENGINE_STATS_ENABLED
            let batchingTickStart = CACurrentMediaTime()
        #endif
        EngineProfiler.shared.beginScope(.batchingTick)
        BatchingSystem.shared.tick()
        BatchingSystem.shared.logMaterialDiagnosticsIfDue()
        EngineProfiler.shared.endScope(.batchingTick)
        #if ENGINE_STATS_ENABLED
            let batchingTickMs = (CACurrentMediaTime() - batchingTickStart) * 1000.0
            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.batchingTickMs += batchingTickMs
            }
        #endif

        OctreeSystem.shared.updateDirtyBounds()

        if gameMode == true {
            AnimationSystem.shared.update(timeSinceLastUpdate)

            // USC scripts (runs every frame in Play mode)
            USCSystem.shared.update(timeSinceLastUpdate)

            // fixed‐timestep physics
            physicsAccumulator += timeSinceLastUpdate
            let maxSteps = 5
            var steps = 0
            while physicsAccumulator >= fixedStep, steps < maxSteps {
                updatePhysicsSystem(deltaTime: fixedStep)
                updateCustomSystems(deltaTime: fixedStep)
                physicsAccumulator -= fixedStep
                steps += 1
            }

            // user game update
            gameUpdateCallback?(timeSinceLastUpdate)
        }
        EngineProfiler.shared.endScope(.update)
        #if ENGINE_STATS_ENABLED
            let updateMs = (CACurrentMediaTime() - updateStart) * 1000.0
            EngineStatsMonitor.shared.update { snapshot in
                snapshot.timing.updateMs = updateMs
            }
        #endif

        // render hook (platform-specific)
        render?()

        // post-render hook (e.g., editor)
        afterRender?()

        #if ENGINE_STATS_ENABLED
            if statsLifecycle == .internalManaged {
                publishEngineStats(frameStartTime: frameStartTime)
                tickFrameMonitors()
            }
        #else
            if statsLifecycle == .internalManaged {
                tickFrameMonitors()
            }
        #endif
        EngineProfiler.shared.endFrame()
        return true
    }

    public func draw(in view: MTKView) {
        if pendingResize {
            initSizeableResources()
            pendingResize = false
        }
        // Tick the progressive loader here (main thread, before runFrame) so newly
        // registered entities are picked up by BatchingSystem in the same frame.
        // In XR, UntoldEngineXR.renderNewFrame() dispatches this to the main thread
        // separately, since its runLoop() runs on the compositor render thread.
        ProgressiveAssetLoader.shared.tick()
        _ = runFrame(
            beforeRender: { [weak self] in self?.delegate?.willDraw(in: view) },
            render: { [weak self] in
                guard let self else { return }
                configuration.updateRenderingSystemCallback(view)
            },
            afterRender: { [weak self] in self?.delegate?.didDraw(in: view) },
            statsLifecycle: .internalManaged
        )
    }

    public func mtkView(_ mtkView: MTKView, drawableSizeWillChange size: CGSize) {
        let oldSize = mtkView.drawableSize
        if size.width == 0 || size.height == 0 {
            return
        }

        let aspect = Float(size.width) / Float(size.height)
        let projectionMatrix = renderInfo.reverseZEnabled
            ? matrixPerspectiveRightHandReverseZ(fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far)
            : matrixPerspectiveRightHand(fovyRadians: degreesToRadians(degrees: fov), aspectRatio: aspect, nearZ: near, farZ: far)

        renderInfo.perspectiveSpace = projectionMatrix

        let viewPortSize: simd_float2 = simd_make_float2(Float(size.width), Float(size.height))
        renderInfo.viewPort = viewPortSize

        let sizeChanged = abs(oldSize.width - size.width) > 0.1 || abs(oldSize.height - size.height) > 0.1
        if size.width > 0, size.height > 0, sizeChanged {
            // Recreate viewport-sized resources once at the start of the next frame.
            if !pendingResize {
                pendingResize = true
            }
        }
    }

    // MARK: - XR Entry Point (VisionOS)

    @MainActor
    public static func createXR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, commandQueue: MTLCommandQueue, colorPixelFormat: MTLPixelFormat, depthPixelFormat: MTLPixelFormat, viewPort: simd_float2) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device
        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = true
        renderInfo.isXRStereoMode = true
        renderInfo.colorPixelFormat = colorPixelFormat
        renderInfo.depthPixelFormat = depthPixelFormat
        renderInfo.viewPort = viewPort

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = colorPixelFormat
        renderInfo.presentDepthPixelFormat = depthPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            handleError(.metalLibraryNotFound, error.localizedDescription)
        }

        renderer.initResources()

        renderEnvironment = true

        return renderer
    }

    @discardableResult
    public func updateXR(useExternalStatsLifecycle: Bool = false) -> Bool {
        runFrame(statsLifecycle: useExternalStatsLifecycle ? .externalManaged : .internalManaged)
    }

    @discardableResult
    public func updateXR(render: @escaping () -> Void, useExternalStatsLifecycle: Bool = false) -> Bool {
        runFrame(render: render, statsLifecycle: useExternalStatsLifecycle ? .externalManaged : .internalManaged)
    }

    /// Syncs the physical headset world position into the ECS camera components used by
    /// streaming and LOD distance calculations. Must be called before updateXR() each frame.
    ///
    /// Only the three position fields are written:
    ///   - LocalTransformComponent.position       — so traverseSceneGraph() derives a consistent WorldTransformComponent
    ///   - CameraComponent.localPosition          — read directly by TextureStreamingSystem and LODSystem
    ///   - WorldTransformComponent.space.columns.3 — read directly by GeometryStreamingSystem and StreamingRegionManager
    ///                                               before traverseSceneGraph() runs
    ///
    /// viewSpace and rotation are intentionally left untouched; renderXR() sets viewSpace
    /// per-eye from the device anchor view matrix each frame.
    public func setXRCameraWorldPosition(_ worldPosition: simd_float3) {
        guard let camera = CameraSystem.shared.activeCamera,
              let localTransform = scene.get(component: LocalTransformComponent.self, for: camera),
              let cameraComp = scene.get(component: CameraComponent.self, for: camera),
              let worldTransform = scene.get(component: WorldTransformComponent.self, for: camera)
        else { return }

        localTransform.position = worldPosition
        cameraComp.localPosition = worldPosition
        // Only the translation column is touched; rotation and scale columns are unchanged.
        worldTransform.space.columns.3 = simd_float4(worldPosition, 1.0)
    }

    /// XR path finalization hook. Call this once after XR submission for the frame.
    public func finalizeXRStatsAndMonitors(frameStartTime: Double) {
        #if ENGINE_STATS_ENABLED
            publishEngineStats(frameStartTime: frameStartTime)
        #else
            _ = frameStartTime
        #endif
        tickFrameMonitors()
    }

    public func renderXR(
        commandBuffer: MTLCommandBuffer,
        passDescriptor: MTLRenderPassDescriptor,
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        eyeIndex: Int
    ) {
        renderInfo.perspectiveSpace = projectionMatrix

        guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
            handleError(.noActiveCamera)
            return
        }

        cameraComponent.viewSpace = viewMatrix

        // Save this eye's view-projection for next frame's per-eye HZB culling.
        if renderInfo.isXRStereoMode {
            let effectiveVM = SceneRootTransform.shared.effectiveViewMatrix(viewMatrix)
            let eyeVP = simd_mul(projectionMatrix, effectiveVM)
            if eyeIndex == 0 { renderInfo.xrEye0ViewProjection = eyeVP }
            else { renderInfo.xrEye1ViewProjection = eyeVP }
        }

        configuration.updateXRRenderingSystemCallback!(.xr(commandBuffer: commandBuffer, passDescriptor: passDescriptor))
    }

    public func getConfiguration() -> UntoldRendererConfig {
        configuration
    }

    @MainActor
    public static func createiOS(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView, immersionStyle: UntoldImmersionMode = .none) -> UntoldRenderer? {
        let renderer = UntoldRenderer(configuration: configuration)

        renderInfo.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            print("Error: Failed to create a Metal command queue.")
            return nil
        }

        renderInfo.commandQueue = commandQueue
        renderInfo.reverseZEnabled = true
        renderInfo.colorPixelFormat = view.colorPixelFormat
        renderInfo.depthPixelFormat = view.depthStencilPixelFormat
        renderInfo.viewPort = simd_float2(Float(view.bounds.size.width), Float(view.bounds.size.height))

        renderInfo.fence = renderInfo.device.makeFence()
        renderInfo.bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)
        renderInfo.textureLoader = MTKTextureLoader(device: renderInfo.device)

        renderInfo.presentColorPixelFormat = view.colorPixelFormat
        renderInfo.presentDepthPixelFormat = view.depthStencilPixelFormat
        renderInfo.colorPipeline = .standard(presentFormat: renderInfo.presentColorPixelFormat)
        renderInfo.colorPixelFormat = renderInfo.colorPipeline.working.sceneColor

        do {
            let mainLibrary = try renderInfo.device.makeLibraryFromBundle()
            renderInfo.library = mainLibrary
            Logger.log(message: "Found Untold Engine metallib")
        } catch {
            handleError(.metalLibraryNotFound, error.localizedDescription)
        }

        renderer.initResources()

        renderInfo.immersionStyle = immersionStyle
        return renderer
    }

    // MARK: - AR Entry Point (iOS)

    @MainActor
    public static func createAR(configuration: UntoldRendererConfig? = nil, device: MTLDevice, view: MTKView) -> UntoldRenderer? {
        createiOS(configuration: configuration, device: device, view: view, immersionStyle: .ar)
    }
}
