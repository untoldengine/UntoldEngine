//
//  NativeFormatHierarchyTests.swift
//  UntoldEngine
//
//  Verifies that `.untold` assets preserve entity parent-child hierarchy through
//  the runtime loader and registration path.
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

final class NativeFormatHierarchyLoaderTests: XCTestCase {
    func testUntoldLoaderPreservesParentChildHierarchy() throws {
        let fixture = try makeHierarchicalUntoldFixture()
        let runtimeAsset = try NativeFormatLoader().loadAssetSync(from: fixture.url)

        XCTAssertEqual(runtimeAsset.nodes.count, 2)

        let parentNode = try XCTUnwrap(runtimeAsset.nodes.first(where: { $0.name == "ParentNode" }))
        let childNode = try XCTUnwrap(runtimeAsset.nodes.first(where: { $0.name == "ChildMeshNode" }))

        XCTAssertNil(parentNode.parentID)
        XCTAssertEqual(childNode.parentID, parentNode.id)
        XCTAssertTrue(parentNode.primitives.isEmpty)
        XCTAssertEqual(childNode.primitives.count, 1)

        let parentTranslation = translation(from: parentNode.worldTransform)
        let childLocalTranslation = translation(from: childNode.localTransform)
        let childWorldTranslation = translation(from: childNode.worldTransform)

        XCTAssertEqual(parentTranslation.x, 2.0, accuracy: 0.0001)
        XCTAssertEqual(parentTranslation.y, 0.0, accuracy: 0.0001)
        XCTAssertEqual(parentTranslation.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(childLocalTranslation.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(childLocalTranslation.y, 3.0, accuracy: 0.0001)
        XCTAssertEqual(childLocalTranslation.z, 0.0, accuracy: 0.0001)
        XCTAssertEqual(childWorldTranslation.x, 2.0, accuracy: 0.0001)
        XCTAssertEqual(childWorldTranslation.y, 3.0, accuracy: 0.0001)
        XCTAssertEqual(childWorldTranslation.z, 0.0, accuracy: 0.0001)
    }

    func testUntoldLoaderPreservesParentChildHierarchyForRealFixture() throws {
        guard let url = Bundle.module.url(forResource: "cubeparentchild", withExtension: "untold") else {
            XCTFail("Failed to locate cubeparentchild.untold in test resources")
            return
        }

        let runtimeAsset = try NativeFormatLoader().loadAssetSync(from: url)

        XCTAssertEqual(runtimeAsset.meshGroups.count, 3)
        XCTAssertGreaterThanOrEqual(runtimeAsset.nodes.count, 3)
        XCTAssertEqual(runtimeAsset.nodes.flatMap(\.primitives).count, 3)
        XCTAssertGreaterThan(runtimeAsset.nodes.filter { $0.parentID != nil }.count, 0)
        XCTAssertGreaterThan(runtimeAsset.nodes.filter(\.primitives.isEmpty).count, 0)

        let nodeIDs = Set(runtimeAsset.nodes.map(\.id))
        for node in runtimeAsset.nodes {
            if let parentID = node.parentID {
                XCTAssertTrue(nodeIDs.contains(parentID), "Every parent ID should resolve to another runtime node")
            }
        }
    }
}

@MainActor
final class NativeFormatHierarchyRegistrationTests: BaseRenderSetup {
    override func tearDown() async throws {
        LoadingSystem.shared.resourceURLFn = getResourceURL
        destroyAllEntities()
        try await super.tearDown()
    }

    override func initializeAssets() {}

    func testSetEntityMesh_buildsEntityHierarchyFromUntoldNodes() throws {
        let fixture = try makeHierarchicalUntoldFixture()
        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, _ in
            guard name == "hierarchy", ext == "untold" else { return nil }
            return fixture.url
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        let rootEntity = createEntity()
        setEntityName(entityId: rootEntity, name: "HierarchyRoot")

        setEntityMesh(entityId: rootEntity, filename: "hierarchy", withExtension: "untold")

        XCTAssertTrue(hasComponent(entityId: rootEntity, componentType: AssetInstanceComponent.self))
        XCTAssertFalse(hasComponent(entityId: rootEntity, componentType: RenderComponent.self))

        let rootChildren = getEntityChildren(parentId: rootEntity)
        XCTAssertEqual(rootChildren.count, 1)

        let parentNodeEntity = try XCTUnwrap(rootChildren.first)
        XCTAssertEqual(getEntityName(entityId: parentNodeEntity), "ParentNode")
        XCTAssertTrue(hasComponent(entityId: parentNodeEntity, componentType: DerivedAssetNodeComponent.self))
        XCTAssertFalse(hasComponent(entityId: parentNodeEntity, componentType: RenderComponent.self))

        let childNodeChildren = getEntityChildren(parentId: parentNodeEntity)
        XCTAssertEqual(childNodeChildren.count, 1)

        let childMeshEntity = try XCTUnwrap(childNodeChildren.first)
        XCTAssertEqual(getEntityName(entityId: childMeshEntity), "ChildMeshNode")
        XCTAssertTrue(hasComponent(entityId: childMeshEntity, componentType: DerivedAssetNodeComponent.self))
        XCTAssertTrue(hasComponent(entityId: childMeshEntity, componentType: RenderComponent.self))

        guard let childLocalTransform = scene.get(component: LocalTransformComponent.self, for: childMeshEntity) else {
            XCTFail("Expected child mesh entity to have a LocalTransformComponent")
            return
        }

        XCTAssertEqual(childLocalTransform.position.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(childLocalTransform.position.y, 3.0, accuracy: 0.0001)
        XCTAssertEqual(childLocalTransform.position.z, 0.0, accuracy: 0.0001)

        guard let childRender = scene.get(component: RenderComponent.self, for: childMeshEntity) else {
            XCTFail("Expected child mesh entity to have a RenderComponent")
            return
        }

        XCTAssertEqual(childRender.assetURL, fixture.url)
        XCTAssertEqual(childRender.assetName, "ChildMeshNode")
        XCTAssertEqual(childRender.mesh.count, 1)
        XCTAssertTrue(transformsApproximatelyEqualForTest(childRender.mesh[0].localSpace, matrix_identity_float4x4))
    }

    func testSetEntityMesh_buildsEntityHierarchyFromRealUntoldFixture() throws {
        guard let url = Bundle.module.url(forResource: "cubeparentchild", withExtension: "untold") else {
            XCTFail("Failed to locate cubeparentchild.untold in test resources")
            return
        }

        let runtimeAsset = try NativeFormatLoader().loadAssetSync(from: url)
        let originalResourceURLFn = LoadingSystem.shared.resourceURLFn
        LoadingSystem.shared.resourceURLFn = { name, ext, _ in
            guard name == "cubeparentchild", ext == "untold" else { return nil }
            return url
        }
        defer { LoadingSystem.shared.resourceURLFn = originalResourceURLFn }

        let rootEntity = createEntity()
        setEntityName(entityId: rootEntity, name: "CubeParentChildRoot")

        setEntityMesh(entityId: rootEntity, filename: "cubeparentchild", withExtension: "untold")

        let allDerivedNodes = collectDescendantEntities(from: rootEntity).filter {
            hasComponent(entityId: $0, componentType: DerivedAssetNodeComponent.self)
        }
        XCTAssertEqual(allDerivedNodes.count, runtimeAsset.nodes.count)

        let derivedNames = Set(allDerivedNodes.map { getEntityName(entityId: $0) })
        XCTAssertEqual(derivedNames, Set(runtimeAsset.nodes.map(\.name)))

        let renderNodes = allDerivedNodes.filter { hasComponent(entityId: $0, componentType: RenderComponent.self) }
        XCTAssertEqual(renderNodes.count, runtimeAsset.nodes.filter { !$0.primitives.isEmpty }.count)

        let entityByName = Dictionary(uniqueKeysWithValues: allDerivedNodes.map { (getEntityName(entityId: $0), $0) })
        let nodeByID = Dictionary(uniqueKeysWithValues: runtimeAsset.nodes.map { ($0.id, $0) })

        for node in runtimeAsset.nodes {
            guard let entity = entityByName[node.name] else {
                XCTFail("Missing derived entity for runtime node \(node.name)")
                continue
            }

            let expectedParentEntity: EntityID = {
                if let parentID = node.parentID, let parentNode = nodeByID[parentID], let entity = entityByName[parentNode.name] {
                    return entity
                }
                return rootEntity
            }()

            XCTAssertEqual(getEntityParent(entityId: entity), expectedParentEntity)
        }
    }
}

private func collectDescendantEntities(from root: EntityID) -> [EntityID] {
    var result: [EntityID] = []
    var queue = getEntityChildren(parentId: root)

    while let current = queue.first {
        queue.removeFirst()
        result.append(current)
        queue.append(contentsOf: getEntityChildren(parentId: current))
    }

    return result
}

private struct HierarchicalUntoldFixture {
    let url: URL
}

private func makeHierarchicalUntoldFixture() throws -> HierarchicalUntoldFixture {
    let stringTable = makeStringTable([
        "ParentNode",
        "ChildMeshNode",
        "ChildPrimitive",
        "ChildMaterial",
    ])

    let parentBounds = UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(1, 1, 1))
    let childBounds = UntoldAABB(min: SIMD3<Float>(-0.5, -0.5, 0), max: SIMD3<Float>(0.5, 0.5, 0))

    let parentEntity = UntoldEntityRecordV1(
        entityId: 0,
        parentEntityId: UntoldFormat.invalidIndex,
        nameOffset: stringTable.offsets["ParentNode"] ?? UntoldFormat.invalidIndex,
        firstMeshRecordIndex: 0,
        meshRecordCount: 0,
        flags: 0,
        localBounds: parentBounds,
        worldBounds: parentBounds,
        localTransform: translationMatrix(x: 2.0, y: 0.0, z: 0.0)
    )

    let childEntity = UntoldEntityRecordV1(
        entityId: 1,
        parentEntityId: 0,
        nameOffset: stringTable.offsets["ChildMeshNode"] ?? UntoldFormat.invalidIndex,
        firstMeshRecordIndex: 0,
        meshRecordCount: 1,
        flags: 0,
        localBounds: childBounds,
        worldBounds: UntoldAABB(min: SIMD3<Float>(1.5, 2.5, 0), max: SIMD3<Float>(2.5, 3.5, 0)),
        localTransform: translationMatrix(x: 0.0, y: 3.0, z: 0.0)
    )

    let material = UntoldMaterialRecordV1(
        nameOffset: stringTable.offsets["ChildMaterial"] ?? UntoldFormat.invalidIndex,
        flags: 0,
        baseColorFactor: SIMD4<Float>(1, 1, 1, 1),
        emissiveFactor: SIMD3<Float>(0, 0, 0),
        normalScale: 1.0,
        metallicFactor: 0.0,
        roughnessFactor: 1.0,
        occlusionStrength: 1.0,
        alphaCutoff: 0.5,
        baseColorTextureIndex: UntoldFormat.invalidIndex,
        normalTextureIndex: UntoldFormat.invalidIndex,
        metallicTextureIndex: UntoldFormat.invalidIndex,
        roughnessTextureIndex: UntoldFormat.invalidIndex,
        emissiveTextureIndex: UntoldFormat.invalidIndex,
        occlusionTextureIndex: UntoldFormat.invalidIndex
    )

    let vertices = [
        UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(-0.5, -0.5, 0),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
            uv0: SIMD2<UInt16>(0, 0),
            uv1: SIMD2<UInt16>(0, 0),
            color0: SIMD4<UInt8>(255, 255, 255, 255)
        ),
        UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(0.5, -0.5, 0),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
            uv0: SIMD2<UInt16>(0, 0),
            uv1: SIMD2<UInt16>(0, 0),
            color0: SIMD4<UInt8>(255, 255, 255, 255)
        ),
        UntoldPBRStaticVertexV1(
            position: SIMD3<Float>(0.0, 0.5, 0),
            normalPacked: UntoldVertexPacking.packNormal(SIMD3<Float>(0, 0, 1)),
            tangentPacked: UntoldVertexPacking.packTangent(SIMD3<Float>(1, 0, 0), handedness: 1),
            uv0: SIMD2<UInt16>(0, 0),
            uv1: SIMD2<UInt16>(0, 0),
            color0: SIMD4<UInt8>(255, 255, 255, 255)
        ),
    ]

