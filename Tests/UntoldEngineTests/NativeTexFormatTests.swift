//
//  NativeTexFormatTests.swift
//  UntoldEngineTests
//
//  Tests for the engine-native .utex texture container format:
//  header encode/decode roundtrips, mip table integrity, and validation rules.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

@testable import UntoldEngine
import XCTest

final class NativeTexFormatTests: XCTestCase {
    // MARK: - Header size

    func testHeaderEncodesSixtyFourBytes() {
        let header = makeHeader()
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        XCTAssertEqual(writer.count, NativeTexFormat.headerSize,
                       "NativeTexHeader must encode to exactly \(NativeTexFormat.headerSize) bytes")
    }

    // MARK: - Mip entry size

    func testMipEntryEncodesSixteenBytes() {
        let entry = NativeTexMipEntry(byteOffset: 0, byteSize: 512, widthPx: 64, heightPx: 64)
        let writer = UntoldBinaryWriter()
        entry.encode(to: writer)
        XCTAssertEqual(writer.count, NativeTexFormat.mipEntrySize,
                       "NativeTexMipEntry must encode to exactly \(NativeTexFormat.mipEntrySize) bytes")
    }

    // MARK: - Payload offset computation

    func testPayloadOffsetWithZeroMipsIsHeaderSize() {
        XCTAssertEqual(NativeTexFormat.payloadOffset(mipCount: 0), UInt32(NativeTexFormat.headerSize))
    }

    func testPayloadOffsetIsAlwaysSixteenByteAligned() {
        for mipCount in 1 ... 20 {
            let offset = NativeTexFormat.payloadOffset(mipCount: mipCount)
            XCTAssertEqual(offset % 16, 0,
                           "payloadOffset for mipCount=\(mipCount) must be 16-byte aligned, got \(offset)")
        }
    }

    func testPayloadOffsetForOneMip() {
        // 64 (header) + 1 × 16 (mip entry) = 80
        XCTAssertEqual(NativeTexFormat.payloadOffset(mipCount: 1), 80)
    }

    func testPayloadOffsetForTwelveMips() {
        // 64 + 12 × 16 = 64 + 192 = 256
        XCTAssertEqual(NativeTexFormat.payloadOffset(mipCount: 12), 256)
    }

    // MARK: - Header roundtrip

    func testHeaderRoundtrip() throws {
        let original = makeHeader()
        let data = encode(original)
        let decoded = try NativeTexHeader.decode(from: UntoldBinaryReader(data: data))

        XCTAssertEqual(decoded.magic, NativeTexFormat.magic)
        XCTAssertEqual(decoded.version, NativeTexFormat.version)
        XCTAssertEqual(decoded.flags, original.flags)
        XCTAssertEqual(decoded.width, original.width)
        XCTAssertEqual(decoded.height, original.height)
        XCTAssertEqual(decoded.mipCount, original.mipCount)
        XCTAssertEqual(decoded.pixelFormat, original.pixelFormat)
        XCTAssertEqual(decoded.blockWidth, original.blockWidth)
        XCTAssertEqual(decoded.blockHeight, original.blockHeight)
        XCTAssertEqual(decoded.payloadOffset, original.payloadOffset)
        XCTAssertEqual(decoded.totalPayloadSize, original.totalPayloadSize)
        XCTAssertEqual(decoded.reserved, [0, 0])
        XCTAssertEqual(decoded.reserved1, [0, 0, 0, 0, 0])
    }

