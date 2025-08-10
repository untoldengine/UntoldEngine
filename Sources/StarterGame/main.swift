
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
        // registerCustomSystem(ballSystemUpdate)

        registerCustomSystem(dribblingSystemUpdate)
        addComponent_Editor(componentOption: DribblingComponent_Editor)

        registerCustomSystem(ballSystemUpdate)
        addComponent_Editor(componentOption: BallComponent_Editor)

        registerCustomSystem(cameraFollowUpdate)
        addComponent_Editor(componentOption: CameraFollowComponent_Editor)

        encodeCustomComponent(type: BallComponent.self)
        encodeCustomComponent(type: CameraFollowComponent.self)
        encodeCustomComponent(
            type: DribblinComponent.self,
            merge: { current, decoded in
                current.maxSpeed  = decoded.maxSpeed
                current.kickSpeed = decoded.kickSpeed
                current.direction = decoded.direction
            }
        )

        /*
        encodeCustomComponent(
            type: DribblinComponent.self,
            editorMetadata: DribblingComponent_Editor,
            serialize: { entityId in
                guard let playerComponent = scene.get(component: DribblinComponent.self, for: entityId) else { return nil }
                return try? JSONEncoder().encode(playerComponent)
            },
            deserialize: { entityId, data in
                if let decoded = try? JSONDecoder().decode(DribblinComponent.self, from: data) {
                    registerComponent(entityId: entityId, componentType: DribblinComponent.self)
                    if let playerComponent = scene.get(component: DribblinComponent.self, for: entityId) {
                        playerComponent.maxSpeed = decoded.maxSpeed
                        playerComponent.kickSpeed = decoded.kickSpeed
                        playerComponent.direction = decoded.direction
                    }
                }
            }
        )

        // serialize/deserialize component
        encodeCustomComponent(
            type: BallComponent.self,
            editorMetadata: BallComponent_Editor,
            serialize: { entityId in
                guard let ballComponent = scene.get(component: BallComponent.self, for: entityId) else { return nil }
                return try? JSONEncoder().encode(ballComponent)
            },
            deserialize: { entityId, data in
                if let decoded = try? JSONDecoder().decode(BallComponent.self, from: data) {
                    registerComponent(entityId: entityId, componentType: BallComponent.self)
                    if let ballComponent = scene.get(component: BallComponent.self, for: entityId) {
                        // save data here
                    }
                }
            }
        )

        encodeCustomComponent(
            type: CameraFollowComponent.self,
            editorMetadata: CameraFollowComponent_Editor,
            serialize: { entityId in
                guard let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) else { return nil }
                return try? JSONEncoder().encode(cameraFollowComponent)
            },
            deserialize: { entityId, data in
                if let decoded = try? JSONDecoder().decode(CameraFollowComponent.self, from: data) {
                    registerComponent(entityId: entityId, componentType: CameraFollowComponent.self)
                    if let cameraFollowComponent = scene.get(component: CameraFollowComponent.self, for: entityId) {
                        // save data here
                        cameraFollowComponent.targetName = decoded.targetName
                        cameraFollowComponent.offset = decoded.offset
                    }
                }
            }
        )
         */
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
