# Using Post-Effects (PostFX) in Untold Engine

The engine provides a post-processing system through the `PostFX` namespace. You can enable and configure individual effects, or apply a full **preset** that sets a curated combination of color grading and SSAO values in a single call.

---

## Applying a Preset

The simplest way to set up post-effects is to apply one of the built-in presets:

```swift
setPostFX(.preset(.cinematic))
```

That single call configures color grading and SSAO together. No scene wiring or callback setup is needed — it works from anywhere in your game code.

### Built-in Presets

| Preset | Description |
|---|---|
| `.neutral` | All effects disabled, default values restored |
| `.cinematic` | Slightly underexposed, desaturated, strong SSAO — moody interior feel |
| `.highContrast` | Boosted exposure and saturation, punchy SSAO — vivid outdoor scenes |
| `.softAO` | Subtle color grading, wide-radius soft ambient occlusion |
| `.archviz` | Bright and airy, clean slightly warm whites, precise SSAO for edge detail — architectural visualization |

### Switching Presets at Runtime

Presets can be swapped at any point during gameplay — for example when transitioning between areas:

```swift
// Entering a dark dungeon
setPostFX(.preset(.cinematic))

// Entering a bright outdoor area
setPostFX(.preset(.highContrast))

// Reset everything to defaults
setPostFX(.preset(.neutral))
```

---

## Custom Presets

If the built-in presets do not fit your scene, create a `PostFXPreset` directly and apply it:

```swift
let sunset = PostFXPreset(
    name: "Sunset",
    colorGrading: true,
    exposure: 0.1,
    saturation: 1.3,
    temperature: 0.4
)

setPostFX(.preset(sunset))
```

All parameters have defaults (matching `.neutral`), so you only need to specify the values you want to change.

The older `PostFX.apply(...)` call remains supported. New code should prefer `setPostFX(.preset(...))` so settings use the same facade style as LOD, rendering, and engine globals.

### PostFXPreset Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `name` | `String` | — | Identifier for the preset |
| `colorGrading` | `Bool` | `false` | Enables color grading pass |
| `exposure` | `Float` | `0.0` | EV adjustment (-2.0 to 2.0) |
| `brightness` | `Float` | `0.0` | Additive brightness (-1.0 to 1.0) |
| `contrast` | `Float` | `1.0` | Contrast multiplier (0.5 to 2.0) |
| `saturation` | `Float` | `1.0` | Saturation multiplier (0.0 to 2.0) |
| `temperature` | `Float` | `0.0` | Color temperature (-1.0 cool to +1.0 warm) |
| `tint` | `Float` | `0.0` | Green/magenta tint (-1.0 to 1.0) |
| `ssao` | `Bool` | `false` | Enables screen-space ambient occlusion |
| `ssaoRadius` | `Float` | `0.5` | Sample radius in world units (0.1 to 2.0) |
| `ssaoBias` | `Float` | `0.025` | Self-occlusion bias (0.01 to 0.1) |
| `ssaoIntensity` | `Float` | `0.0` | Final SSAO multiplier (0.5 to 2.0) |

---

## Anti-Aliasing

Anti-aliasing is configured through the rendering settings facade, not through the `PostFX` namespace:

```swift
setRendering(.antiAliasing(.fxaa))   // Fast Approximate Anti-Aliasing (default)
setRendering(.antiAliasing(.smaa))   // Subpixel Morphological Anti-Aliasing (3-pass)
setRendering(.antiAliasing(.none))   // No anti-aliasing
```

| Mode | Description |
|---|---|
| `.fxaa` | Single-pass screen-space filter. Fast, slightly softens fine detail. |
| `.smaa` | Three-pass chain (edge detection → blend weights → neighborhood blend). Sharper than FXAA, handles diagonal and corner patterns. Costs ~3× the GPU time of FXAA. |
| `.none` | Anti-aliasing skipped entirely. The output transform reads directly from the look pass. |

SMAA also exposes intermediate debug views through `setRendering(.debugView(...))`:

```swift
setRendering(.debugView(.smaaEdges))      // Show edge detection result
setRendering(.debugView(.smaaBlend))      // Show blend-weight texture
setRendering(.debugView(.smaaDifference)) // Show original vs. resolved difference
setRendering(.debugView(.fxaaEdgeDebug))  // Show FXAA luma-gradient edge map
setRendering(.debugView(.lit))            // Normal rendering (default)
```

---

## Enabling Individual Effects

