//
//  UntoldMeshLODSimplifier.swift
//  UntoldEngineMeshCook
//
//  Geometry side of the automatic LOD cook: reduces one mesh of a cooked model to a
//  share of its triangles with meshoptimizer's simplifier.
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

/// One mesh of a cooked model, unpacked for the simplifier.
struct UntoldLODMesh {
    /// `pbrStaticV1` records, `UntoldLODMesh.vertexStride` bytes per vertex.
    var vertexData: Data
    var vertexCount: Int
    var indices: [UInt32]
    /// x, y, z per vertex: what the simplifier reads and the thinning step moves.
    var positions: [Float]
    /// Unpacked normals, x, y, z per vertex: the simplifier's attribute metric.
    var normals: [Float]
    /// For each vertex, the first vertex at the same position: the points of the
    /// surface, whatever their normals and texture coordinates.
    var positionRemap: [UInt32]
    /// `meshopt_SimplifyVertex_*` flags per vertex, or empty when no vertex has any.
    var flags: [UInt8]
    /// `flags` without the texture seams: only the vertices that must stay in place.
    /// Empty when no vertex is locked.
    var lockFlags: [UInt8]
    var boundsMin: SIMD3<Float>
    var boundsMax: SIMD3<Float>

    static let vertexStride = 32

    var triangleCount: Int {
        indices.count / 3
    }

    var diagonal: Float {
        simd_length(boundsMax - boundsMin)
    }

    /// Unpacks `vertexData` (positions and 10:10:10:2 normals) and computes the bounds.
    init(vertexData: Data, indices: [UInt32]) {
        self.vertexData = vertexData
        self.indices = indices
        vertexCount = vertexData.count / Self.vertexStride
        flags = []
        lockFlags = []

        var positions = [Float](repeating: 0, count: vertexCount * 3)
        var normals = [Float](repeating: 0, count: vertexCount * 3)
        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        let count = vertexCount
        vertexData.withUnsafeBytes { raw in
            positions.withUnsafeMutableBufferPointer { positions in
                normals.withUnsafeMutableBufferPointer { normals in
                    for vertex in 0 ..< count {
                        let record = vertex * Self.vertexStride
                        let x = Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record, as: UInt32.self)))
                        let y = Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 4, as: UInt32.self)))
                        let z = Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self)))
                        positions[vertex * 3] = x
                        positions[vertex * 3 + 1] = y
                        positions[vertex * 3 + 2] = z
                        let point = SIMD3<Float>(x, y, z)
                        lower = simd_min(lower, point)
                        upper = simd_max(upper, point)

                        let packed = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 12, as: UInt32.self))
                        let normal = UntoldVertexPacking.unpackNormal(packed)
                        normals[vertex * 3] = normal.x
                        normals[vertex * 3 + 1] = normal.y
                        normals[vertex * 3 + 2] = normal.z
                    }
                }
            }
        }
        var remap = [UInt32](repeating: 0, count: vertexCount)
        positions.withUnsafeBufferPointer { positions in
            meshopt_generatePositionRemap(&remap, positions.baseAddress, count, MemoryLayout<Float>.stride * 3)
        }
        positionRemap = remap
        self.positions = positions
        self.normals = normals
        boundsMin = count > 0 ? lower : .zero
        boundsMax = count > 0 ? upper : .zero
    }

    func position(_ vertex: Int) -> SIMD3<Float> {
        SIMD3<Float>(positions[vertex * 3], positions[vertex * 3 + 1], positions[vertex * 3 + 2])
    }
}

/// One level of one mesh: a compact vertex buffer and its triangles.
struct UntoldLODMeshLevel {
    var vertexData: Data
    var vertexCount: Int
    var indices: [UInt32]
    var boundsMin: SIMD3<Float>
    var boundsMax: SIMD3<Float>
    /// The deviation from the source mesh the simplifier reports, in mesh units.
    var error: Float

    var triangleCount: Int {
        indices.count / 3
    }
}

