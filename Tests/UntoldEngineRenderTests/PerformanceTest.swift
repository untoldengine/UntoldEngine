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
        let frameBudgetMs = 16.67 // ~60 FPS
        let warmupFrames = 120
        let measuredFrames = 300

        // Safety
        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }

        // Warmup: compile pipelines, fill caches
        for _ in 0 ..< warmupFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Measure N frames
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0 ..< measuredFrames {
            renderer.draw(in: renderer.metalView)
        }
        let end = CFAbsoluteTimeGetCurrent()

        let avgMs = ((end - start) / Double(measuredFrames)) * 1000.0
        let fps = 1000.0 / avgMs
        print(String(format: "Perf (wall-clock): avg %.2f ms (%.1f FPS) over %d frames",
                     avgMs, fps, measuredFrames))

        XCTAssertLessThanOrEqual(
            avgMs,
            frameBudgetMs,
            String(format: "❌ Average frame time %.2f ms exceeded budget %.2f ms (%.1f FPS).",
                   avgMs, frameBudgetMs, fps)
        )
    }
}
