//
//  GPUKernelTests.swift
//
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
@testable import UntoldEngine
import XCTest

final class GpuKernelTests: XCTestCase {
    var renderer: UntoldRenderer!
    var window: NSWindow!

    var pLocal: MTLComputePipelineState!
    var pBlock: MTLComputePipelineState!
    var pCompact: MTLComputePipelineState!

    let BLOCK_SIZE = 256

    override func setUp() {
        super.setUp()
        let windowWidth = 1280
        let windowHeight = 720
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)

        window.title = "Test Window"

        // Initialize the renderer
        guard let renderer = UntoldRenderer.create() else {
            XCTFail("Failed to initialize the renderer.")
            return
        }

        window.contentView = renderer.metalView

        self.renderer = renderer

        // Initialize resources
        self.renderer.initResources()

        pLocal = reduceScanLocalScanPipeline.pipelineState
        pBlock = reduceScanBlockScanPipeline.pipelineState
        pCompact = reduceScanScatterCompactedPipeline.pipelineState
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - CPU reference

    /// Exclusive scan over flags: out[i] = sum_{j<i} flags[j]
    private func cpuExclusiveScan(_ flags: [UInt32]) -> [UInt32] {
        var out = Array(repeating: 0 as UInt32, count: flags.count)
        var acc: UInt32 = 0
        for i in 0 ..< flags.count {
            out[i] = acc
            acc &+= flags[i]
        }
        return out
    }

    private func cpuBlockSums(flags: [UInt32], blockSize: Int) -> [UInt32] {
        let blocks = (flags.count + blockSize - 1) / blockSize
        var sums = Array(repeating: 0 as UInt32, count: blocks)
        for b in 0 ..< blocks {
            let lo = b * blockSize
            let hi = min(flags.count, lo + blockSize)
            var s: UInt32 = 0
            for i in lo ..< hi {
                s &+= flags[i]
            }
            sums[b] = s
        }
        return sums
    }

    private func cpuExclusiveScanBlocks(_ blockSums: [UInt32]) -> [UInt32] {
        cpuExclusiveScan(blockSums)
    }

    private func cpuCompactPairs(flags: [UInt32]) -> [(UInt32, UInt32)] {
        var out: [(UInt32, UInt32)] = []
        out.reserveCapacity(Int(flags.reduce(0 as UInt32, +)))
        for (i, f) in flags.enumerated() where f != 0 {
            out.append((UInt32(i), 0)) // (index=i, version=0) for predictable validation
        }
        return out
    }

    struct EntityAABB {
        var center: simd_float4
        var halfExtent: simd_float4
        var index: UInt32
        var version: UInt32
        var pad0: UInt32
        var pad1: UInt32
    }

    // Core test helper

    private struct SeededRNG {
        private var state: UInt64
        init(_ seed: UInt64) { state = seed == 0 ? 0x554E544F4C44 : seed } // "UNTOLD" :)
        mutating func next() -> UInt32 {
            state ^= state << 13; state ^= state >> 7; state ^= state << 17
            return UInt32(truncatingIfNeeded: state)
        }
    }

