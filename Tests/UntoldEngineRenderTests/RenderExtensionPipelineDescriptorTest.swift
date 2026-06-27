//
//  RenderExtensionPipelineDescriptorTest.swift
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

private final class TestRenderExtensionPipelineCreator: RenderExtensionPipelineCreating {
    var failRenderPipelineIDs: Set<RenderPipelineType> = []
    var failComputePipelineIDs: Set<ComputePipelineType> = []

    func makeRenderPipeline(
        _ descriptor: RenderExtensionRenderPipelineDescriptor
    ) -> RenderPipeline? {
        guard !failRenderPipelineIDs.contains(descriptor.id) else { return nil }
        return RenderPipeline(success: true, name: descriptor.name)
    }

    func makeComputePipeline(
        _ descriptor: RenderExtensionComputePipelineDescriptor,
        library _: MTLLibrary
    ) -> ComputePipeline? {
        guard !failComputePipelineIDs.contains(descriptor.id) else { return nil }
        var pipeline = ComputePipeline()
        pipeline.name = descriptor.name
        pipeline.success = true
        return pipeline
    }
}

private final class TestDeclarativePipelineExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let argumentLayoutID: String?
    let renderDescriptors: [RenderExtensionRenderPipelineDescriptor]
    let computeDescriptors: [RenderExtensionComputePipelineDescriptor]

    init(
        id: String,
        argumentLayoutID: String? = nil,
        renderDescriptors: [RenderExtensionRenderPipelineDescriptor] = [],
        computeDescriptors: [RenderExtensionComputePipelineDescriptor] = []
    ) {
        self.id = id
        self.argumentLayoutID = argumentLayoutID
        self.renderDescriptors = renderDescriptors
        self.computeDescriptors = computeDescriptors
    }

    func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry) {
        guard let argumentLayoutID else { return }
        registry.registerArgumentBuffer(
            RenderExtensionArgumentBufferDescriptor(id: argumentLayoutID)
        )
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        for descriptor in renderDescriptors {
            registry.registerRenderPipeline(descriptor)
        }
    }

    func registerComputePipelines(_ registry: ComputePipelineRegistry) {
        for descriptor in computeDescriptors {
            registry.registerComputePipeline(descriptor)
        }
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestFailedCallbackPipelineExtension: RenderExtension, @unchecked Sendable {
    let id = "com.untold.callback-failure"
    let pipelineID: RenderPipelineType = "com.untold.callback-failure.render"

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(pipelineID) { nil }
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

final class RenderExtensionPipelineDescriptorTest: BaseRenderSetup {
    func testValidDeclarativeRenderAndComputePipelinesRegister() {
        let creator = TestRenderExtensionPipelineCreator()
        let previousCreator = RenderExtensionPipelineCreator.shared.replaceForTesting(creator)
        defer { _ = RenderExtensionPipelineCreator.shared.replaceForTesting(previousCreator) }
        let argumentLayoutID = "com.untold.pipeline.arguments"
        let renderDescriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.render",
            requiredArgumentLayoutID: argumentLayoutID
        )
        let computeDescriptor = makeComputeDescriptor(id: "com.untold.pipeline.compute")
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            argumentLayoutID: argumentLayoutID,
            renderDescriptors: [renderDescriptor],
            computeDescriptors: [computeDescriptor]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[renderDescriptor.id])
        XCTAssertNotNil(ComputePipelineManager.shared.pipeline(for: computeDescriptor.id))
    }

    func testMissingRegisteredShaderLibraryRejectsRecipe() {
        let missingLibraryID: RenderShaderLibraryID = "com.untold.pipeline.missing.library"
        let descriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.missing-library",
            vertexShaderLibrary: .registered(missingLibraryID)
        )
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor]
        )
        let expectedError = RenderExtensionPipelineError.missingShaderLibrary(
            pipelineID: descriptor.id.rawValue,
            stage: .vertex,
            libraryID: missingLibraryID.rawValue
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [expectedError]
        )
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[descriptor.id])
        XCTAssertEqual(
            RenderExtensionRegistry.shared.pipelineErrors(forExtensionID: renderExtension.id),
            [expectedError]
        )
    }

    func testMissingShaderFunctionRejectsRecipeBeforeCreation() {
        let descriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.missing-function",
            vertexFunction: "functionThatDoesNotExist"
        )
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor]
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .missingShaderFunction(
                    pipelineID: descriptor.id.rawValue,
                    stage: .vertex,
                    function: "functionThatDoesNotExist"
                ),
            ]
        )
    }

    func testMissingArgumentLayoutRejectsRecipe() {
        let descriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.missing-layout",
            requiredArgumentLayoutID: "com.untold.pipeline.missing.arguments"
        )
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor]
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .missingArgumentLayout(
                    pipelineID: descriptor.id.rawValue,
                    layoutID: "com.untold.pipeline.missing.arguments"
                ),
            ]
        )
    }

    func testInvalidRenderTargetConfigurationReportsEveryError() {
        let descriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.invalid-target",
            colorFormats: [.invalid],
            depthFormat: .invalid,
            depthEnabled: true
        )
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor]
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .invalidColorFormat(pipelineID: descriptor.id.rawValue, index: 0),
                .invalidDepthFormat(pipelineID: descriptor.id.rawValue),
            ]
        )
    }

    func testDuplicatePipelineRecipeRejectsAndRollsBackPipeline() {
        let creator = TestRenderExtensionPipelineCreator()
        let previousCreator = RenderExtensionPipelineCreator.shared.replaceForTesting(creator)
        defer { _ = RenderExtensionPipelineCreator.shared.replaceForTesting(previousCreator) }
        let descriptor = makeRenderDescriptor(id: "com.untold.pipeline.duplicate")
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor, descriptor]
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .duplicatePipelineID(
                    kind: .renderPipeline,
                    pipelineID: descriptor.id.rawValue
                ),
            ]
        )
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[descriptor.id])
    }

    func testPipelineCreationFailureIsStructuredAndTransactional() {
        let descriptor = makeRenderDescriptor(id: "com.untold.pipeline.creation-failure")
        let creator = TestRenderExtensionPipelineCreator()
        creator.failRenderPipelineIDs = [descriptor.id]
        let previousCreator = RenderExtensionPipelineCreator.shared.replaceForTesting(creator)
        defer { _ = RenderExtensionPipelineCreator.shared.replaceForTesting(previousCreator) }
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [descriptor]
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .creationFailed(
                    kind: .renderPipeline,
                    pipelineID: descriptor.id.rawValue
                ),
            ]
        )
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
    }

    func testFailedPipelineReplacementRestoresPreviousExtension() {
        let extensionID = "com.untold.pipeline.replacement"
        let originalDescriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.replacement.original"
        )
        let replacementDescriptor = makeRenderDescriptor(
            id: "com.untold.pipeline.replacement.new"
        )
        let creator = TestRenderExtensionPipelineCreator()
        creator.failRenderPipelineIDs = [replacementDescriptor.id]
        let previousCreator = RenderExtensionPipelineCreator.shared.replaceForTesting(creator)
        defer { _ = RenderExtensionPipelineCreator.shared.replaceForTesting(previousCreator) }
        let original = TestDeclarativePipelineExtension(
            id: extensionID,
            renderDescriptors: [originalDescriptor]
        )
        let replacement = TestDeclarativePipelineExtension(
            id: extensionID,
            renderDescriptors: [replacementDescriptor]
        )
        XCTAssertEqual(RenderExtensionRegistry.shared.register(original), .registered)

        guard case .rejectedArtifacts = RenderExtensionRegistry.shared.register(replacement) else {
            XCTFail("Expected pipeline replacement to be rejected")
            return
        }

        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [extensionID])
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[originalDescriptor.id])
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[replacementDescriptor.id])
    }

    func testInvalidComputeRecipeRollsBackValidRenderRecipe() {
        let creator = TestRenderExtensionPipelineCreator()
        let previousCreator = RenderExtensionPipelineCreator.shared.replaceForTesting(creator)
        defer { _ = RenderExtensionPipelineCreator.shared.replaceForTesting(previousCreator) }
        let renderDescriptor = makeRenderDescriptor(id: "com.untold.pipeline.rollback.render")
        let computeDescriptor = makeComputeDescriptor(
            id: "com.untold.pipeline.rollback.compute",
            function: "missingComputeFunction"
        )
        let renderExtension = TestDeclarativePipelineExtension(
            id: "com.untold.pipeline",
            renderDescriptors: [renderDescriptor],
            computeDescriptors: [computeDescriptor]
        )

        guard case .rejectedArtifacts = RenderExtensionRegistry.shared.register(renderExtension) else {
            XCTFail("Expected invalid compute recipe to reject extension")
            return
        }
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[renderDescriptor.id])
        XCTAssertNil(ComputePipelineManager.shared.pipeline(for: computeDescriptor.id))
    }

    func testLegacyCallbackCreationFailureUsesStructuredDiagnostics() {
        let renderExtension = TestFailedCallbackPipelineExtension()

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension).pipelineErrors,
            [
                .creationFailed(
                    kind: .renderPipeline,
                    pipelineID: renderExtension.pipelineID.rawValue
                ),
            ]
        )
    }

    private func makeRenderDescriptor(
        id: RenderPipelineType,
        vertexFunction: String = "vertexCompositeShader",
        vertexShaderLibrary: RenderShaderLibraryReference = .engine,
        colorFormats: [MTLPixelFormat] = [.rgba16Float],
        depthFormat: MTLPixelFormat = .depth32Float,
        depthEnabled: Bool = false,
        requiredArgumentLayoutID: String? = nil
    ) -> RenderExtensionRenderPipelineDescriptor {
        RenderExtensionRenderPipelineDescriptor(
            id: id,
            vertexFunction: vertexFunction,
            fragmentFunction: "fragmentCompositeShader",
            vertexShaderLibrary: vertexShaderLibrary,
            vertexDescriptor: createCompositeVertexDescriptor(),
            colorFormats: colorFormats,
            depthFormat: depthFormat,
            depthEnabled: depthEnabled,
            name: id.rawValue,
            requiredArgumentLayoutID: requiredArgumentLayoutID
        )
    }

    private func makeComputeDescriptor(
        id: ComputePipelineType,
        function: String = "hzbBuildDepthPyramid"
    ) -> RenderExtensionComputePipelineDescriptor {
        RenderExtensionComputePipelineDescriptor(
            id: id,
            function: function,
            name: id.rawValue
        )
    }
}
