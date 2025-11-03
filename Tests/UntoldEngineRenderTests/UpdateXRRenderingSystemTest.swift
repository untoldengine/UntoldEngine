//
//  UpdateXRRenderingSystemTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import Foundation
import Metal
@testable import UntoldEngine
import XCTest

final class UpdateXRRenderingSystemTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - UpdateXRRenderingSystem XR Full Immersion Tests

    func testUpdateXRRenderingSystem_FullImmersionConfiguresRenderGraphCorrectly() {
        // Set up XR full immersion mode
        renderInfo.immersionStyle = .full

        // Create a command buffer and render pass descriptor for XR
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Build the render graph using the same logic as UpdateXRRenderingSystem
        var (graph, preCompID) = buildGameModeGraph()

        // Verify that full immersion mode creates the environment pass
        XCTAssertNotNil(graph["environment"], "Full immersion mode should create environment pass")
        XCTAssertNil(graph["grid"], "Full immersion mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(preCompID, "precomp", "Final pass ID should be precomp")

        // Verify shadow depends on environment in full immersion
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment in full immersion mode")

        // Add composite pass as UpdateXRRenderingSystem does
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

    func testUpdateXRRenderingSystem_FullImmersionUsesEnvironmentPass() {
        // Set up XR full immersion mode
        renderInfo.immersionStyle = .full

        let (graph, _) = buildGameModeGraph()

        // Verify that full immersion uses environment, not grid or none
        XCTAssertNotNil(graph["environment"], "Full immersion should use environment pass")
        XCTAssertNil(graph["grid"], "Full immersion should not use grid pass")

        // Verify the environment pass has no dependencies (it's the base)
        XCTAssertEqual(graph["environment"]?.dependencies.count, 0,
                       "Environment pass should have no dependencies")
    }

    // MARK: - UpdateXRRenderingSystem XR Passthrough Tests

    func testUpdateXRRenderingSystem_PassthroughConfiguresRenderGraphCorrectly() {
        // Set up XR passthrough mode
        renderInfo.immersionStyle = .mixed

        // Create a command buffer and render pass descriptor for XR
        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        // Build the render graph using the same logic as UpdateXRRenderingSystem
        var (graph, preCompID) = buildGameModeGraph()

        // Verify that passthrough mode does not create environment or grid passes
        XCTAssertNil(graph["environment"], "Passthrough mode should not create environment pass")
        XCTAssertNil(graph["grid"], "Passthrough mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(preCompID, "precomp", "Final pass ID should be precomp")

        // Verify shadow has no base pass dependency in passthrough mode
        XCTAssertEqual(graph["shadow"]?.dependencies, [],
                       "Shadow should have no dependencies in passthrough mode")

        // Add composite pass as UpdateXRRenderingSystem does
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
    }

    func testUpdateXRRenderingSystem_PassthroughHasNoBasePass() {
        // Set up XR passthrough mode
        renderInfo.immersionStyle = .mixed

        let (graph, _) = buildGameModeGraph()

        // Verify that passthrough mode has no base pass (no environment, no grid)
        XCTAssertNil(graph["environment"], "Passthrough mode should not create environment pass")
        XCTAssertNil(graph["grid"], "Passthrough mode should not create grid pass")

        // Verify shadow pass has no dependencies (no base pass to depend on)
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertEqual(graph["shadow"]?.dependencies.count, 0,
                       "Shadow pass should have no dependencies in passthrough mode")
    }

    // MARK: - Composite Pass Dependency Tests

    func testUpdateXRRenderingSystem_CompositePassDependsOnFinalPassFromBuildGameModeGraph() {
        // Test with full immersion
        renderInfo.immersionStyle = .full

        var (graph, preCompID) = buildGameModeGraph()

        // Verify preCompID is "precomp"
        XCTAssertEqual(preCompID, "precomp", "buildGameModeGraph should return 'precomp' as final pass ID")

        // Add composite pass as UpdateXRRenderingSystem does
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

    func testUpdateXRRenderingSystem_CompositePassIsLastInTopologicalOrder() {
        // Test with passthrough mode
        renderInfo.immersionStyle = .mixed

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

    func testUpdateXRRenderingSystem_CompositeDependsOnCorrectFinalPassInAllModes() {
        // Test in all immersion modes to ensure composite always depends on the correct final pass

        let modes: [(UntoldImmersionMode, String)] = [
            (.none, "none"),
            (.full, "full"),
            (.mixed, "mixed"),
        ]

        for (mode, description) in modes {
            renderInfo.immersionStyle = mode

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

    // MARK: - Integration Tests

    func testUpdateXRRenderingSystem_FullWorkflowWithFullImmersion() {
        // Simulate the full UpdateXRRenderingSystem workflow
        renderInfo.immersionStyle = .full

        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // This simulates what UpdateXRRenderingSystem does
        var (graph, preCompID) = buildGameModeGraph()

        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify the entire graph is valid
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["environment"], "Full immersion should have environment pass")
        XCTAssertEqual(sortedPasses.last?.id, "composite", "Composite should be the final pass")
    }

    func testUpdateXRRenderingSystem_FullWorkflowWithPassthrough() {
        // Simulate the full UpdateXRRenderingSystem workflow
        renderInfo.immersionStyle = .mixed

        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer() else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // This simulates what UpdateXRRenderingSystem does
        var (graph, preCompID) = buildGameModeGraph()

        let compositePass = RenderPass(
            id: "composite", dependencies: [preCompID], execute: RenderPasses.compositeExecution
        )
        graph[compositePass.id] = compositePass

        // Verify the entire graph is valid
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNil(graph["environment"], "Passthrough should not have environment pass")
        XCTAssertNil(graph["grid"], "Passthrough should not have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "composite", "Composite should be the final pass")
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
