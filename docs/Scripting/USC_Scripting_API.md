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
- **Entity properties** (position, scale, velocity, acceleration, lights)
- **Script variables** (custom data you store)
- **Engine state** (delta time, input, etc.)

You access the entity's properties using `.getProperty()` and `.setProperty()`.

**Available at Runtime:**
- Current entity's transform (position, scale)
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
- `.greater`, `.less`
- `.equal`, `.notEqual`
- `.lessOrEqual`, `.greaterOrEqual`

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

**Organizing math-heavy code with `.math { ... }`:**
```swift
s.onUpdate()
    .math { m in
        m.getProperty(.velocity, as: "vel")
        m.lengthVec3("vel", as: "speed")
        m.ifGreater("speed", than: 10) { n in
            n.normalizeVec3("vel", as: "dir")
            n.scaleVec3("dir", literal: 10, as: "clampedVel")
            n.setProperty(.velocity, toVariable: "clampedVel")
        }
    }
    .log("Velocity clamped if above 10")
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
s.setVariable("direction", to: simd_float3(x: 1, y: 0, z: 0))
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
    case position, scale

    // Physics
    case velocity, acceleration, mass, angularVelocity

    // Rendering (lights)
    case intensity, color

    // Engine time
    case deltaTime
}
```

**Reading Properties:**
```swift
s.getProperty(.position, as: "pos")        // Store position in "pos" variable
s.getProperty(.velocity, as: "vel")        // Store velocity in "vel" variable
s.getProperty(.deltaTime, as: "dt")        // Store frame delta time
```

**Writing Properties:**
```swift
s.setProperty(.position, toVariable: "newPos")                  // Set from variable
s.setProperty(.velocity, to: simd_float3(x: 0, y: 5, z: 0))     // Set from literal
s.setProperty(.angularVelocity, to: simd_float3(x: 0, y: 1, z: 0)) // Set spin (write-only today)
```

> Note: Rotation is controlled through `rotateTo` / `rotateBy` instructions. Reading rotation via `getProperty(.rotation, ...)` is not yet supported.

**Complete Example:**
```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    .setVariable("offset", to: simd_float3(x: 0, y: 0.1, z: 0))
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
s.normalizeVec3("vec", as: "unitVec")          // normalized vec (zero-safe)
s.dotVec3("a", "b", as: "dot")                 // dot product -> float
s.crossVec3("a", "b", as: "cross")             // cross product -> vec3
s.lerpVec3(from: "a", to: "b", t: "t", as: "lerped") // linear interpolation
s.lerpFloat(from: "a", to: "b", t: "t", as: "out")   // scalar lerp
s.reflectVec3("v", normal: "n", as: "reflected")     // reflect v about normal
s.projectVec3("v", onto: "axis", as: "proj")         // project v onto axis
s.angleBetweenVec3("a", "b", as: "angleDeg")         // angle in degrees
s.clampFloat("speed", min: "minSpeed", max: "maxSpeed", as: "clampedSpeed") // bounds via vars
s.clampVec3("velocity", min: "minVel", max: "maxVel", as: "clampedVel")     // component-wise
```

**Example - Calculate velocity:**
```swift
s.onUpdate()
    .setVariable("direction", to: simd_float3(x: 1, y: 0, z: 0))
    .setVariable("speed", to: 5.0)
    .scaleVec3("direction", by: "speed", as: "velocity")
    .setProperty(.velocity, toVariable: "velocity")
```

---

## 8. Built-in Behaviors (Steering, Camera, Physics)

All behaviors are instruction helpers—no `callAction` or `ScriptArgKey`.

**Steering**
```swift
// Seek toward a target and store the steering force
s.seek(targetPosition: .vec3(x: 10, y: 0, z: 0),
       maxSpeed: .float(5.0),
       result: "seekForce")
       
s.steerSeek(targetPosition: .variableRef("targetPos"),
           maxSpeed: .variableRef("maxSpeed"),
           deltaTime: .variableRef("dt"),
           turnSpeed: .variableRef("turnSpeed"))

// Arrive with slowing radius
s.steerArrive(targetPosition: .variableRef("targetPos"),
              maxSpeed: .variableRef("maxSpeed"),
              slowingRadius: .variableRef("slowingRadius"),
              deltaTime: .variableRef("dt"),
              turnSpeed: .variableRef("turnSpeed"))

// Evade a threat: compute force into result or apply directly
s.steerEvade(threatEntity: .string("Enemy"),
             maxSpeed: .float(6.0),
             result: "evadeForce")    // omit result to apply immediately
             
// Pursuit
s.steerPursuit(targetEntity: .variableRef("targetName"),
              maxSpeed: .variableRef("maxSpeed"),
              deltaTime: .variableRef("dt"),
              turnSpeed: .variableRef("turnSpeed"))

// Align orientation to current velocity (smooth)
s.alignOrientation(deltaTime: .float(0.016),
                   turnSpeed: .float(1.0))
```

