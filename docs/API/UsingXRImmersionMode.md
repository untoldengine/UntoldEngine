# Using XR Immersion Modes

This guide shows how to run your Vision Pro game in **mixed** (passthrough) or
**full** immersion mode, how to enable the environment (skybox), and how to
load a custom IBL/HDR environment.

---

## Choosing an Immersion Mode

Two settings control the immersion mode, and **they must match**:

1. The SwiftUI `ImmersiveSpace` style in your app entry point.
2. The engine's immersion mode, set with `setImmersionMode`.

If they disagree — for example, the space is `.mixed` but the engine is set to
`.full` — you will see camera passthrough bleeding through your scene or a
black background where content should be.

### Full Immersion

Your rendered scene replaces the real world entirely. The environment map is
used as the background.

```swift
@main
struct MyGameApp: App {

    @State private var immersionStyle: ImmersionStyle = .full

    var body: some Scene {
        ImmersiveSpace(id: "ImmersiveSpace") {
            CompositorLayer(configuration: UntoldEngineConfiguration(), renderer: { layerRenderer in
                if let xr = UntoldEngineXR(layerRenderer: layerRenderer) {
                    XRHolder.shared.xr = xr

                    // Must match the ImmersiveSpace style above
                    xr.setImmersionMode(xrImmersionMode: .full)

                    // ... game scene + callbacks + render thread setup
                }
            })
        }
        .immersionStyle(selection: $immersionStyle, in: .full)
    }
}
```

### Mixed Immersion (Passthrough)

Your 3D content is composited over the real world. The environment map is not
shown — the camera passthrough is your background.

```swift
@State private var immersionStyle: ImmersionStyle = .mixed
```

```swift
xr.setImmersionMode(xrImmersionMode: .mixed)
```

```swift
.immersionStyle(selection: $immersionStyle, in: .mixed)
```

### Supporting Both Modes

Allow both styles in the space and keep the engine in sync whenever the
selection changes:

```swift
.immersionStyle(selection: $immersionStyle, in: .mixed, .full)
```

```swift
// Whenever you switch immersionStyle at runtime:
XRHolder.shared.xr?.setImmersionMode(
    xrImmersionMode: immersionStyle is FullImmersionStyle ? .full : .mixed
)
```

---

## Shutting Down and Re-entering the Immersive Space

The examples above cover creating the XR session once. If your app lets the
user leave the immersive space and come back later — dismissing it to show a
picker or menu, then opening it again for the same or a different scene —
you must tear the session down properly first. Otherwise the
`CompositorLayer` renderer closure's usual `if XRHolder.shared.xr == nil`
guard stays false forever, and nothing gets rebuilt on the next entry. This
is a common integration bug: the space visually dismisses fine, but nothing
ever loads again afterward.

### The Shutdown API

```swift
import UntoldEngineXR

@MainActor
public func shutdownUntoldEngineXR(_ xr: UntoldEngineXR, completion: (() -> Void)? = nil)
```

This performs a full, orderly teardown: resets scene-ready state, unregisters
XR input, clears geometry streaming, destroys all entities, clears batches,
octree, picking, and camera state, then stops the XR runtime. **The caller is
responsible for releasing its own XR references (`XRHolder.shared.xr = nil`,
etc.) inside `completion`** — the engine has no knowledge of your app's
holder type, so it can't do this for you.

### Recommended Pattern

Extend your `XRHolder` with a guarded shutdown method, and call it *before*
`dismissImmersiveSpace()` — not after:

```swift
@MainActor
final class XRHolder {
    static let shared = XRHolder()
    var xr: UntoldEngineXR?
    var renderThread: Thread?

    private var isShuttingDown = false
    private var pendingShutdownCompletions: [() -> Void] = []

    var hasActiveSession: Bool {
        xr != nil || renderThread != nil
    }

    func shutdownEngine(completion: (() -> Void)? = nil) {
        if isShuttingDown {
            if let completion { pendingShutdownCompletions.append(completion) }
            return
        }
        isShuttingDown = true
        if let completion { pendingShutdownCompletions.append(completion) }

        let finish = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                destroyAllEntities()
                self.xr = nil
                self.renderThread = nil
                self.isShuttingDown = false
                let completions = self.pendingShutdownCompletions
                self.pendingShutdownCompletions.removeAll()
                completions.forEach { $0() }
            }
        }

        guard let xr else { finish(); return }
        shutdownUntoldEngineXR(xr) { finish() }
    }

    /// Synchronous fallback for sessions left without going through
    /// shutdownEngine (e.g. the system's own dismiss gesture).
    func resetStaleEngineState() {
        xr?.stop()
        destroyAllEntities()
        xr = nil
        renderThread = nil
        isShuttingDown = false
    }
}
```

