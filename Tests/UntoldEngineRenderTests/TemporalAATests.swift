//
//  TemporalAATests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import simd
@testable import UntoldEngine
import XCTest

final class TemporalAATests: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        TAAParams.shared.enabled = false
        FXAAParams.shared.enabled = false
    }

    override func tearDown() async throws {
        TAAParams.shared.enabled = false
        FXAAParams.shared.enabled = false
        try await super.tearDown()
    }

    // MARK: - Halton jitter table

    func testHaltonTableHasCorrectSize() {
        XCTAssertEqual(haltonJitterTable.count, haltonTableSize,
                       "Halton table must have exactly haltonTableSize entries")
    }

    func testHaltonTableValuesAreInRange() {
        for (i, sample) in haltonJitterTable.enumerated() {
            XCTAssertGreaterThanOrEqual(sample.x, -0.5, "Sample \(i) x is below -0.5")
            XCTAssertLessThanOrEqual(sample.x, 0.5, "Sample \(i) x is above  0.5")
            XCTAssertGreaterThanOrEqual(sample.y, -0.5, "Sample \(i) y is below -0.5")
            XCTAssertLessThanOrEqual(sample.y, 0.5, "Sample \(i) y is above  0.5")
        }
    }

    func testHaltonTableHasNoRepeats() {
        let keys = haltonJitterTable.map { "\($0.x),\($0.y)" }
        XCTAssertEqual(Set(keys).count, haltonJitterTable.count,
                       "Halton table should not contain duplicate samples")
    }

    func testCurrentJitterCyclesAfterFullTable() {
        let first = TemporalAA.shared.currentJitter()
        for _ in 0 ..< haltonTableSize {
            TemporalAA.shared.advanceFrame()
        }
        let afterCycle = TemporalAA.shared.currentJitter()
        XCTAssertEqual(first.x, afterCycle.x, accuracy: 1e-6,
                       "Jitter X should return to the same value after one full cycle")
        XCTAssertEqual(first.y, afterCycle.y, accuracy: 1e-6,
                       "Jitter Y should return to the same value after one full cycle")
    }

    // MARK: - TemporalAA state machine

    func testMarkReadySetsIsSupported() {
        // initSizeableResources (called from setUp) already invokes markReady.
        XCTAssertTrue(TemporalAA.shared.isSupported,
                      "isSupported must be true after initSizeableResources")
    }

    func testMarkReadySetsNeedsReset() {
        TemporalAA.shared.markReady()
        XCTAssertTrue(TemporalAA.shared.needsReset,
                      "markReady should arm needsReset so the first frame skips history")
    }

    func testAdvanceFrameClearsNeedsReset() {
        TemporalAA.shared.markReady()
        XCTAssertTrue(TemporalAA.shared.needsReset)
        TemporalAA.shared.advanceFrame()
        XCTAssertFalse(TemporalAA.shared.needsReset,
                       "advanceFrame should clear needsReset after the first frame")
    }

    func testResetSetsNeedsReset() {
        TemporalAA.shared.markReady()
        TemporalAA.shared.advanceFrame()
        XCTAssertFalse(TemporalAA.shared.needsReset)
        TemporalAA.shared.reset()
        XCTAssertTrue(TemporalAA.shared.needsReset,
                      "reset() must re-arm needsReset to flush stale history")
    }

    // MARK: - Camera-jump auto-reset

    func testCheckAndResetTriggersOnLargeJump() {
        // Establish a known baseline position then clear the reset flag.
        TemporalAA.shared.checkAndResetIfNeeded(cameraPosition: .zero)
        TemporalAA.shared.advanceFrame()
        XCTAssertFalse(TemporalAA.shared.needsReset)

        // Jump 3 m — exceeds the 2 m default threshold.
        TemporalAA.shared.checkAndResetIfNeeded(cameraPosition: simd_float3(0, 0, 3))
        XCTAssertTrue(TemporalAA.shared.needsReset,
                      "A camera jump > 2 m should trigger a history reset")
    }

    func testCheckAndResetIgnoresSmallMovement() {
        // Establish a known baseline position then clear the reset flag.
        TemporalAA.shared.checkAndResetIfNeeded(cameraPosition: .zero)
        TemporalAA.shared.advanceFrame()
        XCTAssertFalse(TemporalAA.shared.needsReset)

        // Move 0.5 m — below the 2 m threshold.
        TemporalAA.shared.checkAndResetIfNeeded(cameraPosition: simd_float3(0, 0, 0.5))
        XCTAssertFalse(TemporalAA.shared.needsReset,
                       "A camera move < 2 m must not trigger a history reset")
    }

    // MARK: - GPU: texture allocation

    func testTAATexturesExistAfterInit() {
        XCTAssertNotNil(textureResources.taaOutputTexture,
                        "taaOutputTexture must be allocated after initSizeableResources")
        XCTAssertNotNil(textureResources.taaHistoryTexture,
                        "taaHistoryTexture must be allocated after initSizeableResources")
        XCTAssertNotNil(textureResources.taaPositionHistoryTexture,
                        "taaPositionHistoryTexture must be allocated after initSizeableResources")
        XCTAssertNotNil(textureResources.velocityTexture,
                        "velocityTexture must be allocated after initSizeableResources")
    }

    func testTAATexturesMatchViewportDimensions() {
        guard let out = textureResources.taaOutputTexture,
              let hist = textureResources.taaHistoryTexture,
              let pos = textureResources.taaPositionHistoryTexture
        else {
            XCTFail("TAA textures must exist before checking dimensions")
            return
        }
        for (label, tex) in [("output", out), ("history", hist), ("positionHistory", pos)] {
            XCTAssertEqual(tex.width, windowWidth, "\(label) width must match viewport")
            XCTAssertEqual(tex.height, windowHeight, "\(label) height must match viewport")
        }
    }

    // MARK: - Reference image generation (uncomment to regenerate)

    func generateTAAReferenceImage() {
        XCTAssertNotNil(renderer)
        TAAParams.shared.enabled = true
        for _ in 0 ..< haltonTableSize {
            renderer.draw(in: renderer.metalView)
        }
        let exp = expectation(description: "TAA ref")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if let tex = textureResources.taaOutputTexture {
                self.testGenerateRenderTarget(targetName: "TAA", texture: tex)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }

    // MARK: - GPU: PSNR convergence

    func testTAAOutput() {
        XCTAssertNotNil(renderer, "Renderer must be initialized")
        TAAParams.shared.enabled = true

        // Render one full Halton cycle (16 frames) so the history is converged
        // before we sample the output for comparison. A single-frame test is
        // not meaningful for TAA because frame 0 always outputs current-only
        // (needsReset = true skips history blending).
        for _ in 0 ..< haltonTableSize {
            renderer.draw(in: renderer.metalView)
        }

        let exp = expectation(description: "TAA PSNR")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let tex = textureResources.taaOutputTexture else {
                XCTFail("taaOutputTexture must exist after enabling TAA")
                exp.fulfill()
                return
            }
            self.psnrTest(targetName: "TAA", texture: tex)
            exp.fulfill()
        }
        wait(for: [exp], timeout: TimeInterval(timeoutFactor))
    }
}
