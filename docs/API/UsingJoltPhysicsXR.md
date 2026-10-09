# Getting Started: Jolt Physics in an XR Project

[UntoldJoltPhysics](https://github.com/untoldengine/UntoldJoltPhysics) installs
[Jolt Physics](https://github.com/jrouwe/JoltPhysics) behind the engine's
pluggable [Physics Backend](../Extensions/CreatingAPhysicsBackendPlugin.md)
seam. Rigid bodies described with the engine-owned `RigidBodyComponent` /
`ColliderComponent` are simulated by Jolt instead of the built-in kinetics
integrator — this gives you real collision detection, contacts, triggers and
a character controller, which matters most for XR scenes where hands and
real-world surfaces need to collide with gameplay objects.

This is a getting-started tutorial, not a full reference. See
[Physics System](UsingPhysicsSystem.md) for the engine-owned component
vocabulary and the [UntoldJoltPhysics README](https://github.com/untoldengine/UntoldJoltPhysics)
for the complete backend reference.

## 1. Add the Dependency

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

Jolt is compiled from source (no binaries) and supports macOS 14+, iOS 17+
and visionOS 2+, device and simulator.

## 2. Register the Backend Before the Renderer

```swift
import UntoldJoltPhysics

// Must run before the renderer is created — the registry locks on the
// first simulated substep, so a backend can't be swapped in mid-run.
let jolt = registerJoltPhysics()
```

If an immersive space is closed and reopened, the registry is already
locked from the previous run. Check for an existing backend first instead of
registering again:

```swift
if let active = PhysicsBackendRegistry.shared.activeBackend() {
    // Reuse it.
} else {
    registerJoltPhysics()
}
```

## 3. Give Entities Physics Components

Jolt doesn't introduce new component types — it simulates the engine's own
`RigidBodyComponent` and `ColliderComponent`:

```swift
let ball = createEntity()
setEntityMeshAsync(entityId: ball, filename: "ball", withExtension: "untold")

registerComponent(entityId: ball, componentType: ColliderComponent.self)
registerComponent(entityId: ball, componentType: RigidBodyComponent.self)

if let collider = scene.get(component: ColliderComponent.self, for: ball) {
    collider.shape = .sphere(radius: 0.12)
    collider.restitution = 0.78
}
if let body = scene.get(component: RigidBodyComponent.self, for: ball) {
    body.motionType = .dynamic
    body.mass = 0.62
}
```

Size colliders to match the mesh's real-world scale — a size-7 basketball is
about 0.12 m in radius. When a collider sits on a visible surface (a rim, a
rope), give it a slightly larger radius than the visual geometry so contacts
read as solid instead of grazing.

Watch for a mismatch between the *collider's* radius and the *mesh's*
authored scale — a soccer ball model exported at 1 m diameter still needs its
node scaled down to match an 0.11 m-radius collider, or the visual and the
physics will disagree about where the ball's surface is:

```swift
scaleTo(entityId: ball, scale: SIMD3<Float>(repeating: ballRadius * 2))
```

## 4. XR Hands as Kinematic Bodies

Represent tracked hands as kinematic spheres so dynamic bodies collide
against them, and park them far away when tracking is lost so they don't
sweep through the scene on reacquisition:

```swift
let hand = createEntity()
registerComponent(entityId: hand, componentType: ColliderComponent.self)
registerComponent(entityId: hand, componentType: RigidBodyComponent.self)

if let collider = scene.get(component: ColliderComponent.self, for: hand) {
    collider.shape = .sphere(radius: 0.07)
}
if let body = scene.get(component: RigidBodyComponent.self, for: hand) {
    body.motionType = .kinematic
}

// Each frame:
translateTo(entityId: hand, position: trackedPosition ?? SIMD3<Float>(0, -100, 0))
```

`JoltWorldSettings.maxKinematicStep` / `maxKinematicSpeed` guard against a
hand that reappears far from where it was — without them, a tracking glitch
can look like a swat at full speed.

## 5. Stepping Happens Automatically

Once registered, Jolt steps every fixed update as part of the engine's
physics loop — there's no `step()` call to make yourself.
`JoltWorldSettings.collisionSteps` controls how many Jolt sub-steps run per
engine step; the default of 1 is fine for most scenes, and a higher value
helps fast-moving bodies or cloth stay stable.

## 6. Resetting a Body

Removing and re-adding `RigidBodyComponent`/`ColliderComponent` within the
same frame is invisible to the coordinator's per-substep diff, so it isn't a
reliable way to reset a body's pose. Use the backend's own reset instead:

```swift
if let jolt = PhysicsBackendRegistry.shared.activeBackend() as? JoltPhysicsBackend {
    jolt.resetBody(entity: ball, position: spawnPoint, velocity: .zero)
}
```

This is the right tool for teleporting an entity back into play — e.g. a
ball that fell out of bounds.

## 7. A Note on Damping

`RigidBodyComponent` has no damping field, and the Jolt backend does not
currently wire per-body linear/angular damping through for rigid bodies
(only soft bodies expose it). A Jolt-backed rigid body uses Jolt's own
default linear damping (0.05 in Jolt 5.6) with no way to configure or query
it through the engine seam yet — if you need exact ballistic trajectories,
you have to account for that decay yourself. If you need the kind of
damping control described in
[Physics System](UsingPhysicsSystem.md#damping-and-speed-limits)
(`applyLinearDamping`, `applyAngularDamping`), note that those helpers act on
the built-in kinetics integrator and have no effect on entities simulated by
Jolt.

## Next Steps

For a complete, working visionOS example — a basketball demo with hand
tracking, a trigger-based scoring volume, real-world surface detection, and
backend switching at launch — see
[CoolBasket](https://github.com/untoldengine/UntoldArcade), which runs on
either its own built-in backend or UntoldJoltPhysics interchangeably.

For everything else the backend supports — layers, contact/trigger events,
raycasts, the character controller and soft bodies — see the
[UntoldJoltPhysics README](https://github.com/untoldengine/UntoldJoltPhysics).
