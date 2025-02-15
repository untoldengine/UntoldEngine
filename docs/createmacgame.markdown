---
layout: page
title: Create Mac Game
permalink: /createmacgame/
nav_order: 18
---

# Create a macOS Game in Xcode

For your convinience, I have created a game template that is ready for you to use. Simply [clone the template](https://github.com/untoldengine/UntoldEngine-Game-Template) and you will be ready to go. 

However, if you want to create the project yourself,  follow the guide below:

---

### Prerequisites

Before you begin, ensure you have:

- Xcode installed (version 13 or later recommended).
- The Untold Engine repository URL: https://github.com/untoldengine/UntoldEngine.git

---

### Step 1: Create a New macOS Game Project

1. Open Xcode and navigate to:
    File → New → Project.
2. Select Game under the macOS platform and click Next.
3. Configure your project:
    - Product Name: Enter a name for your game (e.g., "MyRacingGame").
    - Team: Select your Apple Developer Team (if applicable).
    - Language: Swift
    - Game Technology: Metal
4. Click Next, then choose a location to save your project, and click Create.

---

### Step 2: Clean Up Default Files

Xcode generates some default files that are unnecessary for the Untold Engine. Remove the following files from your project:

    - GameViewController.swift
    - Renderer.swift
    - Shaders.metal
    - ShaderTypes.h
    
To delete them:

    1. Right-click each file in the Project Navigator.
    2. Select Delete and confirm.

---

### Step 3: Add the Untold Engine as a Package Dependency

1. Open your Xcode project.
2. Go to: File → Add Packages...
3. In the search field, paste the Untold Engine repository URL: https://github.com/untoldengine/UntoldEngine.git
4. Select the branch or version (e.g., main) and click Add Package.
5. Ensure the package is added to your game target and click Add Package.

---

### Step 4: Set Up the AppDelegate

Now that the engine is included, configure your AppDelegate.swift to initialize the Untold Engine and set up your game window.

Replace the contents of AppDelegate.swift with:

```swift
import Cocoa
import UntoldEngine
import MetalKit

class GameScene {
    init() {
        // Initialize game assets and logic here
    }

    func update(deltaTime: Float) {
        // Game update logic
    }

    func handleInput() {
        // Input handling logic
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var renderer: UntoldRenderer!
    var gameScene: GameScene!

    func applicationDidFinishLaunching(_: Notification) {
        print("Launching Untold Engine v0.2")

        // Step 1: Create and configure the window
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Untold Engine v0.2"
        window.center()

        // Step 2: Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            print("Failed to initialize the renderer.")
            return
        }
        window.contentView = renderer.metalView
        self.renderer = renderer
        renderer.initResources()

        // Step 3: Create the game scene and connect callbacks
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
        return true
    }
    
    func applicationWillTerminate(_: Notification) {
        // Cleanup logic here
    }
}
```
---

### Step 5: Run Your Game

1. Build and run your project in Xcode.
2. If everything is set up correctly, you’ll see a window with a grid rendered by the Untold Engine.

![untoldenginegrid](../images/UntoldEngineGrid.png)

---

### Importing Assets

To import assets such as models, textures, animations, etc, follow the steps in [Importing Asset Files For Your Game]({% link importingassets.markdown %})

---

### Troubleshooting

ShaderType.h Not Found

- Cause: Xcode is referencing an outdated bridging header.
- Solution: Go to Build Settings, search for "Objective-C Bridging Header," and remove any path present.


![bridgeheader](../images/bridgingheader.png)

---

Linker Issues
Cause: The Untold Engine framework is not linked correctly.
Solution: Ensure the "Untold Engine" framework is added to Link Binary With Libraries under the Build Phases section.

![linkerissue](../images/linkerissue.png)

