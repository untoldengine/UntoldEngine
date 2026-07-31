//
//  PhysicsBackendRegistryTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

private final class MockPhysicsBackend: PhysicsBackend {
    let id: String
    let capabilities: PhysicsCapabilities
    private(set) var configuration: PhysicsWorldConfiguration?
    private(set) var stepCount = 0

    init(id: String, capabilities: PhysicsCapabilities = []) {
        self.id = id
        self.capabilities = capabilities
    }

    func configure(_ config: PhysicsWorldConfiguration) {
        configuration = config
    }

    func step(deltaTime _: Float) {
        stepCount += 1
    }
}

private struct MockBackendPlugin: PhysicsBackendPlugin {
    let manifest: PhysicsBackendPluginManifest
    let backendID: String

    init(
        pluginID: String = "com.example.mockphysics",
        displayName: String = "Mock Physics",
        requiredAPIVersion: PhysicsBackendAPIVersion = .current,
        backendID: String? = nil
    ) {
        manifest = PhysicsBackendPluginManifest(
            id: pluginID,
            displayName: displayName,
            version: PhysicsBackendVersion(major: 1, minor: 0, patch: 0),
            requiredAPIVersion: requiredAPIVersion
        )
        self.backendID = backendID ?? pluginID
    }

    func makeBackend() -> any PhysicsBackend {
        MockPhysicsBackend(id: backendID)
    }
}

