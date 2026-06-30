//
//  RenderExtensionPluginLifecycleTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Dispatch
@testable import UntoldEngine
import XCTest

private final class TestPluginLifecycleExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String
    let pipelineID: RenderPipelineType
    let bufferID: RenderBufferResourceID
    let missingTextureID: RenderTextureResourceID?
    let pipelineCreationSucceeds: Bool

    init(
        id: String,
        pipelineID: RenderPipelineType? = nil,
        missingTextureID: RenderTextureResourceID? = nil,
        pipelineCreationSucceeds: Bool = true
    ) {
        self.id = id
        passID = "\(id).pass"
        self.pipelineID = pipelineID ?? RenderPipelineType("\(id).pipeline")
        bufferID = RenderBufferResourceID("\(id).buffer")
        self.missingTextureID = missingTextureID
        self.pipelineCreationSucceeds = pipelineCreationSucceeds
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(pipelineID) { [pipelineCreationSucceeds] in
            pipelineCreationSucceeds
                ? RenderPipeline(success: true, name: self.pipelineID.rawValue)
                : nil
        }
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerBuffer(
            RenderExtensionBufferDescriptor(id: bufferID, length: 64)
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        let resources: [RenderGraphResourceUsage]
        if let missingTextureID {
            resources = [.texture(missingTextureID, access: .read)]
        } else {
            resources = []
        }
        builder.addPass(
            id: passID,
            stage: .beforeOutput,
            resources: resources,
            execute: nil
        )
    }
}

private struct TestRenderingPlugin: RenderExtensionPlugin {
    let manifest: RenderExtensionPluginManifest
    let extensions: [any RenderExtension]

    init(
        id: String,
        version: RenderExtensionPluginVersion = .init(major: 1, minor: 0, patch: 0),
        extensions: [any RenderExtension]
    ) {
        manifest = RenderExtensionPluginManifest(
            id: id,
            displayName: id,
            version: version
        )
        self.extensions = extensions
    }

    func makeRenderExtensions() -> [any RenderExtension] {
        extensions
    }
}

private final class TestBlockingPluginExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String
    let registrationStarted: DispatchSemaphore
    let continueRegistration: DispatchSemaphore

    init(
        id: String,
        registrationStarted: DispatchSemaphore,
        continueRegistration: DispatchSemaphore
    ) {
        self.id = id
        passID = "\(id).pass"
        self.registrationStarted = registrationStarted
        self.continueRegistration = continueRegistration
    }

    func registerResources(_: RenderResourceRegistry) {
        registrationStarted.signal()
        continueRegistration.wait()
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforeOutput, execute: nil)
    }
}

