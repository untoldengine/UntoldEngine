---
name: untold-scene-channels
description: Use when grouping entities to control how a class of objects behaves at runtime — hiding/wireframing background geometry, making walls/windows passthrough-ghosted in mixed XR, excluding context geometry from picking, or making window/opening geometry act as a proxy light source (light portals). Triggers on "hide this geometry", "make the walls see-through in passthrough", "windows should let light in", "exclude this from picking", "wireframe the background". Not for per-entity material color/opacity (see untold-materials-color) or spatial manipulation input (see untold-xr-spatial).
version: 0.1.0
---

# Scene Channels and Light Portals in Untold Engine

Scene channels group entities by role (context geometry, selectable objects, windows, project-specific layers) so you can change rendering, picking, and light-portal behavior for the whole group at once — instead of touching material opacity or per-entity flags. Light portals are built **on top of** scene channels, not a separate light type.

## 1. When to reach for channels instead of materials

Use a scene channel when a behavior applies to a *class* of objects: hide/wireframe background geometry, keep named objects pickable while hiding the rest, ghost window/wall geometry in mixed passthrough, or mark window surfaces as light portals. Do **not** use material opacity for these — opacity is per-entity and doesn't give passthrough-ghost or picking semantics. A hidden channel is skipped entirely by the renderer; `passthroughGhost` keeps depth behavior while reducing scene-color alpha.

## 2. Built-in channels

| Channel | Typical use |
| --- | --- |
| `.contextGeometry` | Walls, floors, ceilings, terrain, merged background geometry |
| `.selectableGeometry` | Objects that should stay visible and pickable |
| `.preserveIdentity` | Objects that must not be merged into static batches |
| `.ghostGeometry` | Walls/structures that should render as passthrough ghosts |

Exported tiled scenes assign some of these automatically — e.g. `NM_`-prefixed objects become selectable + identity-preserving.

## 3. Define and assign project-specific channels

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 0)
}
```

The engine reserves the lower bits for built-ins — always use `userCustom(index:)` for new channels, and keep indexes unique across the project.

Assign by naming convention at export time (preferred for exported scenes):

```swift
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
```

Objects named e.g. `WIN_Kitchen_01` get the channel automatically as they register. For procedural/runtime-created entities, assign directly:

```swift
setEntitySceneChannels(entityId: windowEntity, channels: .windowGeometry)
addEntitySceneChannels(entityId: entity, channels: .selectableGeometry)
removeEntitySceneChannels(entityId: entity, channels: .contextGeometry)
```

## 4. Render modes and picking

All channel behavior goes through one function:

```swift
setSceneChannel(_ channel: SceneChannel, _ property: SceneChannelProperty)
```

```swift
setSceneChannel(.contextGeometry, .renderMode(.normal))
setSceneChannel(.contextGeometry, .renderMode(.hidden))          // skipped by renderer entirely
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
setSceneChannel(.contextGeometry, .pickParticipation(false))
```

An entity is only pickable if **both** its channel-level and entity-level picking rules allow it — either one disabling picking is enough to exclude it. Read state back for UI with `getSceneChannelRenderMode`, `getSceneChannelVisible`, `getSceneChannelPickParticipation`.

`opacity: 0.0` on `passthroughGhost` makes a surface visually disappear in mixed passthrough while it still participates in depth and other channel-based systems — this is the standard pattern for real window geometry in a spatial twin.

## 5. Light portals: scene-channel geometry that emits proxy light

Light portals let channel-tagged geometry (typically window/opening surfaces) act as a proxy real-world light source for a virtual interior. They do **not** create persistent ECS light entities — the engine discovers eligible channel members each frame and treats each as a temporary two-sided area light derived from the entity's transform and local bounds.

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)
setSceneChannel(.windowGeometry, .lightPortal(.disabled))
```

Rules:
- Portal surfaces should be actual window/opening geometry with usable bounds — not entire walls or room shells. Keep the channel narrow for performance.
- Contribution is bounded by `range`; active portals are capped by `maxActivePortals`.
- Authored area lights keep priority over portal-derived proxy lights.
- `useRealWorldTint` only tints from the Vision Pro real-world lighting estimate if that's already enabled — it doesn't turn XR lighting on by itself:
  ```swift
  setRendering(.environment(.lightingMode(.realWorldEstimate)))
  setRendering(.environment(.realWorldLightingContribution(1.0)))
  ```
- Light portals don't make geometry transparent — pair with `passthroughGhost` on the same channel if the window should also show real-world passthrough:
  ```swift
  setSceneChannel(.windowGeometry, .renderMode(.passthroughGhost(opacity: 0.0)))
  ```

## 6. Diagnostics

```swift
let candidates = discoverSceneLightPortalCandidates()
let discovery = getLightPortalDiscoveryDiagnostics()
let proxies = resolveSceneLightPortalProxyLightsForActiveCamera()
let resolution = getLightPortalResolutionDiagnostics()
let performance = getLightPortalPerformanceDiagnostics()
let render = getLightPortalRenderDiagnostics()
```

Or a one-shot log:

```swift
setLogger(.category(.lightPortal, true))
LightPortalSystem.shared.logDiagnosticsNow()
setLogger(.category(.lightPortal, false))
```

## 7. Practical setup for an architectural XR scene

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}

registerSceneChannelPrefix("WIN_", channels: .windowGeometry)

setSceneChannel(.contextGeometry, .pickParticipation(false))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.windowGeometry, .renderMode(.passthroughGhost(opacity: 0.0)))
setSceneChannel(.windowGeometry, .lightPortal(.enabled(useRealWorldTint: true)))
```

Full reference: `docs/API/UsingSceneChannels.md`, `docs/API/UsingLightPortals.md`.
