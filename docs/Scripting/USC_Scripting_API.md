---
id: usc-scripting-api
title: USC Scripting API Reference
sidebar_label: API Reference
sidebar_position: 3
---

# Untold Engine – USC Scripting API Reference

USC (Untold Script Core) is the scripting system inside the Untold Engine.
You write scripts in Swift using a fluent DSL, and the engine executes them at runtime.

This reference provides the complete API surface for building gameplay scripts.

---

## Quick Example

Here's a complete script that makes an entity bounce up and down:

```swift
extension GenerateScripts {
    static func generateBouncingCube(to dir: URL) {
        let script = buildScript(name: "BouncingCube") { s in
            s.onStart()
                .setVariable("bounceSpeed", to: 5.0)
            
            s.onUpdate()
                .getProperty(.position, as: "pos")
                .setVariable("offset", to: Vec3(x: 0.0, y: 0.1, z: 0.0))
                .addVec3("pos", "offset", as: "newPos")
                .setProperty(.position, toVariable: "newPos")
        }
        
        let outputPath = dir.appendingPathComponent("BouncingCube.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ BouncingCube.uscript")
    }
}
```

---

## 1. Script Lifecycle

### Building and Exporting Scripts

USC provides two ways to create scripts:

**buildScript()** - Creates a script in memory:
```swift
let script = buildScript(name: "MyScript") { s in
    s.onUpdate()
        .log("Running every frame")
}
```

**saveUSCScript()** - Saves a script to a `.uscript` file:
```swift
let outputPath = dir.appendingPathComponent("MyScript.uscript")
try? saveUSCScript(script, to: outputPath)
```

**Typical Pattern** - Build then save:
```swift
extension GenerateScripts {
    static func generateMyScript(to dir: URL) {
        let script = buildScript(name: "MyScript") { s in
            s.onUpdate()
                .log("Running every frame")
        }
        
        let outputPath = dir.appendingPathComponent("MyScript.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ MyScript.uscript")
    }
}
```

### TriggerType (Optional)

**Default:** `.perFrame` (runs every frame)

You only need to specify `triggerType` if you want something other than the default:

**When to override:**

- **`.event`** - For event-driven scripts (collision handlers, triggers)
  ```swift
  let script = buildScript(name: "DoorTrigger", triggerType: .event) { s in
      s.onCollision(tag: "Player")  // Coming soon - collision system not yet implemented
          .log("Door opened!")
  }
  ```

- **`.manual`** - For manually controlled scripts (cutscenes, special sequences)
  ```swift
  let script = buildScript(name: "Cutscene", triggerType: .manual) { s in
      s.onEvent("StartCutscene")
          .log("Cutscene playing...")
  }
  ```

**Most scripts don't need to specify this** - the default `.perFrame` works for continuous behaviors like movement and AI.

### ExecutionMode (Optional)

**Default:** `.auto` (engine manages execution)

You rarely need to override this. Only specify `executionMode` for advanced scenarios:

- **`.interpreted`** - Force interpreter-based execution (debugging, special cases)
  ```swift
  let script = buildScript(name: "DebugScript", executionMode: .interpreted) { s in
      s.onUpdate()
          .log("Debug mode")
  }
  ```

**Most scripts should use the default** `.auto` mode.

---

## 2. Events (Entry Points)

Events define when code blocks execute. Chain commands after each event:

**onStart()** - Runs once when the entity starts (like Awake/Start in Unity):
```swift
s.onStart()
    .setVariable("health", to: 100.0)
    .setVariable("speed", to: 5.0)
    .log("Entity initialized")
```

**onUpdate()** - Runs every frame (like Update in Unity):
```swift
s.onUpdate()
    .getProperty(.position, as: "pos")
    .log("Current position")
```

**onCollision(tag:)** - Runs when colliding with tagged entities:
> ⚠️ **Coming Soon** - The collision system is not yet implemented. This API is planned for a future release.

```swift
s.onCollision(tag: "Enemy")
    .log("Hit an enemy!")
    .setVariable("health", to: 0.0)
```

**onEvent(_:)** - Runs when a custom event is fired:
```swift
s.onEvent("PowerUpCollected")
    .setVariable("speed", to: 10.0)
    .log("Speed boost activated")
```

