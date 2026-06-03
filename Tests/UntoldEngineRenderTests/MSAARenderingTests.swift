//
//  MSAARenderingTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
@testable import UntoldEngine
import XCTest

final class MSAARenderingTests: BaseRenderSetup {
    private var deviceSupports4xMSAA: Bool {
        renderInfo.device.supportsTextureSampleCount(4)
    }

    private func assertOpaquePipelineSampleCounts(
        _ expectedSampleCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let modelPipeline = try XCTUnwrap(
            PipelineManager.shared.renderPipelinesByType[.model],
            "Model pipeline should exist",
            file: file,
            line: line
        )
        let lightPipeline = try XCTUnwrap(
            PipelineManager.shared.renderPipelinesByType[.light],
            "Light pipeline should exist",
            file: file,
            line: line
        )

        XCTAssertEqual(modelPipeline.rasterSampleCount, expectedSampleCount, "Model pipeline sample count mismatch", file: file, line: line)
        XCTAssertEqual(lightPipeline.rasterSampleCount, expectedSampleCount, "Light pipeline sample count mismatch", file: file, line: line)
    }

    private func assertOpaqueRenderTargetsUseSampleCount(
        _ expectedSampleCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let descriptor = try XCTUnwrap(
            renderInfo.offscreenRenderPassDescriptor,
            "Offscreen render pass descriptor should exist",
            file: file,
            line: line
        )

        for target in [colorTarget, normalTarget, positionTarget, materialTarget, emissiveTarget] {
            let attachment = descriptor.colorAttachments[Int(target.rawValue)]
            let texture = try XCTUnwrap(
                attachment?.texture,
                "G-buffer attachment \(target) should have a texture",
                file: file,
                line: line
            )
            XCTAssertEqual(texture.sampleCount, expectedSampleCount, "G-buffer texture sample count mismatch for \(target)", file: file, line: line)
        }

        let litAttachment = descriptor.colorAttachments[5]
        let litTexture = try XCTUnwrap(litAttachment?.texture, "Lit attachment should have a texture", file: file, line: line)
        let depthTexture = try XCTUnwrap(descriptor.depthAttachment.texture, "Depth attachment should have a texture", file: file, line: line)

        XCTAssertEqual(litTexture.sampleCount, expectedSampleCount, "Lit attachment texture sample count mismatch", file: file, line: line)
        XCTAssertEqual(depthTexture.sampleCount, expectedSampleCount, "Depth attachment texture sample count mismatch", file: file, line: line)
    }

    func testMSAAModeConfiguresMultisampleOpaqueTargetsAndResolve() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        antiAliasingMode = .msaa
        defer { antiAliasingMode = .fxaa }

        updateOpaqueSampleCountForCurrentState()

        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        try assertOpaqueRenderTargetsUseSampleCount(4)
        try assertOpaquePipelineSampleCounts(4)

        let descriptor = try XCTUnwrap(renderInfo.offscreenRenderPassDescriptor)
        for target in [colorTarget, normalTarget, positionTarget, materialTarget, emissiveTarget] {
            let attachment = descriptor.colorAttachments[Int(target.rawValue)]
            XCTAssertEqual(attachment?.storeAction, .dontCare, "MSAA G-buffer targets should remain memoryless")
            XCTAssertEqual(attachment?.texture?.storageMode, .memoryless)
            XCTAssertNil(attachment?.resolveTexture, "G-buffer targets should not resolve to stored textures")
        }

        let litAttachment = descriptor.colorAttachments[5]
        XCTAssertEqual(litAttachment?.storeAction, .multisampleResolve)
        XCTAssertEqual(litAttachment?.texture?.storageMode, .memoryless)
        XCTAssertEqual(litAttachment?.resolveTexture?.sampleCount, 1)
        XCTAssertTrue(litAttachment?.resolveTexture === textureResources.deferredColorMap)
        XCTAssertEqual(
            textureResources.deferredColorMap?.storageMode,
            .shared,
            "Resolved lit color remains CPU-readable for PSNR/readback tests"
        )

