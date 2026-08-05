# Proposal: `UntoldViewOptions` — runtime-tunable view settings for SwiftUI

**Status:** Draft
**Scope:** `UntoldView` / `SceneView` only. No changes to `UntoldRendererConfig` semantics, no `Observable` conformance on the renderer.

## Motivation

`UntoldRendererConfig` is create-time, immutable configuration (Metal view, pipeline init
blocks, render-system callbacks). That contract is correct and stays as-is: if those change,
recreating the renderer is acceptable.

What is missing is a home for values that must change **while the view is alive** — target
FPS being the first concrete case. Exposing a mutable property on `UntoldView` itself does
not work: `UntoldView` is a SwiftUI value struct, so any state change that flows through it
re-evaluates the body, and today that also re-runs renderer creation (see "Prerequisite"
below). Making `UntoldRenderer` observable is deliberately rejected — it would couple the
engine to SwiftUI and is heavyweight for what is a handful of scalar settings.

Agreed direction:

- `UntoldRendererConfig` — immutable, renderer creation only.
- `UntoldViewOptions` — small `Equatable` value struct for runtime, view-host-scoped
  settings. SwiftUI re-evaluates the view freely; we diff the options in
  `updateNSView`/`updateUIView` against the last-applied copy stored in the coordinator and
  touch the live `MTKView` only when something actually changed.

## Prerequisite: stable renderer ownership

Today both fallbacks re-create the renderer on every SwiftUI re-evaluation:

```swift
// UntoldView.init
self.renderer = renderer ?? UntoldRenderer.create()   // runs on every re-init of the struct

// SceneView.init
self.renderer = renderer ?? UntoldRenderer.create()
```

The demos dodge this by creating the renderer outside and passing it in, but the API should
be safe by default. The fix is the same pattern already used for the `.onUpdate`
subscription: move fallback creation into the `Coordinator`, which SwiftUI keeps alive
across re-evaluations of the representable.

- `SceneView` stores the *optional* renderer handed to it; it no longer force-creates one
  in `init`.
- `Coordinator` gains `var renderer: UntoldRenderer?`. On first `makeNSView`/`makeUIView`,
  it adopts the passed-in renderer or creates one, and from then on always returns the same
  `MTKView`.
- `UntoldView` keeps accepting an optional external renderer (existing API unchanged) but
  stops calling `UntoldRenderer.create()` in `init`; it just forwards the optional down.

This is what makes the rest of the proposal sound: once the `MTKView`/renderer identity is
stable, applying option diffs to it is trivial.

## API

### The options struct

```swift
/// Runtime-tunable settings for the SwiftUI host view. Unlike
/// `UntoldRendererConfig`, these may change while the view is alive; the view
/// applies the difference to the live `MTKView` without recreating the
/// renderer. Equatable so updates are no-ops when nothing changed.
public struct UntoldViewOptions: Equatable, Sendable {
    /// Target frame rate, applied to `MTKView.preferredFramesPerSecond`.
    public var preferredFramesPerSecond: Int

    /// Pauses the draw loop (`MTKView.isPaused`). Simulation and rendering
    /// stop; the last frame stays on screen. Use for menus, inactive tabs,
    /// or battery saving.
    public var isPaused: Bool

    /// Clear color of the drawable, linear RGBA.
    public var clearColor: simd_float4

    public init(
        preferredFramesPerSecond: Int = 60,
        isPaused: Bool = false,
        clearColor: simd_float4 = simd_float4(0, 0, 0, 1)
    ) {
        self.preferredFramesPerSecond = preferredFramesPerSecond
        self.isPaused = isPaused
        self.clearColor = clearColor
    }

    public static let `default` = UntoldViewOptions()
}
```

### Surface on `UntoldView`

Two equivalent ways to drive it — an init parameter for "bind the whole struct", and
per-property modifiers (same copy-on-write pattern `.onUpdate` already uses) for the common
one-liner:

