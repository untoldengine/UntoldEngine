# Rotate an Entity - Continuous Spin

**What you'll learn:**
- Rotating entities with `rotateTo()` inside `onUpdate()`
- Tracking angles with script variables
- Choosing rotation axes with `simd_float3`
- Building USC scripts entirely in Xcode

**Time:** ~7 minutes

**Prerequisites:**
- Untold Engine Studio open with any entity selected (a cube makes rotation easy to see)
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

A rotation script that:
1. Spins an entity around a chosen axis
2. Uses a variable to track the current angle
3. Lets you adjust spin speed without rewriting the script

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `RotateAnEntity`
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
    static func generateRotateAnEntity(to dir: URL) {
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
        generateRotateAnEntity(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateRotateAnEntity) MUST match the tutorial’s script
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
    static func generateRotateAnEntity(to dir: URL) {
        let script = buildScript(name: "RotateAnEntity") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("rotationSpeed", to: 2.0) // degrees per frame
                .setVariable("currentAngle", to: 0.0)
                .setVariable("axis", to: simd_float3(x: 0, y: 1, z: 0))
                .log("RotateAnEntity ready")
            
            // Runs every frame
            s.onUpdate()
                .addFloat("currentAngle", "rotationSpeed", as: "nextAngle")
                .setVariable("currentAngle", to: .variableRef("nextAngle"))
                .rotateTo(
                    degrees: .variableRef("currentAngle"),
                    axis: simd_float3(x:0,y:1,z:0)
                )
        }
        
        let outputPath = dir.appendingPathComponent("RotateAnEntity.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ RotateAnEntity.uscript")
    }
}
```

### Understanding the Code

**`rotationSpeed`** - Controls how much to rotate each frame
- Higher values spin faster
- Change this without touching the rest of the script

**`currentAngle`** - Tracks total rotation
- Prevents drift and keeps rotation smooth

**`axis`** - A `simd_float3` defining which way to spin
- `(0, 1, 0)` spins around Y (like a turntable)
- `(1, 0, 0)` spins forward/backward
- `(0, 0, 1)` spins left/right

**`rotateTo()`** - Sets an absolute rotation
- Uses the stored angle each frame
- Cleanly resets if you set `currentAngle` back to `0`

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ RotateAnEntity.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Select the entity you want to rotate
3. In the Inspector panel, click **Add Component** → **Script Component**
4. In the Asset Browser, find `RotateAnEntity.uscript` under Scripts/Generated
5. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 6: Test It!

1. Click **Play** in the toolbar
2. Watch the entity spin around the Y-axis
3. Open the **Console** view to confirm:
   ```
   RotateAnEntity ready
   ```
4. Click **Stop** to exit Play mode

---

## Understanding the Output

- The entity rotates smoothly using `rotationSpeed` degrees per frame
- Changing `axis` changes the spin direction without new code
- Resetting `currentAngle` to `0` realigns the entity instantly

⚠️ **Consistency Note:** Large `rotationSpeed` values can cause visible jumps. Increase gradually for smoother motion.

---

## Modify and Experiment

Try these changes to learn more:

### Rotate with `rotateBy()`
```swift
s.onUpdate()
    .rotateBy(
        degrees: 1.0,
        axis: simd_float3(x: 0, y: 1, z: 0)
    )
```

### Spin on Multiple Axes
```swift
.setVariable("axis", to: simd_float3(x: 1, y: 1, z: 0)) // diagonal spin
```

### Start Facing a Specific Direction
```swift
s.onStart()
    .rotateTo(
        degrees: 45.0,
        axis: simd_float3(x: 0, y: 1, z: 0)
    )
    .setVariable("currentAngle", to: 45.0)
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Creating a rotation script in Untold Engine Studio  
✅ Tracking angles with script variables  
✅ Rotating entities around any axis  
✅ Building and attaching scripts to entities  
✅ Testing rotations in Play mode  

---

## Need More Help?

- [USC/Introduction](../../03-USC/01_Introduction.md)  
- [USC/QuickStart](../../03-USC/02_QuickStart.md)  
- [USC/Workflow](../../03-USC/03_Workflow.md)  
- [USC/Script](../../03-USC/04_Scritps.md)  
- [USC/API Reference](../../03-USC/05_APIReference.md)  
