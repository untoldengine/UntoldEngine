# XR Lighting

XR lighting lets a visionOS app shade virtual content with the Vision Pro's real-world environment light estimate. The engine receives environment probe updates from ARKit, prefilters the probe into IBL textures, and uses those textures in the normal PBR lighting path.

This is independent of passthrough visibility. A scene can use real-world lighting in mixed passthrough or while rendering only virtual content.

## Startup Setup

Enable XR lighting when the `UntoldEngineXR` instance is created, before starting the XR render loop:

```swift
if let xr = UntoldEngineXR(layerRenderer: layerRenderer) {
    XRHolder.shared.xr = xr

    xr.setImmersionMode(xrImmersionMode: .mixed)
    xr.setXRLightingMode(.realWorldEstimate)
    xr.setXRLightingContribution(1.0)

    xr.start()
    xr.runLoop()
}
```

`setXRLightingMode(_:)` owns the Vision Pro provider lifecycle. It enables or disables ARKit environment light estimation and restarts the ARKit provider set when needed.

Practical rule:

```swift
// Startup/session setup
xr.setXRLightingMode(.realWorldEstimate)

// Runtime tuning
xr.setXRLightingContribution(0.75)
```

Set the lighting mode during XR startup. Change the contribution factor whenever the app needs to tune the strength of real-world lighting.

## Lighting Modes

```swift
xr.setXRLightingMode(.authoredOnly)
xr.setXRLightingMode(.staticIBL)
xr.setXRLightingMode(.realWorldEstimate)
```

| Mode | Effect |
|---|---|
| `.authoredOnly` | Disables IBL contribution and uses authored lights only. |
| `.staticIBL` | Uses the engine's loaded/static HDR IBL path. |
| `.realWorldEstimate` | Uses Vision Pro environment light probes when available. |

If real-world lighting is enabled but no valid probe is available yet, the renderer falls back to the static IBL path.

## Contribution Factor

Use the contribution factor to tune how strongly the Vision Pro lighting probe affects the scene:

```swift
xr.setXRLightingContribution(0.75)
```

The value is a non-negative multiplier:

| Value | Meaning |
|---|---|
| `0.0` | Real-world IBL contributes no ambient/specular lighting. |
| `0.5` | Half-strength real-world IBL. |
| `1.0` | Default full-strength real-world IBL. |
| `> 1.0` | Boosted real-world IBL. |

Negative values are clamped to `0.0`. Non-finite values reset to `1.0`.

The factor applies immediately to the latest cached probe; the app does not need to wait for ARKit to publish another probe update.

The same multiplier can be set through the rendering settings API:

```swift
setRendering(.environment(.realWorldLightingContribution(0.75)))
```

This only changes the contribution factor. Use `xr.setXRLightingMode(_:)` to enable or disable the Vision Pro provider.

Unlike `setXRLightingMode(_:)`, the contribution factor can be changed at runtime. It does not start, stop, or restart ARKit providers.

## Diagnostics

Use diagnostics while testing on Vision Pro:

```swift
print("XR Lighting:", xr.xrEnvironmentLightingDiagnostics())
```

Important fields:

| Field | Meaning |
|---|---|
| `enabled` | Whether the engine requested XR environment lighting. |
| `providerSupported` | Whether ARKit environment light estimation is supported. |
| `providerRunning` | Whether the ARKit provider is currently running. |
| `latestProbeTimestamp` | Timestamp of the latest accepted probe update. |
| `latestProbeTextureValid` | Whether the latest accepted probe contained a usable texture. |
| `latestCameraScaleReference` | Raw camera exposure reference reported with the latest accepted probe, when available. |
| `latestIntensityScale` | Engine-normalized brightness scale derived from the probe camera scale reference. This is applied before `realWorldLightingContribution`. |
| `latestTintColor` | Normalized RGB tint sampled from the latest accepted environment probe. Light portals use this for warm/cool real-world color. |
| `prefilterInFlight` | Whether the engine is currently converting a probe into runtime IBL textures. |
| `lastPrefilterDurationMs` | GPU command duration for the most recent prefilter pass. |
| `realWorldLightingContribution` | Current real-world lighting contribution multiplier. |
| `acceptedProbeUpdateCount` | Number of probe updates accepted by the engine. |
| `skippedProbeUpdateCount` | Number of probe updates skipped because of throttling or in-flight work. |
| `fallbackReason` | Reason XR lighting is unavailable, if the renderer is falling back. |

Probe updates are not expected every frame. ARKit publishes updates opportunistically as the real-world estimate changes. The engine throttles accepted probe work to avoid unnecessary GPU prefiltering.

When testing room-light changes, watch `acceptedProbeUpdateCount`, `latestProbeTimestamp`, and `latestIntensityScale`. The visual result only changes after the engine accepts and prefilters a new probe update.

## Passthrough

XR lighting and passthrough are separate controls:

```swift
xr.setImmersionMode(xrImmersionMode: .mixed)
xr.setXRLightingMode(.realWorldEstimate)
```

Mixed passthrough controls whether the real camera view is visible. XR lighting controls how virtual content is shaded. They can be used together or independently.

## Light Portals

For spatial twin scenes, selected window geometry can be configured as light portals. A portal emits a bounded proxy area light from the window surface, and can scale its intensity using the current XR lighting estimate:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(useRealWorldTint: true))
)
```

See [Light Portals](UsingLightPortals.md) for setup details, diagnostics, performance notes, and limitations.
