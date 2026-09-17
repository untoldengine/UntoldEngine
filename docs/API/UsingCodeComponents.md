# Writing Plugins in Swift

`UntoldComponentKit` lets a project add three things to the engine and the editor in Swift.
Each has a base class:

| Base class | What it adds | Where it shows up |
| --- | --- | --- |
| `ComponentPlugin` | a component: something any entity can have | the Inspector's **Add Component** menu |
| `EntityPlugin` | a kind of entity, with its own properties, geometry and editor representation | the editor's creation shelves, and the entity's own block in the Inspector |
| `EditorMenuPlugin` | items in the editor's menus | under the editor's root menus; never in a game |

The editor compiles these sources, loads them, and reloads them when they change. The same
sources compile into your game on macOS, iOS and visionOS.

They live in one of two places, and the two are kept apart by name:

| | The project's **plugins folder** | A **plugin package** |
| --- | --- | --- |
| What | `Sources/<Project>Plugins`, part of the app like any other source folder | a Swift package of its own, with a `Package.swift` for games and an `untold-package.json` for the editor |
| For | what belongs to this one game | what several games share, such as `UntoldGaussianTwins` |
| Setup | none; the editor creates the folder | listed in the project's `UntoldEditor.json` under `pluginPackages`; the game depends on it like any package |

Either can hold any of the three kinds of plugin.

The kit is a separate library product of the engine package, like `UntoldEngineXR`. It has no
third-party dependencies.

```swift
.product(name: "UntoldComponentKit", package: "UntoldEngine")
```

**Component or entity?** If it could sit on any entity (a spinner, a path follower, a health
bar), it is a `ComponentPlugin`. If it is what the entity *is* (the ring of a torus, the curve
of a spline, the team of a spawn point), it is a property of an `EntityPlugin`. A component
that only one kind of entity could ever carry is a sign it should have been a property of
that entity.

## Writing a component

Subclass `ComponentPlugin`, give every stored property a default, and mark what should be
visible with `@UntoldAttribute`.

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

Rules, which hold for `EntityPlugin` too (both derive from `ScenePlugin`, which you never
subclass directly):

- The kit creates every instance with `init()` and then applies the saved values, so a
  plugin declares no initializer parameters.
- Only `@UntoldAttribute` properties are shown and saved. Everything else is runtime state.
- The unqualified type name is the identity saved in scenes. Renaming a plugin orphans its
  saved values.
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

On each entity its own plugin goes first, then its components in the order they were added.
Callbacks run on the engine's simulation thread: the main thread on macOS and iOS, the
compositor render thread on visionOS. Do not touch SwiftUI or UIKit state from them.

### Actions

Functions are exposed through an explicit table. The editor draws one button per action,
and USC scripts reach them as `"<TypeName>.<ActionName>"` on the script's own entity.

```swift
override class var actions: [PluginAction] {
    [PluginAction("Jump") { ($0 as? PlayerController)?.jump() }]
}
```

```swift
script.callAction("PlayerController.Jump")
```

## Writing a kind of entity

An `EntityPlugin` is a kind of entity: a torus, a spawn point, a spline. The plugin *is* the
entity, not a recipe for one. An instance stays bound to each entity of the kind, is saved
with the scene, and is bound again when the scene is loaded, in the editor and in the game.
Everything that is part of the entity lives on it.

```swift
final class SpawnPointEntity: EntityPlugin {
    @UntoldAttribute var team: Team = .neutral                       // its own properties
    @UntoldAttribute("Spawn Radius", range: 0 ... 10) var radius: Float = 1

    override class var systemImage: String { "flag" }                // the shelf row's icon

    override var editorRepresentation: EditorRepresentation {        // in the editor only
        .icon(systemImage: "flag.fill", tint: team.tint)
    }
}
```

**The shelf.** `shelf` says where the editor lists the kind. The set is closed, like the menu
roots: `.primitives`, `.lights` and `.entities` (the default; the editor shows that shelf only
while it holds something). Rows are dragged into the viewport or onto the hierarchy, or
double-clicked, like the built-in ones. `displayName` defaults to the type name spelled out,
without a trailing `EntityPlugin`, `Plugin` or `Entity`.

