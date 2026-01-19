# Apply Force - Physics Push

**What you'll learn:**
- Applying world-space forces with `applyWorldForce()`
- Controlling force direction and magnitude with variables
- Testing physics-driven motion from Xcode builds
- Building scripts in Xcode before playtesting

**Time:** ~8 minutes

**Prerequisites:**
- Untold Engine Studio open with an entity that has a Physics/Kinetic component
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

A physics push that:
1. Applies a continuous upward force
2. Uses variables for direction and magnitude
3. Shows how to tweak force strength between builds

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `ApplyForce`
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
    static func generateApplyForce(to dir: URL) {
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
        generateApplyForce(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateApplyForce) MUST match the tutorial’s script
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
    static func generateApplyForce(to dir: URL) {
        let script = buildScript(name: "ApplyForce") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("forceDir", to: simd_float3(x: 0, y: 1, z: 0))
                .setVariable("forceMagnitude", to: 0.2)
                .log("ApplyForce ready")
            
            // Runs every frame
            s.onUpdate()
                .applyWorldForce(
                    direction: .variableRef("forceDir"),
                    magnitude: .variableRef("forceMagnitude")
                )
        }
        
        let outputPath = dir.appendingPathComponent("ApplyForce.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ ApplyForce.uscript")
    }
}
```

### Understanding the Code

**`forceDir` + `forceMagnitude`** - Set the push direction and strength
- `(0, 1, 0)` pushes upward
- Reduce magnitude for gentle movement; increase for stronger lifts

**`applyWorldForce()`** - Applies a force in world space
- Requires a Physics/Kinetic component on the entity
- Accumulates over time, so the object accelerates while the force runs

**`onUpdate()`** - Applies force every frame
- Stop the push by setting magnitude to 0 or disabling the Script Component

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ ApplyForce.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Add an entity to the scene.
3. In the Inspector panel, click **Add Component** → **Kinetic Component** 
4. In the Inspector panel, click **Add Component** → **Script Component**
5. In the Asset Browser, find `ApplyForce.uscript` under Scripts/Generated
6. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 6: Test It!

1. Click **Play** in the toolbar
2. Watch the entity accelerate upward as the force is applied each frame
3. Open the **Console** view to confirm:
   ```
   ApplyForce ready
   ```
4. Click **Stop** to exit Play mode

---

## Understanding the Output

- The entity accelerates while the force is active
- Direction is world-based; change `forceDir` to push sideways
- Lower gravity or heavier masses will change how fast it moves

⚠️ **Physics Note:** Forces accumulate; if the object moves too fast, lower `forceMagnitude` or apply the force only on certain frames.

---

## Modify and Experiment

Try these changes to learn more:

### Short Burst Instead of Continuous Force
```swift
s.onStart()
    .setVariable("framesLeft", to: 60) // apply for 1 second at ~60 FPS

s.onUpdate()
    .ifGreater("framesLeft", than: 0) { n in
        n.applyWorldForce(direction: .variableRef("forceDir"),
                          magnitude: .variableRef("forceMagnitude"))
        n.addFloat("framesLeft", literal: -1, as: "framesLeft")
    }
```

### Sideways Push
```swift
.setVariable("forceDir", to: simd_float3(x: 1, y: 0, z: 0)) // push along +X
```

### Switch to Impulse
```swift
s.onUpdate()
    .applyLinearImpulse(direction: .variableRef("forceDir"),
                        magnitude: .variableRef("forceMagnitude"))
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Applying forces to physics-enabled entities  
✅ Controlling direction and magnitude with variables  
✅ Building and attaching physics scripts in the editor  
✅ Testing physics responses in Play mode  

---

