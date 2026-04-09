//
//  NativeTextureLoader.swift
//  UntoldEngine
//
//  Loads engine-native .utex texture containers directly into MTLTexture
//  without passing through MTKTextureLoader or any CGImage-based decode path.
//
//  The loader memory-maps the .utex file, reads the NativeTexHeader and mip table,
//  creates a GPU-private MTLTexture, and uploads each mip level via a staging
//  MTLBuffer + blit encoder.  No CPU-side decompression occurs — ASTC blocks are
//  transferred to the GPU as-is and decoded in hardware.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Metal

public final class NativeTextureLoader: @unchecked Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    public init?(device: MTLDevice) {
        guard let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        commandQueue = queue
        commandQueue.label = "NativeTextureLoader"
    }

    // MARK: - Public entry points

    /// Load a .utex file at `url` and return a GPU-private MTLTexture containing all mip levels.
    /// Returns nil and logs on any error.
    public func loadTexture(from url: URL, label: String? = nil) -> MTLTexture? {
        do {
            return try loadTextureOrThrow(from: url, targetMaxDimension: nil, label: label)
        } catch {
            Logger.logError(message: "[NativeTextureLoader] Failed to load '\(url.lastPathComponent)': \(error)")
            return nil
        }
    }

    /// Load a .utex file, including only the mip levels whose width is at or below
    /// `targetMaxDimension`.  Pass `nil` to load all mip levels (same as `loadTexture(from:)`).
    ///
    /// Use this for distance-based mip streaming: coarse mips for distant objects (saves
    /// GPU memory), fine mips for nearby objects (full fidelity).  The returned texture
    /// has the correct pixel dimensions for the requested tier, so it integrates
    /// transparently with the rest of the streaming system's size comparisons.
    public func loadTexture(from url: URL, targetMaxDimension: Int?, label: String? = nil) -> MTLTexture? {
        do {
            return try loadTextureOrThrow(from: url, targetMaxDimension: targetMaxDimension, label: label)
        } catch {
            Logger.logError(message: "[NativeTextureLoader] Failed to load '\(url.lastPathComponent)' (maxDim=\(targetMaxDimension.map(String.init) ?? "full")): \(error)")
            return nil
        }
    }

    // MARK: - Internal load

    private func loadTextureOrThrow(from url: URL, targetMaxDimension: Int?, label: String?) throws -> MTLTexture {
        // Memory-map the file — zero-copy read for the header and mip table.
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)

        let reader = NativeTexReader()
        let (header, allMips) = try reader.read(from: fileData)

        guard let pixelFormat = MTLPixelFormat(rawValue: UInt(header.pixelFormat)) else {
            throw NativeTexLoadError.unsupportedPixelFormat(header.pixelFormat)
        }
        guard device.supportsPixelFormat(pixelFormat) else {
            throw NativeTexLoadError.pixelFormatNotSupported(pixelFormat)
        }

        // Select the subset of mips to upload.
        // Walk from mip 0 (largest) toward the end; use the first mip whose
        // width fits within targetMaxDimension as the starting level.
        // If targetMaxDimension is nil, start from mip 0 (full resolution).
        let startMip: Int
        if let maxDim = targetMaxDimension, maxDim > 0 {
            startMip = allMips.firstIndex(where: { Int($0.widthPx) <= maxDim }) ?? (allMips.count - 1)
        } else {
            startMip = 0
        }
        let mips = Array(allMips[startMip...])

        let texture = try makeTexture(
            pixelFormat: pixelFormat,
            width: Int(mips[0].widthPx),
            height: Int(mips[0].heightPx),
            mipCount: mips.count,
            label: label
        )
        try upload(mips: mips, from: fileData, header: header, to: texture)
        return texture
    }

    // MARK: - Texture creation

    private func makeTexture(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        mipCount: Int,
        label: String?
    ) throws -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: mipCount > 1
        )
        desc.mipmapLevelCount = mipCount
        desc.storageMode = .private
        desc.usage = .shaderRead  // ASTC blocks cannot be reinterpreted; no .pixelFormatView needed

        guard let texture = device.makeTexture(descriptor: desc) else {
            throw NativeTexLoadError.textureAllocationFailed
        }
        texture.label = label ?? "utex_\(width)x\(height)"
        return texture
    }

    // MARK: - Mip upload

    private func upload(
        mips: [NativeTexMipEntry],
        from fileData: Data,
        header: NativeTexHeader,
        to texture: MTLTexture
    ) throws {
        let blockW = Int(header.blockWidth)
        let blockH = Int(header.blockHeight)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            throw NativeTexLoadError.commandEncoderCreationFailed
        }
        blitEncoder.label = "NativeTextureLoader.blit"

        for (mipIndex, mip) in mips.enumerated() {
            let mipW = Int(mip.widthPx)
            let mipH = Int(mip.heightPx)
            let blocksWide = (mipW + blockW - 1) / blockW
            let blocksHigh = (mipH + blockH - 1) / blockH
            let bytesPerRow = blocksWide * 16      // each ASTC block is always 16 bytes
            let bytesPerImage = bytesPerRow * blocksHigh

            // Slice the mip payload out of the memory-mapped file data.
            let payloadStart = Int(header.payloadOffset) + Int(mip.byteOffset)
            let payloadEnd = payloadStart + Int(mip.byteSize)
            guard payloadEnd <= fileData.count else {
                blitEncoder.endEncoding()
                throw NativeTexLoadError.mipPayloadOutOfBounds(
                    mipIndex: mipIndex,
                    offset: Int(mip.byteOffset),
                    size: Int(mip.byteSize),
                    fileSize: fileData.count
                )
            }

            // Copy into a CPU-visible staging buffer so we can blit to the
            // GPU-private texture.  The buffer is released after the blit commits.
            let stagingBuffer = fileData.withUnsafeBytes { rawBytes -> MTLBuffer? in
                let basePointer = rawBytes.baseAddress!.advanced(by: payloadStart)
                return device.makeBuffer(bytes: basePointer, length: Int(mip.byteSize), options: .storageModeShared)
            }
            guard let stagingBuffer else {
                blitEncoder.endEncoding()
                throw NativeTexLoadError.stagingBufferAllocationFailed(mipIndex: mipIndex)
            }
            stagingBuffer.label = "NativeTexStaging_mip\(mipIndex)"

            blitEncoder.copy(
                from: stagingBuffer,
                sourceOffset: 0,
                sourceBytesPerRow: bytesPerRow,
                sourceBytesPerImage: bytesPerImage,
                sourceSize: MTLSize(width: mipW, height: mipH, depth: 1),
                to: texture,
                destinationSlice: 0,
                destinationLevel: mipIndex,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
        }

        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()  // synchronous for Phase 2; async upload in a later phase

        if let error = commandBuffer.error {
            throw NativeTexLoadError.gpuUploadFailed(error)
        }
    }
}

// MARK: - Load errors

public enum NativeTexLoadError: Error, Sendable {
    case unsupportedPixelFormat(UInt32)
    case pixelFormatNotSupported(MTLPixelFormat)
    case textureAllocationFailed
    case commandEncoderCreationFailed
    case mipPayloadOutOfBounds(mipIndex: Int, offset: Int, size: Int, fileSize: Int)
    case stagingBufferAllocationFailed(mipIndex: Int)
    case gpuUploadFailed(Error)
}

// MARK: - MTLDevice pixel format support helper

private extension MTLDevice {
    /// Returns true if the device supports creating a texture with this pixel format.
    func supportsPixelFormat(_ format: MTLPixelFormat) -> Bool {
        // ASTC formats require Apple GPU family 2 or later (A8 and newer, all Apple Silicon).
        // Use raw values to avoid ASTC enum-case availability differences across SDK targets.
        // Covers: astc_4x4..astc_12x12 in both sRGB (186-200) and LDR (204-218) variants.
        let raw = format.rawValue
        let isASTC = (raw >= 186 && raw <= 200) || (raw >= 204 && raw <= 218)
        if isASTC {
            return supportsFamily(.apple2)
        }
        return true
    }
}
