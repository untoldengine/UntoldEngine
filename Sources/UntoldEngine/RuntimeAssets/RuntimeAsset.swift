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

    public init(
        name: String? = nil,
        sourceURL: URL? = nil,
        isSRGB: Bool = false,
        flags: UInt32 = 0,
        width: Int? = nil,
        height: Int? = nil,
        mipCount: Int? = nil
    ) {
        self.name = name
        self.sourceURL = sourceURL
        self.isSRGB = isSRGB
        self.flags = flags
        self.width = width
        self.height = height
        self.mipCount = mipCount
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

public struct RuntimeAssetNode: Sendable, Equatable {
    public var id: UInt32
    public var parentID: UInt32?
    public var name: String
    public var localTransform: simd_float4x4
    public var worldTransform: simd_float4x4
    public var localBounds: RuntimeAABB
    public var worldBounds: RuntimeAABB
    public var primitives: [RuntimeMeshPrimitive]

    public init(
        id: UInt32,
        parentID: UInt32? = nil,
        name: String,
        localTransform: simd_float4x4 = matrix_identity_float4x4,
        worldTransform: simd_float4x4 = matrix_identity_float4x4,
        localBounds: RuntimeAABB,
        worldBounds: RuntimeAABB,
        primitives: [RuntimeMeshPrimitive]
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.localTransform = localTransform
        self.worldTransform = worldTransform
        self.localBounds = localBounds
        self.worldBounds = worldBounds
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
    public var meshGroups: [RuntimeMeshGroup]

    public init(
        sourceURL: URL,
        sourceKind: RuntimeAssetSourceKind,
        assetName: String,
        rootTransform: simd_float4x4 = matrix_identity_float4x4,
        worldBounds: RuntimeAABB,
        nodes: [RuntimeAssetNode] = [],
        meshGroups: [RuntimeMeshGroup]
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
        self.meshGroups = meshGroups
    }

    public init(
        sourceURL: URL,
        sourceKind: RuntimeAssetSourceKind,
        assetName: String,
        rootTransform: simd_float4x4 = matrix_identity_float4x4,
        worldBounds: RuntimeAABB,
        nodes: [RuntimeAssetNode]
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
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
