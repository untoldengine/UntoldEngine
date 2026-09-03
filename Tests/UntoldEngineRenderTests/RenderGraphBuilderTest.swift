//
//  RenderGraphBuilderTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
import simd
@testable import UntoldEngine
import XCTest

private final class TestStageRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String
    let stage: RenderStage

    init(id: String? = nil, passID: String, stage: RenderStage) {
        self.id = id ?? "test.stage.extension.\(passID)"
        self.passID = passID
        self.stage = stage
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: stage, execute: { _ in })
    }
}

private final class TestContextStageRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.context.stage.extension"
    let passID = "test.context.stage.pass"
    private(set) var observedStage: RenderStage?

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [weak self] context in
            self?.observedStage = context.stage
        }
    }
}

private final class TestMultiPassConflictRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let uniquePassID: String
    let conflictingPassID: String

    init(id: String, uniquePassID: String, conflictingPassID: String) {
        self.id = id
        self.uniquePassID = uniquePassID
        self.conflictingPassID = conflictingPassID
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: uniquePassID, stage: .afterTransparency, execute: nil)
        builder.addPass(id: conflictingPassID, stage: .afterTransparency, execute: nil)
    }
}

private final class TestInvalidResourceThenConflictRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let uniquePassID: String
    let conflictingPassID: String
    let missingTextureID: RenderTextureResourceID

    init(
        id: String,
        uniquePassID: String,
        conflictingPassID: String,
        missingTextureID: RenderTextureResourceID
    ) {
        self.id = id
        self.uniquePassID = uniquePassID
        self.conflictingPassID = conflictingPassID
        self.missingTextureID = missingTextureID
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: uniquePassID,
            stage: .afterTransparency,
            resources: [.texture(missingTextureID, access: .read)],
            execute: nil
        )
        builder.addPass(id: conflictingPassID, stage: .afterTransparency, execute: nil)
    }
}

private final class TestInvalidDependencyRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.invalid.dependency.extension"
    let passID = "test.invalid.dependency.pass"
    let dependencyID = "test.missing.dependency"

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: passID,
            stage: .beforeOutput,
            dependencies: [dependencyID],
            execute: nil
        )
    }
}

private final class TestPublicDependencyRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let firstPassID: String
    let secondPassID: String
    let secondDependencies: [RenderGraphPassDependency]

    init(
        id: String,
        firstPassID: String,
        secondPassID: String,
        secondDependencies: [RenderGraphPassDependency]
    ) {
        self.id = id
        self.firstPassID = firstPassID
        self.secondPassID = secondPassID
        self.secondDependencies = secondDependencies
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: firstPassID, stage: .frameStart, execute: nil)
        builder.addPass(
            id: secondPassID,
            stage: .frameStart,
            dependencies: secondDependencies,
            execute: nil
        )
    }
}

private final class TestPublicDependencyOnlyRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String
    let dependencies: [RenderGraphPassDependency]

    init(
        id: String,
        passID: String,
        dependencies: [RenderGraphPassDependency]
    ) {
        self.id = id
        self.passID = passID
        self.dependencies = dependencies
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: passID,
            stage: .beforePostProcess,
            dependencies: dependencies,
            execute: nil
        )
    }
}

private final class TestLifecycleRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String
    let textureID: String
    let bufferID: RenderBufferResourceID
    let shaderLibraryID: RenderShaderLibraryID
    let renderPipelineType: RenderPipelineType
    let computePipelineType: ComputePipelineType
    let argumentLayoutID: String
    let shaderLibrary: MTLLibrary

    init(
        id: String = "test.lifecycle.extension",
        artifactSuffix: String,
        passID: String? = nil,
        renderPipelineType: RenderPipelineType? = nil,
        shaderLibrary: MTLLibrary
    ) {
        self.id = id
        self.passID = passID ?? "test.lifecycle.\(artifactSuffix).pass"
        textureID = "test.lifecycle.\(artifactSuffix).texture"
        bufferID = RenderBufferResourceID("test.lifecycle.\(artifactSuffix).buffer")
        shaderLibraryID = RenderShaderLibraryID("test.lifecycle.\(artifactSuffix).library")
        self.renderPipelineType = renderPipelineType ?? RenderPipelineType("test.lifecycle.\(artifactSuffix).render")
        computePipelineType = ComputePipelineType("test.lifecycle.\(artifactSuffix).compute")
        argumentLayoutID = "test.lifecycle.\(artifactSuffix).arguments"
        self.shaderLibrary = shaderLibrary
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(shaderLibraryID, library: shaderLibrary)
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(renderPipelineType) {
            RenderPipeline(success: true, name: self.renderPipelineType.rawValue)
        }
    }

    func registerComputePipelines(_ registry: ComputePipelineRegistry) {
        registry.registerComputePipeline(computePipelineType) {
            var pipeline = ComputePipeline()
            pipeline.name = self.computePipelineType.rawValue
            pipeline.success = true
            return pipeline
        }
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: textureID,
                size: .fixed(width: 8, height: 8),
                pixelFormat: .rgba16Float,
                usage: [.renderTarget, .shaderRead]
            )
        )
        registry.registerBuffer(
            RenderExtensionBufferDescriptor(
                id: bufferID,
                length: 64
            )
        )
    }

    func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry) {
        registry.registerArgumentBuffer(
            RenderExtensionArgumentBufferDescriptor(
                id: argumentLayoutID,
                buffers: [
                    RenderExtensionArgumentBuffer(
                        id: RenderExtensionModelSurfaceArgument.buffer0
                    ),
                ]
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .afterTransparency, execute: nil)
    }
}

private final class TestRenderPipelineOnlyExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let pipelineType: RenderPipelineType
    let passID: String

    init(id: String, pipelineType: RenderPipelineType, passID: String) {
        self.id = id
        self.pipelineType = pipelineType
        self.passID = passID
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(pipelineType) {
            RenderPipeline(success: true, name: self.id)
        }
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .afterTransparency, execute: nil)
    }
}

private final class TestRenderPipelineContextExtension: RenderExtension, @unchecked Sendable {
    let id = "test.context.render.pipeline.extension"
    let pipelineType: RenderPipelineType = "test.context.render.pipeline"
    let missingPipelineType: RenderPipelineType = "test.context.render.pipeline.missing"
    let passID = "test.context.render.pipeline.pass"
    private(set) var observedPipelineName: String?
    private(set) var observedMissingPipeline = false

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(pipelineType) {
            RenderPipeline(success: true, name: "Context Render Pipeline")
        }
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [weak self] context in
            guard let self else { return }
            observedPipelineName = context.renderPipelines.pipeline(pipelineType)?.name
            observedMissingPipeline = context.renderPipelines.pipeline(missingPipelineType) == nil
        }
    }
}

private final class TestResourceRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.resource.extension"
    let textureID: String
    let passID: String
    let size: RenderExtensionResourceSize
    var observedTextureSize: SIMD2<Int>?

    init(
        textureID: String,
        passID: String = "test.resource.pass",
        size: RenderExtensionResourceSize
    ) {
        self.textureID = textureID
        self.passID = passID
        self.size = size
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerTexture(
            RenderExtensionTextureDescriptor(
                id: textureID,
                size: size,
                pixelFormat: .rgba16Float,
                usage: [.renderTarget, .shaderRead]
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: passID,
            stage: .beforeOutput,
            resources: [
                .texture(RenderTextureResourceID(textureID), access: .read),
            ],
            execute: { [weak self] context in
                guard let self, let texture = context.resources.texture(textureID) else { return }
                observedTextureSize = SIMD2<Int>(texture.width, texture.height)
            }
        )
    }
}

private final class TestBufferResourceRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let bufferID: RenderBufferResourceID
    let passID: String
    let length: Int
    var observedBufferLength: Int?

    init(
        id: String = "test.buffer-resource.extension",
        bufferID: RenderBufferResourceID,
        passID: String = "test.buffer-resource.pass",
        length: Int
    ) {
        self.id = id
        self.bufferID = bufferID
        self.passID = passID
        self.length = length
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerBuffer(
            RenderExtensionBufferDescriptor(
                id: bufferID,
                length: length
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(
            id: passID,
            stage: .beforeOutput,
            resources: [
                .buffer(bufferID, access: .read),
            ]
        ) { [weak self] context in
            guard let self else { return }
            observedBufferLength = context.resources.buffer(bufferID)?.length
        }
    }
}

private final class TestTransactionalResourceRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let textureDescriptors: [RenderExtensionTextureDescriptor]
    let bufferDescriptors: [RenderExtensionBufferDescriptor]
    private(set) var resourceRegistrationCount = 0

    init(
        id: String,
        textureDescriptors: [RenderExtensionTextureDescriptor] = [],
        bufferDescriptors: [RenderExtensionBufferDescriptor] = []
    ) {
        self.id = id
        self.textureDescriptors = textureDescriptors
        self.bufferDescriptors = bufferDescriptors
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        resourceRegistrationCount += 1
        for descriptor in textureDescriptors {
            registry.registerTexture(descriptor)
        }
        for descriptor in bufferDescriptors {
            registry.registerBuffer(descriptor)
        }
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestResourceUsageRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let passID: String?
    let textureDescriptors: [RenderExtensionTextureDescriptor]
    let bufferDescriptors: [RenderExtensionBufferDescriptor]
    let usages: [RenderGraphResourceUsage]
    let observedTextureIDs: [RenderTextureResourceID]
    let observedBufferIDs: [RenderBufferResourceID]
    private(set) var observedTextures: [RenderTextureResourceID: Bool] = [:]
    private(set) var observedBuffers: [RenderBufferResourceID: Bool] = [:]

    init(
        id: String,
        passID: String? = nil,
        textureDescriptors: [RenderExtensionTextureDescriptor] = [],
        bufferDescriptors: [RenderExtensionBufferDescriptor] = [],
        usages: [RenderGraphResourceUsage] = [],
        observedTextureIDs: [RenderTextureResourceID] = [],
        observedBufferIDs: [RenderBufferResourceID] = []
    ) {
        self.id = id
        self.passID = passID
        self.textureDescriptors = textureDescriptors
        self.bufferDescriptors = bufferDescriptors
        self.usages = usages
        self.observedTextureIDs = observedTextureIDs
        self.observedBufferIDs = observedBufferIDs
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        for descriptor in textureDescriptors {
            registry.registerTexture(descriptor)
        }
        for descriptor in bufferDescriptors {
            registry.registerBuffer(descriptor)
        }
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        guard let passID else { return }
        builder.addPass(id: passID, stage: .beforeOutput, resources: usages) { [weak self] context in
            guard let self else { return }
            for id in observedTextureIDs {
                observedTextures[id] = context.resources.texture(id) != nil
            }
            for id in observedBufferIDs {
                observedBuffers[id] = context.resources.buffer(id) != nil
            }
        }
    }
}

private final class TestRenderExtensionResourceAllocator: RenderExtensionResourceAllocating {
    var failingTextureIDs: Set<RenderTextureResourceID> = []
    var failingBufferIDs: Set<RenderBufferResourceID> = []
    private(set) var textureAllocationCounts: [RenderTextureResourceID: Int] = [:]
    private(set) var bufferAllocationCounts: [RenderBufferResourceID: Int] = [:]

    func makeTexture(
        device: MTLDevice,
        descriptor: RenderExtensionTextureDescriptor,
        width: Int,
        height: Int
    ) -> MTLTexture? {
        textureAllocationCounts[descriptor.id, default: 0] += 1
        guard !failingTextureIDs.contains(descriptor.id) else { return nil }
        return createTexture(
            device: device,
            label: descriptor.label,
            pixelFormat: descriptor.pixelFormat,
            width: width,
            height: height,
            usage: descriptor.usage,
            storageMode: descriptor.storageMode,
            mipMapLevels: descriptor.mipMapLevels,
            sampleCount: descriptor.sampleCount
        )
    }

    func makeBuffer(
        device: MTLDevice,
        descriptor: RenderExtensionBufferDescriptor
    ) -> MTLBuffer? {
        bufferAllocationCounts[descriptor.id, default: 0] += 1
        guard !failingBufferIDs.contains(descriptor.id) else { return nil }
        return createEmptyBuffer(
            device: device,
            length: descriptor.length,
            options: descriptor.options,
            label: descriptor.label
        )
    }
}

private final class TestComputeRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.compute.extension"
    let computeType: ComputePipelineType
    let passID: String
    var observedPipelineName: String?

    init(
        computeType: ComputePipelineType,
        passID: String = "test.compute.pass"
    ) {
        self.computeType = computeType
        self.passID = passID
    }

    func registerComputePipelines(_ registry: ComputePipelineRegistry) {
        registry.registerComputePipeline(computeType) {
            var pipeline = ComputePipeline()
            pipeline.name = "Test Compute Pipeline"
            pipeline.success = true
            return pipeline
        }
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforeOutput, execute: { [weak self] context in
            guard let self else { return }
            observedPipelineName = context.computePipelines.pipeline(computeType)?.name
        })
    }
}

