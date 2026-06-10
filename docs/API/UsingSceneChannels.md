# Scene Channels

Scene channels let you group entities with a bitmask and control behavior for the group. They are useful for large spatial scenes where the app needs to treat background/context geometry differently from interactive objects.

The current built-in channels are:

| Channel | Purpose |
|---|---|
| `.contextGeometry` | Non-selectable scene context such as walls, floors, ceilings, terrain, or merged background geometry |
| `.selectableGeometry` | Entities that should remain visible and selectable as individual objects |
| `.preserveIdentity` | Entities that should not be merged into static batches because their identity matters at runtime |
| `.ghostGeometry` | Specific walls or structures selected for passthrough ghost rendering |

## Default Behavior

For exported tiled scenes, the engine assigns channels automatically:

| Entity name | Default channels |
|---|---|
| `NM_Pipe_001` | `.selectableGeometry`, `.preserveIdentity` |
| `NM_LightFixture_A` | `.selectableGeometry`, `.preserveIdentity` |
| `Wall_North` | `.contextGeometry` |
| merged tile geometry | `.contextGeometry` |

This preserves the existing `NM_` workflow. Objects whose names start with `NM_` remain selectable by default; you do not need to call a channel visibility function to make them selectable.

## Setting Channel Properties

All channel properties are set through a single function:

```swift
setSceneChannel(_ channel: SceneChannel, _ property: SceneChannelProperty)
```

`SceneChannelProperty` is an enum whose cases carry their value, so the compiler enforces the correct type for each property:

```swift
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.contextGeometry, .renderMode(.hidden))
setSceneChannel(.contextGeometry, .renderMode(.normal))
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

New properties can be added to `SceneChannelProperty` in the future without introducing new top-level functions.

## Render Modes

The `.renderMode` property accepts a `SceneChannelRenderMode`:

| Mode | Effect |
|---|---|
| `.normal` | Rendered normally (default) |
| `.hidden` | Skipped by the renderer entirely |
| `.wireframe` | Drawn as edges over the lit scene |
| `.passthroughGhost(opacity:)` | Rendered depth-opaque with reduced alpha only in mixed passthrough |

### Hiding Context Geometry

```swift
setSceneChannel(.contextGeometry, .renderMode(.hidden))
```

To show it again:

```swift
setSceneChannel(.contextGeometry, .renderMode(.normal))
```

This is a visibility feature, not transparency. Hidden entities are skipped by the renderer instead of being rendered with opacity `0.0`.

### Wireframe Mode

```swift
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

`.wireframe` skips the channel from the solid opaque passes and redraws it later over the lit scene. Exported `.untold` meshes can provide feature edge buffers (pre-selected boundary and hard-angle edges exported by the content pipeline), in which case the pass draws only those edges. Meshes without feature edge buffers fall back to triangle wireframe. This is useful for AR or construction walkthroughs where context geometry should remain available as a spatial guide without becoming semi-transparent filled surfaces.

Wireframe rendering can be softened for large scenes using `setWireframeParams`:

```swift
setWireframeParams(
    color: simd_float4(0.2, 0.85, 1.0, 0.65),
    fadeEnabled: true,
    fadeStart: 8.0,
    fadeEnd: 40.0,
    minimumAlpha: 0.08
)
```

Call this once during scene setup — the values persist until changed. All parameters have defaults so you can override only what you need.

Distance fade reduces line opacity as geometry gets farther from the camera, which helps large building models read as a nearby spatial guide instead of a dense full-scene line overlay.

The fade is based on closest-point AABB distance (not center distance), so a room the user is standing inside always renders fully regardless of `fadeEnd`. Only rooms the user is not inside — and has moved beyond `fadeEnd` from — are culled.

| Parameter | Meaning |
|---|---|
| `color` | RGBA wireframe color. `color.a` is the maximum opacity before distance fade is applied. |
| `fadeEnabled` | When `false`, all wireframe geometry renders at full `color.a` regardless of distance. |
| `fadeStart` | Distance (world units) where fading begins. Geometry closer than this uses `color.a`. |
| `fadeEnd` | Distance where fading finishes. Geometry farther than this uses the minimum opacity. |
| `minimumAlpha` | Floor opacity multiplier. Effective far opacity = `color.a × minimumAlpha`. |

The effective opacity is:

```text
near opacity = color.a
far opacity  = color.a * minimumAlpha
```

For example:

```swift
setWireframeParams(
    color: simd_float4(0.2, 0.85, 1.0, 0.2),
    fadeEnabled: true,
    fadeStart: 8.0,
    fadeEnd: 20.0,
    minimumAlpha: 0.01
)
```

This means:

