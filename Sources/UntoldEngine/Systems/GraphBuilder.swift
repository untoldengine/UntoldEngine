
//
//  GraphBuilder.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal

enum GraphError: Error {
    case cycleDetected(String)
}

public enum RenderStage: String, CaseIterable, Sendable {
    case frameStart
    case beforeShadow
    case afterShadow
    case beforeOpaque
    case afterOpaqueDepth
    case afterOpaqueLighting
    case beforeTransparency
    case afterTransparency
    case beforePostProcess
    case afterPostProcess
    case beforeComposite
    case beforeLook
    case beforeOutput
    case frameEnd
}

public struct RenderGraphBuildContext: Sendable {
    public let viewport: SIMD2<Int>
    public let immersionStyle: UntoldImmersionMode
    public let currentEye: Int

    public init(
        viewport: SIMD2<Int>,
        immersionStyle: UntoldImmersionMode,
        currentEye: Int
    ) {
        self.viewport = viewport
        self.immersionStyle = immersionStyle
        self.currentEye = currentEye
    }
}

public struct RenderPassContext {
    public let commandBuffer: MTLCommandBuffer
    public let device: MTLDevice
    public let viewport: SIMD2<Int>
    public let colorFormat: MTLPixelFormat
    public let depthFormat: MTLPixelFormat
    public let immersionStyle: UntoldImmersionMode
    public let currentEye: Int
    public let resources: RenderResourceAccess
    public let computePipelines: ComputePipelineAccess

    public init(
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        viewport: SIMD2<Int>,
        colorFormat: MTLPixelFormat,
        depthFormat: MTLPixelFormat,
        immersionStyle: UntoldImmersionMode,
        currentEye: Int,
        resources: RenderResourceAccess = RenderResourceAccess(),
        computePipelines: ComputePipelineAccess = ComputePipelineAccess()
    ) {
        self.commandBuffer = commandBuffer
        self.device = device
        self.viewport = viewport
        self.colorFormat = colorFormat
        self.depthFormat = depthFormat
        self.immersionStyle = immersionStyle
        self.currentEye = currentEye
        self.resources = resources
        self.computePipelines = computePipelines
    }
}

public typealias RenderGraphPassExecution = (RenderPassContext) -> Void

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

private struct PendingRenderGraphPass {
    let id: String
    let dependencies: [String]
    let execute: RenderGraphPassExecution?
}

public struct RenderGraphBuilder {
    var graph: [String: RenderPass]
    private var pendingStagePasses: [RenderStage: [PendingRenderGraphPass]]

    public init(graph: [String: RenderPass] = [:]) {
        self.graph = graph
        pendingStagePasses = [:]
    }

    public mutating func addPass(
        id: String,
        dependencies: [String],
        execute: ((MTLCommandBuffer) -> Void)?
    ) {
        guard graph[id] == nil else {
            Logger.logWarning(message: "[RenderGraph] Duplicate pass id ignored: \(id)")
            return
        }
        graph[id] = RenderPass(id: id, dependencies: dependencies, execute: execute)
    }

    public mutating func addPass(
        id: String,
        stage: RenderStage,
        dependencies: [String] = [],
        execute: RenderGraphPassExecution?
    ) {
        guard graph[id] == nil else {
            Logger.logWarning(message: "[RenderGraph] Duplicate pass id ignored: \(id)")
            return
        }
        if pendingStagePasses.values.contains(where: { passes in passes.contains(where: { $0.id == id }) }) {
            Logger.logWarning(message: "[RenderGraph] Duplicate staged pass id ignored: \(id)")
            return
        }
        pendingStagePasses[stage, default: []].append(
            PendingRenderGraphPass(id: id, dependencies: dependencies, execute: execute)
        )
    }

    @discardableResult
    mutating func resolveStage(_ stage: RenderStage, after anchorPassID: String?) -> String? {
        guard let passes = pendingStagePasses.removeValue(forKey: stage), !passes.isEmpty else {
            return anchorPassID
        }

        var tail = anchorPassID
        for pass in passes {
            var dependencies = pass.dependencies
            if let tail, !dependencies.contains(tail) {
                dependencies.append(tail)
            }

            let execution = pass.execute.map { execute in
                { commandBuffer in
                    execute(makeRenderPassContext(commandBuffer: commandBuffer))
                }
            }

            addPass(id: pass.id, dependencies: dependencies, execute: execution)
            tail = pass.id
        }

        return tail
    }

    public func build() throws -> [String: RenderPass] {
        try validateGraph(graph)
        return graph
    }
}

func makeRenderGraphBuildContext() -> RenderGraphBuildContext {
    RenderGraphBuildContext(
        viewport: SIMD2<Int>(
            Int(renderInfo.viewPort?.x ?? 0),
            Int(renderInfo.viewPort?.y ?? 0)
        ),
        immersionStyle: renderInfo.immersionStyle,
        currentEye: renderInfo.currentEye
    )
}

func makeRenderPassContext(commandBuffer: MTLCommandBuffer) -> RenderPassContext {
    RenderPassContext(
        commandBuffer: commandBuffer,
        device: renderInfo.device,
        viewport: SIMD2<Int>(
            Int(renderInfo.viewPort?.x ?? 0),
            Int(renderInfo.viewPort?.y ?? 0)
        ),
        colorFormat: renderInfo.colorPixelFormat,
        depthFormat: renderInfo.depthPixelFormat,
        immersionStyle: renderInfo.immersionStyle,
        currentEye: renderInfo.currentEye,
        resources: RenderResourceAccess(),
        computePipelines: ComputePipelineAccess()
    )
}

func validateGraph(_ graph: [String: RenderPass]) throws {
    _ = try topologicalSortGraph(graph: graph)
}

public func executeGraph(
    _: [String: RenderPass], _ sortedPasses: [RenderPass], _ commandBuffer: MTLCommandBuffer
) {
    for pass in sortedPasses {
        pass.execute?(commandBuffer)
    }
}

/// Creates a Directed Acyclic (non-cyclical) Graph
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
