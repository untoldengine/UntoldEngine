# Tutorial 12: Physics Linear Motion Actions

Examples for the new linear motion scripting actions.

Add to `GenerateScripts.swift` as needed:
```swift
generateApplyForceExample(to: outputDir)
generateApplyImpulseExample(to: outputDir)
generateSetVelocityExample(to: outputDir)
generateAddVelocityExample(to: outputDir)
generateClampSpeedExample(to: outputDir)
generateDampingExample(to: outputDir)
generateAngularImpulseExample(to: outputDir)
generateSetAngularVelocityExample(to: outputDir)
generateClampAngularSpeedExample(to: outputDir)
generateAngularDampingExample(to: outputDir)
```

## Apply Force with a direction + magnitude

```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateApplyForceExample(to dir: URL) {
        let script = buildScript(name: "ApplyForceExample") { s in
            s.onUpdate()
                .setVariable("dir", to: simd_float3(0, 1, 0))
                .setVariable("magnitude", to: 5.0)
                .applyWorldForce(direction: .variableRef("dir"),
                                 magnitude: .variableRef("magnitude"))
        }

        let outputPath = dir.appendingPathComponent("ApplyForceExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ ApplyForceExample.uscript")
    }
}
```

## Apply Linear Impulse
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateApplyImpulseExample(to dir: URL) {
        let script = buildScript(name: "ApplyImpulseExample") { s in
            s.onUpdate()
                .setVariable("dir", to: simd_float3(1, 0, 0))
                .setVariable("magnitude", to: 2.0)
                .applyLinearImpulse(direction: .variableRef("dir"),
                                    magnitude: .variableRef("magnitude"))
        }

        let outputPath = dir.appendingPathComponent("ApplyImpulseExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ ApplyImpulseExample.uscript")
    }
}
```

## Set Linear Velocity
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateSetVelocityExample(to dir: URL) {
        let script = buildScript(name: "SetVelocityExample") { s in
            s.onUpdate()
                .setVariable("velocity", to: simd_float3(0, 0, 5))
                .setLinearVelocity(.variableRef("velocity"))
        }

        let outputPath = dir.appendingPathComponent("SetVelocityExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SetVelocityExample.uscript")
    }
}
```

## Add Linear Velocity
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateAddVelocityExample(to dir: URL) {
        let script = buildScript(name: "AddVelocityExample") { s in
            s.onUpdate()
                .setVariable("deltaVelocity", to: simd_float3(1, 0, -1))
                .addLinearVelocity(.variableRef("deltaVelocity"))
        }

        let outputPath = dir.appendingPathComponent("AddVelocityExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AddVelocityExample.uscript")
    }
}
```

## Clamp Linear Speed
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateClampSpeedExample(to dir: URL) {
        let script = buildScript(name: "ClampSpeedExample") { s in
            s.onUpdate()
                .setVariable("minSpeed", to: 2.0)
                .setVariable("maxSpeed", to: 6.0)
                .clampLinearSpeed(min: .variableRef("minSpeed"),
                                  max: .variableRef("maxSpeed"))
        }

        let outputPath = dir.appendingPathComponent("ClampSpeedExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ ClampSpeedExample.uscript")
    }
}
```

## Apply Linear Damping
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateDampingExample(to dir: URL) {
        let script = buildScript(name: "DampingExample") { s in
            s.onUpdate()
                .setVariable("damping", to: 0.5)
                .setVariable("deltaTime", to: 0.016)
                .applyLinearDamping(damping: .variableRef("damping"),
                                    deltaTime: .variableRef("deltaTime"))
        }

        let outputPath = dir.appendingPathComponent("DampingExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ DampingExample.uscript")
    }
}
```

## Apply Angular Impulse
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateAngularImpulseExample(to dir: URL) {
        let script = buildScript(name: "AngularImpulseExample") { s in
            s.onUpdate()
                .setVariable("axis", to: simd_float3(0, 1, 0))
                .setVariable("magnitude", to: 2.0)
                .applyAngularImpulse(axis: .variableRef("axis"),
                                     magnitude: .variableRef("magnitude"))
        }

        let outputPath = dir.appendingPathComponent("AngularImpulseExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AngularImpulseExample.uscript")
    }
}
```

## Set Angular Velocity
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateSetAngularVelocityExample(to dir: URL) {
        let script = buildScript(name: "SetAngularVelocityExample") { s in
            s.onUpdate()
                .setVariable("angularVelocity", to: simd_float3(0, 3, 0))
                .setAngularVelocity(.variableRef("angularVelocity"))
        }

        let outputPath = dir.appendingPathComponent("SetAngularVelocityExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ SetAngularVelocityExample.uscript")
    }
}
```

## Clamp Angular Speed
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateClampAngularSpeedExample(to dir: URL) {
        let script = buildScript(name: "ClampAngularSpeedExample") { s in
            s.onUpdate()
                .setVariable("maxAngularSpeed", to: 5.0)
                .clampAngularSpeed(max: .variableRef("maxAngularSpeed"))
        }

        let outputPath = dir.appendingPathComponent("ClampAngularSpeedExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ ClampAngularSpeedExample.uscript")
    }
}
```

## Apply Angular Damping
```swift
import Foundation
import UntoldEngine

extension GenerateScripts {
    static func generateAngularDampingExample(to dir: URL) {
        let script = buildScript(name: "AngularDampingExample") { s in
            s.onUpdate()
                .setVariable("damping", to: 0.5)
                .setVariable("deltaTime", to: 0.016)
                .applyAngularDamping(damping: .variableRef("damping"),
                                     deltaTime: .variableRef("deltaTime"))
        }

        let outputPath = dir.appendingPathComponent("AngularDampingExample.uscript")
        try? saveUSCScript(script, to: outputPath)
        print("  ✅ AngularDampingExample.uscript")
    }
}
```