    let vertexWriter = UntoldBinaryWriter()
    for vertex in vertices {
        vertex.encode(to: vertexWriter)
    }

    let indexWriter = UntoldBinaryWriter()
    indexWriter.writeUInt16LE(0)
    indexWriter.writeUInt16LE(1)
    indexWriter.writeUInt16LE(2)

    let mesh = UntoldMeshRecordV1(
        entityId: 1,
        meshNameOffset: stringTable.offsets["ChildPrimitive"] ?? UntoldFormat.invalidIndex,
        materialIndex: 0,
        indexType: .uint16,
        vertexCount: 3,
        indexCount: 3,
        vertexStrideBytes: 32,
        flags: 0,
        vertexDataOffset: 0,
        indexDataOffset: 0,
        vertexDataSizeBytes: UInt64(vertexWriter.data.count),
        indexDataSizeBytes: UInt64(indexWriter.data.count),
        estimatedGPUBytes: UInt64(vertexWriter.data.count + indexWriter.data.count),
        localBounds: childBounds
    )

    let chunkPayloads = buildHierarchicalChunkPayloads(
        stringTableData: stringTable.data,
        entities: [parentEntity, childEntity],
        meshes: [mesh],
        materials: [material],
        vertexData: vertexWriter.data,
        indexData: indexWriter.data
    )

