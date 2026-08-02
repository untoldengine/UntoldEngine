//
//  RenderExtensions.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal

public enum RenderExtensionArtifactKind: String, Hashable, Sendable {
    case shaderLibrary
    case renderPipeline
    case computePipeline
    case texture
    case buffer
    case argumentBuffer
    case renderPass
}

public struct RenderExtensionArtifactConflict: Error, Equatable, Sendable, CustomStringConvertible {
    public let kind: RenderExtensionArtifactKind
    public let artifactID: String
    public let requestedOwnerID: String
    public let existingOwnerID: String?

    public init(
        kind: RenderExtensionArtifactKind,
        artifactID: String,
        requestedOwnerID: String,
        existingOwnerID: String?
    ) {
        self.kind = kind
        self.artifactID = artifactID
        self.requestedOwnerID = requestedOwnerID
        self.existingOwnerID = existingOwnerID
    }

    public var description: String {
        let owner = existingOwnerID ?? "engine or unscoped registration"
        return "Extension '\(requestedOwnerID)' cannot register \(kind.rawValue) '\(artifactID)'; it is owned by \(owner)"
    }
}

public enum RenderExtensionRegistrationResult: Equatable, Sendable {
    case registered
    case rejectedPluginOwnership(extensionID: String, pluginID: String)
    case rejected([RenderExtensionArtifactConflict])
    case rejectedResources(
        conflicts: [RenderExtensionArtifactConflict],
        validationErrors: [RenderExtensionResourceValidationError]
    )
    case rejectedArtifacts(
        conflicts: [RenderExtensionArtifactConflict],
        shaderLibraryErrors: [RenderShaderLibraryLoadingError],
        pipelineErrors: [RenderExtensionPipelineError],
        resourceValidationErrors: [RenderExtensionResourceValidationError]
    )

    public var conflicts: [RenderExtensionArtifactConflict] {
        switch self {
        case .registered, .rejectedPluginOwnership:
            return []
        case let .rejected(conflicts):
            return conflicts
        case let .rejectedResources(conflicts, _):
            return conflicts
        case let .rejectedArtifacts(conflicts, _, _, _):
            return conflicts
        }
    }

    public var resourceValidationErrors: [RenderExtensionResourceValidationError] {
        switch self {
        case .registered, .rejectedPluginOwnership, .rejected:
            return []
        case let .rejectedResources(_, validationErrors):
            return validationErrors
        case let .rejectedArtifacts(_, _, _, validationErrors):
            return validationErrors
        }
    }

    public var shaderLibraryErrors: [RenderShaderLibraryLoadingError] {
        switch self {
        case .registered, .rejectedPluginOwnership, .rejected, .rejectedResources:
            return []
        case let .rejectedArtifacts(_, loadingErrors, _, _):
            return loadingErrors
        }
    }

    public var pipelineErrors: [RenderExtensionPipelineError] {
        switch self {
        case .registered, .rejectedPluginOwnership, .rejected, .rejectedResources:
            return []
        case let .rejectedArtifacts(_, _, pipelineErrors, _):
            return pipelineErrors
        }
    }
}

final class RenderExtensionConflictCollector {
    private(set) var conflicts: [RenderExtensionArtifactConflict] = []

    func record(_ conflict: RenderExtensionArtifactConflict) {
        if !conflicts.contains(conflict) {
            conflicts.append(conflict)
        }
    }
}

/// A render-graph-owning plugin. Refines `EngineExtension`, so `update`/`fixedUpdate`/
/// `willUnregister`/`id` come from that shared lifecycle contract — register a
/// `RenderExtension` only with `RenderExtensionRegistry`, never additionally with
/// `EngineExtensionRegistry`, or it will be ticked twice.
public protocol RenderExtension: EngineExtension {
    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry)

    func registerPipelines(_ registry: RenderPipelineRegistry)

    func registerComputePipelines(_ registry: ComputePipelineRegistry)

    func registerResources(_ registry: RenderResourceRegistry)

    func registerArgumentBuffers(_ registry: RenderExtensionArgumentBufferRegistry)

    func resourcesDidLoad(_ access: RenderResourceAccess)

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context: RenderGraphBuildContext
    )
}

public extension RenderExtension {
    func registerShaderLibraries(_: RenderShaderLibraryRegistry) {}
    func registerPipelines(_: RenderPipelineRegistry) {}
    func registerComputePipelines(_: ComputePipelineRegistry) {}
    func registerResources(_: RenderResourceRegistry) {}
    func registerArgumentBuffers(_: RenderExtensionArgumentBufferRegistry) {}
    func resourcesDidLoad(_: RenderResourceAccess) {}
}

public struct RenderShaderLibraryID: Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

/// Describes where an extension shader library is loaded from.
public enum RenderShaderLibrarySource {
    /// Uses an already-created Metal library.
    case library(MTLLibrary)
    /// Loads the default Metal library compiled into a bundle.
    case defaultLibrary(bundle: Bundle)
    /// Loads a precompiled `.metallib` resource relative to a bundle.
    case metallib(bundle: Bundle, resource: String, subdirectory: String? = nil)
}

public enum RenderShaderLibraryPlatformResource {
    public static var currentPlatformSuffix: String {
        #if os(visionOS)
            #if targetEnvironment(simulator)
                "xrossim"
            #else
                "xros"
            #endif
        #elseif os(iOS)
            #if targetEnvironment(simulator)
                "iossim"
            #else
                "ios"
            #endif
        #elseif os(tvOS)
            #if targetEnvironment(simulator)
                "tvossim"
            #else
                "tvos"
            #endif
        #else
            "macos"
        #endif
    }

    public static func resourceName(baseName: String) -> String {
        "\(baseName)-\(currentPlatformSuffix)"
    }
}

/// Describes a structured extension shader-library loading failure.
public enum RenderShaderLibraryLoadingError: Error, Equatable, Sendable, CustomStringConvertible {
    case metalUnavailable(libraryID: RenderShaderLibraryID)
    case resourceNotFound(
        libraryID: RenderShaderLibraryID,
        resource: String,
        subdirectory: String?
    )
    case defaultLibraryCreationFailed(libraryID: RenderShaderLibraryID, bundlePath: String)
    case metallibCreationFailed(
        libraryID: RenderShaderLibraryID,
        resource: String,
        subdirectory: String?
    )
    case libraryCreationFailed(libraryID: RenderShaderLibraryID, url: URL)

    public var description: String {
        switch self {
        case let .metalUnavailable(libraryID):
            return "Cannot load shader library '\(libraryID.rawValue)' before Metal is ready"
        case let .resourceNotFound(libraryID, resource, subdirectory):
            let location = subdirectory.map { " in '\($0)'" } ?? ""
            return "Shader library '\(libraryID.rawValue)' cannot find bundled metallib '\(resource).metallib'\(location)"
        case let .defaultLibraryCreationFailed(libraryID, bundlePath):
            return "Failed to create default shader library '\(libraryID.rawValue)' from bundle '\(bundlePath)'"
        case let .metallibCreationFailed(libraryID, resource, subdirectory):
            let location = subdirectory.map { " in '\($0)'" } ?? ""
            return "Failed to create shader library '\(libraryID.rawValue)' from bundled metallib '\(resource).metallib'\(location)"
        case let .libraryCreationFailed(libraryID, url):
            return "Failed to create shader library '\(libraryID.rawValue)' from '\(url.path)'"
        }
    }
}

private final class RenderShaderLibraryLoadingErrorCollector {
    private(set) var errors: [RenderShaderLibraryLoadingError] = []

    func record(_ error: RenderShaderLibraryLoadingError) {
        if !errors.contains(error) {
            errors.append(error)
        }
    }
}

protocol RenderShaderLibraryLoading: AnyObject {
    func resourceURL(
        in bundle: Bundle,
        resource: String,
        subdirectory: String?
    ) -> URL?

    func makeDefaultLibrary(device: MTLDevice, bundle: Bundle) throws -> MTLLibrary
    func makeLibrary(device: MTLDevice, url: URL) throws -> MTLLibrary
}

private final class DefaultRenderShaderLibraryLoader: RenderShaderLibraryLoading {
    func resourceURL(
        in bundle: Bundle,
        resource: String,
        subdirectory: String?
    ) -> URL? {
        bundle.url(
            forResource: resource,
            withExtension: "metallib",
            subdirectory: subdirectory
        )
    }

    func makeDefaultLibrary(device: MTLDevice, bundle: Bundle) throws -> MTLLibrary {
        try device.makeDefaultLibrary(bundle: bundle)
    }

    func makeLibrary(device: MTLDevice, url: URL) throws -> MTLLibrary {
        try device.makeLibrary(URL: url)
    }
}

private struct RenderShaderLibraryRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let loadingErrors: [RenderShaderLibraryLoadingError]
}

public enum RenderShaderLibraryReference: Sendable {
    case engine
    case registered(RenderShaderLibraryID)
}

public enum RenderExtensionModelSurfacePipelineValidation: Sendable {
    case disabled
    case warn(argumentLayoutID: String? = nil)
}

struct RenderExtensionShaderArgument {
    let name: String
    let index: Int
    let type: MTLBindingType
}

func resolveRenderShaderLibrary(
    _ reference: RenderShaderLibraryReference,
    usage: String
) -> MTLLibrary? {
    switch reference {
    case .engine:
        guard let library = renderInfo.library else {
            handleError(.metalLibraryNotFound)
            return nil
        }
        return library
    case let .registered(id):
        guard let library = RenderShaderLibraryManager.shared.library(id) else {
            Logger.logWarning(message: "[RenderExtension] Missing shader library '\(id.rawValue)' for \(usage)")
            return nil
        }
        return library
    }
}

public final class RenderShaderLibraryManager: @unchecked Sendable {
    public static let shared = RenderShaderLibraryManager()

    private let lock = NSLock()
    private let registrationLock = NSRecursiveLock()
    private var librariesByID: [RenderShaderLibraryID: MTLLibrary] = [:]
    private var libraryOwners: [RenderShaderLibraryID: String] = [:]
    private var currentRegistrationOwnerID: String?
    private var currentConflictCollector: RenderExtensionConflictCollector?
    private var currentLoadingErrorCollector: RenderShaderLibraryLoadingErrorCollector?
    private var loader: any RenderShaderLibraryLoading = DefaultRenderShaderLibraryLoader()

    private init() {}

    public func library(_ id: RenderShaderLibraryID) -> MTLLibrary? {
        lock.lock()
        let library = librariesByID[id]
        lock.unlock()
        return library
    }