/// How a mesh splits into a connected body and clutter.
///
/// Vegetation and similar aggregates are thousands of small disconnected pieces (leaf
/// cards, twigs). Edge collapse can simplify each piece but can only remove triangles
/// beyond that by shrinking pieces away, which thins a canopy out: at 3 % of the
/// triangles a tree keeps under a third of its leaf area. So the pieces of an
/// aggregate are handled apart from the connected surfaces: collapsed while they keep
/// their outline, then thinned evenly through space, and the survivors enlarged to
/// give back the area that was removed (stochastic pruning, as film and game foliage
/// pipelines do).
struct UntoldLODMeshParts {
    /// Component of each vertex; vertices at the same position share a component.
    var componentOfVertex: [Int32]
    var componentCount: Int
    var componentCenters: [SIMD3<Float>]
    /// Index triples of the connected surfaces.
    var bodyIndices: [UInt32]
    /// Index triples of the small pieces of an aggregate; empty for any other mesh.
    var clutterIndices: [UInt32]
    var clutterArea: Float
    /// Median bounding-box diagonal of the clutter pieces.
    var clutterPieceSize: Float

    /// A piece is clutter when its bounding box is under this share of the mesh's.
    static let clutterSizeShare: Float = 0.05
    /// A mesh is an aggregate from this many clutter pieces ...
    static let aggregateMinimumPieces = 64
    /// ... that hold at least this share of its area.
    static let aggregateMinimumAreaShare: Float = 0.25

    init(mesh: UntoldLODMesh) {
        let vertexCount = mesh.vertexCount
        let triangleCount = mesh.triangleCount

        var parent = [Int32](repeating: 0, count: vertexCount)
        var componentOfVertex = [Int32](repeating: -1, count: vertexCount)
        var componentCount = 0
        parent.withUnsafeMutableBufferPointer { parent in
            for vertex in 0 ..< vertexCount {
                parent[vertex] = Int32(vertex)
            }
            func find(_ start: Int) -> Int {
                var node = start
                while Int(parent[node]) != node {
                    parent[node] = parent[Int(parent[node])]
                    node = Int(parent[node])
                }
                return node
            }
            mesh.positionRemap.withUnsafeBufferPointer { remap in
                mesh.indices.withUnsafeBufferPointer { indices in
                    for triangle in 0 ..< triangleCount {
                        let a = find(Int(remap[Int(indices[triangle * 3])]))
                        let b = find(Int(remap[Int(indices[triangle * 3 + 1])]))
                        let c = find(Int(remap[Int(indices[triangle * 3 + 2])]))
                        if a != b {
                            parent[b] = Int32(a)
                        }
                        let root = find(a)
                        if c != root {
                            parent[find(c)] = Int32(root)
                        }
                    }
                }
                componentOfVertex.withUnsafeMutableBufferPointer { componentOfVertex in
                    // A component takes its id from its root, the first time any of its
                    // vertices is met.
                    for vertex in 0 ..< vertexCount {
                        let root = find(Int(remap[vertex]))
                        if componentOfVertex[root] < 0 {
                            componentOfVertex[root] = Int32(componentCount)
                            componentCount += 1
                        }
                        componentOfVertex[vertex] = componentOfVertex[root]
                    }
                }
            }
        }

        var triangles = [Int](repeating: 0, count: componentCount)
        var areas = [Float](repeating: 0, count: componentCount)
        var lower = [SIMD3<Float>](repeating: SIMD3(repeating: .greatestFiniteMagnitude), count: componentCount)
        var upper = [SIMD3<Float>](repeating: SIMD3(repeating: -.greatestFiniteMagnitude), count: componentCount)
        for triangle in 0 ..< triangleCount {
            let a = Int(mesh.indices[triangle * 3])
            let pa = mesh.position(a)
            let pb = mesh.position(Int(mesh.indices[triangle * 3 + 1]))
            let pc = mesh.position(Int(mesh.indices[triangle * 3 + 2]))
            let component = Int(componentOfVertex[a])
            triangles[component] += 1
            areas[component] += 0.5 * simd_length(simd_cross(pb - pa, pc - pa))
            lower[component] = simd_min(lower[component], simd_min(pa, simd_min(pb, pc)))
            upper[component] = simd_max(upper[component], simd_max(pa, simd_max(pb, pc)))
        }

        let clutterLimit = mesh.diagonal * Self.clutterSizeShare
        var isClutter = [Bool](repeating: false, count: componentCount)
        var clutterSizes: [Float] = []
        var clutterArea: Float = 0
        var totalArea: Float = 0
        for component in 0 ..< componentCount where triangles[component] > 0 {
            totalArea += areas[component]
            let size = simd_length(upper[component] - lower[component])
            if size < clutterLimit {
                isClutter[component] = true
                clutterSizes.append(size)
                clutterArea += areas[component]
            }
        }
        let isAggregate = clutterSizes.count >= Self.aggregateMinimumPieces
            && clutterArea >= totalArea * Self.aggregateMinimumAreaShare

        self.componentOfVertex = componentOfVertex
        self.componentCount = componentCount
        componentCenters = zip(lower, upper).map { ($0 + $1) * 0.5 }
        if isAggregate {
            var body: [UInt32] = []
            var clutter: [UInt32] = []
            clutter.reserveCapacity(mesh.indices.count)
            for triangle in 0 ..< triangleCount {
                let range = triangle * 3 ..< triangle * 3 + 3
                if isClutter[Int(componentOfVertex[Int(mesh.indices[triangle * 3])])] {
                    clutter.append(contentsOf: mesh.indices[range])
                } else {
                    body.append(contentsOf: mesh.indices[range])
                }
            }
            bodyIndices = body
            clutterIndices = clutter
            self.clutterArea = clutterArea
            clutterSizes.sort()
            clutterPieceSize = clutterSizes[clutterSizes.count / 2]
        } else {
            bodyIndices = mesh.indices
            clutterIndices = []
            self.clutterArea = 0
            clutterPieceSize = 0
        }
    }
}

