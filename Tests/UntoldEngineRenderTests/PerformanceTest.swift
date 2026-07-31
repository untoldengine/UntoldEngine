//
//  PerformanceTest.swift
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

final class PerformanceTests: BaseRenderSetup {
    private func doubleEnv(_ name: String, default defaultValue: Double) -> Double {
        guard let rawValue = ProcessInfo.processInfo.environment[name],
              let value = Double(rawValue)
        else {
            return defaultValue
        }
        return value
    }

    private func intEnv(_ name: String, default defaultValue: Int) -> Int {
        guard let rawValue = ProcessInfo.processInfo.environment[name],
              let value = Int(rawValue),
              value > 0
        else {
            return defaultValue
        }
        return value
    }

    func test_AverageFrameTime_UnderBudget() throws {
        let frameBudgetMs = doubleEnv("UNTOLD_PERF_GPU_FRAME_BUDGET_MS", default: 17.0)
        let warmupFrames = intEnv("UNTOLD_PERF_WARMUP_FRAMES", default: 120)
        let measuredFrames = intEnv("UNTOLD_PERF_GPU_MEASURED_FRAMES", default: 300)

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
        print(String(format: "Perf budget: avg <= %.2f ms", frameBudgetMs))

        XCTAssertLessThanOrEqual(
            avgMs,
            frameBudgetMs,
            String(format: "❌ Average frame time %.2f ms exceeded budget %.2f ms (%.1f FPS).",
                   avgMs, frameBudgetMs, fps)
        )
    }

    func test_EngineProfiler_CPUFrameMetrics() throws {
        let frameBudgetMs = doubleEnv("UNTOLD_PERF_CPU_FRAME_BUDGET_MS", default: 17.0)
        let p95Multiplier = doubleEnv("UNTOLD_PERF_CPU_P95_MULTIPLIER", default: 1.2)
        let warmupFrames = intEnv("UNTOLD_PERF_WARMUP_FRAMES", default: 120)
        let measuredFrames = intEnv("UNTOLD_PERF_CPU_MEASURED_FRAMES", default: 600)

        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }

        // Enable metrics for this test
        let previousMetricsState = enableEngineMetrics
        enableEngineMetrics = true
        defer { enableEngineMetrics = previousMetricsState }

        // Reset any existing metrics
        EngineProfiler.shared.reset()

        // Warmup
        for _ in 0 ..< warmupFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Reset after warmup to get clean measurements
        EngineProfiler.shared.reset()

        // Measured run (no GPU sync - real-world conditions)
        for _ in 0 ..< measuredFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Get snapshot
        let snapshot = EngineProfiler.shared.snapshot()

        print("=== EngineProfiler CPU Frame Metrics ===")
        print(String(format: "  Samples: %d", snapshot.cpuFrame.sampleCount))
        print(String(format: "  Mean: %.2f ms (%.1f FPS)", snapshot.cpuFrame.meanMs, 1000.0 / snapshot.cpuFrame.meanMs))
        print(String(format: "  P95: %.2f ms (%.1f FPS)", snapshot.cpuFrame.p95Ms, 1000.0 / snapshot.cpuFrame.p95Ms))
        print(String(format: "  P99: %.2f ms (%.1f FPS)", snapshot.cpuFrame.p99Ms, 1000.0 / snapshot.cpuFrame.p99Ms))
        print(String(format: "  Min: %.2f ms", snapshot.cpuFrame.minMs))
        print(String(format: "  Max: %.2f ms", snapshot.cpuFrame.maxMs))
        print(String(format: "  Budget: mean <= %.2f ms, p95 <= %.2f ms",
                     frameBudgetMs, frameBudgetMs * p95Multiplier))
        print("=========================================")

        // Assert we collected samples
        XCTAssertGreaterThan(snapshot.cpuFrame.sampleCount, 0, "No CPU frame samples collected")

        // Assert mean frame time is under budget
        XCTAssertLessThanOrEqual(
            snapshot.cpuFrame.meanMs,
            frameBudgetMs,
            String(format: "❌ Mean CPU frame time %.2f ms exceeded budget %.2f ms",
                   snapshot.cpuFrame.meanMs, frameBudgetMs)
        )

        // Assert p95 is reasonable (allow 20% over budget for variance)
        XCTAssertLessThanOrEqual(
            snapshot.cpuFrame.p95Ms,
            frameBudgetMs * p95Multiplier,
            String(format: "❌ P95 CPU frame time %.2f ms exceeded %.2f ms",
                   snapshot.cpuFrame.p95Ms, frameBudgetMs * p95Multiplier)
        )
    }

    func test_EngineProfiler_GPUMetrics() throws {
        let warmupFrames = 120
        let measuredFrames = 600

        guard renderer != nil else { throw XCTSkip("Renderer not initialized") }
        guard renderer.metalView.device != nil else {
            throw XCTSkip("Metal device not available")
        }

        // Enable metrics
        let previousMetricsState = enableEngineMetrics
        enableEngineMetrics = true
        defer { enableEngineMetrics = previousMetricsState }

        EngineProfiler.shared.reset()

        // Warmup
        for _ in 0 ..< warmupFrames {
            renderer.draw(in: renderer.metalView)
        }

        EngineProfiler.shared.reset()

        // Measured run
        for _ in 0 ..< measuredFrames {
            renderer.draw(in: renderer.metalView)
        }

        // Wait a bit for completion handlers to fire
        Thread.sleep(forTimeInterval: 0.5)

        let snapshot = EngineProfiler.shared.snapshot()

        print("=== EngineProfiler GPU Metrics ===")
        print(String(format: "  Samples: %d", snapshot.gpuCommandBuffer.sampleCount))
        print(String(format: "  Mean: %.2f ms", snapshot.gpuCommandBuffer.meanMs))
        print(String(format: "  P95: %.2f ms", snapshot.gpuCommandBuffer.p95Ms))
        print(String(format: "  P99: %.2f ms", snapshot.gpuCommandBuffer.p99Ms))
        print(String(format: "  Min: %.2f ms", snapshot.gpuCommandBuffer.minMs))
        print(String(format: "  Max: %.2f ms", snapshot.gpuCommandBuffer.maxMs))
        print("===================================")

        // Note: GPU times can be zero/invalid on some systems, so we don't assert they exist
        // Just log the results for informational purposes
        if snapshot.gpuCommandBuffer.sampleCount > 0 {
            print("✅ GPU metrics collection working")
        } else {
            print("ℹ️ GPU metrics not available on this system (gpuStartTime/gpuEndTime not supported)")
        }
    }
}
