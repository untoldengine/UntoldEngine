# Animation State Switch - Idle to Walk

**What you'll learn:**
- Switching animations based on input
- Tracking current state to avoid restart flicker
- Using `playAnimation()` for looped clips
- Building and testing animations from Xcode

**Time:** ~10 minutes

**Prerequisites:**
- Untold Engine Studio open with an entity that has an **Animation Component** and two clips loaded (e.g., `idle`, `walk`)
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

An animation controller that:
1. Plays `idle` when no movement keys are pressed
2. Switches to `walk` when any WASD key is pressed
3. Only changes clips when the state actually changes

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `AnimationStateSwitch`
4. Click OK, then Xcode opens the Scripts package

When the script is created:
- The source file is added to your project
- You edit the script in Xcode

You'll see a template like this:

```swift
import Foundation
import UntoldEngine
import simd

extension GenerateScripts {
    static func generateAnimationStateSwitch(to dir: URL) {
        // Write your script here
    }
}
```
> This script is added to GenerateScripts, which is the entry point the engine uses to discover and generate USC scripts.

---


## Step 2: Wire Up the Script

⚠️ IMPORTANT MANUAL STEP

The editor created your script file, but you need to tell the build system to generate it.

1. Click Scripts: Open in Xcode (blue button in toolbar)
2. In Xcode, open GenerateScripts.swift
3. Add your script to the main() function:

```swift
@main
struct GenerateScripts {
    static func main() {
        print("🔨 Generating USC scripts...")
        
        let outputDir = URL(fileURLWithPath: "Generated/")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Add this line:
        generateAnimationStateSwitch(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateAnimationStateSwitch) MUST match the tutorial’s script
Only adjust that single line per tutorial
The structure, wording, and warning must remain consistent across all documents

---


## Step 3: Write the Script

Replace the function with this complete script:

```swift
import Foundation
import UntoldEngine
import simd

extension GenerateScripts {
    static func generateAnimationStateSwitch(to dir: URL) {
        let script = buildScript(name: "AnimationStateSwitch") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("currentAnim", to: "idle")
                .playAnimation("idle", loop: true)
                .log("AnimationStateSwitch ready - idle playing")
            
            // Runs every frame
            s.onUpdate()
                // Read movement keys
                .getKeyState("w", as: "wPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("d", as: "dPressed")
                
                // Determine if moving
                .setVariable("isMoving", to: false)
                .ifEqual("wPressed", to: true) { n in n.setVariable("isMoving", to: true) }
                .ifEqual("aPressed", to: true) { n in n.setVariable("isMoving", to: true) }
                .ifEqual("sPressed", to: true) { n in n.setVariable("isMoving", to: true) }
                .ifEqual("dPressed", to: true) { n in n.setVariable("isMoving", to: true) }
                
                // Switch to walk when moving
                .ifEqual("isMoving", to: true) { n in
                    n.ifCondition(lhs: .variableRef("currentAnim"), .notEqual, rhs: .string("walk")) { change in
                        change.playAnimation("walk", loop: true)
                        change.setVariable("currentAnim", to: "walk")
                        change.log("Switched to walk")
                    }
                }
                
                // Switch back to idle when not moving
                .ifEqual("isMoving", to: false) { n in
                    n.ifCondition(lhs: .variableRef("currentAnim"), .notEqual, rhs: .string("idle")) { change in
                        change.playAnimation("idle", loop: true)
                        change.setVariable("currentAnim", to: "idle")
                        change.log("Switched to idle")
                    }
                }
        }
        
        let outputPath = dir.appendingPathComponent("AnimationStateSwitch.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AnimationStateSwitch.uscript")
    }
}
```

### Understanding the Code

**State tracking** - `currentAnim` stores what is playing
- Prevents restarting the same clip every frame
- Eliminates flicker when staying in the same state

**Input gating** - `isMoving` becomes true if any WASD key is pressed
- One boolean drives all animation switching

**`playAnimation()` only on change** - Uses a condition to switch
- Keeps transitions smooth
- Avoids repeating the same clip call

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ AnimationStateSwitch.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Add an entity to the scene.
3. In the Asset Library, double click on the animations you want to add to the entity, such as `idle` and `walk`
3. In the Inspector panel, click **Add Component** → **Script Component**
4. In the Asset Browser, find `AnimationStateSwitch.uscript` under Scripts/Generated
5. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 5: Test It!

1. Click **Play** in the toolbar
2. With no input, the entity plays `idle`
3. Press any of `W`, `A`, `S`, `D` to switch to `walk`
4. Release the keys to return to `idle`
5. Click **Stop** to exit Play mode

---

## Understanding the Output

- Idle is the default and fallback state
- Walk plays only while movement keys are down
- No flicker because the script checks before switching

⚠️ **Name Matching:** Clip names are case-sensitive. If your clips are named differently (e.g., `Idle`, `Walking`), update the script strings.

---

## Modify and Experiment

Try these changes to learn more:

### Add a Run State with Shift
```swift
.getKeyState("lshift", as: "shiftPressed")
.ifEqual("shiftPressed", to: true) { n in
    n.ifEqual("isMoving", to: true) { run in
        run.ifCondition(lhs: .variableRef("currentAnim"), .notEqual, rhs: .string("run")) { change in
            change.playAnimation("run", loop: true)
            change.setVariable("currentAnim", to: "run")
        }
    }
}
```

### Add a Jump One-Shot
```swift
.getKeyState("space", as: "jumpPressed")
.ifEqual("jumpPressed", to: true) { n in
    n.playAnimation("jump", loop: false)
    n.setVariable("currentAnim", to: "jump")
}
```

### Reset to Idle After a Delay
```swift
.setVariable("idleTimer", to: 30.0) // half-second at ~60 FPS
.ifEqual("isMoving", to: false) { n in
    n.addFloat("idleTimer", literal: -1.0, as: "idleTimer")
    n.ifEqual("idleTimer", to: 0.0) { back in
        back.playAnimation("idle", loop: true)
        back.setVariable("currentAnim", to: "idle")
    }
}
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Switching animations based on player input  
✅ Tracking the current clip to avoid restart flicker  
✅ Using looped clips for idle/walk states  
✅ Building, attaching, and testing animation controllers  

---

## Need More Help?

- [USC/Introduction](../../03-USC/01_Introduction.md)  
- [USC/QuickStart](../../03-USC/02_QuickStart.md)  
- [USC/Workflow](../../03-USC/03_Workflow.md)  
- [USC/Script](../../03-USC/04_Scritps.md)  
- [USC/API Reference](../../03-USC/05_APIReference.md)  
