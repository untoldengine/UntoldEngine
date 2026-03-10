//
//  Mesh.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import Foundation
import MetalKit
import simd

private extension simd_float3 {
    func isApproximately(_ other: simd_float3, epsilon: Float = 0.01) -> Bool {
        simd_distance(self, other) < epsilon
    }
}

private extension simd_float4x4 {
    func isApproximatelyEqual(to other: simd_float4x4, epsilon: Float = 0.0001) -> Bool {
        let delta0 = simd_length(columns.0 - other.columns.0)
        let delta1 = simd_length(columns.1 - other.columns.1)
        let delta2 = simd_length(columns.2 - other.columns.2)
        let delta3 = simd_length(columns.3 - other.columns.3)

        return delta0 < epsilon && delta1 < epsilon && delta2 < epsilon && delta3 < epsilon
    }
}

public enum CoordinateSystemConversion {
    case autoDetect // Check USD up-axis and convert only if needed
    case forceZUpToYUp // Always apply Z-up to Y-up conversion
    case none // Use transforms as-is from USD
}

private func orientationTransformForAsset(_ asset: MDLAsset, conversion: CoordinateSystemConversion) -> simd_float4x4 {
    let zUpToYUpMatrix: simd_float4x4 = {
        var m = matrix_identity_float4x4
        // Column 0: image of (1,0,0) -> X stays X
        m.columns.0 = simd_float4(1, 0, 0, 0)
        // Column 1: image of (0,1,0) -> Y becomes -Z
        m.columns.1 = simd_float4(0, 0, -1, 0)
        // Column 2: image of (0,0,1) -> Z becomes Y
        m.columns.2 = simd_float4(0, 1, 0, 0)
        // Column 3: translation
        m.columns.3 = simd_float4(0, 0, 0, 1)
        return m
    }()

    switch conversion {
    case .none:
        return matrix_identity_float4x4

    case .forceZUpToYUp:
        return zUpToYUpMatrix

    case .autoDetect:
        let sourceUp = simd_normalize(asset.upAxis)
        let yUp = simd_float3(0, 1, 0)
        let zUp = simd_float3(0, 0, 1)

        // Already Y-up → no conversion needed
        if sourceUp.isApproximately(yUp) {
            return matrix_identity_float4x4
        }

        // Z-up (Blender default) → convert to Y-up
        if sourceUp.isApproximately(zUp) {
            return zUpToYUpMatrix
        }

        // Unknown up axis → no conversion (could log warning here)
        return matrix_identity_float4x4
    }
}

private func composedWorldTransform(for object: MDLObject) -> simd_float4x4 {
    var result = simd_float4x4.identity
    var current: MDLObject? = object

    while let node = current {
        let local = node.transform?.matrix ?? .identity
        result = simd_mul(local, result)
        current = node.parent
    }

    return result
}

public struct Mesh {
    public let metalKitMesh: MTKMesh
    public var submeshes: [SubMesh] = []
    public var modelMDLMesh: MDLMesh
    public var localSpace: simd_float4x4 = .identity
    public var worldSpace: simd_float4x4 = .identity
    var assetName: String
    var boundingBox: (min: simd_float3, max: simd_float3)
    var skin: Skin?
    public var spaceUniform: [MTLBuffer?] = Array(repeating: nil, count: totalPerMeshUniformBuffers())

    init?(modelIOMesh: MDLMesh, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip _: Bool) {
        modelMDLMesh = modelIOMesh

        // Keep mesh-local transform for ECS local-space semantics.
        let meshTransform = modelIOMesh.transform?.matrix ?? .identity

        // Store local space transform
        localSpace = meshTransform

        // Compose full ModelIO ancestry chain (root -> ... -> mesh) for world space.
        worldSpace = composedWorldTransform(for: modelIOMesh)

        // Set asset name from parent, or use the mesh's own name if no parent
        assetName = modelIOMesh.parent?.name ?? modelIOMesh.name

        // Set bounding box dimensions
        boundingBox = (min: modelIOMesh.boundingBox.minBounds, max: modelIOMesh.boundingBox.maxBounds)

        // Create tangents if the mesh has texture coordinates
        if hasTextureCoordinates(mesh: modelIOMesh) {
            modelIOMesh.addOrthTanBasis(
                forTextureCoordinateAttributeNamed: MDLVertexAttributeTextureCoordinate,
                normalAttributeNamed: MDLVertexAttributeNormal,
                tangentAttributeNamed: MDLVertexAttributeTangent
            )
        }

        // Apply vertex descriptor for Metal layout compatibility
        modelIOMesh.vertexDescriptor = vertexDescriptor

        // allocate buffer

        spaceUniform = (0 ..< totalPerMeshUniformBuffers()).compactMap { _ in
            renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [MTLResourceOptions.storageModeShared])
        }

        // Create MetalKit mesh
        modelIOMesh.vertexDescriptor = vertexDescriptor
        var localMetalKitMesh: MTKMesh
        do {
            localMetalKitMesh = try MTKMesh(mesh: modelIOMesh, device: device)
        } catch {
            Logger.logError(message: "Failed to create MTKMesh for '\(assetName)': \(error.localizedDescription)")
            Logger.logError(message: "This may be due to memory pressure, corrupted mesh data, or GPU buffer allocation failure.")
            return nil
        }
        metalKitMesh = localMetalKitMesh

        // Process submeshes locally before assigning
        let processedSubmeshes: [SubMesh] = modelIOMesh.submeshes?.enumerated().compactMap { index, element in
            guard let mdlSubmesh = element as? MDLSubmesh else { return nil }
            guard index < localMetalKitMesh.submeshes.count else { return nil }
            return SubMesh(
                modelIOSubmesh: mdlSubmesh,
                metalKitSubmesh: localMetalKitMesh.submeshes[index],
                textureLoader: textureLoader
            )
        } ?? []

