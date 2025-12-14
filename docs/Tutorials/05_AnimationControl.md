# Tutorial 5: Animation Control with Scripting

**What you'll learn:**
- Playing animations with `playAnimation()`
- Stopping animations with `stopAnimation()`
- Switching between different animation states
- Using looping vs one-shot animations
- Combining animations with input
- Creating a simple state machine for animations

**Time:** ~20 minutes

---

## What We're Building

An animated character that:
1. Plays an "Idle" animation when stationary
2. Switches to "Walk" animation when moving (WASD keys)
3. Plays "Jump" animation when Space is pressed
4. Stops animations on command
5. Demonstrates proper animation state management

**Think of it like:** A game character that responds to player input with appropriate animations.

---

## Prerequisites

Before starting, make sure you understand:
- Basic scripting (Tutorial 1)
- Input handling (Tutorial 2)
- Variables and conditionals (Tutorials 2-3)

**Required Assets:**
- A rigged 3D model (with skeleton)
- Animation files (.usdc format):
  - `idle.usdc` - Idle/standing animation
  - `walking.usdc` - Walking animation
  - `jumping.usdc` - Jump animation (optional)

---

## Step 1: Set Up the Entity in Editor

### Add the Model and Animations

1. In **Untold Engine Studio**, create or select an entity for your character
2. Assign a mesh to the entity (a rigged model)
3. Add an **Animation Component**:
   - Select the entity
   - Click **Add Components** → **Animation Component**
4. Load your animation files:
   - Open **Asset Browser** → **Animations**
   - Assign your animation files (idle, walking, jumping)

**Important:** Make sure you note the exact names of your animations as they appear in the editor (e.g., "idle", "walking", "jumping"). You'll use these names in the script.

---

## Step 2: Create the Script

1. Click **Scripts: New**
2. Name it: `AnimationController`
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
        
        generateAnimationController(to: outputDir)  // Add this
        
        print("✅ All scripts generated in Generated/")
    }
}
```

---

## Step 4: Write the Animation Controller Script

Open `AnimationController.swift` and add:

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateAnimationController(to dir: URL) {
        let script = buildScript(name: "AnimationController") { s in
            // Initialize: Start with idle animation
            s.onStart()
                .setVariable("currentAnimation", to: "idle")
                .playAnimation("idle", loop: true)
                .log("Animation controller initialized - Playing idle")
            
            // Main animation loop
            s.onUpdate()
                .setVariable("isMoving", to: false)
                
                // Check for WASD input (any key means moving)
                .getKeyState("w", as: "wPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("d", as: "dPressed")
                
                // If any movement key is pressed, set isMoving to true
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("isMoving", to: true)
                }
                .ifEqual("aPressed", to: true) { n in
                    n.setVariable("isMoving", to: true)
                }
                .ifEqual("sPressed", to: true) { n in
                    n.setVariable("isMoving", to: true)
                }
                .ifEqual("dPressed", to: true) { n in
                    n.setVariable("isMoving", to: true)
                }
                
                // Switch to walking animation if moving
                .ifEqual("isMoving", to: true) { n in
                    // Only change if not already walking
                    n.ifCondition(lhs: .variableRef("currentAnimation"), .notEqual, rhs: .string("walking")) { change in
                        change.playAnimation("walking", loop: true)
                        change.setVariable("currentAnimation", to: "walking")
                        change.log("Switched to walking animation")
                    }
                }
                
                // Switch to idle animation if not moving
                .ifEqual("isMoving", to: false) { n in
                    // Only change if not already idle
                    n.ifCondition(lhs: .variableRef("currentAnimation"), .notEqual, rhs: .string("idle")) { change in
                        change.playAnimation("idle", loop: true)
                        change.setVariable("currentAnimation", to: "idle")
                        change.log("Switched to idle animation")
                    }
                }
                
                // Jump animation (one-shot, doesn't loop)
                .getKeyState("space", as: "spacePressed")
                .ifEqual("spacePressed", to: true) { n in
                    n.playAnimation("jumping", loop: false)
                    n.setVariable("currentAnimation", to: "jumping")
                    n.log("Playing jump animation")
                }
        }
        
        let outputPath = dir.appendingPathComponent("AnimationController.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AnimationController.uscript")
    }
}
```

### Understanding the Code

**`playAnimation(name, loop: true/false)`**
- Plays an animation by its name (as defined in the Animation Component)
- `loop: true` - Animation repeats continuously (ideal for walk, run, idle)
- `loop: false` - Animation plays once then stops (ideal for jump, attack, death)

**`stopAnimation()`**
- Stops the currently playing animation
- Useful for pausing or resetting animation state

**State Tracking:**
```swift
.setVariable("currentAnimation", to: "idle")
```
- Tracks which animation is currently playing
- Prevents redundant animation switches
- Avoids restarting the same animation every frame

