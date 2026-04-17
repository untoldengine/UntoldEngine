//
//  RuntimeAsset.swift
//  UntoldEngine
//
//  Source-agnostic runtime asset abstractions consumed by the engine after
//  import/cooked-file decoding. This layer intentionally does not depend on
//  ModelIO so `.untold` and legacy USD loaders can target the same contract.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

public typealias RuntimeAABB = UntoldAABB

public enum RuntimeAssetSourceKind: String, Sendable {
    case usd
    case untold
    case procedural
}

public struct RuntimeTextureReference: Sendable, Equatable {
    public var name: String?
    public var sourceURL: URL?
    public var isSRGB: Bool
    public var flags: UInt32
    public var width: Int?
    public var height: Int?
    public var mipCount: Int?
    /// Compressed format of the source asset. When `isASTCNative` is true the
    /// engine loads the texture via NativeTextureLoader instead of MTKTextureLoader.
    public var textureFormat: UntoldTextureFormat

    public init(
        name: String? = nil,
        sourceURL: URL? = nil,
        isSRGB: Bool = false,
        flags: UInt32 = 0,
        width: Int? = nil,
        height: Int? = nil,
        mipCount: Int? = nil,
        textureFormat: UntoldTextureFormat = .unknown
    ) {
        self.name = name
        self.sourceURL = sourceURL
        self.isSRGB = isSRGB
        self.flags = flags
        self.width = width
        self.height = height
        self.mipCount = mipCount
        self.textureFormat = textureFormat
    }
}

public struct RuntimeMaterialSource: Sendable, Equatable {
    public var name: String?
    public var baseColorFactor: SIMD4<Float>
    public var emissiveFactor: SIMD3<Float>
    public var normalScale: Float
    public var metallicFactor: Float
    public var roughnessFactor: Float
    public var occlusionStrength: Float
    public var alphaCutoff: Float
    public var flags: UInt32
    public var baseColorTexture: RuntimeTextureReference?
    public var normalTexture: RuntimeTextureReference?
    public var metallicTexture: RuntimeTextureReference?
    public var roughnessTexture: RuntimeTextureReference?
    public var emissiveTexture: RuntimeTextureReference?
    public var occlusionTexture: RuntimeTextureReference?

    public init(
        name: String? = nil,
        baseColorFactor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1),
        emissiveFactor: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        normalScale: Float = 1.0,
        metallicFactor: Float = 1.0,
        roughnessFactor: Float = 1.0,
        occlusionStrength: Float = 1.0,
        alphaCutoff: Float = 0.5,
        flags: UInt32 = 0,
        baseColorTexture: RuntimeTextureReference? = nil,
        normalTexture: RuntimeTextureReference? = nil,
        metallicTexture: RuntimeTextureReference? = nil,
        roughnessTexture: RuntimeTextureReference? = nil,
        emissiveTexture: RuntimeTextureReference? = nil,
        occlusionTexture: RuntimeTextureReference? = nil
    ) {
        self.name = name
        self.baseColorFactor = baseColorFactor
        self.emissiveFactor = emissiveFactor
        self.normalScale = normalScale
        self.metallicFactor = metallicFactor
        self.roughnessFactor = roughnessFactor
        self.occlusionStrength = occlusionStrength
        self.alphaCutoff = alphaCutoff
        self.flags = flags
        self.baseColorTexture = baseColorTexture
        self.normalTexture = normalTexture
        self.metallicTexture = metallicTexture
        self.roughnessTexture = roughnessTexture
        self.emissiveTexture = emissiveTexture
        self.occlusionTexture = occlusionTexture
    }
}

public enum RuntimeIndexFormat: UInt32, Sendable, Equatable {
    case uint16 = 1
    case uint32 = 2

    public var byteSize: Int {
        switch self {
        case .uint16: 2
        case .uint32: 4
        }
    }
}

public enum RuntimeVertexLayout: UInt32, Sendable, Equatable {
    case pbrStaticV1 = 1

