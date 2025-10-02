//
//  main.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

#if os(macOS)
    import MetalKit
    import SwiftUI
    import UntoldEngine

    // GameScene is where you initialize your game and write game-specific logic.
    class GameScene {
        // Toggle between Editor-loaded scene (true) and Code-built scene (false).
        var useEditorScene: Bool = true

        // Demo assets location + scene file name (adjust as needed).
        private let demoAssetsRelativePath = "DemoGameAssets/Assets"
        private let sceneFilename = "soccergamedemo.json"

        // Resolve ~/Desktop/DemoGameAssets/Assets
        private func demoAssetsBaseURL() -> URL? {
            FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?
                .appendingPathComponent(demoAssetsRelativePath)
        }

        // Resolve the full scene URL if it exists.
        private func demoSceneURL() -> URL? {
            guard let base = demoAssetsBaseURL() else { return nil }
            let url = base.appendingPathComponent(sceneFilename)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        init() {
            //
            // -----------------------------------------------------
            // Demo Game Tutorial – How it Works
            // -----------------------------------------------------
            //
            // The Untold Engine is built on an ECS (Entity–Component–System) architecture:
            //
            // - Entities: These are just IDs (no logic or data by themselves).
            // - Components: Small data containers that hold attributes. For example,
            //   a `BallComponent` might store ball-related properties (speed, position, etc.).
            // - Systems: Functions that run every frame and update entities based on the
            //   components they have. For example, a `ballSystemUpdate` might handle ball physics.
            //
            // By combining these three, you extend what entities can *do*.
            // Think of it as:
            //   - Entity = the "thing"
            //   - Component = the "data"
            //   - System = the "behavior"
            //
            // -----------------------------------------------------
            // IMPORTANT: Download Game Scene and assets
            // -----------------------------------------------------
            // To save you time, we have included preloaded assets you can use right away:
            //
            // Models: Soccer stadium, player, ball, and more.
            // Animations: Prebuilt running, idle, and other character motions.
            // Game Scene: soccergamedemo.json
            //
            // You can download them Demo Game Assets v1.0 (https://github.com/untoldengine/UntoldEngine-Assets/releases/tag/v1).
            //
            //
            // -----------------------------------------------------
            // Two Ways to Initialize a Scene
            // -----------------------------------------------------
            //
            // **Option 1 – Load Scene from the Editor:**
            //
            // 1. Build your scene visually in the Untold Engine Editor and save it (e.g.,
            //    `soccergamedemo.json`). This was done already done for you.
            // 2. Point the engine to your asset folder (in this demo: "DemoGameAssets/Assets").
            // 3. Call `playSceneAt(url:)` to load and deserialize the scene.
            // 4. Look up specific entities by name and attach extra *custom components*
            //    (like `BallComponent` or `DribblinComponent`).
            // 5. Register your custom systems so they update every frame.
            // 6. Hook up input events (WASD movement).
            //
            // This approach is great when working with designers or when you want to quickly
            // assemble a level visually, then extend it with gameplay logic.
            //
            // **Option 2 – Create by Code:**
            //
            // If you prefer to build the scene entirely in code, you can do so by setting
            // a simple flag (e.g., `useEditorScene = false`). When this flag is false,
            // you skip loading the `.json` file and instead:
            //
            // - Call `createEntity()` for each object in your scene.
            // - Assign models with `setEntityMesh`.
            // - Apply transforms with `translateBy` / `rotateTo`.
            // - Add animations with `setEntityAnimations`.
            // - Give entities names with `setEntityName` so they can be looked up later.
            // - Enable physics with `setEntityKinetics`.
            // - Move the camera with `moveCameraTo`.
            // - Adjust global settings like `ambientIntensity`.
            //
            // This approach is useful when you want *full control in code* or prefer to
            // generate scenes procedurally.
            //
            // -----------------------------------------------------
            // Summary
            // -----------------------------------------------------
            //
            // Whether you load from the Editor or create everything in code, the workflow
            // is the same once the scene exists:
            //
            // - Entities are just IDs.
            // - Components attach data/attributes to those IDs.
            // - Systems operate on those components every frame.
            //
            // Use the Editor for fast prototyping, or code for precise control.
            // You can even mix both: load a base scene from the Editor and then add more
            // entities or components through code.
            //


            // Point the engine to your asset folder (used by both options)
            assetBasePath = demoAssetsBaseURL()

            if useEditorScene {
                // --- Option 1: Load the scene created with the Editor ---
                if let url = demoSceneURL() {
                    playSceneAt(url: url)
                } else {
                    print("⚠️ Could not find scene file \(sceneFilename). " +
                        "Expected at Desktop/\(demoAssetsRelativePath). " +
                        "Falling back to code-built scene.")
                    // Fallback to code path if the JSON is missing.
                    buildSceneInCode()
                }
            } else {
                // --- Option 2: Build the exact same scene in code ---
                buildSceneInCode()
            }

            // -----------------------------------------------------
            // Extend behavior by registering custom components
            // (attach data to specific entities)
            // -----------------------------------------------------
            if let ball = findEntity(name: "ball") {
                registerComponent(entityId: ball, componentType: BallComponent.self)
            }

            if let player = findEntity(name: "player") {
                registerComponent(entityId: player, componentType: DribblinComponent.self)
            }

            registerComponent(entityId: findGameCamera(), componentType: CameraFollowComponent.self)

            // -----------------------------------------------------
            // Register systems (run every frame)
            // -----------------------------------------------------
            registerCustomSystem(ballSystemUpdate)
            registerCustomSystem(dribblingSystemUpdate)
            registerCustomSystem(cameraFollowUpdate)

            // Input (WASD) for the demo
            InputSystem.shared.registerKeyboardEvents()
            
            // Disable SSAO
            SSAOParams.shared.enabled = false
        }

        // Build the same demo scene procedurally.
        private func buildSceneInCode() {
            // Stadium (static mesh)
            let stadium = createEntity()
            setEntityMesh(entityId: stadium, filename: "stadium", withExtension: "usdc")
            translateBy(entityId: stadium, position: simd_float3(0.0, 0.0, 0.0))

            // Player (animated, named for lookup)
            let player = createEntity()
            setEntityMesh(entityId: player, filename: "redplayer", withExtension: "usdc", flip: false)
            setEntityName(entityId: player, name: "player")
            rotateTo(entityId: player, angle: 0, axis: simd_float3(0.0, 1.0, 0.0))
            setEntityAnimations(entityId: player, filename: "running", withExtension: "usdc", name: "running")
            setEntityAnimations(entityId: player, filename: "idle", withExtension: "usdc", name: "idle")
            setEntityKinetics(entityId: player)

            // Ball (named for lookup)
            let ball = createEntity()
            setEntityMesh(entityId: ball, filename: "ball", withExtension: "usdc")
            setEntityName(entityId: ball, name: "ball")
            translateBy(entityId: ball, position: simd_float3(0.0, 0.6, 3.0))
            setEntityKinetics(entityId: ball)

            // Camera + lighting
            moveCameraTo(entityId: findGameCamera(), 0.0, 3.0, 10.0)
            ambientIntensity = 0.4
        }

        func update(deltaTime _: Float) {
            // Skip logic if not in game mode
            if gameMode == false { return }
        }

        func handleInput() {
            // Skip logic if not in game mode
            if gameMode == false { return }

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
