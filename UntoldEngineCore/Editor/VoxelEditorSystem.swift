//
//  VoxelChunk.swift
//  UntoldVoxelEditor
//
//  Created by Harold Serrano on 2/17/23.
//

import Foundation
import MetalKit

#if os(iOS)
let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
#endif

func createChunk(uOrigin:simd_float3){

    var guidArray:[VoxelData]=[]
    
    //create a 16x16x16 chunk
    for y in 0 ..< sizeOfChunk{
        for z in 0 ..< sizeOfChunk{
            for x in 0 ..< sizeOfChunk{

                var guid:UInt=grid3dToIndexMap(coord: simd_uint3(UInt32(x),UInt32(y),UInt32(z)), sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
                
                var voxelData:VoxelData=VoxelData(guid: 0, color: simd_float3(0.0,0.0,0.0), material: simd_float3(0.5,0.0,0.0))
                
                voxelData.guid=guid
                guidArray.append(voxelData)
                
                
            }

        }

    }

    intersectionInfo.guidArray=guidArray
    intersectionInfo.didRayIntersectPlane=false
    intersectionInfo.normal=simd_float3(0.0,0.0,0.0)
    insertBlockIntoGPU(intersectionInfo, action: true,storeAction: true)
    
}

func multipleSelection(_ intersectionInfo:IntersectionInfo){
    
    //determine the voxel coordinate, i.e. uGuid->(x,y,z)
    let firstVoxelCoord=indexTo3DGridMap(index: intersectionInfo.guid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    let lastVoxelCoord=indexTo3DGridMap(index: intersectionInfo.guidEnd, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    let firstVoxelOrigin=simd_float3(Float(firstVoxelCoord.x),Float(firstVoxelCoord.y),Float(firstVoxelCoord.z))
    
    let lastVoxelOrigin=simd_float3(Float(lastVoxelCoord.x),Float(lastVoxelCoord.y),Float(lastVoxelCoord.z))
    

    //compute the mid point
    let origin:simd_float3=(firstVoxelOrigin+lastVoxelOrigin)*0.5
    
    var yOffset:Float=0.0
    if voxelAction == .add && intersectionInfo.didRayIntersectPlane == false{
        yOffset=intersectionInfo.normal.y
    }
    voxelNeighborOrigin=simd_float3(Float(origin.x),Float(origin.y)+yOffset,Float(origin.z))
    

    voxelNeighborScale=(abs(lastVoxelOrigin-firstVoxelOrigin) + simd_float3(1.0,1.0,1.0))
    
}

func determineVoxelToHighlight(_ intersectionInfo:IntersectionInfo){
    
    let uGuid:UInt=intersectionInfo.guid
    var uNormal:simd_float3=simd_float3(0.0,0.0,0.0)
    
    if voxelAction == .add{
        uNormal=intersectionInfo.normal
    }
    var floor:Bool=false
    if(intersectionInfo.didRayIntersectPlane){
        floor=true
        uNormal=simd_float3(0.0,0.0,0.0)
    }
    
    //determine the voxel coordinate, i.e. uGuid->(x,y,z)
    let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    //get the adjacent voxel depending on the normal data
    let gridRange=0...sizeOfChunk //range 8x8x8
    
    let x:Int=Int(voxelCoord.x)+Int(uNormal.x)
    let y:Int=Int(voxelCoord.y)+Int(uNormal.y)
    let z:Int=Int(voxelCoord.z)+Int(uNormal.z)
    
    var neighborGuid:UInt=0
    
    if (gridRange.contains(x) && gridRange.contains(y) && gridRange.contains(z) && x<sizeOfChunk && y<sizeOfChunk && z<sizeOfChunk){
        
        //get the new guid from the adjacent voxel coords. i.e. (x,y,z)->uGuid
        neighborGuid=grid3dToIndexMap(coord: simd_uint3(UInt32(x),UInt32(y),UInt32(z)), sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        let neighborVoxelCoord=indexTo3DGridMap(index: neighborGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        voxelNeighborOrigin=simd_float3(Float(neighborVoxelCoord.x),Float(neighborVoxelCoord.y),Float(neighborVoxelCoord.z))
        
        if(floor){
            voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))
        }
        
        
    }
}

func insertBlockIntoGPU(_ intersectionInfo:IntersectionInfo,action:Bool,storeAction:Bool){
    
    for voxel in intersectionInfo.guidArray{
        
        let uGuid:UInt=voxel.guid
        var uNormal:simd_float3=intersectionInfo.normal
        var floor:Bool=false
        if(intersectionInfo.didRayIntersectPlane){
            floor=true
            uNormal=simd_float3(0.0,0.0,0.0)
        }
        //determine the voxel coordinate, i.e. uGuid->(x,y,z)
        let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        //get the adjacent voxel depending on the normal data
        let gridRange=0...sizeOfChunk //range 8x8x8
        
        let x:Int=Int(voxelCoord.x)+Int(uNormal.x)/2
        let y:Int=Int(voxelCoord.y)+Int(uNormal.y)/2
        let z:Int=Int(voxelCoord.z)+Int(uNormal.z)/2
        
        var neighborGuid:UInt=0
        
        if (gridRange.contains(x) && gridRange.contains(y) && gridRange.contains(z) && x<sizeOfChunk && y<sizeOfChunk && z<sizeOfChunk){
            
            //get the new guid from the adjacent voxel coords. i.e. (x,y,z)->uGuid
            neighborGuid=grid3dToIndexMap(coord: simd_uint3(UInt32(x),UInt32(y),UInt32(z)), sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
            let neighborVoxelCoord=indexTo3DGridMap(index: neighborGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
            
            voxelNeighborOrigin=simd_float3(Float(neighborVoxelCoord.x),Float(neighborVoxelCoord.y),Float(neighborVoxelCoord.z))*2.0*scale
            
            if(floor){
                voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
            }
       
            
            //if user did not click simply return. else add the voxel
            if(!action){
                return;
            }

            var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: numOfVerticesPerBlock)

            for (i,value) in vertices.enumerated(){
                newVertices[i]=voxelNeighborOrigin+value
            }


            //set the indices
            var newIndices:[UInt32]=Array(repeating: 0, count: numOfIndicesPerBlock)

            for (i,value) in indices.enumerated(){
                newIndices[i]=UInt32(value)+UInt32(numOfVerticesPerBlock*Int(neighborGuid))
            }

            let newColor:[simd_float3]=Array(repeating: colorSelected, count: numOfVerticesPerBlock)

            let newRoughness:[Float]=Array(repeating: roughnessSelected, count: numOfVerticesPerBlock)
            
            let newMetallic:[Float]=Array(repeating: metallicSelected, count: numOfVerticesPerBlock)
            
            editorVoxelPool.originBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(neighborGuid)).copyMemory(from: &voxelNeighborOrigin, byteCount: MemoryLayout<simd_float3>.stride)

            editorVoxelPool.vertexBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(neighborGuid)).copyMemory(from: newVertices, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)

            editorVoxelPool.normalBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(neighborGuid)).copyMemory(from: normals, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)

            editorVoxelPool.colorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(neighborGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)
            
            editorVoxelPool.baseColorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(neighborGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride)

            editorVoxelPool.indicesBuffer!.contents().advanced(by: MemoryLayout<UInt32>.stride*numOfIndicesPerBlock*Int(neighborGuid)).copyMemory(from: newIndices, byteCount: MemoryLayout<UInt32>.stride*numOfIndicesPerBlock)
            
            editorVoxelPool.roughnessBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(neighborGuid)).copyMemory(from: newRoughness, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)
            
            editorVoxelPool.metallicBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(neighborGuid)).copyMemory(from: newMetallic, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)

            var visible:Bool=true
            editorVoxelPool.voxelVisible!.contents().advanced(by: MemoryLayout<Bool>.stride*Int(neighborGuid)).copyMemory(from: &visible, byteCount: MemoryLayout<Bool>.stride)

            //add operation to stack
            var userOperation:UserOperation=UserOperation(guid: uGuid, neighborGuid: neighborGuid, voxelAction: .add, color: colorSelected, previousColor: previousColorSelected,normal: uNormal,action: action, floor: floor)
            
            if(floor){
                userOperation.guid=uGuid
            }
            if(storeAction){
                undoStack.append(userOperation)
            }
            
            //provide heptic feedback
    #if os(iOS)
            feedbackGenerator.prepare()
            feedbackGenerator.impactOccurred()
    #endif
            
            
        }
    }
    
    
     
}

