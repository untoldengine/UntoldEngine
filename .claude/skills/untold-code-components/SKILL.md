---
name: untold-code-components
description: Use when writing reusable, compiled-Swift gameplay logic with UntoldComponentKit — a ComponentPlugin attachable to any entity, an EntityPlugin defining a whole kind of entity (with its own geometry/editor representation), or an EditorMenuPlugin adding editor menu items. Triggers on "write a component for this", "make a reusable health/spinner/path-follower behavior", "define a new entity type with editor support", "add an editor menu item". Not for a one-off, non-reusable behavior on a single entity in app code (see untold-entity-scene, or registerCustomSystem — CLAUDE.md §3) and not for USC (data-driven, designer-editable scripting) — a separate system this skill does not cover.
version: 0.1.0
---

# Code Components (UntoldComponentKit) in Untold Engine

`UntoldComponentKit` is the compiled-Swift half of the engine's two parallel behavior systems (the other, data-driven half is USC scripting — out of scope here). It lets a project add three things, in Swift, to both the game and the separate Untold Editor app: components, kinds of entity, and editor menu items. The same sources compile into the game on macOS/iOS/visionOS and into the editor.

```swift
.product(name: "UntoldComponentKit", package: "UntoldEngine")
```

## 1. Is this the right tool?

Reach for a plugin when the behavior needs to be **reusable, inspectable, and saved with the scene** — something the Editor's Inspector/shelves should show, or something multiple entities/projects should share. For single-app gameplay code that doesn't need any of that, use the lighter `registerCustomSystem(_:)` closure hook instead (CLAUDE.md §3) — don't reach for a plugin class just to run a per-frame closure. Register with exactly one of `EngineExtension`/`RenderExtension`/`registerCustomSystem` per behavior; mixing them for the same thing is a documented pitfall (CLAUDE.md §7).

**Component or entity?** If it could sit on *any* entity (a spinner, a path follower, a health bar), write a `ComponentPlugin`. If it's what the entity *is* (the ring of a torus, the team of a spawn point), it's a property of an `EntityPlugin`. A component only one kind of entity could ever carry should have been a property of that entity instead.

## 2. Writing a component

```swift
import UntoldComponentKit
import UntoldEngine
import simd

final class PlayerController: ComponentPlugin {
    @UntoldAttribute("Speed", range: 0 ... 20) var speed: Float = 5
    @UntoldAttribute var lives: Int = 3
    @UntoldAttribute var invincible = false
    @UntoldAttribute var spawnOffset: SIMD3<Float> = [0, 1, 0]
    @UntoldAttribute(.color) var tint: SIMD4<Float> = [1, 1, 1, 1]
    @UntoldAttribute var target = EntityRef()
    @UntoldAttribute var footstep = AssetRef(category: .animations)
    @UntoldAttribute var stance: Stance = .idle

    enum Stance: String, CaseIterable { case idle, walk, run }

    override func onUpdate(deltaTime: Float) {
        guard let transform else { return }
        if InputSystem.shared.keyState.wPressed {
            transform.position.z -= speed * deltaTime
        }
    }
}
```

Rules (hold for `EntityPlugin` too — both derive from `ScenePlugin`, never subclassed directly):
- No initializer parameters — the kit creates every instance with `init()` and applies saved values afterward.
- Only `@UntoldAttribute` properties are shown in the Inspector and saved with the scene. Everything else is pure runtime state.
- The **unqualified type name** is the identity saved in scenes — renaming a plugin class orphans its saved values.
- Generic classes are never discovered.

### `@UntoldAttribute` reflection — what each Swift type becomes in the Editor

| Swift type | Editor control | Saved as |
| --- | --- | --- |
| `Float`, `Int` | number field or slider (`range:`, `step:`) | number |
| `Bool` | toggle | bool |
| `String` | text field (`.multiline` for a text box) | string |
| `SIMD3<Float>` | X/Y/Z fields | `[x, y, z]` |
| `SIMD4<Float>` | four fields, or `.color` for a color well | `[x, y, z, w]` |
| `EntityRef` | entity picker | `{"entity": "Enemy01"}` |
| `AssetRef` | asset picker | `{"asset": "Animations/run.untold"}` |
| `String` enum, `CaseIterable` | popup | raw value |

`range`/`step` are editor hints only — values loaded from a saved scene are **not** clamped to them.

## 3. Lifecycle — and the thread you're actually on

| Callback | When |
| --- | --- |
| `onAttach()` | bound to `entity`, in edit mode or in play |
| `onStart()` | play began, or attached while already playing |
| `onUpdate(deltaTime:)` | once per rendered frame while playing |
| `onFixedUpdate(deltaTime:)` | once per simulation step (1/60s default, every frame under `setEngine(.simulationStepping(.perFrame))`) |
| `onStop()` | play ended, or detaching while playing |
| `onDetach()` | removed, entity destroyed, or a hot-reload is replacing the instance |
| `onEditorChanged(property:)` | editor wrote a property while not playing |

