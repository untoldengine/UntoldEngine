# Actors and Locks in the Engine — Benchmark, Lock Census and Rules (Research)

Status: research with measurements, no engine change. Measured 2026-10-03 on `develop` (`108169ce`), Mac16,5 (M4 Max, 12 performance + 4 efficiency cores), macOS 27.0, Xcode 27.0 / Swift 6.4, release builds. Nothing here was measured on a Vision Pro or an iPhone.

Two questions:

1. May engine code use Swift actors, or are they too slow next to locks?
2. Does the per-frame path use the best lock mechanism?

Everything below can be re-run: the benchmark is `Examples/ConcurrencyBench`, the census is `Tests/UntoldEngineRenderTests/LockCensusTests.swift` (section 6).

## TL;DR

1. **No actors for state the frame touches.** The update, render and XR threads are synchronous and cannot `await`. The only bridge is a `Task`, and its latency depends on Swift's shared thread pool: 7 µs when the pool is idle, **2.4 ms to 24 ms (median) when asset jobs fill it**. A lock stays under 1 µs in every case.
2. **Actors are fine at the async edges.** Downloads, disk cache, loading bookkeeping: every caller is already async and the call rate is per asset. The three actors the engine has today fit this. Inside an actor, code costs the same as unsynchronised code; only crossing the boundary costs (47 ns uncontended, 2.3 µs with 8 callers).
3. **The editor may use actors freely**: `@MainActor` for UI state costs the same as `DispatchQueue.main.async`, and actors suit background jobs. Batch the calls: one call from the main actor into another actor costs about 8 µs.
4. **The engine takes about 130 to 140 locks per entity per frame.** A scene of 4,000 cubes takes 564,000 lock acquisitions per frame, nearly all on the main thread with nobody to contend with. 98 % of them come from three places: the `scene` global, the component-id map and the scene-channel visibility check.
5. **A better lock primitive is a small win; fewer locks is the large one.** Swapping those three locks for unfair locks cuts the frame by 2 to 8 %. Removing them altogether (the ceiling of "lock once per system instead of once per access") cuts it by 22 to 26 %.

## 1. Rules proposed

**Engine**

- No actor may own state that the update, render or XR thread reads or writes.
- An actor is allowed when every caller is already `async` and the calls are per asset or per request, never per entity or per frame.
- When the frame needs to see state owned by an actor, the actor publishes it through a lock-protected snapshot. `AssetLoadingState` (actor) with `AssetLoadingGate` (lock) is the existing example.
- Default lock: `OSAllocatedUnfairLock` (macOS 13, iOS 16, visionOS 1). `Synchronization.Mutex` is as fast but needs macOS 15 and iOS 18, above the engine's minimums (macOS 14, iOS 17, visionOS 2).
- `NSRecursiveLock` only where re-entry is real, and never on a per-entity path.
- A serial or concurrent `DispatchQueue` is not a lock: `queue.sync` costs 170 ns uncontended, 50 times an unfair lock.
- Per-frame code reads shared state once per system or pass, not once per entity.

**Editor**

- `@MainActor` for UI state, actors for background work (export, cook, asset scans).
- No per-item `await` from the main actor into another actor: send one batched call.

## 2. Benchmark: actors against locks

`Examples/ConcurrencyBench`, release build, minimum of 5 to 7 runs. The operation is one array element read and written.

**One access, no contention**

| Mechanism | ns per access |
|---|---|
| No synchronisation | 2 to 6 |
| `OSAllocatedUnfairLock` | 3.3 |
| `Synchronization.Mutex` | 3.6 |
| `NSLock` | 12 |
| `NSRecursiveLock` | 17.5 |
| Actor, `await` per access from a task | 47 |
| Actor to actor, `await` per access | 8 |
| Actor pinned to a queue, `assumeIsolated` per access | 135 |
| Serial `DispatchQueue.sync` | 170 |
| Main actor calling an actor, per access (thread hop both ways) | 7,700 |

The baseline is 2 ns with Swift's runtime exclusivity checks off and 6 ns with them on (class stored properties are checked at run time; state inside `OSAllocatedUnfairLock`, `Mutex` or an actor is not). That is why the unfair lock reads lower than the unsynchronised class.

**Eight workers on one state** (ns per access)

| Mechanism | ns |
|---|---|
| `OSAllocatedUnfairLock` | 115 |
| `Synchronization.Mutex` | 128 |
| `NSLock` | 300 |
| `NSRecursiveLock` | 360 |
| Actor | 2,300 |

**One system pass over 10,000 entities, 3 reads each** (µs per frame)

