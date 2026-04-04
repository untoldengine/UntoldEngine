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

        var renderer: UntoldRenderer
        @Bindable var state: DemoState
        @State private var showFilePicker = false
        @State private var showManifestPicker = false

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Load USDZ...") { showFilePicker = true }
                            .buttonStyle(.bordered)
                            .disabled(state.isLoading)
                        Button("Load Streamable Scene...") { showManifestPicker = true }
                            .buttonStyle(.bordered)
                            .disabled(state.isLoading)
                        if state.isLoading {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 16, height: 16)
                        }
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
            .onReceive(Timer.publish(every: Constants.statsRefreshInterval, on: .main, in: .common).autoconnect()) { _ in
                if state.showStats {
                    state.stats = getEngineStatsSnapshot()
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType(filenameExtension: "untold") ?? .data]
            ) { result in
                guard case let .success(url) = result else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                let path = url.deletingPathExtension().path

                state.batchingEnabled = false
                state.streamingEnabled = false
                state.isLoading = true

                guard let onLoadFile = state.onLoadFile else {
                    state.isLoading = false
                    if accessing { url.stopAccessingSecurityScopedResource() }
                    return
                }

                onLoadFile(path) { isOutOfCore in
                    state.isLoading = false
                    state.hasLoadedEntity = true
                    if isOutOfCore {
                        state.streamingEnabled = true
                    }
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            }
            .fileImporter(
                isPresented: $showManifestPicker,
                allowedContentTypes: [UTType(filenameExtension: "json") ?? .json]
            ) { result in
                guard case let .success(url) = result else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                // Pass the path without extension — LoadingSystem handles absolute paths.
                let path = url.deletingPathExtension().path

                state.batchingEnabled = false
                state.streamingEnabled = false
                state.isLoading = true

                guard let onLoadTiledScene = state.onLoadTiledScene else {
                    state.isLoading = false
                    if accessing { url.stopAccessingSecurityScopedResource() }
                    return
                }

                onLoadTiledScene(path) { _ in
                    state.isLoading = false
                    state.hasLoadedEntity = true
                    state.streamingEnabled = true
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            }
        }

        private func sectionLabel(_ text: String) -> some View {
            Text(text)
                .font(.system(.caption, design: .default).weight(.semibold))
                .foregroundStyle(.secondary)
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
