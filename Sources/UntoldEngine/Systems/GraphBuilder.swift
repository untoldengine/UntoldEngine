
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
import simd

public enum RenderGraphError: Error, Equatable, CustomStringConvertible, Sendable {
    case cycleDetected(String)
    case duplicatePassID(String)
    case missingDependency(passID: String, dependencyID: String)
    case missingResource(passID: String, kind: RenderExtensionArtifactKind, resourceID: String)
    case inaccessibleResource(
        passID: String,
        kind: RenderExtensionArtifactKind,
        resourceID: String,
        requestedOwnerID: String,
        existingOwnerID: String?
    )
    case incompatibleResourceUsage(
        passID: String,
        kind: RenderExtensionArtifactKind,
        resourceID: String,
        access: RenderGraphResourceAccess
    )
    case readBeforeWrite(
        passID: String,
        kind: RenderExtensionArtifactKind,
        resourceID: String
    )
    case unorderedResourceWrites(
        kind: RenderExtensionArtifactKind,
        resourceID: String,
        firstPassID: String,
        secondPassID: String
    )
    case unresolvedStages([RenderStage])

    public var description: String {
        switch self {
        case let .cycleDetected(message):
            return message
        case let .duplicatePassID(passID):
            return "Duplicate render pass id: \(passID)"
        case let .missingDependency(passID, dependencyID):
            return "Render pass '\(passID)' depends on missing pass '\(dependencyID)'"
        case let .missingResource(passID, kind, resourceID):
            return "Render pass '\(passID)' references missing \(kind.rawValue) resource '\(resourceID)'"
        case let .inaccessibleResource(passID, kind, resourceID, requestedOwnerID, existingOwnerID):
            let owner = existingOwnerID ?? "engine or unscoped registration"
            return "Render pass '\(passID)' owned by '\(requestedOwnerID)' cannot access \(kind.rawValue) resource '\(resourceID)' owned by \(owner)"
        case let .incompatibleResourceUsage(passID, kind, resourceID, access):
            return "Render pass '\(passID)' declares unsupported \(access.description) access for \(kind.rawValue) resource '\(resourceID)'"
        case let .readBeforeWrite(passID, kind, resourceID):
            return "Render pass '\(passID)' reads \(kind.rawValue) resource '\(resourceID)' before any declared writer"
        case let .unorderedResourceWrites(kind, resourceID, firstPassID, secondPassID):
            return "Render passes '\(firstPassID)' and '\(secondPassID)' write \(kind.rawValue) resource '\(resourceID)' without an ordering dependency"
        case let .unresolvedStages(stages):
            let names = stages.map(\.rawValue).joined(separator: ", ")
            return "Unresolved render extension stage(s): \(names)"
        }
    }
}

public struct RenderGraphResourceAccess: OptionSet, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let read = RenderGraphResourceAccess(rawValue: 1 << 0)
    public static let write = RenderGraphResourceAccess(rawValue: 1 << 1)
    public static let renderTarget = RenderGraphResourceAccess(rawValue: 1 << 2)

    public var description: String {
        var names: [String] = []
        if contains(.read) { names.append("read") }
        if contains(.write) { names.append("write") }
        if contains(.renderTarget) { names.append("renderTarget") }
        let knownBits = Self.read.rawValue | Self.write.rawValue | Self.renderTarget.rawValue
        let unknownBits = rawValue & ~knownBits
        if unknownBits != 0 { names.append("unknown(\(unknownBits))") }
        return names.isEmpty ? "empty" : names.joined(separator: "+")
    }
}

public enum RenderGraphResourceUsage: Hashable, Sendable {
    case texture(RenderTextureResourceID, access: RenderGraphResourceAccess)
    case buffer(RenderBufferResourceID, access: RenderGraphResourceAccess)
}

public enum RenderStage: String, CaseIterable, Sendable {
    case afterOpaqueLighting
    case beforeTransparency
    case afterTransparency
    case beforePostProcess
    case afterPostProcess
    case beforeComposite
    case beforeLook
    case beforeOutput
}

/// Camera transforms captured for the eye currently executing a render-extension pass.
public struct RenderExtensionCameraState: Sendable {
    public let viewMatrix: simd_float4x4
    public let projectionMatrix: simd_float4x4
    public let viewProjectionMatrix: simd_float4x4
    public let worldPosition: simd_float3

    public init(
        viewMatrix: simd_float4x4,
        projectionMatrix: simd_float4x4,
        viewProjectionMatrix: simd_float4x4,
        worldPosition: simd_float3
    ) {
        self.viewMatrix = viewMatrix
        self.projectionMatrix = projectionMatrix
        self.viewProjectionMatrix = viewProjectionMatrix
        self.worldPosition = worldPosition
    }

    public static let identity = RenderExtensionCameraState(
        viewMatrix: matrix_identity_float4x4,
        projectionMatrix: matrix_identity_float4x4,
        viewProjectionMatrix: matrix_identity_float4x4,
        worldPosition: .zero
    )
}

/// Load, store, and clear behavior for an extension draw into the engine scene targets.
public struct SceneRenderPassActions {
    public var colorLoadAction: MTLLoadAction
    public var colorStoreAction: MTLStoreAction
    public var colorClearValue: MTLClearColor
    public var depthLoadAction: MTLLoadAction
    public var depthStoreAction: MTLStoreAction
    public var depthClearValue: Double

