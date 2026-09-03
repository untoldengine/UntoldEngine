//
//  UpdateARRenderingSystemTest.swift
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

final class UpdateARRenderingSystemTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - UpdateARRenderingSystem AR Mode Tests

    func testUpdateARRenderingSystem_ARModeConfiguresRenderGraphCorrectly() throws {
        // Set up AR mode
        renderInfo.immersionStyle = .ar

        // Create a command buffer and render pass descriptor for AR
        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        // Build the render graph using the same logic as UpdateARRenderingSystem
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify that AR mode does not create environment or grid passes
        XCTAssertNil(graph["environment"], "AR mode should not create environment pass")
        XCTAssertNil(graph["grid"], "AR mode should not create grid pass")

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify shadow has no base pass dependency in AR mode
        XCTAssertEqual(graph["shadow"]?.dependencies, [],
                       "Shadow should have no dependencies in AR mode")

        // Verify the graph can be topologically sorted
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")
    }

    func testUpdateARRenderingSystem_ARModeHasNoBasePass() throws {
        // Set up AR mode
        renderInfo.immersionStyle = .ar

        let (graph, _) = try buildGameModeGraph()

        // Verify that AR mode has no base pass (no environment, no grid)
        XCTAssertNil(graph["environment"], "AR mode should not create environment pass")
        XCTAssertNil(graph["grid"], "AR mode should not create grid pass")

        // Verify shadow pass has no dependencies (no base pass to depend on)
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertEqual(graph["shadow"]?.dependencies.count, 0,
                       "Shadow pass should have no dependencies in AR mode")
    }

    func testUpdateARRenderingSystem_ARModeBehavesLikePassthrough() throws {
        // Set up AR mode
        renderInfo.immersionStyle = .ar

        let (arGraph, arFinalPassID) = try buildGameModeGraph()

        // Set up passthrough mode for comparison
        renderInfo.immersionStyle = .mixed

        let (passthroughGraph, passthroughFinalPassID) = try buildGameModeGraph()

        // Verify both modes produce the same graph structure
        XCTAssertEqual(arGraph.count, passthroughGraph.count,
                       "AR and passthrough should have the same number of passes")

        // Verify both have no base pass
        XCTAssertNil(arGraph["environment"], "AR should not have environment pass")
        XCTAssertNil(passthroughGraph["environment"], "Passthrough should not have environment pass")
        XCTAssertNil(arGraph["grid"], "AR should not have grid pass")
        XCTAssertNil(passthroughGraph["grid"], "Passthrough should not have grid pass")

        // Verify both have the same final pass
        XCTAssertEqual(arFinalPassID, passthroughFinalPassID,
                       "AR and passthrough should have the same final pass")

        // Verify shadow dependencies are the same
        XCTAssertEqual(arGraph["shadow"]?.dependencies, passthroughGraph["shadow"]?.dependencies,
                       "AR and passthrough should have the same shadow dependencies")
    }

    // MARK: - Final Pass Tests

    func testUpdateARRenderingSystem_OutputTransformIsTheFinalPass() throws {
        // Test with AR mode
        renderInfo.immersionStyle = .ar

        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify final pass is outputTransform
        XCTAssertEqual(finalPassID, "outputTransform", "buildGameModeGraph should return 'outputTransform' as final pass ID")

        // Verify the dependency chain is correct
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in topological order")
    }

    func testUpdateARRenderingSystem_OutputTransformIsLastInTopologicalOrder() throws {
        // Test with AR mode
        renderInfo.immersionStyle = .ar

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the render graph")
    }

    func testUpdateARRenderingSystem_ARModeIncludedInAllModes() throws {
        // Test that AR mode is properly handled alongside all other immersion modes

        let modes: [(UntoldImmersionMode, String)] = [
            (.none, "none"),
            (.full, "full"),
            (.mixed, "mixed"),
            (.ar, "ar"),
        ]

        for (mode, description) in modes {
            renderInfo.immersionStyle = mode

            let (graph, finalPassID) = try buildGameModeGraph()

            // Verify outputTransform is the final pass for all modes
            XCTAssertEqual(finalPassID, "outputTransform",
                           "Final pass should be 'outputTransform' in \(description) mode")

            // Verify topological ordering
            let sortedPasses = try topologicalSortGraph(graph: graph)

            XCTAssertEqual(sortedPasses.last?.id, finalPassID,
                           "outputTransform should be the last pass in \(description) mode")
        }
    }

    // MARK: - Integration Tests

    func testUpdateARRenderingSystem_FullWorkflowWithARMode() throws {
        // Simulate the full UpdateARRenderingSystem workflow
        renderInfo.immersionStyle = .ar

        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        // This simulates what UpdateARRenderingSystem does
        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertNil(graph["environment"], "AR mode should not have environment pass")
        XCTAssertNil(graph["grid"], "AR mode should not have grid pass")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")
    }

    func testUpdateARRenderingSystem_ARModeGraphTopologicalConstraints() throws {
        // Set up AR mode
        renderInfo.immersionStyle = .ar
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)
        let order = sortedPasses.map(\.id)

        // Verify topological constraints for AR mode
        assertTopologicalConstraints(order: order, constraints: [
            ("shadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    func testUpdateARRenderingSystem_ARModeWithPostProcessing() throws {
        // Set up AR mode
        renderInfo.immersionStyle = .ar
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let (graph, _) = try buildGameModeGraph()

        // Verify post-processing passes exist
        XCTAssertNotNil(graph["depthOfField"], "Depth of field pass should exist")
        XCTAssertNotNil(graph["chromatic"], "Chromatic aberration pass should exist")
        XCTAssertNotNil(graph["bloomThreshold"], "Bloom threshold pass should exist")
        XCTAssertNotNil(graph["bloomComposite"], "Bloom composite pass should exist")
        XCTAssertNotNil(graph["vignette"], "Vignette pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify post-processing chain dependencies
        let sortedPasses = try topologicalSortGraph(graph: graph)
        let order = sortedPasses.map(\.id)

        assertTopologicalConstraints(order: order, constraints: [
            ("lightPass", "depthOfField"),
            ("depthOfField", "chromatic"),
            ("chromatic", "bloomThreshold"),
            ("bloomComposite", "vignette"),
            ("vignette", "precomp"),
            ("precomp", "look"),
            ("look", "outputTransform"),
        ])
    }

    // MARK: - Comparison Tests

    func testUpdateARRenderingSystem_ARVsNoneModeBasePassDifference() throws {
        // Test AR mode
        renderInfo.immersionStyle = .ar
        let (arGraph, _) = try buildGameModeGraph()

        // Test none mode (should have environment or grid)
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false // sky is the default non-IBL background; opt into grid explicitly
        let (noneGraph, _) = try buildGameModeGraph()

        // AR should have no base pass
        XCTAssertNil(arGraph["environment"], "AR mode should not have environment pass")
        XCTAssertNil(arGraph["grid"], "AR mode should not have grid pass")

        // None mode should have grid pass (since renderEnvironment is false)
        XCTAssertNotNil(noneGraph["grid"], "None mode should have grid pass when environment is disabled")

        // AR shadow should have no dependencies, none mode shadow should depend on grid
        XCTAssertEqual(arGraph["shadow"]?.dependencies, [],
                       "AR shadow should have no dependencies")
        XCTAssertEqual(noneGraph["shadow"]?.dependencies, ["grid"],
                       "None mode shadow should depend on grid")
    }

    func testUpdateARRenderingSystem_BasePassModeEnum() throws {
        // Verify BasePassMode correctly identifies AR mode

        renderInfo.immersionStyle = .ar
        let (graph, _) = try buildGameModeGraph()

        // In AR mode, no base pass should be created
        XCTAssertNil(graph["environment"], "BasePassMode.ar should not create environment pass")
        XCTAssertNil(graph["grid"], "BasePassMode.ar should not create grid pass")

        // Shadow should be the first pass in the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertEqual(sortedPasses.first?.id, "shadow",
                       "Shadow should be the first pass when no base pass exists")
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
