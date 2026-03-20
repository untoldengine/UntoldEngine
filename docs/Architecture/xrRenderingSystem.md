# XR Rendering System — How It Works

The XR rendering system is the visionOS counterpart to `UpdateRenderingSystem`. It drives the same deferred render graph used on macOS, but within a completely different frame lifecycle imposed by **CompositorServices** — Apple's low-latency compositor for spatial computing.

The entry point is `UntoldEngineXR`, a class that owns the render loop, the ARKit session, and the spatial input bridge. Everything in this file is compiled only on visionOS (`#if os(visionOS)`).

---

## Why XR Rendering Is Different

On macOS, the MTKView delegate calls `draw(in:)` on the main thread at display refresh rate. The engine owns the timing.

On visionOS, **the compositor owns the timing**. It tells you when to render, provides per-eye textures, and requires you to attach a device anchor (head pose) to every frame before presenting. If you miss the deadline or present without an anchor, the compositor either drops your frame or logs a warning. The `UntoldEngineXR` run loop is specifically structured to satisfy these compositor requirements frame by frame.

---

## Step 0: Initialization

```swift
UntoldEngineXR(layerRenderer: LayerRenderer, device: MTLDevice)
```

At init time, three things happen in parallel:

**ARKit session startup** (async Task): Queries world sensing authorization, then launches `WorldTrackingProvider` and `PlaneDetectionProvider`. World tracking is what gives you the device anchor — the head pose needed to render correctly in the user's space. If world sensing is denied (e.g., the user blocked it in Settings), the engine still runs with world tracking only so rendering doesn't break, it just has no plane data.

**Plane monitor** (background Task): A long-running Swift structured concurrency task that consumes the `planeDetection.anchorUpdates` async stream. Every time the system detects, updates, or removes a real-world surface (floor, wall, table, etc.), it maps the ARKit classification to the engine's `RealSurfaceKind` enum and forwards it to `RealSurfacePlaneStore`. Game code queries this store to snap objects to real surfaces.

**Renderer creation**: `UntoldRenderer.createXR(...)` initializes the Metal device, command queue, G-Buffer textures, pipeline states, and all other GPU resources at the fixed visionOS viewport size (2048 × 1984 per eye).

---

## Step 1: The Run Loop

`runLoop()` is called from a dedicated background thread (the compositor render thread) and runs for the lifetime of the XR session:

```swift
while true {
    switch layerRenderer.state {
    case .paused:    layerRenderer.waitUntilRunning()
    case .running:   renderNewFrame()
    case .invalidated: break  // exit
    }
}
```

The `.paused` state blocks the thread cheaply until the compositor is ready — this happens when the user puts the app in the background or when the system needs to reclaim resources. The `.invalidated` state is the clean shutdown signal.

**Why a background thread?** The compositor render thread must never be blocked by Swift's main actor or UIKit layout passes. Running here ensures that Metal encoding proceeds at compositor frame rate (90 FPS on Vision Pro) without contention.

---

## Step 2: The Per-Frame Lifecycle — `renderNewFrame()`

CompositorServices frames follow a strict protocol. Every call to `renderNewFrame()` must progress through these phases in order:

### 2a. Query + Predict

```swift
let frame = layerRenderer.queryNextFrame()
let timing = frame.predictTiming()
```

`queryNextFrame()` dequeues the next compositor frame. `predictTiming()` returns `optimalInputTime` — the deadline by which you must finish reading input and preparing CPU-side data for the frame. These are not suggestions; missing them causes judder.

### 2b. Update Phase

```swift
frame.startUpdate()
// ... do CPU work ...
frame.endUpdate()
```

Everything between `startUpdate` and `endUpdate` is CPU-side frame preparation:

- **Progressive loading tick**: `ProgressiveAssetLoader.shared.tick()` is dispatched to the main thread via `DispatchQueue.main.async`. The run loop lives on the compositor thread, but `tick()` requires `@MainActor`. This mirrors what `UntoldEngine.swift`'s `draw()` does on macOS.

- **Spatial input processing**: `updateSpatialInputState()` drains the queued `XRSpatialInputSnapshot` events and updates the `InputSystem`. If assets are loading or the scene isn't ready, input is cleared instead to avoid acting on stale state.

- **Game update**: `renderer.updateXR()` calls the user's `gameUpdate` and `handleInput` callbacks. This is where game logic runs — entity movement, animation state machines, physics steps. It is skipped entirely while `AssetLoadingGate.shared.isLoadingAny` is true.

