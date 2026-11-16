---
name: untold-physics
description: Use when an entity needs real collision (rigid bodies, triggers, contacts, raycasts, a character controller), or any kind of movement/steering behavior (chase, flee, follow a path, avoid obstacles) in Untold Engine. The project is moving to the Jolt backend as the default/preferred physics path for everything, including movement — not just collision — so this skill recommends Jolt first. Triggers on "add physics to this object", "make this fall/bounce/collide", "chase/flee/follow a path", "detect when these two objects touch", "XR hands should collide with objects", "move an NPC toward the player". Not for general entity/transform setup (see untold-entity-scene) or physics-driven pose/ragdoll blending on an animated skeleton (see untold-animation-advanced).
version: 0.1.0
---

# Physics and Movement in Untold Engine

**Default to the Jolt backend for anything in this skill's scope — collision, triggers, raycasts, character/NPC movement, and chase/flee/follow-path style behavior.** The engine also ships a built-in kinetics layer and a native `SteeringSystem`, but the project is actively moving away from recommending either: kinetics has no real collision, and `SteeringSystem` only drives kinetics — it silently no-ops on Jolt-backed entities (tracked in [untoldengine/UntoldEngine#1417](https://github.com/untoldengine/UntoldEngine/issues/1417)). Reach for kinetics only for a trivial, collision-free, non-gameplay-movement case (see §5); otherwise register Jolt and build on it.

## 1. Add the dependency and register the Jolt backend

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/untoldengine/UntoldEngine.git", branch: "develop"),
    .package(url: "https://github.com/untoldengine/UntoldJoltPhysics.git", branch: "develop"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "UntoldEngine", package: "UntoldEngine"),
            .product(name: "UntoldJoltPhysics", package: "UntoldJoltPhysics"),
        ]
    ),
]
```

Jolt is compiled from source (no binaries), macOS 14+/iOS 17+/visionOS 2+, device and simulator.

```swift
import UntoldJoltPhysics

// Before the renderer is created — the registry locks on the first simulated substep.
if let active = PhysicsBackendRegistry.shared.activeBackend() {
    // Reuse it — e.g. an XR immersive space was closed and reopened; the registry is already locked.
} else {
    registerJoltPhysics()
}
```

Jolt simulates the engine's own component vocabulary — it doesn't introduce new component types:

```swift
let ball = createEntity()
setEntityMeshAsync(entityId: ball, filename: "ball", withExtension: "untold")

registerComponent(entityId: ball, componentType: ColliderComponent.self)
registerComponent(entityId: ball, componentType: RigidBodyComponent.self)

if let collider = scene.get(component: ColliderComponent.self, for: ball) {
    collider.shape = .sphere(radius: 0.12)   // match real-world scale
    collider.restitution = 0.78
}
if let body = scene.get(component: RigidBodyComponent.self, for: ball) {
    body.motionType = .dynamic   // or .static / .kinematic
    body.mass = 0.62
}
```

Supported shapes: `.sphere(radius:)`, `.box(halfExtents:)`, `.capsule(radius:height:)`, `.cylinder(radius:height:)`, `.convexHull(vertices:)`; set `isTrigger` on the collider for sensor volumes.

**Match the collider to the mesh's authored scale** — if the model was exported at a different real-world size than the collider, visual and physics disagree about where the surface is:

```swift
scaleTo(entityId: ball, scale: SIMD3<Float>(repeating: ballRadius * 2))
```

Adding `RigidBodyComponent`/`ColliderComponent` with **no backend registered is a silent no-op** — nothing moves or collides, and nothing errors. If an object "isn't doing anything," check `PhysicsBackendRegistry.shared.activeBackend()` first.

## 2. Chase, flee, follow-path, avoid-obstacle movement — use the character controller, not the native SteeringSystem

Do **not** reach for the engine's `steerSeek`/`steerArrive`/`steerFlee`/`steerPursuit`/`steerFollowPath`/`steerAvoidObstacles`/`steerWithWASD` on a Jolt-backed entity — they only apply force through `PhysicsComponents` (kinetics) and have no effect on `RigidBodyComponent` bodies. That mismatch is a known, tracked bug, not a documentation gap you should work around by mixing systems.

Instead, drive a `JoltCharacter` yourself: compute a target velocity each frame with ordinary steering math (seek = direction-to-target × max speed; arrive = seek scaled down inside a slowing radius; flee = negated seek; pursuit = seek toward a predicted future position; follow-path = seek toward the next waypoint, advance on arrival) and pass that velocity into `move`. Jolt's `CharacterVirtual` handles collision and sliding against the environment and other bodies — you own the character's height and gravity isn't added for you (pass gravity into the velocity yourself if the character should fall):

```swift
let backend = PhysicsBackendRegistry.shared.activeBackend() as? JoltPhysicsBackend
let character = backend?.addCharacter(entity: npc, /* capsule/cylinder shape, position, ... */)

