# Tutorial 6: Camera Look & Input Movement

**What you'll learn**
- Use `cameraLookAt` to aim the camera
- Move the camera to a fixed point with `cameraMoveTo`
- Drive first-person-style movement with `cameraMoveWithInput` (WASDQE)

**Time:** ~10 minutes

---

## Create the script

Add this to `GenerateScripts.swift`:
```swift
generateCameraControl(to: outputDir)
```

## Script: `CameraControl.swift`
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraControl(to dir: URL) {
        let script = buildScript(name: "CameraControl") { s in
            // Initialize look direction and base speed
            s.onStart()
                .setVariable("camPos", to: simd_float3(0, 3, -8))
                .setVariable("lookTarget", to: simd_float3(0, 1, 0))
                .setVariable("upVec", to: simd_float3(0, 1, 0))
                .setVariable("moveSpeed", to: 6.0)
                .setVariable("dt", to: 0.016) // substitute your frame delta if available

                // Move once to starting position
                .cameraMoveTo(.variableRef("camPos"))

                // Look at target
                .cameraLookAt(eye: .variableRef("camPos"),
                              target: .variableRef("lookTarget"),
                              up: .variableRef("upVec"))

            // Handle input each frame
            s.onUpdate()
                // Set speed & deltaTime
                .setVariable("speed", fromVariable: "moveSpeed")
                .setVariable("deltaTime", fromVariable: "dt")

                // Read inputs (WASD + Q/E for vertical/lift)
                .getKeyState("w", as: "wPressed")
                .getKeyState("a", as: "aPressed")
                .getKeyState("s", as: "sPressed")
                .getKeyState("d", as: "dPressed")
                .getKeyState("q", as: "qPressed")
                .getKeyState("e", as: "ePressed")

                // Move camera with input
                .cameraMoveWithInput(speedVar: "speed",
                                     deltaTimeVar: "deltaTime",
                                     wVar: "wPressed",
                                     aVar: "aPressed",
                                     sVar: "sPressed",
                                     dVar: "dPressed",
                                     qVar: "qPressed",
                                     eVar: "ePressed")
        }

        let outputPath = dir.appendingPathComponent("CameraControl.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraControl.uscript")
    }
}
```