    func update(_ library: MTLLibrary, forID id: RenderShaderLibraryID) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        if let ownerID = currentRegistrationOwnerID,
           librariesByID[id] != nil,
           libraryOwners[id] != ownerID
        {
            currentConflictCollector?.record(
                RenderExtensionArtifactConflict(
                    kind: .shaderLibrary,
                    artifactID: id.rawValue,
                    requestedOwnerID: ownerID,
                    existingOwnerID: libraryOwners[id]
                )
            )
            lock.unlock()
            return
        }
        librariesByID[id] = library
        if let currentRegistrationOwnerID {
            libraryOwners[id] = currentRegistrationOwnerID
        } else {
            libraryOwners.removeValue(forKey: id)
        }
        lock.unlock()
    }

    func load(_ id: RenderShaderLibraryID, source: RenderShaderLibrarySource) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        switch source {
        case let .library(library):
            update(library, forID: id)
        case let .defaultLibrary(bundle):
            guard let device = renderInfo.device else {
                recordLoadingError(.metalUnavailable(libraryID: id))
                return
            }
            do {
                try update(loader.makeDefaultLibrary(device: device, bundle: bundle), forID: id)
            } catch {
                recordLoadingError(
                    .defaultLibraryCreationFailed(
                        libraryID: id,
                        bundlePath: bundle.bundleURL.path
                    )
                )
            }
        case let .metallib(bundle, resource, subdirectory):
            guard let device = renderInfo.device else {
                recordLoadingError(.metalUnavailable(libraryID: id))
                return
            }
            guard let url = loader.resourceURL(
                in: bundle,
                resource: resource,
                subdirectory: subdirectory
            ) else {
                recordLoadingError(
                    .resourceNotFound(
                        libraryID: id,
                        resource: resource,
                        subdirectory: subdirectory
                    )
                )
                return
            }
            do {
                try update(loader.makeLibrary(device: device, url: url), forID: id)
            } catch {
                recordLoadingError(
                    .metallibCreationFailed(
                        libraryID: id,
                        resource: resource,
                        subdirectory: subdirectory
                    )
                )
            }
        }
    }

    func load(_ id: RenderShaderLibraryID, url: URL) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        guard let device = renderInfo.device else {
            recordLoadingError(.metalUnavailable(libraryID: id))
            return
        }
        do {
            try update(loader.makeLibrary(device: device, url: url), forID: id)
        } catch {
            recordLoadingError(.libraryCreationFailed(libraryID: id, url: url))
        }
    }

    func removeLibraries(ownerID: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let ownedIDs = libraryOwners.compactMap { id, owner in
            owner == ownerID ? id : nil
        }
        for id in ownedIDs {
            librariesByID.removeValue(forKey: id)
            libraryOwners.removeValue(forKey: id)
        }
        lock.unlock()
    }

    func removeAll() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        librariesByID.removeAll()
        libraryOwners.removeAll()
        lock.unlock()
    }

    @discardableResult
    fileprivate func registerLibraries(
        ownerID: String,
        _ registerBlock: (RenderShaderLibraryRegistry) -> Void
    ) -> RenderShaderLibraryRegistrationReport {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let previousOwnerID = currentRegistrationOwnerID
        let previousCollector = currentConflictCollector
        let previousLoadingErrorCollector = currentLoadingErrorCollector
        let conflictCollector = RenderExtensionConflictCollector()
        let loadingErrorCollector = RenderShaderLibraryLoadingErrorCollector()
        currentRegistrationOwnerID = ownerID
        currentConflictCollector = conflictCollector
        currentLoadingErrorCollector = loadingErrorCollector
        lock.unlock()

        registerBlock(RenderShaderLibraryRegistry())

        lock.lock()
        currentRegistrationOwnerID = previousOwnerID
        currentConflictCollector = previousCollector
        currentLoadingErrorCollector = previousLoadingErrorCollector
        lock.unlock()
        return RenderShaderLibraryRegistrationReport(
            conflicts: conflictCollector.conflicts,
            loadingErrors: loadingErrorCollector.errors
        )
    }

    func replaceLoaderForTesting(
        _ replacement: any RenderShaderLibraryLoading
    ) -> any RenderShaderLibraryLoading {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        let previous = loader
        loader = replacement
        return previous
    }

    private func recordLoadingError(_ error: RenderShaderLibraryLoadingError) {
        lock.lock()
        let collector = currentLoadingErrorCollector
        lock.unlock()
        if let collector {
            collector.record(error)
        } else {
            Logger.logWarning(message: "[RenderExtension] \(error.description)")
        }
    }
}

public struct RenderShaderLibraryRegistry {
    public init() {}

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        library: MTLLibrary
    ) {
        registerLibrary(id, source: .library(library))
    }

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        source: RenderShaderLibrarySource
    ) {
        RenderShaderLibraryManager.shared.load(id, source: source)
    }

    public func registerDefaultLibrary(
        _ id: RenderShaderLibraryID,
        bundle: Bundle
    ) {
        registerLibrary(id, source: .defaultLibrary(bundle: bundle))
    }

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        bundle: Bundle,
        resource: String,
        subdirectory: String? = nil
    ) {
        registerLibrary(
            id,
            source: .metallib(
                bundle: bundle,
                resource: resource,
                subdirectory: subdirectory
            )
        )
    }

    public func registerPlatformLibrary(
        _ id: RenderShaderLibraryID,
        bundle: Bundle,
        baseResource: String,
        subdirectory: String? = nil
    ) {
        registerLibrary(
            id,
            bundle: bundle,
            resource: RenderShaderLibraryPlatformResource.resourceName(baseName: baseResource),
            subdirectory: subdirectory
        )
    }

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        url: URL
    ) {
        RenderShaderLibraryManager.shared.load(id, url: url)
    }
}

public struct RenderPipelineRegistry {
    public init() {}

    public func registerRenderPipeline(
        _ type: RenderPipelineType,
        initBlock: RenderPipelineInitBlock
    ) {
        guard let pipeline = initBlock(), pipeline.success else {
            PipelineManager.shared.recordRegistrationError(
                .creationFailed(kind: .renderPipeline, pipelineID: type.rawValue)
            )
            return
        }
        PipelineManager.shared.update(rendererPipeLine: pipeline, forType: type)
    }

    public func registerRenderPipeline(
        _ descriptor: RenderExtensionRenderPipelineDescriptor
    ) {
        let errors = validateRenderExtensionRenderPipeline(descriptor)
        guard errors.isEmpty else {
            for error in errors {
                PipelineManager.shared.recordRegistrationError(error)
            }
            return
        }
        guard let pipeline = RenderExtensionPipelineCreator.shared.makeRenderPipeline(descriptor),
              pipeline.success
        else {
            PipelineManager.shared.recordRegistrationError(
                .creationFailed(
                    kind: .renderPipeline,
                    pipelineID: descriptor.id.rawValue
                )
            )
            return
        }
        PipelineManager.shared.update(rendererPipeLine: pipeline, forType: descriptor.id)
    }

    public func registerRenderPipeline(
        _ type: RenderPipelineType,
        vertexShader: String,
        fragmentShader: String?,
        vertexShaderLibrary: RenderShaderLibraryReference = .engine,
        fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
        vertexDescriptor: MTLVertexDescriptor?,
        colorFormats: [MTLPixelFormat],
        depthFormat: MTLPixelFormat,
        depthCompareFunction: MTLCompareFunction = .lessEqual,
        depthEnabled: Bool = true,
        reverseZCompatible: Bool = true,
        blendMode: PipelineBlendMode = .none,
        name: String
    ) {
        registerRenderPipeline(
            RenderExtensionRenderPipelineDescriptor(
                id: type,
                vertexFunction: vertexShader,
                fragmentFunction: fragmentShader,
                vertexShaderLibrary: vertexShaderLibrary,
                fragmentShaderLibrary: fragmentShaderLibrary,
                vertexDescriptor: vertexDescriptor,
                colorFormats: colorFormats,
                depthFormat: depthFormat,
                depthCompareFunction: depthCompareFunction,
                depthEnabled: depthEnabled,
                reverseZCompatible: reverseZCompatible,
                blendMode: blendMode,
                name: name
            )
        )
    }

    public func registerModelSurfacePipeline(
        _ type: RenderPipelineType,
        fragmentShader: String,
        fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
        colorFormats: [MTLPixelFormat]? = nil,
        depthFormat: MTLPixelFormat? = nil,
        depthCompareFunction: MTLCompareFunction = .lessEqual,
        depthEnabled: Bool = false,
        blendMode: PipelineBlendMode = .alphaPremultiplied,
        name: String,
        validation: RenderExtensionModelSurfacePipelineValidation = .disabled
    ) {
        registerRenderPipeline(type) {
            CreatePipeline(
                vertexShader: "vertexModelShader",
                fragmentShader: fragmentShader,
                fragmentShaderLibrary: fragmentShaderLibrary,
                vertexDescriptor: createModelVertexDescriptor(),
                colorFormats: colorFormats ?? [renderInfo.colorPipeline.working.sceneColor],
                depthFormat: depthFormat ?? renderInfo.depthPixelFormat,
                depthCompareFunction: depthCompareFunction,
                depthEnabled: depthEnabled,
                blendMode: blendMode,
                name: name,
                reflectionHandler: modelSurfacePipelineReflectionHandler(
                    validation: validation,
                    pipelineName: name,
                    fragmentShader: fragmentShader
                )
            )
        }
    }

    /// Registers a pipeline for custom geometry drawn into the working scene targets.
    /// The engine-owned scene color and depth formats are resolved at registration time.
    public func registerScenePipeline(
        _ type: RenderPipelineType,
        vertexShader: String,
        fragmentShader: String?,
        vertexShaderLibrary: RenderShaderLibraryReference = .engine,
        fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
        vertexDescriptor: MTLVertexDescriptor? = nil,
        depthCompareFunction: MTLCompareFunction = .lessEqual,
        depthEnabled: Bool = true,
        reverseZCompatible: Bool = true,
        blendMode: PipelineBlendMode = .none,
        name: String
    ) {
        registerRenderPipeline(
            type,
            vertexShader: vertexShader,
            fragmentShader: fragmentShader,
            vertexShaderLibrary: vertexShaderLibrary,
            fragmentShaderLibrary: fragmentShaderLibrary,
            vertexDescriptor: vertexDescriptor,
            colorFormats: [renderInfo.colorPipeline.working.sceneColor],
            depthFormat: renderInfo.depthPixelFormat,
            depthCompareFunction: depthCompareFunction,
            depthEnabled: depthEnabled,
            reverseZCompatible: reverseZCompatible,
            blendMode: blendMode,
            name: name
        )
    }
}

