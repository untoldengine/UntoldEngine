# Move an Entity

Learn how to move entities using the Transform System.

---

## Overview

This tutorial shows you how to:
- Find an entity from a loaded scene
- Move an entity to an absolute position
- Move an entity relative to its current position

---

## Prerequisites

This tutorial assumes you have:
- A project with `GameScene.swift` open
- **A scene loaded** with at least one entity (created in Untold Engine Studio or loaded via `loadScene()`)
- The entity has a name set in the editor (e.g., "Player")

For complete API documentation:

➡️ **[Transform System API](../../../04-Engine%20Development/03-Engine%20Systems/UsingTransformSystem.md)**

---

## Step 1: Find the Entity from Your Scene

In `GameScene.swift`, add a property to store the entity reference:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code (setupAssetPaths, loadScene, etc.) ...
        startGameSystems()
        
        // Find the entity by name (set in the editor)
        player = findEntity(name: "Player")
        
        if player == nil {
            Logger.logWarning(message: "Player entity not found in scene")
        }
    }
}
```

**Important**: "Player" must match the entity name you set in Untold Engine Studio.

---

## Step 2: Move to an Absolute Position

Use `translateTo()` to set an entity to a specific world position:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        
        player = findEntity(name: "Player")
        
        // Move player to position (5, 0, -10)
        translateTo(entityId: player, position: SIMD3<Float>(5.0, 0.0, -10.0))
    }
}
```

**Result**: The entity immediately moves to position (5, 0, -10) in world space.

---

## Step 3: Move Relative to Current Position

Use `translateBy()` to move an entity by an offset:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        
        player = findEntity(name: "Player")
        
        // Move player 3 units to the right (X-axis)
        translateBy(entityId: player, delta: SIMD3<Float>(3.0, 0.0, 0.0))
    }
}
```

**Result**: The entity moves 3 units along the X-axis from its current position.

---

## Step 4: Continuous Movement in Update Loop

For smooth movement every frame, use `translateBy()` in `update(deltaTime:)`:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    let moveSpeed: Float = 5.0  // Units per second
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Move forward continuously
        let movement = SIMD3<Float>(0, 0, -moveSpeed * deltaTime)
        translateBy(entityId: player, delta: movement)
    }
}
```

**Result**: The player moves forward smoothly at 5 units per second.

---

## Understanding Delta Time

**Why multiply by `deltaTime`?**

`deltaTime` is the time (in seconds) since the last frame:
- At 60 FPS: `deltaTime ≈ 0.016` seconds
- At 30 FPS: `deltaTime ≈ 0.033` seconds

By multiplying speed by `deltaTime`, movement becomes **frame-rate independent**:

```swift path=null start=null
// Without deltaTime (BAD)
translateBy(entityId: player, delta: SIMD3<Float>(0, 0, -0.1))
// Result: Speed varies with frame rate ❌

// With deltaTime (GOOD)
let movement = SIMD3<Float>(0, 0, -moveSpeed * deltaTime)
translateBy(entityId: player, delta: movement)
// Result: Consistent speed regardless of frame rate ✅
```

---

## Movement Examples

### Move Forward

```swift path=null start=null
let movement = SIMD3<Float>(0, 0, -moveSpeed * deltaTime)
translateBy(entityId: player, delta: movement)
```

### Move Right

```swift path=null start=null
let movement = SIMD3<Float>(moveSpeed * deltaTime, 0, 0)
translateBy(entityId: player, delta: movement)
```

### Move Up

```swift path=null start=null
let movement = SIMD3<Float>(0, moveSpeed * deltaTime, 0)
translateBy(entityId: player, delta: movement)
```

### Move Along Entity's Forward Direction

```swift path=null start=null
let forward = getForwardAxisVector(entityId: player)
let movement = forward * moveSpeed * deltaTime
translateBy(entityId: player, delta: movement)
```

---

## Checking Entity Position

To read an entity's current position:

```swift path=null start=null
// World position (absolute)
let worldPos = getPosition(entityId: player)
Logger.log(message: "Player world position: \(worldPos)")

// Local position (relative to parent, if parented)
let localPos = getLocalPosition(entityId: player)
Logger.log(message: "Player local position: \(localPos)")
```

---

## Summary

You've learned:

✅ `findEntity(name:)` - Find entities from loaded scenes  
✅ `translateTo()` - Set absolute world position  
✅ `translateBy()` - Move relative to current position  
✅ `deltaTime` - Make movement frame-rate independent  
✅ `getPosition()` - Read current position

---