enum UntoldMeshLODSimplifier {
    /// Weight of each normal component against position in the simplifier's error.
    static let normalWeight: Float = 0.5
    /// The texture seams are released when they hold a mesh this far above its target.
    static let seamReleaseOvershoot: Float = 1.25
    /// Share of a clutter piece's size it may deviate by while it is collapsed.
    static let clutterErrorShare: Float = 0.25
    /// Survivors of the thinning are never enlarged beyond this factor, and the thinning
    /// stops where a larger one would be needed to keep the area.
    static let clutterMaximumScale: Float = 4

    /// Reduces `mesh` towards `ratio` of its triangles, deviating from it by at most
    /// `errorLimit` (mesh units). The result can hold more triangles than asked for:
    /// the simplifier stops at the error limit and at what the topology allows.
    /// `sunkPieces` flags the components of `parts` that the cook sank behind another
    /// surface: they are simplified apart from the rest.
    static func level(of mesh: UntoldLODMesh, parts: UntoldLODMeshParts, ratio: Float, errorLimit: Float, sunkPieces: [Bool] = []) -> UntoldLODMeshLevel {
        var positions = mesh.positions
        var movedVertices: [Int] = []
        var error: Float = 0

        var indices = simplifyBody(mesh: mesh, parts: parts, ratio: ratio, errorLimit: errorLimit, sunkPieces: sunkPieces, error: &error)
        if !parts.clutterIndices.isEmpty {
            indices += simplifyClutter(
                mesh: mesh,
                parts: parts,
                ratio: ratio,
                errorLimit: errorLimit,
                positions: &positions,
                movedVertices: &movedVertices,
                error: &error
            )
        }
        return compact(mesh: mesh, indices: indices, positions: positions, movedVertices: movedVertices, error: error)
    }

    // MARK: - Connected surfaces