private func modelSurfacePipelineReflectionHandler(
    validation: RenderExtensionModelSurfacePipelineValidation,
    pipelineName: String,
    fragmentShader: String
) -> ((MTLRenderPipelineReflection) -> Void)? {
    switch validation {
    case .disabled:
        return nil
    case let .warn(argumentLayoutID):
        return { reflection in
            let arguments = reflection.fragmentBindings.map {
                RenderExtensionShaderArgument(
                    name: $0.name,
                    index: $0.index,
                    type: $0.type
                )
            }
            validateModelSurfaceExtensionPipelineArguments(
                arguments,
                argumentLayoutID: argumentLayoutID,
                pipelineName: pipelineName,
                fragmentShader: fragmentShader
            )
        }
    }
}

@discardableResult
func validateModelSurfaceExtensionPipelineArguments(
    _ arguments: [RenderExtensionShaderArgument],
    argumentLayoutID: String?,
    pipelineName: String,
    fragmentShader: String
) -> Bool {
    let expectedArgumentBufferIndex = RenderExtensionModelSurfaceArgument.argumentBufferIndex
    let hasExpectedArgumentBuffer = arguments.contains {
        $0.type == .buffer && $0.index == expectedArgumentBufferIndex
    }
    var isValid = true

    if !hasExpectedArgumentBuffer {
        isValid = false
        Logger.logWarning(
            message: "[RenderExtension] Model-surface pipeline '\(pipelineName)' fragment '\(fragmentShader)' does not declare an extension argument buffer at [[buffer(\(expectedArgumentBufferIndex))]]"
        )
    }

    let misplacedExtensionBuffers = arguments.filter {
        $0.type == .buffer
            && (11 ... 13).contains($0.index)
    }
    if !misplacedExtensionBuffers.isEmpty {
        isValid = false
        let slots = misplacedExtensionBuffers.map { "\($0.index)" }.joined(separator: ", ")
        Logger.logWarning(
            message: "[RenderExtension] Model-surface pipeline '\(pipelineName)' uses fragment buffer slot(s) \(slots) in the legacy extension range; use the argument buffer at [[buffer(\(expectedArgumentBufferIndex))]] instead"
        )
    }

    let rawExtensionTextures = arguments.filter {
        $0.type == .texture
            && (10 ... 13).contains($0.index)
    }
    if !rawExtensionTextures.isEmpty {
        isValid = false
        let slots = rawExtensionTextures.map { "\($0.index)" }.joined(separator: ", ")
        Logger.logWarning(
            message: "[RenderExtension] Model-surface pipeline '\(pipelineName)' uses raw fragment texture slot(s) \(slots) in the legacy extension range; move them into the extension argument buffer"
        )
    }

    if let argumentLayoutID,
       RenderExtensionArgumentBufferRegistry.shared.descriptor(argumentLayoutID) == nil
    {
        isValid = false
        Logger.logWarning(
            message: "[RenderExtension] Model-surface pipeline '\(pipelineName)' references missing argument layout '\(argumentLayoutID)'"
        )
    }

    return isValid
}

public struct ComputePipelineType: Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public typealias ComputePipelineInitBlock = () -> ComputePipeline?

public final class ComputePipelineManager: @unchecked Sendable {
    public static let shared = ComputePipelineManager()

    private let lock = NSLock()
    private let registrationLock = NSRecursiveLock()
    private var computePipelinesByType: [ComputePipelineType: ComputePipeline] = [:]
    private var computePipelineOwners: [ComputePipelineType: String] = [:]
    private var currentRegistrationOwnerID: String?
    private var currentConflictCollector: RenderExtensionConflictCollector?
    private var currentErrorCollector: RenderExtensionPipelineErrorCollector?
    private var currentRegistrationIDs: Set<ComputePipelineType>?

    private init() {}

    public func pipeline(for type: ComputePipelineType) -> ComputePipeline? {
        lock.lock()
        let pipeline = computePipelinesByType[type]
        lock.unlock()
        return pipeline
    }

    func update(_ pipeline: ComputePipeline, forType type: ComputePipelineType) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        if currentRegistrationOwnerID != nil,
           currentRegistrationIDs?.insert(type).inserted == false
        {
            currentErrorCollector?.record(
                .duplicatePipelineID(kind: .computePipeline, pipelineID: type.rawValue)
            )
            lock.unlock()
            return
        }
        if let ownerID = currentRegistrationOwnerID,
           computePipelinesByType[type] != nil,
           computePipelineOwners[type] != ownerID
        {
            currentConflictCollector?.record(
                RenderExtensionArtifactConflict(
                    kind: .computePipeline,
                    artifactID: type.rawValue,
                    requestedOwnerID: ownerID,
                    existingOwnerID: computePipelineOwners[type]
                )
            )
            lock.unlock()
            return
        }
        computePipelinesByType[type] = pipeline
        if let currentRegistrationOwnerID {
            computePipelineOwners[type] = currentRegistrationOwnerID
        } else {
            computePipelineOwners.removeValue(forKey: type)
        }
        lock.unlock()
    }

    func removePipelines(ownerID: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let ownedTypes = computePipelineOwners.compactMap { type, owner in
            owner == ownerID ? type : nil
        }
        for type in ownedTypes {
            computePipelinesByType.removeValue(forKey: type)
            computePipelineOwners.removeValue(forKey: type)
        }
        lock.unlock()
    }

    func removeAll() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        computePipelinesByType.removeAll()
        computePipelineOwners.removeAll()
        lock.unlock()
    }

    @discardableResult
    func registerPipelines(
        ownerID: String,
        _ registerBlock: (ComputePipelineRegistry) -> Void
    ) -> RenderExtensionPipelineRegistrationReport {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let previousOwnerID = currentRegistrationOwnerID
        let previousCollector = currentConflictCollector
        let previousErrorCollector = currentErrorCollector
        let previousRegistrationIDs = currentRegistrationIDs
        let conflictCollector = RenderExtensionConflictCollector()
        let errorCollector = RenderExtensionPipelineErrorCollector()
        currentRegistrationOwnerID = ownerID
        currentConflictCollector = conflictCollector
        currentErrorCollector = errorCollector
        currentRegistrationIDs = []
        lock.unlock()

        registerBlock(ComputePipelineRegistry())

        lock.lock()
        currentRegistrationOwnerID = previousOwnerID
        currentConflictCollector = previousCollector
        currentErrorCollector = previousErrorCollector
        currentRegistrationIDs = previousRegistrationIDs
        lock.unlock()
        return RenderExtensionPipelineRegistrationReport(
            conflicts: conflictCollector.conflicts,
            errors: errorCollector.errors
        )
    }

    func recordRegistrationError(_ error: RenderExtensionPipelineError) {
        lock.lock()
        let collector = currentErrorCollector
        lock.unlock()
        if let collector {
            collector.record(error)
        } else {
            Logger.logWarning(message: "[RenderExtension] \(error.description)")
        }
    }
}

public struct ComputePipelineRegistry {
    public init() {}

    public func registerComputePipeline(
        _ type: ComputePipelineType,
        initBlock: ComputePipelineInitBlock
    ) {
        guard let pipeline = initBlock(), pipeline.success else {
            ComputePipelineManager.shared.recordRegistrationError(
                .creationFailed(kind: .computePipeline, pipelineID: type.rawValue)
            )
            return
        }
        ComputePipelineManager.shared.update(pipeline, forType: type)
    }

    public func registerComputePipeline(
        _ descriptor: RenderExtensionComputePipelineDescriptor
    ) {
        let validation = validateRenderExtensionComputePipeline(descriptor)
        guard validation.errors.isEmpty, let library = validation.library else {
            for error in validation.errors {
                ComputePipelineManager.shared.recordRegistrationError(error)
            }
            return
        }
        guard let pipeline = RenderExtensionPipelineCreator.shared.makeComputePipeline(
            descriptor,
            library: library
        ), pipeline.success else {
            ComputePipelineManager.shared.recordRegistrationError(
                .creationFailed(
                    kind: .computePipeline,
                    pipelineID: descriptor.id.rawValue
                )
            )
            return
        }
        ComputePipelineManager.shared.update(pipeline, forType: descriptor.id)
    }

    public func registerComputePipeline(
        _ type: ComputePipelineType,
        functionName: String,
        shaderLibrary: RenderShaderLibraryReference = .engine,
        pipelineName: String
    ) {
        registerComputePipeline(
            RenderExtensionComputePipelineDescriptor(
                id: type,
                function: functionName,
                shaderLibrary: shaderLibrary,
                name: pipelineName
            )
        )
    }
}

public struct ComputePipelineAccess {
    public init() {}

    public func pipeline(_ type: ComputePipelineType) -> ComputePipeline? {
        ComputePipelineManager.shared.pipeline(for: type)
    }
}

/// Read-only access to render pipelines available to an executing extension pass.
public struct RenderPipelineAccess {
    public init() {}

    public func pipeline(_ type: RenderPipelineType) -> RenderPipeline? {
        PipelineManager.shared.pipeline(for: type)
    }
}

public struct RenderTextureResourceID: RawRepresentable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public struct RenderBufferResourceID: RawRepresentable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        rawValue = value
    }
}

public enum RenderExtensionResourceLifetime: Equatable, Sendable {
    /// The resource remains allocated while its owning extension is registered.
    case persistent

    /// The resource is eligible for render-graph lifetime planning and backing-store reuse.
    case transient
}

public enum RenderExtensionResourceSize: Equatable, Sendable {
    case viewportScale(Float)
    case fixed(width: Int, height: Int)
}

public enum RenderExtensionResourceValidationError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyID
    case invalidViewportScale(id: String, scale: Float)
    case invalidTextureDimensions(id: String, width: Int, height: Int)
    case emptyTextureUsage(id: String)
    case invalidMipMapLevels(id: String, count: Int)
    case invalidSampleCount(id: String, count: Int)
    case multisampledTextureHasMipmaps(id: String)
    case invalidBufferLength(id: String, length: Int)

    public var description: String {
        switch self {
        case .emptyID:
            return "Render extension resource IDs cannot be empty"
        case let .invalidViewportScale(id, scale):
            return "Texture resource '\(id)' has invalid viewport scale \(scale)"
        case let .invalidTextureDimensions(id, width, height):
            return "Texture resource '\(id)' has invalid dimensions \(width)x\(height)"
        case let .emptyTextureUsage(id):
            return "Texture resource '\(id)' must declare at least one usage"
        case let .invalidMipMapLevels(id, count):
            return "Texture resource '\(id)' has invalid mipmap level count \(count)"
        case let .invalidSampleCount(id, count):
            return "Texture resource '\(id)' has invalid sample count \(count)"
        case let .multisampledTextureHasMipmaps(id):
            return "Multisampled texture resource '\(id)' cannot declare mipmaps"
        case let .invalidBufferLength(id, length):
            return "Buffer resource '\(id)' has invalid length \(length)"
        }
    }
}

