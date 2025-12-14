# Tutorial 10: Local-Space Camera Follow (Chase/Plane Cam)

Use this when you want the camera to stick behind/above a target as it rotates (e.g., plane or third-person chase).

Add to `GenerateScripts.swift`:
```swift
generateCameraFollowLocalExample(to: outputDir)
```

Script: `CameraFollowLocalExample.swift`
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraFollowLocalExample(to dir: URL) {
        let script = buildScript(name: "CameraFollowLocalExample") { s in
            s.onUpdate()
                // Target entity name
                .setVariable("targetEntity", to: "Plane")
                // Offset is defined in target's local space (behind/above)
                .setVariable("localOffset", to: simd_float3(0, 2, -8))
                .setVariable("smoothFactor", to: 6.0)
                .setVariable("deltaTime", to: 0.016)
                .cameraFollowLocal(target: .variableRef("targetEntity"),
                                   localOffset: .variableRef("localOffset"),
                                   smoothFactor: .variableRef("smoothFactor"),
                                   deltaTime: .variableRef("deltaTime"))
        }

        let outputPath = dir.appendingPathComponent("CameraFollowLocalExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraFollowLocalExample.uscript")
    }
}
```
