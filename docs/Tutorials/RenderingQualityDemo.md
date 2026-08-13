# Rendering Quality Demo

The Rendering Quality Demo shows how to change renderer output at runtime. It
loads a small exported scene, then exposes controls for anti-aliasing, render
debug views, PostFX presets, color grading, SSAO, bloom, vignette, depth of
field, and chromatic aberration.

Run it from the repository root:

```bash
swift run RenderingQualityDemo
```

## Source Files

| File | Role |
| --- | --- |
| `Sources/Demos/RenderingQualityDemo/AppDelegate.swift` | Builds the SwiftUI controls for quality settings. |
| `Sources/Demos/RenderingQualityDemo/GameScene.swift` | Loads the scene and applies rendering/PostFX API changes. |
| `Sources/Demos/DemoUtils/DemoUtils.swift` | Provides shared resource, camera, light, and input helpers. |

## What This Demo Teaches

The main API lesson is that rendering quality is controlled through two facade
functions:

```swift
setRendering(...)
setPostFX(...)
```

Use `setRendering(...)` for renderer-level modes such as anti-aliasing,
environment lighting, and debug views. Use `setPostFX(...)` for image-space
effects such as color grading, SSAO, bloom, vignette, and depth of field.

## Engine Configuration

The demo points the engine at the test asset directory and enables the runtime
features it needs:

```swift
gameMode = true
setSceneReady(false)
setEngine(.assetBasePath(demoResourcesURL()))
setRendering(.environment(.ibl(true)))
setRendering(.environment(.visible(false)))
InputSystem.shared.registerMouseEvents()
```

`setEngine(.assetBasePath(...))` tells the engine where to resolve the `.untold`
models used by the demo. `setSceneReady(false)` prevents input-dependent logic
from running while the assets are still loading.

## Loading The Scene

The demo loads three always-resident `.untold` assets:

```swift
let entity = createEntity()
setEntityName(entityId: entity, name: name)
setEntityMeshAsync(entityId: entity, filename: name, withExtension: "untold") { success in
    completion(success ? entity : nil, success)
}
```

After each mesh loads, the demo applies transforms:

```swift
rotateTo(entityId: stadium, angle: -90.0, axis: simd_float3(1.0, 0.0, 0.0))
translateTo(entityId: player, position: simd_float3(-1.1, 0.0, 0.4))
scaleTo(entityId: ball, scale: simd_float3(repeating: 0.75))
```

This keeps rendering-quality controls separate from asset loading. Once the
scene is ready, the same `setRendering(...)` and `setPostFX(...)` calls can be
changed at any time.

## Anti-Aliasing

Anti-aliasing is a renderer setting:

```swift
func setAntiAliasing(_ mode: AntiAliasingMode) {
    setRendering(.antiAliasing(mode))
}
```

The demo switches between modes such as:

```swift
setRendering(.antiAliasing(.fxaa))
setRendering(.antiAliasing(.smaa))
setRendering(.antiAliasing(.none))
```

This is not a PostFX call because anti-aliasing changes how the render graph
resolves the final image.

## Debug Views

The render debug output is also a renderer setting:

```swift
func setDebugView(_ mode: RenderDebugViewMode) {
    if mode == .ssaoBlurred {
        setPostFX(.ssao(.enabled(true)))
    }
    setRendering(.debugView(mode))
}
```

Debug views are useful when tuning quality. For example, SSAO debug output is
only meaningful when SSAO is enabled, so the demo enables it before selecting
`.ssaoBlurred`.

Return to normal rendering with:

```swift
setRendering(.debugView(.lit))
```

## Looks And Presets

The demo defines three curated looks. The neutral look resets to a simple base
state:

```swift
setRendering(.postProcessing(.enabled))
setRendering(.debugView(.lit))
setRendering(.antiAliasing(.fxaa))
setPostFX(.preset(.neutral))
setPostFX(.bloomThreshold(.enabled(false)))
setPostFX(.bloomComposite(.enabled(false)))
setPostFX(.vignette(.enabled(false)))
setPostFX(.chromaticAberration(.enabled(false)))
setPostFX(.depthOfField(.enabled(false)))
```

The cinematic and inspection looks use the same API with different values:

```swift
setPostFX(.preset(.cinematic))
setPostFX(.bloomThreshold(.enabled(true)))
setPostFX(.bloomComposite(.enabled(true)))
setPostFX(.vignette(.enabled(true)))
```

```swift
setPostFX(.preset(.archviz))
setPostFX(.ssao(.enabled(true)))
setPostFX(.ssao(.quality(.high)))
```

Presets are a good starting point. Individual effect calls can then override
specific values.

## Fine-Grained PostFX Controls

Each control in the UI maps to a small method that writes directly to the engine
settings.

Color grading:

```swift
setPostFX(.colorGrading(.enabled(enabled)))
setPostFX(.colorGrading(.exposure(exposure)))
setPostFX(.colorGrading(.brightness(brightness)))
setPostFX(.colorGrading(.contrast(contrast)))
setPostFX(.colorGrading(.saturation(saturation)))
setPostFX(.colorGrading(.temperature(temperature)))
setPostFX(.colorGrading(.tint(tint)))
```

SSAO:

```swift
setPostFX(.ssao(.enabled(enabled)))
setPostFX(.ssao(.quality(quality)))
setPostFX(.ssao(.radius(radius)))
setPostFX(.ssao(.bias(bias)))
setPostFX(.ssao(.intensity(intensity)))
```

Bloom:

```swift
setPostFX(.bloomThreshold(.enabled(enabled)))
setPostFX(.bloomThreshold(.threshold(threshold)))
setPostFX(.bloomThreshold(.intensity(thresholdIntensity)))
setPostFX(.bloomComposite(.enabled(enabled)))
setPostFX(.bloomComposite(.intensity(compositeIntensity)))
```

The pattern is consistent: each effect has an `.enabled(...)` case and separate
cases for its tunable parameters.

## What To Change First

Try these changes in `Sources/Demos/RenderingQualityDemo/GameScene.swift`:

| Goal | API To Change |
| --- | --- |
| Start in cinematic mode | Call `applyCinematicLook()` at the end of `init()`. |
| Prefer sharper AA | Change `.antiAliasing(.fxaa)` to `.antiAliasing(.smaa)`. |
| Inspect SSAO | Call `setRendering(.debugView(.ssaoBlurred))` after enabling SSAO. |
| Make bloom stronger | Increase `.bloomComposite(.intensity(...))`. |
| Disable all extra effects | Use `setPostFX(.preset(.neutral))` and disable effect-specific passes. |

## Related Documentation

- [Post Effects](../API/UsingPostFX.md)
- [Rendering System](../API/UsingRenderingSystem.md)
- [Materials](../API/UsingMaterials.md)
- [Color Management](../API/UsingColorManagement.md)

