//
//  NativeFormatLoader.swift
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

public struct NativeFormatLoader: NamedRuntimeAssetLoading {
    public init() {}

    public func loadAsset(from url: URL) async throws -> RuntimeAsset {
        try loadAssetSync(from: url)
    }

    public func loadAssetSync(from url: URL) throws -> RuntimeAsset {
        let fileData = try Data(contentsOf: url, options: .mappedIfSafe)
        let reader = UntoldReader()
        let decoded = try reader.readAsset(from: fileData)
        let animationClips = try makeRuntimeAnimationClips(decoded: decoded)

        let vertexChunkData: Data
        let indexChunkData: Data
        let edgeIndexChunkData: Data?
        let jointIndexChunkData: Data?
        let jointWeightChunkData: Data?
        if decoded.header.fileType == .animation {
            vertexChunkData = Data()
            indexChunkData = Data()
            edgeIndexChunkData = nil
            jointIndexChunkData = nil
            jointWeightChunkData = nil
        } else {
            vertexChunkData = try reader.readChunkData(.vertexData, from: fileData, entries: decoded.chunks)
            indexChunkData = try reader.readChunkData(.indexData, from: fileData, entries: decoded.chunks)
            edgeIndexChunkData = try? reader.readChunkData(.edgeIndexData, from: fileData, entries: decoded.chunks)
            jointIndexChunkData = try? reader.readChunkData(.jointIndexData, from: fileData, entries: decoded.chunks)
            jointWeightChunkData = try? reader.readChunkData(.jointWeightData, from: fileData, entries: decoded.chunks)
        }

        let runtimeMaterials = try decoded.materials.map { try makeRuntimeMaterial(from: $0, decoded: decoded, baseURL: url.deletingLastPathComponent()) }
        let nodes = try makeRuntimeNodes(
            decoded: decoded,
            rootTransform: decoded.header.rootTransform,
            runtimeMaterials: runtimeMaterials,
            vertexChunkData: vertexChunkData,
            indexChunkData: indexChunkData,
            edgeIndexChunkData: edgeIndexChunkData,
            jointIndexChunkData: jointIndexChunkData,
            jointWeightChunkData: jointWeightChunkData
        )

        return try RuntimeAsset(
            sourceURL: url,
            sourceKind: .untold,
            assetName: url.deletingPathExtension().lastPathComponent,
            rootTransform: decoded.header.rootTransform,
            worldBounds: decoded.header.worldBounds,
            nodes: nodes,
            lights: makeRuntimeLights(decoded: decoded),
            cameras: makeRuntimeCameras(decoded: decoded),
            colorManagement: makeRuntimeColorManagement(decoded: decoded, baseURL: url.deletingLastPathComponent()),
            animationClips: animationClips
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
        indexChunkData: Data,
        edgeIndexChunkData: Data?,
        jointIndexChunkData: Data?,
        jointWeightChunkData: Data?
    ) throws -> [RuntimeAssetNode] {
        guard decoded.header.fileType != .animation else { return [] }
        let entitiesByID = Dictionary(uniqueKeysWithValues: decoded.entities.map { ($0.entityId, $0) })
        let runtimeSkeletonsByEntity = try makeRuntimeSkeletonsByEntity(decoded: decoded)
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
                worldTransform = try simd_mul(resolvedWorldTransform(for: parent), entity.localTransform)
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
                resolvedWorldTransform: resolvedWorldTransform(for: entity),
                runtimeMaterials: runtimeMaterials,
                vertexChunkData: vertexChunkData,
                indexChunkData: indexChunkData,
                edgeIndexChunkData: edgeIndexChunkData,
                jointIndexChunkData: jointIndexChunkData,
                jointWeightChunkData: jointWeightChunkData,
                runtimeSkeletonsByEntity: runtimeSkeletonsByEntity
            )
        }
    }

    private func makeRuntimeLights(decoded: UntoldDecodedAsset) throws -> [RuntimeLightSource] {
        try decoded.lights.map { record in
            let usesRadiometricUnits = record.flags & UntoldLightFlags.radiometric != 0
            let hasCustomDistance = record.flags & UntoldLightFlags.customDistance != 0
            let castsShadow = usesRadiometricUnits
                ? record.flags & UntoldLightFlags.castsShadow != 0
                : record.lightType == .directional
            return try RuntimeLightSource(
                name: decoded.string(at: record.nameOffset),
                kind: runtimeLightKind(from: record.lightType),
                color: record.color,
                intensity: record.intensity,
                position: record.position,
                radius: record.radius,
                range: usesRadiometricUnits && hasCustomDistance ? max(record.falloff, 0.0) : 0.0,
                direction: record.direction,
                falloff: usesRadiometricUnits ? 0.5 : record.falloff,
                right: record.right,
                innerCone: record.innerCone,
                up: record.up,
                outerCone: record.outerCone,
                areaSize: record.areaSize,
                sourcePower: record.sourcePower,
                sourceExposure: record.sourceExposure,
                castsShadow: castsShadow,
                usesRadiometricUnits: usesRadiometricUnits,
                localTransform: record.localTransform
            )
        }
    }

    private func makeRuntimeCameras(decoded: UntoldDecodedAsset) throws -> [RuntimeCameraSource] {
        try decoded.cameras.map { record in
            try RuntimeCameraSource(
                name: decoded.string(at: record.nameOffset),
                position: record.position,
                forward: record.forward,
                up: record.up,
                right: record.right,
                fovYDegrees: record.fovYDegrees,
                nearClip: record.nearClip,
                farClip: record.farClip,
                aspectRatio: record.aspectRatio,
                localTransform: record.localTransform
            )
        }
    }

    private func makeRuntimeColorManagement(decoded: UntoldDecodedAsset, baseURL: URL) throws -> RuntimeColorManagement? {
        guard let record = decoded.colorManagement else { return nil }
        guard (2 ... 64).contains(record.lutSize),
              record.shaperMinStops.isFinite,
              record.shaperMaxStops.isFinite,
              record.shaperMaxStops > record.shaperMinStops,
              record.exposure.isFinite,
              record.gamma.isFinite,
              record.gamma > 0
        else {
            throw UntoldValidationError.invalidColorManagementRecord
        }

        guard record.lutTextureIndex != UntoldFormat.invalidIndex,
              Int(record.lutTextureIndex) < decoded.textures.count
        else {
            throw UntoldValidationError.invalidMaterialIndex(record.lutTextureIndex)
        }
        let textureRecord = decoded.textures[Int(record.lutTextureIndex)]
        guard textureRecord.textureFormat == .rgba16Float,
              textureRecord.mipCount == 1,
              textureRecord.flags & UntoldTextureFlags.lut != 0
        else {
            throw UntoldValidationError.invalidColorManagementRecord
        }
        let expectedWidth = record.lutSize * record.lutSize
        guard textureRecord.width == expectedWidth, textureRecord.height == record.lutSize else {
            throw UntoldValidationError.invalidColorManagementTextureDimensions(
                expectedWidth: expectedWidth,
                expectedHeight: record.lutSize,
                actualWidth: textureRecord.width,
                actualHeight: textureRecord.height
            )
        }

        return try RuntimeColorManagement(
            lutTexture: textureReference(at: record.lutTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            exposure: record.exposure,
            gamma: record.gamma,
            shaperMinStops: record.shaperMinStops,
            shaperMaxStops: record.shaperMaxStops,
            lutSize: Int(record.lutSize)
        )
    }

    private func runtimeLightKind(from lightType: UntoldLightType) -> RuntimeLightSourceKind {
        switch lightType {
        case .directional: .directional
        case .point: .point
        case .spot: .spot
        case .area: .area
        }
    }

    private func makeRuntimeNode(
        from entity: UntoldEntityRecordV1,
        decoded: UntoldDecodedAsset,
        resolvedWorldTransform: simd_float4x4,
        runtimeMaterials: [RuntimeMaterialSource],
        vertexChunkData: Data,
        indexChunkData: Data,
        edgeIndexChunkData: Data?,
        jointIndexChunkData: Data?,
        jointWeightChunkData: Data?,
        runtimeSkeletonsByEntity: [UInt32: RuntimeSkeleton]
    ) throws -> RuntimeAssetNode {
        let nodeName = try decoded.string(at: entity.nameOffset) ?? "entity_\(entity.entityId)"
        let meshStart = Int(entity.firstMeshRecordIndex)
        let meshEnd = meshStart + Int(entity.meshRecordCount)
        let primitives: [RuntimeMeshPrimitive]
        if meshStart < meshEnd, meshStart >= 0, meshEnd <= decoded.meshes.count {
            primitives = try decoded.meshes[meshStart ..< meshEnd].enumerated().map { offset, mesh in
                try makeRuntimePrimitive(
                    from: mesh,
                    meshIndex: UInt32(meshStart + offset),
                    entity: entity,
                    decoded: decoded,
                    runtimeMaterials: runtimeMaterials,
                    vertexChunkData: vertexChunkData,
                    indexChunkData: indexChunkData,
                    edgeIndexChunkData: edgeIndexChunkData,
                    jointIndexChunkData: jointIndexChunkData,
                    jointWeightChunkData: jointWeightChunkData
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
            skeleton: runtimeSkeletonsByEntity[entity.entityId],
            primitives: primitives
        )
    }

    private func makeRuntimePrimitive(
        from mesh: UntoldMeshRecordV1,
        meshIndex: UInt32,
        entity: UntoldEntityRecordV1,
        decoded: UntoldDecodedAsset,
        runtimeMaterials: [RuntimeMaterialSource],
        vertexChunkData: Data,
        indexChunkData: Data,
        edgeIndexChunkData: Data?,
        jointIndexChunkData: Data?,
        jointWeightChunkData: Data?
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
        let edgeIndexCount = Int(mesh.edgeIndexCount)
        let edgeIndexData: Data
        if edgeIndexCount > 0, let edgeIndexChunkData {
            edgeIndexData = try slice(
                from: edgeIndexChunkData,
                offset: Int(mesh.edgeIndexDataOffset),
                size: edgeIndexCount * indexFormat.byteSize
            )
        } else {
            edgeIndexData = Data()
        }

        let material: RuntimeMaterialSource?
        if mesh.materialIndex != UntoldFormat.invalidIndex {
            material = runtimeMaterials[Int(mesh.materialIndex)]
        } else {
            material = nil
        }

        let skinRecord = decoded.skins.first(where: { $0.meshRecordIndex == meshIndex })
        let skin: RuntimeSkinBinding?
        if let skinRecord, let jointIndexChunkData, let jointWeightChunkData {
            let mappingStart = Int(skinRecord.firstJointMappingIndex)
            let mappingEnd = mappingStart + Int(skinRecord.jointCount)
            let mapping = decoded.skinJointMappings[mappingStart ..< mappingEnd].map { Int($0.skeletonJointIndex) }
            let jointIndexData = try slice(
                from: jointIndexChunkData,
                offset: Int(skinRecord.jointIndexDataOffset),
                size: Int(skinRecord.vertexCount) * MemoryLayout<SIMD4<UInt16>>.stride
            )
            let jointWeightData = try slice(
                from: jointWeightChunkData,
                offset: Int(skinRecord.jointWeightDataOffset),
                size: Int(skinRecord.vertexCount) * MemoryLayout<SIMD4<Float>>.stride
            )
            skin = RuntimeSkinBinding(
                skeletonEntityID: skinRecord.skeletonEntityId == UntoldFormat.invalidIndex ? nil : skinRecord.skeletonEntityId,
                skinToSkeletonMap: mapping,
                jointIndexData: jointIndexData,
                jointWeightData: jointWeightData
            )
        } else {
            skin = nil
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
            edgeIndexData: edgeIndexData,
            indexFormat: indexFormat,
            vertexCount: Int(mesh.vertexCount),
            indexCount: Int(mesh.indexCount),
            edgeIndexCount: edgeIndexCount,
            material: material,
            skin: skin,
            estimatedGPUBytes: Int(mesh.estimatedGPUBytes)
        )
    }

    private func makeRuntimeSkeletonsByEntity(decoded: UntoldDecodedAsset) throws -> [UInt32: RuntimeSkeleton] {
        var result: [UInt32: RuntimeSkeleton] = [:]
        for skeleton in decoded.skeletons {
            let start = Int(skeleton.firstJointRecordIndex)
            let end = start + Int(skeleton.jointRecordCount)
            let joints = Array(decoded.skeletonJoints[start ..< end])
            let jointPaths = try joints.map { try decoded.string(at: $0.jointPathOffset) ?? "" }
            let parentIndices = joints.map { $0.parentJointIndex == UntoldFormat.invalidIndex ? nil : Int($0.parentJointIndex) }
            let bindTransforms = joints.map(\.bindTransform)
            let restTransforms = joints.map(\.restTransform)
            result[skeleton.entityId] = try RuntimeSkeleton(
                name: decoded.string(at: skeleton.nameOffset),
                jointPaths: jointPaths,
                parentIndices: parentIndices,
                bindTransforms: bindTransforms,
                restTransforms: restTransforms
            )
        }
        return result
    }

    private func makeRuntimeAnimationClips(decoded: UntoldDecodedAsset) throws -> [RuntimeAnimationClip] {
        try decoded.animationClips.enumerated().map { _, clip in
            let channelStart = Int(clip.firstChannelRecordIndex)
            let channelEnd = channelStart + Int(clip.channelRecordCount)
            let channels = try decoded.animationChannels[channelStart ..< channelEnd].map { channel in
                let translationStart = Int(channel.firstTranslationKeyframeIndex)
                let translationEnd = translationStart + Int(channel.translationKeyframeCount)
                let translations = decoded.translationKeyframes[translationStart ..< translationEnd].map {
                    RuntimeTranslationKeyframe(time: $0.time, value: $0.value)
                }

                let rotationStart = Int(channel.firstRotationKeyframeIndex)
                let rotationEnd = rotationStart + Int(channel.rotationKeyframeCount)
                let rotations = decoded.rotationKeyframes[rotationStart ..< rotationEnd].map {
                    RuntimeRotationKeyframe(time: $0.time, value: $0.value)
                }

                return try RuntimeAnimationChannel(
                    jointPath: decoded.string(at: channel.jointPathOffset) ?? "",
                    translations: translations,
                    rotations: rotations
                )
            }

            return try RuntimeAnimationClip(
                name: decoded.string(at: clip.nameOffset) ?? "clip",
                duration: clip.duration,
                channels: Array(channels)
            )
        }
    }

    private func makeRuntimeMaterial(
        from material: UntoldMaterialRecordV1,
        decoded: UntoldDecodedAsset,
        baseURL: URL
    ) throws -> RuntimeMaterialSource {
        // Files older than minTrustedEmissiveVersion were exported before the
        // Blender exporter multiplied emissive_factor by Emission Strength, so
        // untouched materials carry a bogus (1,1,1) left over from Blender's
        // default Emission Color rather than genuine authored emissive.
        let emissiveFactor = decoded.header.formatVersion >= UntoldFormat.minTrustedEmissiveVersion
            ? material.emissiveFactor
            : SIMD3<Float>(repeating: 0)

        return try RuntimeMaterialSource(
            name: decoded.string(at: material.nameOffset),
            baseColorFactor: material.baseColorFactor,
            emissiveFactor: emissiveFactor,
            normalScale: material.normalScale,
            metallicFactor: material.metallicFactor,
            roughnessFactor: material.roughnessFactor,
            metallicTextureChannel: material.metallicTextureChannel,
            roughnessTextureChannel: material.roughnessTextureChannel,
            occlusionStrength: material.occlusionStrength,
            alphaCutoff: material.alphaCutoff,
            flags: material.flags,
            baseColorTexture: textureReference(at: material.baseColorTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: true),
            normalTexture: textureReference(at: material.normalTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            metallicTexture: textureReference(at: material.metallicTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            roughnessTexture: textureReference(at: material.roughnessTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            emissiveTexture: textureReference(at: material.emissiveTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: true),
            occlusionTexture: textureReference(at: material.occlusionTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            heightTexture: textureReference(at: material.heightTextureIndex, decoded: decoded, baseURL: baseURL, isSRGB: false),
            heightScale: material.heightScale,
            heightBias: material.heightBias,
            heightRemapMin: material.heightRemapMin,
            heightRemapMax: material.heightRemapMax
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
            mipCount: Int(record.mipCount),
            textureFormat: record.textureFormat
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
