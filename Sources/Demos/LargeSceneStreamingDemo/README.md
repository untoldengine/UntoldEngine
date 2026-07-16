# Large Scene Streaming Demo

Focused demo for Untold Engine's manifest-driven tiled-scene streaming path.

Run it from the repository root:

```bash
swift run LargeSceneStreamingDemo
```

What it demonstrates:

- loading a remote tiled-scene manifest with `setEntityStreamScene(entityId:url:)`
- fly-camera traversal through streamed content
- geometry streaming runtime tuning through `setGeometryStreaming(...)`
- automatic runtime batching for streamed tiles
- tile bounds, LOD debug, and texture tier debug overlays
- live engine stats for streaming, batching, draw calls, and memory

The default remote scenes reuse the same public manifests as `ShowcaseDemo`. The
`Field` button loads a procedural offline reference field so the executable still
runs without network access, but that mode is not tile streaming.

To test your own exported world, paste a full `https://.../scene.json` or
`file:///.../scene.json` manifest URL into the custom manifest field.
