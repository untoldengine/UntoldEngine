//
//  GaussianChunkLoader.swift
//  UntoldEngine
//
//  Loads a version-3 `.untoldgs` file for rendering: reads every chunk by byte
//  range (CRC-verified) into a packed staging buffer, binds the SH bytes as they
//  are (the file already stores the renderer's byte contract), and runs the
//  `gaussianDecodeChunks` kernel once to expand the 16-byte records into the
//  `EncodedGaussianSplat` layout the existing cull, sort and draw passes consume.
//  The file is never read whole and no CPU decode runs. The chunk table the decode
//  used stays resident (`GaussianChunkTable`) so the frame can cull chunk by chunk.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import Metal
import simd

/// The chunk table of a `.untoldgs` asset as the renderer keeps it after the load: the
/// per-chunk decode constants (`GaussianChunkDecodeConstants`, 48 bytes per chunk — centre
/// AABB, log-scale range, first splat and count) GPU-resident for the chunk-level cull
/// (`gaussianChunkCull`), and the file's index on the CPU for tests and later paging.
struct GaussianChunkTable {
    /// `GaussianChunkDecodeConstants × chunkCount`, in chunk order; `firstSplat` runs
    /// contiguously so chunk `i` owns splats `firstSplat ..< firstSplat + splatCount` of the
    /// encoded buffer.
    let constantsBuffer: MTLBuffer
    let chunkCount: Int
    /// `1 << header.log2ChunkSplats`: the most splats any chunk holds, the threadgroup width
    /// of the per-chunk passes.
    let splatsPerChunk: Int
    let index: UntoldGSIndex
    /// Per in-flight frame slot, written by `gaussianChunkCull` and read by the per-splat pass
    /// the same frame: the visible-chunk list (`GaussianVisibleChunk × chunkCount`) and its
    /// `GaussianVisibleSet`-shaped record. Allocated by `buildGaussianLoadResult`
    /// (`allocateGaussianVisibleChunkBuffers`), slotted like `gaussianVisibleIndices`.
    var visibleChunks: [MTLBuffer] = []
    var visibleChunkSets: [MTLBuffer] = []

    var gpuBytes: Int {
        constantsBuffer.length
            + visibleChunks.reduce(0) { $0 + $1.length }
            + visibleChunkSets.reduce(0) { $0 + $1.length }
    }
}

/// GPU-resident result of decoding a `.untoldgs` file.
struct GaussianChunkLoadResult {
    let splatCount: Int
    let encodedSplatBuffer: MTLBuffer
    let sphericalHarmonicsBuffer: MTLBuffer?
    let sphericalHarmonicsMetadata: GaussianSHMetadata?
    let meanSquaredSplatExtent: Float
    /// Capture exposure (EV) and white balance the cook recorded in the header.
    let captureExposureEV: Float
    let captureWhiteBalance: SIMD3<Float>
    let boundingBox: (min: simd_float3, max: simd_float3)
    /// Chunk index of the file, kept for callers that want to page later.
    let index: UntoldGSIndex
    /// The same index's decode constants, GPU-resident, for the chunk-level cull.
    let chunkTable: GaussianChunkTable
}

enum GaussianChunkLoadError: Error, CustomStringConvertible {
    case decodePipelineUnavailable
    case deviceUnavailable
    case tooManySplats(Int)
    case bufferAllocationFailed(String)
    case gpuDecodeFailed(String)

    var description: String {
        switch self {
        case .decodePipelineUnavailable: "the Gaussian decode compute pipeline is not available"
        case .deviceUnavailable: "no Metal device or command queue"
        case let .tooManySplats(count): "too many Gaussian splats: \(count) exceeds maximum \(maxNumOfGaussians)"
        case let .bufferAllocationFailed(what): "failed to allocate \(what)"
        case let .gpuDecodeFailed(reason): "GPU decode failed: \(reason)"
        }
    }
}

enum GaussianChunkLoader {
    /// True when the decode kernel compiled, so `.untoldgs` files can take the GPU path.
    static var isAvailable: Bool {
        gaussianDecodePipeline.success && gaussianDecodePipeline.pipelineState != nil
    }

