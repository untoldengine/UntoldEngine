# Tutorial 4: Physics Control with Forces

**What you'll learn:**
- Applying forces to entities with `applyForce()`
- Pausing and unpausing the physics system
- Reading entity position to check state
- Clearing velocity to stop movement
- Using physics for realistic gravity and motion
- Combining input with physics simulation

**Time:** ~15 minutes

---

## What We're Building

A physics-controlled object that:
1. Applies upward force when W key is pressed
2. Falls naturally when the key is released (gravity)
3. Pauses physics when position drops below y=0
4. Unpauses and applies force when W is pressed again
5. Demonstrates proper physics state management

**Think of it like:** A rocket booster that fires when you press W, turns off when released, and resets when it hits the ground.

---

## Prerequisites

Before starting, make sure you understand:
- Basic scripting (Tutorial 1)
- Input handling (Tutorial 2)
- Working with Vec3 and positions (Tutorial 2-3)

---

## Step 1: Set Up the Entity

1. In **Untold Engine Studio**, create or select a cube/sphere entity
2. Add a **Kinetic Component** to the entity:
   - Select the entity
   - Add Component → Kinetic Component
   - **Important:** Physics only works with entities that have a Kinetic Component!

---

## Step 2: Create the Script

1. Click **Scripts: New**
2. Name it: `PhysicsControl`
3. Click OK

---

## Step 3: Wire Up the Script

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
        
        generatePhysicsControl(to: outputDir)  // Add this
        
        print("✅ All scripts generated in Generated/")
    }
}
```

---

## Step 4: Write the Physics Control Script

Open `PhysicsControl.swift` and add:

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generatePhysicsControl(to dir: URL) {
        let script = buildScript(name: "PhysicsControl") { s in
            // Initialize: Start with physics paused
            s.onStart()
                .setVariable("upwardForce", to: Vec3(x: 0, y: 15, z: 0))
                .setVariable("isGrounded", to: true)
                .pausePhysicsComponent(isPaused: true)
                .setGravityScale(0.0)
                .log("Physics control initialized - Press W to launch...")
            
            // Main physics loop
            s.onUpdate()
                
                // Check if entity is below ground (y < 0)
                .ifLess("position.y", than: 0.0) { n in
                    // Hit the ground - pause physics and reset
                    n.pausePhysicsComponent(isPaused: true)
                    n.clearVelocity()  // Stop all movement
                    n.setGravityScale(0.0)
                    n.setVariable("isGrounded", to: true)
                    
                    // Optional: Reset to ground level
                    n.setVariable("resetPos", to: Vec3(x: 0, y: 0.0, z: 0))
                    n.setProperty(.position, toVariable: "resetPos")
                    n.log("Grounded - Physics paused")
                }
                
                // Handle W key input
                .getKeyState("w", as: "wPressed")
                
                // If W is pressed and we're grounded, launch!
                .ifCondition(lhs: .variableRef("wPressed"), .equal, rhs: .bool(true)) { n in
                    n.ifCondition(lhs: .variableRef("isGrounded"), .equal, rhs: .bool(true)) { launch in
                        launch.pausePhysicsComponent(isPaused: false)
                        launch.setVariable("isGrounded", to: false)
                        launch.log("Launching!")
                    }
                    
                    // Apply upward force while W is held
                    n.applyForce(force: .variableRef("upwardForce"))
                }

               .ifGreater("position.y", than: 3.0){ n in 
                 n.clearVelocity()
                 n.setGravityScale(1.0)
               } 

        }
        
        let outputPath = dir.appendingPathComponent("PhysicsControl.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ PhysicsControl.uscript")
    }
}
```

### Understanding the Code

**`pausePhysicsComponent(isPaused: true/false)`**
- Pauses/unpauses the physics simulation for this entity
- When paused: entity ignores gravity, forces, and collisions
- When unpaused: physics simulation resumes normally

**`applyForce(force: Vec3(...))`**
- Applies a force to the entity (like a rocket thrust)
- Force is applied every frame it's called
- Accumulates with gravity and other forces
- Requires a Kinetic Component

**`clearVelocity()`**
- Stops all linear movement instantly
- Useful when resetting or landing
- Does NOT affect forces (just current momentum)

**Position Checking:**
```swift
.ifLess("position.y", than: 0.0) { n in
    // Below ground
}
```
- Reads the Y component of position directly using property path
- Compares against ground level (y=0)
- Triggers when entity falls below ground

