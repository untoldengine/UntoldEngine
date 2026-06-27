//
//  CompiledRenderGraphTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class CompiledRenderGraphTest: XCTestCase {
    func testCompileCapturesPassMetadataAndDeterministicOrder() throws {
        let textureID: RenderTextureResourceID = "test.compiled.texture"
        RenderResourceRegistry.shared.registerTexture(
            RenderExtensionTextureDescriptor(
                id: textureID,
                size: .fixed(width: 1, height: 1),
                pixelFormat: .rgba8Unorm,
                usage: .shaderRead
            )
        )
        defer { RenderResourceRegistry.shared.removeAll() }
        let graph = [
            "surface": RenderPass(
                id: "surface",
                dependencies: ["prepare"],
                execute: nil,
                resourceUsages: [.texture(textureID, access: .read)],
                stage: .beforePostProcess
            ),
            "prepare": RenderPass(
                id: "prepare",
                dependencies: [],
                execute: nil
            ),
        ]

        let compiled = try compileRenderGraph(graph)

        XCTAssertEqual(compiled.executionOrder, ["prepare", "surface"])
        XCTAssertEqual(compiled.passesByID.count, 2)
        XCTAssertEqual(compiled.passesByID["surface"]?.dependencies, ["prepare"])
        XCTAssertEqual(
            compiled.passesByID["surface"]?.resourceUsages,
            [.texture(textureID, access: .read)]
        )
        XCTAssertEqual(
            compiled.passesByID["surface"]?.owner,
            .engine
        )
        XCTAssertEqual(compiled.passesByID["surface"]?.stage, .beforePostProcess)
    }

    func testCompilationOrderDoesNotDependOnDictionaryInsertionOrder() throws {
        let passA = RenderPass(id: "a", dependencies: [], execute: nil)
        let passB = RenderPass(id: "b", dependencies: [], execute: nil)
        let passC = RenderPass(id: "c", dependencies: ["a", "b"], execute: nil)
        var forward: [String: RenderPass] = [:]
        var reverse: [String: RenderPass] = [:]

        forward[passA.id] = passA
        forward[passB.id] = passB
        forward[passC.id] = passC
        reverse[passC.id] = passC
        reverse[passB.id] = passB
        reverse[passA.id] = passA

        let forwardOrder = try compileRenderGraph(forward).executionOrder
        let reverseOrder = try compileRenderGraph(reverse).executionOrder

        XCTAssertEqual(forwardOrder, ["a", "b", "c"])
        XCTAssertEqual(reverseOrder, forwardOrder)
    }

    func testBuilderCompilationPreservesResolvedStageOwnership() throws {
        var builder = RenderGraphBuilder()
        builder.addPass(id: "anchor", dependencies: [], execute: nil)
        builder.beginExtensionRegistration(id: "test.compiled.extension")
        builder.addPass(
            id: "first",
            stage: .afterTransparency,
            execute: nil
        )
        builder.addPass(
            id: "second",
            stage: .afterTransparency,
            execute: nil
        )
        XCTAssertTrue(builder.endExtensionRegistration().succeeded)
        XCTAssertEqual(
            builder.resolveStage(.afterTransparency, after: "anchor"),
            "second"
        )

        let compiled = try builder.compile()

        XCTAssertEqual(compiled.executionOrder, ["anchor", "first", "second"])
        XCTAssertEqual(compiled.passesByID["first"]?.dependencies, ["anchor"])
        XCTAssertEqual(compiled.passesByID["second"]?.dependencies, ["first"])
        XCTAssertEqual(
            compiled.passesByID["first"]?.owner,
            .renderExtension("test.compiled.extension")
        )
        XCTAssertEqual(compiled.passesByID["first"]?.stage, .afterTransparency)
        XCTAssertEqual(compiled.passesByID["second"]?.stage, .afterTransparency)
    }

    func testCompiledGraphIsSnapshotOfMutableSourceGraph() throws {
        var graph = [
            "pass": RenderPass(id: "pass", dependencies: [], execute: nil),
        ]
        let compiled = try compileRenderGraph(graph)

        graph["pass"]?.dependencies.append("later-mutation")
        graph["new"] = RenderPass(id: "new", dependencies: [], execute: nil)

        XCTAssertEqual(compiled.executionOrder, ["pass"])
        XCTAssertEqual(compiled.passesByID.count, 1)
        XCTAssertEqual(compiled.passesByID["pass"]?.dependencies, [])
    }

    func testCompilationRejectsMissingDependencyBeforeCreatingSnapshot() {
        let graph = [
            "pass": RenderPass(
                id: "pass",
                dependencies: ["missing"],
                execute: nil
            ),
        ]

        XCTAssertThrowsError(try compileRenderGraph(graph)) { error in
            XCTAssertEqual(
                error as? RenderGraphError,
                .missingDependency(passID: "pass", dependencyID: "missing")
            )
        }
    }
}