    /// Reads and decodes `url` on the GPU. Synchronous: the caller is already off the
    /// render thread on the async and streaming paths, and the synchronous
    /// `setEntityGaussian` blocks by contract.
    static func load(url: URL) throws -> GaussianChunkLoadResult {
        guard let device = renderInfo.device, let commandQueue = renderInfo.commandQueue else {
            throw GaussianChunkLoadError.deviceUnavailable
        }
        guard isAvailable, let pipelineState = gaussianDecodePipeline.pipelineState else {
            throw GaussianChunkLoadError.decodePipelineUnavailable
        }

        let file = try UntoldGSFile(url: url)
        let header = file.header
        let splatCount = Int(header.splatCount)
        guard splatCount <= Int(maxNumOfGaussians) else {
            throw GaussianChunkLoadError.tooManySplats(splatCount)
        }
        let shBytesPerSplat = header.shBytesPerSplat

        // Packed records for every chunk, contiguous, in chunk order.
        guard let packedBuffer = device.makeBuffer(length: splatCount * UntoldGSFormat.coreRecordSize, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian packed staging buffer")
        }
        packedBuffer.label = "Gaussian Packed Chunks"

        let sphericalHarmonicsBuffer: MTLBuffer?
        if shBytesPerSplat > 0 {
            guard let buffer = device.makeBuffer(length: splatCount * shBytesPerSplat, options: .storageModeShared) else {
                throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian spherical-harmonics buffer")
            }
            buffer.label = "Gaussian Spherical Harmonics"
            sphericalHarmonicsBuffer = buffer
        } else {
            sphericalHarmonicsBuffer = nil
        }

        var constants: [GaussianChunkDecodeConstants] = []
        constants.reserveCapacity(file.index.chunks.count)
        var firstSplat = 0
        let packedBase = packedBuffer.contents()
        let shBase = sphericalHarmonicsBuffer?.contents()

        for chunkIndex in file.index.chunks.indices {
            let chunk = file.index.chunks[chunkIndex]
            let payload = try file.chunkPayload(at: chunkIndex, verify: true)
            let count = Int(chunk.splatCount)
            let coreBytes = Int(chunk.coreBytes)

            payload.withUnsafeBytes { bytes in
                let source = bytes.baseAddress!
                packedBase.advanced(by: firstSplat * UntoldGSFormat.coreRecordSize)
                    .copyMemory(from: source, byteCount: coreBytes)
                if let shBase, shBytesPerSplat > 0 {
                    shBase.advanced(by: firstSplat * shBytesPerSplat)
                        .copyMemory(from: source.advanced(by: coreBytes), byteCount: count * shBytesPerSplat)
                }
            }

            constants.append(GaussianChunkDecodeConstants(
                aabbMinX: chunk.aabbMin.x, aabbMinY: chunk.aabbMin.y, aabbMinZ: chunk.aabbMin.z,
                logScaleMin: chunk.logScaleMin,
                aabbMaxX: chunk.aabbMax.x, aabbMaxY: chunk.aabbMax.y, aabbMaxZ: chunk.aabbMax.z,
                logScaleMax: chunk.logScaleMax,
                firstSplat: UInt32(firstSplat),
                splatCount: UInt32(count),
                _pad0: 0, _pad1: 0
            ))
            firstSplat += count
        }

        guard let encodedSplatBuffer = device.makeBuffer(length: splatCount * MemoryLayout<EncodedGaussianSplat>.stride, options: .storageModeShared) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Encoded Gaussian splat buffer")
        }
        encodedSplatBuffer.label = "Gaussian Encoded Splats"
        guard let constantsBuffer = device.makeBuffer(
            bytes: constants,
            length: constants.count * MemoryLayout<GaussianChunkDecodeConstants>.stride,
            options: .storageModeShared
        ) else {
            throw GaussianChunkLoadError.bufferAllocationFailed("Gaussian chunk constants buffer")
        }
        constantsBuffer.label = "Gaussian Chunk Table"

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder()
        else {
            throw GaussianChunkLoadError.gpuDecodeFailed("could not create a command buffer")
        }
        commandBuffer.label = "Gaussian Chunk Decode"
        encoder.label = "Gaussian Decode Chunks"
        encoder.setComputePipelineState(pipelineState)
        encoder.setBuffer(packedBuffer, offset: 0, index: Int(gaussianDecodePackedIndex.rawValue))
        encoder.setBuffer(constantsBuffer, offset: 0, index: Int(gaussianDecodeChunksIndex.rawValue))
        var chunkCount = UInt32(constants.count)
        encoder.setBytes(&chunkCount, length: MemoryLayout<UInt32>.stride, index: Int(gaussianDecodeChunkCountIndex.rawValue))
        encoder.setBuffer(encodedSplatBuffer, offset: 0, index: Int(gaussianDecodeOutputIndex.rawValue))

        // One threadgroup per chunk; the kernel strides over the chunk when it holds more
        // splats than a threadgroup has threads.
        let threadsPerGroup = min(header.splatsPerChunk, pipelineState.maxTotalThreadsPerThreadgroup)
        encoder.dispatchThreadgroups(
            MTLSize(width: constants.count, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if let error = commandBuffer.error {
            throw GaussianChunkLoadError.gpuDecodeFailed(error.localizedDescription)
        }

        return GaussianChunkLoadResult(
            splatCount: splatCount,
            encodedSplatBuffer: encodedSplatBuffer,
            sphericalHarmonicsBuffer: sphericalHarmonicsBuffer,
            sphericalHarmonicsMetadata: header.shMetadata,
            meanSquaredSplatExtent: header.meanSquaredSplatExtent,
            captureExposureEV: header.captureExposureEV,
            captureWhiteBalance: header.captureWhiteBalance,
            boundingBox: (header.boundingBoxMin, header.boundingBoxMax),
            index: file.index,
            chunkTable: GaussianChunkTable(
                constantsBuffer: constantsBuffer,
                chunkCount: constants.count,
                splatsPerChunk: header.splatsPerChunk,
                index: file.index
            )
        )
    }
}
