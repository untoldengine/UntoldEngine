# Play Animation

Learn how to load and play animations on entities.

---

## Overview

This tutorial shows you how to:
- Load animation data from a `.usdc` file
- Play an animation on an entity
- Pause animations

---

## Prerequisites

This tutorial assumes you have:
- A project with `GameScene.swift` open
- **A scene loaded** with at least one entity that has an animation skeleton
- An animation file (e.g., `running.usdc`) in `GameData/Models/` or `GameData/Animations/`
- The entity has a name set in the editor (e.g., "Player")
- The entity has animations linked in the editor

For complete API documentation:

➡️ **[Animation System API](../../../04-Engine%20Development/03-Engine%20Systems/UsingAnimationSystem.md)**

---

## Step 1: Find the Entity

In `GameScene.swift`, add a property to store the entity reference:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        startGameSystems()
        
        // Find the entity by name (set in the editor)
        player = findEntity(name: "Player")
    }
}
```

---

## Step 2: Load the Animation

>>> Skip this section if you linked an animation to the entity through the editor.

Use `setEntityAnimations()` to load animation data:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
        
        // Load the running animation
        setEntityAnimations(
            entityId: player,
            filename: "running",
            withExtension: "usdc",
            name: "running"
        )
    }
}
```

**Parameters**:
- `filename`: The animation file name (without extension)
- `withExtension`: File extension (usually `"usdc"`)
- `name`: A label to reference this animation later

---

## Step 3: Play the Animation

Use `changeAnimation()` to start playing the animation:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
        
        // Load animation -- Ignore if you linked an animation through the editor
        setEntityAnimations(
            entityId: player,
            filename: "running",
            withExtension: "usdc",
            name: "running"
        )
        
        // Play the animation - we assume that the animation linked is called running
        changeAnimation(entityId: player, name: "running")
    }
}
```

**Result**: The entity plays the "running" animation in a loop.

---

## Step 4: Pause the Animation (Optional)

To pause or resume an animation:

```swift path=null start=null
// Pause the animation
pauseAnimationComponent(entityId: player, isPaused: true)

// Resume the animation
pauseAnimationComponent(entityId: player, isPaused: false)
```

---

## Loading Multiple Animations

You can load multiple animations for the same entity:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
        
        // Load multiple animations -- Ignore if you linked all three animations through the editor
        setEntityAnimations(
            entityId: player,
            filename: "idle",
            withExtension: "usdc",
            name: "idle"
        )
        
        setEntityAnimations(
            entityId: player,
            filename: "running",
            withExtension: "usdc",
            name: "running"
        )
        
        setEntityAnimations(
            entityId: player,
            filename: "jumping",
            withExtension: "usdc",
            name: "jumping"
        )
        
        // Start with idle animation
        changeAnimation(entityId: player, name: "idle")
    }
}
```

---

## Switching Animations at Runtime

Switch between animations based on game state:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    var isRunning: Bool = false
    
    init() {
    // ... setup code ...
    startGameSystems()
    
    // Register input keyboard events
    InputSystem.shared.registerKeyboardEvents()
    
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Check if player is moving
        let wasRunning = isRunning
        isRunning = inputSystem.keyState.wPressed || 
                    inputSystem.keyState.aPressed || 
                    inputSystem.keyState.sPressed || 
                    inputSystem.keyState.dPressed
        
        // Switch animation when state changes
        if isRunning && !wasRunning {
            changeAnimation(entityId: player, name: "running")
        } else if !isRunning && wasRunning {
            changeAnimation(entityId: player, name: "idle")
        }
    }
}
```

---

## File Organization

Animation files should be placed in your project's `GameData` directory:


```
Sources/YourProject/GameData/
├── Models/
│   └── player.usdz
├── Animations/
│   ├── idle.usdc
│   ├── running.usdc
│   └── jumping.usdc
```

---

## Troubleshooting

### Animation doesn't play

1. **Check the entity has a skeleton**: Not all models support animation. The model must have a skeletal rig.
2. **Verify file path**: Make sure the animation file exists in `GameData/Models/` or `GameData/Animations/`.
3. **Check animation name**: The `name` parameter must match when loading and playing.

### Animation plays too fast/slow

Animation playback speed is controlled by the animation file itself. To adjust speed, you'll need to modify the animation in your 3D software (e.g., Blender, Maya) or use animation blending (advanced topic).

---

## Summary

You've learned:

✅ `setEntityAnimations()` - Load animation data  
✅ `changeAnimation()` - Play a specific animation  
✅ `pauseAnimationComponent()` - Pause/resume animations  
✅ Load multiple animations per entity  
✅ Switch animations based on game state

---