    let header = UntoldFileHeaderV1(
        fileType: .tile,
        chunkCount: UInt32(chunkPayloads.count),
        meshCount: 1,
        materialCount: 1,
        textureRefCount: 0,
        entityCount: 2,
        vertexLayout: .pbrStaticV1,
        worldBounds: UntoldAABB(min: SIMD3<Float>(-1, -1, -1), max: SIMD3<Float>(2.5, 3.5, 1))
    )

    let fileData = buildHierarchicalFileData(header: header, chunkPayloads: chunkPayloads)
    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("untold")
    try fileData.write(to: outputURL)
    return HierarchicalUntoldFixture(url: outputURL)
}

private func buildHierarchicalChunkPayloads(
    stringTableData: Data,
    entities: [UntoldEntityRecordV1],
    meshes: [UntoldMeshRecordV1],
    materials: [UntoldMaterialRecordV1],
    vertexData: Data,
    indexData: Data
) -> [(type: UntoldChunkType, data: Data, elementCount: UInt32)] {
    let entityChunk = encodeChunk(entities)
    let meshChunk = encodeChunk(meshes)
    let materialChunk = encodeChunk(materials)
    let textureChunk = Data()

    return [
        (.stringTable, stringTableData, 0),
        (.entityTable, entityChunk, UInt32(entities.count)),
        (.meshTable, meshChunk, UInt32(meshes.count)),
        (.materialTable, materialChunk, UInt32(materials.count)),
        (.textureTable, textureChunk, 0),
        (.vertexData, vertexData, 0),
        (.indexData, indexData, 0),
    ]
}