**Its own properties.** The Inspector shows them in the entity's own block, titled with the
kind, above whatever components the entity carries. That block has no remove button: it is
the entity, and it goes when the entity is deleted.

**Geometry and editor representation.** An entity can have either, both or neither.

| | In the editor | In the game | Example |
| --- | --- | --- | --- |
| Geometry | the mesh | the same mesh | a torus |
| Editor representation | icons, points and lines | nothing | a spawn point |
| Both | the mesh, plus what you need to shape it | the mesh | a spline: a tube, and its control points while editing |
| Neither | a row in the hierarchy | properties and behaviour | game rules |

*Geometry.* The engine's primitives cover cubes, spheres, planes, cylinders and cones. For
anything else, build an `MDLMesh` and convert it with `BasicPrimitives.createMesh(from:)`;
positions, normals and texture coordinates under their standard ModelIO names are enough.
Allocate its buffers with `MTKMeshBufferAllocator(device: renderInfo.device)`.

```swift
public final class TorusEntity: EntityPlugin {
    @UntoldAttribute("Ring Radius", range: 0.1 ... 5) public var ringRadius: Float = 0.5

    override public class var shelf: UntoldEntityShelf { .primitives }

    override public func onAttach() { rebuild() }
    override public func onEditorChanged(property _: String) { rebuild() }

    public func rebuild() {
        let mesh = TorusGeometry.makeMesh(ringRadius: ringRadius, /* ... */)
        setGeneratedMesh(BasicPrimitives.createMesh(from: mesh), name: "Torus")
    }
}
```

The scene does not store generated geometry. It stores the entity's properties, and the plugin
rebuilds the mesh in `onAttach`, which runs when the scene is loaded, in the editor and in the
game. `setGeneratedMesh` keeps the material of the mesh it replaces, so material edits made in
the editor survive a rebuild and a reload. The mesh is part of the entity, so the editor does
not let it be removed on its own.

*Editor representation.* What the editor draws besides the geometry. It is asked for every
frame while editing, so it follows the properties. It is never saved, and it is not drawn in
play mode or in a game. Positions are in the entity's local space.

| Item | Drawn as |
| --- | --- |
| `.icon(systemImage:tint:)` | a camera-facing SF Symbol at the entity's origin, hidden by geometry in front of it like the editor's light markers |
| `.points(_:tint:)` | a dot at each position, over everything, so a handle inside a mesh stays visible |
| `.polyline(_:closed:)` | a white line through the positions, over everything |
| `.handles(properties:tint:)` | a draggable dot for each `SIMD3<Float>` property named; see below |

```swift
override public var editorRepresentation: EditorRepresentation {
    EditorRepresentation([
        .polyline([start, startHandle, endHandle, end], closed: false),
        .handles(properties: ["start", "end"], tint: [1.0, 0.75, 0.2]),
        .handles(properties: ["startHandle", "endHandle"], tint: [0.35, 0.8, 1.0]),
    ])
}
```

*Handles.* A handle is a property you can drag. Right-click the dot in the viewport: the entity
is selected and the move gizmo sits on the point instead of on the entity. Drag an axis, or
edit the field in the Inspector, and the property changes; the entity is told through
`onEditorChanged`, so a spline rebuilds its tube as its control point moves. The whole drag is
one undo step. Only the move gizmo works on a handle; the rotate and scale gizmos go back to
the entity. Any `SIMD3<Float>` property in the entity's local space can be a handle; a name
that is not one is skipped.

An entity that has only an editor representation is selected in the hierarchy or by its
handles, since viewport picking works on meshes, and it gets the move gizmo like anything
visible.

**Starting components.** `onCreate()` runs once, when the entity is first made from the kind,
after `onAttach()`. Give a new entity the components it starts with there, with `add(_:)`. It
does not run when a scene is loaded, which brings back what was saved.

**Behaviour.** An entity plugin gets the same lifecycle and actions as a component, so an
entity with nothing to show (the rules of a match) keeps its behaviour on itself.

## Using plugins in a game

Install the system and register the plugin types once at startup, before loading scenes.

```swift
ScenePluginSystem.discoverInApp()
ScenePluginSystem.install()
ScenePluginSystem.shared.startPlayMode()
```