**⚠️ Important: Property Path vs Variables**

Conditionals like `ifLess`, `ifGreater`, `ifEqual` expect **property paths**, not variable names:

✅ **Correct:**
```swift
.ifLess("position.y", than: 0.0) { ... }      // Direct property path
.ifGreater("position.y", than: 3.0) { ... }  // Direct property path
```

❌ **Incorrect:**
```swift
.getProperty(.position, as: "currentPos")
.ifLess("currentPos.y", than: 0.0) { ... }   // Won't work! currentPos is a variable
```

If you need to use stored variables in conditions, use `ifCondition` instead:
```swift
.getProperty(.position, axis: .y, as: "posY")  // Store Y component in variable
.ifCondition(lhs: .variableRef("posY"), .greater, rhs: .float(3.0)) { ... }
```

**State Management:**
- `isGrounded` tracks whether physics is paused
- Prevents multiple launches while airborne
- Ensures clean state transitions

---

## Step 5: Build and Test

1. In Xcode, press **Cmd+R** to build
2. Return to **Untold Engine Studio**
3. Select your entity
4. Add a **Script Component** if not already present
5. Load the `PhysicsControl.uscript`
6. Click **Play**

**Try it out:**
- **Press and hold W**: Entity launches upward with continuous thrust
- **Release W**: Gravity takes over, entity falls
- **Below ground**: Physics pauses automatically
- **Press W again**: Entity launches from ground

---

## How It Works: Physics Simulation

### With Physics Active:
```
Frame 1: Apply force (15 units up) + Gravity (-9.8 units down) = Net upward
Frame 2: Apply force + Gravity = Still moving up (but slower)
Frame 3: Apply force + Gravity = Still moving up
... Velocity accumulates each frame
```

### When W is Released:
```
Frame N: No force + Gravity = Net downward
Frame N+1: Gravity only = Accelerating down
Frame N+2: Gravity only = Falling faster
```

### When Below Ground:
```
Detect y < 0 → Pause physics → Clear velocity → Reset position
```

---

## Experiment: One-Shot Jump

Instead of continuous thrust, make it a single jump (like Mario):

```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    
    // Check ground
    .ifLess("currentPos.y", than: 0.0) { n in
        n.pausePhysicsComponent(isPaused: true)
        n.clearVelocity()
        n.setVariable("isGrounded", to: true)
        n.setVariable("resetPos", to: Vec3(x: 0, y: 0, z: 0))
        n.setProperty(.position, toVariable: "resetPos")
    }
    
    // Get W key state
    .getKeyState("w", as: "wPressed")
    .getKeyState("w", as: "wPressedPrev")  // From previous frame
    
    // Detect key press (not held)
    .ifCondition(lhs: .variableRef("wPressed"), .equal, rhs: .bool(true)) { n in
        n.ifCondition(lhs: .variableRef("wPressedPrev"), .equal, rhs: .bool(false)) { jump in
            jump.ifCondition(lhs: .variableRef("isGrounded"), .equal, rhs: .bool(true)) { n in
                n.pausePhysicsComponent(isPaused: false)
                n.setVariable("isGrounded", to: false)
                
                // Single impulse instead of continuous force
                n.setVariable("jumpImpulse", to: Vec3(x: 0, y: 20, z: 0))
                n.setProperty(.velocity, toVariable: "jumpImpulse")
                n.log("Jump!")
            }
        }
    }
    
    // Store current state for next frame
    .setVariable("wPressedPrev", to: .variableRef("wPressed"))
```

**Difference:**
- **Original**: Continuous thrust while held (rocket)
- **One-shot**: Single velocity impulse (jump)

---

## Experiment: Adjustable Force

Make the force magnitude controllable:

```swift
s.onStart()
    .setVariable("thrustPower", to: 10.0)  // Base thrust
    .setVariable("isGrounded", to: true)
    .pausePhysicsComponent(isPaused: true)

s.onUpdate()
    // ... position checking code ...
    
    // Adjust thrust with keys
    .getKeyState("up", as: "upPressed")
    .ifCondition(lhs: .variableRef("upPressed"), .equal, rhs: .bool(true)) { n in
        n.addFloat("thrustPower", literal: 0.5, as: "thrustPower")
        n.log("Thrust increased")
    }
    
    .getKeyState("down", as: "downPressed")
    .ifCondition(lhs: .variableRef("downPressed"), .equal, rhs: .bool(true)) { n in
        n.subtractFloat("thrustPower", literal: 0.5, as: "thrustPower")
        n.log("Thrust decreased")
    }
    
    // Apply force with variable magnitude
    .getKeyState("w", as: "wPressed")
    .ifCondition(lhs: .variableRef("wPressed"), .equal, rhs: .bool(true)) { n in
        n.setVariable("upDirection", to: Vec3(x: 0, y: 1, z: 0))
        n.scaleVec3("upDirection", by: "thrustPower", as: "thrustForce")
        n.applyForce(force: .variableRef("thrustForce"))
    }
```

