//
//  UntoldMeshLODCooker.swift
//  UntoldEngineMeshCook
//
//  Builds the automatic LOD chain of a cooked `.untold` model: simplified copies of the
//  model written next to it, each with the screen size from which it is detailed enough.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CMeshOptimizer
import Foundation
import simd
import UntoldEngine

/// Settings of the automatic LOD cook.
public struct UntoldMeshLODOptions: Sendable, Equatable {
    /// The share of the model's triangles each level aims for, finest first.
    public var ratios: [Float]
    /// Models with fewer triangles than this get no chain.
    public var minimumTriangles: Int
    /// How many screen pixels a triangle of a level should cover when the level takes
    /// over, at `referenceViewportHeight`. Higher values switch to the simpler levels
    /// sooner.
    public var pixelsPerTriangle: Float

    /// The viewport height, in pixels, that a level's `screenSize` is written for.
    public static let referenceViewportHeight: Float = 1080

    /// A level is written when it has at most this share of the triangles of the
    /// level before it; one that the simplifier could not reduce further is skipped.
    static let worthwhileReduction: Float = 0.85

    public init(ratios: [Float] = [0.5, 0.15, 0.03], minimumTriangles: Int = 2000, pixelsPerTriangle: Float = 4) {
        self.ratios = ratios
        self.minimumTriangles = minimumTriangles
        self.pixelsPerTriangle = pixelsPerTriangle
    }

    func validate() throws {
        guard !ratios.isEmpty, ratios.count <= 8 else {
            throw UntoldMeshLODError.invalidOptions("between 1 and 8 ratios are needed")
        }
        for (index, ratio) in ratios.enumerated() {
            guard ratio > 0, ratio < 1 else {
                throw UntoldMeshLODError.invalidOptions("ratio \(ratio) must be above 0 and below 1")
            }
            guard index == 0 || ratio < ratios[index - 1] else {
                throw UntoldMeshLODError.invalidOptions("ratios must decrease: \(ratios)")
            }
        }
        guard minimumTriangles >= 0 else {
            throw UntoldMeshLODError.invalidOptions("minimumTriangles must not be negative")
        }
        guard pixelsPerTriangle > 0, pixelsPerTriangle.isFinite else {
            throw UntoldMeshLODError.invalidOptions("pixelsPerTriangle must be above 0")
        }
    }
}

/// One simplified level of a model.
public struct UntoldMeshLODLevel: Sendable, Equatable {
    public var url: URL
    public var triangleCount: Int
    /// The level is detailed enough when the model's bounding sphere covers at most
    /// this share of the viewport height (1 is the whole height), measured on a
    /// viewport `UntoldMeshLODOptions.referenceViewportHeight` pixels high.
    public var screenSize: Float
    /// The largest deviation from the model the simplifier reports, in model units.
    public var error: Float
}

/// The LOD chain of one model. `levels` is empty when the model got none, and
/// `skipped` then says why.
public struct UntoldMeshLODChain: Sendable, Equatable {
    public enum SkipReason: Sendable, Equatable {
        /// Fewer triangles than `UntoldMeshLODOptions.minimumTriangles`.
        case belowMinimumTriangles
        /// Skinned, morphing or animation-only models keep their full meshes: their
        /// levels would need the skin and the morph targets carried over.
        case deforms
        /// A mesh twin of a Gaussian splat already swaps to its splat.
        case gaussianTwin
        /// The file is itself a level of another model.
        case isLevel
        /// A file that is not a level of this model already has the name one of its
        /// levels needs; it is left as it is.
        case levelNameTaken
        /// The simplifier could not reduce the model by a worthwhile amount.
        case irreducible
    }

    public var triangleCount: Int
    public var levels: [UntoldMeshLODLevel]
    public var skipped: SkipReason?
}

public enum UntoldMeshLODError: Error, CustomStringConvertible {
    case invalidOptions(String)
    case unreadableModel(path: String, reason: String)
    case unreadableManifest(path: String, reason: String)
    case writeFailed(path: String, reason: String)