    private static func simplifyBody(
        mesh: UntoldLODMesh,
        parts: UntoldLODMeshParts,
        ratio: Float,
        errorLimit: Float,
        sunkPieces: [Bool],
        error: inout Float
    ) -> [UInt32] {
        let source = parts.bodyIndices
        guard !source.isEmpty else { return [] }
        // A piece the cook sank is bent by its sinking and gives up its triangles less
        // readily than the surfaces beside it; simplified with them towards one target it
        // would keep its own and take theirs. It is simplified on its own share.
        if sunkPieces.contains(true) {
            var sunk: [UInt32] = []
            var kept: [UInt32] = []
            for triangle in stride(from: 0, to: source.count, by: 3) {
                let component = Int(parts.componentOfVertex[Int(source[triangle])])
                if component >= 0, component < sunkPieces.count, sunkPieces[component] {
                    sunk += source[triangle ..< triangle + 3]
                } else {
                    kept += source[triangle ..< triangle + 3]
                }
            }
            if !sunk.isEmpty, !kept.isEmpty {
                return simplifyBody(indices: sunk, mesh: mesh, parts: parts, ratio: ratio, errorLimit: errorLimit, error: &error)
                    + simplifyBody(indices: kept, mesh: mesh, parts: parts, ratio: ratio, errorLimit: errorLimit, error: &error)
            }
        }
        return simplifyBody(indices: source, mesh: mesh, parts: parts, ratio: ratio, errorLimit: errorLimit, error: &error)
    }

    /// Reduces the triangles `source` of `mesh` towards `ratio` of them.
    private static func simplifyBody(
        indices source: [UInt32],
        mesh: UntoldLODMesh,
        parts: UntoldLODMeshParts,
        ratio: Float,
        errorLimit: Float,
        error: inout Float
    ) -> [UInt32] {
        let target = targetIndexCount(source.count, ratio: ratio)
        guard target < source.count else { return source }

        // Small detached parts go first (prune): at the size this level is drawn they
        // are under the error limit, which is what it is chosen for.
        var options = UInt32(meshopt_SimplifyPermissive | meshopt_SimplifyPrune)
            | UInt32(meshopt_SimplifyErrorAbsolute | meshopt_SimplifyErrorClamped)
        if !parts.clutterIndices.isEmpty {
            options |= UInt32(meshopt_SimplifySparse)
        }

        /// The texture seams are kept unless they hold the mesh above the target (a model
        /// unwrapped into many small islands). A level is drawn where its triangles are
        /// a few pixels, and so is what a collapse across a seam does to the texture:
        /// rather than keep triangles nobody can tell apart, the seams are let go.
        func collapse(_ options: UInt32) -> (indices: [UInt32], error: Float) {
            var keptError: Float = 0
            let kept = simplify(mesh: mesh, indices: source, flags: mesh.flags, target: target, errorLimit: errorLimit, options: options, error: &keptError)
            guard Float(kept.count) > Float(target) * seamReleaseOvershoot, mesh.flags != mesh.lockFlags else {
                return (kept, keptError)
            }
            var releasedError: Float = 0
            let released = simplify(mesh: mesh, indices: source, flags: mesh.lockFlags, target: target, errorLimit: errorLimit, options: options, error: &releasedError)
            return !released.isEmpty && released.count < kept.count ? (released, releasedError) : (kept, keptError)
        }

        var result = collapse(options)
        if result.indices.isEmpty {
            // Everything was small enough to prune. A mesh with no triangles cannot be
            // drawn, so keep its shape and let the collapse alone reduce it.
            result = collapse(options & ~UInt32(meshopt_SimplifyPrune))
        }
        if result.indices.isEmpty {
            return source
        }
        error = max(error, result.error)
        return result.indices
    }

    // MARK: - Aggregates

