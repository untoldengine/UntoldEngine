//
//  NativeTexFormat.swift
//  UntoldEngine
//
//  Binary format types for the engine-native .utex texture container.
//  Defines the V1 header, mip table entry, format constants,
//  and binary encode/decode conformances.
//
//  Layout (64-byte header):
//    offset  0 │ magic[8]        "UTEX\0\0\0\0"
//    offset  8 │ version         UInt32
//    offset 12 │ flags           UInt32 (NativeTexFlags)
//    offset 16 │ width           UInt32 (mip-0 pixels)
//    offset 20 │ height          UInt32 (mip-0 pixels)
//    offset 24 │ mipCount        UInt32
//    offset 28 │ pixelFormat     UInt32 (exact MTLPixelFormat rawValue)
//    offset 32 │ blockWidth      UInt8
//    offset 33 │ blockHeight     UInt8
//    offset 34 │ reserved[2]     UInt8
//    offset 36 │ payloadOffset   UInt32 (16-byte aligned, from file start)
//    offset 40 │ totalPayloadSize UInt32
//    offset 44 │ reserved1[5]    UInt32 × 5  (forward compat, write as 0)
//  ─── total: 64 bytes ───
//
//  Mip table (16 bytes × mipCount, at byte 64):
//    byteOffset   UInt32  (from payloadOffset start, 16-byte aligned)
//    byteSize     UInt32
//    widthPx      UInt32
//    heightPx     UInt32
//
//  Payload: raw GPU texture data, mip 0 first (full-res → smallest).
//  ASTC payloads contain 16-byte compressed blocks. Uncompressed RGBA16Float
//  payloads use a 1×1 block and eight bytes per texel.
//  Each mip block stream is 16-byte aligned.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

// MARK: - Format constants

public enum NativeTexFormat {
    /// Fixed 8-byte magic identifying a .utex file.
    public static let magic: [UInt8] = [0x55, 0x54, 0x45, 0x58, 0x00, 0x00, 0x00, 0x00]
    public static let version: UInt32 = 1
    /// Total byte size of NativeTexHeader. Must match the field-by-field encode/decode.
    public static let headerSize: Int = 64
    /// Byte size of each NativeTexMipEntry in the mip table.
    public static let mipEntrySize: Int = 16
    /// Required byte alignment for the payload start and each mip boundary.
    public static let payloadAlignment: Int = 16
    public static let rgba16FloatPixelFormat: UInt32 = 115
    /// MTLPixelFormatR16Unorm. Used for height/displacement map data: single-channel,
    /// 16-bit, linear (not sRGB), uncompressed. Bypasses ASTC deliberately — block
    /// compression's stepping artifacts are especially visible when the height field is
    /// ray-marched per-pixel (POM). See docs/proposals/HeightMapParallaxOcclusionMapping.md.
    public static let r16UnormPixelFormat: UInt32 = 20

    /// Compute the payload start offset for a file with the given mip count.
    /// Result is always 16-byte aligned because headerSize (64) and mipCount × mipEntrySize (16N)
    /// are both multiples of 16.
    public static func payloadOffset(mipCount: Int) -> UInt32 {
        UInt32(headerSize + mipCount * mipEntrySize)
    }

    public static func bytesPerBlock(pixelFormat: UInt32) -> Int? {
        let isASTC = (186 ... 200).contains(pixelFormat) || (204 ... 218).contains(pixelFormat)
        if isASTC {
            return 16
        }
        if pixelFormat == rgba16FloatPixelFormat {
            return 8
        }
        if pixelFormat == r16UnormPixelFormat {
            return 2
        }
        return nil
    }
}

// MARK: - Flags

/// Bit definitions for NativeTexHeader.flags.
public enum NativeTexFlags {
    /// Texture has a meaningful alpha channel.
    public static let hasAlpha: UInt32 = 1 << 0
    /// Alpha channel is premultiplied into the RGB channels.
    public static let premultipliedAlpha: UInt32 = 1 << 1
}

// MARK: - Header

/// 64-byte header at byte 0 of every .utex file.
public struct NativeTexHeader: Sendable, Equatable {
    /// Fixed 8-byte magic. Expected value: NativeTexFormat.magic.
    public var magic: [UInt8]
    public var version: UInt32
    /// Texture attribute flags. See NativeTexFlags.
    public var flags: UInt32
    /// Width of mip level 0 in pixels.
    public var width: UInt32
    /// Height of mip level 0 in pixels.
    public var height: UInt32
    /// Number of mip levels stored in this file.
    public var mipCount: UInt32
    /// Exact MTLPixelFormat raw value. This is the authoritative GPU descriptor.
    /// Examples: 186 = astc_4x4_sRGB, 204 = astc_4x4_ldr, 190 = astc_6x6_sRGB, 208 = astc_6x6_ldr
    public var pixelFormat: UInt32
    /// ASTC block width in texels (e.g. 4 for 4×4 blocks).
    public var blockWidth: UInt8
    /// ASTC block height in texels.
    public var blockHeight: UInt8
    /// 2-byte alignment pad. Write as zero.
    public var reserved: [UInt8]
    /// Byte offset from file start to the first ASTC block. Always 16-byte aligned.
    public var payloadOffset: UInt32
    /// Total byte count of all mip payloads combined.
    public var totalPayloadSize: UInt32
    /// 5-word reserved field for forward compatibility. Write as zero.
    public var reserved1: [UInt32]