| Distance from camera | Effective opacity |
|---|---|
| `0...8` units | `0.2` |
| `8...20` units | Smoothly fades from `0.2` to `0.002` |
| `20+` units | `0.002` |

To make distant lines more visible, increase `minimumAlpha` or `fadeEndDistance`. To reduce clutter sooner, lower `fadeStartDistance` or `fadeEndDistance`. To make all lines lighter, lower `color.a`.

### Passthrough Ghost Mode

```swift
setEntitySceneChannels(entityId: wallEntity, channels: .ghostGeometry)
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

`.passthroughGhost(opacity:)` keeps the channel in the opaque render path, so it continues to write depth and occlude virtual objects behind it. In mixed passthrough mode, only the rendered scene-color alpha is reduced so the camera feed shows through the surface. Virtual objects in front of the ghosted geometry still render normally.

Outside mixed passthrough mode, ghosted channels render as normal opaque geometry. The opacity value is clamped to `0.0...1.0`.

Use `.ghostGeometry` when only selected walls or structures should ghost. Regular `.contextGeometry` can stay normal, hidden, or wireframe independently. If the entity is already static-batched, changing its scene channels queues a batch rebuild so it can split from its previous context batch.

## Pick Participation

The `.pickParticipation` property controls whether ray-picking (`pickEntity`) considers an entire channel:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
setSceneChannel(.contextGeometry, .pickParticipation(true))
```

This is useful for large scenes where background geometry (walls, floors, merged tile geometry) should never be hit by picking rays, while interactive objects remain pickable:

```swift
// Walls, floors, and merged context geometry are skipped by pickEntity().
setSceneChannel(.contextGeometry, .pickParticipation(false))

// Pipes (.selectableGeometry / .preserveIdentity) are unaffected and remain pickable.
```

Channel pick state and per-entity pick state (`setEntityPickParticipation(entityId:enabled:)`) combine with "most restrictive wins": an entity is pickable only if both its channel allows picking and its own `PickInteractionComponent` allows picking. So `setEntityPickParticipation(entityId:enabled:false)` can still exclude individual entities from a channel that otherwise allows picking, but it cannot make an entity pickable again once its channel disables picking.

## Reading Channel State

```swift
let mode = getSceneChannelRenderMode(.contextGeometry)              // SceneChannelRenderMode
let visible = getSceneChannelVisible(.contextGeometry)              // Bool
let pickable = getSceneChannelPickParticipation(.contextGeometry)   // Bool
```

## Explicit Entity Channels

Apps can override the default mapping for any entity:

```swift
setEntitySceneChannels(
    entityId: pipe,
    channels: [.selectableGeometry, .preserveIdentity]
)
```

You can add or remove channels incrementally:

```swift
addEntitySceneChannels(entityId: entity, channels: .selectableGeometry)
removeEntitySceneChannels(entityId: entity, channels: .contextGeometry)
```

Query helpers:

```swift
let channels = getEntitySceneChannels(entityId: entity)
let selectable = isSelectableSceneEntity(entityId: entity)
let context = isNonSelectableSceneContextEntity(entityId: entity)
let preserveIdentity = shouldPreserveSceneEntityIdentity(entityId: entity)
```

## Recommended Construction Workflow

For large construction-site or architectural scenes:

1. Leave walls, floors, ceilings, and other background objects without the `NM_` prefix so they can be merged and assigned `.contextGeometry`.
2. Prefix interactive objects with `NM_` in Blender so they export as separate entities and receive `.selectableGeometry` plus `.preserveIdentity`.
3. At runtime, hide context geometry when the user needs a clear real-world view:

```swift
setSceneChannel(.contextGeometry, .renderMode(.hidden))
```

Or render it as a lightweight guide:

```swift
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

Or use it as a depth-opaque passthrough overlay in mixed mode:

```swift
setEntitySceneChannels(entityId: selectedWall, channels: .ghostGeometry)
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

Selectable objects remain visible and pickable.

## Notes

- Scene channels are an engine-level grouping mechanism. The `NM_` prefix is only the current exporter convention for assigning initial channels.
- `.preserveIdentity` keeps an entity out of static batching so tap-to-select and per-object metadata lookups can still target the original entity.
- Channel render modes work for both individual render entities and batch groups. Batch groups are separated by channel mask, so hiding or wireframe-rendering a channel does not require rebuilding batches.
- Wireframe mode uses exporter-authored feature edges when available. Dense meshes exported without feature edge buffers fall back to triangle edges and may show internal triangulation.

For exporter details, see [Using The Exporter](UsingTheExporter.md#selective-merging-with-the-nm_-prefix). For implementation details, see [Scene Channels Architecture](../Architecture/sceneChannels.md).
