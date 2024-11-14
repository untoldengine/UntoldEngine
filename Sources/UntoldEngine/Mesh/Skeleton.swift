//
//  Skeleton.swift
//  UntoldEngine
//
//  Created by Harold Serrano on 11/13/24.
//

import MetalKit

struct Skeleton {
    
    let parentIndices: [Int?]
    let jointPaths: [String]
    let bindTransforms: [simd_float4x4]
    let restTransforms: [simd_float4x4]
    var currentPose: [simd_float4x4] = []
    
    init?(mdlSkeleton: MDLSkeleton?) {
        // Check if the skeleton and joint paths exist
        guard let mdlSkeleton, !mdlSkeleton.jointPaths.isEmpty else { return nil }
        
        // Initialize properties using helper functions for clarity
        self.jointPaths = mdlSkeleton.jointPaths
        self.parentIndices = Skeleton.computeParentIndices(for: jointPaths)
        self.bindTransforms = mdlSkeleton.jointBindTransforms.float4x4Array
        self.restTransforms = mdlSkeleton.jointRestTransforms.float4x4Array
    }
    
    // Static method to compute parent indices for each joint path
    static func computeParentIndices(for jointPaths: [String]) -> [Int?] {
        return jointPaths.enumerated().map { (index, jointPath) in
            let parentPath = URL(fileURLWithPath: jointPath).deletingLastPathComponent().relativePath
            return jointPaths.firstIndex { $0 == parentPath }
        }
    }
    
    // Maps provided joint paths to indices within the skeleton’s joint paths
    func mapJoints(from paths: [String]) -> [Int] {
        paths.compactMap { self.jointPaths.firstIndex(of: $0) }
    }
}

struct Skin {
    var jointPaths: [String]
    var skeletonMap: [Int]
    var jointMatrixBuffer: MTLBuffer
    
    init?(bindComponent: MDLAnimationBindComponent?, skeleton: Skeleton?) {
        // Ensure bind component and skeleton exist
        guard let bindComponent, let skeleton else {
            print("Error: Missing bind component or skeleton.")
            return nil
        }
        
        // Set up paths and mapping
        self.jointPaths = bindComponent.jointPaths ?? skeleton.jointPaths
        self.skeletonMap = skeleton.mapJoints(from: jointPaths)
        
        // Initialize the joint matrix buffer
        let bufferSize = jointPaths.count * MemoryLayout<simd_float4x4>.stride
        guard let buffer = renderInfo.device.makeBuffer(length: bufferSize) else {
            print("Error: Could not create joint matrix buffer.")
            return nil
        }
        self.jointMatrixBuffer = buffer
    }
    
    // Updates joint matrices in the buffer with the current skeleton pose
    func updateJointMatrices(with skeleton: Skeleton?) {
        guard let skeletonPose = skeleton?.currentPose else { return }
        
        let bufferPointer = jointMatrixBuffer.contents().bindMemory(to: simd_float4x4.self, capacity: jointPaths.count)
        for (index, skinIndex) in skeletonMap.enumerated() {
            bufferPointer[index] = skeletonPose[skinIndex]
        }
    }
}

