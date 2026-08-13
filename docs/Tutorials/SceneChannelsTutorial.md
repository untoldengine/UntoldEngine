# Scene Channels And Passthrough Rendering

Scene channels let you group entities and change how that group behaves at
runtime. They are useful when a spatial app needs to treat context geometry,
selectable objects, windows, ceilings, annotations, or discipline-specific
layers differently.

This tutorial focuses on the API pattern:

```swift
setEntitySceneChannels(entityId: entity, channels: .contextGeometry)
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

## When To Use Scene Channels

Use scene channels when a behavior applies to a class of objects:

- hide or wireframe background geometry
- keep named objects selectable
- ghost window or wall geometry in mixed passthrough
- exclude context geometry from picking
- identify window surfaces for light portals
- prevent specific entities from being merged into static batches

Do not use material opacity for these cases. A hidden scene channel is skipped by
the renderer, and a passthrough ghost channel keeps depth behavior while reducing
scene-color alpha in mixed passthrough.

## Built-In Channels

Untold Engine provides these built-in channels:

| Channel | Typical Use |
| --- | --- |
| `.contextGeometry` | Walls, floors, ceilings, terrain, merged background geometry. |
| `.selectableGeometry` | Objects that should remain visible and pickable. |
| `.preserveIdentity` | Objects that should not be merged into static batches. |
| `.ghostGeometry` | Selected walls or structures that should render as passthrough ghosts. |

Exported tiled scenes assign some channels automatically. For example, objects
with the `NM_` prefix are treated as selectable and identity-preserving.

## Define Project Channels

Use user custom channels for app-specific groups:

```swift
extension SceneChannel {
    static let ceilingGeometry = SceneChannel.userCustom(index: 0)
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}
```

The engine reserves the lower channel bits for built-in channels. Custom channel
indexes avoid future collisions.

## Assign Channels By Prefix

For exported scenes, prefix registration is usually better than assigning every
entity manually:

```swift
registerSceneChannelPrefix("CEIL_", channels: .ceilingGeometry)
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
```

Now exported objects named `CEIL_MainHall` or `WIN_Kitchen_01` are assigned to
those channels as they are registered.

## Assign Channels Directly

For procedural or runtime-created entities, assign channels directly:

```swift
setEntitySceneChannels(
    entityId: windowEntity,
    channels: .windowGeometry
)
```

You can also add or remove channels incrementally:

```swift
addEntitySceneChannels(entityId: entity, channels: .selectableGeometry)
removeEntitySceneChannels(entityId: entity, channels: .contextGeometry)
```

## Render Modes

All channel behavior is set through:

```swift
setSceneChannel(_ channel: SceneChannel, _ property: SceneChannelProperty)
```

Common render modes:

```swift
setSceneChannel(.contextGeometry, .renderMode(.normal))
setSceneChannel(.contextGeometry, .renderMode(.hidden))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.ghostGeometry, .renderMode(.passthroughGhost(opacity: 0.35)))
```

`hidden` skips rendering. `wireframe` draws edges over the lit scene.
`passthroughGhost` is designed for mixed passthrough XR.

## Passthrough Window Geometry

For spatial twin windows, use a custom window channel:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}

registerSceneChannelPrefix("WIN_", channels: .windowGeometry)

setSceneChannel(
    .windowGeometry,
    .renderMode(.passthroughGhost(opacity: 0.0))
)
```

An opacity of `0.0` makes the rendered surface visually disappear in mixed
passthrough, while the channel can still participate in depth and other
channel-based systems. This is useful when the app wants the real window view to
show through without losing the architectural meaning of the window geometry.

## Picking Control

Disable picking for background context while leaving selectable objects alone:

```swift
setSceneChannel(.contextGeometry, .pickParticipation(false))
```

The entity must pass both its channel-level and entity-level picking rules. If
either one disables picking, the entity is not returned by picking APIs.

## Reading Channel State

Use query helpers when building UI controls:

```swift
let mode = getSceneChannelRenderMode(.contextGeometry)
let visible = getSceneChannelVisible(.contextGeometry)
let pickable = getSceneChannelPickParticipation(.contextGeometry)
```

## Practical Setup Pattern

For an architectural XR scene:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}

registerSceneChannelPrefix("WIN_", channels: .windowGeometry)

setSceneChannel(.contextGeometry, .pickParticipation(false))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
setSceneChannel(.windowGeometry, .renderMode(.passthroughGhost(opacity: 0.0)))
```

This keeps ordinary context geometry available as a spatial guide, skips it from
picking, and lets real window content show through in mixed passthrough.

## Related Documentation

- [Scene Channels](../API/UsingSceneChannels.md)
- [Light Portals](../API/UsingLightPortals.md)
- [Spatial Input](../API/UsingSpatialInput.md)
- [Static Batching](../API/UsingStaticBatchingSystem.md)

