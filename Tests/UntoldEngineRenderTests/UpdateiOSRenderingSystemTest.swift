//
//  UpdateiOSRenderingSystemTest.swift
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

final class UpdateiOSRenderingSystemTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // MARK: - iOS Rendering System Tests

    func testUpdateiOSRenderingSystem_iOSModeConfiguresRenderGraphCorrectly() throws {
        // Set up iOS mode (none immersion style)
        renderInfo.immersionStyle = .none

        // Build the render graph
        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify essential passes exist
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertNotNil(graph["model"], "Model pass should exist")
        XCTAssertNotNil(graph["lightPass"], "Light pass should exist")
        XCTAssertNotNil(graph["precomp"], "Pre-composite pass should exist")
        XCTAssertNotNil(graph["look"], "Look pass should exist")
        XCTAssertNotNil(graph["outputTransform"], "Output transform pass should exist")

        // Verify the final pass ID is correct
        XCTAssertEqual(finalPassID, "outputTransform", "Final pass ID should be outputTransform")

        // Verify the graph can be topologically sorted
        let sortedPasses = try topologicalSortGraph(graph: graph)
        XCTAssertTrue(sortedPasses.count > 0, "Sorted passes should not be empty")

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the sorted order")
    }

    func testUpdateiOSRenderingSystem_iOSModeHasBasePass() throws {
        // Set up iOS mode
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false // sky is the default non-IBL background; opt into grid explicitly

        let (graph, _) = try buildGameModeGraph()

        // iOS mode should have a base pass (grid when environment is disabled)
        XCTAssertNotNil(graph["grid"], "iOS mode should have grid pass when environment is disabled")

        // Verify shadow pass depends on the base pass
        XCTAssertNotNil(graph["shadow"], "Shadow pass should exist")
        XCTAssertEqual(graph["shadow"]?.dependencies, ["grid"],
                       "Shadow pass should depend on grid in iOS mode")
    }

    func testUpdateiOSRenderingSystem_iOSModeWithEnvironment() throws {
        // Set up iOS mode with environment
        renderInfo.immersionStyle = .none
        renderEnvironment = true

        let (graph, _) = try buildGameModeGraph()

        // Should have environment pass
        XCTAssertNotNil(graph["environment"], "iOS mode with environment should have environment pass")

        // Shadow should depend on environment
        XCTAssertEqual(graph["shadow"]?.dependencies, ["environment"],
                       "Shadow should depend on environment when enabled")
    }

    // MARK: - Final Pass Tests

    func testUpdateiOSRenderingSystem_OutputTransformIsTheFinalPass() throws {
        // Test with iOS mode
        renderInfo.immersionStyle = .none

        let (graph, finalPassID) = try buildGameModeGraph()

        // Verify final pass is outputTransform
        XCTAssertEqual(finalPassID, "outputTransform", "buildGameModeGraph should return 'outputTransform' as final pass ID")

        // Verify the dependency chain is correct
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in topological order")
    }

    func testUpdateiOSRenderingSystem_OutputTransformIsLastInTopologicalOrder() throws {
        // Test with iOS mode
        renderInfo.immersionStyle = .none

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)

        // Verify outputTransform is the last pass
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform",
                       "outputTransform should be the last pass in the render graph")
    }

    func testUpdateiOSRenderingSystem_iOSModeWithPostProcessing() throws {
        // Set up iOS mode
        renderInfo.immersionStyle = .none
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

    func testUpdateiOSRenderingSystem_iOSModeGraphTopologicalConstraints() throws {
        // Set up iOS mode
        renderInfo.immersionStyle = .none
        DepthOfFieldParams.shared.enabled = true
        defer { DepthOfFieldParams.shared.enabled = false }

        let (graph, _) = try buildGameModeGraph()

        // Sort the graph
        let sortedPasses = try topologicalSortGraph(graph: graph)
        let order = sortedPasses.map(\.id)

        // Verify topological constraints for iOS mode
        assertTopologicalConstraints(order: order, constraints: [
            ("shadow", "batchedShadow"),
            ("batchedShadow", "pointShadow"),
            ("pointShadow", "spotShadow"),
            ("spotShadow", "model"),
            ("model", "lightPass"),
            ("lightPass", "depthOfField"),
        ])
    }

    // MARK: - Integration Tests

    func testUpdateiOSRenderingSystem_FullWorkflowWithiOSMode() throws {
        // Simulate the full rendering workflow for iOS
        renderInfo.immersionStyle = .none

        guard (renderInfo.commandQueue.makeCommandBuffer()) != nil else {
            XCTFail("Failed to create command buffer")
            return
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderer.metalView.currentDrawable?.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear

        let (graph, _) = try buildGameModeGraph()

        // Verify the entire graph is valid
        let sortedPasses = try topologicalSortGraph(graph: graph)

        XCTAssertTrue(sortedPasses.count > 0, "Should have a valid sorted pass list")
        XCTAssertEqual(sortedPasses.last?.id, "outputTransform", "outputTransform should be the final pass")
    }

    // MARK: - Comparison Tests

    func testUpdateiOSRenderingSystem_iOSVsARModeDifference() throws {
        // Test iOS mode
        renderInfo.immersionStyle = .none
        renderEnvironment = false
        renderSkyBackground = false // sky is the default non-IBL background; opt into grid explicitly
        let (iosGraph, _) = try buildGameModeGraph()

        // Test AR mode
        renderInfo.immersionStyle = .ar
        let (arGraph, _) = try buildGameModeGraph()

        // iOS should have base pass (grid)
        XCTAssertNotNil(iosGraph["grid"], "iOS mode should have grid pass")

        // AR should have no base pass
        XCTAssertNil(arGraph["environment"], "AR mode should not have environment pass")
        XCTAssertNil(arGraph["grid"], "AR mode should not have grid pass")

        // iOS shadow should depend on grid, AR shadow should have no dependencies
        XCTAssertEqual(iosGraph["shadow"]?.dependencies, ["grid"],
                       "iOS shadow should depend on grid")
        XCTAssertEqual(arGraph["shadow"]?.dependencies, [],
                       "AR shadow should have no dependencies")
    }

    func testUpdateiOSRenderingSystem_iOSVsMacOSModeSimilarity() throws {
        // Test iOS mode (.none)
        renderInfo.immersionStyle = .none
        renderEnvironment = true
        let (iosGraph, iosPreCompID) = try buildGameModeGraph()

        // macOS typically also uses .none, so they should be similar
        let (macosGraph, macosPreCompID) = try buildGameModeGraph()

        // Both should have the same structure
        XCTAssertEqual(iosGraph.count, macosGraph.count,
                       "iOS and macOS should have the same number of passes")

        // Both should have environment pass
        XCTAssertNotNil(iosGraph["environment"], "iOS should have environment pass")
        XCTAssertNotNil(macosGraph["environment"], "macOS should have environment pass")

        // Both should have the same final pass
        XCTAssertEqual(iosPreCompID, macosPreCompID,
                       "iOS and macOS should have the same final pass")
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
