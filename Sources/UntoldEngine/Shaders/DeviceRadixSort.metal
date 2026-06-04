//
//  DeviceRadixSort.metal
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <metal_stdlib>
#include "../../CShaderTypes/ShaderTypes.h"
using namespace metal;

// ---------------------------------------------------------------------------
// Phase 0 – Clear Histogram
//
// Zeroes the 256-element global histogram buffer before each radix pass.
// Implemented as a compute kernel (not a blit encoder) so that all four
// passes — clear, histogram, per-TG scan, global scan, scatter — can be
// encoded into a single MTLComputeCommandEncoder, eliminating 19 encoder
// boundary stalls per entity per frame.
//
// Dispatch: 1 threadgroup of 256 threads.
// ---------------------------------------------------------------------------

kernel void gaussianRadixClearHistogram(
    device uint *histogram [[buffer(radixClearHistogramBuffer)]],
    uint lid [[thread_position_in_grid]]
) {
    if (lid < 256u) {
        histogram[lid] = 0u;
    }
}

// ---------------------------------------------------------------------------
// Phase 1 – Histogram
//
// Counts digit occurrences per radix pass.  Pass i extracts bits
// (32 + i*8)..(39 + i*8) from the packed UInt64 key:
//
//   pass 0 → bits 32-39  (LSB of the 32-bit depth key)
//   pass 3 → bits 56-63  (MSB of the 32-bit depth key)
//
// Each threadgroup builds a local histogram in threadgroup shared memory,
// then writes two outputs:
//
//   1. global histogram[256]    – accumulated via atomic adds (for the
//                                  global exclusive scan in Phase 2)
//   2. perTGHistograms[gid×256] – direct store of this threadgroup's local
//                                  counts (for the per-TG scan in Phase 1.5)
//
// The caller zeroes histogram[256] before dispatch; perTGHistograms is
// fully overwritten by the kernel so no pre-clearing is needed.
// ---------------------------------------------------------------------------

