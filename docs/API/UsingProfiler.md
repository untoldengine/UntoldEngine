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

## Geometry Streaming Diagnostics

### Per-tick operational snapshot

`GeometryStreamingSystem` maintains a rich per-tick diagnostics struct that is updated every streaming update. Pull it at any point:

```swift
let diag = GeometryStreamingSystem.shared.getDiagnosticsSnapshot()
print("update triggered: \(diag.updateTriggered)  workMs: \(diag.updateWorkMs)")
print("nearby queried: \(diag.nearbyEntitiesQueried)  candidates: \(diag.loadCandidates)")
print("slots available: \(diag.availableLoadSlots)  started: \(diag.startedLoads)")
print("evictions: \(diag.evictionsPerformed)  tileSwapWarnings: \(diag.tileSwapWarnings)")
print("avg async load: \(diag.averageAsyncLoadMs) ms")
```

| Field | What it tells you |
|---|---|
| `updateTriggered` | Whether the streaming tick ran this frame. `false` means the throttle interval hasn't elapsed yet. |
| `updateWorkMs` | CPU time spent inside the streaming update. Spikes here cause frame hitches. |
| `nearbyEntitiesQueried` | How many entities the frustum/radius gate evaluated. |
| `loadCandidates` / `startedLoads` | How many entities were eligible vs actually kicked off. A gap means slots were full. |
| `availableLoadSlots` | Concurrency slots free at the start of the tick. `0` = slot-starved. |
| `evictionTriggered` / `evictionsPerformed` | Whether memory pressure forced an eviction pass. Frequent evictions indicate the budget is too tight for the scene. |
| `lastAsyncLoadMs` / `averageAsyncLoadMs` | I/O + parse time per mesh. High values mean the bottleneck is I/O, not slot count. |
| `lastApplyLoadedMeshMs` | Main-thread GPU upload cost when a mesh completes loading. |
| `tileSwapWarnings` | Count of tile representation thrash events (≥ 6 swaps in 5 s). Nonzero means a tile is oscillating between LOD levels. |

### Streaming summary to console

For a one-shot console dump of streaming counts, cache state, and memory budget together:

```swift
GeometryStreamingSystem.shared.printStats()
```

Output includes: loaded / loading / unloaded entity counts, active load slot usage, cached file count, total cache memory, and mesh budget utilization.

### Tile streaming category log

Enable the `.tileStreaming` category for event-level traces (tile parse timeouts, eviction warnings, swap-thrash alerts):

```swift
Logger.enable(category: .tileStreaming)
// ... reproduce the issue ...
Logger.disable(category: .tileStreaming)
```

---

## Memory Budget Diagnostics

`MemoryBudgetManager` tracks mesh and texture GPU memory against configured budgets. It logs automatically when pressure thresholds are crossed, and can be queried manually.

### Automatic pressure logging

`logStatus()` fires automatically whenever memory crosses the high-water or low-water mark. No setup required — watch the log for:

```
MemoryBudgetManager Status:
- Mesh Memory:    312 MB / 512 MB (60.9%)
- Texture Memory: 198 MB / 512 MB (38.7%)
- Total GPU Memory: 510 MB / 1024 MB (49.8%)
- Tracked Entities: 847
- Under Pressure: false
```

### Manual snapshot

Call at any point to log the current state regardless of pressure:

```swift
MemoryBudgetManager.shared.logStatus()
```

### Programmatic access

```swift
let stats = MemoryBudgetManager.shared.getStats()
print("mesh: \(stats.meshMemoryUsed) / \(stats.geometryBudget)  util: \(stats.geometryUtilization)")
print("texture: \(stats.textureMemoryUsed) / \(stats.textureBudget)  util: \(stats.textureUtilization)")
print("pressure: \(stats.isUnderPressure)")
```

---

## Batching Tick Diagnostics

In addition to the material-diversity report above, `BatchingSystem` exposes a per-tick rebuild snapshot. Use it when the batch group count or frame time is unstable and you need to see inside the rebuild scheduler:

```swift
let diag = BatchingSystem.shared.getTickDiagnosticsSnapshot()
print("dirty cells: \(diag.dirtyCellsBeforePrune) → \(diag.dirtyCellsAfterPrune) after prune")
print("dispatched builds: \(diag.dispatchedBuilds)  applied: \(diag.appliedArtifacts)")
print("deferred by quiescence: \(diag.deferredByQuiescence)")
print("deferred by work budget: \(diag.deferredByWorkBudget)")
print("rebuild work: \(diag.rebuildWorkMs) ms  max cell: \(diag.maxCellRebuildMs) ms")
```

| Field | What it tells you |
|---|---|
| `dirtyCellsBeforePrune` / `AfterPrune` | How many cells needed rebuild vs how many survived the work-budget prune. A large prune gap means the scheduler is throttling. |
| `deferredByQuiescence` | Cells skipped because entities were still arriving. Normal during initial scene load. |
| `deferredByVisibility` | Cells skipped because they were outside the camera frustum. |
| `deferredByWorkBudget` | Cells skipped to stay within the per-tick CPU budget. Persistent nonzero values mean rebuild is falling behind. |
| `skippedByComplexityGuard` | Cells with too many vertices for the runtime budget — they will never batch until the budget is raised or cell size is reduced. |
| `rebuildWorkMs` / `maxCellRebuildMs` | Total and worst-case rebuild time for this tick. |
| `rebuiltVertices` / `rebuiltBufferBytes` | Output size of the rebuild work — useful for estimating GPU buffer pressure. |

For a one-line summary suitable for frame logging:

```swift
print(BatchingSystem.shared.diagnosticSummary())
// batch: registered=916 dirty=3 rebuildMs=0.4 groups=132
```

---

## Debug-only Console Helpers

The following helpers use `print()` rather than the Logger and are intended for quick local inspection. They are not gated by log categories and have no throttle.

| Call | What it prints | Platform |
|---|---|---|
| `GeometryStreamingSystem.shared.printStats()` | Streaming counts + cache stats + memory budget in one block | All |
| `RealSurfacePlaneStore.shared.logAllPlanes()` | All ARKit-detected planes: alignment, classification, Y height, extent | AR only |

These are best used with a breakpoint or a temporary `onUpdate` call. Do not leave them in shipped code.

---

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
