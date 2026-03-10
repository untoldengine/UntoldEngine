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
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - UpdateRenderingSystem Environment Mode Tests

    func testUpdateRenderingSystem_EnvironmentModeConfiguresRenderGraphCorrectly() throws {
        // Set up for macOS/iOS rendering with environment
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        // Build the render graph using the same logic as UpdateRenderingSystem
        let (graph, finalPassID) = buildGameModeGraph()

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
            ("shadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateRenderingSystem_EnvironmentModeUsesEnvironmentPass() {
        // Set up for environment rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = buildGameModeGraph()

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

        // Build the render graph using the same logic as UpdateRenderingSystem
        let (graph, finalPassID) = buildGameModeGraph()

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
            ("shadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateRenderingSystem_GridModeUsesGridPass() {
        // Set up for grid rendering
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        let (graph, _) = buildGameModeGraph()

        // Verify that grid mode uses grid, not environment
        XCTAssertNotNil(graph["grid"], "Grid mode should use grid pass")
        XCTAssertNil(graph["environment"], "Grid mode should not use environment pass")

        // Verify the grid pass has no dependencies (it's the base)
        XCTAssertEqual(graph["grid"]?.dependencies.count, 0,
                       "Grid pass should have no dependencies")
    }

    // MARK: - Final Pass Tests

    func testUpdateRenderingSystem_OutputTransformIsTheFinalPass() throws {
        // Test with environment mode
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, finalPassID) = buildGameModeGraph()

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
        // Test with grid mode
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        let (graph, _) = buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the render graph")
    }

    func testUpdateRenderingSystem_OutputTransformIsCorrectFinalPassInAllRenderModes() throws {
        // Test both environment and grid modes to ensure outputTransform is the final pass

        let modes: [(Bool, String)] = [
            (true, "environment"),
            (false, "grid"),
        ]

        for (useEnvironment, description) in modes {
            renderInfo.immersionStyle = .none
            renderEnvironment = useEnvironment

            let (graph, finalPassID) = buildGameModeGraph()

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

    func testUpdateRenderingSystem_ImmersionStyleNoneDeterminesCorrectBasePass() {
        // Test that immersionStyle .none correctly selects between environment and grid

        // Test environment selection
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        let (envGraph, _) = buildGameModeGraph()
        XCTAssertNotNil(envGraph["environment"], "Should use environment when renderEnvironment is true")
        XCTAssertNil(envGraph["grid"], "Should not use grid when renderEnvironment is true")

        // Test grid selection
        renderEnvironment = false
        let (gridGraph, _) = buildGameModeGraph()
        XCTAssertNotNil(gridGraph["grid"], "Should use grid when renderEnvironment is false")
        XCTAssertNil(gridGraph["environment"], "Should not use environment when renderEnvironment is false")
    }

    func testUpdateRenderingSystem_EnvironmentAndGridModesHaveDifferentDependencies() {
        // Verify that environment and grid modes create different dependency chains

        // Environment mode
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        let (envGraph, _) = buildGameModeGraph()

        // Grid mode
        renderEnvironment = false
        let (gridGraph, _) = buildGameModeGraph()

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
        let (graph, _) = buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["environment"], "Environment mode should have environment pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["environment", "shadow", "model", "lightPass", "gaussian", "precomp", "look", "outputTransform"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_FullWorkflowWithGridMode() throws {
        // Simulate the full UpdateRenderingSystem workflow
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        // This simulates what UpdateRenderingSystem does
        let (graph, _) = buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["grid"], "Grid mode should have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["grid", "shadow", "model", "lightPass", "gaussian", "precomp", "look", "outputTransform"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_GraphTopologicalOrderIsConsistent() throws {
        // Verify that multiple calls produce consistent topological ordering

        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph1, _) = buildGameModeGraph()
        let (graph2, _) = buildGameModeGraph()

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
            ("shadow", "model"),
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
