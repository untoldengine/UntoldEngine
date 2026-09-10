//
//  UntoldAssetPatcher.swift
//  UntoldEngine
//
//  Rewrites the `gaussianAsset` table of a cooked `.untold` file so a scene author (the
//  editor, the CLI) can link an entity to a splat payload after the export. Every other
//  chunk is copied byte for byte; only the string table and the gaussianAsset table are
//  re-emitted.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

/// Sets, removes and lists the `gaussianAsset` records (chunk 25,
/// `UntoldGaussianAssetRecordV1`) of a `.untold` file without re-encoding anything else.
///
/// The `.untold` container has no whole-file writer in Swift; this patcher does not need one.
/// It reads the file through `UntoldReader`, copies the stored bytes of every chunk it does not
/// own (compression, element count and uncompressed size preserved), appends the payload path to
/// the string table when the string is new, emits the new gaussianAsset table, lays the chunks
/// out again on `UntoldFormat.fileAlignment`, and rewrites the header's chunk count and content
/// hash. The result is read back through `UntoldReader` before it is returned.
public enum UntoldAssetPatcher {
    /// What one entity of a `.untold` file links to: the settings of a
    /// `UntoldGaussianAssetRecordV1` with the payload path decoded. Paths are stored relative to
    /// the `.untold` file's directory (see `NativeFormatLoader`'s resolution: an absolute URL, a
    /// path relative to the file, or the flattened basename).
    public struct GaussianAssetLink: Sendable, Equatable {
        /// Path of the `.untoldgs` payload, relative to the `.untold` file's directory.
        public var payloadPath: String
        /// See `UntoldGaussianAssetFlags`. The alignment bit is never held here — it follows
        /// `alignment` — so a value that carries it, copied from a decoded record say, is
        /// stored without it.
        public var flags: UInt32 {
            didSet { flags &= ~UntoldGaussianAssetFlags.alignment }
        }

        /// Valid entries in `lodSplatCounts` / `lodSwitchScreenHeights`, 0...4. Zero means one level.
        public var lodCount: Int
        /// Splat count per LOD level, coarsest first. `lodCount` entries; the initializer pads a
        /// shorter array with zeros so a link compares equal to what `gaussianAssets(in:)` reads back.
        public var lodSplatCounts: [UInt32]
        /// Screen height in pixels above which the next finer level is preferred. `lodCount`
        /// entries, padded like `lodSplatCounts`.
        public var lodSwitchScreenHeights: [Float]
        /// Metres the mesh twin's depth-only occluder shell is shrunk along its normals.
        public var occluderShrinkMeters: Float
        /// Exposure offset in EV, applied on top of the payload's capture exposure.
        public var exposureOffsetEV: Float
        /// Camera distance at which the swap and its prefetch arm. Zero means always.
        public var swapDistanceMeters: Float
        /// How the splat sits in the entity's local space (`GaussianComponent.splatToEntity`),
        /// or nil for identity. Written as the record's alignment fields with
        /// `UntoldGaussianAssetFlags.alignment` set when non-nil; that flag is derived from this
        /// property and never kept in `flags`.
        public var alignment: GaussianSplatAlignment?

        public init(
            payloadPath: String,
            flags: UInt32 = UntoldGaussianAssetFlags.meshTwin,
            lodCount: Int = 0,
            lodSplatCounts: [UInt32] = [],
            lodSwitchScreenHeights: [Float] = [],
            occluderShrinkMeters: Float = 0.02,
            exposureOffsetEV: Float = 0,
            swapDistanceMeters: Float = 0,
            alignment: GaussianSplatAlignment? = nil
        ) {
            self.payloadPath = payloadPath
            self.flags = flags & ~UntoldGaussianAssetFlags.alignment
            self.alignment = alignment
            self.lodCount = lodCount
            // The record stores `maxLODLevels` slots and reads back `lodCount` of them, so a
            // shorter array would come back zero-padded; pad here so the link round-trips.
            // Longer arrays are left alone for `validate()` to reject.
            let levels = min(max(lodCount, 0), UntoldGaussianAssetRecordV1.maxLODLevels)
            self.lodSplatCounts = Self.padded(lodSplatCounts, to: levels, with: 0)
            self.lodSwitchScreenHeights = Self.padded(lodSwitchScreenHeights, to: levels, with: 0)
            self.occluderShrinkMeters = occluderShrinkMeters
            self.exposureOffsetEV = exposureOffsetEV
            self.swapDistanceMeters = swapDistanceMeters
        }

