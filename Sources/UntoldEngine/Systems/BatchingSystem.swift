//
//  BatchingSystem.swift
//  UntoldEngine
//
//  Copyright (C) Untold Engine Studios
//  Licensed under the GNU LGPL v3.0 or later.
//  See the LICENSE file or <https://www.gnu.org/licenses/> for details.
//

import CShaderTypes
import Foundation
import Metal
import simd

// Represents a group of meshes batched together
public struct BatchGroup {
    var id: UUID
    var materialHash: String // Identifier for material compatibility

    // Separate buffers for each vertex attribute (simpler than interleaved)
    var positionBuffer: MTLBuffer?
    var normalBuffer: MTLBuffer?
    var uvBuffer: MTLBuffer?
    var tangentBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?

    var indexCount: Int
    var vertexCount: Int
    var entityIds: [EntityID] // Original entities in this batch
    var meshIndices: [(entityId: EntityID, meshIndex: Int)] // Track source meshes
    var boundingBox: (min: simd_float3, max: simd_float3)
}

// Manages all batching operations
public class BatchingSystem {
    public static let shared = BatchingSystem()

    public private(set) var batchGroups: [BatchGroup] = []
    private var entityToBatch: [EntityID: UUID] = [:] // Track which batch an entity belongs to
    private var batchingEnabled: Bool = false

    private init() {}

    // Generate batches for all static entities in the scene
    public func generateBatches() {
        Logger.log(message: "🔨 Starting static batch generation...")

        // Update all world transforms before batching
        // (batching needs accurate world positions)
        traverseSceneGraph()

        // Clear existing batches
        clearBatches()

        let transformId = getComponentId(for: WorldTransformComponent.self)
        let renderId = getComponentId(for: RenderComponent.self)
        let staticBatchId = getComponentId(for: StaticBatchComponent.self)
        let entities = queryEntitiesWithComponentIds([transformId, renderId, staticBatchId], in: scene)

        Logger.log(message: "📋 Found \(entities.count) entities with StaticBatchComponent")

        // Group meshes by material
        var materialGroups: [String: [(entityId: EntityID, mesh: Mesh, meshIndex: Int, transform: simd_float4x4)]] = [:]

        // Iterate through all entities with StaticBatchComponent
        for entityId in entities {
            // Check if entity has required components
            guard let staticBatch = scene.get(component: StaticBatchComponent.self, for: entityId),
                  staticBatch.canBatch,
                  let renderComponent = scene.get(component: RenderComponent.self, for: entityId),
                  let worldTransform = scene.get(component: WorldTransformComponent.self, for: entityId),
                  let localTransform = scene.get(component: LocalTransformComponent.self, for: entityId)
            else { continue }

            // Skip entities with animations
            if scene.get(component: SkeletonComponent.self, for: entityId) != nil { continue }
            if scene.get(component: AnimationComponent.self, for: entityId) != nil { continue }

            // Skip gizmos and special entities
            if scene.get(component: GizmoComponent.self, for: entityId) != nil { continue }
            if scene.get(component: LightComponent.self, for: entityId) != nil { continue }

            // Process each mesh in the render component
            for (meshIndex, mesh) in renderComponent.mesh.enumerated() {
                for (submeshIndex, submesh) in mesh.submeshes.enumerated() {
                    guard let material = submesh.material else { continue }

                    let matHash = getMaterialHash(material: material)
                    let finalTransform = simd_mul(worldTransform.space, mesh.localSpace)

                    if materialGroups[matHash] == nil {
                        materialGroups[matHash] = []
                    }
                    materialGroups[matHash]!.append((
                        entityId: entityId,
                        mesh: mesh,
                        meshIndex: submeshIndex, // Store submesh index for later use
                        transform: finalTransform
                    ))

                    Logger.log(message: "  → Entity \(entityId): mesh[\(meshIndex)].submesh[\(submeshIndex)] with material hash \(matHash.prefix(8))...")
                }
            }
        }

        Logger.log(message: "📦 Found \(materialGroups.count) material groups")

        // Log material group details
        for (matHash, meshGroup) in materialGroups {
            Logger.log(message: "  Material \(matHash.prefix(8))... has \(meshGroup.count) submeshes")
        }

        // Create batch groups
        for (matHash, meshGroup) in materialGroups {
            // Only batch if we have multiple meshes with same material
            if meshGroup.count < 2 {
                Logger.log(message: "⏭️  Skipping material \(matHash.prefix(8))... (only \(meshGroup.count) submesh, need ≥2 for batching)")
                continue
            }

            Logger.log(message: "🔗 Batching \(meshGroup.count) meshes with material hash: \(matHash.prefix(20))...")

            if let batchGroup = createBatchGroup(from: meshGroup, materialHash: matHash) {
                batchGroups.append(batchGroup)

                // Track entity to batch mapping
                for item in meshGroup {
                    entityToBatch[item.entityId] = batchGroup.id
                }
            }
        }

        Logger.log(message: "✅ Created \(batchGroups.count) batch groups")

        // Print statistics
        let totalBatchedMeshes = batchGroups.reduce(0) { $0 + $1.entityIds.count }
        Logger.log(message: "📊 Batching Stats: \(totalBatchedMeshes) meshes → \(batchGroups.count) draw calls")
    }