`discoverInApp()` asks the Objective-C runtime which `ComponentPlugin` and `EntityPlugin`
subclasses the app defines, so there is no list to maintain. It covers the main executable,
the debug dylib Xcode splits an app's code into, and frameworks embedded in the app bundle,
and it keeps working for classes nothing references in an optimized, dead-stripped build. The
console reports the types it found. For an image outside the bundle use
`ComponentPluginRegistry.shared.discover(imageContaining:)`, or register types one by one with
`register(_:)`.

Projects created from the editor already contain these calls, a `Sources/<Project>Plugins`
folder with a starter component, and the `UntoldComponentKit` dependency. For an existing
project, the editor's **Create plugins folder** button (or
`BuildSystem.shared.addCodeComponents(toProjectAt:projectName:)`) adds the folder and the
dependency and regenerates the Xcode project; the three calls above are left for you to add.

From code:

```swift
// Components
let player = ScenePluginSystem.shared.add(PlayerController.self, to: entity)
player?.speed = 8
let found = ComponentPluginRegistry.component(PlayerController.self, on: entity)
let everyone = ComponentPluginRegistry.entities(with: PlayerController.self)
ScenePluginSystem.shared.remove(PlayerController.self, from: entity)

// Entities of a kind: what the editor's shelves do
let ring = EntityPluginRegistry.shared.instantiate(TorusEntity.self, at: [0, 1, 0], entityName: "Ring")
ring?.ringRadius = 1.4
ring?.rebuild()
let spline = EntityPluginRegistry.plugin(SplinePathEntity.self, on: pathEntity)
let spawns = EntityPluginRegistry.entities(of: SpawnPointEntity.self)
```

An entity carries at most one component of a given type, and is of one kind at most.

## How plugins are saved

Everything the kit puts on an entity lives in one engine component, `ScenePluginsComponent`,
which registers with the scene serializer's custom-component support. The scene format is
unchanged:

```json
{
  "entity": {
    "type": "TorusEntity",
    "properties": { "ringRadius": 1.4, "tubeRadius": 0.08, "ringSegments": 48, "tubeSegments": 20 }
  },
  "components": [
    {
      "type": "PlayerController",
      "properties": { "speed": 12.5, "spawnOffset": [0, 1, 0], "stance": "walk" }
    }
  ]
}
```

A scene can be loaded before, or without, a plugin's type. The values are kept and saved back
untouched, and the plugin comes alive as soon as its type is registered. When saved values are
applied, a property the scene does not mention keeps its default, and a saved value no
property claims is dropped with a log line.

## Adding to the editor's menus

An `EditorMenuPlugin` describes what loaded code adds to the editor's menus, and to the editor
itself. The editor creates one instance when the library loads. A game never instantiates one;
wrap the file in `#if UNTOLD_EDITOR` to keep it out of the game binary altogether.

```swift
final class GaussianTwinsEditor: EditorMenuPlugin {
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

## Plugin packages

A plugin package brings any of the three with it, to every project that lists it. What must
exist in the game (a component, a kind of entity with geometry) goes in its runtime sources,
which then depend on the engine. What only the editor needs (an `EditorMenuPlugin`) goes in
its editor sources, which only the editor compiles and which are not a target of the package.

```json
// <PackageRoot>/untold-package.json
{ "id": "com.example.shapes", "module": "Shapes", "runtimeSources": "Sources/Shapes", "editorSources": "Sources/ShapesEditor" }

// <ProjectRoot>/UntoldEditor.json
{ "pluginPackages": [ { "path": "../Shapes" } ] }
```

`Examples/CodeComponents` has a project with a plugins folder and a plugin package side by side.

## For tool authors: reloading a library

A Swift library cannot be unloaded, so a reload loads a new revision under a unique module
name and moves the data across by type name and property name:

```swift
ScenePluginSystem.shared.prepareForReload()            // snapshot values, detach instances
dlopen(newLibraryPath, RTLD_NOW | RTLD_LOCAL)
ComponentPluginRegistry.shared.discover(imagePath: newLibraryPath, revision: 2, policy: .replace)
EntityPluginRegistry.shared.discover(imagePath: newLibraryPath, revision: 2, replaceExisting: true)
ScenePluginSystem.shared.finishReload()                // new instances, saved values applied
```

A type that no longer exists leaves its slot unbound with its values intact.
