# Rendering Extension Examples

These examples demonstrate the two supported ways to integrate Rendering
Extensions with Untold Engine.

## Application-Local

[`ApplicationLocal`](ApplicationLocal/README.md) contains a focused model-surface
extension and Metal shader intended to be added directly to an application or
framework target.

Use it to learn:

- the `RenderExtension` authoring hooks;
- direct registration through `setRendering`;
- model-surface argument-buffer registration and binding;
- attaching an extension component to an entity.

## Swift Package Plugin

[`SwiftPackagePlugin`](SwiftPackagePlugin/README.md) is a complete, independently
buildable Swift package and an automated acceptance fixture.

Because `SwiftPackagePlugin` contains its own `Package.swift`, Xcode treats it as
a separate nested package and may not show its folder in the parent UntoldEngine
package navigator. The files are still available at
`Examples/RenderingExtensions/SwiftPackagePlugin`. Open that folder's
`Package.swift` separately, add it as a local package dependency, or include both
packages in an Xcode workspace. Do not add its source files directly to the
UntoldEngine target.

Use it to learn:

- package dependency and resource setup;
- precompiled metallib bundling;
- plugin manifests and public installation entry points;
- atomic installation of package-owned extensions;
- consumer-side component configuration;
- camera-aware procedural scene drawing;
- render-pipeline lookup and safe scene color/depth encoding.

> The package fixture uses water-themed names and placeholder shaders to exercise
> the complete API. It is not a real or production-ready water renderer.

Both examples use the same underlying `RenderExtension` API. Applications can
use application-local extensions and package plugins at the same time as long as
their globally registered artifact IDs are unique.

For the authoring guide, see
[Creating a Rendering Extension Plugin](../../docs/Extensions/CreatingRenderingExtensionPlugin.md).
For the complete API reference, see
[Using Rendering Extensions](../../docs/API/UsingRenderingExtensions.md). For
internal behavior, see
[Rendering Extensions Architecture](../../docs/Architecture/RenderingExtensions.md).