    public init(
        flags: UInt32 = 0,
        width: UInt32,
        height: UInt32,
        mipCount: UInt32,
        pixelFormat: UInt32,
        blockWidth: UInt8,
        blockHeight: UInt8,
        payloadOffset: UInt32,
        totalPayloadSize: UInt32
    ) {
        magic = NativeTexFormat.magic
        version = NativeTexFormat.version
        self.flags = flags
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.pixelFormat = pixelFormat
        self.blockWidth = blockWidth
        self.blockHeight = blockHeight
        reserved = [0, 0]
        self.payloadOffset = payloadOffset
        self.totalPayloadSize = totalPayloadSize
        reserved1 = [0, 0, 0, 0, 0]
    }
}

// MARK: - Mip entry

/// 16-byte entry describing one mip level's location and pixel dimensions.
/// The mip table immediately follows the 64-byte header.
public struct NativeTexMipEntry: Sendable, Equatable {
    /// Byte offset from payloadOffset to this mip's ASTC block data. 16-byte aligned.
    public var byteOffset: UInt32
    /// Byte count of this mip's ASTC block data.
    public var byteSize: UInt32
    /// Width of this mip level in pixels.
    public var widthPx: UInt32
    /// Height of this mip level in pixels.
    public var heightPx: UInt32

    public init(byteOffset: UInt32, byteSize: UInt32, widthPx: UInt32, heightPx: UInt32) {
        self.byteOffset = byteOffset
        self.byteSize = byteSize
        self.widthPx = widthPx
        self.heightPx = heightPx
    }
}

// MARK: - Validation errors

public enum NativeTexValidationError: Error, Sendable, Equatable {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case zeroMipCount
    case zeroBlockDimension
    case unsupportedPixelFormat(UInt32)
    case invalidBlockDimensions(pixelFormat: UInt32, width: UInt8, height: UInt8)
    case invalidMipPayloadSize(mipIndex: Int, expected: UInt64, actual: UInt32)
    /// A mip entry's byte range falls outside the declared payload bounds.
    case mipEntryOutOfBounds(mipIndex: Int, offset: UInt32, size: UInt32, payloadSize: UInt32)
}

// MARK: - Binary encode / decode

extension NativeTexHeader: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeBytes(magic) // offset  0 – 7   (8 bytes)
        writer.writeUInt32LE(version) // offset  8 – 11  (4 bytes)
        writer.writeUInt32LE(flags) // offset 12 – 15  (4 bytes)
        writer.writeUInt32LE(width) // offset 16 – 19  (4 bytes)
        writer.writeUInt32LE(height) // offset 20 – 23  (4 bytes)
        writer.writeUInt32LE(mipCount) // offset 24 – 27  (4 bytes)
        writer.writeUInt32LE(pixelFormat) // offset 28 – 31  (4 bytes)
        writer.writeUInt8(blockWidth) // offset 32       (1 byte)
        writer.writeUInt8(blockHeight) // offset 33       (1 byte)
        writer.writeBytes(reserved) // offset 34 – 35  (2 bytes)
        writer.writeUInt32LE(payloadOffset) // offset 36 – 39  (4 bytes)
        writer.writeUInt32LE(totalPayloadSize) // offset 40 – 43  (4 bytes)
        for word in reserved1 { // offset 44 – 63  (5 × 4 = 20 bytes)
            writer.writeUInt32LE(word)
        }
        // Total: 64 bytes
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> NativeTexHeader {
        let magic = try Array(reader.readBytes(count: 8))
        let version = try reader.readUInt32LE()
        let flags = try reader.readUInt32LE()
        let width = try reader.readUInt32LE()
        let height = try reader.readUInt32LE()
        let mipCount = try reader.readUInt32LE()
        let pixelFormat = try reader.readUInt32LE()
        let blockWidth = try reader.readUInt8()
        let blockHeight = try reader.readUInt8()
        let reserved = try Array(reader.readBytes(count: 2))
        let payloadOffset = try reader.readUInt32LE()
        let totalPayloadSize = try reader.readUInt32LE()
        var reserved1: [UInt32] = []
        reserved1.reserveCapacity(5)
        for _ in 0 ..< 5 {
            try reserved1.append(reader.readUInt32LE())
        }

        var header = NativeTexHeader(
            flags: flags,
            width: width,
            height: height,
            mipCount: mipCount,
            pixelFormat: pixelFormat,
            blockWidth: blockWidth,
            blockHeight: blockHeight,
            payloadOffset: payloadOffset,
            totalPayloadSize: totalPayloadSize
        )
        header.magic = magic
        header.version = version
        header.reserved = reserved
        header.reserved1 = reserved1
        return header
    }
}

