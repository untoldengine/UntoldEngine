# Tutorial 8: Camera Move To Point

**What you'll learn**
- Move the camera to a specific point using `cameraMoveTo`

Add this to `GenerateScripts.swift`:
```swift
generateCameraMoveTo(to: outputDir)
```

Script: `CameraMoveTo.swift`
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraMoveTo(to dir: URL) {
        let script = buildScript(name: "CameraMoveTo") { s in
            s.onStart()
                // Target camera position
                .setVariable("camTarget", to: simd_float3(0, 3, -10))
                .cameraMoveTo(.variableRef("camTarget"))
                .log("Camera moved to start point")
        }

        let outputPath = dir.appendingPathComponent("CameraMoveTo.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraMoveTo.uscript")
    }
}
```
