
//
//  RenderResources.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import MetalKit
import ModelIO
import simd

public struct RenderInfo {
    public var perspectiveSpace = simd_float4x4.init(1.0)
    public var currentEye: Int = 0
    public var currentInFlightFrameSlot: Int = 0
    public var device: MTLDevice!
    public var fence: MTLFence!
    public var library: MTLLibrary!
    public var commandQueue: MTLCommandQueue!
    public var lastCommandBuffer: MTLCommandBuffer!
    public var bufferAllocator: MTKMeshBufferAllocator!
    public var textureLoader: MTKTextureLoader!
    public var renderPassDescriptor: MTLRenderPassDescriptor!
    public var environmentRenderPassDescriptor: MTLRenderPassDescriptor!
    public var offscreenRenderPassDescriptor: MTLRenderPassDescriptor!
    public var gaussianRenderPassDescriptor: MTLRenderPassDescriptor!
    public var postProcessRenderPassDescriptor: MTLRenderPassDescriptor!
    // CSM: one render pass descriptor per cascade (3 total), each targeting a separate array slice.
    public var csmRenderPassDescriptors: [MTLRenderPassDescriptor] = []
    public var gizmoRenderPassDescriptor: MTLRenderPassDescriptor!
    public var deferredRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoBlurRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoLowResRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoBlurHorizontalRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoBlurVerticalRenderPassDescriptor: MTLRenderPassDescriptor!
    public var ssaoUpsampleRenderPassDescriptor: MTLRenderPassDescriptor!
    public var iblOffscreenRenderPassDescriptor: MTLRenderPassDescriptor!
    public var colorPixelFormat: MTLPixelFormat!
    public var depthPixelFormat: MTLPixelFormat!
    public var viewPort: simd_float2!
    public var immersionStyle: UntoldImmersionMode = .none
    public var reverseZEnabled: Bool = false
    public var sceneCompositeRenderPassDescriptor: MTLRenderPassDescriptor!
    public var presentColorPixelFormat: MTLPixelFormat = .bgra8Unorm_srgb
    public var presentDepthPixelFormat: MTLPixelFormat = .depth32Float
    public var colorPipeline: ColorPipelineConfig = .standard(presentFormat: .bgra8Unorm_srgb)
    public var hzbMipCount: Int = 0
    public var hzbIsValid: Bool = false
    public var hzbDebugMipLevel: Int = 0

    // XR stereo-aware HZB culling
    // When true, depth and HZB pyramids are maintained per eye and occlusion
    // culling runs independently for each eye, with results unioned.
    public var isXRStereoMode: Bool = false
    public var xrEye0ViewProjection: simd_float4x4 = matrix_identity_float4x4
    public var xrEye1ViewProjection: simd_float4x4 = matrix_identity_float4x4

    // TAA / MetalFX Temporal Scaler
    // unjitteredPerspectiveSpace is the clean projection matrix used by culling, shadow cascades,
    // and velocity computation. perspectiveSpace carries the per-frame Halton jitter for rasterisation.
    public var unjitteredPerspectiveSpace: simd_float4x4 = matrix_identity_float4x4
    public var taaJitterX: Float = 0 // current frame jitter offset in pixels (X)
    public var taaJitterY: Float = 0 // current frame jitter offset in pixels (Y)

    // Per-eye unjittered view-projection matrices for camera-only velocity computation.
    // Index 0 = left / mono,  index 1 = right (XR stereo).
    public var prevViewProjectionEye: [simd_float4x4] = [matrix_identity_float4x4, matrix_identity_float4x4]
    public var currentViewProjectionEye: [simd_float4x4] = [matrix_identity_float4x4, matrix_identity_float4x4]

    /// Velocity pass render pass descriptor (writes rg16Float motion vectors)
    public var velocityRenderPassDescriptor: MTLRenderPassDescriptor!
}

@inline(__always)
public func sceneDepthClearValue() -> Double {
    renderInfo.reverseZEnabled ? 0.0 : 1.0
}

@inline(__always)
public func sceneDepthCompareFunction(_ original: MTLCompareFunction, reverseZCompatible: Bool = true) -> MTLCompareFunction {
    guard reverseZCompatible, renderInfo.reverseZEnabled else {
        return original
    }

    switch original {
    case .less:
        return .greater
    case .lessEqual:
        return .greaterEqual
    case .greater:
        return .less
    case .greaterEqual:
        return .lessEqual
    default:
        return original
    }
}

public struct BufferResources {
    /// Point Lights
    var pointLightBuffer: MTLBuffer?

    /// Spot lights
    var spotLightBuffer: MTLBuffer?

    /// Area light
    var areaLightBuffer: MTLBuffer?

    var gridUniforms: MTLBuffer?
    var gridVertexBuffer: MTLBuffer?

    var voxelUniforms: MTLBuffer?

    // composite quad
    public var quadVerticesBuffer: MTLBuffer?
    public var quadTexCoordsBuffer: MTLBuffer?
    public var quadIndexBuffer: MTLBuffer?

    /// bounding box
    public var boundingBoxBuffer: MTLBuffer?

    // ray tracing uniform
    public var rayTracingUniform: MTLBuffer?
    public var accumulationBuffer: MTLBuffer?

    // ray model
    public var rayModelInstanceBuffer: MTLBuffer?
    public var rayModelPickOutputBuffer: MTLBuffer?

    /// ssao kernel
    var ssaoKernelBuffer: MTLBuffer?

    // Frustum Culling reduce-scan
    var reduceScanFlags: MTLBuffer?
    var reduceScanIndices: MTLBuffer?
    var reduceScanBlockSums: MTLBuffer?
    var reduceScanBlockOffsets: MTLBuffer?
}

