//
//  RenderExtensionPipelineDescriptors.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal

/// Identifies the shader stage referenced by a pipeline validation error.
public enum RenderExtensionShaderStage: String, Equatable, Sendable {
    case vertex
    case fragment
    case compute
}

/// Declaratively describes an extension-owned render pipeline and its dependencies.
public struct RenderExtensionRenderPipelineDescriptor {
    public let id: RenderPipelineType
    public let vertexFunction: String
    public let fragmentFunction: String?
    public let vertexShaderLibrary: RenderShaderLibraryReference
    public let fragmentShaderLibrary: RenderShaderLibraryReference
    public let vertexDescriptor: MTLVertexDescriptor?
    public let colorFormats: [MTLPixelFormat]
    public let depthFormat: MTLPixelFormat
    public let depthCompareFunction: MTLCompareFunction
    public let depthEnabled: Bool
    public let reverseZCompatible: Bool
    public let blendMode: PipelineBlendMode
    public let name: String
    public let requiredArgumentLayoutID: String?

    public init(
        id: RenderPipelineType,
        vertexFunction: String,
        fragmentFunction: String?,
        vertexShaderLibrary: RenderShaderLibraryReference = .engine,
        fragmentShaderLibrary: RenderShaderLibraryReference = .engine,
        vertexDescriptor: MTLVertexDescriptor?,
        colorFormats: [MTLPixelFormat],
        depthFormat: MTLPixelFormat,
        depthCompareFunction: MTLCompareFunction = .lessEqual,
        depthEnabled: Bool = true,
        reverseZCompatible: Bool = true,
        blendMode: PipelineBlendMode = .none,
        name: String,
        requiredArgumentLayoutID: String? = nil
    ) {
        self.id = id
        self.vertexFunction = vertexFunction
        self.fragmentFunction = fragmentFunction
        self.vertexShaderLibrary = vertexShaderLibrary
        self.fragmentShaderLibrary = fragmentShaderLibrary
        self.vertexDescriptor = vertexDescriptor
        self.colorFormats = colorFormats
        self.depthFormat = depthFormat
        self.depthCompareFunction = depthCompareFunction
        self.depthEnabled = depthEnabled
        self.reverseZCompatible = reverseZCompatible
        self.blendMode = blendMode
        self.name = name
        self.requiredArgumentLayoutID = requiredArgumentLayoutID
    }
}

/// Declaratively describes an extension-owned compute pipeline and its shader dependency.
public struct RenderExtensionComputePipelineDescriptor {
    public let id: ComputePipelineType
    public let function: String
    public let shaderLibrary: RenderShaderLibraryReference
    public let name: String

    public init(
        id: ComputePipelineType,
        function: String,
        shaderLibrary: RenderShaderLibraryReference = .engine,
        name: String
    ) {
        self.id = id
        self.function = function
        self.shaderLibrary = shaderLibrary
        self.name = name
    }
}

