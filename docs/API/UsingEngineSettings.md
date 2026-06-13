# Engine Settings API

The Untold Engine uses a consistent style for its API:

```swift
setDomain(.property(value))
setDomain(.group(.property(value)))
```

This keeps user-facing setup code predictable and avoids requiring developers to remember which singleton or global variable owns each value.

Existing direct APIs such as `LODConfig.shared`, `SSAOParams.shared`, `antiAliasingMode`, and `assetBasePath` are still available for compatibility and advanced tuning.


## Rendering

```swift
setRendering(.antiAliasing(.fxaa))
setRendering(.antiAliasing(.smaa))
setRendering(.antiAliasing(.msaa))
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

## Geometry Streaming

```swift
setGeometryStreaming(.enabled(true))
setGeometryStreaming(.tileConcurrency(2))
setGeometryStreaming(.meshConcurrency(3))
setGeometryStreaming(.lodConcurrency(4))
setGeometryStreaming(.hlodConcurrency(4))
setGeometryStreaming(.queryRadius(500.0))
setGeometryStreaming(.frustumGate(.enabled(meshPadding: 5.0, tilePadding: 20.0)))
setGeometryStreaming(.velocityLookAhead(time: 0.5, minSpeed: 1.5))
setGeometryStreaming(.candidateSorting(importance: true, occlusion: true))
setGeometryStreaming(.minimumParsedTileResidentSeconds(8.0))
setGeometryStreaming(.timeouts(tileParse: 60.0, meshLoad: 60.0))
```

Keep one-shot streaming actions as commands:

```swift
GeometryStreamingSystem.shared.forceUnloadAllParsedTiles()
```

## Static Batching

```swift
setBatching(.enabled(true))
setBatching(.cellSize(32.0))
setBatching(.maxDirtyCellsPerTick(8))
setBatching(.visibilityGatedBuild(true))
setBatching(.backgroundArtifactBuild(true))
setBatching(.runtimeTuning(.visionOSBalanced))
```

Entity tagging and rebuild commands remain explicit:

```swift
setEntityStaticBatchComponent(entityId: entity)
generateBatches()
clearSceneBatches()
```

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


## Spatial Debug

```swift
setSpatialDebug(.octreeLeafBounds(.enabled(
    maxLeafNodeCount: 0,
    occupiedOnly: true,
    colorMode: .culling
)))
setSpatialDebug(.tileBounds(enabled: true, maxTileNodeCount: 500))
setSpatialDebug(.staticBatchCellBounds(enabled: true, maxCellCount: 2000, colorMode: .lod))
setSpatialDebug(.lodLevels(true))
setSpatialDebug(.textureStreamingTiers(true))
setSpatialDebug(.disabled)
```

## Logger

```swift
setLogger(.level(.debug))
setLogger(.category(.tileStreaming, true))
setLogger(.categories([.streamingHeartbeat, .oocTiming], true))
setLogger(.resetCategories)
```

Logging itself stays message-oriented:

```swift
Logger.log(message: "Scene loaded", category: LogCategory.general.rawValue)
```

## Camera

```swift
let camera = findGameCamera()
setCamera(.active(camera))
setCamera(.defaultFOV(70.0))
setCamera(.clipPlanes(near: 0.1, far: 1000.0))
```

## Style Rule

For Contributors, when adding new public settings, prefer one of these forms:

```swift
setLOD(.newProperty(value))
setRendering(.newProperty(value))
setPostFX(.effect(.newProperty(value)))
setEngine(.newProperty(value))
setGeometryStreaming(.newProperty(value))
setBatching(.newProperty(value))
setSpatialDebug(.newProperty(value))
setLogger(.newProperty(value))
setCamera(.newProperty(value))
setSceneChannel(.contextGeometry, .renderMode(.wireframe))
```

Avoid adding new public examples that require direct mutation of shared singletons unless the setting is intentionally advanced/internal.