private func buildHierarchicalFileData(
    header: UntoldFileHeaderV1,
    chunkPayloads: [(type: UntoldChunkType, data: Data, elementCount: UInt32)]
) -> Data {
    let headerWriter = UntoldBinaryWriter()
    header.encode(to: headerWriter)
    let headerSize = headerWriter.count
    let chunkTableSize = chunkPayloads.count * 40

    var runningOffset = headerSize + chunkTableSize
    var chunkEntries: [UntoldChunkEntryV1] = []
    for payload in chunkPayloads {
        runningOffset = align(runningOffset, to: 16)
        chunkEntries.append(
            UntoldChunkEntryV1(
                chunkType: payload.type,
                compressionType: .none,
                fileOffset: UInt64(runningOffset),
                compressedSize: UInt64(payload.data.count),
                uncompressedSize: UInt64(payload.data.count),
                elementCount: payload.elementCount
            )
        )
        runningOffset += payload.data.count
    }

    let writer = UntoldBinaryWriter()
    header.encode(to: writer)
    for entry in chunkEntries {
        entry.encode(to: writer)
    }
    for (payload, entry) in zip(chunkPayloads, chunkEntries) {
        writer.align(to: 16)
        XCTAssertEqual(writer.count, Int(entry.fileOffset))
        writer.writeData(payload.data)
    }

    return writer.data
}

private func encodeChunk(_ records: [some UntoldBinaryEncodable]) -> Data {
    let writer = UntoldBinaryWriter()
    for record in records {
        record.encode(to: writer)
    }
    return writer.data
}

private func makeStringTable(_ strings: [String]) -> (data: Data, offsets: [String: UInt32]) {
    let writer = UntoldBinaryWriter()
    var offsets: [String: UInt32] = [:]
    for string in strings {
        offsets[string] = UInt32(writer.count)
        writer.writeNullTerminatedUTF8(string)
    }
    return (writer.data, offsets)
}

private func align(_ value: Int, to alignment: Int) -> Int {
    guard alignment > 0 else { return value }
    let remainder = value % alignment
    return remainder == 0 ? value : value + (alignment - remainder)
}

private func translationMatrix(x: Float, y: Float, z: Float) -> simd_float4x4 {
    var matrix = matrix_identity_float4x4
    matrix.columns.3 = simd_float4(x, y, z, 1.0)
    return matrix
}

private func translation(from matrix: simd_float4x4) -> SIMD3<Float> {
    SIMD3<Float>(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)
}

private func transformsApproximatelyEqualForTest(_ lhs: simd_float4x4, _ rhs: simd_float4x4, epsilon: Float = 0.0001) -> Bool {
    let delta0 = simd_length(lhs.columns.0 - rhs.columns.0)
    let delta1 = simd_length(lhs.columns.1 - rhs.columns.1)
    let delta2 = simd_length(lhs.columns.2 - rhs.columns.2)
    let delta3 = simd_length(lhs.columns.3 - rhs.columns.3)
    return delta0 < epsilon && delta1 < epsilon && delta2 < epsilon && delta3 < epsilon
}