**Camera**
```swift
// Snap camera to a position
s.cameraMoveTo(.vec3(x: 0, y: 3, z: -10))

// Look at a target
s.cameraLookAt(eye: .vec3(x: 0, y: 3, z: -8),
               target: .variableRef("lookTarget"),
               up: .vec3(x: 0, y: 1, z: 0))

// Follow a target with smoothing
s.cameraFollow(target: .string("Player"),
               offset: .vec3(x: 0, y: 3, z: -6),
               smoothFactor: .float(5.0),
               deltaTime: .float(0.016))

// WASDQE fly camera
s.cameraMoveWithInput(speedVar: "moveSpeed",
                      deltaTimeVar: "dt",
                      wVar: "wPressed",
                      aVar: "aPressed",
                      sVar: "sPressed",
                      dVar: "dPressed",
                      qVar: "qPressed",
                      eVar: "ePressed")

// Orbit a target entity (auto look-at)
s.cameraOrbitTarget(target: .string("Boss"),
                    radius: .float(12.0),
                    speed: .float(1.5),
                    deltaTime: .float(0.016),
                    offsetY: .float(1.5))
```

**Physics**
```swift
// Impulse
s.applyLinearImpulse(direction: .vec3(x: 1, y: 0, z: 0),
                     magnitude: .float(5.0))

// Continuous world force
s.applyWorldForce(direction: .vec3(x: 0, y: 1, z: 0),
                  magnitude: .float(3.0))

// Velocity control
s.setLinearVelocity(.vec3(x: 0, y: 0, z: 5))
s.addLinearVelocity(.variableRef("deltaVel"))
s.clampLinearSpeed(min: .float(2.0), max: .float(8.0))

// Angular control
s.applyAngularImpulse(axis: .vec3(x: 0, y: 1, z: 0), magnitude: .float(2.0))
s.clampAngularSpeed(max: .float(5.0))
s.applyAngularDamping(damping: .float(0.6), deltaTime: .float(0.016))
```

---

## 9. Transform & Physics Helpers

**Transform:**
```swift
s.translateTo(x: 1, y: 2, z: 3)                       // Set absolute position
s.translateTo(simd_float3(x: 1, y: 2, z: 3))           // Alternative syntax
s.translateBy(x: 0.1, y: 0, z: 0)                     // Move relative
s.translateBy(simd_float3(x: 0.1, y: 0, z: 0))        // Alternative syntax
s.rotateTo(degrees: 45, axis: simd_float3(x: 0, y: 1, z: 0)) // Set absolute rotation
s.rotateBy(degrees: 45, axis: simd_float3(x: 0, y: 1, z: 0)) // Rotate relative
s.lookAt("targetEntityName")                          // Face another entity
```

**Physics - Force & Torque:**
```swift
s.applyForce(force: simd_float3(x: 0, y: 10, z: 0))                     // Apply linear force
s.applyMoment(force: simd_float3(x: 5, y: 0, z: 0), at: simd_float3(x: 1, y: 0, z: 0))  // Apply torque at point
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
    .setVariable("jumpForce", to: simd_float3(x: 0, y: 15, z: 0))
    .addVec3("currentVel", "jumpForce", as: "newVel")
    .setProperty(.velocity, toVariable: "newVel")
```

**Example - Reset physics:**
```swift
s.onEvent("Respawn")
    .clearVelocity()             // Stop all movement
    .clearAngularVelocity()      // Stop all rotation
    .clearForces()               // Clear force accumulation
    .translateTo(simd_float3(x: 0, y: 5, z: 0))  // Move to spawn point
```

**Example - Apply torque to spin:**
```swift
s.onUpdate()
    .ifKeyPressed("R") { n in
        // Apply torque at the right edge to spin left
        n.applyMoment(force: simd_float3(x: 0, y: 10, z: 0), at: simd_float3(x: 1, y: 0, z: 0))
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
    nested.applyForce(force: simd_float3(x: 0, y: 0, z: -1))
}

s.ifKeyPressed("Space") { nested in
    nested.log("Jump!")
    nested.applyForce(force: simd_float3(x: 0, y: 10, z: 0))
}
```

**Example - WASD movement:**
```swift
s.onUpdate()
    .setVariable("moveSpeed", to: 5.0)
    .ifKeyPressed("W") { n in
        n.applyForce(force: simd_float3(x: 0, y: 0, z: -5))
    }
    .ifKeyPressed("S") { n in
        n.applyForce(force: simd_float3(x: 0, y: 0, z: 5))
    }
    .ifKeyPressed("A") { n in
        n.applyForce(force: simd_float3(x: -5, y: 0, z: 0))
    }
    .ifKeyPressed("D") { n in
        n.applyForce(force: simd_float3(x: 5, y: 0, z: 0))
    }
```

---

## 11. Logging & Debugging

**Log Messages:**
```swift
s.log("Debug message")                    // Simple message
s.log("Player health: 100")               // Can include values
s.logValue("velocity", value: .variableRef("vel")) // Log a labeled variable
s.logValue("spawnPoint", value: .vec3(x: 0, y: 1, z: 2)) // Log a literal with a label
```

**Debug Variables:**
```swift
s.onUpdate()
    .getProperty(.position, as: "pos")
    .log("Position updated")              // Track when events occur
```

---

## 12. Best Practices

### Use enums instead of raw strings
✅ **Good:**
```swift
s.getProperty(.position, as: "pos")
s.setProperty(.velocity, toVariable: "vel")
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
        .setVariable("maxSpeed", to: 5.0)
        .seek(targetPosition: .string("Player"),
              maxSpeed: .variableRef("maxSpeed"),
              result: "steer")
        .applyForce(force: .variableRef("steer"))
    
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
