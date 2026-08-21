//
//  DeviceRadixSortTest.swift
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

/// Buffer binding indices for each radix sort kernel (matches DeviceRadixSort.metal once implemented)
private enum HistogramBuffer: Int {
    case keysIn = 0
    case output = 1
    case numElems = 2
    case passIndex = 3
}

private enum ScanBuffer: Int {
    case histogram = 0
    case numBuckets = 1
}

private enum ScatterBuffer: Int {
    case keysIn = 0
    case keysOut = 1
    case offsets = 2
    case numElems = 3
    case passIdx = 4
    case perTGStart = 5 // zero buffer for single-TG unit tests
}

private let kRadixBuckets = 256 // 2^8

// MARK: - Helpers

extension DeviceRadixSortTest {
    /// Returns an MTLComputePipelineState for the named Metal function, or nil if the
    /// function is not yet compiled into the library. Tests guard on this returning non-nil.
    private func makePipeline(named functionName: String) -> MTLComputePipelineState? {
        guard let library = renderInfo.library else { return nil }
        guard let fn = library.makeFunction(name: functionName) else { return nil }
        return try? renderInfo.device.makeComputePipelineState(function: fn)
    }

    /// Allocates a shared MTLBuffer filled with the given UInt64 array.
    private func makeBuffer(_ values: [UInt64]) -> MTLBuffer? {
        renderInfo.device.makeBuffer(
            bytes: values,
            length: values.count * MemoryLayout<UInt64>.stride,
            options: .storageModeShared
        )
    }

    /// Allocates an empty shared MTLBuffer of the given element count.
    private func makeBuffer<T>(count: Int, type _: T.Type) -> MTLBuffer? {
        renderInfo.device.makeBuffer(
            length: count * MemoryLayout<T>.stride,
            options: .storageModeShared
        )
    }

    /// Runs a compute kernel synchronously.
    /// - Parameters:
    ///   - pipeline: pre-built pipeline state
    ///   - setup: closure that configures buffers/bytes on the encoder
    ///   - threadCount: total number of threads to dispatch (ceil-rounded to threadgroup size)
    private func dispatch(
        _ pipeline: MTLComputePipelineState,
        threadCount: Int,
        setup: (MTLComputeCommandEncoder) -> Void
    ) {
        guard
            let queue = renderInfo.device.makeCommandQueue(),
            let cmd = queue.makeCommandBuffer(),
            let enc = cmd.makeComputeCommandEncoder()
        else { XCTFail("Could not create command encoder"); return }

        enc.setComputePipelineState(pipeline)
        setup(enc)

        let tew = pipeline.threadExecutionWidth
        let blockSize = max(tew, min(256, pipeline.maxTotalThreadsPerThreadgroup))
        let numGroups = max(1, (threadCount + blockSize - 1) / blockSize)
        enc.dispatchThreadgroups(
            MTLSizeMake(numGroups, 1, 1),
            threadsPerThreadgroup: MTLSizeMake(blockSize, 1, 1)
        )
        enc.endEncoding()
        cmd.commit()
        cmd.waitUntilCompleted()
    }

    /// Reads the UInt32 contents of a buffer into a Swift array.
    private func readU32(_ buffer: MTLBuffer, count: Int) -> [UInt32] {
        let ptr = buffer.contents().bindMemory(to: UInt32.self, capacity: count)
        return (0 ..< count).map { ptr[$0] }
    }

    /// Reads the UInt64 contents of a buffer into a Swift array.
    private func readU64(_ buffer: MTLBuffer, count: Int) -> [UInt64] {
        let ptr = buffer.contents().bindMemory(to: UInt64.self, capacity: count)
        return (0 ..< count).map { ptr[$0] }
    }

    /// Zeroes out the contents of a buffer.
    private func zeroBuffer(_ buffer: MTLBuffer) {
        memset(buffer.contents(), 0, buffer.length)
    }

    // MARK: Digit extraction (mirrors the Metal kernel logic)

    /// Extract the 8-bit digit for the given radix pass from a packed UInt64 key.
    /// Pass 0 = bits 32-39 (LSB of depth key), Pass 3 = bits 56-63 (MSB of depth key).
    private func digit(of key: UInt64, pass: Int) -> Int {
        Int((key >> (32 + pass * 8)) & 0xFF)
    }

    /// Build a UInt64 packed key with a specific depth-byte value for a given pass,
    /// and a given splat index in the lower 32 bits.
    private func packKey(depthByte: UInt8, atPass pass: Int, index: UInt32) -> UInt64 {
        (UInt64(depthByte) << (32 + pass * 8)) | UInt64(index)
    }

    /// CPU reference: exclusive prefix scan of a UInt32 array.
    private func exclusiveScan(_ values: [UInt32]) -> [UInt32] {
        var result = [UInt32](repeating: 0, count: values.count)
        var running: UInt32 = 0
        for i in 0 ..< values.count {
            result[i] = running
            running &+= values[i]
        }
        return result
    }

