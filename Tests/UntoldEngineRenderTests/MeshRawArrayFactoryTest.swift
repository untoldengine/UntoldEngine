//
//  MeshRawArrayFactoryTest.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import CShaderTypes
import simd
@testable import UntoldEngine
import XCTest

/// Covers `Mesh.makeMesh(positions:normals:uvs:tangents:indices:name:)` — the public factory
/// that lets runtime code (procedural-geometry extensions, in particular) build a renderable
/// `Mesh` from plain CPU arrays with no source file and no packed runtime-asset payload.
final class MeshRawArrayFactoryTest: BaseRenderSetup {
    override func initializeAssets() {}

    private func quadArrays() -> (
        positions: [SIMD3<Float>],
        normals: [SIMD3<Float>],
        uvs: [SIMD2<Float>],
        indices: [UInt32]
    ) {
        let positions: [SIMD3<Float>] = [
            SIMD3(-1, 0, -1),
            SIMD3(1, 0, -1),
            SIMD3(1, 0, 1),
            SIMD3(-1, 0, 1),
        ]
        let normals = [SIMD3<Float>](repeating: SIMD3(0, 1, 0), count: 4)
        let uvs: [SIMD2<Float>] = [
            SIMD2(0, 0), SIMD2(1, 0), SIMD2(1, 1), SIMD2(0, 1),
        ]
        let indices: [UInt32] = [0, 1, 2, 0, 2, 3]
        return (positions, normals, uvs, indices)
    }

    func testMakeMesh_buildsExpectedVertexAndIndexCounts() throws {
        let (positions, normals, uvs, indices) = quadArrays()

        let mesh = try XCTUnwrap(Mesh.makeMesh(
            positions: positions,
            normals: normals,
            uvs: uvs,
            indices: indices,
            name: "TestQuad"
        ))

        XCTAssertEqual(mesh.name, "TestQuad")
        XCTAssertEqual(mesh.metalKitMesh.vertexCount, positions.count)
        XCTAssertEqual(mesh.metalKitMesh.submeshes.count, 1)
        XCTAssertEqual(mesh.metalKitMesh.submeshes[0].indexCount, indices.count)
    }

    func testMakeMesh_boundingBoxMatchesInputPositions() throws {
        let (positions, normals, uvs, indices) = quadArrays()

        let mesh = try XCTUnwrap(Mesh.makeMesh(
            positions: positions,
            normals: normals,
            uvs: uvs,
            indices: indices,
            name: "TestQuad"
        ))

        XCTAssertLessThan(simd_distance(mesh.localBounds.min, SIMD3<Float>(-1, 0, -1)), 1e-5)
        XCTAssertLessThan(simd_distance(mesh.localBounds.max, SIMD3<Float>(1, 0, 1)), 1e-5)
    }

    func testMakeMesh_positionBufferContentsRoundTrip() throws {
        let (positions, normals, uvs, indices) = quadArrays()

        let mesh = try XCTUnwrap(Mesh.makeMesh(
            positions: positions,
            normals: normals,
            uvs: uvs,
            indices: indices,
            name: "TestQuad"
        ))

        let positionBuffer = mesh.metalKitMesh.vertexBuffers[Int(modelPassVerticesIndex.rawValue)].buffer
        let readBack = positionBuffer.contents().bindMemory(to: simd_float4.self, capacity: positions.count)
        for index in 0 ..< positions.count {
            let expected = positions[index]
            let actual = readBack[index]
            XCTAssertEqual(actual.x, expected.x, accuracy: 1e-5)
            XCTAssertEqual(actual.y, expected.y, accuracy: 1e-5)
            XCTAssertEqual(actual.z, expected.z, accuracy: 1e-5)
            XCTAssertEqual(actual.w, 1.0, accuracy: 1e-5)
        }
    }

    /// Tangents are optional on input, but `Mesh`'s ModelIO construction path recomputes a
    /// proper tangent basis from the UVs/normals whenever texture coordinates are present
    /// (`addOrthTanBasis`), overwriting whatever placeholder was written into the buffer. So
    /// omitting `tangents` shouldn't need to produce any particular value — it just needs to
    /// not crash and to still produce a valid (finite, unit-length, ±1-handed) tangent.
    func testMakeMesh_omittedTangentStillProducesAValidBasis() throws {
        let (positions, normals, uvs, indices) = quadArrays()

        let mesh = try XCTUnwrap(Mesh.makeMesh(
            positions: positions,
            normals: normals,
            uvs: uvs,
            indices: indices,
            name: "TestQuad"
        ))

        let tangentBuffer = mesh.metalKitMesh.vertexBuffers[Int(modelPassTangentIndex.rawValue)].buffer
        let readBack = tangentBuffer.contents().bindMemory(to: simd_float4.self, capacity: positions.count)
        for index in 0 ..< positions.count {
            let tangent = readBack[index]
            XCTAssertTrue(tangent.x.isFinite && tangent.y.isFinite && tangent.z.isFinite)
            XCTAssertEqual(simd_length(SIMD3(tangent.x, tangent.y, tangent.z)), 1.0, accuracy: 1e-4)
            XCTAssertEqual(abs(tangent.w), 1.0, accuracy: 1e-4)
        }
    }

    func testMakeMesh_returnsNilOnMismatchedArrayLengths() {
        let (positions, normals, uvs, indices) = quadArrays()
        let mesh = Mesh.makeMesh(
            positions: positions,
            normals: Array(normals.dropLast()),
            uvs: uvs,
            indices: indices,
            name: "Bad"
        )
        XCTAssertNil(mesh)
    }

    func testMakeMesh_canBeAttachedToAnEntityAndRendered() throws {
        let (positions, normals, uvs, indices) = quadArrays()
        let mesh = try XCTUnwrap(Mesh.makeMesh(
            positions: positions,
            normals: normals,
            uvs: uvs,
            indices: indices,
            name: "TestQuad"
        ))

        let entityId = createEntity()
        setEntityName(entityId: entityId, name: "RawArrayMeshEntity")
        setEntityMeshDirect(entityId: entityId, meshes: [mesh], assetName: "TestQuad")

        let renderComponent = try XCTUnwrap(scene.get(component: RenderComponent.self, for: entityId))
        XCTAssertEqual(renderComponent.mesh.count, 1)
        XCTAssertEqual(renderComponent.mesh[0].metalKitMesh.vertexCount, positions.count)
    }
}
