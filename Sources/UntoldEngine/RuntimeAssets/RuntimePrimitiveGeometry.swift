//
//  RuntimePrimitiveGeometry.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd

/// A primitive's geometry decoded from its packed vertex and index data,
/// for tools and tests that work on an asset without a GPU (the same
/// decoding the mesh upload uses).
public struct RuntimePrimitiveGeometry: Sendable {
    public var positions: [simd_float3]
    public var normals: [simd_float3]
    /// Triangle list, three vertex indices per triangle.
    public var triangles: [UInt32]
    /// Skin joint indices per vertex (into the skin's joint list) and
    /// weights; empty for unskinned primitives.
    public var jointIndices: [simd_ushort4]
    public var jointWeights: [simd_float4]
}

public extension RuntimeMeshPrimitive {
    /// Decodes the primitive's vertices, triangles and skin binding.
    func decodedGeometry() throws -> RuntimePrimitiveGeometry {
        let reader = UntoldBinaryReader(data: vertexData)
        var positions: [simd_float3] = []
        var normals: [simd_float3] = []
        positions.reserveCapacity(vertexCount)
        normals.reserveCapacity(vertexCount)
        for _ in 0 ..< vertexCount {
            let vertex = try UntoldPBRStaticVertexV1.decode(from: reader)
            positions.append(vertex.position)
            normals.append(UntoldVertexPacking.unpackNormal(vertex.normalPacked))
        }

        var triangles = [UInt32](repeating: 0, count: indexCount)
        indexData.withUnsafeBytes { raw in
            switch indexFormat {
            case .uint16:
                let source = raw.bindMemory(to: UInt16.self)
                for i in 0 ..< min(indexCount, source.count) {
                    triangles[i] = UInt32(source[i])
                }
            case .uint32:
                let source = raw.bindMemory(to: UInt32.self)
                for i in 0 ..< min(indexCount, source.count) {
                    triangles[i] = source[i]
                }
            }
        }

        var jointIndices: [simd_ushort4] = []
        var jointWeights: [simd_float4] = []
        if let skin {
            jointIndices = skin.jointIndexData.withUnsafeBytes { Array($0.bindMemory(to: simd_ushort4.self)) }
            jointWeights = skin.jointWeightData.withUnsafeBytes { Array($0.bindMemory(to: simd_float4.self)) }
        }
        return RuntimePrimitiveGeometry(
            positions: positions, normals: normals, triangles: triangles,
            jointIndices: jointIndices, jointWeights: jointWeights
        )
    }
}