        submeshes = processedSubmeshes
    }

    mutating func cleanUp() {
        spaceUniform.removeAll()
        submeshes.removeAll()
        skin?.cleanUp()
        skin = nil
    }

    /// Create a copy of this mesh with fresh uniform buffers.
    /// Use this when assigning cached meshes to a new entity to avoid buffer sharing.
    func copyWithNewUniformBuffers() -> Mesh {
        var copy = self
        // Create new uniform buffers for this entity
        copy.spaceUniform = (0 ..< totalPerMeshUniformBuffers()).compactMap { _ in
            renderInfo.device.makeBuffer(length: MemoryLayout<Uniforms>.stride,
                                         options: [MTLResourceOptions.storageModeShared])
        }
        return copy
    }

    /// Load meshes from a file URL
    static func loadMeshes(url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice, flip: Bool, coordinateConversion: CoordinateSystemConversion = .autoDetect) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        // Apply coordinate system conversion if needed (e.g., Blender Z-up to engine Y-up)
        let orientationTransform = orientationTransformForAsset(asset, conversion: coordinateConversion)
        if orientationTransform != matrix_identity_float4x4 {
            for object in asset.childObjects(of: MDLObject.self) {
                object.transform = MDLTransform(matrix: simd_mul(orientationTransform, object.transform?.matrix ?? .identity))
            }
        }

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let meshes = asset.childObjects(of: MDLObject.self).flatMap {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
        }

        if !meshes.isEmpty {
            return meshes
        }

        // ---- Fallback path: fabricate a safe default mesh ----

        return makeDefaultMesh()
    }

    /// Load meshes asynchronously from a file URL
    static func loadMeshesAsync(
        url: URL,
        vertexDescriptor: MDLVertexDescriptor,
        device: MTLDevice,
        flip: Bool,
        coordinateConversion: CoordinateSystemConversion = .autoDetect,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> [Mesh] {
        // Perform heavy I/O work on background thread
        let asset = await Task.detached { () -> MDLAsset? in
            let bufferAllocator = MTKMeshBufferAllocator(device: device)

            // Validate file exists and get size
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.logError(message: "Asset file not found: \(url.path)")
                return nil
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    let fileSizeMB = Double(fileSize) / (1024 * 1024)
                    Logger.log(message: "Loading asset: \(url.lastPathComponent) (\(String(format: "%.2f", fileSizeMB)) MB)")

                    // Warn for very large files (> 500 MB)
                    if fileSizeMB > 500 {
                        Logger.logWarning(message: "Large asset detected (\(String(format: "%.2f", fileSizeMB)) MB). Loading may take time and consume significant memory.")
                    }
                }
            } catch {
                Logger.logWarning(message: "Could not determine file size: \(error.localizedDescription)")
            }

            // Wrap asset creation in error handling to catch parsing/corruption issues
            let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

            // Apply coordinate system conversion
            let transform = orientationTransformForAsset(asset, conversion: coordinateConversion)
            if transform != matrix_identity_float4x4 {
                for object in asset.childObjects(of: MDLObject.self) {
                    object.transform = MDLTransform(matrix: simd_mul(transform, object.transform?.matrix ?? .identity))
                }
            }

            // Load textures on background thread
            asset.loadTextures()

            return asset
        }.value

        // Handle asset loading failure
        guard let asset else {
            Logger.logError(message: "Failed to load asset from: \(url.lastPathComponent)")
            return makeDefaultMesh()
        }

        // Create Metal resources off-main to maximize parallelism across async loads.
        let textureLoader = TextureLoader(device: device)
        let objects = asset.childObjects(of: MDLObject.self)

        // Count total meshes
        var totalMeshCount = 0
        for object in objects {
            if let _ = object as? MDLMesh {
                totalMeshCount += 1
            } else if object.conforms(to: MDLObjectContainerComponent.self) {
                func countMeshes(_ obj: MDLObject) -> Int {
                    var count = 0
                    if let _ = obj as? MDLMesh { count += 1 }
                    for child in obj.children.objects {
                        count += countMeshes(child)
                    }
                    return count
                }
                totalMeshCount += countMeshes(object)
            }
        }

        // Check against MAX_ENTITIES
        let willEnforceLimit = totalMeshCount > MAX_ENTITIES
        if willEnforceLimit {
            Logger.logWarning(message: "⚠️  Asset contains \(totalMeshCount) meshes but MAX_ENTITIES is set to \(MAX_ENTITIES)")
            Logger.logWarning(message: "Only the first \(MAX_ENTITIES) meshes will be loaded to prevent crashes.")
            Logger.logWarning(message: "To load all meshes, increase MAX_ENTITIES in Globals.swift to at least \(totalMeshCount)")
        }

        var allMeshes: [Mesh] = []
        allMeshes.reserveCapacity(min(totalMeshCount, MAX_ENTITIES))
        var processedMeshes = 0
        let totalForProgress = min(totalMeshCount, MAX_ENTITIES)
        let progressStride = totalForProgress > 200 ? 25 : 1
        var lastReportedProgress = 0

        for object in objects {
            // Enforce MAX_ENTITIES limit
            if processedMeshes >= MAX_ENTITIES {
                Logger.logWarning(message: "🛑 Reached MAX_ENTITIES limit (\(MAX_ENTITIES)). Stopped loading.")
                Logger.logWarning(message: "Loaded \(processedMeshes)/\(totalMeshCount) meshes.")
                break
            }

            let meshes = makeMeshes(object: object, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip)
            allMeshes.append(contentsOf: meshes)
            processedMeshes += meshes.count

            if let progressHandler {
                let shouldReport = processedMeshes == totalForProgress || (processedMeshes - lastReportedProgress) >= progressStride
                if shouldReport {
                    lastReportedProgress = processedMeshes
                    progressHandler(processedMeshes, totalForProgress)
                }
            }
        }

        Logger.log(message: "✅ Loaded \(processedMeshes)/\(totalMeshCount) meshes" + (willEnforceLimit ? " (MAX_ENTITIES limit enforced)" : ""))

        if !allMeshes.isEmpty {
            return allMeshes
        }

        // Fallback to default mesh
        return makeDefaultMesh()
    }

    static func loadSceneMeshes(url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice, coordinateConversion: CoordinateSystemConversion = .autoDetect) -> [[Mesh]] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        // Apply coordinate system conversion if needed (e.g., Blender Z-up to engine Y-up)
        let orientationTransform = orientationTransformForAsset(asset, conversion: coordinateConversion)
        if orientationTransform != matrix_identity_float4x4 {
            for object in asset.childObjects(of: MDLObject.self) {
                object.transform = MDLTransform(matrix: simd_mul(orientationTransform, object.transform?.matrix ?? .identity))
            }
        }

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let meshGroups: [[Mesh]] = asset.childObjects(of: MDLObject.self).map {
            makeMeshes(object: $0, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: true)
        }

        // If the scene had no objects (or everything failed), return a single fallback group
        if meshGroups.isEmpty || meshGroups.allSatisfy(\.isEmpty) {
            Logger.logWarning(message: "Scene contained no usable meshes: \(url.lastPathComponent). Returning a single default fallback mesh.")
            return [makeDefaultMesh()]
        }

        return meshGroups
    }

    /// Load scene meshes asynchronously from a file URL
    static func loadSceneMeshesAsync(
        url: URL,
        vertexDescriptor: MDLVertexDescriptor,
        device: MTLDevice,
        coordinateConversion: CoordinateSystemConversion = .autoDetect,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> [[Mesh]] {
        // Perform heavy I/O work on background thread
        let asset = await Task.detached { () -> MDLAsset? in
            let bufferAllocator = MTKMeshBufferAllocator(device: device)

            // Validate file exists and get size
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.logError(message: "Asset file not found: \(url.path)")
                return nil
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? UInt64 {
                    let fileSizeMB = Double(fileSize) / (1024 * 1024)
                    Logger.log(message: "Loading scene asset: \(url.lastPathComponent) (\(String(format: "%.2f", fileSizeMB)) MB)")

                    // Warn for very large files (> 500 MB)
                    if fileSizeMB > 500 {
                        Logger.logWarning(message: "Large scene asset detected (\(String(format: "%.2f", fileSizeMB)) MB). Loading may take time and consume significant memory.")
                    }
                }
            } catch {
                Logger.logWarning(message: "Could not determine file size: \(error.localizedDescription)")
            }

            // Wrap asset creation in error handling to catch parsing/corruption issues
            let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

            // Apply coordinate system conversion
            let transform = orientationTransformForAsset(asset, conversion: coordinateConversion)
            if transform != matrix_identity_float4x4 {
                for object in asset.childObjects(of: MDLObject.self) {
                    object.transform = MDLTransform(matrix: simd_mul(transform, object.transform?.matrix ?? .identity))
                }
            }

            // Load textures on background thread
            asset.loadTextures()

            return asset
        }.value

        // Handle asset loading failure
        guard let asset else {
            Logger.logError(message: "Failed to load scene asset from: \(url.lastPathComponent)")
            return [makeDefaultMesh()]
        }

        // Create Metal resources off-main to maximize parallelism across async loads.
        let textureLoader = TextureLoader(device: device)
        let objects = asset.childObjects(of: MDLObject.self)

        // First pass: count total meshes for accurate progress
        var totalMeshCount = 0
        for object in objects {
            if let _ = object as? MDLMesh {
                totalMeshCount += 1
            } else if object.conforms(to: MDLObjectContainerComponent.self) {
                func countMeshes(_ obj: MDLObject) -> Int {
                    var count = 0
                    if let _ = obj as? MDLMesh { count += 1 }
                    for child in obj.children.objects {
                        count += countMeshes(child)
                    }
                    return count
                }
                totalMeshCount += countMeshes(object)
            }
        }

        // Check against MAX_ENTITIES hard limit
        let willEnforceLimit = totalMeshCount > MAX_ENTITIES
        let meshesToLoad = min(totalMeshCount, MAX_ENTITIES)

        if willEnforceLimit {
            Logger.logWarning(message: "⚠️  Scene contains \(totalMeshCount) meshes but MAX_ENTITIES is set to \(MAX_ENTITIES)")
            Logger.logWarning(message: "Only the first \(MAX_ENTITIES) meshes will be loaded to prevent crashes.")
            Logger.logWarning(message: "To load all meshes, increase MAX_ENTITIES in Globals.swift to at least \(totalMeshCount)")
            Logger.logWarning(message: "Note: Increasing MAX_ENTITIES will use more memory (~\(totalMeshCount * 2)KB additional).")
        } else {
            // Soft warnings for large scenes even within limits
            let maxRecommendedMeshes = MAX_ENTITIES / 2
            let criticalMeshCount = Int(Double(MAX_ENTITIES) * 0.8)

            if totalMeshCount > criticalMeshCount {
                Logger.logWarning(message: "Scene contains \(totalMeshCount) meshes (approaching MAX_ENTITIES limit of \(MAX_ENTITIES))")
                Logger.logWarning(message: "Loading may take time and consume significant memory.")
            } else if totalMeshCount > maxRecommendedMeshes {
                Logger.log(message: "Scene contains \(totalMeshCount) meshes (within MAX_ENTITIES limit of \(MAX_ENTITIES))")
            }
        }

        var meshGroups: [[Mesh]] = []
        var processedMeshes = 0
        var failedMeshes = 0

        let enableVerboseLogging = totalMeshCount > 1000 // Only log progress for very large scenes
        let progressStride = meshesToLoad > 200 ? 25 : 1
        var lastReportedProgress = 0

        for (index, object) in objects.enumerated() {
            // ENFORCE MAX_ENTITIES LIMIT - stop loading if we've hit the limit
            if processedMeshes >= MAX_ENTITIES {
                let remainingMeshes = totalMeshCount - processedMeshes
                Logger.logWarning(message: "🛑 Reached MAX_ENTITIES limit (\(MAX_ENTITIES)). Stopped loading.")
                Logger.logWarning(message: "Loaded \(processedMeshes)/\(totalMeshCount) meshes successfully.")
                Logger.logWarning(message: "\(remainingMeshes) meshes were not loaded.")
                Logger.logWarning(message: "Increase MAX_ENTITIES in Globals.swift to \(totalMeshCount) to load the complete scene.")
                break // Exit the loop - we've hit the entity limit
            }

            // Log progress every 200 objects for very large files (reduce spam)
            if enableVerboseLogging, index % 200 == 0, index > 0 {
                Logger.log(message: "Processing object \(index)/\(objects.count) (\(Int((Double(index) / Double(objects.count)) * 100))% complete)...")
            }

            // Wrap mesh creation to catch crashes from memory pressure
            let meshes = makeMeshes(object: object, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: true)

            if meshes.isEmpty, object is MDLMesh {
                failedMeshes += 1
                if failedMeshes <= 10 { // Only log first 10 failures to avoid spam
                    Logger.logWarning(message: "Failed to create mesh from object at index \(index). Skipping.")
                }
            }

            meshGroups.append(meshes)
            processedMeshes += meshes.count

            if let progressHandler {
                let shouldReport = processedMeshes == meshesToLoad || (processedMeshes - lastReportedProgress) >= progressStride
                if shouldReport {
                    lastReportedProgress = processedMeshes
                    progressHandler(processedMeshes, min(meshesToLoad, totalMeshCount))
                }
            }
        }

        // Log completion statistics
        let successfulMeshes = processedMeshes
        let wasLimitEnforced = totalMeshCount > MAX_ENTITIES && processedMeshes >= MAX_ENTITIES

        if wasLimitEnforced {
            Logger.log(message: "✅ Partial mesh loading complete: \(successfulMeshes)/\(totalMeshCount) meshes loaded (MAX_ENTITIES limit enforced)")
        } else {
            Logger.log(message: "✅ Mesh loading complete: \(successfulMeshes)/\(totalMeshCount) meshes loaded successfully")
        }

        if failedMeshes > 0 {
            Logger.logWarning(message: "\(failedMeshes) meshes failed to load and were skipped")
        }

        // If the scene had no objects (or everything failed), return a single fallback group
        if meshGroups.isEmpty || meshGroups.allSatisfy(\.isEmpty) {
            Logger.logWarning(message: "Scene contained no usable meshes: \(url.lastPathComponent). Returning a single default fallback mesh.")
            return [makeDefaultMesh()]
        }

        return meshGroups
    }

    static func loadMeshWithName(name: String, url: URL, vertexDescriptor: MDLVertexDescriptor, device: MTLDevice, coordinateConversion: CoordinateSystemConversion = .autoDetect) -> [Mesh] {
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

        // Apply coordinate system conversion if needed (e.g., Blender Z-up to engine Y-up)
        let orientationTransform = orientationTransformForAsset(asset, conversion: coordinateConversion)
        if orientationTransform != matrix_identity_float4x4 {
            for object in asset.childObjects(of: MDLObject.self) {
                object.transform = MDLTransform(matrix: simd_mul(orientationTransform, object.transform?.matrix ?? .identity))
            }
        }

        asset.loadTextures()

        let textureLoader = TextureLoader(device: device)

        let topLevelObjects = asset.childObjects(of: MDLObject.self)

        for mdlObject in topLevelObjects {
            if mdlObject.name == name {
                var meshGroup: [Mesh] = []

                for child in mdlObject.children.objects {
                    if let mesh = child as? MDLMesh {
                        let meshes = makeMeshes(object: mesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: renderInfo.device, flip: true)
                        meshGroup.append(contentsOf: meshes)
                    }
                }

                return meshGroup
            }
        }

        return []
    }

    /// Load a specific mesh by name asynchronously from a file URL
    static func loadMeshWithNameAsync(
        name: String,
        url: URL,
        vertexDescriptor: MDLVertexDescriptor,
        device: MTLDevice,
        coordinateConversion: CoordinateSystemConversion = .autoDetect,
        progressHandler: ((Int, Int) -> Void)? = nil
    ) async -> [Mesh] {
        // Perform heavy I/O work on background thread
        let matchedObject = await Task.detached { () -> MDLObject? in
            let bufferAllocator = MTKMeshBufferAllocator(device: device)

            // Validate file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                Logger.logError(message: "Asset file not found: \(url.path)")
                return nil
            }

            // Wrap asset creation in error handling
            let asset = MDLAsset(url: url, vertexDescriptor: vertexDescriptor, bufferAllocator: bufferAllocator)

            // Apply coordinate system conversion
            let transform = orientationTransformForAsset(asset, conversion: coordinateConversion)
            if transform != matrix_identity_float4x4 {
                for object in asset.childObjects(of: MDLObject.self) {
                    object.transform = MDLTransform(matrix: simd_mul(transform, object.transform?.matrix ?? .identity))
                }
            }

            // Load textures on background thread
            asset.loadTextures()

            // Find the matching object
            let topLevelObjects = asset.childObjects(of: MDLObject.self)
            return topLevelObjects.first { $0.name == name }
        }.value

        // Create Metal resources off-main to maximize parallelism across async loads.
        guard let mdlObject = matchedObject else {
            return []
        }

        let textureLoader = TextureLoader(device: device)
        var meshGroup: [Mesh] = []

        let children = mdlObject.children.objects
        let totalChildren = children.count
        let progressStride = totalChildren > 200 ? 10 : 1
        var processedCount = 0
        var lastReportedProgress = 0

        for child in children {
            if let mesh = child as? MDLMesh {
                let meshes = makeMeshes(object: mesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: renderInfo.device, flip: true)
                meshGroup.append(contentsOf: meshes)
            }

            processedCount += 1
            if let progressHandler {
                let shouldReport = processedCount == totalChildren || (processedCount - lastReportedProgress) >= progressStride
                if shouldReport {
                    lastReportedProgress = processedCount
                    progressHandler(processedCount, totalChildren)
                }
            }
        }

        return meshGroup
    }

    /// Recursively find and create Mesh objects from ModelIO hierarchy
    static func makeMeshes(object: MDLObject, vertexDescriptor: MDLVertexDescriptor, textureLoader: TextureLoader, device: MTLDevice, flip: Bool) -> [Mesh] {
        var meshes = [Mesh]()

        if let mdlMesh = object as? MDLMesh {
            if let mesh = Mesh(modelIOMesh: mdlMesh, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip) {
                meshes.append(mesh)
            } else {
                Logger.logWarning(message: "Skipped mesh '\(mdlMesh.name)' due to creation failure. Continuing with remaining meshes.")
            }
        }

        if object.conforms(to: MDLObjectContainerComponent.self) {
            for child in object.children.objects {
                meshes.append(contentsOf: makeMeshes(object: child, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader, device: device, flip: flip))
            }
        }

        return meshes
    }

    static func computeMeshBoundingBox(for meshes: [Mesh]) -> (min: simd_float3, max: simd_float3) {
        guard meshes.isEmpty == false else {
            return (min: .zero, max: .zero)
        }

        // Start with infinity bounds to ensure proper min/max comparisons
        var combinedMin = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var combinedMax = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        for mesh in meshes {
            let meshMin = mesh.boundingBox.min
            let meshMax = mesh.boundingBox.max
            let corners: [simd_float3] = [
                simd_float3(meshMin.x, meshMin.y, meshMin.z),
                simd_float3(meshMin.x, meshMin.y, meshMax.z),
                simd_float3(meshMin.x, meshMax.y, meshMin.z),
                simd_float3(meshMin.x, meshMax.y, meshMax.z),
                simd_float3(meshMax.x, meshMin.y, meshMin.z),
                simd_float3(meshMax.x, meshMin.y, meshMax.z),
                simd_float3(meshMax.x, meshMax.y, meshMin.z),
                simd_float3(meshMax.x, meshMax.y, meshMax.z),
            ]

            var transformedMin = simd_float3(Float.infinity, Float.infinity, Float.infinity)
            var transformedMax = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

            for corner in corners {
                let transformed = simd_mul(mesh.localSpace, simd_float4(corner.x, corner.y, corner.z, 1.0))
                let transformedPoint = simd_float3(transformed.x, transformed.y, transformed.z)
                transformedMin = simd_min(transformedMin, transformedPoint)
                transformedMax = simd_max(transformedMax, transformedPoint)
            }

            combinedMin = simd_min(combinedMin, transformedMin)
            combinedMax = simd_max(combinedMax, transformedMax)
        }

        return (min: combinedMin, max: combinedMax)
    }

    /// Helper to create one fallback mesh
    static func makeDefaultMesh() -> [Mesh] {
        let textureLoader = TextureLoader(device: renderInfo.device)
        let bufferAllocator = MTKMeshBufferAllocator(device: renderInfo.device)

        let fallbackMDL = MDLMesh(
            sphereWithExtent: [0.5, 0.5, 0.5],
            segments: [32, 16],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: bufferAllocator
        )
        fallbackMDL.name = "UntoldEngine_DefaultMesh"
        let fallback = Mesh.makeMeshes(object: fallbackMDL,
                                       vertexDescriptor: vertexDescriptor.model,
                                       textureLoader: textureLoader,
                                       device: renderInfo.device,
                                       flip: true)
        if fallback.isEmpty {
            Logger.logWarning(message: "Default mesh group creation returned empty; check vertex descriptor/material pipeline.")
        }
        return fallback
    }
}

