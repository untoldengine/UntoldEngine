# "Hello World" - Your First Script

**What you'll learn:**
- Creating a script in Untold Engine Studio
- Using `onStart()` and `onUpdate()` lifecycle events
- Logging messages for debugging
- Attaching scripts to entities

**Time:** ~5 minutes

---

## What We're Building

A simple script that:
1. Logs "Hello, Untold Engine!" when the entity starts
2. Logs "Script running..." every frame during Play mode

---

## Step 1: Create the Script

1. Open **Untold Engine Studio**
2. In the toolbar, click **Scripts: Open in Xcode** (blue button)
3. Click the `+` button and enter the script name: `HelloWorld`
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
    static func generateHelloWorld(to dir: URL) {
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
        generateHelloWorld(to: outputDir)
        
        print("✅ All scripts generated in Generated/")
    }
}
```

Now run the GenerateScripts target (`Cmd+R`) to generate the `.uscript` files.


MPORTANT NOTES:
The function name (e.g. generateHelloWorld) MUST match the tutorial’s script
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
    static func generateHelloWorld(to dir: URL) {
        let script = buildScript(name: "HelloWorld") { s in
            // Runs once when entity starts
            s.onStart()
                .log("Hello, Untold Engine!")
                .log("Script initialized successfully")
            
            // Runs every frame
            s.onUpdate()
                .log("Script running...")
        }
        
        let outputPath = dir.appendingPathComponent("HelloWorld.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ HelloWorld.uscript")
    }
}
```

### Understanding the Code

**`buildScript(name:)`** - Creates a new script
- The name identifies the script in the editor

**`onStart()`** - Lifecycle event that runs once
- Perfect for initialization
- Logs appear in the console when Play mode starts

**`onUpdate()`** - Lifecycle event that runs every frame
- Use for continuous behaviors
- Be mindful of performance (runs 60+ times per second!)

**`.log()`** - Outputs debug messages
- Messages appear in the editor's Console view
- Great for debugging and tracking execution

---

## Step 4: Build the Script

1. In Xcode, press `Cmd+R` to run the GenerateScripts target and generate the `.uscript` (optional: `Cmd+B` first to verify the build).
2. Watch for the Xcode run output:

```
🔨 Generating USC scripts...
  ✅ HelloWorld.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

---

## Step 5: Attach to an Entity

1. Return to **Untold Engine Studio**
2. Select any entity in your scene (create a cube if needed)
3. In the Inspector panel, click **Add Component** → **Script Component**
4. In the Asset Browser, find `HelloWorld.uscript` under Scripts/Generated
5. Double click on the `.uscript`. The script will be linked to the entity
---

## Step 6: Test It!

1. Click **Play** in the toolbar
2. Open the **Console** view (bottom panel)
3. You should see:
   ```
   Hello, Untold Engine!
   Script initialized successfully
   Script running...
   Script running...
   Script running...
   ...
   ```

4. Click **Stop** to exit Play mode

---

## Understanding the Output

- **"Hello, Untold Engine!"** appears once (from `onStart()`)
- **"Script running..."** appears continuously (from `onUpdate()`)

⚠️ **Performance Note:** `onUpdate()` runs every frame! In a real game, avoid heavy logging in `onUpdate()`. This example is just for demonstration.

---

## Modify and Experiment

Try these changes to learn more:

### Change the Messages
```swift
s.onStart()
    .log("Game initialized")
    .log("Player ready!")
```

### Remove the Update Log
```swift
s.onUpdate()
    // Remove .log() to avoid console spam
```

### Add Initialization Variables
```swift
s.onStart()
    .setVariable("playerName", to: "Hero")
    .setVariable("health", to: 100.0)
    .log("Player initialized with 100 health")
```

After making changes:
1. In Xcode, press `Cmd+R` to rerun the GenerateScripts target and regenerate the scripts (`Cmd+B` optional first).
2. Click **Reload** in the Script Component Inspector
3. Test in Play mode

---

## What You Learned

✅ How to create a script in Untold Engine Studio  
✅ Using `onStart()` for initialization  
✅ Using `onUpdate()` for per-frame logic  
✅ Logging debug messages  
✅ Building and attaching scripts to entities  
✅ Testing scripts in Play mode  

---
