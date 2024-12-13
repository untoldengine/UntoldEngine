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
    case noLocalTransformComponent = 1031
    case noSkeletonComponent = 1032
    case noAnimationComponent = 1033
    case noAnimationBind = 1034
    case jointBufferFailed = 1035
    case noSkeletonPose = 1036
    case jointBindFailed = 1037
    case assetHasNoAnimation = 1038
    case fileTypeNotSupported = 1039
    case noentitiesinscene = 1040
    case componentNotFound = 1041
    case failedToGetComponentPointer = 1042
    case valueisNaN = 1043
    case textureFailedLoading = 1044
    case noWorldTransformComponent = 1045

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
            return "Entity is missing or does not exist"
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
            return "Does not have a Physics component. Call setEntityKinetics()"
        case .noKineticComponent:
            return "Does not have a Kinetic component. Call setEntityKinetics()"
        case .noLocalTransformComponent:
            return "Does not have a Local Transform component"
        case .noRenderComponent:
            return "Does not have a Render component"
        case .noSkeletonComponent:
            return "Does not have a Skeleton component"
        case .noAnimationComponent:
            return "Does not have an Animation component. Call setEntityAnimations()"
        case .noAnimationBind:
            return "Missing animation bind component or skeleton."
        case .jointBufferFailed:
            return "Failed to create joint transforms buffer."
        case .noSkeletonPose:
            return "Skeleton pose is unavailable."
        case .jointBindFailed:
            return "Failed to bind joint transforms buffer."
        case .assetHasNoAnimation:
            return "Asset file has no animations"
        case .fileTypeNotSupported:
            return "File type not supported at this moment"
        case .noentitiesinscene:
            return "No entities in the scene"
        case .componentNotFound:
            return "Component pool for type could not be found"
        case .failedToGetComponentPointer:
            return "Failed to get component pointer"
        case .valueisNaN:
            return "value is NaN"
        case .textureFailedLoading:
            return "Failed to load texture"
        case .noWorldTransformComponent:
            return "Does not have a World Transform component"
        }
    }
}

public func handleError(_ error: ErrorHandlingSystem) {
    Logger.logError(message: "\(error.rawValue): \(error.description)")
}

public func handleError(_ error: ErrorHandlingSystem, _ entityId: EntityID) {
    
    guard let name=getEntityName(entityId: entityId)else{
        return
    }
    handleError(error,name)
//    Logger.logError(message: "\(error.rawValue): \(error.description) for \(entityId)")
}

public func handleError(_ error: ErrorHandlingSystem, _ name: String) {
    Logger.logError(message: "\(error.rawValue): \(error.description) for \(name)")
}

public func handleError(_ error: ErrorHandlingSystem, _ argument:String,  _ name: String) {
    Logger.logError(message: "\(error.rawValue): \(argument) \(error.description) for \(name)")
}

public func handleError(_ error: ErrorHandlingSystem, _ argument:String,  _ entityId: EntityID) {
    
    guard let name=getEntityName(entityId: entityId)else{
        return
    }
    handleError(error,argument,name)
    //Logger.logError(message: "\(error.rawValue): \(error.description) for argument \(argument) for \(entityId)")
}

// warnings
public func handleWarning(_ error: ErrorHandlingSystem, _ name: String) {
    Logger.logWarning(message: "\(error.rawValue): \(error.description) for \(name)")
}