### 2c. Wait for Optimal Input Time

```swift
LayerRenderer.Clock().wait(until: timing.optimalInputTime, tolerance: .zero)
```

The thread sleeps until the compositor says it's the best moment to submit GPU work. Submitting too early wastes GPU time on a stale pose; submitting too late misses the scanline. This one call is what makes visionOS rendering feel low-latency.

### 2d. Submission Phase

```swift
frame.startSubmission()
defer { frame.endSubmission() }
```

The `defer` is important: `endSubmission()` **must** be called even if rendering fails partway through. If it isn't called, the compositor stalls. The `defer` guarantees this regardless of how the function exits.

### 2e. Device Anchor Acquisition

```swift
let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: presentationTimeCA)
drawable.deviceAnchor = anchor
```

The device anchor is the head pose — a 4×4 transform from world space to the device. The compositor requires it to be attached to the drawable before presenting; without it, the system can't reproject the frame correctly for the user's eyes.

The engine queries the anchor at **presentation time** (the future moment when the frame will appear on screen), not at "now". This is predictive — it compensates for the latency between encoding and display by predicting where the head will be.

**Resilience strategy**: ARKit can occasionally return `nil` for the anchor (e.g., tracking hiccup, recovery). A three-level fallback prevents dropped frames:
1. Query at predicted presentation time → use it if valid
2. Query at "now" as a retry → use it if valid
3. Fall back to `lastValidDeviceAnchor` — the last anchor that was valid

The engine never skips presenting a drawable once it has been dequeued. Even with no anchor at all, the drawable is presented (the compositor handles it gracefully); skipping would cause a more disruptive compositor error.

---

## Step 3: GPU Encoding — `executeXRSystemPass()`

This is where the actual Metal work happens, split into three parts.

### 3a. Pre-Render Compute (runs once for both eyes)

```swift
performFrustumCulling(commandBuffer: commandBuffer)
executeGaussianDepth(commandBuffer)
executeBitonicSort(commandBuffer)
```

These are the **same three compute passes** as the macOS path: frustum cull, Gaussian depth, bitonic sort. The key difference is they run **once per frame**, not once per eye. The culled visibility list and sorted splat indices produced here are reused by both the left and right eye render passes.

> **Why only once?** Running culling and sorting twice — once per eye — at 90 FPS would double the compute budget for work that produces nearly identical results (the two eyes are only ~65mm apart). One cull pass with a slightly conservative frustum covers both views.

### 3b. Per-Eye Render Loop

```swift
for (viewIndex, view) in drawable.views.enumerated() {
    // compute view and projection matrices
    // configure pass descriptor
    // call renderer.renderXR(...)
}
```

The drawable provides two views (left eye, right eye). For each:

**View matrix construction**:
```swift
let cameraMatrix = simd_inverse(originFromDevice * deviceFromView)
```
`originFromDevice` is the world-to-device transform from the anchor. `deviceFromView` is the eye offset relative to the device center (the IPD offset). Multiplying them gives world-to-eye, then inverting gives the view matrix the shaders expect.

**Projection matrix**:
```swift
let projection = drawable.computeProjection(convention: .rightUpBack, viewIndex: viewIndex)
```
The compositor provides the exact asymmetric projection for each eye. This accounts for the different FOV angles per eye and the physical lens geometry of the headset — it cannot be constructed manually.

**Pass descriptor**: Pre-allocated (`passDescriptorLeft`, `passDescriptorRight`) and reused every frame to avoid 180 allocations/second (2 eyes × 90 FPS). The color and depth textures are swapped in from `drawable.colorTextures[viewIndex]` and `drawable.depthTextures[viewIndex]`.

**`renderer.renderXR(...)`** calls `buildGameModeGraph()` + `topologicalSortGraph()` + `executeGraph()` — the exact same render graph pipeline as macOS. The only thing that changes is:
- `renderInfo.currentEye = viewIndex` — tells uniform uploads which eye's matrices to use
- The base pass mode: `.mixed` immersion omits the base pass (camera passthrough is the background), `.full` immersion renders the skybox

### 3c. HZB Pyramid (built once after both eyes)

```swift
buildHZBDepthPyramid(commandBuffer)
```

After both eyes are encoded into the same command buffer, the HZB depth pyramid is built from the depth texture of the **last eye rendered**. In stereo, this mono pyramid is used for both per-eye occlusion tests in the next frame's frustum cull.

