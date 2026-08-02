//
//  EngineExtensionLifecycleTest.swift
//  UntoldEngineTests
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

private final class LifecycleTrackingEngineExtension: EngineExtension, @unchecked Sendable {
    let id: String
    var updates: [(Float, UInt64)] = []
    var fixedUpdates: [(Float, UInt64)] = []
    var willUnregisterCount = 0

    init(id: String) {
        self.id = id
    }

    func update(deltaTime: Float, context: EngineExtensionUpdateContext) {
        updates.append((deltaTime, context.frameIndex))
    }

    func fixedUpdate(deltaTime: Float, context: EngineExtensionUpdateContext) {
        fixedUpdates.append((deltaTime, context.frameIndex))
    }

    func willUnregister() {
        willUnregisterCount += 1
    }
}

private final class DefaultOnlyEngineExtension: EngineExtension, @unchecked Sendable {
    let id: String
    init(id: String) {
        self.id = id
    }
}

private func makeTestContext(frameIndex: UInt64 = 1) -> EngineExtensionUpdateContext {
    EngineExtensionUpdateContext(
        viewport: SIMD2<Int>(640, 480),
        immersionStyle: .none,
        frameIndex: frameIndex,
        currentEye: 0,
        isPrimaryEye: true
    )
}

final class EngineExtensionLifecycleTest: XCTestCase {
    override func tearDown() {
        EngineExtensionRegistry.shared.removeAll()
        super.tearDown()
    }

    func testUpdateAndFixedUpdateDispatchInRegistrationOrder() {
        let first = LifecycleTrackingEngineExtension(id: "test.engine.first")
        let second = LifecycleTrackingEngineExtension(id: "test.engine.second")
        XCTAssertEqual(EngineExtensionRegistry.shared.register(first), .registered)
        XCTAssertEqual(EngineExtensionRegistry.shared.register(second), .registered)
        XCTAssertEqual(EngineExtensionRegistry.shared.registeredIDs(), [first.id, second.id])

        let context = makeTestContext(frameIndex: 42)
        EngineExtensionRegistry.shared.updateExtensions(deltaTime: 0.25, context: context)
        EngineExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)

        XCTAssertEqual(first.updates.count, 1)
        XCTAssertEqual(second.updates.count, 1)
        XCTAssertEqual(first.updates[0].0, 0.25)
        XCTAssertEqual(second.updates[0].1, 42)
        XCTAssertEqual(first.fixedUpdates.count, 1)
        XCTAssertEqual(second.fixedUpdates.count, 1)
    }

    func testUnregisterCallsWillUnregisterAndRemovesFromRegisteredIDs() {
        let extensionInstance = LifecycleTrackingEngineExtension(id: "test.engine.unregister")
        XCTAssertEqual(EngineExtensionRegistry.shared.register(extensionInstance), .registered)

        EngineExtensionRegistry.shared.unregister(id: extensionInstance.id)

        XCTAssertEqual(extensionInstance.willUnregisterCount, 1)
        XCTAssertFalse(EngineExtensionRegistry.shared.registeredIDs().contains(extensionInstance.id))
    }

    func testRemoveAllCallsWillUnregisterOnEveryExtension() {
        let first = LifecycleTrackingEngineExtension(id: "test.engine.removeAll.first")
        let second = LifecycleTrackingEngineExtension(id: "test.engine.removeAll.second")
        EngineExtensionRegistry.shared.register(first)
        EngineExtensionRegistry.shared.register(second)

        EngineExtensionRegistry.shared.removeAll()

        XCTAssertEqual(first.willUnregisterCount, 1)
        XCTAssertEqual(second.willUnregisterCount, 1)
        XCTAssertTrue(EngineExtensionRegistry.shared.registeredIDs().isEmpty)
    }

    func testHotSwapReplaceCallsWillUnregisterOnPreviousInstanceOnlyAndReturnsReplaced() {
        let original = LifecycleTrackingEngineExtension(id: "test.engine.replace")
        let replacement = LifecycleTrackingEngineExtension(id: "test.engine.replace")

        XCTAssertEqual(EngineExtensionRegistry.shared.register(original), .registered)
        XCTAssertEqual(EngineExtensionRegistry.shared.register(replacement), .replaced)

        XCTAssertEqual(original.willUnregisterCount, 1)
        XCTAssertEqual(replacement.willUnregisterCount, 0)
        XCTAssertEqual(EngineExtensionRegistry.shared.registeredIDs(), [replacement.id])
    }

    func testDefaultImplementationsAreNoOps() {
        let extensionInstance = DefaultOnlyEngineExtension(id: "test.engine.defaults")
        XCTAssertEqual(EngineExtensionRegistry.shared.register(extensionInstance), .registered)

        let context = makeTestContext()
        EngineExtensionRegistry.shared.updateExtensions(deltaTime: 0.1, context: context)
        EngineExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)
        EngineExtensionRegistry.shared.unregister(id: extensionInstance.id)
        // No crash and no assertions to make beyond reaching this point — the protocol's
        // no-op defaults are exercised as long as the above doesn't trap.
    }
}

private final class CombinedRenderAndEngineExtension: RenderExtension, @unchecked Sendable {
    let id: String
    var updateCount = 0

    init(id: String) {
        self.id = id
    }

    func update(deltaTime _: Float, context _: EngineExtensionUpdateContext) {
        updateCount += 1
    }

    func fixedUpdate(deltaTime _: Float, context _: EngineExtensionUpdateContext) {
        updateCount += 1
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

final class CombinedExtensionDispatchTest: XCTestCase {
    override func tearDown() {
        RenderExtensionRegistry.shared.removeAll()
        EngineExtensionRegistry.shared.removeAll()
        super.tearDown()
    }

    /// A type conforming to `RenderExtension` (which refines `EngineExtension`) must be
    /// registered only with `RenderExtensionRegistry`. This proves it is ticked exactly
    /// once per hook per frame even when both registries' dispatch methods run, matching
    /// what `runFrame()` actually does — the combined-plugin path never double-dispatches.
    func testCombinedExtensionRegisteredOnlyWithRenderRegistryTicksExactlyOnce() {
        let combined = CombinedRenderAndEngineExtension(id: "test.combined.dispatch")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(combined), .registered)
        // Deliberately not registered with EngineExtensionRegistry — that's the contract.

        let context = makeTestContext()
        RenderExtensionRegistry.shared.updateExtensions(deltaTime: 0.1, context: context)
        EngineExtensionRegistry.shared.updateExtensions(deltaTime: 0.1, context: context)
        XCTAssertEqual(combined.updateCount, 1)

        RenderExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)
        EngineExtensionRegistry.shared.fixedUpdateExtensions(deltaTime: 1.0 / 60.0, context: context)
        XCTAssertEqual(combined.updateCount, 2)

        RenderExtensionRegistry.shared.unregister(id: combined.id)
    }
}
