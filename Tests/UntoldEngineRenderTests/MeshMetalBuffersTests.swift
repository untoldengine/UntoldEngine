//
//  MeshMetalBuffersTests.swift
//  UntoldEngine
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Metal
import MetalKit
@testable import UntoldEngine
import XCTest

/// A mesh keeps the Metal buffers of its MetalKit mesh, and a submesh the index data of
/// its MetalKit submesh, so that a draw does not ask MetalKit for them. They must be
/// what MetalKit would have answered.
@MainActor
final class MeshMetalBuffersTests: BaseRenderSetup {
    override func tearDown() async throws {
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    private func assertBuffersAreMetalKits(_ meshes: [Mesh], _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(meshes.isEmpty, what, file: file, line: line)
        for mesh in meshes {
            let metalKitBuffers = mesh.metalKitMesh.vertexBuffers
            XCTAssertEqual(mesh.vertexBuffers.count, metalKitBuffers.count, what, file: file, line: line)
            for (kept, metalKit) in zip(mesh.vertexBuffers, metalKitBuffers) {
                XCTAssertTrue(kept === metalKit.buffer, "\(what): vertex buffer", file: file, line: line)
            }
            // The passes bind the six streams of the model's vertex layout: positions,
            // normals, texture coordinates, tangents, joint ids and joint weights.
            XCTAssertGreaterThanOrEqual(mesh.vertexBuffers.count, 6, what, file: file, line: line)

            XCTAssertFalse(mesh.submeshes.isEmpty, what, file: file, line: line)
            for submesh in mesh.submeshes {
                let metalKitSubmesh = submesh.metalKitSubmesh
                XCTAssertEqual(submesh.primitiveType, metalKitSubmesh.primitiveType, what, file: file, line: line)
                XCTAssertEqual(submesh.indexCount, metalKitSubmesh.indexCount, what, file: file, line: line)
                XCTAssertEqual(submesh.indexType, metalKitSubmesh.indexType, what, file: file, line: line)
                XCTAssertTrue(submesh.indexBuffer === metalKitSubmesh.indexBuffer.buffer, "\(what): index buffer", file: file, line: line)
                XCTAssertEqual(submesh.indexBufferOffset, metalKitSubmesh.indexBuffer.offset, what, file: file, line: line)
                XCTAssertGreaterThan(submesh.indexCount, 0, what, file: file, line: line)
            }
        }
    }

    func testAPrimitiveKeepsTheBuffersOfItsMetalKitMesh() {
        assertBuffersAreMetalKits(BasicPrimitives.createCube(extent: 1), "cube")
        assertBuffersAreMetalKits(BasicPrimitives.createSphere(extent: 1), "sphere")
        assertBuffersAreMetalKits(BasicPrimitives.createPlane(width: 2, depth: 2), "plane")
    }

    func testALoadedModelKeepsTheBuffersOfItsMetalKitMeshes() async throws {
        let entity = createEntity()
        let loaded = expectation(description: "model")
        setEntityMeshAsync(entityId: entity, filename: "ball", withExtension: "untold") { _ in loaded.fulfill() }
        await fulfillment(of: [loaded], timeout: 60)

        let render = try XCTUnwrap(scene.get(component: RenderComponent.self, for: entity) ?? firstRenderComponent(under: entity))
        assertBuffersAreMetalKits(render.mesh, "ball.untold")
    }

    func testACopyOfAMeshSharesItsBuffers() {
        let meshes = BasicPrimitives.createCube(extent: 1)
        var copy = meshes
        copy[0].localSpace.columns.3.x = 5

        XCTAssertTrue(copy[0].vertexBuffers[0] === meshes[0].vertexBuffers[0])
        XCTAssertTrue(copy[0].submeshes[0].indexBuffer === meshes[0].submeshes[0].indexBuffer)
    }

    private func firstRenderComponent(under entity: EntityID) -> RenderComponent? {
        for child in getEntityChildren(parentId: entity) {
            if let render = scene.get(component: RenderComponent.self, for: child) ?? firstRenderComponent(under: child) {
                return render
            }
        }
        return nil
    }
}