        XCTAssertEqual(descriptor.depthAttachment.storeAction, .multisampleResolve)
        XCTAssertEqual(descriptor.depthAttachment.texture?.storageMode, .memoryless)
        XCTAssertEqual(descriptor.depthAttachment.resolveTexture?.sampleCount, 1)
        XCTAssertTrue(descriptor.depthAttachment.resolveTexture === textureResources.depthMap)
    }

    func testRuntimeAntiAliasingSwitchKeepsOpaqueTargetsAndPipelinesAligned() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
            updateOpaqueSampleCountForCurrentState()
        }

        for mode in [AntiAliasingMode.msaa, .fxaa, .msaa, .none] {
            antiAliasingMode = mode
            renderDebugViewMode = .lit
            updateOpaqueSampleCountForCurrentState()

            let expectedSampleCount = mode == .msaa ? 4 : 1
            XCTAssertEqual(renderInfo.opaqueSampleCount, expectedSampleCount, "Unexpected opaque sample count for \(mode)")
            try assertOpaqueRenderTargetsUseSampleCount(expectedSampleCount)
            try assertOpaquePipelineSampleCounts(expectedSampleCount)
        }
    }

    func testRuntimeAntiAliasingSwitchRebindsSSAODescriptorsToCurrentTextures() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        let originalQuality = SSAOParams.shared.quality
        SSAOParams.shared.quality = .balanced
        defer {
            SSAOParams.shared.quality = originalQuality
            antiAliasingMode = .fxaa
            updateOpaqueSampleCountForCurrentState()
        }

        antiAliasingMode = .msaa
        updateOpaqueSampleCountForCurrentState()

        let msaaSSAOBlurTexture = try XCTUnwrap(textureResources.ssaoBlurTexture)
        let msaaUpsampleTarget = try XCTUnwrap(renderInfo.ssaoUpsampleRenderPassDescriptor?.colorAttachments[0].texture)
        XCTAssertTrue(msaaUpsampleTarget === msaaSSAOBlurTexture)

        antiAliasingMode = .fxaa
        updateOpaqueSampleCountForCurrentState()

        let fxaaSSAOBlurTexture = try XCTUnwrap(textureResources.ssaoBlurTexture)
        let fxaaUpsampleTarget = try XCTUnwrap(renderInfo.ssaoUpsampleRenderPassDescriptor?.colorAttachments[0].texture)
        XCTAssertTrue(fxaaUpsampleTarget === fxaaSSAOBlurTexture)
        XCTAssertFalse(fxaaSSAOBlurTexture === msaaSSAOBlurTexture)
    }

    func testGBufferDebugViewForcesSingleSampleWhenMSAASelected() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        antiAliasingMode = .msaa
        renderDebugViewMode = .lit
        updateGBufferStorageForCurrentDebugMode()
        updateOpaqueSampleCountForCurrentState()

        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)

        renderDebugViewMode = .albedo
        updateGBufferStorageForCurrentDebugMode()

        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
            updateGBufferStorageForCurrentDebugMode()
            updateOpaqueSampleCountForCurrentState()
        }

        XCTAssertTrue(renderInfo.gBufferDebugStorageEnabled)
        XCTAssertEqual(renderInfo.opaqueSampleCount, 1)
        try assertOpaqueRenderTargetsUseSampleCount(1)
        try assertOpaquePipelineSampleCounts(1)

        let descriptor = try XCTUnwrap(renderInfo.offscreenRenderPassDescriptor)
        XCTAssertEqual(descriptor.colorAttachments[Int(colorTarget.rawValue)].texture?.storageMode, .private)
        XCTAssertEqual(descriptor.colorAttachments[Int(normalTarget.rawValue)].texture?.storageMode, .private)
        XCTAssertTrue(descriptor.colorAttachments[Int(colorTarget.rawValue)].texture?.usage.contains(.shaderRead) == true)
        XCTAssertTrue(descriptor.colorAttachments[Int(normalTarget.rawValue)].texture?.usage.contains(.shaderRead) == true)
    }

    func testSSAOBlurredDebugViewUsesStoredDepthWhenMSAAIsActive() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        antiAliasingMode = .msaa
        renderDebugViewMode = .ssaoBlurred
        defer {
            antiAliasingMode = .fxaa
            renderDebugViewMode = .lit
            updateOpaqueSampleCountForCurrentState()
        }

        _ = buildGameModeGraph()

        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)
        XCTAssertEqual(textureResources.ssaoBlurTexture?.storageMode, .shared)
        XCTAssertEqual(textureResources.depthMap?.storageMode, .private)
        XCTAssertEqual(textureResources.depthMap?.sampleCount, 1)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.depthAttachment.texture?.storageMode, .memoryless)
        XCTAssertEqual(renderInfo.offscreenRenderPassDescriptor.depthAttachment.resolveTexture?.sampleCount, 1)
        XCTAssertTrue(renderInfo.offscreenRenderPassDescriptor.depthAttachment.resolveTexture === textureResources.depthMap)
    }

    func testBatchedModelExecutionReturnsBeforeOpeningSecondEncoderWhenMSAAIsActive() throws {
        guard deviceSupports4xMSAA else {
            throw XCTSkip("Device does not support 4x MSAA")
        }

        antiAliasingMode = .msaa
        enableBatching(true)
        defer {
            enableBatching(false)
            antiAliasingMode = .fxaa
            updateOpaqueSampleCountForCurrentState()
        }

        updateOpaqueSampleCountForCurrentState()
        XCTAssertEqual(renderInfo.opaqueSampleCount, 4)

        let commandBuffer = try XCTUnwrap(renderInfo.commandQueue.makeCommandBuffer())
        XCTAssertNoThrow(RenderPasses.batchedModelExecution(commandBuffer))
    }
}