public struct SubMesh {
    public let metalKitSubmesh: MTKSubmesh
    public var material: Material?

    init(metalKitSubmesh: MTKSubmesh) {
        self.metalKitSubmesh = metalKitSubmesh
    }

    init(modelIOSubmesh: MDLSubmesh, metalKitSubmesh: MTKSubmesh, textureLoader: TextureLoader) {
        self.metalKitSubmesh = metalKitSubmesh

        // Fallback to an empty material if none is provided
        if let mdlMaterial = modelIOSubmesh.material {
            material = Material(mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        } else {
            material = nil
        }
    }
}

public enum WrapMode: Int, CaseIterable, Identifiable, CustomStringConvertible {
    case clampToEdge
    case `repeat`

    public var id: Int {
        rawValue
    }

    public var description: String {
        switch self {
        case .clampToEdge: return "Clamp to Edge"
        case .repeat: return "Repeat"
        }
    }
}

public enum MaterialAlphaMode: Int32, CaseIterable, Identifiable, CustomStringConvertible {
    case opaque = 0
    case mask = 1
    case blend = 2

    public var id: Int32 {
        rawValue
    }

    public var description: String {
        switch self {
        case .opaque: return "Opaque"
        case .mask: return "Mask"
        case .blend: return "Blend"
        }
    }
}

public struct TextureDescriptor {
    public var texture: MTLTexture?
    public var sampler: MTLSamplerState?
    public var wrapMode: WrapMode = .clampToEdge
}

private func clamp01(_ value: Float) -> Float {
    max(0.0, min(1.0, value))
}

private func normalizedMaterialPropertyName(_ name: String) -> String {
    String(name.lowercased().filter { $0.isLetter || $0.isNumber })
}

private func materialPropertyScalar(_ property: MDLMaterialProperty?) -> Float? {
    guard let property else { return nil }

    switch property.type {
    case .float:
        return property.floatValue
    case .float2:
        return property.float2Value.x
    case .float3:
        return property.float3Value.x
    case .float4:
        return property.float4Value.x
    case .color:
        return Float(property.color?.alpha ?? 1.0)
    case .string:
        guard let value = property.stringValue else { return nil }
        return Float(value.trimmingCharacters(in: .whitespacesAndNewlines))
    default:
        return nil
    }
}

private func materialPropertyString(_ property: MDLMaterialProperty?) -> String? {
    guard let property else { return nil }

    switch property.type {
    case .string:
        return property.stringValue?.lowercased()
    case .float, .float2, .float3, .float4, .color:
        if let scalar = materialPropertyScalar(property) {
            return String(scalar)
        }
        return nil
    default:
        return nil
    }
}

private func rgbFromCGColor(_ color: CGColor) -> simd_float3 {
    guard let components = color.components else {
        return simd_float3(1.0, 1.0, 1.0)
    }

    switch components.count {
    case 0:
        return simd_float3(1.0, 1.0, 1.0)
    case 1:
        let v = Float(components[0])
        return simd_float3(v, v, v)
    case 2:
        let v = Float(components[0])
        return simd_float3(v, v, v)
    default:
        return simd_float3(Float(components[0]), Float(components[1]), Float(components[2]))
    }
}

private func decodeBaseColorFactor(_ property: MDLMaterialProperty?) -> (value: simd_float4, hasExplicitAlpha: Bool)? {
    guard let property else { return nil }

    switch property.type {
    case .color:
        guard let cgColor = property.color else { return nil }
        let rgb = rgbFromCGColor(cgColor)
        return (simd_float4(rgb.x, rgb.y, rgb.z, Float(cgColor.alpha)), true)
    case .float4:
        let v = property.float4Value
        return (simd_float4(v.x, v.y, v.z, v.w), true)
    case .float3:
        let v = property.float3Value
        return (simd_float4(v.x, v.y, v.z, 1.0), false)
    case .float2:
        let v = property.float2Value
        return (simd_float4(v.x, v.y, 0.0, 1.0), false)
    case .float:
        let v = property.floatValue
        return (simd_float4(v, v, v, 1.0), false)
    default:
        return nil
    }
}

private func decodeAlphaModeFromMaterialMetadata(_ mdlMaterial: MDLMaterial) -> MaterialAlphaMode? {
    for index in 0 ..< mdlMaterial.count {
        guard let property = mdlMaterial[index] else { continue }
        let key = normalizedMaterialPropertyName(property.name)
        let likelyAlphaModeProperty = key.contains("alphamode")
            || key.contains("opacitymode")
            || key.contains("transparencymode")
            || key.contains("blendmode")

        guard likelyAlphaModeProperty else { continue }

        if let stringValue = materialPropertyString(property)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            if stringValue.contains("blend") || stringValue.contains("transparent") {
                return .blend
            }
            if stringValue.contains("mask") || stringValue.contains("cutout") || stringValue.contains("clip") {
                return .mask
            }
            if stringValue.contains("opaque") || stringValue.contains("none") {
                return .opaque
            }
        }

        if let scalarValue = materialPropertyScalar(property) {
            if scalarValue < 0.5 { return .opaque }
            if scalarValue < 1.5 { return .mask }
            return .blend
        }
    }
    return nil
}

