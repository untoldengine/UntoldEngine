# Logger

UntoldEngine includes a thread-safe logger with log-level filtering, per-category toggles, and a sink API for routing log events to custom destinations (e.g. an in-editor console).

## Log Levels

Log level controls the minimum severity that is emitted. Set it once at startup:

```swift
setLogger(.level(.debug))   // emit everything
setLogger(.level(.info))    // emit info, warnings, and errors
setLogger(.level(.warning)) // emit warnings and errors only
setLogger(.level(.error))   // emit errors only
setLogger(.level(.none))    // suppress all output
```

| Level     | Value | What emits                        |
|-----------|-------|-----------------------------------|
| `.none`   | 0     | nothing                           |
| `.error`  | 1     | errors                            |
| `.warning`| 2     | warnings + errors                 |
| `.info`   | 3     | info + warnings + errors          |
| `.debug`  | 4     | everything                        |
| `.test`   | 5     | everything (used in unit tests)   |

The default level is `.debug`.

## Logging Messages

### Info / general trace

```swift
Logger.log(message: "Scene loaded successfully", category: LogCategory.general.rawValue)
```

Requires `logLevel >= .info`. Suppressed if the category is disabled.

Console output is prefixed with `Log:`.

### Warnings

```swift
Logger.logWarning(message: "Mesh has no UV channel", category: LogCategory.general.rawValue)
```

Requires `logLevel >= .warning` and an enabled category.

Console output is prefixed with `Warning:`.

### Errors

```swift
Logger.logError(message: "Failed to load texture: \(name)", category: LogCategory.general.rawValue)
```

Requires `logLevel >= .error`. Always emits regardless of category state.

Console output is prefixed with `Error:`.

### Debug vectors

```swift
Logger.log(vector: simd_float3(1, 2, 3), category: LogCategory.general.rawValue)
Logger.log(message: "Camera position", vector: position, category: LogCategory.xrCamera.rawValue)
```

Vector helpers require `logLevel >= .debug` and are suppressed if the category is disabled.

> **Note:** Messages are lazily evaluated (`@autoclosure`), so string interpolation cost is skipped when the log would be suppressed.

## Log Categories

Categories let you silence or focus specific subsystems without changing the global log level.

| Category              | Raw value              | Default state |
|-----------------------|------------------------|---------------|
| `.general`            | `"General"`            | enabled       |
| `.ecs`                | `"ECS"`                | enabled       |
| `.engineStats`        | `"EngineStats"`        | enabled       |
| `.integration`        | `"Integration"`        | enabled       |
| `.xrCamera`           | `"XRCamera"`           | disabled      |
| `.lightPortal`        | `"LightPortal"`        | disabled      |
| `.oocTiming`          | `"OOCTiming"`          | disabled      |
| `.oocStatus`          | `"OOCStatus"`          | disabled      |
| `.assetLoader`        | `"AssetLoader"`        | disabled      |
| `.tileStreaming`      | `"TileStreaming"`      | disabled      |
| `.streamingHeartbeat` | `"StreamingHeartbeat"` | disabled      |
| `.textureStreaming`   | `"TextureStreaming"`   | disabled      |
| `.textureLoading`     | `"TextureLoading"`     | disabled      |
| `.batching`           | `"Batching"`           | disabled      |
| `.gaussian`           | `"Gaussian"`           | disabled      |

High-volume categories are off by default to avoid log spam during normal operation.

## Enabling and Disabling Categories

```swift
// Enable a category
setLogger(.category(.oocStatus, true))

// Disable a category
setLogger(.category(.xrCamera, false))

// Toggle multiple categories
setLogger(.categories([.assetLoader, .tileStreaming], true))

// Check current state
if Logger.isEnabled(category: .ecs) { ... }

// Reset all overrides back to defaults
setLogger(.resetCategories)
```

### Typical debug session

```swift
// Turn on verbose geometry streaming traces for a debug session
setLogger(.categories([
    .tileStreaming,
    .streamingHeartbeat,
    .oocStatus,
    .oocTiming,
    .assetLoader,
], true))

// ... reproduce the issue ...

// Clean up after capture
setLogger(.categories([
    .tileStreaming,
    .streamingHeartbeat,
    .oocStatus,
    .oocTiming,
    .assetLoader,
], false))
```

Texture diagnostics can be enabled separately:

```swift
setLogger(.categories([.textureStreaming, .textureLoading], true))
```

### Static batching diagnostics

The `.batching` category drives `BatchingSystem`'s material-diversity report. It tells you why batch coverage is low — too few `StaticBatchComponent` entities, material variety that prevents grouping, cells blocked by the complexity guard, and so on.

**One-shot snapshot** (most common):

```swift
setLogger(.category(.batching, true))
BatchingSystem.shared.logMaterialDiagnosticsNow()  // immediate scan and emit
setLogger(.category(.batching, false))
```

**Periodic auto-logging** (fires at most once every 30 s while enabled):

```swift
// Call once at startup to arm it; the engine loop calls logMaterialDiagnosticsIfDue() each frame.
setLogger(.category(.batching, true))

// When done:
setLogger(.category(.batching, false))
```

Sample output:

```
[BatchMaterial] staticBatch=916 registered=916 resolved=916 batchable=87%
  | singletons=119 groupable=797 | cellsBlocked=2
  | uniqueMatLOD=80 singletonKeys=119 groupableKeys=132

[BatchMaterial] cell(0,-1,0)  ents=224 uniqueKeys=49 singletons=22 groupable=27 groups=0  ratio=0.45
[BatchMaterial] cell(-1,-1,0) ents=238 uniqueKeys=42 singletons=16 groupable=26 groups=0  ratio=0.38
```

| Field | Meaning |
|-------|---------|
| `staticBatch` | Entities in the scene that carry `StaticBatchComponent` |
| `registered` | Entities resident in the batching system |
| `resolved` | Passed all eligibility checks (no animation, no transparency, etc.) |
| `batchable` | Percentage of resolved entities that share a material key with a peer |
| `singletons` | Entities that are the only one with their material in their cell — can never batch |
| `groupable` | Entities that can form a batch group |
| `cellsBlocked` | Cells rejected by the runtime complexity guard |
| `uniqueMatLOD` | Distinct (material × LOD) keys across the whole scene |
| `ratio` | Per-cell singleton fraction — close to 1.0 means high material diversity |

A low `batchable` percentage with a small `uniqueMatLOD` count points to a cell-size or complexity-guard problem. A high `uniqueMatLOD` count with a high `ratio` per cell points to material diversity in the asset.

See `UsingProfiler.md → Static Batching Triage` for a full diagnostic workflow.

## Adding a Custom Sink

Implement `LoggerSink` to route events to a custom destination such as an editor console or file:

```swift
final class ConsoleSink: LoggerSink {
    func didLog(_ event: LogEvent) {
        print("[\(event.category)] \(event.message)")
    }
}

let sink = ConsoleSink()
Logger.addSink(sink)
```

`LogEvent` exposes `level`, `message`, `category`, `file`, `function`, `line`, and `timestamp`.

Sinks are held weakly — the logger will not extend their lifetime.

> Sink delivery and backlog replay are available on macOS (`AppKit`) builds only.

## Category Toggle Notes

- `Logger.log(...)` respects both `logLevel` and category state.
- `Logger.logWarning(...)` respects both `logLevel` and category state.
- `Logger.logError(...)` respects `logLevel` only and is not suppressed by category.
- Category overrides layer on top of the built-in defaults. Call `setLogger(.resetCategories)` to restore defaults without restarting.
