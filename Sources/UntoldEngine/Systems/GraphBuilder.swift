
//
//  GraphBuilder.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/28/24.
//

import Foundation
import Metal

struct RenderPass {
  let id: String
  var dependencies: [String]
  var execute: (MTLCommandBuffer) -> Void

  init(id: String, dependencies: [String], execute: @escaping (MTLCommandBuffer) -> Void) {
    self.id = id
    self.dependencies = dependencies
    self.execute = execute
  }
}

func executeGraph(
  _ graph: [String: RenderPass], _ sortedPasses: [RenderPass], _ commandBuffer: MTLCommandBuffer
) {

  for pass in sortedPasses {
    pass.execute(commandBuffer)
  }

}

func topologicalSortGraph(graph: [String: RenderPass]) -> [RenderPass] {
  var sortedPasses = [RenderPass]()  // This array will hold the sorted nodes (render passes).
  var visited = Set<String>()  // A set to track which nodes have been visited.

  // Nested function to perform depth-first search from a given node.
  func visit(_ pass: RenderPass) {
    if visited.contains(pass.id) {
      return  // If the node has already been visited, return immediately.
    }

    visited.insert(pass.id)  // Mark the node as visited.

    // Visit all the dependencies of the current node before adding the node itself.
    for dependency in pass.dependencies {
      if let depPass = graph[dependency] {
        visit(depPass)  // Recursive call for each dependency.
      }
    }

    // After visiting dependencies, add the current node to the sorted list.
    sortedPasses.append(pass)
  }

  // Iterate over each node in the graph and apply the visit function.
  for (_, pass) in graph {
    visit(pass)
  }

  //return sorted passes
  return sortedPasses
}
