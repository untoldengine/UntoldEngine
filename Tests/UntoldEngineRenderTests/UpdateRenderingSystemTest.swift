//
//  UpdateRenderingSystemTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal
@testable import UntoldEngine
import XCTest

final class UpdateRenderingSystemTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - UpdateRenderingSystem Environment Mode Tests

    func testUpdateRenderingSystem_EnvironmentModeConfiguresRenderGraphCorrectly() throws {
        // Set up for macOS/iOS rendering with environment
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        // Build the render graph using the same logic as UpdateRenderingSystem
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify that environment mode creates the environment pass
        XCTAssertNotNil(graph["environment"], "Environment mode should create environment pass")
        XCTAssertNil(graph["grid"], "Environment mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow depends on environment
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment in environment mode")

        // Verify the graph can be topologically sorted
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")

        // Verify environment comes before composite in the sorted order
        let order = sortedPasses.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("environment", "shadow"),
            ("shadow", "batchedShadow"),
            ("batchedShadow", "pointShadow"),
            ("pointShadow", "spotShadow"),
            ("spotShadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateRenderingSystem_EnvironmentModeUsesEnvironmentPass() throws {
        // Set up for environment rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        // Verify that environment mode uses environment, not grid
        XCTAssertNotNil(graph["environment"], "Environment mode should use environment pass")
        XCTAssertNil(graph["grid"], "Environment mode should not use grid pass")

        // Verify the environment pass has no dependencies (it's the base)
        XCTAssertEqual(graph["environment"]?.dependencies.count, 0,
                       "Environment pass should have no dependencies")
    }

    // MARK: - UpdateRenderingSystem Grid Mode Tests

    func testUpdateRenderingSystem_GridModeConfiguresRenderGraphCorrectly() throws {
        // Set up for macOS/iOS rendering with grid
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false // sky is the default non-IBL background; opt into grid explicitly
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        // Build the render graph using the same logic as UpdateRenderingSystem
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify that grid mode creates the grid pass
        XCTAssertNotNil(graph["grid"], "Grid mode should create grid pass")
        XCTAssertNil(graph["environment"], "Grid mode should not create environment pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow depends on grid
        XCTAssertEqual(graph["shadow"]?.dependencies, ["grid"],
                       "Shadow should depend on grid in grid mode")

        // Verify the graph can be topologically sorted
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")

        // Verify grid comes before composite in the sorted order
        let order = sortedPasses.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("grid", "shadow"),
            ("shadow", "batchedShadow"),
            ("batchedShadow", "pointShadow"),
            ("pointShadow", "spotShadow"),
            ("spotShadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateRenderingSystem_GridModeUsesGridPass() throws {
        // Set up for grid rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false

        let (graph, _) = try buildGameModeGraph()

        // Verify that grid mode uses grid, not environment
        XCTAssertNotNil(graph["grid"], "Grid mode should use grid pass")
        XCTAssertNil(graph["environment"], "Grid mode should not use environment pass")

        // Verify the grid pass has no dependencies (it's the base)
        XCTAssertEqual(graph["grid"]?.dependencies.count, 0,
                       "Grid pass should have no dependencies")
    }

    // MARK: - UpdateRenderingSystem Sky Mode Tests

    func testUpdateRenderingSystem_SkyModeConfiguresRenderGraphCorrectly() throws {
        // Sky is the default non-IBL background for macOS/iOS rendering.
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = true
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let (graph, finalPassID) = try buildGameModeGraph()

        XCTAssertNotNil(graph["sky"], "Sky mode should create sky pass")
        XCTAssertNil(graph["grid"], "Sky mode should not create grid pass")
        XCTAssertNil(graph["environment"], "Sky mode should not create environment pass")

        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow depends on sky
        XCTAssertEqual(graph["shadow"]?.dependencies, ["sky"],
                       "Shadow should depend on sky in sky mode")

        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")

        let order = sortedPasses.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("sky", "shadow"),
            ("shadow", "batchedShadow"),
            ("batchedShadow", "pointShadow"),
            ("pointShadow", "spotShadow"),
            ("spotShadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateRenderingSystem_SkyModeUsesSkyPass() throws {
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = true

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["sky"], "Sky mode should use sky pass")
        XCTAssertNil(graph["grid"], "Sky mode should not use grid pass")
        XCTAssertNil(graph["environment"], "Sky mode should not use environment pass")

        // Verify the sky pass has no dependencies (it's the base)
        XCTAssertEqual(graph["sky"]?.dependencies.count, 0,
                       "Sky pass should have no dependencies")
    }

    func testUpdateRenderingSystem_SkyIsDefaultWhenNotExplicitlySet() throws {
        // renderSkyBackground defaults to true, so leaving it untouched should still select sky.
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        let (graph, _) = try buildGameModeGraph()

        XCTAssertNotNil(graph["sky"], "Sky should be the default background without setting renderSkyBackground")
        XCTAssertNil(graph["grid"], "Grid should not be used by default")
    }

    // MARK: - Final Pass Tests

    func testUpdateRenderingSystem_OutputTransformIsTheFinalPass() throws {
        // Test with environment mode
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify final pass is outputTransform
        XCTAssertEqual(finalPassID, "outputTransform", "buildGameModeGraph should return 'outputTransform' as final pass ID")

        // Verify the dependency chain is correct
        let sortedPasses = try topologicalSortGraph(graph: graph)
        _ = sortedPasses.map(\.id)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in topological order")
    }

    func testUpdateRenderingSystem_OutputTransformIsLastInTopologicalOrder() throws {
        // Test with the default (sky) non-IBL mode
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the render graph")
    }

    func testUpdateRenderingSystem_OutputTransformIsCorrectFinalPassInAllRenderModes() throws {
        // Test environment, sky, and grid modes to ensure outputTransform is the final pass

        let modes: [(useEnvironment: Bool, useSky: Bool, description: String)] = [
            (true, false, "environment"),
            (false, true, "sky"),
            (false, false, "grid"),
        ]

        for (useEnvironment, useSky, description) in modes {
            renderInfo.immersionStyle = .none
            renderEnvironment = useEnvironment
            renderSkyBackground = useSky

            let (graph, finalPassID) = try buildGameModeGraph()

            // Verify outputTransform is the final pass
            XCTAssertEqual(finalPassID, "outputTransform",
                           "Final pass should be 'outputTransform' in \(description) mode")

            // Verify topological ordering
            let sortedPasses = try topologicalSortGraph(graph: graph)

            XCTAssertEqual(sortedPasses.last?.id, finalPassID,
                           "outputTransform should be the last pass in \(description) mode")
        }
    }

    // MARK: - Render Mode Selection Tests

    func testUpdateRenderingSystem_ImmersionStyleNoneDeterminesCorrectBasePass() throws {
        // Test that immersionStyle .none correctly selects between environment, sky, and grid

        // Test environment selection
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        let (envGraph, _) = try buildGameModeGraph()
        XCTAssertNotNil(envGraph["environment"], "Should use environment when renderEnvironment is true")
        XCTAssertNil(envGraph["sky"], "Should not use sky when renderEnvironment is true")
        XCTAssertNil(envGraph["grid"], "Should not use grid when renderEnvironment is true")

        // Test sky selection (the default non-IBL background)
        renderEnvironment = false
        let (skyGraph, _) = try buildGameModeGraph()
        XCTAssertNotNil(skyGraph["sky"], "Should use sky when renderEnvironment is false and renderSkyBackground is true")
        XCTAssertNil(skyGraph["environment"], "Should not use environment when renderEnvironment is false")
        XCTAssertNil(skyGraph["grid"], "Should not use grid when renderSkyBackground is true")

        // Test grid selection (explicit opt-out of the sky)
        renderSkyBackground = false
        let (gridGraph, _) = try buildGameModeGraph()
        XCTAssertNotNil(gridGraph["grid"], "Should use grid when renderEnvironment and renderSkyBackground are false")
        XCTAssertNil(gridGraph["environment"], "Should not use environment when renderEnvironment is false")
        XCTAssertNil(gridGraph["sky"], "Should not use sky when renderSkyBackground is false")
    }

    func testUpdateRenderingSystem_EnvironmentAndGridModesHaveDifferentDependencies() throws {
        // Verify that environment and grid modes create different dependency chains

        // Environment mode
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        let (envGraph, _) = try buildGameModeGraph()

        // Grid mode
        renderEnvironment = false
        renderSkyBackground = false
        let (gridGraph, _) = try buildGameModeGraph()

        // Both should have shadow pass, but with different dependencies
        XCTAssertNotNil(envGraph["shadow"], "Environment graph should have shadow pass")
        XCTAssertNotNil(gridGraph["shadow"], "Grid graph should have shadow pass")

        XCTAssertEqual(envGraph["shadow"]?.dependencies, ["environment"],
                       "In environment mode, shadow should depend on environment")
        XCTAssertEqual(gridGraph["shadow"]?.dependencies, ["grid"],
                       "In grid mode, shadow should depend on grid")
    }

    // MARK: - Integration Tests

    func testUpdateRenderingSystem_FullWorkflowWithEnvironmentMode() throws {
        // Simulate the full UpdateRenderingSystem workflow
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        // This simulates what UpdateRenderingSystem does
        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["environment"], "Environment mode should have environment pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["environment", "shadow", "batchedShadow", "pointShadow", "spotShadow", "model", "lightPass", "gaussian", "precomp", "look", "outputTransform"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_FullWorkflowWithGridMode() throws {
        // Simulate the full UpdateRenderingSystem workflow
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false

        // This simulates what UpdateRenderingSystem does
        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["grid"], "Grid mode should have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["grid", "shadow", "batchedShadow", "pointShadow", "spotShadow", "model", "lightPass", "gaussian", "precomp", "look", "outputTransform"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_FullWorkflowWithSkyMode() throws {
        // Simulate the full UpdateRenderingSystem workflow with the default (sky) background
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = true

        let (graph, _) = try buildGameModeGraph()

        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["sky"], "Sky mode should have sky pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")

        let expectedPasses = ["sky", "shadow", "batchedShadow", "pointShadow", "spotShadow", "model", "lightPass", "gaussian", "precomp", "look", "outputTransform"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_GraphTopologicalOrderIsConsistent() throws {
        // Verify that multiple calls produce consistent topological ordering

        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph1, _) = try buildGameModeGraph()
        let (graph2, _) = try buildGameModeGraph()

        let sorted1 = try topologicalSortGraph(graph: graph1)
        let sorted2 = try topologicalSortGraph(graph: graph2)

        // Both should have the same number of passes
        XCTAssertEqual(sorted1.count, sorted2.count,
                       "Multiple calls should produce graphs with the same number of passes")

        // Verify key ordering constraints are maintained in both
        let order1 = sorted1.map(\.id)
        let order2 = sorted2.map(\.id)

        let constraints = [
            ("environment", "shadow"),
            ("shadow", "batchedShadow"),
            ("batchedShadow", "pointShadow"),
            ("pointShadow", "spotShadow"),
            ("spotShadow", "model"),
            ("model", "lightPass"),
        ]

        assertTopologicalConstraints(order: order1, constraints: constraints)
        assertTopologicalConstraints(order: order2, constraints: constraints)
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