func insertBlockIntoGPU(uGuid:UInt, uColor:simd_float3, uMaterial:simd_float3){
    
    //determine the voxel coordinate, i.e. uGuid->(x,y,z)
    let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    
    var voxelOrigin:simd_float3=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale

    var newVertices:[simd_float3]=Array(repeating: simd_float3(0.0,0.0,0.0), count: numOfVerticesPerBlock)

    for (i,value) in vertices.enumerated(){
        newVertices[i]=voxelOrigin+value
    }


    //set the indices
    var newIndices:[UInt32]=Array(repeating: 0, count: numOfIndicesPerBlock)

    for (i,value) in indices.enumerated(){
        newIndices[i]=UInt32(value)+UInt32(numOfVerticesPerBlock*Int(uGuid))
    }
    
    let newRoughness:[Float]=Array(repeating: uMaterial.x, count: numOfVerticesPerBlock)
    let newMetallic:[Float]=Array(repeating: uMaterial.y, count: numOfVerticesPerBlock)
    let newColor:[simd_float3]=Array(repeating: uColor, count: numOfVerticesPerBlock)
    
    editorVoxelPool.originBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(uGuid)).copyMemory(from: &voxelOrigin, byteCount: MemoryLayout<simd_float3>.stride)

    editorVoxelPool.vertexBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newVertices, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)

    editorVoxelPool.normalBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: normals, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)

    editorVoxelPool.colorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)
    
    editorVoxelPool.baseColorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(uGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride)

    editorVoxelPool.indicesBuffer!.contents().advanced(by: MemoryLayout<UInt32>.stride*numOfIndicesPerBlock*Int(uGuid)).copyMemory(from: newIndices, byteCount: MemoryLayout<UInt32>.stride*numOfIndicesPerBlock)

    editorVoxelPool.roughnessBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newRoughness, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)
    
    editorVoxelPool.metallicBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newMetallic, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)
    
    var visible:Bool=true
    
    editorVoxelPool.voxelVisible!.contents().advanced(by: MemoryLayout<Bool>.stride*Int(uGuid)).copyMemory(from: &visible, byteCount: MemoryLayout<Bool>.stride)

}