```swift
public init(
    renderer: UntoldRenderer? = nil,
    options: UntoldViewOptions = .default,
    @SceneBuilder _ content: @escaping @MainActor () -> [any NodeProtocol]
)

/// Replace all runtime options.
public func options(_ options: UntoldViewOptions) -> UntoldView

/// Sugar for the common case.
public func preferredFramesPerSecond(_ fps: Int) -> UntoldView
public func paused(_ paused: Bool) -> UntoldView
```

Usage in an app:

```swift
struct GameScreen: View {
    @State private var fps = 60
    @State private var inMenu = false

    var body: some View {
        UntoldView(renderer: renderer) {
            MeshNode(resource: "redplayer.usdz", entityID: rootID)
        }
        .preferredFramesPerSecond(fps)
        .paused(inMenu)

        Picker("FPS", selection: $fps) {
            Text("30").tag(30); Text("60").tag(60); Text("120").tag(120)
        }
    }
}
```

When `fps` changes, SwiftUI re-evaluates the body, `updateNSView`/`updateUIView` runs, the
coordinator sees `appliedOptions != options`, and only
`mtkView.preferredFramesPerSecond` is touched. The renderer, the `MTKView`, the frame-event
subscription, and the scene are untouched.

## Implementation

### `SceneView` changes

```swift
public struct SceneView: ViewRepresentable {
    private var renderer: UntoldRenderer?          // optional now; no create() in init
    private var options: UntoldViewOptions
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?

    public init(
        renderer: UntoldRenderer? = nil,
        options: UntoldViewOptions = .default,
        updateHandler: (@MainActor (UpdateEvent) -> Void)? = nil
    ) {
        self.renderer = renderer
        self.options = options
        self.updateHandler = updateHandler
    }

    @MainActor
    public final class Coordinator {
        var renderer: UntoldRenderer?
        var handler: (@MainActor (UpdateEvent) -> Void)?
        var subscription: EventSubscription?
        /// Last options actually applied to the MTKView; nil until first apply.
        var appliedOptions: UntoldViewOptions?
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    /// Resolves the stable renderer: adopts the injected one on first call,
    /// creates a fallback otherwise, and never swaps it afterwards.
    private func resolveRenderer(_ coordinator: Coordinator) -> UntoldRenderer? {
        if coordinator.renderer == nil {
            coordinator.renderer = renderer ?? UntoldRenderer.create()
        }
        return coordinator.renderer
    }

    private func connect(_ coordinator: Coordinator) {
        coordinator.handler = updateHandler
        guard coordinator.subscription == nil, updateHandler != nil,
              let renderer = coordinator.renderer else { return }
        coordinator.subscription = renderer.onUpdate { [weak coordinator] event in
            MainActor.assumeIsolated {
                coordinator?.handler?(event)
            }
        }
    }

    /// Diffs against the last-applied options and touches the MTKView only
    /// for properties that changed.
    private func apply(_ options: UntoldViewOptions, to view: MTKView, coordinator: Coordinator) {
        let previous = coordinator.appliedOptions
        guard previous != options else { return }

        if previous?.preferredFramesPerSecond != options.preferredFramesPerSecond {
            view.preferredFramesPerSecond = options.preferredFramesPerSecond
        }
        if previous?.isPaused != options.isPaused {
            view.isPaused = options.isPaused
        }
        if previous?.clearColor != options.clearColor {
            let c = options.clearColor
            view.clearColor = MTLClearColor(red: Double(c.x), green: Double(c.y),
                                            blue: Double(c.z), alpha: Double(c.w))
        }
        coordinator.appliedOptions = options
    }

    #if os(macOS)
        public func makeNSView(context: Context) -> MTKView {
            let view = resolveRenderer(context.coordinator)?.metalView ?? MTKView()
            connect(context.coordinator)
            apply(options, to: view, coordinator: context.coordinator)
            return view
        }

        public func updateNSView(_ view: MTKView, context: Context) {
            connect(context.coordinator)
            apply(options, to: view, coordinator: context.coordinator)
        }
    #else
        // identical bodies for makeUIView/updateUIView
    #endif
}
```

