//
//  main.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(macOS)
    import MetalKit
    import SwiftUI
    import UniformTypeIdentifiers
    import UntoldEngine

    // MARK: - GameScene
    // All engine API calls live here. DemoState holds UI state only and
    // delegates to these methods via callbacks wired up in AppDelegate.

    class GameScene {
        var loadedEntity: EntityID? = nil
        private var wasRightMousePressed: Bool = false

        init() {
            InputSystem.shared.registerKeyboardEvents()
            InputSystem.shared.registerMouseEvents()
            bypassPostProcessing = true
//            SSAO.setEnabled(false)
//            SSAO.setQuality(.high)
            setupDefaultSceneObjects()
        }

        private func setupDefaultSceneObjects() {
            let gameCamera = createEntity()
            setEntityName(entityId: gameCamera, name: "Main Camera")
            createGameCamera(entityId: gameCamera)

            let light = createEntity()
            setEntityName(entityId: light, name: "Directional Light")
            createDirLight(entityId: light)

            CameraSystem.shared.activeCamera = gameCamera
        }

        /// Loads a USDZ file into the scene, replacing any previously loaded model.
        ///
        /// The work is staged across two callbacks:
        ///   1. `destroyAllEntities` fires once the engine has fully cleaned up the
        ///      previous frame's entities — safe to create new ones here.
        ///   2. `setEntityMeshAsync` fires when the mesh has finished loading off the
        ///      main thread — safe to signal the UI here.
        func loadFile(path: String, completion: @escaping () -> Void) {
            clearSceneBatches()
            loadedEntity = nil

            // Stage 1 — teardown complete, rebuild the scene.
            destroyAllEntities {
                self.setupDefaultSceneObjects()

                // Plant the orbit pivot 5 units in front of the freshly-created camera.
                let camera = findGameCamera()
                setOrbitOffset(entityId: camera, uTargetOffset: 5.0)

                let entity = createEntity()
                self.loadedEntity = entity

                // Stage 2 — mesh loaded, notify the UI.
                setEntityMeshAsync(entityId: entity, filename: path, withExtension: "usdz") { _ in
                    completion()
                }
            }
        }

        /// Marks the loaded entity as a static batch and generates batches,
        /// or disables the batching system when turned off.
        func setBatching(_ enabled: Bool) {
            guard let entity = loadedEntity else { return }
            if enabled {
                setEntityStaticBatchComponent(entityId: entity)
                enableBatching(true)
                generateBatches()
            } else {
                enableBatching(false)
            }
        }

        /// Attaches a streaming component to the loaded entity and enables the
        /// geometry streaming system, or shuts it down when turned off.
        func setStreaming(_ enabled: Bool, streamingRadius: Float, unloadRadius: Float) {
            guard let entity = loadedEntity else { return }
            if enabled {
                enableStreaming(
                    entityId: entity,
                    streamingRadius: streamingRadius,
                    unloadRadius: unloadRadius,
                    priority: 10
                )
                GeometryStreamingSystem.shared.enabled = true
            } else {
                GeometryStreamingSystem.shared.enabled = false
            }
        }

        /// Toggles the per-entity LOD level colour overlay.
        func setLodDebug(_ enabled: Bool) {
            setLODLevelDebug(enabled: enabled)
        }

        /// Toggles the texture streaming tier colour overlay.
        func setStreamingTierDebug(_ enabled: Bool) {
            setTextureStreamingTierDebug(enabled: enabled)
        }

        /// Draws (or hides) the octree leaf-node bounds debug overlay.
        func setSpatialDebug(
            enabled: Bool,
            occupiedOnly: Bool,
            colorMode: SpatialDebugLeafColorMode
        ) {
            if enabled {
                setOctreeLeafBoundsDebug(
                    enabled: true,
                    maxLeafNodeCount: 0,
                    occupiedOnly: occupiedOnly,
                    colorMode: colorMode
                )
            } else {
                disableSpatialDebugVisualization()
            }
        }

        func update(deltaTime _: Float) {
            if gameMode == false { return }
        }

        func handleInput() {
            if gameMode == false { return }
            let input = InputSystem.shared
            let camera = findGameCamera()

            // WASD/QE — fly movement
            moveCameraWithInput(
                entityId: camera,
                input: (
                    w: input.keyState.wPressed,
                    a: input.keyState.aPressed,
                    s: input.keyState.sPressed,
                    d: input.keyState.dPressed,
                    q: input.keyState.qPressed,
                    e: input.keyState.ePressed
                ),
                speed: 1,
                deltaTime: 0.1
            )

            // Right mouse drag — orbit around focal point.
            // On the first frame of press, reset the orbit pivot to 5 units in front
            // of the camera's current position so WASD movement never causes a jump.
            // Lock to the dominant axis (yaw OR pitch per frame) to prevent roll drift.
            if input.keyState.rightMousePressed {
                if !wasRightMousePressed {
                    setOrbitOffset(entityId: camera, uTargetOffset: 5.0)
                }
                var dx = input.mouseDeltaX
                var dy = input.mouseDeltaY
                if abs(dx) < abs(dy) { dx = 0 } else { dy = 0 }
                orbitCameraAround(entityId: camera, uDelta: simd_float2(dx, dy))
            }
            wasRightMousePressed = input.keyState.rightMousePressed

//            // Scroll wheel — dolly in/out (vertical scroll) or pan left/right (horizontal scroll).
//            // Lock to the dominant axis to avoid diagonal drift.
//            let scroll = input.scrollDelta
//            if scroll.x != 0 || scroll.y != 0 {
//                var dx = scroll.x
//                var dy = scroll.y
//                if abs(dx) < abs(dy) { dx = 0 } else { dy = 0 }
//                moveCameraAlongAxis(entityId: camera, uDelta: simd_float3(dx * 0.05, 0, dy * 0.05))
//                input.scrollDelta = .zero
//            }
        }
    }

    // MARK: - DemoState
    // Pure UI state. No engine calls here — each property fires a callback
    // that AppDelegate wires to the matching GameScene method.

    @Observable class DemoState {

        // ── File loading ──────────────────────────────────────────────────
        var hasLoadedEntity: Bool = false
        var isLoading: Bool = false

        // ── Features ──────────────────────────────────────────────────────
        var batchingEnabled: Bool = false {
            didSet { onBatchingChanged?(batchingEnabled) }
        }

        var streamingEnabled: Bool = false {
            didSet { onStreamingChanged?(streamingEnabled, streamingRadius, unloadRadius) }
        }
        var streamingRadius: Double = 250.0 {
            didSet { if streamingEnabled { onStreamingChanged?(true, streamingRadius, unloadRadius) } }
        }
        var unloadRadius: Double = 350.0 {
            didSet { if streamingEnabled { onStreamingChanged?(true, streamingRadius, unloadRadius) } }
        }

        // ── Debug ─────────────────────────────────────────────────────────
        var lodDebugEnabled: Bool = false {
            didSet { onLodDebugChanged?(lodDebugEnabled) }
        }

        var textureStreamingTierDebugEnabled: Bool = false {
            didSet { onTextureStreamingTierDebugChanged?(textureStreamingTierDebugEnabled) }
        }

        var spatialDebugEnabled: Bool = false {
            didSet { onSpatialDebugChanged?(spatialDebugEnabled, spatialOccupiedOnly, spatialColorMode) }
        }
        var spatialColorMode: SpatialDebugLeafColorMode = .plain {
            didSet { if spatialDebugEnabled { onSpatialDebugChanged?(true, spatialOccupiedOnly, spatialColorMode) } }
        }
        var spatialOccupiedOnly: Bool = true {
            didSet { if spatialDebugEnabled { onSpatialDebugChanged?(true, spatialOccupiedOnly, spatialColorMode) } }
        }

        // ── Stats ─────────────────────────────────────────────────────────
        var showStats: Bool = true
        var stats: EngineStatsSnapshot = .init()

        // ── Callbacks — wired by AppDelegate ──────────────────────────────
        var onLoadFile: ((String, @escaping () -> Void) -> Void)?
        var onBatchingChanged: ((Bool) -> Void)?
        var onStreamingChanged: ((Bool, Double, Double) -> Void)?
        var onLodDebugChanged: ((Bool) -> Void)?
        var onTextureStreamingTierDebugChanged: ((Bool) -> Void)?
        var onSpatialDebugChanged: ((Bool, Bool, SpatialDebugLeafColorMode) -> Void)?
    }

    // MARK: - StatsPanel

    struct StatsPanel: View {
        let stats: EngineStatsSnapshot

        private var fps: Double {
            stats.timing.smoothedFrameMs > 0 ? 1000.0 / stats.timing.smoothedFrameMs : 0
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Engine Stats").font(.headline)
                Divider()

                // Timing
                row("FPS",       String(format: "%.1f",    fps))
                row("CPU Frame", String(format: "%.2f ms", stats.timing.frameTotalMs))
                row("GPU",       String(format: "%.2f ms", stats.timing.gpuExecutionMs))
                Divider()

                // Render
                row("Draw Calls",  "\(stats.render.drawCallsTotal)")
                row("  Opaque",    "\(stats.render.drawCallsOpaque)")
                row("  Batched",   "\(stats.render.drawCallsBatched)")
                row("Triangles",   fmt(stats.render.trianglesTotal))
                row("Visible",     "\(stats.render.visibleInstances)")
                Divider()

                // Culling
                row("Frustum",   "\(stats.culling.frustumPassed) / \(stats.culling.frustumTested)")
                row("Occlusion", "\(stats.culling.occlusionPassed) / \(stats.culling.occlusionTested)")
                Divider()

                // Batching
                row("Batch Groups",   "\(stats.batching.batchGroupCount)")
                row("Batched Meshes", "\(stats.batching.batchedMeshCount)")
            }
            .font(.system(.caption, design: .monospaced))
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        private func row(_ label: String, _ value: String) -> some View {
            HStack {
                Text(label).foregroundStyle(.secondary)
                Spacer()
                Text(value)
            }
        }

        private func fmt(_ n: Int) -> String {
            if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
            if n >= 1_000     { return String(format: "%.1fK", Double(n) / 1_000) }
            return "\(n)"
        }
    }

    // MARK: - DemoHUD

    struct DemoHUD: View {
        var renderer: UntoldRenderer
        @Bindable var state: DemoState
        @State private var showFilePicker = false

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                // Controls panel — top left
                VStack(alignment: .leading, spacing: 8) {

                    // ── Load ──────────────────────────────────────────────
                    HStack(spacing: 8) {
                        Button("Load USDZ...") { showFilePicker = true }
                            .buttonStyle(.bordered)
                            .disabled(state.isLoading)
                        if state.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        }
                    }

                    Divider()

                    // ── Controls ──────────────────────────────────────────
                    sectionLabel("CONTROLS")
                    controlHint("WASD / QE", "Translate")
                    controlHint("Right-click drag", "Rotate")

                    Divider()

                    // ── Features ──────────────────────────────────────────
                    sectionLabel("FEATURES")

                    Toggle("Static Batching", isOn: $state.batchingEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!state.hasLoadedEntity || state.isLoading)

                    Toggle("Geometry Streaming", isOn: $state.streamingEnabled)
                        .toggleStyle(.checkbox)
                        .disabled(!state.hasLoadedEntity || state.isLoading)

                    HStack {
                        Text("Stream Radius").foregroundStyle(.secondary)
                        Spacer()
                        TextField("", value: $state.streamingRadius, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    .padding(.leading, 12)
                    .opacity(state.streamingEnabled ? 1.0 : 0.35)
                    .disabled(!state.streamingEnabled)

                    HStack {
                        Text("Unload Radius").foregroundStyle(.secondary)
                        Spacer()
                        TextField("", value: $state.unloadRadius, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 70)
                    }
                    .padding(.leading, 12)
                    .opacity(state.streamingEnabled ? 1.0 : 0.35)
                    .disabled(!state.streamingEnabled)

                    Divider()

                    // ── Debug ─────────────────────────────────────────────
                    sectionLabel("DEBUG")

                    Toggle("LOD Debug", isOn: $state.lodDebugEnabled)
                        .toggleStyle(.checkbox)

                    Toggle("Texture Streaming Debug", isOn: $state.textureStreamingTierDebugEnabled)
                        .toggleStyle(.checkbox)

                    Toggle("Spatial Debug", isOn: $state.spatialDebugEnabled)
                        .toggleStyle(.checkbox)
                    if state.spatialDebugEnabled {
                        Toggle("Occupied Only", isOn: $state.spatialOccupiedOnly)
                            .toggleStyle(.checkbox)
                            .padding(.leading, 12)
                        Picker("Mode", selection: $state.spatialColorMode) {
                            Text("Plain").tag(SpatialDebugLeafColorMode.plain)
                            Text("Residency").tag(SpatialDebugLeafColorMode.residency)
                            Text("Culling").tag(SpatialDebugLeafColorMode.culling)
                        }
                        .pickerStyle(.segmented)
                        .frame(minWidth: 180)
                    }

                    Divider()

                    // ── Stats ─────────────────────────────────────────────
                    Toggle("Engine Stats", isOn: $state.showStats)
                        .toggleStyle(.checkbox)
                }
                .padding(12)
                .fixedSize(horizontal: true, vertical: false)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()

                // Stats panel — top right
                if state.showStats {
                    HStack {
                        Spacer()
                        StatsPanel(stats: state.stats)
                            .frame(width: 260)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }
            .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
                if state.showStats {
                    state.stats = getEngineStatsSnapshot()
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "usdz") ?? .data]
            ) { result in
                guard case .success(let url) = result else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                let path = url.deletingPathExtension().path
                state.batchingEnabled = false
                state.streamingEnabled = false
                state.isLoading = true
                state.onLoadFile?(path) {
                    state.isLoading = false
                    state.hasLoadedEntity = true
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            }
        }

        @ViewBuilder
        private func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(.secondary)
        }

        @ViewBuilder
        private func controlHint(_ key: String, _ action: String) -> some View {
            HStack {
                Text(key)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
                Text(action)
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 4)
        }
    }

    // MARK: - AppDelegate

    class AppDelegate: NSObject, NSApplicationDelegate {
        var window: NSWindow!
        var renderer: UntoldRenderer!
        var gameScene: GameScene!
        var demoState = DemoState()

        func applicationDidFinishLaunching(_: Notification) {
            print("Launching Untold Engine v0.11.2")

            // Step 1. Create and configure the window
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Untold Engine v0.11.2"
            window.center()

            // Step 2. Initialize the renderer
            guard let renderer = UntoldRenderer.create() else {
                print("Failed to initialize the renderer.")
                return
            }
            self.renderer = renderer

            // Step 3. Create the game scene and connect render callbacks
            gameScene = GameScene()
            renderer.setupCallbacks(
                gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
                handleInput: { [weak self] in self?.gameScene.handleInput() }
            )

            // Step 4. Wire DemoState callbacks to GameScene engine calls
            demoState.onLoadFile = { [weak self] path, completion in
                self?.gameScene.loadFile(path: path, completion: completion)
            }
            demoState.onBatchingChanged = { [weak self] enabled in
                self?.gameScene.setBatching(enabled)
            }
            demoState.onStreamingChanged = { [weak self] enabled, radius, unloadRadius in
                self?.gameScene.setStreaming(
                    enabled,
                    streamingRadius: Float(radius),
                    unloadRadius: Float(unloadRadius)
                )
            }
            demoState.onLodDebugChanged = { [weak self] enabled in
                self?.gameScene.setLodDebug(enabled)
            }
            demoState.onTextureStreamingTierDebugChanged = { [weak self] enabled in
                self?.gameScene.setStreamingTierDebug(enabled)
            }
            demoState.onSpatialDebugChanged = { [weak self] enabled, occupiedOnly, colorMode in
                self?.gameScene.setSpatialDebug(
                    enabled: enabled,
                    occupiedOnly: occupiedOnly,
                    colorMode: colorMode
                )
            }

            // Step 5. Present the HUD
            let hostingView = NSHostingView(rootView: DemoHUD(renderer: renderer, state: demoState))
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            true
        }
    }

    // MARK: - Entry point

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
#endif