### Multiple Event Handlers

You can define multiple event handlers in one script:
```swift
let script = buildScript(name: "Player") { s in
    s.onStart()
        .setVariable("score", to: 0.0)
    
    s.onUpdate()
        .getProperty(.position, as: "pos")
    
    // Coming soon - collision system not yet implemented
    s.onCollision(tag: "Coin")
        .addFloat("score", 1.0, as: "score")
}

let outputPath = dir.appendingPathComponent("Player.uscript")
try? saveUSCScript(script, to: outputPath)
```

### Interpreter Execution (Advanced)

For `.interpreted` execution mode:
```swift
interpreter.execute(script: script, context: context, forEvent: "OnStart")
interpreter.execute(script: script, context: context, forEvent: nil)  // onUpdate
```

---

## 3. Script Context

Every script runs with a **context** that provides access to:
- **Entity properties** (position, rotation, velocity, etc.)
- **Script variables** (custom data you store)
- **Engine state** (delta time, input, etc.)

You access the entity's properties using `.getProperty()` and `.setProperty()`.

**Available at Runtime:**
- Current entity's transform (position, rotation, scale)
- Physics properties (velocity, acceleration, mass)
- Rendering properties (color, intensity for lights)
- All script variables you've defined

**Example:**
```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")      // Read from entity
    .getProperty(.velocity, as: "currentVel")      // Read physics
    .setVariable("myCustomData", to: 42.0)          // Store in script
    .setProperty(.position, toVariable: "newPos")  // Write to entity
```

---

## 4. Flow Control

**Conditionals** - Execute code based on comparisons:
```swift
s.ifCondition(
    lhs: .variableRef("speed"),
    .greater,
    rhs: .float(10.0)
) { nested in
    nested.log("Too fast!")
    nested.setVariable("speed", to: 10.0)
}
```

**Available operators:**
- `.greater` - Greater than
- `.less` - Less than
- `.equal` - Equal to

**Convenience conditionals:**
```swift
s.ifGreater("speed", than: 10.0) { nested in
    nested.log("Too fast!")
}

s.ifLess("health", than: 20.0) { nested in
    nested.log("Low health!")
}

s.ifEqual("state", to: 1.0) { nested in
    nested.log("State is 1")
}
```

---

## 5. Values & Variables

**Value Types** - USC supports these data types:
```swift
enum Value {
    case float(Float)                          // Single number
    case vec3(x: Float, y: Float, z: Float)    // 3D vector
    case string(String)                        // Text
    case bool(Bool)                            // True/false
    case variableRef(String)                   // Reference to a variable
}
```

**Setting Variables:**
```swift
s.setVariable("speed", to: 5.0)
s.setVariable("direction", to: Vec3(x: 1, y: 0, z: 0))
s.setVariable("isActive", to: true)
s.setVariable("playerName", to: "Hero")
```

**Using Variable References:**
```swift
s.setVariable("maxSpeed", to: 10.0)
s.setVariable("currentSpeed", to: .variableRef("maxSpeed"))  // Copy value
```

---

## 6. Engine Properties

**Available Properties** - Read/write entity properties:
```swift
enum ScriptProperty: String {
    // Transform
    case position, rotation, scale
    
    // Physics
    case velocity, acceleration, mass
    
    // Rendering (lights)
    case intensity, color
}

enum ScriptAxis: String { case x, y, z }
```

**Reading Properties:**
```swift
s.getProperty(.position, as: "pos")        // Store position in "pos" variable
s.getProperty(.velocity, as: "vel")        // Store velocity in "vel" variable
s.getProperty(.rotation, as: "rot")        // Store rotation in "rot" variable
```

**Writing Properties:**
```swift
s.setProperty(.position, toVariable: "newPos")     // Set from variable
s.setProperty(.velocity, to: Vec3(x: 0, y: 5, z: 0)) // Set from literal
```

**Complete Example:**
```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    .setVariable("offset", to: Vec3(x: 0, y: 0.1, z: 0))
    .addVec3("currentPos", "offset", as: "newPos")
    .setProperty(.position, toVariable: "newPos")  // Move entity up
```

