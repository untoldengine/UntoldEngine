//
//  TemporalAntiAliasing.swift
//  UntoldEngine
//
//  Temporal anti-aliasing: the projection is jittered by a sub-pixel amount each frame, and
//  the resolve pass after the look pass blends the frame with the eye's reprojected, clipped
//  history (TAAShader.metal). Sub-pixel detail a single sample flickers on — thin wires, fine
//  normal maps, the periphery of a foveated frame where a pixel spans several screen pixels —
//  averages out over frames. The reprojection follows the camera through the depth buffer;
//  what moves on its own is covered by the neighbourhood clip, not by motion vectors.
//
//  State is per eye (XR renders the two eyes through the same passes): a history texture
//  ping-pong, the unjittered view-projection of the frame the history holds, and that frame's
//  rasterization rate map when it was foveated — the history is laid out in that map's
//  physical space, so the resolve maps through both frames' maps.
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd

/// Tunables of the temporal resolve.
public final class TAAParams: @unchecked Sendable {
    public static let shared = TAAParams()
    private let lock = NSLock()
    private var historyWeightValue: Float = 0.9
    private var clipGammaValue: Float = 1.25

    /// The share of the (clipped) history in each resolved pixel: higher converges further
    /// and reacts slower. Clamped to [0, 0.98]; the default is 0.9.
    public var historyWeight: Float {
        get { lock.withLock { historyWeightValue } }
        set { lock.withLock { historyWeightValue = min(max(newValue, 0), 0.98) } }
    }

    /// How far the history may stray from a pixel's 3×3 neighbourhood: the clip box is the
    /// neighbourhood's mean ± this many standard deviations. Lower rejects ghosting sooner,
    /// higher keeps pixel-thin features (wires, text) through the frames that miss them.
    /// Clamped to [0.5, 3]; the default is 1.25.
    public var clipGamma: Float {
        get { lock.withLock { clipGammaValue } }
        set { lock.withLock { clipGammaValue = min(max(newValue, 0.5), 3) } }
    }
}

/// Sub-pixel offsets, in pixels, of the Halton (2, 3) sequence centred on the pixel: eight
/// of them, so the average over a short window sits at the pixel centre.
let taaJitterSequence: [simd_float2] = (1 ... 8).map { index in
    func halton(_ index: Int, _ base: Int) -> Float {
        var result: Float = 0
        var fraction: Float = 1
        var i = index
        while i > 0 {
            fraction /= Float(base)
            result += fraction * Float(i % base)
            i /= base
        }
        return result
    }
    return simd_float2(halton(index, 2) - 0.5, halton(index, 3) - 0.5)
}

/// Whether a mode runs the temporal resolve.
extension AntiAliasingMode {
    var isTemporal: Bool {
        switch self {
        case .taa, .msaaTaa:
            return true
        case .none, .fxaa, .smaa, .msaa:
            return false
        }
    }
}

final class TemporalAntiAliasing: @unchecked Sendable {
    static let shared = TemporalAntiAliasing()

    /// What one eye carries from frame to frame.
    struct EyeHistory {
        var textures: [MTLTexture] = []
        var readIndex = 0
        var viewProjection = matrix_identity_float4x4
        var rateMapData: XRRasterizationRateMapData?
        var valid = false
    }

    private(set) var eyes: [EyeHistory] = [EyeHistory(), EyeHistory()]
    private var jitterIndex = 0
    /// The jitter currently added to `renderInfo.perspectiveSpace`, in NDC, so it can be
    /// taken out before the next one goes in (the macOS projection persists across frames).
    private(set) var appliedJitter = simd_float2.zero
    /// The jitter of this frame in pixels of the screen, for diagnostics and tests.
    private(set) var currentJitterPixels = simd_float2.zero

    private var eyeIndex: Int {
        renderInfo.isXRStereoMode ? min(max(renderInfo.currentEye, 0), 1) : 0
    }

    /// The projection was set afresh (a resize, a new eye): nothing of the old jitter is in it.
    func projectionDidChange() {
        appliedJitter = .zero
    }

    /// Before a frame's graph is built: takes last frame's jitter out of the projection and
    /// puts this frame's in — or just takes it out when the mode is not temporal. The offset
    /// lives in the projection's third column: for a perspective projection, whose clip w is
    /// the view-space depth, it shifts every point by a constant amount in NDC.
    func applyJitter() {
        var projection = renderInfo.perspectiveSpace
        projection.columns.2.x -= appliedJitter.x
        projection.columns.2.y -= appliedJitter.y
        appliedJitter = .zero
        currentJitterPixels = .zero

        if antiAliasingMode.isTemporal, let screen = screenSize(), screen.x > 0, screen.y > 0 {
            let pixels = taaJitterSequence[jitterIndex % taaJitterSequence.count]
            jitterIndex += 1
            let ndc = simd_float2(2 * pixels.x / screen.x, 2 * pixels.y / screen.y)
            projection.columns.2.x += ndc.x
            projection.columns.2.y += ndc.y
            appliedJitter = ndc
            currentJitterPixels = pixels
        }
        renderInfo.perspectiveSpace = projection
    }

    /// The size of the screen the projection maps to: the rate map's under foveation, the
    /// textures' otherwise.
    private func screenSize() -> simd_float2? {
        if let foveation = renderInfo.xrFoveation {
            return foveation.screenSize
        }
        return renderInfo.viewPort
    }

    /// This frame's projection without its jitter.
    var unjitteredProjection: simd_float4x4 {
        var projection = renderInfo.perspectiveSpace
        projection.columns.2.x -= appliedJitter.x
        projection.columns.2.y -= appliedJitter.y
        return projection
    }

