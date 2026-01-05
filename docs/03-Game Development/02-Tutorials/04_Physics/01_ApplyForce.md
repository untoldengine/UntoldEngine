# Apply Force

Learn how to use the Physics System to apply forces and create realistic movement.

---

## Overview

This tutorial shows you how to:
- Enable physics on an entity
- Configure mass and gravity
- Apply forces for dynamic movement
- Use the Steering System for advanced behaviors

---

## Prerequisites

This tutorial assumes you have:
- A project with `GameScene.swift` open
- **A scene loaded** with at least one entity
- The entity has a name set in the editor (e.g., "Ball")
- The entity has a kinetic component applied through the editor

For complete API documentation:

➡️ **[Physics System API](../../04-Engine%20Development/03-Engine%20Systems/UsingPhysicsSystem.md)**  
➡️ **[Steering System API](../../04-Engine%20Development/03-Engine%20Systems/UsingSteeringSystem.md)**

---

## Step 1: Find the Entity

In `GameScene.swift`, add a property to store the entity reference:

```swift path=null start=null
class GameScene {
    var ball: EntityID!
    
    init() {
        // ... setup code ...
        startGameSystems()
        
        ball = findEntity(name: "Ball")
    }
}
```

---

## Step 2: Enable Physics (Kinetics)

Before applying forces, enable physics on the entity:

```swift path=null start=null
class GameScene {
    var ball: EntityID!
    
    init() {
        // ... setup code ...
        ball = findEntity(name: "Ball")
        
        // Enable physics components
        setEntityKinetics(entityId: ball) // Ignore this if you linked kinetic component through the editor
    }
}
```

**What this does**: `setEntityKinetics()` adds `PhysicsComponents` and `KineticComponent` to the entity, enabling it to respond to forces.

---

## Step 3: Configure Mass and Gravity

Set the entity's mass and gravity scale:

```swift path=null start=null
class GameScene {
    var ball: EntityID!
    
    init() {
        // ... setup code ...
        ball = findEntity(name: "Ball")
        
        // Enable physics
        setEntityKinetics(entityId: ball) // Ignore this if you linked kinetic component through the editor
        
        // Configure physics properties
        setMass(entityId: ball, mass: 0.5)  // Lighter = easier to move
        setGravityScale(entityId: ball, gravityScale: 1.0)  // Normal gravity
    }
}
```

**Parameters**:
- `mass`: How heavy the entity is. Lower = easier to push. Default is `1.0`.
- `gravityScale`: How much gravity affects it. `0.0` = no gravity, `1.0` = normal gravity.

---

## Step 4: Apply a Force

Use `applyForce()` to push the entity:

```swift path=null start=null
class GameScene {
    var ball: EntityID!
    
    init() {
        // ... setup code ...
        ball = findEntity(name: "Ball")
        
        setEntityKinetics(entityId: ball) // Ignore this if you linked kinetic component through the editor
        setMass(entityId: ball, mass: 0.5)
        setGravityScale(entityId: ball, gravityScale: 1.0)
        
        InputSystem.shared.registerKeyboardEvents()
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Apply forward force when W is pressed
        if inputSystem.keyState.wPressed {
            applyForce(entityId: ball, force: SIMD3<Float>(0.0, 0.0, 5.0))
        }
    }
}
```

**Result**: When you press W, the ball accelerates forward.

**Important**: Forces are applied every frame while the key is pressed. The physics system automatically integrates forces into velocity and position.

---

## Understanding Forces vs. Direct Movement

### Direct Movement (Transform System)

```swift path=null start=null
// Immediate, precise movement
translateBy(entityId: entity, delta: SIMD3<Float>(0, 0, speed * deltaTime))
```

✅ Precise control  
✅ No physics overhead  
❌ No inertia or momentum  
❌ Doesn't interact with physics

### Force-Based Movement (Physics System)

```swift path=null start=null
// Gradual acceleration with momentum
applyForce(entityId: entity, force: SIMD3<Float>(0, 0, 5.0))
```

✅ Realistic inertia  
✅ Physics interactions  
✅ Momentum and deceleration  
❌ Less precise  
❌ Requires tuning

---

## Step 5: Use the Steering System

For easier physics-based movement, use the Steering System:

### Steer to a Target Position

```swift path=null start=null
class GameScene {
    var player: EntityID!
    let maxSpeed: Float = 5.0
    
    init() {
        // ... setup code ...
        player = findEntity(name: "Player")
        
        setEntityKinetics(entityId: player) // Ignore this if you linked kinetic component through the editor
        setMass(entityId: player, mass: 1.0)
        setGravityScale(entityId: player, gravityScale: 0.0)  // No gravity for top-down
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        let targetPosition = SIMD3<Float>(10.0, 0.0, 5.0)
        steerSeek(entityId: player, targetPosition: targetPosition, maxSpeed: maxSpeed, deltaTime: deltaTime)
    }
}
```

