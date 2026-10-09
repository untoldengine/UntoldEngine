//
//  UntoldMeshLODHiddenParts.swift
//  UntoldEngineMeshCook
//
//  The parts of a model that lie hidden a short way behind another, like a car's
//  headliner under its roof, and how they are sunk before a level is simplified so
//  that they stay hidden.
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

/// Finds the vertices of a model that lie hidden a short way behind the surfaces of its
/// other meshes, and sinks them behind those surfaces before a level is simplified.
///
/// Every mesh of a model is simplified on its own, within the allowance of the level
/// (one triangle's size). A car's headliner runs a millimetre under its roof, its door
/// panels a centimetre or two behind its doors: once the allowance exceeds the gap, the
/// coarse triangles of the roof cut below the headliner's and the dark part shows
/// through the paint. A vertex is hidden when its own side is covered (the rays along
/// its normal and in a cone round it all meet another face of the model) and it lies
/// behind a face of another, solid mesh that is seen, within reach of the level's
/// allowance: the face's nearest point in front of the vertex, the way the face points,
/// not beside it. Such a vertex is moved away from that face, along the face's normal,
/// so that it ends twice the allowance behind it: the face may then come in by the
/// allowance and the hidden part go out by it without the two crossing. The move stops
/// two allowances short of any seen face in its way, so that a piece between two seen
/// surfaces that face away from each other (a car's inner wing, between the paint and
/// the wheel-well liner) stays between them. A vertex that is seen is never moved, so
/// what a level draws from outside is the plain simplification of the model; and the
/// sinks are averaged over each piece (a connected component of the mesh) before they
/// are applied, so that a piece that is hidden in one part and seen in another (a
/// car's inner skin, whose wheel wells show through the arches) bends gradually from
/// the one to the other instead of tearing where they meet. Glass covers what is behind
/// it for the purpose of hiding, but nothing is sunk away from glass: what is behind a
/// headlight's lens or a windscreen is seen through it, and stays where it is. A part
/// in front of another (a ball on a floor) is seen on its own side and stays. A vertex
/// two meshes share is sunk only when it is hidden in both, and the same way in both, so
/// that their border stays closed. Aggregates (a canopy of loose cards) neither hide
/// nor are hidden: their pieces are thinned, not bent.
final class UntoldMeshLODHiddenParts {
    /// How far behind a seen face a hidden vertex that touches it is put, as a multiple
    /// of the allowance: the face may come in by one and the hidden part go out by one.
    static let depthShare: Float = 2
    /// How far from a seen face a hidden vertex is still moved, as a multiple of the
    /// allowance. From touching to this distance the move tapers off, so that a hidden
    /// part keeps a share of its thickness and joins its vertices beyond reach without
    /// a step.
    static let reachShare: Float = 3
    /// The most faces, each facing its own way, a vertex is sunk from: a part in a corner
    /// moves away from every face of the corner.
    static let directionsPerVertex = 3
    /// How many times the sinks of a piece are averaged with their neighbours' before
    /// they are applied. Each vertex is sunk from the faces it happens to be nearest,
    /// and neighbours can differ in which; left as they are the sinks bend a piece into
    /// creases that a level then spends its triangles on. Averaged, the piece moves as
    /// one surface.
    static let smoothingPasses = 8
    /// Two faces face their own ways when the cosine between their normals is under this.
    static let distinctDirectionCosine: Float = 0.5
    /// A vertex nearer a face than this share of the model's diameter touches it, and is
    /// on neither side of it (a ball on a floor).
    static let touchingShare: Float = 1e-5
    /// The share of a piece's vertices that must be sunk for the piece to be simplified
    /// on its own share of its mesh's target: bent by its sinking, it would otherwise
    /// keep its triangles and take those of the pieces beside it.
    static let sunkPieceShare: Float = 0.5
    /// A vertex is behind a face when the face's nearest point lies in front of it within
    /// 45 degrees of the way the face points: the cosine of that angle. A vertex beside
    /// a face, past its edge, is not behind it, nor is one under a face farther round a
    /// curved shell than the one that covers it.
    static let behindCosine: Float = 0.7

    /// A seen face a hidden vertex is sunk from.
    struct Reference: Equatable {
        /// The way the face points, in model space.
        var normal: SIMD3<Float>
        /// The vertex's distance to the face in the model.
        var distance: Float
    }

    /// A hidden distinct vertex of a mesh with the faces it is sunk from, nearest first.
    struct HiddenVertex {
        var vertex: Int
        var references: [Reference]
    }

    /// For each mesh, its hidden vertices (one per position); empty for a mesh that has none.
    let hiddenVertices: [[HiddenVertex]]
    /// For each mesh, which of its pieces (the components of its parts) are sunk for the
    /// most part.
    let hiddenPieces: [[Bool]]
    /// For each mesh with a hidden vertex, the distinct vertices of the pieces that have
    /// one, which seen vertices among them must not move, and for each distinct vertex
    /// the distinct vertices it shares a triangle with.
    private let pieceVertices: [[Int]]
    private let seenVertices: [[Bool]]
    private let neighbours: [[[Int32]]]
    private let transforms: [simd_float4x4]
    private let inverseTransforms: [simd_float4x4]
    /// The model's faces, and which of them a sunk vertex must not pass; nil when
    /// nothing is hidden.
    let grid: ModelGrid?
    let referenceTriangles: [Bool]
    let touching: Float

