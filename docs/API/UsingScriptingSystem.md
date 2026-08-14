# Scripting System

Untold Engine includes a USC scripting layer for serializable entity behavior. It is useful when you want gameplay actions to be built in Swift, saved as data, loaded later, and executed by the engine.

The scripting API has three main pieces:

- `USCBuilder` builds scripts with a Swift fluent API.
- `USCScript` is the codable runtime script data.
- `USCInterpreter` executes a script for an entity and event.

Call `initScriptingSystem()` during startup before loading or executing scripts. This registers the script component merge behavior and the built-in math actions.

```swift
initScriptingSystem()
```

## Build A Script

Use `buildScript` for inline script creation.

```swift
let spinScript = buildScript(name: "SpinOnUpdate") { script in
    script
        .onUpdate()
        .rotateBy(degrees: 45.0, axis: simd_float3(0.0, 1.0, 0.0))
}
```

The builder stores instructions as data. The script can be executed immediately or saved to disk.

## Export And Load Scripts

Use `exportScript` to write a `.usc` file and `loadUSCScript(from:)` to load it later.

```swift
let url = projectScriptsURL.appendingPathComponent("SpinOnUpdate.usc")

try exportScript(name: "SpinOnUpdate", to: url) { script in
    script
        .onUpdate()
        .rotateBy(degrees: 45.0, axis: simd_float3(0.0, 1.0, 0.0))
}

let loadedScript = loadUSCScript(from: url)
```

You can also save an existing script:

```swift
try saveUSCScript(spinScript, to: url)
```

## Execute A Script

`USCInterpreter` executes a script against a specific entity through a `USCContext`.

```swift
let entity = createEntity()
setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold")

let context = USCContext(entityId: entity, script: spinScript)
USCInterpreter().execute(script: spinScript, context: context, forEvent: "OnUpdate")
```

For production gameplay, prefer attaching scripts through the engine's script component workflow or deserializing scene-authored scripts. Direct interpreter calls are useful for tools, tests, and custom dispatch.

## Events

Scripts are organized around events:

```swift
buildScript(name: "RobotBehavior") { script in
    script
        .onStart()
        .log("Robot spawned")

    script
        .onUpdate()
        .rotateBy(degrees: 30.0, axis: simd_float3(0.0, 1.0, 0.0))

    script
        .onCollision(tag: "Player")
        .log("Robot touched player")

    script
        .onEvent("OpenDoor")
        .translateBy(x: 0.0, y: 2.0, z: 0.0)
}
```

Physics backend events also fan out to USC events. Contact begin events fire `OnCollision`, and named variants such as `OnCollision:Player` are fired when the other entity has a name. Trigger events fire `OnTriggerEnter` and `OnTriggerExit`.

## Input Conditions

Scripts can read keyboard state and branch on key transitions:

```swift
buildScript(name: "KeyboardMove") { script in
    script
        .onUpdate()
        .ifKeyPressed("w") { block in
            block.translateBy(x: 0.0, y: 0.0, z: -0.05)
        }
        .ifKeyReleased("space") { block in
            block.log("Jump released")
        }
}
```

You can also store key state in a variable:

```swift
script.getKeyState("space", as: "spaceDown")
```

## Entity Commands

The builder includes common transform, animation, camera, and physics actions:

```swift
script.translateTo(x: 0.0, y: 1.0, z: -2.0)
script.translateBy(x: 0.0, y: 0.0, z: -0.1)
script.rotateTo(degrees: 90.0, axis: simd_float3(0.0, 1.0, 0.0))
script.rotateBy(degrees: 10.0, axis: simd_float3(0.0, 1.0, 0.0))
script.lookAt("Target")

script.playAnimation("Walk", loop: true, transitionHalflife: 0.08)
script.stopAnimation()

script.cameraMoveTo(simd_float3(0.0, 1.5, 4.0))

script.applyForce(force: simd_float3(0.0, 5.0, 0.0))
script.clearVelocity()
script.clearForces()
script.setGravityScale(1.0)
```

These commands call the same runtime systems documented elsewhere in the API guide.

## Variables And Properties

Use variables for temporary script state:

```swift
script.setVariable("speed", to: 2.0)
script.setVariable("direction", to: simd_float3(0.0, 0.0, -1.0))
script.logVariable("speed")
```

Use property access when a script needs to read or write entity state:

```swift
script.getProperty(.position, as: "currentPosition")
script.setProperty(.mass, to: 2.0)
script.setProperty(of: "Door", .position, to: simd_float3(0.0, 2.0, 0.0))
```

String key paths are also supported for lower-level access:

```swift
script.getProperty("position", as: "position")
script.getProperty("velocity.x", as: "horizontalVelocity")
script.setProperty("mass", to: 0.5)
```

Use `ScriptProperty` where possible because it avoids typos in common property names.

## Conditions And Math

The builder supports conditionals and math instructions:

```swift
buildScript(name: "MassCheck") { script in
    script
        .onUpdate()
        .getProperty(.mass, as: "mass")
        .ifLess("mass", than: 0.5) { block in
            block.log("Light object")
        }
}
```

Vector and scalar helpers include addition, subtraction, multiplication, division, normalization, dot product, cross product, lerp, reflection, projection, angle checks, and clamps.

```swift
script
    .setVariable("a", to: simd_float3(1.0, 0.0, 0.0))
    .setVariable("b", to: simd_float3(0.0, 0.0, 1.0))
    .addVec3("a", "b", as: "moveDirection")
    .normalizeVec3("moveDirection", as: "moveDirection")
```

## Custom Actions

Register custom actions through `USCActionRegistry` when a script needs to call game-specific behavior.

```swift
USCActionRegistry.shared.register(name: "Game.spawnEffect") { context, args in
    guard let effectName = args["effectName"], case let .string(name) = effectName else {
        return nil
    }

    spawnEffect(named: name, at: context.entityId)
    return nil
}

script
    .setVariable("effectName", to: "Spark")
    .callAction("Game.spawnEffect", args: ["effectName"])
```

Custom actions are a good boundary between data-driven scripts and game-specific Swift code.
