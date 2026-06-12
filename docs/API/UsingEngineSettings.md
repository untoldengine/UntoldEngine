# Engine Settings API

Untold Engine settings should use a consistent style:

```swift
setDomain(.property(value))
setDomain(.group(.property(value)))
```

This keeps user-facing setup code predictable and avoids requiring developers to remember which singleton or global variable owns each value.

Existing direct APIs such as `LODConfig.shared`, `SSAOParams.shared`, `antiAliasingMode`, and `assetBasePath` are still available for compatibility and advanced tuning.

## LOD

```swift
setLOD(.fadeTransitions(.enabled(duration: 0.25)))
setLOD(.fadeTransitions(.disabled))
setLOD(.distanceBias(1.0))
setLOD(.hysteresis(5.0))
setLOD(.updateFrameInterval(4))
setLOD(.minimumCameraDisplacement(0.5))
setLOD(.distanceThresholds([50, 100, 200, 500]))
```

`setLOD(.fadeTransitions(.enabled(duration:)))` replaces the older direct configuration:

```swift
LODConfig.shared.enableFadeTransitions = true
LODConfig.shared.fadeTransitionTime = 0.25
```

## Rendering

```swift
setRendering(.antiAliasing(.fxaa))
setRendering(.antiAliasing(.smaa))
setRendering(.antiAliasing(.none))

setRendering(.debugView(.lit))
setRendering(.debugView(.depth))
setRendering(.debugView(.ssaoBlurred))

setRendering(.postProcessing(.enabled))
setRendering(.postProcessing(.disabled))
```

Wireframe parameters can also be configured through the same domain:

```swift
setRendering(.wireframe(.params(
    color: simd_float4(0.2, 0.85, 1.0, 0.65),
    fadeEnabled: true,
    fadeStart: 8.0,
    fadeEnd: 40.0,
    minimumAlpha: 0.08
)))
```

## PostFX

Use `setPostFX` for individual post-processing and SSAO settings:

```swift
setPostFX(.preset(.cinematic))

setPostFX(.ssao(.enabled(true)))
setPostFX(.ssao(.radius(0.8)))
setPostFX(.ssao(.bias(0.025)))
setPostFX(.ssao(.intensity(0.75)))
setPostFX(.ssao(.quality(.balanced)))

setPostFX(.colorGrading(.enabled(true)))
setPostFX(.colorGrading(.exposure(-0.2)))
setPostFX(.colorGrading(.saturation(0.9)))

setPostFX(.vignette(.enabled(true)))
setPostFX(.vignette(.intensity(0.5)))
setPostFX(.vignette(.radius(0.8)))

setPostFX(.bloomThreshold(.enabled(true)))
setPostFX(.bloomThreshold(.threshold(0.6)))
setPostFX(.bloomThreshold(.intensity(0.8)))
setPostFX(.bloomComposite(.enabled(true)))
setPostFX(.bloomComposite(.intensity(1.0)))

setPostFX(.chromaticAberration(.enabled(true)))
setPostFX(.chromaticAberration(.intensity(0.02)))

setPostFX(.depthOfField(.enabled(true)))
setPostFX(.depthOfField(.focusDistance(4.7)))
setPostFX(.depthOfField(.focusRange(1.5)))
setPostFX(.depthOfField(.maxBlur(10.0)))
```

The nested property shape is intentional: the compiler keeps effect-specific settings grouped with the effect they belong to.

## Engine Globals

```swift
setEngine(.assetBasePath(gameDataURL))
setEngine(.metrics(.enabled))
setEngine(.metrics(.disabled))
```

## Style Rule

When adding new public settings, prefer one of these forms:

```swift
setLOD(.newProperty(value))
setRendering(.newProperty(value))
setPostFX(.effect(.newProperty(value)))
setEngine(.newProperty(value))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

Avoid adding new public examples that require direct mutation of shared singletons unless the setting is intentionally advanced/internal.