    public var stride: Int {
        switch self {
        case .pbrStaticV1: 32
        }
    }
}

public struct RuntimeSkeleton: Sendable, Equatable {
    public var name: String?
    public var jointPaths: [String]
    public var parentIndices: [Int?]
    public var bindTransforms: [simd_float4x4]
    public var restTransforms: [simd_float4x4]

    public init(
        name: String? = nil,
        jointPaths: [String],
        parentIndices: [Int?],
        bindTransforms: [simd_float4x4],
        restTransforms: [simd_float4x4]
    ) {
        self.name = name
        self.jointPaths = jointPaths
        self.parentIndices = parentIndices
        self.bindTransforms = bindTransforms
        self.restTransforms = restTransforms
    }
}

public struct RuntimeSkinBinding: Sendable, Equatable {
    public var skeletonEntityID: UInt32?
    public var skinToSkeletonMap: [Int]
    public var jointIndexData: Data
    public var jointWeightData: Data

    public init(
        skeletonEntityID: UInt32? = nil,
        skinToSkeletonMap: [Int],
        jointIndexData: Data,
        jointWeightData: Data
    ) {
        self.skeletonEntityID = skeletonEntityID
        self.skinToSkeletonMap = skinToSkeletonMap
        self.jointIndexData = jointIndexData
        self.jointWeightData = jointWeightData
    }
}

public struct RuntimeTranslationKeyframe: Sendable, Equatable {
    public var time: Float
    public var value: SIMD3<Float>

    public init(time: Float, value: SIMD3<Float>) {
        self.time = time
        self.value = value
    }
}

public struct RuntimeRotationKeyframe: Sendable, Equatable {
    public var time: Float
    public var value: SIMD4<Float>

    public init(time: Float, value: SIMD4<Float>) {
        self.time = time
        self.value = value
    }
}

public struct RuntimeAnimationChannel: Sendable, Equatable {
    public var jointPath: String
    public var translations: [RuntimeTranslationKeyframe]
    public var rotations: [RuntimeRotationKeyframe]

    public init(
        jointPath: String,
        translations: [RuntimeTranslationKeyframe] = [],
        rotations: [RuntimeRotationKeyframe] = []
    ) {
        self.jointPath = jointPath
        self.translations = translations
        self.rotations = rotations
    }
}

public struct RuntimeAnimationClip: Sendable, Equatable {
    public var name: String
    public var duration: Float
    public var channels: [RuntimeAnimationChannel]

    public init(name: String, duration: Float, channels: [RuntimeAnimationChannel]) {
        self.name = name
        self.duration = duration
        self.channels = channels
    }
}

public struct RuntimeAssetNode: Sendable, Equatable {
    public var id: UInt32
    public var parentID: UInt32?
    public var name: String
    public var localTransform: simd_float4x4
    public var worldTransform: simd_float4x4
    public var localBounds: RuntimeAABB
    public var worldBounds: RuntimeAABB
    public var skeleton: RuntimeSkeleton?
    public var primitives: [RuntimeMeshPrimitive]

    public init(
        id: UInt32,
        parentID: UInt32? = nil,
        name: String,
        localTransform: simd_float4x4 = matrix_identity_float4x4,
        worldTransform: simd_float4x4 = matrix_identity_float4x4,
        localBounds: RuntimeAABB,
        worldBounds: RuntimeAABB,
        skeleton: RuntimeSkeleton? = nil,
        primitives: [RuntimeMeshPrimitive]
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.localTransform = localTransform
        self.worldTransform = worldTransform
        self.localBounds = localBounds
        self.worldBounds = worldBounds
        self.skeleton = skeleton
        self.primitives = primitives
    }
}

