//
//  RenderGraphBuilderTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import Foundation
@testable import UntoldEngine
import XCTest

final class RenderGraphBuilderTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
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

    func testGBufferPass_TopologicalOrder() {
        var graph = [String: RenderPass]()
        let shadowPass = RenderPass(id: "shadow", dependencies: [], execute: nil)
        graph[shadowPass.id] = shadowPass

        gBufferPass(graph: &graph, shadowPass: shadowPass)

        let sorted = try! topologicalSortGraph(graph: graph)
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

        let finalPass = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass",
            geometryPassId: "model"
        )

        // Verify base post-processing passes are created
        XCTAssertNotNil(graph["depthOfField"], "Depth of field pass should be created")
        XCTAssertNotNil(graph["chromatic"], "Chromatic aberration pass should be created")
        XCTAssertNotNil(graph["bloomThreshold"], "Bloom threshold pass should be created")
        XCTAssertNotNil(finalPass, "Should return a final pass")
    }

    func testPostProcessingEffects_CorrectBaseDependencies() {
        var graph = [String: RenderPass]()

        _ = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass",
            geometryPassId: "model"
        )

        XCTAssertEqual(graph["depthOfField"]?.dependencies, ["lightPass"],
                       "Depth of field should depend on lightPass")
        XCTAssertEqual(graph["chromatic"]?.dependencies, ["depthOfField"],
                       "Chromatic aberration should depend on depthOfField")

        let bloomDeps = graph["bloomThreshold"]?.dependencies.sorted()
        let expectedBloomDeps = ["chromatic", "model"].sorted()
        XCTAssertEqual(bloomDeps, expectedBloomDeps,
                       "Bloom threshold should depend on chromatic and model")
    }

    func testPostProcessingEffects_TopologicalOrder() {
        var graph = [String: RenderPass]()

        BloomThresholdParams.shared.enabled = true

        _ = postProcessingEffects(
            graph: &graph,
            deferredPassId: "lightPass",
            geometryPassId: "model"
        )

        let sorted = try! topologicalSortGraph(graph: graph)
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

    func testBuildGameModeGraph_ValidTopologicalOrder() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        BloomThresholdParams.shared.enabled = false

        let (graph, _) = buildGameModeGraph()

        let sorted = try! topologicalSortGraph(graph: graph)
        let order = sorted.map(\.id)

        // Verify key ordering constraints
        assertTopologicalConstraints(order: order, constraints: [
            ("environment", "shadow"),
            ("shadow", "model"),
            ("model", "gaussian"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
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
        XCTAssertNotNil(graph["postProcessBypass"], "Bypass pass should exist when bypassPostProcessing is enabled")
        XCTAssertEqual(graph["postProcessBypass"]?.dependencies, ["transparency"],
                       "Bypass pass should depend on transparency")
        XCTAssertNotNil(graph["look"], "Look pass should exist when bypassing post-processing")
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
        XCTAssertEqual(graph["outputTransform"]?.dependencies, ["look"],
                       "Output transform should depend on look when bypassing post-processing")
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

    func testBuildGameModeGraph_GaussianTopologicalPosition() {
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

        let sorted = try! topologicalSortGraph(graph: graph)
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
