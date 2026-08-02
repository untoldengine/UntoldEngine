# Plugin Authoring Guidelines

This guide describes how external developers should build plugins for Untold
Engine. It applies to rendering plugins today and to future engine plugin
surfaces as they become public.

## Principles

Plugins should be optional, isolated, and boring to remove.

Follow these rules:

- use public Untold Engine APIs only;
- keep plugin code outside the core engine repository;
- namespace every plugin ID, extension ID, pass ID, pipeline ID, and resource ID;
- register through the engine-provided registry for that plugin type;
- clean up plugin-owned state through documented teardown or cleanup hooks;
- keep third-party dependencies inside the plugin package; and
- document the engine versions the plugin supports.

Do not depend on private engine files, internal pass names, global renderer
state, or implementation details that are not documented as plugin API.

## Naming

Use a reverse-DNS namespace that you control:

```swift
public enum ExamplePluginIDs {
    public static let pluginID = "com.example.water"
    public static let renderExtensionID = "com.example.water.renderer"
    public static let shaderLibraryID = "com.example.water.shaders"
    public static let pipelineID = "com.example.water.surface"
    public static let passID = "com.example.water.surface-pass"
}
```

For plugin-owned render extensions, the extension ID must either equal the
plugin ID or begin with the plugin ID followed by a dot.

## Versioning

Use semantic versioning for plugin releases.

Recommended policy:

- patch releases fix plugin bugs without changing public plugin behavior;
- minor releases add features while preserving source compatibility;
- major releases may require a newer engine version or migration work.

The plugin README should include a compatibility table:

```text
Plugin Version | Untold Engine Version
---------------|----------------------
1.0.x          | 0.8.x
1.1.x          | 0.9.x
```

When the engine exposes a manifest-level API version, the plugin should declare
the exact version it requires.

## Repository Checklist

Every plugin repository should include:

- `README.md` with install, registration, platform, and compatibility notes;
- `Package.swift`;
- `LICENSE`;
- `THIRD_PARTY_LICENSES.md` when dependencies are included;
- source tests for manifest and registration behavior;
- example usage or a small sample app when practical; and
- scripts for repeatable shader or native-binary builds.

Native plugins should also document how generated binaries are rebuilt and which
source revision produced them.

Native plugin repositories should keep the native boundary explicit:

```text
UntoldJoltPhysics/
├── Package.swift
├── Sources/
│   ├── CJoltBridge/          # C ABI shim, POD-only public headers
│   └── UntoldJoltPhysics/    # Swift wrapper and engine protocol conformance
├── Native/
│   └── JoltPhysics/          # vendored source or pinned submodule
├── Binaries/
│   └── Jolt.xcframework      # optional SwiftPM binaryTarget artifact
└── Scripts/
    └── build-native.sh
```

Use a C ABI shim between Swift and C++ libraries. Public shim headers should use
opaque handles, plain data structs, and explicit create/destroy functions. Do
not expose C++ types, templates, exceptions, STL containers, or ownership rules
through the Swift-facing boundary.

Native build scripts should be repeatable from a clean checkout and should
state the source revision, platform slices, deployment targets, and build flags
used to produce each binary artifact.

## Cooked Asset Data

Store plugin-specific cooked data in `.untold` plugin extension chunks when it
needs to travel with an engine asset. Use chunk type IDs `>= 0x8000` and wrap
the payload with `UntoldPluginChunkEnvelope`.

The engine exposes decoded plugin chunks through `UntoldDecodedAsset.pluginChunks`
but does not interpret their payloads. A plugin loader should filter by its
`pluginID`, then validate its own `chunkKind`, `chunkVersion`, backend version,
and native library compatibility before using the bytes.

For native cooked data, include enough plugin-owned metadata to invalidate stale
payloads. For example, a physics plugin should key cooked shapes by backend ID
and backend version because cooked binary blobs are rarely forward-compatible
across native library versions.

## Dependency Policy

Optional dependencies belong in the plugin package, not in Untold Engine core.

This includes:

- native source code;
- C or C++ shim targets;
- `.xcframework` or SwiftPM binary targets;
- build scripts;
- shader build outputs;
- cooked data tools; and
- third-party license files.

For code that may be upstreamed or distributed as an official plugin, prefer
permissive licenses such as MIT, BSD, Zlib, or Apache-2.0. Avoid copyleft
dependencies that are difficult to satisfy in statically linked App Store
deliverables.

Official plugins should not vendor LGPL, GPL, or AGPL dependencies unless the
maintainer has explicitly approved a distribution model that satisfies those
licenses on Apple platforms. Plugin repositories that include third-party code
or binaries must include `THIRD_PARTY_LICENSES.md` with the dependency name,
version or revision, license, source URL, and local artifact path.

## Registration

Plugins should expose a small public registration function. The application
calls that function during setup.

Rendering Extension example:

```swift
@discardableResult
public func registerExamplePlugin()
    -> RenderExtensionPluginInstallationResult
{
    RenderExtensionPluginRegistry.shared.install(ExampleRenderPlugin())
}
```

Do not ask application code to directly register internal extension objects
when the plugin has a package-level registry entry. The plugin registry owns the
complete installation transaction.

