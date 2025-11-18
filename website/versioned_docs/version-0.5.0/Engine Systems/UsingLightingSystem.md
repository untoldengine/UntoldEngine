---
id: lightinsystem
title: Lighting System
sidebar_position: 3
---

# Enabling the Lighting System in Untold Engine

The Lighting System lets you add illumination to your scenes using common real-time light types. Under the hood it wires up the required ECS components, provides an editor-friendly visual handle, and tags the light so the renderer can pick it up.

---

## Creating Each Light Type
### Directional Light

Use for sunlight or distant key lights. Orientation (rotation) defines its direction.

```swift
let sun = createEntity()
createDirLight(entityId: sun)
```
### Point Light

Omni light that radiates equally in all directions from a position.

```swift 
let bulb = createEntity()
createPointLight(entityId: bulb)
```

### Spot Light

Cone-shaped light with a position and direction.

```swift
let spot = createEntity()
createSpotLight(entityId: spot)
```

### Area Light

Rect/area emitter used to mimic panels/windows; position and orientation matter.

```swift
let panel = createEntity()
createAreaLight(entityId: panel)
```