**Animation Switching Logic:**
```swift
.ifCondition(lhs: .variableRef("currentAnimation"), .notEqual, rhs: .string("walking")) { n in
    n.playAnimation("walking", loop: true)
    n.setVariable("currentAnimation", to: "walking")
}
```
- Only switches animations if different from current
- Prevents animation restart flicker
- Keeps animations smooth

---

## Step 5: Build and Test

1. In Xcode, press **Cmd+R** to build
2. Return to **Untold Engine Studio**
3. Select your animated entity
4. Add a **Script Component** if not already present
5. Load the `AnimationController.uscript`
6. Click **Play**

**Try it out:**
- **No input**: Character plays idle animation (looping)
- **Press WASD**: Character switches to walking animation
- **Release keys**: Character returns to idle
- **Press Space**: Character plays jump animation (once)

---

## How Animation Looping Works

### Looping Animation (loop: true):
```
Frame 1 → Frame 2 → ... → Last Frame → Frame 1 (repeat)
```
- Continuous cycle
- Used for: idle, walk, run, swim, fly
- Never stops until you call `stopAnimation()` or play a different animation

### One-Shot Animation (loop: false):
```
Frame 1 → Frame 2 → ... → Last Frame → [STOP]
```
- Plays once and stops
- Used for: jump, attack, death, pickup, interact
- Character "holds" on the last frame

---

## Experiment: Simple Stop/Start Control

Add manual animation control with keys:

```swift
extension GenerateScripts {
    static func generateSimpleAnimControl(to dir: URL) {
        let script = buildScript(name: "SimpleAnimControl") { s in
            s.onStart()
                .setVariable("isPlaying", to: false)
                .log("Animation control ready")
            
            s.onUpdate()
                // Press P to play animation
                .getKeyState("p", as: "pPressed")
                .ifEqual("pPressed", to: true) { n in
                    n.ifEqual("isPlaying", to: false) { play in
                        play.playAnimation("walking", loop: true)
                        play.setVariable("isPlaying", to: true)
                        play.log("Animation playing")
                    }
                }
                
                // Press O to stop animation
                .getKeyState("o", as: "oPressed")
                .ifEqual("oPressed", to: true) { n in
                    n.ifEqual("isPlaying", to: true) { stop in
                        stop.stopAnimation()
                        stop.setVariable("isPlaying", to: false)
                        stop.log("Animation stopped")
                    }
                }
        }
        
        let outputPath = dir.appendingPathComponent("SimpleAnimControl.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SimpleAnimControl.uscript")
    }
}
```

**Controls:**
- **P key**: Play animation
- **O key**: Stop animation

---

## Experiment: Animation State Machine

Create a more sophisticated animation system with proper state transitions:

```swift
extension GenerateScripts {
    static func generateAnimStateMachine(to dir: URL) {
        let script = buildScript(name: "AnimStateMachine") { s in
            s.onStart()
                .setVariable("state", to: "idle")
                .setVariable("prevState", to: "")
                .playAnimation("idle", loop: true)
                .log("State machine initialized")
            
            s.onUpdate()
                // Store previous state
                .setVariable("prevState", to: .variableRef("state"))
                
                // Determine new state based on input
                .setVariable("newState", to: "idle")  // Default to idle
                
                // Check for movement input
                .getKeyState("w", as: "moving")
                .ifEqual("moving", to: true) { n in
                    n.setVariable("newState", to: "walking")
                }
                
                // Check for sprint (Shift + movement)
                .getKeyState("lshift", as: "sprinting")
                .ifEqual("sprinting", to: true) { n in
                    n.ifEqual("moving", to: true) { sprint in
                        sprint.setVariable("newState", to: "running")
                    }
                }
                
                // Check for jump (highest priority)
                .getKeyState("space", as: "jumping")
                .ifEqual("jumping", to: true) { n in
                    n.setVariable("newState", to: "jumping")
                }
                
                // Update state variable
                .setVariable("state", to: .variableRef("newState"))
                
                // Only play animation if state changed
                .ifCondition(lhs: .variableRef("state"), .notEqual, rhs: .variableRef("prevState")) { n in
                    // Switch based on new state
                    n.ifCondition(lhs: .variableRef("state"), .equal, rhs: .string("idle")) { idle in
                        idle.playAnimation("idle", loop: true)
                        idle.log("State: IDLE")
                    }
                    
                    n.ifCondition(lhs: .variableRef("state"), .equal, rhs: .string("walking")) { walk in
                        walk.playAnimation("walking", loop: true)
                        walk.log("State: WALKING")
                    }
                    
                    n.ifCondition(lhs: .variableRef("state"), .equal, rhs: .string("running")) { run in
                        run.playAnimation("running", loop: true)
                        run.log("State: RUNNING")
                    }
                    
                    n.ifCondition(lhs: .variableRef("state"), .equal, rhs: .string("jumping")) { jump in
                        jump.playAnimation("jumping", loop: false)
                        jump.log("State: JUMPING")
                    }
                }
        }
        
        let outputPath = dir.appendingPathComponent("AnimStateMachine.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AnimStateMachine.uscript")
    }
}
```

