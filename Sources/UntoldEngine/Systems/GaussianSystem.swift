//
//  GaussianSystem.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

//
//  GaussianSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/10/25.
//

import CShaderTypes
import Foundation
import Metal
import simd

let maxNumOfGaussians: UInt64 = 1024 * 1024 * 5

func initGuassianComputePipelines() {
    if renderInfo.device == nil {
        handleError(.metalDeviceNotFound)
        return
    }

    if renderInfo.library == nil {
        handleError(.metalLibraryNotFound)
        return
    }

    createComputePipeline(into: &gaussianDepthPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianDepthKeys", pipelineName: "Gaussian Depth")

    createComputePipeline(into: &radixClearHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixClearHistogram", pipelineName: "Radix Clear")

    createComputePipeline(into: &radixHistogramPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixHistogram", pipelineName: "Radix Histogram")

    createComputePipeline(into: &radixScanPerTGPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScanPerTG", pipelineName: "Radix ScanPerTG")

    createComputePipeline(into: &radixScanPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScan", pipelineName: "Radix Scan")

    createComputePipeline(into: &radixScatterPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianRadixScatter", pipelineName: "Radix Scatter")
}

public func executeGaussianDepth(_ commandBuffer: MTLCommandBuffer) {
    if gaussianDepthPipeline.success == false {
        handleError(.pipelineStateNulled, gaussianDepthPipeline.name!)
        return
    }

    guard let camera = CameraSystem.shared.activeCamera, let cameraComponent = scene.get(component: CameraComponent.self, for: camera) else {
        handleError(.noActiveCamera)
        return
    }

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Gaussian Depth pass"

    computeEncoder.setComputePipelineState(gaussianDepthPipeline.pipelineState!)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

    for entityId in entities {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }

        guard let worldTransformComponent = scene.get(component: WorldTransformComponent.self, for: entityId) else {
            handleError(.noWorldTransformComponent, entityId)
            continue
        }

        guard scene.get(component: LocalTransformComponent.self, for: entityId) != nil else {
            handleError(.noLocalTransformComponent, entityId)
            continue
        }

        computeEncoder.setBuffer(gaussianComponent.gaussianSortedIndices, offset: 0, index: Int(gaussianIndicesIndex.rawValue))
        computeEncoder.setBuffer(gaussianComponent.splatData, offset: 0, index: Int(gaussianSplatIndex.rawValue))

        // update uniforms
        var gaussianUniform = Uniforms()

        let modelMatrix = simd_mul(worldTransformComponent.space, .identity)

        let viewMatrix: simd_float4x4 = cameraComponent.viewSpace

        let modelViewMatrix = simd_mul(viewMatrix, modelMatrix)

        let upperModelMatrix: matrix_float3x3 = matrix3x3_upper_left(modelMatrix)

        let inverseUpperModelMatrix: matrix_float3x3 = upperModelMatrix.inverse

        let normalMatrix: matrix_float3x3 = inverseUpperModelMatrix.transpose

        gaussianUniform.modelViewMatrix = modelViewMatrix

        gaussianUniform.normalMatrix = normalMatrix

        gaussianUniform.viewMatrix = viewMatrix

        gaussianUniform.modelMatrix = modelMatrix

        gaussianUniform.cameraPosition = cameraComponent.localPosition

        gaussianUniform.projectionMatrix = renderInfo.perspectiveSpace

        guard !gaussianComponent.spaceUniform.isEmpty else {
            handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
            return
        }
        let uniformBufferIndex = min(currentUniformBufferIndex(), gaussianComponent.spaceUniform.count - 1)

        if let gaussianUniformBuffer = gaussianComponent.spaceUniform[uniformBufferIndex] {
            gaussianUniformBuffer.contents().copyMemory(
                from: &gaussianUniform, byteCount: MemoryLayout<Uniforms>.stride
            )
        } else {
            handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
            return
        }

        computeEncoder.setBuffer(
            gaussianComponent.spaceUniform[uniformBufferIndex], offset: 0, index: Int(gaussianUniformIndex.rawValue)
        )

        var localNumGaussians = UInt32(gaussianComponent.splatCount)
        computeEncoder.setBytes(&localNumGaussians, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))

        let tew = gaussianDepthPipeline.pipelineState?.threadExecutionWidth ?? 32
        let maxT = gaussianDepthPipeline.pipelineState?.maxTotalThreadsPerThreadgroup ?? 256
        let target = 256
        var block = min(target, maxT)
        block = (block / tew) * tew
        block = max(block, tew)

        let threadsPerThreadgroup: MTLSize = MTLSizeMake(block, 1, 1)

        // Use dispatchThreadgroups for broader device compatibility (including Vision Pro)
        let numThreadgroups = (Int(gaussianComponent.splatCount) + block - 1) / block
        let threadgroupsPerGrid: MTLSize = MTLSizeMake(numThreadgroups, 1, 1)

        computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    computeEncoder.endEncoding()
}

// MARK: - Device Radix Sort

//
// LSD radix sort over the upper 32 bits of the packed UInt64 key
// [depthKey | splatIndex].  Four passes of 8 bits each (bits 32-63).
//
// Per pass (all encoded into ONE MTLComputeCommandEncoder per entity):
//   0. gaussianRadixClearHistogram – zero histogram[256]          (256 threads)
//   1. gaussianRadixHistogram      – count digits + per-TG counts (N threads)
//   2. gaussianRadixScanPerTG      – exclusive scan per digit col  (256 threads)
//   3. gaussianRadixScan           – global exclusive scan         (256 threads)
//   4. gaussianRadixScatter        – stable reorder                (N threads)
//
// Using one encoder (20 dispatches, 0 blit encoders) eliminates the GPU
// pipeline stalls that come from switching encoder types 20 times per frame.
//
// Block size is fixed at 256 for both histogram and scatter so that
// histGroups == scatterGroups, which is required for correct perTGStart
// indexing (perTGStart[groupId * 256 + digit]).

public func executeRadixSort(_ commandBuffer: MTLCommandBuffer) {
    guard radixClearHistogramPipeline.success else {
        handleError(.pipelineStateNulled, radixClearHistogramPipeline.name!); return
    }
    guard radixHistogramPipeline.success else {
        handleError(.pipelineStateNulled, radixHistogramPipeline.name!); return
    }
    guard radixScanPerTGPipeline.success else {
        handleError(.pipelineStateNulled, radixScanPerTGPipeline.name!); return
    }
    guard radixScanPipeline.success else {
        handleError(.pipelineStateNulled, radixScanPipeline.name!); return
    }
    guard radixScatterPipeline.success else {
        handleError(.pipelineStateNulled, radixScatterPipeline.name!); return
    }

    if radixHistogramBuffer == nil {
        radixHistogramBuffer = renderInfo.device.makeBuffer(
            length: 256 * MemoryLayout<UInt32>.stride, options: .storageModeShared
        )
    }
    guard let histBuffer = radixHistogramBuffer else { return }

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

    // Single compute encoder for all entities and all passes.
    // Dispatches within one encoder execute sequentially on the GPU,
    // so no inter-encoder synchronisation is needed.
    guard let enc = commandBuffer.makeComputeCommandEncoder() else { return }
    enc.label = "Radix Sort"

    for entityId in entities {
        guard let gc = scene.get(component: GaussianComponent.self, for: entityId) else { continue }
        guard let sortedIndices = gc.gaussianSortedIndices else { continue }

        let n = Int(gc.splatCount)
        guard n >= 2 else { continue }

        // Ping-pong temp buffer (CPU alloc before encoding)
        let keyBufLen = n * MemoryLayout<UInt64>.stride
        if radixSortTempBuffer == nil || radixSortTempBuffer!.length < keyBufLen {
            radixSortTempBuffer = renderInfo.device.makeBuffer(
                length: keyBufLen, options: .storageModeShared
            )
        }
        guard let tempBuffer = radixSortTempBuffer else { continue }

        // Fixed block size: histogram and scatter MUST use the same value so
        // that histGroups == scatterGroups and perTGStart indexing is correct.
        let radixBlock = 256
        let numGroups = (n + radixBlock - 1) / radixBlock

        let perTGLen = numGroups * 256 * MemoryLayout<UInt32>.stride
        if radixPerTGHistBuffer == nil || radixPerTGHistBuffer!.length < perTGLen {
            radixPerTGHistBuffer = renderInfo.device.makeBuffer(
                length: perTGLen, options: .storageModeShared
            )
        }
        guard let perTGBuf = radixPerTGHistBuffer else { continue }

        var numElems = UInt32(n)
        var numBuckets = UInt32(256)
        var numGroups32 = UInt32(numGroups)

        for pass in 0 ..< 4 {
            let isEven = (pass % 2 == 0)
            let keysIn = isEven ? sortedIndices : tempBuffer
            let keysOut = isEven ? tempBuffer : sortedIndices
            var passIdx = UInt32(pass)

            // ── 0. Clear histogram ───────────────────────────────────────────
            enc.setComputePipelineState(radixClearHistogramPipeline.pipelineState!)
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixClearHistogramBuffer.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))

            // ── 1. Histogram + per-TG counts ─────────────────────────────────
            enc.setComputePipelineState(radixHistogramPipeline.pipelineState!)
            enc.setBuffer(keysIn, offset: 0, index: Int(radixHistogramKeysIn.rawValue))
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixHistogramOutput.rawValue))
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixHistogramPerTGOut.rawValue))
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: Int(radixHistogramNumElems.rawValue))
            enc.setBytes(&passIdx, length: MemoryLayout<UInt32>.stride, index: Int(radixHistogramPassIndex.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(numGroups, 1, 1), threadsPerThreadgroup: MTLSizeMake(radixBlock, 1, 1))

            // ── 2. Per-TG column scan → per-TG starting offsets ─────────────
            enc.setComputePipelineState(radixScanPerTGPipeline.pipelineState!)
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixScanPerTGBuffer.rawValue))
            enc.setBytes(&numGroups32, length: MemoryLayout<UInt32>.stride, index: Int(radixScanPerTGNumGroups.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))

            // ── 3. Global exclusive scan ─────────────────────────────────────
            enc.setComputePipelineState(radixScanPipeline.pipelineState!)
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixScanHistogram.rawValue))
            enc.setBytes(&numBuckets, length: MemoryLayout<UInt32>.stride, index: Int(radixScanNumBuckets.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: MTLSizeMake(256, 1, 1))

            // ── 4. Stable scatter ────────────────────────────────────────────
            enc.setComputePipelineState(radixScatterPipeline.pipelineState!)
            enc.setBuffer(keysIn, offset: 0, index: Int(radixScatterKeysIn.rawValue))
            enc.setBuffer(keysOut, offset: 0, index: Int(radixScatterKeysOut.rawValue))
            enc.setBuffer(histBuffer, offset: 0, index: Int(radixScatterOffsets.rawValue))
            enc.setBuffer(perTGBuf, offset: 0, index: Int(radixScatterPerTGStart.rawValue))
            enc.setBytes(&numElems, length: MemoryLayout<UInt32>.stride, index: Int(radixScatterNumElems.rawValue))
            enc.setBytes(&passIdx, length: MemoryLayout<UInt32>.stride, index: Int(radixScatterPassIdx.rawValue))
            enc.dispatchThreadgroups(MTLSizeMake(numGroups, 1, 1), threadsPerThreadgroup: MTLSizeMake(radixBlock, 1, 1))
        }
    }

    enc.endEncoding()
}