    private func createBatchGroup(
        from meshGroup: [(entityId: EntityID, mesh: Mesh, meshIndex: Int, transform: simd_float4x4)],
        materialHash: String
    ) -> BatchGroup? {
        var allPositions: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allNormals: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allUVs: [simd_float2] = []
        var allTangents: [simd_float4] = [] // Changed to float4 to match vertex descriptor
        var allIndices: [UInt32] = []
        var entityIds: [EntityID] = []
        var meshIndices: [(EntityID, Int)] = []

        var minBounds = simd_float3(Float.infinity, Float.infinity, Float.infinity)
        var maxBounds = simd_float3(-Float.infinity, -Float.infinity, -Float.infinity)

        // Combine all meshes
        for item in meshGroup {
            let currentVertexOffset = UInt32(allPositions.count)

            // Extract and transform vertices (returns separate arrays)
            let vertexData = extractVertices(from: item.mesh, worldTransform: item.transform)

            allPositions.append(contentsOf: vertexData.positions)
            allNormals.append(contentsOf: vertexData.normals)
            allUVs.append(contentsOf: vertexData.uvs)
            allTangents.append(contentsOf: vertexData.tangents)

            // Update bounding box (extract xyz from float4 positions)
            for position in vertexData.positions {
                let pos3 = simd_float3(position.x, position.y, position.z)
                minBounds = simd_min(minBounds, pos3)
                maxBounds = simd_max(maxBounds, pos3)
            }

            // Extract indices with offset
            let indices = extractIndices(from: item.mesh, submeshIndex: item.meshIndex, indexOffset: currentVertexOffset)
            allIndices.append(contentsOf: indices)

            entityIds.append(item.entityId)
            meshIndices.append((item.entityId, item.meshIndex))
        }

        guard !allPositions.isEmpty, !allIndices.isEmpty else {
            Logger.logWarning(message: "Failed to create batch: no vertices or indices")
            return nil
        }

        // Create separate Metal buffers for each attribute (using float4 for positions, normals, tangents)
        let positionBufferSize = allPositions.count * MemoryLayout<simd_float4>.stride
        let normalBufferSize = allNormals.count * MemoryLayout<simd_float4>.stride
        let uvBufferSize = allUVs.count * MemoryLayout<simd_float2>.stride
        let tangentBufferSize = allTangents.count * MemoryLayout<simd_float4>.stride
        let indexBufferSize = allIndices.count * MemoryLayout<UInt32>.stride

        guard let positionBuffer = renderInfo.device.makeBuffer(
            bytes: allPositions,
            length: positionBufferSize,
            options: .storageModeShared
        ) else {
            Logger.logError(message: "Failed to create batch position buffer")
            return nil
        }

        guard let normalBuffer = renderInfo.device.makeBuffer(
            bytes: allNormals,
            length: normalBufferSize,
            options: .storageModeShared
        ) else {
            Logger.logError(message: "Failed to create batch normal buffer")
            return nil
        }

        guard let uvBuffer = renderInfo.device.makeBuffer(
            bytes: allUVs,
            length: uvBufferSize,
            options: .storageModeShared
        ) else {
            Logger.logError(message: "Failed to create batch UV buffer")
            return nil
        }

        guard let tangentBuffer = renderInfo.device.makeBuffer(
            bytes: allTangents,
            length: tangentBufferSize,
            options: .storageModeShared
        ) else {
            Logger.logError(message: "Failed to create batch tangent buffer")
            return nil
        }

        guard let indexBuffer = renderInfo.device.makeBuffer(
            bytes: allIndices,
            length: indexBufferSize,
            options: .storageModeShared
        ) else {
            Logger.logError(message: "Failed to create batch index buffer")
            return nil
        }

        positionBuffer.label = "Batch Position Buffer"
        normalBuffer.label = "Batch Normal Buffer"
        uvBuffer.label = "Batch UV Buffer"
        tangentBuffer.label = "Batch Tangent Buffer"
        indexBuffer.label = "Batch Index Buffer"

        Logger.log(message: "  ✅ Created batch buffers: \(allPositions.count) positions, \(allIndices.count) indices")
        Logger.log(message: "    Bounds: min=\(minBounds), max=\(maxBounds)")

        return BatchGroup(
            id: UUID(),
            materialHash: materialHash,
            positionBuffer: positionBuffer,
            normalBuffer: normalBuffer,
            uvBuffer: uvBuffer,
            tangentBuffer: tangentBuffer,
            indexBuffer: indexBuffer,
            indexCount: allIndices.count,
            vertexCount: allPositions.count,
            entityIds: entityIds,
            meshIndices: meshIndices,
            boundingBox: (min: minBounds, max: maxBounds)
        )
    }