public enum RenderExtensionResourceState: String, Equatable, Sendable {
    case declared
    case allocated
    case invalidated
    case released
}

public enum RenderExtensionResourceAllocationFailure: Equatable, Sendable {
    case textureCreationFailed(width: Int, height: Int)
    case bufferCreationFailed(length: Int)
}

public struct RenderExtensionResourceAllocationError: Error, Equatable, Sendable, CustomStringConvertible {
    public let kind: RenderExtensionArtifactKind
    public let resourceID: String
    public let ownerID: String?
    public let failure: RenderExtensionResourceAllocationFailure

    public init(
        kind: RenderExtensionArtifactKind,
        resourceID: String,
        ownerID: String?,
        failure: RenderExtensionResourceAllocationFailure
    ) {
        self.kind = kind
        self.resourceID = resourceID
        self.ownerID = ownerID
        self.failure = failure
    }

    public var description: String {
        let owner = ownerID.map { " for extension '\($0)'" } ?? ""
        switch failure {
        case let .textureCreationFailed(width, height):
            return "Failed to allocate texture resource '\(resourceID)'\(owner) at \(width)x\(height)"
        case let .bufferCreationFailed(length):
            return "Failed to allocate buffer resource '\(resourceID)'\(owner) with length \(length)"
        }
    }
}

public struct RenderExtensionTextureDescriptor: Sendable {
    public let id: RenderTextureResourceID
    public let label: String
    public let size: RenderExtensionResourceSize
    public let pixelFormat: MTLPixelFormat
    public let usage: MTLTextureUsage
    public let storageMode: MTLStorageMode
    public let mipMapLevels: Int
    public let sampleCount: Int
    public let lifetime: RenderExtensionResourceLifetime

    public init(
        id: RenderTextureResourceID,
        label: String? = nil,
        size: RenderExtensionResourceSize,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode = .private,
        mipMapLevels: Int = 1,
        sampleCount: Int = 1,
        lifetime: RenderExtensionResourceLifetime = .persistent
    ) {
        self.id = id
        self.label = label ?? id.rawValue
        self.size = size
        self.pixelFormat = pixelFormat
        self.usage = usage
        self.storageMode = storageMode
        self.mipMapLevels = mipMapLevels
        self.sampleCount = sampleCount
        self.lifetime = lifetime
    }

    public init(
        id: String,
        label: String? = nil,
        size: RenderExtensionResourceSize,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode = .private,
        mipMapLevels: Int = 1,
        sampleCount: Int = 1,
        lifetime: RenderExtensionResourceLifetime = .persistent
    ) {
        self.init(
            id: RenderTextureResourceID(id),
            label: label,
            size: size,
            pixelFormat: pixelFormat,
            usage: usage,
            storageMode: storageMode,
            mipMapLevels: mipMapLevels,
            sampleCount: sampleCount,
            lifetime: lifetime
        )
    }

    public func validationErrors() -> [RenderExtensionResourceValidationError] {
        var errors: [RenderExtensionResourceValidationError] = []
        let resourceID = id.rawValue

        if resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyID)
        }
        switch size {
        case let .viewportScale(scale):
            if !scale.isFinite || scale <= 0 {
                errors.append(.invalidViewportScale(id: resourceID, scale: scale))
            }
        case let .fixed(width, height):
            if width <= 0 || height <= 0 {
                errors.append(.invalidTextureDimensions(id: resourceID, width: width, height: height))
            }
        }
        if usage.isEmpty {
            errors.append(.emptyTextureUsage(id: resourceID))
        }
        if mipMapLevels < 1 {
            errors.append(.invalidMipMapLevels(id: resourceID, count: mipMapLevels))
        }
        if sampleCount < 1 {
            errors.append(.invalidSampleCount(id: resourceID, count: sampleCount))
        }
        if sampleCount > 1, mipMapLevels > 1 {
            errors.append(.multisampledTextureHasMipmaps(id: resourceID))
        }
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public struct RenderExtensionBufferDescriptor: Sendable {
    public let id: RenderBufferResourceID
    public let label: String
    public let length: Int
    public let options: MTLResourceOptions
    public let lifetime: RenderExtensionResourceLifetime

    public init(
        id: RenderBufferResourceID,
        label: String? = nil,
        length: Int,
        options: MTLResourceOptions = .storageModeShared,
        lifetime: RenderExtensionResourceLifetime = .persistent
    ) {
        self.id = id
        self.label = label ?? id.rawValue
        self.length = length
        self.options = options
        self.lifetime = lifetime
    }

    public init(
        id: String,
        label: String? = nil,
        length: Int,
        options: MTLResourceOptions = .storageModeShared,
        lifetime: RenderExtensionResourceLifetime = .persistent
    ) {
        self.init(
            id: RenderBufferResourceID(id),
            label: label,
            length: length,
            options: options,
            lifetime: lifetime
        )
    }

    public func validationErrors() -> [RenderExtensionResourceValidationError] {
        var errors: [RenderExtensionResourceValidationError] = []
        let resourceID = id.rawValue

        if resourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyID)
        }
        if length <= 0 {
            errors.append(.invalidBufferLength(id: resourceID, length: length))
        }
        return errors
    }

    public func validate() throws {
        if let error = validationErrors().first {
            throw error
        }
    }
}

public struct RenderResourceAccess {
    private let allowedTextureIDs: Set<RenderTextureResourceID>?
    private let allowedBufferIDs: Set<RenderBufferResourceID>?

    public init() {
        allowedTextureIDs = nil
        allowedBufferIDs = nil
    }

    init(resourceUsages: [RenderGraphResourceUsage]) {
        allowedTextureIDs = Set(resourceUsages.compactMap { usage in
            if case let .texture(id, _) = usage { return id }
            return nil
        })
        allowedBufferIDs = Set(resourceUsages.compactMap { usage in
            if case let .buffer(id, _) = usage { return id }
            return nil
        })
    }

    public func texture(_ id: RenderTextureResourceID) -> MTLTexture? {
        guard allowedTextureIDs?.contains(id) != false else { return nil }
        return RenderResourceRegistry.shared.texture(id)
    }

    public func texture(_ id: String) -> MTLTexture? {
        texture(RenderTextureResourceID(id))
    }

    public func buffer(_ id: RenderBufferResourceID) -> MTLBuffer? {
        guard allowedBufferIDs?.contains(id) != false else { return nil }
        return RenderResourceRegistry.shared.buffer(id)
    }

    public func buffer(_ id: String) -> MTLBuffer? {
        buffer(RenderBufferResourceID(id))
    }

    public func textureState(_ id: RenderTextureResourceID) -> RenderExtensionResourceState? {
        guard allowedTextureIDs?.contains(id) != false else { return nil }
        return RenderResourceRegistry.shared.textureState(id)
    }

    public func textureState(_ id: String) -> RenderExtensionResourceState? {
        textureState(RenderTextureResourceID(id))
    }

    public func bufferState(_ id: RenderBufferResourceID) -> RenderExtensionResourceState? {
        guard allowedBufferIDs?.contains(id) != false else { return nil }
        return RenderResourceRegistry.shared.bufferState(id)
    }

    public func bufferState(_ id: String) -> RenderExtensionResourceState? {
        bufferState(RenderBufferResourceID(id))
    }
}

public struct RenderExtensionArgumentTexture {
    public let id: Int
    public let textureType: MTLTextureType
    public let access: MTLBindingAccess

    public init(
        id: Int,
        textureType: MTLTextureType = .type2D,
        access: MTLBindingAccess = .readOnly
    ) {
        self.id = id
        self.textureType = textureType
        self.access = access
    }
}

public struct RenderExtensionArgumentSampler {
    public let id: Int

    public init(id: Int) {
        self.id = id
    }
}

public struct RenderExtensionArgumentBuffer {
    public let id: Int
    public let access: MTLBindingAccess

    public init(
        id: Int,
        access: MTLBindingAccess = .readOnly
    ) {
        self.id = id
        self.access = access
    }
}

public struct RenderExtensionArgumentBufferDescriptor {
    public let id: String
    public let textures: [RenderExtensionArgumentTexture]
    public let samplers: [RenderExtensionArgumentSampler]
    public let buffers: [RenderExtensionArgumentBuffer]

    public init(
        id: String,
        textures: [RenderExtensionArgumentTexture] = [],
        samplers: [RenderExtensionArgumentSampler] = [],
        buffers: [RenderExtensionArgumentBuffer] = []
    ) {
        self.id = id
        self.textures = textures
        self.samplers = samplers
        self.buffers = buffers
    }
}

public final class RenderExtensionArgumentBufferRegistry: @unchecked Sendable {
    public static let shared = RenderExtensionArgumentBufferRegistry()

    private let lock = NSLock()
    private let registrationLock = NSRecursiveLock()
    private var descriptorsByID: [String: RenderExtensionArgumentBufferDescriptor] = [:]
    private var descriptorOwners: [String: String] = [:]
    private var currentRegistrationOwnerID: String?
    private var currentConflictCollector: RenderExtensionConflictCollector?

    private init() {}

    public func registerArgumentBuffer(_ descriptor: RenderExtensionArgumentBufferDescriptor) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        if let ownerID = currentRegistrationOwnerID,
           descriptorsByID[descriptor.id] != nil,
           descriptorOwners[descriptor.id] != ownerID
        {
            currentConflictCollector?.record(
                RenderExtensionArtifactConflict(
                    kind: .argumentBuffer,
                    artifactID: descriptor.id,
                    requestedOwnerID: ownerID,
                    existingOwnerID: descriptorOwners[descriptor.id]
                )
            )
            lock.unlock()
            return
        }
        descriptorsByID[descriptor.id] = descriptor
        if let currentRegistrationOwnerID {
            descriptorOwners[descriptor.id] = currentRegistrationOwnerID
        } else {
            descriptorOwners.removeValue(forKey: descriptor.id)
        }
        lock.unlock()
    }

    public func descriptor(_ id: String) -> RenderExtensionArgumentBufferDescriptor? {
        lock.lock()
        let descriptor = descriptorsByID[id]
        lock.unlock()
        return descriptor
    }

    public func registeredIDs() -> [String] {
        lock.lock()
        let ids = Array(descriptorsByID.keys)
        lock.unlock()
        return ids
    }

    public func removeAll() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        descriptorsByID.removeAll()
        descriptorOwners.removeAll()
        lock.unlock()
    }

    func removeArgumentBuffers(ownerID: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let ownedIDs = descriptorOwners.compactMap { id, owner in
            owner == ownerID ? id : nil
        }
        for id in ownedIDs {
            descriptorsByID.removeValue(forKey: id)
            descriptorOwners.removeValue(forKey: id)
        }
        lock.unlock()
    }

    @discardableResult
    func registerArgumentBuffers(
        ownerID: String,
        _ registerBlock: (RenderExtensionArgumentBufferRegistry) -> Void
    ) -> [RenderExtensionArtifactConflict] {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let previousOwnerID = currentRegistrationOwnerID
        let previousCollector = currentConflictCollector
        let collector = RenderExtensionConflictCollector()
        currentRegistrationOwnerID = ownerID
        currentConflictCollector = collector
        lock.unlock()

        registerBlock(self)

        lock.lock()
        currentRegistrationOwnerID = previousOwnerID
        currentConflictCollector = previousCollector
        lock.unlock()
        return collector.conflicts
    }
}

