//
//  UntoldRuntimeAssetLoader.swift
//  UntoldEngine
//
//  Runtime asset loader that converts cooked `.untold` files into the
//  source-agnostic RuntimeAsset abstraction.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public struct UntoldRuntimeAssetLoader: NamedRuntimeAssetLoading {
    public init() {}

    public func loadAsset(from url: URL) async throws -> RuntimeAsset {
        try loadAssetSync(from: url)
    }

    public func loadAssetSync(from url: URL) throws -> RuntimeAsset {
        let decoded = try UntoldReader().readAsset(from: url)
        let fileData = try Data(contentsOf: url)

        let vertexChunk = try requiredChunk(.vertexData, in: decoded.chunks)
        let indexChunk = try requiredChunk(.indexData, in: decoded.chunks)
        let vertexChunkData = try chunkData(for: vertexChunk, fileData: fileData)
        let indexChunkData = try chunkData(for: indexChunk, fileData: fileData)

        let runtimeMaterials = try decoded.materials.map { try makeRuntimeMaterial(from: $0, decoded: decoded, baseURL: url.deletingLastPathComponent()) }
        let nodes = try makeRuntimeNodes(
            decoded: decoded,
            rootTransform: decoded.header.rootTransform,
            runtimeMaterials: runtimeMaterials,
            vertexChunkData: vertexChunkData,
            indexChunkData: indexChunkData
        )

        return RuntimeAsset(
            sourceURL: url,
            sourceKind: .untold,
            assetName: url.deletingPathExtension().lastPathComponent,
            rootTransform: decoded.header.rootTransform,
            worldBounds: decoded.header.worldBounds,
            nodes: nodes
        )
    }

    public func loadMeshGroup(named name: String, from url: URL) async throws -> RuntimeMeshGroup? {
        let asset = try await loadAsset(from: url)
        return asset.meshGroups.first(where: { $0.name == name })
    }

    public func loadMeshGroupSync(named name: String, from url: URL) throws -> RuntimeMeshGroup? {
        let asset = try loadAssetSync(from: url)
        return asset.meshGroups.first(where: { $0.name == name })
    }

    private func makeRuntimeNodes(
        decoded: UntoldDecodedAsset,
        rootTransform: simd_float4x4,
        runtimeMaterials: [RuntimeMaterialSource],
        vertexChunkData: Data,
        indexChunkData: Data
    ) throws -> [RuntimeAssetNode] {
        let entitiesByID = Dictionary(uniqueKeysWithValues: decoded.entities.map { ($0.entityId, $0) })
        var worldTransformsByID: [UInt32: simd_float4x4] = [:]
        var visiting: Set<UInt32> = []

        func resolvedWorldTransform(for entity: UntoldEntityRecordV1) throws -> simd_float4x4 {
            if let cached = worldTransformsByID[entity.entityId] {
                return cached
            }

            guard !visiting.contains(entity.entityId) else {
                throw RuntimeAssetLoaderError.malformedAsset("Cycle detected in .untold entity hierarchy for entity \(entity.entityId)")
            }
            visiting.insert(entity.entityId)
            defer { visiting.remove(entity.entityId) }

            let worldTransform: simd_float4x4
            if entity.parentEntityId == UntoldFormat.invalidIndex {
                worldTransform = simd_mul(rootTransform, entity.localTransform)
            } else if let parent = entitiesByID[entity.parentEntityId] {
                worldTransform = simd_mul(try resolvedWorldTransform(for: parent), entity.localTransform)
            } else {
                throw RuntimeAssetLoaderError.malformedAsset("Entity \(entity.entityId) references missing parent \(entity.parentEntityId)")
            }

            worldTransformsByID[entity.entityId] = worldTransform
            return worldTransform
        }

        return try decoded.entities.map { entity in
            try makeRuntimeNode(
                from: entity,
                decoded: decoded,
                resolvedWorldTransform: try resolvedWorldTransform(for: entity),
                runtimeMaterials: runtimeMaterials,
                vertexChunkData: vertexChunkData,
                indexChunkData: indexChunkData
            )
        }
    }

    private func requiredChunk(_ type: UntoldChunkType, in chunks: [UntoldChunkEntryV1]) throws -> UntoldChunkEntryV1 {
        guard let chunk = chunks.first(where: { $0.chunkType == type }) else {
            throw UntoldValidationError.missingRequiredChunk(type)
        }
        return chunk
    }

    private func chunkData(for chunk: UntoldChunkEntryV1, fileData: Data) throws -> Data {
        let start = Int(chunk.fileOffset)
        let end = start + Int(chunk.compressedSize)
        guard start >= 0, end <= fileData.count else {
            throw UntoldBinaryDecodingError.outOfBounds(
                offset: start,
                requested: Int(chunk.compressedSize),
                available: fileData.count
            )
        }
        return fileData.subdata(in: start ..< end)
    }

    private func makeRuntimeNode(
        from entity: UntoldEntityRecordV1,
        decoded: UntoldDecodedAsset,
        resolvedWorldTransform: simd_float4x4,
        runtimeMaterials: [RuntimeMaterialSource],
        vertexChunkData: Data,
        indexChunkData: Data
    ) throws -> RuntimeAssetNode {
        let nodeName = try decoded.string(at: entity.nameOffset) ?? "entity_\(entity.entityId)"
        let meshStart = Int(entity.firstMeshRecordIndex)
        let meshEnd = meshStart + Int(entity.meshRecordCount)
        let primitives: [RuntimeMeshPrimitive]
        if meshStart < meshEnd, meshStart >= 0, meshEnd <= decoded.meshes.count {
            primitives = try decoded.meshes[meshStart ..< meshEnd].map { mesh in
                try makeRuntimePrimitive(
                    from: mesh,
                    entity: entity,
                    decoded: decoded,
                    runtimeMaterials: runtimeMaterials,
                    vertexChunkData: vertexChunkData,
                    indexChunkData: indexChunkData
                )
            }
        } else {
            primitives = []
        }

        return RuntimeAssetNode(
            id: entity.entityId,
            parentID: entity.parentEntityId == UntoldFormat.invalidIndex ? nil : entity.parentEntityId,
            name: nodeName,
            localTransform: entity.localTransform,
            worldTransform: resolvedWorldTransform,
            localBounds: entity.localBounds,
            worldBounds: entity.worldBounds,
            primitives: primitives
        )
    }

    private func makeRuntimePrimitive(
        from mesh: UntoldMeshRecordV1,
        entity: UntoldEntityRecordV1,
        decoded: UntoldDecodedAsset,
        runtimeMaterials: [RuntimeMaterialSource],
        vertexChunkData: Data,
        indexChunkData: Data
    ) throws -> RuntimeMeshPrimitive {
        let vertexLayout: RuntimeVertexLayout = switch decoded.header.vertexLayout {
        case .pbrStaticV1:
            .pbrStaticV1
        }

        let indexFormat: RuntimeIndexFormat = switch mesh.indexType {
        case .uint16:
            .uint16
        case .uint32:
            .uint32
        }

        let primitiveName = try decoded.string(at: mesh.meshNameOffset) ?? "mesh_\(mesh.entityId)"
        let vertexData = try slice(
            from: vertexChunkData,
            offset: Int(mesh.vertexDataOffset),
            size: Int(mesh.vertexDataSizeBytes)
        )
        let indexData = try slice(
            from: indexChunkData,
            offset: Int(mesh.indexDataOffset),
            size: Int(mesh.indexDataSizeBytes)
        )

        let material: RuntimeMaterialSource?
        if mesh.materialIndex != UntoldFormat.invalidIndex {
            material = runtimeMaterials[Int(mesh.materialIndex)]
        } else {
            material = nil
        }

        return RuntimeMeshPrimitive(
            name: primitiveName,
            localTransform: matrix_identity_float4x4,
            worldTransform: matrix_identity_float4x4,
            localBounds: mesh.localBounds,
            worldBounds: entity.worldBounds,
            vertexLayout: vertexLayout,
            vertexData: vertexData,
            indexData: indexData,
            indexFormat: indexFormat,
            vertexCount: Int(mesh.vertexCount),
            indexCount: Int(mesh.indexCount),
            material: material,
            estimatedGPUBytes: Int(mesh.estimatedGPUBytes)
        )
    }

    private func makeRuntimeMaterial(
        from material: UntoldMaterialRecordV1,
        decoded: UntoldDecodedAsset,
        baseURL: URL
    ) throws -> RuntimeMaterialSource {
        RuntimeMaterialSource(
            name: try decoded.string(at: material.nameOffset),
            baseColorFactor: material.baseColorFactor,
            emissiveFactor: material.emissiveFactor,
            normalScale: material.normalScale,
            metallicFactor: material.metallicFactor,
            roughnessFactor: material.roughnessFactor,
            occlusionStrength: material.occlusionStrength,
            alphaCutoff: material.alphaCutoff,
            flags: material.flags,
            baseColorTexture: try textureReference(at: material.baseColorTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: true),
            normalTexture: try textureReference(at: material.normalTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            metallicTexture: try textureReference(at: material.metallicTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            roughnessTexture: try textureReference(at: material.roughnessTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            emissiveTexture: try textureReference(at: material.emissiveTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: true),
            occlusionTexture: try textureReference(at: material.occlusionTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false)
        )
    }

    private func textureReference(
        at index: UInt32,
        decoded: UntoldDecodedAsset,
        baseURL: URL,
        isSRGB: Bool
    ) throws -> RuntimeTextureReference? {
        guard index != UntoldFormat.invalidIndex else { return nil }
        guard Int(index) < decoded.textures.count else {
            throw UntoldValidationError.invalidMaterialIndex(index)
        }

        let record = decoded.textures[Int(index)]
        let name = try decoded.string(at: record.nameOffset)
        let uriString = try decoded.string(at: record.uriOffset)
        let sourceURL = resolvedURL(from: uriString, baseURL: baseURL)
        return RuntimeTextureReference(
            name: name,
            sourceURL: sourceURL,
            isSRGB: isSRGB,
            flags: record.flags,
            width: Int(record.width),
            height: Int(record.height),
            mipCount: Int(record.mipCount)
        )
    }

    private func resolvedURL(from string: String?, baseURL: URL) -> URL? {
        guard let string, !string.isEmpty else { return nil }
        if let absolute = URL(string: string), absolute.scheme != nil {
            return absolute
        }
        let relativeURL = baseURL.appendingPathComponent(string)
        if FileManager.default.fileExists(atPath: relativeURL.path) {
            return relativeURL
        }

        let basename = URL(fileURLWithPath: string).lastPathComponent
        let flattenedBundleURL = baseURL.appendingPathComponent(basename)
        if FileManager.default.fileExists(atPath: flattenedBundleURL.path) {
            return flattenedBundleURL
        }

        return relativeURL
    }

    private func slice(from data: Data, offset: Int, size: Int) throws -> Data {
        let end = offset + size
        guard offset >= 0, size >= 0, end <= data.count else {
            throw UntoldBinaryDecodingError.outOfBounds(
                offset: offset,
                requested: size,
                available: data.count
            )
        }
        return data.subdata(in: offset ..< end)
    }
}