    public init(
        colorLoadAction: MTLLoadAction = .load,
        colorStoreAction: MTLStoreAction = .store,
        colorClearValue: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0),
        depthLoadAction: MTLLoadAction = .load,
        depthStoreAction: MTLStoreAction = .store,
        depthClearValue: Double = sceneDepthClearValue()
    ) {
        self.colorLoadAction = colorLoadAction
        self.colorStoreAction = colorStoreAction
        self.colorClearValue = colorClearValue
        self.depthLoadAction = depthLoadAction
        self.depthStoreAction = depthStoreAction
        self.depthClearValue = depthClearValue
    }

    public static var loadAndStore: SceneRenderPassActions {
        SceneRenderPassActions()
    }
}

/// Capability for encoding extension geometry into the active engine scene color and depth targets.
public struct SceneRenderTargetAccess {
    private let makeEncoder: (SceneRenderPassActions, String?) -> MTLRenderCommandEncoder?

    /// Creates unavailable access. Engine-created pass contexts provide the active capability.
    public init() {
        makeEncoder = { _, _ in nil }
    }

    init(makeEncoder: @escaping (SceneRenderPassActions, String?) -> MTLRenderCommandEncoder?) {
        self.makeEncoder = makeEncoder
    }

    public func makeRenderCommandEncoder(
        actions: SceneRenderPassActions = .loadAndStore,
        label: String? = nil
    ) -> MTLRenderCommandEncoder? {
        makeEncoder(actions, label)
    }

    /// Stages whose render products are the working scene color and depth targets.
    public static func supports(_ stage: RenderStage) -> Bool {
        switch stage {
        case .afterOpaqueLighting, .beforeTransparency, .afterTransparency, .beforePostProcess:
            return true
        case .afterPostProcess, .beforeComposite, .beforeLook, .beforeOutput:
            return false
        }
    }
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
    public let stage: RenderStage?
    public let camera: RenderExtensionCameraState
    public let resources: RenderResourceAccess
    public let computePipelines: ComputePipelineAccess
    public let renderPipelines: RenderPipelineAccess
    public let sceneRenderTargets: SceneRenderTargetAccess

    public init(
        commandBuffer: MTLCommandBuffer,
        device: MTLDevice,
        viewport: SIMD2<Int>,
        colorFormat: MTLPixelFormat,
        depthFormat: MTLPixelFormat,
        immersionStyle: UntoldImmersionMode,
        currentEye: Int,
        stage: RenderStage? = nil,
        camera: RenderExtensionCameraState = .identity,
        resources: RenderResourceAccess = RenderResourceAccess(),
        computePipelines: ComputePipelineAccess = ComputePipelineAccess(),
        renderPipelines: RenderPipelineAccess = RenderPipelineAccess(),
        sceneRenderTargets: SceneRenderTargetAccess = SceneRenderTargetAccess()
    ) {
        self.commandBuffer = commandBuffer
        self.device = device
        self.viewport = viewport
        self.colorFormat = colorFormat
        self.depthFormat = depthFormat
        self.immersionStyle = immersionStyle
        self.currentEye = currentEye
        self.stage = stage
        self.camera = camera
        self.resources = resources
        self.computePipelines = computePipelines
        self.renderPipelines = renderPipelines
        self.sceneRenderTargets = sceneRenderTargets
    }
}

public typealias RenderGraphPassExecution = (RenderPassContext) -> Void

struct RenderPass {
    let id: String
    var dependencies: [String]
    var inferredDependencies: [String]
    var execute: ((MTLCommandBuffer) -> Void)?
    var resourceUsages: [RenderGraphResourceUsage]
    let owner: RenderGraphPassOwner
    let stage: RenderStage?

    init(
        id: String,
        dependencies: [String],
        inferredDependencies: [String] = [],
        execute: ((MTLCommandBuffer) -> Void)?,
        resourceUsages: [RenderGraphResourceUsage] = [],
        owner: RenderGraphPassOwner = .engine,
        stage: RenderStage? = nil
    ) {
        self.id = id
        self.dependencies = dependencies
        self.inferredDependencies = inferredDependencies
        self.execute = execute
        self.resourceUsages = resourceUsages
        self.owner = owner
        self.stage = stage
    }
}

private struct PendingRenderGraphPass {
    let id: String
    let dependencies: [String]
    let resourceUsages: [RenderGraphResourceUsage]
    let execute: RenderGraphPassExecution?
    let owner: RenderGraphPassOwner
}

private struct RenderGraphRegistrationError {
    let error: RenderGraphError
    let ownerID: String?
}

struct RenderGraphExtensionRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let validationErrors: [RenderGraphError]

    var succeeded: Bool {
        conflicts.isEmpty && validationErrors.isEmpty
    }
}

enum RenderGraphPassOwner: Equatable {
    case reservedEngine
    case engine
    case renderExtension(String)

    var extensionID: String? {
        if case let .renderExtension(id) = self {
            return id
        }
        return nil
    }
}

/// Immutable pass metadata and execution captured when a render graph is compiled.
struct CompiledRenderGraphPass {
    let id: String
    let dependencies: [String]
    let inferredDependencies: [String]
    let resourceUsages: [RenderGraphResourceUsage]
    let owner: RenderGraphPassOwner
    let stage: RenderStage?
    let execute: ((MTLCommandBuffer) -> Void)?
}