private func decodeAlphaCutoffFromMaterialMetadata(_ mdlMaterial: MDLMaterial) -> Float? {
    for index in 0 ..< mdlMaterial.count {
        guard let property = mdlMaterial[index] else { continue }
        let key = normalizedMaterialPropertyName(property.name)
        let likelyCutoffProperty = key.contains("alphacutoff")
            || key.contains("alphathreshold")
            || key.contains("maskcutoff")
            || key.contains("maskthreshold")
            || key.contains("opacitycutoff")
            || key.contains("opacitythreshold")

        guard likelyCutoffProperty else { continue }
        if let scalarValue = materialPropertyScalar(property) {
            return clamp01(scalarValue)
        }
    }
    return nil
}

private func textureFormatHasAlpha(_ pixelFormat: MTLPixelFormat) -> Bool {
    switch pixelFormat {
    case .a8Unorm,
         .rgba8Unorm,
         .rgba8Unorm_srgb,
         .bgra8Unorm,
         .bgra8Unorm_srgb,
         .rgba16Unorm,
         .rgba16Float,
         .rgba32Float,
         .rgb10a2Unorm,
         .bgra10_xr,
         .bgra10_xr_srgb,
         .bgr10a2Unorm:
        return true
    default:
        return false
    }
}

private func textureLikelyHasAlphaChannel(_ texture: MTLTexture?) -> Bool {
    guard let texture else { return false }
    return textureFormatHasAlpha(texture.pixelFormat)
}

