//
//  RuntimeAssetLoaderTests.swift
//  UntoldEngine
//
//  Tests for converting cooked `.untold` files into the source-agnostic
//  RuntimeAsset abstraction.
//
//
// Copyright (C) Untold Engine Studios
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import simd
import XCTest
@testable import UntoldEngine

final class RuntimeAssetLoaderTests: XCTestCase {
    func testLoadsRedplayerUntoldIntoRuntimeAsset() async throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold in test resources")
            return
        }

        let runtimeAsset = try await NativeFormatLoader().loadAsset(from: untoldURL)

        XCTAssertEqual(runtimeAsset.sourceKind, .untold)
        XCTAssertEqual(runtimeAsset.sourceURL, untoldURL)
        XCTAssertEqual(runtimeAsset.assetName, "redplayer")
        XCTAssertFalse(runtimeAsset.meshGroups.isEmpty)

        let group = try XCTUnwrap(runtimeAsset.meshGroups.first)
        XCTAssertFalse(group.name.isEmpty)
        XCTAssertFalse(group.primitives.isEmpty)

        let primitive = try XCTUnwrap(group.primitives.first)
        XCTAssertEqual(primitive.vertexLayout, .pbrStaticV1)
        XCTAssertGreaterThan(primitive.vertexCount, 0)
        XCTAssertGreaterThan(primitive.indexCount, 0)
        XCTAssertFalse(primitive.vertexData.isEmpty)
        XCTAssertFalse(primitive.indexData.isEmpty)
        XCTAssertEqual(primitive.vertexData.count, primitive.vertexCount * primitive.vertexLayout.stride)
        XCTAssertEqual(primitive.indexData.count, primitive.indexCount * primitive.indexFormat.byteSize)
        XCTAssertFalse(primitive.name.isEmpty)

        let vertexReader = UntoldBinaryReader(data: primitive.vertexData)
        let firstVertex = try UntoldPBRStaticVertexV1.decode(from: vertexReader)
        XCTAssertTrue(firstVertex.position.x.isFinite)
        XCTAssertTrue(firstVertex.position.y.isFinite)
        XCTAssertTrue(firstVertex.position.z.isFinite)

        let normal = UntoldVertexPacking.unpackNormal(firstVertex.normalPacked)
        let tangent = UntoldVertexPacking.unpackTangent(firstVertex.tangentPacked)
        XCTAssertGreaterThan(length(normal), 0.5)
        XCTAssertGreaterThan(length(tangent.vector), 0.5)
        XCTAssertEqual(abs(tangent.handedness), 1.0)

        if let material = primitive.material {
            XCTAssertGreaterThanOrEqual(material.baseColorFactor.w, 0.0)
            XCTAssertLessThanOrEqual(material.baseColorFactor.w, 1.0)
        }
    }

    func testLoadAssetSyncFromURLProducesValidAsset() throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold in test resources")
            return
        }

        // loadAssetSync reads the file once and passes the same Data to both
        // UntoldReader and the chunk extractor. Verify the result is coherent.
        let asset = try NativeFormatLoader().loadAssetSync(from: untoldURL)

        XCTAssertEqual(asset.sourceKind, .untold)
        XCTAssertEqual(asset.sourceURL, untoldURL)
        XCTAssertFalse(asset.nodes.isEmpty)
        XCTAssertFalse(asset.meshGroups.isEmpty)

        let group = try XCTUnwrap(asset.meshGroups.first)
        XCTAssertFalse(group.primitives.isEmpty)

        let primitive = try XCTUnwrap(group.primitives.first)
        XCTAssertGreaterThan(primitive.vertexCount, 0)
        XCTAssertGreaterThan(primitive.indexCount, 0)
        XCTAssertEqual(primitive.vertexData.count, primitive.vertexCount * primitive.vertexLayout.stride)
        XCTAssertEqual(primitive.indexData.count, primitive.indexCount * primitive.indexFormat.byteSize)
    }

    func testLoadsNamedMeshGroupFromRedplayerUntold() async throws {
        guard let untoldURL = Bundle.module.url(forResource: "redplayer", withExtension: "untold") else {
            XCTFail("Failed to locate redplayer.untold in test resources")
            return
        }

        let asset = try await NativeFormatLoader().loadAsset(from: untoldURL)
        let expectedGroup = try XCTUnwrap(asset.meshGroups.first)

        let namedGroup = try await NativeFormatLoader().loadMeshGroup(named: expectedGroup.name, from: untoldURL)
        XCTAssertEqual(namedGroup, expectedGroup)
    }
}
