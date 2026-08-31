# Rendering Extensions Architecture

This document explains how Rendering Extensions are represented, registered,
compiled, validated, and executed inside Untold Engine. For authoring and
consumer examples, see [Using Rendering Extensions](../API/UsingRenderingExtensions.md).
For a task-oriented introduction, see
[Creating a Rendering Extension Plugin](../Extensions/CreatingRenderingExtensionPlugin.md).
If you're deciding whether a change needs a Rendering Extension at all, and
if so which shape it needs, start with
[Understanding Rendering Extensions](../Extensions/UnderstandingRenderingExtensions.md)
before reading the mechanics below.

## Design Goals

Rendering Extensions provide optional rendering features without exposing the
engine's private render-pass implementation. The architecture is designed to:

- preserve a valid engine graph when an extension fails;
- isolate independently developed providers;
- keep extension resource and pipeline ownership explicit;
- provide stable insertion points without exposing built-in pass names;
- avoid raw Metal binding-slot collisions in model-surface shaders;
- compile mutable declarations into one deterministic executable graph;
- support application-local extensions and distributable package plugins.

## Public Layers

The system has two lifecycle layers.

### `RenderExtension`

`RenderExtension` is the unit of rendering behavior. It owns one stable ID and
may contribute:

- shader libraries;
- texture and buffer declarations;
- argument-buffer layouts;
- render and compute pipelines;
- staged graph passes;
- once-per-frame update work;
- fixed-step simulation work; and
- teardown or resource-refresh handling.

Only `id` and `buildGraph` are required. The registration and lifecycle hooks
have default no-op implementations.

Application-local extensions register directly through `RenderExtensionRegistry`
or the `setRendering` facade.

### `RenderExtensionPlugin`

`RenderExtensionPlugin` is a statically linked package or framework contract
above one or more extensions. Its manifest declares:

- a namespaced plugin ID;
- a display name;
- a semantic release version;
- the exact Rendering Extension API version it requires.

The plugin factory creates all extensions supplied by that module. Installation,
replacement, and removal treat the complete set as one transaction.

Plugins are not runtime-loaded binaries. SwiftPM or the application build system
links their modules into the application before launch.

## Identity and Ownership

Extension-owned artifacts are tracked by owner ID. IDs are global within each
artifact domain:

- render passes;
- shader libraries;
- textures and buffers;
- render and compute pipelines;
- argument-buffer layouts.

Providers must namespace IDs because registration rejects an artifact already
owned by another extension or by the engine.

Resources are owner-private. A pass may access only a resource declared by the
same extension. Knowing another provider's resource ID does not grant access.
Cross-extension exports and imports are not part of the current contract.

Plugin extension IDs must equal the plugin ID or begin with the plugin ID plus a
dot. This lets the registry validate ownership before mutating renderer state.

## Registration Lifecycle

Registration is serialized so graph construction cannot observe a partially
installed or removed extension.

For a standalone extension, the engine:

1. records the extension ID and checks plugin ownership conflicts;
2. collects and validates argument-buffer layouts;
3. resolves shader libraries and creates pipelines when Metal is already ready;
4. collects and validates resource declarations, committing them only if all
   currently available artifact registration succeeded;
5. retains the extension for staged graph contribution;
6. materializes deferred shader and pipeline declarations after Metal becomes
   ready;
7. removes all newly created artifacts if any required registration fails.

Resources can be declared before a Metal device or valid viewport exists. Their
state begins as `declared` and transitions to `allocated` when allocation is
possible. Failed allocation moves a resource to `invalidated`; a later refresh
can retry it. Unregistration moves owned resources to `released` and removes
their backing objects.

When extension resources are committed and allocated, or when viewport-sized
resources are recreated, the engine calls `resourcesDidLoad(_:)`. Extensions
that cache Metal resource handles should refresh those handles from the supplied
`RenderResourceAccess`.

A same-ID standalone registration is a replacement transaction. The previous
extension and its artifacts are restored if the replacement fails.

## Plugin Transactions

Plugin installation starts with pure manifest validation. Validation checks API
compatibility, plugin and extension namespaces, empty declarations, and duplicate
identities without registering anything.

After validation, `RenderExtensionPluginRegistry` installs each supplied
extension under the shared lifecycle lock. If any extension fails:

- earlier siblings from that installation are removed;
- partial resources and pipeline artifacts are released;
- a failed replacement restores the previous plugin and extension order;
- one structured plugin failure records the contributing errors.

Uninstalling a plugin removes every artifact owned by all its extensions.
Attempting to unregister one plugin-owned extension through the standalone
registry removes its complete owning plugin, preserving the package transaction
boundary.

Before an extension is removed, replaced, or rejected by validation after it was
registered, the engine calls `willUnregister()`. The callback is the supported
place to release plugin-owned CPU-side state that is not stored in engine
registries.

## Frame Lifecycle

Each registered extension receives `update(deltaTime:context:)` once per engine
frame before graph construction and render encoding. The context includes:

- viewport;
- immersion style;
- monotonic frame index;
- current eye; and
- `isPrimaryEye`.

