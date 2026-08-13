# Tutorials

The tutorials use the demos in `Sources/Demos` as small, runnable examples of
the Untold Engine API. Each tutorial focuses on the engine calls that matter for
building an application: creating a renderer, registering entities, loading or
creating renderable content, configuring cameras and lights, handling input, and
updating the scene every frame.

The demo READMEs explain how to run each executable. These tutorials explain how
the demos are built and how the same API calls transfer into your own project.

## Learning Path

| Tutorial | Run Command | Main API Focus |
| --- | --- | --- |
| [Starter Demo](StarterDemo.md) | `swift run StarterDemo` | Renderer setup, frame callbacks, scene readiness, entities, meshes, transforms, camera movement, mouse input. |
| [Lighting Demo](LightingDemo.md) | `swift run LightingDemo` | Light entities, directional lights, point lights, spot lights, area lights, light color, intensity, and runtime controls. |
| [Rendering Quality Demo](RenderingQualityDemo.md) | `swift run RenderingQualityDemo` | Rendering settings, anti-aliasing, debug views, PostFX presets, and runtime quality controls. |
| [Exporter Pipeline Demo](ExporterPipelineDemo.md) | `swift run ExporterPipelineDemo` | Loading `.untold` assets, exported animation clips, validation metadata, and authored asset workflows. |
| [Interaction / Gameplay Demo](InteractionGameplayDemo.md) | `swift run InteractionGameplayDemo` | Gameplay-style input, animation switching, physics pause/resume, parented entities, and update-loop behavior. |
| [Large Scene Streaming Demo](LargeSceneStreamingDemo.md) | `swift run LargeSceneStreamingDemo` | Tiled scene manifests, geometry streaming, LOD, static batching, cache budgets, and streaming diagnostics. |
| [Showcase Demo](ShowcaseDemo.md) | `swift run ShowcaseDemo` | A combined demonstration of multiple systems after you understand the focused demos. |

## How To Use These Tutorials

Start with the Starter Demo even if your goal is XR, streaming, or custom
rendering. It shows the basic shape of an Untold Engine application without
external assets or large-scene systems.

After that, choose the demo that matches the system you want to learn. The
tutorials are meant to be read with the source files open:

- `Sources/Demos/<DemoName>/main.swift`
- `Sources/Demos/<DemoName>/AppDelegate.swift`
- `Sources/Demos/<DemoName>/GameScene.swift`

Most demos also use shared setup helpers from `Sources/Demos/DemoUtils`. Those
helpers keep the demo files short, but the tutorials call out the underlying
engine APIs so you can use them directly in your own app.

## Related Documentation

- [Getting Started](../API/GettingStarted.md)
- [Usage Examples](../API/UsageExamples.md)
- [Registration System](../API/UsingRegistrationSystem.md)
- [Transform System](../API/UsingTransformSystem.md)
- [Camera System](../API/UsingCameraSystem.md)
- [Input System](../API/UsingInputSystem.md)
- [Rendering System](../API/UsingRenderingSystem.md)
