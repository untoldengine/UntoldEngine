# Rotate on Q

**What you'll learn**
- Continuous rotation while a key is held
- Using `rotateBy()` with a configurable turn speed

**Time:** ~5 minutes

---

## Steps

1) **Create the script**
- Click **Scripts: New** → name it `RotateOnKeyQ`.

2) **Wire it in `GenerateScripts.swift`**
```swift
generateRotateOnKeyQ(to: outputDir)
```

3) **Script code (`RotateOnKeyQ.swift`)**
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateRotateOnKeyQ(to dir: URL) {
        let script = buildScript(name: "RotateOnKeyQ") { s in
            s.onStart()
                .setVariable("turnSpeed", to: 2.0) // degrees per frame
                .log("Hold Q to rotate left")
            
            s.onUpdate()
                .getKeyState("q", as: "qPressed")
                .ifEqual("qPressed", to: true) { n in
                    n.rotateBy(
                        degrees: .variableRef("turnSpeed"),
                        axis: simd_float3(x: 0, y: 1, z: 0)
                    )
                }
        }
        
        let outputPath = dir.appendingPathComponent("RotateOnKeyQ.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ RotateOnKeyQ.uscript")
    }
}
```

4) **Build & test**
- In Xcode, run the GenerateScripts target to build the scripts, attach the script, press **Play**, and hold **Q** to rotate around the Y-axis. (USC scripts are authored in Xcode; the editor does not include a built-in script editor.)

Optional: You can also edit and build these scripts in Xcode if you prefer an external IDE. This is not required.

5) **Tweak turn speed**
- Adjust `"turnSpeed"` in `onStart()`; use a negative value to rotate the opposite direction.
