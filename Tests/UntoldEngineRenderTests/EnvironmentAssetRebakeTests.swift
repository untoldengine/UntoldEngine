import Foundation
@testable import UntoldEngine
import XCTest

/// An environment loaded from outside the engine bundle must survive the
/// IBL re-bake that `initSizeableResources()` runs on every viewport change.
final class EnvironmentAssetRebakeTests: BaseRenderSetup {
    override func initializeAssets() {}

    private var customDirectory: URL?

    override func tearDown() {
        if let customDirectory {
            try? FileManager.default.removeItem(at: customDirectory)
        }
        super.tearDown()
    }

    func testViewportRebakeKeepsEnvironmentLoadedFromCustomDirectory() throws {
        // A copy of a bundled HDR under a name the engine bundle does not have.
        let source = try XCTUnwrap(
            LoadingSystem.shared.resourceURL(forResource: "teatro_massimo_2k", withExtension: "hdr", subResource: nil)
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("untold-env-rebake-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        customDirectory = directory
        try FileManager.default.copyItem(at: source, to: directory.appendingPathComponent("custom_room.hdr"))

        setRendering(.environment(.asset("custom_room.hdr", directory: directory)))
        XCTAssertTrue(iblSuccessful, "The custom environment must load")
        XCTAssertEqual(hdrURL, "custom_room.hdr")
        XCTAssertEqual(hdrDirectoryURL, directory)

        // What the XR layer (and any window resize) does next.
        initIBLResources()

        XCTAssertTrue(iblSuccessful, "The re-bake must find the environment where it was loaded from")
        XCTAssertEqual(hdrURL, "custom_room.hdr", "The re-bake must not fall back to the default environment")
        XCTAssertNotNil(textureResources.irradianceMap)
    }
}