func changeVoxelRoughness(_ intersectionInfo:IntersectionInfo, action:Bool, storeAction:Bool){
    
    for voxel in intersectionInfo.guidArray{
        
        let uGuid:UInt=voxel.guid
        
        //determine the voxel coordinate, i.e. uGuid->(x,y,z)
        let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
        
        //if user did not click simply return. else add the voxel
        if(!action){
            return;
        }
        
        let newRoughness:[Float]=Array(repeating: roughnessSelected, count: numOfVerticesPerBlock)
        
        //add roughness to the buffer
        editorVoxelPool.roughnessBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newRoughness, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)
    }
    
    
}

func changeVoxelMetallic(_ intersectionInfo:IntersectionInfo, action:Bool, storeAction:Bool){
    
    for voxel in intersectionInfo.guidArray{
        
        let uGuid:UInt=voxel.guid
        
        //determine the voxel coordinate, i.e. uGuid->(x,y,z)
        let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
        
        //if user did not click simply return. else add the voxel
        if(!action){
            return;
        }
        
        let newMetallic:[Float]=Array(repeating: metallicSelected, count: numOfVerticesPerBlock)
        
        //add roughness to the buffer
        editorVoxelPool.metallicBuffer!.contents().advanced(by: MemoryLayout<Float>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newMetallic, byteCount: MemoryLayout<Float>.stride*numOfVerticesPerBlock)
        
    }
    
}

