# Starter Demo

Minimal first-run demo for Untold Engine.

Run it from the repository root:

```bash
swift run StarterDemo
```

What it demonstrates:

- create a renderer-backed macOS window
- create a game camera and directional light
- create one renderable entity
- move the camera with `WASD` and `Q/E`
- orbit with right mouse drag
- update an entity every frame

The demo uses `BasicPrimitives.createCube()` so it runs without external assets.
To try your own content, export a model to `.untold` and replace
`createStarterObject()` in `GameScene.swift` with the commented
`setEntityMeshAsync(...)` example.
