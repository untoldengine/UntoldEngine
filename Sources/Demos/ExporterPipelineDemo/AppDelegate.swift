//
//  AppDelegate.swift
//  ExporterPipelineDemo
//

#if os(macOS)
    import AppKit
    import Observation
    import SwiftUI
    import UntoldEngine

    @MainActor
    @Observable
    final class ExporterPipelineState {
        var selectedAsset: ExportedAssetOption = .redplayer
        var selectedAnimation: ExportedAnimationOption = .idle
        var status = PipelineStatus()
    }

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let windowSize = NSSize(width: 1280, height: 780)
            static let minimumWindowSize = NSSize(width: 920, height: 620)
        }

        private var window: NSWindow!
        private var renderer: UntoldRenderer!
        private var gameScene: GameScene!
        private let state = ExporterPipelineState()

        func applicationDidFinishLaunching(_: Notification) {
            setupWindow()
            setupRendererAndScene()
            presentSceneView()
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
            window.title = "Untold Engine Exporter Pipeline Demo"
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
            gameScene.onStatusChanged = { [weak state] status in
                Task { @MainActor in
                    state?.status = status
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

            let view = ExporterPipelineDemoView(
                renderer: renderer,
                state: state,
                actions: .init(
                    loadAsset: { [weak self] asset in self?.gameScene.loadAsset(asset) },
                    loadAnimation: { [weak self] animation in self?.gameScene.loadAnimation(animation) },
                    reset: { [weak self] in self?.gameScene.resetScene() }
                )
            )

            window.contentView = NSHostingView(rootView: view)
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private struct ExporterPipelineActions {
        let loadAsset: (ExportedAssetOption) -> Void
        let loadAnimation: (ExportedAnimationOption) -> Void
        let reset: () -> Void
    }

    private struct ExporterPipelineDemoView: View {
        let renderer: UntoldRenderer
        @Bindable var state: ExporterPipelineState
        let actions: ExporterPipelineActions

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)
                panel
                    .padding(16)
            }
        }

        private var panel: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exporter Pipeline")
                    .font(.headline)

                Picker("Asset", selection: $state.selectedAsset) {
                    ForEach(ExportedAssetOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                HStack {
                    Button("Load Model") {
                        actions.loadAsset(state.selectedAsset)
                    }
                    Button("Reset") {
                        actions.reset()
                    }
                }

                Divider()

                Picker("Animation", selection: $state.selectedAnimation) {
                    ForEach(ExportedAnimationOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .disabled(!state.selectedAsset.supportsAnimation)

                Button("Load Animation") {
                    actions.loadAnimation(state.selectedAnimation)
                }
                .disabled(!state.selectedAsset.supportsAnimation)

                Divider()

                statusRows

                Text("Right-drag to orbit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 390, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }

        private var statusRows: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(state.status.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                row("Entity", state.status.loadedEntity)
                row("Asset exists", state.status.assetExists ? "Yes" : "No")
                row("Validation", state.status.validation.found ? "Found" : "Missing")
                row("Asset name", state.status.validation.assetName)
                row("Meshes", "\(state.status.validation.meshCount)")
                row("Vertices", "\(state.status.validation.totalVertices)")
                row("Indices", "\(state.status.validation.totalIndices)")
                row("Clips", state.status.animationClips)

                Text(state.status.assetPath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }
        }

        private func row(_ label: String, _ value: String) -> some View {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .monospacedDigit()
            }
            .font(.caption)
        }
    }
#endif