/// A validated render graph with one deterministic execution order.
struct CompiledRenderGraph {
    let passesByID: [String: CompiledRenderGraphPass]
    let executionOrder: [String]
    let orderedPasses: [CompiledRenderGraphPass]
    let resourcePlan: CompiledRenderGraphResourcePlan
    let optimizationReport: CompiledRenderGraphOptimizationReport

    init(orderedPasses: [CompiledRenderGraphPass]) {
        self.orderedPasses = orderedPasses
        passesByID = Dictionary(
            uniqueKeysWithValues: orderedPasses.map { ($0.id, $0) }
        )
        executionOrder = orderedPasses.map(\.id)
        let compiledResourcePlan = compileRenderGraphResourcePlan(orderedPasses)
        resourcePlan = compiledResourcePlan
        optimizationReport = compileRenderGraphOptimizationReport(
            orderedPasses,
            resourcePlan: compiledResourcePlan
        )
    }
}

struct RenderGraphValidationDiagnostic: Equatable {
    let error: RenderGraphError
    let ownerID: String?
}

struct RenderGraphValidationReport: Equatable {
    let diagnostics: [RenderGraphValidationDiagnostic]

    var isValid: Bool {
        diagnostics.isEmpty
    }

    var errors: [RenderGraphError] {
        diagnostics.map(\.error)
    }

    func errorsByExtensionID() -> [String: [RenderGraphError]] {
        Dictionary(grouping: diagnostics.compactMap { diagnostic in
            diagnostic.ownerID.map { ($0, diagnostic.error) }
        }, by: { $0.0 }).mapValues { entries in
            entries.map(\.1)
        }
    }
}

struct RenderGraphCompilationAnalysis {
    let compiledGraph: CompiledRenderGraph?
    let validationReport: RenderGraphValidationReport
    let scheduledGraph: [String: RenderPass]
}

public struct RenderGraphBuilder {
    private var graph: [String: RenderPass]
    private var pendingStagePasses: [RenderStage: [PendingRenderGraphPass]]
    private var passOwners: [String: RenderGraphPassOwner]
    private var registrationErrors: [RenderGraphRegistrationError]
    private var currentExtensionID: String?
    private var currentExtensionConflicts: [RenderExtensionArtifactConflict]

    init(
        graph: [String: RenderPass] = [:],
        reservedPassIDs: Set<String> = []
    ) {
        self.graph = graph
        pendingStagePasses = [:]
        passOwners = Dictionary(
            uniqueKeysWithValues: graph.map { ($0.key, $0.value.owner) }
        )
        for passID in reservedPassIDs where passOwners[passID] == nil {
            passOwners[passID] = .reservedEngine
        }
        registrationErrors = []
        currentExtensionID = nil
        currentExtensionConflicts = []
    }

    @discardableResult
    mutating func addPass(
        id: String,
        dependencies: [String],
        resourceUsages: [RenderGraphResourceUsage] = [],
        execute: ((MTLCommandBuffer) -> Void)?,
        inferredDependencies: [String] = [],
        owner: RenderGraphPassOwner = .engine,
        stage: RenderStage? = nil
    ) -> Bool {
        if let existingOwner = passOwners[id], existingOwner != .reservedEngine {
            Logger.logWarning(message: "[RenderGraph] Duplicate pass id ignored: \(id)")
            recordRegistrationError(.duplicatePassID(id))
            return false
        }
        graph[id] = RenderPass(
            id: id,
            dependencies: dependencies,
            inferredDependencies: inferredDependencies,
            execute: execute,
            resourceUsages: resourceUsages,
            owner: owner,
            stage: stage
        )
        passOwners[id] = owner
        return true
    }

    @discardableResult
    mutating func addPass(_ pass: RenderPass) -> Bool {
        addPass(
            id: pass.id,
            dependencies: pass.dependencies,
            resourceUsages: pass.resourceUsages,
            execute: pass.execute,
            inferredDependencies: pass.inferredDependencies,
            owner: pass.owner,
            stage: pass.stage
        )
    }

    @discardableResult
    public mutating func addPass(
        id: String,
        stage: RenderStage,
        resources: [RenderGraphResourceUsage] = [],
        execute: RenderGraphPassExecution?
    ) -> Bool {
        addPass(
            id: id,
            stage: stage,
            dependencies: [],
            resources: resources,
            execute: execute
        )
    }

    @discardableResult
    mutating func addPass(
        id: String,
        stage: RenderStage,
        dependencies: [String],
        resources: [RenderGraphResourceUsage] = [],
        execute: RenderGraphPassExecution?
    ) -> Bool {
        let owner = currentExtensionID.map(RenderGraphPassOwner.renderExtension) ?? .engine
        guard let existingOwner = passOwners[id] else {
            recordResourceUsageErrors(
                validateRenderGraphResourceUsages(
                    resources,
                    passID: id,
                    ownerID: owner.extensionID
                ),
                ownerID: owner.extensionID
            )
            pendingStagePasses[stage, default: []].append(
                PendingRenderGraphPass(
                    id: id,
                    dependencies: dependencies,
                    resourceUsages: resources,
                    execute: execute,
                    owner: owner
                )
            )
            passOwners[id] = owner
            return true
        }

        if let currentExtensionID {
            let conflict = RenderExtensionArtifactConflict(
                kind: .renderPass,
                artifactID: id,
                requestedOwnerID: currentExtensionID,
                existingOwnerID: existingOwner.extensionID
            )
            if !currentExtensionConflicts.contains(conflict) {
                currentExtensionConflicts.append(conflict)
            }
        } else {
            recordRegistrationError(.duplicatePassID(id))
        }
        Logger.logWarning(message: "[RenderGraph] Duplicate staged pass id ignored: \(id)")
        return false
    }