kernel void gaussianRadixHistogram(
    device uint64_t    *keysIn          [[buffer(radixHistogramKeysIn)]],
    device atomic_uint *histogram       [[buffer(radixHistogramOutput)]],
    constant uint      &numElems        [[buffer(radixHistogramNumElems)]],
    constant uint      &passIndex       [[buffer(radixHistogramPassIndex)]],
    device uint        *perTGHistograms [[buffer(radixHistogramPerTGOut)]],
    uint tid     [[thread_position_in_grid]],
    uint lid     [[thread_position_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup atomic_uint localHist[256];

    for (uint i = lid; i < 256u; i += blockSize) {
        atomic_store_explicit(&localHist[i], 0u, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (tid < numElems) {
        uint64_t key = keysIn[tid];
        uint shift   = 32u + passIndex * 8u;
        uint digit   = (uint)(key >> shift) & 0xFFu;
        atomic_fetch_add_explicit(&localHist[digit], 1u, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Write per-TG local counts AND accumulate into global histogram
    for (uint i = lid; i < 256u; i += blockSize) {
        uint count = atomic_load_explicit(&localHist[i], memory_order_relaxed);
        perTGHistograms[groupId * 256u + i] = count;
        if (count > 0u) {
            atomic_fetch_add_explicit(&histogram[i], count, memory_order_relaxed);
        }
    }
}

// ---------------------------------------------------------------------------
// Phase 1.5 – Per-Threadgroup Column Scan
//
// Converts perTGHistograms[numGroups × 256] in-place to exclusive prefix
// sums along each digit column.  After this kernel:
//
//   perTGHistograms[g × 256 + d] = sum of histogram counts for digit d
//                                    in threadgroups 0 .. g-1
//
// Dispatch: 256 threads in one threadgroup (one thread per digit column).
// Each thread sequentially scans its column over numGroups rows.
// ---------------------------------------------------------------------------

kernel void gaussianRadixScanPerTG(
    device uint   *perTGHist  [[buffer(radixScanPerTGBuffer)]],
    constant uint &numGroups  [[buffer(radixScanPerTGNumGroups)]],
    uint digit [[thread_position_in_grid]]
) {
    if (digit >= 256u) return;

    uint running = 0u;
    for (uint g = 0u; g < numGroups; g++) {
        uint count = perTGHist[g * 256u + digit];   // read original count
        perTGHist[g * 256u + digit] = running;      // overwrite with prefix sum
        running += count;
    }
}

// ---------------------------------------------------------------------------
// Phase 2 – Global Exclusive Scan (Blelloch work-efficient prefix sum)
//
// Converts the global histogram[256] into exclusive prefix sums in-place.
// histogram[d] becomes the starting output index for all elements with
// digit d across the entire key array.
//
// Dispatch: one threadgroup of 256 threads.
// ---------------------------------------------------------------------------

kernel void gaussianRadixScan(
    device uint   *histogram  [[buffer(radixScanHistogram)]],
    constant uint &numBuckets [[buffer(radixScanNumBuckets)]],
    uint lid [[thread_position_in_threadgroup]]
) {
    threadgroup uint temp[256];
    if (lid < numBuckets) {
        temp[lid] = histogram[lid];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Up-sweep
    for (uint stride = 1u; stride < numBuckets; stride <<= 1u) {
        uint idx = (lid + 1u) * (stride << 1u) - 1u;
        if (idx < numBuckets) {
            temp[idx] += temp[idx - stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (lid == 0u) {
        temp[numBuckets - 1u] = 0u;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Down-sweep
    for (uint stride = numBuckets >> 1u; stride > 0u; stride >>= 1u) {
        uint idx = (lid + 1u) * (stride << 1u) - 1u;
        if (idx < numBuckets) {
            uint left          = temp[idx - stride];
            temp[idx - stride] = temp[idx];
            temp[idx]          = temp[idx] + left;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (lid < numBuckets) {
        histogram[lid] = temp[lid];
    }
}

// ---------------------------------------------------------------------------
// Phase 3 – Stable Multi-Threadgroup Scatter
//
// Reorders keys stably using:
//
//   outputPos = globalOffsets[d] + perTGStart[groupId × 256 + d] + localRank
//
// where:
//   globalOffsets[d]          = starting output index for digit d (Phase 2)
//   perTGStart[gid × 256 + d] = how many elements with digit d appear in
//                                threadgroups 0..gid-1 (Phase 1.5)
//   localRank                 = position of this element among same-digit
//                                elements within this threadgroup (in input order)
//
// Thread 0 assigns localRanks sequentially in input order (stability),
// stores them in outputPos[], then all threads scatter in parallel.
//
// Dispatch: ceil(N / 256) threadgroups of 256 threads each.
// RADIX_SCATTER_BLOCK must be ≥ 256 (the block size used at dispatch).
// ---------------------------------------------------------------------------

#define RADIX_SCATTER_BLOCK 256

kernel void gaussianRadixScatter(
    device uint64_t *keysIn    [[buffer(radixScatterKeysIn)]],
    device uint64_t *keysOut   [[buffer(radixScatterKeysOut)]],
    device uint     *offsets   [[buffer(radixScatterOffsets)]],
    constant uint   &numElems  [[buffer(radixScatterNumElems)]],
    constant uint   &passIndex [[buffer(radixScatterPassIdx)]],
    device uint     *perTGStart [[buffer(radixScatterPerTGStart)]],
    uint tid     [[thread_position_in_grid]],
    uint lid     [[thread_position_in_threadgroup]],
    uint groupId [[threadgroup_position_in_grid]],
    uint blockSize [[threads_per_threadgroup]]
) {
    threadgroup uint64_t sharedKeys[RADIX_SCATTER_BLOCK];
    threadgroup uint     outputPos[RADIX_SCATTER_BLOCK];
    threadgroup uint     localCounts[256];

    uint chunkStart = groupId * blockSize;
    uint chunkEnd   = min(chunkStart + blockSize, numElems);
    uint chunkSize  = (chunkEnd > chunkStart) ? (chunkEnd - chunkStart) : 0u;

    if (lid < chunkSize) {
        sharedKeys[lid] = keysIn[chunkStart + lid];
    }

    // Seed running counter = global start + this threadgroup's per-digit start
    for (uint i = lid; i < 256u; i += blockSize) {
        localCounts[i] = offsets[i] + perTGStart[groupId * 256u + i];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Thread 0: walk the chunk in input order, assign output positions stably
    if (lid == 0u) {
        uint shift = 32u + passIndex * 8u;
        for (uint i = 0u; i < chunkSize; i++) {
            uint d = (uint)(sharedKeys[i] >> shift) & 0xFFu;
            outputPos[i] = localCounts[d]++;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (lid < chunkSize) {
        keysOut[outputPos[lid]] = sharedKeys[lid];
    }
}
