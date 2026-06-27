import Foundation
import XCTest

@MainActor
final class ExternalRenderExtensionPackageTests: XCTestCase {
    func testExternalWaterRenderPluginPackageBuildsAndPassesItsContractTests() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fixture = repositoryRoot
            .appendingPathComponent(
                "Examples/RenderingExtensions/SwiftPackagePlugin",
                isDirectory: true
            )
        let scratch = FileManager.default.temporaryDirectory
            .appendingPathComponent("WaterRenderPlugin-(UUID().uuidString)", isDirectory: true)
        let logURL = scratch.appendingPathComponent("swift-test.log")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        defer { try? FileManager.default.removeItem(at: scratch) }

        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "swift", "test",
            "--package-path", fixture.path,
            "--scratch-path", scratch.appendingPathComponent("build").path,
        ]
        process.standardOutput = log
        process.standardError = log
        try process.run()
        process.waitUntilExit()
        try log.synchronize()

        let output = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertEqual(
            process.terminationStatus,
            0,
            "External render-extension fixture failed:\n\(output)"
        )
    }
}
