//
//  DemoHUD.swift
//

#if os(macOS)
    import SwiftUI
    import UniformTypeIdentifiers
    import UntoldEngine

    struct StatsPanel: View {
        let stats: EngineStatsSnapshot

        private var fps: Double {
            stats.timing.smoothedFrameMs > 0 ? 1000.0 / stats.timing.smoothedFrameMs : 0
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text("Engine Stats").font(.headline)
                Divider()

                row("FPS", String(format: "%.1f", fps))
                row("Frame Time", String(format: "%.2f ms", stats.timing.frameTotalMs))
                row("GPU", String(format: "%.2f ms", stats.timing.gpuExecutionMs))
                Divider()

                row("Draw Calls", "\(stats.render.drawCallsTotal)")
                row("  Opaque", "\(stats.render.drawCallsOpaque)")
                row("  Batched", "\(stats.render.drawCallsBatched)")
                row("Triangles", fmt(stats.render.trianglesTotal))
                row("Visible", "\(stats.render.visibleInstances)")
                Divider()

                row("Frustum", "\(stats.culling.frustumPassed) / \(stats.culling.frustumTested)")
                row("Occlusion", "\(stats.culling.occlusionPassed) / \(stats.culling.occlusionTested)")
                Divider()

                row("Batch Groups", "\(stats.batching.batchGroupCount)")
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
            if n >= 1000 { return String(format: "%.1fK", Double(n) / 1000) }
            return "\(n)"
        }
    }

    struct AntiAliasingOptionsView: View {
        @Bindable var state: DemoState

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text("Anti-Aliasing")
                    .foregroundStyle(.secondary)

                Picker("Anti-Aliasing", selection: $state.antiAliasingOption) {
                    ForEach(DemoState.AntiAliasingOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    struct DemoHUD: View {
        private struct ResolutionPreset: Identifiable {
            let label: String
            let size: NSSize

            var id: String {
                label
            }
        }

        private enum Constants {
            static let statsRefreshInterval: TimeInterval = 0.1
            static let usdzExtension = "usdz"
            static let compactWidth: CGFloat = 980
            static let panelCornerRadius: CGFloat = 8
            static let panelPadding: CGFloat = 12
            static let edgePadding: CGFloat = 16
            static let controlsPanelWidth: CGFloat = 320
            static let sidePanelWidth: CGFloat = 260
            static let resolutionPresets: [ResolutionPreset] = [
                .init(label: "800x600", size: NSSize(width: 800, height: 600)),
                .init(label: "1280x720", size: NSSize(width: 1280, height: 720)),
                .init(label: "1600x900", size: NSSize(width: 1600, height: 900)),
                .init(label: "1920x1080", size: NSSize(width: 1920, height: 1080)),
            ]
        }

        private enum LocalImportMode {
            case asset
            case tiledScene

            var allowedContentTypes: [UTType] {
                switch self {
                case .asset:
                    [UTType(filenameExtension: "untold") ?? .data]
                case .tiledScene:
                    [.json]
                }
            }
        }

        var renderer: UntoldRenderer
        @Bindable var state: DemoState
        @State private var showFilePicker = false
        @State private var localImportMode: LocalImportMode = .asset
        @State private var areControlsVisible = false
        @State private var areStatsVisibleInCompact = false

        var body: some View {
            GeometryReader { proxy in
                let isCompact = proxy.size.width < Constants.compactWidth
                let controlsWidth = max(
                    260,
                    min(Constants.controlsPanelWidth, proxy.size.width - Constants.edgePadding * 2)
                )
                let controlsHeight = max(0, proxy.size.height - Constants.edgePadding * 2)

                ZStack(alignment: .topLeading) {
                    SceneView(renderer: renderer)

                    if isCompact {
                        if areControlsVisible {
                            controlsPanelContainer(width: controlsWidth, maxHeight: controlsHeight)
                        }
                    } else {
                        controlsPanelContainer(width: Constants.controlsPanelWidth, maxHeight: controlsHeight)
                    }

                    if isCompact {
                        compactTopBar
                            .padding(Constants.edgePadding)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                    } else {
                        sidePanel
                            .padding(Constants.edgePadding)
                            .frame(maxWidth: .infinity, alignment: .topTrailing)
                    }
                }
            }
            .onReceive(Timer.publish(every: Constants.statsRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
                if state.showStats {
                    state.stats = getEngineStatsSnapshot()
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: localImportMode.allowedContentTypes
            ) { result in
                handleLocalImport(result)
            }
            .sheet(isPresented: $state.showExportPanel) {
                DemoExportSheet(state: state)
            }
        }

        private var controlsPanel: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    sectionLabel("SCENES")
                    Spacer()
                    resolutionMenu
                }

                HStack(alignment: .center, spacing: 8) {
                    Picker("Remote Scene", selection: $state.selectedRemoteSceneID) {
                        ForEach(state.remoteScenes) { scene in
                            Text(scene.title).tag(scene.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(state.isLoading || state.remoteScenes.isEmpty)
                    Button("Load", action: loadSelectedRemoteScene)
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .disabled(state.isLoading || state.selectedRemoteScene?.manifestURL == nil)
                    if state.isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 16, height: 16)
                    }
                }

                HStack(alignment: .center, spacing: 8) {
                    Text("Local Scene")
                        .foregroundStyle(.secondary)
                        .frame(width: 92, alignment: .leading)
                    Menu("Browse") {
                        Button("Asset (.untold)", action: openLocalAssetPicker)
                        Button("Tiled Scene (.json)", action: openLocalTiledScenePicker)
                    }
                    .disabled(state.isLoading)
                    Spacer(minLength: 0)
                }

                Divider()

                sectionLabel("CONTROLS")
                controlHint("WASD / QE", "Translate")
                controlHint("Right-drag (+ Shift)", "Orbit / Yaw")
                controlHint("Two-finger swipe (+ Shift)", "Orbit / Yaw")

                Divider()

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

                sectionLabel("POST FX")

                AntiAliasingOptionsView(state: state)

                HStack(alignment: .center, spacing: 8) {
                    Picker("Preset", selection: $state.selectedPostFXPreset) {
                        ForEach(DemoState.PostFXPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)

                    Button("Apply") {
                        state.applySelectedPostFXPreset()
                    }
                    .buttonStyle(.bordered)
                }

                Toggle("Color Grading", isOn: $state.colorGradingEnabled)
                    .toggleStyle(.checkbox)

                sliderRow(
                    title: "Exposure",
                    value: $state.exposure,
                    range: -4.0 ... 4.0,
                    enabled: state.colorGradingEnabled
                )

                sliderRow(
                    title: "Brightness",
                    value: $state.brightness,
                    range: -1.0 ... 1.0,
                    enabled: state.colorGradingEnabled
                )

                sliderRow(
                    title: "Contrast",
                    value: $state.contrast,
                    range: 0.0 ... 2.0,
                    enabled: state.colorGradingEnabled
                )

                sliderRow(
                    title: "Saturation",
                    value: $state.saturation,
                    range: 0.0 ... 2.0,
                    enabled: state.colorGradingEnabled
                )

                Toggle("SSAO", isOn: $state.ssaoEnabled)
                    .toggleStyle(.checkbox)

                sliderRow(
                    title: "SSAO Radius",
                    value: $state.ssaoRadius,
                    range: 0.1 ... 2.0,
                    enabled: state.ssaoEnabled
                )

                sliderRow(
                    title: "SSAO Bias",
                    value: $state.ssaoBias,
                    range: 0.0 ... 0.1,
                    enabled: state.ssaoEnabled
                )

                sliderRow(
                    title: "SSAO Intensity",
                    value: $state.ssaoIntensity,
                    range: 0.0 ... 2.0,
                    enabled: state.ssaoEnabled
                )

                Divider()

                sectionLabel("DEBUG")

                Toggle("LOD Debug", isOn: $state.lodDebugEnabled)
                    .toggleStyle(.checkbox)

                Toggle("Texture Streaming Debug", isOn: $state.textureStreamingTierDebugEnabled)
                    .toggleStyle(.checkbox)

                Picker("G-Buffer View", selection: $state.renderDebugView) {
                    Text("Lit").tag(RenderDebugViewMode.lit)
                    Text("Albedo").tag(RenderDebugViewMode.albedo)
                    Text("Normal").tag(RenderDebugViewMode.normal)
                    Text("Depth").tag(RenderDebugViewMode.depth)
                    Text("SSAO (Blurred)").tag(RenderDebugViewMode.ssaoBlurred)
                    Text("FXAA Edges").tag(RenderDebugViewMode.fxaaEdgeDebug)
                    Text("SMAA Edges").tag(RenderDebugViewMode.smaaEdges)
                    Text("SMAA Blend").tag(RenderDebugViewMode.smaaBlend)
                    Text("SMAA Difference").tag(RenderDebugViewMode.smaaDifference)
                }
                .pickerStyle(.menu)

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
                    Toggle("Tile Bounds", isOn: $state.tileBoundsEnabled)
                        .toggleStyle(.checkbox)
                        .padding(.leading, 12)
                }

                Divider()

                Toggle("Engine Stats", isOn: $state.showStats)
                    .toggleStyle(.checkbox)
            }
        }

        private func controlsPanelContainer(width: CGFloat, maxHeight: CGFloat) -> some View {
            ScrollView(.vertical) {
                controlsPanel
                    .padding(Constants.panelPadding)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollIndicators(.visible)
            .frame(width: width, alignment: .topLeading)
            .frame(maxHeight: maxHeight, alignment: .topLeading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.panelCornerRadius))
            .padding(Constants.edgePadding)
            .onHover { state.isMouseOverControlPanel = $0 }
        }

        private var sidePanel: some View {
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    if state.showStats {
                        StatsPanel(stats: state.stats)
                            .frame(width: Constants.sidePanelWidth)
                    }

                    DemoToolsPanel(
                        isBusy: state.isLoading || state.isExporting,
                        isExporting: state.isExporting,
                        openExportSheet: { state.showExportPanel = true }
                    )
                    .frame(width: Constants.sidePanelWidth)
                }
            }
        }

        private var compactTopBar: some View {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    Button(areControlsVisible ? "Hide Controls" : "Controls") {
                        areControlsVisible.toggle()
                    }
                    .buttonStyle(.borderedProminent)

                    resolutionMenu

                    Button(areStatsVisibleInCompact ? "Hide Stats" : "Stats") {
                        areStatsVisibleInCompact.toggle()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!state.showStats)

                    Button("Export") {
                        state.showExportPanel = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(state.isLoading || state.isExporting)
                }
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Constants.panelCornerRadius))

                if areStatsVisibleInCompact, state.showStats {
                    StatsPanel(stats: state.stats)
                        .frame(width: Constants.sidePanelWidth)
                }
            }
        }

        private var resolutionMenu: some View {
            Menu("Resolution") {
                ForEach(Constants.resolutionPresets) { preset in
                    Button(preset.label) {
                        resizeWindow(to: preset.size)
                    }
                }
            }
            .menuStyle(.button)
        }

        private func resizeWindow(to size: NSSize) {
            guard let window = NSApp.keyWindow ?? NSApp.windows.first else { return }
            window.setContentSize(size)
            window.center()
        }

        private func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(.secondary)
        }

        private func sliderRow(
            title: String,
            value: Binding<Double>,
            range: ClosedRange<Double>,
            enabled: Bool
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).foregroundStyle(.secondary)
                    Spacer()
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                        .font(.system(.caption, design: .monospaced))
                }

                Slider(value: value, in: range)
            }
            .padding(.leading, 12)
            .opacity(enabled ? 1.0 : 0.35)
            .disabled(!enabled)
        }

        private func loadSelectedRemoteScene() {
            guard let scene = state.selectedRemoteScene,
                  let manifestURL = scene.manifestURL,
                  let onLoadTiledScene = state.onLoadTiledScene
            else { return }

            state.batchingEnabled = false
            state.streamingEnabled = false
            state.isLoading = true

            let sceneID = scene.id
            onLoadTiledScene(sceneID, manifestURL) { success in
                Task { @MainActor in
                    state.isLoading = false
                    state.hasLoadedEntity = success
                    state.streamingEnabled = success
                    if success {
                        state.selectedPostFXPreset = Self.postFXPreset(for: sceneID)
                        state.applySelectedPostFXPreset()
                    }
                }
            }
        }

        private func openLocalAssetPicker() {
            localImportMode = .asset
            showFilePicker = true
        }

        private func openLocalTiledScenePicker() {
            localImportMode = .tiledScene
            showFilePicker = true
        }

        private func handleLocalImport(_ result: Result<URL, Error>) {
            guard case let .success(url) = result else { return }

            let accessing = url.startAccessingSecurityScopedResource()

            state.batchingEnabled = false
            state.streamingEnabled = false
            state.isLoading = true

            switch localImportMode {
            case .asset:
                loadLocalAsset(url: url, accessing: accessing)
            case .tiledScene:
                loadLocalTiledScene(url: url, accessing: accessing)
            }
        }

        private func loadLocalAsset(url: URL, accessing: Bool) {
            let path = url.deletingPathExtension().path

            guard let onLoadFile = state.onLoadFile else {
                finishLocalImport(url: url, accessing: accessing, success: false, streamingEnabled: false)
                return
            }

            onLoadFile(path) { success in
                Task { @MainActor in
                    if success {
                        state.selectedPostFXPreset = .neutral
                        state.applySelectedPostFXPreset()
                    }
                    finishLocalImport(url: url, accessing: accessing, success: success, streamingEnabled: false)
                }
            }
        }

        private func loadLocalTiledScene(url: URL, accessing: Bool) {
            guard let onLoadTiledScene = state.onLoadTiledScene else {
                finishLocalImport(url: url, accessing: accessing, success: false, streamingEnabled: false)
                return
            }

            let sceneID = url.deletingPathExtension().lastPathComponent

            onLoadTiledScene(sceneID, url) { success in
                Task { @MainActor in
                    if success {
                        state.selectedPostFXPreset = .neutral
                        state.applySelectedPostFXPreset()
                    }
                    finishLocalImport(url: url, accessing: accessing, success: success, streamingEnabled: success)
                }
            }
        }

        private static func postFXPreset(for sceneID: String) -> DemoState.PostFXPreset {
            switch sceneID {
            case "f1car", "airplane", "porsche964": .cinematic
            default: .neutral
            }
        }

        private func finishLocalImport(url: URL, accessing: Bool, success: Bool, streamingEnabled: Bool) {
            state.isLoading = false
            state.hasLoadedEntity = success
            state.streamingEnabled = streamingEnabled
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

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
#endif
