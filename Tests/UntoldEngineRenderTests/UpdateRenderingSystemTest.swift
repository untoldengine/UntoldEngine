//
//  UpdateRenderingSystemTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

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

    func testUpdateRenderingSystem_EnvironmentModeConfiguresRenderGraphCorrectly() {
        // Set up for macOS/iOS rendering with environment
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        // Build the render graph using the same logic as UpdateRenderingSystem
        var (graph, preCompID) = buildGameModeGraph()

        // Verify that environment mode creates the environment pass
        XCTAssertNotNil(graph["environment"], "Environment mode should create environment pass")
        XCTAssertNil(graph["grid"], "Environment mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(preCompID, "precomp", "Final pass ID should be precomp")

        // Verify shadow depends on environment
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment in environment mode")

        // Add composite pass as UpdateRenderingSystem does
        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify composite pass was added
        XCTAssertNotNil(graph["composite"], "Composite pass should be added to graph")
        XCTAssertEqual(graph["composite"]?.dependencies, [preCompID],
                       "Composite pass should depend on the final pass from buildGameModeGraph")

        // Verify the graph can be topologically sorted
        let sortedPasses = try! topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify composite is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "composite",
                       "Composite should be the last pass in the sorted order")

        // Verify environment comes before composite in the sorted order
        let order = sortedPasses.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("environment", "shadow"),
            ("shadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
            ("precomp", "composite"),
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

    func testUpdateRenderingSystem_GridModeConfiguresRenderGraphCorrectly() {
        // Set up for macOS/iOS rendering with grid
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        // Build the render graph using the same logic as UpdateRenderingSystem
        var (graph, preCompID) = buildGameModeGraph()

        // Verify that grid mode creates the grid pass
        XCTAssertNotNil(graph["grid"], "Grid mode should create grid pass")
        XCTAssertNil(graph["environment"], "Grid mode should not create environment pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(preCompID, "precomp", "Final pass ID should be precomp")

        // Verify shadow depends on grid
        XCTAssertEqual(graph["shadow"]?.dependencies, ["grid"],
                       "Shadow should depend on grid in grid mode")

        // Add composite pass as UpdateRenderingSystem does
        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify composite pass was added
        XCTAssertNotNil(graph["composite"], "Composite pass should be added to graph")
        XCTAssertEqual(graph["composite"]?.dependencies, [preCompID],
                       "Composite pass should depend on the final pass from buildGameModeGraph")

        // Verify the graph can be topologically sorted
        let sortedPasses = try! topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify composite is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "composite",
                       "Composite should be the last pass in the sorted order")

        // Verify grid comes before composite in the sorted order
        let order = sortedPasses.map(\.id)
        assertTopologicalConstraints(order: order, constraints: [
            ("grid", "shadow"),
            ("shadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
            ("precomp", "composite"),
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

    // MARK: - Composite Pass Dependency Tests

    func testUpdateRenderingSystem_CompositePassDependsOnFinalPassFromBuildGameModeGraph() {
        // Test with environment mode
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        var (graph, preCompID) = buildGameModeGraph()

        // Verify preCompID is "precomp"
        XCTAssertEqual(preCompID, "precomp", "buildGameModeGraph should return 'precomp' as final pass ID")

        // Add composite pass as UpdateRenderingSystem does
        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify composite depends on precomp
        XCTAssertEqual(graph["composite"]?.dependencies, ["precomp"],
                       "Composite pass should depend on precomp (the final pass from buildGameModeGraph)")

        // Verify the dependency chain is correct
        let sortedPasses = try! topologicalSortGraph(graph: graph)
        let order = sortedPasses.map(\.id)

        // Precomp must come before composite
        guard let precompIndex = order.firstIndex(of: "precomp"),
              let compositeIndex = order.firstIndex(of: "composite")
        else {
            XCTFail("Both precomp and composite should be in the sorted order")
            return
        }

        XCTAssertTrue(precompIndex < compositeIndex,
                      "Precomp must come before composite in topological order")
    }

    func testUpdateRenderingSystem_CompositePassIsLastInTopologicalOrder() {
        // Test with grid mode
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        var (graph, preCompID) = buildGameModeGraph()

        // Add composite pass
        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Sort the graph
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        // Verify composite is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "composite",
                       "Composite should be the last pass in the render graph")
    }

    func testUpdateRenderingSystem_CompositeDependsOnCorrectFinalPassInAllRenderModes() {
        // Test both environment and grid modes to ensure composite always depends on the correct final pass

        let modes: [(Bool, String)] = [
            (true, "environment"),
            (false, "grid"),
        ]

        for (useEnvironment, description) in modes {
            renderInfo.immersionStyle = .none
            renderEnvironment = useEnvironment

            var (graph, preCompID) = buildGameModeGraph()

            // Add composite pass
            let compositePass = RenderPass(
                id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
            )
            graph[compositePass.id] = compositePass

            // Verify composite depends on the returned preCompID
            XCTAssertEqual(graph["composite"]?.dependencies, [preCompID],
                           "Composite should depend on '\(preCompID)' in \(description) mode")

            // Verify topological ordering
            let sortedPasses = try! topologicalSortGraph(graph: graph)
            let order = sortedPasses.map(\.id)

            guard let finalPassIndex = order.firstIndex(of: preCompID),
                  let compositeIndex = order.firstIndex(of: "composite")
            else {
                XCTFail("Both final pass '\(preCompID)' and composite should exist in \(description) mode")
                continue
            }

            XCTAssertTrue(finalPassIndex < compositeIndex,
                          "Final pass '\(preCompID)' should come before composite in \(description) mode")
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

    func testUpdateRenderingSystem_FullWorkflowWithEnvironmentMode() {
        // Simulate the full UpdateRenderingSystem workflow
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        // This simulates what UpdateRenderingSystem does
        var (graph, preCompID) = buildGameModeGraph()

        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify the entire graph is valid
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["environment"], "Environment mode should have environment pass")
        XCTAssertEqual(sortedPasses.last?.id, "composite", "Composite should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["environment", "shadow", "model", "lightPass", "precomp", "composite"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_FullWorkflowWithGridMode() {
        // Simulate the full UpdateRenderingSystem workflow
        renderInfo.immersionStyle = .none
        renderEnvironment = false

        // This simulates what UpdateRenderingSystem does
        var (graph, preCompID) = buildGameModeGraph()

        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify the entire graph is valid
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["grid"], "Grid mode should have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "composite", "Composite should be the final pass")

        // Verify all expected passes are present
        let expectedPasses = ["grid", "shadow", "model", "lightPass", "precomp", "composite"]
        for passID in expectedPasses {
            XCTAssertNotNil(graph[passID], "Graph should contain '\(passID)' pass")
        }
    }

    func testUpdateRenderingSystem_GraphTopologicalOrderIsConsistent() {
        // Verify that multiple calls produce consistent topological ordering

        renderInfo.immersionStyle = .none
        renderEnvironment = true

        var (graph1, preCompID1) = buildGameModeGraph()
        let compositePass1 = RenderPass(
            id: "composite", dependencies: [preCompID1], execute: RenderPasses.compositeExecution
        )
        graph1[compositePass1.id] = compositePass1

        var (graph2, preCompID2) = buildGameModeGraph()
        let compositePass2 = RenderPass(
            id: "composite", dependencies: [preCompID2], execute: RenderPasses.compositeExecution
        )
        graph2[compositePass2.id] = compositePass2

        let sorted1 = try! topologicalSortGraph(graph: graph1)
        let sorted2 = try! topologicalSortGraph(graph: graph2)

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
            ("precomp", "composite"),
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