    /// How many positions of the model are hidden behind another mesh within reach of
    /// the coarsest allowance.
    var count: Int {
        hiddenVertices.reduce(0) { $0 + $1.count }
    }

    var isEmpty: Bool {
        hiddenVertices.allSatisfy(\.isEmpty)
    }

    /// Finds the hidden vertices of the model within `reachShare` times
    /// `coarsestAllowance` (model units) of a seen face of another mesh. `glass` flags
    /// the meshes whose material lets through what is behind it.
    init(meshes: [UntoldLODMesh], parts: [UntoldLODMeshParts], transforms: [simd_float4x4], glass: [Bool], diameter: Float, coarsestAllowance: Float) {
        self.transforms = transforms
        inverseTransforms = transforms.map(\.inverse)
        let reach = Self.reachShare * coarsestAllowance
        let eligible = meshes.indices.filter { index in
            meshes[index].vertexCount > 0 && meshes[index].triangleCount > 0 && parts[index].clutterIndices.isEmpty
        }
        guard eligible.count > 1, reach > 0, reach.isFinite, diameter > 0 else {
            hiddenVertices = meshes.map { _ in [] }
            hiddenPieces = parts.map { [Bool](repeating: false, count: $0.componentCount) }
            pieceVertices = meshes.map { _ in [] }
            seenVertices = meshes.map { _ in [] }
            neighbours = meshes.map { _ in [] }
            grid = nil
            referenceTriangles = []
            touching = 0
            return
        }
        let grid = ModelGrid(meshes: meshes, transforms: transforms, included: eligible, cellSize: max(reach / 2, diameter / 96))
        let touching = Self.touchingShare * diameter
        self.touching = touching

        // Only the vertices with a solid mesh within reach are measured: the rays and
        // the searches are the cost of the cook.
        var solidMeshes = [Bool](repeating: false, count: meshes.count)
        for meshIndex in eligible where !glass[meshIndex] {
            solidMeshes[meshIndex] = true
        }
        guard solidMeshes.contains(true) else {
            hiddenVertices = meshes.map { _ in [] }
            hiddenPieces = parts.map { [Bool](repeating: false, count: $0.componentCount) }
            pieceVertices = meshes.map { _ in [] }
            seenVertices = meshes.map { _ in [] }
            neighbours = meshes.map { _ in [] }
            self.grid = nil
            self.referenceTriangles = []
            return
        }
        let near = grid.verticesNear(meshes: solidMeshes, within: reach)
        let seen = grid.seen(near, offset: touching)
        // The faces a hidden vertex may be sunk from: those of a solid mesh with a seen
        // corner.
        let referenceTriangles = grid.triangleFlags { mesh, corners in
            solidMeshes[mesh] && (seen[corners.x] == true || seen[corners.y] == true || seen[corners.z] == true)
        }
        self.grid = grid
        self.referenceTriangles = referenceTriangles
        let shared = Self.sharedVertices(meshes: meshes, grid: grid)

        var hidden = [[HiddenVertex]](repeating: [], count: meshes.count)
        for meshIndex in eligible {
            let mesh = meshes[meshIndex]
            // A vertex other meshes have too is sunk only when it is hidden in each of
            // them, so that it moves the same way in all and their border stays closed.
            let covered = (0 ..< mesh.vertexCount).filter { vertex in
                guard Int(mesh.positionRemap[vertex]) == vertex else { return false }
                guard let global = grid.globalVertex(mesh: meshIndex, vertex: vertex), near[global], seen[global] == false else { return false }
                guard let copies = shared[Self.key(grid.position(global))] else { return true }
                return copies.allSatisfy { seen[$0] == false }
            }
            guard !covered.isEmpty else { continue }
            var references = [[Reference]](repeating: [], count: covered.count)
            references.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let buffer = buffer
                DispatchQueue.concurrentPerform(iterations: covered.count) { index in
                    guard let global = grid.globalVertex(mesh: meshIndex, vertex: covered[index]) else { return }
                    buffer[index] = grid.references(
                        near: grid.position(global), within: reach, touching: touching, behindCosine: Self.behindCosine,
                        ofTriangles: referenceTriangles, limit: Self.directionsPerVertex, distinctCosine: Self.distinctDirectionCosine
                    )
                }
            }
            hidden[meshIndex] = zip(covered, references).compactMap { vertex, found in
                found.isEmpty ? nil : HiddenVertex(vertex: vertex, references: found)
            }
        }
        hiddenVertices = hidden

