# Rotate an Entity

Learn how to rotate entities using the Transform System.

---

## Overview

This tutorial shows you how to:
- Rotate an entity to an absolute angle
- Rotate an entity incrementally
- Create smooth rotation using `deltaTime`

---

## Prerequisites

This tutorial assumes you have:
- A project with `GameScene.swift` open
- **A scene loaded** with at least one entity
- The entity has a name set in the editor (e.g., "Propeller")

For complete API documentation:

➡️ **[Transform System API](../../../04-Engine%20Development/03-Engine%20Systems/UsingTransformSystem.md)**

---

## Step 1: Find the Entity from Your Scene

In `GameScene.swift`, add a property to store the entity reference:

```swift path=null start=null
class GameScene {
    var propeller: EntityID!
    
    init() {
        // ... setup code (setupAssetPaths, loadScene, etc.) ...
        startGameSystems()
        
        // Find the entity by name (set in the editor)
        propeller = findEntity(name: "Propeller")
        
        if propeller == nil {
            Logger.logWarning(message: "Propeller entity not found in scene")
        }
    }
}
```

---

## Step 2: Rotate to an Absolute Angle

Use `rotateTo()` to set an entity to a specific rotation:

```swift path=null start=null
class GameScene {
    var propeller: EntityID!
    
    init() {
        // ... setup code ...
        
        propeller = findEntity(name: "Propeller")
        
        // Rotate 45 degrees around the Y-axis (up)
        rotateTo(entityId: propeller, angle: 45.0, axis: SIMD3<Float>(0, 1, 0))
    }
}
```

**Result**: The entity immediately rotates to 45 degrees around the Y-axis.

---

## Step 3: Rotate Incrementally

Use `rotateBy()` to add rotation to the current orientation:

```swift path=null start=null
class GameScene {
    var propeller: EntityID!
    
    init() {
        // ... setup code ...
        
        propeller = findEntity(name: "Propeller")
        
        // Rotate 15 degrees from current rotation
        rotateBy(entityId: propeller, angle: 15.0, axis: SIMD3<Float>(0, 1, 0))
    }
}
```

**Result**: The entity rotates an additional 15 degrees around the Y-axis.

---

## Step 4: Continuous Rotation in Update Loop

For smooth spinning, use `rotateBy()` in `update(deltaTime:)`:

```swift path=null start=null
class GameScene {
    var propeller: EntityID!
    let rotationSpeed: Float = 90.0  // Degrees per second
    
    init() {
        // ... setup code ...
        propeller = findEntity(name: "Propeller")
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Rotate continuously around Y-axis
        let angleThisFrame = rotationSpeed * deltaTime
        rotateBy(entityId: propeller, angle: angleThisFrame, axis: SIMD3<Float>(0, 1, 0))
    }
}
```

**Result**: The propeller spins smoothly at 90 degrees per second.

---

## Understanding Rotation Axes

### Common Rotation Axes

```swift path=null start=null
// Rotate around Y-axis (up) - typical yaw rotation
rotateBy(entityId: entity, angle: 45.0, axis: SIMD3<Float>(0, 1, 0))

// Rotate around X-axis (right) - pitch rotation
rotateBy(entityId: entity, angle: 45.0, axis: SIMD3<Float>(1, 0, 0))

// Rotate around Z-axis (forward) - roll rotation
rotateBy(entityId: entity, angle: 45.0, axis: SIMD3<Float>(0, 0, 1))
```

### Using Entity's Local Axes

You can also rotate around an entity's own forward/right/up vectors:

```swift path=null start=null
// Rotate around entity's own up direction
let up = getUpAxisVector(entityId: entity)
rotateBy(entityId: entity, angle: 45.0, axis: up)

// Rotate around entity's own right direction
let right = getRightAxisVector(entityId: entity)
rotateBy(entityId: entity, angle: 45.0, axis: right)
```

---

## Rotation Examples

### Spin Clockwise (Y-axis)

```swift path=null start=null
let angle = rotationSpeed * deltaTime
rotateBy(entityId: entity, angle: angle, axis: SIMD3<Float>(0, 1, 0))
```

### Spin Counter-Clockwise (Y-axis)

```swift path=null start=null
let angle = -rotationSpeed * deltaTime  // Negative for opposite direction
rotateBy(entityId: entity, angle: angle, axis: SIMD3<Float>(0, 1, 0))
```

### Tumble (X-axis)

```swift path=null start=null
let angle = rotationSpeed * deltaTime
rotateBy(entityId: entity, angle: angle, axis: SIMD3<Float>(1, 0, 0))
```

### Face a Direction

To face a target, you typically calculate the direction and convert to rotation. This is more advanced, but here's a simple Y-axis example:

```swift path=null start=null
let targetPos = SIMD3<Float>(10, 0, 5)
let currentPos = getPosition(entityId: entity)
let direction = normalize(targetPos - currentPos)

// Calculate angle to target (simplified for Y-axis only)
let angle = atan2(direction.x, direction.z) * (180.0 / .pi)
rotateTo(entityId: entity, angle: angle, axis: SIMD3<Float>(0, 1, 0))
```

---

## Checking Current Rotation

To read an entity's current orientation:

```swift path=null start=null
// World orientation matrix
let worldOrientation = getOrientation(entityId: entity)
Logger.log(message: "World orientation: \(worldOrientation)")

// Local orientation matrix (relative to parent)
let localOrientation = getLocalOrientation(entityId: entity)
Logger.log(message: "Local orientation: \(localOrientation)")
```

---

## Combining Translation and Rotation

You can move and rotate in the same frame:

```swift path=null start=null
func update(deltaTime: Float) {
    if gameMode == false { return }
    
    // Move forward
    let forward = getForwardAxisVector(entityId: player)
    let movement = forward * moveSpeed * deltaTime
    translateBy(entityId: player, delta: movement)
    
    // Rotate based on input
    let turnAngle = turnSpeed * deltaTime
    rotateBy(entityId: player, angle: turnAngle, axis: SIMD3<Float>(0, 1, 0))
}
```

---

## Summary

You've learned:

✅ `rotateTo()` - Set absolute rotation angle  
✅ `rotateBy()` - Rotate incrementally from current orientation  
✅ `deltaTime` - Make rotation frame-rate independent  
✅ Rotation axes - Control rotation direction  
✅ `getOrientation()` - Read current rotation

---