private final class TestShaderLibraryRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.shader.library.extension"
    let libraryID: RenderShaderLibraryID
    let library: MTLLibrary

    init(libraryID: RenderShaderLibraryID, library: MTLLibrary) {
        self.libraryID = libraryID
        self.library = library
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(libraryID, library: library)
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestRegisteredShaderPipelineRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.registered.shader.pipeline.extension"
    let libraryID: RenderShaderLibraryID
    let renderPipelineType: RenderPipelineType
    let computePipelineType: ComputePipelineType
    let library: MTLLibrary

    init(
        libraryID: RenderShaderLibraryID,
        renderPipelineType: RenderPipelineType,
        computePipelineType: ComputePipelineType,
        library: MTLLibrary
    ) {
        self.libraryID = libraryID
        self.renderPipelineType = renderPipelineType
        self.computePipelineType = computePipelineType
        self.library = library
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        registry.registerLibrary(libraryID, library: library)
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerRenderPipeline(
            renderPipelineType,
            vertexShader: "vertexCompositeShader",
            fragmentShader: "fragmentCompositeShader",
            vertexShaderLibrary: .registered(libraryID),
            fragmentShaderLibrary: .registered(libraryID),
            vertexDescriptor: createCompositeVertexDescriptor(),
            colorFormats: [renderInfo.presentColorPixelFormat],
            depthFormat: renderInfo.presentDepthPixelFormat,
            depthEnabled: false,
            name: "Test Registered Shader Render Pipeline"
        )
    }

    func registerComputePipelines(_ registry: ComputePipelineRegistry) {
        registry.registerComputePipeline(
            computePipelineType,
            functionName: "hzbBuildDepthPyramid",
            shaderLibrary: .registered(libraryID),
            pipelineName: "Test Registered Shader Compute Pipeline"
        )
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}

private final class TestModelSurfaceDrawRenderExtension: RenderExtension, @unchecked Sendable {
    let id = "test.model.surface.draw.extension"
    let pipelineType: RenderPipelineType
    let passID: String
    var boundEntityIDs: [EntityID] = []

    init(
        pipelineType: RenderPipelineType,
        passID: String = "test.model.surface.draw.pass"
    ) {
        self.pipelineType = pipelineType
        self.passID = passID
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerModelSurfacePipeline(
            pipelineType,
            fragmentShader: "fragmentGeometryShader",
            depthEnabled: true,
            name: "Test Model Surface Pipeline"
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [weak self] context in
            guard let self else { return }
            context.drawModelSurfaceEntities(
                pipeline: pipelineType,
                label: "Test Model Surface Draw"
            ) { _, entityId, _ in
                self.boundEntityIDs.append(entityId)
            }
        }
    }
}

private final class TestModelSurfaceArgumentDrawRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let pipelineType: RenderPipelineType
    let passID: String
    let argumentLayoutID: String?
    let fragmentShader: String
    let fragmentLibraryID: RenderShaderLibraryID?
    let fragmentLibrary: MTLLibrary?
    var boundEntityIDs: [EntityID] = []
    var encodedValues: [Float] = []

    init(
        id: String = "test.model.surface.argument.draw.extension",
        pipelineType: RenderPipelineType,
        passID: String = "test.model.surface.argument.draw.pass",
        argumentLayoutID: String? = nil,
        fragmentShader: String = "fragmentGeometryShader",
        fragmentLibraryID: RenderShaderLibraryID? = nil,
        fragmentLibrary: MTLLibrary? = nil
    ) {
        self.id = id
        self.pipelineType = pipelineType
        self.passID = passID
        self.argumentLayoutID = argumentLayoutID
        self.fragmentShader = fragmentShader
        self.fragmentLibraryID = fragmentLibraryID
        self.fragmentLibrary = fragmentLibrary
    }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry) {
        guard let fragmentLibraryID, let fragmentLibrary else { return }
        registry.registerLibrary(fragmentLibraryID, library: fragmentLibrary)
    }

    func registerPipelines(_ registry: RenderPipelineRegistry) {
        registry.registerModelSurfacePipeline(
            pipelineType,
            fragmentShader: fragmentShader,
            fragmentShaderLibrary: fragmentLibraryID.map(RenderShaderLibraryReference.registered) ?? .engine,
            depthEnabled: true,
            name: "Test Model Surface Argument Pipeline"
        )
    }

    func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry) {
        guard let argumentLayoutID else { return }

        registry.registerArgumentBuffer(
            RenderExtensionArgumentBufferDescriptor(
                id: argumentLayoutID,
                buffers: [
                    RenderExtensionArgumentBuffer(
                        id: RenderExtensionModelSurfaceArgument.buffer0
                    ),
                ]
            )
        )
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {
        builder.addPass(id: passID, stage: .beforePostProcess) { [weak self] context in
            guard let self else { return }
            context.drawModelSurfaceEntities(
                pipeline: pipelineType,
                label: "Test Model Surface Argument Draw",
                argumentLayoutID: argumentLayoutID,
                bindArguments: { arguments, entityId, _ in
                    var value = Float(self.boundEntityIDs.count + 1)
                    arguments.setBytes(
                        &value,
                        id: RenderExtensionModelSurfaceArgument.buffer0
                    )
                    self.boundEntityIDs.append(entityId)
                    self.encodedValues.append(value)
                }
            )
        }
    }
}

