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
                row("CPU Frame", String(format: "%.2f ms", stats.timing.frameTotalMs))
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

    struct DemoHUD: View {
        private enum Constants {
            static let statsRefreshInterval: TimeInterval = 0.1
            static let usdzExtension = "usdz"
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

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("SCENES")

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
                        Menu("Select") {
                            Button("Asset (.untold)", action: openLocalAssetPicker)
                            Button("Tiled Scene (.json)", action: openLocalTiledScenePicker)
                        }
                        .disabled(state.isLoading)
                        Spacer(minLength: 0)
                    }

                    Divider()

                    sectionLabel("CONTROLS")
                    controlHint("WASD / QE", "Translate")
                    controlHint("Right-click drag", "Rotate")

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
                .padding(12)
                .fixedSize(horizontal: true, vertical: false)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding()

                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 12) {
                        if state.showStats {
                            StatsPanel(stats: state.stats)
                                .frame(width: 260)
                        }

                        DemoToolsPanel(
                            isBusy: state.isLoading || state.isExporting,
                            isExporting: state.isExporting,
                            openExportSheet: { state.showExportPanel = true }
                        )
                        .frame(width: 260)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, alignment: .topTrailing)
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

            onLoadTiledScene(scene.id, manifestURL) { success in
                Task { @MainActor in
                    state.isLoading = false
                    state.hasLoadedEntity = success
                    state.streamingEnabled = success
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
                    finishLocalImport(url: url, accessing: accessing, success: success, streamingEnabled: success)
                }
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
