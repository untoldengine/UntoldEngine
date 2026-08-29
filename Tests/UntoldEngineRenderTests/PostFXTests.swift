//
//  PostFXTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class PostFXTests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        disableAllPostFX()
    }

    override func tearDown() async throws {
        disableAllPostFX()
        try await super.tearDown()
    }

    private func disableAllPostFX() {
        bypassPostProcessing = false
        SSAO.setEnabled(false)
        PostFX.enableColorGrading(false)
        PostFX.enableColorCorrection(false)
        PostFX.enableBloomThreshold(false)
        PostFX.enableBloomComposite(false)
        PostFX.enableVignette(false)
        PostFX.enableChromaticAberration(false)
        PostFX.enableDepthOfField(false)
        antiAliasingMode = .none
    }

    // MARK: - Parameter helpers

    // Each helper sets the same values used in both reference generation and PSNR tests,
    // ensuring the reference and test renders are produced under identical conditions.

    private func configureSSAO() {
        SSAOParams.shared.radius = 0.2
        SSAOParams.shared.intensity = 0.5
        SSAOParams.shared.bias = 0.05
    }

    private func configureDepthOfField() {
        DepthOfFieldParams.shared.focusDistance = 4.7
        DepthOfFieldParams.shared.focusRange = 1.5
        DepthOfFieldParams.shared.maxBlur = 10.0
    }

    private func configureChromaticAberration() {
        ChromaticAberrationParams.shared.intensity = 0.02
    }

    private func configureBloom() {
        BloomThresholdParams.shared.threshold = 0.1
        BloomThresholdParams.shared.intensity = 3.5
        BloomCompositeParams.shared.intensity = 1.0
    }

    private func configureVignette() {
        VignetteParams.shared.intensity = 0.8
        VignetteParams.shared.radius = 0.6
        VignetteParams.shared.softness = 0.4
    }

    private func configureColorGrading() {
        ColorGradingParams.shared.saturation = 2.0
        ColorGradingParams.shared.contrast = 1.5
        ColorGradingParams.shared.exposure = 0.5
    }

    // MARK: - Reference Image Generation

    /* Uncomment to regenerate reference images */
   /*
     func testGeneratePostFXReferenceImages() {
         XCTAssertNotNil(renderer, "Renderer should be initialized")
         XCTAssertNotNil(renderer.metalView, "MetalView should be initialized")

         // --- SSAO ---
         configureSSAO()
         SSAO.setEnabled(true)
         renderer.draw(in: renderer.metalView)
         let expSSAO = expectation(description: "SSAO ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.ssaoBlurTexture {
                 self.testGenerateRenderTarget(targetName: "SSAO", texture: tex)
             }
             expSSAO.fulfill()
         }
         wait(for: [expSSAO], timeout: TimeInterval(timeoutFactor))
         SSAO.setEnabled(false)

         // --- Depth of Field ---
         configureDepthOfField()
         PostFX.enableDepthOfField(true)
         renderer.draw(in: renderer.metalView)
         let expDoF = expectation(description: "DepthOfField ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.depthOfFieldTexture {
                 self.testGenerateRenderTarget(targetName: "DepthOfField", texture: tex)
             }
             expDoF.fulfill()
         }
         wait(for: [expDoF], timeout: TimeInterval(timeoutFactor))
         PostFX.enableDepthOfField(false)

         // --- Chromatic Aberration ---
         configureChromaticAberration()
         PostFX.enableChromaticAberration(true)
         renderer.draw(in: renderer.metalView)
         let expChroma = expectation(description: "ChromaticAberration ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.chromaticAberrationTexture {
                 self.testGenerateRenderTarget(targetName: "ChromaticAberration", texture: tex)
             }
             expChroma.fulfill()
         }
         wait(for: [expChroma], timeout: TimeInterval(timeoutFactor))
         PostFX.enableChromaticAberration(false)

         // --- Bloom ---
         configureBloom()
         PostFX.enableBloomThreshold(true)
         PostFX.enableBloomComposite(true)
         renderer.draw(in: renderer.metalView)
         let expBloom = expectation(description: "Bloom ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.bloomCompositeTexture {
                 self.testGenerateRenderTarget(targetName: "Bloom", texture: tex)
             }
             expBloom.fulfill()
         }
         wait(for: [expBloom], timeout: TimeInterval(timeoutFactor))
         PostFX.enableBloomThreshold(false)
         PostFX.enableBloomComposite(false)

         // --- Vignette ---
         configureVignette()
         PostFX.enableVignette(true)
         renderer.draw(in: renderer.metalView)
         let expVignette = expectation(description: "Vignette ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.vignetteTexture {
                 self.testGenerateRenderTarget(targetName: "Vignette", texture: tex)
             }
             expVignette.fulfill()
         }
         wait(for: [expVignette], timeout: TimeInterval(timeoutFactor))
         PostFX.enableVignette(false)

         // --- Color Grading ---
         configureColorGrading()
         PostFX.enableColorGrading(true)
         renderer.draw(in: renderer.metalView)
         let expColorGrading = expectation(description: "ColorGrading ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.lookTexture {
                 self.testGenerateRenderTarget(targetName: "ColorGrading", texture: tex)
             }
             expColorGrading.fulfill()
         }
         wait(for: [expColorGrading], timeout: TimeInterval(timeoutFactor))
         PostFX.enableColorGrading(false)

         // --- FXAA ---
         antiAliasingMode = .fxaa
         renderer.draw(in: renderer.metalView)
         let expFXAA = expectation(description: "FXAA ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.antiAliasingTexture {
                 self.testGenerateRenderTarget(targetName: "FXAA", texture: tex)
             }
             expFXAA.fulfill()
         }
         wait(for: [expFXAA], timeout: TimeInterval(timeoutFactor))

         antiAliasingMode = .none

         // --- SMAA ---
         antiAliasingMode = .smaa
         renderer.draw(in: renderer.metalView)
         let expSMAA = expectation(description: "SMAA ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.antiAliasingTexture {
                 self.testGenerateRenderTarget(targetName: "SMAA", texture: tex)
             }
             expSMAA.fulfill()
         }
         wait(for: [expSMAA], timeout: TimeInterval(timeoutFactor))
         antiAliasingMode = .none

         // --- MSAA ---
         // Unlike FXAA/SMAA, MSAA is not a discrete post-process pass — the render graph
         // routes .msaa straight from lookPass to the output stage (see the antiAliasingMode
         // switch in RenderingSystem.swift), so lookTexture (not antiAliasingTexture) is what
         // reflects MSAA's effect.
         antiAliasingMode = .msaa
         renderer.draw(in: renderer.metalView)
         let expMSAA = expectation(description: "MSAA ref")
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             if let tex = textureResources.lookTexture {
                 self.testGenerateRenderTarget(targetName: "MSAA", texture: tex)
             }
             expMSAA.fulfill()
         }
         wait(for: [expMSAA], timeout: TimeInterval(timeoutFactor))
         antiAliasingMode = .none
     }
     */
    // MARK: - PSNR Tests

    func testSSAO() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureSSAO()
        SSAO.setEnabled(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.ssaoBlurTexture else {
            XCTFail("ssaoBlurTexture should exist after enabling SSAO")
            return
        }
        psnrTest(targetName: "SSAO", texture: tex)
    }

    func testDepthOfField() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureDepthOfField()
        PostFX.enableDepthOfField(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.depthOfFieldTexture else {
            XCTFail("depthOfFieldTexture should exist after enabling Depth of Field")
            return
        }
        psnrTest(targetName: "DepthOfField", texture: tex)
    }

    func testChromaticAberration() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureChromaticAberration()
        PostFX.enableChromaticAberration(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.chromaticAberrationTexture else {
            XCTFail("chromaticAberrationTexture should exist after enabling Chromatic Aberration")
            return
        }
        psnrTest(targetName: "ChromaticAberration", texture: tex)
    }

    func testBloom() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureBloom()
        PostFX.enableBloomThreshold(true)
        PostFX.enableBloomComposite(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.bloomCompositeTexture else {
            XCTFail("bloomCompositeTexture should exist after enabling Bloom")
            return
        }
        psnrTest(targetName: "Bloom", texture: tex)
    }

    func testVignette() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureVignette()
        PostFX.enableVignette(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.vignetteTexture else {
            XCTFail("vignetteTexture should exist after enabling Vignette")
            return
        }
        psnrTest(targetName: "Vignette", texture: tex)
    }

    func testColorGrading() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureColorGrading()
        PostFX.enableColorGrading(true)
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.lookTexture else {
            XCTFail("lookTexture should exist after enabling Color Grading")
            return
        }
        psnrTest(targetName: "ColorGrading", texture: tex)
    }

    func testFXAA() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        antiAliasingMode = .fxaa
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.antiAliasingTexture else {
            XCTFail("antiAliasingTexture should exist after setting antiAliasingMode = .fxaa")
            return
        }
        psnrTest(targetName: "FXAA", texture: tex)
    }

    func testSMAA() throws {
        // Skip until SMAAReference.png is generated and committed to the test bundle.
        // To generate: uncomment testGeneratePostFXReferenceImages, run it once, then
        // add the saved SMAAReference.png to Tests/UntoldEngineRenderTests/Resources/.
        guard Bundle.module.url(forResource: "SMAAReference", withExtension: "png") != nil else {
            throw XCTSkip("SMAAReference.png not in test bundle — run testGeneratePostFXReferenceImages to create it")
        }

        XCTAssertNotNil(renderer, "Renderer should be initialized")
        antiAliasingMode = .smaa
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        guard let tex = textureResources.antiAliasingTexture else {
            XCTFail("antiAliasingTexture should exist after setting antiAliasingMode = .smaa")
            return
        }
        psnrTest(targetName: "SMAA", texture: tex)
    }

    func testMSAA() throws {
        // Skip until MSAAReference.png is generated and committed to the test bundle.
        // To generate: uncomment testGeneratePostFXReferenceImages, run it once, then
        // add the saved MSAAReference.png to Tests/UntoldEngineRenderTests/Resources/.
        guard Bundle.module.url(forResource: "MSAAReference", withExtension: "png") != nil else {
            throw XCTSkip("MSAAReference.png not in test bundle — run testGeneratePostFXReferenceImages to create it")
        }

        XCTAssertNotNil(renderer, "Renderer should be initialized")
        antiAliasingMode = .msaa
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        // MSAA has no discrete post-process pass of its own — it resolves as part of the
        // opaque pass, and the render graph routes .msaa straight from lookPass to the
        // output stage. So lookTexture (not antiAliasingTexture) is what reflects it.
        guard let tex = textureResources.lookTexture else {
            XCTFail("lookTexture should exist after setting antiAliasingMode = .msaa")
            return
        }
        psnrTest(targetName: "MSAA", texture: tex)
    }

    // MARK: - G-Buffer Debug View Mode Smoke Tests

    //
    // These verify the G-Buffer visualization paths (albedo, normal, position, depth, ssaoBlurred)
    // execute without error and produce a non-nil look texture. They do not use PSNR
    // reference images — correctness of the visual output is verified by inspection when
    // reference images are regenerated.

    func testDebugViewMode_Albedo_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        renderDebugViewMode = .albedo
        defer { renderDebugViewMode = .lit }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after rendering in .albedo debug mode")
    }

    func testDebugViewMode_Normal_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        renderDebugViewMode = .normal
        defer { renderDebugViewMode = .lit }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after rendering in .normal debug mode")
    }

    func testDebugViewMode_Position_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        renderDebugViewMode = .position
        defer { renderDebugViewMode = .lit }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after rendering in .position debug mode")
    }

    func testDebugViewMode_Depth_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        renderDebugViewMode = .depth
        defer { renderDebugViewMode = .lit }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after rendering in .depth debug mode")
    }

    func testDebugViewMode_SSAOBlurred_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        SSAO.setEnabled(true)
        renderDebugViewMode = .ssaoBlurred
        defer {
            renderDebugViewMode = .lit
            SSAO.setEnabled(false)
        }
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after rendering in .ssaoBlurred debug mode")
    }

    func testDebugViewMode_SSAOBlurredAfterAlbedoAndNormal_ProducesLookTexture() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        SSAO.setEnabled(true)
        defer {
            renderDebugViewMode = .lit
            SSAO.setEnabled(false)
        }

        guard let initialSSAOBlurTexture = textureResources.ssaoBlurTexture else {
            XCTFail("Expected SSAO blur texture to exist before debug mode switching")
            return
        }

        renderDebugViewMode = .albedo
        renderer.draw(in: renderer.metalView)

        renderDebugViewMode = .normal
        renderer.draw(in: renderer.metalView)

        renderDebugViewMode = .ssaoBlurred
        renderer.draw(in: renderer.metalView)
        renderInfo.lastCommandBuffer?.waitUntilCompleted()

        XCTAssertNotNil(textureResources.lookTexture,
                        "lookTexture must be non-nil after albedo -> normal -> ssaoBlurred debug sequence")
        XCTAssertTrue(textureResources.ssaoBlurTexture === initialSSAOBlurTexture,
                      "G-buffer debug mode switching must not replace the SSAO blur texture")
    }
}
