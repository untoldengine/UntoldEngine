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

public protocol RenderExtension: AnyObject, Sendable {
    var id: String { get }

    func registerShaderLibraries(_ registry: RenderShaderLibraryRegistry)

    func registerPipelines(_ registry: RenderPipelineRegistry)

    func registerComputePipelines(_ registry: ComputePipelineRegistry)

    func registerResources(_ registry: RenderResourceRegistry)

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

public enum RenderShaderLibraryReference: Sendable {
    case engine
    case registered(RenderShaderLibraryID)
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
    private var librariesByID: [RenderShaderLibraryID: MTLLibrary] = [:]
    private var libraryOwners: [RenderShaderLibraryID: String] = [:]
    private var currentRegistrationOwnerID: String?

    private init() {}

    public func library(_ id: RenderShaderLibraryID) -> MTLLibrary? {
        lock.lock()
        let library = librariesByID[id]
        lock.unlock()
        return library
    }

    func update(_ library: MTLLibrary, forID id: RenderShaderLibraryID) {
        lock.lock()
        librariesByID[id] = library
        if let currentRegistrationOwnerID {
            libraryOwners[id] = currentRegistrationOwnerID
        }
        lock.unlock()
    }

    func removeLibraries(ownerID: String) {
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
        lock.lock()
        librariesByID.removeAll()
        libraryOwners.removeAll()
        lock.unlock()
    }

    func registerLibraries(
        ownerID: String,
        _ registerBlock: (RenderShaderLibraryRegistry) -> Void
    ) {
        lock.lock()
        currentRegistrationOwnerID = ownerID
        lock.unlock()

        registerBlock(RenderShaderLibraryRegistry())

        lock.lock()
        currentRegistrationOwnerID = nil
        lock.unlock()
    }
}

public struct RenderShaderLibraryRegistry {
    public init() {}

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        library: MTLLibrary
    ) {
        RenderShaderLibraryManager.shared.update(library, forID: id)
    }

    public func registerDefaultLibrary(
        _ id: RenderShaderLibraryID,
        bundle: Bundle
    ) {
        guard renderInfo.device != nil else {
            Logger.logWarning(message: "[RenderExtension] Cannot initialize shader library '\(id.rawValue)' before Metal is ready")
            return
        }

        do {
            let library = try renderInfo.device.makeDefaultLibrary(bundle: bundle)
            RenderShaderLibraryManager.shared.update(library, forID: id)
        } catch {
            Logger.logWarning(message: "[RenderExtension] Failed to initialize shader library '\(id.rawValue)': \(error.localizedDescription)")
        }
    }

    public func registerLibrary(
        _ id: RenderShaderLibraryID,
        url: URL
    ) {
        guard renderInfo.device != nil else {
            Logger.logWarning(message: "[RenderExtension] Cannot initialize shader library '\(id.rawValue)' before Metal is ready")
            return
        }

        do {
            let library = try renderInfo.device.makeLibrary(URL: url)
            RenderShaderLibraryManager.shared.update(library, forID: id)
        } catch {
            Logger.logWarning(message: "[RenderExtension] Failed to initialize shader library '\(id.rawValue)' from '\(url.path)': \(error.localizedDescription)")
        }
    }
}

public struct RenderPipelineRegistry {
    public init() {}

    public func registerRenderPipeline(
        _ type: RenderPipelineType,
        initBlock: RenderPipelineInitBlock
    ) {
        guard let pipeline = initBlock() else {
            Logger.logWarning(message: "[RenderExtension] Failed to initialize render pipeline '\(type.rawValue)'")
            return
        }
        PipelineManager.shared.update(rendererPipeLine: pipeline, forType: type)
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
        registerRenderPipeline(type) {
            CreatePipeline(
                vertexShader: vertexShader,
                fragmentShader: fragmentShader,
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
        }
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
        name: String
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
                name: name
            )
        }
    }
}

public struct ComputePipelineType: Hashable, ExpressibleByStringLiteral, Sendable {
    let rawValue: String

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
    private var computePipelinesByType: [ComputePipelineType: ComputePipeline] = [:]
    private var computePipelineOwners: [ComputePipelineType: String] = [:]
    private var currentRegistrationOwnerID: String?

    private init() {}

    public func pipeline(for type: ComputePipelineType) -> ComputePipeline? {
        lock.lock()
        let pipeline = computePipelinesByType[type]
        lock.unlock()
        return pipeline
    }

    func update(_ pipeline: ComputePipeline, forType type: ComputePipelineType) {
        lock.lock()
        computePipelinesByType[type] = pipeline
        if let currentRegistrationOwnerID {
            computePipelineOwners[type] = currentRegistrationOwnerID
        }
        lock.unlock()
    }

    func removePipelines(ownerID: String) {
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
        lock.lock()
        computePipelinesByType.removeAll()
        computePipelineOwners.removeAll()
        lock.unlock()
    }