// MARK: - PLY Loading Helpers

/*
 /// Loads Gaussian splats from a PLY file into the GPU buffer
 public func loadGaussianSplatsFromPLY(url: URL) throws -> Int {
     // Load splats from PLY file
     let splats = try PLYReader.readGaussianSplats(from: url)

     // Check if we exceed the buffer capacity
     guard splats.count <= Int(maxNumOfGaussians) else {
         handleError(.bufferAllocationFailed, "Too many Gaussian splats: \(splats.count) exceeds maximum \(maxNumOfGaussians)")
         throw PLYError.invalidData("Too many Gaussian splats: \(splats.count) exceeds maximum \(maxNumOfGaussians)")
     }

     // Copy to GPU buffer
     guard let splatBuffer = bufferResources.splatData else {
         handleError(.bufferAllocationFailed, "Gaussian splat buffer is nil")
         throw PLYError.invalidData("Gaussian splat buffer not initialized")
     }

     let pointer = splatBuffer.contents().bindMemory(
         to: GaussianSplat.self,
         capacity: splats.count
     )

     for (index, splat) in splats.enumerated() {
         pointer[index] = splat
     }

     // Update current count
     currentNumOfGaussians = splats.count

     print("✓ Loaded \(splats.count) Gaussian splats from \(url.lastPathComponent)")

     return splats.count
 }

 /// Loads Gaussian splats from a PLY file path
 public func loadGaussianSplatsFromPLY(path: String) throws -> Int {
     let url = URL(fileURLWithPath: path)
     return try loadGaussianSplatsFromPLY(url: url)
 }

 /// Loads Gaussian splats from a PLY file in the app bundle
 public func loadGaussianSplatsFromBundle(filename: String, bundle: Bundle = .main) throws -> Int {
     guard let url = bundle.url(forResource: filename, withExtension: "ply") else {
         handleError(.assetDataMissing, "PLY file '\(filename).ply' not found in bundle")
         throw PLYError.invalidFormat("PLY file '\(filename).ply' not found in bundle")
     }
     return try loadGaussianSplatsFromPLY(url: url)
 }
 */
