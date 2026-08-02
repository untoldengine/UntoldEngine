# Plugin Architecture

This document defines the boundary between Untold Engine core and external
plugins. Use it when proposing new extension points, creating an official
plugin package, or reviewing code that would otherwise require a plugin to
modify engine internals.

## Goal

Untold Engine should let external packages add substantial features without
forking or patching the core engine.

A plugin-ready engine provides:

- documented public APIs for extension points;
- stable ownership rules for plugin-provided resources;
- predictable lifecycle callbacks;
- cleanup paths for plugin-owned state;
- compatibility expectations between engine and plugin releases; and
- no forced dependency on optional systems.

The core engine remains usable without installing any plugin.

## Core Versus Plugin

The core engine owns stable contracts and shared runtime coordination. Plugins
own optional feature implementations.

Core engine responsibilities:

- define public protocols, registries, lifecycle hooks, and validation rules;
- preserve default behavior when no plugin is installed;
- keep engine-owned data structures internally consistent;
- expose stable insertion points instead of private implementation details;
- provide cleanup and teardown paths;
- document supported extension behavior; and
- keep `Package.swift` free of optional third-party dependencies.

Plugin responsibilities:

- live outside the core engine repository;
- depend on Untold Engine through SwiftPM or the application build system;
- register through public plugin APIs only;
- namespace every public ID and owned resource;
- own optional dependencies, native binaries, shaders, tools, and licenses;
- avoid accessing private engine files or relying on internal pass names; and
- remain removable without leaving engine state behind.

## Repository Model

Use one repository per substantial plugin package.

Examples:

- `UntoldJoltPhysics`
- `UntoldParticles`
- `UntoldVegetation`
- `UntoldFluids`

This keeps optional dependencies truly optional. A project that needs one plugin
should not download unrelated plugin source, native binaries, build scripts, or
third-party license files.

Small samples and tutorials may live in the engine repository under `Examples/`.
Production plugins should live in their own repositories. An optional index or
documentation page may list official plugins, but it should not require all
plugin source code to be consumed as one package.

## Package Layout

Official plugin repositories should use a consistent layout:

```text
UntoldExamplePlugin/
├── Package.swift
├── README.md
├── LICENSE
├── THIRD_PARTY_LICENSES.md
├── Sources/
│   └── UntoldExamplePlugin/
│       ├── UntoldExamplePlugin.swift
│       ├── Resources/
│       └── Shaders/
├── Tests/
│   └── UntoldExamplePluginTests/
└── Scripts/
```

Native plugins may add C, C++, binary-target, or build-script folders, but those
folders stay in the plugin repository.

Native plugin packages should keep three layers distinct:

- a C ABI shim target for native interop;
- a Swift wrapper target that conforms to engine plugin protocols; and
- optional binary artifacts or vendored native source owned by the plugin repo.

The core engine must not import the native shim, link the native library, or
carry the native build scripts.

## Compatibility

Plugins should declare the engine API version they require through the relevant
plugin manifest or documented package requirement.

Compatibility rules:

- engine minor releases may add new plugin APIs;
- engine patch releases should not break existing plugin source;
- public plugin APIs should use additive evolution where possible;
- breaking plugin API changes require a version bump and migration notes;
- plugin repositories should publish which engine versions they support; and
- applications should resolve one Untold Engine package identity and version
  across the app and all plugins.

The engine should prefer default no-op protocol implementations for additive
hooks when that preserves source compatibility.

## ECS Extension Surface

Plugins may define their own `Component` types and register them on entities
through the public ECS helpers. The component mask supports 128 component type
slots so optional packages can add components without immediately exhausting the
core engine's capacity.

Use `registeredComponentTypes()` when diagnosing component ID allocation. IDs are
assigned lazily and are not stable across launches, so plugin code must not
persist or compare raw component IDs as serialized data.

Plugins that need entity-level bookkeeping can subscribe through
`EntityLifecycleEvents.shared.onEntityCreated` and
`EntityLifecycleEvents.shared.onEntityDestroyed`. Component-specific cleanup
should still use `ComponentRegistry.register(...)` because it runs during the
component cleanup phase.

## Current Plugin Surface

Two lifecycle surfaces are currently supported, and every plugin should pick
exactly one:

