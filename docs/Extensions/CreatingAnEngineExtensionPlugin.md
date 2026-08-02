# Creating an Engine Extension Plugin

This tutorial builds a reusable Swift package that simulates its own entity
state every frame — the shape a physics, audio, or AI backend takes. The
finished plugin owns a `Component`, steps its own simulation on the
fixed-timestep loop, and cleans itself up completely on uninstall, without
touching engine internals.

Use this tutorial for plugins that do not render anything. If your plugin
also owns a render-graph pass — for example, a particle or splat system that
both simulates and draws itself — implement `RenderExtension` instead; it
already includes everything in this tutorial (`update`, `fixedUpdate`,
`willUnregister`) because `RenderExtension` refines `EngineExtension`. See
[Creating a Rendering Extension Plugin](CreatingRenderingExtensionPlugin.md).
Do not implement both protocols on the same type and register with both
registries — see [Which Mechanism Should I Use?](#which-mechanism-should-i-use)
below.

## What You Will Build

The plugin will:

1. define a `Component` that marks an entity as plugin-owned;
2. conform to `EngineExtension` and register with `EngineExtensionRegistry`;
3. step its own simulation once per fixed timestep;
4. track entity lifecycle so it never touches a destroyed entity; and
5. release every resource it owns on `willUnregister()`.

## Prerequisites

- Xcode with Swift 6;
- an Untold Engine checkout or released package dependency; and
- a reverse-DNS namespace owned by you.

The examples use `com.example.gravitybody`. Replace it with your own
namespace.

## Which Mechanism Should I Use?

Untold Engine has two ways to get a per-frame callback. Pick one per type:

- **`EngineExtension` / `EngineExtensionRegistry`** (this tutorial) — for a
  distributable package with its own identity, versioning, and lifecycle
  guarantees. Use this when the simulation logic ships to other projects.
- **`registerCustomSystem(_:)`** (see [Plugin Authoring
  Guidelines](PluginAuthoringGuidelines.md#lifecycle)) — a lightweight,
  closure-based hook for a single game's own gameplay code. No package, no
  namespace, no protocol conformance. Use this for logic that lives inside
  one application and is never distributed.

A type that also conforms to `RenderExtension` must register only with
`RenderExtensionRegistry`, never additionally with `EngineExtensionRegistry`
— `RenderExtension` already inherits the `EngineExtension` contract, so
registering with both would tick `update`/`fixedUpdate` twice per frame.

## 1. Create the Package

```sh
mkdir GravityBodyPlugin
cd GravityBodyPlugin
swift package init --type library --name GravityBodyPlugin
```

Use this layout:

```text
GravityBodyPlugin/
├── Package.swift
├── Sources/
│   └── GravityBodyPlugin/
│       ├── GravityBodyPlugin.swift
│       ├── GravityBodyComponent.swift
│       └── GravityBodyExtension.swift
└── Tests/
    └── GravityBodyPluginTests/
        └── GravityBodyPluginTests.swift
```

## 2. Configure `Package.swift`

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "GravityBodyPlugin",
    platforms: [.macOS(.v14), .iOS(.v17), .visionOS(.v2)],
    products: [
        .library(
            name: "GravityBodyPlugin",
            targets: ["GravityBodyPlugin"]
        ),
    ],
    dependencies: [
        .package(path: "/path/to/UntoldEngine"),
    ],
    targets: [
        .target(
            name: "GravityBodyPlugin",
            dependencies: [
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "GravityBodyPluginTests",
            dependencies: [
                "GravityBodyPlugin",
                .product(name: "UntoldEngine", package: "UntoldEngine"),
            ],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
```

For local development, point at your engine checkout with a `path:`
dependency, as shown. A distributed plugin should use the canonical engine
repository URL and a compatible release requirement — the application and
plugin must resolve the same Untold Engine package identity and version.

Match `platforms:` to every platform your consuming application targets, at
versions at or above the engine's own minimums (currently macOS 14, iOS 17,
visionOS 2). SwiftPM defaults an unlisted platform to its lowest OS version,
so a plugin that only declares `.macOS(.v14)` will fail to build into a
visionOS or iOS app with an unhelpful "requires minimum platform version"
error at the *application's* build, not the plugin's — easy to miss until
someone actually tries to consume the plugin from that platform.

## 3. Define Stable IDs

Create `GravityBodyPlugin.swift`:

```swift
import UntoldEngine

public enum GravityBodyPluginContract {
    public static let pluginID = "com.example.gravitybody"
    public static let extensionID = "com.example.gravitybody"
}
```

An `EngineExtension`'s `id` occupies the same registry namespace other
plugins register into. If a plugin exposes more than one `EngineExtension`,
each extension ID must equal the plugin ID or begin with the plugin ID
followed by a dot — the same rule `RenderExtension` plugins follow.

## 4. Define the Component

Create `GravityBodyComponent.swift`:

```swift
import UntoldEngine
import simd

public final class GravityBodyComponent: Component {
    public var velocity: simd_float3 = .zero
    public var gravityScale: Float = 1.0

    public required init() {}
}
```

`Component` only requires a default initializer. Defining it in your own
package — rather than in engine core — is the point: `registerComponent`
and `ComponentRegistry.register` are public precisely so this never requires
an engine change.

## 5. Implement the Extension

Create `GravityBodyExtension.swift`:

```swift
import UntoldEngine
import simd

final class GravityBodyExtension: EngineExtension, @unchecked Sendable {
    let id = GravityBodyPluginContract.extensionID

    private var trackedEntities: Set<EntityID> = []
    private var destroySubscription: EventSubscription?

    init() {
        ComponentRegistry.register(
            componentType: GravityBodyComponent.self,
            handlerId: GravityBodyPluginContract.pluginID
        ) { [weak self] entityId in
            self?.trackedEntities.remove(entityId)
        }

        destroySubscription = EntityLifecycleEvents.shared.onEntityDestroyed { [weak self] event in
            self?.trackedEntities.remove(event.entityId)
        }
    }

    func fixedUpdate(deltaTime: Float, context _: EngineExtensionUpdateContext) {
        let entities = queryEntities(with: [
            GravityBodyComponent.self,
            LocalTransformComponent.self,
        ])

        for entityId in entities {
            guard let body = scene.get(component: GravityBodyComponent.self, for: entityId),
                  let transform = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }

            body.velocity += simd_float3(0, -9.8 * body.gravityScale, 0) * deltaTime
            transform.position += body.velocity * deltaTime
            trackedEntities.insert(entityId)
        }
    }

    func willUnregister() {
        destroySubscription?.cancel()
        destroySubscription = nil
        trackedEntities.removeAll()
    }
}
```

Notes:

- `fixedUpdate` runs inside the fixed-timestep loop in game mode, alongside
  every other registered `EngineExtension` and `RenderExtension`, in
  registration order. Use `update(deltaTime:context:)` instead for logic that
  should run every rendered frame regardless of game mode.
- Query entities with `queryEntities(with:)` rather than storing your own
  entity list — the ECS mask index is already built for this and stays
  correct as entities are created and destroyed elsewhere in the scene.
- `EntityLifecycleEvents.shared.onEntityDestroyed` is entity-level
  bookkeeping (here, keeping `trackedEntities` accurate for diagnostics).
  Component-specific cleanup — releasing the component's own data when it's
  removed from an entity — goes through `ComponentRegistry.register(...)`
  instead, as shown in `init()`.
- `willUnregister()` is the only place you need explicit teardown code. It
  runs on `unregister(id:)`, on `removeAll()`, and on hot-swap replacement
  (registering a new instance under an already-registered `id`) — cancel
  subscriptions and drop cached state there, not in `deinit`.

## 6. Add the Plugin Registration Function

Continue in `GravityBodyPlugin.swift`:

```swift
@discardableResult
public func registerGravityBodyPlugin() -> EngineExtensionRegistrationResult {
    EngineExtensionRegistry.shared.register(GravityBodyExtension())
}

public func unregisterGravityBodyPlugin() {
    EngineExtensionRegistry.shared.unregister(id: GravityBodyPluginContract.extensionID)
}
```

There is no plugin-bundle registry for `EngineExtension` the way
`RenderExtensionPluginRegistry` exists for render extensions — a plugin with
one extension registers it directly. If your plugin needs several
`EngineExtension` types, register each one in your public installation
function and unregister each by `id` in the uninstall function, in reverse
order.

Expose a small public function rather than asking application code to
construct and register `GravityBodyExtension` itself — that keeps the
extension type's initializer free to change without breaking consumers.

## 7. Install the Plugin in an Application

```swift
import GravityBodyPlugin
import UntoldEngine

let result = registerGravityBodyPlugin()
switch result {
case .registered, .replaced:
    break
}
```

Unlike `RenderExtensionPluginRegistry.install(...)`, `EngineExtensionRegistry.register(_:)`
has no rejection case — there is no artifact ownership to conflict over, so
installation always succeeds. Call it before or after `UntoldRenderer.create()`;
`EngineExtension` has no render-resource dependency that requires a specific
ordering.

## 8. Test the Contract

```swift
@testable import GravityBodyPlugin
import UntoldEngine
import XCTest

@MainActor
final class GravityBodyPluginTests: XCTestCase {
    override func tearDown() {
        EngineExtensionRegistry.shared.removeAll()
    }

    func testRegistrationSucceeds() {
        XCTAssertEqual(registerGravityBodyPlugin(), .registered)
        XCTAssertTrue(
            EngineExtensionRegistry.shared.registeredIDs()
                .contains(GravityBodyPluginContract.extensionID)
        )
    }

    func testFixedUpdateIntegratesGravity() {
        registerGravityBodyPlugin()

        let entityId = createEntity()
        registerComponent(entityId: entityId, componentType: GravityBodyComponent.self)
        registerComponent(entityId: entityId, componentType: LocalTransformComponent.self)

        let context = EngineExtensionUpdateContext(
            viewport: SIMD2<Int>(0, 0),
            immersionStyle: .none,
            frameIndex: 1,
            currentEye: 0,
            isPrimaryEye: true
        )
        EngineExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)

        let transform = scene.get(component: LocalTransformComponent.self, for: entityId)
        XCTAssertLessThan(transform?.position.y ?? 0, 0)
    }

    func testUnregisterStopsSteppingEntities() {
        registerGravityBodyPlugin()
        unregisterGravityBodyPlugin()

        XCTAssertFalse(
            EngineExtensionRegistry.shared.registeredIDs()
                .contains(GravityBodyPluginContract.extensionID)
        )
    }
}
```

Run:

```sh
swift build
swift test
```

## Completion Checklist

- The plugin builds independently from the engine package.
- The `Component` type and every ID are defined in the plugin package, not in
  engine core.
- The extension ID is namespaced under the plugin ID.
- Component cleanup is registered through `ComponentRegistry.register(...)`.
- `willUnregister()` cancels every subscription and releases every cached
  reference the extension owns.
- The plugin conforms to only one of `EngineExtension` or `RenderExtension`
  per type, and registers with exactly one registry.
- Tests cover registration, simulation behavior, and unregistration.

## Common Failures

| Symptom | Likely cause |
| --- | --- |
| `update`/`fixedUpdate` fires twice per frame | The type conforms to `RenderExtension` and was registered with both `RenderExtensionRegistry` and `EngineExtensionRegistry`. Register with `RenderExtensionRegistry` only. |
| Extension keeps running after uninstall | Cleanup logic was placed in `deinit` instead of `willUnregister()`; if anything else still holds a reference to the instance, `deinit` never runs. |
| Simulation touches a destroyed entity | Entities were cached in a local array instead of queried fresh each `fixedUpdate`, or `scene.get(component:for:)` wasn't guarded with `guard let`. |
| Simulation runs in edit mode when it shouldn't | Logic was placed in `update(deltaTime:context:)` instead of `fixedUpdate(deltaTime:context:)` — only the latter is gated by game mode. |

For lifecycle and registration reference, see [Plugin Authoring
Guidelines](PluginAuthoringGuidelines.md). For the render-graph counterpart,
see [Creating a Rendering Extension Plugin](CreatingRenderingExtensionPlugin.md).
