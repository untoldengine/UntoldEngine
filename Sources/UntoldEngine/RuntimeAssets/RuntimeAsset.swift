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

public enum RuntimeLightSourceKind: String, Sendable, Equatable {
    case directional
    case point
    case spot
    case area
}

public struct RuntimeLightSource: Sendable, Equatable {
    public var name: String?
    public var kind: RuntimeLightSourceKind
    public var color: SIMD3<Float>
    public var intensity: Float
    public var position: SIMD3<Float>
    /// Physical source radius used for near-field regularization and shadow softness.
    public var radius: Float
    /// Optional influence cutoff in scene units. Zero means no authored cutoff.
    public var range: Float
    public var direction: SIMD3<Float>
    /// Legacy artistic falloff retained for older assets and procedural lights.
    public var falloff: Float
    public var right: SIMD3<Float>
    public var innerCone: Float
    public var up: SIMD3<Float>
    public var outerCone: Float
    public var areaSize: SIMD2<Float>
    public var sourcePower: Float
    public var sourceExposure: Float
    public var castsShadow: Bool
    public var usesRadiometricUnits: Bool
    public var localTransform: simd_float4x4

    public init(
        name: String? = nil,
        kind: RuntimeLightSourceKind,
        color: SIMD3<Float> = SIMD3<Float>(1, 1, 1),
        intensity: Float = 1.0,
        position: SIMD3<Float> = .zero,
        radius: Float = 1.0,
        range: Float = 0.0,
        direction: SIMD3<Float> = SIMD3<Float>(0, -1, 0),
        falloff: Float = 0.5,
        right: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
        innerCone: Float = 5.0,
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        outerCone: Float = 10.0,
        areaSize: SIMD2<Float> = SIMD2<Float>(1, 1),
        sourcePower: Float = 1.0,
        sourceExposure: Float = 0.0,
        castsShadow: Bool = false,
        usesRadiometricUnits: Bool = false,
        localTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.name = name
        self.kind = kind
        self.color = color
        self.intensity = intensity
        self.position = position
        self.radius = radius
        self.range = range
        self.direction = direction
        self.falloff = falloff
        self.right = right
        self.innerCone = innerCone
        self.up = up
        self.outerCone = outerCone
        self.areaSize = areaSize
        self.sourcePower = sourcePower
        self.sourceExposure = sourceExposure
        self.castsShadow = castsShadow
        self.usesRadiometricUnits = usesRadiometricUnits
        self.localTransform = localTransform
    }
}

public struct RuntimeCameraSource: Sendable, Equatable {
    public var name: String?
    public var position: SIMD3<Float>
    public var forward: SIMD3<Float>
    public var up: SIMD3<Float>
    public var right: SIMD3<Float>
    public var fovYDegrees: Float
    public var nearClip: Float
    public var farClip: Float
    public var aspectRatio: Float
    public var localTransform: simd_float4x4

    public init(
        name: String? = nil,
        position: SIMD3<Float> = .zero,
        forward: SIMD3<Float> = SIMD3<Float>(0, 0, 1),
        up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        right: SIMD3<Float> = SIMD3<Float>(1, 0, 0),
        fovYDegrees: Float = 50.0,
        nearClip: Float = 0.1,
        farClip: Float = 1000.0,
        aspectRatio: Float = 1.5,
        localTransform: simd_float4x4 = matrix_identity_float4x4
    ) {
        self.name = name
        self.position = position
        self.forward = forward
        self.up = up
        self.right = right
        self.fovYDegrees = fovYDegrees
        self.nearClip = nearClip
        self.farClip = farClip
        self.aspectRatio = aspectRatio
        self.localTransform = localTransform
    }
}

public struct RuntimeTextureReference: Sendable, Equatable {
    public var name: String?
    public var sourceURL: URL?
    public var isSRGB: Bool
    public var flags: UInt32
    public var width: Int?
    public var height: Int?
    public var mipCount: Int?
    /// GPU format of the source asset. Native `.utex` formats are loaded via
    /// NativeTextureLoader instead of MTKTextureLoader.
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

/// Scene-wide color-management bake resolved from an asset's
/// `UntoldColorManagementRecordV1`. At most one per `RuntimeAsset` — applied
/// by the scene-authored payload loader, not by individual mesh loads.
public struct RuntimeColorManagement: Sendable, Equatable {
    public var lutTexture: RuntimeTextureReference?
    public var exposure: Float
    public var gamma: Float
    public var shaperMinStops: Float
    public var shaperMaxStops: Float
    public var lutSize: Int