Wherever your UI triggers "leave the experience":

```swift
XRHolder.shared.shutdownEngine {
    Task { @MainActor in
        await dismissImmersiveSpace()
        // reset your own app-level selection/navigation state here
    }
}
```

And defensively, at the top of the `CompositorLayer` renderer closure — in
case the space was ever left without going through your own shutdown flow
(the system's own dismiss gesture, for example):

```swift
CompositorLayer(configuration: UntoldEngineConfiguration(), renderer: { layerRenderer in
    if XRHolder.shared.hasActiveSession {
        XRHolder.shared.resetStaleEngineState()
    }

    if XRHolder.shared.xr == nil {
        // ... build a fresh session, as in the examples above
    }
})
```

The re-entrancy guard (`isShuttingDown`/`pendingShutdownCompletions`) matters
because a user can trigger "leave" more than once before the async teardown
finishes — without it, a second call could race the first and null out `xr`
while the first shutdown is still using it.

> **Note:** `resetUntoldWorldForXR(completion:)` is a lighter-weight sibling
> API — it clears world state (entities, streaming, batching, picking) but
> *keeps the XR runtime alive*. Use it when swapping to a different
> scene/asset without leaving the immersive space at all; use
> `shutdownUntoldEngineXR` (above) when the user is actually exiting the
> space.

---

## Enabling the Environment

Enable environment rendering from your `GameScene` setup:

```swift
setRendering(.environment(.visible(true)))
```

- In **full immersion**, the environment map fills the background behind your
  scene.
- In **mixed immersion**, the environment is not composited — passthrough is
  the background — but the environment still drives image-based lighting (IBL)
  on your objects.

To control whether the environment contributes IBL lighting to your materials:

```swift
setRendering(.environment(.ibl(true)))   // objects are lit by the environment
setRendering(.environment(.ibl(false)))  // disable environment lighting
```

### Lighting Mode

Choose where environment lighting comes from:

```swift
// Use only your authored HDR environment for lighting
setRendering(.environment(.lightingMode(.authoredOnly)))

// Blend in the real-world lighting estimate (mixed immersion)
setRendering(.environment(.lightingMode(.realWorldEstimate)))
setRendering(.environment(.realWorldLightingContribution(1.0)))
```

---

## Setting a Custom IBL Environment

Load your own HDR environment with the `.asset` property. The engine loads the
image, generates mipmaps, and rebuilds the IBL textures (irradiance, specular,
BRDF) in one call:

```swift
setRendering(.environment(.asset("suburban_garden_2k.hdr")))
```

### Where to Put the File

Place the HDR inside your project's `GameData/HDR` folder:

```
MyGame/
└── Sources/
    └── MyGame/
        └── GameData/
            └── HDR/
                └── suburban_garden_2k.hdr
```

The name is resolved through the engine's standard asset search
(`assetBasePath`, which the generated project points at `GameData`). The
extension is optional — when omitted, the engine tries `.hdr`, `.exr`, and
`.png` in that order:

```swift
setRendering(.environment(.asset("suburban_garden_2k")))
```

### Loading From a Custom Location

Pass an explicit directory (the name must include the extension), or use an
absolute path:

```swift
setRendering(.environment(.asset("studio.hdr", directory: myAssetsURL)))

setRendering(.environment(.asset("/Users/me/HDRIs/studio.hdr")))
```

### HDR File Guidelines

- Use an **equirectangular** image with a **2:1 aspect ratio** (e.g.
  2048×1024).
- **2K is the recommended resolution** — it keeps memory low (~20 MB on the
  GPU) and looks sharp as a background. IBL lighting quality does not improve
  beyond 2K.
- Load the environment during scene setup (for example in your `GameScene`
  init), not every frame — the call blocks briefly while the IBL textures are
  generated.

### Complete Example

```swift
private func configureEngineSystems() {
    setRendering(.environment(.visible(true)))
    setRendering(.environment(.ibl(true)))
    setRendering(.environment(.lightingMode(.authoredOnly)))
    setRendering(.environment(.asset("suburban_garden_2k.hdr")))
}
```
