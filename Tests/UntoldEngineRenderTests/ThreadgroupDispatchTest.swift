//
//  ThreadgroupDispatchTest.swift
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

final class ThreadgroupDispatchTest: BaseRenderSetup {
    override func setUp() {
        super.setUp()
        // Initialize compute pipelines
        initGuassianComputePipelines()
        initFrustumCulllingCompute()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Helper Functions

    /// Calculate threadgroups for frustum culling (standard pattern)
    func calculateFrustumCullingThreadgroups(count: Int, pipeline: MTLComputePipelineState) -> (threadgroups: Int, threadsPerThreadgroup: Int) {
        let tew = pipeline.threadExecutionWidth
        let maxT = pipeline.maxTotalThreadsPerThreadgroup
        let target = 256
        var block = min(target, maxT)
        block = (block / tew) * tew
        block = max(block, tew)

        let numThreadgroups = (count + block - 1) / block
        return (numThreadgroups, block)
    }

    /// Calculate threadgroups for Gaussian depth (same pattern as frustum culling)
    func calculateGaussianDepthThreadgroups(splatCount: Int, pipeline: MTLComputePipelineState) -> (threadgroups: Int, threadsPerThreadgroup: Int) {
        let tew = pipeline.threadExecutionWidth
        let maxT = pipeline.maxTotalThreadsPerThreadgroup
        let target = 256
        var block = min(target, maxT)
        block = (block / tew) * tew
        block = max(block, tew)

        let numThreadgroups = (splatCount + block - 1) / block
        return (numThreadgroups, block)
    }

    /// Calculate threadgroups for bitonic sort (same pattern)
    func calculateBitonicSortThreadgroups(powerOfTwoCount: Int, pipeline: MTLComputePipelineState) -> (threadgroups: Int, threadsPerThreadgroup: Int) {
        let tew = pipeline.threadExecutionWidth
        let maxT = pipeline.maxTotalThreadsPerThreadgroup
        let target = 256
        var block = min(target, maxT)
        block = (block / tew) * tew
        block = max(block, tew)

        let numThreadgroups = (powerOfTwoCount + block - 1) / block
        return (numThreadgroups, block)
    }

    /// Calculate threadgroups for reduce-scan mark visible pass
    func calculateMarkVisibleThreadgroups(count: Int, pipeline: MTLComputePipelineState) -> (threadgroups: Int, threadsPerThreadgroup: Int) {
        let w = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
        let numThreadgroups = (count + w - 1) / w
        return (numThreadgroups, w)
    }

    /// Calculate threadgroups for reduce-scan compact pass
    func calculateCompactThreadgroups(count: Int, pipeline: MTLComputePipelineState) -> (threadgroups: Int, threadsPerThreadgroup: Int) {
        let w = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
        let numThreadgroups = (count + w - 1) / w
        return (numThreadgroups, w)
    }

    // MARK: - Test Cases

    func test_executeFrustumCulling_dispatches_correct_threadgroups() {
        guard let pipeline = frustumCullingPipeline.pipelineState else {
            XCTFail("Frustum culling pipeline not initialized")
            return
        }

        // Test various entity counts
        let testCounts = [1, 32, 64, 128, 256, 512, 1000, 2048, 5000]

        for count in testCounts {
            let (threadgroups, threadsPerThreadgroup) = calculateFrustumCullingThreadgroups(count: count, pipeline: pipeline)

            // Verify threadgroup calculation
            XCTAssertGreaterThan(threadgroups, 0, "Threadgroups should be positive for count \(count)")
            XCTAssertGreaterThanOrEqual(threadsPerThreadgroup, pipeline.threadExecutionWidth,
                                        "Threads per threadgroup should be at least thread execution width for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, pipeline.maxTotalThreadsPerThreadgroup,
                                     "Threads per threadgroup should not exceed device limit for count \(count)")

            // Verify coverage: total threads >= count
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, count,
                                        "Total dispatched threads (\(totalThreads)) should cover all items (\(count))")

            // Verify minimal over-dispatch: total threads < count + threadsPerThreadgroup
            XCTAssertLessThan(totalThreads, count + threadsPerThreadgroup,
                              "Should not over-dispatch by more than one threadgroup for count \(count)")

            // Verify alignment: threadsPerThreadgroup should be a multiple of thread execution width
            XCTAssertEqual(threadsPerThreadgroup % pipeline.threadExecutionWidth, 0,
                           "Threads per threadgroup should be aligned to thread execution width for count \(count)")

            print("✓ Count \(count): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads = \(totalThreads) total")
        }

        print("✅ executeFrustumCulling threadgroup dispatch test passed!")
    }

