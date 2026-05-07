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
        FXAAParams.shared.enabled = false
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
        FXAAParams.shared.enabled = true
        renderer.draw(in: renderer.metalView)
        let expFXAA = expectation(description: "FXAA ref")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let tex = textureResources.fxaaTexture {
                self.testGenerateRenderTarget(targetName: "FXAA", texture: tex)
            }
            expFXAA.fulfill()
        }
        wait(for: [expFXAA], timeout: TimeInterval(timeoutFactor))
        FXAAParams.shared.enabled = false
    }

    // MARK: - PSNR Tests

    func testSSAO() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureSSAO()
        SSAO.setEnabled(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "SSAO PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.ssaoBlurTexture else {
                XCTFail("ssaoBlurTexture should exist after enabling SSAO")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "SSAO", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testDepthOfField() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureDepthOfField()
        PostFX.enableDepthOfField(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "DepthOfField PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.depthOfFieldTexture else {
                XCTFail("depthOfFieldTexture should exist after enabling Depth of Field")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "DepthOfField", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testChromaticAberration() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureChromaticAberration()
        PostFX.enableChromaticAberration(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "ChromaticAberration PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.chromaticAberrationTexture else {
                XCTFail("chromaticAberrationTexture should exist after enabling Chromatic Aberration")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "ChromaticAberration", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testBloom() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureBloom()
        PostFX.enableBloomThreshold(true)
        PostFX.enableBloomComposite(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "Bloom PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.bloomCompositeTexture else {
                XCTFail("bloomCompositeTexture should exist after enabling Bloom")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "Bloom", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testVignette() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureVignette()
        PostFX.enableVignette(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "Vignette PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.vignetteTexture else {
                XCTFail("vignetteTexture should exist after enabling Vignette")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "Vignette", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testColorGrading() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        configureColorGrading()
        PostFX.enableColorGrading(true)
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "ColorGrading PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.lookTexture else {
                XCTFail("lookTexture should exist after enabling Color Grading")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "ColorGrading", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    func testFXAA() {
        XCTAssertNotNil(renderer, "Renderer should be initialized")
        FXAAParams.shared.enabled = true
        renderer.draw(in: renderer.metalView)

        let exp = expectation(description: "FXAA PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.fxaaTexture else {
                XCTFail("fxaaTexture should exist after enabling FXAA")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "FXAA", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }
}
