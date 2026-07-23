# Asset Remote Streaming

## Overview

UntoldEngine supports streaming scene geometry directly from remote **HTTPS** servers (e.g., a CDN). Plain `http://` URLs are rejected at the engine boundary to prevent unencrypted asset transmission. When a scene manifest URL points to a remote HTTPS server, the engine downloads the manifest, resolves all tile/HLOD/LOD asset URLs relative to that server, and downloads each asset on demand as the camera approaches. Downloaded assets are stored in a persistent disk cache so subsequent sessions never re-download unchanged files.

This layer sits below the tile streaming system but above the local asset loading pipeline. The rest of the engine — `GeometryStreamingSystem`, `TileComponent`, `UntoldReader` — is unaware of whether an asset came from disk or the network; `RemoteAssetDownloader` resolves a remote URL to a local cached path before the file is opened.

---

## System Components

### `RemoteAssetDownloader` (actor)

`Sources/UntoldEngine/Systems/RemoteAssetDownloader.swift`

The single download actor for all remote assets. Responsibilities:

- Downloads assets via `URLSession` and commits them to `AssetDiskCache`.
- **HTTPS-only enforcement** — `localURL(for:)` throws `DownloadError.insecureScheme` immediately for any non-HTTPS URL. Plain `http://` is never sent to the network.
- **Single-flight deduplication** — if two tiles request the same URL concurrently, only one network request is issued. The second caller suspends until the first completes, then returns the cached path.
- **Exponential backoff retry** — up to 3 attempts total, with delays of 1 s and 2 s between them; the 3rd attempt's failure throws immediately with no further delay.
- **Conditional GET** — if a cached ETag sidecar exists for a URL, the next request includes `If-None-Match: <etag>`. A 304 Not Modified response returns the cached path instantly without re-downloading.
- **Texture pre-fetch** — after downloading a `.untold` file, immediately fetches all textures referenced in its texture table in the background so they are cache-resident before the tile is parsed.

Public API:

```swift
func localURL(for remoteURL: URL) async throws -> URL
```

Returns a local `file://` URL pointing to the cached asset. Throws on permanent failure after all retries are exhausted.

**URLSession configuration:**

| Parameter | Value |
|---|---|
| `timeoutIntervalForRequest` | 30 s |
| `timeoutIntervalForResource` | 300 s |
| Max retry attempts | 3 (delays: 1 s, 2 s; 3rd failure throws immediately) |
| Retry delay formula | `2^attempt` seconds |

---

### `AssetDiskCache` (actor)

`Sources/UntoldEngine/Systems/AssetDiskCache.swift`

A persistent LRU cache that maps remote URLs to local files on disk.

- **Content-addressed storage** — the cache key is `SHA256(url.absoluteString)`. Files are stored at `<cacheDir>/<hash>.<ext>`.
- **ETag sidecars** — ETags from server responses are stored in `<hash>.meta` (JSON). Retrieved by `RemoteAssetDownloader` for conditional GET on subsequent requests.
- **Atomic writes** — each file is written to a temp path first, then renamed. A crash during download leaves an orphaned temp file, not a corrupt cache entry.
- **LRU eviction** — when total cache usage exceeds the budget (default 500 MB), the cache evicts entries by `lastAccess` timestamp (oldest first) until usage falls to 75% of budget.
- **Texture sub-paths** — textures are stored at relative paths under the cache root via `storeAtRelativePath(_:data:)`, so `NativeFormatLoader` can resolve texture URIs by the same relative path they have inside the `.untold` file.

**Cache parameters:**

| Parameter | Default |
|---|---|
| Cache directory | `Library/Caches/UntoldAssetCache/` |
| Budget | 500 MB |
| Eviction target | 75% of budget |
| Cache key | `SHA256(url.absoluteString)` |
| ETag storage | `<hash>.meta` |
| Write strategy | tmp file → atomic rename |

---

## URL Resolution

The engine resolves asset URLs lazily at load time. The helper `resolveAssetURL(_:label:)` is called by the tile loading path before opening any file:

```swift
func resolveAssetURL(_ url: URL, label: String) async -> URL? {
    if url.scheme?.lowercased() == "http" {
        // Plain HTTP is rejected — only HTTPS is permitted.
        let error = RemoteAssetDownloader.DownloadError.insecureScheme("http")
        Logger.logError(message: "[TileStreaming] Remote download failed for \(label): \(error)")
        return nil
    }
    guard url.scheme?.lowercased() == "https" else {
        return url  // Local file:// path — pass through unchanged
    }
    do {
        return try await RemoteAssetDownloader.shared.localURL(for: url)
    } catch {
        Logger.logError(message: "[TileStreaming] Remote download failed for \(label): \(error)")
        return nil
    }
}
```

Local `file://` paths bypass the downloader entirely. Only `https://` URLs go through the remote download cache. Plain `http://` URLs are explicitly rejected with a logged error and a `nil` return, which causes the tile load to mark the tile `.failed` and enter exponential backoff.

---

## Tile URL Construction

When `setEntityStreamScene(entityId:url:)` is called with a remote manifest URL, tile asset URLs are resolved relative to the **manifest directory**:

