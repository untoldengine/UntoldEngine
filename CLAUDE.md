# CLAUDE.md — Untold Engine

Guidance for Claude Code when working in this repository: either developing the engine itself, or helping a developer build a game or application on top of it. Read [Step 0](#0-which-mode-am-i-in) first — the rules differ.

## 0. Which mode am I in?

- **Engine development**: changes inside this repo (`Sources/UntoldEngine`, `Sources/UntoldEngineXR`, `Sources/UntoldEngineAR`, `Sources/UntoldComponentKit`, `Tools/`, `Tests/`). Follow [§6 Coding Conventions](#6-coding-conventions) and [§8 Build and Validation](#8-build-and-validation) strictly.
- **Application development**: building a game/app that depends on the `UntoldEngine` Swift package (own repo, own `Package.swift`). Use only the public, documented APIs described in [§4](#4-application-development) and `docs/API/`. Never reach into engine internals.

## 1. Engine Overview

Untold Engine is an **open-source Swift + Metal engine for Apple platforms** (macOS, iOS, visionOS), built for developers who want full control over rendering, physics, and input without a general-purpose editor-first workflow (RealityKit/Unity/Unreal idioms do **not** apply here — verify every API against this repo before assuming it exists).

- **Language**: Swift 6 (strict concurrency, `swiftLanguageMode(.v6)` everywhere) for engine/app code; **Metal** for GPU rendering and compute.
- **Graphics**: Metal, custom render-graph renderer (no SceneKit/RealityKit dependency).
- **Platforms**: macOS 14+, iOS 17+, visionOS 2+ (per `Package.swift`). A separate, non-Swift-Package **Untold Editor** app exists (`untoldengine studio`, downloaded separately) for visual scene editing — this repo is the engine + CLI, not the editor.
- **Distinguishing design choice**: the public API is largely **free functions operating on an `EntityID`** (e.g. `createEntity()`, `translateTo(entityId:...)`, `setEntityMesh(entityId:...)`), not an object-oriented entity class hierarchy. Don't invent `Entity` methods — look up the matching free function instead.

## 2. Repository Architecture

| Area | Path | What's there |
|---|---|---|
| Engine core | `Sources/UntoldEngine/` | ECS, rendering, physics, animation, scripting — see table below |
| Shared GPU types | `Sources/CShaderTypes/` | C header (`ShaderTypes.h`) defining struct layouts shared by Swift and Metal — the Swift/Metal data bridge |
| visionOS | `Sources/UntoldEngineXR/` | `UntoldEngineXR.swift` — CompositorServices/ARKit-based XR runtime, separate from the MTKView path |
| iOS AR passthrough | `Sources/UntoldEngineAR/` | `UntoldEngineAR.swift` — ARSession/MTKView wrapper for iPhone/iPad passthrough AR |
| Code components | `Sources/UntoldComponentKit/` | `ComponentPlugin`/`EntityPlugin`/`EditorMenuPlugin` base classes, `@UntoldAttribute` reflection, used by the Editor and by code-only projects |
| Cook-time mesh tools | `Sources/UntoldEngineMeshCook/` | LOD-chain generation via `CMeshOptimizer` (vendored meshoptimizer); used by the CLI/Editor, not by runtime apps |
| Demos | `Sources/Demos/*` | Working, runnable example apps — the best ground truth for "how do I actually wire this up" (see [§4](#4-application-development)) |
| CLI | `Tools/UntoldEngineCLI/` | Separate SwiftPM package; `untoldengine` tool: `create`, `update`, `export`, `gaussian-link`, `studio` |
| Tests | `Tests/UntoldEngineTests`, `Tests/UntoldEngineRenderTests`, `Tests/UntoldComponentKitTests` | Unit tests and image-diff render tests |
| Docs | `docs/API/`, `docs/Architecture/`, `docs/Tutorials/`, `docs/Onboarding/`, `docs/Extensions/` | Authoritative usage docs — see [§9](#9-documentation-and-examples) |

Inside `Sources/UntoldEngine/`:

| Subdir | Contains |
|---|---|
| `ECS/` | Entity id packing (`Entity.swift`), world storage (`Scenes.swift`), `ComponentRegistry.swift`/`ComponentPool.swift` |
| `Systems/` | The bulk of the public API: `RegistrationSystem.swift` (entity/mesh/light/animation/LOD/batching/gaussian registration — the biggest file in the engine), `ScenegraphSystem.swift`, `CameraSystem.swift`, `LightingSystem.swift`, `LightPortalSystem.swift`, `InputSystem.swift` (+ platform extensions), `RenderingSystem.swift` |
| `Renderer/` | `UntoldEngine.swift` (the `MTKViewDelegate`, per-frame driver), `RenderPasses.swift`, `PostProcessRenderPasses.swift` |
| `Shaders/` | One `.metal` file per effect (`modelShader.metal`, `LightShader.metal`, `Gaussians.metal`, `HZBCompute.metal`, ...) |
| `UntoldEngineKernels/` | `UntoldEngineKernels.metal` — umbrella file that `#include`s everything in `Shaders/`; this is what actually gets compiled (see [§8](#8-build-and-validation)) |
| `Mesh/` | `Mesh.swift` — `Material` struct, mesh/submesh data model |
| `AssetFormat/` | `UntoldFormat.swift` — the `.untold` binary container schema |
| `RuntimeAssets/` | Asset loaders: `RuntimeAssetLoader.swift`, `NativeFormatLoader.swift`, `GaussianChunkLoader.swift`/`GaussianPageManager.swift` (Gaussian-splat paging), `NativeTextureLoader.swift` |
| `Physics/` | `PhysicsCoordinator.swift`, `PhysicsBackend.swift`/`PhysicsBackendRegistry.swift` (pluggable backend layer), `PhysicsComponents.swift` |
| `Animation/` | Skeletal animation, pose layers, root motion |
| `Scripting/` | USC (Untold Scripting) — data-driven, serializable behavior scripts, distinct from `UntoldComponentKit` |
| `Profiling/`, `Utils/`, `BuildSystem/`, `Resources/` | Supporting infrastructure |

## 3. Core Development Concepts

- **Entities are `EntityID`s, not objects.** `createEntity() -> EntityID` (`RegistrationSystem.swift`); `destroyEntity(entityId:)` tears it down. Creating an entity auto-attaches transform + scenegraph components via an internal `makeSpatial` call — you don't attach those yourself.
- **Components are attached by dedicated `registerXComponent`/`setEntityX` functions**, not by `entity.addComponent(...)`. Every component type has a matching `removeEntityX` teardown function invoked by `destroyEntity`; when adding a new system that introduces a component, you must register a cleanup handler with `ComponentRegistry` or a debug assertion fires.
- **Transforms**: `translateTo`/`translateBy`, `rotateTo(angle:axis:)`/`rotateTo(rotation:)`, `rotateBy`, `getPosition`/`getLocalPosition`, `getOrientation`/`getLocalOrientation` (`docs/API/UsingTransformSystem.md`, matches source exactly). Scene-root-level batch operations (`translateSceneTo/By`, `rotateSceneToYaw/ByYaw`) exist separately — don't apply them per-entity.
- **Scene graph / parenting**: `setParent(childId:parentId:offset:)`, `removeParent(childId:)`, `getEntityChildren(parentId:)`, `getEntityParent(entityId:)` (`ScenegraphSystem.swift`). Use these instead of inventing a transform hierarchy yourself.
- **Materials**: `Material` struct (`Mesh.swift`) has fixed PBR slots — `baseColor, roughness, metallic, normal, emissive, height`. Change them via accessor functions keyed by `entityId`/`meshIndex`/`submeshIndex` (`getMaterialBaseColor`, `updateMaterialColor`, `updateMaterialRoughness`, ...) documented in `docs/API/UsingMaterials.md`. Setters auto-refresh static batching — don't bypass them by poking texture fields directly.
- **Lighting**: four light types only — `createDirLight`, `createPointLight`, `createSpotLight`, `createAreaLight`. Shared getters/setters (`updateLightColor`, `updateLightIntensity`, `updateLightAttenuation`, per-type shadow toggles). Light portals are a separate system (`LightPortalSystem`, `docs/API/UsingLightPortals.md`) for interior/exterior light leaking — not a light type.
- **Camera**: `createGameCamera(entityId:)`, `findGameCamera()`, movement (`moveCameraTo/By`, `cameraMoveBy(..., space:)`), orbit (`orbitAround`, `setOrbitOffset`), `cameraLookAt(eye:target:up:)`, follow modes (`cameraFollow`, `cameraFollowDeadZone`), and waypoint paths (`startCameraPath(waypoints:mode:settings:)`).
- **Assets and the `.untold` format**: the native binary asset container is `.untold` (schema: `docs/Architecture/assetFormat.md`, `AssetFormat/UntoldFormat.swift`). Sync load: `setEntityMesh(entityId:filename:withExtension:assetName:)` (`.untold` only). Async/other formats: `setEntityMeshAsync(...)`. Direct in-memory meshes: `setEntityMeshDirect(entityId:meshes:assetName:)`. Animations: `setEntityAnimations(entityId:filename:withExtension:name:)`. Gaussian splats (`.untoldgs`): `setEntityGaussian`/`setEntityGaussianAsync`. Assets resolve against a base path set via `setEngine(.assetBasePath(url))`.
- **Rendering is a render graph, driven once per frame.** `UntoldEngine` (`Renderer/UntoldEngine.swift`) is an `MTKViewDelegate`; `draw(in view:)` calls `UpdateRenderingSystem(in:)` (`Systems/RenderingSystem.swift`), which executes a graph of passes (`gBufferPass`, shadow pass, `postProcessingEffects`, Gaussian pass) built by `buildGameModeGraph()`/`buildExecutableGameModeGraph()`. Hook your own per-frame logic via `setupCallbacks`/`onUpdate(_:)` — never call `draw` yourself or fight the render graph.
- **visionOS uses a different runtime entirely.** `UntoldEngineXR` wraps a CompositorServices `LayerRenderer` directly (no `MTKView`); it owns its own frame loop (`runLoop()`), foveation, and device-anchor handling. Don't assume macOS/iOS rendering code paths apply on visionOS.
- **Two parallel behavior systems, not interchangeable**: USC (`Scripting/`) is data-driven/serializable (`.usc` files, built with `USCBuilder`, run by `USCInterpreter`) — use for designer-editable logic. `UntoldComponentKit` (`ComponentPlugin`/`EntityPlugin`) is compiled Swift logic with `@UntoldAttribute`-exposed properties — use for engine-level reusable behavior. USC scripts can call component-plugin actions via `script.callAction("<TypeName>.<ActionName>")`; the reverse is not true.
- **Extensibility**: `EngineExtension`/`EngineExtensionRegistry` for non-rendering per-frame plugins (physics/audio/AI backends); `RenderExtension`/`RenderExtensionRegistry` (refines `EngineExtension`) for render-graph-contributing plugins (particles, custom surfaces). Register with exactly one of the two, never both. For single-app gameplay code that doesn't need to be distributable, use the lighter `registerCustomSystem(_:)` closure hook instead of either protocol. Physics follows this same two-layer pattern: a built-in dependency-free kinetics layer (`setEntityKinetics`, `applyForce`, `setLinearVelocity`) always works; rigid-body/collider physics (`RigidBodyComponent`, `ColliderComponent`) only does anything once an external backend (e.g. Jolt) registers via `PhysicsBackendRegistry` — Jolt itself is not vendored in this repo.

## 4. Application Development

Two supported project-creation paths, both producing the same kind of Xcode-buildable package (`docs/Onboarding/GettingStartedMakingGamesCLI.md`, `GettingStartedWithEditor.md`):

- **CLI-first**: `untoldengine create MyGame --platform macos|ios|ios-ar|visionos|multi` (install the CLI first — see [§8](#8-build-and-validation)). Generates `Package.swift`, `Sources/<Name>/{AppDelegate,GameScene,...}.swift`, `GameData/{Scenes,Scripts,Models,Textures,Shaders}`.
- **Editor-first**: `untoldengine studio` installs/launches the separate Untold Editor app for visual placement; still backed by the same code underneath. The Editor is optional — everything it does can be done in code.

**Reference the demos, not your assumptions.** `Sources/Demos/StarterDemo` is the smallest complete macOS example and the best starting point to read end-to-end:
- `main.swift` creates `NSApplication`, assigns an `AppDelegate`.
- `AppDelegate.swift` (`NSApplicationDelegate`, `@MainActor`) creates an `NSWindow`, calls `UntoldRenderer.create()`, wires `setupCallbacks(gameUpdate:handleInput:)`, and hosts the engine-provided `SceneView(renderer:)` via `NSHostingView`. You do not write your own render loop or `MTKView` on macOS/iOS — the engine owns it.
- `GameScene.swift` is where application code lives: calls free functions directly (`createEntity()`, `setEntityName`, `setEntityMeshAsync`, `translateTo`, `updateMaterialColor`, `rotateBy`, `setSceneReady(true)`).

Other demos for specific features: `ShowcaseDemo`, `LargeSceneStreamingDemo` (tile streaming, large outdoor scenes), `InteractionGameplayDemo` (input/picking), `RenderingQualityDemo` (post-FX/quality settings), `LightingDemo`, `ExporterPipelineDemo` (asset pipeline), `Sandbox`. Run any of them with `swift run <DemoName>` (macOS only; all are hidden, non-published package products, runnable only within this repo during development).

**Asset pipeline**: author in Blender → `untoldengine export` converts USD/USDZ to `.untold` (background Blender process, documented in `docs/API/UsingTheExporter.md` and `docs/API/UsingBlenderAddon.md`). Do not hand-author `.untold` files.

## 5. Platform-Specific Considerations

| Platform | Lifecycle | Module | Notes |
|---|---|---|---|
| macOS | `NSApplication` + `AppDelegate` + `UntoldRenderer`/`SceneView` (MTKView-backed) | `UntoldEngine` | Full input (`InputSystem+Keyboard.swift`, `+Mouse.swift`), game controller support |
| iOS | Same MTKView-backed pattern as macOS, UIKit host | `UntoldEngine` (+ `UntoldEngineAR` for passthrough) | `UntoldEngineAR`'s `UntoldEngineAR` class wraps an app-supplied `ARSession`/`MTKView` for camera-passthrough AR (YCbCr textures), separate from visionOS |
| visionOS | `ImmersiveSpace`/`CompositorLayer` hands a CompositorServices `LayerRenderer` to `UntoldEngineXR`, which runs its own frame loop | `UntoldEngineXR` | No `MTKView`. Uses ARKit for world tracking/anchors. Immersion modes via `setImmersionMode(.none/.mixed/.full)`. XR-specific lighting (`setXRLightingMode`) and spatial input (`enqueueSpatialInputSnapshot`) are distinct APIs — see `docs/API/UsingXRImmersionMode.md`, `docs/API/UsingSpatialInput.md`, `docs/API/VisionProRenderingProfile.md` |

Build-system gating mirrors this: `VISIONOS_AVAILABLE` / `AR_AVAILABLE` compile flags (`Package.swift`) gate CompositorServices/ARKit-only code. Never assume ARKit or CompositorServices symbols are available outside their `#if` guards.

## 6. Coding Conventions

Read [`ENGINEERING_PRINCIPLES.md`](ENGINEERING_PRINCIPLES.md) (mirrored at `docs/Contributor/EngineeringPrinciples.md`) for the project's ten governing principles — reliability first, fail gracefully with diagnostics, keep the engine always buildable, favor simple architecture over speculative abstraction, protect public API compatibility, measure before optimizing, etc. The conventions below are the concrete application of those principles to day-to-day code changes.

- Swift 6, strict concurrency (`swiftLanguageMode(.v6)`). Respect `@MainActor`/`Sendable` boundaries already present — don't silence concurrency errors by adding `@unchecked Sendable` or removing actor isolation.
- Follow the free-function, `EntityID`-keyed API style for anything exposed to application code — do not wrap engine state in new classes "for convenience."
- Format/lint with `swiftformat` (pinned version `0.60.1`, `--swiftversion 5.8`): `make format` / `make lint`. Run before considering engine-side work done.
- New engine systems require unit tests **and** a how-to markdown doc under `docs/API/` (per `docs/Contributor/ContributionGuidelines.md`); small fixes are exempt.
- Optional native/third-party dependencies (e.g. a physics backend) belong in a separate plugin repo, never added to this package's `Package.swift` — see the extension architecture in [§3](#3-core-development-concepts) and `docs/Extensions/PluginArchitecture.md`.
- One feature/fix per PR; meaningful commit messages (there is a commit-message-prefix hook).

## 7. Common Pitfalls

- **Editing a `.metal` file and only running `swift build`.** `swift build` never invokes the Metal compiler; the engine ships prebuilt `.metallib` resources. You must rerun `./buildkernels.sh` after any shader change, or the app/tests silently run the stale shader binary ([§8](#8-build-and-validation)).
- **Reaching into Mesh/Material internals instead of using accessor functions.** Setters like `updateMaterialColor` do bookkeeping (static-batch refresh) that direct field mutation skips.
- **Assuming RealityKit/SceneKit/Unity-style APIs exist.** They generally don't. Grep the actual source or an existing demo before using an API you haven't verified in this repo.
- **Writing a custom render/update loop on macOS/iOS.** The engine's `UntoldRenderer`/`MTKViewDelegate` already owns `draw(in:)`; hook per-frame logic through `setupCallbacks`/`onUpdate(_:)` instead.
- **Treating visionOS code as a variant of the macOS/iOS path.** `UntoldEngineXR` is a structurally different runtime (no `MTKView`, its own frame loop) — don't port MTKView-based patterns there uncritically.
- **Registering a new component without a cleanup handler.** `destroyEntity` relies on every component type having a registered cleanup function; skipping this leaks state or trips a debug assertion.
- **Mixing `EngineExtension` and `RenderExtension` registration for the same plugin type**, or reaching for either when a simple `registerCustomSystem(_:)` closure would do for app-local code.
- **Touching SwiftUI/UIKit state from `UntoldComponentKit` lifecycle callbacks** (`onUpdate`, `onFixedUpdate`, etc.) — they run on the engine's simulation thread (main thread on macOS/iOS, the compositor render thread on visionOS), not necessarily the UI thread.
- **Hand-authoring or hand-editing `.untold`/`.untoldgs` files.** These are generated by the exporter/cook pipeline; author source assets in Blender and export instead.

## 8. Build and Validation

Run from the repository root (verified against `Makefile`, `buildkernels.sh`, `Package.swift`):

```bash
swift build                      # build the engine package
sh ./buildkernels.sh             # rebuild all platform .metallibs — REQUIRED after any .metal edit
swift test                       # all tests
swift test --filter UntoldEngineTests          # unit tests only (make testcore)
swift test --parallel --num-workers 4 --filter UntoldEngineRenderTests   # image-diff render tests (make testrenderer; needs opencv-python-headless + scikit-image)
swift run StarterDemo            # run a demo (macOS only); also ShowcaseDemo, LargeSceneStreamingDemo, InteractionGameplayDemo, RenderingQualityDemo, LightingDemo, ExporterPipelineDemo, Sandbox
make lint / make format          # swiftformat check / apply
make testrenderer                # tests engine renderer
make testcore                    # tests engine core
```

Notes:
- Two render-test classes (`AsyncMeshLoadingTest`, `AssetLoadingGateRenderingTests`) hang under parallel workers — run them with `make testrenderer-async` (serial, `--disable-swift-testing`), matching CI.
- CLI tool: install with `./scripts/install-untoldengine-create.sh` (installs to `/usr/local/bin/untoldengine`). **The installed CLI runs its own compiled copy, not this repo's live source** — if you edit `Tools/UntoldEngineCLI`, reinstall before testing CLI behavior.
- pre-commit hooks run `testexporter`/`testcore`/`testrenderer` and `swiftformat --lint` on staged files; don't bypass with `--no-verify` unless the user explicitly asks.

## 9. Documentation and Examples

- `docs/API/` — one file per subsystem (`UsingTransformSystem.md`, `UsingMaterials.md`, `UsingLightingSystem.md`, `UsingPhysicsSystem.md`, `UsingScriptingSystem.md`, `UsingCodeComponents.md`, etc.) — the primary source for API usage beyond this file.
- `docs/Architecture/` — deep-dive design docs (render graph, asset format, streaming, batching, LOD). Note: `docs/Architecture/animationPoseLayer.md` is known to be stale (pre-dates a later pose-layer redesign) — verify animation pose-layer claims against source, not that doc.
- `docs/Tutorials/`, `docs/Onboarding/` — step-by-step walkthroughs for specific demos and first-project setup.
- `docs/Extensions/` — plugin/extension authoring guides.
- `Sources/Demos/*` — the most reliable "does this actually work" reference; prefer reading a demo over inferring usage from a doc alone.
- `.claude/skills/` — task-specific Claude Code skills for application developers: `untold-entity-scene` (scene/entity/material/light/camera work), `untold-new-project` (scaffolding a new project with the CLI), `untold-asset-pipeline` (Blender → `.untold`/`.untoldgs` export). These load automatically when relevant; read one directly if you want the condensed, example-grounded version of a section above.
- `Examples/RenderingExtensions/`, `Examples/CodeComponents/` — standalone worked examples of the extension and code-component systems.

## 10. Rules for AI-Generated Code

- Prefer existing public engine APIs over implementing duplicate functionality.
- Never invent engine classes, methods, components, or configuration options. If unsure an API exists, grep `Sources/UntoldEngine` and check `docs/API/` before using it.
- Inspect existing source or a working demo before using an unfamiliar API.
- Follow the engine's free-function/`EntityID` architecture and the conventions in [§6](#6-coding-conventions).
- Swift for engine/application code, Metal for GPU work — unless a subsystem already requires something else (e.g. Python for exporter tooling).
- Respect the platform-specific lifecycle in [§5](#5-platform-specific-considerations); don't port macOS/iOS render-loop patterns to visionOS or vice versa.
- Respect concurrency annotations, GPU/render-graph synchronization, and component/resource lifetime rules in [§7](#7-common-pitfalls).
- Avoid unnecessary architectural changes when implementing an application feature — extend, don't restructure.
- Prefer small, verifiable changes over large speculative implementations.
- Clearly distinguish verified engine functionality (found in source/docs) from proposed or unsupported features in any explanation you give the user.
- Validate changes using the commands in [§8](#8-build-and-validation) whenever possible, including rebuilding shaders after any `.metal` edit.