// Every frame, between physics steps:
let toTarget = targetPosition - character.position
let seekVelocity = safeNormalize(toTarget) * maxSpeed
character.move(velocity: seekVelocity, deltaTime: deltaTime)
```

Obstacle avoidance: use `PhysicsQuery.raycast` (Jolt answers the engine's raycast capability) to probe ahead of the character and steer the computed velocity away from a hit, rather than the native `steerAvoidObstacles`.

Remove the character with `backend?.removeCharacter(entity:)` when it leaves play. Every `JoltCharacter` call (`move`/`teleport`/`position`/`contacts`) is frame-thread only, between steps — don't call it from a background queue.

For a prop (not an NPC/player) that just needs to physically exist and react to collisions without being steered toward anything, a plain dynamic `RigidBodyComponent` (§1) is enough — you don't need a character controller for that.

## 3. XR hands as kinematic colliders

```swift
registerComponent(entityId: hand, componentType: ColliderComponent.self)
registerComponent(entityId: hand, componentType: RigidBodyComponent.self)
// collider.shape = .sphere(radius: 0.07); body.motionType = .kinematic

translateTo(entityId: hand, position: trackedPosition ?? SIMD3<Float>(0, -100, 0))
```

Kinematic bodies are moved with `MoveKinematic` over the substep, carrying the velocity implied by the engine's transform writes and imparting it on what they hit. `JoltWorldSettings.maxKinematicStep`/`maxKinematicSpeed` turn a tracking glitch (hand reappearing far away) into a teleport instead of a full-speed swat.

## 4. Resetting/teleporting a body

Removing and re-adding the components in the same frame is invisible to the coordinator's diff — not a reliable reset. Use the backend's own reset, e.g. for a ball that fell out of bounds:

```swift
if let jolt = PhysicsBackendRegistry.shared.activeBackend() as? JoltPhysicsBackend {
    jolt.resetBody(entity: ball, position: spawnPoint, velocity: .zero)
}
```

A `JoltCharacter` has its own `teleport`, independent of `resetBody`.

## 5. Built-in kinetics — legacy, use only for trivial collision-free motion

The engine also has a dependency-free kinetics layer (`setEntityKinetics`, `setMass`, `applyForce`, `setLinearVelocity`, `clampLinearSpeed`, `applyLinearDamping`, …; full list in `docs/API/UsingPhysicsSystem.md`). It moves an entity but detects no collisions at all. Reach for it only when nothing in the scene needs to collide with the entity and no chase/flee/path-following behavior is involved — e.g. a projectile with gravity and a one-time impulse that nothing else needs to react to. Do not pair it with the native `SteeringSystem` and call that "steering working" — it only happens to work because both pieces are on the legacy kinetics layer; as the project moves toward Jolt-only physics, this whole layer (and `SteeringSystem` with it) is expected to be phased out. Prefer §2's approach even for simple cases if there's any chance the entity will need real collision later.

## 6. World configuration and stepping

```swift
var config = PhysicsWorldConfiguration()
config.gravity = simd_float3(0.0, -9.8, 0.0)
PhysicsCoordinator.shared.setWorldConfiguration(config)
```

Jolt steps automatically once registered — no manual `step()` call. Default is a fixed 1/60 s step. On a 90/100 Hz headset, set:

```swift
setEngine(.simulationStepping(.perFrame))
```

so the world steps with every frame instead of leaving frames with no new physics pose under the fixed step. `JoltWorldSettings.collisionSteps` further divides each step (default 1; raise it — e.g. 3 — for a powered ragdoll or fast/cloth bodies that need stability).

## 7. Events and queries

```swift
let contactSubscription = PhysicsEvents.shared.onContact { event in
    if event.phase == .began { /* ... */ }
}
let triggerSubscription = PhysicsEvents.shared.onTrigger { event in /* ... */ }
let activationSubscription = PhysicsEvents.shared.onActivation { event in /* ... */ }
```

Keep the returned `EventSubscription` alive as long as needed; `.cancel()` when done. Contact `.began` is only reported past `minContactSpeed` (resting contacts aren't impacts); triggers see dynamic bodies only and rays pass through them. `PhysicsQuery.raycast` is the general-purpose ray query (exclusions, layer masks).

## 8. Common pitfalls

- Using `steerSeek`/`steerArrive`/etc. on a Jolt-backed entity → silent no-op, not a bug in your code ([#1417](https://github.com/untoldengine/UntoldEngine/issues/1417)). Drive a `JoltCharacter` with your own steering math instead (§2).
- Adding `RigidBodyComponent`/`ColliderComponent` and seeing nothing happen → no backend registered. Check `PhysicsBackendRegistry.shared.activeBackend()`.
- Registering the backend after the renderer/first simulated substep → too late; register during app/scene init.
- `applyLinearDamping`/`applyAngularDamping` act on kinetics only — no effect on Jolt-simulated bodies. A Jolt rigid body uses Jolt's own fixed default linear damping (0.05 in Jolt 5.6) with no engine-exposed control.
- Trying to reset a Jolt body by removing/re-adding components in one frame → invisible to the coordinator; use `resetBody` (or `JoltCharacter.teleport` for characters).
- Collider size not matching the mesh's authored scale → visuals and collision disagree about where the surface is.

Full reference: `docs/API/UsingPhysicsSystem.md` (legacy kinetics vocabulary), `docs/API/UsingJoltPhysicsXR.md`, `docs/API/UsingSteeringSystem.md` (native steering — being phased out, see §2 instead), and the [UntoldJoltPhysics README](https://github.com/untoldengine/UntoldJoltPhysics) for the full backend surface (layers, soft bodies, environment boxes, the complete character-controller API).
