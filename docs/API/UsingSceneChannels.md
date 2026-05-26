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

Selectable objects remain visible and pickable.

## Notes

- Scene channels are an engine-level grouping mechanism. The `NM_` prefix is only the current exporter convention for assigning initial channels.
- `.preserveIdentity` keeps an entity out of static batching so tap-to-select and per-object metadata lookups can still target the original entity.
- Channel visibility works for both individual render entities and batch groups. Batch groups are separated by channel mask, so hiding a channel does not require rebuilding batches.

For exporter details, see [Using The Exporter](UsingTheExporter.md#selective-merging-with-the-nm_-prefix). For implementation details, see [Scene Channels Architecture](../Architecture/sceneChannels.md).
