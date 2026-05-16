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
        XCTAssertEqual(graph["ssao"]?.dependencies, ["batchedModel"], "SSAO pass should depend on batched model pass")

        let lightDeps = graph["lightPass"]?.dependencies.sorted()
        let expectedLightDeps = ["batchedModel", "model", "shadow", "ssao"].sorted()
        XCTAssertEqual(lightDeps, expectedLightDeps, "Light pass should depend on batchedModel, model, shadow, and ssao")
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
            ("batchedModel", "ssao"),
            ("shadow", "lightPass"),
            ("model", "lightPass"),
            ("batchedModel", "lightPass"),
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
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["transparency"], "Transparency pass should exist")
        XCTAssertNotNil(graph["spatialDebug"], "Spatial debug pass should exist")
        XCTAssertNotNil(graph["gaussian"], "Gaussian pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

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
            ("spatialDebug", "depthOfField"),
            ("depthOfField", "chromatic"),
            ("chromatic", "bloomThreshold"),
            ("bloomThreshold", "precomp"),
            ("gaussian", "precomp"),
            ("precomp", "look"),
            ("look", "outputTransform"),
        ])
    }

    func testBuildGameModeGraph_BypassPostProcessing_UsesBypassPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        bypassPostProcessing = true
        defer { bypassPostProcessing = false }

        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["spatialDebug"], "Spatial debug pass should exist")
        XCTAssertEqual(graph["spatialDebug"]?.dependencies, ["transparency"],
                       "Spatial debug pass should depend on transparency")
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

    func testBuildGameModeGraph_FXAAEdgeDebugUsesDiagnosticPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .fxaaEdgeDebug
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["fxaaEdgeDebug"], "FXAA edge debug pass should exist")
        XCTAssertNil(graph["fxaa"], "Normal FXAA pass should not exist when viewing FXAA edge debug")
        XCTAssertEqual(graph["fxaaEdgeDebug"]?.dependencies, ["look"],
                       "FXAA edge debug should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["fxaaEdgeDebug"],
                       "Output transform should read the FXAA edge debug output")
    }

    func testBuildGameModeGraph_SMAAUsesThreePassChain() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .smaa
        defer { antiAliasingMode = .fxaa }

        let (graph, finalPassID) = buildGameModeGraph()

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

    func testBuildGameModeGraph_SMAAEdgesDebugStopsAfterEdgePass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaEdges
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass should be outputTransform")
        XCTAssertNotNil(graph["smaaEdges"], "SMAA edge pass should exist for edge debug")
        XCTAssertNil(graph["smaaBlendWeights"], "SMAA blend pass should not run for edge debug")
        XCTAssertNil(graph["smaaNeighborhood"], "SMAA neighborhood pass should not run for edge debug")
        XCTAssertEqual(graph["smaaEdges"]?.dependencies, ["look"],
                       "SMAA edge debug should depend on look")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["smaaEdges"],
                       "Output transform should read the SMAA edge texture")
    }

    func testBuildGameModeGraph_SMAABlendDebugStopsAfterBlendPass() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaBlend
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = buildGameModeGraph()

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

    func testBuildGameModeGraph_SMAADifferenceDebugRunsFullChain() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .smaaDifference
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = buildGameModeGraph()

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
    func testBuildGameModeGraph_NoAAMode_HasNoAAPassAndConnectsDirectlyToOutput() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .none
        renderDebugViewMode = .lit
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
        }

        let (graph, finalPassID) = buildGameModeGraph()

        XCTAssertEqual(finalPassID, "outputTransform")
        XCTAssertNil(graph["fxaa"],              "No FXAA pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaEdges"],         "No SMAA edges pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaBlendWeights"],  "No SMAA blend-weight pass when antiAliasingMode is .none")
        XCTAssertNil(graph["smaaNeighborhood"],  "No SMAA neighborhood pass when antiAliasingMode is .none")
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "outputTransform must depend directly on look when no AA is active")
    }

    // MARK: - G-Buffer Debug View Modes

    /// Switching renderDebugViewMode to any G-Buffer visualization mode must not change the
    /// set of passes in the render graph. The routing change is inside the look pass execution
    /// closure, not in the graph topology.
    func testBuildGameModeGraph_GBufferDebugModes_ProduceSamePassSetAsLitMode() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        antiAliasingMode = .fxaa
        defer { renderDebugViewMode = .lit }

        renderDebugViewMode = .lit
        let (baseGraph, _) = buildGameModeGraph()
        let baseKeys = Set(baseGraph.keys)

        for mode in [RenderDebugViewMode.albedo, .normal, .depth, .ssaoBlurred] {
            renderDebugViewMode = mode
            let (graph, finalPassID) = buildGameModeGraph()
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
    func testBuildGameModeGraph_BloomDisabled_BlurPassesAbsent() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let wasBloom = BloomThresholdParams.shared.enabled
        let wasVignette = VignetteParams.shared.enabled
        BloomThresholdParams.shared.enabled = false
        VignetteParams.shared.enabled = true  // keep the full chain alive; bloom alone is off
        defer {
            BloomThresholdParams.shared.enabled = wasBloom
            VignetteParams.shared.enabled = wasVignette
        }

        let (graph, _) = buildGameModeGraph()

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
