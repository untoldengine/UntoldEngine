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
    private var _renderPipelinesByType: [RenderPipelineType: RenderPipeline] = [:]

    public var renderPipelinesByType: [RenderPipelineType: RenderPipeline] {
        lock.lock()
        let snapshot = _renderPipelinesByType
        lock.unlock()
        return snapshot
    }

    func initRenderPipelines(_ pipelines: [(RenderPipelineType, RenderPipelineInitBlock)]) {
        lock.lock()
        for (type, initBlock) in pipelines {
            _renderPipelinesByType[type] = initBlock()
        }
        lock.unlock()
    }

    public func update(rendererPipeLine: RenderPipeline, forType type: RenderPipelineType) {
        lock.lock()
        _renderPipelinesByType[type] = rendererPipeLine
        lock.unlock()
    }
}
