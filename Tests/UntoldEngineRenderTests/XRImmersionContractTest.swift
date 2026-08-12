//
//  XRImmersionContractTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Metal
import simd
@testable import UntoldEngine
import XCTest

/// Regression coverage for 5cc6571b1's XR full-immersion alpha/depth contract (see
/// docs/API/UsingXRImmersionMode.md and the project's XR alpha immersion notes): in
/// non-passthrough modes the visionOS compositor treats the output layer as fully opaque,
/// so (1) `fragmentPreCompositeShader` must force alpha to 1.0 whenever `isPassthrough`
/// is false, and (2) `fragmentOutputTransformShader` must never emit a depth of exactly
/// 0.0 (the reverse-Z clear/"infinity" value), since the compositor divides by view
/// distance and 0.0 reprojects those pixels to black.
///
/// Both fragment shaders are ordinary (non-platform-gated) Metal functions reachable on
/// macOS, so this dispatches their existing production `RenderPipeline`s directly with
/// fully controlled input textures/uniforms instead of driving the whole renderer —
/// mirrors CullingTest's `executeHZBOcclusionCulling` pattern.
final class XRImmersionContractTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
    }

    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {
        // No scene needed — both tests dispatch their pipeline directly.
    }

    private func makeColorTexture(pixelFormat: MTLPixelFormat, value: SIMD4<Float>, usage: MTLTextureUsage) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: 1, height: 1, mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = .shared
        let texture = renderInfo.device.makeTexture(descriptor: descriptor)!
        if usage.contains(.shaderRead) {
            let bytes: [Float16] = [Float16(value.x), Float16(value.y), Float16(value.z), Float16(value.w)]
            bytes.withUnsafeBytes { raw in
                texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: raw.baseAddress!, bytesPerRow: 8)
            }
        }
        return texture
    }

    private func makeDepthTexture(pixelFormat: MTLPixelFormat, value: Float, usage: MTLTextureUsage) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: 1, height: 1, mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = .shared
        let texture = renderInfo.device.makeTexture(descriptor: descriptor)!
        if usage.contains(.shaderRead) {
            var v = value
            withUnsafeBytes(of: &v) { raw in
                texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: raw.baseAddress!, bytesPerRow: 4)
            }
        }
        return texture
    }

    // MARK: - fragmentPreCompositeShader: forced-opaque contract

    /// Runs the real `.preComposite` pipeline with every alpha-contributing input
    /// (model, environment, Gaussian) transparent, and reads back the composited alpha.
    private func runPreCompositeAndReadAlpha(isPassthrough: Bool) -> Float {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.preComposite], pipeline.success else {
            XCTFail("Expected the Pre-Composite pipeline to be initialized")
            return -1
        }

        let transparentRGBA = makeColorTexture(pixelFormat: .rgba16Float, value: .zero, usage: [.shaderRead])
        let depthDummy = makeDepthTexture(pixelFormat: .depth32Float, value: 0.5, usage: [.shaderRead])
        let outputTexture = makeColorTexture(pixelFormat: .rgba16Float, value: .zero, usage: [.renderTarget, .shaderRead])

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)

        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            XCTFail("Expected to create a command buffer/encoder")
            return -1
        }

        encoder.setRenderPipelineState(pipeline.pipelineState!)
        encoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(transparentRGBA, index: Int(prePassFinalTextureIndex.rawValue))
        encoder.setFragmentTexture(transparentRGBA, index: Int(prePassEnvTextureIndex.rawValue))
        encoder.setFragmentTexture(depthDummy, index: Int(prePassDepthTextureIndex.rawValue))
        encoder.setFragmentTexture(transparentRGBA, index: Int(prePassGizmoTextureIndex.rawValue))
        encoder.setFragmentTexture(transparentRGBA, index: Int(prePassGaussianTextureIndex.rawValue))
        encoder.setFragmentTexture(transparentRGBA, index: Int(prePassSSAOTextureIndex.rawValue))

        var isGameMode = true // skip the gizmo-overlay branch
        encoder.setFragmentBytes(&isGameMode, length: MemoryLayout<Bool>.stride, index: Int(prePassGizmoBufferIndex.rawValue))
        var passthrough = isPassthrough
        encoder.setFragmentBytes(&passthrough, length: MemoryLayout<Bool>.stride, index: Int(prePassPassthroughBufferIndex.rawValue))
        var ssaoEnabled = false
        encoder.setFragmentBytes(&ssaoEnabled, length: MemoryLayout<Bool>.stride, index: Int(prePassSSAOEnabledIndex.rawValue))

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        var pixel = [Float16](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { raw in
            outputTexture.getBytes(raw.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        }
        return Float(pixel[3])
    }

    /// Sanity check: passthrough mode must NOT force opacity — with every input already
    /// transparent, the composited pixel should stay transparent so the camera feed shows
    /// through.
    func testPreCompositeAlpha_passthroughLeavesTransparentPixelsTransparent() {
        let alpha = runPreCompositeAndReadAlpha(isPassthrough: true)
        XCTAssertEqual(alpha, 0.0, accuracy: 0.01, "Passthrough mode should not force alpha to 1.0")
    }

    /// Regression test for 5cc6571b1: with `isPassthrough == false` (full immersion, AR,
    /// macOS), every fully-transparent input (model, environment, Gaussian all alpha 0)
    /// must still composite to alpha 1.0 — the environment layer is opaque and must never
    /// let a background pixel punch through.
    func testPreCompositeAlpha_nonPassthroughForcesOpaque() {
        let alpha = runPreCompositeAndReadAlpha(isPassthrough: false)
        XCTAssertEqual(
            alpha, 1.0, accuracy: 0.01,
            "❌ Non-passthrough compositing should force alpha to 1.0 even when every upstream " +
                "layer is transparent — got \(alpha). If this regresses, XR full-immersion/AR " +
                "background pixels punch through to black on the compositor."
        )
    }

    // MARK: - fragmentOutputTransformShader: zero-depth clamp

    private func runOutputTransformAndReadDepth(sourceDepth: Float) -> Float {
        guard let pipeline = PipelineManager.shared.renderPipelinesByType[.outputTransform], pipeline.success else {
            XCTFail("Expected the Output Transform pipeline to be initialized")
            return -1
        }

        let lookTexture = makeColorTexture(pixelFormat: .rgba16Float, value: SIMD4(0.2, 0.3, 0.4, 1.0), usage: [.shaderRead])
        let sourceDepthTexture = makeDepthTexture(pixelFormat: .depth32Float, value: sourceDepth, usage: [.shaderRead])
        let outputColorTexture = makeColorTexture(
            pixelFormat: renderInfo.presentColorPixelFormat, value: .zero, usage: [.renderTarget, .shaderRead]
        )
        let outputDepthTexture = makeDepthTexture(
            pixelFormat: renderInfo.presentDepthPixelFormat, value: 0, usage: [.renderTarget, .shaderRead]
        )

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = outputColorTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.depthAttachment.texture = outputDepthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.clearDepth = 0.0
        renderPassDescriptor.depthAttachment.storeAction = .store

        guard let commandBuffer = renderInfo.commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else {
            XCTFail("Expected to create a command buffer/encoder")
            return -1
        }

        encoder.setRenderPipelineState(pipeline.pipelineState!)
        if let depthState = pipeline.depthState {
            encoder.setDepthStencilState(depthState)
        }
        encoder.setVertexBuffer(bufferResources.quadVerticesBuffer, offset: 0, index: 0)
        encoder.setVertexBuffer(bufferResources.quadTexCoordsBuffer, offset: 0, index: 1)
        encoder.setFragmentTexture(lookTexture, index: 0)
        encoder.setFragmentTexture(sourceDepthTexture, index: 1)
        var encodingMode: Int32 = 0
        encoder.setFragmentBytes(&encodingMode, length: MemoryLayout<Int32>.stride, index: Int(outputTransformPassEncodingModeIndex.rawValue))

        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: 6,
            indexType: .uint16,
            indexBuffer: bufferResources.quadIndexBuffer!,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        XCTAssertEqual(commandBuffer.status, .completed)

        var depthValue: Float = -1
        withUnsafeMutableBytes(of: &depthValue) { raw in
            outputDepthTexture.getBytes(raw.baseAddress!, bytesPerRow: 4, from: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0)
        }
        return depthValue
    }

    /// Sanity check: a legitimate (non-zero) depth value must pass through unmodified —
    /// the clamp must not corrupt real depth data.
    func testOutputTransformDepth_nonZeroDepthPassesThroughUnchanged() {
        let depth = runOutputTransformAndReadDepth(sourceDepth: 0.5)
        XCTAssertEqual(depth, 0.5, accuracy: 1e-6)
    }

    /// Regression test for 5cc6571b1: `fragmentOutputTransformShader` used to write the
    /// sampled depth straight through. A sky pixel carrying the reverse-Z clear value of
    /// 0.0 ("infinite distance") would reach the visionOS compositor as exactly 0.0, which
    /// the compositor's view-distance reprojection divides by — discarding those pixels
    /// (rendered black). The fix clamps to a finite far depth (1e-4).
    func testOutputTransformDepth_zeroDepthIsClampedToFiniteValue() {
        let depth = runOutputTransformAndReadDepth(sourceDepth: 0.0)
        XCTAssertGreaterThanOrEqual(
            depth, 1e-4 * 0.999,
            "❌ A depth of exactly 0.0 (reverse-Z 'infinity') should be clamped to a finite far " +
                "value, got \(depth). Left at 0.0, the visionOS compositor's view-distance " +
                "reprojection divides by it and discards these pixels as black."
        )
        XCTAssertLessThan(depth, 0.01, "Clamped depth should still be visually indistinguishable from infinity, not a large jump")
    }
}