For fine-grained control outside of presets, you can enable or disable individual effects:

```swift
setPostFX(.colorGrading(.enabled(true)))
setPostFX(.vignette(.enabled(true)))
setPostFX(.chromaticAberration(.enabled(false)))
```

And read their current state:

```swift
let isActive = PostFX.isEnabled(.bloomThreshold)
```

### Available Effects

| Effect | Description |
|---|---|
| `.colorGrading` | Exposure, brightness, contrast, saturation, temperature, tint |
| `.colorLUT` | Toggle only — see below |
| `.colorGradeLUT` | Toggle only — see below |
| `.tonemapOperator` | Selects the native tonemap operator (`.aces` default, or `.agx`) — see below |
| `.colorCorrection` | Lift/gamma/gain per-channel color correction |
| `.bloomThreshold` | Bright-pass filter that feeds the bloom blur chain |
| `.bloomComposite` | Bloom blend pass |
| `.vignette` | Screen-edge darkening |
| `.chromaticAberration` | RGB channel fringing |
| `.depthOfField` | Vogel-disc focus blur (16 samples) |

> **`.colorLUT` is legacy and asset-derived, not user-authored.** It toggles
> a whole-transform LUT baked by the now-retired `--bake-color-management`
> exporter flag. Only assets exported before that flag was removed carry
> one; it's loaded via an explicit `loadSceneAuthored(...)` call (see
> [Using the Registration
> System](UsingRegistrationSystem.md#loading-scene-authored-data)), not by a
> normal mesh import. `setPostFX(.colorLUT(.enabled(false)))` is a no-op if
> no such LUT was loaded.

> **`.colorGradeLUT` wraps a standard, externally-authored `.cube` 3D LUT**
> staged as-is (no conversion — see `--color-grade-lut`), applied as a
> creative grade *on top of* whichever tonemap ran (the native operator, or
> a legacy `.colorLUT` bake), not in place of it. Both can be active at
> once. It can be asset-derived (loaded via `loadSceneAuthored(...)`) or
> set directly with `setColorGradeLUT(filename:withExtension:)`, with no
> scene export involved. `setPostFX(.colorGradeLUT(.enabled(false)))` is a
> no-op if no `.cube` has been loaded either way.

> **`.tonemapOperator` is a plain runtime setting, not asset-derived** —
> unlike the two LUT toggles above, this always takes effect (subject to
> `.colorLUT` overriding it when a whole-transform bake is loaded and
> enabled). `setPostFX(.tonemapOperator(.agx))` / `.aces` switches which
> built-in operator runs. See [Using Color Management](UsingColorManagement.md#native-tonemap-operator).

> **SSAO is not a `PostFXEffect`** — it has its own enable API:
> ```swift
> setPostFX(.ssao(.enabled(true)))
> ```
> SSAO is also configured through `PostFXPreset` when you call `setPostFX(.preset(preset))`.

The current SSAO renderer is depth-only. It samples the stored opaque depth buffer, runs the blur chain internally, and applies the result during pre-composite. This keeps SSAO compatible with the engine's tile-based deferred renderer without forcing normal or position G-Buffer attachments to be stored in memory.

---

## Adjusting Individual Effect Parameters

Each effect exposes its parameters through a shared singleton. Import `UntoldEngine` and write directly:

```swift
// Color grading
setPostFX(.colorGrading(.exposure(-0.2)))
setPostFX(.colorGrading(.contrast(1.15)))
setPostFX(.colorGrading(.saturation(0.9)))
setPostFX(.colorGrading(.temperature(-0.1)))

// Bloom
setPostFX(.bloomThreshold(.threshold(0.6)))
setPostFX(.bloomThreshold(.intensity(0.8)))
setPostFX(.bloomThreshold(.enabled(true)))

// Vignette
setPostFX(.vignette(.intensity(0.5)))
setPostFX(.vignette(.radius(0.8)))
setPostFX(.vignette(.enabled(true)))

// SSAO
setPostFX(.ssao(.radius(0.8)))
setPostFX(.ssao(.intensity(0.75)))
setPostFX(.ssao(.enabled(true)))
setPostFX(.ssao(.quality(.high))) // .fast (8 samples), .balanced (16), .high (32)
```

Direct singleton access remains available for compatibility and advanced tooling. Prefer the `setPostFX(...)` facade in user-facing examples.

For the broader settings style, see [Engine Settings API](UsingEngineAPI.md).
