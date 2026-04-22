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
