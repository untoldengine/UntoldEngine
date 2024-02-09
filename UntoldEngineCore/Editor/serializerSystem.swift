//
//  serializerSystem.swift
//  UntoldEngine3D
//
//  Created by Harold Serrano on 7/6/23.
//

import Metal
import MetalKit
import Foundation
#if os(macOS)
import Cocoa

func selectDirectory() -> URL? {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.prompt = "Select"

    guard openPanel.runModal() == NSApplication.ModalResponse.OK else {
        return nil
    }

    return openPanel.url
}
#endif

func executeSerializeVoxels(uCommandBuffer:MTLCommandBuffer){
    
    if let computeEncoder:MTLComputeCommandEncoder=uCommandBuffer.makeComputeCommandEncoder(){
        
        computeEncoder.setComputePipelineState(serializePipeline.pipelineState!)
        
        //load up data
        computeEncoder.setBuffer(editorVoxelPool.originBuffer, offset: 0, index: BufferIndices.voxelOrigin.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.voxelVisible, offset: 0, index: BufferIndices.voxelVisible.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.baseColorBuffer, offset: 0, index: BufferIndices.voxelBaseColor.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.roughnessBuffer, offset: 0, index: BufferIndices.voxelRoughness.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.metallicBuffer, offset: 0, index: BufferIndices.voxelMetallic.rawValue)
        
        computeEncoder.setBuffer(editorBufferResources.serializeBuffer, offset: 0, index: BufferIndices.voxelSerialized.rawValue)
        computeEncoder.setBuffer(editorBufferResources.voxelSerializeCountBuffer, offset: 0, index: BufferIndices.voxelSerializedCount.rawValue)
        
        //Calculate the threadgroup size
        //let width=(voxelRayPipeline.pipelineState?.threadExecutionWidth)!
        let threadPerThreadgroup=MTLSizeMake(sizeOfChunk*sizeOfChunk, 1, 1)
        let threadsPerGrid=MTLSizeMake(sizeOfChunk*sizeOfChunk*sizeOfChunk, 1, 1) // one for now
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        computeEncoder.endEncoding()
    }
    
}

func deserializer(dataArray:[VoxelData]){
    
    for voxel in dataArray{
        
        insertBlockIntoGPU(uGuid: voxel.guid, uColor: voxel.color,uMaterial: voxel.material)
    }
    
}

func saveArrayOfStructsToFile<T: Codable>(dataArray: [T], filePath: String, directoryURL: URL) {
    let fileURL = directoryURL.appendingPathComponent(filePath)
    
    do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(dataArray)
        
        try jsonData.write(to: fileURL)
    } catch {
        print("Error saving file: \(error.localizedDescription)")
    }
}



