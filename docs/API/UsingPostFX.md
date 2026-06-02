# Using Post-Effects (PostFX) in Untold Engine

The engine provides a post-processing system through the `PostFX` namespace. You can enable and configure individual effects, or apply a full **preset** that sets a curated combination of color grading and SSAO values in a single call.

---

## Applying a Preset

The simplest way to set up post-effects is to apply one of the built-in presets:

```swift
PostFX.apply(.cinematic)
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
PostFX.apply(.cinematic)

// Entering a bright outdoor area
PostFX.apply(.highContrast)

// Reset everything to defaults
PostFX.apply(.neutral)
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

PostFX.apply(sunset)
```

All parameters have defaults (matching `.neutral`), so you only need to specify the values you want to change.

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

Anti-aliasing is configured through the `antiAliasingMode` global, not through the `PostFX` namespace:

```swift
antiAliasingMode = .fxaa   // Fast Approximate Anti-Aliasing (default)
antiAliasingMode = .smaa   // Subpixel Morphological Anti-Aliasing (3-pass)
antiAliasingMode = .none   // No anti-aliasing
```

| Mode | Description |
|---|---|
| `.fxaa` | Single-pass screen-space filter. Fast, slightly softens fine detail. |
| `.smaa` | Three-pass chain (edge detection → blend weights → neighborhood blend). Sharper than FXAA, handles diagonal and corner patterns. Costs ~3× the GPU time of FXAA. |
| `.none` | Anti-aliasing skipped entirely. The output transform reads directly from the look pass. |

SMAA also exposes intermediate debug views via `renderDebugViewMode`:

```swift
renderDebugViewMode = .smaaEdges      // Show edge detection result
renderDebugViewMode = .smaaBlend      // Show blend-weight texture
renderDebugViewMode = .smaaDifference // Show original vs. resolved difference
renderDebugViewMode = .fxaaEdgeDebug  // Show FXAA luma-gradient edge map
renderDebugViewMode = .lit            // Normal rendering (default)
```

---

## Enabling Individual Effects

For fine-grained control outside of presets, you can enable or disable individual effects:

```swift
PostFX.setEnabled(.colorGrading, true)
PostFX.setEnabled(.vignette, true)
PostFX.setEnabled(.chromaticAberration, false)
```

And read their current state:

```swift
let isActive = PostFX.isEnabled(.bloomThreshold)
```

### Available Effects

| Effect | Description |
|---|---|
| `.colorGrading` | Exposure, brightness, contrast, saturation, temperature, tint |
| `.colorCorrection` | Lift/gamma/gain per-channel color correction |
| `.bloomThreshold` | Bright-pass filter that feeds the bloom blur chain |
| `.bloomComposite` | Bloom blend pass |
| `.vignette` | Screen-edge darkening |
| `.chromaticAberration` | RGB channel fringing |
| `.depthOfField` | Vogel-disc focus blur (16 samples) |

> **SSAO is not a `PostFXEffect`** — it has its own enable API:
> ```swift
> SSAO.setEnabled(true)
> // or directly:
> SSAOParams.shared.enabled = true
> ```
> SSAO is also configured through `PostFXPreset` when you call `PostFX.apply(preset)`, but it is not accessible via `PostFX.setEnabled(...)` or `PostFX.isEnabled(...)`.

The current SSAO renderer is depth-only. It samples the stored opaque depth buffer, runs the blur chain internally, and applies the result during pre-composite. This keeps SSAO compatible with the engine's tile-based deferred renderer without forcing normal or position G-Buffer attachments to be stored in memory.

---

## Adjusting Individual Effect Parameters

Each effect exposes its parameters through a shared singleton. Import `UntoldEngine` and write directly:

```swift
// Color grading
ColorGradingParams.shared.exposure    = -0.2
ColorGradingParams.shared.contrast    = 1.15
ColorGradingParams.shared.saturation  = 0.9
ColorGradingParams.shared.temperature = -0.1

// Bloom
BloomThresholdParams.shared.threshold = 0.6
BloomThresholdParams.shared.intensity = 0.8
BloomThresholdParams.shared.enabled   = true

// Vignette
VignetteParams.shared.intensity = 0.5
VignetteParams.shared.radius    = 0.8
VignetteParams.shared.enabled   = true

// SSAO
SSAOParams.shared.radius    = 0.8
SSAOParams.shared.intensity = 0.75
SSAOParams.shared.enabled   = true
```
