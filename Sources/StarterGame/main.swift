#if os(macOS)
    import MetalKit
    import SwiftUI
    import UntoldEngine

    // GameScene is where you would initialize your game and write the game logic.
    class GameScene {
        init() {
            // By default, the engine needs to know where your assets are located.
            // Here we point it to a folder named "DemoGameAssets/Assets" on the Desktop.
            // You can change this to any folder where you keep your own assets.
            if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
                assetBasePath = desktopURL.appendingPathComponent("DemoGameAssets/Assets")
            }

            // Note: You’re not limited to the editor for setting up entities.
            // The editor provides a visual workflow, but you can also create and
            // configure everything directly in code if that’s your preference.
            // Here is an example. For more details, see:
            // https://github.com/untoldengine/UntoldEngine?tab=readme-ov-file#systems

            let stadium = createEntity()
            setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdc")
            translateBy(entityId: stadium, position: simd_float3(0.0, 0.0, 0.0))

            let player = createEntity()
            setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdc", flip: false)
            rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
            setEntityAnimations(entityId: player, filename: "running", withExtension: "usdc", name: "running")
            changeAnimation(entityId: player, name: "running") // Start animation
        }

        func update(deltaTime _: Float) {
            // Skip logic if not in game mode
            if gameMode == false {
                return
            }
        }

        func handleInput() {
            // Skip logic if not in game mode
            if gameMode == false {
                return
            }

            // Handle input here
        }
    }

    // AppDelegate: Boiler plate code -- Handles everything – Renderer, Metal setup, and GameScene initialization
    class AppDelegate: NSObject, NSApplicationDelegate {
        var window: NSWindow!
        var renderer: UntoldRenderer!
        var gameScene: GameScene!

        func applicationDidFinishLaunching(_: Notification) {
            print("Launching Untold Engine v0.2")

            // Step 1. Create and configure the window
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1920, height: 1080),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.title = "Untold Engine v0.2"
            window.center()

            // Step 2. Initialize the renderer and connect metal content
            guard let renderer = UntoldRenderer.create() else {
                print("Failed to initialize the renderer.")
                return
            }

            window.contentView = renderer.metalView

            self.renderer = renderer

            // Step 3. Create the game scene and connect callbacks
            gameScene = GameScene()
            renderer.setupCallbacks(
                gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
                handleInput: { [weak self] in self?.gameScene.handleInput() }
            )

            let hostingView = NSHostingView(rootView: SceneView(renderer: renderer))
            window.contentView = hostingView

            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }

        func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            true
        }
    }

    // Entry point

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate

    app.run()
#endif