    public var description: String {
        switch self {
        case let .invalidOptions(reason):
            "Invalid LOD options: \(reason)"
        case let .unreadableModel(path, reason):
            "Could not read the model \(path): \(reason)"
        case let .unreadableManifest(path, reason):
            "Could not read the pack manifest \(path): \(reason)"
        case let .writeFailed(path, reason):
            "Could not write \(path): \(reason)"
        }
    }
}

public enum UntoldMeshLODCooker {
    /// The file of level `index` (1 is the first simplified one) of the model at `modelURL`.
    public static func levelURL(forModelAt modelURL: URL, level index: Int) -> URL {
        let stem = modelURL.deletingPathExtension().lastPathComponent
        return modelURL.deletingLastPathComponent()
            .appendingPathComponent("\(stem)_LOD\(index)")
            .appendingPathExtension(modelURL.pathExtension)
    }

    /// Builds the LOD chain of the model at `modelURL` and writes its levels next to it
    /// as `<name>_LOD1.untold`, `<name>_LOD2.untold`, ... Levels of an earlier cook are
    /// removed first, so the files on disk are always those of the returned chain.
    ///
    /// Every mesh is simplified towards each of `options.ratios`, within a deviation
    /// of one triangle of the level (the model's diameter over the square root of the
    /// level's triangle count). Vertices that two meshes of the model share stay in
    /// place, so material boundaries do not open. The texture seams of a textured mesh
    /// keep their texture coordinates, unless they hold a level well above its target.
    @discardableResult
    public static func cookChain(forModelAt modelURL: URL, options: UntoldMeshLODOptions = UntoldMeshLODOptions()) throws -> UntoldMeshLODChain {
        try options.validate()

        let fileData: Data
        let decoded: UntoldDecodedAsset
        let reader = UntoldReader()
        do {
            fileData = try Data(contentsOf: modelURL, options: .mappedIfSafe)
            decoded = try reader.readAsset(from: fileData)
        } catch {
            throw UntoldMeshLODError.unreadableModel(path: modelURL.path, reason: String(describing: error))
        }

        let triangleCount = decoded.meshes.reduce(0) { $0 + Int($1.indexCount) / 3 }
        func skip(_ reason: UntoldMeshLODChain.SkipReason) -> UntoldMeshLODChain {
            UntoldMeshLODChain(triangleCount: triangleCount, levels: [], skipped: reason)
        }
        if decoded.header.flags & UntoldFileFlags.generatedLODLevel != 0 {
            // Not a model: the levels around it belong to the model it was made from.
            return skip(.isLevel)
        }
        let fileManager = FileManager.default
        for index in 1 ... options.ratios.count {
            let url = levelURL(forModelAt: modelURL, level: index)
            if fileManager.fileExists(atPath: url.path), !isGeneratedLevel(url) {
                return skip(.levelNameTaken)
            }
        }
        try removeLevels(ofModelAt: modelURL)
        if decoded.header.fileType == .animation || !decoded.skins.isEmpty || !decoded.morphTargets.isEmpty {
            return skip(.deforms)
        }
        if !decoded.gaussianAssets.isEmpty {
            return skip(.gaussianTwin)
        }
        if triangleCount < max(options.minimumTriangles, 1) {
            return skip(.belowMinimumTriangles)
        }

        var unpacked: [UntoldLODMesh]
        let transforms: [simd_float4x4]
        do {
            let vertexChunk = try reader.readChunkData(.vertexData, from: fileData, entries: decoded.chunks)
            let indexChunk = try reader.readChunkData(.indexData, from: fileData, entries: decoded.chunks)
            unpacked = try decoded.meshes.map { try unpack($0, vertexChunk: vertexChunk, indexChunk: indexChunk) }
            transforms = try meshTransforms(decoded)
        } catch {
            throw UntoldMeshLODError.unreadableModel(path: modelURL.path, reason: String(describing: error))
        }
        applyVertexFlags(to: &unpacked, transforms: transforms, textured: decoded.meshes.map { usesTextures($0, in: decoded) })
        let meshes = unpacked
        let parts = meshes.map(UntoldLODMeshParts.init)
        let diameter = modelDiameter(meshes: meshes, transforms: transforms)
        let scales = transforms.map(largestAxisScale)

        var levels: [UntoldMeshLODLevel] = []
        var previousTriangles = triangleCount
        for ratio in options.ratios {
            // One triangle of the level, if its triangles tiled the model's bounding
            // square: a deviation of that size is as small on screen as the level's
            // triangles are when it takes over.
            let plannedTriangles = max(Float(triangleCount) * ratio, 1)
            let errorLimit = diameter / plannedTriangles.squareRoot()

            var meshLevels = [UntoldLODMeshLevel?](repeating: nil, count: meshes.count)
            meshLevels.withUnsafeMutableBufferPointer { results in
                // Each iteration writes its own slot.
                nonisolated(unsafe) let results = results
                DispatchQueue.concurrentPerform(iterations: meshes.count) { index in
                    let scale = scales[index]
                    results[index] = UntoldMeshLODSimplifier.level(
                        of: meshes[index],
                        parts: parts[index],
                        ratio: ratio,
                        errorLimit: scale > 0 ? errorLimit / scale : errorLimit
                    )
                }
            }
            let simplified = meshLevels.compactMap { $0 }
            let levelTriangles = simplified.reduce(0) { $0 + $1.triangleCount }
            guard simplified.count == meshes.count,
                  Float(levelTriangles) <= Float(previousTriangles) * UntoldMeshLODOptions.worthwhileReduction
            else { continue }

            let url = levelURL(forModelAt: modelURL, level: levels.count + 1)
            do {
                let file = try UntoldMeshLODWriter.levelFile(source: decoded, sourceData: fileData, levels: simplified)
                try file.write(to: url, options: .atomic)
            } catch {
                throw UntoldMeshLODError.writeFailed(path: url.path, reason: String(describing: error))
            }
            levels.append(UntoldMeshLODLevel(
                url: url,
                triangleCount: levelTriangles,
                screenSize: screenSize(triangleCount: levelTriangles, pixelsPerTriangle: options.pixelsPerTriangle),
                error: zip(simplified, scales).map { $0.error * $1 }.max() ?? 0
            ))
            previousTriangles = levelTriangles
        }

        return UntoldMeshLODChain(
            triangleCount: triangleCount,
            levels: levels,
            skipped: levels.isEmpty ? .irreducible : nil
        )
    }

