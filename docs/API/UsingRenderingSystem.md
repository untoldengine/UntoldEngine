# Rendering System

The rendering system displays your entities through Metal. It supports runtime `.untold` assets, PBR materials, tile-based deferred lighting, screen-space ambient occlusion, anti-aliasing, scene-channel render modes, light portals, XR lighting, and debug views.

## How to Enable the Rendering System

### Step 1: Create an Entity

Start by creating an entity that represents your 3D object.

```swift
let entity = createEntity()
```
---

### Step 2: Load A Mesh

To display a model, load its `.untold` runtime asset and link it to the entity. For normal app and game code, use `setEntityMeshAsync`:

```swift
setEntityMeshAsync(entityId: entity, filename: "robot", withExtension: "untold") { success in
    guard success else { return }
    translateTo(entityId: entity, position: simd_float3(0.0, 0.0, -2.0))
}
```

Parameters:

- `entityId`: The ID of the entity created earlier.
- `filename`: The name of the `.untold` file without the extension.
- `withExtension`: The file extension, typically `"untold"` for runtime assets.
- `completion`: Called when the mesh has been loaded and registered.

`setEntityMeshAsync` registers the render and transform data needed by the renderer. If the asset includes PBR textures, the renderer uses the material maps automatically.

For tooling, tests, or cases that require immediate GPU residency, `setEntityMesh` is still available:

```swift
setEntityMesh(entityId: entity, filename: "robot", withExtension: "untold")
```

---

## Scene-Authored Data

`setEntityMesh` and `setEntityMeshAsync` load geometry and materials. Scene-authored lights, cameras, and baked color grading are loaded separately:

```swift
loadSceneAuthored(filename: "office", withExtension: "untold") { success in
    // Scene-authored lights/cameras and any baked color LUT are registered.
}
```

For streamed tile manifests:

```swift
loadSceneAuthored(url: manifestURL) { success in
    // Scene-authored data from the manifest is registered.
}
```

See [Registration System](UsingRegistrationSystem.md) and [Color Management](UsingColorManagement.md) for the full scene-authored workflow.

## Lighting

Renderable assets need lighting unless their material is emissive or the scene is using a specialized debug view. The most common setup is a directional light:

```swift
let sun = createEntity()
createDirLight(entityId: sun)
setLight(entityId: sun, .intensity(1.4))
setLight(entityId: sun, .color(simd_float3(1.0, 0.95, 0.85)))
```

See [Lighting System](UsingLightingSystem.md) and [Light Portals](UsingLightPortals.md) for the full lighting API.

## Common Issues and Fixes

#### Issue: My Model Isn’t Visible!

- Cause: The scene lacks a light source.
- Solution: Add a directional or point light as shown above. Lighting is required to render objects visibly.

#### Issue: Model Appears Flat or Dull

- Cause: PBR textures are missing or not linked properly.
- Solution: Ensure the `.untold` asset references the correct PBR textures, and verify their paths during the loading process.

#### Debugging Tip

- Log the addition of lights and entities to verify the scene setup.
- Ensure the position of the point light is within the visible range of the camera and the objects it is meant to illuminate.

---

### Tips and Best Practices

- Combine Light Types: Use directional lights for overall scene lighting and point lights for localized effects.
- Use PBR Materials: Provide high-quality PBR textures for realistic rendering.
- Position Lights Intelligently: Place point lights strategically to highlight key areas without excessive overlap.

---

## Anti-Aliasing

Set the anti-aliasing mode globally before the first frame (or at any point to change it at runtime):

```swift
setRendering(.antiAliasing(.fxaa))   // Fast Approximate Anti-Aliasing (default)
setRendering(.antiAliasing(.smaa))   // Subpixel Morphological Anti-Aliasing
setRendering(.antiAliasing(.none))   // Disabled
```

SMAA produces sharper results than FXAA and handles diagonal/corner patterns, at roughly 3× the GPU cost of FXAA. For most scenes `.fxaa` is a good default. See [UsingPostFX](UsingPostFX.md) for debug views that let you inspect the intermediate AA passes.

---

## Deferred Lighting and SSAO

Opaque geometry uses a tile-based deferred rendering (TBDR) path. The model pass writes G-Buffer data into memoryless tile attachments, then the lighting shader reads those attachments through framebuffer fetch inside the same render encoder. This keeps the high-bandwidth G-Buffer data on the GPU tile instead of round-tripping it through full-screen textures.

SSAO is still available through `setPostFX(.ssao(...))` and PostFX presets, but the current implementation is **depth-only**. It samples the stored opaque depth buffer and applies the blurred occlusion during pre-composite. It no longer requires the normal or position G-Buffer textures to be stored in memory.

```swift
setPostFX(.ssao(.enabled(true)))
setPostFX(.ssao(.radius(0.8)))
setPostFX(.ssao(.bias(0.025)))
setPostFX(.ssao(.intensity(0.75)))
```

Use `.ssaoBlurred` in the debug view to inspect the final blurred occlusion texture.

---

## Debug View Modes

The engine can visualize individual G-Buffer layers and anti-aliasing internals in place of the final lit image:

```swift
setRendering(.debugView(.lit))            // Normal output (default)
setRendering(.debugView(.albedo))         // G-Buffer base color
setRendering(.debugView(.normal))         // G-Buffer surface normals
setRendering(.debugView(.position))       // G-Buffer world position
setRendering(.debugView(.depth))          // Linearized depth buffer (grayscale)
setRendering(.debugView(.ssaoBlurred))    // SSAO occlusion result
setRendering(.debugView(.fxaaEdgeDebug))  // FXAA luma-gradient edge map
setRendering(.debugView(.smaaEdges))      // SMAA edge detection output
setRendering(.debugView(.smaaBlend))      // SMAA blend-weight texture
setRendering(.debugView(.smaaDifference)) // Original vs. SMAA-resolved difference
```

Restore normal rendering with `setRendering(.debugView(.lit))`.

For the broader settings style, see [Engine Settings API](UsingEngineAPI.md).

For optional renderer features that add their own graph passes or resources, see [Rendering Extensions](UsingRenderingExtensions.md).

---