    mutating func beginExtensionRegistration(id: String) {
        precondition(currentExtensionID == nil, "Render extension pass registrations cannot overlap")
        currentExtensionID = id
        currentExtensionConflicts = []
    }

    mutating func endExtensionRegistration() -> RenderGraphExtensionRegistrationReport {
        guard let extensionID = currentExtensionID else {
            return RenderGraphExtensionRegistrationReport(conflicts: [], validationErrors: [])
        }
        let conflicts = currentExtensionConflicts
        let validationErrors = registrationErrors.compactMap { registrationError in
            registrationError.ownerID == extensionID ? registrationError.error : nil
        }
        if !conflicts.isEmpty || !validationErrors.isEmpty {
            for stage in RenderStage.allCases {
                pendingStagePasses[stage]?.removeAll { pass in
                    pass.owner == .renderExtension(extensionID)
                }
            }
            passOwners = passOwners.filter { _, owner in
                owner != .renderExtension(extensionID)
            }
            registrationErrors.removeAll { $0.ownerID == extensionID }
        }
        currentExtensionID = nil
        currentExtensionConflicts = []
        return RenderGraphExtensionRegistrationReport(
            conflicts: conflicts,
            validationErrors: validationErrors
        )
    }

    mutating func removeExtensionContributions(extensionIDs: Set<String>) {
        guard !extensionIDs.isEmpty else { return }
        for stage in RenderStage.allCases {
            pendingStagePasses[stage]?.removeAll { pass in
                guard let ownerID = pass.owner.extensionID else { return false }
                return extensionIDs.contains(ownerID)
            }
        }
        let removedPassIDs: [String] = passOwners.compactMap { entry in
            guard let ownerID = entry.value.extensionID,
                  extensionIDs.contains(ownerID)
            else {
                return nil
            }
            return entry.key
        }
        for passID in removedPassIDs {
            passOwners.removeValue(forKey: passID)
            graph.removeValue(forKey: passID)
        }
        registrationErrors.removeAll { error in
            error.ownerID.map(extensionIDs.contains) == true
        }
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
                let resources = RenderResourceAccess(resourceUsages: pass.resourceUsages)
                return { commandBuffer in
                    execute(makeRenderPassContext(
                        commandBuffer: commandBuffer,
                        resources: resources,
                        stage: stage
                    ))
                }
            }

            graph[pass.id] = RenderPass(
                id: pass.id,
                dependencies: dependencies,
                execute: execution,
                resourceUsages: pass.resourceUsages,
                owner: pass.owner,
                stage: stage
            )
            tail = pass.id
        }

        return tail
    }

    func build() throws -> [String: RenderPass] {
        try buildWithCompilation().graph
    }

    func buildWithCompilation() throws -> (
        graph: [String: RenderPass],
        compiledGraph: CompiledRenderGraph
    ) {
        let analysis = try analyzeForCompilation()
        guard let compiledGraph = analysis.compiledGraph else {
            throw analysis.validationReport.errors[0]
        }
        return (analysis.scheduledGraph, compiledGraph)
    }

    func compile() throws -> CompiledRenderGraph {
        let analysis = try analyzeForCompilation()
        guard let compiledGraph = analysis.compiledGraph else {
            throw analysis.validationReport.errors[0]
        }
        return compiledGraph
    }

    func analyzeForCompilation() throws -> RenderGraphCompilationAnalysis {
        if let registrationError = registrationErrors.first {
            throw registrationError.error
        }

        let unresolvedStages = RenderStage.allCases.filter {
            pendingStagePasses[$0]?.isEmpty == false
        }
        guard unresolvedStages.isEmpty else {
            throw RenderGraphError.unresolvedStages(unresolvedStages)
        }

        return analyzeRenderGraph(graph)
    }

    private mutating func recordRegistrationError(
        _ error: RenderGraphError,
        ownerID: String? = nil
    ) {
        if !registrationErrors.contains(where: { $0.error == error && $0.ownerID == ownerID }) {
            registrationErrors.append(RenderGraphRegistrationError(error: error, ownerID: ownerID))
        }
    }

    private mutating func recordResourceUsageErrors(
        _ errors: [RenderGraphError],
        ownerID: String?
    ) {
        for error in errors {
            recordRegistrationError(error, ownerID: ownerID)
        }
    }
}

