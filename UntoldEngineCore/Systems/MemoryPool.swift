//
//  MemoryPool.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/18/24.
//

import Foundation
import Metal

struct MemoryPoolManager{
    private var pool:MTLBuffer
    private var blockSize:Int
    private var capacity:Int
    private var freeList: [Int]
    var allocations: [AssetID: [Int]] = [:]
    
    init?(_ device:MTLDevice, _ blockSize:Int, _ capacity:Int, _ name:String){
        self.blockSize=blockSize
        self.capacity=capacity
        
        let length=blockSize*capacity
        guard let buffer=device.makeBuffer(length: length, options: .storageModeShared) else{ return nil}
        
        self.pool=buffer
        self.pool.label=name
        //initialize freeList with block indices
        self.freeList = Array(0..<capacity)
    }
    
    
    mutating func allocate()->Int?{
        guard !freeList.isEmpty else {
            
            print("Allocation Failed: Memory Pool is Empty")
            return nil
        }
        
        let allocatedBlock=freeList.removeLast()
        print("Allocated Block at Address: \(allocatedBlock)")
        
        return allocatedBlock*blockSize
    }
    
    mutating func deallocate(_ offset: Int) {
        let blockIndex = offset / blockSize
        guard freeList.contains(blockIndex) == false else {
            handleError(.memoryPoolDeallocationBlocksFree)
            return
        }
        freeList.append(blockIndex)
        print("Deallocated Block at Index: \(blockIndex)")
    }

    
    mutating func allocateContinuousBlocks(_ assetId: AssetID, blocksNeeded: Int) -> Bool {
        print("Requesting \(blocksNeeded) continuous blocks for Asset \(assetId)")
        guard blocksNeeded > 0 && blocksNeeded <= freeList.count else {
            handleError(.memoryPoolDeallocationNotEnoughMem)
            return false
        }

        // Find a continuous sequence of free blocks
        var startIndex: Int?
        for i in 0..<(freeList.count - blocksNeeded + 1) {
            var isContinuous = true
            for j in 0..<(blocksNeeded - 1) {
                if freeList[i + j] + 1 != freeList[i + j + 1] {
                    isContinuous = false
                    break
                }
            }

            if isContinuous {
                startIndex = i
                break
            }
        }

        // Check if a continuous chunk was found
        guard let start = startIndex else {
            handleError(.memoryPoolFailedToAllocate,blocksNeeded,assetId)
            return false
        }

        // Allocate the continuous blocks
        let allocatedBlockIndices = Array(freeList[start..<(start + blocksNeeded)])
        freeList.removeSubrange(start..<(start + blocksNeeded))

        // Store the starting offset of the allocated range
        let startingOffset = allocatedBlockIndices.first! * blockSize
        allocations[assetId] = [startingOffset]
        print("Allocated continuous blocks for Asset \(assetId) starting at offset \(startingOffset)")

        return true
    }

    
    mutating func deallocateContinuousBlocks(_ assetId: AssetID) {
        guard let blockIndices = allocations[assetId] else {
            handleError(.memoryPoolNoBlocksAllocated,assetId)
            return
        }

        for blockIndex in blockIndices {
            deallocate(blockIndex * blockSize)
        }

        allocations.removeValue(forKey: assetId)
    }

    func blocks(_ assetId: AssetID) -> [Int]? {
        return allocations[assetId]?.map { $0 * blockSize }
    }

    mutating func writeArrayData<T>(_ assetId:AssetID, offset dataOffset:Int, voxelData data: [T]) {
        
        guard let entityStartOffset = allocations[assetId]?.first else{
            handleError(.memoryPoolAssetNotInAllocation,assetId)
            return
        }
        
        let totalOffset=entityStartOffset+dataOffset
        
        guard totalOffset + MemoryLayout<T>.stride * data.count <= pool.length else {
            handleError(.memoryPoolWritingBeyondCapacity)
            return
        }
        
        let bufferPointer=pool.contents()
        let dataPointer = bufferPointer.advanced(by: totalOffset).assumingMemoryBound(to: T.self)
        
        for (index,element) in data.enumerated(){
            (dataPointer+index).initialize(to: element)
        }
    }
    
    mutating func writeSingleData<T>(_ assetId:AssetID, _ dataOffset:Int, _ data: T){
        
        guard let entityStartOffset = allocations[assetId]?.first else{
            handleError(.memoryPoolAssetNotInAllocation,assetId)
            return
        }
        
        let totalOffset=entityStartOffset+dataOffset
        guard totalOffset+MemoryLayout<T>.stride <= pool.length else{
            handleError(.memoryPoolWritingBeyondCapacity)
            return
        }
        
        let bufferPointer=pool.contents()
        let dataPointer=bufferPointer.advanced(by: totalOffset).assumingMemoryBound(to: T.self)
        dataPointer.pointee = data
    }

    func setVertexBuffer(_ renderEncoder: MTLRenderCommandEncoder,_ assetId: AssetID,_ index: Int) {
            guard let vertexOffset = allocations[assetId]?.first else {
                handleError(.memoryPoolAssetNotInAllocation, assetId)
                return
            }

            renderEncoder.setVertexBuffer(pool, offset: vertexOffset, index: index)
        }
    
    func readArrayData<T>(_ assetId: AssetID, offset dataOffset: Int, count: Int) -> [T] {
        guard let entityStartOffset = allocations[assetId]?.first else {
            handleError(.memoryPoolAssetNotInAllocation, assetId)
            return []
        }

        let totalOffset = entityStartOffset + dataOffset
        guard totalOffset + MemoryLayout<T>.stride * count <= pool.length else {
            handleError(.memoryPoolReadingBeyongCapacity)
            return []
        }

        let bufferPointer = pool.contents()
        let dataPointer = bufferPointer.advanced(by: totalOffset).assumingMemoryBound(to: T.self)

        return (0..<count).map { dataPointer.advanced(by: $0).pointee }
    }

    func readSingleData<T>(_ assetId: AssetID, offset dataOffset: Int) -> T? {
        guard let entityStartOffset = allocations[assetId]?.first else {
            handleError(.memoryPoolAssetNotInAllocation, assetId)
            return nil
        }

        let totalOffset = entityStartOffset + dataOffset
        guard totalOffset + MemoryLayout<T>.stride <= pool.length else {
            handleError(.memoryPoolReadingBeyongCapacity)
            return nil
        }

        let bufferPointer = pool.contents()
        let dataPointer = bufferPointer.advanced(by: totalOffset).assumingMemoryBound(to: T.self)
        
        return dataPointer.pointee
    }

    
    func getBuffer() -> MTLBuffer {
            return pool
        }
    
    func readAndPrintData<T>(type: T.Type, fromOffset offset: Int, count: Int) where T: CustomStringConvertible {
            guard offset + MemoryLayout<T>.stride * count <= pool.length else {
                handleError(.memoryPoolReadingBeyongCapacity)
                return
            }

            let bufferPointer = pool.contents()
            let dataPointer = bufferPointer.advanced(by: offset).assumingMemoryBound(to: T.self)

            for i in 0..<count {
                let element = dataPointer.advanced(by: i).pointee
                print("Element \(i): \(element)")
            }
        }
}
