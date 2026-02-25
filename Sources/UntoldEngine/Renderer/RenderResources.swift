
//
//  RenderResources.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import Foundation
import MetalKit
import ModelIO
import simd

public struct RenderInfo {
    public var perspectiveSpace = simd_float4x4.init(1.0)
    public var currentEye: Int = 0
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
    public var shadowRenderPassDescriptor: MTLRenderPassDescriptor!
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
    // Point Lights
    var pointLightBuffer: MTLBuffer?

    // Spot lights
    var spotLightBuffer: MTLBuffer?

    // Area light
    var areaLightBuffer: MTLBuffer?

    var gridUniforms: MTLBuffer?
    var gridVertexBuffer: MTLBuffer?

    var voxelUniforms: MTLBuffer?

    // composite quad
    public var quadVerticesBuffer: MTLBuffer?
    public var quadTexCoordsBuffer: MTLBuffer?
    public var quadIndexBuffer: MTLBuffer?

    // bounding box
    public var boundingBoxBuffer: MTLBuffer?

    // ray tracing uniform
    public var rayTracingUniform: MTLBuffer?
    public var accumulationBuffer: MTLBuffer?

    // ray model
    public var rayModelInstanceBuffer: MTLBuffer?

    // ssao kernel
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
}

public struct VertexDescriptors {
    public var model: MDLVertexDescriptor!
    public var gizmo: MDLVertexDescriptor!
}

public struct TextureResources {
    public var shadowMap: MTLTexture?
    public var colorMap: MTLTexture?
    public var normalMap: MTLTexture?
    public var positionMap: MTLTexture?
    public var materialMap: MTLTexture?
    public var emissiveMap: MTLTexture?
    public var depthMap: MTLTexture?
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

    // SSAO
    public var ssaoNoiseTexture: MTLTexture?

    // Gaussian
    public var gaussianColorMap: MTLTexture?

    public var sceneCompositeTexture: MTLTexture?
    public var lookTexture: MTLTexture?

    // Hi-Z / HZB
    public var hzbDepthPyramid: MTLTexture?
    public var hzbMipViews: [MTLTexture] = []
    public var hzbDebugMipTexture: MTLTexture?
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