func validateRenderGraphResourceUsages(
    _ usages: [RenderGraphResourceUsage],
    passID: String,
    ownerID: String?
) -> [RenderGraphError] {
    var errors: [RenderGraphError] = []
    let registry = RenderResourceRegistry.shared
    let knownAccess: RenderGraphResourceAccess = [.read, .write, .renderTarget]

    for usage in usages {
        switch usage {
        case let .texture(id, access):
            guard let declaration = registry.textureDeclaration(id) else {
                errors.append(.missingResource(passID: passID, kind: .texture, resourceID: id.rawValue))
                continue
            }
            if let ownerID, declaration.ownerID != ownerID {
                errors.append(
                    .inaccessibleResource(
                        passID: passID,
                        kind: .texture,
                        resourceID: id.rawValue,
                        requestedOwnerID: ownerID,
                        existingOwnerID: declaration.ownerID
                    )
                )
                continue
            }

            var unsupported = RenderGraphResourceAccess(rawValue: access.rawValue & ~knownAccess.rawValue)
            if access.isEmpty {
                unsupported = access
            }
            if access.contains(.read), !declaration.descriptor.usage.contains(.shaderRead) {
                unsupported.insert(.read)
            }
            if access.contains(.write), !declaration.descriptor.usage.contains(.shaderWrite) {
                unsupported.insert(.write)
            }
            if access.contains(.renderTarget), !declaration.descriptor.usage.contains(.renderTarget) {
                unsupported.insert(.renderTarget)
            }
            if access.isEmpty || !unsupported.isEmpty {
                errors.append(
                    .incompatibleResourceUsage(
                        passID: passID,
                        kind: .texture,
                        resourceID: id.rawValue,
                        access: access.isEmpty ? access : unsupported
                    )
                )
            }

        case let .buffer(id, access):
            guard let declaration = registry.bufferDeclaration(id) else {
                errors.append(.missingResource(passID: passID, kind: .buffer, resourceID: id.rawValue))
                continue
            }
            if let ownerID, declaration.ownerID != ownerID {
                errors.append(
                    .inaccessibleResource(
                        passID: passID,
                        kind: .buffer,
                        resourceID: id.rawValue,
                        requestedOwnerID: ownerID,
                        existingOwnerID: declaration.ownerID
                    )
                )
                continue
            }

            let supportedAccess: RenderGraphResourceAccess = [.read, .write]
            let unsupported = RenderGraphResourceAccess(rawValue: access.rawValue & ~supportedAccess.rawValue)
            if access.isEmpty || !unsupported.isEmpty {
                errors.append(
                    .incompatibleResourceUsage(
                        passID: passID,
                        kind: .buffer,
                        resourceID: id.rawValue,
                        access: access.isEmpty ? access : unsupported
                    )
                )
            }
        }
    }
    return errors
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

func makeRenderPassContext(
    commandBuffer: MTLCommandBuffer,
    resources: RenderResourceAccess = RenderResourceAccess(),
    stage: RenderStage? = nil
) -> RenderPassContext {
    let cameraState: RenderExtensionCameraState
    if let camera = CameraSystem.shared.activeCamera,
       let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
    {
        cameraState = makeRenderExtensionCameraState(
            cameraViewMatrix: cameraComponent.viewSpace,
            projectionMatrix: renderInfo.perspectiveSpace
        )
    } else {
        cameraState = makeRenderExtensionCameraState(
            cameraViewMatrix: matrix_identity_float4x4,
            projectionMatrix: renderInfo.perspectiveSpace
        )
    }
    let sceneRenderTargets = makeSceneRenderTargetAccess(
        commandBuffer: commandBuffer,
        stage: stage,
        descriptor: renderInfo.deferredRenderPassDescriptor
    )

    return RenderPassContext(
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
        stage: stage,
        camera: cameraState,
        resources: resources,
        computePipelines: ComputePipelineAccess(),
        renderPipelines: RenderPipelineAccess(),
        sceneRenderTargets: sceneRenderTargets
    )
}

func makeSceneRenderTargetAccess(
    commandBuffer: MTLCommandBuffer,
    stage: RenderStage?,
    descriptor: MTLRenderPassDescriptor?
) -> SceneRenderTargetAccess {
    guard let stage, SceneRenderTargetAccess.supports(stage), let descriptor else {
        return SceneRenderTargetAccess()
    }

    return SceneRenderTargetAccess { actions, label in
        guard let encoderDescriptor = makeSceneRenderPassDescriptor(
            copying: descriptor,
            actions: actions
        ), let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: encoderDescriptor)
        else {
            return nil
        }
        encoder.label = label
        return encoder
    }
}

func makeSceneRenderPassDescriptor(
    copying source: MTLRenderPassDescriptor,
    actions: SceneRenderPassActions
) -> MTLRenderPassDescriptor? {
    let supportedLoadActions: [MTLLoadAction] = [.load, .clear, .dontCare]
    let supportedStoreActions: [MTLStoreAction] = [.store, .dontCare]
    guard supportedLoadActions.contains(actions.colorLoadAction),
          supportedLoadActions.contains(actions.depthLoadAction),
          supportedStoreActions.contains(actions.colorStoreAction),
          supportedStoreActions.contains(actions.depthStoreAction),
          let colorTexture = source.colorAttachments[0].texture,
          let depthTexture = source.depthAttachment.texture,
          colorTexture.width == depthTexture.width,
          colorTexture.height == depthTexture.height,
          colorTexture.sampleCount == depthTexture.sampleCount,
          let descriptor = source.copy() as? MTLRenderPassDescriptor
    else {
        return nil
    }

    descriptor.colorAttachments[0].loadAction = actions.colorLoadAction
    descriptor.colorAttachments[0].storeAction = actions.colorStoreAction
    descriptor.colorAttachments[0].clearColor = actions.colorClearValue
    descriptor.depthAttachment.loadAction = actions.depthLoadAction
    descriptor.depthAttachment.storeAction = actions.depthStoreAction
    descriptor.depthAttachment.clearDepth = actions.depthClearValue
    return descriptor
}