`isPrimaryEye` is true for non-stereo rendering and for eye 0 in stereo XR. Use
it for work that must run once per frame instead of once per eye.

In game mode, registered extensions also receive
`fixedUpdate(deltaTime:context:)` inside the fixed-timestep loop after built-in
physics and before legacy custom systems. The fixed delta time is the engine
simulation step.

## Shader and Pipeline Packaging

Shader registration is independent from pipeline creation. An extension can:

- supply an existing `MTLLibrary`;
- load a bundle's default library;
- resolve a precompiled metallib by bundle-relative resource name or URL.

Package code resolves `Bundle.module` internally and passes that bundle to the
shader registry. The consumer does not access the package bundle directly.

Render and compute pipeline descriptors are preflighted before Metal creation.
Validation resolves referenced libraries and functions, checks render-target
formats and argument-layout dependencies, and detects duplicate IDs. Creation
errors participate in the same extension or plugin transaction.

Pipeline materialization may be deferred until the renderer has a Metal device.
A deferred failure removes the owning standalone extension or complete plugin.

Scene pipelines are a specialization of the same descriptor and ownership
path. `registerScenePipeline` supplies the current working scene-color and depth
formats internally, while leaving shader libraries, vertex layout, depth
comparison and writes, reverse-Z conversion, and blending under extension
control. This prevents package code from coupling itself to platform drawable
or engine attachment formats.

## Model-Surface Argument Isolation

Engine model drawing already occupies low Metal texture, sampler, and buffer
slots. Allowing extensions to bind arbitrary raw indices would let two providers
or an extension and the engine overwrite each other's bindings.

Model-surface extension shaders instead receive one fixed
`UntoldModelSurfaceExtensionArguments` argument buffer at the engine-owned
`UntoldModelSurfaceExtensionArgumentBufferIndex`.

The outer Metal slot is shared by the ABI, but every draw binds only the active
pipeline's encoded argument buffer. Members such as `texture0`, `sampler0`, and
`buffer0` are local IDs within that buffer. A water extension and a grass
extension can therefore use the same local member IDs without sharing Metal
resource slots.

`RenderExtensionArgumentBufferDescriptor` records which local members an
extension uses. The engine validates the referenced layout, creates an encoder
from the pipeline reflection data, encodes per-entity values, makes referenced
resources resident, and binds the resulting buffer before drawing.

The fixed shader ABI contains the complete local ranges:

- textures `0...7`;
- samplers `8...15`;
- buffers `16...31`.

Registered layouts identify active members and access requirements; they do not
change the fixed ABI structure size.

## Staged Graph Contribution

Extensions do not create raw engine `RenderPass` values or name built-in pass
dependencies. `RenderGraphBuilder` exposes stable stage anchors instead:

```swift
.frameStart
.beforeShadows
.afterOpaqueLighting
.beforeTransparency
.afterTransparency
.beforePostProcess
.afterPostProcess
.beforeComposite
.beforeLook
.beforeOutput
```

Early stages are intended for setup work. `.frameStart` runs before built-in
scene rendering begins. `.beforeShadows` runs after any scene background pass and
before shadow rendering.

During graph construction, each extension receives an owner-scoped builder.
Staged pass declarations are collected with their owner, resource usages, and
execution closure. Pass IDs are checked against other providers and reserved
engine IDs. A conflict discards that extension's complete staged contribution.

When the engine resolves a stage, it inserts its pending passes after the stage
anchor. Passes retain registration order within the same stage, producing an
explicit dependency chain.

Extensions may declare explicit dependencies only through
`RenderGraphPassDependency`. A pass can depend on an earlier pass owned by the
same extension with `.sameExtension("pass-id")`, or on one of the documented
engine dependency targets:

```swift
.engine(.sceneDepth)
.engine(.opaqueLighting)
.engine(.sceneComposite)
```

Raw built-in pass IDs and cross-extension dependencies are not public contract.
Invalid dependencies reject the extension's staged contribution.

Pass closures do not execute during registration or graph construction. They are
captured for later command encoding.

The executable pass context retains its stable stage and supplies read-only
camera and pipeline capabilities. Camera state is captured when each pass
executes, after the renderer has installed the current eye's view and projection
matrices. The view includes the scene-root transform, view-projection uses
`projection * view`, and world position is derived from the inverse effective
view. Render and compute pipeline accessors are lookup-only and preserve the
existing owner-controlled registration and cleanup lifecycle.

`RenderPassContext` also carries `deltaTime`, `frameIndex`, `currentEye`, and
`isPrimaryEye` so pass closures can avoid private frame counters and hand-written
XR eye guards.

Scene render-target access is a capability rather than a public render-pass
descriptor. It is defined only for the scene-color portion of the graph:
`afterOpaqueLighting`, `beforeTransparency`, `afterTransparency`, and
`beforePostProcess`. Encoder creation at later post-processing, composite, look,
or output stages is rejected because those stages do not guarantee compatible
working scene color and depth targets. The capability copies and configures the
engine descriptor; mutable `renderInfo` state is never exposed. Only ordinary
load actions and store-or-discard actions are accepted. Resolve actions are
rejected because the capability operates on the resolved, single-sample scene
attachments. Missing or mismatched color/depth targets also reject encoder
creation. A new context is built during each eye's graph execution, so the
copied attachments follow the active XR eye without exposing compositor targets.