public struct Material {
    public var baseColor: TextureDescriptor
    public var roughness: TextureDescriptor
    public var metallic: TextureDescriptor
    public var normal: TextureDescriptor

    // Texture URLs
    public var baseColorURL: URL?
    public var roughnessURL: URL?
    public var metallicURL: URL?
    public var normalURL: URL?

    // Store MDLTexture references for embedded textures (USDZ)
    // These allow us to re-export or extract texture data later
    public var baseColorMDLTexture: MDLTexture?
    public var roughnessMDLTexture: MDLTexture?
    public var metallicMDLTexture: MDLTexture?
    public var normalMDLTexture: MDLTexture?

    // Default values
    public var baseColorValue: simd_float4 = .init(1.0, 1.0, 1.0, 1.0)
    public var edgeTint: simd_float4 = .init(0.0, 0.0, 0.0, 1.0)
    public var emissiveValue: simd_float3 = .zero
    public var roughnessValue: Float = 1.0
    public var metallicValue: Float = 0.0

    // Disney material properties
    public var specular: Float = 0.0
    public var specularTint: Float = 0.0
    public var subsurface: Float = 0.0
    public var anisotropic: Float = 0.0
    public var sheen: Float = 0.0
    public var sheenTint: Float = 0.0
    public var clearCoat: Float = 0.0
    public var clearCoatGloss: Float = 0.0
    public var ior: Float = 1.5
    public var emit: Bool = false
    public var interactWithLight: Bool = true
    public var alphaMode: MaterialAlphaMode = .opaque
    public var alphaCutoff: Float = 0.5