    // Clear all existing batches
    public func clearBatches() {
        batchGroups.removeAll()
        entityToBatch.removeAll()
    }

    // Check if an entity is part of a batch
    public func isBatched(entityId: EntityID) -> Bool {
        entityToBatch[entityId] != nil
    }

    // Get batch group for an entity
    public func getBatchGroup(for entityId: EntityID) -> BatchGroup? {
        guard let batchId = entityToBatch[entityId] else { return nil }
        return batchGroups.first { $0.id == batchId }
    }

    public func setEnabled(_ enabled: Bool) {
        batchingEnabled = enabled
    }

    public func isEnabled() -> Bool {
        batchingEnabled
    }

    // Generate a hash representing material properties for batching compatibility
    private func getMaterialHash(material: Material) -> String {
        var components: [String] = []

        // Texture URLs (or "none" if no texture)
        components.append(material.baseColorURL?.absoluteString ?? "none")
        components.append(material.roughnessURL?.absoluteString ?? "none")
        components.append(material.metallicURL?.absoluteString ?? "none")
        components.append(material.normalURL?.absoluteString ?? "none")

        // Base color value (important for meshes without textures)
        components.append(String(format: "%.2f,%.2f,%.2f,%.2f",
                                 material.baseColorValue.x,
                                 material.baseColorValue.y,
                                 material.baseColorValue.z,
                                 material.baseColorValue.w))

        // Material values (rounded to avoid tiny differences)
        components.append(String(format: "%.2f", material.roughnessValue))
        components.append(String(format: "%.2f", material.metallicValue))
        components.append(String(format: "%.2f", material.specular))
        components.append(String(format: "%.2f", material.ior))

        // Flags
        components.append("\(material.interactWithLight)")

        return components.joined(separator: "|")
    }

    // Check if two materials are compatible for batching
    private func areMaterialsCompatible(_ mat1: Material, _ mat2: Material) -> Bool {
        getMaterialHash(material: mat1) == getMaterialHash(material: mat2)
    }

