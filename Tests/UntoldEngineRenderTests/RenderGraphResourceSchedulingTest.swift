//
//  RenderGraphResourceSchedulingTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class RenderGraphResourceSchedulingTest: BaseRenderSetup {
    func testCompilationInfersWriterBeforeLeadingReader() throws {
        let bufferID = declareBuffer("test.schedule.raw")
        let reader = RenderPass(
            id: "a-reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .read)]
        )
        let writer = RenderPass(
            id: "z-writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )

        let analysis = analyzeRenderGraph([reader.id: reader, writer.id: writer])
        let compiled = try XCTUnwrap(analysis.compiledGraph)

        XCTAssertTrue(analysis.validationReport.isValid)
        XCTAssertEqual(compiled.executionOrder, [writer.id, reader.id])
        XCTAssertEqual(compiled.passesByID[reader.id]?.dependencies, [writer.id])
        XCTAssertEqual(compiled.passesByID[reader.id]?.inferredDependencies, [writer.id])
        XCTAssertTrue(compiled.passesByID[writer.id]?.inferredDependencies.isEmpty == true)
    }

    func testCompilationInfersRAWAndWARDependenciesAcrossWrites() throws {
        let bufferID = declareBuffer("test.schedule.raw-war")
        let firstWriter = RenderPass(
            id: "a-writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )
        let reader = RenderPass(
            id: "b-reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .read)]
        )
        let secondWriter = RenderPass(
            id: "c-writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )

        let compiled = try compileRenderGraph([
            firstWriter.id: firstWriter,
            reader.id: reader,
            secondWriter.id: secondWriter,
        ])

        XCTAssertEqual(compiled.executionOrder, [firstWriter.id, reader.id, secondWriter.id])
        XCTAssertEqual(compiled.passesByID[reader.id]?.inferredDependencies, [firstWriter.id])
        XCTAssertEqual(
            compiled.passesByID[secondWriter.id]?.inferredDependencies,
            [firstWriter.id, reader.id]
        )
    }

    func testCompilationInfersWAWDependencyBetweenUnorderedWriters() throws {
        let bufferID = declareBuffer("test.schedule.waw")
        let first = RenderPass(
            id: "first",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )
        let second = RenderPass(
            id: "second",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )

        let compiled = try compileRenderGraph([second.id: second, first.id: first])

        XCTAssertEqual(compiled.executionOrder, [first.id, second.id])
        XCTAssertEqual(compiled.passesByID[second.id]?.inferredDependencies, [first.id])
    }

    func testRenderTargetAccessSchedulesBeforeShaderReader() throws {
        let textureID: RenderTextureResourceID = "test.schedule.render-target"
        RenderResourceRegistry.shared.registerTexture(
            RenderExtensionTextureDescriptor(
                id: textureID,
                size: .fixed(width: 4, height: 4),
                pixelFormat: .rgba8Unorm,
                usage: [.renderTarget, .shaderRead]
            )
        )
        let reader = RenderPass(
            id: "reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .read)]
        )
        let renderTarget = RenderPass(
            id: "render-target",
            dependencies: [],
            execute: nil,
            resourceUsages: [.texture(textureID, access: .renderTarget)]
        )

        let compiled = try compileRenderGraph([
            reader.id: reader,
            renderTarget.id: renderTarget,
        ])

        XCTAssertEqual(compiled.executionOrder, [renderTarget.id, reader.id])
        XCTAssertEqual(
            compiled.passesByID[reader.id]?.inferredDependencies,
            [renderTarget.id]
        )
    }

    func testCompilationSchedulesIndependentHazardsForMultipleExtensions() throws {
        let grass = SchedulingResourceRenderExtension(id: "com.example.grass")
        let water = SchedulingResourceRenderExtension(id: "com.example.water")
        setRendering(.extensions(.register(grass)))
        setRendering(.extensions(.register(water)))

        let grassReader = RenderPass(
            id: "a-grass-reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(grass.bufferID, access: .read)],
            owner: .renderExtension(grass.id)
        )
        let grassWriter = RenderPass(
            id: "b-grass-writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(grass.bufferID, access: .write)],
            owner: .renderExtension(grass.id)
        )
        let waterReader = RenderPass(
            id: "c-water-reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(water.bufferID, access: .read)],
            owner: .renderExtension(water.id)
        )
        let waterWriter = RenderPass(
            id: "d-water-writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(water.bufferID, access: .write)],
            owner: .renderExtension(water.id)
        )

        let compiled = try compileRenderGraph([
            grassReader.id: grassReader,
            grassWriter.id: grassWriter,
            waterReader.id: waterReader,
            waterWriter.id: waterWriter,
        ])

        XCTAssertEqual(
            compiled.passesByID[grassReader.id]?.inferredDependencies,
            [grassWriter.id]
        )
        XCTAssertEqual(
            compiled.passesByID[waterReader.id]?.inferredDependencies,
            [waterWriter.id]
        )
        XCTAssertEqual(compiled.passesByID[grassReader.id]?.owner, .renderExtension(grass.id))
        XCTAssertEqual(compiled.passesByID[waterWriter.id]?.owner, .renderExtension(water.id))
    }

    func testExplicitResourceOrderingIsPreservedWithoutDuplicateInference() throws {
        let bufferID = declareBuffer("test.schedule.explicit")
        let writer = RenderPass(
            id: "writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )
        let reader = RenderPass(
            id: "reader",
            dependencies: [writer.id],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .read)]
        )

        let compiled = try compileRenderGraph([reader.id: reader, writer.id: writer])

        XCTAssertEqual(compiled.passesByID[reader.id]?.dependencies, [writer.id])
        XCTAssertTrue(compiled.passesByID[reader.id]?.inferredDependencies.isEmpty == true)
    }

    func testContradictoryExplicitOrderingIsNotReversed() {
        let bufferID = declareBuffer("test.schedule.conflict")
        let reader = RenderPass(
            id: "reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .read)]
        )
        let writer = RenderPass(
            id: "writer",
            dependencies: [reader.id],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )

        let analysis = analyzeRenderGraph([reader.id: reader, writer.id: writer])

        XCTAssertNil(analysis.compiledGraph)
        XCTAssertEqual(analysis.scheduledGraph[writer.id]?.dependencies, [reader.id])
        XCTAssertTrue(analysis.scheduledGraph[reader.id]?.inferredDependencies.isEmpty == true)
        XCTAssertEqual(
            analysis.validationReport.errors,
            [
                .readBeforeWrite(
                    passID: reader.id,
                    kind: .buffer,
                    resourceID: bufferID.rawValue
                ),
            ]
        )
    }

    func testSchedulingIsIndependentOfDictionaryInsertionOrder() throws {
        let bufferID = declareBuffer("test.schedule.deterministic")
        let reader = RenderPass(
            id: "reader",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .read)]
        )
        let writer = RenderPass(
            id: "writer",
            dependencies: [],
            execute: nil,
            resourceUsages: [.buffer(bufferID, access: .write)]
        )
        var forward: [String: RenderPass] = [:]
        var reverse: [String: RenderPass] = [:]
        forward[reader.id] = reader
        forward[writer.id] = writer
        reverse[writer.id] = writer
        reverse[reader.id] = reader

        let first = try compileRenderGraph(forward)
        let second = try compileRenderGraph(reverse)

        XCTAssertEqual(first.executionOrder, second.executionOrder)
        XCTAssertEqual(
            first.passesByID[reader.id]?.inferredDependencies,
            second.passesByID[reader.id]?.inferredDependencies
        )
    }

    private func declareBuffer(_ id: String) -> RenderBufferResourceID {
        let bufferID = RenderBufferResourceID(id)
        RenderResourceRegistry.shared.registerBuffer(
            RenderExtensionBufferDescriptor(id: bufferID, length: 64)
        )
        return bufferID
    }
}

private final class SchedulingResourceRenderExtension: RenderExtension, @unchecked Sendable {
    let id: String
    let bufferID: RenderBufferResourceID

    init(id: String) {
        self.id = id
        bufferID = RenderBufferResourceID("\(id).buffer")
    }

    func registerResources(_ registry: RenderResourceRegistry) {
        registry.registerBuffer(RenderExtensionBufferDescriptor(id: bufferID, length: 64))
    }

    func buildGraph(
        _: inout RenderGraphBuilder,
        context _: RenderGraphBuildContext
    ) {}
}
