# Interaction / Gameplay Demo

The Interaction / Gameplay Demo shows how to combine asset loading, input,
animation switching, physics-backed steering, and scene graph parenting into a
small gameplay-style loop.

Run it from the repository root:

```bash
swift run InteractionGameplayDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/InteractionGameplayDemo/AppDelegate.swift` | Creates the renderer, `SceneView`, and callbacks. |
| `Sources/Demos/InteractionGameplayDemo/GameScene.swift` | Loads the stadium, player, and ball; handles input; switches animation; drives movement. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides shared setup helpers for resources, camera, light, and input. |

## What This Demo Teaches

This demo is about turning engine systems into a simple gameplay loop:

1. Load a static scene.
2. Load a player entity.
3. Add animations and physics behavior to the player.
4. Load a ball and parent it to the player.
5. Read keyboard input.
6. Switch animation and movement behavior every frame.

The core APIs are:

```swift
setEntityMeshAsync(...)
setEntityAnimations(...)
changeAnimation(...)
setEntityKinetics(...)
pausePhysicsComponent(...)
steerSeek(...)
setParent(...)
```

## Scene Loading

The demo loads three assets:

```swift
loadStadium(...)
loadPlayer(...)
loadBall(...)
```

Each loader follows the same async mesh pattern:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: "Red Player")
setEntityMeshAsync(entityId: entity, filename: "redplayer", withExtension: "untold") { success in
    guard success else {
        completion(nil, false)
        return
    }

    translateTo(entityId: entity, position: Constants.playerStart)
    completion(entity, true)
}
```

The player load is the most important because it also configures gameplay
systems after the mesh succeeds.

## Animation Setup

The player registers two animation clips:

```swift
setEntityAnimations(entityId: entity, filename: "running", withExtension: "untold", name: "running")
setEntityAnimations(entityId: entity, filename: "idle", withExtension: "untold", name: "idle")
changeAnimation(entityId: entity, name: "idle")
```

The clip names are the runtime handles used later:

```swift
private var currentAnimation = "idle"

private func playAnimationIfNeeded(_ name: String) {
    guard let redPlayer, currentAnimation != name else { return }
    currentAnimation = name
    changeAnimation(entityId: redPlayer, name: name)
}
```

That guard avoids repeatedly restarting the same animation every frame.

## Physics And Steering Setup

The player is configured for physics-backed movement:

```swift
setEntityKinetics(entityId: entity)
setGravityScale(entityId: entity, gravityScale: 0.0)
setLinearDragCoefficient(entityId: entity, coefficients: simd_float2(1.5, 0.2))
pausePhysicsComponent(entityId: entity, isPaused: true)
```

`setEntityKinetics(...)` prepares the entity for physics movement. Gravity is
disabled for this top-down demo, drag is tuned for stable movement, and physics
starts paused until the user presses a movement key.

The actual movement happens in `update(deltaTime:)`:

```swift
steerSeek(
    entityId: redPlayer,
    targetPosition: targetPosition,
    maxSpeed: Constants.maxPlayerSpeed,
    deltaTime: deltaTime,
    turnSpeed: Constants.turnSpeed
)
```

`steerSeek(...)` calculates steering behavior and applies movement through the
physics system. The demo computes the target from keyboard input.

## Input To Gameplay State

Input handling is deliberately small:

```swift
let input = InputSystem.shared.keyState
startMoving = input.wPressed || input.aPressed || input.sPressed || input.dPressed
```

The update loop uses `startMoving` to decide which systems should run:

```swift
if startMoving {
    playAnimationIfNeeded("running")
    pausePhysicsComponent(entityId: redPlayer, isPaused: false)
} else {
    playAnimationIfNeeded("idle")
    pausePhysicsComponent(entityId: redPlayer, isPaused: true)
    return
}
```

This keeps input polling separate from simulation. `handleInput()` records
intent. `update(deltaTime:)` applies the consequences.

## Building A Movement Target

The movement target is derived from the player's current position:

```swift
private func movementTarget(from currentPosition: simd_float3) -> simd_float3 {
    let input = InputSystem.shared.keyState
    var targetPosition = currentPosition

    if input.wPressed { targetPosition.z += 1.0 }
    if input.sPressed { targetPosition.z -= 1.0 }
    if input.aPressed { targetPosition.x -= 1.0 }
    if input.dPressed { targetPosition.x += 1.0 }

    return targetPosition
}
```

The steering system then moves the player toward that short-range target. This
is a simple pattern for keyboard-directed character motion.

## Parenting The Ball

The ball is attached to the player once both async loads have completed:

```swift
private func attachBallToPlayerIfReady() {
    guard ballAttached == false, let ball, let redPlayer else { return }
    setParent(childId: ball, parentId: redPlayer)
    ballAttached = true
}
```

`setParent(childId:parentId:)` puts the ball under the player's transform. The
ball keeps its local offset:

```swift
translateTo(entityId: entity, position: Constants.ballLocalOffset)
```

After parenting, that offset is interpreted relative to the player.

## Per-Frame Ball Rotation

The demo rotates the ball while the player moves:

```swift
rotateBy(
    entityId: ball,
    angle: Constants.ballRollDegreesPerSecond * deltaTime,
    axis: getRightAxisVector(entityId: ball)
)
```

This combines transform queries and transform updates. `getRightAxisVector(...)`
returns the ball's current right axis, and `rotateBy(...)` applies incremental
rotation around that axis.

## API Pattern To Remember

Gameplay code usually becomes a small state machine around engine APIs:

```swift
handleInput()       // read input and update intent
update(deltaTime:)  // switch animation, physics, steering, transforms
```

Use `isSceneReady()` before reading or mutating loaded entities:

```swift
if gameMode == false { return }
if isSceneReady() == false { return }
```

That keeps gameplay systems from running before async content is available.

## What To Change First

Try these changes in `Sources/Demos/InteractionGameplayDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Make the player faster | Increase `Constants.maxPlayerSpeed`. |
| Make turning slower | Decrease `Constants.turnSpeed`. |
| Change input mapping | Edit `movementTarget(from:)`. |
| Add another animation state | Register another clip with `setEntityAnimations(...)` and switch with `changeAnimation(...)`. |
| Detach the ball | Remove or conditionalize `setParent(childId:parentId:)`. |
| Change ball placement | Edit `Constants.ballLocalOffset`. |

## Related Documentation

- [Animation System](../API/UsingAnimationSystem.md)
- [Physics System](../API/UsingPhysicsSystem.md)
- [Steering System](../API/UsingSteeringSystem.md)
- [Scene Graph](../API/UsingScenegraph.md)
- [Input System](../API/UsingInputSystem.md)