/// Describes a pipeline recipe validation or Metal creation failure.
public enum RenderExtensionPipelineError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyPipelineID(kind: RenderExtensionArtifactKind)
    case emptyPipelineName(kind: RenderExtensionArtifactKind, pipelineID: String)
    case emptyShaderFunction(pipelineID: String, stage: RenderExtensionShaderStage)
    case missingShaderLibrary(
        pipelineID: String,
        stage: RenderExtensionShaderStage,
        libraryID: String?
    )
    case missingShaderFunction(
        pipelineID: String,
        stage: RenderExtensionShaderStage,
        function: String
    )
    case missingRenderTarget(pipelineID: String)
    case tooManyColorAttachments(pipelineID: String, count: Int)
    case invalidColorFormat(pipelineID: String, index: Int)
    case invalidDepthFormat(pipelineID: String)
    case missingArgumentLayout(pipelineID: String, layoutID: String)
    case duplicatePipelineID(kind: RenderExtensionArtifactKind, pipelineID: String)
    case creationFailed(kind: RenderExtensionArtifactKind, pipelineID: String)

    public var description: String {
        switch self {
        case let .emptyPipelineID(kind):
            return "Extension \(kind.rawValue) IDs cannot be empty"
        case let .emptyPipelineName(kind, pipelineID):
            return "Extension \(kind.rawValue) '\(pipelineID)' must provide a name"
        case let .emptyShaderFunction(pipelineID, stage):
            return "Extension pipeline '\(pipelineID)' has an empty \(stage.rawValue) function"
        case let .missingShaderLibrary(pipelineID, stage, libraryID):
            let library = libraryID ?? "engine"
            return "Extension pipeline '\(pipelineID)' cannot resolve \(stage.rawValue) shader library '\(library)'"
        case let .missingShaderFunction(pipelineID, stage, function):
            return "Extension pipeline '\(pipelineID)' cannot find \(stage.rawValue) function '\(function)'"
        case let .missingRenderTarget(pipelineID):
            return "Extension render pipeline '\(pipelineID)' must declare a color or depth target"
        case let .tooManyColorAttachments(pipelineID, count):
            return "Extension render pipeline '\(pipelineID)' declares \(count) color attachments; Metal supports at most 8"
        case let .invalidColorFormat(pipelineID, index):
            return "Extension render pipeline '\(pipelineID)' has an invalid color format at index \(index)"
        case let .invalidDepthFormat(pipelineID):
            return "Extension render pipeline '\(pipelineID)' enables depth writes without a depth format"
        case let .missingArgumentLayout(pipelineID, layoutID):
            return "Extension render pipeline '\(pipelineID)' references missing argument layout '\(layoutID)'"
        case let .duplicatePipelineID(kind, pipelineID):
            return "Extension declares \(kind.rawValue) '\(pipelineID)' more than once"
        case let .creationFailed(kind, pipelineID):
            return "Failed to create extension \(kind.rawValue) '\(pipelineID)'"
        }
    }
}

final class RenderExtensionPipelineErrorCollector {
    private(set) var errors: [RenderExtensionPipelineError] = []

    func record(_ error: RenderExtensionPipelineError) {
        if !errors.contains(error) {
            errors.append(error)
        }
    }
}

struct RenderExtensionPipelineRegistrationReport {
    let conflicts: [RenderExtensionArtifactConflict]
    let errors: [RenderExtensionPipelineError]
}

protocol RenderExtensionPipelineCreating: AnyObject {
    func makeRenderPipeline(
        _ descriptor: RenderExtensionRenderPipelineDescriptor
    ) -> RenderPipeline?

    func makeComputePipeline(
        _ descriptor: RenderExtensionComputePipelineDescriptor,
        library: MTLLibrary
    ) -> ComputePipeline?
}

private final class DefaultRenderExtensionPipelineCreator: RenderExtensionPipelineCreating {
    func makeRenderPipeline(
        _ descriptor: RenderExtensionRenderPipelineDescriptor
    ) -> RenderPipeline? {
        CreatePipeline(
            vertexShader: descriptor.vertexFunction,
            fragmentShader: descriptor.fragmentFunction,
            vertexShaderLibrary: descriptor.vertexShaderLibrary,
            fragmentShaderLibrary: descriptor.fragmentShaderLibrary,
            vertexDescriptor: descriptor.vertexDescriptor,
            colorFormats: descriptor.colorFormats,
            depthFormat: descriptor.depthFormat,
            depthCompareFunction: descriptor.depthCompareFunction,
            depthEnabled: descriptor.depthEnabled,
            reverseZCompatible: descriptor.reverseZCompatible,
            blendMode: descriptor.blendMode,
            name: descriptor.name
        )
    }

    func makeComputePipeline(
        _ descriptor: RenderExtensionComputePipelineDescriptor,
        library: MTLLibrary
    ) -> ComputePipeline? {
        guard let device = renderInfo.device else { return nil }
        var pipeline = ComputePipeline()
        CreateComputePipeline(
            into: &pipeline,
            device: device,
            library: library,
            functionName: descriptor.function,
            pipelineName: descriptor.name
        )
        return pipeline.success ? pipeline : nil
    }
}

final class RenderExtensionPipelineCreator: @unchecked Sendable {
    static let shared = RenderExtensionPipelineCreator()

    private let lock = NSLock()
    private var creator: any RenderExtensionPipelineCreating = DefaultRenderExtensionPipelineCreator()

    private init() {}

    func makeRenderPipeline(
        _ descriptor: RenderExtensionRenderPipelineDescriptor
    ) -> RenderPipeline? {
        lock.lock()
        let creator = creator
        lock.unlock()
        return creator.makeRenderPipeline(descriptor)
    }