    public init(
        lutTexture: RuntimeTextureReference? = nil,
        exposure: Float = 0.0,
        gamma: Float = 1.0,
        shaperMinStops: Float = -10.0,
        shaperMaxStops: Float = 6.0,
        lutSize: Int = 0
    ) {
        self.lutTexture = lutTexture
        self.exposure = exposure
        self.gamma = gamma
        self.shaperMinStops = shaperMinStops
        self.shaperMaxStops = shaperMaxStops
        self.lutSize = lutSize
    }
}

public struct RuntimeMaterialSource: Sendable, Equatable {
    public var name: String?
    public var baseColorFactor: SIMD4<Float>
    public var emissiveFactor: SIMD3<Float>
    public var normalScale: Float
    public var metallicFactor: Float
    public var roughnessFactor: Float
    public var metallicTextureChannel: UntoldTextureChannel
    public var roughnessTextureChannel: UntoldTextureChannel
    public var occlusionStrength: Float
    public var alphaCutoff: Float
    public var flags: UInt32
    public var baseColorTexture: RuntimeTextureReference?
    public var normalTexture: RuntimeTextureReference?
    public var metallicTexture: RuntimeTextureReference?
    public var roughnessTexture: RuntimeTextureReference?
    public var emissiveTexture: RuntimeTextureReference?
    public var occlusionTexture: RuntimeTextureReference?
    public var heightTexture: RuntimeTextureReference?
    public var heightScale: Float
    public var heightMidlevel: Float
    public var heightRemapMin: Float
    public var heightRemapMax: Float

    public init(
        name: String? = nil,
        baseColorFactor: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1),
        emissiveFactor: SIMD3<Float> = SIMD3<Float>(0, 0, 0),
        normalScale: Float = 1.0,
        metallicFactor: Float = 1.0,
        roughnessFactor: Float = 1.0,
        metallicTextureChannel: UntoldTextureChannel = .r,
        roughnessTextureChannel: UntoldTextureChannel = .r,
        occlusionStrength: Float = 1.0,
        alphaCutoff: Float = 0.5,
        flags: UInt32 = 0,
        baseColorTexture: RuntimeTextureReference? = nil,
        normalTexture: RuntimeTextureReference? = nil,
        metallicTexture: RuntimeTextureReference? = nil,
        roughnessTexture: RuntimeTextureReference? = nil,
        emissiveTexture: RuntimeTextureReference? = nil,
        occlusionTexture: RuntimeTextureReference? = nil,
        heightTexture: RuntimeTextureReference? = nil,
        heightScale: Float = 0.05,
        heightMidlevel: Float = 0.5,
        heightRemapMin: Float = 0.0,
        heightRemapMax: Float = 1.0
    ) {
        self.name = name
        self.baseColorFactor = baseColorFactor
        self.emissiveFactor = emissiveFactor
        self.normalScale = normalScale
        self.metallicFactor = metallicFactor
        self.roughnessFactor = roughnessFactor
        self.metallicTextureChannel = metallicTextureChannel
        self.roughnessTextureChannel = roughnessTextureChannel
        self.occlusionStrength = occlusionStrength
        self.alphaCutoff = alphaCutoff
        self.flags = flags
        self.baseColorTexture = baseColorTexture
        self.normalTexture = normalTexture
        self.metallicTexture = metallicTexture
        self.roughnessTexture = roughnessTexture
        self.emissiveTexture = emissiveTexture
        self.occlusionTexture = occlusionTexture
        self.heightTexture = heightTexture
        self.heightScale = heightScale
        self.heightMidlevel = heightMidlevel
        self.heightRemapMin = heightRemapMin
        self.heightRemapMax = heightRemapMax
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
    public var edgeIndexData: Data
    public var indexFormat: RuntimeIndexFormat
    public var vertexCount: Int
    public var indexCount: Int
    public var edgeIndexCount: Int
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
        edgeIndexData: Data = Data(),
        indexFormat: RuntimeIndexFormat,
        vertexCount: Int,
        indexCount: Int,
        edgeIndexCount: Int = 0,
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
        self.edgeIndexData = edgeIndexData
        self.indexFormat = indexFormat
        self.vertexCount = vertexCount
        self.indexCount = indexCount
        self.edgeIndexCount = edgeIndexCount
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
    public var lights: [RuntimeLightSource]
    public var cameras: [RuntimeCameraSource]
    public var colorManagement: RuntimeColorManagement?
    public var animationClips: [RuntimeAnimationClip]
    public var meshGroups: [RuntimeMeshGroup]

    public init(
        sourceURL: URL,
        sourceKind: RuntimeAssetSourceKind,
        assetName: String,
        rootTransform: simd_float4x4 = matrix_identity_float4x4,
        worldBounds: RuntimeAABB,
        nodes: [RuntimeAssetNode] = [],
        lights: [RuntimeLightSource] = [],
        cameras: [RuntimeCameraSource] = [],
        colorManagement: RuntimeColorManagement? = nil,
        animationClips: [RuntimeAnimationClip] = [],
        meshGroups: [RuntimeMeshGroup]
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
        self.lights = lights
        self.cameras = cameras
        self.colorManagement = colorManagement
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
        lights: [RuntimeLightSource] = [],
        cameras: [RuntimeCameraSource] = [],
        colorManagement: RuntimeColorManagement? = nil,
        animationClips: [RuntimeAnimationClip] = []
    ) {
        self.sourceURL = sourceURL
        self.sourceKind = sourceKind
        self.assetName = assetName
        self.rootTransform = rootTransform
        self.worldBounds = worldBounds
        self.nodes = nodes
        self.lights = lights
        self.cameras = cameras
        self.colorManagement = colorManagement
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