- `EngineExtension` / `EngineExtensionRegistry` — the base per-frame lifecycle
  contract (`id`, `update`, `fixedUpdate`, `willUnregister`). Use this for
  plugins that do not own a render-graph surface, such as a physics or audio
  backend.
- `RenderExtension` / `RenderExtensionPlugin` — refines `EngineExtension` and
  adds render, compute, shader, argument-buffer, texture, and buffer
  registries, staged render-graph contribution, and owner-scoped validation
  and rollback. Use this for plugins that render, including ones that also
  simulate their own state (for example, a particle or splat system) — a
  `RenderExtension` already receives `update`/`fixedUpdate`/`willUnregister`
  through the base protocol, so there is no separate simulation registration
  step.

A plugin that conforms to `RenderExtension` must register only with
`RenderExtensionRegistry`. Registering the same instance with
`EngineExtensionRegistry` as well would tick it twice per frame.

Both are statically linked Swift packages or frameworks. Neither is a
runtime-loaded binary module.

See [Rendering Extensions Architecture](../Architecture/RenderingExtensions.md),
[Creating a Rendering Extension Plugin](CreatingRenderingExtensionPlugin.md),
and [Creating an Engine Extension Plugin](CreatingAnEngineExtensionPlugin.md).

## Planned Plugin-Readiness Areas

The engine should continue moving private workarounds into documented extension
points. Important areas include:

- render graph stages and dependency rules that support GPU-driven plugins;
- ECS capacity, component diagnostics, and entity lifecycle observation;
- native dependency and shader packaging conventions.

Each area should land as a focused engine milestone with tests and migration
notes. A plugin should not be required to modify core internals to test a normal
feature path.

## Plugin-Owned Spatial Data

Plugins that generate or simulate their own geometry can participate in engine
spatial queries through `PluginSpatialRegistry`.

The registry is intentionally separate from `OctreeSystem`. Engine entities
continue to use the octree path, while plugin providers expose snapshots of
world-space bounds and optional raycast hits through a public contract:

```swift
final class WaterSpatialProvider: PluginSpatialProvider {
    let ownerID = "com.example.water"

    func boundsSnapshot() -> [PluginSpatialBounds] {
        [
            PluginSpatialBounds(
                ownerID: ownerID,
                objectID: "surface.main",
                entityId: waterEntity,
                bounds: currentSurfaceBounds
            )
        ]
    }
}

PluginSpatialRegistry.shared.register(WaterSpatialProvider())
```

If a provider does not implement a custom raycast, the default implementation
uses its AABB snapshot. Plugins that have more precise geometry can return
their own `PluginSpatialHit` values from `raycast(_:options:)`.

`pickPluginSpatialObject(...)` returns plugin hits directly, including objects
that are not backed by an entity. `pickEntity(...)` also considers plugin hits
when a hit provides an `entityId`, preserving the existing entity-based picking
API while letting plugin geometry be selected.

Plugin spatial bounds and hits are expressed in the engine's un-shifted
world-space convention. The public picking helpers handle `SceneRootTransform`
the same way engine entity picking does.

## Plugin Asset Data

Plugin-specific cooked data belongs in plugin extension chunks, not in core
engine tables. The `.untold` container reserves chunk type IDs `>= 0x8000` for
plugin-owned payloads.

Each plugin chunk uses the shared `UntoldPluginChunkEnvelope` header:

```swift
let data = UntoldPluginChunkEnvelope.encode(
    metadata: UntoldPluginChunkMetadata(
        pluginID: "com.example.jolt",
        chunkKind: 1,
        chunkVersion: 3
    ),
    payload: cookedShapeBytes
)
```

At load time, `UntoldReader` exposes these payloads through
`UntoldDecodedAsset.pluginChunks`. The engine validates the envelope and leaves
the payload opaque; the plugin owns decoding, version compatibility, and any
native-library-specific invalidation.

## Review Checklist

Use this checklist when reviewing a plugin-facing engine change:

- Does the change keep default engine behavior unchanged?
- Can a plugin use the feature through public APIs only?
- Are IDs, resources, and cleanup ownership explicit?
- Is the lifecycle ordering documented?
- Does uninstall or failed registration roll back owned state?
- Are XR and multi-view frame semantics clear when relevant?
- Are unsupported capabilities handled with validation, a no-op, or a clear
  diagnostic?
- Does the change avoid adding optional third-party dependencies to core?
- Are examples or tests included for the public contract?
