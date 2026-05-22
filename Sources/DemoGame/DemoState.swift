//
//  DemoState.swift
//

#if os(macOS)
    import Foundation
    import Observation
    import UntoldEngine

    /// Pure UI state. No engine calls here.
    /// AppDelegate wires callbacks so this state can trigger GameScene methods.
    @MainActor @Observable final class DemoState {
        private enum Defaults {
            static let streamingRadius: Double = 200.0
            static let unloadRadius: Double = 350.0
            static let selectedRemoteSceneID = "dungeon"
        }

        enum PostFXPreset: String, CaseIterable, Identifiable {
            case neutral = "Neutral"
            case cinematic = "Cinematic"
            case highContrast = "High Contrast"
            case softAO = "Soft AO"
            case archviz = "Archviz"

            var id: String {
                rawValue
            }

            var enginePreset: UntoldEngine.PostFXPreset {
                switch self {
                case .neutral: return .neutral
                case .cinematic: return .cinematic
                case .highContrast: return .highContrast
                case .softAO: return .softAO
                case .archviz: return .archviz
                }
            }
        }

        enum AntiAliasingOption: String, CaseIterable, Identifiable {
            case none = "None"
            case fxaa = "FXAA"
            case smaa = "SMAA"

            var id: String {
                rawValue
            }

            var engineMode: AntiAliasingMode {
                switch self {
                case .none: .none
                case .fxaa: .fxaa
                case .smaa: .smaa
                }
            }
        }

        @ObservationIgnored private var isApplyingPostFXPreset = false

        struct RemoteSceneOption: Identifiable, Hashable {
            let id: String
            let title: String
            let manifestURL: URL?
        }

        // MARK: - File Loading

        var hasLoadedEntity: Bool = false
        var isLoading: Bool = false
        let remoteScenes: [RemoteSceneOption] = [
            .init(
                id: "dungeon",
                title: "Game Dungeon",
                manifestURL: URL(string: "https://d8pyi1c08k1w.cloudfront.net/dungeon3/dungeon3.json")!
            ),
            .init(
                id: "city",
                title: "Cartoon City",
                manifestURL: URL(string: "https://d8pyi1c08k1w.cloudfront.net/city/city.json")!
            ),
            .init(
                id: "f1car",
                title: "Formula 1",
                manifestURL: URL(string: "https://d8pyi1c08k1w.cloudfront.net/F1Car/F1Car.json")!
            ),
            .init(
                id: "airplane",
                title: "Skyhawk",
                manifestURL: URL(string: "https://d8pyi1c08k1w.cloudfront.net/Shyhawk_stream/Skyhawks.json")!
            ),
            .init(
                id: "porsche964",
                title: "Porsche 964",
                manifestURL: URL(string: "https://d8pyi1c08k1w.cloudfront.net/Porsche964-stream/Porsche964-stream.json")!
            ),
        ]
        var selectedRemoteSceneID: String = Defaults.selectedRemoteSceneID

        var selectedRemoteScene: RemoteSceneOption? {
            remoteScenes.first { $0.id == selectedRemoteSceneID }
        }

        // MARK: - Features

        var batchingEnabled: Bool = false {
            didSet { onBatchingChanged?(batchingEnabled) }
        }

        var streamingEnabled: Bool = false {
            didSet { onStreamingChanged?(streamingEnabled, streamingRadius, unloadRadius) }
        }

        var streamingRadius: Double = Defaults.streamingRadius {
            didSet { if streamingEnabled { onStreamingChanged?(true, streamingRadius, unloadRadius) } }
        }

        var unloadRadius: Double = Defaults.unloadRadius {
            didSet { if streamingEnabled { onStreamingChanged?(true, streamingRadius, unloadRadius) } }
        }

        // MARK: - Debug

        var lodDebugEnabled: Bool = false {
            didSet { onLodDebugChanged?(lodDebugEnabled) }
        }

        // MARK: - Post Processing

        var colorGradingEnabled: Bool = false {
            didSet { notifyColorGradingChanged() }
        }

        var exposure: Double = 0.0 {
            didSet { notifyColorGradingChanged() }
        }

        var brightness: Double = 0.0 {
            didSet { notifyColorGradingChanged() }
        }

        var contrast: Double = 1.0 {
            didSet { notifyColorGradingChanged() }
        }

        var saturation: Double = 1.0 {
            didSet { notifyColorGradingChanged() }
        }

        var ssaoEnabled: Bool = false {
            didSet { notifySSAOChanged() }
        }

        var ssaoRadius: Double = 0.5 {
            didSet { notifySSAOChanged() }
        }

        var ssaoBias: Double = 0.025 {
            didSet { notifySSAOChanged() }
        }

        var ssaoIntensity: Double = 0.0 {
            didSet { notifySSAOChanged() }
        }

        var selectedPostFXPreset: PostFXPreset = .neutral

        var antiAliasingOption: AntiAliasingOption = .fxaa {
            didSet { onAntiAliasingChanged?(antiAliasingOption.engineMode) }
        }

        var textureStreamingTierDebugEnabled: Bool = false {
            didSet { onTextureStreamingTierDebugChanged?(textureStreamingTierDebugEnabled) }
        }

        var renderDebugView: RenderDebugViewMode = .lit {
            didSet { onRenderDebugViewChanged?(renderDebugView) }
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

        var tileBoundsEnabled: Bool = false {
            didSet { onTileBoundsChanged?(tileBoundsEnabled) }
        }

        // MARK: - Stats

        var showStats: Bool = true
        var stats: EngineStatsSnapshot = .init()

        var isMouseOverControlPanel: Bool = false {
            didSet { onMouseOverControlPanelChanged?(isMouseOverControlPanel) }
        }

        // MARK: - Callbacks (wired by AppDelegate)

        var onLoadFile: ((String, @escaping @Sendable (Bool) -> Void) -> Void)?
        var onLoadTiledScene: ((String, URL, @escaping @Sendable (Bool) -> Void) -> Void)?
        var onBatchingChanged: ((Bool) -> Void)?
        var onStreamingChanged: ((Bool, Double, Double) -> Void)?
        var onLodDebugChanged: ((Bool) -> Void)?
        var onColorGradingChanged: ((Bool, Double, Double, Double, Double) -> Void)?
        var onSSAOChanged: ((Bool, Double, Double, Double) -> Void)?
        var onAntiAliasingChanged: ((AntiAliasingMode) -> Void)?
        var onTextureStreamingTierDebugChanged: ((Bool) -> Void)?
        var onRenderDebugViewChanged: ((RenderDebugViewMode) -> Void)?
        var onSpatialDebugChanged: ((Bool, Bool, SpatialDebugLeafColorMode) -> Void)?
        var onTileBoundsChanged: ((Bool) -> Void)?
        var onMouseOverControlPanelChanged: ((Bool) -> Void)?

        func applySelectedPostFXPreset() {
            let preset = selectedPostFXPreset.enginePreset
            isApplyingPostFXPreset = true
            colorGradingEnabled = preset.colorGrading
            exposure = Double(preset.exposure)
            brightness = Double(preset.brightness)
            contrast = Double(preset.contrast)
            saturation = Double(preset.saturation)
            ssaoEnabled = preset.ssao
            ssaoRadius = Double(preset.ssaoRadius)
            ssaoBias = Double(preset.ssaoBias)
            ssaoIntensity = Double(preset.ssaoIntensity)
            isApplyingPostFXPreset = false
            PostFX.apply(preset)
        }

        private func notifyColorGradingChanged(force: Bool = false) {
            if isApplyingPostFXPreset { return }
            if force || colorGradingEnabled {
                onColorGradingChanged?(colorGradingEnabled, exposure, brightness, contrast, saturation)
            } else if !colorGradingEnabled {
                onColorGradingChanged?(false, exposure, brightness, contrast, saturation)
            }
        }

        private func notifySSAOChanged(force: Bool = false) {
            if isApplyingPostFXPreset { return }
            if force || ssaoEnabled {
                onSSAOChanged?(ssaoEnabled, ssaoRadius, ssaoBias, ssaoIntensity)
            } else if !ssaoEnabled {
                onSSAOChanged?(false, ssaoRadius, ssaoBias, ssaoIntensity)
            }
        }

    }
#endif