final class RenderGraphBuilderTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - addSceneBackgroundPass Tests

    func testAddSceneBackgroundPass_EnvironmentMode() {
        var graph = [String: RenderPass]()

        let passID = addSceneBackgroundPass(to: &graph, mode: .environment)

        XCTAssertNotNil(passID, "Environment mode should return a pass ID")
        XCTAssertEqual(passID, "environment", "Pass ID should be 'environment'")
        XCTAssertNotNil(graph["environment"], "Environment pass should be added to graph")
        XCTAssertEqual(graph["environment"]?.dependencies.count, 0, "Environment pass should have no dependencies")
    }

    func testAddSceneBackgroundPass_GridMode() {
        var graph = [String: RenderPass]()

        let passID = addSceneBackgroundPass(to: &graph, mode: .grid)

        XCTAssertNotNil(passID, "Grid mode should return a pass ID")
        XCTAssertEqual(passID, "grid", "Pass ID should be 'grid'")
        XCTAssertNotNil(graph["grid"], "Grid pass should be added to graph")
        XCTAssertEqual(graph["grid"]?.dependencies.count, 0, "Grid pass should have no dependencies")
    }

    func testAddSceneBackgroundPass_NoneMode() {
        var graph = [String: RenderPass]()

        let passID = addSceneBackgroundPass(to: &graph, mode: .none)

        XCTAssertNil(passID, "None mode should return nil")
        XCTAssertTrue(graph.isEmpty, "Graph should remain empty for .none mode")
    }

    // MARK: - gBufferPass Tests

    func testGBufferPass_CreatesCorrectPasses() {
        var graph = [String: RenderPass]()
        let shadowPass = RenderPass(id: "shadow", dependencies: [], execute: nil)
        graph[shadowPass.id] = shadowPass

        gBufferPass(graph: &graph, shadowPass: shadowPass)

        // Verify all passes are created
        XCTAssertNotNil(graph["model"], "Model pass should be created")
        XCTAssertNotNil(graph["batchedModel"], "Batched model pass should be created")
        XCTAssertNotNil(graph["ssao"], "SSAO pass should be created (handles blur internally)")
        XCTAssertNotNil(graph["lightPass"], "Light pass should be created")
    }

    func testGBufferPass_CorrectDependencies() {
        var graph = [String: RenderPass]()
        let shadowPass = RenderPass(id: "shadow", dependencies: [], execute: nil)
        graph[shadowPass.id] = shadowPass

        gBufferPass(graph: &graph, shadowPass: shadowPass)

        // Verify dependencies
        XCTAssertEqual(graph["model"]?.dependencies, ["shadow"], "Model pass should depend on shadow pass")
        XCTAssertEqual(graph["batchedModel"]?.dependencies, ["model"], "Batched model pass should depend on model pass")
        XCTAssertEqual(graph["hzbDepthSource"]?.dependencies, ["batchedModel"], "HZB source pass should depend on batched model pass")
        XCTAssertNil(graph["wireframeOcclusionDepth"], "Wireframe occlusion depth pass should not exist in the graph")
        XCTAssertEqual(graph["ssao"]?.dependencies, ["hzbDepthSource"], "SSAO pass should depend on the stored opaque depth source")

        let lightDeps = graph["lightPass"]?.dependencies.sorted()
        XCTAssertEqual(lightDeps, ["ssao"], "Light pass stub should wait for SSAO before downstream composition")
    }

    func testGBufferPass_TopologicalOrder() throws {
        var graph = [String: RenderPass]()
        let shadowPass = RenderPass(id: "shadow", dependencies: [], execute: nil)
        graph[shadowPass.id] = shadowPass

        gBufferPass(graph: &graph, shadowPass: shadowPass)

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Verify correct ordering constraints
        assertTopologicalConstraints(order: order, constraints: [
            ("shadow", "model"),
            ("model", "batchedModel"),
            ("batchedModel", "hzbDepthSource"),
            ("hzbDepthSource", "ssao"),
            ("ssao", "lightPass"),
        ])
    }

    // MARK: - postProcessingEffects Tests

    func testPostProcessingEffects_CreatesBasePasses() {
        var graph = [String: RenderPass]()
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let finalPass = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass"
        )

        // Verify base post-processing passes are created
        XCTAssertNotNil(graph["depthOfField"], "Depth of field pass should be created")
        XCTAssertNotNil(graph["chromatic"], "Chromatic aberration pass should be created")
        XCTAssertNotNil(graph["bloomThreshold"], "Bloom threshold pass should be created")
        XCTAssertNotNil(finalPass, "Should return a final pass")
    }

    func testPostProcessingEffects_CorrectBaseDependencies() {
        var graph = [String: RenderPass]()
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        _ = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass"
        )

        XCTAssertEqual(graph["depthOfField"]?.dependencies, ["lightPass"],
                       "Depth of field should depend on lightPass")
        XCTAssertEqual(graph["chromatic"]?.dependencies, ["depthOfField"],
                       "Chromatic aberration should depend on depthOfField")

        let bloomDeps = graph["bloomThreshold"]?.dependencies
        XCTAssertEqual(bloomDeps, ["chromatic"],
                       "Bloom threshold should depend only on chromatic")
    }

    func testPostProcessingEffects_TopologicalOrder() throws {
        let lightPass = RenderPass(id: "lightPass", dependencies: [], execute: nil)
        var graph = [lightPass.id: lightPass]

        BloomThresholdParams.shared.enabled = true

        _ = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass"
        )

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Verify correct ordering of post-processing chain
        assertTopologicalConstraints(order: order, constraints: [
            ("depthOfField", "chromatic"),
            ("chromatic", "bloomThreshold"),
            ("bloomThreshold", "blur_pass_hor_pass1"),
            ("blur_pass_hor_pass1", "blur_pass_ver_pass1"),
            ("blur_pass_ver_pass1", "blur_pass_hor_pass2"),
            ("blur_pass_hor_pass2", "blur_pass_ver_pass2"),
        ])

        // Clean up
        BloomThresholdParams.shared.enabled = false
    }

    // MARK: - buildGameModeGraph Integration Tests

    func testBuildGameModeGraph_CreatesCompleteGraph() throws {
        // Set up environment for non-XR rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify essential passes exist
        XCTAssertNotNil(graph["environment"], "Environment pass should exist")
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["transparency"], "Transparency pass should exist")
        XCTAssertNotNil(graph["wireframe"], "Wireframe pass should exist")
        XCTAssertNotNil(graph["spatialDebug"], "Spatial debug pass should exist")
        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify final pass
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
    }

    func testBuildGameModeGraph_GridMode() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false // sky is the default non-IBL background; opt into grid explicitly

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["grid"], "Grid pass should exist when renderEnvironment is false")
        XCTAssertNil(graph["environment"], "Environment pass should not exist")

        // Shadow should depend on grid
        XCTAssertEqual(graph["shadow"]?.dependencies, ["grid"],
                       "Shadow should depend on grid in grid mode")
    }

    func testBuildGameModeGraph_XRPassthroughMode() throws {
        renderInfo.immersionStyle = .mixed

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph["environment"], "Environment pass should not exist in passthrough mode")
        XCTAssertNil(graph["grid"], "Grid pass should not exist in passthrough mode")

        // Shadow should have no base pass dependency
        XCTAssertEqual(graph["shadow"]?.dependencies, [],
                       "Shadow should have no dependencies in passthrough mode")
    }

    func testBuildGameModeGraph_XRFullImmersionMode() throws {
        renderInfo.immersionStyle = .full

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["environment"], "Environment pass should exist in full immersion mode")
        XCTAssertNil(graph["grid"], "Grid pass should not exist in full immersion mode")

        // Shadow should depend on environment
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment in full immersion mode")
    }

    func testBuildGameModeGraph_ValidTopologicalOrder() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let (graph, _) = try buildGameModeGraph()

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Verify key ordering constraints
        assertTopologicalConstraints(order: order, constraints: [
            ("environment", "shadow"),
            ("shadow", "model"),
            ("model", "gaussian"),
            ("model", "lightPass"),
            ("lightPass", "transparency"),
            ("transparency", "wireframe"),
            ("wireframe", "spatialDebug"),
            ("spatialDebug", "depthOfField"),
            ("depthOfField", "chromatic"),
            ("chromatic", "bloomThreshold"),
            ("bloomThreshold", "precomp"),
            ("gaussian", "precomp"),
            ("precomp", "look"),
            ("look", "outputTransform"),
        ])
    }

    func testBuildGameModeGraph_BypassPostProcessing_UsesBypassPass() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        defer { bypassPostProcessing = false }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["wireframe"], "Wireframe pass should exist")
        XCTAssertNotNil(graph["spatialDebug"], "Spatial debug pass should exist")
        XCTAssertEqual(graph["wireframe"]?.dependencies, ["transparency"],
                       "Wireframe pass should depend on transparency")
        XCTAssertEqual(graph["spatialDebug"]?.dependencies, ["wireframe"],
                       "Spatial debug pass should depend on wireframe")
        XCTAssertNotNil(graph["postProcessBypass"], "Bypass pass should exist when bypassPostProcessing is enabled")
        XCTAssertEqual(graph["postProcessBypass"]?.dependencies, ["spatialDebug"],
                       "Bypass pass should depend on spatialDebug")
        XCTAssertNotNil(graph["look"], "Look pass should exist when bypassing post-processing")
        XCTAssertNotNil(graph["fxaa"], "FXAA pass should exist when bypassing post-processing")
        XCTAssertNotNil(graph["outputTransform"], "Output transform should exist when bypassing post-processing")

        XCTAssertNil(graph["depthOfField"], "Depth of field pass should not exist when bypassing post-processing")
        XCTAssertNil(graph["chromatic"], "Chromatic pass should not exist when bypassing post-processing")
        XCTAssertNil(graph["bloomThreshold"], "Bloom threshold pass should not exist when bypassing post-processing")

        let precompDeps = graph["precomp"]?.dependencies.sorted() ?? []
        XCTAssertTrue(precompDeps.contains("postProcessBypass"),
                      "Precomp should depend on postProcessBypass when bypassing post-processing")
        XCTAssertTrue(precompDeps.contains("gaussian"),
                      "Precomp should still depend on gaussian pass")

        XCTAssertEqual(graph["look"]?.dependencies, ["precomp"],
                       "Look should depend on precomp when bypassing post-processing")
        XCTAssertEqual(graph["fxaa"]?.dependencies, ["look"],
                       "FXAA should depend on look when bypassing post-processing")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["fxaa"],
                       "Output transform should depend on fxaa when bypassing post-processing")
    }

    func testBuildGameModeGraph_FXAAEdgeDebugUsesDiagnosticPass() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .fxaaEdgeDebug
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["fxaaEdgeDebug"], "FXAA edge debug pass should exist")
        XCTAssertNil(graph["fxaa"], "Normal FXAA pass should not exist when viewing FXAA edge debug")
        XCTAssertEqual(graph["fxaaEdgeDebug"]?.dependencies, ["look"],
                       "FXAA edge debug should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["fxaaEdgeDebug"],
                       "Output transform should read the FXAA edge debug output")
    }

    func testBuildGameModeGraph_SMAAUsesThreePassChain() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .smaa
        defer { antiAliasingMode = .fxaa }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNil(graph["fxaa"], "FXAA pass should not exist when SMAA is active")
        XCTAssertNotNil(graph["smaaEdges"], "SMAA edge pass should exist")
        XCTAssertNotNil(graph["smaaBlendWeights"], "SMAA blend-weight pass should exist")
        XCTAssertNotNil(graph["smaaNeighborhood"], "SMAA neighborhood pass should exist")
        XCTAssertEqual(graph["smaaEdges"]?.dependencies, ["look"],
                       "SMAA edge pass should depend on look")
        XCTAssertEqual(graph["smaaBlendWeights"]?.dependencies, ["smaaEdges"],
                       "SMAA blend-weight pass should depend on edge detection")
        XCTAssertEqual(graph["smaaNeighborhood"]?.dependencies, ["smaaBlendWeights"],
                       "SMAA neighborhood pass should depend on blend weights")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["smaaNeighborhood"],
                       "Output transform should read the SMAA neighborhood output")
    }

    func testBuildGameModeGraph_SMAAEdgesDebugStopsAfterEdgePass() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaEdges
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["smaaEdges"], "SMAA edge pass should exist for edge debug")
        XCTAssertNil(graph["smaaBlendWeights"], "SMAA blend pass should not run for edge debug")
        XCTAssertNil(graph["smaaNeighborhood"], "SMAA neighborhood pass should not run for edge debug")
        XCTAssertEqual(graph["smaaEdges"]?.dependencies, ["look"],
                       "SMAA edge debug should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["smaaEdges"],
                       "Output transform should read the SMAA edge texture")
    }

    func testBuildGameModeGraph_SMAABlendDebugStopsAfterBlendPass() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaBlend
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["smaaEdges"], "SMAA edge pass should exist for blend debug")
        XCTAssertNotNil(graph["smaaBlendWeights"], "SMAA blend pass should exist for blend debug")
        XCTAssertNil(graph["smaaNeighborhood"], "SMAA neighborhood pass should not run for blend debug")
        XCTAssertEqual(graph["smaaEdges"]?.dependencies, ["look"],
                       "SMAA edge pass should depend on look")
        XCTAssertEqual(graph["smaaBlendWeights"]?.dependencies, ["smaaEdges"],
                       "SMAA blend debug should depend on edge detection")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["smaaBlendWeights"],
                       "Output transform should read the SMAA blend texture")
    }

    func testBuildGameModeGraph_SMAADifferenceDebugRunsFullChain() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaDifference
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["smaaEdges"], "SMAA edge pass should exist for difference debug")
        XCTAssertNotNil(graph["smaaBlendWeights"], "SMAA blend pass should exist for difference debug")
        XCTAssertNotNil(graph["smaaNeighborhood"], "SMAA neighborhood pass should exist for difference debug")
        XCTAssertNotNil(graph["smaaDifference"], "SMAA difference pass should exist for difference debug")
        XCTAssertEqual(graph["smaaEdges"]?.dependencies, ["look"],
                       "SMAA edge pass should depend on look")
        XCTAssertEqual(graph["smaaBlendWeights"]?.dependencies, ["smaaEdges"],
                       "SMAA blend pass should depend on edge detection")
        XCTAssertEqual(graph["smaaNeighborhood"]?.dependencies, ["smaaBlendWeights"],
                       "SMAA neighborhood pass should depend on blend weights")
        XCTAssertEqual(graph["smaaDifference"]?.dependencies, ["smaaNeighborhood"],
                       "SMAA difference pass should compare after neighborhood resolve")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["smaaDifference"],
                       "Output transform should read the SMAA difference texture")
    }

    // MARK: - AntiAliasing .none Mode

    /// When antiAliasingMode is .none, no AA pass of any kind should appear in the graph
    /// and outputTransform must depend directly on look rather than on an AA pass.
    func testBuildGameModeGraph_NoAAMode_HasNoAAPassAndConnectsDirectlyToOutput() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .lit
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform")
        XCTAssertNil(graph["fxaa"], "No FXAA pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaEdges"], "No SMAA edges pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaBlendWeights"], "No SMAA blend-weight pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaNeighborhood"], "No SMAA neighborhood pass when antiAliasingMode is .none")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform must depend directly on look when no AA is active")
    }

    func testBuildGameModeGraph_MSAAMode_UsesOpaqueResolveAndNoPostAAPass() throws {
        guard renderInfo.device.supportsTextureSampleCount(4) else {
            return
        }

        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .msaa
        renderDebugViewMode = .lit
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
            updateOpaqueSampleCountForCurrentState()
        }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertEqual(renderInfo.opaqueSampleCount, 4,
                       "buildGameModeGraph must reconcile MSAA mode changes from DemoHUD")
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.colorAttachments[0].texture?.sampleCount, 4)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.colorAttachments[5].storeAction, .multisampleResolve)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.depthAttachment.storeAction, .multisampleResolve)
        XCTAssertEqual(finalPassID, "outputTransform")
        XCTAssertNil(graph["fxaa"], "MSAA is resolved during the opaque pass, so no FXAA pass should be inserted")
        XCTAssertNil(graph["smaaEdges"], "MSAA is resolved during the opaque pass, so no SMAA edge pass should be inserted")
        XCTAssertNil(graph["smaaBlendWeights"], "MSAA should not run the SMAA blend-weight pass")
        XCTAssertNil(graph["smaaNeighborhood"], "MSAA should not run the SMAA neighborhood pass")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform must depend directly on look when MSAA handles opaque edges")
    }

    // MARK: - G-Buffer Debug View Modes

    /// Switching renderDebugViewMode to any G-Buffer visualization mode must not change the
    /// set of passes in the render graph. The routing change is inside the look pass execution
    /// closure, not in the graph topology.
    func testBuildGameModeGraph_GBufferDebugModes_ProduceSamePassSetAsLitMode() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .fxaa
        defer { renderDebugViewMode = .lit }

        renderDebugViewMode = .lit
        let (baseGraph, _) = try buildGameModeGraph()
        let baseKeys = Set(baseGraph.keys)

        for mode in [RenderDebugViewMode.albedo, .normal, .position, .roughness, .metallic, .depth, .ssaoBlurred, .preTonemapHDRLuminance, .postTonemapOutput] {
            renderDebugViewMode = mode
            let (graph, finalPassID) = try buildGameModeGraph()
            XCTAssertEqual(Set(graph.keys), baseKeys,
                           "Graph pass set must equal .lit mode for .\(mode) debug mode")
            XCTAssertEqual(finalPassID, "outputTransform",
                           "Final pass must be outputTransform in .\(mode) debug mode")
        }
    }

    // MARK: - Bloom Disabled State

    /// When BloomThresholdParams.enabled is false but at least one other effect is active,
    /// the full post-process chain runs but the variable-length blur chain must be entirely
    /// absent and bloomComposite must depend directly on bloomThreshold with no blur
    /// intermediates in between.
    /// Note: when ALL effects are disabled, postProcessingEffects() short-circuits to a
    /// lightweight bypass pass (postProcessDisabledBypass) — bloomComposite never appears.
    /// This test enables vignette to keep the full chain alive while isolating bloom state.
    func testBuildGameModeGraph_BloomDisabled_BlurPassesAbsent() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let wasBloom = BloomThresholdParams.shared.enabled
        let wasVignette = VignetteParams.shared.enabled
        BloomThresholdParams.shared.enabled = false
        VignetteParams.shared.enabled = true // keep the full chain alive; bloom alone is off
        defer {
            BloomThresholdParams.shared.enabled = wasBloom
            VignetteParams.shared.enabled = wasVignette
        }

        let (graph, _) = try buildGameModeGraph()

        // No blur passes should exist when bloom is disabled.
        XCTAssertNil(graph["blur_pass_hor_pass1"], "Horizontal blur pass 1 must not exist when bloom is disabled")
        XCTAssertNil(graph["blur_pass_ver_pass1"], "Vertical blur pass 1 must not exist when bloom is disabled")
        XCTAssertNil(graph["blur_pass_hor_pass2"], "Horizontal blur pass 2 must not exist when bloom is disabled")
        XCTAssertNil(graph["blur_pass_ver_pass2"], "Vertical blur pass 2 must not exist when bloom is disabled")

        // bloomComposite must depend directly on bloomThreshold (no blur intermediates).
        XCTAssertEqual(graph["bloomComposite"]?.dependencies, ["bloomThreshold"],
                       "bloomComposite must depend directly on bloomThreshold when bloom is disabled")
    }

    // MARK: - Gaussian Pass Integration Tests

    func testBuildGameModeGraph_GaussianPassExists() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should exist in game mode graph")
    }

    func testBuildGameModeGraph_GaussianDependsOnModel() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        XCTAssertEqual(graph["gaussian"]?.dependencies, ["model"],
                       "Gaussian pass should depend on model pass to access depth buffer")
    }

    func testBuildGameModeGraph_PreCompDependsOnGaussian() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        let precompDeps = graph["precomp"]?.dependencies.sorted() ?? []
        XCTAssertTrue(precompDeps.contains("gaussian"),
                      "Pre-composite pass should depend on gaussian pass")
    }

    func testBuildGameModeGraph_GaussianHasExecutionFunction() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["gaussian"]?.execute,
                        "Gaussian pass should have an execution function")
    }

    func testBuildGameModeGraph_GaussianInAllRenderModes() throws {
        // Test that gaussian pass exists in all render modes
        let modes: [(UntoldImmersionMode, Bool, Bool, String)] = [
            (.none, true, true, "environment"),
            (.none, false, false, "grid"),
            (.full, true, true, "full immersion"),
            (.mixed, false, true, "passthrough"),
        ]

        for (immersionStyle, useEnvironment, useSky, description) in modes {
            renderInfo.immersionStyle = immersionStyle
            renderEnvironment = useEnvironment
            renderSkyBackground = useSky

            let (graph, _) = try buildGameModeGraph()

            XCTAssertNotNil(graph["gaussian"],
                            "Gaussian pass should exist in \(description) mode")
            XCTAssertEqual(graph["gaussian"]?.dependencies, ["model"],
                           "Gaussian should depend on model in \(description) mode")
        }
    }

    func testBuildGameModeGraph_GaussianTopologicalPosition() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Gaussian must come after model
        guard let gaussianIndex = order.firstIndex(of: "gaussian"),
              let modelIndex = order.firstIndex(of: "model")
        else {
            XCTFail("Both gaussian and model passes should exist")
            return
        }

        XCTAssertTrue(modelIndex < gaussianIndex,
                      "Model pass must come before gaussian pass")

        // Gaussian must come before precomp
        guard let precompIndex = order.firstIndex(of: "precomp") else {
            XCTFail("Precomp pass should exist")
            return
        }

        XCTAssertTrue(gaussianIndex < precompIndex,
                      "Gaussian pass must come before pre-composite pass")
    }

    func testRenderExtensionRegisteredThroughRenderingAPIInsertsAfterTransparency() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        setRendering(.extensions(.register(
            TestStageRenderExtension(passID: "test.afterTransparency", stage: .afterTransparency)
        )))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["test.afterTransparency"], "Extension pass should be added to the graph")
        XCTAssertEqual(graph["test.afterTransparency"]?.dependencies, ["transparency"])
        XCTAssertEqual(graph["wireframe"]?.dependencies, ["test.afterTransparency"],
                       "Wireframe should wait for afterTransparency extension passes")

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("transparency", "test.afterTransparency"),
            ("test.afterTransparency", "wireframe"),
        ])
    }

    func testRenderExtensionBeforePostProcessRewiresPostProcessEntry() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        setRendering(.extensions(.register(
            TestStageRenderExtension(passID: "test.beforePostProcess", stage: .beforePostProcess)
        )))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertEqual(graph["test.beforePostProcess"]?.dependencies, ["spatialDebug"])
        XCTAssertEqual(graph["depthOfField"]?.dependencies, ["test.beforePostProcess"],
                       "Post-processing should start after beforePostProcess extension passes")

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("spatialDebug", "test.beforePostProcess"),
            ("test.beforePostProcess", "depthOfField"),
        ])
    }

    func testRenderExtensionBeforeOutputRewiresOutputTransform() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        setRendering(.extensions(.register(
            TestStageRenderExtension(passID: "test.beforeOutput", stage: .beforeOutput)
        )))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertEqual(graph["test.beforeOutput"]?.dependencies, ["look"])
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["test.beforeOutput"],
                       "Output transform should wait for beforeOutput extension passes")

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("look", "test.beforeOutput"),
            ("test.beforeOutput", "outputTransform"),
        ])
    }

    func testRenderStageContractContainsOnlyResolvedStages() {
        XCTAssertEqual(RenderStage.allCases, [
            .frameStart,
            .beforeShadows,
            .afterOpaqueLighting,
            .beforeTransparency,
            .afterTransparency,
            .beforePostProcess,
            .afterPostProcess,
            .beforeComposite,
            .beforeLook,
            .beforeOutput,
        ])
    }

    func testReservedPassIDsCoverEveryGameModeGraphVariant() throws {
        let originalEnvironment = renderEnvironment
        let originalSkyBackground = renderSkyBackground
        let originalBypass = bypassPostProcessing
        let originalAA = antiAliasingMode
        let originalDebugMode = renderDebugViewMode
        let originalBloom = BloomThresholdParams.shared.enabled
        let originalVignette = VignetteParams.shared.enabled
        let originalChromatic = ChromaticAberrationParams.shared.enabled
        let originalDepthOfField = DepthOfFieldParams.shared.enabled
        defer {
            renderEnvironment = originalEnvironment
            renderSkyBackground = originalSkyBackground
            bypassPostProcessing = originalBypass
            antiAliasingMode = originalAA
            renderDebugViewMode = originalDebugMode
            BloomThresholdParams.shared.enabled = originalBloom
            VignetteParams.shared.enabled = originalVignette
            ChromaticAberrationParams.shared.enabled = originalChromatic
            DepthOfFieldParams.shared.enabled = originalDepthOfField
        }

        var observedPassIDs = Set<String>()
        func captureGraphPassIDs() throws {
            let (graph, _) = try buildGameModeGraph()
            observedPassIDs.formUnion(graph.keys)
        }

        bypassPostProcessing = false
        BloomThresholdParams.shared.enabled = true
        VignetteParams.shared.enabled = true
        ChromaticAberrationParams.shared.enabled = true
        DepthOfFieldParams.shared.enabled = true
        renderDebugViewMode = .lit

        for environmentEnabled in [false, true] {
            renderEnvironment = environmentEnabled
            for mode in [AntiAliasingMode.none, .fxaa, .smaa, .msaa] {
                antiAliasingMode = mode
                try captureGraphPassIDs()
            }
        }

        // renderEnvironment=false alone selects the default sky background above; also capture
        // the grid pass (reachable via the renderSkyBackground opt-out) so it stays reserved.
        renderEnvironment = false
        renderSkyBackground = false
        try captureGraphPassIDs()
        renderSkyBackground = true

        antiAliasingMode = .none
        for mode in [
            RenderDebugViewMode.fxaaEdgeDebug,
            .smaaEdges,
            .smaaBlend,
            .smaaDifference,
        ] {
            renderDebugViewMode = mode
            try captureGraphPassIDs()
        }

        renderDebugViewMode = .lit
        bypassPostProcessing = true
        try captureGraphPassIDs()

        bypassPostProcessing = false
        BloomThresholdParams.shared.enabled = false
        VignetteParams.shared.enabled = false
        ChromaticAberrationParams.shared.enabled = false
        DepthOfFieldParams.shared.enabled = false
        try captureGraphPassIDs()

        XCTAssertEqual(observedPassIDs, gameModeReservedPassIDs)
    }

    func testEverySupportedRenderExtensionStageParticipatesInGraphOrder() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        antiAliasingMode = .none
        defer {
            bypassPostProcessing = false
            antiAliasingMode = .fxaa
        }

        let stagedPasses: [(id: String, stage: RenderStage)] = [
            ("test.stage.frameStart", .frameStart),
            ("test.stage.beforeShadows", .beforeShadows),
            ("test.stage.afterOpaqueLighting", .afterOpaqueLighting),
            ("test.stage.beforeTransparency", .beforeTransparency),
            ("test.stage.afterTransparency", .afterTransparency),
            ("test.stage.beforePostProcess", .beforePostProcess),
            ("test.stage.afterPostProcess", .afterPostProcess),
            ("test.stage.beforeComposite", .beforeComposite),
            ("test.stage.beforeLook", .beforeLook),
            ("test.stage.beforeOutput", .beforeOutput),
        ]
        for stagedPass in stagedPasses {
            setRendering(.extensions(.register(
                TestStageRenderExtension(passID: stagedPass.id, stage: stagedPass.stage)
            )))
        }

        let (graph, _) = try buildGameModeGraph()
        for stagedPass in stagedPasses {
            XCTAssertNotNil(graph[stagedPass.id], "Missing pass for \(stagedPass.stage.rawValue)")
        }

        let order = try topologicalSortGraph(graph: graph).map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("test.stage.frameStart", "environment"),
            ("environment", "test.stage.beforeShadows"),
            ("test.stage.beforeShadows", "shadow"),
            ("lightPass", "test.stage.afterOpaqueLighting"),
            ("test.stage.afterOpaqueLighting", "test.stage.beforeTransparency"),
            ("test.stage.beforeTransparency", "transparency"),
            ("transparency", "test.stage.afterTransparency"),
            ("test.stage.afterTransparency", "wireframe"),
            ("spatialDebug", "test.stage.beforePostProcess"),
            ("test.stage.beforePostProcess", "postProcessBypass"),
            ("postProcessBypass", "test.stage.afterPostProcess"),
            ("test.stage.afterPostProcess", "test.stage.beforeComposite"),
            ("test.stage.beforeComposite", "precomp"),
            ("precomp", "test.stage.beforeLook"),
            ("test.stage.beforeLook", "look"),
            ("look", "test.stage.beforeOutput"),
            ("test.stage.beforeOutput", "outputTransform"),
        ])
    }

    func testPublicPassDependenciesAllowSameExtensionEarlierPasses() throws {
        setRendering(.extensions(.register(
            TestPublicDependencyRenderExtension(
                id: "test.public.dependencies.same-owner",
                firstPassID: "test.public.dependencies.first",
                secondPassID: "test.public.dependencies.second",
                secondDependencies: [.sameExtension("test.public.dependencies.first")]
            )
        )))

        let (graph, _) = try buildGameModeGraph()
        let second = try XCTUnwrap(graph["test.public.dependencies.second"])
        XCTAssertTrue(second.dependencies.contains("test.public.dependencies.first"))

        let order = try topologicalSortGraph(graph: graph).map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("test.public.dependencies.first", "test.public.dependencies.second"),
        ])
    }

    func testPublicPassDependenciesAllowCuratedEnginePasses() throws {
        setRendering(.extensions(.register(
            TestPublicDependencyOnlyRenderExtension(
                id: "test.public.dependencies.engine",
                passID: "test.public.dependencies.after-lighting",
                dependencies: [.engine(.opaqueLighting)]
            )
        )))

        let (graph, _) = try buildGameModeGraph()
        let pass = try XCTUnwrap(graph["test.public.dependencies.after-lighting"])
        XCTAssertTrue(pass.dependencies.contains(RenderGraphEnginePassDependency.opaqueLighting.rawValue))
    }

    func testPublicPassDependenciesRejectCrossExtensionPasses() throws {
        setRendering(.extensions(.register(
            TestStageRenderExtension(
                id: "test.public.dependencies.source",
                passID: "test.public.dependencies.source-pass",
                stage: .frameStart
            )
        )))
        setRendering(.extensions(.register(
            TestPublicDependencyOnlyRenderExtension(
                id: "test.public.dependencies.invalid-consumer",
                passID: "test.public.dependencies.invalid-pass",
                dependencies: [.sameExtension("test.public.dependencies.source-pass")]
            )
        )))

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNotNil(graph["test.public.dependencies.source-pass"])
        XCTAssertNil(graph["test.public.dependencies.invalid-pass"])
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(
            "test.public.dependencies.invalid-consumer"
        ))
    }

    func testSupportedRenderExtensionStagesResolveAcrossImmersionModes() throws {
        let immersionModes: [UntoldImmersionMode] = [.none, .mixed, .full, .ar]
        bypassPostProcessing = true
        antiAliasingMode = .none
        defer {
            bypassPostProcessing = false
            antiAliasingMode = .fxaa
        }

        for (modeIndex, immersionMode) in immersionModes.enumerated() {
            RenderExtensionRegistry.shared.removeAll()
            renderInfo.immersionStyle = immersionMode

            let passIDs = RenderStage.allCases.map { stage in
                "test.mode\(modeIndex).\(stage.rawValue)"
            }
            for (stage, passID) in zip(RenderStage.allCases, passIDs) {
                setRendering(.extensions(.register(
                    TestStageRenderExtension(passID: passID, stage: stage)
                )))
            }

            let (graph, _) = try buildGameModeGraph()
            for (stage, passID) in zip(RenderStage.allCases, passIDs) {
                XCTAssertNotNil(
                    graph[passID],
                    "Missing \(stage.rawValue) pass in immersion mode \(immersionMode)"
                )
            }
        }
    }

    func testRenderExtensionsPreserveRegistrationOrderWithinStage() throws {
        let firstPassID = "test.sameStage.first"
        let secondPassID = "test.sameStage.second"
        setRendering(.extensions(.register(
            TestStageRenderExtension(passID: firstPassID, stage: .afterTransparency)
        )))
        setRendering(.extensions(.register(
            TestStageRenderExtension(passID: secondPassID, stage: .afterTransparency)
        )))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertEqual(graph[firstPassID]?.dependencies, ["transparency"])
        XCTAssertEqual(graph[secondPassID]?.dependencies, [firstPassID])
        XCTAssertEqual(graph["wireframe"]?.dependencies, [secondPassID])
    }

    func testRenderGraphBuildRejectsUnresolvedStagePasses() {
        var builder = RenderGraphBuilder()
        XCTAssertTrue(builder.addPass(
            id: "test.unresolved.stage",
            stage: .beforeOutput,
            execute: nil
        ))

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .unresolvedStages([.beforeOutput])
            )
        }
    }

    func testRenderGraphBuilderRejectsDuplicatePendingStagePassID() {
        var builder = RenderGraphBuilder()

        XCTAssertTrue(builder.addPass(
            id: "test.duplicate.stage",
            stage: .afterTransparency,
            execute: nil
        ))
        XCTAssertFalse(builder.addPass(
            id: "test.duplicate.stage",
            stage: .beforeOutput,
            execute: nil
        ))

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .duplicatePassID("test.duplicate.stage")
            )
        }
    }

    func testRenderGraphBuilderRejectsDuplicateImmediatePassID() {
        var builder = RenderGraphBuilder()
        XCTAssertTrue(builder.addPass(id: "test.duplicate", dependencies: [], execute: nil))
        XCTAssertFalse(builder.addPass(id: "test.duplicate", dependencies: [], execute: nil))

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .duplicatePassID("test.duplicate")
            )
        }
    }

    func testRenderGraphBuilderRejectsMissingDependency() {
        var builder = RenderGraphBuilder()
        builder.addPass(
            id: "test.dependent",
            dependencies: ["test.missing"],
            execute: nil
        )

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .missingDependency(
                    passID: "test.dependent",
                    dependencyID: "test.missing"
                )
            )
        }
    }

    func testDirectRenderGraphBuilderStillRejectsMissingResourceUsage() {
        let textureID: RenderTextureResourceID = "test.usage.direct.missing"
        var builder = RenderGraphBuilder()
        builder.addPass(
            id: "test.usage.direct.pass",
            stage: .beforeOutput,
            resources: [.texture(textureID, access: .read)],
            execute: nil
        )

        XCTAssertThrowsError(try builder.build()) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .missingResource(
                    passID: "test.usage.direct.pass",
                    kind: .texture,
                    resourceID: textureID.rawValue
                )
            )
        }
    }

    func testGameModeGraphRejectsExtensionWithInvalidDependencyAndRebuilds() throws {
        let renderExtension = TestInvalidDependencyRenderExtension()
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph[renderExtension.passID])
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(
                forExtensionID: renderExtension.id
            ),
            [
                .missingDependency(
                    passID: renderExtension.passID,
                    dependencyID: renderExtension.dependencyID
                ),
            ]
        )
    }

    func testReservedEnginePassIDRejectsOnlyConflictingExtension() throws {
        let renderExtension = TestLifecycleRenderExtension(
            id: "test.pass.reserved.extension",
            artifactSuffix: "reserved.pass",
            passID: "transparency",
            shaderLibrary: renderInfo.library
        )
        setRendering(.extensions(.register(renderExtension)))
        assertLifecycleArtifactsPresent(renderExtension)

        let graph = try buildExecutableGameModeGraph()

        XCTAssertNotNil(graph.passesByID["transparency"])
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        assertLifecycleArtifactsAbsent(renderExtension)
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: renderExtension.id),
            [
                RenderExtensionArtifactConflict(
                    kind: .renderPass,
                    artifactID: "transparency",
                    requestedOwnerID: renderExtension.id,
                    existingOwnerID: nil
                ),
            ]
        )
    }

    func testDuplicateProviderPassIDRollsBackRejectedExtensionPasses() throws {
        let first = TestStageRenderExtension(
            id: "test.pass.owner.first",
            passID: "test.pass.shared",
            stage: .afterTransparency
        )
        let second = TestMultiPassConflictRenderExtension(
            id: "test.pass.owner.second",
            uniquePassID: "test.pass.second.unique",
            conflictingPassID: first.passID
        )
        setRendering(.extensions(.register(first)))
        setRendering(.extensions(.register(second)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph[first.passID])
        XCTAssertNil(graph[second.uniquePassID])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id])
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: second.id),
            [
                RenderExtensionArtifactConflict(
                    kind: .renderPass,
                    artifactID: first.passID,
                    requestedOwnerID: second.id,
                    existingOwnerID: first.id
                ),
            ]
        )
    }

    func testPassCollisionRollsBackOwnedResourceValidationErrors() throws {
        let first = TestStageRenderExtension(
            id: "test.usage.rollback.first",
            passID: "test.usage.rollback.shared",
            stage: .afterTransparency
        )
        let second = TestInvalidResourceThenConflictRenderExtension(
            id: "test.usage.rollback.second",
            uniquePassID: "test.usage.rollback.unique",
            conflictingPassID: first.passID,
            missingTextureID: "test.usage.rollback.missing"
        )
        setRendering(.extensions(.register(first)))
        setRendering(.extensions(.register(second)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph[first.passID])
        XCTAssertNil(graph[second.uniquePassID])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id])
    }

    func testRenderGraphIsolatesMissingExtensionResourceUsage() throws {
        let textureID: RenderTextureResourceID = "test.usage.missing.texture"
        let renderExtension = TestResourceUsageRenderExtension(
            id: "test.usage.missing",
            passID: "test.usage.missing.pass",
            usages: [.texture(textureID, access: .read)]
        )
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph["test.usage.missing.pass"])
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: renderExtension.id),
            [
                .missingResource(
                    passID: "test.usage.missing.pass",
                    kind: .texture,
                    resourceID: textureID.rawValue
                ),
            ]
        )
    }

    func testRenderGraphIsolatesCrossExtensionResourceUsage() throws {
        let textureID: RenderTextureResourceID = "test.usage.provider.texture"
        let provider = TestResourceUsageRenderExtension(
            id: "test.usage.provider",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ]
        )
        let consumer = TestResourceUsageRenderExtension(
            id: "test.usage.consumer",
            passID: "test.usage.consumer.pass",
            usages: [.texture(textureID, access: .read)]
        )
        setRendering(.extensions(.register(provider)))
        setRendering(.extensions(.register(consumer)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph["test.usage.consumer.pass"])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [provider.id])
        XCTAssertNotNil(getRenderResource(textureID))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: consumer.id),
            [
                .inaccessibleResource(
                    passID: "test.usage.consumer.pass",
                    kind: .texture,
                    resourceID: textureID.rawValue,
                    requestedOwnerID: consumer.id,
                    existingOwnerID: provider.id
                ),
            ]
        )
    }

    func testRenderGraphIsolatesIncompatibleTextureUsageAndReleasesArtifacts() throws {
        let textureID: RenderTextureResourceID = "test.usage.incompatible.texture"
        let renderExtension = TestResourceUsageRenderExtension(
            id: "test.usage.incompatible.texture",
            passID: "test.usage.incompatible.texture.pass",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            usages: [.texture(textureID, access: [.write, .renderTarget])]
        )
        setRendering(.extensions(.register(renderExtension)))

        XCTAssertNotNil(getRenderResource(textureID))
        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph["test.usage.incompatible.texture.pass"])
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .released)
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: renderExtension.id),
            [
                .incompatibleResourceUsage(
                    passID: "test.usage.incompatible.texture.pass",
                    kind: .texture,
                    resourceID: textureID.rawValue,
                    access: [.write, .renderTarget]
                ),
            ]
        )
    }

    func testRenderGraphIsolatesRenderTargetBufferUsage() throws {
        let bufferID: RenderBufferResourceID = "test.usage.incompatible.buffer"
        let renderExtension = TestResourceUsageRenderExtension(
            id: "test.usage.incompatible.buffer",
            passID: "test.usage.incompatible.buffer.pass",
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 64),
            ],
            usages: [.buffer(bufferID, access: .renderTarget)]
        )
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNil(graph["test.usage.incompatible.buffer.pass"])
        XCTAssertNil(getRenderResource(bufferID))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: renderExtension.id),
            [
                .incompatibleResourceUsage(
                    passID: "test.usage.incompatible.buffer.pass",
                    kind: .buffer,
                    resourceID: bufferID.rawValue,
                    access: .renderTarget
                ),
            ]
        )
    }

    func testGraphValidationFailureDoesNotRemoveHealthyExtensionPasses() throws {
        let healthy = TestStageRenderExtension(
            id: "test.usage.isolation.healthy",
            passID: "test.usage.isolation.healthy.pass",
            stage: .beforeOutput
        )
        let invalid = TestResourceUsageRenderExtension(
            id: "test.usage.isolation.invalid",
            passID: "test.usage.isolation.invalid.pass",
            usages: [.buffer("test.usage.isolation.missing", access: .read)]
        )
        setRendering(.extensions(.register(healthy)))
        setRendering(.extensions(.register(invalid)))

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph[healthy.passID])
        XCTAssertNil(graph["test.usage.isolation.invalid.pass"])
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [healthy.id])
    }

    func testGraphValidationReportsAllErrorsAndRollsBackAllExtensionPasses() throws {
        let firstTextureID: RenderTextureResourceID = "test.usage.multiple.first"
        let secondBufferID: RenderBufferResourceID = "test.usage.multiple.second"
        let firstInvalidExtension = TestResourceUsageRenderExtension(
            id: "test.usage.multiple",
            passID: "test.usage.multiple.first.pass",
            usages: [.texture(firstTextureID, access: .read)]
        )
        let secondInvalidExtension = TestResourceUsageRenderExtension(
            id: firstInvalidExtension.id,
            passID: "test.usage.multiple.second.pass",
            usages: [.buffer(secondBufferID, access: .read)]
        )

        var builder = RenderGraphBuilder()
        builder.beginExtensionRegistration(id: firstInvalidExtension.id)
        firstInvalidExtension.buildGraph(&builder, context: makeRenderGraphBuildContext())
        secondInvalidExtension.buildGraph(&builder, context: makeRenderGraphBuildContext())
        let report = builder.endExtensionRegistration()

        XCTAssertEqual(
            report.validationErrors,
            [
                .missingResource(
                    passID: "test.usage.multiple.first.pass",
                    kind: .texture,
                    resourceID: firstTextureID.rawValue
                ),
                .missingResource(
                    passID: "test.usage.multiple.second.pass",
                    kind: .buffer,
                    resourceID: secondBufferID.rawValue
                ),
            ]
        )
        XCTAssertTrue(report.conflicts.isEmpty)
        XCTAssertTrue(try builder.build().isEmpty)
    }

    func testSuccessfulReregistrationClearsGraphValidationErrors() throws {
        let extensionID = "test.usage.diagnostics.reregister"
        let invalid = TestResourceUsageRenderExtension(
            id: extensionID,
            passID: "test.usage.diagnostics.invalid.pass",
            usages: [.texture("test.usage.diagnostics.missing", access: .read)]
        )
        setRendering(.extensions(.register(invalid)))
        _ = try buildGameModeGraph()
        XCTAssertFalse(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: extensionID).isEmpty
        )

        let valid = TestStageRenderExtension(
            id: extensionID,
            passID: "test.usage.diagnostics.valid.pass",
            stage: .beforeOutput
        )
        XCTAssertEqual(RenderExtensionRegistry.shared.register(valid), .registered)

        XCTAssertTrue(
            RenderExtensionRegistry.shared.graphValidationErrors(forExtensionID: extensionID).isEmpty
        )
    }

    func testRenderPassContextExposesOnlyDeclaredResourceUsages() throws {
        let declaredTextureID: RenderTextureResourceID = "test.usage.declared.texture"
        let undeclaredTextureID: RenderTextureResourceID = "test.usage.undeclared.texture"
        let declaredBufferID: RenderBufferResourceID = "test.usage.declared.buffer"
        let undeclaredBufferID: RenderBufferResourceID = "test.usage.undeclared.buffer"
        let usages: [RenderGraphResourceUsage] = [
            .texture(declaredTextureID, access: [.read, .renderTarget]),
            .buffer(declaredBufferID, access: .write),
        ]
        let renderExtension = TestResourceUsageRenderExtension(
            id: "test.usage.scoped",
            passID: "test.usage.scoped.pass",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: declaredTextureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: [.shaderRead, .renderTarget]
                ),
                RenderExtensionTextureDescriptor(
                    id: undeclaredTextureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: declaredBufferID, length: 64),
                RenderExtensionBufferDescriptor(id: undeclaredBufferID, length: 64),
            ],
            usages: usages,
            observedTextureIDs: [declaredTextureID, undeclaredTextureID],
            observedBufferIDs: [declaredBufferID, undeclaredBufferID]
        )
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()
        XCTAssertEqual(graph["test.usage.scoped.pass"]?.resourceUsages, usages)
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph["test.usage.scoped.pass"]?.execute?(commandBuffer)

        XCTAssertEqual(renderExtension.observedTextures[declaredTextureID], true)
        XCTAssertEqual(renderExtension.observedTextures[undeclaredTextureID], false)
        XCTAssertEqual(renderExtension.observedBuffers[declaredBufferID], true)
        XCTAssertEqual(renderExtension.observedBuffers[undeclaredBufferID], false)
    }

    func testRenderPassContextExposesResolvedStage() throws {
        let renderExtension = TestContextStageRenderExtension()
        setRendering(.extensions(.register(renderExtension)))

        let (graph, _) = try buildGameModeGraph()
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        graph[renderExtension.passID]?.execute?(commandBuffer)

        XCTAssertEqual(renderExtension.observedStage, .beforePostProcess)
    }

    func testRenderExtensionRegistersFixedTextureResource() {
        let textureID: RenderTextureResourceID = "test.fixed.texture"

        setRendering(.extensions(.register(
            TestResourceRenderExtension(
                textureID: textureID.rawValue,
                size: .fixed(width: 128, height: 64)
            )
        )))

        let texture = getRenderResource(textureID)
        XCTAssertNotNil(texture, "Extension texture should be created when registered after renderer initialization")
        XCTAssertEqual(texture?.width, 128)
        XCTAssertEqual(texture?.height, 64)
        XCTAssertEqual(texture?.pixelFormat, .rgba16Float)
    }

    func testRenderExtensionViewportTextureResourceRecreatesOnResize() {
        let textureID = "test.viewport.texture"

        setRendering(.extensions(.register(
            TestResourceRenderExtension(
                textureID: textureID,
                size: .viewportScale(0.5)
            )
        )))

        var texture = getRenderResource(.texture(textureID))
        XCTAssertEqual(texture?.width, windowWidth / 2)
        XCTAssertEqual(texture?.height, windowHeight / 2)

        renderInfo.viewPort = simd_float2(640, 360)
        renderer.initSizeableResources()

        texture = getRenderResource(.texture(textureID))
        XCTAssertEqual(texture?.width, 320)
        XCTAssertEqual(texture?.height, 180)
    }

    func testRenderPassContextExposesExtensionResources() throws {
        let extensionInstance = TestResourceRenderExtension(
            textureID: "test.context.texture",
            passID: "test.context.pass",
            size: .fixed(width: 32, height: 16)
        )
        setRendering(.extensions(.register(extensionInstance)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph["test.context.pass"]?.execute?(commandBuffer)

        XCTAssertEqual(extensionInstance.observedTextureSize, SIMD2<Int>(32, 16))
    }

    func testRenderExtensionUnregisterRemovesOwnedTextureResources() {
        let textureID = "test.unregister.texture"
        let extensionInstance = TestResourceRenderExtension(
            textureID: textureID,
            size: .fixed(width: 8, height: 8)
        )

        setRendering(.extensions(.register(extensionInstance)))
        XCTAssertNotNil(getRenderResource(.texture(textureID)))

        setRendering(.extensions(.unregister(extensionInstance.id)))
        XCTAssertNil(getRenderResource(.texture(textureID)),
                     "Unregistering an extension should remove its owned texture resources")
        XCTAssertEqual(
            RenderResourceRegistry.shared.textureState(RenderTextureResourceID(textureID)),
            .released
        )
    }

    func testRenderExtensionRegistersTypedBufferResource() throws {
        let bufferID: RenderBufferResourceID = "test.typed.buffer"
        let extensionInstance = TestBufferResourceRenderExtension(
            bufferID: bufferID,
            length: 256
        )

        setRendering(.extensions(.register(extensionInstance)))

        let buffer = getRenderResource(bufferID)
        XCTAssertEqual(buffer?.length, 256)
        XCTAssertEqual(buffer?.label, bufferID.rawValue)

        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }
        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[extensionInstance.passID]?.execute?(commandBuffer)
        XCTAssertEqual(extensionInstance.observedBufferLength, 256)
    }

    func testRenderExtensionUnregisterRemovesOwnedBufferResources() {
        let bufferID: RenderBufferResourceID = "test.unregister.buffer"
        let extensionInstance = TestBufferResourceRenderExtension(
            bufferID: bufferID,
            length: 64
        )

        setRendering(.extensions(.register(extensionInstance)))
        XCTAssertNotNil(getRenderResource(bufferID))

        setRendering(.extensions(.unregister(extensionInstance.id)))
        XCTAssertNil(getRenderResource(bufferID))
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .released)
    }

    func testInvalidResourceDeclarationRejectsEntireTransaction() {
        let textureID: RenderTextureResourceID = "test.transaction.valid.texture"
        let invalidBufferID: RenderBufferResourceID = "test.transaction.invalid.buffer"
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.transaction.invalid",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 16, height: 16),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: invalidBufferID, length: 0),
            ]
        )

        let result = RenderExtensionRegistry.shared.register(renderExtension)
        let expectedError = RenderExtensionResourceValidationError.invalidBufferLength(
            id: invalidBufferID.rawValue,
            length: 0
        )

        XCTAssertEqual(
            result,
            .rejectedResources(conflicts: [], validationErrors: [expectedError])
        )
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertNil(getRenderResource(invalidBufferID))
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.resourceValidationErrors(forExtensionID: renderExtension.id),
            [expectedError]
        )
    }

    func testDuplicateResourceIDRejectsEntireTransaction() {
        let textureID: RenderTextureResourceID = "test.transaction.unique.texture"
        let bufferID: RenderBufferResourceID = "test.transaction.duplicate.buffer"
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.transaction.duplicate",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 64),
                RenderExtensionBufferDescriptor(id: bufferID, length: 128),
            ]
        )
        let expectedConflict = RenderExtensionArtifactConflict(
            kind: .buffer,
            artifactID: bufferID.rawValue,
            requestedOwnerID: renderExtension.id,
            existingOwnerID: renderExtension.id
        )

        XCTAssertEqual(
            RenderExtensionRegistry.shared.register(renderExtension),
            .rejected([expectedConflict])
        )
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertNil(getRenderResource(bufferID))
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: renderExtension.id),
            [expectedConflict]
        )
    }

    func testResourceCollisionDoesNotCommitEarlierDeclarations() {
        let sharedTextureID: RenderTextureResourceID = "test.transaction.shared.texture"
        let uniqueBufferID: RenderBufferResourceID = "test.transaction.second.unique.buffer"
        let first = TestTransactionalResourceRenderExtension(
            id: "test.transaction.first",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: sharedTextureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ]
        )
        let second = TestTransactionalResourceRenderExtension(
            id: "test.transaction.second",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: sharedTextureID,
                    size: .fixed(width: 32, height: 32),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: uniqueBufferID, length: 64),
            ]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(first), .registered)
        let originalTexture = getRenderResource(sharedTextureID)
        let result = RenderExtensionRegistry.shared.register(second)

        XCTAssertEqual(
            result,
            .rejected([
                RenderExtensionArtifactConflict(
                    kind: .texture,
                    artifactID: sharedTextureID.rawValue,
                    requestedOwnerID: second.id,
                    existingOwnerID: first.id
                ),
            ])
        )
        XCTAssertTrue(getRenderResource(sharedTextureID) === originalTexture)
        XCTAssertNil(getRenderResource(uniqueBufferID))
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id])
    }

    func testInvalidReplacementPreservesPreviousResourceObjects() {
        let ownerID = "test.transaction.replacement"
        let originalTextureID: RenderTextureResourceID = "test.transaction.original.texture"
        let originalBufferID: RenderBufferResourceID = "test.transaction.original.buffer"
        let replacementTextureID: RenderTextureResourceID = "test.transaction.replacement.texture"
        let invalidBufferID: RenderBufferResourceID = "test.transaction.replacement.invalid"
        let original = TestTransactionalResourceRenderExtension(
            id: ownerID,
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: originalTextureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: originalBufferID, length: 64),
            ]
        )
        let replacement = TestTransactionalResourceRenderExtension(
            id: ownerID,
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: replacementTextureID,
                    size: .fixed(width: 16, height: 16),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: invalidBufferID, length: -1),
            ]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(original), .registered)
        let originalTexture = getRenderResource(originalTextureID)
        let originalBuffer = getRenderResource(originalBufferID)

        guard case .rejectedResources = RenderExtensionRegistry.shared.register(replacement) else {
            XCTFail("Expected invalid replacement resources to be rejected")
            return
        }

        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [ownerID])
        XCTAssertTrue(getRenderResource(originalTextureID) === originalTexture)
        XCTAssertTrue(getRenderResource(originalBufferID) === originalBuffer)
        XCTAssertNil(getRenderResource(replacementTextureID))
        XCTAssertNil(getRenderResource(invalidBufferID))
        XCTAssertEqual(original.resourceRegistrationCount, 1)
    }

    func testResourceDeclarationsCommitBeforeMetalAllocation() {
        let bufferID: RenderBufferResourceID = "test.transaction.deferred.buffer"
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.transaction.deferred",
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 96),
            ]
        )
        let device = renderInfo.device
        renderInfo.device = nil
        defer { renderInfo.device = device }

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertNil(getRenderResource(bufferID))
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .declared)
        XCTAssertEqual(renderExtension.resourceRegistrationCount, 1)

        renderInfo.device = device
        RenderResourceRegistry.shared.recreateResources()

        XCTAssertEqual(getRenderResource(bufferID)?.length, 96)
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .allocated)
        XCTAssertEqual(renderExtension.resourceRegistrationCount, 1)
    }

    func testViewportTextureRemainsDeclaredUntilViewportIsValid() {
        let textureID: RenderTextureResourceID = "test.lifecycle.deferred-viewport.texture"
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.lifecycle.deferred-viewport",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .viewportScale(0.5),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ]
        )
        let viewport = renderInfo.viewPort
        renderInfo.viewPort = .zero
        defer { renderInfo.viewPort = viewport }

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .declared)

        renderInfo.viewPort = viewport
        RenderResourceRegistry.shared.recreateResources()

        XCTAssertNotNil(getRenderResource(textureID))
        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .allocated)
    }

    func testViewportResizeReallocatesOnlyAffectedExtensionResources() {
        let fixedTextureID: RenderTextureResourceID = "test.lifecycle.fixed.texture"
        let viewportTextureID: RenderTextureResourceID = "test.lifecycle.viewport.texture"
        let bufferID: RenderBufferResourceID = "test.lifecycle.buffer"
        let allocator = TestRenderExtensionResourceAllocator()
        let previousAllocator = RenderResourceRegistry.shared.replaceAllocatorForTesting(allocator)
        defer {
            _ = RenderResourceRegistry.shared.replaceAllocatorForTesting(previousAllocator)
        }
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.lifecycle.selective-resize",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: fixedTextureID,
                    size: .fixed(width: 32, height: 16),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
                RenderExtensionTextureDescriptor(
                    id: viewportTextureID,
                    size: .viewportScale(0.5),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 64),
            ]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        let fixedTexture = getRenderResource(fixedTextureID)
        let viewportTexture = getRenderResource(viewportTextureID)
        let buffer = getRenderResource(bufferID)

        renderInfo.viewPort = simd_float2(640, 360)
        RenderResourceRegistry.shared.recreateResources()

        XCTAssertTrue(getRenderResource(fixedTextureID) === fixedTexture)
        XCTAssertFalse(getRenderResource(viewportTextureID) === viewportTexture)
        XCTAssertTrue(getRenderResource(bufferID) === buffer)
        XCTAssertEqual(getRenderResource(viewportTextureID)?.width, 320)
        XCTAssertEqual(getRenderResource(viewportTextureID)?.height, 180)
        XCTAssertEqual(allocator.textureAllocationCounts[fixedTextureID], 1)
        XCTAssertEqual(allocator.textureAllocationCounts[viewportTextureID], 2)
        XCTAssertEqual(allocator.bufferAllocationCounts[bufferID], 1)
    }

    func testAllocationFailuresAreStructuredAndRetryable() {
        let textureID: RenderTextureResourceID = "test.lifecycle.failed.texture"
        let bufferID: RenderBufferResourceID = "test.lifecycle.failed.buffer"
        let ownerID = "test.lifecycle.failed"
        let allocator = TestRenderExtensionResourceAllocator()
        allocator.failingTextureIDs = [textureID]
        allocator.failingBufferIDs = [bufferID]
        let previousAllocator = RenderResourceRegistry.shared.replaceAllocatorForTesting(allocator)
        defer {
            _ = RenderResourceRegistry.shared.replaceAllocatorForTesting(previousAllocator)
        }
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: ownerID,
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 16, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 128),
            ]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertNil(getRenderResource(bufferID))
        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .invalidated)
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .invalidated)
        XCTAssertEqual(
            RenderExtensionRegistry.shared.resourceAllocationErrors(forExtensionID: ownerID),
            [
                RenderExtensionResourceAllocationError(
                    kind: .buffer,
                    resourceID: bufferID.rawValue,
                    ownerID: ownerID,
                    failure: .bufferCreationFailed(length: 128)
                ),
                RenderExtensionResourceAllocationError(
                    kind: .texture,
                    resourceID: textureID.rawValue,
                    ownerID: ownerID,
                    failure: .textureCreationFailed(width: 16, height: 8)
                ),
            ]
        )

        allocator.failingTextureIDs = []
        allocator.failingBufferIDs = []
        RenderResourceRegistry.shared.recreateResources()

        XCTAssertNotNil(getRenderResource(textureID))
        XCTAssertNotNil(getRenderResource(bufferID))
        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .allocated)
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .allocated)
        XCTAssertTrue(
            RenderExtensionRegistry.shared.resourceAllocationErrors(forExtensionID: ownerID).isEmpty
        )
        XCTAssertEqual(allocator.textureAllocationCounts[textureID], 2)
        XCTAssertEqual(allocator.bufferAllocationCounts[bufferID], 2)
    }

    func testRemovingAllExtensionsReleasesResourceLifecycleState() {
        let textureID: RenderTextureResourceID = "test.lifecycle.remove-all.texture"
        let bufferID: RenderBufferResourceID = "test.lifecycle.remove-all.buffer"
        let renderExtension = TestTransactionalResourceRenderExtension(
            id: "test.lifecycle.remove-all",
            textureDescriptors: [
                RenderExtensionTextureDescriptor(
                    id: textureID,
                    size: .fixed(width: 8, height: 8),
                    pixelFormat: .rgba16Float,
                    usage: .shaderRead
                ),
            ],
            bufferDescriptors: [
                RenderExtensionBufferDescriptor(id: bufferID, length: 32),
            ]
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(renderExtension), .registered)
        RenderExtensionRegistry.shared.removeAll()

        XCTAssertEqual(RenderResourceRegistry.shared.textureState(textureID), .released)
        XCTAssertEqual(RenderResourceRegistry.shared.bufferState(bufferID), .released)
        XCTAssertNil(getRenderResource(textureID))
        XCTAssertNil(getRenderResource(bufferID))
    }

    func testRenderExtensionRegistersComputePipeline() {
        let computeType: ComputePipelineType = "test.compute.pipeline"

        setRendering(.extensions(.register(
            TestComputeRenderExtension(computeType: computeType)
        )))

        let pipeline = ComputePipelineManager.shared.pipeline(for: computeType)
        XCTAssertNotNil(pipeline)
        XCTAssertTrue(pipeline?.success == true)
        XCTAssertEqual(pipeline?.name, "Test Compute Pipeline")
    }

    func testRenderPassContextExposesExtensionComputePipelines() throws {
        let computeType: ComputePipelineType = "test.context.compute.pipeline"
        let extensionInstance = TestComputeRenderExtension(
            computeType: computeType,
            passID: "test.context.compute.pass"
        )

        setRendering(.extensions(.register(extensionInstance)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph["test.context.compute.pass"]?.execute?(commandBuffer)

        XCTAssertEqual(extensionInstance.observedPipelineName, "Test Compute Pipeline")
    }

    func testRenderPassContextExposesExtensionRenderPipelines() throws {
        let extensionInstance = TestRenderPipelineContextExtension()
        setRendering(.extensions(.register(extensionInstance)))

        let (graph, _) = try buildGameModeGraph()
        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        graph[extensionInstance.passID]?.execute?(commandBuffer)

        XCTAssertEqual(extensionInstance.observedPipelineName, "Context Render Pipeline")
        XCTAssertTrue(extensionInstance.observedMissingPipeline)
    }

    func testRenderExtensionUnregisterRemovesPipelineFromRenderPipelineAccess() {
        let extensionInstance = TestRenderPipelineContextExtension()
        setRendering(.extensions(.register(extensionInstance)))
        let access = RenderPipelineAccess()

        XCTAssertNotNil(access.pipeline(extensionInstance.pipelineType))

        setRendering(.extensions(.unregister(extensionInstance.id)))

        XCTAssertNil(access.pipeline(extensionInstance.pipelineType))
    }

    func testRenderExtensionUnregisterRemovesOwnedComputePipelines() {
        let computeType: ComputePipelineType = "test.unregister.compute.pipeline"
        let extensionInstance = TestComputeRenderExtension(computeType: computeType)

        setRendering(.extensions(.register(extensionInstance)))
        XCTAssertNotNil(ComputePipelineManager.shared.pipeline(for: computeType))

        setRendering(.extensions(.unregister(extensionInstance.id)))
        XCTAssertNil(ComputePipelineManager.shared.pipeline(for: computeType),
                     "Unregistering an extension should remove its owned compute pipelines")
    }

    func testRenderExtensionRegistersShaderLibrary() {
        let libraryID: RenderShaderLibraryID = "test.shader.library"
        let extensionInstance = TestShaderLibraryRenderExtension(
            libraryID: libraryID,
            library: renderInfo.library
        )

        setRendering(.extensions(.register(extensionInstance)))

        XCTAssertNotNil(RenderShaderLibraryManager.shared.library(libraryID),
                        "Render extension should register its shader library after renderer initialization")
    }

    func testRenderExtensionUnregisterRemovesOwnedShaderLibraries() {
        let libraryID: RenderShaderLibraryID = "test.unregister.shader.library"
        let extensionInstance = TestShaderLibraryRenderExtension(
            libraryID: libraryID,
            library: renderInfo.library
        )

        setRendering(.extensions(.register(extensionInstance)))
        XCTAssertNotNil(RenderShaderLibraryManager.shared.library(libraryID))

        setRendering(.extensions(.unregister(extensionInstance.id)))
        XCTAssertNil(RenderShaderLibraryManager.shared.library(libraryID),
                     "Unregistering an extension should remove its owned shader libraries")
    }

    func testReplacingRenderExtensionRemovesStaleOwnedArtifactsAndPreservesOrder() throws {
        let original = TestLifecycleRenderExtension(
            artifactSuffix: "original",
            shaderLibrary: renderInfo.library
        )
        let replacement = TestLifecycleRenderExtension(
            artifactSuffix: "replacement",
            shaderLibrary: renderInfo.library
        )
        let trailing = TestStageRenderExtension(
            passID: "test.lifecycle.trailing.pass",
            stage: .afterTransparency
        )

        setRendering(.extensions(.register(original)))
        setRendering(.extensions(.register(trailing)))
        assertLifecycleArtifactsPresent(original)

        setRendering(.extensions(.register(replacement)))

        XCTAssertEqual(
            RenderExtensionRegistry.shared.registeredIDs(),
            [replacement.id, trailing.id]
        )
        assertLifecycleArtifactsAbsent(original)
        assertLifecycleArtifactsPresent(replacement)

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNil(graph[original.passID])
        XCTAssertEqual(graph[replacement.passID]?.dependencies, ["transparency"])
        XCTAssertEqual(graph[trailing.passID]?.dependencies, [replacement.passID])
    }

    func testUnregisterRenderExtensionRemovesEveryOwnedArtifact() {
        let renderExtension = TestLifecycleRenderExtension(
            artifactSuffix: "unregister",
            shaderLibrary: renderInfo.library
        )

        setRendering(.extensions(.register(renderExtension)))
        assertLifecycleArtifactsPresent(renderExtension)

        setRendering(.extensions(.unregister(renderExtension.id)))

        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        assertLifecycleArtifactsAbsent(renderExtension)
    }

    func testUnregisterUnknownExtensionLeavesRegisteredArtifactsUntouched() {
        let renderExtension = TestLifecycleRenderExtension(
            artifactSuffix: "unknown.unregister",
            shaderLibrary: renderInfo.library
        )
        setRendering(.extensions(.register(renderExtension)))

        setRendering(.extensions(.unregister("test.lifecycle.unknown")))

        XCTAssertTrue(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        assertLifecycleArtifactsPresent(renderExtension)
    }

    func testArtifactCollisionsRejectSecondProviderWithoutOverwritingFirst() {
        let first = TestLifecycleRenderExtension(
            id: "test.collision.first",
            artifactSuffix: "shared",
            shaderLibrary: renderInfo.library
        )
        let second = TestLifecycleRenderExtension(
            id: "test.collision.second",
            artifactSuffix: "shared",
            shaderLibrary: renderInfo.library
        )

        XCTAssertEqual(RenderExtensionRegistry.shared.register(first), .registered)
        let result = RenderExtensionRegistry.shared.register(second)

        guard case let .rejected(conflicts) = result else {
            XCTFail("Expected the second provider to be rejected")
            return
        }
        XCTAssertEqual(
            Set(conflicts.map(\.kind)),
            Set([
                .shaderLibrary,
                .renderPipeline,
                .computePipeline,
                .texture,
                .buffer,
                .argumentBuffer,
            ])
        )
        XCTAssertTrue(conflicts.allSatisfy { $0.requestedOwnerID == second.id })
        XCTAssertTrue(conflicts.allSatisfy { $0.existingOwnerID == first.id })
        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id])
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: second.id),
            conflicts
        )
        assertLifecycleArtifactsPresent(first)
    }

    func testExtensionCannotOverwriteBuiltInRenderPipeline() {
        let builtInPipeline = PipelineManager.shared.renderPipelinesByType[.model]
        let renderExtension = TestLifecycleRenderExtension(
            id: "test.collision.builtin",
            artifactSuffix: "builtin",
            renderPipelineType: .model,
            shaderLibrary: renderInfo.library
        )

        let result = RenderExtensionRegistry.shared.register(renderExtension)

        XCTAssertEqual(
            result,
            .rejected([
                RenderExtensionArtifactConflict(
                    kind: .renderPipeline,
                    artifactID: RenderPipelineType.model.rawValue,
                    requestedOwnerID: renderExtension.id,
                    existingOwnerID: nil
                ),
            ])
        )
        XCTAssertFalse(RenderExtensionRegistry.shared.registeredIDs().contains(renderExtension.id))
        XCTAssertEqual(
            PipelineManager.shared.renderPipelinesByType[.model]?.name,
            builtInPipeline?.name
        )
        XCTAssertNil(getRenderResource(.texture(renderExtension.textureID)))
        XCTAssertNil(getRenderResource(renderExtension.bufferID))
        XCTAssertNil(RenderShaderLibraryManager.shared.library(renderExtension.shaderLibraryID))
        XCTAssertNil(ComputePipelineManager.shared.pipeline(for: renderExtension.computePipelineType))
        XCTAssertNil(
            RenderExtensionArgumentBufferRegistry.shared.descriptor(renderExtension.argumentLayoutID)
        )
    }

    func testRejectedReplacementRestoresPreviousExtension() throws {
        let original = TestLifecycleRenderExtension(
            id: "test.collision.replacement",
            artifactSuffix: "replacement.original",
            shaderLibrary: renderInfo.library
        )
        let blocker = TestLifecycleRenderExtension(
            id: "test.collision.blocker",
            artifactSuffix: "replacement.blocked",
            shaderLibrary: renderInfo.library
        )
        let rejectedReplacement = TestLifecycleRenderExtension(
            id: original.id,
            artifactSuffix: "replacement.blocked",
            shaderLibrary: renderInfo.library
        )
        XCTAssertEqual(RenderExtensionRegistry.shared.register(original), .registered)
        XCTAssertEqual(RenderExtensionRegistry.shared.register(blocker), .registered)

        let result = RenderExtensionRegistry.shared.register(rejectedReplacement)

        guard case .rejected = result else {
            XCTFail("Expected replacement registration to be rejected")
            return
        }
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registeredIDs(),
            [original.id, blocker.id]
        )
        assertLifecycleArtifactsPresent(original)
        assertLifecycleArtifactsPresent(blocker)

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNotNil(graph[original.passID])
        XCTAssertNotNil(graph[blocker.passID])
    }

    func testDeferredPipelineCollisionRemovesRejectedExtensionBeforeGraphBuild() throws {
        let pipelineType: RenderPipelineType = "test.collision.deferred.pipeline"
        let first = TestRenderPipelineOnlyExtension(
            id: "test.collision.deferred.first",
            pipelineType: pipelineType,
            passID: "test.collision.deferred.first.pass"
        )
        let second = TestRenderPipelineOnlyExtension(
            id: "test.collision.deferred.second",
            pipelineType: pipelineType,
            passID: "test.collision.deferred.second.pass"
        )
        let device = renderInfo.device
        let library = renderInfo.library

        renderInfo.device = nil
        renderInfo.library = nil
        XCTAssertEqual(RenderExtensionRegistry.shared.register(first), .registered)
        XCTAssertEqual(RenderExtensionRegistry.shared.register(second), .registered)
        renderInfo.device = device
        renderInfo.library = library

        RenderExtensionRegistry.shared.registerPipelines()

        XCTAssertEqual(RenderExtensionRegistry.shared.registeredIDs(), [first.id])
        XCTAssertEqual(
            PipelineManager.shared.renderPipelinesByType[pipelineType]?.name,
            first.id
        )
        XCTAssertEqual(
            RenderExtensionRegistry.shared.registrationConflicts(forExtensionID: second.id),
            [
                RenderExtensionArtifactConflict(
                    kind: .renderPipeline,
                    artifactID: pipelineType.rawValue,
                    requestedOwnerID: second.id,
                    existingOwnerID: first.id
                ),
            ]
        )

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNotNil(graph[first.passID])
        XCTAssertNil(graph[second.passID])
    }

    func testUnownedRenderPipelineUpdateSurvivesExtensionUnregister() {
        let renderExtension = TestLifecycleRenderExtension(
            artifactSuffix: "pipeline.override",
            shaderLibrary: renderInfo.library
        )
        setRendering(.extensions(.register(renderExtension)))

        PipelineManager.shared.update(
            rendererPipeLine: RenderPipeline(success: true, name: "Engine Replacement"),
            forType: renderExtension.renderPipelineType
        )
        setRendering(.extensions(.unregister(renderExtension.id)))

        XCTAssertEqual(
            PipelineManager.shared.renderPipelinesByType[renderExtension.renderPipelineType]?.name,
            "Engine Replacement"
        )
    }

    func testRemovingAllExtensionsPreservesBuiltInRenderPipelines() {
        let builtInModelPipeline = PipelineManager.shared.renderPipelinesByType[.model]
        XCTAssertNotNil(builtInModelPipeline)

        setRendering(.extensions(.register(
            TestLifecycleRenderExtension(
                artifactSuffix: "remove.all",
                shaderLibrary: renderInfo.library
            )
        )))
        setRendering(.extensions(.removeAll))

        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[.model])
    }

    func testNestedRenderPipelineRegistrationRestoresOuterOwnerScope() {
        let outerOwnerID = "test.lifecycle.outer.owner"
        let innerOwnerID = "test.lifecycle.inner.owner"
        let outerFirstType: RenderPipelineType = "test.lifecycle.outer.first"
        let outerSecondType: RenderPipelineType = "test.lifecycle.outer.second"
        let innerType: RenderPipelineType = "test.lifecycle.inner"

        PipelineManager.shared.registerPipelines(ownerID: outerOwnerID) { outerRegistry in
            outerRegistry.registerRenderPipeline(outerFirstType) {
                RenderPipeline(success: true, name: "Outer First")
            }
            PipelineManager.shared.registerPipelines(ownerID: innerOwnerID) { innerRegistry in
                innerRegistry.registerRenderPipeline(innerType) {
                    RenderPipeline(success: true, name: "Inner")
                }
            }
            outerRegistry.registerRenderPipeline(outerSecondType) {
                RenderPipeline(success: true, name: "Outer Second")
            }
        }

        PipelineManager.shared.removePipelines(ownerID: outerOwnerID)

        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[outerFirstType])
        XCTAssertNil(PipelineManager.shared.renderPipelinesByType[outerSecondType])
        XCTAssertNotNil(PipelineManager.shared.renderPipelinesByType[innerType])

        PipelineManager.shared.removePipelines(ownerID: innerOwnerID)
    }

    func testRenderExtensionRenderPipelineUsesRegisteredShaderLibrary() {
        let pipelineType: RenderPipelineType = "test.registered.shader.render.pipeline"
        let extensionInstance = TestRegisteredShaderPipelineRenderExtension(
            libraryID: "test.registered.render.shader.library",
            renderPipelineType: pipelineType,
            computePipelineType: "test.unused.compute.pipeline",
            library: renderInfo.library
        )

        setRendering(.extensions(.register(extensionInstance)))

        let pipeline = PipelineManager.shared.renderPipelinesByType[pipelineType]
        XCTAssertNotNil(pipeline)
        XCTAssertTrue(pipeline?.success == true)
        XCTAssertEqual(pipeline?.name, "Test Registered Shader Render Pipeline")
    }

    func testRenderExtensionComputePipelineUsesRegisteredShaderLibrary() {
        let computeType: ComputePipelineType = "test.registered.shader.compute.pipeline"
        let extensionInstance = TestRegisteredShaderPipelineRenderExtension(
            libraryID: "test.registered.compute.shader.library",
            renderPipelineType: "test.unused.render.pipeline",
            computePipelineType: computeType,
            library: renderInfo.library
        )

        setRendering(.extensions(.register(extensionInstance)))

        let pipeline = ComputePipelineManager.shared.pipeline(for: computeType)
        XCTAssertNotNil(pipeline)
        XCTAssertTrue(pipeline?.success == true)
        XCTAssertEqual(pipeline?.name, "Test Registered Shader Compute Pipeline")
    }

    private func assertLifecycleArtifactsPresent(
        _ renderExtension: TestLifecycleRenderExtension,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNotNil(
            getRenderResource(.texture(renderExtension.textureID)),
            file: file,
            line: line
        )
        XCTAssertNotNil(
            getRenderResource(renderExtension.bufferID),
            file: file,
            line: line
        )
        XCTAssertNotNil(
            RenderShaderLibraryManager.shared.library(renderExtension.shaderLibraryID),
            file: file,
            line: line
        )
        XCTAssertNotNil(
            PipelineManager.shared.renderPipelinesByType[renderExtension.renderPipelineType],
            file: file,
            line: line
        )
        XCTAssertNotNil(
            ComputePipelineManager.shared.pipeline(for: renderExtension.computePipelineType),
            file: file,
            line: line
        )
        XCTAssertNotNil(
            RenderExtensionArgumentBufferRegistry.shared.descriptor(renderExtension.argumentLayoutID),
            file: file,
            line: line
        )
    }

    private func assertLifecycleArtifactsAbsent(
        _ renderExtension: TestLifecycleRenderExtension,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertNil(
            getRenderResource(.texture(renderExtension.textureID)),
            file: file,
            line: line
        )
        XCTAssertNil(
            getRenderResource(renderExtension.bufferID),
            file: file,
            line: line
        )
        XCTAssertNil(
            RenderShaderLibraryManager.shared.library(renderExtension.shaderLibraryID),
            file: file,
            line: line
        )
        XCTAssertNil(
            PipelineManager.shared.renderPipelinesByType[renderExtension.renderPipelineType],
            file: file,
            line: line
        )
        XCTAssertNil(
            ComputePipelineManager.shared.pipeline(for: renderExtension.computePipelineType),
            file: file,
            line: line
        )
        XCTAssertNil(
            RenderExtensionArgumentBufferRegistry.shared.descriptor(renderExtension.argumentLayoutID),
            file: file,
            line: line
        )
    }

    func testRenderPassContextDrawsModelSurfaceEntities() throws {
        let entity = createEntity()
        setEntityMeshDirect(
            entityId: entity,
            meshes: BasicPrimitives.createCube(extent: 1.0),
            assetName: "test_model_surface_cube"
        )
        visibleEntityIds = [entity]

        let extensionInstance = TestModelSurfaceDrawRenderExtension(
            pipelineType: "test.model.surface.pipeline"
        )
        setRendering(.extensions(.register(extensionInstance)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[extensionInstance.passID]?.execute?(commandBuffer)

        XCTAssertEqual(extensionInstance.boundEntityIDs, [entity])
    }

    func testRenderPassContextDrawsModelSurfaceEntitiesWithArgumentBufferBinding() throws {
        let entity = createEntity()
        setEntityMeshDirect(
            entityId: entity,
            meshes: BasicPrimitives.createCube(extent: 1.0),
            assetName: "test_model_surface_argument_cube"
        )
        visibleEntityIds = [entity]

        let extensionInstance = TestModelSurfaceArgumentDrawRenderExtension(
            pipelineType: "test.model.surface.argument.pipeline"
        )
        setRendering(.extensions(.register(extensionInstance)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[extensionInstance.passID]?.execute?(commandBuffer)

        XCTAssertEqual(extensionInstance.boundEntityIDs, [entity])
        XCTAssertEqual(extensionInstance.encodedValues, [1.0])
    }

    func testRenderPassContextMakesArgumentBufferResourcesResident() throws {
        let shaderSource = """
        #include <metal_stdlib>
        using namespace metal;

        struct TestArguments {
            texture2d<float> texture0 [[id(0)]];
            texture2d<float> texture1 [[id(1)]];
            texture2d<float> texture2 [[id(2)]];
            texture2d<float> texture3 [[id(3)]];
            texture2d<float> texture4 [[id(4)]];
            texture2d<float> texture5 [[id(5)]];
            texture2d<float> texture6 [[id(6)]];
            texture2d<float> texture7 [[id(7)]];
            sampler sampler0 [[id(8)]];
            sampler sampler1 [[id(9)]];
            sampler sampler2 [[id(10)]];
            sampler sampler3 [[id(11)]];
            sampler sampler4 [[id(12)]];
            sampler sampler5 [[id(13)]];
            sampler sampler6 [[id(14)]];
            sampler sampler7 [[id(15)]];
            constant uchar *buffer0 [[id(16)]];
            constant uchar *buffer1 [[id(17)]];
            constant uchar *buffer2 [[id(18)]];
            constant uchar *buffer3 [[id(19)]];
            constant uchar *buffer4 [[id(20)]];
            constant uchar *buffer5 [[id(21)]];
            constant uchar *buffer6 [[id(22)]];
            constant uchar *buffer7 [[id(23)]];
            constant uchar *buffer8 [[id(24)]];
            constant uchar *buffer9 [[id(25)]];
            constant uchar *buffer10 [[id(26)]];
            constant uchar *buffer11 [[id(27)]];
            constant uchar *buffer12 [[id(28)]];
            constant uchar *buffer13 [[id(29)]];
            constant uchar *buffer14 [[id(30)]];
            constant uchar *buffer15 [[id(31)]];
        };

        fragment float4 testArgumentBufferFragment(
            constant TestArguments &arguments [[buffer(10)]])
        {
            return *reinterpret_cast<constant float4 *>(arguments.buffer0);
        }
        """
        let fragmentLibrary = try renderInfo.device.makeLibrary(source: shaderSource, options: nil)
        let entity = createEntity()
        setEntityMeshDirect(
            entityId: entity,
            meshes: BasicPrimitives.createPlane(),
            assetName: "test_argument_buffer_residency_plane"
        )
        visibleEntityIds = [entity]

        let extensionInstance = TestModelSurfaceArgumentDrawRenderExtension(
            pipelineType: "test.argument.buffer.residency.pipeline",
            argumentLayoutID: "test.argument.buffer.residency.layout",
            fragmentShader: "testArgumentBufferFragment",
            fragmentLibraryID: "test.argument.buffer.residency.shaders",
            fragmentLibrary: fragmentLibrary
        )
        setRendering(.extensions(.register(extensionInstance)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[extensionInstance.passID]?.execute?(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        XCTAssertEqual(commandBuffer.status, .completed)
        XCTAssertNil(commandBuffer.error)
    }

    func testRenderExtensionsOwnIndependentArgumentLayoutsWithSharedLocalIDs() throws {
        let entity = createEntity()
        setEntityMeshDirect(
            entityId: entity,
            meshes: BasicPrimitives.createCube(extent: 1.0),
            assetName: "test_model_surface_argument_layout_cube"
        )
        visibleEntityIds = [entity]

        let waterLayoutID = "test.water.argument.layout"
        let grassLayoutID = "test.grass.argument.layout"
        let waterExtension = TestModelSurfaceArgumentDrawRenderExtension(
            id: "test.water.argument.extension",
            pipelineType: "test.water.argument.pipeline",
            passID: "test.water.argument.pass",
            argumentLayoutID: waterLayoutID
        )
        let grassExtension = TestModelSurfaceArgumentDrawRenderExtension(
            id: "test.grass.argument.extension",
            pipelineType: "test.grass.argument.pipeline",
            passID: "test.grass.argument.pass",
            argumentLayoutID: grassLayoutID
        )

        setRendering(.extensions(.register(waterExtension)))
        setRendering(.extensions(.register(grassExtension)))
        antiAliasingMode = .none
        defer { antiAliasingMode = .fxaa }

        XCTAssertNotNil(RenderExtensionArgumentBufferRegistry.shared.descriptor(waterLayoutID))
        XCTAssertNotNil(RenderExtensionArgumentBufferRegistry.shared.descriptor(grassLayoutID))
        XCTAssertEqual(
            RenderExtensionArgumentBufferRegistry.shared.descriptor(waterLayoutID)?.buffers.first?.id,
            RenderExtensionModelSurfaceArgument.buffer0
        )
        XCTAssertEqual(
            RenderExtensionArgumentBufferRegistry.shared.descriptor(grassLayoutID)?.buffers.first?.id,
            RenderExtensionModelSurfaceArgument.buffer0
        )

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[waterExtension.passID]?.execute?(commandBuffer)
        graph[grassExtension.passID]?.execute?(commandBuffer)

        XCTAssertEqual(waterExtension.boundEntityIDs, [entity])
        XCTAssertEqual(grassExtension.boundEntityIDs, [entity])
        XCTAssertEqual(waterExtension.encodedValues, [1.0])
        XCTAssertEqual(grassExtension.encodedValues, [1.0])

        setRendering(.extensions(.unregister(waterExtension.id)))

        XCTAssertNil(RenderExtensionArgumentBufferRegistry.shared.descriptor(waterLayoutID))
        XCTAssertNotNil(RenderExtensionArgumentBufferRegistry.shared.descriptor(grassLayoutID))
    }

    func testModelSurfaceExtensionPipelineValidationAcceptsArgumentBufferSlot() {
        let isValid = validateModelSurfaceExtensionPipelineArguments(
            [
                RenderExtensionShaderArgument(
                    name: "arguments",
                    index: RenderExtensionModelSurfaceArgument.argumentBufferIndex,
                    type: .buffer
                ),
            ],
            argumentLayoutID: nil,
            pipelineName: "Test Valid Model Surface Pipeline",
            fragmentShader: "validFragment"
        )

        XCTAssertTrue(isValid)
    }

    func testModelSurfaceExtensionPipelineValidationRejectsMissingArgumentBuffer() {
        let isValid = validateModelSurfaceExtensionPipelineArguments(
            [],
            argumentLayoutID: nil,
            pipelineName: "Test Missing Argument Buffer Pipeline",
            fragmentShader: "missingArgumentFragment"
        )

        XCTAssertFalse(isValid)
    }

    func testModelSurfaceExtensionPipelineValidationRejectsLegacyRawSlots() {
        let isValid = validateModelSurfaceExtensionPipelineArguments(
            [
                RenderExtensionShaderArgument(
                    name: "arguments",
                    index: RenderExtensionModelSurfaceArgument.argumentBufferIndex,
                    type: .buffer
                ),
                RenderExtensionShaderArgument(
                    name: "legacyTexture",
                    index: 10,
                    type: .texture
                ),
                RenderExtensionShaderArgument(
                    name: "legacyBuffer",
                    index: 11,
                    type: .buffer
                ),
            ],
            argumentLayoutID: nil,
            pipelineName: "Test Legacy Raw Slot Pipeline",
            fragmentShader: "legacyRawSlotFragment"
        )

        XCTAssertFalse(isValid)
    }

    func testModelSurfaceExtensionPipelineValidationRejectsMissingLayout() {
        let missingLayoutID = "test.missing.argument.layout"
        RenderExtensionArgumentBufferRegistry.shared.removeAll()

        let isValid = validateModelSurfaceExtensionPipelineArguments(
            [
                RenderExtensionShaderArgument(
                    name: "arguments",
                    index: RenderExtensionModelSurfaceArgument.argumentBufferIndex,
                    type: .buffer
                ),
            ],
            argumentLayoutID: missingLayoutID,
            pipelineName: "Test Missing Layout Pipeline",
            fragmentShader: "missingLayoutFragment"
        )

        XCTAssertFalse(isValid)
    }

    func testSampleRenderExtensionRegistersScratchTextureAndGraphPass() throws {
        let sample = SampleRenderExtension()

        setRendering(.extensions(.register(sample)))

        let texture = getRenderResource(.texture(sample.scratchTextureID))
        XCTAssertNotNil(texture)
        XCTAssertEqual(texture?.width, windowWidth)
        XCTAssertEqual(texture?.height, windowHeight)

        let (graph, _) = try buildGameModeGraph()
        XCTAssertNotNil(graph[sample.passID])
        XCTAssertEqual(graph["outputTransform"]?.dependencies, [sample.passID])

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("look", sample.passID),
            (sample.passID, "outputTransform"),
        ])
    }

    func testSampleRenderExtensionPassExecutes() throws {
        let sample = SampleRenderExtension()
        setRendering(.extensions(.register(sample)))

        let (graph, _) = try buildGameModeGraph()
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Expected command buffer")
            return
        }

        graph[sample.passID]?.execute?(commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        XCTAssertEqual(commandBuffer.status, .completed)
    }

    // MARK: - Helper Methods

    func assertTopologicalConstraints(
        order: [String],
        constraints: [(before: String, after: String)],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for (before, after) in constraints {
            guard let beforeIndex = order.firstIndex(of: before),
                  let afterIndex = order.firstIndex(of: after)
            else {
                XCTFail("Missing node(s): \(before) or \(after)", file: file, line: line)
                continue
            }

            XCTAssertTrue(beforeIndex < afterIndex,
                          "\(before) should come before \(after)",
                          file: file, line: line)
        }
    }
}
