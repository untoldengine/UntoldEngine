# Progressive Asset Loader

## TL;DR

Loading a large USDZ file the normal way allocates Metal GPU buffers for every mesh in the file at once — on a 500 MB scene that can spike GPU memory hard enough for the OS to kill your app.

The Progressive Asset Loader avoids this by splitting the work across three phases:

1. **Parse once, on a background thread.** The entire file is read and all geometry is unpacked into CPU memory. No GPU memory is touched yet.
2. **Upload a small batch every frame.** Each frame, a few meshes are copied from CPU memory to Metal buffers. Only those meshes' GPU memory is allocated — not the rest of the file.
3. **Make each batch renderable immediately.** As soon as a batch is uploaded, its entities are registered into the ECS and appear in the scene. The asset builds up progressively while the rest of the scene keeps rendering at full speed.

This continues frame by frame until the asset is fully loaded, trading a one-time spike for a smooth, bounded cost per frame.

The loader routes automatically based on **on-disk file size** (default threshold: 50 MB). A 1.5 MB file with 2 000 simple meshes is uploaded instantly via the fast path; a 530 MB file is streamed progressively to avoid exhausting GPU memory.

---

## Stage 1 — Triggering the load

Someone in game code calls something like:

```swift
setEntityMesh(entityId: ship, filename: "bigship", withExtension: "usdz")
```

That eventually calls `setEntityMeshAsync()` in `RegistrationSystem.swift`. This function checks two conditions before taking the progressive path:

```swift
if assetName == nil, ProgressiveAssetLoader.shared.enabled { ... }
```

`assetName == nil` means "load the whole file as a scene" (as opposed to picking one named object out of it). If both conditions are true, it continues into the progressive path.

---

## Stage 2 — CPU-only parse (`parseAssetAsync`)

```swift
guard let assetData = await Mesh.parseAssetAsync(url: url, vertexDescriptor: vd, device: device)
```

This runs on a **background thread** via `Task.detached`. What happens inside:

