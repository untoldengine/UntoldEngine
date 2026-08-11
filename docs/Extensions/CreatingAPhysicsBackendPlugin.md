# Creating a Physics Backend Plugin

A physics backend replaces the engine's numerical simulation for entities that
opt in, while everything else — components, events, queries, the frame loop —
stays engine-owned. This guide covers everything needed to implement one in an
external Swift package, without reading engine source. The engine keeps zero
native dependencies: heavyweight physics libraries (Jolt, PhysX, …) live in
your plugin package, never in core.

For the general plugin philosophy (namespacing, licensing, review expectations)
read [Plugin Authoring Guidelines](PluginAuthoringGuidelines.md) first —
notably: optional native libraries and binary frameworks belong in the plugin
repository, and dependency licenses should be MIT/BSD/Zlib/Apache-2.0.

## The moving parts

| Engine type | Role |
|---|---|
| `PhysicsBackend` | The protocol your simulation implements |
| `PhysicsBackendPlugin` + `PhysicsBackendPluginManifest` | Identity, versioning, validation |
| `PhysicsBackendRegistry` | Single-slot install/uninstall with rollback |
| `ColliderComponent`, `RigidBodyComponent` | Engine-owned ECS vocabulary — never define your own |
| `PhysicsCoordinator` | Engine-side driver; you never call it directly |
| `PhysicsEventSink` | Where your buffered events go each substep |
| `PhysicsQuery.raycast` | Routed to your backend when you report `.raycast` |

## Minimal skeleton

```swift
import UntoldEngine

final class MyBackend: PhysicsBackend {
    let id = "com.example.myphysics.backend"
    let capabilities: PhysicsCapabilities = [.collisions, .raycast]

    func configure(_ config: PhysicsWorldConfiguration) { /* gravity, layers */ }
    func didAddBody(entity: EntityID, descriptor: PhysicsBodyDescriptor) { /* create body */ }
    func didRemoveBody(entity: EntityID) { /* destroy body */ }
    func step(deltaTime: Float) { /* advance simulation one fixed substep */ }
    func drainEvents(into sink: any PhysicsEventSink) { /* hand over buffered events */ }
    func writeKinematicTargets(_ batch: PhysicsBodyWriteBatch) { /* engine → you */ }
    func readActiveTransforms(into batch: PhysicsTransformReadBatch) -> Int { /* you → engine */ }
    func raycast(_ ray: PhysicsRay, filter: PhysicsQueryFilter) -> PhysicsRayHit? { /* query */ }
}

struct MyBackendPlugin: PhysicsBackendPlugin {
    let manifest = PhysicsBackendPluginManifest(
        id: "com.example.myphysics",
        displayName: "My Physics",
        version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
        requiredAPIVersion: .current
    )

    func makeBackend() -> any PhysicsBackend { MyBackend() }
}
```

Every method except `configure` and `step` has a default no-op implementation,
so a minimal backend implements only what it supports. Calls gated on a
capability you don't declare are defined no-ops.

Install before creating the renderer:

```swift
switch PhysicsBackendRegistry.shared.install(MyBackendPlugin()) {
case .installed, .replaced: break
case let .rejected(failure): print(failure) // validation errors, conflict, or lock
}
```

Validation requires a reverse-DNS namespaced plugin ID, a backend ID inside the
plugin's namespace, and an exact `requiredAPIVersion` match. One external
backend is active at a time: installing under the same ID replaces it, a
different ID while one is installed is rejected. The registry **locks on the
first simulated substep** — install/uninstall after that are rejected for the
rest of the run.

## What the engine does with your backend

Installing schedules the engine's `PhysicsCoordinator` (an `EngineExtension`)
into the fixed-timestep loop; uninstalling removes it. Once per fixed substep,
after the built-in integrator, the coordinator:

1. **Diffs the body set.** Entities carrying `RigidBodyComponent` +
   `ColliderComponent` + `LocalTransformComponent` are yours. New ones arrive
   via `didAddBody` with a `PhysicsBodyDescriptor` snapshot (shape, mass,
   layer/mask, gravity scale, initial pose and velocities); entities that lost
   those components or were destroyed arrive via `didRemoveBody`.
2. **Writes kinematic targets** — one `PhysicsBodyWriteBatch` with parallel
   entity/transform buffers for every kinematic body.
3. **Calls `step(deltaTime:)`.**
4. **Reads transforms back** — you fill the `PhysicsTransformReadBatch` with
   your *active* bodies (sleeping bodies can be skipped) and return the count.
   The engine applies them to dynamic bodies' `LocalTransformComponent` and
   marks the scene graph dirty.
5. **Drains events** via `drainEvents(into:)`.

The built-in integrator keeps running for legacy `PhysicsComponents`/
`KineticComponent` entities regardless — both can coexist in one scene, and
your backend never sees them.

## Contracts to honor

- **Threading.** Every protocol method is called on the engine's frame thread.
  Parallelize internally all you like, but callbacks from your worker threads
  must never reach the engine: buffer events into fixed-capacity storage during
  `step` and hand them over only in `drainEvents`. Report overflow through
  `reportDroppedEvents(count:)` — never allocate or throw mid-step.
- **Batch-only transforms.** Transform exchange happens through the two batch
  calls, one contiguous buffer per direction per substep. Never per-body calls.
  The buffers are valid only for the duration of the call.
- **Units.** Metres/kilograms/seconds, Y-up, quaternion orientations — matching
  `PhysicsWorldConfiguration`, whose `collisionLayerMatrix[layer]` is the bit
  mask of layers that `layer` collides with (empty = everything collides).

## Events

Deliver `PhysicsContactEvent` (began/persisted/ended),
`PhysicsTriggerEvent` (entered/exited) and `PhysicsBodyActivationEvent` to the
sink during `drainEvents`. The engine fans them out to `PhysicsEvents`
subscribers and fires USC script events (`OnCollision`, `OnTriggerEnter`,
`OnTriggerExit`) — you only produce the events; delivery order is your
delivery order.

## Queries

Declare `.raycast` and `PhysicsQuery.raycast(_:filter:)` routes to your
`raycast` implementation — your answer (including a miss) is authoritative.
Without the capability, the engine answers from its octree of entity bounds
instead. Honor `PhysicsQueryFilter`: skip `excludedEntities`, and test
`layerMask` against each body's layer. Shapecast and overlap capability bits
exist but are not yet exposed through `PhysicsQuery`; declaring them today is
harmless and future-proof.

## Testing without an engine run

The engine's own suites (`PhysicsBackendRegistryTests`,
`PhysicsCoordinatorTests`, `PhysicsEventsTests`, `PhysicsQueryTests`) exercise
every seam above with mock backends — they double as reference implementations
for the protocol's expected behavior. A useful pattern for your package's
tests: install your plugin, drive `PhysicsCoordinator.shared.fixedUpdate`
manually, and assert on your backend's recorded calls, exactly as those suites
do.
