//
//  RuntimeMeshConstructionTests.swift
//  UntoldEngine
//
//  Tests for converting RuntimeAsset primitives into engine Mesh objects
//  without ModelIO file parsing.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import XCTest
@testable import UntoldEngine

@MainActor
final class RuntimeMeshConstructionTests: BaseRenderSetup {
    func testBuildsEngineMeshesFromUntoldRuntimeAsset() async throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold in test resources")
            return
        }

        let runtimeAsset = try await UntoldRuntimeAssetLoader().loadAsset(from: untoldURL)

        guard let firstNode = runtimeAsset.nodes.first(where: { !$0.primitives.isEmpty }),
              let firstPrimitive = firstNode.primitives.first
        else {
            XCTFail("redplayer.untold has no nodes with primitives")
            return
        }

        let firstMesh = try XCTUnwrap(
            Mesh.makeMesh(from: firstPrimitive, device: renderInfo.device),
            "Mesh.makeMesh should succeed for a valid runtime primitive"
        )

        XCTAssertFalse(firstMesh.submeshes.isEmpty)
        XCTAssertGreaterThan(firstMesh.metalKitMesh.vertexBuffers.count, 0)
        XCTAssertGreaterThan(firstMesh.metalKitMesh.submeshes.count, 0)
        XCTAssertFalse(firstMesh.assetName.isEmpty)
        XCTAssertLessThanOrEqual(firstMesh.boundingBox.min.x, firstMesh.boundingBox.max.x)
        XCTAssertLessThanOrEqual(firstMesh.boundingBox.min.y, firstMesh.boundingBox.max.y)
        XCTAssertLessThanOrEqual(firstMesh.boundingBox.min.z, firstMesh.boundingBox.max.z)

        let submesh = try XCTUnwrap(firstMesh.submeshes.first)
        XCTAssertEqual(submesh.metalKitSubmesh.primitiveType, .triangle)
        XCTAssertGreaterThan(submesh.metalKitSubmesh.indexCount, 0)

        if let material = submesh.material {
            XCTAssertGreaterThanOrEqual(material.baseColorValue.w, 0.0)
            XCTAssertLessThanOrEqual(material.baseColorValue.w, 1.0)
        }
    }
}
