//
//  EngineSignposts.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import os.signpost

public enum ProfileScope {
    // Frame lifecycle
    case frame
    case update

    // Render subsystem
    case renderPrep
    case encode
    case submit
    case shadowPass

    /// Culling subsystem
    case culling

    // Streaming subsystem
    case streamingRegion
    case geometryStreaming

    // Batching subsystem
    case batchingTick
    case batchingRebuild

    // Gaussian-splat subsystem — separate lane from mesh culling/encode so a trace can
    // show which of cull/depth-key/radix-sort/draw is actually costing frame time,
    // rather than everything showing up lumped into renderPrep/encode.
    case gaussianCull
    case gaussianDepth
    case gaussianSort
    case gaussianDraw
}

final class EngineSignposts {
    private static let subsystem = "com.untoldengine.profiling"

    // Separate log handles give distinct lanes in Instruments.
    private static let frameLog = OSLog(subsystem: subsystem, category: "Frame")
    private static let renderLog = OSLog(subsystem: subsystem, category: "Render")
    private static let cullingLog = OSLog(subsystem: subsystem, category: "Culling")
    private static let streamingLog = OSLog(subsystem: subsystem, category: "Streaming")
    private static let batchingLog = OSLog(subsystem: subsystem, category: "Batching")
    private static let gaussianLog = OSLog(subsystem: subsystem, category: "Gaussian")

    // One stable signpost ID per scope.
    private static let frameID = OSSignpostID(log: frameLog)
    private static let updateID = OSSignpostID(log: frameLog)
    private static let renderPrepID = OSSignpostID(log: renderLog)
    private static let encodeID = OSSignpostID(log: renderLog)
    private static let submitID = OSSignpostID(log: renderLog)
    private static let shadowPassID = OSSignpostID(log: renderLog)
    private static let cullingID = OSSignpostID(log: cullingLog)
    private static let streamingRegionID = OSSignpostID(log: streamingLog)
    private static let geometryStreamingID = OSSignpostID(log: streamingLog)
    private static let batchingTickID = OSSignpostID(log: batchingLog)
    private static let batchingRebuildID = OSSignpostID(log: batchingLog)
    private static let gaussianCullID = OSSignpostID(log: gaussianLog)
    private static let gaussianDepthID = OSSignpostID(log: gaussianLog)
    private static let gaussianSortID = OSSignpostID(log: gaussianLog)
    private static let gaussianDrawID = OSSignpostID(log: gaussianLog)

    func beginScope(_ scope: ProfileScope) {
        let (log, id, name) = descriptor(for: scope)
        os_signpost(.begin, log: log, name: name, signpostID: id)
    }

    func endScope(_ scope: ProfileScope) {
        let (log, id, name) = descriptor(for: scope)
        os_signpost(.end, log: log, name: name, signpostID: id)
    }

    private func descriptor(for scope: ProfileScope) -> (OSLog, OSSignpostID, StaticString) {
        switch scope {
        case .frame: return (Self.frameLog, Self.frameID, "Frame")
        case .update: return (Self.frameLog, Self.updateID, "Update")
        case .renderPrep: return (Self.renderLog, Self.renderPrepID, "RenderPrep")
        case .encode: return (Self.renderLog, Self.encodeID, "Encode")
        case .submit: return (Self.renderLog, Self.submitID, "Submit")
        case .shadowPass: return (Self.renderLog, Self.shadowPassID, "ShadowPass")
        case .culling: return (Self.cullingLog, Self.cullingID, "Culling")
        case .streamingRegion: return (Self.streamingLog, Self.streamingRegionID, "StreamingRegion")
        case .geometryStreaming: return (Self.streamingLog, Self.geometryStreamingID, "GeometryStreaming")
        case .batchingTick: return (Self.batchingLog, Self.batchingTickID, "BatchingTick")
        case .batchingRebuild: return (Self.batchingLog, Self.batchingRebuildID, "BatchingRebuild")
        case .gaussianCull: return (Self.gaussianLog, Self.gaussianCullID, "GaussianCull")
        case .gaussianDepth: return (Self.gaussianLog, Self.gaussianDepthID, "GaussianDepth")
        case .gaussianSort: return (Self.gaussianLog, Self.gaussianSortID, "GaussianSort")
        case .gaussianDraw: return (Self.gaussianLog, Self.gaussianDrawID, "GaussianDraw")
        }
    }
}
