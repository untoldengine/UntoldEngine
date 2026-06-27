import Metal
import UntoldEngine
import WaterRenderPlugin
import XCTest

final class WaterRenderPluginTests: XCTestCase {
    func testPluginManifestAndExtensionNamespaceAreValid() {
        let plugin = WaterRenderPlugin()

        XCTAssertEqual(plugin.manifest.id, WaterRenderPluginContract.pluginID)
        XCTAssertEqual(plugin.manifest.requiredAPIVersion, .current)
        XCTAssertTrue(RenderExtensionPluginValidator.validate(plugin).isValid)
        XCTAssertEqual(
            plugin.makeRenderExtensions().map(\.id),
            [WaterRenderPluginContract.extensionID]
        )
    }

    func testBundledMetallibContainsEveryDeclaredFunction() throws {
        let url = try XCTUnwrap(WaterRenderPlugin.bundledMetallibURL)
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let library = try device.makeLibrary(URL: url)

        XCTAssertNotNil(library.makeFunction(name: "waterFixtureTextureKernel"))
        XCTAssertNotNil(library.makeFunction(name: "waterFixtureSurfaceFragment"))
    }

    func testPublicRegistrationEntryPointHasPluginInstallationSignature() {
        let entryPoint: () -> RenderExtensionPluginInstallationResult = registerWaterRenderPlugin
        _ = entryPoint
    }
}