func changeVoxelColor(_ intersectionInfo:IntersectionInfo, action:Bool, storeAction:Bool){
    
    for voxel in intersectionInfo.guidArray{
        
        let uGuid:UInt=voxel.guid
        
        //determine the voxel coordinate, i.e. uGuid->(x,y,z)
        let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
        
        //if user did not click simply return. else add the voxel
        if(!action){
            return;
        }
        
        let newColor:[simd_float3]=Array(repeating: colorSelected, count: numOfVerticesPerBlock)
        
        editorVoxelPool.colorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)
        
        editorVoxelPool.baseColorBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(uGuid)).copyMemory(from: newColor, byteCount: MemoryLayout<simd_float3>.stride)
        
        
        let userOperation:UserOperation=UserOperation(guid: uGuid,neighborGuid: 100000, voxelAction: .color, color: colorSelected, previousColor: previousColorSelected, normal: simd_float3(0.0,0.0,0.0), action: action, floor: false)
        
        if(storeAction){
            undoStack.append(userOperation)
        }
        
    }
    //provide heptic feedback
#if os(iOS)
    feedbackGenerator.prepare()
    feedbackGenerator.impactOccurred()
#endif
    
}

func removeBlockFromGPU(_ intersectionInfo:IntersectionInfo, action:Bool, storeAction:Bool){
    
    for voxel in intersectionInfo.guidArray{
        
        let uGuid:UInt=voxel.guid
        
        //determine the voxel coordinate, i.e. uGuid->(x,y,z)
        let voxelCoord=indexTo3DGridMap(index: uGuid, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
        
        voxelNeighborOrigin=simd_float3(Float(voxelCoord.x),Float(voxelCoord.y),Float(voxelCoord.z))*2.0*scale
        
        //if user did not click simply return. else add the voxel
        if(!action){
            return;
        }
        
        var origin:simd_float3=simd_float3(-.greatestFiniteMagnitude,-.greatestFiniteMagnitude,-.greatestFiniteMagnitude)
        
        editorVoxelPool.originBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*Int(uGuid)).copyMemory(from: &origin, byteCount: MemoryLayout<simd_float3>.stride)
        
        editorVoxelPool.vertexBuffer!.contents().advanced(by: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock*Int(uGuid)).copyMemory(from: zeroVertices, byteCount: MemoryLayout<simd_float3>.stride*numOfVerticesPerBlock)
        
        var visible:Bool=false
        editorVoxelPool.voxelVisible!.contents().advanced(by: MemoryLayout<Bool>.stride*Int(uGuid)).copyMemory(from: &visible, byteCount: MemoryLayout<Bool>.stride)
        
        let userOperation:UserOperation=UserOperation(guid: uGuid,neighborGuid: 100000, voxelAction: .remove, color: colorSelected, previousColor: previousColorSelected, normal: simd_float3(0.0,0.0,0.0), action: action, floor: false)
        
        if(storeAction){
            undoStack.append(userOperation)
        }
        
        
    }
    
    //provide heptic feedback
#if os(iOS)
    feedbackGenerator.prepare()
    feedbackGenerator.impactOccurred()
#endif
    
}

func setRayParameters(uRayOrigin:simd_float3, uRayDirection:simd_float3) {
    rayOrigin=uRayOrigin
    rayDirection=uRayDirection
}