extension NativeTexMipEntry: UntoldBinaryEncodable, UntoldBinaryDecodable {
    public func encode(to writer: UntoldBinaryWriter) {
        writer.writeUInt32LE(byteOffset)
        writer.writeUInt32LE(byteSize)
        writer.writeUInt32LE(widthPx)
        writer.writeUInt32LE(heightPx)
    }

    public static func decode(from reader: UntoldBinaryReader) throws -> NativeTexMipEntry {
        try NativeTexMipEntry(
            byteOffset: reader.readUInt32LE(),
            byteSize: reader.readUInt32LE(),
            widthPx: reader.readUInt32LE(),
            heightPx: reader.readUInt32LE()
        )
    }
}

// MARK: - Reader helper

/// Parses a .utex file and returns the validated header and mip table.
/// Does not load or validate the ASTC payload — that is the runtime loader's job.
public struct NativeTexReader {
    public init() {}

    public func read(from data: Data) throws -> (header: NativeTexHeader, mips: [NativeTexMipEntry]) {
        let reader = UntoldBinaryReader(data: data)
        let header = try NativeTexHeader.decode(from: reader)
        try validate(header: header)

        var mips: [NativeTexMipEntry] = []
        mips.reserveCapacity(Int(header.mipCount))
        for _ in 0 ..< header.mipCount {
            try mips.append(NativeTexMipEntry.decode(from: reader))
        }

        try validate(mips: mips, header: header)
        return (header, mips)
    }

    private func validate(header: NativeTexHeader) throws {
        guard header.magic == NativeTexFormat.magic else {
            throw NativeTexValidationError.invalidMagic
        }
        guard header.version == NativeTexFormat.version else {
            throw NativeTexValidationError.unsupportedVersion(header.version)
        }
        guard header.mipCount > 0 else {
            throw NativeTexValidationError.zeroMipCount
        }
        guard header.blockWidth > 0, header.blockHeight > 0 else {
            throw NativeTexValidationError.zeroBlockDimension
        }
        guard NativeTexFormat.bytesPerBlock(pixelFormat: header.pixelFormat) != nil else {
            throw NativeTexValidationError.unsupportedPixelFormat(header.pixelFormat)
        }
        let isUncompressed = header.pixelFormat == NativeTexFormat.rgba16FloatPixelFormat
            || header.pixelFormat == NativeTexFormat.r16UnormPixelFormat
        if isUncompressed,
           header.blockWidth != 1 || header.blockHeight != 1
        {
            throw NativeTexValidationError.invalidBlockDimensions(
                pixelFormat: header.pixelFormat,
                width: header.blockWidth,
                height: header.blockHeight
            )
        }
    }

    private func validate(mips: [NativeTexMipEntry], header: NativeTexHeader) throws {
        guard let bytesPerBlock = NativeTexFormat.bytesPerBlock(pixelFormat: header.pixelFormat) else {
            throw NativeTexValidationError.unsupportedPixelFormat(header.pixelFormat)
        }
        for (index, mip) in mips.enumerated() {
            let end = UInt64(mip.byteOffset) + UInt64(mip.byteSize)
            guard end <= UInt64(header.totalPayloadSize) else {
                throw NativeTexValidationError.mipEntryOutOfBounds(
                    mipIndex: index,
                    offset: mip.byteOffset,
                    size: mip.byteSize,
                    payloadSize: header.totalPayloadSize
                )
            }
            let isUncompressed = header.pixelFormat == NativeTexFormat.rgba16FloatPixelFormat
                || header.pixelFormat == NativeTexFormat.r16UnormPixelFormat
            if isUncompressed {
                let blocksWide = (UInt64(mip.widthPx) + UInt64(header.blockWidth) - 1) / UInt64(header.blockWidth)
                let blocksHigh = (UInt64(mip.heightPx) + UInt64(header.blockHeight) - 1) / UInt64(header.blockHeight)
                let expectedSize = blocksWide * blocksHigh * UInt64(bytesPerBlock)
                guard UInt64(mip.byteSize) == expectedSize else {
                    throw NativeTexValidationError.invalidMipPayloadSize(
                        mipIndex: index,
                        expected: expectedSize,
                        actual: mip.byteSize
                    )
                }
            }
        }
    }
}
