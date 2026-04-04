//
//  AssetValidationTests.swift
//  UntoldEngine
//
//  Validation tests that compare real exported `.untold` geometry against
//  companion JSON validation artifacts emitted by the exporter.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
@testable import UntoldEngine
import XCTest

final class AssetValidationTests: XCTestCase {
    func testRedplayerUntoldMatchesValidationJSON() throws {
        try assertUntoldMatchesValidationJSON(assetName: "redplayer")
    }

    func testCubeParentChildUntoldMatchesValidationJSON() throws {
        try assertUntoldMatchesValidationJSON(assetName: "cubeparentchild")
    }

    private func assertUntoldMatchesValidationJSON(assetName: String) throws {
        guard let untoldURL = Bundle.module.url(forResource: assetName, withExtension: "untold") else {
            XCTFail("Failed to locate \(assetName).untold in test resources")
            return
        }

        guard let validationURL = Bundle.module.url(forResource: "\(assetName).validation", withExtension: "json") else {
            XCTFail("Failed to locate \(assetName).validation.json in test resources")
            return
        }

        let decoded = try UntoldReader().readAsset(from: untoldURL)
        let fileData = try Data(contentsOf: untoldURL)
        let validation = try JSONDecoder().decode(
            UntoldValidationAsset.self,
            from: Data(contentsOf: validationURL)
        )

        XCTAssertEqual(validation.format, "untold-validation")
        XCTAssertEqual(validation.version, 1)
        XCTAssertEqual(validation.meshCount, decoded.meshes.count)
        XCTAssertEqual(validation.meshes.count, decoded.meshes.count)

        let vertexChunk = try requiredChunk(.vertexData, in: decoded.chunks)
        let indexChunk = try requiredChunk(.indexData, in: decoded.chunks)
        let vertexChunkData = try chunkData(for: vertexChunk, fileData: fileData)
        let indexChunkData = try chunkData(for: indexChunk, fileData: fileData)

        for (meshIndex, mesh) in decoded.meshes.enumerated() {
            let expected = validation.meshes[meshIndex]
            XCTAssertEqual(Int(mesh.vertexCount), expected.vertexCount, "Vertex count mismatch for mesh \(meshIndex)")
            XCTAssertEqual(Int(mesh.indexCount), expected.indexCount, "Index count mismatch for mesh \(meshIndex)")

            if mesh.meshNameOffset != UntoldFormat.invalidIndex {
                XCTAssertEqual(try decoded.string(at: mesh.meshNameOffset), expected.name)
            }

            let vertices = try decodeVertices(for: mesh, from: vertexChunkData)
            let indices = try decodeIndices(for: mesh, from: indexChunkData)

            XCTAssertEqual(vertices.count, expected.vertexCount)
            XCTAssertEqual(indices.count, expected.indexCount)

            for i in 0 ..< vertices.count {
                let actualVertex = vertices[i]
                let expectedPosition = expected.positions[i].simd3
                assertApproximatelyEqual(
                    actualVertex.position,
                    expectedPosition,
                    tolerance: 1e-5,
                    message: "Position mismatch at vertex \(i), mesh \(meshIndex)"
                )

                let actualNormal = UntoldVertexPacking.unpackNormal(actualVertex.normalPacked)
                let expectedNormal = expected.normals[i].simd3
                assertApproximatelyEqual(
                    actualNormal,
                    expectedNormal,
                    tolerance: 0.01,
                    message: "Normal mismatch at vertex \(i), mesh \(meshIndex)"
                )

                let actualTangent = UntoldVertexPacking.unpackTangent(actualVertex.tangentPacked)
                let expectedTangent = expected.tangents[i].xyz.simd3
                assertApproximatelyEqual(
                    actualTangent.vector,
                    expectedTangent,
                    tolerance: 0.01,
                    message: "Tangent mismatch at vertex \(i), mesh \(meshIndex)"
                )
                XCTAssertEqual(
                    actualTangent.handedness,
                    expected.tangents[i].handedness,
                    "Tangent handedness mismatch at vertex \(i), mesh \(meshIndex)"
                )

                let actualUV = decodeHalfUV(actualVertex.uv0)
                let expectedUV = expected.uv0[i].simd2
                assertApproximatelyEqual(
                    actualUV,
                    expectedUV,
                    tolerance: 0.001,
                    message: "UV mismatch at vertex \(i), mesh \(meshIndex)"
                )
            }

            XCTAssertEqual(indices, expected.indices, "Index buffer mismatch for mesh \(meshIndex)")
        }
    }