    private func reduceAndScan(flags: [UInt32]) {
        let N = flags.count
        let numBlocks = (N + BLOCK_SIZE - 1) / BLOCK_SIZE
        let nBytesU32 = MemoryLayout<UInt32>.stride

        // --- CPU reference ---
        _ = cpuExclusiveScan(flags)
        let refBlockSums = cpuBlockSums(flags: flags, blockSize: BLOCK_SIZE)
        _ = cpuExclusiveScanBlocks(refBlockSums)
        let refPairs = cpuCompactPairs(flags: flags).map { Pair(index: $0.0, version: $0.1) }
        let refVisibleCnt = UInt32(refPairs.count)

        // --- Buffers (GPU) ---
        // Private buffers, like your code
        let flagsBufPriv = renderInfo.device.makeBuffer(length: nBytesU32 * N, options: .storageModePrivate)!
        let indicesBufPriv = renderInfo.device.makeBuffer(length: nBytesU32 * N, options: .storageModePrivate)! // holds local/exclusive indices
        let blockSumsBufPriv = renderInfo.device.makeBuffer(length: nBytesU32 * numBlocks, options: .storageModePrivate)!
        let blockOffsBufPriv = renderInfo.device.makeBuffer(length: nBytesU32 * numBlocks, options: .storageModePrivate)!

        let visibleCountBuf = renderInfo.device.makeBuffer(length: nBytesU32, options: .storageModeShared)! // readback
        let visibilityBuf = renderInfo.device.makeBuffer(length: MemoryLayout<VisibleEntity>.stride * N, options: .storageModeShared)!

        // Staging upload (shared) for flags and AABBs
        let flagsStage = renderInfo.device.makeBuffer(bytes: flags, length: nBytesU32 * N, options: .storageModeShared)!

        // AABBs: make predictable (index=i, version=0)
        var aabbs: [EntityAABB] = (0 ..< N).map { i in
            EntityAABB(center: .init(0, 0, 0, 0),
                       halfExtent: .init(0, 0, 0, 0),
                       index: UInt32(i),
                       version: 0,
                       pad0: 0, pad1: 0)
        }
        let aabbStage = renderInfo.device.makeBuffer(bytes: &aabbs, length: MemoryLayout<EntityAABB>.stride * N, options: .storageModeShared)!
        let aabbPriv = renderInfo.device.makeBuffer(length: MemoryLayout<EntityAABB>.stride * N, options: .storageModePrivate)!

        // --- Command buffer ---
        let cmd = renderInfo.commandQueue.makeCommandBuffer()!

        // Upload to private
        let blit = cmd.makeBlitCommandEncoder()!
        blit.copy(from: flagsStage, sourceOffset: 0, to: flagsBufPriv, destinationOffset: 0, size: nBytesU32 * N)
        blit.copy(from: aabbStage, sourceOffset: 0, to: aabbPriv, destinationOffset: 0, size: MemoryLayout<EntityAABB>.stride * N)
        blit.fill(buffer: visibleCountBuf, range: 0 ..< nBytesU32, value: 0)
        blit.endEncoding()

        // ---- Local Scan pass ----
        do {
            let enc = cmd.makeComputeCommandEncoder()!
            enc.label = "Local Scan Pass"
            enc.setComputePipelineState(pLocal)
            enc.setBuffer(flagsBufPriv, offset: 0, index: Int(scanLocalPassFlagIndex.rawValue))
            enc.setBuffer(indicesBufPriv, offset: 0, index: Int(scanLocalPassIndicesIndex.rawValue))
            enc.setBuffer(blockSumsBufPriv, offset: 0, index: Int(scanLocalPassBlockSumsIndex.rawValue))
            var count32 = UInt32(N)
            enc.setBytes(&count32, length: nBytesU32, index: Int(scanLocalPassCountIndex.rawValue))

            // num threadgroups = numBlocks, threadsPerTG = BLOCK_SIZE
            enc.dispatchThreadgroups(MTLSize(width: numBlocks, height: 1, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: BLOCK_SIZE, height: 1, depth: 1))
            enc.endEncoding()
        }

        // ---- Block Scan (scan block sums) ----
        do {
            let enc = cmd.makeComputeCommandEncoder()!
            enc.label = "Block Scan Pass"
            enc.setComputePipelineState(pBlock)
            enc.setBuffer(blockSumsBufPriv, offset: 0, index: Int(scanBlockSumPassSumIndex.rawValue))
            enc.setBuffer(blockOffsBufPriv, offset: 0, index: Int(scanBlockSumPassOffsetIndex.rawValue))
            var nbU32 = UInt32(numBlocks)
            enc.setBytes(&nbU32, length: 4, index: 2)

            // power-of-two threads up to 1024 (as in your code)
            var threads = 1
            while threads < numBlocks {
                threads <<= 1
            }
            threads = min(1024, threads)

            enc.dispatchThreadgroups(MTLSize(width: 1, height: 1, depth: 1),
                                     threadsPerThreadgroup: MTLSize(width: threads, height: 1, depth: 1))
            enc.endEncoding()
        }

        // ---- Compact pass ----
        do {
            let enc = cmd.makeComputeCommandEncoder()!
            enc.label = "Compact and Stream Pass"
            enc.setComputePipelineState(pCompact)
            enc.setBuffer(flagsBufPriv, offset: 0, index: Int(compactPassFlagsIndex.rawValue))
            enc.setBuffer(indicesBufPriv, offset: 0, index: Int(compactPassIndicesIndex.rawValue))
            enc.setBuffer(blockOffsBufPriv, offset: 0, index: Int(compactPassBlockOffsetIndex.rawValue))
            enc.setBuffer(aabbPriv, offset: 0, index: Int(compactPassEntityAABBIndex.rawValue))
            var count32 = UInt32(N)
            enc.setBytes(&count32, length: nBytesU32, index: Int(compactPassCountIndex.rawValue))
            enc.setBuffer(visibilityBuf, offset: 0, index: Int(compactPassVisibilityIndicesIndex.rawValue))
            enc.setBuffer(visibleCountBuf, offset: 0, index: Int(compactPassVisibilityCountIndex.rawValue))

            let w = min(pCompact.maxTotalThreadsPerThreadgroup, 256)
            enc.dispatchThreads(MTLSize(width: N, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: w, height: 1, depth: 1))
            enc.endEncoding()
        }

        cmd.commit()
        cmd.waitUntilCompleted()
        
        struct Pair: Equatable {
            var index: UInt32
            var version: UInt32
        }

        // ---- Readback & Assert ----
        let gpuCount = visibleCountBuf.contents().load(as: UInt32.self)
        XCTAssertEqual(gpuCount, refVisibleCnt, "visibleCount mismatch")

        // Only first gpuCount entries are valid
        let visPtr = visibilityBuf.contents().bindMemory(to: VisibleEntity.self, capacity: Int(gpuCount))
        let gpuPairs = (0..<Int(gpuCount)).map { Pair(index: visPtr[$0].index, version: visPtr[$0].version) }
        
        XCTAssertEqual(gpuPairs, refPairs, "compacted output mismatch (order-preserving)")
        
    }

    // --- Tests ---

    func test_pattern_1010_small() {
        let flags: [UInt32] = [1, 0, 1, 0, 1, 0, 1, 0]
        reduceAndScan(flags: flags)
    }

    func test_all_zero() {
        let flags = Array(repeating: 0 as UInt32, count: 257) // tail across 2 blocks
        reduceAndScan(flags: flags)
    }

    func test_all_one() {
        let flags = Array(repeating: 1 as UInt32, count: 257)
        reduceAndScan(flags: flags)
    }

    func test_non_power_of_two_random_fixedSeed() {
        var rng = SeededRNG(42)
        let N = 1000 + 37 // non power of two, crosses blocks
        let flags: [UInt32] = (0 ..< N).map { _ in rng.next() & 1 }
        reduceAndScan(flags: flags)
    }

    func test_edge_touching_block_boundary() {
        // Exactly multiple of BLOCK_SIZE then +1 element
        let N = BLOCK_SIZE * 3 + 1
        var flags = Array(repeating: 0 as UInt32, count: N)
        // sprinkle some 1s around boundaries
        flags[BLOCK_SIZE - 1] = 1
        flags[BLOCK_SIZE] = 1
        flags[BLOCK_SIZE * 2] = 1
        flags[N - 1] = 1
        reduceAndScan(flags: flags)
    }
}