Non-rendering plugins register directly with `EngineExtensionRegistry.shared.register(_:)`
instead — there is no equivalent plugin-bundle registry for that surface yet,
so the plugin's public registration function should call it directly and
return the plugin's own type, not an engine-defined installation result.

## Resource Ownership

Plugin resources should be declared through engine registries, not stored in
global side channels.

For rendering plugins:

- declare textures and buffers in `registerResources`;
- declare shader libraries in `registerShaderLibraries`;
- declare pipelines in `registerPipelines` or `registerComputePipelines`;
- declare argument-buffer layouts in `registerArgumentBuffers`; and
- declare graph passes in `buildGraph`.

A render pass may only access resources permitted by the public render-extension
contract. Cross-plugin resource access is unsupported unless a future API
explicitly defines exports and imports.

## ECS Components

Plugins may define components by conforming to `Component`:

```swift
public final class ExamplePluginComponent: Component {
    public var strength: Float = 1

    public required init() {}
}
```

Register plugin components with the public ECS helpers. Do not persist raw
component IDs; they are assigned lazily and are diagnostic only. Use
`registeredComponentTypes()` when debugging ID allocation.

Use `EntityLifecycleEvents` for entity-level bookkeeping:

```swift
let subscription = EntityLifecycleEvents.shared.onEntityDestroyed { event in
    // Release plugin-owned state for event.entityId.
}
```

Keep the returned `EventSubscription` and call `cancel()` when the plugin no
longer needs the callback. Use `ComponentRegistry.register(...)` for
component-specific cleanup.

## Lifecycle

Plugins should assume the engine owns lifecycle ordering.

Every plugin gets the base `EngineExtension` lifecycle, regardless of whether
it renders anything:

- `update(deltaTime:context:)` runs once per engine frame, before graph
  construction and render encoding, regardless of game mode;
- `fixedUpdate(deltaTime:context:)` runs inside the fixed-timestep loop in game
  mode; and
- `willUnregister()` runs before registered plugin state is removed —
  including on `unregister(id:)`, `removeAll()`, and hot-swap replacement
  (registering a new instance under an already-registered `id`).

Use `context.isPrimaryEye` for work that should run once per frame in stereo
XR rather than once per eye.

Rendering plugins additionally receive registration callbacks, staged
graph-build callbacks, and:

- `resourcesDidLoad(_:)`, which runs after registered resources are allocated
  or recreated.

`RenderExtension` refines `EngineExtension` — it does not redeclare `update`,
`fixedUpdate`, or `willUnregister`, it inherits them. A type conforming to
`RenderExtension` must register only with `RenderExtensionRegistry`. It should
never also register with `EngineExtensionRegistry`; doing so would tick its
`update`/`fixedUpdate` twice per frame. A plugin that simulates its own state
and renders it (for example, a particle or splat system) needs only one
registration, with `RenderExtensionRegistry`.

A plugin with no render-graph surface — a physics or audio backend, for
example — conforms to `EngineExtension` directly and registers with
`EngineExtensionRegistry`:

```swift
final class ExamplePhysicsBackend: EngineExtension {
    let id = "com.example.physics"

    func fixedUpdate(deltaTime: Float, context: EngineExtensionUpdateContext) {
        // Advance the simulation.
    }

    func willUnregister() {
        // Release backend-owned state.
    }
}

EngineExtensionRegistry.shared.register(ExamplePhysicsBackend())
```

Until a hook is public and documented, plugin code should not emulate it by
reading private engine state or patching engine internals.

## Spatial Participation

Plugins that own simulated or generated geometry should register a
`PluginSpatialProvider` instead of building private picking stores that
application code has to query separately.

Use `boundsSnapshot()` to expose world-space AABBs for broad spatial queries.
If AABB picking is accurate enough, rely on the default `raycast(_:options:)`
implementation. If the plugin owns more precise geometry, override
`raycast(_:options:)` and return sorted `PluginSpatialHit` values.

Attach `entityId` to `PluginSpatialBounds` or `PluginSpatialHit` when the
plugin object should participate in existing entity-based picking through
`pickEntity(...)`. Leave `entityId` nil for plugin-only objects and query them
with `pickPluginSpatialObject(...)`.

Unregister the provider during plugin teardown:

```swift
func willUnregister() {
    PluginSpatialRegistry.shared.unregister(ownerID: ExamplePluginIDs.pluginID)
}
```

Do not register plugin geometry directly into `OctreeSystem`; that remains an
engine-owned spatial index for ECS render entities.

## Testing

At minimum, a plugin should test:

- manifest validation;
- duplicate ID rejection;
- successful registration;
- uninstall or replacement behavior when supported;
- shader or native resource lookup;
- platform-specific resource selection; and
- compatibility with the documented Untold Engine version.

Engine-side plugin-readiness changes should include tests that prove a sample
external plugin can use the new public contract without internal access.

## Before Requesting Engine Changes

When a plugin needs a new engine extension point, describe:

- the plugin use case;
- which private engine behavior the plugin currently needs;
- the smallest public API that would remove that private dependency;
- lifecycle and threading expectations;
- cleanup behavior;
- failure behavior; and
- tests that would validate the contract.

The engine should add extension points only when they serve a concrete plugin
need and can be documented as stable public behavior.
