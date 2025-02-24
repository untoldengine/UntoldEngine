
import MetalKit
import SwiftUI
import UntoldEngine

// GameScene is where you would initialize your game and write the game logic.
class GameScene {
    // Declare entity IDs
    let player: EntityID

    init() {
        // Step 1: Configure the Camera
        camera.lookAt(
            eye: simd_float3(0.0, 7.0, 15.0), // Camera position
            target: simd_float3(0.0, 0.0, 0.0), // Look-at target
            up: simd_float3(0.0, 1.0, 0.0) // Up direction
        )

        // Step 2: Create a Red Player Entity with Animation
        player = createEntity()

        setEntityName(entityId: player, name: "player")

        setEntityMesh(entityId: player, filename: "hollandPlayer", withExtension: "usdc", flip: false)

        // Add animations or physics components to the player

        // Add other assets

        // Lighting
        let sunEntity: EntityID = createEntity()

        setEntityName(entityId: sunEntity, name: "light")

        // Create the directional light instance
        let sun = DirectionalLight()

        // Add the light to the lighting system
        lightingSystem.addDirectionalLight(entityID: sunEntity, light: sun)
    }

    func update(deltaTime _: Float) {
        // Skip logic if not in game mode
        if gameMode == false {
            return
        }

        // Update the game state here
        // Example: Move the player based on input
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

        if enableEditor {
            if #available(macOS 12.0, *) {
                let hostingView = NSHostingView(rootView: EditorView(mtkView: renderer.metalView))
                window.contentView = hostingView
            } else {
                // Fallback on earlier versions
            }
        }

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
