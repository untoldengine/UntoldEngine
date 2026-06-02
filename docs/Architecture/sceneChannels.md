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
| `.ghostGeometry` | Specific walls/structures selected for passthrough ghost rendering |

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

Channel rendering is controlled globally. The compatibility visibility API maps to render modes:

```swift
setSceneChannelVisible(.contextGeometry, false) // .hidden
setSceneChannelVisible(.contextGeometry, true)  // .normal
```

New code can set the render mode directly:

```swift
setSceneChannelRenderMode(.contextGeometry, .normal)
setSceneChannelRenderMode(.contextGeometry, .hidden)
setSceneChannelRenderMode(.contextGeometry, .wireframe)
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

The render passes call `shouldHideSceneEntity(entityId:)` for individual entities. Hidden entities are skipped before draw encoding. This is different from opacity: no transparent draw is submitted, so the feature avoids transparency sorting issues.

Batched rendering filters `BatchGroup`s through channel render-mode helpers. Hidden groups are skipped. Wireframe groups are skipped from solid opaque and shadow passes, then redrawn in the wireframe pass after transparency and before spatial debug overlays.

Passthrough ghost groups remain in the solid opaque path and continue to write depth. In mixed passthrough mode, the renderer lowers only the final scene-color alpha for those channels, allowing the real-world camera feed to show through while virtual geometry behind the ghosted surface remains occluded. Outside mixed passthrough mode, ghost channels render as normal opaque geometry.

Use `.ghostGeometry` for specific walls/structures that should ghost independently from the rest of `.contextGeometry`. Assigning `.ghostGeometry` to an entity updates static batching state so selected geometry can split into its own batch group.

For `.untold` assets, the exporter writes optional architectural edge index buffers for boundary and hard-angle edges. The runtime loader stores these on `RuntimeMeshPrimitive`, `Mesh`, and `BatchGroup`, and the wireframe pass draws them as line primitives when available. Meshes without edge buffers fall back to existing mesh and batch index buffers with Metal triangle line fill mode, which can display dense internal triangulation.

`WireframeRenderParams` controls visual density. `distanceFadeEnabled`, `fadeStartDistance`, `fadeEndDistance`, and `minimumAlpha` reduce line opacity for distant geometry without changing the scene-channel API. The fragment shader uses `color.a` as the near opacity and fades to `color.a * minimumAlpha` between `fadeStartDistance` and `fadeEndDistance`.

## Batching

Scene channels affect batching in two ways:

1. Entities with `.preserveIdentity` are excluded as batch candidates.
2. `BatchBuildKey` includes the channel mask, so entities in different channels do not merge into the same batch group.

This lets the renderer hide or wireframe-render `.contextGeometry` batches without rebuilding batch artifacts and without affecting `.selectableGeometry` entities.

## Exporter Compatibility

The engine does not require object names to implement channels. However, the current Blender/exporter workflow uses `NM_` as a compatibility convention:

- `NM_*` objects are exported individually.
- Their names survive into the `.untold` file.
- At runtime they default to `.selectableGeometry` and `.preserveIdentity`.
- Regular merged geometry defaults to `.contextGeometry`.

This keeps the existing selectable-object workflow intact while moving the engine feature itself toward generic channels.
