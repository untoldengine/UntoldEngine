# Move With WASD

**What you'll learn**
- WASD input pattern
- Preparing for local-space movement (relative to entity facing)
- Current limitation: USC moves in world space; see note below

**Time:** ~10 minutes

---

> ⚠️ Local-space movement (respecting the entity’s current rotation) needs a helper like `transformDirection` in the engine scripting layer. Until that ships, this tutorial shows the same WASD pattern using world-space axes so you can keep iterating. Swap the movement block once local-space support is available.

## Steps

1) **Create the script**
- Click **Scripts: New** → name it `MoveWithWASD_LocalSpace`.

2) **Wire it in `GenerateScripts.swift`**
```swift
generateMoveWithWASD_LocalSpace(to: outputDir)
```

3) **Script code (`MoveWithWASD_LocalSpace.swift`)**
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateMoveWithWASD_LocalSpace(to dir: URL) {
        let script = buildScript(name: "MoveWithWASD_LocalSpace") { s in
            // Configurable speeds
            s.onStart()
                .setVariable("moveSpeed", to: 0.08)
                .log("WASD world-space movement ready")
            
            s.onUpdate()
                .getProperty(.position, as: "pos")
                .setVariable("offset", to: simd_float3(x: 0, y: 0, z: 0))
                
                // Read keys
                .getKeyState("w", as: "wPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("d", as: "dPressed")
                
                // World-space movement (swap this block once local-space support exists)
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: 0, y: 0, z: 1))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                .ifEqual("sPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: 0, y: 0, z: -1))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                .ifEqual("aPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: -1, y: 0, z: 0))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                .ifEqual("dPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: 1, y: 0, z: 0))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                
                // Apply
                .addVec3("pos", "offset", as: "newPos")
                .setProperty(.position, toVariable: "newPos")
        }
        
        let outputPath = dir.appendingPathComponent("MoveWithWASD_LocalSpace.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ MoveWithWASD_LocalSpace.uscript")
    }
}
```

4) **Build & test**
- Build in Xcode, attach the script, and use WASD to move along world axes.

5) **Upgrade to true local-space (when available)**
- Replace the direction block with a helper that converts a local direction (e.g., `simd_float3(0,0,1)` for forward) into world space based on the entity’s rotation, then reuse the rest of this script unchanged.