## Resource Access Declarations

Each staged pass declares typed texture and buffer access. Construction checks:

- the resource exists;
- the pass owner owns it;
- the descriptor supports the requested Metal usage;
- the pass does not request an invalid access combination.

The pass context is capability-scoped. It exposes only resources listed in that
pass declaration, so an undeclared lookup returns `nil` even when the extension
owns the resource.

Typed declarations also provide the input used by hazard scheduling and lifetime
analysis.

## Graph Compilation Pipeline

After all built-in and extension stages have been resolved, the mutable graph is
compiled into an immutable `CompiledRenderGraph`.

### 1. Declaration Validation

Compilation first reports missing pass dependencies and invalid resource
declarations. If dependencies are complete, it topologically sorts the explicit
and stage-generated graph. Dictionary insertion order does not affect the result.

### 2. Resource-Hazard Scheduling

For each typed resource, compilation merges a pass's declarations and derives
ordering constraints for:

- read after write (RAW);
- write after read (WAR);
- write after write (WAW);
- render-target writes followed by shader access.

Inferred dependencies are stored separately from author-declared dependencies
for diagnostics. The scheduler never removes or reverses an explicit or stage
edge. If an explicit order contradicts required resource flow, validation reports
the conflict rather than silently changing author intent.

Resources with no graph writer remain valid because persistent data may be
initialized outside graph execution.

### 3. Whole-Graph Validation

The scheduled graph is sorted again and checked as a whole. Every reader of a
graph-written resource must be the writer or depend on a writer, and every pair
of writers must have a dependency path ordering them.

Diagnostics retain extension ownership so a failing provider can be isolated.

### 4. Immutable Executable Graph

A valid graph becomes an immutable ordered array and ID lookup table. Each
compiled pass snapshots:

- explicit and inferred dependencies;
- typed resource usage;
- extension ownership;
- stable stage;
- execution closure.

Frame encoding iterates this ordered array. It does not sort or reinterpret the
mutable builder state again.

### 5. Resource Lifetime Plan

Compilation records the first and last execution index for every used declared
resource. Persistent resources are never alias candidates.

Resources marked `.transient` receive deterministic alias-slot assignments when
all of these conditions hold:

- their execution intervals do not overlap;
- they have the same owner;
- they have the same resource kind;
- their allocation-relevant descriptor properties match.

This is currently planning metadata. The registry still allocates one Metal
resource per declaration; physical backing-store aliasing is not enabled.

### 6. Optimization Audit

The compiled graph stores a non-destructive optimization report containing:

- pass and dependency counts;
- explicit and inferred dependency counts;
- persistent and transient resource counts;
- alias-slot and potential backing-store reduction counts;
- unused resource declarations;
- direct dependency edges already covered by another path;
- resource-plan consistency issues.

The audit does not remove passes, dependencies, or resources. Safe pass culling
requires explicit output-root and side-effect contracts that the current API
does not provide.

## Failure Isolation and Graph Rebuild

Registration errors are recorded before graph construction. Graph-level errors
can appear later when extension passes are combined with the complete engine
graph.

When whole-graph validation attributes an error to a standalone extension, the
engine removes that extension, releases its artifacts, and rebuilds the graph so
healthy extensions continue rendering.

When the failing extension belongs to a plugin, the complete plugin is removed,
including sibling extensions. Plugin failure metadata retains the graph errors.

An unattributed engine graph failure skips rendering for that frame rather than
executing a partial or invalid graph.

## Execution Model

Graph construction and compilation are declarative. During frame encoding, the
renderer walks `CompiledRenderGraph.orderedPasses` and invokes each captured
closure with the current command buffer and scoped resource access.

No extension code can reorder arbitrary built-in passes. Extensions should rely
only on stable stage semantics and declared resource flow.

## Current Boundaries

The implemented architecture intentionally does not provide:

- runtime discovery or dynamic loading of unknown extension binaries;
- cross-extension resource exports or imports;
- arbitrary dependencies on private engine pass IDs;
- physical transient resource aliasing;
- destructive pass or dependency pruning;
- argument-buffer helpers for every engine material path.

The argument-buffer helper currently targets model-surface fragment shaders.
Built-in model and material migration can proceed independently without changing
the extension contract.

## Reference Implementations

- [Application-local argument-buffer sample](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/ApplicationLocal)
- [External package acceptance fixture](https://github.com/untoldengine/UntoldEngine/tree/develop/Examples/RenderingExtensions/SwiftPackagePlugin),
  including a vertex-ID-driven custom-geometry draw that exercises camera context,
  pipeline lookup, scene color/depth access, depth state, staged graph execution,
  plugin ownership, and cleanup.
- [Rendering System architecture](renderingSystem.md)