    func testHeaderRoundtripEquality() throws {
        let original = makeHeader()
        let decoded = try NativeTexHeader.decode(from: UntoldBinaryReader(data: encode(original)))
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Mip entry roundtrip

    func testMipEntryRoundtrip() throws {
        let original = NativeTexMipEntry(byteOffset: 256, byteSize: 16_384, widthPx: 1024, heightPx: 512)
        let decoded = try NativeTexMipEntry.decode(from: UntoldBinaryReader(data: encode(original)))
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Full container roundtrip

    func testFullContainerRoundtripWithThreeMips() throws {
        let mips = [
            NativeTexMipEntry(byteOffset: 0, byteSize: 1024, widthPx: 256, heightPx: 256),
            NativeTexMipEntry(byteOffset: 1024, byteSize: 256, widthPx: 128, heightPx: 128),
            NativeTexMipEntry(byteOffset: 1280, byteSize: 64, widthPx: 64, heightPx: 64),
        ]
        let totalPayloadSize = mips.last.map { $0.byteOffset + $0.byteSize } ?? 0
        let payloadOffset = NativeTexFormat.payloadOffset(mipCount: mips.count)

        var header = makeHeader()
        header.mipCount = UInt32(mips.count)
        header.payloadOffset = payloadOffset
        header.totalPayloadSize = totalPayloadSize

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        for mip in mips { mip.encode(to: writer) }
        let data = writer.data

        let (decodedHeader, decodedMips) = try NativeTexReader().read(from: data)
        XCTAssertEqual(decodedHeader, header)
        XCTAssertEqual(decodedMips, mips)
    }

    // MARK: - NativeTexReader validation

    func testReaderAcceptsValidContainer() throws {
        let container = makeMinimalContainer(mipCount: 4)
        XCTAssertNoThrow(try NativeTexReader().read(from: container))
    }

    func testReaderRejectsInvalidMagic() throws {
        var data = makeMinimalContainer(mipCount: 1)
        data[0] = 0xFF  // corrupt first byte of magic

        XCTAssertThrowsError(try NativeTexReader().read(from: data)) { error in
            XCTAssertEqual(error as? NativeTexValidationError, .invalidMagic)
        }
    }

    func testReaderRejectsUnsupportedVersion() throws {
        let original = makeHeader()
        let writer = UntoldBinaryWriter()
        var header = original
        header.version = 99
        header.encode(to: writer)

        XCTAssertThrowsError(try NativeTexReader().read(from: writer.data)) { error in
            XCTAssertEqual(error as? NativeTexValidationError, .unsupportedVersion(99))
        }
    }

    func testReaderRejectsZeroMipCount() throws {
        var header = makeHeader()
        header.mipCount = 0
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)

        XCTAssertThrowsError(try NativeTexReader().read(from: writer.data)) { error in
            XCTAssertEqual(error as? NativeTexValidationError, .zeroMipCount)
        }
    }

    func testReaderRejectsZeroBlockDimension() throws {
        var header = makeHeader()
        header.blockWidth = 0
        let data = makeMinimalContainerWith(header: header, mipCount: 1)

        XCTAssertThrowsError(try NativeTexReader().read(from: data)) { error in
            XCTAssertEqual(error as? NativeTexValidationError, .zeroBlockDimension)
        }
    }

    func testReaderRejectsMipEntryExceedingPayload() throws {
        // mip entry claims byteOffset=0 byteSize=9999 but totalPayloadSize=100
        let mipCount = 1
        let payloadOffset = NativeTexFormat.payloadOffset(mipCount: mipCount)
        var header = makeHeader()
        header.mipCount = 1
        header.payloadOffset = payloadOffset
        header.totalPayloadSize = 100  // deliberately small

        let overflowMip = NativeTexMipEntry(byteOffset: 0, byteSize: 9999, widthPx: 64, heightPx: 64)

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        overflowMip.encode(to: writer)

        XCTAssertThrowsError(try NativeTexReader().read(from: writer.data)) { error in
            guard case let NativeTexValidationError.mipEntryOutOfBounds(idx, _, _, _) = error else {
                return XCTFail("Expected mipEntryOutOfBounds, got \(error)")
            }
            XCTAssertEqual(idx, 0)
        }
    }

    // MARK: - Magic constant

    func testMagicIsCorrectASCII() {
        // "UTEX" followed by four zero bytes
        let magic = NativeTexFormat.magic
        XCTAssertEqual(magic.count, 8)
        XCTAssertEqual(magic[0], UInt8(ascii: "U"))
        XCTAssertEqual(magic[1], UInt8(ascii: "T"))
        XCTAssertEqual(magic[2], UInt8(ascii: "E"))
        XCTAssertEqual(magic[3], UInt8(ascii: "X"))
        XCTAssertEqual(magic[4], 0)
        XCTAssertEqual(magic[5], 0)
        XCTAssertEqual(magic[6], 0)
        XCTAssertEqual(magic[7], 0)
    }

    // MARK: - Helpers

    private func makeHeader() -> NativeTexHeader {
        NativeTexHeader(
            flags: NativeTexFlags.hasAlpha,
            width: 1024,
            height: 512,
            mipCount: 10,
            pixelFormat: 186,  // MTLPixelFormat.astc_4x4_sRGB
            blockWidth: 4,
            blockHeight: 4,
            payloadOffset: NativeTexFormat.payloadOffset(mipCount: 10),
            totalPayloadSize: 1_398_101
        )
    }

    private func encode(_ header: NativeTexHeader) -> Data {
        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        return writer.data
    }

    private func encode(_ entry: NativeTexMipEntry) -> Data {
        let writer = UntoldBinaryWriter()
        entry.encode(to: writer)
        return writer.data
    }

    /// Builds a syntactically valid container with N mips of trivial size,
    /// so NativeTexReader can parse it without payload-bounds failures.
    private func makeMinimalContainer(mipCount: Int) -> Data {
        var header = makeHeader()
        let mipByteSize: UInt32 = 16  // one ASTC block per mip (smallest valid payload)
        let payloadOffset = NativeTexFormat.payloadOffset(mipCount: mipCount)
        header.mipCount = UInt32(mipCount)
        header.payloadOffset = payloadOffset
        header.totalPayloadSize = UInt32(mipCount) * mipByteSize

        let writer = UntoldBinaryWriter()
        header.encode(to: writer)
        for i in 0 ..< mipCount {
            NativeTexMipEntry(
                byteOffset: UInt32(i) * mipByteSize,
                byteSize: mipByteSize,
                widthPx: max(1, 1024 >> i),
                heightPx: max(1, 512 >> i)
            ).encode(to: writer)
        }
        return writer.data
    }

    private func makeMinimalContainerWith(header: NativeTexHeader, mipCount: Int) -> Data {
        let writer = UntoldBinaryWriter()
        var h = header
        h.mipCount = UInt32(mipCount)
        h.payloadOffset = NativeTexFormat.payloadOffset(mipCount: mipCount)
        h.totalPayloadSize = 16
        h.encode(to: writer)
        NativeTexMipEntry(byteOffset: 0, byteSize: 16, widthPx: 4, heightPx: 4).encode(to: writer)
        return writer.data
    }
}
