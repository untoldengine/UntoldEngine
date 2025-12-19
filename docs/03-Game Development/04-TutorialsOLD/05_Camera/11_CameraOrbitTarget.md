# Tutorial 11: Orbit Camera Around an Entity

Add to `GenerateScripts.swift`:
```swift
generateCameraOrbitTargetExample(to: outputDir)
```

Script: `CameraOrbitTargetExample.swift`
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateCameraOrbitTargetExample(to dir: URL) {
        let script = buildScript(name: "CameraOrbitTargetExample") { s in
            s.onUpdate()
                .setVariable("targetEntity", to: "Boss")
                .setVariable("radius", to: 10.0)
                .setVariable("speed", to: 1.2)   // angular speed
                .setVariable("deltaTime", to: 0.016)
                .setVariable("offset", to: 1.5)  // optional Y lift
                .cameraOrbitTarget(target: .variableRef("targetEntity"),
                                   radius: .variableRef("radius"),
                                   speed: .variableRef("speed"),
                                   deltaTime: .variableRef("deltaTime"),
                                   offsetY: .variableRef("offset"))
        }

        let outputPath = dir.appendingPathComponent("CameraOrbitTargetExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ CameraOrbitTargetExample.uscript")
    }
}
```
