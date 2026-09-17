//
//  DiscoveryTests.swift
//  UntoldComponentKitTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldComponentKit
@testable import UntoldEngine
import XCTest

@MainActor
final class DiscoveryTests: XCTestCase {
    override func setUp() async throws {
        resetKitTestState()
    }

    func testImageDiscoveryFindsSubclassesAndNeverTheBase() throws {
        let imagePath = try XCTUnwrap(ImageDiscovery.imagePath(containing: SpinnerComponent.self))
        let names = ImageDiscovery.classes(inImageAt: imagePath, inheritingFrom: ComponentPlugin.self)
            .map { String(describing: $0) }

        XCTAssertTrue(names.contains("SpinnerComponent"))
        XCTAssertTrue(names.contains("BaseMover"))
        XCTAssertTrue(names.contains("DerivedMover"), "indirect subclasses count")
        XCTAssertFalse(names.contains("ComponentPlugin"))
        XCTAssertFalse(names.contains("SampleExtension"), "other hierarchies are filtered out")
        XCTAssertNotNil(ImageDiscovery.mainExecutablePath())
    }

    func testAnUnknownImageYieldsNothing() {
        XCTAssertTrue(ImageDiscovery.classes(inImageAt: "/nonexistent/image.dylib", inheritingFrom: ComponentPlugin.self).isEmpty)
    }

    func testRegistryDiscoveryRegistersTheImageAndReportsNameClashes() {
        let report = ComponentPluginRegistry.shared.discover(imageContaining: SpinnerComponent.self, revision: 3)

        XCTAssertTrue(report.registered.contains("SpinnerComponent"))
        XCTAssertTrue(report.registered.contains("DerivedMover"))
        XCTAssertEqual(report.registered.filter { $0 == "Reloadable" }.count, 1)
        XCTAssertEqual(report.rejected, ["Reloadable"], "the test image holds two types named Reloadable")
        XCTAssertEqual(ComponentPluginRegistry.shared.entries.first { $0.name == "SpinnerComponent" }?.revision, 3)

        let second = ComponentPluginRegistry.shared.discover(imageContaining: SpinnerComponent.self)
        XCTAssertTrue(second.registered.isEmpty, "discovering the same image again changes nothing")
    }

    func testExtensionDiscovery() throws {
        let imagePath = try XCTUnwrap(ImageDiscovery.imagePath(containing: SampleExtension.self))
        let names = EditorMenuPluginRegistry.shared.discover(imagePath: imagePath, revision: 2)

        XCTAssertTrue(names.contains("SampleExtension"))
        XCTAssertTrue(names.contains("BrokenExtension"))
        XCTAssertFalse(names.contains("SpinnerComponent"))
        XCTAssertTrue(EditorMenuPluginRegistry.shared.type(named: "SampleExtension") == SampleExtension.self)
        XCTAssertEqual(EditorMenuPluginRegistry.shared.entries.first { $0.name == "SampleExtension" }?.revision, 2)
    }
}

extension DiscoveryTests {
    func testAppImagesAlwaysIncludeTheMainExecutable() throws {
        let executable = try XCTUnwrap(ImageDiscovery.mainExecutablePath())
        XCTAssertTrue(ImageDiscovery.appImagePaths().contains(executable))
    }

    func testDiscoverInAppDoesNotPickUpImagesOutsideTheApp() {
        // Under XCTest the "app" is the test runner, and these doubles live in the test bundle
        // elsewhere on disk, so they must not be registered by the app-wide scan.
        ScenePluginSystem.discoverInApp()
        XCTAssertNil(ComponentPluginRegistry.shared.type(named: "SpinnerComponent"))
        XCTAssertNil(EntityPluginRegistry.shared.type(named: "MarkerEntity"))
    }
}