    func registerPipelines(
        ownerID: String,
        _ registerBlock: (ComputePipelineRegistry) -> Void
    ) {
        lock.lock()
        currentRegistrationOwnerID = ownerID
        lock.unlock()

        registerBlock(ComputePipelineRegistry())

        lock.lock()
        currentRegistrationOwnerID = nil
        lock.unlock()
    }
}

public struct ComputePipelineRegistry {
    public init() {}

    public func registerComputePipeline(
        _ type: ComputePipelineType,
        initBlock: ComputePipelineInitBlock
    ) {
        guard let pipeline = initBlock() else {
            Logger.logWarning(message: "[RenderExtension] Failed to initialize compute pipeline '\(type.rawValue)'")
            return
        }
        ComputePipelineManager.shared.update(pipeline, forType: type)
    }

    public func registerComputePipeline(
        _ type: ComputePipelineType,
        functionName: String,
        shaderLibrary: RenderShaderLibraryReference = .engine,
        pipelineName: String
    ) {
        guard renderInfo.device != nil else {
            Logger.logWarning(message: "[RenderExtension] Cannot initialize compute pipeline '\(type.rawValue)' before Metal is ready")
            return
        }

        guard let library = resolveRenderShaderLibrary(
            shaderLibrary,
            usage: "compute shader '\(functionName)'"
        ) else {
            return
        }

        var pipeline = ComputePipeline()
        CreateComputePipeline(
            into: &pipeline,
            device: renderInfo.device,
            library: library,
            functionName: functionName,
            pipelineName: pipelineName
        )

        guard pipeline.success else {
            Logger.logWarning(message: "[RenderExtension] Failed to initialize compute pipeline '\(type.rawValue)'")
            return
        }
        ComputePipelineManager.shared.update(pipeline, forType: type)
    }
}

public struct ComputePipelineAccess {
    public init() {}

    public func pipeline(_ type: ComputePipelineType) -> ComputePipeline? {
        ComputePipelineManager.shared.pipeline(for: type)
    }
}

public enum RenderExtensionResourceSize: Sendable {
    case viewportScale(Float)
    case fixed(width: Int, height: Int)
}

public struct RenderExtensionTextureDescriptor: Sendable {
    public let id: String
    public let label: String
    public let size: RenderExtensionResourceSize
    public let pixelFormat: MTLPixelFormat
    public let usage: MTLTextureUsage
    public let storageMode: MTLStorageMode
    public let mipMapLevels: Int
    public let sampleCount: Int

    public init(
        id: String,
        label: String? = nil,
        size: RenderExtensionResourceSize,
        pixelFormat: MTLPixelFormat,
        usage: MTLTextureUsage,
        storageMode: MTLStorageMode = .private,
        mipMapLevels: Int = 1,
        sampleCount: Int = 1
    ) {
        self.id = id
        self.label = label ?? id
        self.size = size
        self.pixelFormat = pixelFormat
        self.usage = usage
        self.storageMode = storageMode
        self.mipMapLevels = max(1, mipMapLevels)
        self.sampleCount = max(1, sampleCount)
    }
}

public struct RenderResourceAccess {
    public init() {}

    public func texture(_ id: String) -> MTLTexture? {
        RenderResourceRegistry.shared.texture(id)
    }
}

public final class RenderResourceRegistry: @unchecked Sendable {
    public static let shared = RenderResourceRegistry()

    private let lock = NSLock()
    private var textureDescriptors: [String: RenderExtensionTextureDescriptor] = [:]
    private var textures: [String: MTLTexture] = [:]
    private var textureOwners: [String: String] = [:]
    private var currentRegistrationOwnerID: String?

    private init() {}

    public func registerTexture(_ descriptor: RenderExtensionTextureDescriptor) {
        lock.lock()
        textureDescriptors[descriptor.id] = descriptor
        if let currentRegistrationOwnerID {
            textureOwners[descriptor.id] = currentRegistrationOwnerID
        }
        lock.unlock()

        if renderInfo.device != nil, renderInfo.viewPort != nil {
            recreateTexture(descriptor)
        }
    }

    public func texture(_ id: String) -> MTLTexture? {
        lock.lock()
        let texture = textures[id]
        lock.unlock()
        return texture
    }

    public func removeAll() {
        lock.lock()
        textureDescriptors.removeAll()
        textures.removeAll()
        textureOwners.removeAll()
        lock.unlock()
    }

    func removeResources(ownerID: String) {
        lock.lock()
        let ownedTextureIDs = textureOwners.compactMap { id, owner in
            owner == ownerID ? id : nil
        }
        for textureID in ownedTextureIDs {
            textureDescriptors.removeValue(forKey: textureID)
            textures.removeValue(forKey: textureID)
            textureOwners.removeValue(forKey: textureID)
        }
        lock.unlock()
    }

    func registerResources(
        ownerID: String,
        _ registerBlock: (RenderResourceRegistry) -> Void
    ) {
        lock.lock()
        currentRegistrationOwnerID = ownerID
        lock.unlock()

        registerBlock(self)

        lock.lock()
        currentRegistrationOwnerID = nil
        lock.unlock()
    }