    /// Texture presence flags
    public var hasNormalMap: Bool {
        normal.texture != nil
    }

    public var hasBaseMap: Bool {
        baseColor.texture != nil
    }

    public var hasRoughMap: Bool {
        roughness.texture != nil
    }

    public var hasMetalMap: Bool {
        metallic.texture != nil
    }

    public var hasTransparency: Bool {
        alphaMode == .blend
    }

    public var stScale: Float = 1.0

    @available(*, deprecated, message: "Material name is no longer used for initialization.")
    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader, name: String) {
        _ = name
        self.init(mdlMaterial: mdlMaterial, textureLoader: textureLoader)
    }

    init(mdlMaterial: MDLMaterial, textureLoader: TextureLoader) {
        let baseColorProperty = mdlMaterial.property(with: .baseColor)

        // Load textures and set URLs
        baseColor = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: baseColorProperty, isSRGB: true, outputURL: &baseColorURL, outputMDLTexture: &baseColorMDLTexture, mapType: "Basecolor map"), wrapMode: .repeat)

        normal = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .tangentSpaceNormal), isSRGB: false, outputURL: &normalURL, outputMDLTexture: &normalMDLTexture, mapType: "Normal map"), wrapMode: .clampToEdge)

        roughness = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .roughness), isSRGB: false, outputURL: &roughnessURL, outputMDLTexture: &roughnessMDLTexture, mapType: "Roughness map"), wrapMode: .repeat)

        metallic = createTextureDescriptor(device: renderInfo.device, texture: textureLoader.loadTexture(from: mdlMaterial.property(with: .metallic), isSRGB: false, outputURL: &metallicURL, outputMDLTexture: &metallicMDLTexture, mapType: "Metallic map"), wrapMode: .repeat)

        var baseColorHasExplicitAlpha = false
        if let decodedBase = decodeBaseColorFactor(baseColorProperty) {
            baseColorValue = decodedBase.value
            baseColorHasExplicitAlpha = decodedBase.hasExplicitAlpha
        }
        roughnessValue = mdlMaterial.property(with: .roughness)?.floatValue ?? roughnessValue
        metallicValue = mdlMaterial.property(with: .metallic)?.floatValue ?? metallicValue

        // Opacity scalar modulates base alpha when provided by source material metadata.
        let opacityScalar = materialPropertyScalar(mdlMaterial.property(with: .opacity))
        if let opacityScalar {
            baseColorValue.w = clamp01(baseColorValue.w * opacityScalar)
        }

        // Import alpha metadata first; if unavailable, infer from common fallback signals.
        let explicitAlphaMode = decodeAlphaModeFromMaterialMetadata(mdlMaterial)
        let explicitAlphaCutoff = decodeAlphaCutoffFromMaterialMetadata(mdlMaterial)

        if let explicitAlphaMode {
            alphaMode = explicitAlphaMode
            if let explicitAlphaCutoff {
                alphaCutoff = explicitAlphaCutoff
            }
        } else {
            let hasAlphaFactor = baseColorHasExplicitAlpha && baseColorValue.w < 0.999
            let opacityBelowOne = (opacityScalar ?? 1.0) < 0.999

            if hasAlphaFactor || opacityBelowOne {
                alphaMode = .blend
            } else if textureLikelyHasAlphaChannel(baseColor.texture) {
                alphaMode = .mask
                alphaCutoff = explicitAlphaCutoff ?? 0.5
            } else {
                alphaMode = .opaque
            }
        }

        // if textures exist, the roughnessValue and MetallicValue act as modulators
        if roughness.texture != nil {
            roughnessValue = 1.0
        }

        if metallic.texture != nil {
            metallicValue = 1.0
        }

        // Load remaining Disney properties
        specular = mdlMaterial.property(with: .specular)?.floatValue ?? 0.0
        specularTint = mdlMaterial.property(with: .specularTint)?.floatValue ?? 0.0
        subsurface = mdlMaterial.property(with: .subsurface)?.floatValue ?? 0.0
        anisotropic = mdlMaterial.property(with: .anisotropicRotation)?.floatValue ?? 0.0
        sheenTint = mdlMaterial.property(with: .sheenTint)?.floatValue ?? 0.0
        clearCoat = mdlMaterial.property(with: .clearcoat)?.floatValue ?? 0.0
        ior = mdlMaterial.property(with: .materialIndexOfRefraction)?.floatValue ?? 1.5
    }
}