public struct RuntimeMeshPrimitive: Sendable, Equatable {
    public var name: String
    public var localTransform: simd_float4x4
    public var worldTransform: simd_float4x4
    public var localBounds: RuntimeAABB
    public var worldBounds: RuntimeAABB
    public var vertexLayout: RuntimeVertexLayout
    public var vertexData: Data
    public var indexData: Data
    public var indexFormat: RuntimeIndexFormat
    public var vertexCount: Int
    public var indexCount: Int
    public var material: RuntimeMaterialSource?
    public var skin: RuntimeSkinBinding?
    public var estimatedGPUBytes: Int

    public init(
        name: String,
        localTransform: simd_float4x4 = matrix_identity_float4x4,
        worldTransform: simd_float4x4 = matrix_identity_float4x4,
        localBounds: RuntimeAABB,
        worldBounds: RuntimeAABB,
        vertexLayout: RuntimeVertexLayout,
        vertexData: Data,
        indexData: Data,
        indexFormat: RuntimeIndexFormat,
        vertexCount: Int,
        indexCount: Int,
        material: RuntimeMaterialSource? = nil,
        skin: RuntimeSkinBinding? = nil,
        estimatedGPUBytes: Int = 0
    ) {
        self.name = name
        self.localTransform = localTransform
        self.worldTransform = worldTransform
        self.localBounds = localBounds
        self.worldBounds = worldBounds
        self.vertexLayout = vertexLayout
        self.vertexData = vertexData
        self.indexData = indexData
        self.indexFormat = indexFormat
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.material = material
        self.skin = skin
        self.estimatedGPUBytes = estimatedGPUBytes
    }
}

public struct RuntimeMeshGroup: Sendable, Equatable {
    public var name: String
    public var localTransform: simd_float4x4
    public var worldTransform: simd_float4x4
    public var localBounds: RuntimeAABB
    public var worldBounds: RuntimeAABB
    public var primitives: [RuntimeMeshPrimitive]

    public init(
        name: String,
        localTransform: simd_float4x4 = matrix_identity_float4x4,
        worldTransform: simd_float4x4 = matrix_identity_float4x4,
        localBounds: RuntimeAABB,
        worldBounds: RuntimeAABB,
        primitives: [RuntimeMeshPrimitive]
    ) {
        self.name = name
        self.localTransform = localTransform
        self.worldTransform = worldTransform
        self.localBounds = localBounds
        self.worldBounds = worldBounds
        self.primitives = primitives
    }
}

public struct RuntimeAsset: Sendable, Equatable {
    public var sourceURL: URL
    public var sourceKind: RuntimeAssetSourceKind
    public var assetName: String
    public var rootTransform: simd_float4x4
    public var worldBounds: RuntimeAABB
    public var nodes: [RuntimeAssetNode]
    public var animationClips: [RuntimeAnimationClip]
    public var meshGroups: [RuntimeMeshGroup]

    public init(
        sourceURL: URL,
        sourceKind: RuntimeAssetSourceKind,
        assetName: String,
        rootTransform: simd_float4x4 = matrix_identity_float4x4,
        worldBounds: RuntimeAABB,
        nodes: [RuntimeAssetNode] = [],
        animationClips: [RuntimeAnimationClip] = [],
        meshGroups: [RuntimeMeshGroup]
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
        self.animationClips = animationClips
        self.meshGroups = meshGroups
    }

    public init(
        sourceURL: URL,
        sourceKind: RuntimeAssetSourceKind,
        assetName: String,
        rootTransform: simd_float4x4 = matrix_identity_float4x4,
        worldBounds: RuntimeAABB,
        nodes: [RuntimeAssetNode],
        animationClips: [RuntimeAnimationClip] = []
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
        self.animationClips = animationClips
        meshGroups = nodes.compactMap { node in
            guard !node.primitives.isEmpty else { return nil }
            return RuntimeMeshGroup(
                name: node.name,
                localTransform: node.localTransform,
                worldTransform: node.worldTransform,
                localBounds: node.localBounds,
                worldBounds: node.worldBounds,
                primitives: node.primitives
            )
        }
    }
}
