//
//  DemoState.swift
//


#if os(macOS)
    import Observation
    import UntoldEngine

    // Pure UI state. No engine calls here.
    // AppDelegate wires callbacks so this state can trigger GameScene methods.
    @Observable final class DemoState {
        private enum Defaults {
            static let streamingRadius: Double = 200.0
            static let unloadRadius: Double = 350.0
        }

        // MARK: - File Loading

        var hasLoadedEntity: Bool = false
        var isLoading: Bool = false

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

        // MARK: - Stats

        var showStats: Bool = true
        var stats: EngineStatsSnapshot = .init()

        // MARK: - Callbacks (wired by AppDelegate)

        var onLoadFile: ((String, @escaping (Bool) -> Void) -> Void)?
        var onBatchingChanged: ((Bool) -> Void)?
        var onStreamingChanged: ((Bool, Double, Double) -> Void)?
        var onLodDebugChanged: ((Bool) -> Void)?
        var onTextureStreamingTierDebugChanged: ((Bool) -> Void)?
        var onRenderDebugViewChanged: ((RenderDebugViewMode) -> Void)?
        var onSpatialDebugChanged: ((Bool, Bool, SpatialDebugLeafColorMode) -> Void)?
    }
#endif
