# Enabling the Lighting System in Untold Engine

The Lighting System lets you add illumination to your scenes using common real-time light types. Under the hood it wires up the required ECS components, provides an editor-friendly visual handle, and tags the light so the renderer can pick it up.

---
## Direction Convention

Transform forward still means local `+Z`, but non-point lights emit along local `-Z` transformed into world space. Use `getLightEmissionDirection(entityId:)` when you need the semantic emission/travel direction instead of deriving signs from `getForwardAxisVector(entityId:)` directly.

Directional shader uniforms use the opposite vector because the BRDF expects the vector from the shaded point toward the light source.

Area-light shader uniforms keep a separate `forward` value for the LTC rectangle polygon/front normal used to choose winding. Use `getLightEmissionDirection(entityId:)` for editor handles and authored light travel direction; do not treat `AreaLight.forward` as the semantic travel vector.

## Runtime Environment Lighting

Use rendering environment settings to choose how indirect/environment lighting is resolved:

```swift
setRendering(.environment(.lightingMode(.authoredOnly)))
setRendering(.environment(.lightingMode(.staticIBL)))
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(0.75)))
```

`realWorldEstimate` uses Vision Pro environment light probes when an `UntoldEngineXR` instance is active. The XR layer observes the runtime lighting mode, starts or stops the ARKit environment-light provider as needed, and feeds prefiltered probe textures into the normal PBR lighting path.

See [XR Lighting](UsingXRLighting.md) for Vision Pro probe setup and diagnostics. See [Light Portals](UsingLightPortals.md) for proxy area lights emitted from selected window/opening geometry.

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

---

## Configuring Light Properties

Use `setLight(entityId:, _:)` to configure any light after creation. The call shape follows the standard engine pattern — shared properties sit at the top level, and type-specific properties are grouped under a sub-domain:

```swift
setLight(entityId: light, .property(value))               // shared
setLight(entityId: light, .lightType(.property(value)))   // type-specific
```

### Shared properties (all light types)

Color and intensity apply to every light type. Use `.power` for Blender-style radiometric local lights; it is a convenience alias for setting the numeric intensity and switching the light to radiometric units.

```swift
setLight(entityId: light, .color(simd_float3(1.0, 0.85, 0.7)))
setLight(entityId: light, .intensity(2.5))
setLight(entityId: light, .power(300.0)) // watts for point, spot, and area lights
```

`.intensity` preserves the current unit mode. `.power` always enables radiometric units.

### Directional light

The `.directional(.active)` case designates the entity as the scene's active directional light — the one the renderer uses for shadows and directional shading. Only one entity can be active at a time; calling this again on a different entity replaces the previous one.

```swift
let sun = createEntity()
createDirLight(entityId: sun)
rotateTo(entityId: sun, angle: -45.0, axis: simd_float3(1, 0, 0))

setLight(entityId: sun, .color(simd_float3(1.0, 0.95, 0.8)))
setLight(entityId: sun, .intensity(1.2))
setLight(entityId: sun, .directional(.active))
```

Directional shadows use cascaded shadow maps. Runtime softness can be tuned globally:

```swift
setShadowSoftness(ShadowSoftnessSettings(
    enabled: true,
    nearRadiusTexels: 2.0,
    farRadiusTexels: 5.0,
    depthScale: 1.0,
    xrRadiusScale: 1.35
))
```

`nearRadiusTexels` and `farRadiusTexels` control the PCF radius across the shadow distance. `xrRadiusScale` applies only while stereo XR rendering is active, where hard shadow edges are more noticeable.

### Point light

Point lights separate emitter size from influence range. `radius` is the physical source radius used for light regularization and soft-shadow filtering. `range` is the optional influence cutoff; use `0` to disable the authored cutoff. `falloff` and raw attenuation coefficients are legacy artistic controls:

```swift
let bulb = createEntity()
createPointLight(entityId: bulb)
translateTo(entityId: bulb, position: simd_float3(0, 2, 0))

setLight(entityId: bulb, .color(simd_float3(1, 0.6, 0.2)))
setLight(entityId: bulb, .power(300.0))
setLight(entityId: bulb, .point(.range(5.0)))
setLight(entityId: bulb, .point(.radius(0.1)))
setLight(entityId: bulb, .point(.falloff(0.7)))
setLight(entityId: bulb, .point(.attenuation(simd_float3(1, 0.5, 0.1))))
setLight(entityId: bulb, .point(.castsShadow(true)))
```

Point shadows are opt-in. The renderer currently shadows one point light per frame: the first point light with `castsShadow(true)` in the engine's point-light query order. Point shadows use a cube depth map, so they cost six depth renders for the active shadowed point light.

### Spot light

Spot lights add a cone. `coneAngle` is the engine outer half-angle in degrees. Blender's UI displays the full cone angle, so a Blender `45` degree spot corresponds to `.spot(.coneAngle(22.5))`. `radius` is source size, `range` is influence cutoff, and `falloff` softens the inner edge:

```swift
let spot = createEntity()
createSpotLight(entityId: spot)

setLight(entityId: spot, .color(simd_float3(1, 1, 0.9)))
setLight(entityId: spot, .power(600.0))
setLight(entityId: spot, .spot(.range(8.0)))
setLight(entityId: spot, .spot(.radius(0.05)))
setLight(entityId: spot, .spot(.coneAngle(22.5)))
setLight(entityId: spot, .spot(.falloff(0.6)))
setLight(entityId: spot, .spot(.attenuation(simd_float3(1, 0.4, 0.08))))
setLight(entityId: spot, .spot(.castsShadow(true)))
```

Spot shadows are opt-in. The renderer currently shadows one spot light per frame: the first spot light with `castsShadow(true)` in the engine's spot-light query order. The spot light's `range`, when nonzero, defines its lighting cutoff and shadow distance.

### Area light

Area lights derive their bounds from the entity's scale and orientation. `twoSided` controls whether the light emits from both faces of the rectangle, and `range` is the optional influence cutoff:

```swift
let panel = createEntity()
createAreaLight(entityId: panel)
scaleTo(entityId: panel, scale: simd_float3(2.0, 1.0, 1.0))

setLight(entityId: panel, .color(simd_float3(0.9, 0.95, 1.0)))
setLight(entityId: panel, .power(500.0))
setLight(entityId: panel, .area(.range(6.0)))
setLight(entityId: panel, .area(.twoSided(true)))
```

---

## Querying Light Properties

```swift
let color     = getLightColor(entityId: light)
let intensity = getLightIntensity(entityId: light)
let radius    = getLightRadius(entityId: light)
let falloff   = getLightFalloff(entityId: light)
let coneAngle = getLightConeAngle(entityId: light)
```

---

## Light Direction Queries

```swift
// World-space semantic emission/travel direction (away from the light)
let emission = getLightEmissionDirection(entityId: light)

// Local +Z in world space (transform axis, not emission)
let forward = getLightTransformForwardAxis(entityId: light)

// Direction from shaded point toward the light (BRDF input convention)
let shader = getDirectionalLightShaderDirection(entityId: light)
```