    func makeComputePipeline(
        _ descriptor: RenderExtensionComputePipelineDescriptor,
        library: MTLLibrary
    ) -> ComputePipeline? {
        lock.lock()
        let creator = creator
        lock.unlock()
        return creator.makeComputePipeline(descriptor, library: library)
    }

    func replaceForTesting(
        _ replacement: any RenderExtensionPipelineCreating
    ) -> any RenderExtensionPipelineCreating {
        lock.lock()
        let previous = creator
        creator = replacement
        lock.unlock()
        return previous
    }
}

func validateRenderExtensionRenderPipeline(
    _ descriptor: RenderExtensionRenderPipelineDescriptor
) -> [RenderExtensionPipelineError] {
    let pipelineID = descriptor.id.rawValue
    var errors = validatePipelineIdentity(
        kind: .renderPipeline,
        pipelineID: pipelineID,
        name: descriptor.name
    )
    validateShader(
        pipelineID: pipelineID,
        stage: .vertex,
        function: descriptor.vertexFunction,
        reference: descriptor.vertexShaderLibrary,
        errors: &errors
    )
    if let fragmentFunction = descriptor.fragmentFunction {
        validateShader(
            pipelineID: pipelineID,
            stage: .fragment,
            function: fragmentFunction,
            reference: descriptor.fragmentShaderLibrary,
            errors: &errors
        )
    }
    if descriptor.colorFormats.isEmpty, descriptor.depthFormat == .invalid {
        errors.append(.missingRenderTarget(pipelineID: pipelineID))
    }
    if descriptor.colorFormats.count > 8 {
        errors.append(
            .tooManyColorAttachments(
                pipelineID: pipelineID,
                count: descriptor.colorFormats.count
            )
        )
    }
    for (index, format) in descriptor.colorFormats.enumerated() where format == .invalid {
        errors.append(.invalidColorFormat(pipelineID: pipelineID, index: index))
    }
    if descriptor.depthEnabled, descriptor.depthFormat == .invalid {
        errors.append(.invalidDepthFormat(pipelineID: pipelineID))
    }
    if let layoutID = descriptor.requiredArgumentLayoutID,
       RenderExtensionArgumentBufferRegistry.shared.descriptor(layoutID) == nil
    {
        errors.append(.missingArgumentLayout(pipelineID: pipelineID, layoutID: layoutID))
    }
    return errors
}

func validateRenderExtensionComputePipeline(
    _ descriptor: RenderExtensionComputePipelineDescriptor
) -> (errors: [RenderExtensionPipelineError], library: MTLLibrary?) {
    let pipelineID = descriptor.id.rawValue
    var errors = validatePipelineIdentity(
        kind: .computePipeline,
        pipelineID: pipelineID,
        name: descriptor.name
    )
    let library = validateShader(
        pipelineID: pipelineID,
        stage: .compute,
        function: descriptor.function,
        reference: descriptor.shaderLibrary,
        errors: &errors
    )
    return (errors, library)
}

private func validatePipelineIdentity(
    kind: RenderExtensionArtifactKind,
    pipelineID: String,
    name: String
) -> [RenderExtensionPipelineError] {
    var errors: [RenderExtensionPipelineError] = []
    if pipelineID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        errors.append(.emptyPipelineID(kind: kind))
    }
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        errors.append(.emptyPipelineName(kind: kind, pipelineID: pipelineID))
    }
    return errors
}

@discardableResult
private func validateShader(
    pipelineID: String,
    stage: RenderExtensionShaderStage,
    function: String,
    reference: RenderShaderLibraryReference,
    errors: inout [RenderExtensionPipelineError]
) -> MTLLibrary? {
    if function.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        errors.append(.emptyShaderFunction(pipelineID: pipelineID, stage: stage))
        return nil
    }

    let library: MTLLibrary?
    let libraryID: String?
    switch reference {
    case .engine:
        library = renderInfo.library
        libraryID = nil
    case let .registered(id):
        library = RenderShaderLibraryManager.shared.library(id)
        libraryID = id.rawValue
    }
    guard let library else {
        errors.append(
            .missingShaderLibrary(
                pipelineID: pipelineID,
                stage: stage,
                libraryID: libraryID
            )
        )
        return nil
    }
    guard library.makeFunction(name: function) != nil else {
        errors.append(
            .missingShaderFunction(
                pipelineID: pipelineID,
                stage: stage,
                function: function
            )
        )
        return library
    }
    return library
}