---

## 7. Math Operations

**Float Math:**
```swift
s.addFloat("a", "b", as: "sum")                 // sum = a + b (two variables)
s.addFloat("a", literal: 5.0, as: "sum")       // sum = a + 5 (variable + literal)
s.mulFloat("a", "b", as: "product")            // product = a * b (two variables)
s.mulFloat("a", literal: 2.0, as: "product")   // product = a * 2 (variable * literal)
```

**Vector Math:**
```swift
s.addVec3("v1", "v2", as: "sum")               // sum = v1 + v2
s.scaleVec3("dir", literal: 2.0, as: "scaled") // scaled = dir * 2.0
s.scaleVec3("dir", by: "scale", as: "scaled")  // scaled = dir * scale
s.lengthVec3("vec", as: "length")              // length = magnitude of vec
```

**Example - Calculate velocity:**
```swift
s.onUpdate()
    .setVariable("direction", to: Vec3(x: 1, y: 0, z: 0))
    .setVariable("speed", to: 5.0)
    .scaleVec3("direction", by: "speed", as: "velocity")
    .setProperty(.velocity, toVariable: "velocity")
```

---

## 8. Actions / Args (AI & Steering)

**Action Names** - Built-in AI behaviors:
```swift
enum ScriptActionName: String {
    // Basic AI
    case seek       // Move toward target
    case flee       // Move away from threat
    case arrive     // Move toward target and slow down
    case pursuit    // Predict and intercept moving target
    case evade      // Predict and avoid moving threat
    
    // Steering (returns force vectors)
    case steerSeek, steerArrive, steerFlee, steerPursuit, steerFollowPath
    
    // Special
    case orbit      // Orbit around a point
}
```

**Action Arguments:**
```swift
enum ScriptArgKey: String {
    case targetPosition, threatPosition
    case targetEntity, threatEntity
    case maxSpeed, slowingRadius
    case deltaTime, turnSpeed, weight
    case centerPosition, radius
}
```

**Calling Actions:**

Actions require setting up argument variables first, then calling the action:

```swift
// Seek toward a target
s.setVariable("targetPos", to: Vec3(x: 10, y: 0, z: 0))
    .setVariable("maxSpeed", to: 5.0)
    .callAction(.seek, args: ["targetPos", "maxSpeed"], result: "seekForce")

// Using ScriptArgKey for type safety
s.setVariable(ScriptArgKey.targetPosition.rawValue, to: Vec3(x: 10, y: 0, z: 0))
    .setVariable(ScriptArgKey.maxSpeed.rawValue, to: 5.0)
    .callAction(.seek, args: [.targetPosition, .maxSpeed], result: "seekForce")
```

---

## 9. Transform & Physics Helpers

**Transform:**
```swift
s.translateTo(x: 1, y: 2, z: 3)                       // Set absolute position
s.translateTo(Vec3(x: 1, y: 2, z: 3))                 // Alternative syntax
s.translateBy(x: 0.1, y: 0, z: 0)                     // Move relative
s.translateBy(Vec3(x: 0.1, y: 0, z: 0))               // Alternative syntax
s.rotateTo(degrees: 45, axis: Vec3(x: 0, y: 1, z: 0)) // Set absolute rotation
s.rotateBy(degrees: 45, axis: Vec3(x: 0, y: 1, z: 0)) // Rotate relative
s.lookAt("targetEntityName")                          // Face another entity
```

**Physics - Force & Torque:**
```swift
s.applyForce(force: Vec3(x: 0, y: 10, z: 0))                     // Apply linear force
s.applyMoment(force: Vec3(x: 5, y: 0, z: 0), at: Vec3(x: 1, y: 0, z: 0))  // Apply torque at point
```

**Physics - Velocity Control:**
```swift
s.clearVelocity()                     // Stop linear movement instantly
s.clearAngularVelocity()              // Stop rotation instantly
s.clearForces()                       // Clear accumulated forces
```

**Physics - Gravity & Pause:**
```swift
s.setGravityScale(0.5)                // Half gravity (0 = no gravity, 1 = normal, 2 = double)
s.pausePhysicsComponent(isPaused: true)   // Pause/unpause physics simulation
```

