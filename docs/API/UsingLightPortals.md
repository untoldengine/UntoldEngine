# Light Portals

Light portals let selected scene-channel geometry act as a proxy source for real-world window light. This is intended for spatial twin scenes where windows, doors, or openings should let ambient real-world light appear to enter the virtual model.

The feature uses the existing area-light shader path. Each active portal surface becomes a temporary two-sided area light derived from that entity's transform and local bounds. The portal plane is inferred from the two largest local bounding-box axes, so XY, XZ, and YZ window meshes can all be used as portal surfaces. The renderer does not create persistent light entities.

## Basic Setup

Define a project-specific channel for windows:

```swift
extension SceneChannel {
    static let windowGeometry = SceneChannel.userCustom(index: 1)
}
```

Assign entities to the channel directly:

```swift
setEntitySceneChannels(entityId: windowEntity, channels: .windowGeometry)
```

Or map exported names by prefix:

```swift
registerSceneChannelPrefix("WIN_", channels: .windowGeometry)
```

Enable the channel as a light portal:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 1.0,
        range: 6.0,
        useRealWorldTint: true,
        maxActivePortals: 8,
        activationDistance: 15.0
    ))
)
```

Disable it again:

```swift
setSceneChannel(.windowGeometry, .lightPortal(.disabled))
```

## Parameters

| Parameter | Meaning |
|---|---|
| `intensity` | Base area-light intensity for each portal. Non-finite values fall back to `1.0`; negative values clamp to `0.0`. |
| `range` | Maximum portal area-light influence distance in scene units, measured from the closest point on the portal rectangle. Portal contribution fades smoothly over the last 25% of the range. |
| `useRealWorldTint` | When real-world XR lighting is active and valid, scales portal intensity by the current XR probe intensity and real-world contribution factor. If XR lighting is unavailable while the runtime mode requests real-world lighting, the portal emits at `0.0` instead of using the configured base intensity. |
| `maxActivePortals` | Maximum active portal proxy lights for the channel. Nearby portals are selected first within each portal-enabled channel. |
| `activationDistance` | Maximum camera distance from the portal rectangle for a portal to become active. |

If an entity belongs to multiple portal-enabled channels, the engine combines the channel settings using the most permissive intensity, range, and activation distance. `useRealWorldTint` is enabled if any channel requests it. Active portal limits are enforced per portal-enabled channel.

## Real-World Tint

`useRealWorldTint: true` applies the XR probe's normalized intensity scale and the engine's real-world lighting contribution multiplier:

```text
portal intensity = portal intensity * xr intensity scale * real-world contribution
```

If no valid XR probe is available while XR real-world lighting is enabled, real-world-tinted portals emit no light. When XR lighting is valid, changing `setRendering(.environment(.realWorldLightingContribution(...)))` affects portal strength immediately.

Light portals do not enable XR lighting by themselves. Configure XR real-world probe lighting separately with `setRendering(.environment(.lightingMode(.realWorldEstimate)))`. See [XR Lighting](UsingXRLighting.md) for probe setup, provider lifecycle, diagnostics, and passthrough behavior.

## Diagnostics

Discovery diagnostics report which scene entities are eligible portal surfaces:

```swift
let candidates = discoverSceneLightPortalCandidates()
let discovery = getLightPortalDiscoveryDiagnostics()
print(candidates)
print(discovery)
```

Resolution diagnostics report which portals become active proxy lights:

```swift
let proxies = resolveSceneLightPortalProxyLightsForActiveCamera()
let resolution = getLightPortalResolutionDiagnostics()
let performance = getLightPortalPerformanceDiagnostics()
let render = getLightPortalRenderDiagnostics()
print(proxies)
print(resolution)
print(performance)
print(render)
```

Important fields:

| Field | Meaning |
|---|---|
| `scannedRenderableEntityCount` | Renderable entities scanned for portal eligibility. |
| `candidateCount` | Renderable, visible entities on portal-enabled channels. |
| `skippedHiddenCount` | Entities skipped because their scene-channel render mode is hidden. |
| `skippedInvisibleRenderComponentCount` | Entities skipped because their render component is invisible. |
| `skippedDisabledPortalCount` | Renderable entities whose channels are not portal-enabled. |
| `skippedInvalidGeometryCount` | Portal-channel entities skipped because their local bounds are non-finite, too small, or not thin enough to infer a portal plane. |
| `discoveredCandidateCount` | Portal candidates considered for proxy-light resolution. |
| `activePortalCount` | Portal proxy lights emitted after distance filtering and active-count capping. |
| `skippedByActivationDistanceCount` | Candidates outside `activationDistance`. |
| `maxActivePortals` | Active portal cap used for the current resolved list. |
| `lastDiscoveryDurationMs` | Time spent scanning renderable entities and building portal candidates during the latest discovery pass. |
| `lastResolutionDurationMs` | Time spent distance-filtering, sorting, and selecting active portal proxy lights during the latest resolution pass. |
| `lastScannedRenderableEntityCount` | Renderable entity count from the latest discovery pass, useful for spotting broad scans in large scenes. |
| `lastResolvedProxyLightCount` | Active proxy-light count from the latest resolution pass. |
| `environmentIntensityScale` | Final XR/environment multiplier used for real-world-tinted portal proxy lights. |
| `xrIntensityScale` | XR probe intensity scale before the user contribution multiplier. |
| `environmentTintColor` | RGB tint applied to real-world-tinted portal proxy lights. |
| `realWorldLightingContribution` | User contribution multiplier from the rendering settings API. |
| `maxEffectivePortalIntensity` | Brightest portal intensity emitted into the area-light buffer for the latest frame. |

## Performance

The feature is designed to be bounded:

- When no scene channel has light portals enabled, the renderer takes a fast path and skips portal discovery entirely.
- When at least one portal channel is enabled, discovery scans renderable entities with transform and render components.
- Resolution filters by distance to the portal rectangle and sorts candidates by nearest first.
- Portal discovery and resolution are cached per render frame and reused by the engine's render passes.
- Only `maxActivePortals` are emitted as proxy area lights.
- Authored area lights keep priority; portal lights only fill remaining `maxAreaLights` capacity.
- Portal lights fade down near their own source plane to avoid making the window frame itself look like an emissive object.

For large spatial twins, keep the portal channel narrow. Assign only actual window/opening surfaces to the portal channel, not full walls or entire room shells.

### Collecting Performance Data

Light portal diagnostics follow the same category-log pattern described in [Profiler](UsingProfiler.md). Enable the `.lightPortal` category once, and the engine logs a throttled diagnostics summary automatically from the frame monitor path. No code is needed inside your app or game `update()` function.

```swift
setLogger(.category(.lightPortal, true))
// Reproduce the issue. The engine logs light portal diagnostics about once per second.
setLogger(.category(.lightPortal, false))
```

The automatic log emits the latest discovery, resolution, performance, and render snapshots. The snapshots are updated by the normal portal discovery/resolution/render paths; the one-second interval only controls log emission.

For a one-shot snapshot:

```swift
setLogger(.category(.lightPortal, true))
LightPortalSystem.shared.logDiagnosticsNow()
setLogger(.category(.lightPortal, false))
```

For scale checks, focus on:

| Field | Why it matters |
|---|---|
| `lastScannedRenderableEntityCount` | How broad the portal discovery scan is. |
| `lastDiscoveryDurationMs` | CPU time spent finding portal candidates. |
| `lastResolutionDurationMs` | CPU time spent selecting active proxy lights. |
| `activePortalCount` | Number of portal candidates selected after distance and cap filtering. |
| `portalAreaLightCount` | Number of portal proxy lights uploaded into the area-light path. |

Recommended starting values:

```swift
setSceneChannel(
    .windowGeometry,
    .lightPortal(.enabled(
        intensity: 0.5,
        range: 4.0,
        useRealWorldTint: true,
        maxActivePortals: 4,
        activationDistance: 10.0
    ))
)
```

Increase `maxActivePortals` only if the visual benefit is clear on device.

## Limitations

Light portals are an approximation. They do not ray trace sunlight through openings, clip light to the portal shape, or compute physical bounce lighting. They emit proxy area lights from the selected window surfaces.

Portal brightness follows accepted XR probe updates, not every rendered frame. If the real room lights change, use XR lighting diagnostics to confirm that `acceptedProbeUpdateCount`, `latestProbeTimestamp`, and `latestIntensityScale` changed before judging the visual result.

The feature does not make windows transparent by itself. Use scene-channel render modes separately if a window or wall should be hidden, wireframed, or rendered as a passthrough ghost.

Portal proxy lights do not create persistent ECS light entities, so they are not serialized as scene-authored lights. Configure them through scene channels at runtime.