    private static func simplifyClutter(
        mesh: UntoldLODMesh,
        parts: UntoldLODMeshParts,
        ratio: Float,
        errorLimit: Float,
        positions: inout [Float],
        movedVertices: inout [Int],
        error: inout Float
    ) -> [UInt32] {
        let source = parts.clutterIndices
        let target = targetIndexCount(source.count, ratio: ratio)
        guard target < source.count else { return source }

        // 1. Collapse inside the pieces while they keep their outline.
        let pieceLimit = min(errorLimit, parts.clutterPieceSize * clutterErrorShare)
        let options = UInt32(meshopt_SimplifyPermissive | meshopt_SimplifySparse)
            | UInt32(meshopt_SimplifyErrorAbsolute | meshopt_SimplifyErrorClamped)
        var collapseError: Float = 0
        var collapsed = simplify(mesh: mesh, indices: source, flags: mesh.flags, target: target, errorLimit: pieceLimit, options: options, error: &collapseError)
        if collapsed.isEmpty {
            collapsed = source
        } else {
            error = max(error, collapseError)
        }

        // 2. Thin the pieces out evenly: along a space-filling curve through their
        // centres, every piece adds its share of the triangle budget and is kept when
        // the running total passes a whole one.
        var pieceTriangles = [Int32](repeating: 0, count: parts.componentCount)
        var collapsedArea: Float = 0
        for triangle in 0 ..< collapsed.count / 3 {
            let a = Int(collapsed[triangle * 3])
            pieceTriangles[Int(parts.componentOfVertex[a])] += 1
            let b = Int(collapsed[triangle * 3 + 1])
            let c = Int(collapsed[triangle * 3 + 2])
            collapsedArea += 0.5 * simd_length(simd_cross(mesh.position(b) - mesh.position(a), mesh.position(c) - mesh.position(a)))
        }
        var keep = [Bool](repeating: true, count: parts.componentCount)
        if collapsed.count > target {
            let pieces = (0 ..< parts.componentCount).filter { pieceTriangles[$0] > 0 }
            let ordered = mortonOrder(pieces, centers: parts.componentCenters, lower: mesh.boundsMin, upper: mesh.boundsMax)
            // Never thinner than the enlargement of step 3 can make up for: below that
            // share the aggregate would show through, whatever the ratio asked for.
            let fullestShare = collapsedArea > 0
                ? Double(parts.clutterArea / (collapsedArea * clutterMaximumScale * clutterMaximumScale))
                : 1
            let share = min(max(Double(target) / Double(collapsed.count), fullestShare), 1)
            var credit = 0.5
            for piece in ordered {
                credit += share
                if credit >= 1 {
                    credit -= 1
                } else {
                    keep[piece] = false
                }
            }
        }
        var kept: [UInt32] = []
        kept.reserveCapacity(min(collapsed.count, target + 3))
        var keptArea: Float = 0
        for triangle in 0 ..< collapsed.count / 3 {
            let a = Int(collapsed[triangle * 3])
            guard keep[Int(parts.componentOfVertex[a])] else { continue }
            let b = Int(collapsed[triangle * 3 + 1])
            let c = Int(collapsed[triangle * 3 + 2])
            kept.append(contentsOf: [UInt32(a), UInt32(b), UInt32(c)])
            keptArea += 0.5 * simd_length(simd_cross(mesh.position(b) - mesh.position(a), mesh.position(c) - mesh.position(a)))
        }
        guard !kept.isEmpty, keptArea > 0 else {
            return collapsed
        }

        // 3. Enlarge the survivors, each about its own centre, to the area the clutter
        // had: the aggregate keeps its density and its silhouette. Positions stay
        // inside the mesh's bounds, so every level fits the bounds of the first.
        let scale = min(max((parts.clutterArea / keptArea).squareRoot(), 1), clutterMaximumScale)
        if scale > 1.001 {
            var isMoved = [Bool](repeating: false, count: mesh.vertexCount)
            for index in kept {
                let vertex = Int(index)
                guard !isMoved[vertex] else { continue }
                isMoved[vertex] = true
                movedVertices.append(vertex)
                let center = parts.componentCenters[Int(parts.componentOfVertex[vertex])]
                let moved = simd_clamp(center + (mesh.position(vertex) - center) * scale, mesh.boundsMin, mesh.boundsMax)
                positions[vertex * 3] = moved.x
                positions[vertex * 3 + 1] = moved.y
                positions[vertex * 3 + 2] = moved.z
            }
        }
        return kept
    }

