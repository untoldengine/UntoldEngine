# Move Forward on W

**What you'll learn**
- Single-direction movement triggered by one key
- Reading key state with `getKeyState()`
- Moving an entity by updating `.position`

**Time:** ~5 minutes

---

## Steps

1) **Create the script**
- In Untold Engine Studio, click **Scripts: New** and name it `MoveForwardOnKey`.

2) **Wire it in `GenerateScripts.swift`**
```swift
generateMoveForwardOnKey(to: outputDir)
```

3) **Script code (`MoveForwardOnKey.swift`)**
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateMoveForwardOnKey(to dir: URL) {
        let script = buildScript(name: "MoveForwardOnKey") { s in
            // Set movement speed once
            s.onStart()
                .setVariable("moveSpeed", to: 0.1)
                .log("MoveForwardOnKey ready – hold W to move")
            
            // Move while W is held
            s.onUpdate()
                .getProperty(.position, as: "pos")
                .setVariable("offset", to: simd_float3(x: 0, y: 0, z: 0))
                
                .getKeyState("w", as: "wPressed")
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: 0, y: 0, z: 1))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                
                .addVec3("pos", "offset", as: "newPos")
                .setProperty(.position, toVariable: "newPos")
        }
        
        let outputPath = dir.appendingPathComponent("MoveForwardOnKey.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ MoveForwardOnKey.uscript")
    }
}
```

4) **Build & test**
- Build in Xcode (**Cmd+R**), attach `MoveForwardOnKey.uscript` to an entity, press **Play**, then hold **W** to move forward.

5) **Tweak speed**
- Change `"moveSpeed"` in `onStart()` to tune movement distance per frame.