final class TextureLoader {
    let device: MTLDevice
    private let mtkLoader: MTKTextureLoader
    private var textureCache: [TextureCacheKey: MTLTexture] = [:]

    private struct TextureCacheKey: Hashable {
        let id: String
        let isSRGB: Bool
    }

    init(device: MTLDevice) {
        self.device = device
        mtkLoader = MTKTextureLoader(device: device)
    }

    private func textureViewMatchingSRGB(_ tex: MTLTexture, wantSRGB: Bool) -> MTLTexture {
        let pairs: [MTLPixelFormat: (linear: MTLPixelFormat, srgb: MTLPixelFormat)] = [
            .rgba8Unorm: (.rgba8Unorm, .rgba8Unorm_srgb),
            .rgba8Unorm_srgb: (.rgba8Unorm, .rgba8Unorm_srgb),
            .bgra8Unorm: (.bgra8Unorm, .bgra8Unorm_srgb),
            .bgra8Unorm_srgb: (.bgra8Unorm, .bgra8Unorm_srgb),
        ]

        guard let pair = pairs[tex.pixelFormat] else { return tex }
        let target = wantSRGB ? pair.srgb : pair.linear
        if tex.pixelFormat == target { return tex }
        return tex.makeTextureView(pixelFormat: target) ?? tex
    }

    /// Build a stable identity URL for USDZ-embedded textures.
    /// Uses the package-relative path when available (from ModelIO stringValue),
    /// so identical embedded textures shared across meshes get the same identity.
    private func embeddedTextureURL(from property: MDLMaterialProperty, fallbackTextureName: String) -> URL? {
        if let propertyString = property.stringValue,
           let openBracket = propertyString.lastIndex(of: "["),
           let closeBracket = propertyString.lastIndex(of: "]"),
           openBracket < closeBracket
        {
            let start = propertyString.index(after: openBracket)
            let rawInnerPath = String(propertyString[start ..< closeBracket])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\\", with: "/")

            if !rawInnerPath.isEmpty {
                let encodedPath = rawInnerPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? rawInnerPath
                return URL(string: "usdz-embedded://\(encodedPath)")
            }
        }

        let encodedFallback = fallbackTextureName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fallbackTextureName
        return URL(string: "usdz-embedded://\(encodedFallback)")
    }