        /// The link a file's record describes, with its path read from the string table.
        public init(record: UntoldGaussianAssetRecordV1, payloadPath: String) {
            let levels = Int(record.lodCount)
            self.init(
                payloadPath: payloadPath,
                flags: record.flags,
                lodCount: levels,
                lodSplatCounts: Array(record.lodSplatCounts.prefix(levels)),
                lodSwitchScreenHeights: Array(record.lodSwitchScreenHeights.prefix(levels)),
                occluderShrinkMeters: record.occluderShrinkMeters,
                exposureOffsetEV: record.exposureOffsetEV,
                swapDistanceMeters: record.swapDistanceMeters,
                alignment: record.alignment
            )
        }

        /// The record this link is written as, once the path sits in the string table. The link
        /// is expected to pass `validate()`; a link that does not is still turned into a record
        /// (a negative `lodCount` clamps to zero, arrays are cut or padded to four slots) rather
        /// than trapping, so a caller may preview the record before validating.
        public func record(entityId: UInt32, payloadPathOffset: UInt32) -> UntoldGaussianAssetRecordV1 {
            UntoldGaussianAssetRecordV1(
                entityId: entityId,
                payloadPathOffset: payloadPathOffset,
                flags: flags & ~UntoldGaussianAssetFlags.alignment,
                lodCount: UInt32(clamping: lodCount),
                lodSplatCounts: lodSplatCounts,
                lodSwitchScreenHeights: lodSwitchScreenHeights,
                occluderShrinkMeters: occluderShrinkMeters,
                exposureOffsetEV: exposureOffsetEV,
                swapDistanceMeters: swapDistanceMeters,
                alignment: alignment
            )
        }

        /// Throws `UntoldAssetPatcher.Error.invalidLink` when the link cannot be written as a
        /// record `UntoldReader` would accept: an empty path or one containing NUL (the string
        /// table is NUL-terminated), more than `UntoldGaussianAssetRecordV1.maxLODLevels` levels or
        /// more LOD entries than levels, negative or non-finite distances, a non-finite exposure,
        /// an alignment that is not finite or whose scale is not greater than zero.
        public func validate() throws {
            guard !payloadPath.isEmpty else {
                throw Error.invalidLink("payload path is empty")
            }
            guard !payloadPath.utf8.contains(0) else {
                throw Error.invalidLink("payload path contains a NUL byte")
            }
            guard (0 ... UntoldGaussianAssetRecordV1.maxLODLevels).contains(lodCount) else {
                throw Error.invalidLink("lodCount \(lodCount) is not in 0...\(UntoldGaussianAssetRecordV1.maxLODLevels)")
            }
            guard lodSplatCounts.count <= lodCount else {
                throw Error.invalidLink("\(lodSplatCounts.count) lodSplatCounts for \(lodCount) levels")
            }
            guard lodSwitchScreenHeights.count <= lodCount else {
                throw Error.invalidLink("\(lodSwitchScreenHeights.count) lodSwitchScreenHeights for \(lodCount) levels")
            }
            guard lodSwitchScreenHeights.allSatisfy(\.isFinite) else {
                throw Error.invalidLink("lodSwitchScreenHeights must be finite")
            }
            guard occluderShrinkMeters.isFinite, occluderShrinkMeters >= 0 else {
                throw Error.invalidLink("occluderShrinkMeters \(occluderShrinkMeters) must be finite and non-negative")
            }
            guard swapDistanceMeters.isFinite, swapDistanceMeters >= 0 else {
                throw Error.invalidLink("swapDistanceMeters \(swapDistanceMeters) must be finite and non-negative")
            }
            guard exposureOffsetEV.isFinite else {
                throw Error.invalidLink("exposureOffsetEV must be finite")
            }
            if let alignment, !alignment.isValid {
                throw Error.invalidLink("alignment must be finite with a scale greater than zero (\(alignment))")
            }
        }