| Mechanism | µs |
|---|---|
| No synchronisation | 6.5 |
| Unfair lock taken once per pass | 6.4 |
| Actor, the pass runs inside it (one hop) | 6.5 |
| Unfair lock per read | 64 |
| `NSRecursiveLock` per read | 340 to 420 |
| Actor, `await` per read | 425 |

**Time for a synchronous thread to get one value** (µs; 1,500 samples)

| Thread pool | Unfair lock p50 / p99 | Actor through `Task` p50 / p99 |
|---|---|---|
| Idle | 0.04 / 0.33 | 7 / 27 |
| Full of 20 ms jobs at the same priority | 0.08 / 0.54 | 24,400 / 33,100 |
| Full of 20 ms jobs at utility priority | 0.04 / 0.46 | 2,400 / 10,400 |

The saturation test is synthetic: 32 tasks that each burn 20 ms without a suspension point, which is what a mesh or texture decode looks like to the pool.

Round trip from a background thread to the main thread, idle: 7.6 µs with `DispatchQueue.main.async`, 7.4 µs with `Task { @MainActor }` (p99 about 29 µs for both).

**Reading.** The cost of an actor is the boundary, not the body. Crossing it per access is 14 times an unfair lock, 20 times under contention. Worse for a frame loop, the wait is not bounded by the engine: it is bounded by whatever else runs on the cooperative pool.

## 3. What the engine does today

Counted in `Sources/UntoldEngine` and `Sources/UntoldEngineXR`:

| Mechanism | Sites |
|---|---|
| `NSLock` / `NSRecursiveLock` declarations | about 110 |
| `OSAllocatedUnfairLock` | 3 (XR input, real-surface picking) |
| Actors | 3 (`AssetLoadingState`, `AssetDiskCache`, `RemoteAssetDownloader`) |
| `DispatchQueue` used as a lock | `AnimationSystem` (`isEnabled`), `MeshResourceManager` (23 uses) |

The three actors sit at the async edge and are within the proposed rule. `AssetLoadingState` shows the limit of an actor in the engine: the render loop must know whether loading is in progress and cannot `await`, so a second, lock-based object (`AssetLoadingGate`) mirrors the answer.

## 4. Lock census of the frame

`LockCensusTests` hooks `-[NSLock lock]` and `-[NSRecursiveLock lock]`, runs `renderer.draw` on the render-test scene plus a grid of cubes, and attributes every acquisition to the engine function that made it. Release build; the frame time is the wall time of `renderer.draw` without the hook.

| Scene | Lock acquisitions per frame | Per cube | Off the main thread | `renderer.draw` |
|---|---|---|---|---|
| 1,000 cubes | 127,900 | 128 | 7 per frame | 6.7 ms |
| 4,000 cubes | 563,900 | 141 | 7 per frame | 25.9 ms |

By lock (debug build, 1,000 cubes, where the accessors are not inlined):

| Lock | Per frame | Share | Where |
|---|---|---|---|
| `scene` global getter (`NSRecursiveLock`) | 65,800 | 49 % | `Utils/Globals.swift`, `CoreRuntimeGlobals` |
| Component-id map (`NSLock`) | 50,700 | 38 % | `ECS/ComponentPool.swift`, `componentTypeInfo(for:)` |
| Scene-channel render mode (`NSLock`) | 10,400 | 8 % | `Utils/SceneContextVisibility.swift`, `renderMode(for:)` |
| `renderInfo` global getter | 2,600 | 2 % | `Utils/Globals.swift` |
| `RenderStatsCollector.recordDraw` | 1,750 | 1 % | debug builds only (`ENGINE_STATS_ENABLED`) |
| `LODConfig.shared`, two `SpatialDebugVisualization` flags, `pomQualitySettings` | 730 each | 2 % | one read per drawn entity |
| Everything else | under 400 | 0.3 % | |

By caller (release build, 4,000 cubes): `Scene.get(component:for:)` 194,000, the model/light pass 58,600, `shadowCasterEntityIds` 48,000, `collectShadowCasterBounds` 40,000, the transparency pass 29,300, `hasComponent` 37,300, `getEntityComponent` from `bindJointStreams` and `deformedStreams` 30,700, the shadow pass 16,000, frustum culling 12,000.

Public API, per call: `scene.get(component:for:)` takes 2 locks, `translateTo(entityId:position:)` takes 22.

Almost none of these acquisitions ever meets another thread. They are pure overhead on a single thread, so the question is less "which lock" than "why lock here at all".

## 5. Experiment: what the locks cost in the frame

Same test, release build, 120 frames, three runs each (not committed; the patch replaced the lock objects of `CoreRuntimeGlobals`, `RuntimeGlobalsStore`, the component-id map and `SceneChannelVisibilityState`).