func makeRenderExtensionCameraState(
    cameraViewMatrix: simd_float4x4,
    projectionMatrix: simd_float4x4
) -> RenderExtensionCameraState {
    let viewMatrix = SceneRootTransform.shared.effectiveViewMatrix(cameraViewMatrix)
    let inverseView = simd_inverse(viewMatrix)
    let homogeneousPosition = inverseView.columns.3
    let inverseW: Float = homogeneousPosition.w == 0 ? 1 : 1 / homogeneousPosition.w
    return RenderExtensionCameraState(
        viewMatrix: viewMatrix,
        projectionMatrix: projectionMatrix,
        viewProjectionMatrix: simd_mul(projectionMatrix, viewMatrix),
        worldPosition: simd_float3(
            homogeneousPosition.x * inverseW,
            homogeneousPosition.y * inverseW,
            homogeneousPosition.z * inverseW
        )
    )
}

func validateGraph(_ graph: [String: RenderPass]) throws {
    let report = analyzeRenderGraph(graph).validationReport
    if let error = report.errors.first {
        throw error
    }
}

func executeGraph(_ graph: CompiledRenderGraph, _ commandBuffer: MTLCommandBuffer) {
    for pass in graph.orderedPasses {
        pass.execute?(commandBuffer)
    }
}

func compileRenderGraph(_ graph: [String: RenderPass]) throws -> CompiledRenderGraph {
    let analysis = analyzeRenderGraph(graph)
    guard let compiledGraph = analysis.compiledGraph else {
        throw analysis.validationReport.errors[0]
    }
    return compiledGraph
}

func analyzeRenderGraph(_ graph: [String: RenderPass]) -> RenderGraphCompilationAnalysis {
    var diagnostics = validateMissingRenderGraphDependencies(graph)
    diagnostics.append(contentsOf: validateRenderGraphDeclarations(graph))
    var scheduledGraph = graph
    let explicitlySortedPasses: [RenderPass]?
    if diagnostics.contains(where: {
        if case .missingDependency = $0.error { return true }
        return false
    }) {
        explicitlySortedPasses = nil
    } else {
        do {
            explicitlySortedPasses = try topologicalSortGraph(graph: graph)
        } catch let error as RenderGraphError {
            let passID = renderGraphPassID(for: error)
            diagnostics.insert(
                RenderGraphValidationDiagnostic(
                    error: error,
                    ownerID: passID.flatMap { graph[$0]?.owner.extensionID }
                ),
                at: 0
            )
            explicitlySortedPasses = nil
        } catch {
            diagnostics.insert(
                RenderGraphValidationDiagnostic(
                    error: .cycleDetected(error.localizedDescription),
                    ownerID: nil
                ),
                at: 0
            )
            explicitlySortedPasses = nil
        }
    }

    let sortedPasses: [RenderPass]?
    if let explicitlySortedPasses {
        scheduledGraph = scheduleRenderGraphResourceHazards(
            graph,
            explicitlySortedPasses: explicitlySortedPasses
        )
        do {
            sortedPasses = try topologicalSortGraph(graph: scheduledGraph)
        } catch let error as RenderGraphError {
            let passID = renderGraphPassID(for: error)
            diagnostics.append(
                RenderGraphValidationDiagnostic(
                    error: error,
                    ownerID: passID.flatMap { scheduledGraph[$0]?.owner.extensionID }
                )
            )
            sortedPasses = nil
        } catch {
            diagnostics.append(
                RenderGraphValidationDiagnostic(
                    error: .cycleDetected(error.localizedDescription),
                    ownerID: nil
                )
            )
            sortedPasses = nil
        }
    } else {
        sortedPasses = nil
    }

    if let sortedPasses {
        diagnostics.append(contentsOf: validateRenderGraphResourceHazards(sortedPasses))
    }

    let report = RenderGraphValidationReport(diagnostics: uniqueDiagnostics(diagnostics))
    guard report.isValid, let sortedPasses else {
        return RenderGraphCompilationAnalysis(
            compiledGraph: nil,
            validationReport: report,
            scheduledGraph: scheduledGraph
        )
    }

    let passes = sortedPasses.map { pass in
        CompiledRenderGraphPass(
            id: pass.id,
            dependencies: pass.dependencies,
            inferredDependencies: pass.inferredDependencies,
            resourceUsages: pass.resourceUsages,
            owner: pass.owner,
            stage: pass.stage,
            execute: pass.execute
        )
    }
    return RenderGraphCompilationAnalysis(
        compiledGraph: CompiledRenderGraph(orderedPasses: passes),
        validationReport: report,
        scheduledGraph: scheduledGraph
    )
}

private func validateMissingRenderGraphDependencies(
    _ graph: [String: RenderPass]
) -> [RenderGraphValidationDiagnostic] {
    var diagnostics: [RenderGraphValidationDiagnostic] = []
    for passID in graph.keys.sorted() {
        guard let pass = graph[passID] else { continue }
        for dependencyID in pass.dependencies where graph[dependencyID] == nil {
            diagnostics.append(
                RenderGraphValidationDiagnostic(
                    error: .missingDependency(
                        passID: pass.id,
                        dependencyID: dependencyID
                    ),
                    ownerID: pass.owner.extensionID
                )
            )
        }
    }
    return diagnostics
}

