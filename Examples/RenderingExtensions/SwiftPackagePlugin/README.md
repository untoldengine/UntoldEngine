# Water Render Plugin Fixture

> **Example fixture only:** This package is not a real or production-ready water
> renderer. Its shaders and visual behavior are intentionally minimal placeholders
> used to demonstrate and test how a third-party Rendering Extension is packaged,
> registered, validated, and distributed with Swift Package Manager.

This nested package is the acceptance fixture for distributing an Untold Engine
rendering extension independently from the engine package. It contains:

- a `RenderExtensionPlugin` manifest and public registration entry point;
- compute and model-surface extension implementations;
- declared texture resources and compute/render pipelines;
- a model-surface argument-buffer layout;
- Metal source plus a bundled, precompiled macOS `.metallib`;
- consumer-side tests that import only public engine and plugin APIs.

## Opening in Xcode

This directory contains its own `Package.swift`, so Xcode treats it as a separate
package boundary and may hide it from the parent UntoldEngine package navigator.
Open this directory's `Package.swift` separately, add the directory as a local
package dependency, or include both packages in an Xcode workspace. Do not add
the package's source files directly to the UntoldEngine target.

## Engine Dependency

The fixture's `Package.swift` uses:

```swift
.package(path: "../../..")
```

That path is relative to this package directory and works only while the fixture
is nested inside the UntoldEngine repository. It is not resolved relative to the
consuming application. If you copy the package elsewhere, replace it with the
path to your local engine checkout:

```swift
.package(path: "/path/to/UntoldEngine")
```

For distribution, use the canonical UntoldEngine repository URL and a compatible
version requirement instead. The consuming application and plugin should resolve
the same UntoldEngine package source and version.

## Consumer Integration

Add the `WaterRenderPlugin` library product to the application target, import the
module, and install it before renderer creation:

```swift
import WaterRenderPlugin

let result = registerWaterRenderPlugin()
```

`registerWaterRenderPlugin()` installs every extension in the plugin atomically.
The package remains a compile-time SwiftPM dependency; this is not runtime module
discovery or dynamic loading from an arbitrary folder.

Install the plugin once during application startup, before renderer creation,
and handle the installation result:

```swift
import UntoldEngine
import WaterRenderPlugin

func installWaterRendering() -> Bool {
    switch registerWaterRenderPlugin() {
    case .installed:
        return true
    case .replaced:
        // A plugin with the same manifest ID was already installed and was
        // replaced atomically by this version.
        return true
    case let .rejected(failure):
        print("Water plugin validation errors:", failure.validationErrors)
        print("Water plugin artifact conflicts:", failure.artifactConflicts)
        print("Water plugin graph errors:", failure.graphValidationErrors)
        return false
    }
}
```

After installation, create a model entity and attach the public component
exported by the package. The plugin's surface pass selects only entities carrying
this component:

```swift
if installWaterRendering() {
    let water = createEntity()
    setEntityMeshDirect(
        entityId: water,
        meshes: BasicPrimitives.createPlane(),
        assetName: "water"
    )
    registerComponent(entityId: water, componentType: WaterSurfaceComponent.self)

    if let surface = getEntityComponent(
        entityId: water,
        componentType: WaterSurfaceComponent.self
    ) {
        surface.tint = SIMD4<Float>(0.08, 0.38, 0.62, 1.0)
        surface.roughness = 0.08
        surface.waveStrength = 0.18
    }
}
```

Do not also register `WaterSurfaceRenderExtension` through `setRendering`. The
plugin entry point already creates it with the package-only `Bundle.module` and
registers it under plugin lifecycle management.

## Package Plugin Versus Application-Local Extension

This package and the
[`ApplicationLocal`](../ApplicationLocal/README.md)
sample use the same `RenderExtension` hooks and argument-buffer APIs. The tint
sample shows the smallest application-local implementation. This fixture adds
the pieces required for third-party distribution:

- a SwiftPM library product and `Bundle.module` resource access;
- a bundled precompiled metallib;
- a versioned `RenderExtensionPluginManifest`;
- a factory that can supply one or more extensions;
- one public function that installs or rolls back the complete plugin.

Applications can use both forms simultaneously. Register application-local
extensions with `setRendering(.extensions(.register(...)))` and install package
plugins through `RenderExtensionPluginRegistry` or their public entry points.
Every extension and artifact ID must remain globally unique. Extension-owned
resources remain private and cannot be accessed by another provider.

Run the fixture independently from the engine repository root:

```sh
swift test --package-path Examples/RenderingExtensions/SwiftPackagePlugin
```

Rebuild the bundled macOS shader library after changing the Metal source:

```sh
Examples/RenderingExtensions/SwiftPackagePlugin/Scripts/build-metallib.sh
```

A production package should build and bundle a metallib for every platform and
SDK it supports. This fixture is macOS-only so the checked-in binary has one
unambiguous target.
