---
name: untold-engine-config
description: Use for engine-wide setup and tuning that doesn't require writing a custom extension — the setRendering/setPostFX/setLOD/setBatching/setEngine/setSpatialDebug/setLogger settings-API family, declaring a scene with SceneView/UntoldView/SceneBuilder nodes instead of imperative calls, and the Vision Pro mixed-immersion rendering profile (render path, tonemap, primaries, foveation, real-world lighting) as measured against RealityKit. Triggers on "turn on/off anti-aliasing", "set up post effects", "configure LOD/batching globally", "declare my scene with SwiftUI nodes", "match RealityKit's look on Vision Pro", "what settings does a mixed-immersion space need". Not for writing a custom render pass or per-frame plugin (see untold-render-extensions), per-entity material/color edits (see untold-materials-color), XR immersion-mode/spatial-input application code (see untold-xr-spatial), or performance triage/diagnostics after something is already configured (see untold-performance-diagnostics).
version: 0.1.0
---

# Engine-Wide Configuration in Untold Engine

Untold Engine's settings surface follows one consistent shape across every domain: `setDomain(.property(value))` or `setDomain(.group(.property(value)))`. Learn the shape once and you can guess most calls correctly instead of grepping for each one. Direct singletons (`LODConfig.shared`, `SSAOParams.shared`, `TAAParams.shared`, `antiAliasingMode`, `assetBasePath`) still exist for compatibility/advanced tuning, but prefer the settings-API form for new code.

## 1. Rendering and post effects

```swift
setRendering(.antiAliasing(.fxaa))     // default, cheapest
setRendering(.antiAliasing(.smaa))     // sharper, ~3x FXAA cost
setRendering(.antiAliasing(.msaa))
setRendering(.antiAliasing(.taa))      // temporal: jittered frames + reprojected history
setRendering(.antiAliasing(.msaaTaa))  // 4x MSAA G-buffer + temporal resolve
setRendering(.antiAliasing(.none))

setRendering(.postProcessing(.enabled))
setRendering(.debugView(.lit))         // restore normal output; see UsingRenderingSystem.md for every debug view
setRendering(.maxShadowCastingDistance(2.0))        // tighten CSM range for small-scale (e.g. AR tabletop) scenes
setRendering(.smallObjectCulling(pixels: 2.0))       // 0 draws everything regardless of screen size
setRendering(.occlusionCullingMaxCameraStep(0.5))    // skip the occlusion test after a camera jump/fast flight
setRendering(.foveatedRendering(.disabled))          // diagnostic only — visionOS enables this by default
setRendering(.instancedDraws(.disabled))             // diagnostic only — same-mesh/same-material entities instance by default
```

```swift
setPostFX(.preset(.cinematic))
setPostFX(.ssao(.enabled(true))); setPostFX(.ssao(.radius(0.8))); setPostFX(.ssao(.quality(.balanced)))
setPostFX(.colorGrading(.enabled(true))); setPostFX(.colorGrading(.exposure(-0.2)))
setPostFX(.vignette(.enabled(true)))
setPostFX(.bloomThreshold(.enabled(true))); setPostFX(.bloomComposite(.intensity(1.0)))
setPostFX(.chromaticAberration(.enabled(true)))
setPostFX(.depthOfField(.enabled(true))); setPostFX(.depthOfField(.focusDistance(4.7)))
```

Custom render passes/shaders belong to `untold-render-extensions`, not here — `setRendering(.extensions(...))` registration is covered there.

## 2. Engine globals, LOD, batching, streaming, debug, logging

```swift
setEngine(.assetBasePath(gameDataURL))
setEngine(.metrics(.enabled))
setEngine(.simulationStepping(.fixed))     // default: one 1/60s step per 1/60s accumulated
setEngine(.simulationStepping(.perFrame))  // steps with the display's own cadence instead — use if a physics/extension sim visibly stalls on 90/100Hz displays
```

```swift
setLOD(.fadeTransitions(.enabled(duration: 0.25)))
setLOD(.distanceThresholds([50, 100, 200, 500]))

setBatching(.enabled(true)); setBatching(.cellSize(32.0)); setBatching(.runtimeTuning(.visionOSBalanced))

setGeometryStreaming(.enabled(true)); setGeometryStreaming(.queryRadius(500.0))   // full setup: see untold-geometry-streaming

setSpatialDebug(.tileBounds(enabled: true, maxTileNodeCount: 500))
setSpatialDebug(.disabled)

setLogger(.level(.debug)); setLogger(.category(.tileStreaming, true))
```

Full tuning/triage workflows for LOD/batching/streaming/debug/logging live in `untold-geometry-streaming` and `untold-performance-diagnostics` — this section is just the settings-API shape.

