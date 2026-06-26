//
//  AppDelegate.swift
//  LargeSceneStreamingDemo
//

#if os(macOS)
    import AppKit
    import Observation
    import SwiftUI
    import UntoldEngine

    @MainActor
    @Observable
    final class LargeSceneStreamingState {
        var status = "Loading default remote scene..."
        var customManifestURL = ""
        var isLoading = false
        var tileBoundsEnabled = true
        var lodDebugEnabled = false
        var textureTierDebugEnabled = false
        var showStats = true
    }

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let windowSize = NSSize(width: 1440, height: 860)
            static let minimumWindowSize = NSSize(width: 1000, height: 680)
        }

        private var window: NSWindow!
        private var renderer: UntoldRenderer!
        private var gameScene: GameScene!
        private let state = LargeSceneStreamingState()

        func applicationDidFinishLaunching(_: Notification) {
            setupWindow()
            setupRendererAndScene()
            presentSceneView()
            gameScene.loadPreset(.dungeon)
        }

        func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            true
        }

        private func setupWindow() {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: Constants.windowSize),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Untold Engine Large Scene Streaming Demo"
            window.minSize = Constants.minimumWindowSize
            window.center()
        }

        private func setupRendererAndScene() {
            guard let renderer = UntoldRenderer.create() else {
                print("Failed to initialize UntoldRenderer.")
                NSApp.terminate(nil)
                return
            }

            self.renderer = renderer
            gameScene = GameScene()
            gameScene.onStatusChanged = { [weak state] message, isLoading in
                Task { @MainActor in
                    state?.status = message
                    state?.isLoading = isLoading
                }
            }

            renderer.setupCallbacks(
                gameUpdate: { [weak self] deltaTime in
                    self?.gameScene.update(deltaTime: deltaTime)
                },
                handleInput: { [weak self] in
                    self?.gameScene.handleInput()
                }
            )
        }

        private func presentSceneView() {
            guard let renderer else { return }

            let view = LargeSceneStreamingDemoView(
                renderer: renderer,
                state: state,
                actions: .init(
                    loadPreset: { [weak self] preset in self?.gameScene.loadPreset(preset) },
                    loadCustomURL: { [weak self] url in self?.gameScene.loadManifest(url: url, label: "Custom Manifest") },
                    loadFallbackField: { [weak self] in self?.gameScene.loadFallbackField() },
                    setTileBounds: { [weak self] enabled in self?.gameScene.setTileBoundsDebug(enabled) },
                    setLodDebug: { [weak self] enabled in self?.gameScene.setLodDebug(enabled) },
                    setTextureTierDebug: { [weak self] enabled in self?.gameScene.setTextureTierDebug(enabled) }
                )
            )

            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private struct LargeSceneStreamingActions {
        let loadPreset: (GameScene.RemoteScenePreset) -> Void
        let loadCustomURL: (URL) -> Void
        let loadFallbackField: () -> Void
        let setTileBounds: (Bool) -> Void
        let setLodDebug: (Bool) -> Void
        let setTextureTierDebug: (Bool) -> Void
    }

    private struct LargeSceneStreamingDemoView: View {
        let renderer: UntoldRenderer
        @Bindable var state: LargeSceneStreamingState
        let actions: LargeSceneStreamingActions

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                HStack(alignment: .top, spacing: 12) {
                    controls
                    if state.showStats {
                        statsPanel
                    }
                }
                .padding(16)
            }
        }

        private var controls: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Large Scene Streaming")
                        .font(.headline)
                    Text(state.status)
                        .font(.caption)
                        .foregroundStyle(state.isLoading ? .orange : .secondary)
                        .lineLimit(2)
                }

                HStack {
                    Button("Dungeon") { actions.loadPreset(.dungeon) }
                    Button("City") { actions.loadPreset(.city) }
                    Button("Field") { actions.loadFallbackField() }
                }

                HStack {
                    TextField("https://.../scene.json or file:///...", text: $state.customManifestURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 320)
                    Button("Load") {
                        guard let url = URL(string: state.customManifestURL), url.scheme != nil else {
                            state.status = "Enter a full manifest URL."
                            return
                        }
                        actions.loadCustomURL(url)
                    }
                }

                Toggle("Tile Bounds", isOn: $state.tileBoundsEnabled)
                    .onChange(of: state.tileBoundsEnabled) { _, enabled in actions.setTileBounds(enabled) }
                Toggle("LOD Debug", isOn: $state.lodDebugEnabled)
                    .onChange(of: state.lodDebugEnabled) { _, enabled in actions.setLodDebug(enabled) }
                Toggle("Texture Tier Debug", isOn: $state.textureTierDebugEnabled)
                    .onChange(of: state.textureTierDebugEnabled) { _, enabled in actions.setTextureTierDebug(enabled) }
                Toggle("Stats", isOn: $state.showStats)

                Text("WASD move  |  Q/E up-down  |  Right-drag orbit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 420, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        private var statsPanel: some View {
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                let stats = getEngineStatsSnapshot()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Streaming Stats")
                        .font(.headline)
                    stat("Active loads", stats.streaming.activeLoads)
                    stat("Candidates", stats.streaming.loadCandidates)
                    stat("Loaded mesh entities", stats.streaming.residentMeshEntities)
                    stat("Full tiles visible", stats.streaming.visibleFullTileRepresentations)
                    stat("LOD visible", stats.streaming.visibleLODRepresentations)
                    stat("HLOD visible", stats.streaming.visibleHLODRepresentations)
                    stat("Batch groups", stats.batching.batchGroupCount)
                    stat("Draw calls", stats.render.drawCallsTotal)
                    stat("Mesh memory", "\(stats.memory.meshMemoryBytes / (1024 * 1024)) MB")
                }
                .padding(12)
                .frame(width: 230, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }

        private func stat(_ label: String, _ value: some CustomStringConvertible) -> some View {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value.description)
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
#endif
