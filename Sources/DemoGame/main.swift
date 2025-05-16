import MetalKit
import UntoldEngine

// GameScene is where you would initialize your game and write the game logic.
class GameScene {
    init() {}

    func update(deltaTime _: Float) {
        // Skip logic if not in game mode
        if gameMode == false {
            return
        }

        // Handle idle animation and physics pause
        if isWASDPressed() {
        } else {
            return
        }
    }

    func handleInput() {
        // Skip logic if not in game mode
        if gameMode == false {
            return
        }
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
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
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

        renderer.initResources()

        // Step 3. Create the game scene and connect callbacks
        gameScene = GameScene()
        renderer.setupCallbacks(
            gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
            handleInput: { [weak self] in self?.gameScene.handleInput() }
        )

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