    private func requiredChunk(_ type: UntoldChunkType, in chunks: [UntoldChunkEntryV1]) throws -> UntoldChunkEntryV1 {
        guard let chunk = chunks.first(where: { $0.chunkType == type }) else {
            throw UntoldValidationError.missingRequiredChunk(type)
        }
        return chunk
    }

    private func chunkData(for chunk: UntoldChunkEntryV1, fileData: Data) throws -> Data {
        let start = Int(chunk.fileOffset)
        let end = start + Int(chunk.compressedSize)
        guard start >= 0, end <= fileData.count else {
            throw UntoldBinaryDecodingError.outOfBounds(offset: start, requested: Int(chunk.compressedSize), available: fileData.count)
        }
        return fileData.subdata(in: start ..< end)
    }

    private func decodeVertices(for mesh: UntoldMeshRecordV1, from chunkData: Data) throws -> [UntoldPBRStaticVertexV1] {
        let reader = UntoldBinaryReader(data: chunkData)
        try reader.seek(to: Int(mesh.vertexDataOffset))

        var vertices: [UntoldPBRStaticVertexV1] = []
        vertices.reserveCapacity(Int(mesh.vertexCount))
        for _ in 0 ..< mesh.vertexCount {
            try vertices.append(UntoldPBRStaticVertexV1.decode(from: reader))
        }
        return vertices
    }

    private func decodeIndices(for mesh: UntoldMeshRecordV1, from chunkData: Data) throws -> [Int] {
        let reader = UntoldBinaryReader(data: chunkData)
        try reader.seek(to: Int(mesh.indexDataOffset))

        var indices: [Int] = []
        indices.reserveCapacity(Int(mesh.indexCount))
        switch mesh.indexType {
        case .uint16:
            for _ in 0 ..< mesh.indexCount {
                try indices.append(Int(reader.readUInt16LE()))
            }
        case .uint32:
            for _ in 0 ..< mesh.indexCount {
                try indices.append(Int(reader.readUInt32LE()))
            }
        }
        return indices
    }

    private func decodeHalfUV(_ packed: SIMD2<UInt16>) -> SIMD2<Float> {
        SIMD2<Float>(
            Float(Float16(bitPattern: packed.x)),
            Float(Float16(bitPattern: packed.y))
        )
    }

    private func assertApproximatelyEqual(
        _ actual: SIMD3<Float>,
        _ expected: SIMD3<Float>,
        tolerance: Float,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(abs(actual.x - expected.x), tolerance, message, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(actual.y - expected.y), tolerance, message, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(actual.z - expected.z), tolerance, message, file: file, line: line)
    }

    private func assertApproximatelyEqual(
        _ actual: SIMD2<Float>,
        _ expected: SIMD2<Float>,
        tolerance: Float,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThanOrEqual(abs(actual.x - expected.x), tolerance, message, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(actual.y - expected.y), tolerance, message, file: file, line: line)
    }
}

private struct UntoldValidationAsset: Decodable {
    let format: String
    let version: Int
    let assetName: String
    let meshCount: Int
    let meshes: [UntoldValidationMesh]

    private enum CodingKeys: String, CodingKey {
        case format
        case version
        case assetName = "asset_name"
        case meshCount = "mesh_count"
        case meshes
    }
}

private struct UntoldValidationMesh: Decodable {
    let name: String
    let vertexCount: Int
    let indexCount: Int
    let positions: [[Float]]
    let normals: [[Float]]
    let tangents: [UntoldValidationTangent]
    let uv0: [[Float]]
    let indices: [Int]

    private enum CodingKeys: String, CodingKey {
        case name
        case vertexCount = "vertex_count"
        case indexCount = "index_count"
        case positions
        case normals
        case tangents
        case uv0
        case indices
    }
}

private struct UntoldValidationTangent: Decodable {
    let xyz: [Float]
    let handedness: Float
}

private extension [Float] {
    var simd3: SIMD3<Float> {
        precondition(count == 3, "Expected exactly 3 floats")
        return SIMD3<Float>(self[0], self[1], self[2])
    }

    var simd2: SIMD2<Float> {
        precondition(count == 2, "Expected exactly 2 floats")
        return SIMD2<Float>(self[0], self[1])
    }
}