        private static func padded<T>(_ values: [T], to count: Int, with fill: T) -> [T] {
            guard values.count < count else { return values }
            return values + Array(repeating: fill, count: count - values.count)
        }
    }

    public enum Error: Swift.Error, Equatable, CustomStringConvertible {
        /// The entity id is not in the file's entity table.
        case unknownEntity(UInt32)
        /// The link fails `GaussianAssetLink.validate()`; the payload says why.
        case invalidLink(String)
        /// The input did not read as a `.untold` file, or the patched output did not read back.
        case corruptFile(String)

        public var description: String {
            switch self {
            case let .unknownEntity(entityId):
                "entity \(entityId) is not in the entity table"
            case let .invalidLink(reason):
                "invalid gaussianAsset link: \(reason)"
            case let .corruptFile(reason):
                "corrupt .untold file: \(reason)"
            }
        }
    }

    // MARK: - Public API

    /// Returns `fileData` with the `gaussianAsset` record for `entityId` set to `link`,
    /// replacing an existing record for that entity. Every other chunk's stored bytes are
    /// copied unchanged (compression preserved). The payload path is appended to the string
    /// table unless an identical string already exists, whose offset is reused; the string
    /// table is otherwise append-only, so every offset the other tables hold stays valid. The
    /// gaussianAsset table chunk is replaced in place or appended; chunk offsets are laid out
    /// again on 16-byte alignment, `header.chunkCount` is updated and `header.contentHash` is
    /// recomputed — or kept all-zero when the input had an all-zero hash, since such a file is
    /// read without the check.
    public static func settingGaussianAsset(
        _ link: GaussianAssetLink,
        onEntity entityId: UInt32,
        in fileData: Data
    ) throws -> Data {
        try link.validate()
        let decoded = try decode(fileData)
        guard decoded.entities.contains(where: { $0.entityId == entityId }) else {
            throw Error.unknownEntity(entityId)
        }

        var stringTable = decoded.stringTableData
        let pathOffset = try appendingStringIfNeeded(link.payloadPath, to: &stringTable)
        let record = link.record(entityId: entityId, payloadPathOffset: pathOffset)

        var records = decoded.gaussianAssets.filter { $0.entityId != entityId }
        if let index = decoded.gaussianAssets.firstIndex(where: { $0.entityId == entityId }) {
            records.insert(record, at: min(index, records.count))
        } else {
            records.append(record)
        }

        let result = try rebuild(decoded, fileData: fileData, stringTable: stringTable, gaussianAssets: records)
        try verify(result) { asset in
            asset.gaussianAssets.contains { $0.entityId == entityId && $0.payloadPathOffset == pathOffset }
        }
        return result
    }

    /// Returns `fileData` without the `gaussianAsset` record for `entityId`; the chunk is
    /// dropped when the table becomes empty. Returns the input unchanged when the file carries
    /// no record for that entity. The path string stays in the string table, which is
    /// append-only. Throws `unknownEntity` when the entity is not in the entity table.
    public static func removingGaussianAsset(onEntity entityId: UInt32, in fileData: Data) throws -> Data {
        let decoded = try decode(fileData)
        guard decoded.entities.contains(where: { $0.entityId == entityId }) else {
            throw Error.unknownEntity(entityId)
        }
        guard decoded.gaussianAssets.contains(where: { $0.entityId == entityId }) else {
            return fileData
        }
        let records = decoded.gaussianAssets.filter { $0.entityId != entityId }
        let result = try rebuild(decoded, fileData: fileData, stringTable: decoded.stringTableData, gaussianAssets: records)
        try verify(result) { asset in
            !asset.gaussianAssets.contains { $0.entityId == entityId }
        }
        return result
    }

