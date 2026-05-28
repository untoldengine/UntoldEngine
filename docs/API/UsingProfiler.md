# Profiler

UntoldEngine profiling has two layers that are meant to be used together:

1. **Structured metrics** (stable numbers for trends and regressions)
2. **Category logs** (on-demand narrative traces for deep debugging)

Use structured metrics as the source of truth, then enable category logs only when you need extra context.

## Quick Start

Enable the profiler at runtime:

```swift
enableEngineMetrics = true
```

Or via environment variable:

```bash
export UNTOLD_METRICS=1
./YourApp
```

Enable periodic frame stats logging:

```swift
setEngineStatsLogging(
    enabled: true,
    profile: .compact,    // or .verbose
    intervalSeconds: 1.0
)
```

Read profiler snapshots programmatically:

```swift
let metrics = EngineProfiler.shared.snapshot()
print("CPU mean: \(metrics.cpuFrame.meanMs) ms")
print("GPU mean: \(metrics.gpuCommandBuffer.meanMs) ms")

let frameStats = getEngineStatsSnapshot()
print("Frame: \(frameStats.frameIndex)")
print("Update: \(frameStats.timing.updateMs) ms")
print("Render: \(frameStats.timing.renderTotalMs) ms")
```

## OOC And Asset Triage Mode

High-volume instrumentation categories are disabled by default:

- `OOCTiming`
- `OOCStatus`
- `AssetLoader`

Enable them when diagnosing OOC/loader behavior:

```swift
// Keep structured profiler metrics on
enableEngineMetrics = true
setEngineStatsLogging(enabled: true, profile: .compact, intervalSeconds: 1.0)

// Add focused trace logs
Logger.enable(category: .oocStatus)   // OutOfCore lifecycle/status
Logger.enable(category: .oocTiming)   // OOC timing detail
Logger.enable(category: .assetLoader) // progressive loader parse/upload
```

Disable after capture:

```swift
Logger.disable(category: .oocTiming)
Logger.disable(category: .oocStatus)
Logger.disable(category: .assetLoader)
```

## Static Batching Triage

When FPS is lower than expected and the `draws` count in the engine stats is high relative to `visible` entities, the static batching system may not be producing as many groups as expected.

Enable the `.batching` log category to get a material-diversity report:

```swift
// One-shot snapshot at any point (e.g. after the scene finishes loading)
Logger.enable(category: .batching)
BatchingSystem.shared.logMaterialDiagnosticsNow()
Logger.disable(category: .batching)
```

Or arm it to fire automatically every 30 seconds during a session:

```swift
Logger.enable(category: .batching)
// engine loop calls logMaterialDiagnosticsIfDue() each frame — no extra code needed
```

### Reading the output

```
[BatchMaterial] staticBatch=916 registered=916 resolved=916 batchable=87%
  | singletons=119 groupable=797 | cellsBlocked=2
  | uniqueMatLOD=80 singletonKeys=119 groupableKeys=132

[BatchMaterial] cell(0,-1,0)  ents=224 uniqueKeys=49 singletons=22 groupable=27 groups=0  ratio=0.45
[BatchMaterial] cell(-1,-1,0) ents=238 uniqueKeys=42 singletons=16 groupable=26 groups=0  ratio=0.38
[BatchMaterial] cell(-2,-1,0) ents=49  uniqueKeys=24 singletons=12 groupable=12 groups=12 ratio=0.50
```

**Scene-level fields:**

| Field | What it tells you |
|-------|-------------------|
| `staticBatch` | How many entities have `StaticBatchComponent`. If this is 0 the asset was not set up for batching. |
| `registered / resolved` | Should match `staticBatch` once all tiles are resident. A large gap means entities are failing eligibility checks (animation, transparency). |
| `batchable` | Percentage of resolved entities that share a material key with a peer. Above 80% is healthy. |
| `cellsBlocked` | Cells rejected by the runtime complexity guard — their entities are rendered individually regardless of material sharing. |
| `uniqueMatLOD` | Distinct (material × LOD) keys globally. A small number (< 200) with high `batchable` is ideal. |

**Per-cell fields:**

| Field | What it tells you |
|-------|-------------------|
| `ents` | Entities registered in the cell. Very high counts (> 150) risk hitting the complexity guard. |
| `uniqueKeys` | Distinct material keys in the cell. Many keys spread across few entities = high diversity. |
| `groups` | Batch groups actually built. `0` with non-zero `groupable` means the cell has not been built yet or was blocked. |
| `ratio` | `singletonKeys / uniqueKeys`. Close to 1.0 means nearly every material is unique to one entity — nothing will batch. |

### Diagnosing common patterns

**`groups=0` on large cells, `cellsBlocked > 0`**  
The complexity guard is rejecting cells with too many vertices. Reduce the batch cell size (default 32 world units) so fewer entities land per cell, or raise `maxRuntimeCellVertices` / `maxRuntimeCellBufferBytes` in the platform tuning profile.

**High `uniqueMatLOD` count, `ratio` near 1.0 per cell**  
Material diversity in the asset: each mesh instance uses a slightly different material, preventing grouping. The fix is asset-side — consolidate materials into shared PBR parameter sets or texture atlases.

**`batchable=0%`, `staticBatch=0`**  
The scene entities were not tagged with `StaticBatchComponent` during export or scene setup. No batching will occur until the component is present.

**`resolved` much lower than `registered`**  
Entities are failing `resolveBatchCandidate`. Common causes: transparent submeshes, skeleton/animation components, or `preserveIdentity` scene channels. Check the entity setup.

## Instruments Workflow

When metrics are enabled, the engine emits signpost scopes:

- `Frame`
- `Update`
- `RenderPrep`
- `Encode`
- `Submit`

To inspect timeline data:

1. Open Instruments
2. Choose **Points of Interest**
3. Filter subsystem to `com.untoldengine.profiling`
4. Run the app with `enableEngineMetrics = true` (or `UNTOLD_METRICS=1`)

## Build Configuration Notes

- `EngineProfiler` is available in all configs, but disabled by default until enabled at runtime.
- `EngineStats` collection is compiled in debug by default (`ENGINE_STATS_ENABLED`).
- For release profiling with `EngineStats`, build with `-DENGINE_STATS_ENABLED`.

If `ENGINE_STATS_ENABLED` is not compiled in, `getEngineStatsSnapshot()` returns default values and `setEngineStatsLogging(...)` is effectively a no-op.

## Category Toggle Notes

- Category filtering applies to `Logger.log(...)` debug/info trace paths.
- Warnings and errors still emit regardless of category state.
- Logger messages are lazily evaluated, so disabled categories avoid message-building cost.

## Debug Helper (DEBUG Only)

```swift
#if DEBUG
let metricsLogger = MetricsDebugLogger()
metricsLogger.logIfNeeded() // throttle-prints approximately once per second
#endif
```

## Integrated Systems

Profiler hooks are already integrated into:

- `UntoldEngine.swift` (`runFrame`)
- `RenderingSystem.swift` (`UpdateRenderingSystem`)
- `UntoldEngineXR.swift` (`executeXRSystemPass`)
- `UntoldEngineAR.swift` (`draw`)
- `BatchingSystem.swift` (`logMaterialDiagnosticsIfDue` — fires automatically every 30 s when the `.batching` category is enabled)
