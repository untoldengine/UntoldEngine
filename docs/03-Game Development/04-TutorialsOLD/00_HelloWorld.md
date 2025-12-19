# Tutorial 1: "Hello World" - Your First Script

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
2. In the toolbar, click **Scripts: Open in Xcode** (USC scripts are authored in Xcode; the editor does not include a built-in script editor).
3. Enter the script name: `HelloWorld`
4. Click OK; Xcode opens the script for editing.

When the script is created:
- The source file is added to your project
- Xcode is used for all script editing (the Untold Editor has no built-in script editor)

You'll see a template like this:

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateHelloWorld(to dir: URL) {
        // Write your script here
    }
}
```

---


## Step 2: Write the Script

Replace the function with this complete script:

```swift
import Foundation
import UntoldEngine

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

1. In Xcode, run the GenerateScripts target to build the scripts (USC scripts are authored and generated from Xcode; the editor does not include a built-in script editor).
2. Watch for the console output:

```
🔨 Generating USC scripts...
  ✅ HelloWorld.uscript
✅ All scripts generated in Generated/
```

**First build?** May take 30-60 seconds to download engine dependencies. Subsequent builds are much faster.

Optional: You can also edit and build these scripts in Xcode if you prefer an external IDE. This is not required.

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
1. In Xcode, run the GenerateScripts target to build the scripts (USC scripts are authored and generated from Xcode; the editor does not include a built-in script editor).
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

## Next Steps


**Need More Help?**
- Check the [USC Scripting API Reference](../Scripting/USC_Scripting_API.md)
- See the [Quick Start Guide](../Scripting/USC_Scripting_QuickStart.md)