        // The pieces with a hidden vertex: their vertices and neighbours for the
        // smoothing, which of those are seen, and whether the piece is sunk for the most
        // part.
        var hiddenPieces: [[Bool]] = parts.map { [Bool](repeating: false, count: $0.componentCount) }
        var pieceVertices = [[Int]](repeating: [], count: meshes.count)
        var seenVertices = [[Bool]](repeating: [], count: meshes.count)
        var neighbours = [[[Int32]]](repeating: [], count: meshes.count)
        for meshIndex in eligible where !hidden[meshIndex].isEmpty {
            let mesh = meshes[meshIndex]
            let part = parts[meshIndex]
            var sunkOfPiece = [Int](repeating: 0, count: part.componentCount)
            for hiddenVertex in hidden[meshIndex] {
                let component = Int(part.componentOfVertex[hiddenVertex.vertex])
                if component >= 0, component < sunkOfPiece.count {
                    sunkOfPiece[component] += 1
                }
            }
            var sizeOfPiece = [Int](repeating: 0, count: part.componentCount)
            for vertex in 0 ..< mesh.vertexCount where Int(mesh.positionRemap[vertex]) == vertex {
                let component = Int(part.componentOfVertex[vertex])
                if component >= 0, component < sizeOfPiece.count {
                    sizeOfPiece[component] += 1
                }
            }
            func pieceHasHidden(_ vertex: Int) -> Bool {
                let component = Int(part.componentOfVertex[vertex])
                return component >= 0 && component < sunkOfPiece.count && sunkOfPiece[component] > 0
            }
            for component in sunkOfPiece.indices where sizeOfPiece[component] > 0 {
                hiddenPieces[meshIndex][component] = Float(sunkOfPiece[component]) >= Float(sizeOfPiece[component]) * Self.sunkPieceShare
            }
            pieceVertices[meshIndex] = (0 ..< mesh.vertexCount).filter { Int(mesh.positionRemap[$0]) == $0 && pieceHasHidden($0) }
            var isSeen = [Bool](repeating: false, count: mesh.vertexCount)
            for vertex in pieceVertices[meshIndex] {
                if let global = grid.globalVertex(mesh: meshIndex, vertex: vertex), seen[global] != false {
                    isSeen[vertex] = true
                }
            }
            seenVertices[meshIndex] = isSeen
            var edges = Set<UInt64>()
            for triangle in stride(from: 0, to: mesh.indices.count, by: 3) {
                let corners = (0 ..< 3).map { Int(mesh.positionRemap[Int(mesh.indices[triangle + $0])]) }
                guard pieceHasHidden(corners[0]) else { continue }
                for (a, b) in [(corners[0], corners[1]), (corners[1], corners[2]), (corners[2], corners[0])] where a != b {
                    edges.insert(UInt64(min(a, b)) << 32 | UInt64(max(a, b)))
                }
            }
            var lists = [[Int32]](repeating: [], count: mesh.vertexCount)
            for edge in edges {
                let a = Int(edge >> 32), b = Int(edge & 0xFFFF_FFFF)
                lists[a].append(Int32(b))
                lists[b].append(Int32(a))
            }
            neighbours[meshIndex] = lists
        }
        self.hiddenPieces = hiddenPieces
        self.seenVertices = seenVertices
        self.pieceVertices = pieceVertices
        self.neighbours = neighbours
    }

    /// The meshes with their hidden vertices sunk for a level whose allowance is
    /// `allowance` (model units): a hidden vertex within `reachShare` allowances of a
    /// seen face moves away from it along the face's normal, by `depthShare` allowances
    /// when it touches the face and by less up to the edge of reach; the sinks are
    /// averaged over each piece (`smoothingPasses`), and none goes farther than
    /// `depthShare` allowances short of the first seen face in its way. A mesh with no
    /// hidden vertex within reach is returned as it is.
    func sunk(_ meshes: [UntoldLODMesh], allowance: Float) -> [UntoldLODMesh] {
        guard allowance > 0, allowance.isFinite, let grid else { return meshes }
        let reach = Self.reachShare * allowance
        let depth = Self.depthShare * allowance
        let lock = UInt8(meshopt_SimplifyVertex_Lock)
        var result = meshes
        for meshIndex in meshes.indices where !hiddenVertices[meshIndex].isEmpty {
            let mesh = meshes[meshIndex]
            let transform = transforms[meshIndex]
            let inverse = inverseTransforms[meshIndex]
            // The sink of each hidden vertex, in model space.
            var sinks = [SIMD3<Float>](repeating: .zero, count: mesh.vertexCount)
            for hidden in hiddenVertices[meshIndex] {
                for reference in hidden.references where reference.distance < reach {
                    sinks[hidden.vertex] -= reference.normal * ((reach - reference.distance) * (depth / reach))
                }
            }
            // Averaged over each piece, so that it moves as one surface and bends
            // gradually to the vertices of it that are seen, which do not move. A vertex
            // another mesh shares keeps its own, the same in both meshes.
            let vertices = pieceVertices[meshIndex]
            let isSeen = seenVertices[meshIndex]
            let lists = neighbours[meshIndex]
            if !lists.isEmpty {
                for _ in 0 ..< Self.smoothingPasses {
                    var next = sinks
                    for vertex in vertices where !isSeen[vertex] && (mesh.lockFlags.isEmpty || mesh.lockFlags[vertex] & lock == 0) {
                        var sum = sinks[vertex]
                        var count: Float = 1
                        for neighbour in lists[vertex] {
                            sum += sinks[Int(neighbour)]
                            count += 1
                        }
                        next[vertex] = sum / count
                    }
                    sinks = next
                }
            }
            var moved: [Int: SIMD3<Float>] = [:]
            for vertex in vertices where !isSeen[vertex] {
                var length = simd_length(sinks[vertex])
                guard length > 0 else { continue }
                let start = simd_make_float3(simd_mul(transform, SIMD4<Float>(mesh.position(vertex), 1)))
                let direction = sinks[vertex] / length
                if let blocked = grid.nearestHit(from: start + direction * touching, direction: direction, within: length + depth, ofTriangles: referenceTriangles) {
                    length = min(length, max(blocked + touching - depth, 0))
                    guard length > 0 else { continue }
                }
                moved[vertex] = simd_make_float3(simd_mul(inverse, SIMD4<Float>(start + direction * length, 1)))
            }
            guard !moved.isEmpty else { continue }
            // Every vertex at the position moves with it: the copies of a seam or a hard
            // edge stay together, and the position remap stays true.
            var positions = mesh.positions
            var vertexData = mesh.vertexData
            var lower = mesh.boundsMin
            var upper = mesh.boundsMax
            vertexData.withUnsafeMutableBytes { raw in
                for vertex in 0 ..< mesh.vertexCount {
                    guard let position = moved[Int(mesh.positionRemap[vertex])] else { continue }
                    positions[vertex * 3] = position.x
                    positions[vertex * 3 + 1] = position.y
                    positions[vertex * 3 + 2] = position.z
                    let record = vertex * UntoldLODMesh.vertexStride
                    raw.storeBytes(of: position.x.bitPattern.littleEndian, toByteOffset: record, as: UInt32.self)
                    raw.storeBytes(of: position.y.bitPattern.littleEndian, toByteOffset: record + 4, as: UInt32.self)
                    raw.storeBytes(of: position.z.bitPattern.littleEndian, toByteOffset: record + 8, as: UInt32.self)
                    lower = simd_min(lower, position)
                    upper = simd_max(upper, position)
                }
            }
            var copy = mesh
            copy.positions = positions
            copy.vertexData = vertexData
            copy.boundsMin = lower
            copy.boundsMax = upper
            result[meshIndex] = copy
        }
        return result
    }

    // MARK: - Shared vertices

    /// For every model-space position that two or more meshes have a vertex at (the
    /// locked vertices), the first vertex of each of those meshes there, as the grid
    /// numbers them.
    private static func sharedVertices(meshes: [UntoldLODMesh], grid: ModelGrid) -> [SIMD3<UInt32>: [Int]] {
        let lock = UInt8(meshopt_SimplifyVertex_Lock)
        var copies: [SIMD3<UInt32>: [Int]] = [:]
        for (meshIndex, mesh) in meshes.enumerated() where !mesh.lockFlags.isEmpty {
            for vertex in 0 ..< mesh.vertexCount where mesh.lockFlags[vertex] & lock != 0 && Int(mesh.positionRemap[vertex]) == vertex {
                guard let global = grid.globalVertex(mesh: meshIndex, vertex: vertex) else { continue }
                copies[key(grid.position(global)), default: []].append(global)
            }
        }
        return copies.filter { $0.value.count > 1 }
    }

    static func key(_ point: SIMD3<Float>) -> SIMD3<UInt32> {
        // Adding zero folds -0 into +0.
        let folded = point + SIMD3<Float>(repeating: 0)
        return SIMD3<UInt32>(folded.x.bitPattern, folded.y.bitPattern, folded.z.bitPattern)
    }

    // MARK: - The model's triangles on a grid

    /// The triangles of the model's meshes in model space, binned on a uniform grid, so
    /// that the faces near a point and the faces along a ray are found without a pass
    /// over them all.
    final class ModelGrid: Sendable {
        /// Model-space position of every vertex of the included meshes, mesh after mesh.
        private let positions: [SIMD3<Float>]
        /// Model-space normal of every vertex, unit length (zero when the mesh has none).
        private let normals: [SIMD3<Float>]
        /// The first vertex at the same position within the mesh, as a global index.
        private let firstAtPosition: [Int32]
        private let meshOfVertex: [Int32]
        /// Where each mesh's vertices start; -1 for a mesh that is not included.
        private let vertexStart: [Int]
        /// Corners of every triangle as global vertex indices.
        private let triangles: [SIMD3<Int32>]
        /// The way each triangle's face points, turned to agree with its vertices.
        private let faceNormals: [SIMD3<Float>]
        private let meshOfTriangle: [Int32]
        private let origin: SIMD3<Float>
        private let cellStep: SIMD3<Float>
        private let cells: SIMD3<Int>
        private let cellStart: [Int]
        private let cellTriangles: [Int32]
        /// Per cell, one bit per mesh (modulo 64) that has a triangle in it.
        private let cellMeshes: [UInt64]

        init(meshes: [UntoldLODMesh], transforms: [simd_float4x4], included: [Int], cellSize: Float) {
            var positions: [SIMD3<Float>] = []
            var normals: [SIMD3<Float>] = []
            var firstAtPosition: [Int32] = []
            var meshOfVertex: [Int32] = []
            var vertexStart = [Int](repeating: -1, count: meshes.count)
            var triangles: [SIMD3<Int32>] = []
            var faceNormals: [SIMD3<Float>] = []
            var meshOfTriangle: [Int32] = []
            var lower = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var upper = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
            for meshIndex in included {
                let mesh = meshes[meshIndex]
                let transform = transforms[meshIndex]
                let rotation = Self.normalTransform(of: transform)
                vertexStart[meshIndex] = positions.count
                let base = Int32(positions.count)
                for vertex in 0 ..< mesh.vertexCount {
                    let point = simd_make_float3(simd_mul(transform, SIMD4<Float>(mesh.position(vertex), 1)))
                    positions.append(point)
                    let normal = simd_mul(rotation, SIMD3<Float>(mesh.normals[vertex * 3], mesh.normals[vertex * 3 + 1], mesh.normals[vertex * 3 + 2]))
                    let length = simd_length(normal)
                    normals.append(length > 0 ? normal / length : .zero)
                    firstAtPosition.append(base + Int32(mesh.positionRemap[vertex]))
                    meshOfVertex.append(Int32(meshIndex))
                    lower = simd_min(lower, point)
                    upper = simd_max(upper, point)
                }
                for triangle in 0 ..< mesh.triangleCount {
                    let corners = SIMD3<Int32>(
                        base + Int32(mesh.indices[triangle * 3]),
                        base + Int32(mesh.indices[triangle * 3 + 1]),
                        base + Int32(mesh.indices[triangle * 3 + 2])
                    )
                    let a = positions[Int(corners.x)], b = positions[Int(corners.y)], c = positions[Int(corners.z)]
                    var normal = simd_cross(b - a, c - a)
                    let length = simd_length(normal)
                    normal = length > 0 ? normal / length : .zero
                    // A mirrored transform turns the winding round; the vertices say which
                    // side the face is on.
                    let vertexNormal = normals[Int(corners.x)] + normals[Int(corners.y)] + normals[Int(corners.z)]
                    if simd_dot(normal, vertexNormal) < 0 {
                        normal = -normal
                    }
                    triangles.append(corners)
                    faceNormals.append(normal)
                    meshOfTriangle.append(Int32(meshIndex))
                }
            }

            let size = max(cellSize, 1e-6)
            let origin = lower - size
            let extent = upper - lower + 2 * size
            let counts = SIMD3<Int>(
                min(max(Int((extent.x / size).rounded(.up)), 1), 128),
                min(max(Int((extent.y / size).rounded(.up)), 1), 128),
                min(max(Int((extent.z / size).rounded(.up)), 1), 128)
            )
            let cellStep = SIMD3<Float>(extent.x / Float(counts.x), extent.y / Float(counts.y), extent.z / Float(counts.z))
            let cellCount = counts.x * counts.y * counts.z
            func cellRange(_ lo: SIMD3<Float>, _ hi: SIMD3<Float>) -> (SIMD3<Int>, SIMD3<Int>) {
                let a = (lo - origin) / cellStep
                let b = (hi - origin) / cellStep
                let first = SIMD3<Int>(
                    min(max(Int(a.x), 0), counts.x - 1), min(max(Int(a.y), 0), counts.y - 1), min(max(Int(a.z), 0), counts.z - 1)
                )
                let last = SIMD3<Int>(
                    min(max(Int(b.x), 0), counts.x - 1), min(max(Int(b.y), 0), counts.y - 1), min(max(Int(b.z), 0), counts.z - 1)
                )
                return (first, last)
            }
            var perCell = [Int32](repeating: 0, count: cellCount)
            var ranges: [(SIMD3<Int>, SIMD3<Int>)] = []
            ranges.reserveCapacity(triangles.count)
            for corners in triangles {
                let a = positions[Int(corners.x)], b = positions[Int(corners.y)], c = positions[Int(corners.z)]
                let r = cellRange(simd_min(simd_min(a, b), c), simd_max(simd_max(a, b), c))
                ranges.append(r)
                for z in r.0.z ... r.1.z {
                    for y in r.0.y ... r.1.y {
                        for x in r.0.x ... r.1.x {
                            perCell[(z * counts.y + y) * counts.x + x] += 1
                        }
                    }
                }
            }
            var start = [Int](repeating: 0, count: cellCount + 1)
            for cell in 0 ..< cellCount {
                start[cell + 1] = start[cell] + Int(perCell[cell])
            }
            var fill = start
            var binned = [Int32](repeating: 0, count: start[cellCount])
            var meshBits = [UInt64](repeating: 0, count: cellCount)
            for (index, r) in ranges.enumerated() {
                let bit = UInt64(1) << UInt64(Int(meshOfTriangle[index]) % 64)
                for z in r.0.z ... r.1.z {
                    for y in r.0.y ... r.1.y {
                        for x in r.0.x ... r.1.x {
                            let cell = (z * counts.y + y) * counts.x + x
                            binned[fill[cell]] = Int32(index)
                            fill[cell] += 1
                            meshBits[cell] |= bit
                        }
                    }
                }
            }
            self.positions = positions
            self.normals = normals
            self.firstAtPosition = firstAtPosition
            self.meshOfVertex = meshOfVertex
            self.vertexStart = vertexStart
            self.triangles = triangles
            self.faceNormals = faceNormals
            self.meshOfTriangle = meshOfTriangle
            self.origin = origin
            self.cellStep = cellStep
            cells = counts
            cellStart = start
            cellTriangles = binned
            cellMeshes = meshBits
        }

        // MARK: Vertices

        var vertexCount: Int {
            positions.count
        }

        func globalVertex(mesh: Int, vertex: Int) -> Int? {
            let start = vertexStart[mesh]
            return start >= 0 ? start + vertex : nil
        }

        func mesh(ofVertex vertex: Int) -> Int {
            Int(meshOfVertex[vertex])
        }

        /// The mesh of a vertex and its index within that mesh.
        func local(ofVertex vertex: Int) -> (mesh: Int, vertex: Int) {
            let mesh = Int(meshOfVertex[vertex])
            return (mesh, vertex - vertexStart[mesh])
        }

        var triangleCount: Int {
            triangles.count
        }

        func mesh(ofTriangle triangle: Int) -> Int {
            Int(meshOfTriangle[triangle])
        }

        /// A flag per triangle from its mesh and its corners (global vertex indices).
        func triangleFlags(_ flag: (_ mesh: Int, _ corners: SIMD3<Int>) -> Bool) -> [Bool] {
            triangles.indices.map { triangle in
                let corners = triangles[triangle]
                return flag(Int(meshOfTriangle[triangle]), SIMD3<Int>(Int(corners.x), Int(corners.y), Int(corners.z)))
            }
        }

        func position(_ vertex: Int) -> SIMD3<Float> {
            positions[vertex]
        }

        /// For each vertex, whether a triangle of one of `meshes` lies within `reach` of
        /// its cell.
        func verticesNear(meshes: [Bool], within reach: Float) -> [Bool] {
            var wanted: UInt64 = 0
            for (mesh, isWanted) in meshes.enumerated() where isWanted {
                wanted |= UInt64(1) << UInt64(mesh % 64)
            }
            let rings = cellRings(for: reach)
            // The meshes within `rings` cells of each cell, by a separable dilation.
            var dilated = cellMeshes
            for axis in 0 ..< 3 where rings[axis] > 0 {
                let ring = rings[axis]
                var next = dilated
                for z in 0 ..< cells.z {
                    for y in 0 ..< cells.y {
                        for x in 0 ..< cells.x {
                            var bits: UInt64 = 0
                            for step in -ring ... ring {
                                var c = SIMD3<Int>(x, y, z)
                                c[axis] += step
                                guard c[axis] >= 0, c[axis] < cells[axis] else { continue }
                                bits |= dilated[(c.z * cells.y + c.y) * cells.x + c.x]
                            }
                            next[(z * cells.y + y) * cells.x + x] = bits
                        }
                    }
                }
                dilated = next
            }
            var near = [Bool](repeating: false, count: positions.count)
            for vertex in positions.indices {
                guard let home = cell(of: positions[vertex]) else { continue }
                near[vertex] = dilated[(home.z * cells.y + home.y) * cells.x + home.x] & wanted != 0
            }
            return near
        }

        /// The rays cast from a vertex to tell whether its side is seen: one along its
        /// normal and this many round it, `coneAngle` from the normal. A wheel-arch
        /// liner's normal points at the tyre, and the liner is seen through the arch all
        /// the same.
        static let coneRays = 8
        static let coneAngle: Float = .pi / 3

        /// For each vertex flagged in `asked`, whether the ray along its normal, or one of
        /// the cone of rays round it, escapes the model: true for a seen vertex, false for
        /// a covered one, nil for a vertex not asked about or without a normal. The
        /// vertices at one position (a hard edge, a seam) share the answer: the position
        /// is seen when any of them is.
        func seen(_ asked: [Bool], offset: Float) -> [Bool?] {
            var result = [Bool?](repeating: nil, count: positions.count)
            let list = positions.indices.filter { asked[Int(firstAtPosition[$0])] }
            let cosine = cos(Self.coneAngle), sine = sin(Self.coneAngle)
            result.withUnsafeMutableBufferPointer { buffer in
                nonisolated(unsafe) let buffer = buffer
                DispatchQueue.concurrentPerform(iterations: list.count) { index in
                    let vertex = list[index]
                    let normal = normals[vertex]
                    guard simd_length_squared(normal) > 0 else { return }
                    let from = positions[vertex] + normal * offset
                    if !rayHitsAnything(from: from, direction: normal) {
                        buffer[vertex] = true
                        return
                    }
                    let helper: SIMD3<Float> = abs(normal.y) < 0.9 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(1, 0, 0)
                    let side = simd_normalize(simd_cross(normal, helper))
                    let up = simd_cross(normal, side)
                    for ray in 0 ..< Self.coneRays {
                        let angle = 2 * Float.pi * Float(ray) / Float(Self.coneRays)
                        let direction = normal * cosine + (side * cos(angle) + up * sin(angle)) * sine
                        if !rayHitsAnything(from: from, direction: direction) {
                            buffer[vertex] = true
                            return
                        }
                    }
                    buffer[vertex] = false
                }
            }
            var byFirst: [Int: Bool] = [:]
            for vertex in list {
                guard let value = result[vertex] else { continue }
                let first = Int(firstAtPosition[vertex])
                byFirst[first] = (byFirst[first] ?? false) || value
            }
            for vertex in positions.indices {
                if let value = byFirst[Int(firstAtPosition[vertex])] {
                    result[vertex] = value
                }
            }
            return result
        }

        // MARK: Faces near a point

        /// The faces flagged in `ofTriangles` within `reach` of `point` that `point` lies
        /// behind: the face's nearest point is farther than `touching` and in front of
        /// `point`, within the angle whose cosine is `behindCosine` of the way the face
        /// points. Nearest first, at most `limit` of them and each facing its own way (the
        /// cosine between the normals of any two under `distinctCosine`).
        func references(
            near point: SIMD3<Float>, within reach: Float, touching: Float, behindCosine: Float,
            ofTriangles: [Bool], limit: Int, distinctCosine: Float
        ) -> [Reference] {
            guard let home = cell(of: point) else { return [] }
            let rings = cellRings(for: reach)
            var candidates: [(distance: Float, normal: SIMD3<Float>)] = []
            for z in max(home.z - rings.z, 0) ... min(home.z + rings.z, cells.z - 1) {
                for y in max(home.y - rings.y, 0) ... min(home.y + rings.y, cells.y - 1) {
                    for x in max(home.x - rings.x, 0) ... min(home.x + rings.x, cells.x - 1) {
                        for index in triangles(in: SIMD3<Int>(x, y, z)) {
                            let triangle = Int(index)
                            guard ofTriangles[triangle] else { continue }
                            let corners = triangles[triangle]
                            let normal = faceNormals[triangle]
                            let closest = Self.closestPoint(
                                to: point, onTriangle: positions[Int(corners.x)], positions[Int(corners.y)], positions[Int(corners.z)]
                            )
                            let offset = point - closest
                            let distance = simd_length(offset)
                            guard distance <= reach, distance > touching, simd_dot(offset, normal) < -behindCosine * distance else { continue }
                            candidates.append((distance, normal))
                        }
                    }
                }
            }
            guard !candidates.isEmpty else { return [] }
            candidates.sort { $0.distance < $1.distance }
            var references: [Reference] = []
            for candidate in candidates where references.count < limit {
                guard references.allSatisfy({ simd_dot($0.normal, candidate.normal) < distinctCosine }) else { continue }
                references.append(Reference(normal: candidate.normal, distance: candidate.distance))
            }
            return references
        }

        // MARK: Rays

        /// Whether a ray from `start` along `direction` meets a triangle of the model
        /// before it leaves the grid.
        func rayHitsAnything(from start: SIMD3<Float>, direction: SIMD3<Float>) -> Bool {
            guard simd_length_squared(direction) > 0 else { return false }
            var hit = false
            traverse(from: start, direction: direction) { cell, _ in
                for index in triangles(in: cell) {
                    let corners = triangles[Int(index)]
                    if Self.rayHits(start, direction, positions[Int(corners.x)], positions[Int(corners.y)], positions[Int(corners.z)]) {
                        hit = true
                        return false
                    }
                }
                return true
            }
            return hit
        }

        /// Visits the cells a ray from `start` along `direction` passes, in order, with the
        /// distance along the ray at which it enters each, until `visit` returns false or
        /// the ray leaves the grid.
        private func traverse(from start: SIMD3<Float>, direction: SIMD3<Float>, _ visit: (SIMD3<Int>, Float) -> Bool) {
            // Amanatides and Woo: from cell to cell along the ray.
            var current: SIMD3<Int>
            var entered: Float = 0
            if let home = cell(of: start) {
                current = home
            } else {
                let lower = origin
                let upper = origin + cellStep * SIMD3<Float>(Float(cells.x), Float(cells.y), Float(cells.z))
                var tEnter: Float = 0
                var tExit: Float = .greatestFiniteMagnitude
                for axis in 0 ..< 3 {
                    if abs(direction[axis]) < 1e-12 {
                        if start[axis] < lower[axis] || start[axis] > upper[axis] {
                            return
                        }
                    } else {
                        let t1 = (lower[axis] - start[axis]) / direction[axis]
                        let t2 = (upper[axis] - start[axis]) / direction[axis]
                        tEnter = max(tEnter, min(t1, t2))
                        tExit = min(tExit, max(t1, t2))
                    }
                }
                guard tEnter <= tExit, let home = cell(of: start + direction * (tEnter + 1e-6)) else { return }
                current = home
                entered = tEnter
            }
            var step = SIMD3<Int>(repeating: 0)
            var tMax = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            var tDelta = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
            for axis in 0 ..< 3 where abs(direction[axis]) > 1e-12 {
                step[axis] = direction[axis] > 0 ? 1 : -1
                let boundary = origin[axis] + cellStep[axis] * Float(current[axis] + (direction[axis] > 0 ? 1 : 0))
                tMax[axis] = (boundary - start[axis]) / direction[axis]
                tDelta[axis] = cellStep[axis] / abs(direction[axis])
            }
            while visit(current, entered) {
                // Into the next cell along the axis whose boundary comes first.
                let axis = tMax.x < tMax.y ? (tMax.x < tMax.z ? 0 : 2) : (tMax.y < tMax.z ? 1 : 2)
                current[axis] += step[axis]
                guard current[axis] >= 0, current[axis] < cells[axis] else { return }
                entered = tMax[axis]
                tMax[axis] += tDelta[axis]
            }
        }

        /// How far past a triangle's edge, in its own coordinates, a ray still hits it:
        /// a ray through a vertex or an edge of the model (a lining offset from its
        /// surface sends one through every vertex) must not slip between the faces there.
        private static let edgeTolerance: Float = 1e-4

        /// The distance along a ray from `start` along `direction` (unit length) to the
        /// nearest face flagged in `ofTriangles`, when there is one within `limit`.
        func nearestHit(from start: SIMD3<Float>, direction: SIMD3<Float>, within limit: Float, ofTriangles: [Bool]) -> Float? {
            guard simd_length_squared(direction) > 0 else { return nil }
            var best: Float?
            traverse(from: start, direction: direction) { cell, entry in
                if let best, entry > best {
                    return false
                }
                guard entry <= limit else { return false }
                for index in triangles(in: cell) where ofTriangles[Int(index)] {
                    let corners = triangles[Int(index)]
                    if let t = Self.rayDistance(start, direction, positions[Int(corners.x)], positions[Int(corners.y)], positions[Int(corners.z)]),
                       t <= limit, t < (best ?? .greatestFiniteMagnitude)
                    {
                        best = t
                    }
                }
                return true
            }
            return best
        }

        private static func rayHits(_ start: SIMD3<Float>, _ direction: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Bool {
            rayDistance(start, direction, a, b, c) != nil
        }

        /// The distance along the ray to the triangle, when the ray meets it ahead.
        private static func rayDistance(_ start: SIMD3<Float>, _ direction: SIMD3<Float>, _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float? {
            // Möller and Trumbore, either side of the face.
            let e1 = b - a, e2 = c - a
            let p = simd_cross(direction, e2)
            let det = simd_dot(e1, p)
            guard abs(det) > 1e-12 else { return nil }
            let f = 1 / det
            let s = start - a
            let u = f * simd_dot(s, p)
            guard u >= -edgeTolerance, u <= 1 + edgeTolerance else { return nil }
            let q = simd_cross(s, e1)
            let v = f * simd_dot(direction, q)
            guard v >= -edgeTolerance, u + v <= 1 + edgeTolerance else { return nil }
            let t = f * simd_dot(e2, q)
            return t > 0 ? t : nil
        }

        // MARK: Cells

        /// How many cells each way cover `reach`.
        private func cellRings(for reach: Float) -> SIMD3<Int> {
            SIMD3<Int>(
                Int((reach / cellStep.x).rounded(.up)), Int((reach / cellStep.y).rounded(.up)), Int((reach / cellStep.z).rounded(.up))
            )
        }

        private func cell(of point: SIMD3<Float>) -> SIMD3<Int>? {
            let p = (point - origin) / cellStep
            guard p.x >= 0, p.y >= 0, p.z >= 0 else { return nil }
            let c = SIMD3<Int>(Int(p.x), Int(p.y), Int(p.z))
            guard c.x < cells.x, c.y < cells.y, c.z < cells.z else { return nil }
            return c
        }

        private func triangles(in cell: SIMD3<Int>) -> ArraySlice<Int32> {
            let index = (cell.z * cells.y + cell.y) * cells.x + cell.x
            return cellTriangles[cellStart[index] ..< cellStart[index + 1]]
        }

        /// What takes a normal of the mesh to model space: the inverse transpose of the
        /// transform's upper 3x3 (the transform itself for a rotation and a uniform scale).
        static func normalTransform(of transform: simd_float4x4) -> simd_float3x3 {
            let upper = simd_float3x3(
                simd_make_float3(transform.columns.0),
                simd_make_float3(transform.columns.1),
                simd_make_float3(transform.columns.2)
            )
            let inverse = upper.inverse
            return inverse.determinant.isFinite && inverse.determinant != 0 ? inverse.transpose : upper
        }

        /// The point of the triangle `a b c` nearest to `p`.
        static func closestPoint(to p: SIMD3<Float>, onTriangle a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> SIMD3<Float> {
            // Ericson, Real-Time Collision Detection, closest point on a triangle.
            let ab = b - a, ac = c - a, ap = p - a
            let d1 = simd_dot(ab, ap), d2 = simd_dot(ac, ap)
            if d1 <= 0, d2 <= 0 {
                return a
            }
            let bp = p - b
            let d3 = simd_dot(ab, bp), d4 = simd_dot(ac, bp)
            if d3 >= 0, d4 <= d3 {
                return b
            }
            let vc = d1 * d4 - d3 * d2
            if vc <= 0, d1 >= 0, d3 <= 0 {
                let v = d1 / (d1 - d3)
                return a + v * ab
            }
            let cp = p - c
            let d5 = simd_dot(ab, cp), d6 = simd_dot(ac, cp)
            if d6 >= 0, d5 <= d6 {
                return c
            }
            let vb = d5 * d2 - d1 * d6
            if vb <= 0, d2 >= 0, d6 <= 0 {
                let w = d2 / (d2 - d6)
                return a + w * ac
            }
            let va = d3 * d6 - d5 * d4
            if va <= 0, d4 - d3 >= 0, d5 - d6 >= 0 {
                let w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
                return b + w * (c - b)
            }
            let denominator = 1 / (va + vb + vc)
            let v = vb * denominator, w = vc * denominator
            return a + ab * v + ac * w
        }
    }
}