`dismantleNSView`/`dismantleUIView` additionally clear `coordinator.appliedOptions` (and
`coordinator.renderer` if we decide the coordinator owns fallback renderers' lifetime).

### `UntoldView` changes

```swift
public struct UntoldView: View {
    private var renderer: UntoldRenderer?          // no create() in init anymore
    private var options: UntoldViewOptions
    private var content: [any NodeProtocol] = []
    private var updateHandler: (@MainActor (UpdateEvent) -> Void)?

    public init(
        renderer: UntoldRenderer? = nil,
        options: UntoldViewOptions = .default,
        @SceneBuilder _ content: @escaping @MainActor () -> [any NodeProtocol]
    ) {
        self.renderer = renderer
        self.options = options
        self.content = content()
    }

    public var body: some View {
        SceneView(renderer: renderer, options: options, updateHandler: updateHandler)
    }

    public func options(_ options: UntoldViewOptions) -> UntoldView {
        var copy = self; copy.options = options; return copy
    }

    public func preferredFramesPerSecond(_ fps: Int) -> UntoldView {
        var copy = self; copy.options.preferredFramesPerSecond = fps; return copy
    }

    public func paused(_ paused: Bool) -> UntoldView {
        var copy = self; copy.options.isPaused = paused; return copy
    }
}
```

Note the `@State private var metalView` currently held by `UntoldView` goes away — the
coordinator is the stable holder, and `UntoldView` never needs the view directly.

## What belongs in options (and what does not)

Rule of thumb: **`UntoldViewOptions` owns properties of the host `MTKView` / presentation
surface.** Anything that tunes the engine or render pipeline itself already has a live
settings channel (`setRendering`, `setPostFX`, `setLOD`, `setEngine`, … backed by the
lock-protected shared store) and stays there — those work from any context, not just
SwiftUI, and duplicating them here would create two sources of truth.

Included now:

| Property | Applied to | Why |
|---|---|---|
| `preferredFramesPerSecond` | `MTKView.preferredFramesPerSecond` | The motivating case. Also removes the hardcoded 60 in `UntoldRenderer.create()` as the only knob. |
| `isPaused` | `MTKView.isPaused` | Cheap, obviously view-scoped, immediately useful (menus, background, battery). |
| `clearColor` | `MTKView.clearColor` | Cosmetic surface property; lets SwiftUI theme the canvas. |

Good candidates for a follow-up, same mechanism:

- **`renderScale: Float`** (dynamic resolution) — scale the drawable size relative to the
  view's native size. Flows naturally through the existing
  `mtkView(_:drawableSizeWillChange:)` resize path, but needs care because `create()`
  currently pins `contentsScale = 1.0`; worth its own pass.
- **`drawsOnDemand: Bool`** — `enableSetNeedsDisplay` + paused combo for editor-style
  "render only when dirty" hosts.

Deliberately excluded:

- Anti-aliasing, post-FX, LOD, debug views, environment — already live-tunable via
  `EngineSettingsAPI`; call those from `onChange` in SwiftUI if needed.
- `gameMode` — engine-wide state, not a property of one host view.
- Anything from `UntoldRendererConfig` — pipeline blocks and callbacks stay create-time.

## Behavior notes

- **No renderer recreation, ever, from options.** Every property in the struct must be
  applicable to the live `MTKView`. If a future setting cannot be applied live, it belongs
  in `UntoldRendererConfig`, not here — that is the invariant that keeps the two types from
  blurring together.
- **Idempotent application.** The coordinator-side diff means a re-evaluation storm from
  unrelated SwiftUI state costs one `Equatable` compare and nothing else.
- **Multiple views** — options are per-`SceneView` instance (per coordinator), so two
  `UntoldView`s over different renderers can run different FPS/pause states independently.
- `Sendable` is free (scalars + simd), which keeps the struct usable from non-main contexts
  that compute settings, even though application always happens on the main thread inside
  the representable callbacks.

## Migration

- `UntoldView(renderer:)` and `SceneView(renderer:)` signatures gain only defaulted
  parameters — source-compatible.
- The SceneBuilder demo (UntoldArcade) can drop its "create renderer in the parent's init"
  workaround once the coordinator owns the fallback, though passing an external renderer
  remains supported and correct.
