//
//  AppDelegate.swift
//  StarterDemo
//

#if os(macOS)
    import AppKit
    import SwiftUI
    import UntoldEngine

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let windowSize = NSSize(width: 1280, height: 720)
            static let minimumWindowSize = NSSize(width: 800, height: 600)
        }

        private var window: NSWindow!
        private var renderer: UntoldRenderer!
        private var gameScene: GameScene!

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
            window.title = "Untold Engine Starter Demo"
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

            let hostingView = NSHostingView(rootView: StarterDemoView(renderer: renderer))
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private struct StarterDemoView: View {
        let renderer: UntoldRenderer

        var body: some View {
            ZStack(alignment: .topLeading) {
                SceneView(renderer: renderer)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Starter Demo")
                        .font(.headline)
                    Text("WASD move  |  Q/E up-down  |  Right-drag orbit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(16)
            }
        }
    }
#endif