```
Manifest:    https://cdn.example.com/dungeon3/dungeon3.json
Tile path:   tiles/tile_0_0.untold
→ Tile URL:  https://cdn.example.com/dungeon3/tiles/tile_0_0.untold

HLOD path:   hlods/tile_0_0_hlod.untold
→ HLOD URL:  https://cdn.example.com/dungeon3/hlods/tile_0_0_hlod.untold
```

The same construction applies to HLOD and per-tile LOD URLs. All of these are stored in their respective `TileComponent` fields as absolute `https://` URLs. `resolveAssetURL` translates them to cached local paths at load time.

---

## End-to-End Flow

### Phase 1 — Manifest download

```swift
let sceneRoot = createEntity()
setEntityName(entityId: sceneRoot, name: "scene")

if let manifestURL = URL(string: "https://cdn.example.com/scene/scene.json") {
    setEntityStreamScene(entityId: sceneRoot, url: manifestURL)
}
```

```text
  │
  ├─ URL has https scheme → download manifest
  │   └─ RemoteAssetDownloader.localURL(for: manifestURL)
  │       ├─ AssetDiskCache.localURL(for:) → cache miss
  │       ├─ URLSession GET with optional If-None-Match header
  │       ├─ 200 OK → AssetDiskCache.store(data:for:etag:) atomically
  │       └─ Return local file:// path
  │
  └─ Decode JSON at local path → TileManifest
     └─ registerTiledScene(manifest:baseURL:)
         ├─ Construct tile URLs relative to manifest URL
         ├─ Register lightweight TileComponent stubs (no geometry)
         └─ Each stub stores tileURL as https:// in TileComponent
```

### Phase 2 — Tile download (on demand, per streaming tick)

```
GeometryStreamingSystem: camera enters prefetchRadius for tile_0_0
  │
  └─ loadTile(entityId:)
      ├─ setEntityMeshAsync(entityId: meshEntity, ...)
      │
      └─ Inside async Task:
          ├─ resolveAssetURL(tileURL)          ← tileURL is https://
          │   └─ RemoteAssetDownloader.localURL(for: tileURL)
          │       ├─ Cache hit? → return local path immediately
          │       └─ Cache miss? → download, store, return local path
          │
          ├─ Parse asset at local path
          │   └─ .untold → UntoldReader
          │
          └─ Upload geometry to Metal GPU buffers
```

### Phase 3 — Texture pre-fetch (for `.untold` assets)

After a `.untold` file is downloaded, `RemoteAssetDownloader` immediately pre-fetches all referenced textures in the background:

```
RemoteAssetDownloader downloads tile_0_0.untold
  │
  └─ downloadTextures(in: untoldData, remoteBaseURL: tileDirectoryURL)
      ├─ Parse texture table URIs from .untold header
      └─ For each texture URI (e.g. "Textures/wall_albedo.png"):
          ├─ Check AssetDiskCache for relative path → skip if present
          ├─ Construct: remoteBaseURL + "/" + uri
          ├─ Download → AssetDiskCache.storeAtRelativePath(uri, data:)
          └─ (Failures skipped; geometry still loads, just untextured)
```

Textures are stored at their relative URI under the cache root. When `NativeFormatLoader` later resolves texture paths, it finds them at the same relative path without knowing they came from a CDN.

---

## Caching Mechanics

### Cache Hit (steady state)

On the second session or after an initial warm-up pass, all tiles are cached locally:

```
resolveAssetURL(tileURL)
  └─ RemoteAssetDownloader.localURL(for: tileURL)
      └─ AssetDiskCache.localURL(for: tileURL) → hit
          └─ Return file:// path instantly (zero network I/O)
```

### Manifest Revalidation (ETag)

On subsequent sessions the manifest is revalidated cheaply:

```
GET /scene/scene.json
Headers: If-None-Match: "abc123"

← 304 Not Modified
   → Return cached manifest path, no re-download
   → All tile URLs resolved from unchanged local manifest
```

If the server returns 200 with a new ETag, the manifest and its ETag sidecar are updated atomically.

### LRU Eviction

When accumulated downloads exceed the 500 MB budget:

```
AssetDiskCache.evictIfNeeded()
  ├─ Sort entries by lastAccess ascending (oldest first)
  └─ Delete files (and their .meta sidecars) until usage ≤ 375 MB (75%)
```

Evicted files are re-downloaded transparently on next access. The cache directory persists across app launches; only explicit `clearCache()` or OS-driven cache purges remove it entirely.

---

## Retry and Error Handling

### Network retry (RemoteAssetDownloader)

| Attempt | Delay before next attempt |
|---|---|
| 1 | — (immediate first try) |
| 2 | 1 s (after attempt 1 fails) |
| 3 (final) | 2 s (after attempt 2 fails) |

After attempt 3 fails, `localURL(for:)` throws immediately — no further delay is scheduled. The tile load marks state `.failed` and enters the tile-level exponential backoff (5 s → 10 s → 20 s → 60 s max) before retrying.

### HTTP 304 Not Modified

Treated as a cache hit. No file write occurs; `localURL(for:)` returns the existing cached path.

