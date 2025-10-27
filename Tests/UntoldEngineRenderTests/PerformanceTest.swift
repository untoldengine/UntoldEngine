//
//  PerformanceTest.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.

import CShaderTypes
import simd
import UniformTypeIdentifiers
@testable import UntoldEngine
import XCTest

final class PerformanceTests: BaseRenderSetup {
    func test_AverageFrameTime_UnderBudget() throws {
        // Tune per target device
        let frameBudgetMs = 17.0 // ~60 FPS - I'm relaxing the frame time for CI
        let warmupFrames = 120
        let measuredFrames = 300

        // Safety
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }
        guard let device = renderer.metalView.device else {
            throw XCTSkip("Metal device not available")
        }

        // Warmup: compile pipelines, fill caches
        for _ in 0 ..< warmupFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Wait for GPU to finish warmup work
        if let commandQueue = device.makeCommandQueue(),
           let commandBuffer = commandQueue.makeCommandBuffer()
        {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }

        // Measure N frames with GPU synchronization
        var frameTimes: [Double] = []

        for _ in 0 ..< measuredFrames {
            let frameStart = CFAbsoluteTimeGetCurrent()

            renderer.draw(in: renderer.metalView)

            // Wait for this frame's GPU work to complete
            if let commandQueue = device.makeCommandQueue(),
               let commandBuffer = commandQueue.makeCommandBuffer()
            {
                commandBuffer.commit()
                commandBuffer.waitUntilCompleted()
            }

            let frameEnd = CFAbsoluteTimeGetCurrent()
            frameTimes.append((frameEnd - frameStart) * 1000.0)
        }

        let avgMs = frameTimes.reduce(0, +) / Double(frameTimes.count)
        let fps = 1000.0 / avgMs

        print(String(format: "Perf (GPU-synced): avg %.2f ms (%.1f FPS) over %d frames",
                     avgMs, fps, measuredFrames))

        XCTAssertLessThanOrEqual(
            avgMs,
            frameBudgetMs,
            String(format: "❌ Average frame time %.2f ms exceeded budget %.2f ms (%.1f FPS).",
                   avgMs, frameBudgetMs, fps)
        )
    }
}
