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
            static let appVersion = "0.12.10"
            static let windowSize = NSSize(width: 1920, height: 1080)
        }

        private enum ExportError: LocalizedError {
            case exporterScriptMissing
            case tileExporterScriptMissing

            var errorDescription: String? {
                switch self {
                case .exporterScriptMissing:
                    "Could not find scripts/export-untold in the UntoldEngine repository."
                case .tileExporterScriptMissing:
                    "Could not find scripts/export-untold-tiles in the UntoldEngine repository."
                }
            }
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
            demoState.onLoadTiledScene = { [weak self] sceneID, url, completion in
                self?.gameScene.loadTileScene(sceneID: sceneID, url: url, completion: completion)
            }
            demoState.onExportUntoldAsset = { [weak self] inputURL, outputURL, convertOrientation, validateOutput, sourceOrientation, completion in
                guard let self else {
                    completion(.failure(NSError(domain: "DemoGame.Export", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Export controller is unavailable.",
                    ])))
                    return
                }

                exportUntoldAsset(
                    inputURL: inputURL,
                    outputURL: outputURL,
                    convertOrientation: convertOrientation,
                    validateOutput: validateOutput,
                    sourceOrientation: sourceOrientation,
                    completion: completion
                )
            }
            demoState.onExportTiledScene = { [weak self] inputURL, outputDirectoryURL, tileSizeX, tileSizeY, tileSizeZ, autoTileSize, generateHLOD, generateLOD, completion in
                guard let self else {
                    completion(.failure(NSError(domain: "DemoGame.Export", code: -1, userInfo: [
                        NSLocalizedDescriptionKey: "Export controller is unavailable.",
                    ])))
                    return
                }

                exportTiledScene(
                    inputURL: inputURL,
                    outputDirectoryURL: outputDirectoryURL,
                    tileSizeX: tileSizeX,
                    tileSizeY: tileSizeY,
                    tileSizeZ: tileSizeZ,
                    autoTileSize: autoTileSize,
                    generateHLOD: generateHLOD,
                    generateLOD: generateLOD,
                    completion: completion
                )
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
            demoState.onTileBoundsChanged = { enabled in
                setTileBoundsDebug(enabled: enabled)
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

        private func exportUntoldAsset(
            inputURL: URL,
            outputURL: URL,
            convertOrientation: Bool,
            validateOutput: Bool,
            sourceOrientation: DemoState.ExportSourceOrientation,
            completion: @escaping @MainActor (Result<String, Error>) -> Void
        ) {
            let repoRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let exporterScript = repoRoot.appendingPathComponent("scripts/export-untold")

            guard FileManager.default.isExecutableFile(atPath: exporterScript.path) else {
                completion(.failure(ExportError.exporterScriptMissing))
                return
            }

            let process = Process()
            process.executableURL = exporterScript
            process.currentDirectoryURL = repoRoot

            var arguments = [
                "--input", inputURL.path,
                "--output", outputURL.path,
                "--source-orientation", sourceOrientation.rawValue,
            ]

            if convertOrientation {
                arguments.append("--ConvertOrientation")
            }

            if validateOutput {
                arguments.append("--validate")
            }

            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let log = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                Task { @MainActor in
                    if process.terminationStatus == 0 {
                        let message = log.isEmpty
                            ? "Export completed: \(outputURL.path)"
                            : "Export completed.\n\(log)"
                        completion(.success(message))
                    } else {
                        let message = log.isEmpty
                            ? "Export failed with exit code \(process.terminationStatus)."
                            : log
                        completion(.failure(NSError(domain: "DemoGame.Export", code: Int(process.terminationStatus), userInfo: [
                            NSLocalizedDescriptionKey: message,
                        ])))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                completion(.failure(error))
            }
        }

        private func exportTiledScene(
            inputURL: URL,
            outputDirectoryURL: URL,
            tileSizeX: Double,
            tileSizeY: Double,
            tileSizeZ: Double,
            autoTileSize: Bool,
            generateHLOD: Bool,
            generateLOD: Bool,
            completion: @escaping @MainActor (Result<String, Error>) -> Void
        ) {
            let repoRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            let exporterScript = repoRoot.appendingPathComponent("scripts/export-untold-tiles")

            guard FileManager.default.isExecutableFile(atPath: exporterScript.path) else {
                completion(.failure(ExportError.tileExporterScriptMissing))
                return
            }

            let process = Process()
            process.executableURL = exporterScript
            process.currentDirectoryURL = repoRoot

            var arguments = [
                "--input", inputURL.path,
                "--output-dir", outputDirectoryURL.path,
            ]

            if autoTileSize {
                arguments.append("--auto-tile-size")
            } else {
                arguments.append(contentsOf: [
                    "--tile-size-x", String(tileSizeX),
                    "--tile-size-y", String(tileSizeY),
                    "--tile-size-z", String(tileSizeZ),
                ])
            }

            if generateHLOD {
                arguments.append("--generate-hlod")
            }

            if generateLOD {
                arguments.append("--generate-lod")
            }

            process.arguments = arguments

            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            process.terminationHandler = { process in
                let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let log = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                Task { @MainActor in
                    if process.terminationStatus == 0 {
                        let message = log.isEmpty
                            ? "Tiled export completed: \(outputDirectoryURL.path)"
                            : "Tiled export completed.\n\(log)"
                        completion(.success(message))
                    } else {
                        let message = log.isEmpty
                            ? "Tiled export failed with exit code \(process.terminationStatus)."
                            : log
                        completion(.failure(NSError(domain: "DemoGame.Export", code: Int(process.terminationStatus), userInfo: [
                            NSLocalizedDescriptionKey: message,
                        ])))
                    }
                }
            }

            do {
                try process.run()
            } catch {
                completion(.failure(error))
            }
        }
    }
#endif
