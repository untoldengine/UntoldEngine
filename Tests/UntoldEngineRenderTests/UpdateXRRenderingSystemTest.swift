//
//  UpdateXRRenderingSystemTest.swift
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

final class UpdateXRRenderingSystemTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - UpdateXRRenderingSystem XR Full Immersion Tests

    func testUpdateXRRenderingSystem_FullImmersionConfiguresRenderGraphCorrectly() throws {
        // Set up XR full immersion mode
        renderInfo.immersionStyle = .full
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        // Create a command buffer and render pass descriptor for XR
        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        // Build the render graph using the same logic as UpdateXRRenderingSystem
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify that full immersion mode creates the environment pass
        XCTAssertNotNil(graph["environment"], "Full immersion mode should create environment pass")
        XCTAssertNil(graph["grid"], "Full immersion mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow depends on environment in full immersion
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment in full immersion mode")

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

    func testUpdateXRRenderingSystem_FullImmersionUsesEnvironmentPass() throws {
        // Set up XR full immersion mode
        renderInfo.immersionStyle = .full

        let (graph, _) = try buildGameModeGraph()

        // Verify that full immersion uses environment, not grid or none
        XCTAssertNotNil(graph["environment"], "Full immersion should use environment pass")
        XCTAssertNil(graph["grid"], "Full immersion should not use grid pass")

        // Verify the environment pass has no dependencies (it's the base)
        XCTAssertEqual(graph["environment"]?.dependencies.count, 0,
                       "Environment pass should have no dependencies")
    }

    // MARK: - UpdateXRRenderingSystem XR Passthrough Tests

    func testUpdateXRRenderingSystem_PassthroughConfiguresRenderGraphCorrectly() throws {
        // Set up XR passthrough mode
        renderInfo.immersionStyle = .mixed

        // Create a command buffer and render pass descriptor for XR
        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        // Build the render graph using the same logic as UpdateXRRenderingSystem
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify that passthrough mode does not create environment or grid passes
        XCTAssertNil(graph["environment"], "Passthrough mode should not create environment pass")
        XCTAssertNil(graph["grid"], "Passthrough mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow has no base pass dependency in passthrough mode
        XCTAssertEqual(graph["shadow"]?.dependencies, [],
                       "Shadow should have no dependencies in passthrough mode")

        // Verify the graph can be topologically sorted
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")
    }

    func testUpdateXRRenderingSystem_PassthroughHasNoBasePass() throws {
        // Set up XR passthrough mode
        renderInfo.immersionStyle = .mixed

        let (graph, _) = try buildGameModeGraph()

        // Verify that passthrough mode has no base pass (no environment, no grid)
        XCTAssertNil(graph["environment"], "Passthrough mode should not create environment pass")
        XCTAssertNil(graph["grid"], "Passthrough mode should not create grid pass")

        // Verify shadow pass has no dependencies (no base pass to depend on)
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertEqual(graph["shadow"]?.dependencies.count, 0,
                       "Shadow pass should have no dependencies in passthrough mode")
    }

    // MARK: - Final Pass Tests

    func testUpdateXRRenderingSystem_OutputTransformIsTheFinalPass() throws {
        // Test with full immersion
        renderInfo.immersionStyle = .full

        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify final pass is outputTransform
        XCTAssertEqual(finalPassID, "outputTransform", "buildGameModeGraph should return 'outputTransform' as final pass ID")

        // Verify the dependency chain is correct
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in topological order")
    }

    func testUpdateXRRenderingSystem_OutputTransformIsLastInTopologicalOrder() throws {
        // Test with passthrough mode
        renderInfo.immersionStyle = .mixed

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the render graph")
    }

    func testUpdateXRRenderingSystem_OutputTransformIsCorrectFinalPassInAllModes() throws {
        // Test in all immersion modes to ensure outputTransform is the final pass

        let modes: [(UntoldImmersionMode, String)] = [
            (.none, "none"),
            (.full, "full"),
            (.mixed, "mixed"),
        ]

        for (mode, description) in modes {
            renderInfo.immersionStyle = mode

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

    // MARK: - Integration Tests

    func testUpdateXRRenderingSystem_FullWorkflowWithFullImmersion() throws {
        // Simulate the full UpdateXRRenderingSystem workflow
        renderInfo.immersionStyle = .full

        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // This simulates what UpdateXRRenderingSystem does
        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNotNil(graph["environment"], "Full immersion should have environment pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")
    }

    func testUpdateXRRenderingSystem_FullWorkflowWithPassthrough() throws {
        // Simulate the full UpdateXRRenderingSystem workflow
        renderInfo.immersionStyle = .mixed

        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // This simulates what UpdateXRRenderingSystem does
        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNil(graph["environment"], "Passthrough should not have environment pass")
        XCTAssertNil(graph["grid"], "Passthrough should not have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")
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