| Variant | 1,000 cubes | 4,000 cubes |
|---|---|---|
| Today (`NSRecursiveLock` + `NSLock`) | 6.52 / 6.68 / 6.90 ms | 25.54 / 25.93 / 27.93 ms |
| Unfair locks (recursive wrapper for the globals) | 5.98 / 6.01 / 6.28 ms | 25.07 / 25.19 / 25.36 ms |
| Those locks removed (single-threaded test, ceiling only) | 4.81 / 4.90 / 5.01 ms | 20.01 / 22.08 / 30.61 ms |

- Better primitive: 8 % of the frame at 1,000 cubes, 2 % at 4,000 (best run against best run).
- No per-access locking: 26 % at 1,000 cubes, 22 % at 4,000 (best run against best run; the 4,000-cube runs were noisy, with one outlier at 30.6 ms).

The third row is not a shippable change. It is the most that restructuring can give: the frame holding the scene for a whole system or pass instead of locking for each component read.

## 6. Review of the critical path

Ranked by measured weight.

1. **`scene` and the other `CoreRuntimeGlobals`** (`Utils/Globals.swift:39`). Every read locks an `NSRecursiveLock` and copies the `Scene` struct; `_modify` holds the lock across the caller's mutation, which is why the lock has to be recursive. Half of all acquisitions. Best mechanism: none per access. A system or pass should borrow the scene once. Until then, a recursive unfair lock is a drop-in gain.
2. **Component-id map** (`ECS/ComponentPool.swift:30`). `getComponentId(for:)` locks and looks up a dictionary on every `scene.get`. Component ids never change after registration. Best mechanism: a per-type static id (no lock, no lookup); an unfair lock is the minimal step.
3. **`SceneChannelVisibilityState.renderMode(for:)`** (`Utils/SceneContextVisibility.swift:61`). Called per entity per pass (shadow, model, transparency, wireframe, occluder shell); each call locks and builds two arrays. In the common case no channel is overridden. Best mechanism: a lock-free "nothing overridden" fast path, or one snapshot per frame.
4. **Per-entity reads of per-frame constants**: `LODConfig.shared`, `SpatialDebugVisualization.colorRenderablesByLOD` / `colorRenderablesByStreamingTier`, `pomQualitySettings`, `renderInfo`. Each is a lock per drawn entity for a value that does not change during the pass. Read once per pass.
5. **`RuntimeGlobalsStore`** (`Utils/Globals.swift:1068`). An `NSRecursiveLock` around about 80 scalar globals, each taken one at a time. Its accessors only copy a value in or out, so it should not need to be recursive (to confirm before changing it); an unfair lock would then be enough.
6. **`DispatchQueue.sync` as a lock**: `AnimationSystem.isEnabled` (concurrent queue with barrier writes) and `MeshResourceManager.accessQueue`. The census does not count queues; from the benchmark each uncontended `sync` costs about 170 ns. Replace with an unfair lock where the path is per frame.
7. **`RenderStatsCollector.recordDraw`**: a lock per draw, debug builds only. Accumulate per pass and publish once.
8. **Already right**: `TripleCPUBuffer` and `publishVisibleEntities` (once per frame), the XR input queues (`OSAllocatedUnfairLock`), the loading gate.

Suggested order: items 2 and 3 (small, local), item 4 (hoists), item 5 and the unfair swap of item 1 (mechanical), then the scene borrow of item 1, which is where the largest gain is and which needs a design.

## 7. Reproduce

```bash
# Actors against locks
swift run -c release --package-path Examples/ConcurrencyBench            # all sections
swift run -c release --package-path Examples/ConcurrencyBench ConcurrencyBench 4   # one section (1 to 5)

# Lock census of the frame (opt-in test, skipped otherwise)
UNTOLD_LOCK_CENSUS=1 UNTOLD_LOCK_CENSUS_ENTITIES=4000 UNTOLD_LOCK_CENSUS_FRAMES=120 CI=true \
    swift test -c release -Xswiftc -enable-testing --filter LockCensusTests 2>&1 | xcrun swift-demangle --simplified
```

## 8. Limits

- One machine, macOS only. The ratios should hold on iOS and visionOS (same runtime, same lock implementations); the absolute numbers will not. The pool-saturation result depends on core count: fewer cores saturate sooner.
- The census scene is static cubes plus the render-test scene: no animation, physics, streaming load or XR. Those paths are reviewed from the source only.
- The census counts `NSLock` and `NSRecursiveLock`. It does not count `OSAllocatedUnfairLock` (3 sites) or dispatch queues.
- The frame times are the wall time of `renderer.draw` in a headless test, which includes command encoding but not presentation.
