# Code Components Example

A project the Untold Editor can open, with the three things code can add: components
(`ComponentPlugin`), kinds of entity (`EntityPlugin`) and editor menu items
(`EditorMenuPlugin`). Some come from the project's own plugins folder and some from a plugin
package, the two places plugins can live. It exercises every way the editor loads code, and
its game builds with the same sources.

See [Writing Plugins in Swift](../../docs/API/UsingCodeComponents.md) for the API.

## What is here

```text
CodeComponents/
├── SampleProject/                         the game
│   ├── project.yml                        XcodeGen spec; engine and plugin package referenced by path
│   ├── UntoldEditor.json                  lists the plugin packages this project uses
│   └── Sources/
│       ├── SampleProject/                 app delegate, GameScene, GameData
│       └── SampleProjectPlugins/          the project's plugins folder: what belongs to this one game
│           ├── Spinner.swift              ComponentPlugin with two attributes
│           ├── Bobber.swift               ComponentPlugin with an action, importing the plugin package
│           ├── SpawnPoint.swift           EntityPlugin: an editor representation and no geometry
│           ├── GameRules.swift            EntityPlugin: properties and behaviour, nothing to show
│           └── SampleTools.swift          EditorMenuPlugin, editor-only (#if UNTOLD_EDITOR)
└── SamplePluginPackage/                   a plugin package: a Swift package that several games could share
    ├── Package.swift                      what games depend on
    ├── untold-package.json                what the editor reads
    └── Sources/
        ├── SamplePluginPackage/           the package's runtime, compiled into games
        │   ├── PulseClock.swift           plain Swift shared with the project's Bobber
        │   ├── Torus.swift                EntityPlugin: geometry, a primitive the engine lacks
        │   ├── SplinePath.swift           EntityPlugin: geometry and an editor representation; plus PathFollower, a ComponentPlugin
        │   └── GeneratedGeometry.swift    packs vertices into the mesh the engine converts
        └── SamplePluginPackageEditor/     its editor side, an EditorMenuPlugin; no game target compiles this
```

### Plugins folder or plugin package

| | `Sources/SampleProjectPlugins/` | `SamplePluginPackage/` |
| --- | --- | --- |
| Belongs to | this one game | any game that lists it |
| Setup | none: a folder, no `Package.swift`, no manifest | `Package.swift` for games, `untold-package.json` for the editor |
| In the game | compiled straight into the app with the rest of `Sources` | an ordinary package dependency |
| In the editor | compiled by itself as one library | compiled as two: the runtime, and the editor side that no game builds |
| Types | internal | `public`, because other modules use them |

Put what is specific to the game in the folder and what other games could want in a package.
The real case for a package is `UntoldGaussianTwins`, which has to be shared between projects
and brings its editor menus with it.

### Four kinds of entity

An `EntityPlugin` is the entity: its own properties, and whichever of geometry and editor
representation it has.

| Kind | Shelf | Own properties | In the editor | In the game |
| --- | --- | --- | --- | --- |
| **Torus** (package) | Primitives | ring and tube radius, segments | the ring mesh | the same mesh |
| **Spline Path** (package) | Entities | four control points, thickness, segments | a tube, plus its control polygon and its control points as draggable handles | the tube; `position(at:)` for whatever travels along it |
| **Spawn Point** (project) | Entities | team, radius | a flag in the team's color and a circle for the radius | only a position: `SpawnPointEntity.all(for:)` |
| **Game Rules** (project) | Entities | round length, score to win | a row in the hierarchy | the round timer |

There is no "torus shape" component. A ring's shape could only ever belong to a torus, so it is
the Torus entity's own properties. Components are for what any entity could have: `Spinner`,
`Bobber`, and the package's `PathFollower`, which moves any entity along a Spline Path.

## In the editor

Open `SampleProject` from the welcome screen, or launch the editor with
`--open-project <path to SampleProject>`. The folder is recognised by its `project.yml`, so the
Xcode project does not have to be generated first.

The **Plugins** tab at the bottom shows what happened: three libraries were built, in order.

| Library | From | Loaded |
| --- | --- | --- |
| `SamplePluginPackage_r1` | the package's runtime sources | globally, so the next two find its symbols |
| `SamplePluginPackageEditor_r1` | the package's editor sources | locally |
| `SampleProjectPlugins_r1` | the project's plugins folder | locally |

