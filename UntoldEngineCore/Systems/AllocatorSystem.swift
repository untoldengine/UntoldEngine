//
//  AllocatorSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/15/24.
//

import Foundation

func loadVoxelIntoPool(_ filename:String){
    
    guard let fileURL = Bundle.main.url(forResource: filename, withExtension: "json") else { 
        handleError(.filenameNotFound, filename)
        return
    }
        
    guard let voxelDataArray: [VoxelData] = readArrayOfStructsFromFile(filePath: fileURL) else {return}

    let blocksNeeded = Int(ceil(Double(voxelDataArray.count) / Double(memoryPoolBlockSize)))
    
    var assetData:AssetData=AssetData()
    assetData.assetId=globalAssetId
    assetData.name=filename
    assetData.entityDataSize=voxelDataArray.count
    assetData.indexCount=voxelDataArray.count*numOfIndicesPerBlock
    
    //allocate memory for the entity
    vertexMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
    normalMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
    indicesMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
    colorMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
    roughnessMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
    metallicMemoryPool!.allocateContinuousBlocks(assetData.assetId, blocksNeeded: blocksNeeded)
        
    //set index offset for entity
    guard let indexOffset=indicesMemoryPool!.allocations[assetData.assetId]?.first else {return}
    
    assetData.indexOffset=indexOffset
    assetDataArray.append(assetData)
    
    for (index, voxel) in voxelDataArray.enumerated(){
        copyDataIntoPools(assetData.assetId, voxel.rawOrigin, voxel.color, voxel.material, Int(index),voxel.scale)
    }
    
    //set map between string and asset data
    assetDataMap[filename]=assetDataArray[(Int)(assetData.assetId)]
    globalAssetId = globalAssetId + 1

}
            
func copyDataIntoPools(_ assetId:AssetID, _ origin:simd_float3, _ color:simd_float3, _ material:simd_float3, _ offset:Int, _ scale:Float){
    
    var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: numOfVerticesPerBlock)

    for (i,value) in vertices.enumerated(){
        newVertices[i]=origin+value*scale
        
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
