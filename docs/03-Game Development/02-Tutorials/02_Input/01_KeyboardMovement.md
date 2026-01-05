# Keyboard Movement

Learn how to move entities using keyboard input.

---

## Overview

This tutorial shows you how to:
- Detect keyboard input using the Input System
- Move an entity based on WASD keys
- Combine input with Transform System

---

## Prerequisites

This tutorial assumes you have:
- A project with `GameScene.swift` open
- **A scene loaded** with at least one entity
- The entity has a name set in the editor (e.g., "Player")

For complete API documentation:

➡️ **[Input System API](../../04-Engine%20Development/03-Engine%20Systems/UsingInputSystem.md)**

---

## Step 1: Enable Input System

Before detecting input, you need to register keyboard events. Add this to your `startGameSystems()` helper or in `init()`:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    
    init() {
        // ... setup code ...
        startGameSystems()
        
        // Register input keyboard events
        InputSystem.shared.registerKeyboardEvents()
        
        // Find the entity by name (set in the editor)
        player = findEntity(name: "Player")
    }
}
```

**Important**: Call `InputSystem.shared.registerKeyboardEvents()` once during initialization to enable keyboard input detection.

---

## Step 2: Detect Keyboard Input

The Input System provides a `keyState` object to check if keys are pressed:

```swift path=null start=null
func update(deltaTime: Float) {
    if gameMode == false { return }
    
    // Check if W key is pressed
    if inputSystem.keyState.wPressed == true {
        Logger.log(message: "W key pressed!")
    }
}
```

**Available Keys**:
- `inputSystem.keyState.wPressed` - W key
- `inputSystem.keyState.aPressed` - A key
- `inputSystem.keyState.sPressed` - S key
- `inputSystem.keyState.dPressed` - D key

---

## Step 3: Move Entity with WASD

Combine input detection with movement:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    let moveSpeed: Float = 5.0
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        var movement = SIMD3<Float>(0, 0, 0)
        
        // Forward (W)
        if inputSystem.keyState.wPressed == true {
            movement.z += moveSpeed * deltaTime
        }
        
        // Backward (S)
        if inputSystem.keyState.sPressed == true {
            movement.z -= moveSpeed * deltaTime
        }
        
        // Left (A)
        if inputSystem.keyState.aPressed == true {
            movement.x -= moveSpeed * deltaTime
        }
        
        // Right (D)
        if inputSystem.keyState.dPressed == true {
            movement.x += moveSpeed * deltaTime
        }
        
        // Apply movement
        if movement != SIMD3<Float>(0, 0, 0) {
            translateBy(entityId: player, delta: movement)
        }
    }
}
```

**Result**: The player moves based on WASD input at 5 units per second.

---

## Understanding the Code

### Input Detection

```swift path=null start=null
if inputSystem.keyState.wPressed == true {
    // Key is currently pressed
}
```

The Input System automatically tracks key states. You don't need to register listeners or handle events.

### Accumulating Movement

```swift path=null start=null
var movement = SIMD3<Float>(0, 0, 0)

if inputSystem.keyState.wPressed == true {
    movement.z += moveSpeed * deltaTime
}

if inputSystem.keyState.dPressed == true {
    movement.x += moveSpeed * deltaTime
}
```

By accumulating input into a `movement` vector, diagonal movement (W+D) works correctly.

### Delta Time

Multiplying by `deltaTime` ensures consistent speed regardless of frame rate:

```swift path=null start=null
movement.z += moveSpeed * deltaTime  // ✅ Frame-rate independent
movement.z += 0.1                    // ❌ Varies with frame rate
```

---

## Advanced: Normalized Diagonal Movement

Diagonal movement (W+D) is currently faster than single-direction movement. To fix this, normalize the movement vector:

```swift path=null start=null
func update(deltaTime: Float) {
    if gameMode == false { return }
    
    var movement = SIMD3<Float>(0, 0, 0)
    
    // Accumulate input
    if inputSystem.keyState.wPressed == true {
        movement.z += 1.0
    }
    if inputSystem.keyState.sPressed == true {
        movement.z -= 1.0
    }
    if inputSystem.keyState.aPressed == true {
        movement.x -= 1.0
    }
    if inputSystem.keyState.dPressed == true {
        movement.x += 1.0
    }
    
    // Normalize and apply speed
    if movement != SIMD3<Float>(0, 0, 0) {
        movement = normalize(movement) * moveSpeed * deltaTime
        translateBy(entityId: player, delta: movement)
    }
}
```

**Result**: Diagonal movement is now the same speed as cardinal movement.

---

## Example: Tank Controls (Forward + Rotation)

For tank-style controls where forward moves along the entity's facing direction:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    let moveSpeed: Float = 5.0
    let turnSpeed: Float = 90.0  // Degrees per second
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Forward/backward movement
        var forwardMovement: Float = 0.0
        if inputSystem.keyState.wPressed == true {
            forwardMovement = moveSpeed * deltaTime
        }
        if inputSystem.keyState.sPressed == true {
            forwardMovement = -moveSpeed * deltaTime
        }
        
        // Apply forward movement along entity's forward direction
        if forwardMovement != 0.0 {
            let forward = getForwardAxisVector(entityId: player)
            translateBy(entityId: player, delta: forward * forwardMovement)
        }
        
        // Left/right rotation
        var turnAngle: Float = 0.0
        if inputSystem.keyState.aPressed == true {
            turnAngle = -turnSpeed * deltaTime
        }
        if inputSystem.keyState.dPressed == true {
            turnAngle = turnSpeed * deltaTime
        }
        
        // Apply rotation
        if turnAngle != 0.0 {
            rotateBy(entityId: player, angle: turnAngle, axis: SIMD3<Float>(0, 1, 0))
        }
    }
}
```

---

## Summary

You've learned:

✅ `inputSystem.keyState` - Check keyboard input  
✅ Detect W, A, S, D keys  
✅ Combine input with `translateBy()`  
✅ Normalize diagonal movement  
✅ Tank-style controls with rotation

---

## API Reference

For complete Input System documentation:

➡️ **[Input System API](../../04-Engine%20Development/03-Engine%20Systems/UsingInputSystem.md)**

---

## Where to Go Next

- **Play animations**: [../03_Animation/01_PlayAnimation.md](../03_Animation/01_PlayAnimation.md)
- **Apply physics forces**: [../04_Physics/01_ApplyForce.md](../04_Physics/01_ApplyForce.md)