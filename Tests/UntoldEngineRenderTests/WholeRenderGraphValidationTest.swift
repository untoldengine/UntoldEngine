//
//  WholeRenderGraphValidationTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
@testable import UntoldEngine
import XCTest

private final class TestHazardRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let textureID: RenderTextureResourceID
    let readerPassID: String
    let writerPassID: String
    let writesBeforeReading: Bool

    init(id: String, writesBeforeReading: Bool) {
        self.id = id
        textureID = RenderTextureResourceID("\(id).texture")
        readerPassID = "\(id).reader"
        writerPassID = "\(id).writer"
        self.writesBeforeReading = writesBeforeReading
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: textureID,
                size: .fixed(width: 4, height: 4),
                pixelFormat: .rgba8Unorm,
                usage: [.shaderRead, .shaderWrite]
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        if writesBeforeReading {
            builder.addPass(
                id: writerPassID,
                stage: .beforeOutput,
                resources: [.texture(textureID, access: .write)],
                execute: nil
            )
            builder.addPass(
                id: readerPassID,
                stage: .beforeOutput,
                resources: [.texture(textureID, access: .read)],
                execute: nil
            )
        } else {
            builder.addPass(
                id: readerPassID,
                stage: .beforeOutput,
                resources: [.texture(textureID, access: .read)],
                execute: nil
            )
            builder.addPass(
                id: writerPassID,
                stage: .beforeOutput,
                resources: [.texture(textureID, access: .write)],
                execute: nil
            )
        }
    }
}

private struct TestHazardRenderPlugin: RenderExtensionPlugin {
    let manifest: RenderExtensionPluginManifest
    let renderExtension: TestHazardRenderExtension

    init(id: String) {
        manifest = RenderExtensionPluginManifest(
            id: id,
            displayName: "Hazard Test Plugin",
            version: RenderExtensionPluginVersion(major: 1, minor: 0, patch: 0)
        )
        renderExtension = TestHazardRenderExtension(
            id: "\(id).surface",
            writesBeforeReading: false
        )
    }

    func makeRenderExtensions() -> [any RenderExtension] {
        [renderExtension]
    }
}

final class WholeRenderGraphValidationTest: BaseRenderSetup {
    func testValidationReportsEveryMissingDependencyWithOwner() {
        let first = RenderPass(
            id: "first",
            dependencies: ["missing-a"],
            execute: nil,
            owner: .renderExtension("test.first.extension")
        )
        let second = RenderPass(
            id: "second",
            dependencies: ["missing-b"],
            execute: nil,
            owner: .renderExtension("test.second.extension")
        )

        XCTAssertEqual(
            analyzeRenderGraph([first.id: first, second.id: second])
                .validationReport.diagnostics,
            [
                RenderGraphValidationDiagnostic(
                    error: .missingDependency(
                        passID: first.id,
                        dependencyID: "missing-a"
                    ),
                    ownerID: "test.first.extension"
                ),
                RenderGraphValidationDiagnostic(
                    error: .missingDependency(
                        passID: second.id,
                        dependencyID: "missing-b"
                    ),
                    ownerID: "test.second.extension"
                ),
            ]
        )
    }

    func testReadBeforeWriteIsAttributedToReaderOwner() {
        let textureID: RenderTextureResourceID = "test.hazard.read-before-write"
        let reader = RenderPass(
            id: "reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .read)],
            owner: .renderExtension("test.reader.extension")
        )
        let writer = RenderPass(
            id: "writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .write)],
            owner: .renderExtension("test.writer.extension")
        )

        XCTAssertEqual(
            validateRenderGraphResourceHazards([reader, writer]),
            [
                RenderGraphValidationDiagnostic(
                    error: .readBeforeWrite(
                        passID: reader.id,
                        kind: .texture,
                        resourceID: textureID.rawValue
                    ),
                    ownerID: "test.reader.extension"
                ),
            ]
        )
    }

    func testValidationRejectsUnscheduledWritersDeterministically() {
        let bufferID: RenderBufferResourceID = "test.hazard.multiple-writers"
        let first = RenderPass(
            id: "first",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)],
            owner: .renderExtension("test.writer.extension")
        )
        let second = RenderPass(
            id: "second",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)],
            owner: .renderExtension("test.writer.extension")
        )

        XCTAssertEqual(
            validateRenderGraphResourceHazards([first, second]),
            [
                RenderGraphValidationDiagnostic(
                    error: .unorderedResourceWrites(
                        kind: .buffer,
                        resourceID: bufferID.rawValue,
                        firstPassID: first.id,
                        secondPassID: second.id
                    ),
                    ownerID: "test.writer.extension"
                ),
            ]
        )
    }

    func testOrderedWriterThenReaderIsValid() {
        let textureID: RenderTextureResourceID = "test.hazard.ordered"
        let writer = RenderPass(
            id: "writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .write)]
        )
        let reader = RenderPass(
            id: "reader",
            dependencies: [writer.id],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .read)]
        )

        XCTAssertTrue(validateRenderGraphResourceHazards([writer, reader]).isEmpty)
    }

    func testInvalidStandaloneExtensionIsRejectedAndGraphIsRebuilt() throws {
        let renderExtension = TestHazardRenderExtension(
            id: "test.hazard.standalone",
            writesBeforeReading: false
        )
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph[renderExtension.readerPassID])
        XCTAssertNil(graph[renderExtension.writerPassID])
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(
                forExtensionID: renderExtension.id
            ),
            [
                .readBeforeWrite(
                    passID: renderExtension.readerPassID,
                    kind: .texture,
                    resourceID: renderExtension.textureID.rawValue
                ),
            ]
        )
        XCTAssertEqual(
            RenderResourceRegistry.shared.textureState(renderExtension.textureID),
            .released
        )
    }

    func testValidStandaloneExtensionSurvivesWholeGraphValidation() throws {
        let renderExtension = TestHazardRenderExtension(
            id: "test.hazard.valid",
            writesBeforeReading: true
        )
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph[renderExtension.writerPassID])
        XCTAssertNotNil(graph[renderExtension.readerPassID])
        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertTrue(
            RenderExtensionRegistry.shared.graphValidationErrors(
                forExtensionID: renderExtension.id
            ).isEmpty
        )
    }

    func testInvalidPluginIsRejectedWithWholeGraphDiagnostics() throws {
        let plugin = TestHazardRenderPlugin(id: "com.untold.hazard")
        XCTAssertEqual(RenderExtensionPluginRegistry.shared.install(plugin), .installed)

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph[plugin.renderExtension.readerPassID])
        XCTAssertNil(graph[plugin.renderExtension.writerPassID])
        XCTAssertTrue(RenderExtensionPluginRegistry.shared.installedPluginIDs().isEmpty)
        XCTAssertEqual(
            RenderExtensionPluginRegistry.shared.failure(
                forPluginID: plugin.manifest.id
            )?.graphValidationErrors,
            [
                .readBeforeWrite(
                    passID: plugin.renderExtension.readerPassID,
                    kind: .texture,
                    resourceID: plugin.renderExtension.textureID.rawValue
                ),
            ]
        )
    }
}
