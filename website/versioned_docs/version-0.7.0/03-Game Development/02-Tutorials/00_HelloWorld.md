# Hello World

Your first UntoldEngine program - logging a message every frame.

---

## Overview

This tutorial shows you how to add custom code to your game's update loop and log output to the console.

---

## Prerequisites

This tutorial assumes you have:
- Created a project using the `Untold Engine Studio` or `untoldengine-create`
- Opened the project in Xcode
- Located `GameScene.swift` in your project

---

## Step 1: Open GameScene.swift

In Xcode, navigate to:

```
Sources/YourProjectName/GameScene.swift
```

---

## Step 2: Add Your First Game Logic

Find the `update(deltaTime:)` method in `GameScene.swift`:

```swift path=null start=null
func update(deltaTime: Float) {
    // Skip logic if not in game mode
    if gameMode == false { return }
    
    // Add your custom update logic here
}
```

Replace the comment with:

```swift path=null start=null
func update(deltaTime: Float) {
    // Skip logic if not in game mode
    if gameMode == false { return }
    
    // Your first game code! 🎉
    Logger.log(message: "Hello World! Delta: \(deltaTime)")
}
```

---

## Step 3: Build and Run

Press **Cmd+R** in Xcode.

Open the **Debug Console** (Cmd+Shift+Y) to see:

```
Hello World! Delta: 0.016
Hello World! Delta: 0.017
Hello World! Delta: 0.016
...
```

The message appears every frame! 🚀

---

## What Just Happened?

### The Update Loop

`update(deltaTime:)` is called every frame by the engine:

- **60 FPS** = called 60 times per second
- **deltaTime** = time since last frame (in seconds)

All game logic goes here: movement, input handling, collision detection, etc.

### Logging

```swift path=null start=null
Logger.log(message: "Hello World!")
```

Use `Logger.log()` to print debug messages. It's better than `print()` because:
- Engine-aware logging
- Can be filtered/disabled in production
- Consistent formatting

### Other Logging Methods

```swift path=null start=null
Logger.logWarning(message: "Something might be wrong")
Logger.logError(message: "Something went wrong!")
```

---

## Limiting Output (Recommended)

Logging every frame creates spam. Let's log once per second instead:

```swift path=null start=null
class GameScene {
    var elapsedTime: Float = 0.0  // Add this property
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Accumulate time
        elapsedTime += deltaTime
        
        // Log once per second
        if elapsedTime >= 1.0 {
            Logger.log(message: "Hello World! One second passed.")
            elapsedTime = 0.0  // Reset
        }
    }
}
```

Now you'll see:

```
Hello World! One second passed.
Hello World! One second passed.
...
```

Much cleaner!

---

## Summary

You've learned:

✅ The `update(deltaTime:)` method runs every frame  
✅ `deltaTime` is the time between frames  
✅ `Logger.log()` prints messages to the console  
✅ How to accumulate time for periodic actions

This is the foundation of game development: **write code that runs every frame**.

