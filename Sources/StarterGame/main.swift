
import MetalKit
import SwiftUI
import UntoldEngine

// GameScene is where you would initialize your game and write the game logic.
class GameScene {
    init() {
        if let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            assetBasePath = desktopURL.appendingPathComponent("MyGreatGame")
        }

        // register custom systems. do not delete

        // 1. Register custom system
        // 2. add component to editor
        // 3. encode/decode custom component
        
        registerCustomSystem(ballSystemUpdate)
        addComponent_Editor(componentOption: BallComponent_Editor)
        encodeCustomComponent(type: BallComponent.self)

        registerCustomSystem(dribblingSystemUpdate)
        addComponent_Editor(componentOption: DribblingComponent_Editor)
        encodeCustomComponent(
            type: DribblinComponent.self,
            merge: { current, decoded in
                current.maxSpeed  = decoded.maxSpeed
                current.kickSpeed = decoded.kickSpeed
                current.direction = decoded.direction
            }
        )
        
        registerCustomSystem(cameraFollowUpdate)
        addComponent_Editor(componentOption: CameraFollowComponent_Editor)
        encodeCustomComponent(type: CameraFollowComponent.self,
                              merge: {current, decoded in
            current.targetName = decoded.targetName
            current.offset = decoded.offset
        })
       
        

        
        /*
         //Example: Load game

         let sceneURL = URL(fileURLWithPath: "Path/to/file.json")

         playSceneAt(url:sceneURL)

         // if from loading from main.bundle:

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
