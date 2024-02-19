//
//  ErrorSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/24.
//

import Foundation

enum ErrorHandlingSystem: Int, Error, CustomStringConvertible{
    
    case pipelineStateCreationFailed = 1001
    case bufferAllocationFailed = 1002
    case renderPassDescriptorCreationFailed = 1003
    case renderPassCreationFailed = 1004
    case assetDataMissing = 1005
    case pipelineStateNulled = 1006
    case filenameNotFound = 1007
    case memoryPoolDeallocationBlocksFree = 1008
    case memoryPoolDeallocationNotEnoughMem = 1009
    case memoryPoolFailedToAllocate = 1010
    case memoryPoolNoBlocksAllocated = 1011
    case memoryPoolAssetNotInAllocation = 1012
    case memoryPoolWritingBeyondCapacity = 1013
    case memoryPoolReadingBeyongCapacity = 1014
    
    var description: String{
        
        switch self{
        case .pipelineStateCreationFailed:
            return "Failed to create pipeline state."
        case .bufferAllocationFailed:
            return "Buffer allocation failed."
        case .renderPassDescriptorCreationFailed:
            return "Failed to created render pass descriptor."
        case .renderPassCreationFailed:
            return "Failed to create render pass."
        case .assetDataMissing:
            return "Asset data missing for Entity ID:"
        case .pipelineStateNulled:
            return "Pipeline State is null"
        case .filenameNotFound:
            return "Filename not found"
        case .memoryPoolDeallocationBlocksFree:
            return "Deallocation Failed: Block already free"
        case .memoryPoolDeallocationNotEnoughMem:
            return "Allocation Failed: Not enough blocks available"
        case .memoryPoolFailedToAllocate:
            return "Failed to find continuous blocks for Asset"
        case .memoryPoolNoBlocksAllocated:
            return "No blocks allocated for Asset"
        case .memoryPoolAssetNotInAllocation:
            return "Asset not found in allocations"
        case .memoryPoolWritingBeyondCapacity:
            return "Writing beyond the buffer's capacity"
        case .memoryPoolReadingBeyongCapacity:
            return "Reading beyond the buffer's capacity"
        }
    }
}

func handleError(_ error: ErrorHandlingSystem, _ blocksNeeded:Int, _ assetId:AssetID){
    print("Error: \(error.rawValue): \(error.description). Blocks needed: \(blocksNeeded) for asset id \(assetId)")
}

func handleError(_ error: ErrorHandlingSystem){
    print("Error: \(error.rawValue): \(error.description)")
}

func handleError(_ error: ErrorHandlingSystem, _ entityId:EntityID){
    print("Error: \(error.rawValue): \(error.description) for \(entityId)")
}

func handleError(_ error: ErrorHandlingSystem, _ name:String){
    print("Error: \(error.rawValue): \(error.description) for \(name)")
}
