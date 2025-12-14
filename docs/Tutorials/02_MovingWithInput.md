# Tutorial 2: Moving an Object with Input

**What you'll learn:**
- Reading keyboard input with `getKeyState()`
- Using conditionals to respond to input
- Modifying entity position for movement
- Working with simd_float3 vectors and vector math
- Building movement from multiple simultaneous inputs

**Time:** ~10 minutes

---

## What We're Building

A player controller that:
1. Moves forward/backward with W/S keys
2. Strafes left/right with A/D keys
3. Supports diagonal movement (multiple keys at once)
4. Uses position-based movement for precise control

---

## Step 1: Create the Script

1. In **Untold Engine Studio**, click **Scripts: New**
2. Name it: `PlayerMovement`
3. Click OK

---

## Step 2: Wire Up the Script

1. Click **Scripts: Open in Xcode**
2. Open `GenerateScripts.swift`
3. Add to the `main()` function:

```swift
@main
struct GenerateScripts {
    static func main() {
        print("🔨 Generating USC scripts...")
        
        let outputDir = URL(fileURLWithPath: "Generated/")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        generatePlayerMovement(to: outputDir)  // Add this
        
        print("✅ All scripts generated in Generated/")
    }
}
```

---

## Step 3: Write the Movement Script

Open `PlayerMovement.swift` and add:

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generatePlayerMovement(to dir: URL) {
        let script = buildScript(name: "PlayerMovement") { s in
            // Initialize movement speed
            s.onStart()
                .setVariable("moveSpeed", to: 5.0)
                .log("Player movement initialized")
            
            // Handle input every frame
s.onUpdate()
    .math { m in
        m.getProperty(.position, as: "currentPos")
        m.setVariable("newPosition", to: simd_float3(x: 0, y: 0, z: 0))

        // Get key states
        m.getKeyState("w", as: "wPressed")
        m.getKeyState("s", as: "sPressed")
        m.getKeyState("a", as: "aPressed")
        m.getKeyState("d", as: "dPressed")

        // Forward (W key)
        m.ifEqual("wPressed", to: true) { n in
            n.setVariable("offset", to: simd_float3(x: 0, y: 0, z: 1))
            n.addVec3("newPosition", "offset", as: "newPosition")
        }
        // Backward (S key)
        m.ifEqual("sPressed", to: true) { n in
            n.setVariable("offset", to: simd_float3(x: 0, y: 0, z: -1))
            n.addVec3("newPosition", "offset", as: "newPosition")
        }
        // Left (A key)
        m.ifEqual("aPressed", to: true) { n in
            n.setVariable("offset", to: simd_float3(x: -1, y: 0, z: 0))
            n.addVec3("newPosition", "offset", as: "newPosition")
        }
        // Right (D key)
        m.ifEqual("dPressed", to: true) { n in
            n.setVariable("offset", to: simd_float3(x: 1, y: 0, z: 0))
            n.addVec3("newPosition", "offset", as: "newPosition")
        }

        m.addVec3("currentPos", "newPosition", as: "finalPos")
        m.setProperty(.position, toVariable: "finalPos")
    }
        }
        
        let outputPath = dir.appendingPathComponent("PlayerMovement.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ PlayerMovement.uscript")
    }
}
```

### Understanding the Code

**`getKeyState("w", as: "wPressed")`** - Reads the current state of a key
- Stores the result (true/false) in a variable
- Must be checked every frame to respond to input

**`ifCondition(...)`** - Executes code when a condition is true
- Checks if the key state variable equals `true`
- The nested block runs only when the condition passes

**`simd_float3(x, y, z)`** - Represents a 3D vector
- Positive Z = forward, Negative Z = backward
- Negative X = left, Positive X = right
- Y axis controls up/down (we'll use this later)

**Building Movement:**
1. Get the current position
2. Start with a zero offset vector
3. For each pressed key, add its direction to the offset
4. Add the offset to current position
5. Set the new position

**Position-Based Movement:**
- Direct, predictable movement
- Updates happen every frame
- Not affected by physics simulation

---

## Step 4: Build and Test

1. In Xcode, press **Cmd+R** to build
2. Return to **Untold Engine Studio**
3. Select your player entity (or create a cube)
4. Add a **Script Component** if needed
5. Load the `PlayerMovement.uscript`
6. Click **Play**

**Try it out:**
- Press **W** to move forward
- Press **S** to move backward
- Press **A** to move left
- Press **D** to move right

**Note:** This script uses position-based movement, so you don't need a Kinetic Component. The entity will move directly without physics simulation.

---

## Step 5: Smooth Camera Follow (Optional)

For a better view, position the camera to follow the player:

1. Select your scene camera
2. Set its position to something like: `(0, 10, 10)` (above and behind)
3. Rotate it to look down at the player

---

## Experiment: Variable Speed

Let's make the movement speed adjustable using the variable we set in `onStart()`.

### Using Variables for Speed

Currently, our offset is always 1 unit. Let's scale it by the `moveSpeed` variable:

```swift
extension GenerateScripts {
    static func generatePlayerMovement(to dir: URL) {
        let script = buildScript(name: "PlayerMovement") { s in
            s.onStart()
                .setVariable("moveSpeed", to: 0.2)  // Try different values!
                .log("Player movement initialized")
            
            s.onUpdate()
                .getProperty(.position, as: "currentPos")
                .setVariable("newPosition", to: simd_float3(x: 0, y: 0, z: 0))
                
                // Get key states
                .getKeyState("w", as: "wPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("d", as: "dPressed")
                
                // Forward (W key)
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("direction", to: simd_float3(x: 0, y: 0, z: 1))
                    n.scaleVec3("direction", by: "moveSpeed", as: "offset")
                    n.addVec3("newPosition", "offset", as: "newPosition")
                }
                // Backward (S key)
                .ifEqual("sPressed", to: true) { n in
                    n.setVariable("direction", to: simd_float3(x: 0, y: 0, z: -1))
                    n.scaleVec3("direction", by: "moveSpeed", as: "offset")
                    n.addVec3("newPosition", "offset", as: "newPosition")
                }
                // Left (A key)
                .ifEqual("aPressed", to: true) { n in
                    n.setVariable("direction", to: simd_float3(x: -1, y: 0, z: 0))
                    n.scaleVec3("direction", by: "moveSpeed", as: "offset")
                    n.addVec3("newPosition", "offset", as: "newPosition")
                }
                // Right (D key)
                .ifEqual("dPressed", to: true) { n in
                    n.setVariable("direction", to: simd_float3(x: 1, y: 0, z: 0))
                    n.scaleVec3("direction", by: "moveSpeed", as: "offset")
                    n.addVec3("newPosition", "offset", as: "newPosition")
                }
                
                .addVec3("currentPos", "newPosition", as: "finalPos")
                .setProperty(.position, toVariable: "finalPos")
        }
        
        let outputPath = dir.appendingPathComponent("PlayerMovement.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ PlayerMovement.uscript")
    }
}
```

### What Changed:

1. **Direction vectors** represent the movement direction (length = 1)
2. **`scaleVec3()`** multiplies the direction by `moveSpeed`
3. **Scaled offset** is added to the position for smooth, adjustable movement

Now you can change `moveSpeed` in `onStart()` to adjust how fast the player moves!

---

## Experiment: Add Sprint

Let's add a sprint feature when holding Shift:

```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    .setVariable("newPosition", to: simd_float3(x: 0, y: 0, z: 0))
    
    // Check if Shift is held for sprint speed
    .setVariable("currentSpeed", to: 0.2)  // Default speed
    .getKeyState("lshift", as: "shiftPressed")
    .ifEqual("shiftPressed", to: true) { n in
        n.setVariable("currentSpeed", to: 0.5)  // Sprint speed
    }
    
    // Get WASD key states
    .getKeyState("w", as: "wPressed")
    .getKeyState("s", as: "sPressed")
    .getKeyState("a", as: "aPressed")
    .getKeyState("d", as: "dPressed")
    
    // Forward with sprint
    .ifEqual("wPressed", to: true) { n in
        n.setVariable("direction", to: simd_float3(x: 0, y: 0, z: 1))
        n.scaleVec3("direction", by: "currentSpeed", as: "offset")
        n.addVec3("newPosition", "offset", as: "newPosition")
    }
    // ... repeat for S, A, D with the same pattern