private struct RenderGraphResourceKey: Hashable, Comparable {
    let kind: RenderExtensionArtifactKind
    let id: String

    static func < (lhs: RenderGraphResourceKey, rhs: RenderGraphResourceKey) -> Bool {
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        return lhs.id < rhs.id
    }
}

private func validateRenderGraphDeclarations(
    _ graph: [String: RenderPass]
) -> [RenderGraphValidationDiagnostic] {
    var diagnostics: [RenderGraphValidationDiagnostic] = []
    for passID in graph.keys.sorted() {
        guard let pass = graph[passID] else { continue }
        diagnostics += validateRenderGraphResourceUsages(
            pass.resourceUsages,
            passID: pass.id,
            ownerID: pass.owner.extensionID
        ).map { error in
            RenderGraphValidationDiagnostic(
                error: error,
                ownerID: pass.owner.extensionID
            )
        }
    }
    return diagnostics
}

private struct RenderGraphResourceAccessRecord {
    let passID: String
    let access: RenderGraphResourceAccess
}

func scheduleRenderGraphResourceHazards(
    _ graph: [String: RenderPass],
    explicitlySortedPasses: [RenderPass]
) -> [String: RenderPass] {
    var scheduledGraph = graph
    let accesses = collectRenderGraphResourceAccesses(explicitlySortedPasses)

    for key in accesses.keys.sorted() {
        guard var sequence = accesses[key],
              let firstWriterIndex = sequence.firstIndex(where: { isWriteAccess($0.access) })
        else {
            continue
        }

        if firstWriterIndex > 0 {
            let firstWriter = sequence[firstWriterIndex]
            let leadingReaders = Array(sequence[..<firstWriterIndex])
            let blockedReaders = leadingReaders.filter { reader in
                renderPass(
                    firstWriter.passID,
                    dependsOn: reader.passID,
                    passesByID: scheduledGraph
                )
            }
            let movableReaders = leadingReaders.filter { reader in
                !blockedReaders.contains(where: { $0.passID == reader.passID })
            }
            sequence = blockedReaders
                + [firstWriter]
                + movableReaders
                + Array(sequence[(firstWriterIndex + 1)...])
        }

        var lastWriterID: String?
        var readersSinceWrite: [String] = []
        for record in sequence {
            if isWriteAccess(record.access) {
                if let lastWriterID {
                    addInferredRenderGraphDependency(
                        from: lastWriterID,
                        to: record.passID,
                        graph: &scheduledGraph
                    )
                }
                for readerID in readersSinceWrite {
                    addInferredRenderGraphDependency(
                        from: readerID,
                        to: record.passID,
                        graph: &scheduledGraph
                    )
                }
                readersSinceWrite.removeAll(keepingCapacity: true)
                lastWriterID = record.passID
            } else if record.access.contains(.read) {
                if let lastWriterID {
                    addInferredRenderGraphDependency(
                        from: lastWriterID,
                        to: record.passID,
                        graph: &scheduledGraph
                    )
                }
                readersSinceWrite.append(record.passID)
            }
        }
    }
    return scheduledGraph
}

private func collectRenderGraphResourceAccesses(
    _ sortedPasses: [RenderPass]
) -> [RenderGraphResourceKey: [RenderGraphResourceAccessRecord]] {
    var accesses: [RenderGraphResourceKey: [RenderGraphResourceAccessRecord]] = [:]
    for pass in sortedPasses {
        var mergedAccess: [RenderGraphResourceKey: RenderGraphResourceAccess] = [:]
        for usage in pass.resourceUsages {
            let key: RenderGraphResourceKey
            let access: RenderGraphResourceAccess
            switch usage {
            case let .texture(id, declaredAccess):
                key = RenderGraphResourceKey(kind: .texture, id: id.rawValue)
                access = declaredAccess
            case let .buffer(id, declaredAccess):
                key = RenderGraphResourceKey(kind: .buffer, id: id.rawValue)
                access = declaredAccess
            }
            mergedAccess[key, default: []].formUnion(access)
        }
        for key in mergedAccess.keys.sorted() {
            accesses[key, default: []].append(
                RenderGraphResourceAccessRecord(
                    passID: pass.id,
                    access: mergedAccess[key] ?? []
                )
            )
        }
    }
    return accesses
}

private func addInferredRenderGraphDependency(
    from prerequisiteID: String,
    to dependentID: String,
    graph: inout [String: RenderPass]
) {
    guard prerequisiteID != dependentID,
          graph[prerequisiteID] != nil,
          var dependent = graph[dependentID],
          !dependent.dependencies.contains(prerequisiteID),
          !renderPass(
              prerequisiteID,
              dependsOn: dependentID,
              passesByID: graph
          )
    else {
        return
    }

    dependent.dependencies.append(prerequisiteID)
    dependent.inferredDependencies.append(prerequisiteID)
    graph[dependentID] = dependent
}

