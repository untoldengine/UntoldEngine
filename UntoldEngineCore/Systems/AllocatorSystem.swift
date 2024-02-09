//
//  AllocatorSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation

func loadVoxelIntoPool(_ assetId:AssetID, _ filename:String){
    
    guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "json") else { 
        handleError(.filenameNotFound, filename)
        return
    }
        
    guard let voxelDataArray: [VoxelData] = readArrayOfStructsFromFile(filePath: fileURL) else {return}

    let blocksNeeded = Int(ceil(Double(voxelDataArray.count) / Double(memoryPoolBlockSize)))
    
    var assetData:AssetData=AssetData()
    assetData.assetId=assetId
    assetData.name=filename
    assetData.entityDataSize=voxelDataArray.count
    assetData.indexCount=voxelDataArray.count*numOfIndicesPerBlock
    
    //allocate memory for the entity
    vertexMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
    normalMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
    indicesMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
    colorMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
    roughnessMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
    metallicMemoryPool!.allocateContinuousBlocks(assetId, blocksNeeded: blocksNeeded)
        
    //set index offset for entity
    guard let indexOffset=indicesMemoryPool!.allocations[assetId]?.first else {return}
    
    assetData.indexOffset=indexOffset
    assetDataArray.append(assetData)
    
    for (index, voxel) in voxelDataArray.enumerated(){
        copyDataIntoPools(assetId, voxel.rawOrigin, voxel.color, voxel.material, Int(index))
    }
    

}
            
func copyDataIntoPools(_ assetId:AssetID, _ origin:simd_float3, _ color:simd_float3, _ material:simd_float3, _ offset:Int){
    
//    let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
//    
//    
//    var voxelOrigin:simd_float3=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
//    
    var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: numOfVerticesPerBlock)

    for (i,value) in vertices.enumerated(){
        newVertices[i]=origin+value
        
    }
    
    vertexMemoryPool.writeArrayData(assetId, offset: MemoryLayout<simd_float3>.stride*offset*numOfVerticesPerBlock, voxelData: newVertices)
     
    //load normals
    normalMemoryPool.writeArrayData(assetId, offset: MemoryLayout<simd_float3>.stride*offset*numOfVerticesPerBlock, voxelData: normals)
    
    //load indices
    //set the indices
    var newIndices:[UInt32]=Array(repeating: 0, count: numOfIndicesPerBlock)

    for (i,value) in indices.enumerated(){
        newIndices[i]=UInt32(value)+UInt32(numOfVerticesPerBlock*Int(offset))
    }
    
    indicesMemoryPool.writeArrayData(assetId, offset: MemoryLayout<UInt32>.stride*offset*numOfIndicesPerBlock, voxelData: newIndices)
    
    //load material data
    let newRoughness:[Float]=Array(repeating: material.x, count: numOfVerticesPerBlock)
    let newMetallic:[Float]=Array(repeating: material.y, count: numOfVerticesPerBlock)
    let newColor:[simd_float3]=Array(repeating: color, count: numOfVerticesPerBlock)
    
    colorMemoryPool.writeArrayData(assetId, offset: MemoryLayout<simd_float3>.stride*offset*numOfVerticesPerBlock, voxelData: newColor)
    roughnessMemoryPool.writeArrayData(assetId, offset: MemoryLayout<Float>.stride*offset*numOfVerticesPerBlock, voxelData: newRoughness)
    metallicMemoryPool.writeArrayData(assetId, offset: MemoryLayout<Float>.stride*offset*numOfVerticesPerBlock, voxelData: newMetallic)
    
    
}
