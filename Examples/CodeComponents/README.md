# Code Components Example

A project the Untold Editor can open, with components written in Swift, new kinds of entity
for the editor's creation shelves, a project-level editor extension, and a small plugin that
brings its own menu items and its own primitive. It exercises every way the editor loads code,
and its game builds with the same sources.

See [Using Code Components](../../docs/API/UsingCodeComponents.md) for the API.

## What is here

```text
CodeComponents/
├── SampleProject/
│   ├── project.yml                        XcodeGen spec; engine and plugin referenced by path
│   ├── UntoldEditor.json                  tells the editor which plugins this project uses
│   └── Sources/
│       ├── SampleProject/                 the game: app delegate, GameScene, GameData
│       └── SampleProjectComponents/       what the editor compiles and loads
│           ├── Spinner.swift              a component with two attributes
│           ├── Bobber.swift               a component with an action, importing the plugin
│           ├── SpawnPoint.swift           an entity kind the editor shows as an icon; the game shows nothing
│           ├── GameRules.swift            an entity kind with nothing to show anywhere
│           └── SampleTools.swift          an EditorExtension, editor-only (#if UNTOLD_EDITOR)
└── SamplePlugin/
    ├── Package.swift                      what games depend on
    ├── untold-plugin.json                 what the editor reads
    └── Sources/
        ├── SamplePlugin/                  the plugin's runtime
        │   ├── PulseClock.swift           plain Swift shared with the project's Bobber
        │   └── Torus.swift                an entity kind with a shape of its own: a primitive the engine lacks
        └── SamplePluginEditor/            its editor side; no game target compiles this
```

### Three kinds of entity

| Kind | Shelf | In the editor | In the game |
| --- | --- | --- | --- |
| **Torus** (plugin) | Primitives | a ring mesh, reshaped live from the Inspector | the same mesh, rebuilt from the saved attributes |
| **Spawn Point** (project) | Entities | a flag icon in the team's color | only a position: `SpawnPoint.all(for:)` |
| **Game Rules** (project) | Entities | a row in the hierarchy | data and a round timer |

Each is an `EntityTemplate` (the shelf row) plus a `CodeComponent` (what the entity is once it
exists, and what the scene saves).

## In the editor

Open `SampleProject` from the welcome screen, or launch the editor with
`--open-project <path to SampleProject>`. The folder is recognised by its `project.yml`, so the
Xcode project does not have to be generated first.

The **Components** tab at the bottom shows what happened: three libraries were built, in order.

| Library | From | Loaded |
| --- | --- | --- |
| `SamplePlugin_r1` | the plugin's runtime sources | globally, so the next two find its symbols |
| `SamplePluginEditor_r1` | the plugin's editor sources | locally |
| `SampleProjectComponents_r1` | the project's components folder | locally |

Things to try:

1. Add an entity, select it, and open **Add Component** in the Inspector. The components from
   code are in the same menu as the engine's, under **From Code**. Attach `Spinner` and `Bobber`;
   their `@UntoldAttribute` properties are the fields you see. Press Play.
2. In the **Assets** tab, open **Primitives**: **Torus** is listed under Cube, Sphere and Plane,
   and it comes from the plugin. Drag it into the viewport, then change Ring Radius or Tube
   Segments in the Inspector and watch the ring rebuild. Open **Entities**, which exists only
   because this project adds kinds to it: double-click **Spawn Point** and switch its team to see
   the flag change color; double-click **Game Rules**, which appears in the hierarchy and nowhere
   else. Save the scene and reopen it: the ring comes back as a ring, not as the engine's
   fallback cube, because `TorusShape` rebuilds it from its saved attributes.
3. **Debug ▸ Sample Plugin ▸ Fast Pulse** speeds every Bobber up. The item comes from the
   plugin. **Debug ▸ Sample Project** comes from `SampleTools.swift`. Both menus exist only while
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

The app target compiles everything under `Sources`, so the components are part of the game with
no separate target, and `SamplePlugin` is an ordinary package dependency. `GameScene` registers
the components at startup and the console says which ones it found:

```text
[ComponentKit] Code component types in the app: Bobber, GameRules, SpawnPoint, Spinner, TorusShape
[ComponentKit] Entity templates in the app: GameRulesEntity, SpawnPointEntity, TorusEntity
[Sample] Red team spawns at [SIMD3<Float>(-2.0, 0.0, 1.0)]
```

This sample has no saved scene, so `GameScene.createSampleScene()` builds a cube in code and
attaches the components with `CodeComponentSystem.shared.add(_:to:)`, the same call the
Inspector makes. It then creates one of each entity kind through
`EntityTemplateRegistry.shared.instantiate(_:at:)`, the same call the shelves make: a ring
around the cube, a red spawn point that draws nothing, and the rules.

## Notes

- Both packages are referenced by path (`../../..` and `../SamplePlugin`) so the sample always
  builds against the engine checkout it sits in. A real project pins the engine by URL; the
  editor writes that pin for the projects it creates.
- Component sources may import the engine, the kit, declared plugins, Foundation and simd. They
  must not use types from the game target, because the editor compiles the folder on its own.
- A plugin's editor sources are compiled only by the editor. Keep them out of the plugin's
  `Package.swift`, as here.
- The plugin's runtime defines a component, so its `Package.swift` depends on the engine: by
  path here, by the same URL as the game's pin in a real plugin. A plugin with no engine types
  in its runtime needs no such dependency.
- Selecting an icon entity is done in the hierarchy, as with lights: viewport picking works on
  meshes.
