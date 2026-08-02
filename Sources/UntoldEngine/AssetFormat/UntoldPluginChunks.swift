//
//  UntoldPluginChunks.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

public enum UntoldPluginChunkFormat {
    public static let magic: UInt32 = 0x5458_4555 // "UEXT" little-endian bytes.
    public static let version: UInt16 = 1
}

public struct UntoldPluginChunkMetadata: Sendable, Equatable {
    public let pluginID: String
    public let chunkKind: UInt32
    public let chunkVersion: UInt32

    public init(pluginID: String, chunkKind: UInt32, chunkVersion: UInt32) {
        self.pluginID = pluginID
        self.chunkKind = chunkKind
        self.chunkVersion = chunkVersion
    }
}

public struct UntoldPluginChunk: Sendable, Equatable {
    public let chunkType: UntoldChunkType
    public let metadata: UntoldPluginChunkMetadata
    public let payload: Data

    public init(
        chunkType: UntoldChunkType,
        metadata: UntoldPluginChunkMetadata,
        payload: Data
    ) {
        self.chunkType = chunkType
        self.metadata = metadata
        self.payload = payload
    }
}

public enum UntoldPluginChunkEnvelope {
    public static func encode(metadata: UntoldPluginChunkMetadata, payload: Data) -> Data {
        let pluginIDData = Data(metadata.pluginID.utf8)
        precondition(pluginIDData.count <= Int(UInt16.max), "Plugin IDs must fit in UInt16 byte length")

        let writer = UntoldBinaryWriter()
        writer.writeUInt32LE(UntoldPluginChunkFormat.magic)
        writer.writeUInt16LE(UntoldPluginChunkFormat.version)
        writer.writeUInt16LE(UInt16(pluginIDData.count))
        writer.writeUInt32LE(metadata.chunkKind)
        writer.writeUInt32LE(metadata.chunkVersion)
        writer.writeData(pluginIDData)
        writer.writeData(payload)
        return writer.data
    }

    public static func decode(chunkType: UntoldChunkType, data: Data) throws -> UntoldPluginChunk {
        let reader = UntoldBinaryReader(data: data)
        let magic = try reader.readUInt32LE()
        guard magic == UntoldPluginChunkFormat.magic else {
            throw UntoldValidationError.invalidPluginChunkHeader
        }

        let version = try reader.readUInt16LE()
        guard version == UntoldPluginChunkFormat.version else {
            throw UntoldValidationError.unsupportedPluginChunkVersion(UInt32(version))
        }

        let pluginIDLength = try Int(reader.readUInt16LE())
        let chunkKind = try reader.readUInt32LE()
        let chunkVersion = try reader.readUInt32LE()
        let pluginIDData = try reader.readBytes(count: pluginIDLength)
        guard let pluginID = String(data: pluginIDData, encoding: .utf8),
              !pluginID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw UntoldValidationError.invalidPluginChunkHeader
        }

        let payload = try reader.readBytes(count: reader.remainingBytes)
        return UntoldPluginChunk(
            chunkType: chunkType,
            metadata: UntoldPluginChunkMetadata(
                pluginID: pluginID,
                chunkKind: chunkKind,
                chunkVersion: chunkVersion
            ),
            payload: payload
        )
    }
}