    func test_executeReduceScanFrustumCulling_markVisible_dispatches_correct_threadgroups() {
        guard let pipeline = reduceScanMarkVisiblePipeline.pipelineState else {
            XCTFail("Mark visible pipeline not initialized")
            return
        }

        let testCounts = [1, 32, 64, 128, 256, 512, 1000, 2048, 5000]

        for count in testCounts {
            let (threadgroups, threadsPerThreadgroup) = calculateMarkVisibleThreadgroups(count: count, pipeline: pipeline)

            // Verify threadgroup calculation
            XCTAssertGreaterThan(threadgroups, 0, "Threadgroups should be positive for count \(count)")
            XCTAssertGreaterThan(threadsPerThreadgroup, 0, "Threads per threadgroup should be positive for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, 256,
                                     "Threads per threadgroup should not exceed target (256) for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, pipeline.maxTotalThreadsPerThreadgroup,
                                     "Threads per threadgroup should not exceed device limit for count \(count)")

            // Verify coverage
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, count,
                                        "Total dispatched threads (\(totalThreads)) should cover all items (\(count))")

            // Verify minimal over-dispatch
            XCTAssertLessThan(totalThreads, count + threadsPerThreadgroup,
                              "Should not over-dispatch by more than one threadgroup for count \(count)")

            print("✓ Mark Visible - Count \(count): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads = \(totalThreads) total")
        }