func executeVoxelRayIntersectionPass(uCommandBuffer:MTLCommandBuffer){
    
    //upate the ray uniform
    let viewMatrix:simd_float4x4 = camera.viewSpace
    
    
    var rayUniform=RayUniforms()
    
    rayUniform.rayOrigin=rayOrigin
    rayUniform.rayDirection=rayDirection
    rayUniform.projectionMatrix=renderInfo.perspectiveSpace
    rayUniform.viewMatrix=viewMatrix
    
    editorBufferResources.voxelRayUniform?.contents().copyMemory(from: &rayUniform, byteCount: MemoryLayout<RayUniforms>.stride)
    
    if let computeEncoder:MTLComputeCommandEncoder=uCommandBuffer.makeComputeCommandEncoder(){
        
        computeEncoder.setComputePipelineState(voxelRayPipeline.pipelineState!)
        
        //load up data
        computeEncoder.setBuffer(editorVoxelPool.originBuffer, offset: 0, index: BufferIndices.voxelOrigin.rawValue)
        computeEncoder.setBuffer(editorBufferResources.voxelRayUniform, offset: 0, index: BufferIndices.intersectionUniform.rawValue)
        computeEncoder.setBuffer(editorBufferResources.intersectionTest, offset: 0, index: BufferIndices.intersectionResult.rawValue)
        computeEncoder.setBuffer(editorBufferResources.tIntersectionParam, offset: 0, index: BufferIndices.intersectionTParam.rawValue)
        computeEncoder.setBuffer(editorBufferResources.pointIntersect, offset: 0, index: BufferIndices.intersectionPointInt.rawValue)
        computeEncoder.setBuffer(editorBufferResources.blockIntersectedGuid, offset: 0, index: BufferIndices.intersectGuid.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.voxelVisible, offset: 0, index: BufferIndices.voxelVisible.rawValue)
        computeEncoder.setBuffer(editorBufferResources.planeRayIntersectionResult, offset: 0, index: BufferIndices.planeRayIntersectionResult.rawValue)
        computeEncoder.setBuffer(editorBufferResources.planeRayIntersectionPoint, offset: 0, index: BufferIndices.planeRayIntersectionPoint.rawValue)
        computeEncoder.setBuffer(editorBufferResources.planeRayIntersectionTime, offset: 0, index: BufferIndices.planeRayIntersectionTime.rawValue)
        
        //Calculate the threadgroup size
        //let width=(voxelRayPipeline.pipelineState?.threadExecutionWidth)!
        let threadPerThreadgroup=MTLSizeMake(sizeOfChunk*sizeOfChunk, 1, 1)
        let threadsPerGrid=MTLSizeMake(editorVoxelPool.originBuffer!.length/MemoryLayout<simd_float3>.stride, 1, 1) // one for now
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        computeEncoder.endEncoding()
    }
    
    
}

func executeNormalPlaneComputePass(uCommandBuffer:MTLCommandBuffer){
    
    //upate the ray uniform
    let viewMatrix:simd_float4x4 = camera.viewSpace
    
    
    var rayUniform=RayUniforms()
    
    rayUniform.rayOrigin=rayOrigin
    rayUniform.rayDirection=rayDirection
    rayUniform.projectionMatrix=renderInfo.perspectiveSpace
    rayUniform.viewMatrix=viewMatrix
    
    //get current box highlighit info
    let box=getHighlightedBoxBoundaries()
    
    editorBufferResources.voxelRayUniform?.contents().copyMemory(from: &rayUniform, byteCount: MemoryLayout<RayUniforms>.stride)
    
    if let computeEncoder:MTLComputeCommandEncoder=uCommandBuffer.makeComputeCommandEncoder(){
        
        computeEncoder.setComputePipelineState(normalPlaneComputePipeline.pipelineState!)
        
        //load up data
       
        computeEncoder.setBuffer(editorBufferResources.voxelRayUniform, offset: 0, index: Int(planeNormalRayIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.normalPlaneTIntersectionParam, offset: 0, index: Int(planeNormalTParamIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.normalPlanePointIntersect, offset: 0, index: Int(planeNormalInterceptPointIndex.rawValue))
        computeEncoder.setBuffer(editorBufferResources.normalPlaneIntersectionTest, offset: 0, index: Int(planeNormalIntResultIndex.rawValue))
        
        let boxOriginBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride,options: [])
        
        if let boxOriginBufferPtr=boxOriginBuffer?.contents().bindMemory(to: simd_float3.self, capacity: 1){
            boxOriginBufferPtr.pointee=box.origin
        }
        
        let boxHalfwidthBuffer=renderInfo.device.makeBuffer(length: MemoryLayout<simd_float3>.stride,options: [])
        
        if let boxHalfwidthBufferPtr=boxHalfwidthBuffer?.contents().bindMemory(to: simd_float3.self, capacity: 1){
            boxHalfwidthBufferPtr.pointee=box.halfwidth
        }
        
        computeEncoder.setBuffer(boxOriginBuffer, offset: 0, index: Int(planeNormalBoxOriginIndex.rawValue))
        computeEncoder.setBuffer(boxHalfwidthBuffer, offset: 0, index: Int(planeNormalBoxHalfwidthIndex.rawValue))
        
        //Calculate the threadgroup size
        //let width=(voxelRayPipeline.pipelineState?.threadExecutionWidth)!
        let threadPerThreadgroup=MTLSizeMake(1, 1, 1)
        let threadsPerGrid=MTLSizeMake(1, 1, 1) // one for now
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        boxOriginBuffer?.setPurgeableState(.empty)
        boxHalfwidthBuffer?.setPurgeableState(.empty)
        computeEncoder.endEncoding()
    }
    
}

func executeRemoveAllVoxels(uCommandBuffer:MTLCommandBuffer){
    
    if let computeEncoder:MTLComputeCommandEncoder=uCommandBuffer.makeComputeCommandEncoder(){
        
        computeEncoder.setComputePipelineState(voxelRemoveAllPipeline.pipelineState!)
        
        //load up data
        computeEncoder.setBuffer(editorVoxelPool.originBuffer, offset: 0, index: BufferIndices.voxelOrigin.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.vertexBuffer, offset: 0, index: BufferIndices.voxelVertices.rawValue)
        computeEncoder.setBuffer(editorVoxelPool.voxelVisible, offset: 0, index: BufferIndices.voxelVisible.rawValue)
        
        //Calculate the threadgroup size
        //let width=(voxelRayPipeline.pipelineState?.threadExecutionWidth)!
        let threadPerThreadgroup=MTLSizeMake(sizeOfChunk*sizeOfChunk, 1, 1)
        let threadsPerGrid=MTLSizeMake(sizeOfChunk*sizeOfChunk*sizeOfChunk, 1, 1) // one for now
        
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadPerThreadgroup)
        
        computeEncoder.endEncoding()
    }
    
}

