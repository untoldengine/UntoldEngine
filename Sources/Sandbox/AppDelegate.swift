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
            static let appVersion = "0.17.0"
            static let windowSize = NSSize(width: 1600, height: 900)
        }

        var window: NSWindow!
        var renderer: UntoldRenderer!
        var gameScene: GameScene!

        func applicationDidFinishLaunching(_: Notification) {
            print("Launching Untold Engine Sandbox v\(Constants.appVersion)")

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
            window.title = "Untold Engine Sandbox v\(Constants.appVersion)"
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

            let hostingView = NSHostingView(rootView: SceneView(renderer: renderer))
            window.contentView = hostingView
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
#endif