    /// The links a file carries, by entity id, with paths decoded from the string table. When
    /// an entity has more than one record the first is kept, as `NativeFormatLoader` does.
    public static func gaussianAssets(in fileData: Data) throws -> [UInt32: GaussianAssetLink] {
        let decoded = try decode(fileData)
        var links: [UInt32: GaussianAssetLink] = [:]
        for record in decoded.gaussianAssets where links[record.entityId] == nil {
            guard let path = try decoded.string(at: record.payloadPathOffset) else {
                throw Error.corruptFile("gaussianAsset record for entity \(record.entityId) has no payload path")
            }
            links[record.entityId] = GaussianAssetLink(record: record, payloadPath: path)
        }
        return links
    }

    // MARK: - Reading

    private static func decode(_ fileData: Data) throws -> UntoldDecodedAsset {
        do {
            return try UntoldReader().readAsset(from: fileData)
        } catch {
            throw Error.corruptFile(String(describing: error))
        }
    }

    /// The patched file must read back, and carry what was asked for.
    private static func verify(_ fileData: Data, _ check: (UntoldDecodedAsset) -> Bool) throws {
        let asset: UntoldDecodedAsset
        do {
            asset = try UntoldReader().readAsset(from: fileData)
        } catch {
            throw Error.corruptFile("patched file does not read back: \(error)")
        }
        guard check(asset) else {
            throw Error.corruptFile("patched file does not carry the requested gaussianAsset table")
        }
    }

    // MARK: - String table

    /// The offset of `string` in the table: an existing entry's when one is identical, else the
    /// offset it is appended at. Entries are the NUL-terminated strings of the table, so the
    /// match is on whole entries, never on the tail of a longer one.
    static func appendingStringIfNeeded(_ string: String, to stringTable: inout Data) throws -> UInt32 {
        let bytes = Array(string.utf8)
        var entryStart = stringTable.startIndex
        while entryStart < stringTable.endIndex {
            guard let terminator = stringTable[entryStart...].firstIndex(of: 0) else { break }
            if stringTable[entryStart ..< terminator].elementsEqual(bytes) {
                return UInt32(entryStart - stringTable.startIndex)
            }
            entryStart = terminator + 1
        }

        var offset = stringTable.count
        if entryStart < stringTable.endIndex {
            // The table ends in an unterminated run of bytes; terminate it so the new entry
            // does not extend a string that some record already points into.
            stringTable.append(0)
            offset = stringTable.count
        }
        guard offset <= Int(UInt32.max) - bytes.count - 1 else {
            throw Error.invalidLink("string table too large for a 32-bit offset")
        }
        stringTable.append(contentsOf: bytes)
        stringTable.append(0)
        return UInt32(offset)
    }

    // MARK: - Layout

    private struct ChunkPayload {
        var entry: UntoldChunkEntryV1
        var storedBytes: Data
    }