final class RenderExtensionPluginLifecycleTest: BaseRenderSetup {
    func testMultiExtensionPluginInstallsAndPublishesManifest() {
        let first = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let second = TestPluginLifecycleExtension(id: "com.untold.water.caustics")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [first, second]
        )

        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)

        XCTAssertEqual(RenderExtensionPluginRegistry.shared.installedPluginIDs(), [plugin.manifest.id])
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.installedManifests(), [plugin.manifest])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id, second.id])
        XCTAssertNotNil(getRenderResource(first.bufferID))
        XCTAssertNotNil(getRenderResource(second.bufferID))
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[first.pipelineID])
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[second.pipelineID])
    }

    func testPluginInstallationRollsBackEveryExtensionWhenOneFails() {
        let sharedPipelineID: RenderPipelineType = "com.untold.water.shared.pipeline"
        let first = TestPluginLifecycleExtension(
            id: "com.untold.water.first",
            pipelineID: sharedPipelineID
        )
        let second = TestPluginLifecycleExtension(
            id: "com.untold.water.second",
            pipelineID: sharedPipelineID
        )
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [first, second]
        )

        guard case let .rejected(failure) = RenderExtensionPluginRegistry.shared.install(plugin) else {
            XCTFail("Expected plugin installation to fail")
            return
        }

        XCTAssertEqual(failure.extensionFailures.map(\.extensionID), [second.id])
        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().isEmpty)
        XCTAssertNil(getRenderResource(first.bufferID))
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[sharedPipelineID])
    }

    func testPluginCannotReplaceStandaloneExtensionWithSameID() {
        let standalone = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(standalone), .registered)
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [TestPluginLifecycleExtension(id: standalone.id)]
        )

        XCTAssertEqual(
            RenderExtensionPluginRegistry.shared.install(plugin),
            .rejected(
                RenderExtensionPluginFailure(conflictingExtensionIDs: [standalone.id])
            )
        )
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [standalone.id])
        XCTAssertNotNil(getRenderResource(standalone.bufferID))
    }

    func testSuccessfulPluginReplacementUpdatesExtensionsInPlace() {
        let leading = TestPluginLifecycleExtension(id: "com.untold.leading")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(leading), .registered)
        let original = TestPluginLifecycleExtension(id: "com.untold.water.original")
        let originalPlugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [original]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(originalPlugin), .installed)
        let trailing = TestPluginLifecycleExtension(id: "com.untold.trailing")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(trailing), .registered)
        let replacement = TestPluginLifecycleExtension(id: "com.untold.water.replacement")
        let replacementPlugin = TestRenderingPlugin(
            id: "com.untold.water",
            version: .init(major: 2, minor: 0, patch: 0),
            extensions: [replacement]
        )

        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(replacementPlugin), .replaced)

        XCTAssertEqual(
            RenderExtensionRegistry.shared.registeredIDs(),
            [leading.id, replacement.id, trailing.id]
        )
        XCTAssertNil(getRenderResource(original.bufferID))
        XCTAssertNotNil(getRenderResource(replacement.bufferID))
        XCTAssertEqual(
            RenderExtensionPluginRegistry.shared.installedManifests(),
            [replacementPlugin.manifest]
        )
    }

    func testFailedPluginReplacementRestoresPreviousPlugin() {
        let original = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let originalPlugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [original]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(originalPlugin), .installed)
        let invalidReplacement = TestPluginLifecycleExtension(
            id: original.id,
            pipelineCreationSucceeds: false
        )
        let replacementPlugin = TestRenderingPlugin(
            id: "com.untold.water",
            version: .init(major: 2, minor: 0, patch: 0),
            extensions: [invalidReplacement]
        )

        guard case .rejected = RenderExtensionPluginRegistry.shared.install(replacementPlugin) else {
            XCTFail("Expected plugin replacement to fail")
            return
        }

        XCTAssertEqual(RenderExtensionPluginRegistry.shared.installedManifests(), [originalPlugin.manifest])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [original.id])
        XCTAssertNotNil(getRenderResource(original.bufferID))
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[original.pipelineID])
    }

    func testUninstallRemovesEveryPluginOwnedArtifact() {
        let first = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let second = TestPluginLifecycleExtension(id: "com.untold.water.caustics")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [first, second]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)

        let pipelineAccess = RenderPipelineAccess()
        XCTAssertNotNil(pipelineAccess.pipeline(first.pipelineID))
        XCTAssertNotNil(pipelineAccess.pipeline(second.pipelineID))

        RenderExtensionPluginRegistry.shared.uninstall(id: plugin.manifest.id)

        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().isEmpty)
        XCTAssertNil(getRenderResource(first.bufferID))
        XCTAssertNil(getRenderResource(second.bufferID))
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[first.pipelineID])
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[second.pipelineID])
        XCTAssertNil(pipelineAccess.pipeline(first.pipelineID))
        XCTAssertNil(pipelineAccess.pipeline(second.pipelineID))
    }

    func testLegacyExtensionUnregisterRemovesWholeOwningPlugin() {
        let first = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let second = TestPluginLifecycleExtension(id: "com.untold.water.caustics")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [first, second]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)

        RenderExtensionRegistry.shared.unregister(id: first.id)

        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().isEmpty)
    }

    func testStandaloneRegistrationCannotReplacePluginOwnedExtension() {
        let pluginExtension = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [pluginExtension]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)
        let standaloneReplacement = TestPluginLifecycleExtension(id: pluginExtension.id)

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(standaloneReplacement),
            .rejectedPluginOwnership(
                extensionID: pluginExtension.id,
                pluginID: plugin.manifest.id
            )
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.installedPluginIDs(), [plugin.manifest.id])
        XCTAssertNotNil(getRenderResource(pluginExtension.bufferID))
    }

    func testGraphFailureRollsBackWholePluginAndPreservesHealthyPlugin() throws {
        let healthyExtension = TestPluginLifecycleExtension(id: "com.untold.grass.surface")
        let healthyPlugin = TestRenderingPlugin(
            id: "com.untold.grass",
            extensions: [healthyExtension]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(healthyPlugin), .installed)
        let validWaterExtension = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let missingTextureID: RenderTextureResourceID = "com.untold.water.missing"
        let invalidWaterExtension = TestPluginLifecycleExtension(
            id: "com.untold.water.invalid",
            missingTextureID: missingTextureID
        )
        let invalidPlugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [validWaterExtension, invalidWaterExtension]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(invalidPlugin), .installed)

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph[healthyExtension.passID])
        XCTAssertNil(graph[validWaterExtension.passID])
        XCTAssertNil(graph[invalidWaterExtension.passID])
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.installedPluginIDs(), [healthyPlugin.manifest.id])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [healthyExtension.id])
        XCTAssertNil(getRenderResource(validWaterExtension.bufferID))
        XCTAssertEqual(
            RenderExtensionPluginRegistry.shared.failure(forPluginID: invalidPlugin.manifest.id)?.graphValidationErrors,
            [
                .missingResource(
                    passID: invalidWaterExtension.passID,
                    kind: .texture,
                    resourceID: missingTextureID.rawValue
                ),
            ]
        )
    }

    func testDeferredPipelineFailureRemovesWholePluginWhenMetalBecomesReady() {
        let validExtension = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let invalidExtension = TestPluginLifecycleExtension(
            id: "com.untold.water.invalid",
            pipelineCreationSucceeds: false
        )
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [validExtension, invalidExtension]
        )
        let device = renderInfo.device
        let library = renderInfo.library
        renderInfo.device = nil
        renderInfo.library = nil
        defer {
            renderInfo.device = device
            renderInfo.library = library
        }

        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)
        renderInfo.device = device
        renderInfo.library = library

        RenderExtensionRegistry.shared.registerPipelines()

        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().isEmpty)
        XCTAssertNil(getRenderResource(validExtension.bufferID))
        XCTAssertFalse(
            RenderExtensionPluginRegistry.shared.failure(forPluginID: plugin.manifest.id)?
                .extensionFailures.isEmpty ?? true
        )
    }

    func testPluginRemoveAllPreservesStandaloneExtensions() {
        let standalone = TestPluginLifecycleExtension(id: "com.untold.standalone")
        XCTAssertEqual(RenderExtensionRegistry.shared.register(standalone), .registered)
        let pluginExtension = TestPluginLifecycleExtension(id: "com.untold.water.surface")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [pluginExtension]
        )
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)

        RenderExtensionPluginRegistry.shared.removeAll()

        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [standalone.id])
        XCTAssertNotNil(getRenderResource(standalone.bufferID))
        XCTAssertNil(getRenderResource(pluginExtension.bufferID))
    }

    func testGraphBuildCannotObservePartiallyInstalledPlugin() throws {
        let registrationStarted = DispatchSemaphore(value: 0)
        let continueRegistration = DispatchSemaphore(value: 0)
        let installCompleted = DispatchSemaphore(value: 0)
        let graphStarted = DispatchSemaphore(value: 0)
        let graphCompleted = DispatchSemaphore(value: 0)
        let blockingExtension = TestBlockingPluginExtension(
            id: "com.untold.water.blocking",
            registrationStarted: registrationStarted,
            continueRegistration: continueRegistration
        )
        let trailingExtension = TestPluginLifecycleExtension(id: "com.untold.water.trailing")
        let plugin = TestRenderingPlugin(
            id: "com.untold.water",
            extensions: [blockingExtension, trailingExtension]
        )
        defer { continueRegistration.signal() }

        DispatchQueue.global().async {
            _ = RenderExtensionPluginRegistry.shared.install(plugin)
            installCompleted.signal()
        }
        XCTAssertEqual(registrationStarted.wait(timeout: .now() + 1), .success)

        DispatchQueue.global().async {
            graphStarted.signal()
            _ = try? buildGameModeGraph()
            graphCompleted.signal()
        }
        XCTAssertEqual(graphStarted.wait(timeout: .now() + 1), .success)
        XCTAssertEqual(graphCompleted.wait(timeout: .now() + 0.1), .timedOut)

        continueRegistration.signal()
        XCTAssertEqual(installCompleted.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(graphCompleted.wait(timeout: .now() + 2), .success)

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNotNil(graph[blockingExtension.passID])
        XCTAssertNotNil(graph[trailingExtension.passID])
    }
}
