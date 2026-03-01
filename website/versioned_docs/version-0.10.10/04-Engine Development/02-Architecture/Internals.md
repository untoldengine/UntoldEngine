---
id: engine-architecture
title: Engine Architecture Internals
sidebar_position: 2
---

# Untold Engine Architecture Internals

You’re looking under the hood of Untold Engine. This is how the pieces fit together, why we picked them, and where contributors can plug in.

## The Big Idea: ECS at the Core
Untold Engine is deliberately **ECS-first**:
- **Entities** are just 64-bit IDs (index + version) managed in `Scenes.swift` with pooling, masks, and tombstones.
- **Components** are plain data (no logic) in `ECS/Components.swift`: transforms, render payloads, physics state, animation sets, lights, scripts, etc. Components live in type-specific pools keyed by component ID.
- **Systems** are the behavior layer in `Sources/UntoldEngine/Systems/`. Each system queries entities by component mask and runs every frame (or in fixed steps for physics). Examples: Transform, Scenegraph, Rendering, Physics, Animation, Input, Culling, Loading, Lighting, Shadow, Steering, USC scripting.

Why this matters: contributors can add data (components) and behavior (systems) without rewriting the core. Keep components dumb, keep systems focused, and everything stays modular and testable.

## Frame Flow
`UntoldRenderer.runFrame` orchestrates each tick:
1) **Simulation prep**: delta time, scene graph traversal, input handling.
2) **Gameplay & scripting**: AnimationSystem, USCSystem, custom game update callbacks.
3) **Physics**: fixed-timestep accumulator, gravity/drag/forces, Runge–Kutta integration (collision/contact still open for contribution).
4) **Culling & rendering**: frustum cull, Gaussian depth/sort, build render graph, execute passes, present.

## Rendering Stack
- **Entry point**: `UntoldRenderer` (MTKView delegate) sets up device/queue, loads metallib, initializes buffers, and drives the frame loop. Platform variants exist for macOS/iOS, visionOS (XR), and AR.
- **Render graph**: `RenderingSystem.swift` builds a dependency graph (environment/grid/AR base → shadow → GBuffer/model → gaussian → post → precomp) and executes via `RenderPasses` + `PipelineManager`.
- **Pipelines**: Render and compute pipelines live in `Renderer/Pipelines/`. Gaussian splats run dedicated compute passes (depth + bitonic sort) before their render pass.

## Physics & Motion
- **Data**: `PhysicsComponents` and `KineticComponent` store mass, velocity/angular velocity, drag, inertia tensors, forces, moments, and pause flags.
- **Runtime**: `updatePhysicsSystem` accumulates forces/moments, applies gravity/drag, and integrates with Runge–Kutta. Collision/contact resolution is intentionally minimal today—prime territory for contributions.
- **Steering & Animation**: SteeringSystem and AnimationSystem run alongside physics to drive motion and skeletal playback.

## Scripting (USC)
- **Data**: `ScriptComponent` holds one or more scripts plus file paths (backward compatible with single-script scenes).
- **Runtime**: `USCSystem` ticks the `USCInterpreter` each frame. Actions are registered in `USCScripting.swift` (math helpers, etc.). Extend the DSL by adding actions to `USCActionRegistry`.

## Scenes, Assets, Resources
- **Scene authoring**: Swift DSL in `Scenes/Builder/` (`Node`/`SceneBuilder`) plus `SceneSerializer` for persistence.
- **Meshes/animations**: abstractions in `Mesh/` and `Skeleton`; resources created through MTK allocators/loaders.
- **Bundled bits**: Prebuilt metallibs per platform and demo resources under `Resources/`.

## Platform Layers
- **XR (visionOS)**: `UntoldEngineXR` ties CompositorServices/ARKit to the core renderer entry.
- **AR (iOS)**: `UntoldEngineAR` wraps MTKView + ARKit for AR mode.
- **Sample**: `Sources/DemoGame` shows system registration and simple gameplay loops.

## Where Contributors Can Make Impact
- **Collision/contact & determinism**: Build the missing collision stack, material/friction models, and deterministic stepping for netcode/replays.
- **Render passes/pipelines**: Add or refine passes in the render graph (effects, optimizations, new pipelines).
- **USC actions & API surface**: Expose new engine capabilities to scripts; add higher-level gameplay helpers.
- **Debug/observability**: Better logging sinks, on-screen overlays, profiling, and error surfacing.
- **New systems/components**: AI utilities, networking hooks, gameplay-specific data—keep components data-only and register them for serialization where relevant.

When proposing big changes, consider ECS storage impact, system ordering, and cross-platform Metal constraints. Align early with maintainers for collision/determinism/netcode-sized work so we keep the architecture cohesive.