    /// `pieces` in the order of the Morton codes of their centres within the bounds.
    private static func mortonOrder(_ pieces: [Int], centers: [SIMD3<Float>], lower: SIMD3<Float>, upper: SIMD3<Float>) -> [Int] {
        let extent = simd_max(upper - lower, SIMD3<Float>(repeating: 1e-9))
        func spread(_ value: UInt32) -> UInt64 {
            var bits = UInt64(value & 0x1FFFFF)
            bits = (bits | (bits << 32)) & 0x1F_0000_0000_FFFF
            bits = (bits | (bits << 16)) & 0x1F_0000_FF00_00FF
            bits = (bits | (bits << 8)) & 0x100F_00F0_0F00_F00F
            bits = (bits | (bits << 4)) & 0x10C3_0C30_C30C_30C3
            bits = (bits | (bits << 2)) & 0x1249_2492_4924_9249
            return bits
        }
        let codes: [UInt64] = pieces.map { piece in
            let unit = simd_clamp((centers[piece] - lower) / extent, .zero, SIMD3<Float>(repeating: 1))
            let cell = unit * 2_097_151
            return spread(UInt32(cell.x)) | (spread(UInt32(cell.y)) << 1) | (spread(UInt32(cell.z)) << 2)
        }
        return pieces.indices.sorted { codes[$0] != codes[$1] ? codes[$0] < codes[$1] : pieces[$0] < pieces[$1] }.map { pieces[$0] }
    }

    // MARK: - meshoptimizer

    private static func targetIndexCount(_ indexCount: Int, ratio: Float) -> Int {
        max(Int(Float(indexCount / 3) * ratio), 1) * 3
    }

    private static func simplify(
        mesh: UntoldLODMesh,
        indices: [UInt32],
        flags: [UInt8],
        target: Int,
        errorLimit: Float,
        options: UInt32,
        error: inout Float
    ) -> [UInt32] {
        var destination = [UInt32](repeating: 0, count: indices.count)
        var resultError: Float = 0
        let weights = [Float](repeating: normalWeight, count: 3)
        let floatStride = MemoryLayout<Float>.stride * 3
        let count = mesh.positions.withUnsafeBufferPointer { positions in
            mesh.normals.withUnsafeBufferPointer { normals in
                flags.withUnsafeBufferPointer { flags in
                    meshopt_simplifyWithAttributes(
                        &destination,
                        indices,
                        indices.count,
                        positions.baseAddress,
                        mesh.vertexCount,
                        floatStride,
                        normals.baseAddress,
                        floatStride,
                        weights,
                        weights.count,
                        flags.isEmpty ? nil : flags.baseAddress,
                        target,
                        errorLimit,
                        options,
                        &resultError
                    )
                }
            }
        }
        destination.removeLast(destination.count - count)
        error = resultError
        return destination
    }

    /// The cosine of the angle from which a kept vertex's normal is taken to belong to the
    /// surface it was simplified away from, not to the one it now sits on: 30 degrees.
    static let settledNormalCosine: Float = 0.866