**State Machine Features:**
- Tracks current and previous states
- Only switches animation when state changes
- Priority system: Jump > Run > Walk > Idle
- Clean state transitions

---

## Experiment: Animation with Movement

Combine animations with actual movement for a complete character controller:

```swift
extension GenerateScripts {
    static func generateAnimatedMovement(to dir: URL) {
        let script = buildScript(name: "AnimatedMovement") { s in
            s.onStart()
                .setVariable("moveSpeed", to: 0.1)
                .setVariable("currentAnim", to: "idle")
                .playAnimation("idle", loop: true)
            
            s.onUpdate()
                .getProperty(.position, as: "currentPos")
                .setVariable("isMoving", to: false)
                
                // Forward movement with W
                .getKeyState("w", as: "wPressed")
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("isMoving", to: true)
                    n.setVariable("offset", to: simd_float3(x: 0, y: 0, z: 0.1))
                    n.addsimd_float3("currentPos", "offset", as: "newPos")
                    n.setProperty(.position, toVariable: "newPos")
                }
                
                // Switch animations based on movement
                .ifEqual("isMoving", to: true) { n in
                    n.ifCondition(lhs: .variableRef("currentAnim"), .notEqual, rhs: .string("walking")) { change in
                        change.playAnimation("walking", loop: true)
                        change.setVariable("currentAnim", to: "walking")
                    }
                }
                .ifEqual("isMoving", to: false) { n in
                    n.ifCondition(lhs: .variableRef("currentAnim"), .notEqual, rhs: .string("idle")) { change in
                        change.playAnimation("idle", loop: true)
                        change.setVariable("currentAnim", to: "idle")
                    }
                }
        }
        
        let outputPath = dir.appendingPathComponent("AnimatedMovement.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AnimatedMovement.uscript")
    }
}
```

Now the character moves AND animates in sync!

---

## Animation Best Practices

### 1. Always Track Current Animation
```swift
.setVariable("currentAnimation", to: "idle")
```
- Prevents redundant switches
- Avoids animation restart flicker
- Enables smooth transitions

### 2. Check Before Switching
```swift
.ifCondition(lhs: .variableRef("currentAnimation"), .notEqual, rhs: .string("walking")) {
    // Only switch if different
}
```
- Don't restart the same animation
- Maintains animation continuity

### 3. Use Loops Appropriately
- **Loop = true**: Idle, walk, run, swim (continuous actions)
- **Loop = false**: Jump, attack, death (one-time actions)

### 4. Animation Priority
```
Jump (highest) > Attack > Run > Walk > Idle (lowest)
```
- Higher priority animations interrupt lower ones
- Idle is always the fallback state

### 5. Match Animation Names Exactly
```swift
.playAnimation("walking", loop: true)  // Must match asset name
```
- Case-sensitive
- Must match the name in your Animation Component
- Use consistent naming conventions

---

## Common Animation Patterns

### Idle → Walk → Run
```swift
// No input = idle
// W = walk
// Shift+W = run
```

### Jump with Return to Previous State
```swift
// Track state before jump
// Play jump (loop: false)
// Return to previous state when jump finishes
```

### Attack Combo
```swift
// First click = attack1 (loop: false)
// Second click = attack2 (loop: false)
// Third click = attack3 (loop: false)
// Reset to idle
```

---

## Debugging Tips

**Animation not playing?**
- ✓ Check Animation Component is added
- ✓ Verify animation file is loaded in component
- ✓ Confirm animation name matches exactly (case-sensitive)
- ✓ Check model has a skeleton/rig

**Animation keeps restarting?**
- ✓ Remove state tracking check
- ✓ Only call `playAnimation()` when state changes
- ✓ Use `currentAnimation` variable to track state

**Wrong animation plays?**
- ✓ Check string names for typos
- ✓ Verify priority logic (which animation should win)
- ✓ Add `.log()` to see which branch executes

**Animation stops unexpectedly?**
- ✓ Check if `stopAnimation()` is being called
- ✓ Verify `loop: true` for continuous animations
- ✓ Make sure state isn't switching rapidly

---

## What You Learned

✅ Playing animations with `playAnimation()`  
✅ Stopping animations with `stopAnimation()`  
✅ Using looping vs one-shot animations  
✅ Tracking animation state  
✅ Switching between animations smoothly  
✅ Combining animations with input  
✅ Building a simple animation state machine

---

## Next Steps

**[Tutorial 6: Collision Detection](./06_CollisionDetection.md)** - React to collisions with other objects *(coming soon)*

**Challenges:**
- Add a "crouch" animation when C is pressed
- Create an attack animation that plays once on mouse click
- Build a combo system (3-hit attack sequence)
- Add animation speed control (slow-motion effect)
- Combine animations with physics (Tutorial 4)

**Need Help?**
- [USC Scripting API - Animation](../Scripting/USC_Scripting_API.md#9-transform--physics-helpers)
- [Animation System Guide](../Engine%20Systems/UsingAnimationSystem.md)
- [Adding Animations in Editor](../Editor/addAnimationsUsingEditor.md)
