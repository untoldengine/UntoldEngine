# Logger

UntoldEngine includes a thread-safe logger with log-level filtering, per-category toggles, and a sink API for routing log events to custom destinations (e.g. an in-editor console).

## Log Levels

Log level controls the minimum severity that is emitted. Set it once at startup:

```swift
Logger.logLevel = .debug   // emit everything
Logger.logLevel = .info    // emit info, warnings, and errors
Logger.logLevel = .warning // emit warnings and errors only
Logger.logLevel = .error   // emit errors only
Logger.logLevel = .none    // suppress all output
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

Requires `logLevel >= .warning`. Always emits regardless of category state.

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
| `.oocTiming`          | `"OOCTiming"`          | disabled      |
| `.oocStatus`          | `"OOCStatus"`          | disabled      |
| `.assetLoader`        | `"AssetLoader"`        | disabled      |
| `.tileStreaming`      | `"TileStreaming"`      | disabled      |
| `.streamingHeartbeat` | `"StreamingHeartbeat"` | disabled      |
| `.textureStreaming`   | `"TextureStreaming"`   | disabled      |
| `.textureLoading`     | `"TextureLoading"`     | disabled      |

High-volume categories (`xrCamera`, `oocTiming`, `oocStatus`, `assetLoader`, `tileStreaming`, `streamingHeartbeat`, `textureStreaming`, `textureLoading`) are off by default to avoid log spam during normal operation.

## Enabling and Disabling Categories

```swift
// Enable a category
Logger.enable(category: .oocStatus)

// Disable a category
Logger.disable(category: .xrCamera)

// Toggle with a Bool
Logger.set(category: .assetLoader, enabled: true)

// Check current state
if Logger.isEnabled(category: .ecs) { ... }

// Reset all overrides back to defaults
Logger.resetCategoryToggles()
```

### Typical debug session

```swift
// Turn on verbose geometry streaming traces for a debug session
Logger.enable(category: .tileStreaming)
Logger.enable(category: .streamingHeartbeat)
Logger.enable(category: .oocStatus)
Logger.enable(category: .oocTiming)
Logger.enable(category: .assetLoader)

// ... reproduce the issue ...

// Clean up after capture
Logger.disable(category: .tileStreaming)
Logger.disable(category: .streamingHeartbeat)
Logger.disable(category: .oocStatus)
Logger.disable(category: .oocTiming)
Logger.disable(category: .assetLoader)
```

Texture diagnostics can be enabled separately:

```swift
Logger.enable(category: .textureStreaming)
Logger.enable(category: .textureLoading)
```

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
- `Logger.logWarning(...)` and `Logger.logError(...)` respect `logLevel` only — they are never suppressed by category.
- Category overrides layer on top of the built-in defaults. Call `resetCategoryToggles()` to restore defaults without restarting.