func getHighlightBoxNormal(uMouseLocation:simd_float2){
    
    let rayDirection:simd_float3=rayDirectionInWorldSpace(uMouseLocation: uMouseLocation, uViewPortDim: renderInfo.viewPort, uPerspectiveSpace: renderInfo.perspectiveSpace, uViewSpace: camera.viewSpace)
    let rayOrigin:simd_float3=camera.localPosition
    
    setRayParameters(uRayOrigin: rayOrigin, uRayDirection: rayDirection)
    
    if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
        
        executeNormalPlaneComputePass(uCommandBuffer: commandBuffer);
        
        commandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
            
            let didRayBoxIntersect=UnsafeRawBufferPointer(start: editorBufferResources.normalPlaneIntersectionTest!.contents(), count: MemoryLayout<Int>.stride).bindMemory(to: Int.self)
            
            if(didRayBoxIntersect[0]==1){
                
                let pointIntersect=UnsafeRawBufferPointer(start: editorBufferResources.normalPlanePointIntersect!.contents(), count: MemoryLayout<simd_float3>.stride).bindMemory(to: simd_float3.self)
                
                planeToExtrude=pointIntersect[0]
                
            }
            
            //reset
            var zero:Int=0;
            editorBufferResources.normalPlaneIntersectionTest!.contents().copyMemory(from:&zero, byteCount: MemoryLayout<Int>.stride)
            
           
            var maxInt:UInt=UInt.max
            editorBufferResources.normalPlaneTIntersectionParam!.contents().copyMemory(from:&maxInt, byteCount: MemoryLayout<UInt>.stride)
        }
        
        commandBuffer.commit()
    }
}

