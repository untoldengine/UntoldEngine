# Tutorial 9: Camera Action Examples (MoveBy, Rotate, Follow)

Add to `GenerateScripts.swift` as needed:
```swift
generateCameraMoveByExample(to: outputDir)
generateCameraRotateExample(to: outputDir)
generateCameraFollowExample(to: outputDir)
```

## cameraMoveBy (world offset)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraMoveByExample(to dir: URL) {
        let script = buildScript(name: "CameraMoveByExample") { s in
            s.onStart()
                // Move camera by +X/+Y/+Z in world space
                .setVariable("delta", to: simd_float3(1, 2, 3))
                .cameraMoveBy(.variableRef("delta"))
        }

        let outputPath = dir.appendingPathComponent("CameraMoveByExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraMoveByExample.uscript")
    }
}
```

## cameraRotate (pitch/yaw)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraRotateExample(to dir: URL) {
        let script = buildScript(name: "CameraRotateExample") { s in
            s.onUpdate()
                .setVariable("pitch", to: 0.0)   // look up/down
                .setVariable("yaw", to: -0.08)   // look left/right
                .setVariable("sensitivity", to: 1.0)
                .cameraRotate(pitch: .variableRef("pitch"),
                              yaw: .variableRef("yaw"),
                              sensitivity: .variableRef("sensitivity"))
        }

        let outputPath = dir.appendingPathComponent("CameraRotateExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraRotateExample.uscript")
    }
}
```

## cameraFollow (offset + smoothing)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraFollowExample(to dir: URL) {
        let script = buildScript(name: "CameraFollowExample") { s in
            s.onUpdate()
                .setVariable("targetEntity", to: "Player")
                .setVariable("offset", to: simd_float3(0, 3, -6))
                .setVariable("smoothFactor", to: 5.0) // higher = snappier
                .setVariable("deltaTime", to: 0.016)   // your frame dt
                .cameraFollow(target: .variableRef("targetEntity"),
                              offset: .variableRef("offset"),
                              smoothFactor: .variableRef("smoothFactor"),
                              deltaTime: .variableRef("deltaTime"))
        }

        let outputPath = dir.appendingPathComponent("CameraFollowExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraFollowExample.uscript")
    }
}
```
