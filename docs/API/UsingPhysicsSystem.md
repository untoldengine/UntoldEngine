# Physics System

Untold Engine has two physics layers:

- The built-in kinetics system handles mass, gravity scale, velocity, forces, impulses, damping, and steering-style movement.
- The pluggable physics backend layer adds rigid bodies, colliders, contacts, triggers, activation events, and backend-owned simulation when a backend plugin is installed.

Use the built-in kinetics helpers for lightweight motion and gameplay steering. Use `RigidBodyComponent` and `ColliderComponent` when an external backend should own collision-aware simulation.

## Built-In Kinetics

Create an entity, load its mesh, and enable kinetics:

```swift
let player = createEntity()

setEntityMeshAsync(entityId: player, filename: "redplayer", withExtension: "untold") { success in
    guard success else { return }
    setEntityKinetics(entityId: player)
    setMass(entityId: player, mass: 0.5)
    setGravityScale(entityId: player, gravityScale: 1.0)
}
```

Apply forces, impulses, or direct velocity changes from update code:

```swift
applyForce(entityId: player, force: simd_float3(0.0, 0.0, 5.0))
applyLinearImpulse(entityId: player, direction: simd_float3(0.0, 1.0, 0.0), magnitude: 3.0)
setLinearVelocity(entityId: player, velocity: simd_float3(0.0, 0.0, -2.0))
```

Useful runtime helpers include:

```swift
getMass(entityId: player)
getVelocity(entityId: player)
setVelocity(entityId: player, velocity: simd_float3.zero)
clearForces(entityId: player)
clearVelocity(entityId: player)
clearAngularVelocity(entityId: player)
pausePhysicsComponent(entityId: player, isPaused: true)
isPhysicsComponentPaused(entityId: player)
```

Forces accumulate until the physics update consumes them. Apply forces only when gameplay intends to push the entity.

## Damping And Speed Limits

The physics system includes helpers for controlling velocity without writing the integration loop yourself.

```swift
clampLinearSpeed(entityId: player, minSpeed: 0.0, maxSpeed: 4.0)
applyLinearDamping(entityId: player, dampingFactor: 0.92, deltaTime: deltaTime)

setAngularVelocity(entityId: player, angularVelocity: simd_float3(0.0, 2.0, 0.0))
clampAngularSpeed(entityId: player, maxAngularSpeed: 3.0)
applyAngularDamping(entityId: player, dampingFactor: 0.9, deltaTime: deltaTime)
```

## Steering

The steering system calculates movement forces on top of the physics layer:

```swift
steerSeek(
    entityId: player,
    targetPosition: simd_float3(0.0, 0.0, 5.0),
    maxSpeed: 2.0,
    deltaTime: deltaTime
)
```

Additional helpers include:

- `steerFlee(entityId:threatPosition:maxSpeed:deltaTime:)`
- `steerArrive(entityId:targetPosition:maxSpeed:slowingRadius:deltaTime:)`
- `steerPursuit(entityId:targetEntity:maxSpeed:deltaTime:)`
- `steerFollowPath(entityId:path:maxSpeed:deltaTime:)`
- `steerAvoidObstacles(entityId:obstacles:avoidanceRadius:maxSpeed:deltaTime:)`

See [Steering System](UsingSteeringSystem.md) for details.

## Backend Rigid Bodies And Colliders

External physics backends consume engine-owned ECS components. An entity must have `RigidBodyComponent`, `ColliderComponent`, and a transform to be owned by the backend coordinator.

```swift
let crate = createEntity()
setEntityMeshAsync(entityId: crate, filename: "crate", withExtension: "untold")

registerComponent(entityId: crate, componentType: RigidBodyComponent.self)
registerComponent(entityId: crate, componentType: ColliderComponent.self)

if let body = scene.get(component: RigidBodyComponent.self, for: crate) {
    body.motionType = .dynamic
    body.mass = 2.0
    body.gravityScale = 1.0
    body.layer = 0
    body.collisionMask = .max
}

if let collider = scene.get(component: ColliderComponent.self, for: crate) {
    collider.shape = .box(halfExtents: simd_float3(0.5, 0.5, 0.5))
    collider.friction = 0.6
    collider.restitution = 0.1
    collider.isTrigger = false
}
```

Supported collider shapes are:

- `.sphere(radius:)`
- `.box(halfExtents:)`
- `.capsule(radius:height:)`
- `.cylinder(radius:height:)`
- `.convexHull(vertices:)`

Supported motion types are `.static`, `.kinematic`, and `.dynamic`.

## World Configuration

`PhysicsCoordinator` owns world-level settings shared by the backend and the built-in integrator.

```swift
var config = PhysicsWorldConfiguration()
config.gravity = simd_float3(0.0, -9.8, 0.0)
PhysicsCoordinator.shared.setWorldConfiguration(config)
```

If a backend is installed later, the coordinator applies the current configuration to it.

## Backend Events

When an installed backend emits events, subscribe through `PhysicsEvents`.

```swift
let contactSubscription = PhysicsEvents.shared.onContact { event in
    if event.phase == .began {
        print("Contact:", event.entityA, event.entityB)
    }
}

let triggerSubscription = PhysicsEvents.shared.onTrigger { event in
    print("Trigger:", event.phase, event.triggerEntity, event.otherEntity)
}

let activationSubscription = PhysicsEvents.shared.onActivation { event in
    print("Active:", event.entity, event.isActive)
}
```

Keep the returned `EventSubscription` alive for as long as you want to receive events. Call `cancel()` on the subscription when you no longer need it.

With no external backend installed, contact and trigger events are dormant because the built-in kinetics integrator does not perform collision detection.