### HTTP error codes (4xx, 5xx)

Counted as a failure, subject to the retry policy above. A 404 is retried like any other error — the manifest may be temporarily unavailable or behind an eventual-consistent CDN.

### Texture pre-fetch failures

Individual texture download failures are silently skipped. Geometry still loads and renders, just without that texture (Metal will bind a default 1×1 white fallback). This prevents a single bad texture URL from blocking tile geometry.

### Single-flight deduplication

If 10 tiles all reference the same shared texture and all request it simultaneously, only one `URLSession` task fires. The other 9 suspend and resume with the cached result once the first download completes.

---

## Integration with Tile Streaming

Remote streaming is transparent to `GeometryStreamingSystem` and `TileComponent`. From their perspective:

- `TileComponent.tileURL` holds the canonical URL for the tile (`https://` for remote scenes, `file://` for local scenes).
- `loadTile()` calls `setEntityMeshAsync`, which calls `resolveAssetURL` to get a local path before parsing.
- The streaming state machine (`.unloaded → .parsing → .parsed → .unloading`) is identical regardless of whether the asset was local or remote.
- Tile retry backoff, grace-period unloads, memory budget gates, and prefetch radius behavior all apply equally to remote tiles.

The only difference in behavior is a latency bump on first load when a tile is not yet cached. The prefetch radius absorbs most of this: the tile begins downloading when the camera is `effectivePrefetchRadius` away, giving the download time to complete before the camera reaches `streamingRadius`.

For a typical scene with `streamingRadius = 80 m` and `unloadRadius = 120 m`, `effectivePrefetchRadius` auto-computes to 100 m. At walking speed (~1.5 m/s) this is ~13 seconds of headroom — well above the download + parse time for a 15–20 MB tile over a 10 Mbps connection (~12–16 s worst case).

---

## Showcase Demo Configuration

`Sources/Demos/ShowcaseDemo/DemoState.swift` registers two remote scenes:

```swift
let remoteScenes: [RemoteSceneOption] = [
    .init(
        id: "dungeon",
        title: "Dungeon",
        manifestURL: URL(string: "https://cdn.example.net/dungeon3/dungeon3.json")!
    ),
    .init(
        id: "city",
        title: "City",
        manifestURL: URL(string: "https://cdn.example.net/city/city.json")!
    ),
]
```

`GameScene.loadTileScene(url:)` creates a root entity and passes it with the manifest URL to `setEntityStreamScene(entityId:url:)`:

```swift
func loadTileScene(sceneID: String, url: URL, completion: @escaping @Sendable (Bool) -> Void) {
    clearSceneBatches()
    GeometryStreamingSystem.shared.enabled = true

    let sceneRoot = createEntity()
    setEntityName(entityId: sceneRoot, name: sceneID)

    setEntityStreamScene(entityId: sceneRoot, url: url) { success in
        completion(success)
    }
}
```

The HUD (`DemoHUD.swift`) presents scene options; on selection it calls `onLoadTiledScene` which routes to `loadTileScene(url:)`.

---

## Threading and Safety

| Concern | Mechanism |
|---|---|
| `RemoteAssetDownloader` actor isolation | Swift actor — safe to call from any `Task` or thread |
| `AssetDiskCache` actor isolation | Swift actor — all reads and writes are serialised |
| Single-flight gate | `inFlightDownloads: [URL: Task<URL, Error>]` dictionary, actor-protected |
| Atomic cache writes | Temp file + `FileManager.moveItem` (atomic on same volume) |
| ECS mutations | Main thread only, via `withWorldMutationGate` |
| Tile completion guard | `scene.exists(entityId)` checked before every ECS write in upload completion closures |

---

## Key Design Parameters Summary

| Parameter | Value | Location |
|---|---|---|
| Permitted URL schemes | `https://` only — `http://` is rejected | `RemoteAssetDownloader`, `resolveAssetURL` |
| Max download retries | 3 | `RemoteAssetDownloader` |
| Retry delay formula | `2^attempt` seconds | `RemoteAssetDownloader` |
| Request timeout | 30 s | `URLSession` configuration |
| Resource timeout | 300 s | `URLSession` configuration |
| Disk cache budget | 500 MB | `AssetDiskCache` |
| Cache eviction target | 75% of budget | `AssetDiskCache` |
| Cache key | `SHA256(url.absoluteString)` | `AssetDiskCache` |
| ETag revalidation | Yes (conditional GET) | `RemoteAssetDownloader` |
| Texture pre-fetch | Yes (post-download, async) | `RemoteAssetDownloader` |
| Single-flight dedup | Yes (actor-isolated dictionary) | `RemoteAssetDownloader` |

---

## See Also

- [`tilebasedstreaming.md`](tilebasedstreaming.md) — tile lifecycle, manifest schema, HLOD, LOD bands
- [`geometryStreamingSystem.md`](geometryStreamingSystem.md) — mesh-level OCC streaming, memory pressure, eviction
- [`assetFormat.md`](assetFormat.md) — `.untold` binary format specification
- [`progressiveAssetLoader.md`](progressiveAssetLoader.md) — CPU heap management for out-of-core assets