Things to try:

1. Add an entity, select it, and open **Add Component** in the Inspector. The components from
   code are in the same menu as the engine's, under **From Code**: Bobber, Path Follower and
   Spinner. The kinds of entity are not there; they are not components. Attach `Spinner` and
   `Bobber`; their `@UntoldAttribute` properties are the fields you see. Press Play.
2. In the **Assets** tab, open **Primitives**: **Torus** is listed under Cube, Sphere and Plane,
   and it comes from the plugin package. Drag it into the viewport. The Inspector shows a **Torus** block
   above the components: those are the entity's own properties. Change Ring Radius or Tube
   Segments and watch the ring rebuild. Open **Entities**, which exists only because this
   project adds kinds to it. Double-click **Spline Path**: a tube with four dots and a white
   control polygon around it. Right-click a dot: the move gizmo sits on it; drag one axis and
   the tube and the polygon follow, and one undo takes the whole drag back. Start Handle in the
   Inspector does the same from the other side. Double-click **Spawn Point** and change its team and radius to see the flag change
   color and the circle resize. Double-click **Game Rules**, which appears in the hierarchy and
   nowhere else. To see a component use a kind of entity, add a sphere, give it **Path Follower**,
   type the path entity's name into Path, and press Play. Save the scene and reopen it: every
   kind comes back as itself with its values, the ring as a ring and not as the engine's fallback
   cube, because each entity rebuilds its geometry from its saved properties.
3. **Debug ▸ Sample Package ▸ Fast Pulse** speeds every Bobber up. The item comes from the
   plugin package. **Debug ▸ Sample Project** comes from `SampleTools.swift`, an
   `EditorMenuPlugin` in the project's folder. Both menus exist only while
   this project is open; loaded code can add items under the editor's fixed root menus but can
   never create a root menu of its own.
4. Turn on **Rebuild on save**, open the project in Xcode, change `speed`'s default or add an
   attribute to `Spinner`, and save. The editor reloads in a second or two and the values you
   set in the Inspector survive. Introduce a compile error and the last good version keeps
   running while the error, with its file and line, appears in the tab.
5. Save the scene, then quit and reopen: the components and their values come back. Remove
   `Bobber.swift`, rebuild, and the Inspector shows Bobber as not available while keeping its
   saved values.

## As a game

```sh
cd SampleProject
xcodegen generate
open SampleProject.xcodeproj
```

The app target compiles everything under `Sources`, so the plugins folder is part of the game
with no separate target, and `SamplePluginPackage` is an ordinary package dependency. `GameScene` registers
the components at startup and the console says which ones it found:

```text
[ComponentKit] Component plugins in the app: Bobber, PathFollower, Spinner
[ComponentKit] Entity plugins in the app: GameRulesEntity, SpawnPointEntity, SplinePathEntity, TorusEntity
[Sample] Red team spawns at [SIMD3<Float>(-2.0, 0.0, 1.0)]
```

This sample has no saved scene, so `GameScene.createSampleScene()` builds a cube in code and
attaches the components with `ScenePluginSystem.shared.add(_:to:)`, the same call the
Inspector makes. It then creates one of each kind of entity through
`EntityPluginRegistry.shared.instantiate(_:at:entityName:)`, the same call the shelves make: a
ring around the cube, a spline with a ball travelling along it (the tube is there, the control
points are not), a red spawn point that draws nothing, and the rules.

## Notes

- Both packages are referenced by path (`../../..` and `../SamplePluginPackage`) so the sample
  always builds against the engine checkout it sits in. A real project pins the engine by URL; the
  editor writes that pin for the projects it creates.
- The plugins folder may import the engine, the kit, the listed plugin packages, Foundation and
  simd. It must not use types from the game target, because the editor compiles the folder on
  its own.
- A package's editor sources are compiled only by the editor. Keep them out of its
  `Package.swift`, as here.
- The package's runtime defines entity and component plugins, so its `Package.swift` depends
  on the engine: by path here, by the same URL as the game's pin in a real package. A package
  with no engine types in its runtime needs no such dependency.
- An entity that is only an editor representation is selected in the hierarchy, as lights are,
  or through its handles: viewport picking works on meshes. It gets the move gizmo all the same.
