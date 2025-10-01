
//
//  GraphBuilder.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import Metal

enum GraphError: Error {
    case cycleDetected(String)
}

public struct RenderPass {
    public let id: String
    var dependencies: [String]
    var execute: ((MTLCommandBuffer) -> Void)?

    public init(id: String, dependencies: [String], execute: ((MTLCommandBuffer) -> Void)?) {
        self.id = id
        self.dependencies = dependencies
        self.execute = execute
    }
}

public func executeGraph(
    _: [String: RenderPass], _ sortedPasses: [RenderPass], _ commandBuffer: MTLCommandBuffer
) {
    for pass in sortedPasses {
        pass.execute?(commandBuffer)
    }
}

// Creates a Directed Acyclic (non-cyclical) Graph
public func topologicalSortGraph(graph: [String: RenderPass]) throws -> [RenderPass] {
    var sortedPasses = [RenderPass]()
    var visited = Set<String>()
    var visiting = Set<String>() // Tracks nodes in the current recursion stack

    func visit(_ pass: RenderPass) throws {
        if visiting.contains(pass.id) {
            throw GraphError.cycleDetected("Cycle detected at node \(pass.id)")
        }
        if visited.contains(pass.id) {
            return
        }

        visiting.insert(pass.id)

        for dependency in pass.dependencies {
            if let depPass = graph[dependency] {
                try visit(depPass)
            }
        }

        visiting.remove(pass.id)
        visited.insert(pass.id)
        sortedPasses.append(pass)
    }

    for (_, pass) in graph {
        try visit(pass)
    }

    return sortedPasses
}