**Example - Jump mechanic:**
```swift
s.onEvent("Jump")
    .getProperty(.velocity, as: "currentVel")
    .setVariable("jumpForce", to: Vec3(x: 0, y: 15, z: 0))
    .addVec3("currentVel", "jumpForce", as: "newVel")
    .setProperty(.velocity, toVariable: "newVel")
```

**Example - Reset physics:**
```swift
s.onEvent("Respawn")
    .clearVelocity()             // Stop all movement
    .clearAngularVelocity()      // Stop all rotation
    .clearForces()               // Clear force accumulation
    .translateTo(Vec3(x: 0, y: 5, z: 0))  // Move to spawn point
```

**Example - Apply torque to spin:**
```swift
s.onUpdate()
    .ifKeyPressed("R") { n in
        // Apply torque at the right edge to spin left
        n.applyMoment(force: Vec3(x: 0, y: 10, z: 0), at: Vec3(x: 1, y: 0, z: 0))
    }
```

**Animation:**
```swift
s.playAnimation("Walk", loop: true)                  // Play looping animation
s.playAnimation("Jump", loop: false)                 // Play once
s.stopAnimation()                                    // Stop current animation
```

---

## 10. Input Conditions

**Keyboard Input:**
```swift
s.ifKeyPressed("W") { nested in
    nested.log("Forward")
    nested.applyForce(force: Vec3(x: 0, y: 0, z: -1))
}

s.ifKeyPressed("Space") { nested in
    nested.log("Jump!")
    nested.applyForce(force: Vec3(x: 0, y: 10, z: 0))
}
```

**Example - WASD movement:**
```swift
s.onUpdate()
    .setVariable("moveSpeed", to: 5.0)
    .ifKeyPressed("W") { n in
        n.applyForce(force: Vec3(x: 0, y: 0, z: -5))
    }
    .ifKeyPressed("S") { n in
        n.applyForce(force: Vec3(x: 0, y: 0, z: 5))
    }
    .ifKeyPressed("A") { n in
        n.applyForce(force: Vec3(x: -5, y: 0, z: 0))
    }
    .ifKeyPressed("D") { n in
        n.applyForce(force: Vec3(x: 5, y: 0, z: 0))
    }
```

---

## 11. Logging & Debugging

**Log Messages:**
```swift
s.log("Debug message")                    // Simple message
s.log("Player health: 100")               // Can include values
```

**Debug Variables:**
```swift
s.onUpdate()
    .getProperty(.position, as: "pos")
    .log("Position updated")              // Track when events occur
```

---

## 12. Best Practices

### Use Enums for Type Safety
✅ **Good:**
```swift
s.getProperty(.position, as: "pos")
s.callAction(.seek, args: [.targetPosition: "target"], result: "force")
```

❌ **Avoid:**
```swift
s.getProperty("position", as: "pos")  // String-based, no autocomplete
```

### Variable Naming
- Use descriptive names: `"playerHealth"` not `"h"`
- Consistent naming: `"currentPos"`, `"targetPos"`, `"newPos"`
- Avoid conflicts with property names

### Performance
- Use `.perFrame` for continuous behaviors (movement, AI)
- Use `.event` for one-time triggers (collision, pickups)
- Minimize operations in `onUpdate()` when possible

### Script Organization
```swift
let script = buildScript(name: "Enemy") { s in
    // Initialization
    s.onStart()
        .setVariable("health", to: 100.0)
        .setVariable("speed", to: 3.0)
    
    // Main loop
    s.onUpdate()
        .callAction(.seek, args: [.targetPosition: "playerPos"], result: "force")
        .applyForce(force: .variableRef("force"))
    
    // Event handlers (collision system coming soon)
    s.onCollision(tag: "Bullet")
        .subtractFloat("health", 10.0, as: "health")
}

let outputPath = dir.appendingPathComponent("Enemy.uscript")
try? saveUSCScript(script, to: outputPath)
```

### Debugging Tips
- Add `.log()` statements to trace execution
- Use meaningful variable names for debugging
- Test scripts incrementally
- Check console output in Play mode
