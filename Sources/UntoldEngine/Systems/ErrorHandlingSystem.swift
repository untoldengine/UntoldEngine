//
//  ErrorHandlingSystem.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 1/27/24.
//

import Foundation

public enum ErrorHandlingSystem: Int, Error, CustomStringConvertible {
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
    case entityMissing = 1016
    case textureMissing = 1017
    case iBLCreationFailed = 1018
    case kernelCreationFailed = 1019
    case shaderCreationFailed = 1020
    case textureCoordsMissing = 1021
    case iblMipMapBlitCreationFailed = 1022
    case iblPreFilterCreationFailed = 1023
    case iblSpecMipMapCreationFailed = 1024
    case iblSpecMipMapBlitCreationFailed = 1025
    case iblMipMapCreationFailed = 1026
    case normalTextureMissing = 1027
    case noPhysicsComponent = 1028
    case noKineticComponent = 1029
    case noRenderComponent = 1030
    case noTransformComponent = 1031
    case noSkeletonComponent = 1032
    case noAnimationComponent = 1033
    case noAnimationBind = 1034
    case jointBufferFailed = 1035
    case noSkeletonPose = 1036
    case jointBindFailed = 1037

    public var description: String {
        switch self {
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
        case .entityMissing:
            return "Entity is missing"
        case .textureMissing:
            return "Texture was not found in the file"
        case .iBLCreationFailed:
            return "IBL pre-filters unable to be created"
        case .kernelCreationFailed:
            return "Compute Kernel functions were not found"
        case .shaderCreationFailed:
            return "Shaders functions were not found"
        case .textureCoordsMissing:
            return "Texture coordinates missing"
        case .iblMipMapBlitCreationFailed:
            return "IBL Mip Map Blit failed"
        case .iblPreFilterCreationFailed:
            return "IBL Pre-Filters Generation failed"
        case .iblSpecMipMapCreationFailed:
            return "IBL Specular Mip Map Generation failed"
        case .iblSpecMipMapBlitCreationFailed:
            return "IBL Specular Mip Map Blit Failed"
        case .iblMipMapCreationFailed:
            return "IBL Mip Map Generation failed"
        case .normalTextureMissing:
            return "Normal Texture is missing"
        case .noPhysicsComponent:
            return "Does not have a Physics component"
        case .noKineticComponent:
            return "Does not have a Kinetic component"
        case .noTransformComponent:
            return "Does not have a Transform component"
        case .noRenderComponent:
            return "Does not have a Render component"
        case .noSkeletonComponent:
            return "Does not have a Skeleton component"
        case .noAnimationComponent:
            return "Does not have a Render component"
        case .noAnimationBind:
            return "Missing animation bind component or skeleton."
        case .jointBufferFailed:
            return "Failed to create joint transforms buffer."
        case .noSkeletonPose:
            return "Skeleton pose is unavailable."
        case .jointBindFailed:
            return "Failed to bind joint transforms buffer."
        }
    }
}

public func handleError(_ error: ErrorHandlingSystem) {
    print("Error: \(error.rawValue): \(error.description)")
}

public func handleError(_ error: ErrorHandlingSystem, _ entityId: EntityID) {
    print("Error: \(error.rawValue): \(error.description) for \(entityId)")
}

public func handleError(_ error: ErrorHandlingSystem, _ name: String) {
    print("Error: \(error.rawValue): \(error.description) for \(name)")
}

// warnings
public func handleWarning(_ error: ErrorHandlingSystem, _ name: String) {
    print("Warning: \(error.rawValue): \(error.description) for \(name)")
}