func validateRenderGraphResourceHazards(
    _ sortedPasses: [RenderPass]
) -> [RenderGraphValidationDiagnostic] {
    let passesByID = Dictionary(uniqueKeysWithValues: sortedPasses.map { ($0.id, $0) })
    var accesses: [RenderGraphResourceKey: [(pass: RenderPass, access: RenderGraphResourceAccess)]] = [:]

    for pass in sortedPasses {
        var mergedAccess: [RenderGraphResourceKey: RenderGraphResourceAccess] = [:]
        for usage in pass.resourceUsages {
            let key: RenderGraphResourceKey
            let access: RenderGraphResourceAccess
            switch usage {
            case let .texture(id, declaredAccess):
                key = RenderGraphResourceKey(kind: .texture, id: id.rawValue)
                access = declaredAccess
            case let .buffer(id, declaredAccess):
                key = RenderGraphResourceKey(kind: .buffer, id: id.rawValue)
                access = declaredAccess
            }
            mergedAccess[key, default: []].formUnion(access)
        }
        for key in mergedAccess.keys.sorted() {
            accesses[key, default: []].append((pass, mergedAccess[key] ?? []))
        }
    }

    var diagnostics: [RenderGraphValidationDiagnostic] = []
    for key in accesses.keys.sorted() {
        guard let resourceAccesses = accesses[key] else { continue }
        let writers = resourceAccesses.filter { isWriteAccess($0.access) }
        guard !writers.isEmpty else { continue }

        for reader in resourceAccesses where reader.access.contains(.read) {
            let hasOrderedWriter = writers.contains { writer in
                writer.pass.id == reader.pass.id || renderPass(
                    reader.pass.id,
                    dependsOn: writer.pass.id,
                    passesByID: passesByID
                )
            }
            if !hasOrderedWriter {
                diagnostics.append(
                    RenderGraphValidationDiagnostic(
                        error: .readBeforeWrite(
                            passID: reader.pass.id,
                            kind: key.kind,
                            resourceID: key.id
                        ),
                        ownerID: reader.pass.owner.extensionID
                    )
                )
            }
        }

        for firstIndex in writers.indices {
            for secondIndex in writers.indices where secondIndex > firstIndex {
                let first = writers[firstIndex].pass
                let second = writers[secondIndex].pass
                let isOrdered = renderPass(
                    first.id,
                    dependsOn: second.id,
                    passesByID: passesByID
                ) || renderPass(
                    second.id,
                    dependsOn: first.id,
                    passesByID: passesByID
                )
                if !isOrdered {
                    diagnostics.append(
                        RenderGraphValidationDiagnostic(
                            error: .unorderedResourceWrites(
                                kind: key.kind,
                                resourceID: key.id,
                                firstPassID: first.id,
                                secondPassID: second.id
                            ),
                            ownerID: second.owner.extensionID ?? first.owner.extensionID
                        )
                    )
                }
            }
        }
    }
    return diagnostics
}

private func isWriteAccess(_ access: RenderGraphResourceAccess) -> Bool {
    !access.intersection([.write, .renderTarget]).isEmpty
}

private func renderPass(
    _ passID: String,
    dependsOn dependencyID: String,
    passesByID: [String: RenderPass]
) -> Bool {
    var pending = passesByID[passID]?.dependencies ?? []
    var visited: Set<String> = []
    while let current = pending.popLast() {
        if current == dependencyID { return true }
        guard visited.insert(current).inserted else { continue }
        pending.append(contentsOf: passesByID[current]?.dependencies ?? [])
    }
    return false
}

private func renderGraphPassID(for error: RenderGraphError) -> String? {
    switch error {
    case let .missingDependency(passID, _),
         let .missingResource(passID, _, _),
         let .inaccessibleResource(passID, _, _, _, _),
         let .incompatibleResourceUsage(passID, _, _, _),
         let .readBeforeWrite(passID, _, _):
        return passID
    case let .unorderedResourceWrites(_, _, _, secondPassID):
        return secondPassID
    case let .cycleDetected(message):
        return message.split(separator: " ").last.map(String.init)
    case .duplicatePassID, .unresolvedStages:
        return nil
    }
}

private func uniqueDiagnostics(
    _ diagnostics: [RenderGraphValidationDiagnostic]
) -> [RenderGraphValidationDiagnostic] {
    var result: [RenderGraphValidationDiagnostic] = []
    for diagnostic in diagnostics where !result.contains(diagnostic) {
        result.append(diagnostic)
    }
    return result
}

/// Creates a Directed Acyclic (non-cyclical) Graph
func topologicalSortGraph(graph: [String: RenderPass]) throws -> [RenderPass] {
    for passID in graph.keys.sorted() {
        guard let pass = graph[passID] else {
            continue
        }
        for dependencyID in pass.dependencies where graph[dependencyID] == nil {
            throw RenderGraphError.missingDependency(
                passID: pass.id,
                dependencyID: dependencyID
            )
        }
    }

    var sortedPasses = [RenderPass]()
    var visited = Set<String>()
    var visiting = Set<String>() // Tracks nodes in the current recursion stack

    func visit(_ pass: RenderPass) throws {
        if visiting.contains(pass.id) {
            throw RenderGraphError.cycleDetected("Cycle detected at node \(pass.id)")
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

    for passID in graph.keys.sorted() {
        if let pass = graph[passID] {
            try visit(pass)
        }
    }

    return sortedPasses
}
