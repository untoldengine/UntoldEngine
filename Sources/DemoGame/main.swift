
import MetalKit
import SwiftUI
import UntoldEngine

// GameScene is where you initialize your game and write game-specific logic.
class GameScene {
    init() {
        
        // By default, the engine needs to know where your assets are located.
        // Here we point it to a folder named "DemoGameAssets" on the Desktop.
        // You can change this to any folder where you keep your own assets.
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            assetBasePath = desktopURL.appendingPathComponent("DemoGameAssets")
        }
        
        //Take a look at the DribblingSystem and BallSystem (inside `Sources/DemoGame`) to see how the game is structured and get familiar with the Untold Engine API.

        // The Untold Engine uses an ECS (Entity–Component–System) architecture.
        // This means you can extend the engine by adding your own custom
        // components and systems. Below we register the custom ones used in
        // this demo game. (Feel free to follow this pattern for your own!)

        // ⚡ Steps to add your own system:
        // 1. Register your custom system function.
        // 2. Add the component so it shows up in the Editor.
        // 3. Register how your component is encoded/decoded (saved/loaded).
        
        // Ball system
        registerCustomSystem(ballSystemUpdate)
        addComponent_Editor(componentOption: BallComponent_Editor)
        encodeCustomComponent(type: BallComponent.self)

        // Dribbling system
        registerCustomSystem(dribblingSystemUpdate)
        addComponent_Editor(componentOption: DribblingComponent_Editor)
        encodeCustomComponent(
            type: DribblinComponent.self,
            merge: { current, decoded in
                current.maxSpeed = decoded.maxSpeed
                current.kickSpeed = decoded.kickSpeed
                current.direction = decoded.direction
            }
        )

        // Camera follow system
        registerCustomSystem(cameraFollowUpdate)
        addComponent_Editor(componentOption: CameraFollowComponent_Editor)
        encodeCustomComponent(
            type: CameraFollowComponent.self,
            merge: { current, decoded in
                current.targetName = decoded.targetName
                current.offset = decoded.offset
            }
        )

        /*
         -----------------------------------------------------
         Example: Loading a saved scene
         -----------------------------------------------------
         
         // Load from a file path:
         let sceneURL = URL(fileURLWithPath: "Path/to/file.json")
         playSceneAt(url: sceneURL)

         // Load from the app bundle:
         if let sceneURL = Bundle.main.url(forResource: "file", withExtension: "json") {
             playSceneAt(url: sceneURL)
         } else {
             print("Scene file not found in bundle.")
         }
         */
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

        renderer.initResources()

        // Step 3. Create the game scene and connect callbacks
        gameScene = GameScene()
        renderer.setupCallbacks(
            gameUpdate: { [weak self] deltaTime in self?.gameScene.update(deltaTime: deltaTime) },
            handleInput: { [weak self] in self?.gameScene.handleInput() }
        )

        if enableEditor {
            if #available(macOS 13.0, *) {
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