On an entity, its own `EntityPlugin` runs first, then components in the order added.

**All of these run on the engine's simulation thread** — the main thread on macOS/iOS, but the **compositor render thread on visionOS**. This is a direct instance of the CLAUDE.md §7 pitfall ("touching SwiftUI/UIKit state from component lifecycle callbacks"): never write to `@Published`/SwiftUI state or touch UIKit directly from `onUpdate`/`onFixedUpdate`/etc. — hop to the main actor first if you need to.

### Actions — the bridge to USC, without pulling USC into this skill

```swift
override class var actions: [PluginAction] {
    [PluginAction("Jump") { ($0 as? PlayerController)?.jump() }]
}
```

The Editor draws one button per action; a USC script on the same entity can call `script.callAction("PlayerController.Jump")`. You don't need to know anything about USC beyond this one-directional call-in — the data-driven side of the two-system split is not covered here.

## 4. Writing a kind of entity

An `EntityPlugin` *is* the entity — bound to it, saved with the scene, rebound on load, in both editor and game:

```swift
final class SpawnPointEntity: EntityPlugin {
    @UntoldAttribute var team: Team = .neutral
    @UntoldAttribute("Spawn Radius", range: 0 ... 10) var radius: Float = 1

    override class var systemImage: String { "flag" }                // shelf row icon
    override var editorRepresentation: EditorRepresentation {        // editor-only
        .icon(systemImage: "flag.fill", tint: team.tint)
    }
}
```

- `shelf` is a closed set: `.primitives`, `.lights`, `.entities` (default).
- An entity can have geometry, editor representation, both, or neither (game rules with no visual need neither).
- For custom geometry, build an `MDLMesh` and convert with `BasicPrimitives.createMesh(from:)`; rebuild it in `onAttach()`/`onEditorChanged(property:)` via `setGeneratedMesh(...)` — the scene stores the entity's *properties*, not the generated mesh, and `setGeneratedMesh` preserves material edits across a rebuild.
- `onCreate()` runs once when the entity is first created from the kind (use `add(_:)` to give it starting components) — it does **not** run when a saved scene loads an existing instance.
- An `EntityPlugin` gets the same lifecycle/actions as a `ComponentPlugin` — the same simulation-thread rule in §3 applies.

## 5. Registering plugins in a game

Once, at startup, before loading scenes:

```swift
ScenePluginSystem.discoverInApp()
ScenePluginSystem.install()
ScenePluginSystem.shared.startPlayMode()
```

`discoverInApp()` finds every `ComponentPlugin`/`EntityPlugin` subclass via the Objective-C runtime — no manual list, and it survives dead-stripped release builds. Projects created from the Editor already have these three calls and a `Sources/<Project>Plugins` folder; for an existing project, use the Editor's **Create plugins folder** button (or `BuildSystem.shared.addCodeComponents(toProjectAt:projectName:)`) to add the folder/dependency, then add the three calls yourself.

```swift
let player = ScenePluginSystem.shared.add(PlayerController.self, to: entity)
player?.speed = 8
let found = ComponentPluginRegistry.component(PlayerController.self, on: entity)
ScenePluginSystem.shared.remove(PlayerController.self, from: entity)

let ring = EntityPluginRegistry.shared.instantiate(TorusEntity.self, at: [0, 1, 0], entityName: "Ring")
```

An entity carries at most one component of a given type, and is of at most one `EntityPlugin` kind.

## 6. Editor menu items (editor-only — never ships in the game)

```swift
final class GaussianTwinsEditor: EditorMenuPlugin {
    @UntoldMenu(.view, "Preview Splat Twins") var previewTwins = true
}
```

Wrap the whole file in `#if UNTOLD_EDITOR` — a game never instantiates an `EditorMenuPlugin`, and this keeps it out of the game binary entirely.

## 7. Common pitfalls to call out proactively

- **Writing to SwiftUI/UIKit state directly from a lifecycle callback.** All callbacks run on the simulation thread, which is the compositor render thread (not the main thread) on visionOS — see §3.
- **Giving a plugin an initializer with parameters.** The kit only ever calls `init()`; anything else won't compile into a working plugin.
- **Renaming a shipped `ComponentPlugin`/`EntityPlugin` type.** The unqualified type name is the save identity — renaming orphans every saved instance's values.
- **Reaching for a `ComponentPlugin` for one-off, app-local logic that doesn't need Inspector/editor support.** Use `registerCustomSystem(_:)` instead — see §1.
- **Expecting `onCreate()` to run on scene load.** It only fires when an entity is first instantiated from the kind, not when a saved scene restores an existing one.
- **A component that loads fine from Xcode debug builds but fails in a packaged release build** — usually an internal (non-`final`) member on a subclass whose symbols get hidden in release; this is why `ScenePlugin`'s non-overridable members are `final`.

Full reference, including plugin packages (`untold-package.json`) for sharing plugins across projects and the library-reload flow for tool authors: `docs/API/UsingCodeComponents.md`. Worked example: `Examples/CodeComponents`.