func shootRay(uMouseLocation:simd_float2){
    
    let rayDirection:simd_float3=rayDirectionInWorldSpace(uMouseLocation: uMouseLocation, uViewPortDim: renderInfo.viewPort, uPerspectiveSpace: renderInfo.perspectiveSpace, uViewSpace: camera.viewSpace)
    let rayOrigin:simd_float3=camera.localPosition
    
    setRayParameters(uRayOrigin: rayOrigin, uRayDirection: rayDirection)
    
    if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
        
        executeVoxelRayIntersectionPass(uCommandBuffer: commandBuffer);
        
        commandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
            
            let didRayIntersectPlane=UnsafeRawBufferPointer(start: editorBufferResources.planeRayIntersectionResult!.contents(), count: MemoryLayout<Bool>.stride).bindMemory(to: Bool.self)
            
            let planeRayIntersectPoint=UnsafeRawBufferPointer(start: editorBufferResources.planeRayIntersectionPoint!.contents(), count: MemoryLayout<simd_float3>.stride).bindMemory(to: simd_float3.self)
            
            let planeRayIntersectTime=UnsafeRawBufferPointer(start: editorBufferResources.planeRayIntersectionTime!.contents(), count: MemoryLayout<simd_float3>.stride).bindMemory(to: Float.self)
            
            let didRayBoxIntersect=UnsafeRawBufferPointer(start: editorBufferResources.intersectionTest!.contents(), count: MemoryLayout<Int>.stride).bindMemory(to: Int.self)
            
            if(didRayBoxIntersect[0]==1){
                
                let pointIntersect=UnsafeRawBufferPointer(start: editorBufferResources.pointIntersect!.contents(), count: MemoryLayout<simd_float3>.stride).bindMemory(to: simd_float3.self)
                
                
                let tMinPointer=UnsafeRawBufferPointer(start: editorBufferResources.tIntersectionParam!.contents(), count: MemoryLayout<Float>.stride).bindMemory(to: Float.self)

                let guid=UnsafeRawBufferPointer(start: editorBufferResources.blockIntersectedGuid!.contents(), count: MemoryLayout<UInt>.stride).bindMemory(to: UInt.self)
                
                //intersection info
                if(selectionMode == .single || selectionMode == .multipleselectionstart){
                    intersectionInfo.guid=guid[0]
                    intersectionInfo.guidEnd=guid[0]
                }else if(selectionMode == .multipleselectionmoving){
                    intersectionInfo.guidEnd=guid[0]
                }
                
                intersectionInfo.normal=pointIntersect[0]
                intersectionInfo.didRayIntersectPlane=didRayIntersectPlane[0]
                
                if(selectionMode == .single || selectionMode == .multipleselectionstart){
                    determineVoxelToHighlight(intersectionInfo)
                }else if(selectionMode == .multipleselectionmoving){
                    multipleSelection(intersectionInfo)
                }
                
            }
            
            //reset
            var zero:Int=0;
            editorBufferResources.intersectionTest!.contents().copyMemory(from:&zero, byteCount: MemoryLayout<Int>.stride)
            
            var maxInt:UInt=UInt.max
            editorBufferResources.tIntersectionParam!.contents().copyMemory(from:&maxInt, byteCount: MemoryLayout<UInt>.stride)
            
            var reset:Bool=false
            editorBufferResources.planeRayIntersectionResult!.contents().copyMemory(from: &reset, byteCount: MemoryLayout<Bool>.stride)
            
            editorBufferResources.planeRayIntersectionPoint!.contents().copyMemory(from:&zero, byteCount: MemoryLayout<Int>.stride)
            
            editorBufferResources.planeRayIntersectionTime!.contents().copyMemory(from:&maxInt, byteCount: MemoryLayout<UInt>.stride)
        }
        
        commandBuffer.commit()
    }
    
    enableRayVoxelIntersection=false
}

func getHighlightedBoxBoundaries()->HighLightBox{
    
    let origin:simd_float3=simd_float3(voxelNeighborOrigin.x,voxelNeighborOrigin.y,voxelNeighborOrigin.z)
    
    let halfwidth:simd_float3=simd_float3(voxelNeighborScale.x,voxelNeighborScale.y,voxelNeighborScale.z)
    
    var box:HighLightBox=HighLightBox()
    box.origin=origin
    box.halfwidth=halfwidth
    
    return box
    
}