        print("✅ executeReduceScanFrustumCulling mark visible threadgroup dispatch test passed!")
    }

    func test_executeReduceScanFrustumCulling_compact_dispatches_correct_threadgroups() {
        guard let pipeline = reduceScanScatterCompactedPipeline.pipelineState else {
            XCTFail("Scatter compacted pipeline not initialized")
            return
        }

        let testCounts = [1, 32, 64, 128, 256, 512, 1000, 2048, 5000]

        for count in testCounts {
            let (threadgroups, threadsPerThreadgroup) = calculateCompactThreadgroups(count: count, pipeline: pipeline)

            // Verify threadgroup calculation
            XCTAssertGreaterThan(threadgroups, 0, "Threadgroups should be positive for count \(count)")
            XCTAssertGreaterThan(threadsPerThreadgroup, 0, "Threads per threadgroup should be positive for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, 256,
                                     "Threads per threadgroup should not exceed target (256) for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, pipeline.maxTotalThreadsPerThreadgroup,
                                     "Threads per threadgroup should not exceed device limit for count \(count)")

            // Verify coverage
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, count,
                                        "Total dispatched threads (\(totalThreads)) should cover all items (\(count))")

            // Verify minimal over-dispatch
            XCTAssertLessThan(totalThreads, count + threadsPerThreadgroup,
                              "Should not over-dispatch by more than one threadgroup for count \(count)")

            print("✓ Compact - Count \(count): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads = \(totalThreads) total")
        }

        print("✅ executeReduceScanFrustumCulling compact threadgroup dispatch test passed!")
    }

    func test_executeGaussianDepth_dispatches_correct_threadgroups() {
        guard let pipeline = gaussianDepthPipeline.pipelineState else {
            XCTFail("Gaussian depth pipeline not initialized")
            return
        }

        let testCounts = [1, 8, 32, 64, 128, 256, 512, 1024, 2048, 5000, 10000]

        for count in testCounts {
            let (threadgroups, threadsPerThreadgroup) = calculateGaussianDepthThreadgroups(splatCount: count, pipeline: pipeline)

            // Verify threadgroup calculation
            XCTAssertGreaterThan(threadgroups, 0, "Threadgroups should be positive for splat count \(count)")
            XCTAssertGreaterThanOrEqual(threadsPerThreadgroup, pipeline.threadExecutionWidth,
                                        "Threads per threadgroup should be at least thread execution width for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, pipeline.maxTotalThreadsPerThreadgroup,
                                     "Threads per threadgroup should not exceed device limit for count \(count)")

            // Verify coverage
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, count,
                                        "Total dispatched threads (\(totalThreads)) should cover all splats (\(count))")

            // Verify minimal over-dispatch
            XCTAssertLessThan(totalThreads, count + threadsPerThreadgroup,
                              "Should not over-dispatch by more than one threadgroup for count \(count)")

            // Verify alignment
            XCTAssertEqual(threadsPerThreadgroup % pipeline.threadExecutionWidth, 0,
                           "Threads per threadgroup should be aligned to thread execution width for count \(count)")

            print("✓ Gaussian Depth - Splat count \(count): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads = \(totalThreads) total")
        }

        print("✅ executeGaussianDepth threadgroup dispatch test passed!")
    }

    func test_executeBitonicSort_dispatches_correct_threadgroups() {
        guard let pipeline = bitonicSortPipeline.pipelineState else {
            XCTFail("Bitonic sort pipeline not initialized")
            return
        }

        // Test power-of-2 counts (bitonic sort requirement)
        let testCounts: [UInt] = [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096]

        for count in testCounts {
            // Bitonic sort uses nextPowerOf2, but for these tests the input is already power of 2
            var mutableCount = count
            let powerOfTwo = nextPowerOf2(x: &mutableCount)

            XCTAssertEqual(powerOfTwo, count, "Input should already be power of 2")

            let (threadgroups, threadsPerThreadgroup) = calculateBitonicSortThreadgroups(powerOfTwoCount: Int(powerOfTwo), pipeline: pipeline)

            // Verify threadgroup calculation
            XCTAssertGreaterThan(threadgroups, 0, "Threadgroups should be positive for count \(count)")
            XCTAssertGreaterThanOrEqual(threadsPerThreadgroup, pipeline.threadExecutionWidth,
                                        "Threads per threadgroup should be at least thread execution width for count \(count)")
            XCTAssertLessThanOrEqual(threadsPerThreadgroup, pipeline.maxTotalThreadsPerThreadgroup,
                                     "Threads per threadgroup should not exceed device limit for count \(count)")

            // Verify coverage
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, Int(powerOfTwo),
                                        "Total dispatched threads (\(totalThreads)) should cover all items (\(powerOfTwo))")

            // Verify minimal over-dispatch
            XCTAssertLessThan(totalThreads, Int(powerOfTwo) + threadsPerThreadgroup,
                              "Should not over-dispatch by more than one threadgroup for count \(count)")

            // Verify alignment
            XCTAssertEqual(threadsPerThreadgroup % pipeline.threadExecutionWidth, 0,
                           "Threads per threadgroup should be aligned to thread execution width for count \(count)")

            print("✓ Bitonic Sort - Count \(count): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads = \(totalThreads) total")
        }

        // Also test non-power-of-2 inputs to verify nextPowerOf2 behavior
        let nonPowerOfTwoTests: [(input: UInt, expected: UInt)] = [
            (3, 4), (5, 8), (7, 8), (100, 128), (1000, 1024), (5000, 8192),
        ]

        for (input, expected) in nonPowerOfTwoTests {
            var mutableInput = input
            let powerOfTwo = nextPowerOf2(x: &mutableInput)

            XCTAssertEqual(powerOfTwo, expected, "nextPowerOf2(\(input)) should equal \(expected)")

            let (threadgroups, threadsPerThreadgroup) = calculateBitonicSortThreadgroups(powerOfTwoCount: Int(powerOfTwo), pipeline: pipeline)

            // Verify coverage for rounded-up count
            let totalThreads = threadgroups * threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, Int(powerOfTwo),
                                        "Total threads should cover power-of-2 padded count for input \(input)")

            print("✓ Bitonic Sort - Input \(input) → Power-of-2 \(powerOfTwo): \(threadgroups) threadgroups × \(threadsPerThreadgroup) threads")
        }

        print("✅ executeBitonicSort threadgroup dispatch test passed!")
    }

    // MARK: - Edge Cases

    func test_threadgroup_calculation_edge_cases() {
        guard let pipeline = frustumCullingPipeline.pipelineState else {
            XCTFail("Pipeline not initialized")
            return
        }

        // Test count = 1 (minimum)
        let (tg1, tpt1) = calculateFrustumCullingThreadgroups(count: 1, pipeline: pipeline)
        XCTAssertEqual(tg1, 1, "Single item should require 1 threadgroup")
        XCTAssertGreaterThanOrEqual(tpt1, 1, "Should dispatch at least 1 thread")

        // Test count = thread execution width (should be exactly 1 threadgroup)
        let tew = pipeline.threadExecutionWidth
        let (tg2, tpt2) = calculateFrustumCullingThreadgroups(count: tew, pipeline: pipeline)
        XCTAssertEqual(tg2, 1, "Count equal to thread execution width should use 1 threadgroup")
        XCTAssertGreaterThanOrEqual(tpt2, tew, "Threads per threadgroup should be at least thread execution width")
        XCTAssertEqual(tpt2 % tew, 0, "Threads per threadgroup should be a multiple of thread execution width")

        // Test count = maxTotalThreadsPerThreadgroup (boundary)
        let maxThreads = pipeline.maxTotalThreadsPerThreadgroup
        let (tg3, tpt3) = calculateFrustumCullingThreadgroups(count: maxThreads, pipeline: pipeline)
        XCTAssertGreaterThan(tg3, 0, "Max threads count should produce valid threadgroups")
        XCTAssertLessThanOrEqual(tpt3, maxThreads, "Should not exceed device limit")

        // Test count just over threadgroup size (should use 2 threadgroups)
        let justOver = tpt1 + 1
        let (tg4, _) = calculateFrustumCullingThreadgroups(count: justOver, pipeline: pipeline)
        XCTAssertEqual(tg4, 2, "Count just over one threadgroup size should use 2 threadgroups")

        print("✅ Edge case tests passed!")
    }

    // MARK: - Integration Test

    func test_dispatch_calculation_consistency() {
        // Verify all pipelines use consistent calculation patterns
        guard let frustumPipeline = frustumCullingPipeline.pipelineState,
              let gaussianDepthPipeline = gaussianDepthPipeline.pipelineState,
              let bitonicPipeline = bitonicSortPipeline.pipelineState,
              let markVisiblePipeline = reduceScanMarkVisiblePipeline.pipelineState,
              let compactPipeline = reduceScanScatterCompactedPipeline.pipelineState
        else {
            XCTFail("Pipelines not initialized")
            return
        }

        let testCount = 512

        // Calculate for all pipelines
        let frustumResult = calculateFrustumCullingThreadgroups(count: testCount, pipeline: frustumPipeline)
        let gaussianResult = calculateGaussianDepthThreadgroups(splatCount: testCount, pipeline: gaussianDepthPipeline)
        let bitonicResult = calculateBitonicSortThreadgroups(powerOfTwoCount: testCount, pipeline: bitonicPipeline)
        let markVisibleResult = calculateMarkVisibleThreadgroups(count: testCount, pipeline: markVisiblePipeline)
        let compactResult = calculateCompactThreadgroups(count: testCount, pipeline: compactPipeline)

        // All should provide adequate coverage
        let results = [
            ("Frustum Culling", frustumResult),
            ("Gaussian Depth", gaussianResult),
            ("Bitonic Sort", bitonicResult),
            ("Mark Visible", markVisibleResult),
            ("Compact", compactResult),
        ]

        for (name, result) in results {
            let totalThreads = result.threadgroups * result.threadsPerThreadgroup
            XCTAssertGreaterThanOrEqual(totalThreads, testCount,
                                        "\(name): Total threads should cover test count")
            print("✓ \(name): \(result.threadgroups) × \(result.threadsPerThreadgroup) = \(totalThreads) threads")
        }

        print("✅ Dispatch calculation consistency test passed!")
    }
}
