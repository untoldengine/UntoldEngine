# Play an Animation - Single Clip

**What you'll learn:**
- Playing an animation clip with `playAnimation()`
- Looping vs. one-shot playback
- Using variables to track the current clip
- Building and testing animations from Xcode

**Time:** ~8 minutes

**Prerequisites:**
- Untold Engine Studio open with an entity that has an **Animation Component** and at least one loaded clip (e.g., `idle`)
- Access to Xcode via **Scripts: Open in Xcode** (toolbar button)

---

## What We're Building

A simple animation script that:
1. Plays a single clip on start
2. Loops it continuously
3. Shows how to trigger a one-shot clip on demand

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `PlayAnimation`
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
    static func generatePlayAnimation(to dir: URL) {
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
        generatePlayAnimation(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generatePlayAnimation) MUST match the tutorial’s script
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
    static func generatePlayAnimation(to dir: URL) {
        let script = buildScript(name: "PlayAnimation") { s in
            // Runs once when the entity starts
            s.onStart()
                .setVariable("idleClip", to: "idle")   // Must match the clip name in the Animation Component
                .setVariable("currentClip", to: "idle")
                .playAnimation("idle", loop: true)
                .log("Playing idle animation (looping)")
            
            // Optional: trigger a one-shot animation with Space
            s.onUpdate()
                .getKeyState("space", as: "spacePressed")
                .ifEqual("spacePressed", to: true) { n in
                    n.playAnimation("jump", loop: false) // Replace with your one-shot clip name
                    n.setVariable("currentClip", to: "jump")
                    n.log("Playing jump animation (one-shot)")
                }
        }
        
        let outputPath = dir.appendingPathComponent("PlayAnimation.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ PlayAnimation.uscript")
    }
}
```

### Understanding the Code

**`playAnimation(name, loop:)`** - Starts an animation by name
- `loop: true` repeats continuously (great for idle or walk)
- `loop: false` plays once (great for jump or attacks)

**Clip names** - Must match exactly what you see in the Animation Component
- Case-sensitive
- If you rename a clip in the editor, update the script too

**`currentClip` variable** - Tracks what is playing
- Useful when adding more conditions later

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ PlayAnimation.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Select an entity that has an **Animation Component**
3. In the Asset Library, double click on the animations you want to add to the entity, i.e. `idle` and `jump`
4. In the Inspector panel, click **Add Component** → **Script Component**
5. In the Asset Browser, find `PlayAnimation.uscript` under Scripts/Generated
6. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 6: Test It!

1. Click **Play** in the toolbar
2. The entity should immediately play the `idle` clip on loop
3. Tap **Space** to trigger the one-shot clip (e.g., `jump`)
4. Click **Stop** to exit Play mode

---

## Understanding the Output

- Looping clip runs continuously until another clip interrupts it
- One-shot clip plays once; if you need to return to idle automatically, add a timer or state check
- If nothing plays, verify the clip names match the Animation Component exactly

⚠️ **Asset Note:** The script only calls animations that already exist on the entity’s Animation Component. Ensure clips are loaded and named correctly.

---

## Modify and Experiment

Try these changes to learn more:

### Start with a Different Clip
```swift
.setVariable("idleClip", to: "breathing_idle")
.playAnimation("breathing_idle", loop: true)
```

### Return to Idle After One-Shot
```swift
s.onUpdate()
    .getKeyState("space", as: "spacePressed")
    .ifEqual("spacePressed", to: true) { n in
        n.playAnimation("jump", loop: false)
        n.setVariable("currentClip", to: "jump")
    }
    // Simple timer to return to idle after ~1 second
    .setVariable("returnTimer", to: 60.0) // frames at ~60 FPS
    .ifGreater("returnTimer", than: 0.0) { n in
        n.addFloat("returnTimer", literal: -1.0, as: "returnTimer")
    }
    .ifEqual("returnTimer", to: 0.0) { n in
        n.playAnimation("idle", loop: true)
        n.setVariable("currentClip", to: "idle")
    }
```

### Add a Stop Button
```swift
.getKeyState("p", as: "pPressed")
.ifEqual("pPressed", to: true) { n in
    n.stopAnimation()
    n.log("Animation stopped")
}
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ Playing animation clips with `playAnimation()`  
✅ Looping vs. one-shot playback  
✅ Tracking the current clip with script variables  
✅ Building, attaching, and testing animation scripts  

---

## Need More Help?

- [USC/Introduction](../../03-USC/01_Introduction.md)  
- [USC/QuickStart](../../03-USC/02_QuickStart.md)  
- [USC/Workflow](../../03-USC/03_Workflow.md)  
- [USC/Script](../../03-USC/04_Scritps.md)  
- [USC/API Reference](../../03-USC/05_APIReference.md)  
