# Using Code Components

`UntoldComponentKit` lets you write gameplay components as Swift classes, mark the
properties the editor should show, and have their values saved with the scene. The same
source compiles into your game on macOS, iOS and visionOS.

It is a separate library product of the engine package, like `UntoldEngineXR`. It has no
third-party dependencies.

```swift
.product(name: "UntoldComponentKit", package: "UntoldEngine")
```

## Writing a component

Subclass `CodeComponent`, give every stored property a default, and mark what should be
visible with `@UntoldAttribute`.

```swift
import UntoldComponentKit
import UntoldEngine
import simd

final class PlayerController: CodeComponent {
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

Rules:

- The kit creates every instance with `init()` and then applies the saved values, so a
  component declares no initializer parameters.
- Only `@UntoldAttribute` properties are shown and saved. Everything else is runtime state.
- The unqualified type name is the identity saved in scenes. Renaming a component orphans
  its saved values.
- Generic classes are not discovered.

### Attribute kinds

| Swift type | Editor control | Saved as |
| --- | --- | --- |
| `Float`, `Int` | number field or slider (`range:`, `step:`) | number |
| `Bool` | toggle | bool |
| `String` | text field; `.multiline` for a text box | string |
| `SIMD3<Float>` | X/Y/Z fields | `[x, y, z]` |
| `SIMD4<Float>` | four fields; `.color` for a color well | `[x, y, z, w]` |
| `EntityRef` | entity picker, stored by entity name | `{"entity": "Enemy01"}` |
| `AssetRef` | asset picker, stored as a project-relative path | `{"asset": "Animations/run.untold"}` |
| `String` enum, `CaseIterable` | popup | raw value |

`range` and `step` are hints for the control. Values loaded from a scene are not clamped.

### Lifecycle

| Callback | When |
| --- | --- |
| `onAttach()` | the instance was bound to `entity`, in edit mode or in play |
| `onStart()` | play began, or the instance was attached while playing |
| `onUpdate(deltaTime:)` | once per rendered frame while playing |
| `onFixedUpdate(deltaTime:)` | once per fixed step while playing |
| `onStop()` | play ended, or the instance is being detached while playing |
| `onDetach()` | removed, entity destroyed, or a reload is replacing the instance |
| `onEditorChanged(property:)` | the editor wrote a property while not playing |

Callbacks run on the engine's simulation thread: the main thread on macOS and iOS, the
compositor render thread on visionOS. Do not touch SwiftUI or UIKit state from them.

### Actions

Functions are exposed through an explicit table. The editor draws one button per action,
and USC scripts reach them as `"<TypeName>.<ActionName>"` on the script's own entity.

```swift
override class var actions: [ComponentAction] {
    [ComponentAction("Jump") { ($0 as? PlayerController)?.jump() }]
}
```

```swift
script.callAction("PlayerController.Jump")
```

## Using components in a game

Install the system and register the component types once at startup, before loading scenes.

```swift
CodeComponentRegistry.shared.discoverInApp()
CodeComponentSystem.install()
CodeComponentSystem.shared.startPlayMode()
```

`discoverInApp()` asks the Objective-C runtime which `CodeComponent` subclasses the app
defines, so there is no list to maintain. It covers the main executable, the debug dylib Xcode
splits an app's code into, and frameworks embedded in the app bundle, and it keeps working for
classes nothing references in an optimized, dead-stripped build. The console reports the types
it found. For an image outside the bundle use `discover(imageContaining: SomeComponent.self)`,
or register types one by one with `register(_:)`.

Projects created from the editor already contain these calls, a `Sources/<Project>Components`
folder with a starter component, and the `UntoldComponentKit` dependency. For an existing
project, the editor's **Create component package** button (or
`BuildSystem.shared.addCodeComponents(toProjectAt:projectName:)`) adds the folder and the
dependency and regenerates the Xcode project; the three calls above are left for you to add.

From code:

```swift
let player = CodeComponentSystem.shared.add(PlayerController.self, to: entity)
player?.speed = 8

let found = CodeComponentRegistry.component(PlayerController.self, on: entity)
let everyone = CodeComponentRegistry.entities(with: PlayerController.self)

CodeComponentSystem.shared.remove(PlayerController.self, from: entity)
```

An entity carries at most one component of a given type.

## How components are saved

Every code component on an entity lives in one engine component,
`CodeComponentsComponent`, which registers with the scene serializer's custom-component
support. The scene format is unchanged:

```json
{
  "components": [
    {
      "type": "PlayerController",
      "properties": { "speed": 12.5, "spawnOffset": [0, 1, 0], "stance": "walk" }
    }
  ]
}
```

A scene can be loaded before, or without, a component's type. The values are kept and
saved back untouched, and the component comes alive as soon as its type is registered. When
saved values are applied, a property the scene does not mention keeps its default, and a
saved value no property claims is dropped with a log line.

## Extending the editor

An `EditorExtension` describes what loaded code adds to the editor itself. The editor
creates one instance when the library loads. A game never instantiates one; wrap the file in
`#if UNTOLD_EDITOR` to keep it out of the game binary altogether.

```swift
final class GaussianTwinsEditor: EditorExtension {
    @UntoldMenu(.view, "Preview Splat Twins") var previewTwins = true
    @UntoldMenu(.debug, "Splat Twin/Blend Cap") var blendCap: BlendCap = .c64
    @UntoldMenu(.debug, "Splat Twin/Reset Link Adoption")
    var resetAdoption = UntoldMenuAction { GaussianTwinSystem.shared.resetSceneLinkAdoption() }

    enum BlendCap: String, CaseIterable { case c64 = "64", c128 = "128", unlimited = "Unlimited" }

    override func menuDidChange(_ domain: UntoldMenuDomain, _ path: String) {
        if previewTwins { GaussianTwinSystem.shared.install() } else { GaussianTwinSystem.shared.uninstall() }
    }
}
```

The first argument of `@UntoldMenu` is the root menu, from a closed set: `.file`, `.view`,
`.debug`, `.tools`. Loaded code can never create a root menu. The second argument is the item
title, optionally preceded by submenu names separated by `/`.

| Property type | Menu item |
| --- | --- |
| `Bool` | toggle with a checkmark |
| `String` enum, `CaseIterable` | submenu with one radio item per case; adopt `UntoldMenuTitled` for custom titles |
| `UntoldMenuAction` | command |

Options: `key:`, `tooltip:`, `persist:` (on by default; the editor saves the value per
project and restores it on load), `enabled:`.

Callbacks: `onLoad`, `onUnload`, `onSceneReset`, `onPlayModeChanged`, `onEditorUpdate`,
`menuWillOpen` (refresh wrapped values so checkmarks stay truthful) and `menuDidChange`.

## For tool authors: reloading a library

A Swift library cannot be unloaded, so a reload loads a new revision under a unique module
name and moves the data across by type name and property name:

```swift
CodeComponentSystem.shared.prepareForReload()          // snapshot values, detach instances
dlopen(newLibraryPath, RTLD_NOW | RTLD_LOCAL)
CodeComponentRegistry.shared.discover(imagePath: newLibraryPath, revision: 2, policy: .replace)
CodeComponentSystem.shared.finishReload()              // new instances, saved values applied
```

A type that no longer exists leaves its slot unbound with its values intact.