public struct TripleBufferResources {
    var frustumPlane: TripleBuffer<simd_float4>?
    var entityAABB: TripleBuffer<EntityAABB>?
    var visibleCount: TripleBuffer<UInt32>?
    var visibility: TripleBuffer<VisibleEntity>?
    var hzbCandidateVisibleCount: TripleBuffer<UInt32>?
    var hzbCandidateVisibility: TripleBuffer<VisibleEntity>?

    // Per-eye HZB occlusion output buffers (XR stereo only).
    var hzbEye0VisibleCount: TripleBuffer<UInt32>?
    var hzbEye0Visibility: TripleBuffer<VisibleEntity>?
    var hzbEye1VisibleCount: TripleBuffer<UInt32>?
    var hzbEye1Visibility: TripleBuffer<VisibleEntity>?
}

public struct VertexDescriptors {
    public var model: MDLVertexDescriptor!
    public var gizmo: MDLVertexDescriptor!
}

public struct TextureResources {
    // CSM depth texture array — 3 slices, one per cascade.
    public var csmShadowMap: MTLTexture?
    public var colorMap: MTLTexture?
    public var normalMap: MTLTexture?
    public var positionMap: MTLTexture?
    public var materialMap: MTLTexture?
    public var emissiveMap: MTLTexture?
    public var depthMap: MTLTexture?
    public var hzbSourceDepthMap: MTLTexture?
    public var environmentColorMap: MTLTexture?

    // deferred
    public var deferredColorMap: MTLTexture?
    public var deferredDepthMap: MTLTexture?

    // ibl
    public var environmentTexture: MTLTexture?
    public var irradianceMap: MTLTexture?
    public var specularMap: MTLTexture?
    public var iblBRDFMap: MTLTexture?

    // raytracing dest texture
    public var rayTracingDestTexture: MTLTexture?
    public var rayTracingPreviousTexture: MTLTexture?
    public var rayTracingRandomTexture: MTLTexture?
    public var rayTracingDestTextureArray: MTLTexture?
    public var rayTracingAccumTexture: [MTLTexture] = []

    // debugger textures

    public var tonemapTexture: MTLTexture?
    public var blurDebugTextures: MTLTexture?
    public var colorCorrectionTexture: MTLTexture?
    public var blurTextureHor: MTLTexture?
    public var blurTextureVer: MTLTexture?
    public var bloomThresholdTextuture: MTLTexture?
    public var bloomCompositeTexture: MTLTexture?
    public var vignetteTexture: MTLTexture?
    public var chromaticAberrationTexture: MTLTexture?
    public var depthOfFieldTexture: MTLTexture?
    public var ssaoTexture: MTLTexture?
    public var ssaoDepthMap: MTLTexture?
    public var ssaoBlurTexture: MTLTexture?
    public var ssaoBlurDepthTexture: MTLTexture?

    // Low-resolution SSAO textures for performance
    public var ssaoTextureLowRes: MTLTexture?
    public var ssaoBlurTextureLowRes: MTLTexture?
    public var ssaoBlurHorizontal: MTLTexture? // Intermediate for separable blur

    // Area texture ltc_1
    public var areaTextureLTCMag: MTLTexture?
    public var areaTextureLTCMat: MTLTexture?

    // Gizmo
    public var gizmoColorTexture: MTLTexture?
    public var gizmoDepthTexture: MTLTexture?

    /// SSAO
    public var ssaoNoiseTexture: MTLTexture?

    /// Gaussian
    public var gaussianColorMap: MTLTexture?

    public var sceneCompositeTexture: MTLTexture?
    public var lookTexture: MTLTexture?
    public var fxaaTexture: MTLTexture?

    // Hi-Z / HZB (single pyramid — macOS / non-stereo path)
    public var hzbDepthPyramid: MTLTexture?
    public var hzbMipViews: [MTLTexture] = []
    public var hzbDebugMipTexture: MTLTexture?

    // Per-eye depth maps and HZB pyramids for XR stereo culling.
    // Index 0 = left / eye 0, index 1 = right / eye 1.
    public var depthMapEye: [MTLTexture?] = [nil, nil]
    public var hzbDepthPyramidEye: [MTLTexture?] = [nil, nil]
    public var hzbMipViewsEye: [[MTLTexture]] = [[], []]

    // TAA / MetalFX Temporal Scaler textures.
    // velocityTexture: rg16Float screen-space motion vectors (camera-only, re-computed each frame).
    // taaOutputTexture: resolved TAA output for mono / desktop.
    // taaOutputTextureEye[]: per-eye resolved TAA output for XR stereo.
    public var velocityTexture: MTLTexture?
    public var taaOutputTexture: MTLTexture?
    public var taaOutputTextureEye: [MTLTexture?] = [nil, nil]
    // History textures: the previous frame's resolved TAA output, read by the resolve shader.
    public var taaHistoryTexture: MTLTexture?
    public var taaHistoryTextureEye: [MTLTexture?] = [nil, nil]
    // Previous frame's world-position G-buffer, used to reject stale history on
    // disocclusions and object motion that camera-only velocity cannot represent.
    public var taaPositionHistoryTexture: MTLTexture?
    public var taaPositionHistoryTextureEye: [MTLTexture?] = [nil, nil]
}

public struct AccelStructResources {
    public var primitiveAccelerationStructures: [MTLAccelerationStructure] = []
    public var instanceTransforms: [MTLPackedFloat4x3] = []
    public var accelerationStructIndex: [UInt32] = []
    public var entityIDIndex: [EntityID] = []
    public var instanceAccelerationStructure: MTLAccelerationStructure?
    public var instanceBuffer: MTLBuffer?
    public var mask: [Int32] = []

    public init() {}
}
