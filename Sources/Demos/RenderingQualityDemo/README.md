# Rendering Quality Demo

Focused demo for Untold Engine rendering and post-processing controls.

Run it from the repository root:

```bash
swift run RenderingQualityDemo
```

What it demonstrates:

- anti-aliasing modes through `setRendering(.antiAliasing(...))`
- render debug views through `setRendering(.debugView(...))`
- PostFX presets through `setPostFX(.preset(...))`
- interactive sliders for color grading, SSAO, bloom, vignette, depth of field, and chromatic aberration
- a small textured scene using assets from `Tests/UntoldEngineRenderTests/Resources`

Controls:

- use the on-screen panel to switch quality settings
- right-drag orbits the camera