    func loadTexture(from property: MDLMaterialProperty?,
                     isSRGB: Bool,
                     outputURL: inout URL?,
                     outputMDLTexture: inout MDLTexture?,
                     mapType: String) -> MTLTexture?
    {
        guard let property else { return nil }

        let options: [MTKTextureLoader.Option: Any] = [
            .textureUsage: MTLTextureUsage([.shaderRead, .pixelFormatView]).rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .SRGB: isSRGB,
            .generateMipmaps: true,
            .origin: MTKTextureLoader.Origin.topLeft, // matches MDL byte layout
        ]

        // 1) Prefer the sampler path (works for USDZ-embedded textures)
        if let sampler = property.textureSamplerValue,
           let mdlTex = sampler.texture
        {
            let textureName = mdlTex.name.isEmpty ? "embedded_\(mapType.replacingOccurrences(of: " ", with: "_"))" : mdlTex.name
            let stableEmbeddedURL = embeddedTextureURL(from: property, fallbackTextureName: textureName)
            let stableIdentity = stableEmbeddedURL?.absoluteString ?? "usdz-embedded://\(textureName)"
            let cacheKey = TextureCacheKey(id: stableIdentity, isSRGB: isSRGB)
            if let cached = textureCache[cacheKey] {
                outputURL = stableEmbeddedURL ?? URL(string: cacheKey.id)
                outputMDLTexture = mdlTex
                return cached
            }

            do {
                let tex = try mtkLoader.newTexture(texture: mdlTex, options: options)

                outputURL = stableEmbeddedURL

                // Store the MDLTexture reference for later use (e.g., texture extraction)
                outputMDLTexture = mdlTex

                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                textureCache[cacheKey] = texView
                return texView
            } catch {
                handleError(.textureFailedLoading)
            }
        }

        // URL (absolute or resolved by USD/MDL)
        if let url = property.urlValue {
            let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
            if let cached = textureCache[cacheKey] {
                outputURL = url
                return cached
            }
            if let tex = try? mtkLoader.newTexture(URL: url, options: options) {
                outputURL = url
                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                textureCache[cacheKey] = texView
                return texView
            }
        }

        // String (relative) -> try to resolve against the model’s base path if you keep it
        if let str = property.stringValue, !str.isEmpty {
            // 1) Try as-is (absolute or already-resolved)
            if let url = URL(string: str), url.isFileURL {
                let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
                if let cached = textureCache[cacheKey] {
                    outputURL = url
                    return cached
                }
                if let tex = try? mtkLoader.newTexture(URL: url, options: options) {
                    outputURL = url
                    let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                    textureCache[cacheKey] = texView
                    return texView
                }
            }
            // 2) Try against known asset base
            if let base = assetBasePath {
                let candidate = base.appendingPathComponent(str)
                let cacheKey = TextureCacheKey(id: candidate.standardizedFileURL.path, isSRGB: isSRGB)
                if let cached = textureCache[cacheKey] {
                    outputURL = candidate
                    return cached
                }
                if FileManager.default.fileExists(atPath: candidate.path),
                   let tex = try? mtkLoader.newTexture(URL: candidate, options: options)
                {
                    outputURL = candidate
                    let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                    textureCache[cacheKey] = texView
                    return texView
                }
            }
            // 3) Try resources bundle lookup by filename
            let name = URL(fileURLWithPath: str).deletingPathExtension().lastPathComponent
            let ext = URL(fileURLWithPath: str).pathExtension
            if let url = getResourceURL(resourceName: name, ext: ext.isEmpty ? "png" : ext, subName: nil),
               let tex = try? mtkLoader.newTexture(URL: url, options: options)
            {
                let cacheKey = TextureCacheKey(id: url.standardizedFileURL.path, isSRGB: isSRGB)
                outputURL = url
                let texView = textureViewMatchingSRGB(tex, wantSRGB: isSRGB)
                textureCache[cacheKey] = texView
                return texView
            }
        }

        return nil
    }

    func loadDefaultColorTexture(color: simd_float4) -> MTLTexture? {
        // Generate a 1x1 texture with a solid color
        let descriptor = MTLTextureDescriptor()
        descriptor.pixelFormat = .rgba8Unorm_srgb
        descriptor.width = 1
        descriptor.height = 1
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        let rawData = [UInt8(color.x * 255), UInt8(color.y * 255), UInt8(color.z * 255), UInt8(color.w * 255)]
        texture.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: rawData, bytesPerRow: 4)
        return texture
    }

    func defaultTexture() -> MTLTexture {
        let size = 64
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm_srgb, width: size, height: size, mipmapped: true)
        desc.usage = [.shaderRead]
        guard let tex = renderInfo.device.makeTexture(descriptor: desc) else {
            Logger.logError(message: "Failed to create default texture. GPU may be out of memory.")
            fatalError("Critical: Unable to create default texture. Metal device may be unavailable.")
        }

        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for y in 0 ..< size {
            for x in 0 ..< size {
                let isDark = ((x / 8 + y / 8) % 2) == 0
                let c: UInt8 = isDark ? 200 : 50
                let i = (y * size + x) * 4
                pixels[i + 0] = c
                pixels[i + 1] = c
                pixels[i + 2] = c
                pixels[i + 3] = 255
            }
        }
        tex.replace(region: MTLRegionMake2D(0, 0, size, size), mipmapLevel: 0, withBytes: pixels, bytesPerRow: size * 4)
        return tex
    }
}

func createTextureDescriptor(device: MTLDevice,
                             texture: MTLTexture?,
                             wrapMode: WrapMode) -> TextureDescriptor
{
    let sampler = cachedSamplerState(device: device, wrapMode: wrapMode)
    return TextureDescriptor(texture: texture, sampler: sampler, wrapMode: wrapMode)
}

private enum TextureSamplerCache {
    static var cache: [WrapMode: MTLSamplerState] = [:]
    static let lock = NSLock()
}

private func cachedSamplerState(device: MTLDevice, wrapMode: WrapMode) -> MTLSamplerState? {
    TextureSamplerCache.lock.lock()
    defer { TextureSamplerCache.lock.unlock() }

    if let existing = TextureSamplerCache.cache[wrapMode] {
        return existing
    }

    let samplerDescriptor = MTLSamplerDescriptor()
    samplerDescriptor.minFilter = .linear
    samplerDescriptor.magFilter = .linear
    samplerDescriptor.mipFilter = .linear
    samplerDescriptor.sAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge
    samplerDescriptor.tAddressMode = (wrapMode == .repeat) ? .repeat : .clampToEdge

    let sampler = device.makeSamplerState(descriptor: samplerDescriptor)
    if let sampler {
        TextureSamplerCache.cache[wrapMode] = sampler
    }

    return sampler
}
