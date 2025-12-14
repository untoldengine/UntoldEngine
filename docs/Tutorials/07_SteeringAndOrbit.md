# Tutorial 7: Steering Actions & Camera Orbit

**What you'll learn**
- Use steering helpers to drive entities: `steerSeek`, `steerArrive`, `steerPursuit`
- Orbit around a point (works well for cameras)

Add these to `GenerateScripts.swift` as needed, then build.

---

## steerSeek (apply force toward a target)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateSteerSeek(to dir: URL) {
        let script = buildScript(name: "SteerSeek") { s in
            s.onStart()
                .setVariable("targetPos", to: simd_float3(5, 0, 5))
                .setVariable("maxSpeed", to: 6.0)
                .setVariable("turnSpeed", to: 1.0)
                .setVariable("dt", to: 0.016)

            s.onUpdate()
                .steerSeek(targetPosition: .variableRef("targetPos"),
                           maxSpeed: .variableRef("maxSpeed"),
                           deltaTime: .variableRef("dt"),
                           turnSpeed: .variableRef("turnSpeed"))
        }

        let outputPath = dir.appendingPathComponent("SteerSeek.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SteerSeek.uscript")
    }
}
```

## steerArrive (approach target and slow down)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateSteerArrive(to dir: URL) {
        let script = buildScript(name: "SteerArrive") { s in
            s.onStart()
                .setVariable("targetPos", to: simd_float3(-3, 0, 8))
                .setVariable("maxSpeed", to: 5.0)
                .setVariable("slowingRadius", to: 2.5)
                .setVariable("turnSpeed", to: 1.0)
                .setVariable("dt", to: 0.016)

            s.onUpdate()
                .steerArrive(targetPosition: .variableRef("targetPos"),
                             maxSpeed: .variableRef("maxSpeed"),
                             slowingRadius: .variableRef("slowingRadius"),
                             deltaTime: .variableRef("dt"),
                             turnSpeed: .variableRef("turnSpeed"))
        }

        let outputPath = dir.appendingPathComponent("SteerArrive.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SteerArrive.uscript")
    }
}
```

## steerPursuit (chase a moving entity)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateSteerPursuit(to dir: URL) {
        let script = buildScript(name: "SteerPursuit") { s in
            s.onStart()
                .setVariable("targetName", to: "Player")
                .setVariable("maxSpeed", to: 6.5)
                .setVariable("turnSpeed", to: 1.2)
                .setVariable("dt", to: 0.016)

            s.onUpdate()
                .steerPursuit(targetEntity: .variableRef("targetName"),
                              maxSpeed: .variableRef("maxSpeed"),
                              deltaTime: .variableRef("dt"),
                              turnSpeed: .variableRef("turnSpeed"))
        }

        let outputPath = dir.appendingPathComponent("SteerPursuit.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SteerPursuit.uscript")
    }
}
```

## orbit (great for camera fly-arounds)
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateOrbitCamera(to dir: URL) {
        let script = buildScript(name: "OrbitCamera") { s in
            s.onStart()
                .setVariable("center", to: simd_float3(0, 1.5, 0))
                .setVariable("radius", to: 6.0)
                .setVariable("maxSpeed", to: 4.0)
                .setVariable("turnSpeed", to: 1.0)
                .setVariable("dt", to: 0.016)

            s.onUpdate()
                .orbit(centerPosition: .variableRef("center"),
                       radius: .variableRef("radius"),
                       maxSpeed: .variableRef("maxSpeed"),
                       deltaTime: .variableRef("dt"),
                       turnSpeed: .variableRef("turnSpeed"))
        }

        let outputPath = dir.appendingPathComponent("OrbitCamera.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ OrbitCamera.uscript")
    }
}
```