- Creates `MDLMeshBufferDataAllocator()` — this is the key. Instead of the normal `MTKMeshBufferAllocator` which would immediately allocate Metal GPU buffers for every mesh in the file, this allocator stores all vertex and index data in **CPU heap memory** (NSData-backed buffers). On a 500 MB USDZ file, no GPU memory is touched yet.
- Calls `MDLAsset(url: url, vertexDescriptor: vd, bufferAllocator: cpuAllocator)` — ModelIO parses the entire file, unpacks every mesh's vertex/index data, and lays it out in CPU memory according to your vertex descriptor.
- Applies the orientation transform (Z-up → Y-up if needed) to top-level objects.
- Calls `asset.loadTextures()`.
- Returns a `ProgressiveAssetData` struct containing: the `MDLAsset` reference (kept alive so the CPU buffers don't get freed), the list of top-level `MDLObject`s, and a shared `TextureLoader`.

Back in `setEntityMeshAsync`, it checks the **on-disk file size**:

```swift
let fileSizeBytes = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int ?? 0
if fileSizeBytes > ProgressiveAssetLoader.shared.fileSizeThresholdBytes {
    // PROGRESSIVE PATH
```

If the file exceeds `fileSizeThresholdBytes` (default 50 MB), it goes progressive. Otherwise it falls through to the immediate fast path.

**Why file size instead of mesh count?** A 1.5 MB file with 2 000 simple meshes allocates trivial GPU memory all at once — instantaneous. A 530 MB file with the same mesh count exhausts GPU memory and triggers an OS kill. File size reflects what actually stresses the GPU memory budget; mesh count does not.

---

## Stage 3 — Building the job and releasing the gate

`setEntityMeshAsync` builds an array of `PendingObjectItem` — one per top-level `MDLObject`:

```swift
PendingObjectItem(
    index: i,
    object: topLevelObject,
    rootEntityId: entityId,
    url: url, filename: filename, withExtension: ext,
    vertexDescriptor: vd,
    textureLoader: assetData.textureLoader,
    device: device
)
```

Then it does two important things before returning:

1. **Releases the loading gate** — `AssetLoadingState.shared.finishLoading(entityId)`. This unblocks anything waiting for this entity to finish loading. From the ECS's perspective the entity is "loaded" even though meshes are still being registered. The root entity exists; children will appear progressively.

2. **Enqueues the job** — `ProgressiveAssetLoader.shared.enqueue(job)`. The job is added to the `jobs` dictionary under the lock and `setEntityMeshAsync` returns. No more work happens here.

At this point: the file is parsed into CPU memory, a job is queued, and the calling code has moved on.

---

## Stage 4 — The engine loop calls `tick()` each frame

In `UntoldEngine.swift`, every frame before `BatchingSystem.tick()`:

```swift
ProgressiveAssetLoader.shared.tick()
BatchingSystem.shared.tick()
```

`tick()` is called on the main thread (enforced by `dispatchPrecondition`). Here's what happens inside each tick:

**1. Snapshot the jobs:**
```swift
lock.lock()
snapshot = Array(jobs.values)
lock.unlock()
```
Takes references to all active jobs under the lock, then releases it. All mutation below happens without the lock because it's all single-threaded (main thread only).

**2. Round-robin ordering:**
```swift
roundRobinOffset = (roundRobinOffset + 1) % snapshot.count
```
Rotates which job goes first so simultaneous loads share the budget fairly.

**3. For each job, process up to budget:**

```swift
while processedThisTick < maxMeshesPerTick, job.hasPendingWork {
    let elapsedMs = (CACurrentMediaTime() - tickStart) * 1000
    if elapsedMs >= maxTickMilliseconds { break }

    let item = job.pending[job.nextPendingIndex]
    job.nextPendingIndex += 1
    ...
}
```

Two budgets gate how much work happens per tick: a count (`maxMeshesPerTick = 4`) and a wall-clock time (`maxTickMilliseconds = 2.0`). Whichever is hit first stops processing.

---

## Stage 5 — Per-item: CPU → GPU buffer copy (`makeMeshesFromCPUBuffers`)

For each `PendingObjectItem` dequeued, this function is called:

```swift
let meshes = Mesh.makeMeshesFromCPUBuffers(
    object: item.object, vertexDescriptor: item.vertexDescriptor,
    textureLoader: item.textureLoader, device: item.device, flip: true
)
```

It walks the `MDLObject` hierarchy and for each `MDLMesh` it finds:

**Step 1 — Tangent basis (CPU):**
```swift
mdlMesh.addOrthTanBasis(...)
```
Computes tangent and bitangent vectors from UV coordinates. This operates entirely in CPU memory — safe because the buffers are `MDLMeshBufferData`.

**Step 2 — Capture transforms from original:**
```swift
let localTransform = mdlMesh.transform?.matrix ?? .identity
let worldTransform = composedWorldTransform(for: mdlMesh)  // walks parent chain
```
These are captured now because the next step creates a new mesh object without a parent chain.

**Step 3 — Copy CPU buffers to Metal buffers (`copyBuffersToMetal`):**

This is the core of the whole system. `MTKMesh(mesh:device:)` requires Metal-backed (`MTKMeshBuffer`) buffers — it flat-out refuses CPU-heap buffers with `MTKModelErrorNoMTLBuffer`. So we do the copy manually:

```swift
let mtkAllocator = MTKMeshBufferAllocator(device: device)

// For each vertex buffer:
let dst = mtkAllocator.newBuffer(srcBuf.length, type: .vertex)
memcpy(dstMap.bytes, srcMap.bytes, srcBuf.length)

// For each index buffer in each submesh:
let dstIdx = mtkAllocator.newBuffer(srcIdx.length, type: .index)
memcpy(dstMap.bytes, srcMap.bytes, srcIdx.length)
```

A fresh `MTKMeshBufferAllocator` is created for **this one mesh only**. Its vertex and index data is `memcpy`'d from CPU heap into new `MTLBuffer`s. Only this mesh's GPU memory is allocated — not the rest of the file.

A new `MDLMesh` is constructed from these Metal-backed buffers.

**Step 4 — Create `Mesh` and fix up transforms:**
```swift
var mesh = Mesh(modelIOMesh: mtkBacked, ...)
mesh.localSpace = localTransform   // restored from original
mesh.worldSpace = worldTransform   // restored from original
```

`Mesh.init` calls `MTKMesh(mesh: mtkBacked, device:)` — this succeeds because the buffers are now Metal-backed. Transforms are then overwritten directly from the values captured in step 2, bypassing any `MDLTransform` decompose/recompose that could corrupt scale.

---

## Stage 6 — ECS registration (`registerProgressiveChildEntity`)

```swift
registerProgressiveChildEntity(
    meshes: meshes, index: item.index,
    rootEntityId: item.rootEntityId, ...
)
```

This runs inside `withWorldMutationGate`, which briefly pauses the XR renderer's scene traversal so ECS state can be mutated safely. Inside:

1. Creates a new child entity.
2. Registers transform and scene graph components.
3. Calls `applyWorldTransform(firstMesh.worldSpace, to: childEntityId)` — sets the entity's position, rotation, and scale by decomposing the world-space matrix.
4. Calls `associateMeshesToEntity` and `registerRenderComponent` — this runs `resolveMeshTransformsForRender`, which detects the parent hierarchy (because `localSpace != worldSpace`) and zeros `localSpace` so the renderer doesn't double-apply the transform.
5. Calls `setParent(childId: childEntityId, parentId: rootEntityId)` — attaches this child to the root asset entity.
6. Tags it with a `DerivedAssetNodeComponent` with a stable node path.

**The entity is now renderable.** It appears in the scene immediately on the next frame.

---

## Stage 7 — BatchingSystem picks it up the same frame

Because `ProgressiveAssetLoader.tick()` runs **before** `BatchingSystem.tick()` each frame, any entity registered in step 6 is picked up by the batching system in the **same frame** it was registered. There's no one-frame delay.

---

## Stage 8 — Job completion

When `job.completedCount >= job.totalCount`, the job is finished:

- `job.assetRef = nil` — releases the `MDLAsset`. This frees the CPU-heap buffers that were allocated back in stage 2. The GPU-side `MTLBuffer`s in each `MTKMesh` are retained by the `Mesh` structs attached to the registered entities.
- The completion callback fires on the main actor.
- The job is removed from `jobs` under the lock.
- The completion log reports total groups, elapsed time, and any failed mesh count.

---

## The whole picture in one line per stage

```
setEntityMeshAsync()             → triggers the pipeline
parseAssetAsync()                → file → CPU heap (no GPU spike)
enqueue(job)                     → registers work, releases gate, returns
tick() frame N                   → dequeues 4 items (or 2ms worth)
makeMeshesFromCPUBuffers()       → CPU heap → MTLBuffer (one mesh at a time)
registerProgressiveChildEntity() → ECS entity, immediately renderable
BatchingSystem.tick()            → picks up new entity same frame
... repeat for N/4 frames ...
job.assetRef = nil               → CPU heap freed, GPU memory remains
```
