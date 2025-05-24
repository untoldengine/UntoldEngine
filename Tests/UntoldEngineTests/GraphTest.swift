//
//  GraphTest.swift
//
//
//  Created by Harold Serrano on 5/24/25.
//

import Foundation
@testable import UntoldEngine
import XCTest

final class GraphTest: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    func testGraphLogicalOrder() {
        // build a render graph
        var graph = [String: RenderPass]()

        let nodeA = RenderPass(id: "nodeA", dependencies: [], execute: nil)
        graph[nodeA.id] = nodeA

        let nodeB = RenderPass(id: "nodeB", dependencies: [nodeA.id], execute: nil)
        graph[nodeB.id] = nodeB

        let nodeC = RenderPass(id: "nodeC", dependencies: [nodeB.id], execute: nil)
        graph[nodeC.id] = nodeC
        // sorted it
        let sortedPasses = try! topologicalSortGraph(graph: graph)

        let expectedOrder = [nodeA.id, nodeB.id, nodeC.id]
        var actualOrder: [String] = []

        for node in sortedPasses {
            actualOrder.append(node.id)
        }

        XCTAssertEqual(actualOrder, expectedOrder, "The nodes are not in the expected order.")
    }

    func testGraphWithBranchingDependency() {
        var graph = [String: RenderPass]()

        let nodeA = RenderPass(id: "nodeA", dependencies: [], execute: nil)
        let nodeB = RenderPass(id: "nodeB", dependencies: ["nodeA"], execute: nil)
        let nodeC = RenderPass(id: "nodeC", dependencies: ["nodeA"], execute: nil)
        let nodeD = RenderPass(id: "nodeD", dependencies: ["nodeB", "nodeC"], execute: nil)

        [nodeA, nodeB, nodeC, nodeD].forEach { graph[$0.id] = $0 }

        let sorted = try! topologicalSortGraph(graph: graph)

        let actualOrder = sorted.map(\.id)

        // nodeA must come before nodeB and nodeC
        XCTAssertTrue(actualOrder.firstIndex(of: "nodeA")! < actualOrder.firstIndex(of: "nodeB")!)
        XCTAssertTrue(actualOrder.firstIndex(of: "nodeA")! < actualOrder.firstIndex(of: "nodeC")!)
        // nodeB and nodeC must come before nodeD
        XCTAssertTrue(actualOrder.firstIndex(of: "nodeB")! < actualOrder.firstIndex(of: "nodeD")!)
        XCTAssertTrue(actualOrder.firstIndex(of: "nodeC")! < actualOrder.firstIndex(of: "nodeD")!)
    }

    func testGraphWithSharedDependency() {
        var graph = [String: RenderPass]()

        let nodeA = RenderPass(id: "nodeA", dependencies: [], execute: nil)
        let nodeB = RenderPass(id: "nodeB", dependencies: ["nodeA"], execute: nil)
        let nodeC = RenderPass(id: "nodeC", dependencies: ["nodeB"], execute: nil)
        let nodeD = RenderPass(id: "nodeD", dependencies: ["nodeA"], execute: nil)

        [nodeA, nodeB, nodeC, nodeD].forEach { graph[$0.id] = $0 }

        let sorted = try! topologicalSortGraph(graph: graph)
        let actualOrder = sorted.map(\.id)

        // Validate partial order constraints
        let indexA = actualOrder.firstIndex(of: "nodeA")!
        let indexB = actualOrder.firstIndex(of: "nodeB")!
        let indexC = actualOrder.firstIndex(of: "nodeC")!
        let indexD = actualOrder.firstIndex(of: "nodeD")!

        XCTAssertTrue(indexA < indexB, "nodeA must come before nodeB")
        XCTAssertTrue(indexB < indexC, "nodeB must come before nodeC")
        XCTAssertTrue(indexA < indexD, "nodeA must come before nodeD")
    }

    func testGraphWithNoDependencies() {
        let nodeA = RenderPass(id: "nodeA", dependencies: [], execute: nil)
        let nodeB = RenderPass(id: "nodeB", dependencies: [], execute: nil)
        let nodeC = RenderPass(id: "nodeC", dependencies: [], execute: nil)

        let graph = [nodeA.id: nodeA, nodeB.id: nodeB, nodeC.id: nodeC]

        let sorted = try! topologicalSortGraph(graph: graph)
        let actualOrder = sorted.map(\.id)

        // The order doesn't matter as long as all nodes are included
        XCTAssertEqual(Set(actualOrder), Set(["nodeA", "nodeB", "nodeC"]))
    }

    func testCycleDetection() {
        let nodeA = RenderPass(id: "nodeA", dependencies: ["nodeC"], execute: nil)
        let nodeB = RenderPass(id: "nodeB", dependencies: ["nodeA"], execute: nil)
        let nodeC = RenderPass(id: "nodeC", dependencies: ["nodeB"], execute: nil)

        let graph = [nodeA.id: nodeA, nodeB.id: nodeB, nodeC.id: nodeC]

        XCTAssertThrowsError(try topologicalSortGraph(graph: graph)) { error in
            XCTAssertTrue(error is GraphError)
            if case let GraphError.cycleDetected(node) = error {
                print("Cycle correctly detected at: \(node)")
            } else {
                XCTFail("Expected a cycleDetected error")
            }
        }
    }

    func testGraphWithSharedDependency_usingHelper() {
        var graph = [String: RenderPass]()

        let nodeA = RenderPass(id: "nodeA", dependencies: [], execute: nil)
        let nodeB = RenderPass(id: "nodeB", dependencies: ["nodeA"], execute: nil)
        let nodeC = RenderPass(id: "nodeC", dependencies: ["nodeB"], execute: nil)
        let nodeD = RenderPass(id: "nodeD", dependencies: ["nodeA"], execute: nil)

        [nodeA, nodeB, nodeC, nodeD].forEach { graph[$0.id] = $0 }

        let sorted = try! topologicalSortGraph(graph: graph)
        let actualOrder = sorted.map(\.id)

        assertTopologicalConstraints(order: actualOrder, constraints: [
            ("nodeA", "nodeB"),
            ("nodeB", "nodeC"),
            ("nodeA", "nodeD"),
        ])
    }

    func assertTopologicalConstraints(order: [String], constraints: [(before: String, after: String)], file: StaticString = #file, line: UInt = #line) {
        for (before, after) in constraints {
            guard let beforeIndex = order.firstIndex(of: before),
                  let afterIndex = order.firstIndex(of: after)
            else {
                XCTFail("Missing node(s): \(before) or \(after)", file: file, line: line)
                continue
            }

            XCTAssertTrue(beforeIndex < afterIndex, "\(before) should come before \(after)", file: file, line: line)
        }
    }
}