    /// Forgets every eye's history: the next resolve of each eye outputs its frame as is.
    func invalidateHistory() {
        for index in eyes.indices {
            eyes[index].valid = false
        }
    }

    /// The eye's history textures at the current viewport, made or remade when needed (a
    /// remake invalidates the history).
    private func historyTextures(for eye: Int) -> [MTLTexture]? {
        let width = max(1, Int(renderInfo.viewPort.x))
        let height = max(1, Int(renderInfo.viewPort.y))
        if eyes[eye].textures.count == 2, eyes[eye].textures[0].width == width, eyes[eye].textures[0].height == height {
            return eyes[eye].textures
        }
        guard let device = renderInfo.device else { return nil }
        var textures: [MTLTexture] = []
        for slot in 0 ..< 2 {
            guard let texture = createTexture(
                device: device,
                label: "TAA History Eye \(eye) \(slot)",
                pixelFormat: renderInfo.colorPipeline.working.lookOutput,
                width: width,
                height: height,
                usage: [.shaderRead, .renderTarget],
                storageMode: .private
            ) else { return nil }
            textures.append(texture)
        }
        eyes[eye].textures = textures
        eyes[eye].readIndex = 0
        eyes[eye].valid = false
        return textures
    }

    /// The resolve: the look output and the eye's history into the anti-aliasing texture and
    /// the eye's other history texture, then the frame's matrices and map become the history's.
    func encodeResolve(_ commandBuffer: MTLCommandBuffer) {
        guard let source = textureResources.lookTexture,
              let destination = textureResources.antiAliasingTexture,
              let depth = textureResources.depthMap,
              let pipeline = PipelineManager.shared.renderPipelinesByType[.taa],
              pipeline.success,
              let pipelineState = pipeline.pipelineState,
              let camera = CameraSystem.shared.activeCamera,
              let cameraComponent = scene.get(component: CameraComponent.self, for: camera)
        else {
            handleError(.renderPassCreationFailed, "TAA Pass: missing texture, pipeline or camera")
            return
        }
        let eye = eyeIndex
        guard let textures = historyTextures(for: eye) else {
            handleError(.renderPassCreationFailed, "TAA Pass: history textures")
            return
        }
        let readTexture = textures[eyes[eye].readIndex]
        let writeTexture = textures[1 - eyes[eye].readIndex]

        let view = SceneRootTransform.shared.effectiveViewMatrix(cameraComponent.viewSpace)
        let viewProjection = simd_mul(unjitteredProjection, view)
        let currentRateMap = renderInfo.xrFoveation?.rateMapData
        var constants = TAAConstants()
        constants.invViewProjection = simd_inverse(viewProjection)
        constants.prevViewProjection = eyes[eye].viewProjection
        constants.rateMapSizes = rateMapSizes(currentRateMap)
        constants.prevRateMapSizes = rateMapSizes(eyes[eye].rateMapData)
        constants.physicalSize = simd_float2(Float(source.width), Float(source.height))
        constants.historyWeight = TAAParams.shared.historyWeight
        constants.clipGamma = TAAParams.shared.clipGamma
        constants.historyValid = eyes[eye].valid ? 1 : 0
        constants.reverseZ = renderInfo.reverseZEnabled ? 1 : 0

        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = destination
        descriptor.colorAttachments[0].loadAction = .dontCare
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[1].texture = writeTexture
        descriptor.colorAttachments[1].loadAction = .dontCare
        descriptor.colorAttachments[1].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            handleError(.renderPassCreationFailed, "TAA Pass")
            return
        }
        encoder.label = "TAA Pass"
        encoder.pushDebugGroup("TAA Pass")
        encoder.setRenderPipelineState(pipelineState)
        encoder.waitForFence(renderInfo.fence, before: .fragment)
        encoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(source, index: Int(taaPassColorTextureIndex.rawValue))
        encoder.setFragmentTexture(readTexture, index: Int(taaPassHistoryTextureIndex.rawValue))
        encoder.setFragmentTexture(depth, index: Int(taaPassDepthTextureIndex.rawValue))
        encoder.setFragmentBytes(&constants, length: MemoryLayout<TAAConstants>.stride, index: Int(taaPassConstantsIndex.rawValue))
        // The maps' sizes are in the constants; the shader reads a map's parameters only when
        // its sizes say there is one, so a placeholder stands in for a uniform frame.
        let placeholder = rateMapPlaceholderBuffer()
        encoder.setFragmentBuffer(currentRateMap?.buffer ?? placeholder, offset: 0, index: Int(taaPassRateMapDataIndex.rawValue))
        encoder.setFragmentBuffer(eyes[eye].rateMapData?.buffer ?? placeholder, offset: 0, index: Int(taaPassPrevRateMapDataIndex.rawValue))
        encoder.drawIndexedPrimitivesTracked(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )
        encoder.updateFence(renderInfo.fence, after: .fragment)
        encoder.popDebugGroup()
        encoder.endEncoding()

        eyes[eye].readIndex = 1 - eyes[eye].readIndex
        eyes[eye].viewProjection = viewProjection
        eyes[eye].rateMapData = currentRateMap
        eyes[eye].valid = true
    }
}

/// The graph's temporal resolve pass, in the slot FXAA or SMAA otherwise take.
let taaRenderPass: RenderPasses.RenderPassExecution = { commandBuffer in
    TemporalAntiAliasing.shared.encodeResolve(commandBuffer)
}