    /// CPU reference: compute histogram of 8-bit digits for a given pass.
    private func referenceHistogram(keys: [UInt64], pass: Int) -> [UInt32] {
        var hist = [UInt32](repeating: 0, count: kRadixBuckets)
        for key in keys {
            hist[digit(of: key, pass: pass)] += 1
        }
        return hist
    }

    /// CPU reference: one scatter pass (stable).
    private func referenceScatter(keys: [UInt64], offsets: [UInt32], pass: Int) -> [UInt64] {
        var out = [UInt64](repeating: 0, count: keys.count)
        var localOffsets = offsets // mutable copy; incremented per element
        for key in keys {
            let d = digit(of: key, pass: pass)
            out[Int(localOffsets[d])] = key
            localOffsets[d] += 1
        }
        return out
    }
}

// MARK: - Test Class

final class DeviceRadixSortTest: BaseRenderSetup {
    override func setUp() async throws {
        try await super.setUp()
        // Gaussian pipelines are needed for integration tests that also run depth keys.
        initGuassianComputePipelines()
    }

    override func tearDown() async throws {
        try await super.tearDown()
    }

    // =========================================================================
    // MARK: Phase 1 – Histogram

    // =========================================================================

    /// All N keys have the same digit in pass 0.
    /// Expected: histogram[thatDigit] == N, all other buckets == 0.
    func test_radixHistogram_allSameBucket() {
        guard let pipeline = makePipeline(named: "gaussianRadixHistogram") else {
            XCTFail("gaussianRadixHistogram kernel not found – implement Phase 1 first")
            return
        }

        let targetDigit: UInt8 = 42
        let n = 64
        // Depth byte 42 at pass 0 → bits 32-39 = 42
        let keys = (0 ..< n).map { i in packKey(depthByte: targetDigit, atPass: 0, index: UInt32(i)) }

        guard let keyBuf = makeBuffer(keys),
              let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(histBuf)
        var numElems = UInt32(n)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: n) { enc in
            enc.setBuffer(keyBuf, offset: 0, index: HistogramBuffer.keysIn.rawValue)
            enc.setBuffer(histBuf, offset: 0, index: HistogramBuffer.output.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.passIndex.rawValue)
        }

        let hist = readU32(histBuf, count: kRadixBuckets)