final class PhysicsBackendRegistryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        PhysicsBackendRegistry.shared.resetForTesting()
    }

    override func tearDown() {
        PhysicsBackendRegistry.shared.resetForTesting()
        super.tearDown()
    }

    func testInstallValidPlugin() {
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin())

        XCTAssertEqual(result, .installed)
        XCTAssertEqual(PhysicsBackendRegistry.shared.activeManifest()?.id, "com.example.mockphysics")
        XCTAssertEqual(PhysicsBackendRegistry.shared.activeBackend()?.id, "com.example.mockphysics")
        XCTAssertNil(PhysicsBackendRegistry.shared.failure(forPluginID: "com.example.mockphysics"))
    }

    func testEmptyPluginIDIsRejected() {
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(pluginID: "", backendID: "some.backend"))

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertTrue(failure.validationErrors.contains(.emptyPluginID))
        XCTAssertNil(PhysicsBackendRegistry.shared.activeBackend())
    }

    func testNonNamespacedPluginIDIsRejected() {
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(pluginID: "mockphysics"))

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertTrue(failure.validationErrors.contains(.pluginIDMustBeNamespaced("mockphysics")))
    }

    func testEmptyDisplayNameIsRejected() {
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(displayName: "  "))

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertTrue(failure.validationErrors.contains(.emptyDisplayName(pluginID: "com.example.mockphysics")))
    }

    func testAPIVersionMismatchIsRejected() {
        let result = PhysicsBackendRegistry.shared.install(
            MockBackendPlugin(requiredAPIVersion: PhysicsBackendAPIVersion(99))
        )

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertEqual(
            failure.validationErrors,
            [.unsupportedAPIVersion(
                pluginID: "com.example.mockphysics",
                required: PhysicsBackendAPIVersion(99),
                supported: .current
            )]
        )
    }

    func testBackendIDOutsidePluginNamespaceIsRejected() {
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(backendID: "org.other.backend"))

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertTrue(failure.validationErrors.contains(
            .backendIDOutsidePluginNamespace(
                pluginID: "com.example.mockphysics",
                backendID: "org.other.backend"
            )
        ))
    }

    func testNamespacedBackendIDInsidePluginNamespaceIsAccepted() {
        let result = PhysicsBackendRegistry.shared.install(
            MockBackendPlugin(backendID: "com.example.mockphysics.world")
        )

        XCTAssertEqual(result, .installed)
        XCTAssertEqual(PhysicsBackendRegistry.shared.activeBackend()?.id, "com.example.mockphysics.world")
    }

    func testSecondPluginWithDifferentIDIsRejected() {
        PhysicsBackendRegistry.shared.install(MockBackendPlugin())
        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(pluginID: "com.example.otherphysics"))

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertEqual(failure.conflictingPluginID, "com.example.mockphysics")
        XCTAssertEqual(
            PhysicsBackendRegistry.shared.failure(forPluginID: "com.example.otherphysics"),
            failure
        )
        XCTAssertEqual(PhysicsBackendRegistry.shared.activeManifest()?.id, "com.example.mockphysics")
    }

    func testReinstallingSamePluginIDReplaces() {
        PhysicsBackendRegistry.shared.install(MockBackendPlugin())
        let previousBackend = PhysicsBackendRegistry.shared.activeBackend()

        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin())

        XCTAssertEqual(result, .replaced)
        XCTAssertNotNil(PhysicsBackendRegistry.shared.activeBackend())
        XCTAssertTrue(PhysicsBackendRegistry.shared.activeBackend() !== previousBackend)
    }

    func testUninstall() {
        PhysicsBackendRegistry.shared.install(MockBackendPlugin())

        XCTAssertTrue(PhysicsBackendRegistry.shared.uninstall(id: "com.example.mockphysics"))
        XCTAssertNil(PhysicsBackendRegistry.shared.activeBackend())
        XCTAssertNil(PhysicsBackendRegistry.shared.activeManifest())
    }

    func testUninstallUnknownIDReturnsFalse() {
        XCTAssertFalse(PhysicsBackendRegistry.shared.uninstall(id: "com.example.unknown"))

        PhysicsBackendRegistry.shared.install(MockBackendPlugin())
        XCTAssertFalse(PhysicsBackendRegistry.shared.uninstall(id: "com.example.unknown"))
        XCTAssertNotNil(PhysicsBackendRegistry.shared.activeBackend())
    }

    func testLockedRegistryRejectsInstall() {
        PhysicsBackendRegistry.shared.lockForRuntime()

        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin())

        guard case let .rejected(failure) = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertTrue(failure.registryLocked)
        XCTAssertNil(PhysicsBackendRegistry.shared.activeBackend())
    }

    func testLockedRegistryRejectsUninstall() {
        PhysicsBackendRegistry.shared.install(MockBackendPlugin())
        PhysicsBackendRegistry.shared.lockForRuntime()

        XCTAssertFalse(PhysicsBackendRegistry.shared.uninstall(id: "com.example.mockphysics"))
        XCTAssertNotNil(PhysicsBackendRegistry.shared.activeBackend())
    }

    func testValidationRejectionDoesNotDisturbActivePlugin() {
        PhysicsBackendRegistry.shared.install(MockBackendPlugin())

        let result = PhysicsBackendRegistry.shared.install(MockBackendPlugin(pluginID: "notnamespaced"))

        guard case .rejected = result else {
            return XCTFail("Expected rejection, got \(result)")
        }
        XCTAssertEqual(PhysicsBackendRegistry.shared.activeManifest()?.id, "com.example.mockphysics")
    }

    func testBackendDefaultImplementationsAreInert() {
        let backend = MockPhysicsBackend(id: "com.example.mockphysics")

        XCTAssertNil(backend.raycast(
            PhysicsRay(origin: .zero, direction: simd_float3(0, -1, 0)),
            filter: PhysicsQueryFilter()
        ))

        var entities = [EntityID](repeating: .invalid, count: 4)
        var transforms = [PhysicsBodyTransform](
            repeating: PhysicsBodyTransform(position: .zero, orientation: simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)),
            count: 4
        )
        let written = entities.withUnsafeMutableBufferPointer { entityBuffer in
            transforms.withUnsafeMutableBufferPointer { transformBuffer in
                backend.readActiveTransforms(
                    into: PhysicsTransformReadBatch(entities: entityBuffer, transforms: transformBuffer)
                )
            }
        }
        XCTAssertEqual(written, 0)
    }
}