```

---

## Understanding Position vs Velocity

### Using Position (What we did):
```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    .setVariable("offset", to: simd_float3(x: 0, y: 0, z: 1))
    .addVec3("currentPos", "offset", as: "newPos")
    .setProperty(.position, toVariable: "newPos")
```
- Direct, instant movement
- More predictable/controllable
- Not affected by physics
- No Kinetic Component required

### Using Velocity (Alternative):
```swift
s.onUpdate()
    .setVariable("velocity", to: simd_float3(x: 0, y: 0, z: 5))
    .setProperty(.velocity, toVariable: "velocity")
```
- Natural physics-based movement
- Smooth acceleration/deceleration
- Affected by physics system
- Requires Kinetic Component

### Using Forces (Another Alternative):
```swift
s.onUpdate()
    .ifKeyPressed("W") { n in
        n.applyForce(force: simd_float3(x: 0, y: 0, z: -5))
    }
```
- Most realistic physics response
- Momentum and inertia
- Requires Kinetic Component
- Can feel "floaty" if not tuned

All three approaches are valid! Choose based on your game's needs.

---

## What You Learned

✅ Reading keyboard input with `getKeyState()`  
✅ Using conditionals with `ifCondition()`  
✅ Working with simd_float3 vectors for 3D movement  
✅ Using variables for configurable parameters  
✅ Scaling vectors with `scaleVec3()`  
✅ Modifying entity position directly  
✅ Building up movement from multiple inputs

---

## Next Steps

**[Tutorial 3: Rotating and Scaling Objects](./03_RotatingAndScaling.md)** - Learn to manipulate entity transforms

**Challenges:**
- Add jump functionality with the Space key (Y-axis movement)
- Add crouch/fly down with the C key
- Normalize diagonal movement so it's not faster than cardinal directions
- Add smooth acceleration/deceleration

**Need Help?**
- [USC Scripting API - Input](../Scripting/USC_Scripting_API.md#10-input-conditions)
- [USC Scripting API - Math Operations](../Scripting/USC_Scripting_API.md#7-math-operations)

---

## Math Helper Quick Examples

```swift
s.onUpdate()
    .math { m in
        // Normalize (zero-safe)
        m.normalizeVec3("dir", as: "dirNorm")

        // Dot / cross
        m.dotVec3("forward", "input", as: "alignment")   // -1..1
        m.crossVec3("forward", "up", as: "right")

        // Reflect / project
        m.reflectVec3("incoming", normal: "surfaceNormal", as: "bounce")
        m.projectVec3("velocity", onto: "groundNormal", as: "slide")

        // Angles & lerp
        m.angleBetweenVec3("a", "b", as: "angleDeg")
        m.lerpVec3(from: "startPos", to: "endPos", t: "t", as: "pos")
        m.lerpFloat(from: "speed0", to: "speed1", t: "t", as: "speed")

        // Clamp
        m.clampVec3("vel", min: "minVel", max: "maxVel", as: "vel")
        m.clampFloat("speed", min: "minSpeed", max: "maxSpeed", as: "speed")
    }

// Orient toward another entity by name
s.onUpdate()
    .lookAt("TargetEntityName")
```