    func recreateResources() {
        guard renderInfo.device != nil, renderInfo.viewPort != nil else { return }

        lock.lock()
        let descriptors = Array(textureDescriptors.values)
        lock.unlock()

        for descriptor in descriptors {
            recreateTexture(descriptor)
        }
    }

    private func recreateTexture(_ descriptor: RenderExtensionTextureDescriptor) {
        guard renderInfo.device != nil, renderInfo.viewPort != nil else { return }

        let size = resolvedSize(for: descriptor.size)
        guard size.width > 0, size.height > 0 else {
            Logger.logWarning(message: "[RenderExtension] Invalid texture size for resource '\(descriptor.id)'")
            return
        }

        guard let texture = createTexture(
            device: renderInfo.device,
            label: descriptor.label,
            pixelFormat: descriptor.pixelFormat,
            width: size.width,
            height: size.height,
            usage: descriptor.usage,
            storageMode: descriptor.storageMode,
            mipMapLevels: descriptor.mipMapLevels,
            sampleCount: descriptor.sampleCount
        ) else {
            Logger.logWarning(message: "[RenderExtension] Failed to create texture resource '\(descriptor.id)'")
            return
        }

        lock.lock()
        textures[descriptor.id] = texture
        lock.unlock()
    }

    private func resolvedSize(for size: RenderExtensionResourceSize) -> (width: Int, height: Int) {
        switch size {
        case let .viewportScale(scale):
            let clampedScale = max(scale, 0.001)
            return (
                width: max(1, Int((renderInfo.viewPort?.x ?? 0) * clampedScale)),
                height: max(1, Int((renderInfo.viewPort?.y ?? 0) * clampedScale))
            )
        case let .fixed(width, height):
            return (width: max(1, width), height: max(1, height))
        }
    }
}

public final class RenderExtensionRegistry: @unchecked Sendable {
    public static let shared = RenderExtensionRegistry()

    private let lock = NSLock()
    private var extensionsByID: [String: any RenderExtension] = [:]
    private var extensionOrder: [String] = []

    private init() {}

    public func register(_ renderExtension: any RenderExtension) {
        lock.lock()
        if extensionsByID[renderExtension.id] == nil {
            extensionOrder.append(renderExtension.id)
        }
        extensionsByID[renderExtension.id] = renderExtension
        lock.unlock()

        if renderInfo.device != nil {
            RenderShaderLibraryManager.shared.registerLibraries(ownerID: renderExtension.id) { registry in
                renderExtension.registerShaderLibraries(registry)
            }
        }
        if renderInfo.device != nil, renderInfo.library != nil {
            renderExtension.registerPipelines(RenderPipelineRegistry())
            ComputePipelineManager.shared.registerPipelines(ownerID: renderExtension.id) { registry in
                renderExtension.registerComputePipelines(registry)
            }
        }
        if renderInfo.device != nil, renderInfo.viewPort != nil {
            RenderResourceRegistry.shared.registerResources(ownerID: renderExtension.id) { registry in
                renderExtension.registerResources(registry)
            }
        }
    }

    public func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }

        extensionsByID.removeValue(forKey: id)
        extensionOrder.removeAll { $0 == id }
        RenderShaderLibraryManager.shared.removeLibraries(ownerID: id)
        RenderResourceRegistry.shared.removeResources(ownerID: id)
        ComputePipelineManager.shared.removePipelines(ownerID: id)
    }

    public func removeAll() {
        lock.lock()
        extensionsByID.removeAll()
        extensionOrder.removeAll()
        lock.unlock()
        RenderShaderLibraryManager.shared.removeAll()
        RenderResourceRegistry.shared.removeAll()
        ComputePipelineManager.shared.removeAll()
    }

    public func registeredIDs() -> [String] {
        lock.lock()
        let ids = extensionOrder
        lock.unlock()
        return ids
    }

    func buildGraph(
        _ builder: inout RenderGraphBuilder,
        context: RenderGraphBuildContext
    ) {
        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()

        for renderExtension in orderedExtensions {
            renderExtension.buildGraph(&builder, context: context)
        }
    }

    func registerPipelines() {
        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()

        let registry = RenderPipelineRegistry()
        for renderExtension in orderedExtensions {
            RenderShaderLibraryManager.shared.registerLibraries(ownerID: renderExtension.id) { registry in
                renderExtension.registerShaderLibraries(registry)
            }
            renderExtension.registerPipelines(registry)
            ComputePipelineManager.shared.registerPipelines(ownerID: renderExtension.id) { registry in
                renderExtension.registerComputePipelines(registry)
            }
        }
    }

    func registerResources() {
        lock.lock()
        let orderedExtensions = extensionOrder.compactMap { extensionsByID[$0] }
        lock.unlock()

        let registry = RenderResourceRegistry.shared
        for renderExtension in orderedExtensions {
            registry.registerResources(ownerID: renderExtension.id) { registry in
                renderExtension.registerResources(registry)
            }
        }
    }
}