---

## Experiment: Horizontal Control

Add horizontal movement while in the air:

```swift
s.onUpdate()
    // ... existing code ...
    
    // When airborne, allow steering
    .ifCondition(lhs: .variableRef("isGrounded"), .equal, rhs: .bool(false)) { n in
        // Apply upward thrust with W
        n.getKeyState("w", as: "wPressed")
        n.ifCondition(lhs: .variableRef("wPressed"), .equal, rhs: .bool(true)) { w in
            w.applyForce(force: Vec3(x: 0, y: 15, z: 0))
        }
        
        // Steer left with A
        n.getKeyState("a", as: "aPressed")
        n.ifCondition(lhs: .variableRef("aPressed"), .equal, rhs: .bool(true)) { a in
            a.applyForce(force: Vec3(x: -5, y: 0, z: 0))
        }
        
        // Steer right with D
        n.getKeyState("d", as: "dPressed")
        n.ifCondition(lhs: .variableRef("dPressed"), .equal, rhs: .bool(true)) { d in
            d.applyForce(force: Vec3(x: 5, y: 0, z: 0))
        }
    }
```

Now you have a controllable flying object!

---

## Understanding Forces vs Velocity

### Using Forces (What we did):
```swift
s.applyForce(force: Vec3(x: 0, y: 15, z: 0))
```
- **Natural physics**: Accumulates with gravity
- **Momentum**: Builds up over time
- **Realistic**: Feels like real rocket thrust
- **Requires**: Kinetic Component

### Using Velocity (Alternative):
```swift
s.setProperty(.velocity, to: Vec3(x: 0, y: 10, z: 0))
```
- **Direct control**: Sets exact speed
- **Immediate**: No acceleration
- **Predictable**: Constant speed
- **Requires**: Kinetic Component

### Using Position (Tutorial 2):
```swift
s.setProperty(.position, to: Vec3(x: 0, y: 2, z: 0))
```
- **Teleportation**: Instant movement
- **No physics**: Ignores gravity
- **Simple**: Easy to control
- **No requirements**: Works without Kinetic Component

Choose based on your game's feel!

---

## Debugging Tips

**Entity not moving?**
- ✓ Check that Kinetic Component is added
- ✓ Verify physics is unpaused (`isPaused: false`)
- ✓ Check force magnitude (try increasing to 25)

**Entity falls through ground?**
- ✓ Condition might not be triggering (check `y < 0.0`)
- ✓ Add `.log()` statements to see when code runs
- ✓ Ground plane might be at different Y level

**Entity launches automatically?**
- ✓ Physics might not be paused on start
- ✓ Check `onStart()` includes `pausePhysicsComponent(isPaused: true)`

**W key not working?**
- ✓ Verify key name is lowercase: `"w"` not `"W"`
- ✓ Add log in key press block to confirm detection

---

## What You Learned

✅ Applying forces with `applyForce()`  
✅ Pausing/unpausing physics simulation  
✅ Reading entity position for state checks  
✅ Clearing velocity to stop movement  
✅ Combining input with physics  
✅ Managing physics state transitions  
✅ Understanding forces vs velocity vs position

---

## Next Steps

**[Tutorial 5: Collision Detection](./05_CollisionDetection.md)** - React to collisions with other objects *(coming soon)*

**Challenges:**
- Add a maximum height limit (pause physics at y > 20)
- Create a "fuel system" that limits how long W can be held
- Add sideways thrust with A/D keys
- Make the entity rotate based on velocity direction
- Add visual effects when launching (animation or scale pulse)

**Need Help?**
- [USC Scripting API - Physics](../Scripting/USC_Scripting_API.md#9-transform--physics-helpers)
- [Using the Physics System](../Engine%20Systems/UsingPhysicsSystem.md)
- [USC Scripting API - Input](../Scripting/USC_Scripting_API.md#10-input-conditions)
