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

The bitmask design allows future channels to be added without changing the storage model. Bits `0...31` are reserved for built-in engine channels. Bits `32...63` are reserved for app/project-specific channels created through:

```swift
SceneChannel.userCustom(index: 0)
```

This lets apps define domain names such as `.ceilingGeometry` or `.windowGeometry` in their own code without hardcoding those semantics into the engine and without colliding with future engine channels.

## Default Assignment

Runtime and streamed entities receive `EntitySceneChannelsComponent` during registration. The default mapping is:

| Source | Channels |
|---|---|
| entity name starts with `NM_` | `.selectableGeometry`, `.preserveIdentity` |
| entity name matches a registered app prefix | registered channels |
| renderable/streamed entity without `NM_` | `.contextGeometry` |

Explicit calls to `setEntitySceneChannels(entityId:channels:)` override the default mapping. The component tracks whether its value came from engine defaults so later name updates can refresh default channels without overwriting app-defined channels.

Apps can register additional prefix mappings:

```swift
registerSceneChannelPrefix("CEIL_", channels: .userCustom(index: 0))
registerSceneChannelPrefix("WIN_", channels: .userCustom(index: 1))
```

The built-in `NM_` prefix is evaluated first to preserve selectable-object compatibility. Registered prefixes use longest-prefix matching so broad and specific project prefixes can coexist.

`fallbackSceneChannels` exists only as a temporary compatibility path for entities created outside the normal registration flow. It should be removed once all entity creation paths assign scene channels explicitly.

## Rendering

Channel rendering is controlled globally through `setSceneChannel(_:_:)`:

```swift
setSceneChannel(.contextGeometry, .renderMode(.normal))
setSceneChannel(.contextGeometry, .renderMode(.hidden))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

The older compatibility APIs map to the same render-mode state and should only be used while migrating older code:

```swift
setSceneChannelVisible(.contextGeometry, false) // Deprecated; use .renderMode(.hidden)
setSceneChannelVisible(.contextGeometry, true)  // Deprecated; use .renderMode(.normal)
```

The render passes call `shouldHideSceneEntity(entityId:)` for individual entities. Hidden entities are skipped before draw encoding. This is different from opacity: no transparent draw is submitted, so the feature avoids transparency sorting issues.

Batched rendering filters `BatchGroup`s through channel render-mode helpers. Hidden groups are skipped. Wireframe groups are skipped from solid opaque and shadow passes, then redrawn in the wireframe pass after transparency and before spatial debug overlays.

Passthrough ghost groups remain in the solid opaque path and continue to write depth. In mixed passthrough mode, the renderer lowers only the final scene-color alpha for those channels, allowing the real-world camera feed to show through while virtual geometry behind the ghosted surface remains occluded. Outside mixed passthrough mode, ghost channels render as normal opaque geometry.

Use `.ghostGeometry` for specific walls/structures that should ghost independently from the rest of `.contextGeometry`. Assigning `.ghostGeometry` to an entity updates static batching state so selected geometry can split into its own batch group.

For `.untold` assets, the exporter writes optional architectural edge index buffers for boundary and hard-angle edges. The runtime loader stores these on `RuntimeMeshPrimitive`, `Mesh`, and `BatchGroup`, and the wireframe pass draws them as line primitives when available. Meshes without edge buffers fall back to existing mesh and batch index buffers with Metal triangle line fill mode, which can display dense internal triangulation.

`WireframeRenderParams` controls visual density. `distanceFadeEnabled`, `fadeStartDistance`, `fadeEndDistance`, and `minimumAlpha` reduce line opacity for distant geometry without changing the scene-channel API. The fragment shader uses `color.a` as the near opacity and fades to `color.a * minimumAlpha` between `fadeStartDistance` and `fadeEndDistance`.

## Light Portals

Scene channels also own light portal configuration:

```swift
setSceneChannel(
    .userCustom(index: 1),
    .lightPortal(.enabled(
        intensity: 1.0,
        range: 6.0,
        useRealWorldTint: true,
        maxActivePortals: 8,
        activationDistance: 15.0
    ))
)
```

`LightPortalSystem` discovers visible render entities whose channel mask resolves to an enabled light-portal mode. Discovery rejects hidden entities, invisible render components, disabled portal channels, and geometry whose local bounds are not thin enough to infer a portal plane. Resolution then filters candidates by camera distance and emits the nearest proxy area lights up to the channel cap.

The renderer does not create persistent ECS light entities for portals. Instead, each active portal becomes a temporary area-light entry for the current frame. Authored area lights keep priority, and portal proxy lights fill only the remaining area-light capacity. When `useRealWorldTint` is enabled, portal intensity and tint come from the current XR environment lighting estimate and `realWorldLightingContribution`; if XR real-world lighting is requested but invalid, real-world-tinted portals intentionally emit at zero.

Portal discovery, resolution, performance, and render diagnostics are exposed through the light portal API and can be logged through the `.lightPortal` logger category.

## Picking

`SceneChannelInteractionState` (in `SceneContextVisibility.swift`) tracks a bitmask of channels with picking disabled via:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
```

Two gating functions in `ScenePickingSystem.swift` check both the per-entity `PickInteractionComponent.participatesInPicking` and `isSceneEntityPickableByChannel(entityId:)` (channel-derived), combining them with "most restrictive wins":

- `scenePickingShouldIgnoreEntityDueToInteractionSettings(_:)` — used by the CPU candidate list and the octree broad-phase.
- `scenePickingUsesMeshHitRepresentation(_:)` — used by the standalone GPU backend (`pickEntityGPU`) to build/validate the Metal acceleration structure. This path is also reached from `automatic`/`octreeGPUPreferred` whenever the octree is disabled, so both functions need the channel check for full backend coverage.

Toggling a channel's pick participation marks all currently-visible entities in that channel dirty (`scenePickingMarkEntityDirty`), forcing the GPU picking acceleration structures to rebuild on the next pick. `scenePickingComputeEntitySignature` also hashes the channel-derived pickability so cached signatures stay consistent.

Channel pick state does not affect batching or rendering — it only filters `pickEntity` candidates.

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

This keeps the existing selectable-object workflow intact while moving the engine feature itself toward generic channels. Additional app-specific exporter prefixes should be registered at runtime rather than added as built-in engine semantics.
