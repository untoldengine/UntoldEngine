# Keyboard Movement - WASD Motion

**What you'll learn:**
- Reading keyboard input with `getKeyState()`
- Building movement vectors from multiple keys
- Combining input with `setProperty(.position)`
- Iterating quickly with Xcode builds

**Time:** ~10 minutes

**Prerequisites:**
- Untold Engine Studio open with an entity you want to move
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

A simple controller that:
1. Moves with **WASD**
2. Supports diagonal movement by combining keys
3. Uses a configurable speed variable

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `KeyboardMovement`
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
    static func generateKeyboardMovement(to dir: URL) {
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
        generateKeyboardMovement(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateKeyboardMovement) MUST match the tutorial’s script
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
    static func generateKeyboardMovement(to dir: URL) {
        let script = buildScript(name: "KeyboardMovement") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("moveSpeed", to: 0.2) // units per frame
                .setVariable("forward", to: simd_float3(x: 0, y: 0, z: 1))
                .setVariable("right", to: simd_float3(x: 1, y: 0, z: 0))
                .log("KeyboardMovement ready")
            
            // Runs every frame
            s.onUpdate()
                .getProperty(.position, as: "currentPos")
                .setVariable("offset", to: simd_float3(x: 0, y: 0, z: 0))
                
                // Read keys
                .getKeyState("w", as: "wPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("d", as: "dPressed")
                
                // Forward (W)
                .ifEqual("wPressed", to: true) { n in
                    n.scaleVec3("forward", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                // Backward (S)
                .ifEqual("sPressed", to: true) { n in
                    n.scaleVec3("forward", by: "moveSpeed", as: "stepForward")
                    n.scaleVec3("stepForward", literal: -1.0, as: "stepBack")
                    n.addVec3("offset", "stepBack", as: "offset")
                }
                // Left (A)
                .ifEqual("aPressed", to: true) { n in
                    n.scaleVec3("right", by: "moveSpeed", as: "stepRight")
                    n.scaleVec3("stepRight", literal: -1.0, as: "stepLeft")
                    n.addVec3("offset", "stepLeft", as: "offset")
                }
                // Right (D)
                .ifEqual("dPressed", to: true) { n in
                    n.scaleVec3("right", by: "moveSpeed", as: "stepRight")
                    n.addVec3("offset", "stepRight", as: "offset")
                }
                
                // Apply movement
                .addVec3("currentPos", "offset", as: "nextPos")
                .setProperty(.position, toVariable: "nextPos")
        }
        
        let outputPath = dir.appendingPathComponent("KeyboardMovement.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ KeyboardMovement.uscript")
    }
}
```

### Understanding the Code

**`getKeyState()`** - Reads whether a key is pressed this frame
- Lowercase strings like `"w"` match keyboard keys

**Offset pattern** - Build movement from multiple keys
- Start with `offset = (0,0,0)`
- Add forward/back and left/right contributions
- Apply once per frame

**`moveSpeed` variable** - Single place to tune speed
- Scale any direction by this value (or its negative)

**Position-based control** - Directly updates `.position`
- No physics required for this example
- Works consistently every frame

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ KeyboardMovement.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Select the entity you want to move
3. In the Inspector panel, click **Add Component** → **Script Component**
4. In the Asset Browser, find `KeyboardMovement.uscript` under Scripts/Generated
5. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 5: Test It!

1. Click **Play** in the toolbar
2. Press `W`, `A`, `S`, `D` to move the entity
3. Hold multiple keys (e.g., `W` + `D`) to move diagonally
4. Click **Stop** to exit Play mode

---

## Understanding the Output

- Movement updates every frame based on current key states
- Diagonal movement combines offset vectors naturally
- Changing `moveSpeed` updates all directions at once

⚠️ **Scene Scale Note:** If motion is too fast for your scene scale, drop `moveSpeed` to `0.05` and retest.

---

## Modify and Experiment

Try these changes to learn more:

### Adjustable Sprint
```swift
.getKeyState("lshift", as: "shiftPressed")
.setVariable("currentSpeed", to: 0.15)
.ifEqual("shiftPressed", to: true) { n in
    n.setVariable("currentSpeed", to: 0.4)
}
// Use currentSpeed instead of moveSpeed when scaling direction
```

### Vertical Movement
```swift
.getKeyState("space", as: "upPressed")
.getKeyState("c", as: "downPressed")
.ifEqual("upPressed", to: true) { n in
    n.addVec3("offset", simd_float3(x: 0, y: 0.2, z: 0), as: "offset")
}
.ifEqual("downPressed", to: true) { n in
    n.addVec3("offset", simd_float3(x: 0, y: -0.2, z: 0), as: "offset")
}
```

### Normalize Diagonals
```swift
.normalizeVec3("offset", as: "offset")
.scaleVec3("offset", by: "moveSpeed", as: "offset")
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Reading keyboard input with `getKeyState()`  
✅ Building movement vectors from multiple keys  
✅ Updating position every frame with `onUpdate()`  
✅ Building and attaching scripts to entities  
✅ Testing interactive input in Play mode  

---

