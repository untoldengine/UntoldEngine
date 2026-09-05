//
//  AppDelegate.swift
//

#if os(macOS)
    import AppKit
    import Foundation
    import SwiftUI
    import UntoldEngine

    @MainActor
    final class AppDelegate: NSObject, NSApplicationDelegate {
        private enum Constants {
            static let appVersion = "0.18.1"
            static let defaultWindowSize = NSSize(width: 1920, height: 1080)
            static let minimumWindowSize = NSSize(width: 640, height: 480)
        }

        private struct LaunchOptions {
            var windowSize = Constants.defaultWindowSize
        }

        var window: NSWindow!
        var renderer: UntoldRenderer!
        var gameScene: GameScene!
        var demoState = DemoState()

        func applicationDidFinishLaunching(_: Notification) {
            print("Launching Untold Engine v\(Constants.appVersion)")

            guard let launchOptions = parseLaunchOptions(arguments: CommandLine.arguments) else {
                NSApp.terminate(nil)
                return
            }
            setupWindow(size: launchOptions.windowSize)
            setupRendererAndScene()
            wireDemoStateCallbacks()
            presentHUD()
        }

        func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            true
        }

        private func setupWindow(size: NSSize) {
            window = NSWindow(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Untold Engine v\(Constants.appVersion)"
            window.minSize = Constants.minimumWindowSize
            window.center()
        }

        private func parseLaunchOptions(arguments: [String]) -> LaunchOptions? {
            var options = LaunchOptions()
            var index = 1

            while index < arguments.count {
                let argument = arguments[index]

                if argument == "--help" || argument == "-h" {
                    printUsage()
                    return nil
                }

                if argument == "--resolution" {
                    guard index + 1 < arguments.count else {
                        print("Missing value for --resolution. Expected WIDTHxHEIGHT, for example 800x600.")
                        printUsage()
                        return nil
                    }

                    if let size = parseResolution(arguments[index + 1]) {
                        options.windowSize = size
                    } else {
                        print("Invalid resolution '\(arguments[index + 1])'. Expected WIDTHxHEIGHT with minimum 640x480.")
                        printUsage()
                        return nil
                    }
                    index += 2
                    continue
                }

                if argument.hasPrefix("--resolution=") {
                    let value = String(argument.dropFirst("--resolution=".count))
                    if let size = parseResolution(value) {
                        options.windowSize = size
                    } else {
                        print("Invalid resolution '\(value)'. Expected WIDTHxHEIGHT with minimum 640x480.")
                        printUsage()
                        return nil
                    }
                }

                index += 1
            }

            return options
        }

        private func parseResolution(_ value: String) -> NSSize? {
            let normalized = value.lowercased()
            let parts = normalized.split(separator: "x", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let width = Double(parts[0]),
                  let height = Double(parts[1]),
                  width >= Constants.minimumWindowSize.width,
                  height >= Constants.minimumWindowSize.height
            else {
                return nil
            }

            return NSSize(width: width, height: height)
        }

        private func printUsage() {
            print("""
            Usage: swift run ShowcaseDemo [--resolution WIDTHxHEIGHT]

            Options:
              --resolution WIDTHxHEIGHT  Start the demo at a specific window size, for example 800x600.
              -h, --help                 Show this help.
            """)
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
            demoState.onLoadTiledScene = { [weak self] sceneID, url, completion in
                self?.gameScene.loadTileScene(sceneID: sceneID, url: url, completion: completion)
            }
            demoState.onLoadSceneAuthoredFile = { [weak self] path, completion in
                self?.gameScene.loadSceneAuthoredFile(path: path, completion: completion)
            }
            demoState.onLoadSceneAuthoredURL = { [weak self] url, completion in
                self?.gameScene.loadSceneAuthoredURL(url: url, completion: completion)
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
            demoState.onColorGradingChanged = { [weak self] enabled, exposure, brightness, contrast, saturation in
                self?.gameScene.setColorGrading(
                    enabled: enabled,
                    exposure: Float(exposure),
                    brightness: Float(brightness),
                    contrast: Float(contrast),
                    saturation: Float(saturation)
                )
            }
            demoState.onSSAOChanged = { [weak self] enabled, radius, bias, intensity in
                self?.gameScene.setSSAO(
                    enabled: enabled,
                    radius: Float(radius),
                    bias: Float(bias),
                    intensity: Float(intensity)
                )
            }
            demoState.onAntiAliasingChanged = { [weak self] mode in
                self?.gameScene.setAntiAliasing(mode)
            }
            demoState.onTextureStreamingTierDebugChanged = { [weak self] enabled in
                self?.gameScene.setStreamingTierDebug(enabled)
            }
            demoState.onRenderDebugViewChanged = { [weak self] mode in
                self?.gameScene.setRenderDebugView(mode)
            }
            demoState.onSpatialDebugChanged = { [weak self] enabled, octreeCellsEnabled, occupiedOnly, colorMode in
                self?.gameScene.setSpatialDebug(
                    enabled: enabled,
                    octreeCellsEnabled: octreeCellsEnabled,
                    occupiedOnly: occupiedOnly,
                    colorMode: colorMode
                )
            }
            demoState.onTileBoundsChanged = { [weak self] enabled in
                self?.gameScene.setTileBoundsDebug(enabled)
            }
            demoState.onMouseOverControlPanelChanged = { [weak self] isOver in
                self?.gameScene.suppressCameraInput = isOver
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