## 3. Camera and lighting (settings-API form)

```swift
setCamera(.active(findGameCamera()))
setCamera(.defaultFOV(70.0))
setCamera(.clipPlanes(near: 0.1, far: 1000.0))

setLight(entityId: light, .color(simd_float3(1.0, 0.85, 0.7)))
setLight(entityId: light, .intensity(2.5))
setLight(entityId: light, .point(.range(5.0)))
setLight(entityId: light, .spot(.coneAngle(22.5)))   // engine half-angle
```

Entity/light creation (`createDirLight`, etc.) and day-to-day camera/light work belong to `untold-entity-scene` — this is only the global-settings shape for the same domains.

## 4. Declaring a scene: SceneView vs. UntoldView/SceneBuilder

Two SwiftUI entry points host the same `UntoldRenderer`:

- **`SceneView`** — imperative. Call engine facade APIs (`createEntity`, `setEntityMeshAsync`, ...) inside `.onInit { }`, which runs once after the renderer (and its Metal device) exists.
- **`UntoldView`** — declarative `SceneBuilder` nodes, for compact SwiftUI-style scene setup. `MeshNode`/`CubeNode`/`SphereNode`/etc. create normal entities under the hood; nesting nodes creates normal `setParent` relationships.

```swift
UntoldView {
    CameraNode(name: "Main Camera").lookAt(eye: simd_float3(0, 1.2, 4), target: simd_float3(0, 0.8, 0))
    DirectionalLightNode(name: "Sun").intensity(1.5)
    MeshNode(resource: "robot.untold", name: "Robot")
        .translateTo(x: 0, y: 0, z: -2)
        .roughness(0.45)
}
.onUpdate { event in
    if let drone = findEntity(name: "Drone") {
        rotateBy(entityId: drone, angle: 30.0 * Float(event.deltaTime), axis: simd_float3(0, 1, 0))
    }
}
```

Use `onUpdate` for per-frame logic; keep state in the ECS or a reference type, not SwiftUI `@State` that would rebuild scene content every frame. `UntoldViewOptions` (frame rate, pause, clear color) can change live without recreating the renderer or scene — everything else (anti-aliasing, post effects, LOD, lighting, scene channels) still goes through the settings APIs above, not through the builder.

Pick the builder for compact declarative setup; pick `SceneView` when a demo/app needs explicit control over loading order, registration, or runtime systems.

## 5. Vision Pro mixed-immersion profile (measured against RealityKit)

If a mixed-passthrough Vision Pro app needs to visually match RealityKit's look and cost, this is the measured starting profile (visionOS 26, Oct 2026 measurement) — don't rediscover it per-project:

```swift
setRendering(.renderPath(.forward))                        // visionOS default; matches RealityKit's per-fragment lighting cost
setRendering(.antiAliasing(.msaaTaa))                       // 4 samples
setPostFX(.tonemapOperator(.none))                          // RealityKit applies no curve below white in mixed space
setPostFX(.colorPrimaries(.displayP3))                      // matches RealityKit's P3 primaries
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(1.0)))
// lightingSmoothingTimeConstant ~3s so a new probe estimate fades in, not cuts
setRendering(.occlusionCullingMaxCameraStep(0.5))
```

Turn the sun off in mixed space — the room's probe already supplies the key light; a sun on top doubles it. A **full-immersion** space is different: there's no passthrough to match, so a real tonemap (ACES/AgX) is correct again, real-world lighting contribution stops making sense, and primaries become a stylistic choice rather than a matching requirement.

If a Mac renders remotely and the headset only composites (Compositor Services remote immersive space), presentation values (tonemap, primaries, room light) still follow the headset, but render-quality budget (AA samples, shadow taps, texture budget, LOD distances) is the Mac's to raise — the render path still starts forward unless the app explicitly picks otherwise.

This profile is about matching a specific platform's expected look/cost — for general frame-time/memory problem-solving once something is mis-performing, use `untold-performance-diagnostics` instead. For immersion-mode switching and spatial input itself, use `untold-xr-spatial`.

## 6. Shipping-build asset optimization (pointer, not detail)

ASTC texture baking (`untoldengine texbake`) and LZ4 geometry compression (`--compress-geometry`) reduce runtime memory/file size for shipped builds. These are export/asset-pipeline steps, not engine settings calls — see `untold-asset-pipeline` and `untold-materials-color` for the actual workflow; `docs/API/Optimizations.md` has the full command reference.

Full reference: `docs/API/UsingEngineAPI.md`, `docs/API/UsingSceneBuilder.md`, `docs/API/VisionProRenderingProfile.md`, `docs/API/Optimizations.md`.