protocol RenderExtensionResourceAllocating: AnyObject {
    func makeTexture(
        device: MTLDevice,
        descriptor: RenderExtensionTextureDescriptor,
        width: Int,
        height: Int
    ) -> MTLTexture?

    func makeBuffer(
        device: MTLDevice,
        descriptor: RenderExtensionBufferDescriptor
    ) -> MTLBuffer?
}

private final class DefaultRenderExtensionResourceAllocator: RenderExtensionResourceAllocating {
    func makeTexture(
        device: MTLDevice,
        descriptor: RenderExtensionTextureDescriptor,
        width: Int,
        height: Int
    ) -> MTLTexture? {
        createTexture(
            device: device,
            label: descriptor.label,
            pixelFormat: descriptor.pixelFormat,
            width: width,
            height: height,
            usage: descriptor.usage,
            storageMode: descriptor.storageMode,
            mipMapLevels: descriptor.mipMapLevels,
            sampleCount: descriptor.sampleCount
        )
    }

    func makeBuffer(
        device: MTLDevice,
        descriptor: RenderExtensionBufferDescriptor
    ) -> MTLBuffer? {
        createEmptyBuffer(
            device: device,
            length: descriptor.length,
            options: descriptor.options,
            label: descriptor.label
        )
    }
}

private final class RenderResourceDeclarationCollector {
    let ownerID: String
    var textureDescriptors: [RenderExtensionTextureDescriptor] = []
    var bufferDescriptors: [RenderExtensionBufferDescriptor] = []

    init(ownerID: String) {
        self.ownerID = ownerID
    }
}

private struct RenderResourceRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let validationErrors: [RenderExtensionResourceValidationError]
    let committed: Bool

    var succeeded: Bool {
        conflicts.isEmpty && validationErrors.isEmpty
    }
}

public final class RenderResourceRegistry: @unchecked Sendable {
    public static let shared = RenderResourceRegistry()

    private let lock = NSLock()
    private let registrationLock = NSRecursiveLock()
    private var textureDescriptors: [RenderTextureResourceID: RenderExtensionTextureDescriptor] = [:]
    private var textures: [RenderTextureResourceID: MTLTexture] = [:]
    private var textureOwners: [RenderTextureResourceID: String] = [:]
    private var textureStates: [RenderTextureResourceID: RenderExtensionResourceState] = [:]
    private var textureAllocationErrors: [RenderTextureResourceID: RenderExtensionResourceAllocationError] = [:]
    private var bufferDescriptors: [RenderBufferResourceID: RenderExtensionBufferDescriptor] = [:]
    private var buffers: [RenderBufferResourceID: MTLBuffer] = [:]
    private var bufferOwners: [RenderBufferResourceID: String] = [:]
    private var bufferStates: [RenderBufferResourceID: RenderExtensionResourceState] = [:]
    private var bufferAllocationErrors: [RenderBufferResourceID: RenderExtensionResourceAllocationError] = [:]
    private var currentDeclarationCollector: RenderResourceDeclarationCollector?
    private var allocator: any RenderExtensionResourceAllocating = DefaultRenderExtensionResourceAllocator()

    private init() {}

    public func registerTexture(_ descriptor: RenderExtensionTextureDescriptor) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        if let currentDeclarationCollector {
            currentDeclarationCollector.textureDescriptors.append(descriptor)
            return
        }

        let validationErrors = descriptor.validationErrors()
        guard validationErrors.isEmpty else {
            logValidationErrors(validationErrors)
            return
        }

        lock.lock()
        textureDescriptors[descriptor.id] = descriptor
        textures.removeValue(forKey: descriptor.id)
        textureOwners.removeValue(forKey: descriptor.id)
        textureStates[descriptor.id] = .declared
        textureAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()