    /// The screen size at which `triangleCount` triangles are about `pixelsPerTriangle`
    /// pixels each: the model's bounding square is `screenSize * referenceViewportHeight`
    /// pixels on a side.
    static func screenSize(triangleCount: Int, pixelsPerTriangle: Float) -> Float {
        (pixelsPerTriangle * Float(max(triangleCount, 1))).squareRoot() / UntoldMeshLODOptions.referenceViewportHeight
    }

    /// Deletes the level files a previous cook wrote for the model at `modelURL`.
    public static func removeLevels(ofModelAt modelURL: URL) throws {
        let fileManager = FileManager.default
        var index = 1
        while true {
            let url = levelURL(forModelAt: modelURL, level: index)
            guard fileManager.fileExists(atPath: url.path) else { return }
            // Only what a cook wrote: a file that happens to be named like a level stays.
            guard isGeneratedLevel(url) else { return }
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw UntoldMeshLODError.writeFailed(path: url.path, reason: error.localizedDescription)
            }
            index += 1
        }
    }

    private static func isGeneratedLevel(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 256),
              let header = try? UntoldFileHeaderV1.decode(from: UntoldBinaryReader(data: head))
        else { return false }
        return header.flags & UntoldFileFlags.generatedLODLevel != 0
    }

    // MARK: - Reading the model

    private static func unpack(_ record: UntoldMeshRecordV1, vertexChunk: Data, indexChunk: Data) throws -> UntoldLODMesh {
        let vertexStart = Int(record.vertexDataOffset)
        let vertexSize = Int(record.vertexCount) * UntoldLODMesh.vertexStride
        let indexStart = Int(record.indexDataOffset)
        let indexCount = Int(record.indexCount) - Int(record.indexCount) % 3
        let indexSize = indexCount * (record.indexType == .uint16 ? 2 : 4)
        guard Int(record.vertexStrideBytes) == UntoldLODMesh.vertexStride,
              vertexStart + vertexSize <= vertexChunk.count,
              indexStart + indexSize <= indexChunk.count
        else {
            throw UntoldValidationError.invalidVertexDataRange(
                offset: record.vertexDataOffset,
                size: record.vertexDataSizeBytes,
                chunkSize: UInt64(vertexChunk.count)
            )
        }

        let vertexCount = Int(record.vertexCount)
        var indices = [UInt32](repeating: 0, count: indexCount)
        indexChunk.withUnsafeBytes { raw in
            for position in 0 ..< indexCount {
                let index = if record.indexType == .uint16 {
                    UInt32(UInt16(littleEndian: raw.loadUnaligned(fromByteOffset: indexStart + position * 2, as: UInt16.self)))
                } else {
                    UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: indexStart + position * 4, as: UInt32.self))
                }
                // An index past the vertices would read outside the buffers below.
                indices[position] = index < UInt32(vertexCount) ? index : 0
            }
        }
        let base = vertexChunk.startIndex + vertexStart
        return UntoldLODMesh(vertexData: vertexChunk.subdata(in: base ..< base + vertexSize), indices: indices)
    }

    /// For each mesh record, the transform from its mesh space to the model's.
    private static func meshTransforms(_ decoded: UntoldDecodedAsset) throws -> [simd_float4x4] {
        let entities = Dictionary(decoded.entities.map { ($0.entityId, $0) }, uniquingKeysWith: { first, _ in first })
        var resolved: [UInt32: simd_float4x4] = [:]
        func worldTransform(of entity: UntoldEntityRecordV1, depth: Int) throws -> simd_float4x4 {
            if let transform = resolved[entity.entityId] {
                return transform
            }
            guard depth <= decoded.entities.count else {
                throw RuntimeAssetLoaderError.malformedAsset("Cycle in the entity hierarchy at entity \(entity.entityId)")
            }
            let transform: simd_float4x4 = if entity.parentEntityId != UntoldFormat.invalidIndex, let parent = entities[entity.parentEntityId] {
                try simd_mul(worldTransform(of: parent, depth: depth + 1), entity.localTransform)
            } else {
                simd_mul(decoded.header.rootTransform, entity.localTransform)
            }
            resolved[entity.entityId] = transform
            return transform
        }
        return try decoded.meshes.map { mesh in
            guard let entity = entities[mesh.entityId] else { return matrix_identity_float4x4 }
            return try worldTransform(of: entity, depth: 0)
        }
    }

    private static func largestAxisScale(_ transform: simd_float4x4) -> Float {
        max(
            simd_length(simd_make_float3(transform.columns.0)),
            simd_length(simd_make_float3(transform.columns.1)),
            simd_length(simd_make_float3(transform.columns.2))
        )
    }

    private static func modelDiameter(meshes: [UntoldLODMesh], transforms: [simd_float4x4]) -> Float {
        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        for (mesh, transform) in zip(meshes, transforms) where mesh.vertexCount > 0 {
            for corner in 0 ..< 8 {
                let point = SIMD4<Float>(
                    corner & 1 == 0 ? mesh.boundsMin.x : mesh.boundsMax.x,
                    corner & 2 == 0 ? mesh.boundsMin.y : mesh.boundsMax.y,
                    corner & 4 == 0 ? mesh.boundsMin.z : mesh.boundsMax.z,
                    1
                )
                let moved = simd_make_float3(simd_mul(transform, point))
                lower = simd_min(lower, moved)
                upper = simd_max(upper, moved)
            }
        }
        let diameter = simd_length(upper - lower)
        return diameter.isFinite ? diameter : 0
    }

    // MARK: - Vertices the simplifier must respect

    /// Whether the material of `mesh` reads a texture, and so its texture coordinates matter.
    private static func usesTextures(_ mesh: UntoldMeshRecordV1, in decoded: UntoldDecodedAsset) -> Bool {
        guard mesh.materialIndex != UntoldFormat.invalidIndex, Int(mesh.materialIndex) < decoded.materials.count else {
            return false
        }
        let material = decoded.materials[Int(mesh.materialIndex)]
        return [
            material.baseColorTextureIndex,
            material.normalTextureIndex,
            material.metallicTextureIndex,
            material.roughnessTextureIndex,
            material.emissiveTextureIndex,
            material.occlusionTextureIndex,
            material.heightTextureIndex,
        ].contains { $0 != UntoldFormat.invalidIndex }
    }

    /// Sets the simplifier flags of every mesh: a vertex whose position another mesh of
    /// the model also has is locked (the meshes are the materials of one surface and
    /// must keep meeting there), and a vertex on a texture seam of a textured mesh keeps
    /// its texture coordinates.
    static func applyVertexFlags(to meshes: inout [UntoldLODMesh], transforms: [simd_float4x4], textured: [Bool]) {
        let lock = UInt8(meshopt_SimplifyVertex_Lock)
        let protect = UInt8(meshopt_SimplifyVertex_Protect)

        // Model-space position → the mesh that has it, or -1 once a second mesh does.
        var owners: [SIMD3<UInt32>: Int32] = [:]
        if meshes.count > 1 {
            owners.reserveCapacity(meshes.reduce(0) { $0 + $1.vertexCount })
            for (meshIndex, mesh) in meshes.enumerated() {
                for vertex in 0 ..< mesh.vertexCount where Int(mesh.positionRemap[vertex]) == vertex {
                    let key = positionKey(mesh.position(vertex), transform: transforms[meshIndex])
                    if let owner = owners[key] {
                        if owner != Int32(meshIndex) {
                            owners[key] = -1
                        }
                    } else {
                        owners[key] = Int32(meshIndex)
                    }
                }
            }
        }

        for meshIndex in meshes.indices {
            let mesh = meshes[meshIndex]
            var flags = [UInt8](repeating: 0, count: mesh.vertexCount)
            var locks = [UInt8](repeating: 0, count: mesh.vertexCount)
            var hasFlags = false
            var hasLocks = false
            mesh.vertexData.withUnsafeBytes { raw in
                for vertex in 0 ..< mesh.vertexCount {
                    let first = Int(mesh.positionRemap[vertex])
                    if first != vertex {
                        guard textured[meshIndex] else { continue }
                        // uv0 is the two half floats at byte 20 of the record.
                        let texture = raw.loadUnaligned(fromByteOffset: vertex * UntoldLODMesh.vertexStride + 20, as: UInt32.self)
                        let firstTexture = raw.loadUnaligned(fromByteOffset: first * UntoldLODMesh.vertexStride + 20, as: UInt32.self)
                        if texture != firstTexture {
                            flags[vertex] |= protect
                            hasFlags = true
                        }
                    } else if !owners.isEmpty, owners[positionKey(mesh.position(vertex), transform: transforms[meshIndex])] == -1 {
                        flags[vertex] |= lock
                        locks[vertex] |= lock
                        hasFlags = true
                        hasLocks = true
                    }
                }
            }
            meshes[meshIndex].flags = hasFlags ? flags : []
            meshes[meshIndex].lockFlags = hasLocks ? locks : []
        }
    }

    private static func positionKey(_ position: SIMD3<Float>, transform: simd_float4x4) -> SIMD3<UInt32> {
        // Meshes split from one surface share its transform, so equal points stay bit
        // for bit equal through it. Adding zero folds -0 into +0.
        let moved = simd_make_float3(simd_mul(transform, SIMD4<Float>(position, 1))) + SIMD3<Float>(repeating: 0)
        return SIMD3<UInt32>(moved.x.bitPattern, moved.y.bitPattern, moved.z.bitPattern)
    }
}