**Why after both eyes, not per eye?** Building HZB per eye would double the cost and produce two pyramids that next frame's single-dispatch cull can't easily consume. The right eye's depth is a reasonable approximation for the combined scene.

### 3d. Present and Commit

```swift
drawable.encodePresent(commandBuffer: commandBuffer)
commandBuffer.commit()
```

Note `encodePresent` vs. macOS's `commandBuffer.present(drawable)`. On visionOS, the present must be **encoded into the command buffer** as a GPU command so the compositor can precisely time when the drawable lands on screen relative to GPU work completion. It is not a CPU-side call.

The completion handler signals `commandBufferSemaphore` when the GPU finishes, freeing a slot for the next frame.

---

## Spatial Input Bridge

`configureSpatialEventBridge()` registers a closure on `layerRenderer.onSpatialEvent`. Every time the compositor fires a pinch gesture or spatial tap, the closure:

1. Extracts the **selection ray** — origin and direction in world space — from the event's `selectionRay` field
2. Extracts the **input device pose** (hand position and orientation) if available
3. Maps the CompositorServices phase (`.active`, `.ended`, `.cancelled`) to the engine's `XRSpatialInteractionPhase`
4. Packs everything into an `XRSpatialInputSnapshot` and enqueues it in `InputSystem`

The snapshot is processed on the next frame's update phase by `spatialGestureRecognizer.updateSpatialInputState()`, which converts raw ray/phase sequences into higher-level gesture events (tap, hold, drag) that game code can query.

> The bridge is gated on `isSceneReady()` and `!AssetLoadingGate.shared.isLoadingAny`. Input events while loading are discarded to prevent game code from acting on uninitialized entities.

---

## The Full XR Frame in One Picture

```
[Compositor thread] runLoop() → renderNewFrame()
        │
        ├─ queryNextFrame() + predictTiming()
        ├─ frame.startUpdate()
        │       ├─ [Main thread async] ProgressiveAssetLoader.tick()
        │       ├─ updateSpatialInputState()   (drain gesture queue)
        │       └─ renderer.updateXR()         (gameUpdate + handleInput)
        ├─ frame.endUpdate()
        ├─ wait(until: optimalInputTime)       (sleep until compositor deadline)
        ├─ frame.startSubmission()
        ├─ queryDrawable()                     (get per-eye textures)
        ├─ queryDeviceAnchor() → fallback chain → drawable.deviceAnchor = anchor
        │
        └─ executeXRSystemPass()
                │
                ├─ [GPU compute] frustumCulling    (once, covers both eyes)
                ├─ [GPU compute] gaussianDepth
                ├─ [GPU compute] bitonicSort
                │
                ├─ for eye in [left, right]:
                │       ├─ compute view matrix (originFromDevice × deviceFromView)⁻¹
                │       ├─ compute projection  (drawable.computeProjection)
                │       ├─ configure passDescriptor (color + depth textures)
                │       └─ renderer.renderXR() → buildGameModeGraph()
                │                                  topologicalSortGraph()
                │                                  executeGraph()
                │                                  [same DAG as macOS]
                │
                ├─ [GPU compute] buildHZBDepthPyramid  (once, after both eyes)
                ├─ drawable.encodePresent(commandBuffer)
                └─ commandBuffer.commit()
                        │
                        └─ [GPU→thread callback] semaphore.signal()
        │
        └─ frame.endSubmission()
```

---

## Key Differences From the macOS Path

| | macOS (`UpdateRenderingSystem`) | visionOS (`executeXRSystemPass`) |
|---|---|---|
| Frame timing | MTKView drives at display rate | CompositorServices dictates via `optimalInputTime` |
| Eyes | 1 | 2 (per-eye loop over `drawable.views`) |
| Compute passes | Once per frame | Once per frame (shared across both eyes) |
| View matrix | Camera entity transform | `(originFromDevice × deviceFromView)⁻¹` from ARKit anchor |
| Projection | Camera component FOV | `drawable.computeProjection()` — asymmetric per-eye |
| Present call | `commandBuffer.present(drawable)` | `drawable.encodePresent(commandBuffer:)` — encoded as GPU command |
| HZB build | After the single render graph | After both eyes, once |
| Base pass | Environment or grid | Environment (full immersion) or none (mixed/passthrough) |
| Game update thread | Main thread (MTKView delegate) | Compositor thread, with main-thread dispatch for restricted APIs |