        if renderInfo.device != nil, hasValidViewport {
            allocateTexture(descriptor)
        }
    }

    public func texture(_ id: String) -> MTLTexture? {
        texture(RenderTextureResourceID(id))
    }

    public func texture(_ id: RenderTextureResourceID) -> MTLTexture? {
        lock.lock()
        let texture = textureStates[id] == .allocated ? textures[id] : nil
        lock.unlock()
        return texture
    }

    public func textureState(_ id: RenderTextureResourceID) -> RenderExtensionResourceState? {
        lock.lock()
        let state = textureStates[id]
        lock.unlock()
        return state
    }

    public func textureState(_ id: String) -> RenderExtensionResourceState? {
        textureState(RenderTextureResourceID(id))
    }

    public func textureAllocationError(
        _ id: RenderTextureResourceID
    ) -> RenderExtensionResourceAllocationError? {
        lock.lock()
        let error = textureAllocationErrors[id]
        lock.unlock()
        return error
    }

    public func registerBuffer(_ descriptor: RenderExtensionBufferDescriptor) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        if let currentDeclarationCollector {
            currentDeclarationCollector.bufferDescriptors.append(descriptor)
            return
        }

        let validationErrors = descriptor.validationErrors()
        guard validationErrors.isEmpty else {
            logValidationErrors(validationErrors)
            return
        }

        lock.lock()
        bufferDescriptors[descriptor.id] = descriptor
        buffers.removeValue(forKey: descriptor.id)
        bufferOwners.removeValue(forKey: descriptor.id)
        bufferStates[descriptor.id] = .declared
        bufferAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()

        if renderInfo.device != nil {
            allocateBuffer(descriptor)
        }
    }

    public func buffer(_ id: String) -> MTLBuffer? {
        buffer(RenderBufferResourceID(id))
    }

    public func buffer(_ id: RenderBufferResourceID) -> MTLBuffer? {
        lock.lock()
        let buffer = bufferStates[id] == .allocated ? buffers[id] : nil
        lock.unlock()
        return buffer
    }

    public func bufferState(_ id: RenderBufferResourceID) -> RenderExtensionResourceState? {
        lock.lock()
        let state = bufferStates[id]
        lock.unlock()
        return state
    }

    public func bufferState(_ id: String) -> RenderExtensionResourceState? {
        bufferState(RenderBufferResourceID(id))
    }

    public func bufferAllocationError(
        _ id: RenderBufferResourceID
    ) -> RenderExtensionResourceAllocationError? {
        lock.lock()
        let error = bufferAllocationErrors[id]
        lock.unlock()
        return error
    }

    func textureDeclaration(
        _ id: RenderTextureResourceID
    ) -> (descriptor: RenderExtensionTextureDescriptor, ownerID: String?)? {
        lock.lock()
        guard let descriptor = textureDescriptors[id] else {
            lock.unlock()
            return nil
        }
        let ownerID = textureOwners[id]
        lock.unlock()
        return (descriptor, ownerID)
    }

    func bufferDeclaration(
        _ id: RenderBufferResourceID
    ) -> (descriptor: RenderExtensionBufferDescriptor, ownerID: String?)? {
        lock.lock()
        guard let descriptor = bufferDescriptors[id] else {
            lock.unlock()
            return nil
        }
        let ownerID = bufferOwners[id]
        lock.unlock()
        return (descriptor, ownerID)
    }

    func declarationSnapshot() -> [RenderGraphResourceDeclarationSnapshot] {
        lock.lock()
        let textures = textureDescriptors.map { id, descriptor in
            RenderGraphResourceDeclarationSnapshot(
                kind: .texture,
                resourceID: id.rawValue,
                ownerID: textureOwners[id],
                lifetime: descriptor.lifetime
            )
        }
        let buffers = bufferDescriptors.map { id, descriptor in
            RenderGraphResourceDeclarationSnapshot(
                kind: .buffer,
                resourceID: id.rawValue,
                ownerID: bufferOwners[id],
                lifetime: descriptor.lifetime
            )
        }
        lock.unlock()
        return (textures + buffers).sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return lhs.resourceID < rhs.resourceID
        }
    }

    public func removeAll() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        for id in textureDescriptors.keys {
            textureStates[id] = .released
        }
        for id in bufferDescriptors.keys {
            bufferStates[id] = .released
        }
        textureDescriptors.removeAll()
        textures.removeAll()
        textureOwners.removeAll()
        textureAllocationErrors.removeAll()
        bufferDescriptors.removeAll()
        buffers.removeAll()
        bufferOwners.removeAll()
        bufferAllocationErrors.removeAll()
        lock.unlock()
    }

    func removeResources(ownerID: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        removeResourceStorage(ownerID: ownerID)
        lock.unlock()
    }

    @discardableResult
    fileprivate func registerResources(
        ownerID: String,
        commitIfValid: Bool = true,
        _ registerBlock: (RenderResourceRegistry) -> Void
    ) -> RenderResourceRegistrationReport {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        let previousCollector = currentDeclarationCollector
        let collector = RenderResourceDeclarationCollector(ownerID: ownerID)
        currentDeclarationCollector = collector

        registerBlock(self)

        currentDeclarationCollector = previousCollector
        return evaluateAndCommit(collector, commitIfValid: commitIfValid)
    }

    func recreateResources() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        guard renderInfo.device != nil else { return }

        lock.lock()
        let textureDescriptors = hasValidViewport ? Array(textureDescriptors.values) : []
        let bufferDescriptors = Array(bufferDescriptors.values)
        lock.unlock()

        for descriptor in textureDescriptors {
            allocateTextureIfNeeded(descriptor)
        }
        for descriptor in bufferDescriptors {
            allocateBufferIfNeeded(descriptor)
        }
    }

    func replaceAllocatorForTesting(
        _ replacement: any RenderExtensionResourceAllocating
    ) -> any RenderExtensionResourceAllocating {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        let previous = allocator
        allocator = replacement
        return previous
    }

    func allocationErrors(ownerID: String) -> [RenderExtensionResourceAllocationError] {
        lock.lock()
        let errors = textureAllocationErrors.values.filter { $0.ownerID == ownerID }
            + bufferAllocationErrors.values.filter { $0.ownerID == ownerID }
        lock.unlock()
        return errors.sorted {
            if $0.kind.rawValue == $1.kind.rawValue {
                return $0.resourceID < $1.resourceID
            }
            return $0.kind.rawValue < $1.kind.rawValue
        }
    }

    private func evaluateAndCommit(
        _ collector: RenderResourceDeclarationCollector,
        commitIfValid: Bool
    ) -> RenderResourceRegistrationReport {
        var validationErrors: [RenderExtensionResourceValidationError] = []
        for descriptor in collector.textureDescriptors {
            appendUnique(descriptor.validationErrors(), to: &validationErrors)
        }
        for descriptor in collector.bufferDescriptors {
            appendUnique(descriptor.validationErrors(), to: &validationErrors)
        }

        lock.lock()
        let existingTextureDescriptors = textureDescriptors
        let existingTextureOwners = textureOwners
        let existingBufferDescriptors = bufferDescriptors
        let existingBufferOwners = bufferOwners
        lock.unlock()

        var conflicts: [RenderExtensionArtifactConflict] = []
        var seenTextureIDs: Set<RenderTextureResourceID> = []
        for descriptor in collector.textureDescriptors {
            if !seenTextureIDs.insert(descriptor.id).inserted {
                appendUnique(
                    RenderExtensionArtifactConflict(
                        kind: .texture,
                        artifactID: descriptor.id.rawValue,
                        requestedOwnerID: collector.ownerID,
                        existingOwnerID: collector.ownerID
                    ),
                    to: &conflicts
                )
            } else if existingTextureDescriptors[descriptor.id] != nil,
                      existingTextureOwners[descriptor.id] != collector.ownerID
            {
                appendUnique(
                    RenderExtensionArtifactConflict(
                        kind: .texture,
                        artifactID: descriptor.id.rawValue,
                        requestedOwnerID: collector.ownerID,
                        existingOwnerID: existingTextureOwners[descriptor.id]
                    ),
                    to: &conflicts
                )
            }
        }

        var seenBufferIDs: Set<RenderBufferResourceID> = []
        for descriptor in collector.bufferDescriptors {
            if !seenBufferIDs.insert(descriptor.id).inserted {
                appendUnique(
                    RenderExtensionArtifactConflict(
                        kind: .buffer,
                        artifactID: descriptor.id.rawValue,
                        requestedOwnerID: collector.ownerID,
                        existingOwnerID: collector.ownerID
                    ),
                    to: &conflicts
                )
            } else if existingBufferDescriptors[descriptor.id] != nil,
                      existingBufferOwners[descriptor.id] != collector.ownerID
            {
                appendUnique(
                    RenderExtensionArtifactConflict(
                        kind: .buffer,
                        artifactID: descriptor.id.rawValue,
                        requestedOwnerID: collector.ownerID,
                        existingOwnerID: existingBufferOwners[descriptor.id]
                    ),
                    to: &conflicts
                )
            }
        }

        guard validationErrors.isEmpty, conflicts.isEmpty, commitIfValid else {
            return RenderResourceRegistrationReport(
                conflicts: conflicts,
                validationErrors: validationErrors,
                committed: false
            )
        }

        lock.lock()
        removeResourceStorage(ownerID: collector.ownerID)
        for descriptor in collector.textureDescriptors {
            textureDescriptors[descriptor.id] = descriptor
            textureOwners[descriptor.id] = collector.ownerID
            textureStates[descriptor.id] = .declared
            textureAllocationErrors.removeValue(forKey: descriptor.id)
        }
        for descriptor in collector.bufferDescriptors {
            bufferDescriptors[descriptor.id] = descriptor
            bufferOwners[descriptor.id] = collector.ownerID
            bufferStates[descriptor.id] = .declared
            bufferAllocationErrors.removeValue(forKey: descriptor.id)
        }
        lock.unlock()

        if renderInfo.device != nil, hasValidViewport {
            for descriptor in collector.textureDescriptors {
                allocateTexture(descriptor)
            }
        }
        if renderInfo.device != nil {
            for descriptor in collector.bufferDescriptors {
                allocateBuffer(descriptor)
            }
        }

        return RenderResourceRegistrationReport(
            conflicts: [],
            validationErrors: [],
            committed: true
        )
    }

    private func removeResourceStorage(ownerID: String) {
        let ownedTextureIDs = textureOwners.compactMap { id, owner in
            owner == ownerID ? id : nil
        }
        for textureID in ownedTextureIDs {
            textureDescriptors.removeValue(forKey: textureID)
            textures.removeValue(forKey: textureID)
            textureOwners.removeValue(forKey: textureID)
            textureStates[textureID] = .released
            textureAllocationErrors.removeValue(forKey: textureID)
        }
        let ownedBufferIDs = bufferOwners.compactMap { id, owner in
            owner == ownerID ? id : nil
        }
        for bufferID in ownedBufferIDs {
            bufferDescriptors.removeValue(forKey: bufferID)
            buffers.removeValue(forKey: bufferID)
            bufferOwners.removeValue(forKey: bufferID)
            bufferStates[bufferID] = .released
            bufferAllocationErrors.removeValue(forKey: bufferID)
        }
    }

    private func appendUnique<T: Equatable>(_ values: [T], to destination: inout [T]) {
        for value in values {
            appendUnique(value, to: &destination)
        }
    }

    private func appendUnique<T: Equatable>(_ value: T, to destination: inout [T]) {
        if !destination.contains(value) {
            destination.append(value)
        }
    }

    private func allocateTextureIfNeeded(_ descriptor: RenderExtensionTextureDescriptor) {
        let size = resolvedSize(for: descriptor.size)
        lock.lock()
        let isCurrent = textureStates[descriptor.id] == .allocated
            && textures[descriptor.id].map {
                $0.width == size.width
                    && $0.height == size.height
                    && $0.pixelFormat == descriptor.pixelFormat
                    && $0.usage == descriptor.usage
                    && $0.storageMode == descriptor.storageMode
                    && $0.mipmapLevelCount == descriptor.mipMapLevels
                    && $0.sampleCount == descriptor.sampleCount
                    && $0.label == descriptor.label
            } == true
        lock.unlock()

        if !isCurrent {
            allocateTexture(descriptor, resolvedSize: size)
        }
    }

    private func allocateTexture(
        _ descriptor: RenderExtensionTextureDescriptor,
        resolvedSize: (width: Int, height: Int)? = nil
    ) {
        guard let device = renderInfo.device, hasValidViewport else { return }

        let size = resolvedSize ?? self.resolvedSize(for: descriptor.size)
        lock.lock()
        let ownerID = textureOwners[descriptor.id]
        textureStates[descriptor.id] = .invalidated
        textureAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()

        guard let texture = allocator.makeTexture(
            device: device,
            descriptor: descriptor,
            width: size.width,
            height: size.height
        ) else {
            let error = RenderExtensionResourceAllocationError(
                kind: .texture,
                resourceID: descriptor.id.rawValue,
                ownerID: ownerID,
                failure: .textureCreationFailed(width: size.width, height: size.height)
            )
            lock.lock()
            textures.removeValue(forKey: descriptor.id)
            textureStates[descriptor.id] = .invalidated
            textureAllocationErrors[descriptor.id] = error
            lock.unlock()
            Logger.logWarning(message: "[RenderExtension] \(error.description)")
            return
        }

        lock.lock()
        textures[descriptor.id] = texture
        textureStates[descriptor.id] = .allocated
        textureAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()
    }

    private func allocateBufferIfNeeded(_ descriptor: RenderExtensionBufferDescriptor) {
        lock.lock()
        let isCurrent = bufferStates[descriptor.id] == .allocated
            && buffers[descriptor.id] != nil
        lock.unlock()

        if !isCurrent {
            allocateBuffer(descriptor)
        }
    }

    private func allocateBuffer(_ descriptor: RenderExtensionBufferDescriptor) {
        guard let device = renderInfo.device else { return }

        lock.lock()
        let ownerID = bufferOwners[descriptor.id]
        bufferStates[descriptor.id] = .invalidated
        bufferAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()

        guard let buffer = allocator.makeBuffer(device: device, descriptor: descriptor) else {
            let error = RenderExtensionResourceAllocationError(
                kind: .buffer,
                resourceID: descriptor.id.rawValue,
                ownerID: ownerID,
                failure: .bufferCreationFailed(length: descriptor.length)
            )
            lock.lock()
            buffers.removeValue(forKey: descriptor.id)
            bufferStates[descriptor.id] = .invalidated
            bufferAllocationErrors[descriptor.id] = error
            lock.unlock()
            Logger.logWarning(message: "[RenderExtension] \(error.description)")
            return
        }

        lock.lock()
        buffers[descriptor.id] = buffer
        bufferStates[descriptor.id] = .allocated
        bufferAllocationErrors.removeValue(forKey: descriptor.id)
        lock.unlock()
    }

    private func resolvedSize(for size: RenderExtensionResourceSize) -> (width: Int, height: Int) {
        switch size {
        case let .viewportScale(scale):
            return (
                width: max(1, Int((renderInfo.viewPort?.x ?? 0) * scale)),
                height: max(1, Int((renderInfo.viewPort?.y ?? 0) * scale))
            )
        case let .fixed(width, height):
            return (width: width, height: height)
        }
    }

    private var hasValidViewport: Bool {
        guard let viewport = renderInfo.viewPort else { return false }
        return viewport.x.isFinite && viewport.y.isFinite && viewport.x > 0 && viewport.y > 0
    }

    private func logValidationErrors(_ errors: [RenderExtensionResourceValidationError]) {
        for error in errors {
            Logger.logWarning(message: "[RenderExtension] \(error.description)")
        }
    }
}

public final class RenderExtensionRegistry: @unchecked Sendable {
    public static let shared = RenderExtensionRegistry()

    private let lock = NSLock()
    private let lifecycleLock = NSRecursiveLock()
    private var extensionsByID: [String: any RenderExtension] = [:]
    private var extensionOrder: [String] = []
    private var registrationConflictsByExtensionID: [String: [RenderExtensionArtifactConflict]] = [:]
    private var shaderLibraryErrorsByExtensionID: [String: [RenderShaderLibraryLoadingError]] = [:]
    private var pipelineErrorsByExtensionID: [String: [RenderExtensionPipelineError]] = [:]
    private var resourceValidationErrorsByExtensionID: [String: [RenderExtensionResourceValidationError]] = [:]
    private var graphValidationErrorsByExtensionID: [String: [RenderGraphError]] = [:]

    private init() {}

    func performPluginLifecycle<T>(_ body: () -> T) -> T {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return body()
    }

    func registeredExtension(id: String) -> (any RenderExtension)? {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let renderExtension = extensionsByID[id]
        lock.unlock()
        return renderExtension
    }