    /// Gives every vertex of a level whose normal is far from the faces around it the
    /// normal of those faces. The simplifier keeps the vertices it does not collapse with
    /// their normals as they were: a vertex that stood in a groove, on a crease or at the
    /// foot of a ridge keeps a sideways normal when the groove is gone and it sits on a
    /// span of flat triangles, and that shades the span dark. The faces are averaged per
    /// vertex, not per position, so a hard edge (two vertices at one position, a normal
    /// for each side) keeps both its normals; and the average is turned to the side of
    /// the vertex's own normal, since a mesh wound the other way round (a mirrored part)
    /// has its faces' cross products pointing in. The tangent follows the normal it is
    /// paired with. Returns how many normals were replaced.
    @discardableResult
    static func settleNormals(of vertices: inout Data, vertexCount: Int, indices: [UInt32]) -> Int {
        guard vertexCount > 0, !indices.isEmpty else { return 0 }
        var faceSum = [SIMD3<Float>](repeating: .zero, count: vertexCount)
        var replaced = 0
        vertices.withUnsafeMutableBytes { raw in
            func position(_ vertex: Int) -> SIMD3<Float> {
                let record = vertex * UntoldLODMesh.vertexStride
                return SIMD3<Float>(
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record, as: UInt32.self))),
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 4, as: UInt32.self))),
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self)))
                )
            }
            for triangle in stride(from: 0, to: indices.count, by: 3) {
                let a = Int(indices[triangle]), b = Int(indices[triangle + 1]), c = Int(indices[triangle + 2])
                guard a < vertexCount, b < vertexCount, c < vertexCount else { continue }
                let pa = position(a)
                // Twice the area, along the face's normal: the larger faces weigh more.
                let weighted = simd_cross(position(b) - pa, position(c) - pa)
                faceSum[a] += weighted
                faceSum[b] += weighted
                faceSum[c] += weighted
            }
            for vertex in 0 ..< vertexCount {
                let length = simd_length(faceSum[vertex])
                guard length > 0 else { continue }
                var faces = faceSum[vertex] / length
                let record = vertex * UntoldLODMesh.vertexStride
                let packedNormal = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 12, as: UInt32.self))
                let normal = UntoldVertexPacking.unpackNormal(packedNormal)
                if simd_dot(normal, faces) < 0 {
                    faces = -faces
                }
                guard simd_dot(normal, faces) < settledNormalCosine else { continue }
                raw.storeBytes(of: UntoldVertexPacking.packNormal(faces).littleEndian, toByteOffset: record + 12, as: UInt32.self)
                // The tangent stays in the surface: its part along the new normal goes.
                let packedTangent = UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 16, as: UInt32.self))
                let tangent = UntoldVertexPacking.unpackTangent(packedTangent)
                let inPlane = tangent.vector - faces * simd_dot(tangent.vector, faces)
                let inPlaneLength = simd_length(inPlane)
                if inPlaneLength > 1e-4 {
                    raw.storeBytes(
                        of: UntoldVertexPacking.packTangent(inPlane / inPlaneLength, handedness: tangent.handedness).littleEndian,
                        toByteOffset: record + 16,
                        as: UInt32.self
                    )
                }
                replaced += 1
            }
        }
        return replaced
    }

    /// Orders the triangles for the GPU's vertex cache and keeps only the vertices they use.
    private static func compact(
        mesh: UntoldLODMesh,
        indices: [UInt32],
        positions: [Float],
        movedVertices: [Int],
        error: Float
    ) -> UntoldLODMeshLevel {
        var source = mesh.vertexData
        if !movedVertices.isEmpty {
            source.withUnsafeMutableBytes { raw in
                for vertex in movedVertices {
                    for axis in 0 ..< 3 {
                        raw.storeBytes(
                            of: positions[vertex * 3 + axis].bitPattern.littleEndian,
                            toByteOffset: vertex * UntoldLODMesh.vertexStride + axis * 4,
                            as: UInt32.self
                        )
                    }
                }
            }
        }

        var ordered = [UInt32](repeating: 0, count: indices.count)
        meshopt_optimizeVertexCache(&ordered, indices, indices.count, mesh.vertexCount)

        // optimizeVertexFetch writes at most one record per source vertex.
        var vertices = Data(count: mesh.vertexCount * UntoldLODMesh.vertexStride)
        let vertexCount = vertices.withUnsafeMutableBytes { destination in
            source.withUnsafeBytes { source in
                meshopt_optimizeVertexFetch(
                    destination.baseAddress,
                    &ordered,
                    ordered.count,
                    source.baseAddress,
                    mesh.vertexCount,
                    UntoldLODMesh.vertexStride
                )
            }
        }
        vertices.removeSubrange(vertexCount * UntoldLODMesh.vertexStride ..< vertices.count)
        settleNormals(of: &vertices, vertexCount: vertexCount, indices: ordered)

        var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        vertices.withUnsafeBytes { raw in
            for vertex in 0 ..< vertexCount {
                let record = vertex * UntoldLODMesh.vertexStride
                let point = SIMD3<Float>(
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record, as: UInt32.self))),
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 4, as: UInt32.self))),
                    Float(bitPattern: UInt32(littleEndian: raw.loadUnaligned(fromByteOffset: record + 8, as: UInt32.self)))
                )
                lower = simd_min(lower, point)
                upper = simd_max(upper, point)
            }
        }
        return UntoldLODMeshLevel(
            vertexData: vertices,
            vertexCount: vertexCount,
            indices: ordered,
            boundsMin: vertexCount > 0 ? lower : mesh.boundsMin,
            boundsMax: vertexCount > 0 ? upper : mesh.boundsMax,
            error: error
        )
    }
}