    // Extract vertex data from a mesh and transform to world space
    // Returns separate arrays for each attribute (using float4 to match shader expectations)
    private func extractVertices(from mesh: Mesh, worldTransform: simd_float4x4) -> (
        positions: [simd_float4],
        normals: [simd_float4],
        uvs: [simd_float2],
        tangents: [simd_float4]
    ) {
        var positions: [simd_float4] = []
        var normals: [simd_float4] = []
        var uvs: [simd_float2] = []
        var tangents: [simd_float4] = []

        let metalMesh = mesh.metalKitMesh

        // Get vertex buffers
        guard metalMesh.vertexBuffers.count > Int(modelPassVerticesIndex.rawValue) else {
            return (positions, normals, uvs, tangents)
        }

        let positionBuffer = metalMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer
        let normalBuffer = metalMesh.vertexBuffers[Int(modelPassNormalIndex.rawValue)].buffer
        let uvBuffer = metalMesh.vertexBuffers[Int(modelPassUVIndex.rawValue)].buffer
        let tangentBuffer = metalMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer

        // Get vertex count
        guard mesh.submeshes.first != nil else { return (positions, normals, uvs, tangents) }
        let vertexCount = metalMesh.vertexCount

        // Extract raw data (Metal vertex buffers use float4 for positions, normals, tangents)
        let posData = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let normData = normalBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)
        let uvData = uvBuffer.contents().bindMemory(to: simd_float2.self, capacity: vertexCount)
        let tanData = tangentBuffer.contents().bindMemory(to: simd_float4.self, capacity: vertexCount)

        // Calculate normal transformation matrix (inverse transpose of upper 3x3)
        let upperModelMatrix = matrix_float3x3(columns: (
            simd_float3(worldTransform.columns.0.x, worldTransform.columns.0.y, worldTransform.columns.0.z),
            simd_float3(worldTransform.columns.1.x, worldTransform.columns.1.y, worldTransform.columns.1.z),
            simd_float3(worldTransform.columns.2.x, worldTransform.columns.2.y, worldTransform.columns.2.z)
        ))
        let normalMatrix = upperModelMatrix.inverse.transpose

        // Reserve capacity
        positions.reserveCapacity(vertexCount)
        normals.reserveCapacity(vertexCount)
        uvs.reserveCapacity(vertexCount)
        tangents.reserveCapacity(vertexCount)

        // Transform and append
        for i in 0 ..< vertexCount {
            // Transform position to world space (keep as float4)
            let localPos = posData[i] // Already float4 with w component
            let worldPos = worldTransform * localPos
            positions.append(worldPos)

            // Transform normal to world space (extract xyz, transform, then pack as float4 with w=0)
            let localNorm = simd_float3(normData[i].x, normData[i].y, normData[i].z)
            let worldNormal = simd_normalize(normalMatrix * localNorm)
            normals.append(simd_float4(worldNormal.x, worldNormal.y, worldNormal.z, 0.0))

            // UVs don't need transformation
            uvs.append(uvData[i])

            // Transform tangent to world space (extract xyz, transform, preserve w)
            let localTan = simd_float3(tanData[i].x, tanData[i].y, tanData[i].z)
            let worldTangent = simd_normalize(normalMatrix * localTan)
            tangents.append(simd_float4(worldTangent.x, worldTangent.y, worldTangent.z, tanData[i].w))
        }

        return (positions, normals, uvs, tangents)
    }

    // Extract indices from a mesh with offset applied
    private func extractIndices(from mesh: Mesh, submeshIndex: Int, indexOffset: UInt32) -> [UInt32] {
        var indices: [UInt32] = []

        guard submeshIndex < mesh.submeshes.count else { return indices }
        let submesh = mesh.submeshes[submeshIndex]

        let indexBuffer = submesh.metalKitSubmesh.indexBuffer.buffer
        let indexCount = submesh.metalKitSubmesh.indexCount
        let indexType = submesh.metalKitSubmesh.indexType

        if indexType == .uint16 {
            let rawIndices = indexBuffer.contents().bindMemory(to: UInt16.self, capacity: indexCount)
            for i in 0 ..< indexCount {
                indices.append(UInt32(rawIndices[i]) + indexOffset)
            }
        } else if indexType == .uint32 {
            let rawIndices = indexBuffer.contents().bindMemory(to: UInt32.self, capacity: indexCount)
            for i in 0 ..< indexCount {
                indices.append(rawIndices[i] + indexOffset)
            }
        }

        return indices
    }
}