    func setRegisteredExtensionOrder(_ orderedIDs: [String]) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let existingIDs = Set(extensionsByID.keys)
        let orderedExistingIDs = orderedIDs.filter(existingIDs.contains)
        let remainingIDs = extensionOrder.filter {
            existingIDs.contains($0) && !orderedExistingIDs.contains($0)
        }
        extensionOrder = orderedExistingIDs + remainingIDs
        lock.unlock()
    }

    @discardableResult
    public func register(_ renderExtension: any RenderExtension) -> RenderExtensionRegistrationResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        if let pluginID = RenderExtensionPluginRegistry.shared.installedPluginID(
            containingExtensionID: renderExtension.id
        ) {
            return .rejectedPluginOwnership(
                extensionID: renderExtension.id,
                pluginID: pluginID
            )
        }

        return registerExtensionLocked(renderExtension)
    }

    func registerPluginOwnedExtension(
        _ renderExtension: any RenderExtension
    ) -> RenderExtensionRegistrationResult {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        return registerExtensionLocked(renderExtension)
    }

    private func registerExtensionLocked(
        _ renderExtension: any RenderExtension
    ) -> RenderExtensionRegistrationResult {
        lock.lock()
        let previousExtension = extensionsByID[renderExtension.id]
        lock.unlock()

        removeOwnedPipelineArtifacts(ownerID: renderExtension.id)
        let report = registerAvailableArtifacts(for: renderExtension)

        guard report.succeeded else {
            removeOwnedPipelineArtifacts(ownerID: renderExtension.id)
            if report.resourcesCommitted {
                RenderResourceRegistry.shared.removeResources(ownerID: renderExtension.id)
            }

            if let previousExtension {
                let restorationReport = report.resourcesCommitted
                    ? registerAvailableArtifacts(for: previousExtension)
                    : registerAvailablePipelineArtifactsReport(for: previousExtension)
                if !restorationReport.succeeded {
                    removeOwnedArtifacts(ownerID: renderExtension.id)
                    removeRegisteredExtension(id: renderExtension.id)
                    logRegistrationFailures(
                        ownerID: previousExtension.id,
                        conflicts: restorationReport.conflicts,
                        shaderLibraryErrors: restorationReport.shaderLibraryErrors,
                        pipelineErrors: restorationReport.pipelineErrors,
                        validationErrors: restorationReport.resourceValidationErrors
                    )
                }
            }

            lock.lock()
            registrationConflictsByExtensionID[renderExtension.id] = report.conflicts
            shaderLibraryErrorsByExtensionID[renderExtension.id] = report.shaderLibraryErrors
            pipelineErrorsByExtensionID[renderExtension.id] = report.pipelineErrors
            resourceValidationErrorsByExtensionID[renderExtension.id] = report.resourceValidationErrors
            lock.unlock()
            logRegistrationFailures(
                ownerID: renderExtension.id,
                conflicts: report.conflicts,
                shaderLibraryErrors: report.shaderLibraryErrors,
                pipelineErrors: report.pipelineErrors,
                validationErrors: report.resourceValidationErrors
            )
            if !report.shaderLibraryErrors.isEmpty || !report.pipelineErrors.isEmpty {
                return .rejectedArtifacts(
                    conflicts: report.conflicts,
                    shaderLibraryErrors: report.shaderLibraryErrors,
                    pipelineErrors: report.pipelineErrors,
                    resourceValidationErrors: report.resourceValidationErrors
                )
            }
            if report.resourceValidationErrors.isEmpty {
                return .rejected(report.conflicts)
            }
            return .rejectedResources(
                conflicts: report.conflicts,
                validationErrors: report.resourceValidationErrors
            )
        }

        let shouldNotifyResourcesDidLoad = report.resourcesCommitted
            && RenderResourceRegistry.shared.allocationErrors(ownerID: renderExtension.id).isEmpty

        lock.lock()
        if extensionsByID[renderExtension.id] == nil {
            extensionOrder.append(renderExtension.id)
        } else if let previousExtension, previousExtension !== renderExtension {
            previousExtension.willUnregister()
        }
        extensionsByID[renderExtension.id] = renderExtension
        registrationConflictsByExtensionID.removeValue(forKey: renderExtension.id)
        shaderLibraryErrorsByExtensionID.removeValue(forKey: renderExtension.id)
        pipelineErrorsByExtensionID.removeValue(forKey: renderExtension.id)
        resourceValidationErrorsByExtensionID.removeValue(forKey: renderExtension.id)
        graphValidationErrorsByExtensionID.removeValue(forKey: renderExtension.id)
        lock.unlock()
        if shouldNotifyResourcesDidLoad {
            renderExtension.resourcesDidLoad(RenderResourceAccess())
        }
        return .registered
    }

    public func updateExtensions(deltaTime: Float, context: EngineExtensionUpdateContext) {
        for renderExtension in orderedExtensionsSnapshot() {
            renderExtension.update(deltaTime: deltaTime, context: context)
        }
    }

    public func fixedUpdateExtensions(deltaTime: Float, context: EngineExtensionUpdateContext) {
        for renderExtension in orderedExtensionsSnapshot() {
            renderExtension.fixedUpdate(deltaTime: deltaTime, context: context)
        }
    }

    public func notifyResourcesDidLoad() {
        let access = RenderResourceAccess()
        for renderExtension in orderedExtensionsSnapshot() {
            guard resourceAllocationErrors(forExtensionID: renderExtension.id).isEmpty else {
                continue
            }
            renderExtension.resourcesDidLoad(access)
        }
    }

    public func unregister(id: String) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        if let pluginID = RenderExtensionPluginRegistry.shared.installedPluginID(
            containingExtensionID: id
        ) {
            RenderExtensionPluginRegistry.shared.uninstall(id: pluginID)
            return
        }

        unregisterExtensionLocked(id: id)
    }

    func unregisterPluginOwnedExtension(id: String) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        unregisterExtensionLocked(id: id)
    }

    private func unregisterExtensionLocked(id: String) {
        lock.lock()
        let removedExtension = extensionsByID.removeValue(forKey: id)
        extensionOrder.removeAll { $0 == id }
        registrationConflictsByExtensionID.removeValue(forKey: id)
        shaderLibraryErrorsByExtensionID.removeValue(forKey: id)
        pipelineErrorsByExtensionID.removeValue(forKey: id)
        resourceValidationErrorsByExtensionID.removeValue(forKey: id)
        graphValidationErrorsByExtensionID.removeValue(forKey: id)
        lock.unlock()

        removedExtension?.willUnregister()
        removeOwnedArtifacts(ownerID: id)
    }

    public func removeAll() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let removedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        extensionsByID.removeAll()
        extensionOrder.removeAll()
        registrationConflictsByExtensionID.removeAll()
        shaderLibraryErrorsByExtensionID.removeAll()
        pipelineErrorsByExtensionID.removeAll()
        resourceValidationErrorsByExtensionID.removeAll()
        graphValidationErrorsByExtensionID.removeAll()
        lock.unlock()
        for renderExtension in removedExtensions {
            renderExtension.willUnregister()
        }
        RenderExtensionPluginRegistry.shared.removeAllMetadata()
        RenderShaderLibraryManager.shared.removeAll()
        PipelineManager.shared.removeAllExtensionPipelines()
        RenderResourceRegistry.shared.removeAll()
        ComputePipelineManager.shared.removeAll()
        RenderExtensionArgumentBufferRegistry.shared.removeAll()
    }

    public func registeredIDs() -> [String] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let ids = extensionOrder
        lock.unlock()
        return ids
    }

    private func orderedExtensionsSnapshot() -> [any RenderExtension] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()
        return orderedExtensions
    }

    public func registrationConflicts(forExtensionID id: String) -> [RenderExtensionArtifactConflict] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let conflicts = registrationConflictsByExtensionID[id] ?? []
        lock.unlock()
        return conflicts
    }

    public func resourceValidationErrors(
        forExtensionID id: String
    ) -> [RenderExtensionResourceValidationError] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let errors = resourceValidationErrorsByExtensionID[id] ?? []
        lock.unlock()
        return errors
    }

    public func shaderLibraryErrors(
        forExtensionID id: String
    ) -> [RenderShaderLibraryLoadingError] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let errors = shaderLibraryErrorsByExtensionID[id] ?? []
        lock.unlock()
        return errors
    }

    public func pipelineErrors(
        forExtensionID id: String
    ) -> [RenderExtensionPipelineError] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let errors = pipelineErrorsByExtensionID[id] ?? []
        lock.unlock()
        return errors
    }

    public func resourceAllocationErrors(
        forExtensionID id: String
    ) -> [RenderExtensionResourceAllocationError] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        return RenderResourceRegistry.shared.allocationErrors(ownerID: id)
    }

    public func graphValidationErrors(forExtensionID id: String) -> [RenderGraphError] {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let errors = graphValidationErrorsByExtensionID[id] ?? []
        lock.unlock()
        return errors
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context: RenderGraphBuildContext
    ) {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()

        for renderExtension in orderedExtensions {
            lock.lock()
            let isStillRegistered = extensionsByID[renderExtension.id] != nil
            lock.unlock()
            guard isStillRegistered else { continue }

            builder.beginExtensionRegistration(id: renderExtension.id)
            renderExtension.buildGraph(&builder, context: context)
            let report = builder.endExtensionRegistration()
            if !report.succeeded {
                removeOwnedArtifacts(ownerID: renderExtension.id)
                removeRegisteredExtension(
                    id: renderExtension.id,
                    conflicts: report.conflicts,
                    graphValidationErrors: report.validationErrors
                )
                logRegistrationConflicts(report.conflicts)
                logGraphValidationErrors(
                    report.validationErrors,
                    ownerID: renderExtension.id
                )
                let pluginExtensionIDs = RenderExtensionPluginRegistry.shared.invalidateInstalledPlugin(
                    containingExtensionID: renderExtension.id,
                    artifactConflicts: report.conflicts,
                    graphValidationErrors: report.validationErrors
                )
                if !pluginExtensionIDs.isEmpty {
                    builder.removeExtensionContributions(
                        extensionIDs: Set(pluginExtensionIDs)
                    )
                    for extensionID in pluginExtensionIDs where extensionID != renderExtension.id {
                        unregister(id: extensionID)
                    }
                }
                renderExtension.willUnregister()
            }
        }
    }

    /// Removes extensions responsible for whole-graph validation failures.
    /// Plugin-owned failures invalidate every extension supplied by that plugin.
    @discardableResult
    func rejectGraphValidationFailures(
        _ report: RenderGraphValidationReport
    ) -> Set<String> {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        let errorsByExtensionID = report.errorsByExtensionID()
        guard !errorsByExtensionID.isEmpty else { return [] }

        lock.lock()
        let orderedFailingIDs = extensionOrder.filter { errorsByExtensionID[$0] != nil }
        lock.unlock()

        let pluginIDsByExtensionID = Dictionary(uniqueKeysWithValues: orderedFailingIDs.compactMap {
            extensionID in
            RenderExtensionPluginRegistry.shared.installedPluginID(
                containingExtensionID: extensionID
            ).map { (extensionID, $0) }
        })
        var removedExtensionIDs: Set<String> = []
        var processedPluginIDs: Set<String> = []

        for extensionID in orderedFailingIDs {
            let errors = errorsByExtensionID[extensionID] ?? []
            if let pluginID = pluginIDsByExtensionID[extensionID] {
                guard processedPluginIDs.insert(pluginID).inserted else { continue }
                let pluginFailingIDs = orderedFailingIDs.filter {
                    pluginIDsByExtensionID[$0] == pluginID
                }
                let pluginErrors = pluginFailingIDs.flatMap {
                    errorsByExtensionID[$0] ?? []
                }
                let pluginExtensionIDs = RenderExtensionPluginRegistry.shared.invalidateInstalledPlugin(
                    containingExtensionID: extensionID,
                    graphValidationErrors: pluginErrors
                )
                for pluginExtensionID in pluginExtensionIDs {
                    unregisterExtensionLocked(id: pluginExtensionID)
                    removedExtensionIDs.insert(pluginExtensionID)
                }
                for failingID in pluginFailingIDs {
                    removeRegisteredExtension(
                        id: failingID,
                        graphValidationErrors: errorsByExtensionID[failingID] ?? []
                    )
                    logGraphValidationErrors(
                        errorsByExtensionID[failingID] ?? [],
                        ownerID: failingID
                    )
                }
                continue
            } else {
                unregisterExtensionLocked(id: extensionID)
                removeRegisteredExtension(
                    id: extensionID,
                    graphValidationErrors: errors
                )
                removedExtensionIDs.insert(extensionID)
            }

            logGraphValidationErrors(errors, ownerID: extensionID)
        }
        return removedExtensionIDs
    }

    func registerPipelines() {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }

        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()

        for renderExtension in orderedExtensions {
            lock.lock()
            let isStillRegistered = extensionsByID[renderExtension.id] != nil
            lock.unlock()
            guard isStillRegistered else { continue }

            removeOwnedPipelineArtifacts(ownerID: renderExtension.id)
            let report = registerAvailablePipelineArtifacts(for: renderExtension)
            if !report.succeeded {
                removeOwnedArtifacts(ownerID: renderExtension.id)
                removeRegisteredExtension(
                    id: renderExtension.id,
                    conflicts: report.conflicts,
                    shaderLibraryErrors: report.shaderLibraryErrors,
                    pipelineErrors: report.pipelineErrors
                )
                logRegistrationFailures(
                    ownerID: renderExtension.id,
                    conflicts: report.conflicts,
                    shaderLibraryErrors: report.shaderLibraryErrors,
                    pipelineErrors: report.pipelineErrors,
                    validationErrors: []
                )
                let pluginExtensionIDs = RenderExtensionPluginRegistry.shared.invalidateInstalledPlugin(
                    containingExtensionID: renderExtension.id,
                    artifactConflicts: report.conflicts,
                    shaderLibraryErrors: report.shaderLibraryErrors,
                    pipelineErrors: report.pipelineErrors
                )
                for extensionID in pluginExtensionIDs where extensionID != renderExtension.id {
                    unregister(id: extensionID)
                }
                renderExtension.willUnregister()
            }
        }
    }

    private func registerAvailableArtifacts(
        for renderExtension: any RenderExtension
    ) -> RenderExtensionArtifactRegistrationReport {
        let pipelineReport = registerAvailablePipelineArtifacts(for: renderExtension)
        let resourceReport = RenderResourceRegistry.shared.registerResources(
            ownerID: renderExtension.id,
            commitIfValid: pipelineReport.succeeded
        ) { registry in
            renderExtension.registerResources(registry)
        }
        return RenderExtensionArtifactRegistrationReport(
            conflicts: pipelineReport.conflicts + resourceReport.conflicts,
            shaderLibraryErrors: pipelineReport.shaderLibraryErrors,
            pipelineErrors: pipelineReport.pipelineErrors,
            resourceValidationErrors: resourceReport.validationErrors,
            resourcesCommitted: resourceReport.committed
        )
    }

    private func registerAvailablePipelineArtifactsReport(
        for renderExtension: any RenderExtension
    ) -> RenderExtensionArtifactRegistrationReport {
        let pipelineReport = registerAvailablePipelineArtifacts(for: renderExtension)
        return RenderExtensionArtifactRegistrationReport(
            conflicts: pipelineReport.conflicts,
            shaderLibraryErrors: pipelineReport.shaderLibraryErrors,
            pipelineErrors: pipelineReport.pipelineErrors,
            resourceValidationErrors: [],
            resourcesCommitted: false
        )
    }

    private func registerAvailablePipelineArtifacts(
        for renderExtension: any RenderExtension
    ) -> RenderExtensionPipelineArtifactRegistrationReport {
        var conflicts = RenderExtensionArgumentBufferRegistry.shared.registerArgumentBuffers(ownerID: renderExtension.id) { registry in
            renderExtension.registerArgumentBuffers(registry)
        }
        var shaderLibraryErrors: [RenderShaderLibraryLoadingError] = []
        var pipelineErrors: [RenderExtensionPipelineError] = []

        if renderInfo.device != nil {
            let shaderReport = RenderShaderLibraryManager.shared.registerLibraries(ownerID: renderExtension.id) { registry in
                renderExtension.registerShaderLibraries(registry)
            }
            conflicts += shaderReport.conflicts
            shaderLibraryErrors = shaderReport.loadingErrors
        }

        guard shaderLibraryErrors.isEmpty else {
            return RenderExtensionPipelineArtifactRegistrationReport(
                conflicts: conflicts,
                shaderLibraryErrors: shaderLibraryErrors,
                pipelineErrors: pipelineErrors
            )
        }

        if renderInfo.device != nil, renderInfo.library != nil {
            let renderPipelineReport = PipelineManager.shared.registerPipelines(ownerID: renderExtension.id) { registry in
                renderExtension.registerPipelines(registry)
            }
            conflicts += renderPipelineReport.conflicts
            pipelineErrors += renderPipelineReport.errors
            let computePipelineReport = ComputePipelineManager.shared.registerPipelines(ownerID: renderExtension.id) { registry in
                renderExtension.registerComputePipelines(registry)
            }
            conflicts += computePipelineReport.conflicts
            pipelineErrors += computePipelineReport.errors
        }
        return RenderExtensionPipelineArtifactRegistrationReport(
            conflicts: conflicts,
            shaderLibraryErrors: shaderLibraryErrors,
            pipelineErrors: pipelineErrors
        )
    }

    private func removeOwnedArtifacts(ownerID: String) {
        removeOwnedPipelineArtifacts(ownerID: ownerID)
        RenderResourceRegistry.shared.removeResources(ownerID: ownerID)
    }

    private func removeOwnedPipelineArtifacts(ownerID: String) {
        RenderExtensionArgumentBufferRegistry.shared.removeArgumentBuffers(ownerID: ownerID)
        RenderShaderLibraryManager.shared.removeLibraries(ownerID: ownerID)
        PipelineManager.shared.removePipelines(ownerID: ownerID)
        ComputePipelineManager.shared.removePipelines(ownerID: ownerID)
    }

    private func removeRegisteredExtension(
        id: String,
        conflicts: [RenderExtensionArtifactConflict]? = nil,
        shaderLibraryErrors: [RenderShaderLibraryLoadingError]? = nil,
        pipelineErrors: [RenderExtensionPipelineError]? = nil,
        graphValidationErrors: [RenderGraphError]? = nil
    ) {
        lock.lock()
        extensionsByID.removeValue(forKey: id)
        extensionOrder.removeAll { $0 == id }
        if let conflicts {
            registrationConflictsByExtensionID[id] = conflicts
            shaderLibraryErrorsByExtensionID.removeValue(forKey: id)
            pipelineErrorsByExtensionID.removeValue(forKey: id)
            resourceValidationErrorsByExtensionID.removeValue(forKey: id)
        }
        if let shaderLibraryErrors {
            shaderLibraryErrorsByExtensionID[id] = shaderLibraryErrors
        }
        if let pipelineErrors {
            pipelineErrorsByExtensionID[id] = pipelineErrors
        }
        if let graphValidationErrors {
            graphValidationErrorsByExtensionID[id] = graphValidationErrors
        }
        lock.unlock()
    }

    private func logRegistrationConflicts(_ conflicts: [RenderExtensionArtifactConflict]) {
        for conflict in conflicts {
            Logger.logWarning(message: "[RenderExtension] \(conflict.description)")
        }
    }

    private func logGraphValidationErrors(_ errors: [RenderGraphError], ownerID: String) {
        for error in errors {
            Logger.logWarning(
                message: "[RenderExtension] Extension '\(ownerID)' has an invalid graph contribution: \(error.description)"
            )
        }
    }

    private func logRegistrationFailures(
        ownerID: String,
        conflicts: [RenderExtensionArtifactConflict],
        shaderLibraryErrors: [RenderShaderLibraryLoadingError],
        pipelineErrors: [RenderExtensionPipelineError],
        validationErrors: [RenderExtensionResourceValidationError]
    ) {
        logRegistrationConflicts(conflicts)
        for error in shaderLibraryErrors {
            Logger.logWarning(message: "[RenderExtension] Extension '\(ownerID)' cannot load shaders: \(error.description)")
        }
        for error in pipelineErrors {
            Logger.logWarning(message: "[RenderExtension] Extension '\(ownerID)' cannot create pipelines: \(error.description)")
        }
        for error in validationErrors {
            Logger.logWarning(message: "[RenderExtension] Extension '\(ownerID)' cannot register resources: \(error.description)")
        }
    }
}

private struct RenderExtensionArtifactRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let shaderLibraryErrors: [RenderShaderLibraryLoadingError]
    let pipelineErrors: [RenderExtensionPipelineError]
    let resourceValidationErrors: [RenderExtensionResourceValidationError]
    let resourcesCommitted: Bool

    var succeeded: Bool {
        conflicts.isEmpty && shaderLibraryErrors.isEmpty && pipelineErrors.isEmpty
            && resourceValidationErrors.isEmpty
    }
}

private struct RenderExtensionPipelineArtifactRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let shaderLibraryErrors: [RenderShaderLibraryLoadingError]
    let pipelineErrors: [RenderExtensionPipelineError]

    var succeeded: Bool {
        conflicts.isEmpty && shaderLibraryErrors.isEmpty && pipelineErrors.isEmpty
    }
}
