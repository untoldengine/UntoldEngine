# UntoldEngine Profiling Module

A lightweight, cross-platform (macOS, iOS, visionOS) benchmarking and metrics system for UntoldEngine.

## Features

- **CPU Frame Time Measurement**: Per-frame CPU duration tracking with rolling statistics (mean, p95, p99)
- **GPU Duration Measurement**: Command buffer GPU time tracking using `MTLCommandBuffer.gpuStartTime/gpuEndTime`
- **Signpost Integration**: Named signpost scopes for Instruments profiling
- **Low Overhead**: Disabled by default, minimal cost when enabled
- **Thread-Safe**: GPU metrics collection safe across completion handler threads
- **No GPU Stalls**: Uses completion handlers, never calls `waitUntilCompleted()`

## Usage

### Enabling Metrics

Metrics are disabled by default. Enable them in one of two ways:

#### 1. Runtime Flag (in code)
```swift
enableEngineMetrics = true
```

#### 2. Environment Variable
```bash
export UNTOLD_METRICS=1
./YourApp
```

### Retrieving Metrics

```swift
let snapshot = EngineProfiler.shared.snapshot()

print("CPU Frame Mean: \(snapshot.cpuFrame.meanMs) ms")
print("CPU Frame P95: \(snapshot.cpuFrame.p95Ms) ms")
print("CPU Frame P99: \(snapshot.cpuFrame.p99Ms) ms")

print("GPU Mean: \(snapshot.gpuCommandBuffer.meanMs) ms")
print("GPU P95: \(snapshot.gpuCommandBuffer.p95Ms) ms")
print("GPU P99: \(snapshot.gpuCommandBuffer.p99Ms) ms")
```

### Debug Logging (DEBUG builds only)

```swift
#if DEBUG
let metricsLogger = MetricsDebugLogger()

// Call this once per frame (e.g., in your render loop)
metricsLogger.logIfNeeded() // Prints stats every ~1 second
#endif
```

### Instruments Integration

When metrics are enabled, the following signpost scopes are emitted:

- **Frame**: Entire frame boundary (begin to end)
- **Update**: Game/physics update phase
- **RenderPrep**: Culling, gaussian, and bitonic sort
- **Encode**: Render graph execution
- **Submit**: Command buffer commit

To view in Instruments:
1. Open Instruments
2. Select "Points of Interest" template
3. Filter by subsystem: `com.untoldengine.profiling`
4. Run your app with metrics enabled

## Architecture

- **FrameMetricsCollector**: Ring buffer (2000 samples) for CPU frame times
- **CommandBufferMetricsCollector**: Thread-safe ring buffer for GPU durations
- **EngineSignposts**: os.signpost integration for Instruments
- **EngineProfiler**: Single front-door API
- **MetricsSnapshot**: Data structures for retrieving statistics

## Integration Points

The profiling system is automatically integrated into:

- `UntoldEngine.swift` (`runFrame`): Frame and Update scopes
- `RenderingSystem.swift` (`UpdateRenderingSystem`): RenderPrep, Encode scopes, GPU metrics
- `UntoldEngineXR.swift` (`executeXRSystemPass`): XR-specific scoping and GPU metrics
- `UntoldEngineAR.swift` (`draw`): AR-specific scoping and GPU metrics

## Notes

- Percentiles (p95, p99) are computed only when `snapshot()` is called, not per-frame
- GPU times can be zero or invalid on some systems; these samples are automatically dropped
- The ring buffer holds up to 2000 samples (approximately 33 seconds at 60 FPS)
- When disabled, all profiler calls return immediately with near-zero overhead
