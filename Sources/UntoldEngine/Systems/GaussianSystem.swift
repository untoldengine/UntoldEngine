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

var maxNumOfGaussians: UInt64 = 1024 * 1024 * 5

func initGuassianComputePipelines() {
    createComputePipeline(into: &bitonicSortPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianBitonicSort", pipelineName: "Bitonic Sort")

    createComputePipeline(into: &gaussianDepthPipeline, device: renderInfo.device, library: renderInfo.library, functionName: "gaussianDepthKeys", pipelineName: "Gaussian Depth")
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

        if let gaussianUniformBuffer = gaussianComponent.spaceUniform[renderInfo.currentEye] {
            gaussianUniformBuffer.contents().copyMemory(
                from: &gaussianUniform, byteCount: MemoryLayout<Uniforms>.stride
            )
        } else {
            handleError(.bufferAllocationFailed, "Gaussian Uniform buffer")
            return
        }

        computeEncoder.setBuffer(
            gaussianComponent.spaceUniform[renderInfo.currentEye], offset: 0, index: Int(gaussianUniformIndex.rawValue)
        )

        var localNumGaussians = UInt32(gaussianComponent.splatCount)
        computeEncoder.setBytes(&localNumGaussians, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))

        let tew = bitonicSortPipeline.pipelineState?.threadExecutionWidth // e.g. 32/64
        let maxT = bitonicSortPipeline.pipelineState?.maxTotalThreadsPerThreadgroup // device cap
        let target = 256
        var block = min(target, maxT!)
        block = (block / tew!) * tew! // align down to multiple of tew
        block = max(block, tew!) // never below tew

        let threadsPerThreadgroup: MTLSize = MTLSizeMake(block, 1, 1)
        let threadsPerGrid: MTLSize = MTLSizeMake(Int(gaussianComponent.splatCount), 1, 1)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }

    computeEncoder.endEncoding()
}

public func executeBitonicSort(_ commandBuffer: MTLCommandBuffer) {
    if bitonicSortPipeline.success == false {
        handleError(.pipelineStateNulled, bitonicSortPipeline.name!)
        return
    }

    let computeEncoder: MTLComputeCommandEncoder = commandBuffer.makeComputeCommandEncoder()!

    computeEncoder.label = "Bitonic Sort pass"

    computeEncoder.setComputePipelineState(bitonicSortPipeline.pipelineState!)

    let transformId = getComponentId(for: WorldTransformComponent.self)
    let gaussianId = getComponentId(for: GaussianComponent.self)
    let entities = queryEntitiesWithComponentIds([transformId, gaussianId], in: scene)

    for entityId in entities {
        guard let gaussianComponent = scene.get(component: GaussianComponent.self, for: entityId) else {
            handleError(.noGaussianComponent, entityId)
            continue
        }
        var splatCount = gaussianComponent.splatCount
        // Make a local mutable copy to satisfy inout requirement
        var powerOfTwoNumGaussian = UInt32(nextPowerOf2(x: &splatCount))
        var subarraySize = 2
        while subarraySize <= Int(gaussianComponent.splatCount) {
            var comparisonDistance = subarraySize / 2
            while comparisonDistance > 0 {
                computeEncoder.setBytes(&powerOfTwoNumGaussian, length: MemoryLayout<UInt32>.stride, index: Int(gaussianNumberOfSplatsIndex.rawValue))

                computeEncoder.setBytes(&subarraySize, length: MemoryLayout<Int>.stride, index: Int(gaussianSubArraySizeIndex.rawValue))

                computeEncoder.setBytes(&comparisonDistance, length: MemoryLayout<Int>.stride, index: Int(gaussianComparisonDistanceIndex.rawValue))

                computeEncoder.setBuffer(gaussianComponent.gaussianSortedIndices, offset: 0, index: Int(gaussianIndicesIndex.rawValue))

                let tew = bitonicSortPipeline.pipelineState?.threadExecutionWidth // e.g. 32/64
                let maxT = bitonicSortPipeline.pipelineState?.maxTotalThreadsPerThreadgroup // device cap
                let target = 256
                var block = min(target, maxT!)
                block = (block / tew!) * tew! // align down to multiple of tew
                block = max(block, tew!) // never below tew

                let threadsPerThreadgroup: MTLSize = MTLSizeMake(block, 1, 1)
                let threadsPerGrid: MTLSize = MTLSizeMake(Int(powerOfTwoNumGaussian), 1, 1)

                computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

                comparisonDistance /= 2
            }

            subarraySize *= 2
        }
    }

    computeEncoder.endEncoding()
}

// MARK: - PLY Loading Helpers

/*
 Usage Examples:

   // Example 1: Load from absolute path
   do {
       let count = try loadGaussianSplatsFromPLY(path: "/path/to/gaussians.ply")
       print("Loaded \(count) splats")

       // Now render them
       executeGaussianDepth(commandBuffer, numGaussians: count)
       executeBitonicSort(commandBuffer, numGaussians: UInt(count))
   } catch {
       print("Error loading PLY: \(error)")
   }

   // Example 2: Load from app bundle
   do {
       let count = try loadGaussianSplatsFromBundle(filename: "scene")
       // Uses currentNumOfGaussians automatically
       executeGaussianDepth(commandBuffer, numGaussians: currentNumOfGaussians)
   } catch {
       print("Error: \(error)")
   }

   // Example 3: Load from URL
   let url = URL(fileURLWithPath: "path/to/file.ply")
   do {
       let count = try loadGaussianSplatsFromPLY(url: url)
   } catch {
       print("Error: \(error)")
   }
 */
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
