# Code Components and Editor Extensions: Swift-authored components and plugin menus, loaded and reloaded by the editor

**Status:** Revision 5.2 (2026-09-18). Implemented through stage 3d on feature branches in both repos; see Implementation status below. Decisions D1 to D8 are locked (§14).
**Scope:** `UntoldEngine` (new `UntoldComponentKit` product, generated-project spec) and `UntoldEditor` (loader, inspector, menu host, panel, app bundle). No change to the ECS core, the `.untoldscene` format, or any existing component.
**Baseline:** editor `develop` @ `4a95ce5` (v0.19.0); engine fork `develop` @ `cd7ca92e` (the revision the editor's `Package.resolved` pins); Xcode 27.0, Swift 6.4, macOS 27.0.
**Repos:** `miolabs/UntoldEngine`, `miolabs/UntoldEditor`. `miolabs/UntoldGaussianTwins` and the twin demo adopt it afterwards (stage 5): that work is on hold until this feature has been tested.
**Working agreement:** commit as work progresses and push branches to the miolabs fork; no pull request until the whole loop works end to end (§12 defines that bar).

Changes in revision 2: `@Expose` is now `@UntoldAttribute`; new `EditorMenuPlugin` with `@UntoldMenu` menu items (§5); plugin packages such as UntoldGaussianTwins bring their editor integration with them (§7.8); generated projects are XcodeGen projects, which corrects §9 and D5; spikes C and D added; the feature is tested on its own sample project first, and the twin demo is updated after that (§11, §12).

Revision 2.1: `@UntoldMenu` takes the root domain first, then the submenu path or just the title. Loaded code is tied to the editor's fixed root menus and cannot create new ones (§5.2).

Revision 4: loaded code can add kinds of entity to the editor's creation shelves (`EntityPlugin`, §5.6), with the three sorts a plugin needs: nothing to show, an editor-only representation, or a shape of its own that also exists in the game. The Inspector has one **Add Component** menu instead of two (§7.6).

Revision 4.1 (superseded by revision 5): a component could be locked to its kind of entity, so a torus's shape was never offered for a cube.

Revision 5: the base classes are named after what they are, and a kind of entity is a thing of its own. `CodeComponent` is `ComponentPlugin`, `EntityTemplate` is `EntityPlugin`, `EditorExtension` is `EditorMenuPlugin` (the engine already calls its extension points plugins: `PhysicsBackendPlugin`, `RenderExtensionPlugin`). An `EntityPlugin` stays bound to its entity and carries the entity's own properties, its geometry and its editor representation, which is now icons, points and polylines so a spline can show its control points (§5.6). The component lock of revision 4.1 is gone. `ScenePlugin` is the shared base of the two plugins bound to entities, `ScenePluginSystem` drives both, and `ComponentAction` is `PluginAction`. This document uses the new names throughout.

Revision 5.1: the two places plugins live are named apart. The project's own folder is `Sources/<Project>Plugins` (was `<Project>Components`, a leftover from when only components lived there), and a shared one is a *plugin package*, the term the engine's plugin docs already use: `untold-package.json` in its root, listed under `pluginPackages` in `UntoldEditor.json`. The sample package is `SamplePluginPackage`, its editor side the folder `SampleEditorPluginPackage` with the menu plugin `SampleMenus`; a package's editor-side library is named after its folder. The old folder name, keys and file name are still read and reported (§7.1).

Revision 5.2: control points can be dragged. `.handles(properties:tint:)` names `SIMD3<Float>` properties of an `EntityPlugin`; a click on one, with either button, puts the move gizmo on the point, and dragging an axis writes the property as an Inspector edit would, one undo step per drag (§5.6). Entities with only an editor representation get the gizmo too.

## Implementation status (2026-09-17)

Branches, all pushed to the miolabs fork, no pull request opened:

| Repo | Branch | Holds |
| --- | --- | --- |
| UntoldEngine | `feature/component_kit` | the kit, its tests and guide, generated-project support, the example |
| UntoldEditor | `feature/code_components_loader` | loader, inspector blocks and the one Add Component menu, menu host, panel, hot reload, packaged SDK, entity shelves and viewport markers |
| UntoldGaussianTwins | `fork-engine-component-kit` | `fork-engine` with only the engine pin changed, so SwiftPM resolves one engine |

One branch per repo instead of the one per stage planned in §11: the editor and the twins pin branch both name the engine branch, so stacked branches would have meant re-pinning all three at every stage. Commits are small and topical and can be regrouped for review.

| Stage | State | Evidence |
| --- | --- | --- |
| 0 Spikes | Closed, except one item | Real-module compile and load run as a test in both repos; compile takes 0.45 s per library; reloading 1,000 instances takes 26 ms. Not verified: rebuilding menus while one is open (needs a person at the UI) |
| 1 Kit | Done | 55 tests. `Sources/UntoldComponentKit`, `docs/API/UsingCodeComponents.md` |
| 1b Generated projects | Done | 10 tests. A generated project was built with `xcodebuild` and reports its component at startup |
| 2 Loader, 2b Inspector, 2c Menus, 3 Hot reload | Done | 64 new editor tests (709 in the suite, the one failure predates this work). Verified in the running editor, debug and packaged release |
| 3b Sample | Done | `Examples/CodeComponents`: opens in the editor (three libraries, three component plugins, four entity plugins, two menu plugins) and builds as a game |
| 3c, 3d Kinds of entity (§5.6) | Done | In the running editor, debug and packaged release: four kinds on the shelves (Torus on Primitives; Spline Path, Spawn Point and Game Rules on Entities); Add Component offers the three components and no kind; each entity carries its own properties; an Inspector-style edit reshapes the torus (1,029 to 441 vertices) and the spline (665 to 249, its midpoint following the moved handle); the spawn point's circle follows its radius; the icon, line and point drawing paths all run in the real render pass; after a scene round trip every kind comes back as itself with its edited values and its components. The game built with `xcodebuild` registers three component plugins and four entity plugins and creates one of each. Handles: the spline's four control points are drawn as handles in the running editor and follow a property write; picking, local-space writing under a rotated transform, selection validity and the single undo step are unit-tested; the click and drag themselves need a person |
| 4 Polish | Not started | Basic pickers and a color well exist; macro package, evolution SDK, stable entity IDs, plugin resources and CLI flags remain |
| 5 Twins adoption | On hold | Waits for the feature to be tested by hand |

Measured in the running editor on a sample project: launch to first library loaded 4.1 s including app start; save to new revision live 1.2 s; broken save to error with file and line 0.2 s, with the last good revision still running.

### What the real runs found

Each of these passed every unit test and failed only in a real build, which is why the plan insisted on running the packaged app and a generated game.

1. **Hidden symbols in release.** A subclass in a loaded library copies its base class's dispatch table, entries for internal members included, and release builds hide internal symbols. The packaged editor failed to load any component until `entity`, `isAttached` and `hasStarted` became `final`. `scripts/verify-component-sdk.sh` now checks this at packaging time: it compiles a fixture against the bundled SDK and confirms the executable exports every symbol it needs (103 today, with an entity plugin that has its own properties, a generated mesh and an editor representation in the fixture).
2. **Xcode's debug dylib.** Xcode builds an app's code into `<App>.debug.dylib` and leaves the executable as a stub, so scanning the main executable found nothing. `discoverInApp()` became `discoverInApp()`, which covers every image inside the app bundle.
3. **Image paths.** The loader records `/private/var/...` for a library opened as `/var/...`. Discovery now matches a path against the loaded images instead of trusting its spelling.
4. **Entities pending destruction.** `scene.mask(for:)` hides them, so the cleanup handler could not reach the instances to detach. The lookup uses the component bit instead.
5. **The bundle script** hardcoded a build path the newer SwiftPM does not use, and did not copy the editor's own resource bundle, so the packaged app crashed at launch outside the build tree. Both fixed.
6. **Marker colors.** The first viewport icons came out washed: the pixels are sRGB and the texture was read as linear. Only looking at the running editor showed it; the texture is `rgba8Unorm_srgb` now.

### Deviations from this document

- Components from code are drawn by the Inspector directly, like Splat Twin, instead of being registered through `addComponent_Editor`: scene-composition mode whitelists registered components and would have hidden them, and the set of types changes whenever a library loads. They are added from the same **Add Component** menu as the engine's, under a "From Code" heading; the first version had a second button, which was one too many.
- The editor gained `--open-project <folder>`, and accepts a folder with a `project.yml` and no generated Xcode project.
- Each Swift module is a directory in the newer SwiftPM layout; the SDK packaging copies recursively.
- An unloaded type's saved values round-trip unchanged, not byte for byte: the scene encoder does not sort keys.
- `BuildSettings.includesCodeComponents` is opt-in, so projects generated without it are exactly what they were. The editor turns it on when it knows its own engine reference.

### Left for a person

Nothing here can be driven from a script, because macOS refuses UI scripting without an accessibility grant:

- The Inspector renders every kind of field and edits are undoable.
- The one Add Component menu lists the engine's components, then the ones from code under "From Code".
- Rows for kinds of entity drag from the shelves into the viewport and the hierarchy; the Entities shelf appears and disappears with its contents.
- An entity of a kind shows its own block at the top of the Inspector, titled with the kind, and its fields edit it.
- How the editor representation looks on screen: the flag's tint, the spawn radius circle, and the spline's dots and control polygon staying visible over its tube.
- Clicking a spline control point puts the gizmo on it, dragging an axis reshapes the tube, one undo takes the drag back, and a left click on a dot does not drop the selection.
- The contributed menu items appear, toggle, and keep their checkmarks.
- Play, stop, and a rebuild that lands during play.

`Examples/CodeComponents/README.md` lists the steps.

### Found on the way, not part of this work

- `CreateProjectViewTests.test_createProjectView_resultProjectPathIsNilByDefault` fails on the editor's pristine `develop`.
- Generated projects keep `{{PROJECT_NAME}}` in `Main.storyboard`: the variable pass skips storyboard files.

---

## 1. The ask

1. Components are written in Swift, in Xcode, by subclassing a base class the engine ships. Code is the primary interface; the editor views and tunes.
2. A property wrapper marks what the editor sees: `@UntoldAttribute` properties become inspector fields and are saved with the scene; actions become inspector buttons and script-callable functions.
3. When a project is opened, the editor finds the project's component sources, compiles them and loads them. A change made in Xcode is recompiled and shows up in the running editor without relaunching it.
4. The same sources compile into the final game on macOS, iOS and visionOS with no editor involvement and no dynamic loading.
5. Loaded code can also extend the editor itself. `@UntoldMenu(.debug, "Splat Twin/…")` declares a menu item under one of the editor's fixed root menus; when the library loads, the item appears there. The twin gaussian work is the first real consumer: it is a plugin, and its debug and preview menus should arrive with the plugin instead of being hardcoded in the editor. That adoption happens after this feature has been tested; the twin session is on hold until then.
6. Everything editor-only (compiler, loader, inspector, menu host) stays on macOS. The kit that game code depends on is platform neutral.

## 2. What exists today, and what this proposal reuses

| Capability | Where | Reuse |
| --- | --- | --- |
| `Component` protocol (only `init()`), class-based components, 128-slot component mask, lazily assigned IDs keyed by `ObjectIdentifier` | `ECS/ComponentPool.swift`, `ECS/Scenes.swift` | User components live behind one engine slot (§6.2), so reloads never consume mask slots |
| Custom component serialization: `encodeCustomComponent(type:merge:)` writes `EntityData.customComponents: [String: Data]` and decodes by type name | `Systems/RegistrationSystem.swift:3152`, `Scenes/SceneSerializer.swift:822`, `:1745` | The kit's storage component is `Component & Codable` and registers here. No serializer change |
| Per-frame plugin lifecycle: `EngineExtension` (`update` every frame, `fixedUpdate` in game mode only) | `ECS/EngineExtensions.swift`, `Renderer/UntoldEngine.swift:592`, `:636` | `ScenePluginSystem` is one `EngineExtension` |
| USC scripting: `ScriptComponent`, `USCSystem.startPlayMode/stopPlayMode`, `USCActionRegistry` | `Scripting/`, `Systems/USCSystem.swift` | Component actions are registered as USC actions (§4.3) |
| Inspector extension point `ComponentOption_Editor` + public `addComponent_Editor(componentOption:)` | `Editor/InspectorView.swift:16`, `:137` | One "Code Components" section |
| Menu bar built by hand in the app delegate; checkmarks synced in `menuNeedsUpdate` | `UntoldEditorApp.swift:96`, `:198` | `EditorMenuHost` adds contributed items with the same sync pattern (§7.7) |
| Twin plugin wiring: the editor imports `UntoldGaussianTwins`, owns `GaussianTwinPreviewSettings`, the `Preview Splat Twins` item and, on `feature/gaussian_large_capture`, a `Splat Debug` tree of toggles and radio submenus (+280 lines in the app delegate) | `Editor/GaussianTwinPreviewSettings.swift`, `UntoldEditorApp.swift` | This is the code that moves into the plugin's editor sources (§7.8) |
| Project model: `EditorAssetBasePath.basePath` is `<Root>/Sources/<Project>/GameData`; open-project flow requires `<Project>.xcodeproj` | `Editor/EditorController.swift:33`, `Editor/EditorView.swift:1250` | Component folder is derived the same way; the twin demos already match this layout |
| Generated projects are XcodeGen projects: `XcodeGenProjectSpec.generateYAML` writes `project.yml`, and the app target compiles everything under `Sources/` except `GameData` | `BuildSystem/XcodeGenProjectSpec.swift`, `BuildSystem/BuildSystem.swift:420` | A components folder under `Sources/` is compiled by the app target with no new target (§9) |
| Play mode: `setEditorPlayMode` snapshots the scene, restores it on stop, starts/stops USC | `Editor/EditorView.swift:1751` | Same hook starts/stops code components |
| Background process with task UI (`swift run` under `TaskCenter`), Log Console, undo manager | `Systems/ScriptProjectManager.swift:139`, `Editor/EditorUndoManager.swift:283` | Compile pipeline pattern; undoable edits |
| App bundle script copies executable, metallib, resource bundle, exporter scripts | `UntoldEditor/create_app_bundle.sh` | Gains the Component SDK copy step (§7.2) |
| Feature flags; `EditorAuthoringMode.sceneCompositionOnly = true` currently hides the Script Component | `Config/EditorFeatureFlags.swift` | New `enableCodeComponents` flag |

Not present today: any property metadata or reflection for components, any dynamic code loading (`HotReloadingSystem.swift` only swaps a hand-picked `.metallib`), any way for code outside the editor to add a menu item, a compile SDK in the app bundle.

## 3. Design in one picture

```
Xcode ──edits──▶ project:  <Root>/Sources/<Project>Plugins/*.swift    ◀── same files, no editor ──┐
                 plugin:   <Plugin>/Sources/<Plugin>Editor/*.swift   (editor-only sources)         │
                                   │                                                               │
        editor: watch / "Build"    ▼                                                               ▼
        /usr/bin/xcrun swiftc -emit-library                                       Xcode / xcodebuild (static link)
        against the Component SDK shipped in the .app                                              │
                                   │                                                               ▼
                                   ▼                                               game binary: macOS / iOS / visionOS
        dlopen <Module>_r<N>.dylib ──▶ discovery ──▶ registries rebind                             │
                   │                          │                                                    │
                   ▼                          ▼                                                    ▼
        Inspector: @UntoldAttribute    Menu bar: @UntoldMenu      ◀── UntoldComponentKit: base classes, wrappers,
        fields, action buttons         items by domain                reflection, storage, system, registries
```

Three parts, in dependency order:

- **A. `UntoldComponentKit`** (engine package, new library product and target, like `UntoldEngineAR`). Platform neutral: Foundation, simd, ObjC runtime, `UntoldEngine`. Holds `ComponentPlugin`, `@UntoldAttribute`, `EditorMenuPlugin`, `@UntoldMenu`, reflection, the storage component, the per-frame system, registries and discovery, and the USC bridge.
- **B. Editor** (macOS only): source discovery, compiler, loader, reload and state migration, inspector section, menu host, Plugins panel, Component SDK inside the app bundle.
- **C. Build system**: generated XcodeGen projects link the kit and call registration; the app bundle script ships the SDK.

## 4. Authoring components

### 4.1 What a developer writes

```swift
import UntoldComponentKit
import UntoldEngine
import simd

final class PlayerController: ComponentPlugin {
    @UntoldAttribute("Speed", range: 0...20) var speed: Float = 5
    @UntoldAttribute var jumpHeight: Float = 1.5
    @UntoldAttribute var lives: Int = 3
    @UntoldAttribute var invincible = false
    @UntoldAttribute var spawnOffset: SIMD3<Float> = [0, 1, 0]
    @UntoldAttribute(.color) var tint: SIMD4<Float> = [1, 1, 1, 1]
    @UntoldAttribute var target = EntityRef()                  // resolved by entity name
    @UntoldAttribute var footstep = AssetRef(category: .animations)
    @UntoldAttribute var stance: Stance = .idle                // String enum + CaseIterable: picker

    enum Stance: String, CaseIterable { case idle, walk, run }

    override class var actions: [PluginAction] {
        [
            PluginAction("Jump") { ($0 as! PlayerController).jump() },
            PluginAction("Reset") { ($0 as! PlayerController).reset() },
        ]
    }

    override func onStart() {
        // play mode began, or the entity was spawned during play
    }

    override func onUpdate(deltaTime dt: Float) {
        guard let transform else { return }
        if InputSystem.shared.keyState.wPressed { transform.position.z -= speed * dt }
    }

    func jump() { /* ... */ }
    func reset() { /* ... */ }
}
```

Rules the kit enforces or documents:

- Subclass `ComponentPlugin`. `final` is recommended. Generic classes are not discovered. No initializer parameters: the kit constructs every instance with `init()` and then applies saved values.
- Only stored properties wrapped in `@UntoldAttribute` are shown and saved. Everything else is runtime-only state.
- `actions` is an explicit table in v1. An attribute on the function itself needs a Swift macro (§5.5, D6).
- Lifecycle, in order: `onAttach()` (instance bound to an entity, edit or play), `onStart()` (play begins), `onUpdate(deltaTime:)` (each frame in play), `onFixedUpdate(deltaTime:)` (fixed step, in play), `onStop()`, `onDetach()`, and `onEditorChanged(property:)` (the inspector wrote a value; edit mode only).
- Access: `entity: EntityID`, `transform: LocalTransformComponent?`, the `scene` global and every public engine API. `ComponentPluginRegistry.entities(with: PlayerController.self)` and `ComponentPluginRegistry.component(PlayerController.self, on: entityId)` replace `queryEntities` for kit types.
- **Isolation rule.** Component sources may import only `UntoldEngine`, `UntoldComponentKit`, plugin modules declared for the project, Foundation and simd. They must not reference types from the app target: the editor compiles this folder on its own, and its compile error is the guard.

### 4.2 Supported `@UntoldAttribute` kinds

| Swift type | Inspector control | Saved as | Hints |
| --- | --- | --- | --- |
| `Float` | number field or slider | number | `range:`, `step:` |
| `Int` | number field or slider | integer | `range:`, `step:` |
| `Bool` | toggle | bool | |
| `String` | text field | string | `.multiline` |
| `SIMD3<Float>` | X/Y/Z fields (existing `TextInputVectorView`) | `[x, y, z]` | |
| `SIMD4<Float>` | X/Y/Z/W fields, or a color well with `.color` | `[x, y, z, w]` | `.color` |
| `EntityRef` | picker over scene entities, stores the entity name | `{"entity": "Enemy01"}` | see D7 |
| `AssetRef` | picker over the project's asset category, stores a project-relative path | `{"asset": "Animations/run.untold"}` | `category:` |
| `RawRepresentable<String> & CaseIterable` enum | popup | raw value | |

Optionals are not supported in v1. Adding a kind is one conformance to `UntoldAttributeValueType` in the kit plus one control in the editor.

### 4.3 Actions and scripts

Every `PluginAction` is registered in `USCActionRegistry` as `"<TypeName>.<ActionName>"` when its type registers, and removed when the type is replaced. A USC script attached to the same entity can call it with `callAction("PlayerController.Jump")`. The inspector shows one button per action, in edit mode and in play mode. Edit-mode actions are authoring helpers; their effects are not tracked by undo (the play-mode snapshot already protects the scene during play).

## 5. Extending the editor: `EditorMenuPlugin` and `@UntoldMenu`

Components describe entities. An `EditorMenuPlugin` describes what a loaded library adds to the editor itself. It is discovered the same way as components, instantiated once when its library loads, and ignored entirely in a game.

### 5.1 What a plugin author writes

This is the twins plugin's editor side, replacing `GaussianTwinPreviewSettings` and the hardcoded `Splat Debug` tree:

```swift
import UntoldComponentKit
import UntoldEngine
import UntoldGaussianTwins

final class GaussianTwinsEditor: EditorMenuPlugin {
    @UntoldMenu(.view, "Preview Splat Twins",
                tooltip: "Swap meshes linked to a .untoldgs twin for the splat as the scene camera approaches.")
    var previewTwins = true

    @UntoldMenu(.debug, "Splat Twin/Disable HZB Occlusion Cull") var disableHZBCull = false
    @UntoldMenu(.debug, "Splat Twin/Disable Opaque Depth Test") var disableDepthTest = false
    @UntoldMenu(.debug, "Splat Twin/Blend Cap") var blendCap: BlendCap = .c64      // enum: radio submenu

    @UntoldMenu(.debug, "Splat Twin/Reset Link Adoption")
    var resetAdoption = UntoldMenuAction { GaussianTwinSystem.shared.resetSceneLinkAdoption() }

    enum BlendCap: String, CaseIterable { case c64 = "64", c128 = "128", unlimited = "Unlimited" }

    override func menuDidChange(_ domain: UntoldMenuDomain, _ path: String) {
        if previewTwins { GaussianTwinSystem.shared.install() } else { GaussianTwinSystem.shared.uninstall() }
        GaussianDebugOptions.shared.disableHZBOcclusionCull = disableHZBCull
        GaussianDebugOptions.shared.disableOpaqueDepthTest = disableDepthTest
    }

    override func onSceneReset() { GaussianTwinSystem.shared.resetSceneLinkAdoption() }
    override func onUnload() { GaussianTwinSystem.shared.uninstall() }
}
```

### 5.2 `@UntoldMenu` kinds, domains and path rules

| Property type | Menu item | Example |
| --- | --- | --- |
| `Bool` | toggle with a checkmark | `@UntoldMenu(.debug, "Splat Twin/Preview") var preview = true` |
| `RawRepresentable<String> & CaseIterable` enum | submenu with one radio item per case | `Blend Cap ▸ 64 / 128 / Unlimited` |
| `UntoldMenuAction` | command | `Reset Link Adoption` |

Options: `key:` (key equivalent), `tooltip:`, `persist:` (default `true`), `enabled:` (closure evaluated when the menu opens).

Domains. The first argument names one of the editor's root menus. The set is closed and owned by the kit and the editor, so loaded code can never create a root menu:

| Domain | Root menu | Notes |
| --- | --- | --- |
| `.file` | `File` | the editor's existing menu; contributed items follow a separator below the editor's own |
| `.view` | `View` | same |
| `.debug` | `Debug` | owned by the editor, shown only while it holds at least one item |
| `.tools` | `Tools` | same; the home for plugin commands that are not diagnostics |

Path rules: the second argument is the item title, optionally preceded by submenu names separated by `/`, as in `"Splat Twin/Blend Cap"`. It never names a root. Items are grouped per extension and keep declaration order; a second declaration of the same domain and path is rejected with an error in the Components panel. Built-in items cannot be overridden. Adding a domain means changing the kit and the editor together.

### 5.3 Lifecycle

`onLoad()`, `onUnload()`, `onSceneReset()` (a scene was loaded or cleared, or the project switched: the three places the editor calls `GaussianTwinPreviewSettings.sceneDidReset()` today), `onPlayModeChanged(_:)`, `onEditorUpdate(deltaTime:)` (edit mode, optional), `menuWillOpen()` (refresh wrapped values from outside state so checkmarks stay truthful), `menuDidChange(_ domain:_ path:)`.

### 5.4 State and persistence

The wrapper owns the value. The editor persists it per project in `UserDefaults` under `editor.menu.<project-hash>.<domain>.<path>` and re-applies it on load and after every reload, then calls `menuDidChange` once per item. That reproduces what `GaussianTwinPreviewSettings` does by hand with `editor.gaussianTwins.preview`. `persist: false` opts out.

### 5.5 The function form

`@UntoldMenu(.debug, "SplatTwin", .bool) func setSplatTwin(_ on: Bool)` and `@UntoldMenu(.debug, "Splat Twin/Reset") func reset()` put the attribute on the function. Swift only allows custom attributes on functions through macros, so this form arrives with the macro package (D6): a member marker `@UntoldMenu` plus a type-level macro that synthesizes the same descriptors the wrappers produce. Semantics are identical: for `.bool` the editor owns and persists the state and calls the function on load and on every toggle. The property form above needs no macro and ships in v1.

### 5.6 Kinds of entity: `EntityPlugin`

A plugin's entity is not always a mesh. It can be a torus, but it can also be a spawn point, which the editor must show and the game must not; a spline, which is a tube in the game and a tube plus control points in the editor; or a rules object, which nothing shows. Loaded code adds such kinds with an `EntityPlugin`.

**The plugin is the entity, not a recipe for one.** An instance stays bound to each entity of the kind, is saved with the scene, and is bound again on load, in the editor and in the game. Everything that is part of the entity lives on it:

```swift
public final class SplinePathEntity: EntityPlugin {
    @UntoldAttribute("Start") public var start: SIMD3<Float> = [-1.5, 0, 0]          // its own properties
    @UntoldAttribute("Start Handle") public var startHandle: SIMD3<Float> = [-0.5, 1, 1]
    // ...
    override public func onAttach() { rebuild() }                                    // its geometry
    override public func onEditorChanged(property _: String) { rebuild() }

    override public var editorRepresentation: EditorRepresentation {                 // its editor representation
        EditorRepresentation([
            .polyline([start, startHandle, endHandle, end], closed: false),
            .points([start, end], tint: [1.0, 0.75, 0.2]),
            .points([startHandle, endHandle], tint: [0.35, 0.8, 1.0]),
        ])
    }
}
```

| Part of the entity | Mechanism | Saved |
| --- | --- | --- |
| Its own properties | `@UntoldAttribute` on the plugin; the Inspector shows them in the entity's own block, titled with the kind, above its components, with no remove button | yes, under `"entity"` next to `"components"` |
| Geometry | built in `onAttach` and `onEditorChanged`, handed over with `setGeneratedMesh(_:name:)` | no: the properties that define it are |
| Editor representation | `var editorRepresentation`: `.icon`, `.points`, `.polyline` and `.handles`, in the entity's local space; asked every frame while editing, so it follows the properties | no |
| Starting components | `onCreate()`, once, when the entity is first made from the kind | the components are |
| Behaviour | the same lifecycle and actions as a component | n/a |

An entity can have geometry, an editor representation, both or neither: torus, spawn point, spline, game rules. Icons are hidden by geometry in front of them, like the editor's light markers; lines and points are drawn over everything, so a handle inside a mesh stays visible. All of it is drawn in the editor's light marker pass, so it is absent in play mode and cannot reach a game. Lines reuse the pipeline of the selection box and are white; points are small billboards.

**Handles.** `.handles` names `SIMD3<Float>` properties, and each is a draggable point. The property is the truth and the dot follows it, so nothing new exists in the hierarchy, the scene file or play mode (the alternative, editor-only child entities, would have needed meshes to be pickable, a serializer rule to skip them, and removal at play). A click near a dot, with either button and within 14 points of it on screen (each handle is projected with the camera's own matrices, which a test checks against the engine's click ray), selects the entity and puts the move gizmo on the point instead of on the entity; the gizmo's own axis drag then writes the property through `ScenePluginSystem.setAttribute`, so `onEditorChanged` rebuilds the geometry as the point moves, and the drag is registered as one undo step. The selected handle is drawn white and holds while its entity stays the active one; the rotate and scale gizmos go back to the entity. Entities whose only presence is an editor representation get the gizmo too, so a spawn point can be moved in the viewport.

**Shelves are a closed set**, for the reason the menu roots are (§5.2): `.primitives` and `.lights` put the row under the built-in ones, and `.entities` is a third shelf that the Content browser shows only while it holds something. Rows behave like the built-in rows: drag into the viewport or onto the hierarchy, or double-click. The payload carries the kind's type name under its own key, so the existing drop decoding tells it from an asset, a light or a primitive.

**Component or entity.** A `ComponentPlugin` is something any entity could have. What could only ever belong to one kind of entity is not a component: it is a property of that entity. Revision 4 had it the other way round (a one-shot `EntityTemplate` plus a `TorusShape` component, then, in 4.1, a way to lock that component to its kind). The lock was a symptom: a component that can only be tied to one entity is part of the entity, so it became the entity's own properties and the lock went away.

For shapes the engine does not ship there was no public way in: `Mesh.makeMeshes` is internal. `BasicPrimitives.createMesh(from: MDLMesh)` is the one engine addition. Generated geometry is recorded by the scene as a procedural mesh name the engine does not know, which it restores as a cube; the plugin then replaces it on attach, and `setGeneratedMesh` carries the old submesh's material over, so material edits survive both a rebuild and a reload. A mesh built this way is part of the entity, and the editor's remove policy keeps it.

Entity plugins are discovered and registered per library revision like the other plugins, unregister with their library, and are listed in the Plugins tab. `ScenePluginSystem.discoverInApp()` registers them in a game too, where `EntityPluginRegistry.shared.instantiate(_:at:entityName:)` makes the same entities in code.

## 6. Kit internals

### 6.1 Reflection without macros

`UntoldAttribute<Value>` and `UntoldMenu<Value>` are **class-based** property wrappers conforming to `AnyUntoldAttribute` / `AnyUntoldMenu` (label or path, kind, hints, `getAny()`, `setAny(_:)`). `untoldAttributes()` and `untoldMenuItems()` walk `Mirror` from the root superclass down, in declaration order, and strip the `_` prefix from each wrapped property's label. Because the wrapper is a reference the instance owns, the inspector and the menu host write through the same object the code reads. No key paths, no code generation. Verified in spike B (§8).

### 6.2 Storage: one engine slot, kit-managed instances

`ScenePluginsComponent: Component, Codable` is the only engine component the kit adds. It holds `[Slot]` where a slot is `typeName`, `payload: [String: UntoldAttributeValue]` and `instance: ComponentPlugin?`.

Why not one engine component per user type:

- Engine component IDs are keyed by `ObjectIdentifier` of the Swift type. Every reload produces new types, so each reload would burn one of the 128 slots per user type.
- Scenes must load before the library is available (and in a fresh editor without one). A slot with `instance == nil` keeps its payload, round-trips it untouched on save, and is bound when the type appears. The inspector shows it as "not available in the loaded library".

### 6.3 Serialization

Registered once with `encodeCustomComponent(type: ScenePluginsComponent.self)`. The payload written under `customComponents["ScenePluginsComponent"]`:

```json
{
  "components": [
    {
      "type": "PlayerController",
      "properties": {
        "speed": 12.5,
        "spawnOffset": [0, 1, 0],
        "target": { "entity": "Enemy01" },
        "stance": "walk"
      }
    }
  ]
}
```

Serialization is reflection-driven, not synthesized `Codable`. Two reasons: spike B showed that a subclass of a `Codable` class does not get synthesized coding for its own properties, and reflection tolerates properties added or removed between reloads (missing: default kept; extra: dropped with a log line).

### 6.4 Registries and discovery

`ComponentPluginRegistry` and `EditorMenuPluginRegistry` map unqualified type names to types, with a `revision` stamp. `discover(imagePath:)` uses `objc_copyClassNamesForImage` and keeps classes whose superclass chain reaches `ComponentPlugin` or `EditorMenuPlugin`. No entry point and no hand-maintained list. Spike C proved it for a loaded dylib and for classes compiled into an executable with `-O -whole-module-optimization -dead_strip`, where nothing references them. The game calls `discoverInApp()`. Duplicate names across modules are rejected with an error. `rebind(name:to:)` is what a reload calls: same name, new type, old instances migrated (§7.5).

### 6.5 System

`ScenePluginSystem: EngineExtension`, id `com.untoldengine.componentkit`. `update` forwards to `onUpdate` only while `gameMode` is true; `fixedUpdate` forwards to `onFixedUpdate` (already gated by the engine). It ticks after input and scene-graph traversal and before LOD and batching, which is where `EngineExtensionRegistry.updateExtensions` sits in `runFrame`. `startPlayMode()` / `stopPlayMode()` mirror `USCSystem`.

### 6.6 Cleanup and threading

`ComponentRegistry.register(componentType: ScenePluginsComponent.self)` calls `onDetach` on every live instance when an entity is destroyed. Callbacks run on the engine's simulation thread: main on macOS and iOS, the compositor render thread on visionOS (`runFrame` is driven from there in XR). Components must not touch SwiftUI or UIKit state directly. The kit builds in language mode 6; user sources compile in language mode 5 (same as the editor and generated games).

## 7. Editor integration

### 7.1 What gets compiled

| Source | Location | Reloads |
| --- | --- | --- |
| The project's plugins folder | `<Root>/Sources/<Project>Plugins/`, or the `pluginsFolder` path in `<Root>/UntoldEditor.json` | on save |
| A plugin package listed by path (under development) | `pluginPackages[].path` in `UntoldEditor.json`; the package root holds `untold-package.json` | on save |
| A plugin package the editor already links | its editor sources only; the runtime module comes from the SDK | on save |

Two places, named apart on purpose. The *plugins folder* belongs to the one game: part of the app like any source folder, no manifest, created by the editor. A *plugin package* is a Swift package of its own that several projects share (`UntoldGaussianTwins`), with a `Package.swift` for games and an `untold-package.json` for the editor; it is the "plugin package" of the engine's plugin architecture docs. Either can hold component, entity and editor menu plugins. `BuildSystem.pluginsFolderName(forProject:)` is the one place the folder name lives; the names from before the rename (`<Project>Components`, the `components` and `plugins` keys, `untold-plugin.json`) are still read, and each is reported in the Plugins tab and the console with what to rename it to, so projects made earlier keep working.

`UntoldEditor.json` (optional, project root):

```json
{ "pluginsFolder": "Sources/SplatTwinPlugins",
  "pluginPackages": [ { "path": "../../../Libs/UntoldGaussianTwins" } ] }
```

`untold-package.json` (plugin package root):

```json
{ "id": "com.miolabs.untold.gaussianTwins",
  "module": "UntoldGaussianTwins",
  "runtimeSources": "Sources/UntoldGaussianTwins",
  "editorSources": "Sources/UntoldGaussianTwinsEditor" }
```

If the plugins folder is missing, the panel offers **Create plugins folder**, mirroring `ScriptProjectManager.initializeProject`.

### 7.2 Component SDK inside the app bundle

Compiling against the editor's own modules is what lets loaded code share the editor's engine (one `scene`, one registry). The bundle ships `Contents/Resources/ComponentSDK/`:

```
ComponentSDK/
├── Modules/
│   ├── UntoldEngine.swiftmodule          (+ .swiftdoc)
│   ├── UntoldComponentKit.swiftmodule    (+ .swiftdoc)
│   └── UntoldGaussianTwins.swiftmodule   (every plugin the editor links; listed in sdk.json)
├── CShaderTypes/
│   ├── *.h                               (UntoldEngine imports this clang module)
│   └── module.modulemap                  (rewritten with a relative umbrella; SwiftPM's points at the checkout)
└── sdk.json   { swiftCompilerVersion, engineRevision, target, languageMode, providedModules }
```

When the editor runs from source, the SDK resolves to the build directory next to the executable. Two SwiftPM layouts exist and the resolver probes both: `.build/<triple>/<config>/Modules/` (classic build system, what the editor's current `.build` uses) and `.build/out/Products/<Config>/` (the newer build system Swift 6.4 selected in the spikes). `create_app_bundle.sh` gains the copy step and writes `sdk.json`.

### 7.3 Compile

`ComponentCompiler` runs `/usr/bin/xcrun swiftc` by absolute path (the user's `swift` on `PATH` can be a swiftly shim; on the baseline machine it points at a missing toolchain):

```
/usr/bin/xcrun swiftc -emit-library -parse-as-library \
  -o <cache>/<Module>_r<N>.dylib -module-name <Module>_r<N> \
  -emit-module -emit-module-path <cache>/<Module>_r<N>.swiftmodule \
  -module-alias <Plugin>=<Plugin>_r<N>            (one per reloadable plugin this module imports)
  -swift-version 5 -Onone -g -D UNTOLD_EDITOR \
  -target arm64-apple-macosx14.0 -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -I <SDK>/Modules -I <cache> -Xcc -fmodule-map-file=<SDK>/CShaderTypes/module.modulemap \
  -Xlinker -undefined -Xlinker dynamic_lookup \
  <every .swift in the source folder>
```

`<cache>` is `~/Library/Caches/com.untoldengine.studio/Components/<project-hash>/`. Build order: package runtime modules, then package editor modules, then the project module. Diagnostics go to the Log Console and the Components panel. The compile runs as a `TaskCenter` task with cancel. Pre-flight: `swiftc --version` must equal `sdk.json.swiftCompilerVersion`; otherwise one clear error names the required Xcode. `-D UNTOLD_EDITOR` lets sources guard editor-only code with `#if UNTOLD_EDITOR`.

### 7.4 Load

`ComponentLibraryLoader` loads plugin runtime libraries with `RTLD_NOW | RTLD_GLOBAL` and everything else with `RTLD_NOW | RTLD_LOCAL`, then runs discovery on each image. Spike D showed why: a module that imports a reloadable plugin resolves the plugin's symbols through the flat namespace, which only sees global images. Libraries are never `dlclose`d: Swift runtime metadata cannot be unloaded safely. `N` increments per build and every module name is unique per build, which avoids the ObjC runtime's duplicate-class registration (spike A). `-module-alias` keeps `import UntoldGaussianTwins` valid in source while the real module is `UntoldGaussianTwins_r<N>` (spike D).

### 7.5 Reload protocol

Runs on the main thread between frames (the draw loop is on main; a `DispatchQueue.main` block lands between two `MTKView` draws):

1. If play mode is on, stop it. This restores the pre-play snapshot, so play-mode drift is never migrated.
2. Snapshot: every slot's live instance is reflected into its payload. Extensions get `onUnload()`.
3. Load revision `N+1` of every rebuilt module, discover, `rebind` every type by name. Types that disappeared keep their payload and lose their instance.
4. Re-instantiate components: `init()`, apply payload (missing property: default; extra property: dropped, logged), `onAttach()`. Instantiate extensions, rebuild their menu items, re-apply persisted values, call `onLoad()` then `menuDidChange` per item.
5. Refresh inspector and hierarchy. USC action registrations are replaced.

The old libraries stay mapped. Their memory cost is roughly the dylib size per reload and is shown in the panel.

### 7.6 Rebuild on save, inspector, panel

- A `DispatchSource` watcher on every reloadable source folder, debounced 300 ms, triggers compile + reload when **Rebuild on save** is on. Off by default on the first open of a project; the panel asks once. A manual **Build** button always exists. The editor only ever compiles the opened project's component folder and the plugins that project declares.
- Components from code are rendered by `ScenePluginInspectorView`, drawn by the Inspector directly like Splat Twin so scene-composition mode keeps them, and styled like the engine's components. Per attached instance: display name, remove button, the field form generated from `untoldAttributes()`, then action buttons. Unknown types render as a read-only row that keeps their payload. There is one **Add Component** menu (`AddComponentMenu`): the engine's components, then the registry's types under a "From Code" heading. Edits go through `EditorUndoManager.registerValueChange`, mark the scene dirty, and call `onEditorChanged(property:)`.
- The Content browser's Primitives and Lights shelves list the entity kinds loaded code added under the built-in rows, and an Entities shelf appears while it has any (§5.6).
- A **Plugins** tab beside Log and Tasks: per-module status (`r<N>`, built at, compiler), discovered components with instance counts, loaded extensions with their menu paths, entity kinds with their shelf, the error list (click opens the file at the line in Xcode via `xed --line`), and the buttons **Build**, **Rebuild on save**, **Open in Xcode**, **Reveal folder**.
- Everything sits behind `EditorFeatureFlags.enableCodeComponents`.

### 7.7 Menu host

`EditorMenuHost` owns every contributed `NSMenuItem`. It builds items from `untoldMenuItems()` of each loaded extension, maps each domain to its root menu (`Debug` and `Tools` are shown only while they hold items), tags items with their owner revision, and on reload removes the old revision's items before building the new ones. It is the `NSMenuDelegate` for contributed menus: `menuNeedsUpdate` calls the extension's `menuWillOpen()` and then syncs checkmarks and radio marks from the wrapped values, the same pattern the app delegate uses today for its own items. A click writes the wrapper, persists the value, and calls `menuDidChange(domain, path)`.

### 7.8 Plugin packages, and moving the twins integration out of the editor

A plugin package keeps its runtime where it is (`Sources/UntoldGaussianTwins`, linked by games through SwiftPM as today) and adds an editor-only folder, `Sources/UntoldGaussianTwinsEditor`, which no game target compiles.

Two loading modes:

- **The editor links the plugin** (the twins today). The SDK provides the runtime module, the loader compiles only the plugin's editor sources, and their symbols resolve into the running editor exactly as engine symbols do. There is one `GaussianTwinSystem`. This is the mode to start with.
- **The editor does not link the plugin.** The loader compiles the runtime sources as `<Module>_r<N>`, loads it globally, and aliases it for everything that imports it. This works for Swift-only plugins without resources, which is what UntoldGaussianTwins is (three files, one dependency). Plugins with metallibs or C targets need a resource story first and are out of scope for v1.

A plugin must never be present both ways at once: a statically linked copy and a loaded copy would mean two singletons, with the inspector talking to one and the menu to the other. `sdk.json.providedModules` is what the loader checks.

Migration of the twins integration happens after the feature has been tested on the sample project (stage 5), in two steps:

1. **Menus and system lifecycle** move to `GaussianTwinsEditor` (§5.1): `Preview Splat Twins`, the `Splat Debug` toggles and radio submenus, the `Working Set` submenu, install/uninstall and `sceneDidReset`. `GaussianTwinPreviewSettings.swift` and the menu code in `UntoldEditorApp.swift` are deleted. The editor keeps linking the plugin.
2. **The Splat Twin inspector section, align mode and link persistence** stay in the editor for now. They are SwiftUI views over editor internals, and the declarative API here cannot express them. They move when an editor UI module exists for plugins to import (out of scope, listed in stage 4). After that the editor stops linking the plugin.

## 8. Feasibility spikes (Xcode 27.0, Swift 6.4, SwiftPM release builds)

Spikes A and B ran on 2026-09-14, C and D on 2026-09-17. Appendix B has the commands.

### Spike A: dynamic loading into a SwiftPM executable

| Check | Result |
| --- | --- |
| dylib built with `-I <build>/Modules` and `-Xlinker -undefined -Xlinker dynamic_lookup`, no host library linked, loads with `RTLD_NOW` and its entry runs | Pass |
| Globals are shared: the plugin incremented a host global; the host read the new value | Pass (counter 101 after one register + 100) |
| A host function the host never references (`@inline(never)`) is still in the executable and callable from the plugin | Pass (`nm` finds it; SwiftPM does not dead-strip) |
| A small unreferenced function absent from the executable | Still callable: the client emitted its own copy through cross-module optimization |
| Two versions of the plugin with the same module name loaded in one process | Both work, but the ObjC runtime warns that the class is implemented twice |
| Same, with a unique module name per version | Pass, no warning |

### Spike B: reflection without macros

| Check | Result |
| --- | --- |
| Class-based wrapper on `Float`, `Int`, `Bool`, `SIMD3<Float>`; `Mirror` lists the five wrapped properties in declaration order with label and range; an unwrapped property is skipped | Pass |
| Inspector-style write through the reflected wrapper changes the component's value; a later `onUpdate` mutates it further | Pass (5 → 12.5 → 13.0) |
| Synthesized `Codable` on a subclass of a `Codable` base class | Produced `{}`: subclasses get no synthesis, hence §6.3 |

### Spike C: discovery through the ObjC runtime

| Check | Result |
| --- | --- |
| `objc_copyClassNamesForImage` on the main executable finds two `ComponentPlugin` subclasses nothing references, built with `-O` | Pass |
| Same with `-O -Xlinker -dead_strip` | Pass |
| Same with `-O -whole-module-optimization -Xlinker -dead_strip` (what an Xcode Release app target does) | Pass |
| Same API on a `dlopen`ed dylib with no entry point; non-component classes filtered out; instances created through `init()` | Pass |

### Spike D: a reloadable plugin module imported by project code

| Check | Result |
| --- | --- |
| Plugin built as `TwinLib_r1`; project sources say `import TwinLib` and compile with `-module-alias TwinLib=TwinLib_r1` | Pass |
| Plugin loaded `RTLD_GLOBAL`, project loaded `RTLD_LOCAL`; project code calls the plugin's singleton | Pass |
| Revision 2 of both loaded into the same process after revision 1; each project revision sees its own plugin revision; no ObjC warnings | Pass |
| Control: plugin loaded `RTLD_LOCAL` | Fails as predicted: `symbol not found in flat namespace` |

### Still to prove in stage 0

- Compiling against the editor's real `UntoldEngine.swiftmodule` (it imports `CShaderTypes` and Metal) with the SDK layout in §7.2, from a bundled app and from a source build, in both SwiftPM layouts.
- `-target` and deployment-target agreement between the editor binary and the loaded dylibs.
- Removing and rebuilding contributed `NSMenuItem`s across a reload while a menu is open.
- Wall time of a full compile (expected 1 to 3 s for a handful of files) and of the reload protocol on a scene with a few hundred instances.

## 9. Final target path

Generated projects and the twin demos are XcodeGen projects. Their app target's sources are `Sources/` minus `GameData`, so `Sources/<Project>Plugins/` is compiled into the app with no new target. Three changes:

1. `XcodeGenProjectSpec.generateYAML` adds the kit to the app target's dependencies:

```yaml
    dependencies:
      - package: UntoldEngine
        product: UntoldComponentKit
```

2. The engine package reference comes from `BuildSettings` instead of the hardcoded upstream URL and `branch: develop`, and defaults to the revision the editor was built with (D8). While the kit exists only on the fork, projects that use it point at `https://github.com/miolabs/UntoldEngine.git`.
3. The generated `GameScene` registers before loading scenes:

```swift
private func configureEngineSystems() {
    gameMode = true
    AnimationSystem.shared.isEnabled = true
    ComponentPluginRegistry.discoverInApp()
    ScenePluginSystem.install()          // registers the EngineExtension and the storage component's serializer
    ScenePluginSystem.shared.startPlayMode()
    /* ... */
}
```

Scenes decode `customComponents` as they do today; slots bind to the statically linked types; `onAttach` and `onStart` run. iOS and visionOS use exactly this path. Nothing dynamic ships in a game. `EditorMenuPlugin` subclasses compile into the game only if their file is not guarded by `#if UNTOLD_EDITOR`; they are never instantiated there.

XcodeGen lists files at generation time, so the editor re-runs `xcodegen generate` after it creates the plugins folder or a new plugin file (`BuildSystem` already locates the tool). For an existing project such as SplatTwin or BedroomTwin, **Create component package** adds the dependency line to `project.yml`, regenerates, and prints the registration snippet to the Log Console.

SwiftPM-style projects (the legacy `BuildTemplates.packageSwift` path) get the same result with a `<Project>Plugins` library target that the executable depends on.

## 10. Constraints, risks, mitigations

| Risk | Effect | Mitigation |
| --- | --- | --- |
| Binary `.swiftmodule` files are compiler-version specific | Compiles must use the same `swiftc` that built the editor | `sdk.json` check with a clear error naming the required Xcode; a source-built editor always matches. The release workflow must build with a current Xcode (it uses Swift 6.0 today). Later: `.swiftinterface` with library evolution (D3) |
| Swift dylibs cannot be unloaded | Memory grows by about one dylib per module per reload | Unique module names, old instances released, footprint shown in the panel |
| Reloaded types have new identity | Any engine-side reference to a user type goes stale | All references go through the kit registries by name; the engine never sees user types (§6.2) |
| A plugin present both statically and as a loaded copy | Two singletons; inspector and menu drive different systems | `sdk.json.providedModules` decides the mode per plugin; never both (§7.8) |
| Plugin runtime loaded with `RTLD_LOCAL` | Dependent modules fail to load | Loader rule in §7.4, covered by the integration test |
| Components share the app module in the game but compile alone in the editor | Code that references app types builds in Xcode and fails in the editor | Isolation rule (§4.1); the editor's error names the file and line |
| Editor engine revision differs from the project's pinned engine | Compiles against an API the game does not have, or vice versa | Warn from `sdk.json.engineRevision` vs the project's resolved pin; D8 removes the skew for new projects |
| User code runs in the editor process | A crash in a component or a menu action takes the editor down | Autosave the open scene before every play and every reload. Later: out-of-process play |
| visionOS drives `runFrame` from the compositor render thread | Component callbacks are off the main thread there | Documented in §6.6; no SwiftUI or UIKit access from callbacks |
| Two types with the same name, or two menu items with the same domain and path | Ambiguity | Registries and the menu host reject the second with an error in the panel |
| The editor README states the editor is not for gameplay logic or script attachment | This feature changes that stance | Behind `enableCodeComponents`; on in the fork, proposed upstream with the flag off (D4) |
| Loading code from a folder | Same trust level as running the project in Xcode | Only the opened project's folder and its declared plugins are compiled; rebuild-on-save is opt-in per project |

## 11. Staged delivery

Branches are cut from the fork's `develop`. The editor feature branch points its engine dependency at the engine feature branch by name. Commits and pushes to the fork are fine at any time; no pull request until §12's end-to-end bar is met.

| Stage | Goal | Repo | Branch | Contents | Tests |
| --- | --- | --- | --- | --- | --- |
| 0 | Close the open spikes (§8) | scratch | none | Real-module compile from source and bundle; target agreement; menu rebuild across reload; timings | Notes appended to this document |
| 1 | Kit, static path | engine | `feature/component_kit` | `Sources/UntoldComponentKit/`: `ComponentPlugin`, `UntoldAttribute`, values, `EntityRef`, `AssetRef`, `PluginAction`, `EditorMenuPlugin`, `UntoldMenu`, `UntoldMenuAction`, storage component, registries and discovery, system, USC bridge; package product; `docs/API/UsingCodeComponents.md` | Reflection order and kinds, payload round-trip, unknown-type preservation, discovery in the test image, rebind migration, gating on `gameMode`, USC registration, menu descriptor reflection and path parsing |
| 1b | Generated projects | engine | `feature/component_kit_projects` | XcodeGen spec dependency and configurable engine reference; `GameScene` registration; add-to-existing-project helper; SwiftPM template target | Spec snapshot tests; a generated project builds in CI |
| 2 | Editor loads at project open | editor | `feature/code_components_loader` | Source locator and manifests, SDK resolution and `sdk.json`, compiler (build graph, aliases), loader (global and local), Components panel, feature flag; bundle script SDK step | Locator and manifest parsing; compiler argument builder (pure, snapshot-tested); SDK resolution in both layouts; integration test that compiles fixtures against the test build's modules and loads them, including a plugin runtime plus a dependent module |
| 2b | Inspector | editor | `feature/code_components_inspector` | Inspector section, new `EditorField` kinds, Add Component submenu, undo and dirty-state wiring, play-mode wiring | Form generation; undo of an edit; add and remove mark dirty; play start and stop reach the system |
| 2c | Menu host | editor | `feature/code_components_menus` | `EditorMenuHost`, path resolution, persistence, `menuWillOpen` / `menuDidChange`, extension lifecycle calls at scene reset and play changes | Path to menu tree; checkmark and radio sync; persisted value re-applied; duplicate path rejected; items removed on unload |
| 3 | Hot reload | editor | `feature/code_components_hot_reload` | Reload protocol (§7.5), watcher and rebuild-on-save, autosave before reload, panel status | Migration with added and removed properties; reload during play stops play first; menu items rebuilt with values kept; watcher debounce |
| 3b | Sample project and sample plugin: the test vehicle for the whole loop | engine | `feature/component_kit_sample` | `Examples/CodeComponentsSample`: a generated macOS project with two components and one `EditorMenuPlugin` that adds a `Debug` menu, plus `SamplePlugin`, a tiny Swift-only plugin package listed by path with its own editor sources | The §12 end-to-end checklist is run against it by hand; its sources double as fixtures for the loader integration test |
| 4 | Polish | all | per item | Entity and asset pickers, enum popups, color well; macro package for `@UntoldMenu` and `@Callable` on functions (D6); editor UI module so plugins can ship inspector sections; library-evolution SDK (D3); stable entity IDs (D7); plugin resources | Per item |
| 5 | Twins plugin and twin demo adopt it, after the end-to-end test passes; done together with the twin gaussian session, which is on hold until then | twins + editor + arcade | `feature/editor_extension` (twins), `feature/twins_menus_from_plugin` (editor), demo branch in `UntoldArcade` | `untold-plugin.json`, `Sources/UntoldGaussianTwinsEditor/GaussianTwinsEditor.swift`; editor deletes `GaussianTwinPreviewSettings` and the hardcoded twin and splat debug menus; the demo's `project.yml` links the kit and gains a components folder | `SplatDebugMenuTests` ported to the descriptor level; preview toggle persists across relaunch; demo builds for visionOS |

Order: 1 before 1b and 2; 2 before 2b, 2c and 3; 3b needs 1b and is what stages 2 to 3 are tested against; 5 starts only after the end-to-end test passes; 4 is independent items. Stage 2 alone is already useful: libraries load once at project open, and a relaunch picks up changes.

## 12. Acceptance criteria

- **Stage 1.** A test target defines a `ComponentPlugin` subclass with every supported kind; `untoldAttributes()` lists them in order; a scene saved with the kit's payload loads back with equal values; a scene saved with a type the test image does not contain round-trips its payload unchanged; `onUpdate` runs only in game mode; USC `callAction("Type.Action")` invokes the action on the entity; an `EditorMenuPlugin` subclass reports its menu descriptors with parsed paths.
- **Stage 1b.** A project created from the editor builds in Xcode with a components folder that contains the starter component, and the running game instantiates it from the saved scene.
- **Stage 2.** Opening a project with a plugins folder compiles it, the Plugins panel lists the types, and **Add Component** offers them. A compile error appears in the panel and the Log Console with file and line, and clicking it opens Xcode at that line. From a bundled app the compile uses only files inside `Contents/Resources/ComponentSDK`.
- **Stage 2b.** Every kind renders its control; edits are undoable and mark the scene dirty; values survive save and reload of the scene.
- **Stage 2c.** An extension's `@UntoldMenu(.debug, "Splat Twin/…")` items appear when its library loads, under the editor's `Debug` root, which was hidden while empty; an item cannot name or create a root menu; toggles show checkmarks, enums show radio marks, values persist across relaunch, and the menu disappears when the project closes.
- **Stage 3.** Editing and saving a component in Xcode while the editor is open, with rebuild-on-save on, updates the inspector within a few seconds; instance values survive the reload; a renamed property falls back to its default and logs; a removed type keeps its payload and shows as unavailable; menu items are rebuilt with their values kept.
- **End to end (the bar for opening pull requests).** Run on `Examples/CodeComponentsSample`. The project opens in the editor. Its components compile, load, are editable and hot-reload. The sample extension's `Debug` menu and the sample plugin's menu appear on load, keep their values across reload and relaunch, and disappear when the project closes. The sample app builds in Xcode with the same component sources and behaves the same from the saved scene.
- **After the bar (stage 5).** The twins plugin's menus come from the plugin's own editor sources, no twin menu code remains in the editor, and the twin demo builds for visionOS with a components folder.

## 13. Test plan

Kit tests run on macOS in `swift test` and are platform neutral apart from discovery, which is tested on macOS only. Editor tests use `@testable import UntoldEditor` under `swift test --filter UntoldEditorTests` as today. The dynamic-loading integration test builds fixtures with the same compiler invocation the editor uses, against the test process's own build directory, and loads them: one standalone module, and one plugin runtime plus a dependent module through an alias. It is the automated form of spikes A, C and D and guards the same-compiler contract; it runs only when `xcrun swiftc` is available (skipped otherwise, never failed). Menu host tests work on descriptors and an `NSMenu` built in memory; no window is needed.

## 14. Decisions

### Locked on 2026-09-17 (recommendations accepted)

| # | Decision | Outcome |
| --- | --- | --- |
| D1 | Where the kit lives | A target and product in the engine package, `UntoldComponentKit` |
| D2 | Storage | One engine slot with kit-managed instances |
| D3 | Compiler policy | Same compiler as the editor for v1; library evolution revisited later |
| D4 | Editor scope | Behind `enableCodeComponents`, on in the fork, proposed upstream with the flag off |
| D5 | Where component sources live | One folder inside the project. **Corrected in revision 2:** generated projects are XcodeGen projects, so the folder sits under `Sources/` and is compiled by the app target; only SwiftPM-style projects get a separate target |
| D6 | Attributes on functions | Explicit tables and property wrappers for v1; macros in stage 4, in a separate `UntoldComponentMacros` package so the engine package keeps zero dependencies |
| D7 | Entity references | By name. Scene UUIDs are regenerated on every save (`SceneSerializer.swift:509`), so a stable ID is engine work outside this proposal |
| D8 | Engine pin in generated projects | The editor's engine revision, from `sdk.json` |
| Naming | Wrapper names | `@UntoldAttribute` for inspector properties, `@UntoldMenu` for menu items |
| Menu roots | How an item picks its root menu | The first argument is a domain from a closed set (`.file`, `.view`, `.debug`, `.tools`); the second is the submenu path or just the title. Loaded code cannot create root menus |
| Sequencing | What the feature is tested on | Its own sample project and sample plugin first. The twin gaussian session is on hold until that test passes; the twins plugin and the twin demo are updated afterwards (stage 5) |

### Open

| # | Question | Default if nothing is said |
| --- | --- | --- |
| N1 | `@UntoldMenu` directly on a function needs the macro package. Pull D6 forward so the function form exists from the first version? | No. v1 ships the property form in §5.1; the function form follows in stage 4 |
| N2 | Stage 5, first migration of the twins integration: menus and system lifecycle move to the plugin first; the Splat Twin inspector section, align mode and link persistence stay in the editor until plugins can ship UI | Yes, in that order (§7.8) |

## Appendix A. Touch list

**Engine**

- `Package.swift`: product `UntoldComponentKit`, target `Sources/UntoldComponentKit`, test target.
- `Sources/UntoldComponentKit/`: `ComponentPlugin.swift`, `UntoldAttribute.swift`, `UntoldAttributeValue.swift`, `EntityRef.swift`, `AssetRef.swift`, `PluginAction.swift`, `EditorMenuPlugin.swift`, `UntoldMenu.swift`, `ScenePluginsComponent.swift`, `ComponentPluginRegistry.swift`, `EditorMenuPluginRegistry.swift`, `ImageDiscovery.swift`, `ScenePlugin.swift`, `ScenePluginSystem.swift`, `USCBridge.swift`, `EntityPlugin.swift`, `EditorRepresentation.swift`.
- `Sources/UntoldEngine/Mesh/BasicPrimitives.swift`: `createMesh(from:)`.
- `Sources/UntoldEngine/BuildSystem/XcodeGenProjectSpec.swift`: kit dependency, configurable engine reference.
- `Sources/UntoldEngine/BuildSystem/BuildTemplates.swift`: registration call, starter component file, SwiftPM template target.
- `Sources/UntoldEngine/BuildSystem/BuildSystem.swift`: add-to-existing-project helper, `xcodegen generate` re-run.
- `docs/API/UsingCodeComponents.md`, `docs/index.md` link.

**Editor**

- `Sources/UntoldEditor/Components/`: `ComponentSourceLocator.swift`, `EditorProjectManifest.swift`, `PluginPackageManifest.swift`, `ComponentSDK.swift`, `ComponentCompiler.swift`, `ComponentLibraryLoader.swift`, `ComponentReloadCoordinator.swift`, `ComponentSourceWatcher.swift`, `ComponentsPanelView.swift`, `ScenePluginInspectorView.swift`, `EditorMenuHost.swift`.
- `Sources/UntoldEditor/UntoldEditorApp.swift`: hand the menu bar to `EditorMenuHost`; in stage 3b, delete the twin and splat debug items.
- `Sources/UntoldEditor/Editor/InspectorView.swift`: the code component blocks and the one `AddComponentMenu`.
- `Sources/UntoldEditor/Components/`: also `AddComponentMenu.swift`, `EntityPluginPlacement.swift`, `EntityPluginShelfViews.swift`, `EditorRepresentationRenderer.swift`.
- `Sources/UntoldEditor/Editor/AssetPlacement.swift`, `AssetBrowserView.swift`, `AssetBrowserNavigationState.swift`: the entity plugin row payload, the rows on the shelves, the Entities shelf.
- `Sources/UntoldEditor/Renderer/EditorRenderPasses.swift`: markers drawn in the light marker pass.
- `Sources/UntoldEditor/Editor/ComponentEditorForm.swift`: new `EditorField` kinds.
- `Sources/UntoldEditor/Editor/EditorView.swift`: discovery on project open, play-mode start/stop, scene-reset notifications to extensions, bottom-panel tab.
- `Sources/UntoldEditor/Config/EditorFeatureFlags.swift`: `enableCodeComponents`.
- `create_app_bundle.sh`: Component SDK copy and `sdk.json`.
- `Tests/UntoldEditorTests/`: one file per new type plus `ComponentLoaderIntegrationTests.swift`.

**UntoldGaussianTwins**

- `untold-package.json`, `Sources/UntoldGaussianTwinsEditor/GaussianTwinsEditor.swift`.

## Appendix B. Reproducing the spikes

Spike A, host package: a library target exporting `public var sharedCounter`, a `Registry` class, a `Plugin` protocol, `register(_:)`, and an `@inline(never)` function the executable never calls; an executable that `dlopen`s each argument, `dlsym`s `untold_plugin_entry`, calls it, and prints the global. Build with `/usr/bin/swift build -c release`. Compile and run the plugin:

```sh
BIN=.build/release
/usr/bin/swiftc -emit-library -o libPlugin.1.dylib -module-name GameComponents_r1 \
  -I "$BIN" -I "$BIN/Modules" Plugin.swift -Xlinker -undefined -Xlinker dynamic_lookup
"$BIN/HostApp" libPlugin.1.dylib
nm -m libPlugin.1.dylib | grep 'dynamically looked up'
```

Spike B: a single file with the class wrapper, its protocol, a `ComponentPlugin` base with the reflection walk, and a `PlayerController` subclass; compile with `/usr/bin/swiftc -O reflect.swift` and run.

Spike C: a `discoverComponents(imagePath:)` function built on `objc_copyClassNamesForImage` and `class_getSuperclass`; two subclasses nothing references. Build the three-file executable with `-O`, with `-O -Xlinker -dead_strip`, and with `-O -whole-module-optimization -Xlinker -dead_strip`, and pass `_dyld_get_image_name(0)`. For the dylib case the host `dlopen`s the path and passes the same path to discovery.

Spike D:

```sh
swiftc -emit-library -parse-as-library -emit-module -emit-module-path out/TwinLib_r1.swiftmodule \
  -module-name TwinLib_r1 -o out/TwinLib_r1.dylib -I "$BIN" TwinLib.swift -Xlinker -undefined -Xlinker dynamic_lookup
swiftc -emit-library -parse-as-library -module-name GameComponents_r1 -module-alias TwinLib=TwinLib_r1 \
  -o out/GameComponents_r1.dylib -I "$BIN" -I out Project.swift -Xlinker -undefined -Xlinker dynamic_lookup
"$BIN/HostApp" G:out/TwinLib_r1.dylib out/GameComponents_r1.dylib     # "G:" = RTLD_GLOBAL in the spike host
```
