//
//  AppDelegate.swift
//  RenderingQualityDemo
//

#if os(macOS)
    import AppKit
    import Observation
    import SwiftUI
    import UntoldEngine

    @MainActor
    @Observable
    final class RenderingQualityState {
        var selectedPreset: QualityPreset = .neutral
        var selectedAA: AntiAliasingOption = .fxaa
        var selectedDebugView: DebugViewOption = .lit

        var colorGradingEnabled = false
        var exposure = 0.0
        var brightness = 0.0
        var contrast = 1.0
        var saturation = 1.0
        var temperature = 0.0
        var tint = 0.0

        var ssaoEnabled = false
        var ssaoQuality: SSAOQualityOption = .balanced
        var ssaoRadius = 0.75
        var ssaoBias = 0.02
        var ssaoIntensity = 0.65

        var bloomEnabled = false
        var bloomThreshold = 0.62
        var bloomThresholdIntensity = 0.5
        var bloomCompositeIntensity = 0.65

        var vignetteEnabled = false
        var vignetteIntensity = 0.32
        var vignetteRadius = 0.82
        var vignetteSoftness = 0.42

        var depthOfFieldEnabled = false
        var focusDistance = 11.0
        var focusRange = 3.5
        var maxBlur = 6.0

        var chromaticAberrationEnabled = false
        var chromaticAberrationIntensity = 0.012
    }

    enum QualityPreset: String, CaseIterable, Identifiable {
        case neutral = "Neutral"
        case cinematic = "Cinematic"
        case inspection = "Inspection"

        var id: String { rawValue }
    }

    enum AntiAliasingOption: String, CaseIterable, Identifiable {
        case none = "None"
        case fxaa = "FXAA"
        case smaa = "SMAA"
        case msaa = "MSAA"

        var id: String { rawValue }

        var mode: AntiAliasingMode {
            switch self {
            case .none: .none
            case .fxaa: .fxaa
            case .smaa: .smaa
            case .msaa: .msaa
            }
        }
    }

    enum SSAOQualityOption: String, CaseIterable, Identifiable {
        case fast = "Fast"
        case balanced = "Balanced"
        case high = "High"

        var id: String { rawValue }

        var quality: SSAOQuality {
            switch self {
            case .fast: .fast
            case .balanced: .balanced
            case .high: .high
            }
        }
    }

    enum DebugViewOption: String, CaseIterable, Identifiable {
        case lit = "Lit"
        case albedo = "Albedo"
        case normal = "Normal"
        case depth = "Depth"
        case ssao = "SSAO"
        case fxaaEdges = "FXAA Edges"
        case smaaEdges = "SMAA Edges"
        case smaaBlend = "SMAA Blend"
        case smaaDifference = "SMAA Diff"

        var id: String { rawValue }

        var mode: RenderDebugViewMode {
            switch self {
            case .lit: .lit
            case .albedo: .albedo
            case .normal: .normal
            case .depth: .depth
            case .ssao: .ssaoBlurred
            case .fxaaEdges: .fxaaEdgeDebug
            case .smaaEdges: .smaaEdges
            case .smaaBlend: .smaaBlend
            case .smaaDifference: .smaaDifference
            }
        }
    }

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let windowSize = NSSize(width: 1360, height: 820)
            static let minimumWindowSize = NSSize(width: 980, height: 660)
        }

        private var window: NSWindow!
        private var renderer: UntoldRenderer!
        private var gameScene: GameScene!
        private let state = RenderingQualityState()

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
            window.title = "Untold Engine Rendering Quality Demo"
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

            window.contentView = NSHostingView(
                rootView: RenderingQualityDemoView(
                    renderer: renderer,
                    state: state,
                    actions: makeActions()
                )
            )
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        private func makeActions() -> RenderingQualityActions {
            .init(
                applyPreset: { [weak self] preset in self?.applyPreset(preset) },
                setAA: { [weak self] option in self?.gameScene.setAntiAliasing(option.mode) },
                setDebugView: { [weak self] option in self?.gameScene.setDebugView(option.mode) },
                applyColorGrading: { [weak self] in self?.applyColorGrading() },
                applySSAO: { [weak self] in self?.applySSAO() },
                applyBloom: { [weak self] in self?.applyBloom() },
                applyVignette: { [weak self] in self?.applyVignette() },
                applyDepthOfField: { [weak self] in self?.applyDepthOfField() },
                applyChromaticAberration: { [weak self] in self?.applyChromaticAberration() }
            )
        }

        private func applyPreset(_ preset: QualityPreset) {
            state.selectedPreset = preset
            state.selectedDebugView = .lit

            switch preset {
            case .neutral:
                state.selectedAA = .fxaa
                state.colorGradingEnabled = false
                state.exposure = 0.0
                state.brightness = 0.0
                state.contrast = 1.0
                state.saturation = 1.0
                state.temperature = 0.0
                state.tint = 0.0
                state.ssaoEnabled = false
                state.bloomEnabled = false
                state.vignetteEnabled = false
                state.depthOfFieldEnabled = false
                state.chromaticAberrationEnabled = false
                gameScene.applyNeutralLook()
            case .cinematic:
                state.selectedAA = .smaa
                state.colorGradingEnabled = true
                state.exposure = -0.2
                state.brightness = -0.05
                state.contrast = 1.15
                state.saturation = 0.9
                state.temperature = 0.0
                state.tint = 0.0
                state.ssaoEnabled = true
                state.ssaoQuality = .balanced
                state.ssaoRadius = 0.5
                state.ssaoBias = 0.02
                state.ssaoIntensity = 0.5
                state.bloomEnabled = true
                state.bloomThreshold = 0.62
                state.bloomThresholdIntensity = 0.45
                state.bloomCompositeIntensity = 0.55
                state.vignetteEnabled = true
                state.vignetteIntensity = 0.28
                state.vignetteRadius = 0.82
                state.vignetteSoftness = 0.42
                state.depthOfFieldEnabled = false
                state.chromaticAberrationEnabled = false
                gameScene.applyCinematicLook()
            case .inspection:
                state.selectedAA = .smaa
                state.colorGradingEnabled = true
                state.exposure = 0.15
                state.brightness = 0.05
                state.contrast = 1.1
                state.saturation = 0.95
                state.temperature = 0.08
                state.tint = 0.0
                state.ssaoEnabled = true
                state.ssaoQuality = .high
                state.ssaoRadius = 0.85
                state.ssaoBias = 0.02
                state.ssaoIntensity = 0.7
                state.bloomEnabled = false
                state.vignetteEnabled = false
                state.depthOfFieldEnabled = false
                state.chromaticAberrationEnabled = false
                gameScene.applyInspectionLook()
            }
        }

        private func applyColorGrading() {
            gameScene.setColorGrading(
                enabled: state.colorGradingEnabled,
                exposure: Float(state.exposure),
                brightness: Float(state.brightness),
                contrast: Float(state.contrast),
                saturation: Float(state.saturation),
                temperature: Float(state.temperature),
                tint: Float(state.tint)
            )
        }

        private func applySSAO() {
            gameScene.setSSAO(
                enabled: state.ssaoEnabled,
                radius: Float(state.ssaoRadius),
                bias: Float(state.ssaoBias),
                intensity: Float(state.ssaoIntensity),
                quality: state.ssaoQuality.quality
            )
        }

        private func applyBloom() {
            gameScene.setBloom(
                enabled: state.bloomEnabled,
                threshold: Float(state.bloomThreshold),
                thresholdIntensity: Float(state.bloomThresholdIntensity),
                compositeIntensity: Float(state.bloomCompositeIntensity)
            )
        }

        private func applyVignette() {
            gameScene.setVignette(
                enabled: state.vignetteEnabled,
                intensity: Float(state.vignetteIntensity),
                radius: Float(state.vignetteRadius),
                softness: Float(state.vignetteSoftness)
            )
        }

        private func applyDepthOfField() {
            gameScene.setDepthOfField(
                enabled: state.depthOfFieldEnabled,
                focusDistance: Float(state.focusDistance),
                focusRange: Float(state.focusRange),
                maxBlur: Float(state.maxBlur)
            )
        }

        private func applyChromaticAberration() {
            gameScene.setChromaticAberration(
                enabled: state.chromaticAberrationEnabled,
                intensity: Float(state.chromaticAberrationIntensity)
            )
        }
    }

    private struct RenderingQualityActions {
        let applyPreset: (QualityPreset) -> Void
        let setAA: (AntiAliasingOption) -> Void
        let setDebugView: (DebugViewOption) -> Void
        let applyColorGrading: () -> Void
        let applySSAO: () -> Void
        let applyBloom: () -> Void
        let applyVignette: () -> Void
        let applyDepthOfField: () -> Void
        let applyChromaticAberration: () -> Void
    }

    private struct RenderingQualityDemoView: View {
        let renderer: UntoldRenderer
        @Bindable var state: RenderingQualityState
        let actions: RenderingQualityActions

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                ScrollView {
                    controls
                }
                .frame(width: 390, height: 720)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(16)
            }
        }

        private var controls: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rendering Quality")
                    .font(.headline)

                Picker("Preset", selection: $state.selectedPreset) {
                    ForEach(QualityPreset.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: state.selectedPreset) { _, value in actions.applyPreset(value) }

                Picker("AA", selection: $state.selectedAA) {
                    ForEach(AntiAliasingOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: state.selectedAA) { _, value in actions.setAA(value) }

                Picker("Debug View", selection: $state.selectedDebugView) {
                    ForEach(DebugViewOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .onChange(of: state.selectedDebugView) { _, value in actions.setDebugView(value) }

                Divider()
                section("Color")
                Toggle("Color Grading", isOn: $state.colorGradingEnabled)
                    .onChange(of: state.colorGradingEnabled) { _, _ in actions.applyColorGrading() }
                slider("Exposure", $state.exposure, -4.0 ... 4.0, state.colorGradingEnabled, actions.applyColorGrading)
                slider("Brightness", $state.brightness, -1.0 ... 1.0, state.colorGradingEnabled, actions.applyColorGrading)
                slider("Contrast", $state.contrast, 0.0 ... 2.0, state.colorGradingEnabled, actions.applyColorGrading)
                slider("Saturation", $state.saturation, 0.0 ... 2.0, state.colorGradingEnabled, actions.applyColorGrading)
                slider("Temperature", $state.temperature, -1.0 ... 1.0, state.colorGradingEnabled, actions.applyColorGrading)
                slider("Tint", $state.tint, -1.0 ... 1.0, state.colorGradingEnabled, actions.applyColorGrading)

                Divider()
                section("SSAO")
                Toggle("SSAO", isOn: $state.ssaoEnabled)
                    .onChange(of: state.ssaoEnabled) { _, _ in actions.applySSAO() }
                Picker("Quality", selection: $state.ssaoQuality) {
                    ForEach(SSAOQualityOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .disabled(!state.ssaoEnabled)
                .onChange(of: state.ssaoQuality) { _, _ in actions.applySSAO() }
                slider("Radius", $state.ssaoRadius, 0.1 ... 2.0, state.ssaoEnabled, actions.applySSAO)
                slider("Bias", $state.ssaoBias, 0.0 ... 0.1, state.ssaoEnabled, actions.applySSAO)
                slider("Intensity", $state.ssaoIntensity, 0.0 ... 2.0, state.ssaoEnabled, actions.applySSAO)

                Divider()
                section("Bloom")
                Toggle("Bloom", isOn: $state.bloomEnabled)
                    .onChange(of: state.bloomEnabled) { _, _ in actions.applyBloom() }
                slider("Threshold", $state.bloomThreshold, 0.0 ... 2.0, state.bloomEnabled, actions.applyBloom)
                slider("Threshold Int.", $state.bloomThresholdIntensity, 0.0 ... 2.0, state.bloomEnabled, actions.applyBloom)
                slider("Composite Int.", $state.bloomCompositeIntensity, 0.0 ... 2.0, state.bloomEnabled, actions.applyBloom)

                Divider()
                section("Lens")
                Toggle("Vignette", isOn: $state.vignetteEnabled)
                    .onChange(of: state.vignetteEnabled) { _, _ in actions.applyVignette() }
                slider("Vignette Int.", $state.vignetteIntensity, 0.0 ... 1.0, state.vignetteEnabled, actions.applyVignette)
                slider("Radius", $state.vignetteRadius, 0.0 ... 1.5, state.vignetteEnabled, actions.applyVignette)
                slider("Softness", $state.vignetteSoftness, 0.0 ... 1.0, state.vignetteEnabled, actions.applyVignette)

                Toggle("Depth of Field", isOn: $state.depthOfFieldEnabled)
                    .onChange(of: state.depthOfFieldEnabled) { _, _ in actions.applyDepthOfField() }
                slider("Focus Distance", $state.focusDistance, 0.5 ... 30.0, state.depthOfFieldEnabled, actions.applyDepthOfField)
                slider("Focus Range", $state.focusRange, 0.1 ... 12.0, state.depthOfFieldEnabled, actions.applyDepthOfField)
                slider("Max Blur", $state.maxBlur, 0.0 ... 16.0, state.depthOfFieldEnabled, actions.applyDepthOfField)

                Toggle("Chromatic Aberration", isOn: $state.chromaticAberrationEnabled)
                    .onChange(of: state.chromaticAberrationEnabled) { _, _ in actions.applyChromaticAberration() }
                slider("Chromatic Int.", $state.chromaticAberrationIntensity, 0.0 ... 0.05, state.chromaticAberrationEnabled, actions.applyChromaticAberration)

                Text("Right-drag to orbit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }

        private func section(_ title: String) -> some View {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }

        private func slider(
            _ title: String,
            _ value: Binding<Double>,
            _ range: ClosedRange<Double>,
            _ enabled: Bool,
            _ onChange: @escaping () -> Void
        ) -> some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                    Spacer()
                    Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
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
