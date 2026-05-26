# Scene Channels

Scene channels are a generic bitmask used to describe how runtime entities participate in scene-level behavior. They avoid hardcoding engine features around app-specific object names while still supporting exporter conventions such as the `NM_` prefix.

## Data Model

`SceneChannel` is an `OptionSet` backed by `UInt64`. Each entity can have an `EntitySceneChannelsComponent` containing one or more channels.

Current built-in channels:

| Channel | Meaning |
|---|---|
| `.contextGeometry` | Background scene geometry that can be hidden as a group |
| `.selectableGeometry` | Runtime entities intended for picking/interaction |
| `.preserveIdentity` | Entities that should remain separate and should not be static-batched |

The bitmask design allows future channels to be added without changing the storage model.

## Default Assignment

Runtime and streamed entities receive `EntitySceneChannelsComponent` during registration. The default mapping is:

| Source | Channels |
|---|---|
| entity name starts with `NM_` | `.selectableGeometry`, `.preserveIdentity` |
| renderable/streamed entity without `NM_` | `.contextGeometry` |

Explicit calls to `setEntitySceneChannels(entityId:channels:)` override the default mapping. The component tracks whether its value came from engine defaults so later name updates can refresh default channels without overwriting app-defined channels.

`fallbackSceneChannels` exists only as a temporary compatibility path for entities created outside the normal registration flow. It should be removed once all entity creation paths assign scene channels explicitly.

## Rendering

Channel visibility is controlled globally:

```swift
setSceneChannelVisible(.contextGeometry, false)
```

The render passes call `shouldHideSceneEntity(entityId:)` for individual entities. Hidden entities are skipped before draw encoding. This is different from opacity: no transparent draw is submitted, so the feature avoids transparency sorting issues.

Batched rendering filters `BatchGroup`s through `areSceneChannelsVisible(_:)`. If a group's channel mask intersects a hidden channel, the whole group is skipped.

## Batching

Scene channels affect batching in two ways:

1. Entities with `.preserveIdentity` are excluded as batch candidates.
2. `BatchBuildKey` includes the channel mask, so entities in different channels do not merge into the same batch group.

This lets the renderer hide `.contextGeometry` batches without rebuilding batch artifacts and without affecting `.selectableGeometry` entities.

## Exporter Compatibility

The engine does not require object names to implement channels. However, the current Blender/exporter workflow uses `NM_` as a compatibility convention:

- `NM_*` objects are exported individually.
- Their names survive into the `.untold` file.
- At runtime they default to `.selectableGeometry` and `.preserveIdentity`.
- Regular merged geometry defaults to `.contextGeometry`.

This keeps the existing selectable-object workflow intact while moving the engine feature itself toward generic channels.