    /// Re-emits the file: the header, the chunk table, then every chunk payload on 16-byte
    /// alignment in the input's chunk order. Chunks other than the string table and the
    /// gaussianAsset table keep their stored bytes and entry fields; the two owned tables are
    /// written uncompressed.
    private static func rebuild(
        _ decoded: UntoldDecodedAsset,
        fileData: Data,
        stringTable: Data,
        gaussianAssets: [UntoldGaussianAssetRecordV1]
    ) throws -> Data {
        var payloads: [ChunkPayload] = []
        payloads.reserveCapacity(decoded.chunks.count + 1)
        for chunk in decoded.chunks {
            switch chunk.chunkType {
            case .stringTable:
                var entry = chunk
                entry.compressionType = .none
                entry.compressedSize = UInt64(stringTable.count)
                entry.uncompressedSize = UInt64(stringTable.count)
                payloads.append(ChunkPayload(entry: entry, storedBytes: stringTable))
            case .gaussianAssetTable:
                guard !gaussianAssets.isEmpty else { continue }
                payloads.append(gaussianAssetPayload(gaussianAssets, template: chunk))
            default:
                // Compared in UInt64 before converting: an entry the reader never touches (an
                // unknown chunk type) may carry sizes that do not fit an Int.
                guard chunk.fileOffset <= UInt64(fileData.count),
                      chunk.compressedSize <= UInt64(fileData.count) - chunk.fileOffset
                else {
                    throw Error.corruptFile("chunk \(chunk.chunkType.rawValue) points outside the file")
                }
                let start = Int(chunk.fileOffset)
                let end = start + Int(chunk.compressedSize)
                payloads.append(ChunkPayload(entry: chunk, storedBytes: fileData.subdata(in: start ..< end)))
            }
        }
        if !gaussianAssets.isEmpty, !decoded.chunks.contains(where: { $0.chunkType == .gaussianAssetTable }) {
            payloads.append(gaussianAssetPayload(gaussianAssets, template: nil))
        }

        var header = decoded.header
        header.chunkCount = UInt32(payloads.count)
        let headerSize = encodedSize(of: header)
        let chunkTableSize = encodedSize(of: UntoldChunkEntryV1(chunkType: .stringTable, fileOffset: 0, compressedSize: 0, uncompressedSize: 0)) * payloads.count
        let alignment = Int(UntoldFormat.fileAlignment)

        var runningOffset = headerSize + chunkTableSize
        for index in payloads.indices {
            runningOffset = aligned(runningOffset, to: alignment)
            payloads[index].entry.fileOffset = UInt64(runningOffset)
            payloads[index].entry.compressedSize = UInt64(payloads[index].storedBytes.count)
            runningOffset += payloads[index].storedBytes.count
        }

        let file = UntoldBinaryWriter()
        header.encode(to: file)
        for payload in payloads {
            payload.entry.encode(to: file)
        }
        for payload in payloads {
            file.align(to: alignment)
            file.writeData(payload.storedBytes)
        }

        // The hash covers the payloads alone, so the header is filled in once they are laid out.
        guard header.contentHash.contains(where: { $0 != 0 }) else { return file.data }
        var data = file.data
        header.contentHash = try Array(UntoldFormat.contentHash(of: payloads.map(\.entry), in: data))
        let headerWriter = UntoldBinaryWriter()
        header.encode(to: headerWriter)
        data.replaceSubrange(0 ..< headerSize, with: headerWriter.data)
        return data
    }

    private static func gaussianAssetPayload(
        _ records: [UntoldGaussianAssetRecordV1],
        template: UntoldChunkEntryV1?
    ) -> ChunkPayload {
        let writer = UntoldBinaryWriter()
        for record in records {
            record.encode(to: writer)
        }
        var entry = template ?? UntoldChunkEntryV1(
            chunkType: .gaussianAssetTable,
            fileOffset: 0,
            compressedSize: 0,
            uncompressedSize: 0
        )
        entry.compressionType = .none
        entry.compressedSize = UInt64(writer.count)
        entry.uncompressedSize = UInt64(writer.count)
        entry.elementCount = UInt32(records.count)
        return ChunkPayload(entry: entry, storedBytes: writer.data)
    }

    private static func encodedSize(of value: some UntoldBinaryEncodable) -> Int {
        let writer = UntoldBinaryWriter()
        value.encode(to: writer)
        return writer.count
    }

    private static func aligned(_ value: Int, to alignment: Int) -> Int {
        let remainder = value % alignment
        return remainder == 0 ? value : value + (alignment - remainder)
    }
}
