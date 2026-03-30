//
//  AppDelegate.swift
//

#if os(macOS)
    import AppKit
    import SwiftUI
    import UntoldEngine

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let appVersion = "0.11.2"
            static let windowSize = NSSize(width: 1920, height: 1080)
        }

        var window: NSWindow!
        var renderer: UntoldRenderer!
        var gameScene: GameScene!
        var demoState = DemoState()

        func applicationDidFinishLaunching(_: Notification) {
            print("Launching Untold Engine v\(Constants.appVersion)")

            setupWindow()
            setupRendererAndScene()
            wireDemoStateCallbacks()
            presentHUD()
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
            window.title = "Untold Engine v\(Constants.appVersion)"
            window.center()
        }

        private func setupRendererAndScene() {
            guard let renderer = UntoldRenderer.create() else {
                print("Failed to initialize the renderer.")
                return
            }
            self.renderer = renderer

            gameScene = GameScene()
            renderer.setupCallbacks(
                gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
                handleInput: { [weak self] in self?.gameScene.handleInput() }
            )
        }

        private func wireDemoStateCallbacks() {
            demoState.onLoadFile = { [weak self] path, completion in
                self?.gameScene.loadFile(path: path, completion: completion)
            }
            demoState.onLoadTiledScene = { [weak self] path, completion in
                self?.gameScene.loadTileScene(manifestPath: path, completion: completion)
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
            demoState.onRenderDebugViewChanged = { [weak self] mode in
                self?.gameScene.setRenderDebugView(mode)
            }
            demoState.onSpatialDebugChanged = { [weak self] enabled, occupiedOnly, colorMode in
                self?.gameScene.setSpatialDebug(
                    enabled: enabled,
                    occupiedOnly: occupiedOnly,
                    colorMode: colorMode
                )
            }
        }

        private func presentHUD() {
            guard let renderer else { return }
            let hostingView = NSHostingView(rootView: DemoHUD(renderer: renderer, state: demoState))
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
#endif