**Result**: The entity smoothly accelerates toward the target position.

---

## Steering System Examples

### Steer with WASD Keys

The easiest way to add physics-based movement:

```swift path=null start=null
class GameScene {
    var player: EntityID!
    let maxSpeed: Float = 5.0
    
    init() {
        // ... setup code ...
        InputSystem.shared.registerKeyboardEvents()
        
        player = findEntity(name: "Player")
        setEntityKinetics(entityId: player) // Ignore this if you linked kinetic component through the editor
        setMass(entityId: player, mass: 1.0)
        setGravityScale(entityId: player, gravityScale: 0.0)
    }
    
    func update(deltaTime: Float) {
        if gameMode == false { return }
        
        // Automatic WASD steering
        steerWithWASD(entityId: player, maxSpeed: maxSpeed, deltaTime: deltaTime)
    }
}
```

**Result**: WASD keys apply forces in the corresponding directions with smooth acceleration/deceleration.

### Flee from a Threat

```swift path=null start=null
let threatPosition = SIMD3<Float>(0.0, 0.0, 0.0)
steerFlee(entityId: player, threatPosition: threatPosition, maxSpeed: maxSpeed, deltaTime: deltaTime)
```

### Follow a Path

```swift path=null start=null
let waypoints = [
    SIMD3<Float>(0, 0, 0),
    SIMD3<Float>(5, 0, 0),
    SIMD3<Float>(5, 0, 5),
    SIMD3<Float>(0, 0, 5)
]
steerFollowPath(entityId: player, path: waypoints, maxSpeed: maxSpeed, deltaTime: deltaTime)
```

### Pursue a Moving Target

```swift path=null start=null
let enemy = findEntity(name: "Enemy")
steerPursuit(entityId: player, targetEntity: enemy!, maxSpeed: maxSpeed, deltaTime: deltaTime)
```

### Avoid Obstacles

```swift path=null start=null
let obstacles = [
    findEntity(name: "Rock1")!,
    findEntity(name: "Rock2")!,
    findEntity(name: "Tree1")!
]
steerAvoidObstacles(entityId: player, obstacles: obstacles, avoidanceRadius: 2.0, maxSpeed: maxSpeed, deltaTime: deltaTime)
```

### Arrive at Target (Slowing Down)

```swift path=null start=null
let targetPosition = SIMD3<Float>(10.0, 0.0, 5.0)
steerArrive(entityId: player, targetPosition: targetPosition, maxSpeed: maxSpeed, deltaTime: deltaTime)
```

**Difference from `steerSeek()`**: `steerArrive()` slows down as it approaches the target, preventing overshoot.

---

## Combining Steering Behaviors

You can use multiple steering behaviors together:

```swift path=null start=null
func update(deltaTime: Float) {
    if gameMode == false { return }
    
    // Steer toward target while avoiding obstacles
    let targetPosition = SIMD3<Float>(10.0, 0.0, 5.0)
    
    steerSeek(entityId: player, targetPosition: targetPosition, maxSpeed: maxSpeed, deltaTime: deltaTime)
    
    let obstacles = [findEntity(name: "Rock1")!, findEntity(name: "Rock2")!]
    steerAvoidObstacles(entityId: player, obstacles: obstacles, avoidanceRadius: 2.0, maxSpeed: maxSpeed, deltaTime: deltaTime)
}
```

---

## When to Use What?

### Use Transform System (`translateBy`, `translateTo`)
- Precise, scripted movement
- UI elements or camera
- Platformer-style movement
- When you don't need physics interactions

### Use Physics System (`applyForce`)
- Projectiles (bullets, grenades)
- Vehicles with custom physics
- When you need low-level control

### Use Steering System (`steerSeek`, `steerWithWASD`, etc.)
- Character movement in top-down or 3D games
- AI pathfinding and behaviors
- When you want smooth, realistic movement with minimal code

---

## Summary

You've learned:

✅ `setEntityKinetics()` - Enable physics on entities  
✅ `setMass()` and `setGravityScale()` - Configure physics properties  
✅ `applyForce()` - Apply custom forces  
✅ `steerWithWASD()` - Easy WASD physics movement  
✅ Steering behaviors - Seek, flee, pursue, avoid, arrive  
✅ When to use Transform vs. Physics vs. Steering

---

## API Reference

For complete documentation:

➡️ **[Physics System API](../../04-Engine%20Development/03-Engine%20Systems/UsingPhysicsSystem.md)**  
➡️ **[Steering System API](../../04-Engine%20Development/03-Engine%20Systems/UsingSteeringSystem.md)**

---

## Where to Go Next

- **More complex steering**: Combine multiple behaviors for emergent AI
- **Collision detection**: React to physics collisions (advanced topic)
- **Custom forces**: Create wind, explosions, or gravity wells
