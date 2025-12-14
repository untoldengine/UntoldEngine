# Rotate Left/Right + Move Forward

**What you'll learn**
- Combining rotation and forward movement
- Separate turn speed vs move speed controls
- Using key-held logic for simultaneous actions

**Time:** ~10 minutes

---

> Note: Movement below uses world-space forward (`+Z`). If you want movement to follow the entity’s facing, pair this with a local-space helper when available (see `MoveWithWASD_LocalSpace.md`).

## Steps

1) **Create the script**
- Click **Scripts: New** → name it `RotateAndMoveCombined`.

2) **Wire it in `GenerateScripts.swift`**
```swift
generateRotateAndMoveCombined(to: outputDir)
```

3) **Script code (`RotateAndMoveCombined.swift`)**
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateRotateAndMoveCombined(to dir: URL) {
        let script = buildScript(name: "RotateAndMoveCombined") { s in
            s.onStart()
                .setVariable("moveSpeed", to: 0.08)
                .setVariable("turnSpeed", to: 2.5) // degrees per frame
                .setVariable("negTurnSpeed", to: -2.5)
                .log("Use A/D to rotate, W to move forward")
            
            s.onUpdate()
                // Read keys
                .getKeyState("a", as: "aPressed")
                .getKeyState("d", as: "dPressed")
                .getKeyState("w", as: "wPressed")
                
                // Rotation (world yaw)
                .ifEqual("aPressed", to: true) { n in
                    n.rotateBy(
                        degrees: .variableRef("turnSpeed"),
                        axis: simd_float3(x: 0, y: 1, z: 0)
                    )
                }
                .ifEqual("dPressed", to: true) { n in
                    n.rotateBy(
                        degrees: .variableRef("negTurnSpeed"),
                        axis: simd_float3(x: 0, y: 1, z: 0)
                    )
                }
                
                // Movement (forward in world space)
                .getProperty(.position, as: "pos")
                .setVariable("offset", to: simd_float3(x: 0, y: 0, z: 0))
                .ifEqual("wPressed", to: true) { n in
                    n.setVariable("dir", to: simd_float3(x: 0, y: 0, z: 1))
                    n.scaleVec3("dir", by: "moveSpeed", as: "step")
                    n.addVec3("offset", "step", as: "offset")
                }
                .addVec3("pos", "offset", as: "newPos")
                .setProperty(.position, toVariable: "newPos")
        }
        
        let outputPath = dir.appendingPathComponent("RotateAndMoveCombined.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ RotateAndMoveCombined.uscript")
    }
}
```

4) **Build & test**
- Build in Xcode, attach the script, press **Play**, hold **A/D** to spin and **W** to move forward.

5) **Tuning**
- Increase `"turnSpeed"` for snappier rotation; adjust `"moveSpeed"` for forward pace.
