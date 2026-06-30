//
//  PipelineManager.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public final class PipelineManager: @unchecked Sendable {
    /// Thread-safe shared instance
    public static let shared: PipelineManager = .init()

    private let lock = NSLock()
    private let registrationLock = NSRecursiveLock()
    private var _renderPipelinesByType: [RenderPipelineType: RenderPipeline] = [:]
    private var renderPipelineOwners: [RenderPipelineType: String] = [:]
    private var currentRegistrationOwnerID: String?
    private var currentConflictCollector: RenderExtensionConflictCollector?
    private var currentErrorCollector: RenderExtensionPipelineErrorCollector?
    private var currentRegistrationIDs: Set<RenderPipelineType>?

    public var renderPipelinesByType: [RenderPipelineType: RenderPipeline] {
        lock.lock()
        let snapshot = _renderPipelinesByType
        lock.unlock()
        return snapshot
    }

    public func pipeline(for type: RenderPipelineType) -> RenderPipeline? {
        lock.lock()
        let pipeline = _renderPipelinesByType[type]
        lock.unlock()
        return pipeline
    }

    func initRenderPipelines(_ pipelines: [(RenderPipelineType, RenderPipelineInitBlock)]) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        for (type, initBlock) in pipelines {
            _renderPipelinesByType[type] = initBlock()
            renderPipelineOwners.removeValue(forKey: type)
        }
        lock.unlock()
    }

    public func update(rendererPipeLine: RenderPipeline, forType type: RenderPipelineType) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        if currentRegistrationOwnerID != nil,
           currentRegistrationIDs?.insert(type).inserted == false
        {
            currentErrorCollector?.record(
                .duplicatePipelineID(kind: .renderPipeline, pipelineID: type.rawValue)
            )
            lock.unlock()
            return
        }
        if let ownerID = currentRegistrationOwnerID,
           _renderPipelinesByType[type] != nil,
           renderPipelineOwners[type] != ownerID
        {
            currentConflictCollector?.record(
                RenderExtensionArtifactConflict(
                    kind: .renderPipeline,
                    artifactID: type.rawValue,
                    requestedOwnerID: ownerID,
                    existingOwnerID: renderPipelineOwners[type]
                )
            )
            lock.unlock()
            return
        }
        _renderPipelinesByType[type] = rendererPipeLine
        if let currentRegistrationOwnerID {
            renderPipelineOwners[type] = currentRegistrationOwnerID
        } else {
            renderPipelineOwners.removeValue(forKey: type)
        }
        lock.unlock()
    }

    @discardableResult
    func registerPipelines(
        ownerID: String,
        _ registerBlock: (RenderPipelineRegistry) -> Void
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

        registerBlock(RenderPipelineRegistry())

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

    func removePipelines(ownerID: String) {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let ownedTypes = renderPipelineOwners.compactMap { type, owner in
            owner == ownerID ? type : nil
        }
        for type in ownedTypes {
            _renderPipelinesByType.removeValue(forKey: type)
            renderPipelineOwners.removeValue(forKey: type)
        }
        lock.unlock()
    }

    func removeAllExtensionPipelines() {
        registrationLock.lock()
        defer { registrationLock.unlock() }

        lock.lock()
        let ownedTypes = Array(renderPipelineOwners.keys)
        for type in ownedTypes {
            _renderPipelinesByType.removeValue(forKey: type)
        }
        renderPipelineOwners.removeAll()
        lock.unlock()
    }
}
