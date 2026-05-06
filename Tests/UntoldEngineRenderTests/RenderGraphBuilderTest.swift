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
@testable import UntoldEngine
import XCTest

final class RenderGraphBuilderTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        // Explicit state — don't rely on global defaults so tests are self-contained.
        TAAParams.shared.enabled = true
        FXAAParams.shared.enabled = false
    }

    override func tearDown() async throws {
        TAAParams.shared.enabled = true
        FXAAParams.shared.enabled = false
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
        XCTAssertNotNil(graph["hzbDepthSource"], "HZB depth source pass should be created")
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
        XCTAssertEqual(graph["hzbDepthSource"]?.dependencies, ["batchedModel"], "HZB depth source pass should depend on batched model pass")
        XCTAssertEqual(graph["ssao"]?.dependencies, ["batchedModel"], "SSAO pass should depend on batched model pass")

        let lightDeps = graph["lightPass"]?.dependencies.sorted()
        let expectedLightDeps = ["hzbDepthSource", "model", "shadow", "ssao"].sorted()
        XCTAssertEqual(lightDeps, expectedLightDeps, "Light pass should depend on hzbDepthSource, model, shadow, and ssao")
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
            ("batchedModel", "ssao"),
            ("shadow", "lightPass"),
            ("model", "lightPass"),
            ("hzbDepthSource", "lightPass"),
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
        var graph = [String: RenderPass]()

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

    func testBuildGameModeGraph_CreatesCompleteGraph() {
        // Set up environment for non-XR rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, finalPassID) = buildGameModeGraph()

        // Verify essential passes exist
        XCTAssertNotNil(graph["environment"], "Environment pass should exist")
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["hzbDepthSource"], "HZB depth source pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["transparency"], "Transparency pass should exist")
        XCTAssertNotNil(graph["spatialDebug"], "Spatial debug pass should exist")
        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // TAA is enabled by default — verify TAA and velocity passes are present,
        // and FXAA (mutually exclusive with TAA) is absent.
        XCTAssertNotNil(graph["taa"], "TAA pass should exist when TAA is enabled")
        XCTAssertNotNil(graph["velocity"], "Velocity pass should exist when TAA is enabled")
        XCTAssertNotNil(graph["taaPostProcessSource"], "TAA source handoff pass should exist when TAA is enabled")
        XCTAssertNil(graph["fxaa"], "FXAA pass must not exist when TAA takes priority")

        // Verify final pass
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
    }

    func testBuildGameModeGraph_GridMode() {
        renderInfo.immersionStyle = .none
        renderEnvironment = false // Should use grid instead

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["grid"], "Grid pass should exist when renderEnvironment is false")
        XCTAssertNil(graph["environment"], "Environment pass should not exist")

        // Shadow should depend on grid
        XCTAssertEqual(graph["shadow"]?.dependencies, ["grid"],
                       "Shadow should depend on grid in grid mode")
    }

    func testBuildGameModeGraph_XRPassthroughMode() {
        renderInfo.immersionStyle = .mixed

        let (graph, _) = buildGameModeGraph()

        XCTAssertNil(graph["environment"], "Environment pass should not exist in passthrough mode")
        XCTAssertNil(graph["grid"], "Grid pass should not exist in passthrough mode")

        // Shadow should have no base pass dependency
        XCTAssertEqual(graph["shadow"]?.dependencies, [],
                       "Shadow should have no dependencies in passthrough mode")
    }

    func testBuildGameModeGraph_XRFullImmersionMode() {
        renderInfo.immersionStyle = .full

        let (graph, _) = buildGameModeGraph()

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

        let (graph, _) = buildGameModeGraph()

        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Verify key ordering constraints
        assertTopologicalConstraints(order: order, constraints: [
            ("environment", "shadow"),
            ("shadow", "model"),
            ("model", "gaussian"),
            ("model", "lightPass"),
            ("lightPass", "transparency"),
            ("transparency", "spatialDebug"),
            ("spatialDebug", "taa"),
            ("batchedModel", "velocity"),
            ("velocity", "taa"),
            ("taa", "taaPostProcessSource"),
            ("taaPostProcessSource", "depthOfField"),
            ("depthOfField", "chromatic"),
            ("chromatic", "bloomThreshold"),
            ("bloomThreshold", "precomp"),
            ("gaussian", "precomp"),
            ("precomp", "look"),
            ("look", "outputTransform"),
        ])
    }

    func testBuildGameModeGraph_BypassPostProcessing_WithTAA() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        defer { bypassPostProcessing = false }

        // TAA is enabled (setUp default) — verifies the bypass path with TAA active.
        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")

        // Post-processing chain replaced by bypass pass.
        XCTAssertNotNil(graph["postProcessBypass"], "Bypass pass should exist when bypassPostProcessing is enabled")
        XCTAssertEqual(graph["postProcessBypass"]?.dependencies, ["taaPostProcessSource"],
                       "Bypass pass should depend on the TAA post-process source handoff")
        XCTAssertNil(graph["depthOfField"], "DepthOfField should not exist when bypassing post-processing")
        XCTAssertNil(graph["chromatic"], "Chromatic should not exist when bypassing post-processing")
        XCTAssertNil(graph["bloomThreshold"], "BloomThreshold should not exist when bypassing post-processing")

        // Precomp still depends on both the bypass pass and gaussian.
        let precompDeps = graph["precomp"]?.dependencies.sorted() ?? []
        XCTAssertTrue(precompDeps.contains("postProcessBypass"), "Precomp should depend on postProcessBypass")
        XCTAssertTrue(precompDeps.contains("gaussian"), "Precomp should still depend on gaussian")

        // TAA output chain: spatialDebug + velocity -> taa -> postProcessBypass -> precomp -> look.
        XCTAssertNotNil(graph["taa"], "TAA pass should exist")
        XCTAssertNotNil(graph["velocity"], "Velocity pass should exist alongside TAA")
        XCTAssertNotNil(graph["taaPostProcessSource"], "TAA source handoff pass should exist")
        XCTAssertNil(graph["fxaa"], "FXAA must not exist when TAA takes priority")
        XCTAssertEqual(graph["look"]?.dependencies, ["precomp"],
                       "Look should depend on precomp")
        let taaDeps = graph["taa"]?.dependencies.sorted() ?? []
        XCTAssertTrue(taaDeps.contains("spatialDebug"), "TAA should depend on spatialDebug")
        XCTAssertTrue(taaDeps.contains("velocity"), "TAA should depend on velocity")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "Output transform should depend on look after TAA feeds post-processing")
    }

    func testBuildGameModeGraph_BypassPostProcessing_WithFXAA() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        TAAParams.shared.enabled = false
        FXAAParams.shared.enabled = true
        defer {
            bypassPostProcessing = false
            TAAParams.shared.enabled = true
            FXAAParams.shared.enabled = false
        }

        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["fxaa"], "FXAA pass should exist when TAA is disabled and FXAA is enabled")
        XCTAssertNil(graph["taa"], "TAA pass must not exist when TAA is disabled")
        XCTAssertNil(graph["velocity"], "Velocity pass must not exist when TAA is disabled")
        XCTAssertEqual(graph["fxaa"]?.dependencies, ["look"],
                       "FXAA should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["fxaa"],
                       "Output transform should depend on fxaa")
    }

    // MARK: - Gaussian Pass Integration Tests

    func testBuildGameModeGraph_GaussianPassExists() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should exist in game mode graph")
    }

    func testBuildGameModeGraph_GaussianDependsOnModel() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertEqual(graph["gaussian"]?.dependencies, ["model"],
                       "Gaussian pass should depend on model pass to access depth buffer")
    }

    func testBuildGameModeGraph_PreCompDependsOnGaussian() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        let precompDeps = graph["precomp"]?.dependencies.sorted() ?? []
        XCTAssertTrue(precompDeps.contains("gaussian"),
                      "Pre-composite pass should depend on gaussian pass")
    }

    func testBuildGameModeGraph_GaussianHasExecutionFunction() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["gaussian"]?.execute,
                        "Gaussian pass should have an execution function")
    }

    func testBuildGameModeGraph_GaussianInAllRenderModes() {
        // Test that gaussian pass exists in all render modes
        let modes: [(UntoldImmersionMode, Bool, String)] = [
            (.none, true, "environment"),
            (.none, false, "grid"),
            (.full, true, "full immersion"),
            (.mixed, false, "passthrough"),
        ]

        for (immersionStyle, useEnvironment, description) in modes {
            renderInfo.immersionStyle = immersionStyle
            renderEnvironment = useEnvironment

            let (graph, _) = buildGameModeGraph()

            XCTAssertNotNil(graph["gaussian"],
                            "Gaussian pass should exist in \(description) mode")
            XCTAssertEqual(graph["gaussian"]?.dependencies, ["model"],
                           "Gaussian should depend on model in \(description) mode")
        }
    }

    func testBuildGameModeGraph_GaussianTopologicalPosition() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

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

    // MARK: - TAA in the render graph

    func testBuildGameModeGraph_TAAEnabled_CorrectDependencies() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        // velocity reads the G-buffer position written by batchedModel.
        XCTAssertEqual(graph["velocity"]?.dependencies, ["batchedModel"],
                       "Velocity pass should depend on batchedModel")

        // taa needs the lit scene before post-processing plus motion vectors.
        let taaDeps = graph["taa"]?.dependencies.sorted() ?? []
        XCTAssertTrue(taaDeps.contains("spatialDebug"), "TAA should depend on spatialDebug")
        XCTAssertTrue(taaDeps.contains("velocity"), "TAA should depend on velocity")

        XCTAssertEqual(graph["taaPostProcessSource"]?.dependencies, ["taa"],
                       "TAA handoff should depend on the resolved TAA output")
        XCTAssertEqual(graph["postProcessDisabledBypass"]?.dependencies, ["taaPostProcessSource"],
                       "Post-processing should read from the TAA handoff when effects are disabled")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform should depend on look after TAA feeds post-processing")
    }

    func testBuildGameModeGraph_TAAEnabled_TopologicalOrder() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()
        let sorted = try topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        assertTopologicalConstraints(order: order, constraints: [
            ("batchedModel", "velocity"),
            ("spatialDebug", "taa"),
            ("velocity", "taa"),
            ("taa", "taaPostProcessSource"),
            ("taaPostProcessSource", "postProcessDisabledBypass"),
            ("postProcessDisabledBypass", "precomp"),
            ("precomp", "look"),
            ("look", "outputTransform"),
        ])
    }

    func testBuildGameModeGraph_TAADisabled_NoTAAOrVelocityPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        TAAParams.shared.enabled = false
        defer { TAAParams.shared.enabled = true }

        let (graph, _) = buildGameModeGraph()

        XCTAssertNil(graph["taa"], "TAA pass must not exist when TAA is disabled")
        XCTAssertNil(graph["velocity"], "Velocity pass must not exist when TAA is disabled")
    }

    func testBuildGameModeGraph_TAADisabled_OutputDependsOnLook() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        TAAParams.shared.enabled = false
        FXAAParams.shared.enabled = false
        defer {
            TAAParams.shared.enabled = true
            FXAAParams.shared.enabled = false
        }

        let (graph, _) = buildGameModeGraph()

        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform should depend directly on look when both TAA and FXAA are off")
    }

    func testBuildGameModeGraph_TAAAndFXAABothEnabled_TAAWins() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        TAAParams.shared.enabled = true
        FXAAParams.shared.enabled = true
        defer { FXAAParams.shared.enabled = false }

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["taa"], "TAA pass should exist when both AA flags are enabled")
        XCTAssertNil(graph["fxaa"], "FXAA pass must not exist when TAA takes priority")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform should depend on look because TAA feeds post-processing")
    }

    func testBuildGameModeGraph_TAADisabled_FXAAEnabled_CreatesFXAAPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        TAAParams.shared.enabled = false
        FXAAParams.shared.enabled = true
        defer {
            TAAParams.shared.enabled = true
            FXAAParams.shared.enabled = false
        }

        let (graph, _) = buildGameModeGraph()

        XCTAssertNotNil(graph["fxaa"], "FXAA pass should exist when TAA is off and FXAA is on")
        XCTAssertNil(graph["taa"], "TAA pass must not exist when TAA is disabled")
        XCTAssertNil(graph["velocity"], "Velocity pass must not exist when TAA is disabled")
        XCTAssertEqual(graph["fxaa"]?.dependencies, ["look"],
                       "FXAA should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["fxaa"],
                       "outputTransform should depend on fxaa")
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
