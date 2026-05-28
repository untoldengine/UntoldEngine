# Scene Channels

Scene channels let you group entities with a bitmask and control behavior for the group. They are useful for large spatial scenes where the app needs to treat background/context geometry differently from interactive objects.

The current built-in channels are:

| Channel | Purpose |
|---|---|
| `.contextGeometry` | Non-selectable scene context such as walls, floors, ceilings, terrain, or merged background geometry |
| `.selectableGeometry` | Entities that should remain visible and selectable as individual objects |
| `.preserveIdentity` | Entities that should not be merged into static batches because their identity matters at runtime |

## Default Behavior

For exported tiled scenes, the engine assigns channels automatically:

| Entity name | Default channels |
|---|---|
| `NM_Pipe_001` | `.selectableGeometry`, `.preserveIdentity` |
| `NM_LightFixture_A` | `.selectableGeometry`, `.preserveIdentity` |
| `Wall_North` | `.contextGeometry` |
| merged tile geometry | `.contextGeometry` |

This preserves the existing `NM_` workflow. Objects whose names start with `NM_` remain selectable by default; you do not need to call a channel visibility function to make them selectable.

## Hiding Context Geometry

To hide non-selectable context geometry while keeping selectable objects visible:

```swift
setSceneChannelVisible(.contextGeometry, false)
```

To show it again:

```swift
setSceneChannelVisible(.contextGeometry, true)
```

This is a visibility feature, not transparency. Hidden entities are skipped by the renderer instead of being rendered with opacity `0.0`.

## Render Modes

Scene channels can also be assigned a render mode:

```swift
setSceneChannelRenderMode(.contextGeometry, .normal)
setSceneChannelRenderMode(.contextGeometry, .hidden)
setSceneChannelRenderMode(.contextGeometry, .wireframe)
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

The older visibility helpers are compatibility wrappers:

```swift
setSceneChannelVisible(.contextGeometry, false) // same as .hidden
setSceneChannelVisible(.contextGeometry, true)  // same as .normal
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
setSceneChannelVisible(.contextGeometry, false)
```

Or render it as a lightweight guide:

```swift
setSceneChannelRenderMode(.contextGeometry, .wireframe)
```

Selectable objects remain visible and pickable.

## Notes

- Scene channels are an engine-level grouping mechanism. The `NM_` prefix is only the current exporter convention for assigning initial channels.
- `.preserveIdentity` keeps an entity out of static batching so tap-to-select and per-object metadata lookups can still target the original entity.
- Channel render modes work for both individual render entities and batch groups. Batch groups are separated by channel mask, so hiding or wireframe-rendering a channel does not require rebuilding batches.
- Wireframe mode uses exporter-authored feature edges when available. Dense meshes exported without feature edge buffers fall back to triangle edges and may show internal triangulation.

For exporter details, see [Using The Exporter](UsingTheExporter.md#selective-merging-with-the-nm_-prefix). For implementation details, see [Scene Channels Architecture](../Architecture/sceneChannels.md).
