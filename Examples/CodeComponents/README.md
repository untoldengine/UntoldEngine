# Code Components Example

A project the Untold Editor can open, with components written in Swift, a project-level editor
extension, and a small plugin that brings its own editor menu items. It exercises every way
the editor loads code, and its game builds with the same sources.

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
│           └── SampleTools.swift          an EditorExtension, editor-only (#if UNTOLD_EDITOR)
└── SamplePlugin/
    ├── Package.swift                      what games depend on
    ├── untold-plugin.json                 what the editor reads
    └── Sources/
        ├── SamplePlugin/                  the plugin's runtime
        └── SamplePluginEditor/            its editor side; no game target compiles this
```

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

1. Add an entity, select it, and use **Add Code Component** in the Inspector to attach
   `Spinner` and `Bobber`. Their `@UntoldAttribute` properties are the fields you see. Press Play.
2. **Debug ▸ Sample Plugin ▸ Fast Pulse** speeds every Bobber up. The item comes from the
   plugin. **Debug ▸ Sample Project** comes from `SampleTools.swift`. Both menus exist only while
   this project is open; loaded code can add items under the editor's fixed root menus but can
   never create a root menu of its own.
3. Turn on **Rebuild on save**, open the project in Xcode, change `speed`'s default or add an
   attribute to `Spinner`, and save. The editor reloads in a second or two and the values you
   set in the Inspector survive. Introduce a compile error and the last good version keeps
   running while the error, with its file and line, appears in the tab.
4. Save the scene, then quit and reopen: the components and their values come back. Remove
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
[ComponentKit] Code component types in the app: Bobber, Spinner
```

This sample has no saved scene, so `GameScene.createSampleScene()` builds a cube in code and
attaches the components with `CodeComponentSystem.shared.add(_:to:)`, the same call the
Inspector makes.

## Notes

- Both packages are referenced by path (`../../..` and `../SamplePlugin`) so the sample always
  builds against the engine checkout it sits in. A real project pins the engine by URL; the
  editor writes that pin for the projects it creates.
- Component sources may import the engine, the kit, declared plugins, Foundation and simd. They
  must not use types from the game target, because the editor compiles the folder on its own.
- A plugin's editor sources are compiled only by the editor. Keep them out of the plugin's
  `Package.swift`, as here.
