# Move an Entity - Basic Translation

**What you'll learn:**
- Moving an entity with `setProperty(.position)`
- Using `simd_float3` direction vectors
- Controlling speed with script variables
- Updating position every frame with `onUpdate()`

**Time:** ~7 minutes

**Prerequisites:**
- Untold Engine Studio installed and a scene with any entity (a cube works great)
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

A simple movement script that:
1. Moves an entity steadily along a chosen axis
2. Uses variables to control speed and direction
3. Logs a message when movement begins

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `MoveAnEntity`
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
    static func generateMoveAnEntity(to dir: URL) {
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
        generateMoveAnEntity(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateMoveAnEntity) MUST match the tutorial’s script
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
    static func generateMoveAnEntity(to dir: URL) {
        let script = buildScript(name: "MoveAnEntity") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("moveSpeed", to: 0.05) // units per frame
                .setVariable("direction", to: simd_float3(x: 0, y: 0, z: 1))
                .log("MoveAnEntity ready")
            
            // Runs every frame
            s.onUpdate()
                .getProperty(.position, as: "currentPos")
                .scaleVec3("direction", by: "moveSpeed", as: "step")
                .addVec3("currentPos", "step", as: "nextPos")
                .setProperty(.position, toVariable: "nextPos")
        }
        
        let outputPath = dir.appendingPathComponent("MoveAnEntity.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ MoveAnEntity.uscript")
    }
}
```

### Understanding the Code

**`moveSpeed` + `direction`** - Control how fast and where to move
- Speed is a scalar; direction is a vector (x, y, z)
- Change either without touching the rest of the script

**`getProperty(.position, as:)`** - Reads the current position
- Positions are `simd_float3` values

**`scaleVec3()` + `addVec3()`** - Build the new position
- Scales the direction by speed
- Adds it to the current position for smooth motion

**`setProperty(.position, toVariable:)`** - Applies the updated position
- Runs every frame inside `onUpdate()`
- Keeps the movement continuous while Play mode runs

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ MoveAnEntity.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 4: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Select any entity in your scene (a cube or platform)
3. In the Inspector panel, click **Add Component** → **Script Component**
4. In the Asset Browser, find `MoveAnEntity.uscript` under Scripts/Generated
5. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 5: Test It!

1. Click **Play** in the toolbar
2. Watch the entity move steadily along the +Z axis
3. Check the **Console** view to confirm:
   ```
   MoveAnEntity ready
   ```
4. Click **Stop** to exit Play mode

---

## Understanding the Output

- The entity moves every frame toward +Z
- Speed comes from `moveSpeed`; direction comes from `direction`
- To stop movement, disable the Script Component or set speed to 0

⚠️ **Placement Note:** If the entity is already near a boundary, lower the speed or adjust the start position to avoid moving out of view.

---

## Modify and Experiment

Try these changes to learn more:

### Move Upward Instead
```swift
.setVariable("direction", to: simd_float3(x: 0, y: 1, z: 0))
```

### Slow or Fast Motion
```swift
.setVariable("moveSpeed", to: 0.01) // slower
// or
.setVariable("moveSpeed", to: 0.15) // faster
```

### Pause After a Distance
```swift
s.onUpdate()
    .getProperty(.position, as: "currentPos")
    .ifGreater("currentPos.z", than: 10.0) { n in
        n.setVariable("moveSpeed", to: 0.0) // stop after z > 10
    }
    .scaleVec3("direction", by: "moveSpeed", as: "step")
    .addVec3("currentPos", "step", as: "nextPos")
    .setProperty(.position, toVariable: "nextPos")
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Creating a movement script in Untold Engine Studio  
✅ Using variables for speed and direction  
✅ Updating position every frame with `onUpdate()`  
✅ Building and attaching scripts to entities  
✅ Testing motion in Play mode  

---

## Need More Help?

- [USC/Introduction](../../03-USC/01_Introduction.md)  
- [USC/QuickStart](../../03-USC/02_QuickStart.md)  
- [USC/Workflow](../../03-USC/03_Workflow.md)  
- [USC/Script](../../03-USC/04_Scritps.md)  
- [USC/API Reference](../../03-USC/05_APIReference.md)  
