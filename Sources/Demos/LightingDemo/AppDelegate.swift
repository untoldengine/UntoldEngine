#if os(macOS)
    import AppKit
    import Observation
    import SwiftUI
    import UntoldEngine

    @MainActor @Observable
    final class LightingState {
        var dirEnabled: Bool = true
        var dirIntensity: Double = 1.2

        var pointEnabled: Bool = true
        var pointIntensity: Double = 3.0

        var spotEnabled: Bool = true
        var spotIntensity: Double = 4.0
        var spotConeAngle: Double = 20.0

        var areaEnabled: Bool = true
        var areaIntensity: Double = 2.0
    }

    struct LightingActions {
        let onDirChanged: () -> Void
        let onPointChanged: () -> Void
        let onSpotChanged: () -> Void
        let onAreaChanged: () -> Void
    }

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let windowSize = NSSize(width: 1280, height: 760)
            static let minimumWindowSize = NSSize(width: 800, height: 600)
        }

        private var window: NSWindow!
        private var renderer: UntoldRenderer!
        private var gameScene: GameScene!
        private let state = LightingState()

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
            window.title = "Untold Engine – Lighting Demo"
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
            renderer.setupCallbacks(
                gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
                handleInput: { [weak self] in self?.gameScene.handleInput() }
            )
        }

        private func presentSceneView() {
            guard let renderer else { return }
            window.contentView = NSHostingView(
                rootView: LightingDemoView(renderer: renderer, state: state, actions: makeActions())
            )
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        private func makeActions() -> LightingActions {
            LightingActions(
                onDirChanged: { [weak self] in
                    guard let self else { return }
                    gameScene.setDirLight(enabled: state.dirEnabled, intensity: Float(state.dirIntensity))
                },
                onPointChanged: { [weak self] in
                    guard let self else { return }
                    gameScene.setPointLight(enabled: state.pointEnabled, intensity: Float(state.pointIntensity))
                },
                onSpotChanged: { [weak self] in
                    guard let self else { return }
                    gameScene.setSpotLight(
                        enabled: state.spotEnabled,
                        intensity: Float(state.spotIntensity),
                        coneAngle: Float(state.spotConeAngle)
                    )
                },
                onAreaChanged: { [weak self] in
                    guard let self else { return }
                    gameScene.setAreaLight(enabled: state.areaEnabled, intensity: Float(state.areaIntensity))
                }
            )
        }
    }

    // MARK: - HUD

    struct LightingDemoView: View {
        let renderer: UntoldRenderer
        @Bindable var state: LightingState
        let actions: LightingActions

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                ScrollView {
                    controlsPanel
                }
                .frame(width: 300)
                .frame(maxHeight: 680)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(16)
            }
        }

        private var controlsPanel: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Lighting").font(.headline)
                Text("Right-drag to orbit")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                lightSection(
                    title: "DIRECTIONAL",
                    code: "createDirLight(entityId:)",
                    enabled: $state.dirEnabled,
                    intensity: $state.dirIntensity,
                    intensityRange: 0 ... 3,
                    onChange: actions.onDirChanged
                )

                Divider()

                lightSection(
                    title: "POINT",
                    code: "createPointLight(entityId:)",
                    enabled: $state.pointEnabled,
                    intensity: $state.pointIntensity,
                    intensityRange: 0 ... 8,
                    onChange: actions.onPointChanged
                )

                Divider()

                spotSection

                Divider()

                lightSection(
                    title: "AREA",
                    code: "createAreaLight(entityId:)",
                    enabled: $state.areaEnabled,
                    intensity: $state.areaIntensity,
                    intensityRange: 0 ... 6,
                    onChange: actions.onAreaChanged
                )
            }
            .padding(12)
        }

        private var spotSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "SPOT", code: "createSpotLight(entityId:)")

                Toggle("Enabled", isOn: $state.spotEnabled)
                    .onChange(of: state.spotEnabled) { _, _ in actions.onSpotChanged() }

                slider("Intensity", $state.spotIntensity, 0 ... 10, state.spotEnabled, actions.onSpotChanged)
                slider("Cone Angle", $state.spotConeAngle, 5 ... 60, state.spotEnabled, actions.onSpotChanged)
            }
        }

        private func lightSection(
            title: String,
            code: String,
            enabled: Binding<Bool>,
            intensity: Binding<Double>,
            intensityRange: ClosedRange<Double>,
            onChange: @escaping () -> Void
        ) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: title, code: code)

                Toggle("Enabled", isOn: enabled)
                    .onChange(of: enabled.wrappedValue) { _, _ in onChange() }

                slider("Intensity", intensity, intensityRange, enabled.wrappedValue, onChange)
            }
        }

        private func sectionHeader(title: String, code: String) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(code)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }

        private func slider(
            _ label: String,
            _ value: Binding<Double>,
            _ range: ClosedRange<Double>,
            _ enabled: Bool,
            _ onChange: @escaping () -> Void
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                    Spacer()
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: value, in: range)
                    .onChange(of: value.wrappedValue) { _, _ in onChange() }
            }
            .font(.caption)
            .opacity(enabled ? 1.0 : 0.35)
            .disabled(!enabled)
        }
    }
#endif
