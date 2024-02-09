//
//  IntersectionCompute.swift
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/20/23.
//

import Foundation
import MetalKit
import Metal
import simd

struct IntersectionCompute {
    
    let kernelPipelineState:MTLComputePipelineState
    var rayOrigin:simd_float3!
    var rayDirection:simd_float3!
    var uniforms:MTLBuffer
    
    var result:MTLBuffer
    var tParam:MTLBuffer
    var pointIntersect:MTLBuffer
    
    var guid:MTLBuffer
    
    init?() {
        
        //create a library
        let library=renderInfo.device.makeDefaultLibrary()!
        
        //create a kernel
        guard let kernel=library.makeFunction(name: "voxelIntersect") else{
            print("Unable to create kernel")
            return nil
        }
        
        //create a pipeline
        
        do{
            kernelPipelineState=try renderInfo.device.makeComputePipelineState(function: kernel)
        }catch{
            print("Could not create the Compute Pipeline")
            return nil
        }
        
        //allocate buffer
        uniforms=renderInfo.device.makeBuffer(length: MemoryLayout<RayUniforms>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        result=renderInfo.device.makeBuffer(length: MemoryLayout<Int>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        tParam=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        pointIntersect=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        guid=renderInfo.device.makeBuffer(length: MemoryLayout<UInt>.stride, options: [MTLResourceOptions.storageModeShared])!
        
        var zero=0;
        var zerovec:simd_float3=simd_float3(0.0,0.0,0.0)
        var maxInt:UInt=UInt.max
        
        result.contents().initializeMemory(as: Int.self, from:&zero, count:1)
        tParam.contents().initializeMemory(as: UInt.self, from: &maxInt, count: 1)
        pointIntersect.contents().initializeMemory(as: simd_float3.self, from: &zerovec, count:1 )
        
    }
    
    mutating func setRayParameters(uRayOrigin:simd_float3, uRayDirection:simd_float3) {
        rayOrigin=uRayOrigin
        rayDirection=uRayDirection
    }
    
    func updateRayUniforms(){
        
        let viewMatrix:simd_float4x4 = camera.viewSpace
        
        
        var rayUniform=RayUniforms()
        
        rayUniform.rayOrigin=rayOrigin
        rayUniform.rayDirection=rayDirection
        rayUniform.projectionMatrix=renderInfo.perspectiveSpace
        rayUniform.viewMatrix=viewMatrix
        
        uniforms.contents().copyMemory(from: &rayUniform, byteCount: MemoryLayout<RayUniforms>.stride)
    }
    
    func execute(uComputeEncoder:MTLComputeCommandEncoder, voxelChunk:MTLBuffer){
        
        updateRayUniforms()
        
        uComputeEncoder.setComputePipelineState(kernelPipelineState)
        
        //load up data
        uComputeEncoder.setBuffer(voxelChunk, offset: 0, index: BufferIndices.voxelOrigin.rawValue)
        uComputeEncoder.setBuffer(uniforms, offset: 0, index: BufferIndices.intersectionUniform.rawValue)
        uComputeEncoder.setBuffer(result, offset: 0, index: BufferIndices.intersectionResult.rawValue)
        uComputeEncoder.setBuffer(tParam, offset: 0, index: BufferIndices.intersectionTParam.rawValue)
        uComputeEncoder.setBuffer(pointIntersect, offset: 0, index: BufferIndices.intersectionPointInt.rawValue)
        uComputeEncoder.setBuffer(guid, offset: 0, index: BufferIndices.intersectGuid.rawValue)
        
        //Calculate the threadgroup size
        let width=kernelPipelineState.threadExecutionWidth
        let threadPerThreadgroup=MTLSizeMake(width, 1, 1)
        let threadsPerGrid=MTLSizeMake(voxelChunk.length/MemoryLayout<simd_float3>.stride, 1, 1) // one for now

        uComputeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        uComputeEncoder.endEncoding()
    }
}