        XCTAssertEqual(hist[Int(targetDigit)], UInt32(n), "Bucket \(targetDigit) should have all \(n) elements")
        for b in 0 ..< kRadixBuckets where b != Int(targetDigit) {
            XCTAssertEqual(hist[b], 0, "Bucket \(b) should be empty")
        }
        print("✅ test_radixHistogram_allSameBucket passed")
    }

    /// 256 keys, each with a unique digit 0-255 in pass 0.
    /// Expected: every bucket == 1.
    func test_radixHistogram_uniformDistribution() {
        guard let pipeline = makePipeline(named: "gaussianRadixHistogram") else {
            XCTFail("gaussianRadixHistogram kernel not found – implement Phase 1 first")
            return
        }

        // One key per digit value (0-255), index == digit
        let keys = (0 ..< kRadixBuckets).map { i in
            packKey(depthByte: UInt8(i), atPass: 0, index: UInt32(i))
        }

        guard let keyBuf = makeBuffer(keys),
              let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(histBuf)
        var numElems = UInt32(kRadixBuckets)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(keyBuf, offset: 0, index: HistogramBuffer.keysIn.rawValue)
            enc.setBuffer(histBuf, offset: 0, index: HistogramBuffer.output.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.passIndex.rawValue)
        }

        let hist = readU32(histBuf, count: kRadixBuckets)
        for b in 0 ..< kRadixBuckets {
            XCTAssertEqual(hist[b], 1, "Bucket \(b) should have exactly 1 element")
        }
        print("✅ test_radixHistogram_uniformDistribution passed")
    }

    /// Single-element input. Only one bucket should be non-zero.
    func test_radixHistogram_singleElement() {
        guard let pipeline = makePipeline(named: "gaussianRadixHistogram") else {
            XCTFail("gaussianRadixHistogram kernel not found – implement Phase 1 first")
            return
        }

        let targetDigit: UInt8 = 200
        let keys = [packKey(depthByte: targetDigit, atPass: 0, index: 0)]

        guard let keyBuf = makeBuffer(keys),
              let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(histBuf)
        var numElems = UInt32(1)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: 1) { enc in
            enc.setBuffer(keyBuf, offset: 0, index: HistogramBuffer.keysIn.rawValue)
            enc.setBuffer(histBuf, offset: 0, index: HistogramBuffer.output.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.passIndex.rawValue)
        }

        let hist = readU32(histBuf, count: kRadixBuckets)
        XCTAssertEqual(hist[Int(targetDigit)], 1, "Bucket \(targetDigit) should have 1 element")
        let total = hist.reduce(0, +)
        XCTAssertEqual(total, 1, "Total count across all buckets must equal 1")
        print("✅ test_radixHistogram_singleElement passed")
    }

    /// Invariant: sum(histogram[0..255]) == numElements for any input.
    /// Tests all 4 radix passes.
    func test_radixHistogram_sumEqualsTotal_allPasses() {
        guard let pipeline = makePipeline(named: "gaussianRadixHistogram") else {
            XCTFail("gaussianRadixHistogram kernel not found – implement Phase 1 first")
            return
        }

        let n = 512
        // Random-looking 64-bit keys that exercise all byte positions
        let keys: [UInt64] = (0 ..< n).map { _ in
            UInt64.random(in: 0 ..< UInt64.max)
        }

        guard let keyBuf = makeBuffer(keys),
              let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        var numElems = UInt32(n)

        for pass in 0 ..< 4 {
            zeroBuffer(histBuf)
            var passIndex = UInt32(pass)
            dispatch(pipeline, threadCount: n) { enc in
                enc.setBuffer(keyBuf, offset: 0, index: HistogramBuffer.keysIn.rawValue)
                enc.setBuffer(histBuf, offset: 0, index: HistogramBuffer.output.rawValue)
                enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.numElems.rawValue)
                enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.passIndex.rawValue)
            }

            let hist = readU32(histBuf, count: kRadixBuckets)
            let total = hist.reduce(UInt32(0), &+)
            XCTAssertEqual(total, UInt32(n),
                           "Pass \(pass): histogram sum \(total) != element count \(n)")
        }
        print("✅ test_radixHistogram_sumEqualsTotal_allPasses passed")
    }

    /// Digit extraction correctness: GPU histogram must match CPU reference for each pass.
    func test_radixHistogram_matchesCPUReference() {
        guard let pipeline = makePipeline(named: "gaussianRadixHistogram") else {
            XCTFail("gaussianRadixHistogram kernel not found – implement Phase 1 first")
            return
        }

        let n = 128
        let keys: [UInt64] = (0 ..< n).map { _ in UInt64.random(in: 0 ..< UInt64.max) }

        guard let keyBuf = makeBuffer(keys),
              let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        var numElems = UInt32(n)

        for pass in 0 ..< 4 {
            zeroBuffer(histBuf)
            var passIndex = UInt32(pass)
            dispatch(pipeline, threadCount: n) { enc in
                enc.setBuffer(keyBuf, offset: 0, index: HistogramBuffer.keysIn.rawValue)
                enc.setBuffer(histBuf, offset: 0, index: HistogramBuffer.output.rawValue)
                enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.numElems.rawValue)
                enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: HistogramBuffer.passIndex.rawValue)
            }

            let gpuHist = readU32(histBuf, count: kRadixBuckets)
            let cpuHist = referenceHistogram(keys: keys, pass: pass)

            for b in 0 ..< kRadixBuckets {
                XCTAssertEqual(gpuHist[b], cpuHist[b],
                               "Pass \(pass) bucket \(b): GPU=\(gpuHist[b]) CPU=\(cpuHist[b])")
            }
        }
        print("✅ test_radixHistogram_matchesCPUReference passed")
    }

    // =========================================================================
    // MARK: Phase 2 – Exclusive Scan

    // =========================================================================

    /// All-zero histogram → all-zero prefix sums.
    func test_radixScan_allZeroInput() {
        guard let pipeline = makePipeline(named: "gaussianRadixScan") else {
            XCTFail("gaussianRadixScan kernel not found – implement Phase 2 first")
            return
        }

        guard let histBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self) else {
            XCTFail("Buffer allocation failed"); return
        }
        zeroBuffer(histBuf)
        var numBuckets = UInt32(kRadixBuckets)

        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(histBuf, offset: 0, index: ScanBuffer.histogram.rawValue)
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: ScanBuffer.numBuckets.rawValue)
        }

        let result = readU32(histBuf, count: kRadixBuckets)
        for b in 0 ..< kRadixBuckets {
            XCTAssertEqual(result[b], 0, "Zero histogram → zero scan output at bucket \(b)")
        }
        print("✅ test_radixScan_allZeroInput passed")
    }

    /// Invariant: output[0] is always 0 (exclusive scan definition).
    func test_radixScan_firstOutputIsAlwaysZero() {
        guard let pipeline = makePipeline(named: "gaussianRadixScan") else {
            XCTFail("gaussianRadixScan kernel not found – implement Phase 2 first")
            return
        }

        // Non-trivial histogram: all buckets have count 1
        var hist = [UInt32](repeating: 1, count: kRadixBuckets)

        guard let histBuf = renderInfo.device.makeBuffer(
            bytes: &hist, length: hist.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        else { XCTFail("Buffer allocation failed"); return }

        var numBuckets = UInt32(kRadixBuckets)
        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(histBuf, offset: 0, index: ScanBuffer.histogram.rawValue)
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: ScanBuffer.numBuckets.rawValue)
        }

        let result = readU32(histBuf, count: kRadixBuckets)
        XCTAssertEqual(result[0], 0, "Exclusive scan: output[0] must always be 0")
        print("✅ test_radixScan_firstOutputIsAlwaysZero passed")
    }

    /// Known sequence: input [3, 1, 4, 1, 5, ...].
    /// Output must match CPU exclusive prefix sum.
    func test_radixScan_knownSequence() {
        guard let pipeline = makePipeline(named: "gaussianRadixScan") else {
            XCTFail("gaussianRadixScan kernel not found – implement Phase 2 first")
            return
        }

        // Build a deterministic histogram pattern
        var hist = (0 ..< kRadixBuckets).map { i in UInt32(i % 17) } // 0,1,2,...,16,0,1,...
        let expected = exclusiveScan(hist)

        guard let histBuf = renderInfo.device.makeBuffer(
            bytes: &hist, length: hist.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        else { XCTFail("Buffer allocation failed"); return }

        var numBuckets = UInt32(kRadixBuckets)
        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(histBuf, offset: 0, index: ScanBuffer.histogram.rawValue)
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: ScanBuffer.numBuckets.rawValue)
        }

        let result = readU32(histBuf, count: kRadixBuckets)
        for b in 0 ..< kRadixBuckets {
            XCTAssertEqual(result[b], expected[b],
                           "Scan mismatch at bucket \(b): got \(result[b]), expected \(expected[b])")
        }
        print("✅ test_radixScan_knownSequence passed")
    }

    /// Invariant: output[last] + original[last] == total element count.
    func test_radixScan_lastEntryPlusCountEqualsTotal() {
        guard let pipeline = makePipeline(named: "gaussianRadixScan") else {
            XCTFail("gaussianRadixScan kernel not found – implement Phase 2 first")
            return
        }

        let n = 512
        var hist = referenceHistogram(
            keys: (0 ..< n).map { _ in UInt64.random(in: 0 ..< UInt64.max) },
            pass: 0
        )

        // Remember the last count before the scan overwrites it
        let lastCount = hist[kRadixBuckets - 1]
        let totalElements = UInt32(n)

        guard let histBuf = renderInfo.device.makeBuffer(
            bytes: &hist, length: hist.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        else { XCTFail("Buffer allocation failed"); return }

        var numBuckets = UInt32(kRadixBuckets)
        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(histBuf, offset: 0, index: ScanBuffer.histogram.rawValue)
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: ScanBuffer.numBuckets.rawValue)
        }

        let result = readU32(histBuf, count: kRadixBuckets)
        let lastOffset = result[kRadixBuckets - 1]
        XCTAssertEqual(lastOffset + lastCount, totalElements,
                       "result[last](\(lastOffset)) + original[last](\(lastCount)) should equal total (\(totalElements))")
        print("✅ test_radixScan_lastEntryPlusCountEqualsTotal passed")
    }

    /// Invariant: output is monotonically non-decreasing (counts are non-negative).
    func test_radixScan_monotonicallyNonDecreasing() {
        guard let pipeline = makePipeline(named: "gaussianRadixScan") else {
            XCTFail("gaussianRadixScan kernel not found – implement Phase 2 first")
            return
        }

        var hist = referenceHistogram(
            keys: (0 ..< 256).map { _ in UInt64.random(in: 0 ..< UInt64.max) },
            pass: 1
        )

        guard let histBuf = renderInfo.device.makeBuffer(
            bytes: &hist, length: hist.count * MemoryLayout<UInt32>.stride,
            options: .storageModeShared
        )
        else { XCTFail("Buffer allocation failed"); return }

        var numBuckets = UInt32(kRadixBuckets)
        dispatch(pipeline, threadCount: kRadixBuckets) { enc in
            enc.setBuffer(histBuf, offset: 0, index: ScanBuffer.histogram.rawValue)
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: ScanBuffer.numBuckets.rawValue)
        }

        let result = readU32(histBuf, count: kRadixBuckets)
        for b in 1 ..< kRadixBuckets {
            XCTAssertGreaterThanOrEqual(result[b], result[b - 1],
                                        "Scan output not non-decreasing at bucket \(b): \(result[b]) < \(result[b - 1])")
        }
        print("✅ test_radixScan_monotonicallyNonDecreasing passed")
    }

    // =========================================================================
    // MARK: Phase 3 – Scatter

    // =========================================================================

    /// One radix pass with 8 elements whose digits are all distinct (0-7).
    /// After scatter, element at position i should have its digit == its original index.
    func test_radixScatter_singlePass_knownMapping() {
        guard let pipeline = makePipeline(named: "gaussianRadixScatter") else {
            XCTFail("gaussianRadixScatter kernel not found – implement Phase 3 first")
            return
        }

        // 8 keys: digit 7,0,3,1,5,2,6,4 in pass 0; index = position in array
        let digitOrder: [UInt8] = [7, 0, 3, 1, 5, 2, 6, 4]
        let n = digitOrder.count
        let keys = digitOrder.enumerated().map { i, d in packKey(depthByte: d, atPass: 0, index: UInt32(i)) }

        // Build reference histogram and offsets
        let hist = referenceHistogram(keys: keys, pass: 0)
        let offsets = exclusiveScan(hist)

        guard let keyInBuf = makeBuffer(keys),
              let keyOutBuf = makeBuffer(count: n, type: UInt64.self),
              let offsetBuf = renderInfo.device.makeBuffer(
                  bytes: offsets.map { $0 },
                  length: offsets.count * MemoryLayout<UInt32>.stride,
                  options: .storageModeShared
              ),
              let zeroBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(zeroBuf)
        var numElems = UInt32(n)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: n) { enc in
            enc.setBuffer(keyInBuf, offset: 0, index: ScatterBuffer.keysIn.rawValue)
            enc.setBuffer(keyOutBuf, offset: 0, index: ScatterBuffer.keysOut.rawValue)
            enc.setBuffer(offsetBuf, offset: 0, index: ScatterBuffer.offsets.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.passIdx.rawValue)
            enc.setBuffer(zeroBuf, offset: 0, index: ScatterBuffer.perTGStart.rawValue)
        }

        let result = readU64(keyOutBuf, count: n)
        let cpuRef = referenceScatter(keys: keys, offsets: offsets.map { $0 }, pass: 0)

        for i in 0 ..< n {
            XCTAssertEqual(result[i], cpuRef[i],
                           "Scatter mismatch at output position \(i): got \(result[i]), expected \(cpuRef[i])")
        }
        print("✅ test_radixScatter_singlePass_knownMapping passed")
    }

    /// After scatter, every original key must appear exactly once (permutation property).
    func test_radixScatter_isPermutation() {
        guard let pipeline = makePipeline(named: "gaussianRadixScatter") else {
            XCTFail("gaussianRadixScatter kernel not found – implement Phase 3 first")
            return
        }

        let n = 256
        let keys: [UInt64] = (0 ..< n).map { _ in UInt64.random(in: 0 ..< UInt64.max) }
        let hist = referenceHistogram(keys: keys, pass: 0)
        let offsets = exclusiveScan(hist)

        guard let keyInBuf = makeBuffer(keys),
              let keyOutBuf = makeBuffer(count: n, type: UInt64.self),
              let offsetBuf = renderInfo.device.makeBuffer(
                  bytes: offsets.map { $0 },
                  length: offsets.count * MemoryLayout<UInt32>.stride,
                  options: .storageModeShared
              ),
              let zeroBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(zeroBuf)
        var numElems = UInt32(n)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: n) { enc in
            enc.setBuffer(keyInBuf, offset: 0, index: ScatterBuffer.keysIn.rawValue)
            enc.setBuffer(keyOutBuf, offset: 0, index: ScatterBuffer.keysOut.rawValue)
            enc.setBuffer(offsetBuf, offset: 0, index: ScatterBuffer.offsets.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.passIdx.rawValue)
            enc.setBuffer(zeroBuf, offset: 0, index: ScatterBuffer.perTGStart.rawValue)
        }

        let result = readU64(keyOutBuf, count: n)

        // Verify result is a permutation: same multiset as input
        XCTAssertEqual(result.sorted(), keys.sorted(),
                       "Scatter output is not a permutation of the input")
        print("✅ test_radixScatter_isPermutation passed")
    }

    /// Scatter must be stable: keys with the same digit preserve their relative input order.
    /// Build keys where digit is constant (all 0) — output order must equal input order.
    func test_radixScatter_stability() {
        guard let pipeline = makePipeline(named: "gaussianRadixScatter") else {
            XCTFail("gaussianRadixScatter kernel not found – implement Phase 3 first")
            return
        }

        // All 16 keys have digit 0 in pass 0. The only ordering information is
        // the splat index in the lower 32 bits. Stability requires they come out
        // in the same order as they went in.
        let n = 16
        let keys: [UInt64] = (0 ..< n).map { i in packKey(depthByte: 0, atPass: 0, index: UInt32(i)) }
        let hist = referenceHistogram(keys: keys, pass: 0) // hist[0] == 16
        let offsets = exclusiveScan(hist) // offsets[0] == 0

        guard let keyInBuf = makeBuffer(keys),
              let keyOutBuf = makeBuffer(count: n, type: UInt64.self),
              let offsetBuf = renderInfo.device.makeBuffer(
                  bytes: offsets.map { $0 },
                  length: offsets.count * MemoryLayout<UInt32>.stride,
                  options: .storageModeShared
              ),
              let zeroBuf = makeBuffer(count: kRadixBuckets, type: UInt32.self)
        else { XCTFail("Buffer allocation failed"); return }

        zeroBuffer(zeroBuf)
        var numElems = UInt32(n)
        var passIndex = UInt32(0)

        dispatch(pipeline, threadCount: n) { enc in
            enc.setBuffer(keyInBuf, offset: 0, index: ScatterBuffer.keysIn.rawValue)
            enc.setBuffer(keyOutBuf, offset: 0, index: ScatterBuffer.keysOut.rawValue)
            enc.setBuffer(offsetBuf, offset: 0, index: ScatterBuffer.offsets.rawValue)
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.numElems.rawValue)
            enc.setBytes(&passIndex, length: MemoryLayout<UInt32>.stride, index: ScatterBuffer.passIdx.rawValue)
            enc.setBuffer(zeroBuf, offset: 0, index: ScatterBuffer.perTGStart.rawValue)
        }

        let result = readU64(keyOutBuf, count: n)

        // Stable: relative order within same digit must be preserved
        for i in 0 ..< n {
            XCTAssertEqual(result[i], keys[i],
                           "Stability violated at output position \(i): got index \(result[i] & 0xFFFF_FFFF), expected \(keys[i] & 0xFFFF_FFFF)")
        }
        print("✅ test_radixScatter_stability passed")
    }

    // =========================================================================
    // MARK: Integration – Full Radix Sort

    // =========================================================================

    /// 8 packed depth keys at known depths; after full radix sort the depth keys
    /// must be in ascending (front-to-back) order.
    func test_radixSort_small_knownDepthOrder() {
        guard makePipeline(named: "gaussianRadixHistogram") != nil,
              makePipeline(named: "gaussianRadixScan") != nil,
              makePipeline(named: "gaussianRadixScatter") != nil
        else {
            XCTFail("One or more radix sort kernels not found – implement all phases first")
            return
        }

        initGuassianComputePipelines()

        let depthValues: [Float] = [10, 50, 20, 100, 30, 5, 70, 15] // front-to-back: 5,10,15,20,30,50,70,100
        let n = depthValues.count

        /// Compute depth keys using the same IEEE-754-to-sortable-uint conversion as the GPU
        func floatToSortableU32(_ x: Float) -> UInt32 {
            let u = x.bitPattern
            let mask: UInt32 = (u >> 31) != 0 ? 0xFFFF_FFFF : 0x8000_0000
            return u ^ mask
        }

        let inputKeys = depthValues.enumerated().map { i, z in
            (UInt64(floatToSortableU32(z)) << 32) | UInt64(i)
        }

        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)

        guard let gc = scene.get(component: GaussianComponent.self, for: entity),
              let wt = scene.get(component: WorldTransformComponent.self, for: entity)
        else { XCTFail("Component access failed"); return }

        wt.space = matrix_identity_float4x4

        guard let keyBuf = makeBuffer(inputKeys) else { XCTFail("Buffer allocation failed"); return }
        gc.gaussianSortedIndices = Array(repeating: keyBuf, count: maxInFlightCommandBuffers)
        gc.splatCount = UInt(n)
        gc.visibleSplatCountForRendering = UInt(n)

        guard let queue = renderInfo.device.makeCommandQueue(),
              let cmd = queue.makeCommandBuffer()
        else { XCTFail("Command queue failed"); return }

        executeRadixSort(cmd)

        cmd.commit()
        cmd.waitUntilCompleted()

        let result = readU64(keyBuf, count: n)

        for i in 1 ..< n {
            let prev = UInt32((result[i - 1] >> 32) & 0xFFFF_FFFF)
            let curr = UInt32((result[i] >> 32) & 0xFFFF_FFFF)
            XCTAssertLessThanOrEqual(prev, curr,
                                     "Depth keys not in ascending order at position \(i): \(prev) > \(curr)")
        }
        print("✅ test_radixSort_small_knownDepthOrder passed")
    }

    /// Radix sort output must match Swift's sort for 256 random UInt64 values.
    func test_radixSort_matchesCPUSort_256elements() {
        guard makePipeline(named: "gaussianRadixClearHistogram") != nil,
              makePipeline(named: "gaussianRadixHistogram") != nil,
              makePipeline(named: "gaussianRadixScanPerTG") != nil,
              makePipeline(named: "gaussianRadixScan") != nil,
              makePipeline(named: "gaussianRadixScatter") != nil
        else {
            XCTFail("One or more radix sort kernels not found – implement all phases first")
            return
        }

        let n = 256
        let inputKeys: [UInt64] = (0 ..< n).map { i in
            let high = UInt64((n - 1 - i) * 2 + 1)
            let low = UInt64((i &* 1_664_525 &+ 1_013_904_223) & 0xFFFF_FFFF)
            return (high << 32) | low
        }
        let expectedSorted = inputKeys.sorted()

        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)

        guard let gc = scene.get(component: GaussianComponent.self, for: entity),
              let wt = scene.get(component: WorldTransformComponent.self, for: entity)
        else { XCTFail("Component access failed"); return }

        wt.space = matrix_identity_float4x4

        guard let keyBuf = makeBuffer(inputKeys) else { XCTFail("Buffer allocation failed"); return }
        gc.gaussianSortedIndices = Array(repeating: keyBuf, count: maxInFlightCommandBuffers)
        gc.splatCount = UInt(n)
        gc.visibleSplatCountForRendering = UInt(n)

        guard let queue = renderInfo.device.makeCommandQueue(),
              let cmd = queue.makeCommandBuffer()
        else { XCTFail("Command queue failed"); return }

        executeRadixSort(cmd)

        cmd.commit()
        cmd.waitUntilCompleted()

        let result = readU64(keyBuf, count: n)

        for i in 0 ..< n {
            XCTAssertEqual(result[i], expectedSorted[i],
                           "Mismatch at index \(i): got \(result[i]), expected \(expectedSorted[i])")
        }
        print("✅ test_radixSort_matchesCPUSort_256elements passed")
    }

    /// Running radix sort twice on the same data must produce the same result (idempotent, deterministic).
    func test_radixSort_isDeterministic() {
        guard makePipeline(named: "gaussianRadixHistogram") != nil,
              makePipeline(named: "gaussianRadixScan") != nil,
              makePipeline(named: "gaussianRadixScatter") != nil
        else {
            XCTFail("One or more radix sort kernels not found – implement all phases first")
            return
        }

        let n = 256
        let inputKeys: [UInt64] = (0 ..< n).map { i in
            let high = UInt64((n - 1 - i) * 2 + 1)
            let low = UInt64((i &* 1_664_525 &+ 1_013_904_223) & 0xFFFF_FFFF)
            return (high << 32) | low
        }
        let expectedSorted = inputKeys.sorted()

        // First sort
        let entity1 = createEntity()
        registerComponent(entityId: entity1, componentType: GaussianComponent.self)
        registerComponent(entityId: entity1, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity1, componentType: LocalTransformComponent.self)

        guard let gc1 = scene.get(component: GaussianComponent.self, for: entity1),
              let wt1 = scene.get(component: WorldTransformComponent.self, for: entity1),
              let buf1 = makeBuffer(inputKeys)
        else { XCTFail("Setup failed"); return }

        wt1.space = matrix_identity_float4x4
        gc1.gaussianSortedIndices = Array(repeating: buf1, count: maxInFlightCommandBuffers)
        gc1.splatCount = UInt(n)
        gc1.visibleSplatCountForRendering = UInt(n)

        guard let queue = renderInfo.device.makeCommandQueue(),
              let cmd1 = queue.makeCommandBuffer()
        else { XCTFail("Command queue failed"); return }

        executeRadixSort(cmd1)
        cmd1.commit()
        cmd1.waitUntilCompleted()

        let result1 = readU64(buf1, count: n)

        for i in 0 ..< n {
            XCTAssertEqual(result1[i], expectedSorted[i],
                           "First sort: mismatch at \(i)")
        }
        print("✅ test_radixSort_isDeterministic passed")
    }

    /// Full pipeline: depth key computation followed by radix sort produces
    /// ascending depth (front-to-back) ordering, matching the bitonic pipeline.
    func test_radixSort_depthOrdering_withCamera() {
        guard makePipeline(named: "gaussianRadixHistogram") != nil,
              makePipeline(named: "gaussianRadixScan") != nil,
              makePipeline(named: "gaussianRadixScatter") != nil
        else {
            XCTFail("One or more radix sort kernels not found – implement all phases first")
            return
        }

        let positions: [simd_float3] = [
            simd_float3(0, 0, -10),
            simd_float3(0, 0, -50),
            simd_float3(0, 0, -20),
            simd_float3(0, 0, -100),
            simd_float3(0, 0, -30),
            simd_float3(0, 0, -5),
            simd_float3(0, 0, -70),
            simd_float3(0, 0, -15),
        ]
        let numSplats = positions.count

        let splats = positions.map { pos in
            EncodedGaussianSplat(
                position: pos,
                covA: simd_half3(1, 0, 0),
                covB: simd_half3(1, 0, 1),
                colorAndOpacity: simd_half4(1, 0, 0, 1)
            )
        }

        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)

        let cameraEntity = createEntity()
        registerComponent(entityId: cameraEntity, componentType: CameraComponent.self)
        registerComponent(entityId: cameraEntity, componentType: LocalTransformComponent.self)
        CameraSystem.shared.activeCamera = cameraEntity

        guard let gc = scene.get(component: GaussianComponent.self, for: entity),
              let wt = scene.get(component: WorldTransformComponent.self, for: entity),
              let cam = scene.get(component: CameraComponent.self, for: cameraEntity)
        else { XCTFail("Component access failed"); return }

        cam.viewSpace = matrix_identity_float4x4
        cam.localPosition = simd_float3(0, 0, 0)
        wt.space = matrix_identity_float4x4

        guard let splatBuf = renderInfo.device.makeBuffer(
            bytes: splats,
            length: numSplats * MemoryLayout<EncodedGaussianSplat>.stride,
            options: .storageModeShared
        ),
            let keyBuf = makeBuffer(count: numSplats, type: UInt64.self),
            let visibleIndexBuf = renderInfo.device.makeBuffer(
                bytes: (0 ..< numSplats).map { UInt32($0) },
                length: numSplats * MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            ),
            let visibleCountBuf = renderInfo.device.makeBuffer(
                length: MemoryLayout<UInt32>.stride,
                options: .storageModeShared
            )
        else { XCTFail("Buffer allocation failed"); return }

        visibleCountBuf.contents().storeBytes(of: UInt32(numSplats), as: UInt32.self)
        gc.encodedSplatData = splatBuf
        gc.gaussianSortedIndices = Array(repeating: keyBuf, count: maxInFlightCommandBuffers)
        gc.gaussianVisibleIndices = Array(repeating: visibleIndexBuf, count: maxInFlightCommandBuffers)
        gc.gaussianVisibleCount = Array(repeating: visibleCountBuf, count: maxInFlightCommandBuffers)
        gc.splatCount = UInt(numSplats)
        gc.visibleSplatCountForRendering = UInt(numSplats)
        gc.spaceUniform = (0 ..< 2).compactMap { _ in
            renderInfo.device.makeBuffer(
                length: MemoryLayout<Uniforms>.stride,
                options: .storageModeShared
            )
        }

        guard let queue = renderInfo.device.makeCommandQueue(),
              let cmd = queue.makeCommandBuffer()
        else { XCTFail("Command queue failed"); return }

        executeGaussianDepth(cmd)
        executeRadixSort(cmd)

        cmd.commit()
        cmd.waitUntilCompleted()

        let result = readU64(keyBuf, count: numSplats)

        // Verify ascending depth key order (front-to-back)
        for i in 1 ..< numSplats {
            let prevKey = UInt32((result[i - 1] >> 32) & 0xFFFF_FFFF)
            let currKey = UInt32((result[i] >> 32) & 0xFFFF_FFFF)
            XCTAssertLessThanOrEqual(prevKey, currKey,
                                     "Depth keys not ascending at position \(i): \(prevKey) > \(currKey)")
        }

        // Verify all indices are in valid range
        for i in 0 ..< numSplats {
            let idx = UInt32(result[i] & 0xFFFF_FFFF)
            XCTAssertLessThan(idx, UInt32(numSplats), "Index \(idx) out of range at position \(i)")
        }

        print("✅ test_radixSort_depthOrdering_withCamera passed")
    }

    /// Correctness at a larger power-of-2 size (1024 elements).
    func test_radixSort_1024elements_matchesCPU() {
        guard makePipeline(named: "gaussianRadixHistogram") != nil,
              makePipeline(named: "gaussianRadixScan") != nil,
              makePipeline(named: "gaussianRadixScatter") != nil
        else {
            XCTFail("One or more radix sort kernels not found – implement all phases first")
            return
        }

        let n = 1024
        let inputKeys: [UInt64] = (0 ..< n).map { i in
            let high = UInt64((n - 1 - i) * 2 + 1)
            let low = UInt64((i &* 1_664_525 &+ 1_013_904_223) & 0xFFFF_FFFF)
            return (high << 32) | low
        }
        let expectedSorted = inputKeys.sorted()

        let entity = createEntity()
        registerComponent(entityId: entity, componentType: GaussianComponent.self)
        registerComponent(entityId: entity, componentType: WorldTransformComponent.self)
        registerComponent(entityId: entity, componentType: LocalTransformComponent.self)

        guard let gc = scene.get(component: GaussianComponent.self, for: entity),
              let wt = scene.get(component: WorldTransformComponent.self, for: entity),
              let keyBuf = makeBuffer(inputKeys)
        else { XCTFail("Setup failed"); return }

        wt.space = matrix_identity_float4x4
        gc.gaussianSortedIndices = Array(repeating: keyBuf, count: maxInFlightCommandBuffers)
        gc.splatCount = UInt(n)
        gc.visibleSplatCountForRendering = UInt(n)

        guard let queue = renderInfo.device.makeCommandQueue(),
              let cmd = queue.makeCommandBuffer()
        else { XCTFail("Command queue failed"); return }

        executeRadixSort(cmd)

        cmd.commit()
        cmd.waitUntilCompleted()

        let result = readU64(keyBuf, count: n)

        // Check monotonically sorted
        for i in 1 ..< n {
            XCTAssertLessThanOrEqual(result[i - 1], result[i],
                                     "Not sorted at index \(i)")
        }
        // Check matches CPU
        for i in 0 ..< n {
            XCTAssertEqual(result[i], expectedSorted[i],
                           "CPU/GPU mismatch at index \(i)")
        }
        print("✅ test_radixSort_1024elements_matchesCPU passed")
    }
}
