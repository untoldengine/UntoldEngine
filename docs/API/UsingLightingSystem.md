# Enabling the Lighting System in Untold Engine

The Lighting System lets you add illumination to your scenes using common real-time light types. Under the hood it wires up the required ECS components, provides an editor-friendly visual handle, and tags the light so the renderer can pick it up.

---
## Direction Convention

Transform forward still means local `+Z`, but non-point lights emit along local `-Z` transformed into world space. Use `getLightEmissionDirection(entityId:)` when you need the semantic emission/travel direction instead of deriving signs from `getForwardAxisVector(entityId:)` directly.

Directional shader uniforms use the opposite vector because the BRDF expects the vector from the shaded point toward the light source.

Area-light shader uniforms keep a separate `forward` value for the LTC rectangle polygon/front normal used to choose winding. Use `getLightEmissionDirection(entityId:)` for editor handles and authored light travel direction; do not treat `AreaLight.forward` as the semantic travel vector.

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