func getAllVoxelsInBox(uMouseLocation:simd_float2){
    
    //get ray information
    let rayDirection:simd_float3=rayDirectionInWorldSpace(uMouseLocation: uMouseLocation, uViewPortDim: renderInfo.viewPort, uPerspectiveSpace: renderInfo.perspectiveSpace, uViewSpace: camera.viewSpace)
    let rayOrigin:simd_float3=camera.localPosition
    
    setRayParameters(uRayOrigin: rayOrigin, uRayDirection: rayDirection)
    
    //get current box highlighit info
    let box=getHighlightedBoxBoundaries()
    
    if let commandBuffer=renderInfo.commandQueue.makeCommandBuffer(){
        
        executeVoxelBoxIntersection(uCommandBuffer: commandBuffer,box)
        
        commandBuffer.addCompletedHandler{(_ commandBuffer)-> Swift.Void in
            
            let bufferPointerCount=UnsafeRawBufferPointer(start: editorBufferResources.boxGuidIntersectionCountBuffer!.contents(), count: 1).bindMemory(to: UInt.self)

            let count:UInt=bufferPointerCount.baseAddress!.pointee
            
            let dataPointer = editorBufferResources.boxGuidIntersectionBuffer!.contents().assumingMemoryBound(to: VoxelData.self)
            intersectionInfo.guidArray = Array(UnsafeBufferPointer(start: dataPointer, count: Int(count)))
            
                            
                if(voxelAction == .add){ //add
                    insertBlockIntoGPU(intersectionInfo,action:true,storeAction: true)

                }else if(voxelAction == .remove){ //remove
                    removeBlockFromGPU(intersectionInfo,action:true,storeAction: true)
                }else if(voxelAction == .color){ //color
                    changeVoxelColor(intersectionInfo,action:true,storeAction: true)
                }else if(voxelAction == .roughness){ //add roughness
                    changeVoxelRoughness(intersectionInfo,action:true,storeAction: true)
                }else if(voxelAction == .metallic){ //add metallic
                    changeVoxelMetallic(intersectionInfo,action:true,storeAction: true)
                }
                
            
            //clear all data
            var zero:UInt=0
            editorBufferResources.boxGuidIntersectionCountBuffer!.contents().copyMemory(from: &zero, byteCount: MemoryLayout<UInt>.stride)
            
            intersectionInfo.didRayIntersectPlane=false
            intersectionInfo.normal=simd_float3(0.0,0.0,0.0)
            intersectionInfo.guid=0
            intersectionInfo.guidEnd=0
            intersectionInfo.guidArray.removeAll()
            
            selectionMode = .single
            voxelNeighborScale=simd_float3(1.0,1.0,1.0)
            
        }
        
        commandBuffer.commit()
    }
}

func extrudePlane(extrutionSign:Float){
    
    if intersectionInfo.guidEnd < intersectionInfo.guid{
        var temp:UInt=intersectionInfo.guidEnd
        intersectionInfo.guidEnd=intersectionInfo.guid
        intersectionInfo.guid=temp
    }
    
    var newPlaneToExtrude=planeToExtrude*extrutionSign
    
    var guidIndex:UInt=intersectionInfo.guidEnd
    var planeExtrutionPositive:Bool=true
    
    if planeToExtrude.x == -1.0 || planeToExtrude.y == -1.0 || planeToExtrude.z == -1.0{
        guidIndex=intersectionInfo.guid
        planeExtrutionPositive=false
        
    }
    
    
    
    let guidEndCoord=indexTo3DGridMap(index: guidIndex, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    let newGuidEndCoord = getSpecificAdjacentVoxel(x: UInt(guidEndCoord.x), y: UInt(guidEndCoord.y), z: UInt(guidEndCoord.z), direction: .tuple(dx: Int(newPlaneToExtrude.x), dy: Int(newPlaneToExtrude.y), dz: Int(newPlaneToExtrude.z)))
    
    if newGuidEndCoord == nil{
        return
    }
    
    let newGuidEndIndex=grid3dToIndexMap(coord: newGuidEndCoord!, sizeX: UInt(sizeOfChunk), sizeY: UInt(sizeOfChunk), sizeZ: UInt(sizeOfChunk))
    
    if planeExtrutionPositive == false{
        intersectionInfo.guid=newGuidEndIndex
    }else{
        intersectionInfo.guidEnd=newGuidEndIndex
    }
    
    multipleSelection(intersectionInfo)
}
